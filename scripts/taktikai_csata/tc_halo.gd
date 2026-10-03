extends Node

# TAKTIKAI CSATA – élő többjátékos csata: a résztvevő (hadvezér vagy néző) oldala. ÖNÁLLÓ, a két játékban azonos.
#
# A csatát a házigazda szimulálja (tc_halo_gazda.gd); itt egy „báb” szimuláció (Bab: a TcSzim leszármazottja)
# áll, amelyet a felület (tc_csata) és a rajz (tc_nezet) ugyanúgy olvas, mint egyjátékos módban – de nem lép
# magától: a házigazda pillanatképeiből kapja az állapotot, a parancsokat pedig (a felület ugyanazokat a
# szim.parancs_*() függvényeket hívja) a házigazdának küldi.
#   – Simítás: a pillanatképek a házigazda órájával jönnek; a lejátszás ~KESLELTETES ms-mal mögöttük jár, és a
#     két szomszédos kép közt simít (a tc_nezet alfa-ja). A visszaszámlálókat képkockánként számolja.
#   – A harc ködét a házigazda alkalmazza: amit a címzett nem lát, az meg sem érkezik ide.
#   – Felállításkor a saját egységek húzása azonnal látszik (helyben is elvégzi), a házigazda ugyanígy rakja le.
# A felület kiegészítései (kész, szünetkérés, jóváhagyás, néző: a látás választása, vissza a térképre) is itt
# épülnek fel, a tc_csata ui-jára.

const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")
const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const K := preload("res://scripts/taktikai_csata/tc_halo_kod.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")

const KESLELTETES := 130         # ms: a lejátszás ennyivel jár a legfrissebb pillanatkép mögött
const HELYI_MS := 700            # a felállításkor helyben mozgatott egység ennyi ideig nem ugrik vissza

signal vege_jott

## A báb: a felület és a rajz számára ugyanolyan, mint a TcSzim, de az állapota a házigazdától jön
class Bab extends Szim:
	var halo: Object = null
	var latott: Dictionary = {}               # a most látott blokkok (a saját oldal mindig)
	var ero_net: Array = [1.0, 1.0]
	var legi_net: Array = [-1.0, -1.0]        # a légierő készenléte (csataidő), -1: nincs
	var eredmeny_net: Dictionary = {}
	var _helyben: bool = false

	func lep(_dt: float = LEPES) -> void:
		pass

	func lathatosag_frissit() -> void:
		pass

	func lathatosag_frissit_egy(_b: Szim.Blokk) -> void:
		pass

	func lathato(b: Szim.Blokk, _nezo: int) -> bool:
		return latott.has(b.id) or fazis == "vege"

	func ero(o: int) -> float:
		return float(ero_net[o])

	func indit() -> void:
		if halo != null: halo.kesz_valt()

	func telepit(id: int, p: Vector2) -> void:
		super(id, p)
		if halo == null: return
		halo.helyi_mozgas(id)
		if not _helyben: halo.parancs("telepit", [id, p])

	func telepit_irany(id: int, ir: Vector2) -> void:
		super(id, ir)
		if halo == null: return
		halo.helyi_mozgas(id)
		if not _helyben: halo.parancs("telepit_irany", [id, ir])

	func parancs_mozog(ids: Array, pont: Vector2, ir: Vector2 = Vector2.ZERO, fut: bool = false) -> void:
		if halo != null: halo.parancs("mozog", [ids, pont, ir, fut])
		if fazis == "telepites":
			_helyben = true
			super(ids, pont, ir, fut)
			_helyben = false

	func parancs_vonal(ids: Array, a: Vector2, c: Vector2, fut: bool = false) -> void:
		if halo != null: halo.parancs("vonal", [ids, a, c, fut])
		if fazis == "telepites":
			_helyben = true
			super(ids, a, c, fut)
			_helyben = false

	func parancs_tamad(ids: Array, cel_id: int) -> void:
		if halo != null: halo.parancs("tamad", [ids, cel_id])

	func parancs_kapu(ids: Array, kapu_i: int) -> void:
		if halo != null: halo.parancs("kapu", [ids, kapu_i])

	## (a felület ebből tudja, kapott-e parancsot gép – a kos, az ostromtorony, a hajítógép, az aknászok, a löveg; a
	## házigazda ugyanígy dönt – a falak, a tornyok itt is állnak)
	func parancs_fal(ids: Array, p: Vector2) -> bool:
		if not ostrom or fazis != "csata": return false
		var van := false
		for id in ids:
			var b := blokk(int(id))
			if b == null or not b.aktiv() or b.oldal == vedo: continue
			if b.gep != "" or ("tuzer" in b and bool(b.get("tuzer"))): van = true
		if not van: return false
		var jo := not O.hajito_cel(self, p).is_empty()
		for i in terkep.kapuk.size():
			if terkep.kapu_all(i) and p.distance_to(Vector2(terkep.kapuk[i]["p"])) < A.CELLA * 4.0: jo = true
		if not jo: return false
		if halo != null: halo.parancs("fal", [ids, p])
		return true

	func parancs_all(ids: Array) -> void:
		if halo != null: halo.parancs("all", [ids])

	func parancs_alakzat(ids: Array, nev: String) -> void:
		if halo != null: halo.parancs("alakzat", [ids, nev])

	func parancs_tuz(ids: Array, szabad: bool) -> void:
		if halo != null: halo.parancs("tuz", [ids, szabad])

	func parancs_zaro(ids: Array, be: bool) -> void:
		if halo != null: halo.parancs("zaro", [ids, be])

	func parancs_futas(ids: Array, fut: bool) -> void:
		if halo != null: halo.parancs("futas", [ids, fut])

	func parancs_tartalek(ids: Array, t: bool) -> void:
		if halo != null: halo.parancs("tartalek", [ids, t])

	func parancs_kepesseg(ids: Array, nev: String) -> void:
		if halo != null: halo.parancs("kepesseg", [ids, nev])

	func visszavonul(_o: int) -> void:
		if halo != null: halo.parancs("vissza", [])

	func legi_hatra(o: int) -> float:
		var x := float(legi_net[o])
		if x < 0.0: return -1.0
		return maxf(0.0, x - ido)

	func legicsapas(o: int, cel_id: int) -> bool:
		if fazis != "csata" or legi_hatra(o) != 0.0: return false
		if halo != null: halo.parancs("legi", [cel_id])
		return true

	func eredmeny() -> Dictionary:
		if not eredmeny_net.is_empty(): return eredmeny_net
		return super()

var csata_id: int = 0
var cfg: Dictionary = {}
var en: int = -1                 # a vezetett oldal (-1: néző)
var nezet_oldal: int = -1        # a látás (-1: mindkét oldalé – néző)
var kotott: bool = false         # a néző nem választhat másik látást (szövetséges néző)
var beall: Dictionary = {}
var nevek: Array = ["", ""]
var bab: Bab = null
var kuld: Callable               # func(adat: PackedByteArray): a házigazdának
var kilepes: Callable            # func(): a néző visszamegy a térképre (a Net értesíti a házigazdát)
var csata: Node = null           # a tc_csata
var alfa: float = 1.0
var ido_lep: float = 0.0
var szunet: bool = false
var gyors: float = 1.0
var vez: Dictionary = {}
var lezarva: bool = false        # a csata véget ért (megjött az eredmény)
# mérés
var stat_bajt: int = 0
var stat_pill: int = 0
var stat_kezd_ms: int = 0

var _sor: Array = []             # a beérkezett, még le nem játszott pillanatképek
var _cur: Dictionary = {}
var _kov_t: int = -1
var _net: Dictionary = {}        # id -> a mezők utolsó értékei (a MEZOK sorrendjében)
var _lat: Dictionary = {}        # a hálózaton most látott blokkok
var _ofszet: float = INF         # a helyi és a házigazda órája közti legkisebb különbség (ms)
var _lejar: Dictionary = {}      # id -> {mező: lejárat csataideje} (HATRA)
var _ota: Dictionary = {}        # id -> {mező: kezdet csataideje} (OTA)
var _helyi: Dictionary = {}      # id -> ms: felállításkor helyben mozgatva
var _hir_lat: int = 0
var _hir_sor: Array = []         # [szöveg, lejárat ms]
var _mezo_van: Array = []
var _telep_var: Dictionary = {}  # a még el nem küldött felállítási mozgatások
var _telep_ms: int = 0
const TELEP_MS := 60

# ── Indítás ──────────────────────────────────────────────────────

## A START üzenet tartalmából (a Net hívja)
func beallit(start: Dictionary) -> void:
	cfg = start.get("cfg", {})
	en = int(start.get("en", -1))
	nezet_oldal = int(start.get("nezet", -1))
	kotott = bool(start.get("kotott", false))
	beall = start.get("beall", {})
	nevek = start.get("nevek", ["", ""])
	stat_kezd_ms = Time.get_ticks_msec()

## A báb (a tc_csata.indit hívja a TcSzim helyett): ugyanabból a beállításból épül, mint a házigazdáé (ugyanaz a
## terep, ugyanazok az azonosítók), de egyik oldalát sem vezeti gép, és az ellenségből semmit nem lát
func szim_keszit(p_cfg: Dictionary) -> Bab:
	var c := p_cfg.duplicate(true)
	for s in c.get("oldalak", []): (s as Dictionary)["ai"] = false
	bab = Bab.new()
	bab.halo = self
	bab.beallit(c)
	bab.latott.clear()
	for b in bab.blokkok:
		b.felderitve = false
		b.latva = -99.0
	_mezo_van.clear()
	var b0: Object = bab.blokkok[0] if not bab.blokkok.is_empty() else null
	for m in K.MEZOK: _mezo_van.append(str(m[0]) == "" or (b0 != null and str(m[0]) in b0))
	# ami a felület felépülése előtt jött
	return bab

## A felület kész (a tc_csata.indit végén): a házigazda ettől számolja a felállítás idejét
func betoltve() -> void:
	_kuld(K.boritek(K.BETOLTVE, csata_id, PackedByteArray()))

# ── Küldés ───────────────────────────────────────────────────────

func parancs(nev: String, args: Array) -> void:
	if en < 0 or lezarva: return
	if nev == "telepit" or nev == "telepit_irany":
		# a felállításkori húzás képkockánként mozgat: egységenként a legutolsó hely megy, TELEP_MS-onként egyben
		_telep_var["%s:%d" % [nev, int(args[0])]] = [nev, int(args[0]), args[1]]
		return
	_kuld(K.boritek_var(K.PARANCS, csata_id, [nev, args]))

func _telep_kuld() -> void:
	if _telep_var.is_empty(): return
	var lista: Array = _telep_var.values()
	_telep_var.clear()
	_kuld(K.boritek_var(K.PARANCS, csata_id, ["telepit_tobb", [lista]]))

func keres(d: Dictionary) -> void:
	if lezarva: return
	_kuld(K.boritek_var(K.KERES, csata_id, d))

func _kuld(adat: PackedByteArray) -> void:
	if kuld.is_valid(): kuld.call(adat)

func helyi_mozgas(id: int) -> void:
	_helyi[id] = Time.get_ticks_msec()

## A felület gombjai
func kesz_valt() -> void:
	if en < 0 or bab == null or bab.fazis != "telepites": return
	var k: Array = vez.get("kesz", [false, false])
	keres({"k": "kesz", "v": not bool(k[en])})

func szunet_ker() -> void:
	if en >= 0: keres({"k": "szunet"})

func sebesseg_ker(s: float) -> void:
	if en >= 0: keres({"k": "seb", "v": s})

# ── Fogadás ──────────────────────────────────────────────────────

func uzenet(adat: PackedByteArray) -> void:
	stat_bajt += adat.size()
	match K.tipus_of(adat):
		K.ALLAPOT:
			stat_pill += 1
			_allapot(K.tartalom(adat))
		K.VEZERLES:
			var v: Variant = K.var_of(adat)
			if typeof(v) == TYPE_DICTIONARY:
				vez = v
				if int(vez.get("nezet", nezet_oldal)) != nezet_oldal:
					nezet_oldal = int(vez["nezet"])
					if csata != null: csata.nezo_valt(nezet_oldal)
				kotott = bool(vez.get("kotott", kotott))
				for h in vez.get("hirek", []):
					if int(h[0]) > _hir_lat:
						_hir_lat = int(h[0])
						_hir_sor.append([_fmt(str(h[1]), h[2]), Time.get_ticks_msec() + 6000])
		K.VEGE:
			var v: Variant = K.var_of(adat)
			if typeof(v) == TYPE_DICTIONARY and bab != null:
				bab.eredmeny_net = v.get("e", {})
			lezarva = true
			vege_jott.emit()

func _allapot(adat: PackedByteArray) -> void:
	if bab == null: return
	var sp := StreamPeerBuffer.new()
	sp.data_array = adat
	var t := int(sp.get_u32())
	var ido := sp.get_float()
	var all := sp.get_u8()
	var gy := float(sp.get_u8()) / 10.0
	var e := {"t": t, "ido": ido, "szunet": (all & 1) != 0, "fazis": ["telepites", "csata", "vege", "vege"][(all >> 1) & 3],
		"gyors": gy, "g": {}, "valt": {}, "ki": [], "x": {}}
	var d := float(Time.get_ticks_msec() - t)
	_ofszet = d if _ofszet == INF else minf(_ofszet + 0.4, d)
	var gm := K.varint_olvas(sp)
	for i in K.GLOBALIS.size():
		if gm & (1 << i): e["g"][i] = K.olvas(sp, int(K.GLOBALIS[i][1]))
	var nki := sp.get_u16()
	for i in nki:
		var id := sp.get_u16()
		e["ki"].append(id)
		_lat.erase(id)
	var db := sp.get_u16()
	for i in db:
		var id := sp.get_u16()
		var mask := K.varint_olvas(sp)
		if not _net.has(id):
			var ures: Array = []
			ures.resize(K.MEZOK.size())
			_net[id] = ures
		var v: Array = _net[id]
		var valt := {}
		for j in K.MEZOK.size():
			if mask & (1 << j):
				var x: Variant = K.olvas(sp, int(K.MEZOK[j][1]))
				v[j] = x
				valt[j] = x
		e["valt"][id] = valt
		_lat[id] = true
	var poz := {}
	for id in _lat:
		var v: Array = _net.get(id, [])
		if v.is_empty() or v[0] == null: continue
		poz[id] = [v[0], v[1] if v[1] != null else Vector2(0, -1)]
	e["poz"] = poz
	var xn := sp.get_u32()
	if xn > 0:
		var xv: Variant = bytes_to_var(sp.get_data(xn)[1])
		if typeof(xv) == TYPE_DICTIONARY: e["x"] = xv
	_sor.append(e)

# ── Lejátszás (a tc_csata hívja minden képkockában) ──────────────

func frissit(delta: float) -> void:
	if bab == null:
		return
	var most := Time.get_ticks_msec()
	if most - _telep_ms >= TELEP_MS:
		_telep_ms = most
		_telep_kuld()
	var rt := float(most) - _ofszet - float(KESLELTETES)
	if _ofszet == INF: rt = -INF
	var valt := false
	# ha nagyon lemaradt (a csatatér felépítése alatt jött sok kép), egyszerre utoléri
	while _sor.size() > 12:
		_alkalmaz(_sor.pop_front())
		valt = true
	while not _sor.is_empty() and float(int(_sor[0]["t"])) <= rt:
		_alkalmaz(_sor.pop_front())
		valt = true
	var kov: Dictionary = _sor[0] if not _sor.is_empty() else {}
	var kt := int(kov["t"]) if not kov.is_empty() else -1
	if valt or kt != _kov_t:
		_kov_t = kt
		_celok(kov)
	var ido0 := bab.ido
	if not _cur.is_empty():
		var a := 1.0
		if not kov.is_empty():
			var dt := float(kt - int(_cur["t"]))
			a = clampf((rt - float(int(_cur["t"]))) / maxf(dt, 1.0), 0.0, 1.0)
			bab.ido = lerpf(float(_cur["ido"]), float(kov["ido"]), a)
		else:
			bab.ido = float(_cur["ido"])
		alfa = a
		szunet = bool(_cur["szunet"])
		gyors = float(_cur["gyors"])
	ido_lep = maxf(0.0, bab.ido - ido0) if bab.fazis == "csata" else 0.0
	_szamlalok()
	_ui_frissit(delta)

func _celok(kov: Dictionary) -> void:
	if _cur.is_empty(): return
	var most := Time.get_ticks_msec()
	var p0s: Dictionary = _cur["poz"]
	var p1s: Dictionary = kov.get("poz", {})
	for id in p0s:
		var b := bab.blokk(int(id))
		if b == null: continue
		if most - int(_helyi.get(id, -100000)) < HELYI_MS and bab.fazis == "telepites": continue
		var p0: Array = p0s[id]
		var p1: Array = p1s.get(id, p0)
		b.elozo_poz = p0[0]
		b.elozo_irany = p0[1]
		b.poz = p1[0]
		b.irany = p1[1]

func _alkalmaz(e: Dictionary) -> void:
	var g: Dictionary = e["g"]
	for i in g:
		var nev: String = K.GLOBALIS[int(i)][0]
		var v: Variant = g[i]
		match nev:
			"fazis": bab.fazis = str(v)
			"foter_ido": bab.foter_ido = float(v)
			"ero0": bab.ero_net[0] = float(v)
			"ero1": bab.ero_net[1] = float(v)
			"legi0": bab.legi_net[0] = float(v)
			"legi1": bab.legi_net[1] = float(v)
			"gyoztes": bab.gyoztes = int(v)
			"kapuk":
				var a: Array = v
				for k in mini(a.size(), bab.terkep.kapuk.size()):
					var volt := float(bab.terkep.kapuk[k]["hp"])
					bab.terkep.kapuk[k]["hp"] = float(a[k])
					if volt > 0.0 and float(a[k]) <= 0.0: bab.terkep.kapu_tor(k)
			"kapu_utes":
				var a: Array = v
				for k in mini(a.size(), bab.terkep.kapuk.size()):
					if int(a[k]) > 0: bab.terkep.kapuk[k]["utes"] = float(a[k]) * 0.1
			"tornyok":
				var bits := int(v)
				for k in mini(bab.terkep.tornyok.size(), 30): bab.terkep.tornyok[k]["aktiv"] = (bits & (1 << k)) != 0
			"tornyok_rom":
				var bits := int(v)
				for k in mini(bab.terkep.tornyok.size(), 30): bab.terkep.tornyok[k]["rom"] = (bits & (1 << k)) != 0
			"fellegvar_ido": bab.fellegvar_ido = float(v)
			"foter_kesz": bab.foter_kesz = int(v) != 0
			"felmentes": bab.felmentes_ido = float(v)
	bab.fazis = str(e["fazis"])
	# az eltűnt (már nem látott) blokkok: az utolsó látott helyük „szellemként” marad
	for id in e["ki"]:
		bab.latott.erase(id)
		var b := bab.blokk(int(id))
		if b != null and b.oldal != en: b.felderitve = false
	var valt: Dictionary = e["valt"]
	for id in valt:
		var b := bab.blokk(int(id))
		if b == null: continue
		var uj := not bab.latott.has(id)
		bab.latott[id] = true
		var m: Dictionary = valt[id]
		for j in m: _mezo_be(b, int(j), m[j])
		if uj and m.has(0):
			b.poz = m[0]
			b.elozo_poz = m[0]
			if m.has(1):
				b.irany = m[1]
				b.elozo_irany = m[1]
	# a látott ellenség: most is látja (a szellem innen indul, ha eltűnik)
	for id in e["poz"]:
		var b := bab.blokk(int(id))
		if b == null or b.oldal == en: continue
		var p: Array = e["poz"][id]
		b.felderitve = true
		b.latva = float(e["ido"])
		b.lat_poz = p[0]
		b.lat_irany = p[1]
		b.lat_szel = b.szel
		b.lat_mely = b.mely
	_extra(e["x"], float(e["ido"]))
	_cur = e

func _mezo_be(b: Szim.Blokk, j: int, v: Variant) -> void:
	var m: Array = K.MEZOK[j]
	var nev: String = m[0]
	var f: int = m[1]
	match f:
		K.BITEK:
			var nevek_: Array = K.JELZOK_SAJAT if bool(m[2]) else K.JELZOK
			for i in nevek_.size():
				var n: String = nevek_[i]
				if n in b: b.set(n, (int(v) & (1 << i)) != 0)
			return
		K.HATRA:
			if not _lejar.has(b.id): _lejar[b.id] = {}
			_lejar[b.id][nev] = float(v)
			return
		K.OTA:
			if not _ota.has(b.id): _ota[b.id] = {}
			_ota[b.id][nev] = float(v)
			return
	match nev:
		"poz", "irany": return            # a simítás állítja (lásd _celok)
		"kep_kesz":
			b.kep_kesz = v if typeof(v) == TYPE_DICTIONARY else {}
		"kontakt", "ut":
			b.set(nev, v if v != null else [])
		"allapot", "loszer", "lo_ad_loszer", "harc_cel", "cel_id":
			b.set(nev, int(v))
		_:
			b.set(nev, v)

func _szamlalok() -> void:
	var ido := bab.ido
	for id in _lejar:
		var b := bab.blokk(int(id))
		if b == null: continue
		var d: Dictionary = _lejar[id]
		for n in d:
			var x := float(d[n])
			b.set(n, maxf(0.0, x - ido) if x > 0.0 else 0.0)
	for id in _ota:
		var b := bab.blokk(int(id))
		if b == null: continue
		var d: Dictionary = _ota[id]
		for n in d: b.set(n, maxf(0.0, ido - float(d[n])))

func _extra(x: Dictionary, ido: float) -> void:
	for e in x.get("e", []): bab.esemenyek.append(e)
	if x.has("l"):
		for l in x["l"]: bab.lovesek.append(l)
	if not bab.lovesek.is_empty() and ido - float(bab.lovesek[0]["ido"]) > 2.5:
		bab.lovesek = bab.lovesek.filter(func(l: Dictionary) -> bool: return ido - float(l["ido"]) <= 2.5)
	if x.has("f"):
		for f in x["f"]: bab.fust_felhok.append(f)
	if not bab.fust_felhok.is_empty():
		bab.fust_felhok = bab.fust_felhok.filter(func(f: Array) -> bool: return ido - float(f[2]) <= float(f[3]) + 1.0)
	if "robbanasok" in bab:
		var r: Array = bab.get("robbanasok")
		for y in x.get("r", []): r.append(y)
		if not r.is_empty() and ido - float(r[0]["ido"]) > 1.5:
			bab.set("robbanasok", r.filter(func(y: Dictionary) -> bool: return ido - float(y["ido"]) <= 1.5))
	if "raketak" in bab:
		var r: Array = bab.get("raketak")
		for y in x.get("k", []): r.append(y)
		while r.size() > 40: r.pop_front()
	if "tolcserek" in bab and x.has("t"):
		var r: Array = bab.get("tolcserek")
		for y in x["t"]: r.append(y)
		bab.set("tolcser_ossz", int(bab.get("tolcser_ossz")) + (x["t"] as Array).size())
		while r.size() > 600: r.pop_front()
	for c in x.get("res", []):
		bab.terkep.fal_tor({"cellak": [int(c)], "c": -1})
	var fu: Dictionary = x.get("fu", {})
	for c in fu: bab.terkep.fal_utes[c] = float(fu[c])

## Mérés: bájt / mp és pillanatkép / mp a kezdet óta
func meres() -> Dictionary:
	var mp := maxf(0.001, float(Time.get_ticks_msec() - stat_kezd_ms) / 1000.0)
	return {"bps": float(stat_bajt) / mp, "pill_mp": float(stat_pill) / mp, "sor": _sor.size(), "ofszet": _ofszet}

# ── A felület kiegészítései ──────────────────────────────────────

var _lbl: Label = null
var _keres_panel: PanelContainer = null
var _keres_lbl: Label = null
var _nezo_sor: PanelContainer = null
var _nezet_opt: OptionButton = null
var _ui_ido: float = 0.0

## A tc_csata felületére (az indit végén hívja)
func ui_epit(cs: Node) -> void:
	csata = cs
	var ui: Control = cs.ui
	_lbl = cs._cimke("", 16, Color(1.0, 0.92, 0.65))
	_lbl.add_theme_constant_override("outline_size", 5)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl.position.y = cs.FELSO_M + 50
	ui.add_child(_lbl)
	# kérés (szünet, sebesség) a másik hadvezértől
	_keres_panel = PanelContainer.new()
	_keres_panel.add_theme_stylebox_override("panel", cs._panel_stilus(0.96))
	_keres_panel.visible = false
	ui.add_child(_keres_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_keres_panel.add_child(v)
	_keres_lbl = cs._cimke("", 16)
	_keres_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_keres_lbl)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	h.add_child(cs._gomb(tr("TC_NET_ACCEPT"), func() -> void: keres({"k": "valasz", "v": true}), 120))
	h.add_child(cs._gomb(tr("TC_NET_DECLINE"), func() -> void: keres({"k": "valasz", "v": false}), 120))
	if en < 0:
		# néző: nem vezényel; a látás választása (ha nem kötött), vissza a térképre
		for b in [cs.btn_szunet, cs.btn_vissza]:
			if b != null: b.visible = false
		for par in cs.btn_seb: (par[0] as Button).visible = false
		if cs.telep_panel != null: cs.telep_panel.visible = false
		_nezo_sor = PanelContainer.new()
		_nezo_sor.add_theme_stylebox_override("panel", cs._panel_stilus(0.9))
		_nezo_sor.position = Vector2(8, cs.FELSO_M + 8)
		ui.add_child(_nezo_sor)
		var hs := HBoxContainer.new()
		hs.add_theme_constant_override("separation", 8)
		_nezo_sor.add_child(hs)
		hs.add_child(cs._cimke(tr("TC_NET_SPECTATING"), 15, Color(1.0, 0.88, 0.55)))
		hs.add_child(cs._cimke(tr("TC_NET_VIEW"), 14))
		_nezet_opt = OptionButton.new()
		_nezet_opt.focus_mode = Control.FOCUS_NONE
		_nezet_opt.add_item(tr("TC_NET_VIEW_ALL"), 0)
		for o in 2: _nezet_opt.add_item(_fmt("TC_NET_VIEW_SIDE", [_oldal_nev(o)]), o + 1)
		_nezet_opt.select(nezet_oldal + 1)
		_nezet_opt.disabled = kotott
		_nezet_opt.item_selected.connect(func(i: int) -> void: keres({"k": "nezet", "v": i - 1}))
		hs.add_child(_nezet_opt)
		hs.add_child(cs._gomb(tr("TC_NET_BACK_TO_MAP"), func() -> void:
			if kilepes.is_valid(): kilepes.call()
			if is_instance_valid(csata): csata._befejez()))
	_ui_frissit(1.0)

func _oldal_nev(o: int) -> String:
	if bab != null and o < bab.oldalak.size():
		var n := str(bab.oldalak[o]["nev"])
		if n != "": return n
	return str(nevek[o])

func _ui_frissit(delta: float) -> void:
	if csata == null or _lbl == null: return
	_ui_ido -= delta
	if _ui_ido > 0.0: return
	_ui_ido = 0.2
	var sorok: PackedStringArray = []
	var fazis := bab.fazis
	var kesz: Array = vez.get("kesz", [false, false])
	var harc: Array = vez.get("harcos", [false, false])
	if fazis == "telepites":
		var th := float(vez.get("telep_hatra", -1.0))
		if th < 0.0: sorok.append(tr("TC_NET_LOADING"))
		else: sorok.append(_fmt("TC_NET_DEPLOY_TIME", [_perc(th)]))
		for o in 2:
			if o != en and bool(harc[o]) and bool(kesz[o]): sorok.append(_fmt("TC_NET_OPP_READY", [_oldal_nev(o)]))
		# a „Kész” gomb felirata
		var bi: Variant = csata.get("btn_indit")
		if en >= 0 and bi != null and is_instance_valid(bi):
			var masik := 1 - en
			(bi as Button).text = tr("TC_NET_READY") if not bool(kesz[en]) else _fmt("TC_NET_READY_WAIT", [_oldal_nev(masik)])
	elif fazis == "csata":
		if szunet or bool(vez.get("szunet", false)):
			var ki := int(vez.get("szunet_ki", -1))
			sorok.append(_fmt("TC_NET_PAUSED_BY", [_oldal_nev(ki) if ki >= 0 else "?", _perc(float(vez.get("szunet_hatra", 0.0)))]))
		if en >= 0 and bool(harc[0]) and bool(harc[1]):
			var m: Array = vez.get("maradt", [0, 0])
			sorok.append(_fmt("TC_NET_PAUSES_LEFT", [int(m[en])]))
	# a sebességgombok: ember ember ellen csak 1× és 2×
	var lehet: Array = vez.get("sebessegek", [1.0, 2.0, 4.0])
	if en >= 0:
		for par in csata.btn_seb: (par[0] as Button).visible = float(par[1]) in lehet
	# a függő kérés
	var k: Dictionary = vez.get("keres", {})
	var masiktol := not k.is_empty() and en >= 0 and int(k["ki"]) != en
	_keres_panel.visible = masiktol
	if masiktol:
		var szoveg := _fmt("TC_NET_REQ_PAUSE", [_oldal_nev(int(k["ki"]))]) if str(k["tipus"]) == "szunet" \
			else _fmt("TC_NET_REQ_SPEED", [_oldal_nev(int(k["ki"])), _szam(float(k["v"]))])
		_keres_lbl.text = szoveg + "  (" + _perc(float(k.get("hatra", 0.0))) + ")"
		_keres_panel.reset_size()
		var vm: Vector2 = csata._kepernyo()
		_keres_panel.position = Vector2((vm.x - _keres_panel.size.x) * 0.5, csata.FELSO_M + 84.0)
	elif not k.is_empty() and en >= 0 and int(k["ki"]) == en:
		sorok.append(_fmt("TC_NET_WAIT_ANSWER", [_oldal_nev(1 - en)]))
	# rövid értesítések (a gép átvette, elutasították…)
	var most := Time.get_ticks_msec()
	_hir_sor = _hir_sor.filter(func(h: Array) -> bool: return int(h[1]) > most)
	for h in _hir_sor: sorok.append(str(h[0]))
	_lbl.text = "\n".join(sorok)
	_lbl.reset_size()
	_lbl.position.x = (csata._kepernyo().x - _lbl.size.x) * 0.5
	if _nezo_sor != null:
		# (jobb felül, a felső sáv alatt)
		_nezo_sor.reset_size()
		_nezo_sor.position = Vector2(csata._kepernyo().x - _nezo_sor.size.x - 8.0, csata.FELSO_M + 8.0)
	if _nezet_opt != null:
		_nezet_opt.disabled = kotott
		if _nezet_opt.selected != nezet_oldal + 1: _nezet_opt.select(nezet_oldal + 1)

static func _perc(mp: float) -> String:
	var s := int(ceil(maxf(mp, 0.0)))
	return "%d:%02d" % [s / 60, s % 60]

static func _szam(x: float) -> String:
	return str(int(x)) if is_equal_approx(x, roundf(x)) else str(x)

static func _fmt(kulcs: String, args: Array) -> String:
	var s := TranslationServer.translate(kulcs)
	for i in args.size():
		var a: Variant = args[i]
		s = s.replace("{%d}" % i, TranslationServer.translate(a) if a is String else str(a))
	return s
