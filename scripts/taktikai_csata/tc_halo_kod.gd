extends RefCounted

# TAKTIKAI CSATA – élő többjátékos csata: az üzenetek kódolása. ÖNÁLLÓ, a két játékban azonos.
#
# A házigazdán fut a szimuláció (tc_halo_gazda.gd); a résztvevők (a két hadvezér és a nézők) gépén egy „báb”
# szimuláció (tc_halo.gd, Bab) csak megjeleníti, amit a házigazda küld. Minden üzenet egy borítékban megy:
#   [típus: u8][csata azonosító: u16][tartalom]
# Házigazda → résztvevő:
#   START     a csata beállítása (cfg), a szerep (melyik oldalt vezeti, vagy néző), a szabályok   (var)
#   ALLAPOT   pillanatkép, másodpercenként ~10× (bináris, különbségek: csak ami változott, lásd lent)
#   VEZERLES  a vezérlés állapota: szünet, sebesség, a „kész” jelek, a függő kérés, a hátralévő idők   (var)
#   VEGE      a csata eredménye (TcSzim.eredmeny())                                                   (var)
# Résztvevő → házigazda:
#   PARANCS   egy parancs: [név, [argumentumok]] (mozog, vonal, tamad, kapu, fal, all, alakzat, tuz, zaro,
#             futas, tartalek, kepesseg, telepit, telepit_irany, vissza, legi)                           (var)
#   KERES     vezérlés-kérés: {"k": "kesz" | "szunet" | "seb" | "valasz" | "nezet", "v": …}           (var)
#   BETOLTVE  a csatatér felépült a résztvevő gépén (a felállítás ideje ettől számít)
#
# A pillanatkép (ALLAPOT):
#   u32 a házigazda órája (ms) · f32 a csata ideje · u8 állapot (0. bit: szünet; 1–2. bit: fázis) · u8 sebesség×10
#   varint maszk + a változott közös mezők (GLOBALIS)
#   u16 db + az eltűnt (már nem látott) blokkok azonosítói
#   u16 db + blokkonként: u16 azonosító, varint maszk, a változott mezők (MEZOK sorrendjében)
#   u32 hossz + var_to_bytes(egyéb: események, lövések, robbanások, füst, falrések…), ha van
# A különbség címzettenként számít (a megbízható csatornán sorrendben érkezik, nem vész el): az újonnan
# látott blokk minden mezője megy, utána csak a változás. Az ellenség rejtett blokkjairól semmi nem megy át
# (a harc köde a házigazdán dől el, a címzett látása szerint), a parancsai, útvonalai (csak saját mezők) sem.

const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")

const START := 1
const ALLAPOT := 2
const VEZERLES := 3
const VEGE := 4
const PARANCS := 10
const KERES := 11
const BETOLTVE := 12

# a mezők fajtái
const V2 := 0        # Vector2, 0,1 egység pontossággal (2 × u16)
const SZOG := 1      # irány (u16, a teljes kör 65536 lépés)
const U8 := 2
const U16 := 3
const I16 := 4
const X10 := 5       # lebegőpontos × 10 (i16)
const X100 := 6      # lebegőpontos × 100 (i16)
const STR := 7       # rövid szöveg (u8 hossz)
const IDS := 8       # azonosítók listája (u8 db × u16)
const PTS := 9       # pontok listája (u8 db × V2)
const VAR := 10      # bármi (var_to_bytes, u16 hossz) – ritkán változik
const IDO := 11      # a csata ideje (× 10, i16): -99 = soha
const HATRA := 12    # visszaszámláló (a lejárat csataideje × 10, i16; 0 = nincs): a báb képkockánként számolja
const OTA := 13      # növekvő számláló („mióta”): a kezdete × 10 (i16)
const BITEK := 14    # jelzők (u16) – a JELZOK, illetve a JELZOK_SAJAT sorrendjében
const LETSZAM := 15  # létszám × 2 (u16)
const I32 := 16

## A blokkok szinkronizált mezői: [név, fajta, csak a saját oldalnak]. A gyakran változók elöl (a maszk
## változó hosszú: az első hét mező egy bájt). Ami az egyik játékban nincs meg, kimarad.
const MEZOK := [
	["poz", V2, false], ["irany", SZOG, false], ["letszam", LETSZAM, false], ["moral", I16, false],
	["allapot", U8, false], ["nyomas", X100, false], ["hajt", X100, false],
	["kontakt", IDS, false], ["harc_cel", I16, false], ["lo_cel", V2, false], ["loves_ido", IDO, false],
	["tuz_alatt", HATRA, false], ["roham_ido", HATRA, false], ["farad", X100, false],
	["alakzat", STR, false], ["szel", X10, false], ["mely", X10, false], ["loszer", U16, false],
	["lo_ad_loszer", U16, false], ["szinlel_ido", IDO, false], ["duh_ido", IDO, false], ["rendezetlen", IDO, false],
	["maszas", X10, false], ["kivalt", HATRA, false], ["vadult", HATRA, false], ["allo_ido", OTA, false],
	["elfojtva", HATRA, false], ["lefogva", X10, false], ["", BITEK, false],
	["parancs", STR, true], ["cel_pont", V2, true], ["cel_id", I16, true], ["ut", PTS, true],
	["kep_kesz", VAR, true], ["", BITEK, true],
	# a városostrom: az akna ásása (csak a saját oldalnak – a védő nem tudja, hol ásnak)
	["akna", X10, true],
]
const JELZOK := ["rejtett", "tartalek", "tuz_szabad", "futas", "portyaz", "beszivarog", "maszott", "fekszik",
	"rohamra", "zaro", "kivonul", "dokkolt"]
const JELZOK_SAJAT := ["fut_parancs", "felderitve"]

## A közös (nem blokkhoz kötött) mezők: [név, fajta]
const GLOBALIS := [
	["fazis", STR], ["foter_ido", X10], ["ero0", I32], ["ero1", I32], ["legi0", HATRA], ["legi1", HATRA],
	["kapuk", IDS], ["kapu_utes", IDS], ["tornyok", I32], ["resek", I32], ["gyoztes", I16],
	# a városostrom: a fellegvár elfoglalása, elesett-e a főtér, a ledöntött tornyok, a felmentő sereg érkezése (csataidő)
	["fellegvar_ido", X10], ["foter_kesz", U8], ["tornyok_rom", I32], ["felmentes", X10],
]

# ── Boríték ──────────────────────────────────────────────────────

static func boritek(tipus: int, csata_id: int, tartalom: PackedByteArray) -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(3)
	r[0] = tipus
	r[1] = csata_id & 0xff
	r[2] = (csata_id >> 8) & 0xff
	r.append_array(tartalom)
	return r

static func boritek_var(tipus: int, csata_id: int, v: Variant) -> PackedByteArray:
	return boritek(tipus, csata_id, var_to_bytes(v))

static func tipus_of(adat: PackedByteArray) -> int:
	return int(adat[0]) if adat.size() >= 3 else -1

static func id_of(adat: PackedByteArray) -> int:
	return int(adat[1]) | (int(adat[2]) << 8) if adat.size() >= 3 else -1

static func tartalom(adat: PackedByteArray) -> PackedByteArray:
	return adat.slice(3)

## A var-tartalom biztonságos kibontása (objektumot nem enged)
static func var_of(adat: PackedByteArray) -> Variant:
	if adat.size() < 4: return null
	return bytes_to_var(adat.slice(3))

# ── Kvantálás ────────────────────────────────────────────────────

## A mező értéke kvantálva (összehasonlítható: ha ez nem változott, nem megy át). ido: a csata ideje
static func kvant(fajta: int, v: Variant, ido: float) -> Variant:
	match fajta:
		V2:
			var p: Vector2 = v
			return Vector2i(clampi(roundi(p.x * 10.0), 0, 65535), clampi(roundi(p.y * 10.0), 0, 65535))
		SZOG:
			var ir: Vector2 = v
			if ir.length_squared() < 0.000001: return 0
			return posmod(roundi(ir.angle() / TAU * 65536.0), 65536)
		U8: return clampi(roundi(float(v)), 0, 255)
		U16: return clampi(int(v), 0, 65535)
		I16: return clampi(roundi(float(v)), -32768, 32767)
		I32: return clampi(roundi(float(v)), -2147483647, 2147483647)
		X10: return clampi(roundi(float(v) * 10.0), -32768, 32767)
		X100: return clampi(roundi(float(v) * 100.0), -32768, 32767)
		STR: return str(v).left(120)
		IDS:
			var r := PackedInt32Array()
			for x in v:
				if r.size() >= 255: break
				r.append(clampi(int(x), 0, 65535))
			return r
		PTS:
			var r := PackedInt32Array()
			for x in v:
				if r.size() >= 510: break
				var p: Vector2 = x
				r.append(clampi(roundi(p.x * 10.0), 0, 65535))
				r.append(clampi(roundi(p.y * 10.0), 0, 65535))
			return r
		VAR:
			# (az összehasonlításhoz maga az érték – a szótár, a tömb tartalom szerint egyezik; kiíráskor kódoljuk)
			if v is Dictionary or v is Array: return v.duplicate(true)
			return v
		IDO: return clampi(roundi(float(v) * 10.0), -32768, 32767)
		HATRA:
			var h := float(v)
			if h <= 0.0: return 0
			return clampi(roundi((ido + h) * 10.0), 1, 32767)
		OTA: return clampi(roundi((ido - float(v)) * 10.0), -32768, 32767)
		LETSZAM: return clampi(roundi(maxf(float(v), 0.0) * 2.0), 0, 65535)
	return v

## A kvantált érték kiírása
static func ir(sp: StreamPeerBuffer, fajta: int, q: Variant) -> void:
	match fajta:
		V2:
			var p: Vector2i = q
			sp.put_u16(p.x); sp.put_u16(p.y)
		SZOG, U16, LETSZAM, BITEK: sp.put_u16(int(q))
		U8: sp.put_u8(int(q))
		I16, X10, X100, IDO, HATRA, OTA: sp.put_16(int(q))
		I32: sp.put_32(int(q))
		STR:
			var b: PackedByteArray = str(q).to_utf8_buffer()
			if b.size() > 255: b = b.slice(0, 255)
			sp.put_u8(b.size()); sp.put_data(b)
		IDS:
			var a: PackedInt32Array = q
			sp.put_u8(a.size())
			for x in a: sp.put_u16(x)
		PTS:
			var a: PackedInt32Array = q
			sp.put_u8(a.size() / 2)
			for x in a: sp.put_u16(x)
		VAR:
			var b: PackedByteArray = var_to_bytes(q)
			sp.put_u16(b.size()); sp.put_data(b)

## Beolvasás: a báb mezőjébe írható érték (a HATRA, OTA nyersen: a lejárat / a kezdet csataideje)
static func olvas(sp: StreamPeerBuffer, fajta: int) -> Variant:
	match fajta:
		V2:
			var x := sp.get_u16()
			var y := sp.get_u16()
			return Vector2(float(x) * 0.1, float(y) * 0.1)
		SZOG: return Vector2.from_angle(float(sp.get_u16()) / 65536.0 * TAU)
		U16, BITEK: return sp.get_u16()
		LETSZAM: return float(sp.get_u16()) * 0.5
		U8: return sp.get_u8()
		I16: return float(sp.get_16())
		I32: return float(sp.get_32())
		X10, IDO: return float(sp.get_16()) * 0.1
		X100: return float(sp.get_16()) * 0.01
		HATRA, OTA: return float(sp.get_16()) * 0.1
		STR:
			var n := sp.get_u8()
			return sp.get_data(n)[1].get_string_from_utf8() if n > 0 else ""
		IDS:
			var n := sp.get_u8()
			var r: Array = []
			for i in n: r.append(sp.get_u16())
			return r
		PTS:
			var n := sp.get_u8()
			var r: Array = []
			for i in n:
				var x := sp.get_u16()
				var y := sp.get_u16()
				r.append(Vector2(float(x) * 0.1, float(y) * 0.1))
			return r
		VAR:
			var n := sp.get_u16()
			if n == 0: return null
			return bytes_to_var(sp.get_data(n)[1])
	return null

## Változó hosszú egész (7 bit bájtonként)
static func varint_ir(sp: StreamPeerBuffer, v: int) -> void:
	while true:
		var b := v & 0x7f
		v = v >> 7
		if v != 0:
			sp.put_u8(b | 0x80)
		else:
			sp.put_u8(b)
			return

static func varint_olvas(sp: StreamPeerBuffer) -> int:
	var v := 0
	var s := 0
	while s < 63:
		var b := sp.get_u8()
		v |= (b & 0x7f) << s
		if (b & 0x80) == 0: break
		s += 7
	return v

## A jelzők egy egészben (a blokk nem létező mezői kimaradnak)
static func bitek(b: Object, nevek: Array) -> int:
	var r := 0
	for i in nevek.size():
		var n: String = nevek[i]
		if n in b and bool(b.get(n)): r |= 1 << i
	return r

## Egy parancs ellenőrzött Vector2-je (véges szám a csatatéren), különben INF
static func pont(v: Variant, w: float, h: float) -> Vector2:
	if typeof(v) != TYPE_VECTOR2: return Vector2.INF
	var p: Vector2 = v
	if not p.is_finite(): return Vector2.INF
	return Vector2(clampf(p.x, -50.0, w + 50.0), clampf(p.y, -50.0, h + 50.0))
