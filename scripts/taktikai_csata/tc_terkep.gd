extends RefCounted

# TAKTIKAI CSATA – a csatatér: a terepháló (erdő, láp, folyó, gázló, szikla, sánc, ostromnál a fallal körülvett
# település), a magasság (dombok) és a festett háttérkép. A tartomány tájából generálódik, egy vetőmagból
# (ugyanaz a mag = ugyanaz a tér).
#
# A pálya felül–alul két felállítási sávval: a 0. oldal (a játékos) lent, az 1. oldal fent. A védő a
# saját sávja elé kap egy dombot (és ha van, sáncot), hogy a terep neki kedvezzen – mint az automatikus
# csatában a terep védőszorzója. Ostromnál a védő a falak mögött áll: a település a saját szélén van, a
# fal elején kapu és tornyok, oldalt egy kiskapu, középen a főtér.
#
# Útkeresés: ostromnál (falak, házak, kapuk) rácsos A* (AStarGrid2D) oldalanként: a védő a falon is jár,
# a támadó gyalogsága létrával átmászhat rajta (drágán), a lovasság, a szekér, az elefánt és a kos csak a
# betört kapun át juthat be. Nyílt csatatéren elég a folyó gázlóit megkeresni (atkeles).

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const O := preload("res://scripts/taktikai_csata/tc_ostrom.gd")

var gw: int = 0
var gh: int = 0
var cellak: PackedByteArray = PackedByteArray()
var magas: PackedFloat32Array = PackedFloat32Array()
var terep: String = ""
# folyó: y = folyo_y + folyo_amp · sin(x · folyo_f + folyo_fazis); a gázlók x-középpontjai
var folyo: bool = false
var folyo_y: float = 0.0
var folyo_amp: float = 0.0
var folyo_f: float = 0.0
var folyo_fazis: float = 0.0
var gazlok: Array = []
const FOLYO_FEL := 14.0     # a meder fél szélessége
const GAZLO_FEL := 42.0     # a gázló fél szélessége
# tengerpart: a pálya bal vagy jobb szélén víz; a szárazföld x-tartománya
var min_x: float = 0.0
var max_x: float = A.TER_W
var tenger_bal: bool = false
var part: bool = false
var sanc: bool = false
# ostrom
var ostrom: bool = false
var vedo_oldal: int = -1
var varos: Rect2 = Rect2()          # a fal külső széle
var belso: Rect2 = Rect2()          # a falon belüli terület (a falakkal együtt: a védők felállítási helye)
var foter: Vector2 = Vector2.ZERO
var elo_fal_y: float = 0.0          # az ellenség felé néző fal közepének y-ja
var kapuk: Array = []               # [{"p": közép, "ki": kifelé mutató irány, "cellak": PackedInt32Array, "hp": float}]
var tornyok: Array = []             # [{"p": Vector2, "ujra": float, "aktiv": bool}]
var hazak: Array = []               # [Rect2] a házak (a rajzhoz)
# a falba ütött rések: a faltörő kos a falszakaszt is ledöntheti. fal_hp: cella -> a még hátralévő ereje;
# fal_utes: cella -> az utolsó ütés ideje (a rajznak, a hangnak); resek: a ledőlt cellák (a rajzhoz: kőtörmelék);
# fal_valtozas: nő, ha rés nyílt (a falak rajza ekkor frissül)
var fal_hp: Dictionary = {}
var fal_utes: Dictionary = {}
var resek: Array = []
var fal_valtozas: int = 0
# a városostrom (lásd tc_ostrom.gd): a város stílusa, van-e fala, a kifelé (az ostromló felé) mutató irány, az épületek
# ([{"r": Rect2, "h": magasság, "f": fajta}] – a rajzhoz), a modern város megerősített romjai, a fellegvár udvara (INF:
# nincs) és területe, az ostromrámpa, a falszakaszai, a dokkolt ostromtornyok hídjai (cella -> a torony), a
# körülzárás sáncai, a csillagerőd előtti futóárkok (a rajzhoz); varos_opt: a beallit adja a város felépítéséhez
var stilus: String = "kozepkor"
var falak: bool = true
var kifele: Vector2 = Vector2(0, 1)
var epuletek: Array = []
var rom_erod: Array = []
var fellegvar: Vector2 = Vector2.INF
var fellegvar_rect: Rect2 = Rect2()
var rampa: Dictionary = {}
var rampa_fal: Dictionary = {}
var hidak: Dictionary = {}
## a fal lépcsői belülről (a védők ezeken jutnak fel a fal tetejére): lépcsőcella -> a falcella, amelyre visz
var lepcsok: Dictionary = {}
## a fal tövének cellái (kívül-belül), amelyekről nem vezet lépcső: a védők útkeresése ezeket kerüli (lásd _astar_epit)
var _fal_to: Dictionary = {}
var korulzar: bool = false
var parhuzamosok: Array = []
var varos_opt: Dictionary = {}
var _astar: Array = []              # 0: a védő, 1: a támadó gyalogsága (létrával), 2: a többi támadó
# a díszletek (a rajzhoz): fák [poz, méret, változat], sziklák [poz, méret, változat]
var fak: Array = []
var kovek: Array = []

func _init() -> void:
	gw = int(A.TER_W / A.CELLA)
	gh = int(A.TER_H / A.CELLA)
	cellak.resize(gw * gh)
	magas.resize(gw * gh)

## A csatatér előállítása. terep: "" (síkság), "hills", "mountains", "forest", "marsh", "desert"
## p_vedo: a védő oldala (0 lent, 1 fent; -1 = nyílt ütközet, egyik sem); p_ostrom: fallal védett település
func general(p_terep: String, p_folyo: bool, p_part: bool, p_sanc: bool, p_vedo: int, mag: int, p_ostrom: bool = false) -> void:
	terep = p_terep
	vedo_oldal = p_vedo
	ostrom = p_ostrom and p_vedo >= 0
	var rng := RandomNumberGenerator.new()
	rng.seed = mag
	cellak.fill(A.NYILT)
	magas.fill(0.0)
	kapuk = []
	tornyok = []
	hazak = []
	fal_hp = {}
	fal_utes = {}
	resek = []
	fal_valtozas = 0
	epuletek = []
	rom_erod = []
	fellegvar = Vector2.INF
	fellegvar_rect = Rect2()
	rampa = {}
	rampa_fal = {}
	hidak = {}
	lepcsok = {}
	_fal_to = {}
	korulzar = false
	parhuzamosok = []
	# ── tengerpart ──
	part = p_part
	min_x = 0.0
	max_x = A.TER_W
	if part:
		tenger_bal = rng.randf() < 0.5
		if tenger_bal: min_x = 110.0
		else: max_x = A.TER_W - 110.0
	# ── dombok ──
	var dombok := {"": 2, "hills": 6, "mountains": 8, "forest": 2, "marsh": 1, "desert": 5}
	var amp := {"": 0.55, "hills": 0.85, "mountains": 1.0, "forest": 0.6, "marsh": 0.4, "desert": 0.45}
	var nd: int = int(dombok.get(terep, 2))
	var na: float = float(amp.get(terep, 0.55))
	for i in nd:
		var c := Vector2(rng.randf_range(min_x + 100.0, max_x - 100.0), rng.randf_range(260.0, A.TER_H - 260.0))
		_domb(c, rng.randf_range(90.0, 170.0), na * rng.randf_range(0.6, 1.0))
	# a védő dombja: a felállítási sávja elején (a védők a gerincén állnak fel)
	if p_vedo >= 0:
		var y := 170.0 if p_vedo == 1 else A.TER_H - 170.0
		var x := rng.randf_range(A.TER_W * 0.35, A.TER_W * 0.65)
		_domb(Vector2(x, y), 190.0, maxf(na, 0.6) * 0.9)
	# ── foltok ──
	var erdo := {"": 3, "hills": 3, "mountains": 3, "forest": 9, "marsh": 3, "desert": 0}
	var lap := {"": 0, "hills": 0, "mountains": 0, "forest": 1, "marsh": 7, "desert": 0}
	var szikla := {"": 0, "hills": 2, "mountains": 6, "forest": 0, "marsh": 0, "desert": 3}
	for i in int(erdo.get(terep, 2)): _folt(rng, A.ERDO, rng.randf_range(50.0, 110.0 if terep == "forest" else 80.0))
	for i in int(lap.get(terep, 0)): _folt(rng, A.LAP, rng.randf_range(50.0, 100.0))
	for i in int(szikla.get(terep, 0)): _folt(rng, A.SZIKLA, rng.randf_range(30.0, 60.0))
	# ── folyó ──
	folyo = p_folyo
	gazlok = []
	if folyo:
		folyo_y = A.TER_H * 0.5 + rng.randf_range(-50.0, 50.0)
		folyo_amp = rng.randf_range(20.0, 45.0)
		folyo_f = rng.randf_range(0.004, 0.008)
		folyo_fazis = rng.randf_range(0.0, TAU)
		var ng := 2 if rng.randf() < 0.5 else 3
		for i in ng:
			var sav := (max_x - min_x) / float(ng)
			gazlok.append(min_x + sav * (float(i) + 0.5) + rng.randf_range(-sav * 0.2, sav * 0.2))
		for gy in gh:
			for gx in gw:
				var p := Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)
				var d := absf(p.y - folyo_y_at(p.x))
				if d < FOLYO_FEL + A.CELLA * 0.5:
					cellak[gy * gw + gx] = A.GAZLO if _gazlonal(p.x) else A.VIZ
					magas[gy * gw + gx] = 0.0
				elif d < 45.0 and rng.randf() < 0.25 and terep != "desert":
					cellak[gy * gw + gx] = A.LAP
	# ── a tenger ──
	if part:
		for gy in gh:
			for gx in gw:
				var x := (gx + 0.5) * A.CELLA
				if x < min_x or x > max_x:
					cellak[gy * gw + gx] = A.VIZ
					magas[gy * gw + gx] = 0.0
	# ── sánc a védő első vonalában ──
	sanc = p_sanc and p_vedo >= 0 and not ostrom
	if sanc:
		# a karósor a védők első vonalában: aki mögötte / rajta áll, védett (lásd TcSzim._kozelharc)
		var y := A.TELEPITES_MELYSEG - 45.0 if p_vedo == 1 else A.TER_H - A.TELEPITES_MELYSEG + 45.0
		var x := A.TER_W * 0.22
		while x < A.TER_W * 0.78:
			var hossz := rng.randf_range(120.0, 200.0)
			var x2 := minf(x + hossz, A.TER_W * 0.78)
			var xx := x
			while xx < x2:
				var c := cella_index(Vector2(xx, y))
				if c >= 0 and cellak[c] != A.VIZ: cellak[c] = A.SANC
				xx += A.CELLA
			x = x2 + rng.randf_range(50.0, 80.0)
	# a felállítási sávokban ne legyen láp és szikla (legyen hova állni)
	for gy in gh:
		for gx in gw:
			var y := (gy + 0.5) * A.CELLA
			if y < A.TELEPITES_MELYSEG or y > A.TER_H - A.TELEPITES_MELYSEG:
				var i := gy * gw + gx
				if cellak[i] == A.LAP or cellak[i] == A.SZIKLA: cellak[i] = A.NYILT
	# ── a település ──
	if ostrom: _varos(rng, p_vedo)
	_astar = []
	if ostrom:
		_lepcsok_szamol()
		_astar_epit()
	_diszletek(mag)

func _domb(c: Vector2, r: float, a: float) -> void:
	for gy in gh:
		for gx in gw:
			var p := Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)
			var d2 := p.distance_squared_to(c) / (r * r)
			if d2 > 4.0: continue
			var i := gy * gw + gx
			magas[i] = minf(1.0, magas[i] + a * exp(-d2 * 1.4))

func _folt(rng: RandomNumberGenerator, tipus: int, r: float) -> void:
	var c := Vector2(rng.randf_range(min_x + 40.0, max_x - 40.0), rng.randf_range(120.0, A.TER_H - 120.0))
	# néhány egymásba érő kör: szabálytalan folt
	var korok: Array = [[c, r]]
	for i in 3:
		korok.append([c + Vector2(rng.randf_range(-r, r), rng.randf_range(-r * 0.7, r * 0.7)), r * rng.randf_range(0.5, 0.85)])
	for gy in gh:
		for gx in gw:
			var p := Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)
			for k in korok:
				if p.distance_to(k[0]) < float(k[1]):
					var i := gy * gw + gx
					if cellak[i] == A.NYILT: cellak[i] = tipus
					break

func _gazlonal(x: float) -> bool:
	for g in gazlok:
		if absf(x - float(g)) < GAZLO_FEL: return true
	return false

func folyo_y_at(x: float) -> float:
	return folyo_y + folyo_amp * sin(x * folyo_f + folyo_fazis)

# ── A település (ostrom) ─────────────────────────────────────────
#
# 27 × 13 cellás fallal körülvett négyszög a védő szélén. Az ellenség felé néző fal közepén a főkapu (két
# toronnyal), a sarkain egy-egy torony, az egyik oldalfalon a kiskapu (torony nélkül: a gyenge pont). A fal
# mögött egy utcányi körút, az elülső fél nyitott (itt állnak fel a védők), a hátsó félben házak, középen a
# főtér, a kapuktól a főtérig kövezett utca.

func _cset(gx: int, gy: int, t: int) -> void:
	if gx < 0 or gy < 0 or gx >= gw or gy >= gh: return
	cellak[gy * gw + gx] = t

func _varos(rng: RandomNumberGenerator, v: int) -> void:
	# a város a közös felépítővel (tc_ostrom.gd): a falak, a kapuk, a tornyok, az utcák, a háztömbök, a tér, a fellegvár
	var opt := varos_opt.duplicate()
	opt["telep"] = A.TELEPITES_MELYSEG
	O.varos_general(self, rng, v, opt)
func _kapu(cl: Array, ki: Vector2) -> void:
	var idx := PackedInt32Array()
	var k := Vector2.ZERO
	for c in cl:
		var ci: Vector2i = c
		_cset(ci.x, ci.y, A.KAPU)
		idx.append(ci.y * gw + ci.x)
		k += Vector2((ci.x + 0.5) * A.CELLA, (ci.y + 0.5) * A.CELLA)
	kapuk.append({"p": k / float(cl.size()), "ki": ki, "cellak": idx, "hp": A.KAPU_HP})

## A kapu betört: a helye kövezett út lesz (mindenki átjár rajta)
func kapu_tor(i: int) -> void:
	var k: Dictionary = kapuk[i]
	k["hp"] = 0.0
	for c in k["cellak"]:
		cellak[int(c)] = A.TER
		for g in _astar:
			var ag: AStarGrid2D = g
			var pp := Vector2i(int(c) % gw, int(c) / gw)
			ag.set_point_solid(pp, false)
			ag.set_point_weight_scale(pp, 1.0)

func kapu_all(i: int) -> bool:
	return float(kapuk[i]["hp"]) > 0.0

## A p ponthoz (legfeljebb r távolságra) legközelebbi törhető falszakasz: a település körfalának egy egyenes
## darabja (nem sarok, nem kapu vagy torony melletti cella): {"c": a középső cella indexe, "p": a közepe, "ki":
## kifelé mutató irány, "cellak": a fal mentén a három cella} – vagy {}, ha nincs ilyen
func fal_szakasz(p: Vector2, r: float = 50.0) -> Dictionary:
	if not ostrom: return {}
	var c0 := Vector2i(int(p.x / A.CELLA), int(p.y / A.CELLA))
	var rc := int(ceil(r / A.CELLA))
	var legj: Dictionary = {}
	var ld := INF
	for dy in range(-rc, rc + 1):
		for dx in range(-rc, rc + 1):
			var q := c0 + Vector2i(dx, dy)
			if _cella_q(q) != A.FAL: continue
			var cp := Vector2((q.x + 0.5) * A.CELLA, (q.y + 0.5) * A.CELLA)
			if not varos.has_point(cp): continue
			var ki := Vector2i.ZERO
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var q2: Vector2i = q + d
				var c2 := Vector2((q2.x + 0.5) * A.CELLA, (q2.y + 0.5) * A.CELLA)
				var t2 := _cella_q(q2)
				if not varos.has_point(c2) and t2 != A.FAL and t2 != A.TORONY and t2 != A.KAPU and t2 != A.VIZ:
					ki = d
					break
			if ki == Vector2i.ZERO: continue
			var t := Vector2i(ki.y, ki.x)
			if _cella_q(q - t) != A.FAL or _cella_q(q + t) != A.FAL: continue
			var d := cp.distance_to(p)
			if d < ld:
				ld = d
				var idx := PackedInt32Array()
				for qq in [q - t, q, q + t]:
					var v: Vector2i = qq
					idx.append(v.y * gw + v.x)
				legj = {"c": q.y * gw + q.x, "p": cp, "ki": Vector2(ki), "cellak": idx}
	return legj

func _cella_q(q: Vector2i) -> int:
	if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh: return A.VIZ
	return int(cellak[q.y * gw + q.x])

## Áll-e még a falszakasz (a középső cellája fal)
func fal_all(c: int) -> bool:
	return c >= 0 and c < cellak.size() and int(cellak[c]) == A.FAL

## A falszakasz ledőlt: a cellái kőtörmelékes, járható helyek lesznek (mindenki átjár rajtuk)
func fal_tor(sz: Dictionary) -> void:
	for c in sz["cellak"]:
		var ci := int(c)
		if int(cellak[ci]) != A.FAL: continue
		# (a rés helyén kőtörmelék: járható, de fedezéket ad, lassít)
		cellak[ci] = A.ROM
		resek.append(ci)
		if _astar.size() > 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nj := ci + dy * gw + dx
					if _fal_to.has(nj) and nj >= 0 and nj < cellak.size():
						_fal_to.erase(nj)
						var ag0: AStarGrid2D = _astar[0]
						ag0.set_point_solid(Vector2i(nj % gw, nj / gw), int(cellak[nj]) in [A.VIZ, A.TORONY, A.HAZ, A.KAPU, A.FAL])
						ag0.set_point_weight_scale(Vector2i(nj % gw, nj / gw), 1.0)
		var pp := Vector2i(ci % gw, ci / gw)
		for g in _astar:
			var ag: AStarGrid2D = g
			ag.set_point_solid(pp, false)
			ag.set_point_weight_scale(pp, 1.3)
	fal_hp.erase(int(sz["c"]))
	fal_valtozas += 1

## A falcella átjárója (a dokkolt ostromtorony hídja) megnyílt / megszűnt: a mászó támadó útkeresése szerint
func atjaro_valt(ci: int) -> void:
	if _astar.size() < 2 or ci < 0 or ci >= cellak.size() or int(cellak[ci]) != A.FAL: return
	var ag: AStarGrid2D = _astar[1]
	ag.set_point_weight_scale(Vector2i(ci % gw, ci / gw), 1.0 if O.atjaro(self, ci) else 10.0)

## A pont a falon belül van-e (a fallal együtt)
func bent(p: Vector2, tures: float = 0.0) -> bool:
	return ostrom and varos.grow(tures).has_point(p)

# ── Útkeresés (ostrom) ───────────────────────────────────────────

func _astar_epit() -> void:
	for mod in 3:
		var ag := AStarGrid2D.new()
		ag.region = Rect2i(0, 0, gw, gh)
		ag.cell_size = Vector2(1, 1)
		ag.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		ag.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		ag.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		ag.update()
		for gy in gh:
			for gx in gw:
				var t := int(cellak[gy * gw + gx])
				var pp := Vector2i(gx, gy)
				match t:
					A.VIZ, A.TORONY, A.HAZ, A.KAPU: ag.set_point_solid(pp, true)
					A.FAL:
						if mod == 0: ag.set_point_weight_scale(pp, 2.0)
						elif mod == 1: ag.set_point_weight_scale(pp, 10.0)
						else: ag.set_point_solid(pp, true)
					A.ERDO: ag.set_point_weight_scale(pp, 1.3)
					A.LAP, A.SZIKLA, A.GAZLO: ag.set_point_weight_scale(pp, 1.8)
					A.ROM: ag.set_point_weight_scale(pp, 1.5)
					A.RAMPA: ag.set_point_weight_scale(pp, 1.2)
				if t == A.FAL and mod == 1 and O.atjaro(self, gy * gw + gx): ag.set_point_weight_scale(pp, 1.0)
				# a védők a lépcsőkön jutnak fel a falra: a fal tövében (a lépcsőn kívül) nem lépnek fel rá
				if mod == 0 and _fal_to.has(gy * gw + gx):
					if varos.has_point(Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)): ag.set_point_weight_scale(pp, 12.0)
					else: ag.set_point_solid(pp, true)
		_astar.append(ag)

func _szabad(p: Vector2, mod: int) -> bool:
	if p.x < min_x + 8.0 or p.x > max_x - 8.0 or p.y < 4.0 or p.y > A.TER_H - 4.0: return false
	var t := cella(p)
	match t:
		A.VIZ, A.TORONY, A.HAZ, A.KAPU: return false
		A.FAL: return mod <= 1
	return true

func _egyenes(a: Vector2, b: Vector2, mod: int) -> bool:
	var l := a.distance_to(b)
	var n := int(l / 8.0) + 1
	var elozo := cella_index(a)
	for i in range(1, n + 1):
		var q := a.lerp(b, float(i) / float(n))
		if not _szabad(q, mod): return false
		# (a védő a falra csak lépcsőn jut fel, és azon jön le: ilyenkor az útkereső vezeti)
		var ci := cella_index(q)
		if mod == 0 and ci != elozo and ci >= 0 and elozo >= 0 and (int(cellak[ci]) == A.FAL) != (int(cellak[elozo]) == A.FAL):
			if not lepcsok.has(ci) and not lepcsok.has(elozo): return false
		elozo = ci
	return true

## A fal lépcsői: a fal belső tövében, nagyjából 5 cellánként (a tornyok, a kapuk mellett mindig), és a fal tövének
## többi cellája (kívül, belül – a kapuk előtti, mögötti cellák kivételével), amelyet a védők útkeresése kerül
func _lepcsok_szamol() -> void:
	lepcsok = {}
	_fal_to = {}
	if not falak: return
	var kp := varos.get_center()
	var jeloltek: Array = []          # [cella, falcella, elsőbbség]
	for gy in gh:
		for gx in gw:
			var ci := gy * gw + gx
			if int(cellak[ci]) != A.FAL: continue
			for d in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
				var nx: int = gx + d.x
				var ny: int = gy + d.y
				if nx < 0 or ny < 0 or nx >= gw or ny >= gh: continue
				var nj := ny * gw + nx
				var tn := int(cellak[nj])
				if tn == A.FAL or tn == A.TORONY or tn == A.KAPU or tn == A.HAZ or tn == A.VIZ: continue
				_fal_to[nj] = ci
				# (a belső oldalon: a város közepe felé)
				var pn := Vector2((nx + 0.5) * A.CELLA, (ny + 0.5) * A.CELLA)
				var pf := Vector2((gx + 0.5) * A.CELLA, (gy + 0.5) * A.CELLA)
				if pn.distance_squared_to(kp) >= pf.distance_squared_to(kp) or not varos.has_point(pn): continue
				var elso := 0
				for e in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
					var ex: int = gx + e.x
					var ey: int = gy + e.y
					if ex >= 0 and ey >= 0 and ex < gw and ey < gh and int(cellak[ey * gw + ex]) in [A.TORONY, A.KAPU]: elso = 1
				jeloltek.append([nj, ci, elso])
	# (előbb a tornyok, kapuk mellettiek; a többi közül, ami 4 cellánál messzebb van a már kiválasztottaktól)
	jeloltek.sort_custom(func(x: Array, y: Array) -> bool: return int(x[2]) > int(y[2]))
	var kivalasztott: Array = []
	for j in jeloltek:
		var c := int(j[0])
		var x := c % gw
		var y := c / gw
		var kozel := false
		for k in kivalasztott:
			if maxi(absi(int(k) % gw - x), absi(int(k) / gw - y)) < (3 if int(j[2]) > 0 else 5):
				kozel = true
				break
		if kozel: continue
		kivalasztott.append(c)
		lepcsok[c] = int(j[1])
	# a kapuk előtt, mögött szabad az út (a kitörés, a visszavonulás)
	for k in kapuk:
		for c in (k as Dictionary)["cellak"]:
			var x := int(c) % gw
			var y := int(c) / gw
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < gw and ny < gh: _fal_to.erase(ny * gw + nx)
	for c in lepcsok: _fal_to.erase(c)

## Útvonal ostromnál (mod: 0 védő, 1 mászó támadó, 2 nem mászó támadó). Üres: egyenesen mehet (vagy nincs út).
func ut(honnan: Vector2, hova: Vector2, mod: int) -> Array:
	if _astar.is_empty(): return atkeles(honnan, hova)
	if _egyenes(honnan, hova, mod): return []
	var ag: AStarGrid2D = _astar[clampi(mod, 0, 2)]
	var a := Vector2i(clampi(int(honnan.x / A.CELLA), 0, gw - 1), clampi(int(honnan.y / A.CELLA), 0, gh - 1))
	var b := Vector2i(clampi(int(hova.x / A.CELLA), 0, gw - 1), clampi(int(hova.y / A.CELLA), 0, gh - 1))
	if ag.is_point_solid(a):
		a = _kozeli_szabad(ag, a)
	if ag.is_point_solid(b):
		b = _kozeli_szabad(ag, b)
	var ids: Array[Vector2i] = ag.get_id_path(a, b, true)
	if ids.size() < 2: return []
	var pts: Array = []
	for c in ids: pts.append(Vector2((c.x + 0.5) * A.CELLA, (c.y + 0.5) * A.CELLA))
	# ha az út tényleg a célig ér (nem csak a legközelebbi elérhető pontig), a vége maga a cél
	if ids[-1] == b and not ag.is_point_solid(Vector2i(clampi(int(hova.x / A.CELLA), 0, gw - 1), clampi(int(hova.y / A.CELLA), 0, gh - 1))):
		pts[-1] = hova
	# simítás: a lehető legtávolabbi, egyenesen elérhető pontra ugrik
	var r: Array = []
	var cur := honnan
	var i := 0
	while i < pts.size():
		var j := pts.size() - 1
		while j > i and not _egyenes(cur, pts[j], mod): j -= 1
		cur = pts[j]
		r.append(cur)
		i = j + 1
	return r

func _kozeli_szabad(ag: AStarGrid2D, c: Vector2i) -> Vector2i:
	for r in range(1, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := c + Vector2i(dx, dy)
				if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh: continue
				if not ag.is_point_solid(q): return q
	return c

# ── Lekérdezések ─────────────────────────────────────────────────

func cella_index(p: Vector2) -> int:
	var gx := int(p.x / A.CELLA)
	var gy := int(p.y / A.CELLA)
	if gx < 0 or gy < 0 or gx >= gw or gy >= gh: return -1
	return gy * gw + gx

func cella(p: Vector2) -> int:
	var i := cella_index(p)
	return A.VIZ if i < 0 else int(cellak[i])

## A magasság (0–1) kétvonalas interpolációval
func magassag(p: Vector2) -> float:
	var fx := clampf(p.x / A.CELLA - 0.5, 0.0, float(gw - 1))
	var fy := clampf(p.y / A.CELLA - 0.5, 0.0, float(gh - 1))
	var x0 := int(fx); var y0 := int(fy)
	var x1 := mini(x0 + 1, gw - 1); var y1 := mini(y0 + 1, gh - 1)
	var tx := fx - x0; var ty := fy - y0
	var a := lerpf(magas[y0 * gw + x0], magas[y0 * gw + x1], tx)
	var b := lerpf(magas[y1 * gw + x0], magas[y1 * gw + x1], tx)
	return lerpf(a, b, ty)

## Járható-e (oldaltól függetlenül: a falon a védők járnak, a kapu, a torony, a ház nem)
func jarhato(p: Vector2) -> bool:
	if p.x < min_x + 8.0 or p.x > max_x - 8.0 or p.y < 4.0 or p.y > A.TER_H - 4.0: return false
	var t := cella(p)
	return t != A.VIZ and t != A.KAPU and t != A.TORONY and t != A.HAZ

## A védő lépése a fal és a föld között: csak a fal belső oldalán (a városban) lehet (kívül a fal meredek)
func fal_lepes_ok(honnan: Vector2, hova: Vector2) -> bool:
	var a := cella(honnan) == A.FAL
	var b := cella(hova) == A.FAL
	if a == b: return true
	var fold := honnan if b else hova
	return varos.has_point(fold)

## Járható-e egy adott mozgásmódnak (0 védő, 1 mászó támadó – maszott: a létrán már fent van –, 2 nem mászó)
func jarhato_mod(p: Vector2, mod: int, maszott: bool) -> bool:
	if not jarhato(p): return false
	if cella(p) == A.FAL: return mod == 0 or (mod == 1 and maszott)
	return true

## A sebesség szorzója egy ponton (lovas: ló, szekér, elefánt)
func seb_szorzo(p: Vector2, p_lovas: bool) -> float:
	var s: Array = A.TEREP_SEB.get(cella(p), [1.0, 1.0])
	var v := float(s[1] if p_lovas else s[0])
	if v <= 0.0: v = 0.3
	# a meredek domboldal is lassít egy kicsit
	return v * (1.0 - 0.15 * magassag(p))

## Útvonal a folyón át: ha a két pont a folyó két partján van, és az egyenes nem gázlón kel át, a
## legközelebbi gázlón át vezet. Visszaad: a közbülső pontok (üres = egyenesen mehet).
func atkeles(honnan: Vector2, hova: Vector2) -> Array:
	if not folyo or gazlok.is_empty(): return []
	var a_eszak := honnan.y < folyo_y_at(honnan.x)
	var b_eszak := hova.y < folyo_y_at(hova.x)
	if a_eszak == b_eszak: return []
	# hol metszi az egyenes a medret (felezéssel)
	var t0 := 0.0; var t1 := 1.0
	for i in 14:
		var tm := (t0 + t1) * 0.5
		var pm := honnan.lerp(hova, tm)
		if (pm.y < folyo_y_at(pm.x)) == a_eszak: t0 = tm
		else: t1 = tm
	var metsz := honnan.lerp(hova, t0)
	if _gazlonal(metsz.x): return []
	var legjobb := float(gazlok[0])
	for g in gazlok:
		var gx := float(g)
		if absf(gx - metsz.x) + absf(gx - hova.x) * 0.3 < absf(legjobb - metsz.x) + absf(legjobb - hova.x) * 0.3: legjobb = gx
	var ir := 1.0 if a_eszak else -1.0
	var fy := folyo_y_at(legjobb)
	return [Vector2(legjobb, fy - ir * 45.0), Vector2(legjobb, fy + ir * 45.0)]

## Van-e fal (vagy álló kapu, torony) a két pont között – ostromnál a falon át nem lehet kardot váltani
func fal_kozott(a: Vector2, b: Vector2) -> bool:
	if not ostrom: return false
	var l := a.distance_to(b)
	var n := int(l / 7.0) + 1
	for i in range(1, n):
		var t := cella(a.lerp(b, float(i) / float(n)))
		if t == A.FAL or t == A.KAPU or t == A.TORONY or t == A.HAZ: return true
	return false

# ── Díszletek (fák, sziklák) ─────────────────────────────────────

func _diszletek(mag: int) -> void:
	fak = []
	kovek = []
	var rng := RandomNumberGenerator.new()
	rng.seed = mag * 31 + 7
	for gy in gh:
		for gx in gw:
			var t := int(cellak[gy * gw + gx])
			var szel_erdo := false
			if t == A.ERDO:
				# az erdő szélén ritkább
				var sz := 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(gx, gy) + d
					if q.x >= 0 and q.y >= 0 and q.x < gw and q.y < gh and cellak[q.y * gw + q.x] == A.ERDO: sz += 1
				szel_erdo = sz < 4
				var db := 2 if szel_erdo else 3
				for k in db:
					var p := Vector2((gx + rng.randf()) * A.CELLA, (gy + rng.randf()) * A.CELLA)
					var fenyo := terep == "mountains" or (terep == "forest" and rng.randf() < 0.3)
					fak.append([p, rng.randf_range(15.0, 24.0), 1 if fenyo else 0, rng.randf_range(0.8, 1.1)])
			elif t == A.NYILT and terep != "desert" and rng.randf() < (0.012 if terep != "marsh" else 0.004):
				var p := Vector2((gx + rng.randf()) * A.CELLA, (gy + rng.randf()) * A.CELLA)
				if not bent(p, 60.0): fak.append([p, rng.randf_range(12.0, 19.0), 2 if rng.randf() < 0.5 else 0, rng.randf_range(0.85, 1.1)])
			elif t == A.SZIKLA:
				for k in 2:
					var p := Vector2((gx + rng.randf()) * A.CELLA, (gy + rng.randf()) * A.CELLA)
					kovek.append([p, rng.randf_range(6.0, 13.0), rng.randi() % 2, rng.randf_range(0.85, 1.1)])
			elif t == A.NYILT and rng.randf() < (0.02 if terep in ["hills", "mountains", "desert"] else 0.005):
				var p := Vector2((gx + rng.randf()) * A.CELLA, (gy + rng.randf()) * A.CELLA)
				if not bent(p, 40.0): kovek.append([p, rng.randf_range(3.0, 6.0), rng.randi() % 2, rng.randf_range(0.85, 1.1)])

# ── A festett háttér ─────────────────────────────────────────────

const SZIN_FU := Color(0.42, 0.52, 0.26)
const SZIN_FU_SZARAZ := Color(0.52, 0.53, 0.28)
const SZIN_HOMOK := Color(0.80, 0.70, 0.48)
const SZIN_ERDO := Color(0.18, 0.27, 0.13)
const SZIN_LAP := Color(0.34, 0.41, 0.30)
const SZIN_VIZ := Color(0.20, 0.36, 0.48)
const SZIN_GAZLO := Color(0.46, 0.53, 0.50)
const SZIN_SZIKLA := Color(0.55, 0.52, 0.46)
const SZIN_SANC := Color(0.45, 0.33, 0.20)
const SZIN_FAL := Color(0.72, 0.67, 0.56)
const SZIN_KOVEZET := Color(0.62, 0.57, 0.48)
const SZIN_UT := Color(0.60, 0.52, 0.38)

static func _zaj(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 1023) / 1023.0

## A csatatér képe (1 képpont = `lepes` egység). Az alfa a vizet jelzi (a terepárnyaló hullámoztatja):
## 1 szárazföld, 0,5 víz, 0,75 gázló.
func kep(lepes: float = 2.0) -> Image:
	var w := int(A.TER_W / lepes)
	var h := int(A.TER_H / lepes)
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var alap := SZIN_HOMOK if terep == "desert" else SZIN_FU
	var alap2 := SZIN_HOMOK.darkened(0.08) if terep == "desert" else SZIN_FU_SZARAZ
	if terep == "mountains":
		alap = SZIN_FU.lerp(SZIN_SZIKLA, 0.3)
		alap2 = SZIN_SZIKLA.lerp(SZIN_FU_SZARAZ, 0.4)
	if terep == "marsh":
		alap = SZIN_FU.lerp(SZIN_LAP, 0.3)
		alap2 = SZIN_LAP.lightened(0.05)
	# nagy léptékű foltosság (dúsabb és szárazabb részek) – egyetlen zajkép
	var zaj := FastNoiseLite.new()
	zaj.seed = int(folyo_fazis * 1000.0) + int(min_x) + gw
	zaj.frequency = 0.012
	zaj.fractal_octaves = 3
	var zk := zaj.get_image(w, h, false, false, true)
	var zd := zk.get_data()
	var zlep := zd.size() / maxi(w * h, 1)
	# a magasság képpontonként egyszer (a lejtő a szomszédokból)
	var hm := PackedFloat32Array()
	hm.resize(w * h)
	for py in h:
		for px in w:
			hm[py * w + px] = magassag(Vector2((px + 0.5) * lepes, (py + 0.5) * lepes))
	# a folyó medre oszloponként
	var fy := PackedFloat32Array()
	fy.resize(w)
	var gz := PackedByteArray()
	gz.resize(w)
	for px in w:
		var x := (px + 0.5) * lepes
		fy[px] = folyo_y_at(x) if folyo else -9999.0
		gz[px] = 1 if folyo and _gazlonal(x) else 0
	var lejto_d := maxi(1, int(round(6.0 / lepes)))
	# földút (csak a képen): kanyargó, kitaposott nyomvonal a csatatéren át – a mag szerint, nem mindig
	var ur := RandomNumberGenerator.new()
	ur.seed = zaj.seed + 991
	var ut_van := not ostrom and terep != "marsh" and ur.randf() < 0.75
	var ut_x0 := ur.randf_range(min_x + 180.0, max_x - 180.0)
	var ut_amp := ur.randf_range(50.0, 150.0)
	var ut_f := ur.randf_range(0.003, 0.007)
	var ut_fazis := ur.randf() * TAU
	var ut_ferde := ur.randf_range(-0.25, 0.25)
	for py in h:
		for px in w:
			var p := Vector2((px + 0.5) * lepes, (py + 0.5) * lepes)
			# a foltok szélét a zaj elmossa (ne legyen szögletes a cellaháló)
			var z1 := _zaj(px >> 2, py >> 2)
			var z2 := _zaj((px >> 2) + 911, (py >> 2) + 37)
			var t := cella(p + Vector2((z1 - 0.5) * 16.0, (z2 - 0.5) * 16.0))
			if t == A.VIZ or t == A.GAZLO: t = A.NYILT
			var tp := cella(p)
			# a település cellái pontosan (nem mosódnak el)
			if tp == A.FAL or tp == A.KAPU or tp == A.TORONY or tp == A.HAZ or tp == A.TER: t = tp
			elif t == A.FAL or t == A.KAPU or t == A.TORONY or t == A.HAZ or t == A.TER: t = A.NYILT
			# a víz pontos alakja (a meder és a part nem a cellahálót követi)
			var zv := (_zaj(px >> 1, (py >> 1) + 501) - 0.5) * 5.0
			var part_szel := false
			var alfa := 255
			if part and (p.x < min_x + zv or p.x > max_x - zv): t = A.VIZ
			elif part and (p.x < min_x + 14.0 + zv or p.x > max_x - 14.0 - zv): part_szel = true
			if folyo:
				var d := absf(p.y - fy[px])
				if d < FOLYO_FEL + zv * 0.6: t = A.GAZLO if gz[px] == 1 else A.VIZ
				elif d < FOLYO_FEL + 5.0 + zv: part_szel = true
			var nz := float(zd[(py * w + px) * zlep]) / 255.0
			var c: Color = alap.lerp(alap2, clampf((nz - 0.35) * 1.6, 0.0, 1.0))
			match t:
				A.ERDO: c = SZIN_ERDO.lerp(SZIN_ERDO.lightened(0.15), nz)
				A.LAP:
					c = SZIN_LAP.lerp(SZIN_LAP.darkened(0.2), nz)
					# pocsolyák a lápban
					if _zaj(px >> 1, (py >> 1) + 77) > 0.86:
						c = SZIN_VIZ.lerp(SZIN_LAP, 0.35)
						alfa = 150
				A.VIZ:
					c = SZIN_VIZ.darkened(0.18 * (1.0 - clampf(absf(p.y - fy[px]) / FOLYO_FEL, 0.0, 1.0))) if folyo and absf(p.y - fy[px]) < 30.0 else SZIN_VIZ
					alfa = 128
				A.GAZLO:
					c = SZIN_GAZLO
					alfa = 190
				A.SZIKLA: c = SZIN_SZIKLA.lerp(alap, 0.25)
				A.SANC: c = SZIN_SANC
				A.TER: c = SZIN_KOVEZET
				A.HAZ: c = SZIN_UT
				A.FAL, A.TORONY: c = SZIN_FAL
				A.KAPU: c = SZIN_UT
			if part_szel: c = c.lerp(SZIN_HOMOK, 0.55)
			if ut_van and (t == A.NYILT or t == A.SZIKLA):
				var du := absf(p.x - (ut_x0 + ut_amp * sin(p.y * ut_f + ut_fazis) + (p.y - A.TER_H * 0.5) * ut_ferde))
				if du < 9.0 + zv:
					var ue := 1.0 - smoothstep(4.0, 9.0 + zv, du)
					c = c.lerp(SZIN_UT.lerp(alap, 0.25), ue * 0.62)
					# a két keréknyom
					if absf(du - 2.4) < 1.2: c = c.darkened(0.07 * ue)
			var m := hm[py * w + px]
			if alfa == 255:
				# domborzat: magasabban világosabb és sárgásabb, a lejtő fényt-árnyékot kap (a fény bal felülről)
				var dm := hm[maxi(py - lejto_d, 0) * w + maxi(px - lejto_d, 0)] - hm[mini(py + lejto_d, h - 1) * w + mini(px + lejto_d, w - 1)]
				c = c.lerp(Color(0.66, 0.62, 0.40), m * 0.18)
				c = c.lightened(clampf(dm * 5.0, 0.0, 0.15)).darkened(clampf(-dm * 5.0, 0.0, 0.2))
				# halvány szintvonal (a domb olvasható maradjon)
				var sz := fmod(m * 6.0, 1.0)
				if m > 0.08 and (sz < 0.03 or sz > 0.97) and t != A.FAL and t != A.TER: c = c.darkened(0.07)
			# kövezet: kőlapok hézaga
			if t == A.TER and ((px + (py / 3) * 2) % 4 == 0 or py % 3 == 0): c = c.darkened(0.12)
			var zz := _zaj(px, py) - 0.5
			c = c.lightened(zz * 0.08) if zz > 0.0 else c.darkened(-zz * 0.08)
			var i := (py * w + px) * 4
			data[i] = int(clampf(c.r, 0.0, 1.0) * 255.0)
			data[i + 1] = int(clampf(c.g, 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf(c.b, 0.0, 1.0) * 255.0)
			data[i + 3] = alfa
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	# sánc: hegyes karók sora
	for gy in gh:
		for gx in gw:
			if cellak[gy * gw + gx] != A.SANC: continue
			for k in 4:
				var tp := Vector2((gx + 0.125 + k * 0.25) * A.CELLA, (gy + 0.5) * A.CELLA) / lepes
				_kor(img, tp, 1.6 * 2.0 / lepes, Color(0.25, 0.16, 0.08), Color(0.62, 0.48, 0.30))
	if ostrom: O.varos_kep(self, img, lepes)
	return img

# a falak (pártázattal, árnyékkal) és a házak (nyeregtető) a képre
func _varos_kep(img: Image, lepes: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	# a fal árnyéka kifelé-lefelé (jobbra-le), aztán maga a fal
	for gy in gh:
		for gx in gw:
			var t := int(cellak[gy * gw + gx])
			if t != A.FAL and t != A.TORONY and t != A.KAPU: continue
			var r := Rect2(gx * A.CELLA / lepes, gy * A.CELLA / lepes, A.CELLA / lepes, A.CELLA / lepes)
			_teglalap(img, Rect2(r.position + Vector2(3.0, 4.0) / lepes * 2.0, r.size), Color(0, 0, 0), 0.35)
	for gy in gh:
		for gx in gw:
			var t := int(cellak[gy * gw + gx])
			if t != A.FAL: continue
			var r := Rect2(gx * A.CELLA / lepes, gy * A.CELLA / lepes, A.CELLA / lepes, A.CELLA / lepes)
			_teglalap(img, r, SZIN_FAL, 1.0)
			# a kövek: sorok és hézagok
			for py in range(int(r.position.y), int(r.end.y)):
				for px in range(int(r.position.x), int(r.end.x)):
					if px < 0 or py < 0 or px >= w or py >= h: continue
					var zz := _zaj(px * 3, py * 5)
					var c := SZIN_FAL.darkened(0.1 * zz)
					if (py % 3 == 0) or ((px + (py / 3) * 2) % 5 == 0): c = c.darkened(0.16)
					img.set_pixel(px, py, c)
			# a pártázat: a szomszéd nem-fal oldalán sötét perem és fogak
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(gx, gy) + d
				if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh: continue
				var tq := int(cellak[q.y * gw + q.x])
				if tq == A.FAL or tq == A.TORONY or tq == A.KAPU: continue
				var kint := not varos.grow(-A.CELLA * 0.5).has_point(Vector2((q.x + 0.5) * A.CELLA, (q.y + 0.5) * A.CELLA))
				var vas := maxf(1.0, 3.0 / lepes)
				var perem := Rect2()
				if d.x == 1: perem = Rect2(r.end.x - vas, r.position.y, vas, r.size.y)
				elif d.x == -1: perem = Rect2(r.position.x, r.position.y, vas, r.size.y)
				elif d.y == 1: perem = Rect2(r.position.x, r.end.y - vas, r.size.x, vas)
				else: perem = Rect2(r.position.x, r.position.y, r.size.x, vas)
				_teglalap(img, perem, SZIN_FAL.darkened(0.45 if kint else 0.3), 1.0)
				if kint:
					# fogak (merlon): világos kockák a külső peremen
					var n := 4
					for k in n:
						if k % 2 == 1: continue
						var f := float(k) / float(n)
						var fr := Rect2()
						if d.x != 0: fr = Rect2(perem.position.x - (vas if d.x == 1 else -vas), r.position.y + r.size.y * f, vas, r.size.y / float(n))
						else: fr = Rect2(r.position.x + r.size.x * f, perem.position.y - (vas if d.y == 1 else -vas), r.size.x / float(n), vas)
						_teglalap(img, fr, SZIN_FAL.lightened(0.18), 1.0)
	# házak: árnyék, nyeregtető (a gerinc a hosszabbik irányban), fal-perem
	var sivatag := terep == "desert"
	var rng := RandomNumberGenerator.new()
	rng.seed = int(varos.position.x) * 13 + 5
	for hr in hazak:
		var hz: Rect2 = hr
		var r := Rect2(hz.position / lepes, hz.size / lepes)
		# a telken 1–3 ház
		var db := 1 if r.size.y < r.size.x * 1.4 else 2
		for k in db:
			var rr := Rect2(r.position + Vector2(0, r.size.y * float(k) / float(db)), Vector2(r.size.x, r.size.y / float(db) - 1.0))
			rr = rr.grow(-0.5)
			_teglalap(img, Rect2(rr.position + Vector2(2.0, 2.5), rr.size), Color(0, 0, 0), 0.4)
			var teto := Color(0.66, 0.33, 0.22).lerp(Color(0.55, 0.30, 0.22), rng.randf()) if not sivatag else Color(0.80, 0.72, 0.56).darkened(rng.randf() * 0.1)
			if not sivatag and rng.randf() < 0.3: teto = Color(0.62, 0.52, 0.30)     # nádtető
			if sivatag:
				# lapos tető, peremmel
				_teglalap(img, rr, teto.darkened(0.15), 1.0)
				_teglalap(img, rr.grow(-1.0), teto, 1.0)
			else:
				var fekvo := rr.size.x > rr.size.y
				if fekvo:
					_teglalap(img, Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.5)), teto.lightened(0.12), 1.0)
					_teglalap(img, Rect2(rr.position + Vector2(0, rr.size.y * 0.5), Vector2(rr.size.x, rr.size.y * 0.5)), teto.darkened(0.12), 1.0)
				else:
					_teglalap(img, Rect2(rr.position, Vector2(rr.size.x * 0.5, rr.size.y)), teto.lightened(0.12), 1.0)
					_teglalap(img, Rect2(rr.position + Vector2(rr.size.x * 0.5, 0), Vector2(rr.size.x * 0.5, rr.size.y)), teto.darkened(0.12), 1.0)
				# cserépsorok
				for py in range(int(rr.position.y), int(rr.end.y)):
					if py % 2 == 0: continue
					for px in range(int(rr.position.x), int(rr.end.x)):
						if px >= 0 and py >= 0 and px < w and py < h:
							img.set_pixel(px, py, img.get_pixel(px, py).darkened(0.07))

static func _teglalap(img: Image, r: Rect2, c: Color, alfa: float) -> void:
	var w := img.get_width(); var h := img.get_height()
	var x0 := maxi(0, int(r.position.x)); var y0 := maxi(0, int(r.position.y))
	var x1 := mini(w, int(ceil(r.end.x))); var y1 := mini(h, int(ceil(r.end.y)))
	for y in range(y0, y1):
		for x in range(x0, x1):
			if alfa >= 1.0: img.set_pixel(x, y, Color(c.r, c.g, c.b, img.get_pixel(x, y).a))
			else:
				var o := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(lerpf(o.r, c.r, alfa), lerpf(o.g, c.g, alfa), lerpf(o.b, c.b, alfa), o.a))

static func _kor(img: Image, c: Vector2, r: float, sotet: Color, vilagos: Color) -> void:
	var w := img.get_width(); var h := img.get_height()
	var ri := int(ceil(r))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var d := Vector2(dx, dy).length()
			if d > r: continue
			var x := int(c.x) + dx; var y := int(c.y) + dy
			if x < 0 or y < 0 or x >= w or y >= h: continue
			# a bal felső része világosabb (a fény felülről jön)
			var f := clampf(0.5 - (float(dx) + float(dy)) / (2.0 * r + 0.01), 0.0, 1.0)
			var s := sotet.lerp(vilagos, f * 0.8)
			img.set_pixel(x, y, Color(s.r, s.g, s.b, 1.0))
