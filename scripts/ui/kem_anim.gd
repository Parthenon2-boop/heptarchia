extends Control

# A KÉMABLAK ANIMÁCIÓJA – kóddal rajzolt, festett hatású éjszakai jelenet (nincs hozzá képfájl):
# holdfényes ég pislákoló csillagokkal, a távolban egy tábor tábortüzei, előtérben a burh cölöpfala
# a kapu fáklyájával, a falon fel-alá járó őr fáklyával, a földön kúszó köd, és egy csuklyás kém,
# aki a bokrok árnyékából a fal tövéhez oson.
#
# Állapotok (allapot): "var" – a kém lapul, figyel; "uton" – elindul a fal felé (a küldetés folyamatban);
# "siker" – visszasurran a sötétbe; "kudarc" – dolgavégezetlenül hátrál; "lebukott" – az őr fáklyája
# rávetül, vörös villanás.
# A stilus a kor szerinti díszlet: "burh" (angolszász cölöpfal és sátortábor).

const EG_FENT := Color(0.04, 0.05, 0.12)
const EG_LENT := Color(0.16, 0.14, 0.26)
const HOLD := Color(0.96, 0.93, 0.80)
const DOMB := Color(0.07, 0.08, 0.11)
const FOLD := Color(0.03, 0.03, 0.04)
const FOLD_FENY := Color(0.13, 0.14, 0.18)
const HOLDFENY := Color(0.55, 0.62, 0.85)
const FA := Color(0.17, 0.11, 0.07)
const FA_VILAGOS := Color(0.30, 0.20, 0.12)
const TUZ := Color(1.0, 0.62, 0.22)
const TUZ_MAG := Color(1.0, 0.90, 0.55)
const KOPENY := Color(0.07, 0.07, 0.08)
const KOD := Color(0.62, 0.66, 0.78)
const VOROS := Color(0.95, 0.20, 0.12)

var stilus := "burh"
var allapot := "var"
var _t := 0.0                 # az eltelt idő
var _at := 0.0                # az állapotváltás óta eltelt idő
var _kem_x := 0.34            # a kém helye (a szélesség arányában)
var _kem_honnan := 0.34
var _csillagok: Array = []    # [pozíció (arány), fényesség, fázis]
var _kodok: Array = []        # [y arány, sebesség, szélesség, fázis]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 230)
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true    # a sötétbe surranó kém ne lógjon ki a képből
	var rng := RandomNumberGenerator.new()
	rng.seed = 1066
	for i in 46:
		_csillagok.append([Vector2(rng.randf(), rng.randf() * 0.5), rng.randf_range(0.35, 1.0), rng.randf() * TAU])
	for i in 5:
		_kodok.append([rng.randf_range(0.72, 0.95), rng.randf_range(0.012, 0.03), rng.randf_range(0.25, 0.5), rng.randf()])

func allit(uj: String) -> void:
	if uj == allapot: return
	_kem_honnan = _kem_x
	allapot = uj
	_at = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_t += delta
	_at += delta
	match allapot:
		"var":
			_kem_x = lerpf(_kem_x, 0.34, minf(1.0, delta * 2.0))
		"uton":
			_kem_x = lerpf(_kem_honnan, 0.50, _simit(_at / 1.8))
		"siker":
			_kem_x = lerpf(_kem_honnan, -0.08, _simit(_at / 1.4))
		"kudarc":
			_kem_x = lerpf(_kem_honnan, 0.33, _simit(_at / 1.6))
		"lebukott":
			_kem_x = lerpf(_kem_honnan, 0.44, _simit(_at / 0.8))
	queue_redraw()

static func _simit(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## pislákolás: két szinusz keveréke (nem ismétlődik feltűnően)
func _pislak(fazis: float, seb: float = 1.0) -> float:
	return 0.75 + 0.15 * sin(_t * 7.3 * seb + fazis) + 0.10 * sin(_t * 12.9 * seb + fazis * 1.7)

func _fenykor(c: Vector2, r: float, szin: Color, ero: float) -> void:
	for i in 6:
		var k := 1.0 - float(i) / 6.0
		draw_circle(c, r * k, Color(szin, ero * 0.12 * (1.0 - k * 0.4)))

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0: return
	# ── az ég: színátmenet ──
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([EG_FENT, EG_FENT, EG_LENT, EG_LENT]))
	for s in _csillagok:
		var a: float = float(s[1]) * (0.55 + 0.45 * sin(_t * 1.6 + float(s[2])))
		draw_circle(Vector2(s[0].x * w, s[0].y * h), 1.1, Color(1, 1, 0.92, a))
	# ── a hold, fényudvarral ──
	var hold := Vector2(w * 0.80, h * 0.20)
	_fenykor(hold, 46.0, HOLD, 0.9)
	draw_circle(hold, 15.0, HOLD)
	draw_circle(hold + Vector2(5, -3), 13.0, Color(EG_FENT.lerp(HOLD, 0.25), 0.35))
	# ── a távoli dombok és a tábor ──
	var domb := PackedVector2Array([Vector2(0, h * 0.62)])
	for i in 13:
		var x := w * float(i) / 12.0
		domb.append(Vector2(x, h * (0.56 + 0.05 * sin(float(i) * 1.3) + 0.03 * sin(float(i) * 2.9))))
	domb.append(Vector2(w, h)); domb.append(Vector2(0, h))
	draw_colored_polygon(domb, DOMB)
	_tabor(w, h)
	# ── a köd a dombok előtt ──
	for k in _kodok:
		var x := fmod(float(k[3]) + _t * float(k[1]), 1.4) - 0.2
		var c := Vector2(x * w, float(k[0]) * h)
		draw_set_transform(c, 0.0, Vector2(float(k[2]) * w / 40.0, 0.35))
		draw_circle(Vector2.ZERO, 40.0, Color(KOD, 0.07))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ── a fal ──
	_fal(w, h)
	# ── az előtér: föld, bokrok ──
	# a holdfény a mező peremén világosabb, lefelé sötétedik
	var fold := PackedVector2Array([Vector2(0, h * 0.86), Vector2(w * 0.3, h * 0.84), Vector2(w * 0.6, h * 0.87),
		Vector2(w, h * 0.85), Vector2(w, h), Vector2(0, h)])
	draw_polygon(fold, PackedColorArray([FOLD_FENY, FOLD_FENY, FOLD_FENY, FOLD_FENY, FOLD, FOLD]))
	draw_polyline(PackedVector2Array([fold[0], fold[1], fold[2], fold[3]]), Color(0.42, 0.46, 0.62, 0.35), 1.2)
	_bokor(Vector2(w * 0.20, h * 0.86), 1.0)
	_bokor(Vector2(w * 0.29, h * 0.87), 0.7)
	# ── a kém ──
	_kem(Vector2(_kem_x * w, h * 0.86), h)
	# ── lebukás: vörös villanás ──
	if allapot == "lebukott":
		var a := clampf(1.0 - _at / 1.2, 0.0, 1.0) * 0.35 + 0.08 * (0.5 + 0.5 * sin(_t * 9.0))
		draw_rect(Rect2(0, 0, w, h), Color(VOROS, a))
	# ── keret: sötét szélek (vignetta) ──
	for i in 8:
		var a := 0.10 * (1.0 - float(i) / 8.0)
		draw_rect(Rect2(i * 3.0, i * 3.0, w - i * 6.0, h - i * 6.0), Color(0, 0, 0, a), false, 6.0)
	draw_rect(Rect2(0, 0, w, h), Color(0.55, 0.42, 0.22), false, 2.0)

func _tabor(w: float, h: float) -> void:
	# a távoli tábor sátrai és tüzei a dombhajlatban
	for i in 6:
		var x := w * (0.08 + 0.07 * float(i))
		var y := h * (0.60 + 0.012 * sin(float(i) * 2.1))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, y), Vector2(x + 7, y), Vector2(x, y - 9)]), Color(0.13, 0.11, 0.12))
	for i in 3:
		var p := Vector2(w * (0.12 + 0.13 * float(i)), h * 0.615)
		var f := _pislak(float(i) * 2.3, 0.8)
		_fenykor(p, 16.0 * f, TUZ, f)
		draw_circle(p, 2.2 * f, TUZ_MAG)

func _fal(w: float, h: float) -> void:
	var x0 := w * 0.55
	var alj := h * 0.86
	var teto := h * 0.50
	# cölöpfal: hegyes karók
	var x := x0
	while x < w + 10.0:
		var cw := 9.0
		var csucs := teto - 6.0 + 3.0 * sin(x * 0.7)
		draw_colored_polygon(PackedVector2Array([Vector2(x, alj), Vector2(x + cw, alj), Vector2(x + cw, csucs + 6),
			Vector2(x + cw * 0.5, csucs), Vector2(x, csucs + 6)]), FA if int(x / cw) % 2 == 0 else FA.darkened(0.15))
		# a karók közti rés és a holdfényes perem
		draw_line(Vector2(x, csucs + 6), Vector2(x, alj), Color(0.02, 0.01, 0.01), 1.2)
		draw_line(Vector2(x + cw * 0.5, csucs), Vector2(x + cw, csucs + 6), Color(HOLDFENY, 0.35), 1.0)
		x += cw
	# a járószint (a gyilokjáró) és a kapu
	draw_rect(Rect2(x0, teto + 8, w - x0, 3), FA_VILAGOS.darkened(0.3))
	var kapu := Rect2(w * 0.70, alj - h * 0.20, w * 0.07, h * 0.20)
	draw_rect(kapu, Color(0.03, 0.02, 0.02))
	draw_rect(Rect2(kapu.position.x - 4, kapu.position.y - 5, kapu.size.x + 8, 5), FA_VILAGOS.darkened(0.2))
	# a kapu fáklyája
	var fk := Vector2(kapu.position.x - 8, kapu.position.y + 4)
	var f := _pislak(0.6)
	_fenykor(fk, 70.0 * f, TUZ, 0.9 * f)
	draw_line(fk, fk + Vector2(0, 10), FA_VILAGOS, 2.0)
	draw_circle(fk + Vector2(0, -2), 3.4 * f, TUZ)
	draw_circle(fk + Vector2(0, -1), 1.8, TUZ_MAG)
	# az őr a gyilokjárón, fáklyával: fel-alá jár, lebukáskor megáll és a kém felé fordul
	var gx: float
	var fordul := 1.0
	if allapot == "lebukott":
		gx = w * 0.60
		fordul = -1.0
	else:
		var s := sin(_t * 0.45)
		gx = w * (0.77 + 0.17 * s)
		fordul = 1.0 if cos(_t * 0.45) > 0.0 else -1.0
	var gl := Vector2(gx, teto + 8)
	var gf := _pislak(2.0, 1.2)
	var fenyero := 1.6 if allapot == "lebukott" else 1.0
	_fenykor(gl + Vector2(8 * fordul, -22), 52.0 * gf * fenyero, TUZ, 0.8 * gf)
	draw_colored_polygon(PackedVector2Array([gl + Vector2(-4, 0), gl + Vector2(4, 0), gl + Vector2(3, -14), gl + Vector2(-3, -14)]), KOPENY)
	draw_circle(gl + Vector2(0, -17), 3.4, KOPENY)
	draw_line(gl + Vector2(-5 * fordul, 2), gl + Vector2(-5 * fordul, -28), Color(0.25, 0.22, 0.2), 1.4)   # lándzsa
	draw_circle(gl + Vector2(8 * fordul, -22), 2.6 * gf, TUZ)
	if allapot == "lebukott":
		# a fénycsóva a kémre vetül, és felkiáltójel az őr fölött
		var kem := Vector2(_kem_x * w, h * 0.80)
		draw_colored_polygon(PackedVector2Array([gl + Vector2(8 * fordul, -22), kem + Vector2(-22, 10), kem + Vector2(22, 10)]),
			Color(TUZ, 0.13))
		var jel := gl + Vector2(0, -38)
		draw_circle(jel, 7.0, Color(0.1, 0.05, 0.03))
		draw_circle(jel, 5.6, VOROS)
		draw_line(jel + Vector2(0, -3.5), jel + Vector2(0, 1.0), Color(1, 0.95, 0.85), 1.8)
		draw_circle(jel + Vector2(0, 3.0), 1.0, Color(1, 0.95, 0.85))

func _bokor(p: Vector2, s: float) -> void:
	for i in 5:
		var o := Vector2((float(i) - 2.0) * 9.0 * s, -abs(float(i) - 2.0) * -3.0 * s - 10.0 * s)
		draw_circle(p + o, 11.0 * s, Color(0.04, 0.06, 0.05))

## A csuklyás kém: köpeny, csuklya, lépő lábak (álló helyzetben lapul, lélegzik)
func _kem(alj: Vector2, h: float) -> void:
	var megy := allapot in ["uton", "siker", "kudarc", "lebukott"] and _at < 2.0
	var irany := -1.0 if allapot in ["siker", "kudarc"] else 1.0
	var lapul := 0.0 if megy else 0.25 + 0.03 * sin(_t * 1.8)
	var magas := h * 0.27 * (1.0 - lapul)
	var lepes := sin(_t * 11.0) if megy else 0.0
	var a := 1.0
	if allapot == "uton": a = 1.0 - 0.55 * _simit((_at - 1.4) / 0.8)    # beolvad a fal árnyékába
	var kc := Color(KOPENY, a)
	if allapot == "lebukott": _fenykor(alj + Vector2(0, -magas * 0.5), 34.0, VOROS, 0.6)
	# lábak
	draw_line(alj + Vector2(-2, -magas * 0.3), alj + Vector2(-2 + 7 * lepes * irany, 0), kc, 3.6)
	draw_line(alj + Vector2(2, -magas * 0.3), alj + Vector2(2 - 7 * lepes * irany, 0), kc, 3.6)
	# a köpeny: előre dőlő alak
	var d := 6.0 * irany * (1.0 if megy else 0.4)
	var test := PackedVector2Array([alj + Vector2(-11, -magas * 0.25), alj + Vector2(11, -magas * 0.25),
		alj + Vector2(5 + d, -magas * 0.85), alj + Vector2(-5 + d, -magas * 0.85)])
	draw_colored_polygon(test, kc)
	# holdfény a köpeny hátán (a hold jobbra fent van)
	draw_line(test[1], test[2], Color(HOLDFENY, 0.55 * a), 1.4)
	# a köpeny lobogó szegélye
	var lob := 3.0 * sin(_t * 5.0)
	draw_colored_polygon(PackedVector2Array([alj + Vector2(-9, -magas * 0.25), alj + Vector2(-14 * irany - lob, -magas * 0.2),
		alj + Vector2(-5 + d, -magas * 0.7)]), kc)
	# a csuklya hegyes vége
	var fej := alj + Vector2(d * 1.3, -magas * 0.95)
	draw_circle(fej, magas * 0.13, kc)
	draw_colored_polygon(PackedVector2Array([fej + Vector2(-magas * 0.12, -2), fej + Vector2(magas * 0.05, -magas * 0.1),
		fej + Vector2(-magas * 0.22 * irany, -magas * 0.02)]), kc)
	# a holdfény a csuklya peremén
	draw_arc(fej, magas * 0.13, -PI * 0.9, -PI * 0.35, 8, Color(0.55, 0.6, 0.8, 0.45 * a), 1.2)
