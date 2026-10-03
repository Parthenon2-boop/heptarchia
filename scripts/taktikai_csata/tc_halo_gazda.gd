extends Node

# TAKTIKAI CSATA – élő többjátékos csata: a házigazda oldala. ÖNÁLLÓ, a két játékban azonos.
#
# A házigazda gépén fut az egyetlen igazi szimuláció (TcSzim): minden szabály, minden véletlen szám itt dől
# el. A két hadvezér (és a nézők) gépe csak parancsokat küld, és a pillanatképekből rajzol (tc_halo.gd).
#   – A parancsot a küldő oldalának egységeire szűrjük (a másik oldal egységeit nem lehet vezényelni), a
#     pontokat a csatatérre szorítjuk, a láthatatlan ellenséget nem lehet megtámadni; másodpercenként
#     legfeljebb PARANCS_PER_MP parancs.
#   – Pillanatkép ~10×/mp, címzettenként a saját látása szerint (a harc köde itt dől el: a rejtett ellenségről
#     semmi nem megy ki), különbségként (lásd tc_halo_kod.gd).
#   – Felállítás: egyszerre, mindkét fél a saját sávjában; ha mindkettő „kész”, vagy lejár az idő, indul.
#   – Szünet: bármelyik hadvezér kérheti; ha a beállítás szerint kell, a másik jóváhagyja. Ember az ember
#     ellen: hadvezérenként legfeljebb „szunet_db” szünet, egyenként legfeljebb „szunet_mp” másodperc.
#     Sebesség: ember ember ellen 1× és 2× (a másik jóváhagyásával), a gép ellen 1×, 2×, 4×.
#   – Ha egy hadvezér kilép, az oldalát a gép veszi át; ha egyik oldalt sem vezeti ember, a csata
#     a jelenlegi állásból gyorsan végigfut (az eredmény ugyanúgy a szimulációé).
# Használat (a játék Net-je): gazda.indit(cfg, [peer0, peer1], [név0, név1], beall, kuld); gazda.uzenet(peer, adat);
# gazda.nezo_be(peer, nezet, kotott); gazda.kilepett(peer); a `vege` jel a TcSzim.eredmeny()-t adja.

const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")
const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const K := preload("res://scripts/taktikai_csata/tc_halo_kod.gd")

signal vege(eredmeny: Dictionary)
signal vezerles_valtozott

const PILLANAT_MS := 90          # a pillanatképek közti idő (≈11/mp)
const VEZ_MS := 1000             # a vezérlés állapota ennyi időnként akkor is megy (a visszaszámlálók)
const KERES_MS := 15000          # a függő kérésre (szünet, sebesség) ennyi ideig lehet válaszolni
const BETOLT_MAX_MS := 45000     # ha a csatatér ennyi idő alatt sem épül fel valamelyik gépen, a felállítás akkor is indul
const PARANCS_PER_MP := 40
const GEPI_LEPES := 400          # ha egyik oldalt sem vezeti ember: képkockánként ennyi lépés
# a másik oldal eseményei közül ezek mindig látszanak (a csata menete, az ostrom)
const KOZOS_ESEMENYEK := ["TC_EV_END", "TC_EV_WITHDRAW", "TC_EV_GENERAL_FELL", "TC_EV_GATE", "TC_EV_PLAZA",
	"TC_EV_TOWER", "TC_EV_BREACH", "TC_EV_AIRSTRIKE", "TC_EV_MINE", "TC_EV_TOWER_DOWN", "TC_EV_PLAZA_TAKEN", "TC_EV_CITADEL",
	"TC_EV_RELIEF_ARRIVES", "TC_EV_TOWER_DOCK"]

var csata_id: int = 0
var szim: Szim = null
var cfg: Dictionary = {}
var kuld: Callable                       # func(peer: int, adat: PackedByteArray) -> void
var beall: Dictionary = {"szunet_jovahagy": true, "szunet_db": 3, "szunet_mp": 60.0, "telep_mp": 90.0}
var harcos: Array = [0, 0]               # oldalanként a vezető gép (peer), 0: a gép (MI) vezeti
var nevek: Array = ["", ""]
var cimzettek: Dictionary = {}           # peer -> címzett (lásd _cimzett_be)
var szunet: bool = false
var szunet_ki: int = -1
var szunet_vege_ms: int = 0
var szunet_maradt: Array = [3, 3]
var gyors: float = 1.0
var keres: Dictionary = {}               # a függő kérés: {"tipus": "szunet" | "seb", "ki": oldal, "v", "lejar"}
var kesz: Array = [false, false]
var telep_vege_ms: int = 0               # 0: a résztvevők még építik a csatateret
var lezarva: bool = false                # a vége elment (a csomópont csak a késve érkező üzeneteket várja)
var _kezd_ms: int = 0
var _gyujto: float = 0.0
var _pill_ms: int = 0
var _lat_ido: float = 0.0
var _esemeny_n: int = 0
var _utolso: Dictionary = {}             # a listák utoljára látott eleme (lásd _uj_elemek)
var _tolcser_n: int = 0
var _hirek: Array = []                   # [sorszám, kulcs, argumentumok] – rövid értesítések a felületnek
var _hir_n: int = 0
var _mezo_van: Array = []
var _jelzok: Array = []
var _teljes: int = 0                     # a meglévő mezők maszkja (a saját oldalnak)
var _kozos: int = 0                      # ugyanez a csak saját mezők nélkül
var _elozo: Dictionary = {}              # id -> az előző pillanatkép kvantált mezői
var _w: float = 1400.0
var _h: float = 900.0
# mérés
var stat_bajt: int = 0
var stat_pill: int = 0
var stat_kezd_ms: int = 0
var stat_us: int = 0                     # a pillanatképek összeállítására fordított idő (µs)

# ── Indítás ──────────────────────────────────────────────────────

## cfg: a TcSzim.beallit szótára (benne "oldalak"); p_harcos: [peer0, peer1] (0: a gép vezeti); kuld: az üzenet
## elküldése egy résztvevőnek
func indit(p_cfg: Dictionary, p_harcos: Array, p_nevek: Array, p_beall: Dictionary, p_kuld: Callable) -> void:
	cfg = p_cfg.duplicate(true)
	harcos = [int(p_harcos[0]), int(p_harcos[1])]
	nevek = [str(p_nevek[0]), str(p_nevek[1])]
	for k in p_beall: beall[k] = p_beall[k]
	kuld = p_kuld
	var od: Array = cfg.get("oldalak", [])
	for o in mini(2, od.size()): (od[o] as Dictionary)["ai"] = harcos[o] == 0
	szim = Szim.new()
	szim.beallit(cfg)
	if "ter_w" in szim.terkep:
		_w = float(szim.terkep.get("ter_w"))
		_h = float(szim.terkep.get("ter_h"))
	else:
		_w = A.TER_W
		_h = A.TER_H
	_mezo_van.clear()
	var b0: Object = szim.blokkok[0] if not szim.blokkok.is_empty() else null
	for m in K.MEZOK:
		_mezo_van.append(str(m[0]) == "" or (b0 != null and str(m[0]) in b0))
	# a csak az egyik játékban meglévő jelzők (a többit a _kvant_blokk kifejtve olvassa)
	_teljes = 0
	_kozos = 0
	for i in K.MEZOK.size():
		if not _mezo_van[i]: continue
		_teljes |= 1 << i
		if not bool(K.MEZOK[i][2]): _kozos |= 1 << i
	_jelzok.clear()
	for j in [7, 8, 9]:
		if b0 != null and K.JELZOK[j] in b0: _jelzok.append(j)
	szunet_maradt = [int(beall["szunet_db"]), int(beall["szunet_db"])]
	for o in 2: kesz[o] = harcos[o] == 0
	_kezd_ms = Time.get_ticks_msec()
	stat_kezd_ms = _kezd_ms
	for o in 2:
		if harcos[o] > 0: _cimzett_be(harcos[o], o, o, false)

func _cimzett_be(peer: int, oldal: int, nezet: int, kotott: bool) -> void:
	cimzettek[peer] = {"oldal": oldal, "nezet": nezet, "kotott": kotott, "b": {}, "g": [], "lat": {},
		"betoltve": false, "fu": {}, "res": 0, "elso": true, "bajt": 0, "vez": PackedByteArray(), "vez_ms": 0,
		"pc": 0, "pc_ms": 0}
	var start := {"cfg": cfg, "en": oldal, "nezet": nezet, "kotott": kotott, "beall": beall, "nevek": nevek}
	_kuld(peer, K.boritek_var(K.START, csata_id, start))
	_vez_kuld(peer, true)

## Néző csatlakozik (nezet: -1 mindkét oldal látása, 0 / 1 az egyik oldalé; kotott: nem válthat – a
## szövetséges néző csak a szövetségese látását kapja)
func nezo_be(peer: int, nezet: int, kotott: bool) -> void:
	if lezarva or cimzettek.has(peer): return
	_cimzett_be(peer, -1, clampi(nezet, -1, 1), kotott)

func nezo_ki(peer: int) -> void:
	var c: Dictionary = cimzettek.get(peer, {})
	if c.is_empty() or int(c["oldal"]) >= 0: return
	cimzettek.erase(peer)

## Egy résztvevő kilépett (megszakadt a kapcsolata): a hadvezér oldalát a gép veszi át
func kilepett(peer: int) -> void:
	cimzettek.erase(peer)
	for o in 2:
		if harcos[o] != peer: continue
		harcos[o] = 0
		szim.oldalak[o]["ai"] = true
		kesz[o] = true
		if not keres.is_empty(): keres = {}
		if szunet: _folytat()
		_hir("TC_NET_AI_TOOK_OVER", [nevek[o]])
	_vez_valt()

func harcosok_szama() -> int:
	return (1 if harcos[0] > 0 else 0) + (1 if harcos[1] > 0 else 0)

func ember_ember_ellen() -> bool:
	return harcos[0] > 0 and harcos[1] > 0

# ── Futás ────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if szim == null or lezarva: return
	var most := Time.get_ticks_msec()
	match szim.fazis:
		"telepites":
			_lat_ido -= delta
			if _lat_ido <= 0.0:
				_lat_ido = 0.3
				szim.lathatosag_frissit()
			if telep_vege_ms == 0:
				var mind := true
				for o in 2:
					if harcos[o] > 0 and not bool(cimzettek.get(harcos[o], {}).get("betoltve", false)): mind = false
				if mind or most - _kezd_ms > BETOLT_MAX_MS:
					telep_vege_ms = most + int(float(beall["telep_mp"]) * 1000.0)
					_vez_valt()
			elif (kesz[0] and kesz[1]) or most >= telep_vege_ms:
				_indit()
		"csata":
			if szunet and most >= szunet_vege_ms: _folytat()
			if not szunet:
				if harcosok_szama() == 0:
					# senki sem vezeti: a csata a jelenlegi állásból gyorsan lefut
					for i in GEPI_LEPES:
						if szim.fazis != "csata": break
						szim.lep()
				else:
					_gyujto += minf(delta, 0.1) * gyors
					var db := 0
					while _gyujto >= Szim.LEPES and db < 12:
						szim.lep()
						_gyujto -= Szim.LEPES
						db += 1
					if db >= 12: _gyujto = 0.0
	if not keres.is_empty() and most > int(keres.get("lejar", 0)):
		keres = {}
		_vez_valt()
	if most >= _pill_ms or szim.fazis == "vege":
		# (egyenletes ütem: a képkockák hosszától függetlenül átlagosan PILLANAT_MS-onként)
		_pill_ms = maxi(_pill_ms + PILLANAT_MS, most - PILLANAT_MS)
		_pillanatkep()
	for peer in cimzettek.keys():
		if most - int(cimzettek[peer]["vez_ms"]) >= VEZ_MS: _vez_kuld(int(peer), true)
	if szim.fazis == "vege":
		lezarva = true
		var e := szim.eredmeny()
		for peer in cimzettek.keys(): _kuld(int(peer), K.boritek_var(K.VEGE, csata_id, {"e": e}))
		vege.emit(e)

func _indit() -> void:
	if szim.fazis != "telepites": return
	kesz = [true, true]
	szim.indit()
	_vez_valt()

## Teszthez / a gazdagép felületéhez: a csata léptetése a képkockáktól függetlenül
func leptet(mp: float) -> void:
	for i in int(mp / Szim.LEPES):
		if szim.fazis != "csata": break
		szim.lep()

# ── Üzenetek a résztvevőktől ─────────────────────────────────────

func uzenet(peer: int, adat: PackedByteArray) -> void:
	if szim == null or lezarva: return
	var c: Dictionary = cimzettek.get(peer, {})
	if c.is_empty(): return
	match K.tipus_of(adat):
		K.BETOLTVE:
			c["betoltve"] = true
		K.PARANCS:
			# túl sok parancs: a többi elvész
			var most := Time.get_ticks_msec()
			if most - int(c["pc_ms"]) >= 1000:
				c["pc_ms"] = most
				c["pc"] = 0
			c["pc"] = int(c["pc"]) + 1
			if int(c["pc"]) > PARANCS_PER_MP: return
			_parancs(c, K.var_of(adat))
		K.KERES:
			_keres(c, K.var_of(adat))

## Csak a küldő oldalának élő egységei
func _sajat_ids(v: Variant, o: int) -> Array:
	var r: Array = []
	if typeof(v) != TYPE_ARRAY: return r
	for x in (v as Array):
		if typeof(x) != TYPE_INT and typeof(x) != TYPE_FLOAT: continue
		var b := szim.blokk(int(x))
		if b != null and b.oldal == o and not int(x) in r: r.append(int(x))
		if r.size() >= 64: break
	return r

func _parancs(c: Dictionary, v: Variant) -> void:
	var o := int(c["oldal"])
	if o < 0 or harcos[o] == 0 or szim.fazis == "vege": return
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2 or typeof(v[0]) != TYPE_STRING or typeof(v[1]) != TYPE_ARRAY: return
	var nev: String = v[0]
	var a: Array = v[1]
	var n := a.size()
	match nev:
		"vissza":
			szim.visszavonul(o)
			return
		"telepit_tobb":
			# a felállításkori mozgatások egyben: [[„telepit” | „telepit_irany”, id, pont], …]
			if n != 1 or typeof(a[0]) != TYPE_ARRAY or szim.fazis != "telepites": return
			var db := 0
			for x in (a[0] as Array):
				db += 1
				if db > 64: break
				if typeof(x) != TYPE_ARRAY or (x as Array).size() != 3 or typeof(x[0]) != TYPE_STRING: continue
				if typeof(x[1]) not in [TYPE_INT, TYPE_FLOAT]: continue
				var b := szim.blokk(int(x[1]))
				var p := K.pont(x[2], _w, _h)
				if b == null or b.oldal != o or p == Vector2.INF: continue
				if str(x[0]) == "telepit": szim.telepit(b.id, p)
				elif str(x[0]) == "telepit_irany": szim.telepit_irany(b.id, p)
			return
		"legi":
			if n != 1 or not szim.has_method("legicsapas"): return
			var t := szim.blokk(int(a[0]) if typeof(a[0]) in [TYPE_INT, TYPE_FLOAT] else -1)
			if t == null or t.oldal == o or not szim.lathato(t, o): return
			szim.call("legicsapas", o, t.id)
			return
	if n < 1: return
	var ids := _sajat_ids(a[0], o)
	if ids.is_empty(): return
	match nev:
		"mozog":
			if n != 4: return
			var p := K.pont(a[1], _w, _h)
			var ir := K.pont(a[2], 2.0, 2.0)
			if p == Vector2.INF or ir == Vector2.INF: return
			szim.parancs_mozog(ids, p, ir if ir.length() > 0.01 else Vector2.ZERO, bool(a[3]))
		"vonal":
			if n != 4: return
			var p1 := K.pont(a[1], _w, _h)
			var p2 := K.pont(a[2], _w, _h)
			if p1 == Vector2.INF or p2 == Vector2.INF: return
			szim.parancs_vonal(ids, p1, p2, bool(a[3]))
		"tamad":
			if n != 2: return
			var t := szim.blokk(int(a[1]) if typeof(a[1]) in [TYPE_INT, TYPE_FLOAT] else -1)
			# a láthatatlan ellenséget nem lehet megtámadni (a felületén nem is látszik)
			if t == null or t.oldal == o or not szim.lathato(t, o): return
			szim.parancs_tamad(ids, t.id)
		"kapu":
			if n != 2 or typeof(a[1]) not in [TYPE_INT, TYPE_FLOAT]: return
			szim.parancs_kapu(ids, int(a[1]))
		"fal":
			if n != 2: return
			var p := K.pont(a[1], _w, _h)
			if p == Vector2.INF: return
			szim.parancs_fal(ids, p)
		"all":
			szim.parancs_all(ids)
		"alakzat":
			if n != 2 or typeof(a[1]) != TYPE_STRING: return
			szim.parancs_alakzat(ids, str(a[1]).left(24))
		"tuz":
			if n == 2: szim.parancs_tuz(ids, bool(a[1]))
		"zaro":
			if n == 2 and szim.has_method("parancs_zaro"): szim.call("parancs_zaro", ids, bool(a[1]))
		"futas":
			if n == 2: szim.parancs_futas(ids, bool(a[1]))
		"tartalek":
			if n == 2: szim.parancs_tartalek(ids, bool(a[1]))
		"kepesseg":
			if n != 2 or typeof(a[1]) != TYPE_STRING: return
			szim.parancs_kepesseg(ids, str(a[1]).left(24))

func _keres(c: Dictionary, v: Variant) -> void:
	if typeof(v) != TYPE_DICTIONARY: return
	var d: Dictionary = v
	var o := int(c["oldal"])
	match str(d.get("k", "")):
		"kesz":
			if o >= 0 and harcos[o] > 0 and szim.fazis == "telepites":
				kesz[o] = bool(d.get("v", true))
				_vez_valt()
		"szunet":
			if o >= 0 and harcos[o] > 0: _szunet_ker(o)
		"seb":
			if o >= 0 and harcos[o] > 0: _seb_ker(o, float(d.get("v", 1.0)))
		"valasz":
			if o >= 0 and harcos[o] > 0: _valasz(o, bool(d.get("v", false)))
		"nezet":
			if o >= 0 or bool(c["kotott"]): return
			var n := int(d.get("v", -1))
			if n < -1 or n > 1 or n == int(c["nezet"]): return
			c["nezet"] = n
			# a következő pillanatkép mindent újraküld (a régi látás blokkjai az „eltűnt” listán mennek)
			c["b"] = {}
			c["g"] = []
			_vez_kuld(_peer_of(c), true)

func _peer_of(c: Dictionary) -> int:
	for p in cimzettek:
		if is_same(cimzettek[p], c): return int(p)
	return 0

func _szunet_ker(o: int) -> void:
	if szim.fazis != "csata": return
	if szunet:
		_folytat()
		return
	if ember_ember_ellen():
		if int(szunet_maradt[o]) <= 0:
			_hir("TC_NET_NO_PAUSES", [nevek[o]])
			_vez_valt()
			return
		if bool(beall["szunet_jovahagy"]):
			if not keres.is_empty(): return
			keres = {"tipus": "szunet", "ki": o, "v": 0.0, "lejar": Time.get_ticks_msec() + KERES_MS}
			_vez_valt()
			return
	_szunetel(o)

func _szunetel(o: int) -> void:
	szunet = true
	szunet_ki = o
	szunet_vege_ms = Time.get_ticks_msec() + int(float(beall["szunet_mp"]) * 1000.0)
	if ember_ember_ellen(): szunet_maradt[o] = maxi(0, int(szunet_maradt[o]) - 1)
	_vez_valt()

func _folytat() -> void:
	szunet = false
	szunet_ki = -1
	_vez_valt()

## A választható sebességek: ember ember ellen 1× és 2×, a gép ellen 4× is
func sebessegek() -> Array:
	return [1.0, 2.0] if ember_ember_ellen() else [1.0, 2.0, 4.0]

func _seb_ker(o: int, v: float) -> void:
	if not v in sebessegek() or is_equal_approx(v, gyors): return
	if ember_ember_ellen():
		if not keres.is_empty(): return
		keres = {"tipus": "seb", "ki": o, "v": v, "lejar": Time.get_ticks_msec() + KERES_MS}
		_vez_valt()
		return
	gyors = v
	_vez_valt()

func _valasz(o: int, igen: bool) -> void:
	if keres.is_empty() or int(keres["ki"]) == o: return
	var k := keres
	keres = {}
	if igen:
		match str(k["tipus"]):
			"szunet":
				if szim.fazis == "csata" and not szunet: _szunetel(int(k["ki"]))
			"seb":
				gyors = float(k["v"])
	else:
		_hir("TC_NET_DECLINED", [nevek[o]])
	_vez_valt()

func _hir(kulcs: String, args: Array) -> void:
	_hir_n += 1
	_hirek.append([_hir_n, kulcs, args])
	while _hirek.size() > 6: _hirek.pop_front()

# ── A vezérlés állapota ──────────────────────────────────────────

func vezerles(c: Dictionary) -> Dictionary:
	var most := Time.get_ticks_msec()
	var k := {}
	if not keres.is_empty():
		k = {"tipus": keres["tipus"], "ki": keres["ki"], "v": keres["v"], "hatra": maxf(0.0, float(int(keres["lejar"]) - most) / 1000.0)}
	return {"szunet": szunet, "szunet_ki": szunet_ki, "szunet_hatra": maxf(0.0, float(szunet_vege_ms - most) / 1000.0) if szunet else 0.0,
		"gyors": gyors, "sebessegek": sebessegek(), "kesz": kesz.duplicate(), "fazis": szim.fazis,
		"telep_hatra": maxf(0.0, float(telep_vege_ms - most) / 1000.0) if telep_vege_ms > 0 else -1.0,
		"maradt": szunet_maradt.duplicate(), "szunet_db": int(beall["szunet_db"]), "jovahagy": bool(beall["szunet_jovahagy"]),
		"harcos": [harcos[0] > 0, harcos[1] > 0], "nevek": nevek.duplicate(), "keres": k, "nezet": c["nezet"],
		"kotott": c["kotott"], "oldal": c["oldal"], "hirek": _hirek.duplicate(true)}

func _vez_valt() -> void:
	for peer in cimzettek.keys(): _vez_kuld(int(peer), false)
	vezerles_valtozott.emit()

func _vez_kuld(peer: int, mindenkepp: bool) -> void:
	var c: Dictionary = cimzettek.get(peer, {})
	if c.is_empty(): return
	var v := vezerles(c)
	var adat := K.boritek_var(K.VEZERLES, csata_id, v)
	# (a visszaszámlálók nélkül ugyanaz: nem kell újra küldeni)
	var kulcs := v.duplicate()
	kulcs.erase("szunet_hatra"); kulcs.erase("telep_hatra")
	if kulcs.has("keres") and not (kulcs["keres"] as Dictionary).is_empty():
		var kk: Dictionary = (kulcs["keres"] as Dictionary).duplicate()
		kk.erase("hatra")
		kulcs["keres"] = kk
	var lenyomat := var_to_bytes(kulcs)
	if not mindenkepp and lenyomat == c["vez"]: return
	c["vez"] = lenyomat
	c["vez_ms"] = Time.get_ticks_msec()
	_kuld(peer, adat)

func _kuld(peer: int, adat: PackedByteArray) -> void:
	var c: Dictionary = cimzettek.get(peer, {})
	if not c.is_empty(): c["bajt"] = int(c["bajt"]) + adat.size()
	stat_bajt += adat.size()
	if kuld.is_valid(): kuld.call(peer, adat)

# ── Pillanatkép ──────────────────────────────────────────────────

func _latja(c: Dictionary, b: Szim.Blokk) -> bool:
	if szim.fazis == "vege": return true
	var n := int(c["nezet"])
	if n < 0 or b.oldal == n or b.felderitve: return true
	# akit látott elesni / kifutni, az látható marad (a halála is átmegy, rejteni nincs mit)
	return b.allapot > Szim.MENEKUL and (c["lat"] as Dictionary).has(b.id)

## A blokk mezői kvantálva (ugyanaz, mint a K.kvant mezőnként – a gyakoriak kifejtve, mert ez minden
## pillanatképben minden blokkra lefut; a csak az egyik játékban meglévők általánosan)
func _kvant_blokk(b: Szim.Blokk) -> Array:
	var ido := szim.ido
	var r: Array = []
	r.resize(K.MEZOK.size())
	var p := b.poz
	r[0] = Vector2i(clampi(roundi(p.x * 10.0), 0, 65535), clampi(roundi(p.y * 10.0), 0, 65535))
	var ir := b.irany
	r[1] = posmod(roundi(ir.angle() / TAU * 65536.0), 65536) if ir.length_squared() > 0.000001 else 0
	r[2] = clampi(roundi(maxf(b.letszam, 0.0) * 2.0), 0, 65535)
	r[3] = clampi(roundi(b.moral), -32768, 32767)
	r[4] = clampi(b.allapot, 0, 255)
	r[5] = clampi(roundi(b.nyomas * 100.0), -32768, 32767)
	r[6] = clampi(roundi(b.hajt * 100.0), -32768, 32767)
	r[7] = K.kvant(K.IDS, b.kontakt, ido)
	r[8] = clampi(b.harc_cel, -32768, 32767)
	var lc := b.lo_cel
	r[9] = Vector2i(clampi(roundi(lc.x * 10.0), 0, 65535), clampi(roundi(lc.y * 10.0), 0, 65535))
	r[10] = clampi(roundi(b.loves_ido * 10.0), -32768, 32767)
	r[11] = clampi(roundi((ido + b.tuz_alatt) * 10.0), 1, 32767) if b.tuz_alatt > 0.0 else 0
	r[12] = clampi(roundi((ido + b.roham_ido) * 10.0), 1, 32767) if b.roham_ido > 0.0 else 0
	r[13] = clampi(roundi(b.farad * 100.0), -32768, 32767)
	r[14] = b.alakzat
	r[15] = clampi(roundi(b.szel * 10.0), -32768, 32767)
	r[16] = clampi(roundi(b.mely * 10.0), -32768, 32767)
	r[17] = clampi(b.loszer, 0, 65535)
	r[18] = clampi(b.lo_ad_loszer, 0, 65535)
	r[19] = clampi(roundi(b.szinlel_ido * 10.0), -32768, 32767)
	r[20] = clampi(roundi(b.duh_ido * 10.0), -32768, 32767)
	r[21] = clampi(roundi(b.rendezetlen * 10.0), -32768, 32767)
	r[22] = clampi(roundi(b.maszas * 10.0), -32768, 32767)
	r[23] = clampi(roundi((ido + b.kivalt) * 10.0), 1, 32767) if b.kivalt > 0.0 else 0
	r[24] = clampi(roundi((ido + b.vadult) * 10.0), 1, 32767) if b.vadult > 0.0 else 0
	for i in range(25, 28):
		if _mezo_van[i]: r[i] = K.kvant(int(K.MEZOK[i][1]), b.get(str(K.MEZOK[i][0])), ido)
	var bits := (1 if b.rejtett else 0) | (2 if b.tartalek else 0) | (4 if b.tuz_szabad else 0) | (8 if b.futas else 0) \
		| (16 if b.portyaz else 0) | (32 if b.beszivarog else 0) | (64 if b.maszott else 0) | (1024 if b.kivonul else 0) \
		| (2048 if b.dokkolt else 0)
	for j in _jelzok:
		if bool(b.get(K.JELZOK[j])): bits |= 1 << j
	r[28] = bits
	r[29] = b.parancs
	var cp := b.cel_pont
	r[30] = Vector2i(clampi(roundi(cp.x * 10.0), 0, 65535), clampi(roundi(cp.y * 10.0), 0, 65535))
	r[31] = clampi(b.cel_id, -32768, 32767)
	r[32] = K.kvant(K.PTS, b.ut, ido)
	r[33] = b.kep_kesz.duplicate()
	r[34] = (1 if b.fut_parancs else 0) | (2 if b.felderitve else 0)
	r[35] = clampi(roundi(b.akna * 10.0), -32768, 32767)
	return r

func _kvant_glob() -> Array:
	var ido := szim.ido
	var r: Array = []
	for m in K.GLOBALIS:
		var nev: String = m[0]
		var v: Variant = null
		match nev:
			"fazis": v = szim.fazis
			"foter_ido": v = szim.foter_ido
			"ero0": v = szim.ero(0)
			"ero1": v = szim.ero(1)
			"legi0", "legi1":
				# a légierő: -1 nincs, különben a készenlét csataideje (a báb számolja vissza)
				var h := float(szim.call("legi_hatra", 0 if nev == "legi0" else 1)) if szim.has_method("legi_hatra") else -1.0
				v = -1.0 if h < 0.0 else ido + h
				r.append(K.kvant(K.X10, v, ido))
				continue
			"kapuk":
				var a: Array = []
				for k in szim.terkep.kapuk: a.append(maxi(0, roundi(float(k["hp"]))))
				v = a
			"kapu_utes":
				var a: Array = []
				for k in szim.terkep.kapuk: a.append(maxi(0, roundi(float(k.get("utes", -9.0)) * 10.0)))
				v = a
			"tornyok":
				var bits := 0
				for i in mini(szim.terkep.tornyok.size(), 30):
					if bool(szim.terkep.tornyok[i].get("aktiv", true)): bits |= 1 << i
				v = bits
			"resek": v = szim.terkep.resek.size()
			"gyoztes": v = szim.gyoztes
			"fellegvar_ido": v = szim.fellegvar_ido
			"foter_kesz": v = 1 if szim.foter_kesz else 0
			"tornyok_rom":
				var bits := 0
				for i in mini(szim.terkep.tornyok.size(), 30):
					if bool(szim.terkep.tornyok[i].get("rom", false)): bits |= 1 << i
				v = bits
			"felmentes": v = szim.felmentes_ido
		r.append(K.kvant(int(m[1]), v, ido))
	return r

## Az utolsó pillanatkép óta a listába került elemek (a lista elejéről a régiek kieshetnek, a végére jönnek az újak)
func _uj_elemek(kulcs: String, lista: Array) -> Array:
	var utolso: Variant = _utolso.get(kulcs, null)
	var kezd := 0
	if utolso != null:
		kezd = -1
		for i in range(lista.size() - 1, -1, -1):
			if is_same(lista[i], utolso):
				kezd = i + 1
				break
		if kezd < 0: kezd = 0
	_utolso[kulcs] = lista[lista.size() - 1] if not lista.is_empty() else utolso
	return lista.slice(kezd)

func _uj_extra() -> Dictionary:
	var x := {}
	var ev: Array = []
	while _esemeny_n < szim.esemenyek.size():
		ev.append(szim.esemenyek[_esemeny_n])
		_esemeny_n += 1
	x["e"] = ev
	x["l"] = _uj_elemek("l", szim.lovesek)
	x["f"] = _uj_elemek("f", szim.fust_felhok)
	if "robbanasok" in szim: x["r"] = _uj_elemek("r", szim.get("robbanasok"))
	if "raketak" in szim: x["k"] = _uj_elemek("k", szim.get("raketak"))
	if "tolcserek" in szim:
		var ossz := int(szim.get("tolcser_ossz"))
		var lista: Array = szim.get("tolcserek")
		var uj := mini(ossz - _tolcser_n, lista.size())
		_tolcser_n = ossz
		x["t"] = lista.slice(lista.size() - uj) if uj > 0 else []
	return x

func _pillanatkep() -> void:
	if cimzettek.is_empty(): return
	var t0 := Time.get_ticks_usec()
	# blokkonként egyszer: a kvantált mezők, és hogy az előző pillanatkép óta melyik változott (a címzett, aki
	# az előzőt kapta meg, csak ezeket kapja; akinek ugyanaz a tömb az alapja, annak semmi sem változott)
	var vals := {}
	var valt := {}
	for b in szim.blokkok:
		var v := _kvant_blokk(b)
		var pv: Array = _elozo.get(b.id, [])
		if pv.is_empty():
			valt[b.id] = -1
		elif pv == v:
			v = pv
			valt[b.id] = 0
		else:
			var m := 0
			for i in v.size():
				if _mezo_van[i] and pv[i] != v[i]: m |= 1 << i
			valt[b.id] = m
		vals[b.id] = v
	var elozo := _elozo
	_elozo = vals
	var g := _kvant_glob()
	var x := _uj_extra()
	var most := Time.get_ticks_msec()
	var csomagok := {}
	for peer in cimzettek.keys():
		csomagok[peer] = _kodol(cimzettek[peer], vals, valt, elozo, g, x, most)
	# (a mérés csak az összeállítást számolja, a küldést nem)
	stat_pill += 1
	stat_us += Time.get_ticks_usec() - t0
	for peer in csomagok:
		_kuld(int(peer), K.boritek(K.ALLAPOT, csata_id, csomagok[peer]))

func _kodol(c: Dictionary, vals: Dictionary, valt: Dictionary, elozo: Dictionary, g: Array, x: Dictionary, most: int) -> PackedByteArray:
	var sp := StreamPeerBuffer.new()
	sp.put_u32(most & 0xffffffff)
	sp.put_float(szim.ido)
	var fk := 0 if szim.fazis == "telepites" else (1 if szim.fazis == "csata" else 2)
	sp.put_u8((1 if szunet else 0) | (fk << 1))
	sp.put_u8(clampi(roundi(gyors * 10.0), 0, 255))
	# a közös mezők
	var elozo_g: Array = c["g"]
	var gm := 0
	for i in g.size():
		if elozo_g.size() != g.size() or elozo_g[i] != g[i]: gm |= 1 << i
	K.varint_ir(sp, gm)
	for i in g.size():
		if gm & (1 << i): K.ir(sp, int(K.GLOBALIS[i][1]), g[i])
	c["g"] = g
	# a látott blokkok
	var regi: Dictionary = c["lat"]
	var latott := {}
	for b in szim.blokkok:
		if _latja(c, b): latott[b.id] = true
	var ki: Array = []
	for id in regi:
		if not latott.has(id):
			ki.append(int(id))
			(c["b"] as Dictionary).erase(id)
	sp.put_u16(ki.size())
	for id in ki: sp.put_u16(id)
	var bsp := StreamPeerBuffer.new()
	var db := 0
	var bb: Dictionary = c["b"]
	var o := int(c["oldal"])
	for b in szim.blokkok:
		if not latott.has(b.id): continue
		var v: Array = vals[b.id]
		var e: Array = bb.get(b.id, [])
		var sajat := o >= 0 and b.oldal == o
		var szabad := _teljes if sajat else _kozos
		var mask := 0
		if e.is_empty():
			mask = szabad
		elif is_same(e, v):
			continue
		elif int(valt[b.id]) >= 0 and is_same(e, elozo.get(b.id)):
			mask = int(valt[b.id]) & szabad
		else:
			for i in v.size():
				if (szabad & (1 << i)) and e[i] != v[i]: mask |= 1 << i
		if mask == 0:
			bb[b.id] = v
			continue
		db += 1
		bsp.put_u16(b.id)
		K.varint_ir(bsp, mask)
		for i in v.size():
			if mask & (1 << i): K.ir(bsp, int(K.MEZOK[i][1]), v[i])
		bb[b.id] = v
	sp.put_u16(db)
	sp.put_data(bsp.data_array)
	c["lat"] = latott
	# egyéb: események, lövések, hatások (a címzett látása szerint)
	var xe := _extra_cimzett(c, x, latott)
	if xe.is_empty():
		sp.put_u32(0)
	else:
		var xb := var_to_bytes(xe)
		sp.put_u32(xb.size())
		sp.put_data(xb)
	return sp.data_array

func _extra_cimzett(c: Dictionary, x: Dictionary, latott: Dictionary) -> Dictionary:
	var r := {}
	var n := int(c["nezet"])
	var ev: Array = []
	for e in x["e"]:
		if _esemeny_latszik(e, n, latott): ev.append(e)
	if not ev.is_empty(): r["e"] = ev
	var lv: Array = []
	for l in x["l"]:
		var d := _loves_cimzett(l, n, latott)
		if not d.is_empty(): lv.append(d)
	if not lv.is_empty(): r["l"] = lv
	var elso := bool(c["elso"])
	c["elso"] = false
	# a hatások mindenkinek látszanak (a füst, a robbanás, a tölcsér); a későn érkező néző a meglévőket is megkapja
	if elso:
		if not szim.fust_felhok.is_empty(): r["f"] = szim.fust_felhok.duplicate()
		if "tolcserek" in szim and not (szim.get("tolcserek") as Array).is_empty(): r["t"] = (szim.get("tolcserek") as Array).duplicate()
	else:
		for k in ["f", "r", "k", "t"]:
			if x.has(k) and not (x[k] as Array).is_empty(): r[k] = x[k]
	if szim.ostrom:
		var resek: Array = szim.terkep.resek
		if resek.size() > int(c["res"]):
			r["res"] = resek.slice(int(c["res"]))
			c["res"] = resek.size()
		var fu: Dictionary = c["fu"]
		var uj := {}
		for cella in szim.terkep.fal_utes:
			var t := float(szim.terkep.fal_utes[cella])
			if not fu.has(cella) or float(fu[cella]) != t:
				uj[cella] = t
				fu[cella] = t
		if not uj.is_empty(): r["fu"] = uj
	return r

func _esemeny_latszik(e: Dictionary, n: int, latott: Dictionary) -> bool:
	if n < 0: return true
	var o := int(e.get("oldal", -1))
	if o == n: return true
	if str(e.get("kulcs", "")) in KOZOS_ESEMENYEK: return true
	if e.has("poz") and typeof(e["poz"]) == TYPE_VECTOR2:
		var p: Vector2 = e["poz"]
		for b in szim.blokkok:
			if latott.has(b.id) and b.allapot <= Szim.MENEKUL and b.poz.distance_squared_to(p) < 160.0 * 160.0: return true
		return false
	var nev := str(e.get("nev", ""))
	if nev == "": return false
	for b in szim.blokkok:
		if b.oldal == o and b.nev == nev and latott.has(b.id): return true
	return false

## A lövés a címzettnek: ha a lövőt nem látja, a nyíl csak a pálya második felétől látszik (a lövő helye nem megy át)
func _loves_cimzett(l: Dictionary, n: int, latott: Dictionary) -> Dictionary:
	if n < 0: return l
	var forras := szim.blokk(int(l.get("forras", -1)))
	var cel := szim.blokk(int(l.get("cel", -1)))
	var lat_f := forras == null or forras.oldal == n or latott.has(forras.id)
	var lat_c := cel != null and (cel.oldal == n or latott.has(cel.id))
	if forras == null and int(l.get("o", -1)) != n and not lat_c and not l.has("legi"):
		# a torony lövése: a látott célra
		lat_f = false
	if not lat_f and not lat_c: return {}
	if lat_f: return l
	var d := l.duplicate()
	var a: Vector2 = l.get("a", Vector2.ZERO)
	var b: Vector2 = l.get("b", Vector2.ZERO)
	d["a"] = a.lerp(b, 0.55)
	d.erase("forras")
	return d

# ── Mérés ────────────────────────────────────────────────────────

## Címzettenként az elküldött bájtok másodpercenként (a csata kezdete óta) és a pillanatképek ideje
func meres() -> Dictionary:
	var mp := maxf(0.001, float(Time.get_ticks_msec() - stat_kezd_ms) / 1000.0)
	var r := {}
	for peer in cimzettek: r[peer] = float(cimzettek[peer]["bajt"]) / mp
	return {"cimzettek": r, "ossz_bps": float(stat_bajt) / mp, "pillanatkep": stat_pill,
		"pill_us": float(stat_us) / float(maxi(stat_pill, 1))}
