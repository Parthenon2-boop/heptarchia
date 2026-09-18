extends Node2D

# HEPTARCHIA – tengeri díszek: finom hullámtaréjok, szélrózsa iránytűvonalakkal, egy viking hosszúhajó
# és egy lemerülő bálna farka. Visszafogott, a kékeszöld tengerhez illő színekkel.
# A térkép-világ gyereke (a térképpel együtt nagyul); a sea_decor shader levágja a szárazföldre eső részt.

const FONT := preload("res://assets/ui/font_title.tres")
const INK := Color(0.13, 0.20, 0.26, 0.9)          # sötét, tengerkék tus
const INK_SOFT := Color(0.13, 0.20, 0.26, 0.45)
const FOAM := Color(0.88, 0.93, 0.91, 0.75)        # világos hullámtaréj
const FOAM_FAINT := Color(0.88, 0.93, 0.91, 0.22)
const CREAM := Color(0.93, 0.91, 0.84)
const GOLD := Color(0.86, 0.70, 0.38)
const WOOD := Color(0.30, 0.21, 0.15)
const WOOD_LIGHT := Color(0.50, 0.36, 0.23)
const RED := Color(0.62, 0.19, 0.14)

const COMPASS := Vector2(150, 560)
const COMPASS_R := 40.0
const WAVES := [Vector2(700, 118), Vector2(862, 330), Vector2(905, 205), Vector2(78, 178), Vector2(250, 118),
	Vector2(474, 566), Vector2(742, 360), Vector2(300, 610), Vector2(60, 400), Vector2(935, 520), Vector2(420, 250),
	Vector2(230, 470), Vector2(760, 140)]

const WHALE_BODY := Color(0.21, 0.29, 0.35)
const WHALE_BELLY := Color(0.62, 0.68, 0.68)
const SHARK_BODY := Color(0.36, 0.42, 0.46)

# Egy kiegészítő térképének további díszei: {"waves": [Vector2], "whales": [Vector2], "whale_tails": [Vector2],
# "sharks": [Vector2], "dolphins": [Vector2] (hullámként rajzolódnak), "longships": [Vector2]}
var extra: Dictionary = {}

func _draw() -> void:
	_draw_compass(COMPASS, COMPASS_R)
	for w in WAVES + extra.get("waves", []) + extra.get("dolphins", []):
		_crests(w, 1.0)
	_whale(Vector2(835, 262), 1.0, false)
	_whale_tail(Vector2(95, 290), 0.9)
	_shark(Vector2(270, 525), 1.0, false)
	_shark(Vector2(735, 300), 0.9, true)
	_longship(Vector2(625, 175), 1.0)
	for i in extra.get("whales", []).size():
		_whale(extra["whales"][i], 1.0, i % 2 == 1)
	for p in extra.get("whale_tails", []):
		_whale_tail(p, 0.9)
	for i in extra.get("sharks", []).size():
		_shark(extra["sharks"][i], 1.0, i % 2 == 1)
	for p in extra.get("longships", []):
		_longship(p, 1.0)

func _pts(pos: Vector2, s: float, flip: bool, local: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in local: out.append(pos + Vector2(p.x * (-1.0 if flip else 1.0), p.y) * s)
	return out

func _curve(a: Vector2, b: Vector2, c: Vector2, n: int = 8) -> Array:
	var out: Array = []
	for i in n + 1: out.append(_bezier(a, b, c, float(i) / n))
	return out

func _closed(poly: PackedVector2Array, col: Color, width: float) -> void:
	var o := poly.duplicate()
	o.append(poly[0])
	draw_polyline(o, col, width, true)

# ── Bálna: a felszínen úszó, levegőt fújó bálna (a hasa a víz alatt) ──

func _whale(pos: Vector2, s: float, flip: bool) -> void:
	# a test: kerek fej balra, ívelt hát, elvékonyodó farokszár, vízszintes farokúszó
	var body: Array = []
	body += _curve(Vector2(-40, 2), Vector2(-40, -12), Vector2(-24, -13))       # homlok
	body += _curve(Vector2(-24, -13), Vector2(2, -15), Vector2(22, -7))         # hát
	body += _curve(Vector2(22, -7), Vector2(32, -3), Vector2(38, -3))           # farokszár
	body += [Vector2(44, -9), Vector2(50, -10), Vector2(46, -3), Vector2(52, 3), Vector2(46, 2), Vector2(40, 1)]  # farokúszó
	body += _curve(Vector2(40, 1), Vector2(26, 5), Vector2(8, 8))               # has hátul
	body += _curve(Vector2(8, 8), Vector2(-20, 11), Vector2(-40, 2))            # has és áll
	var poly := _pts(pos, s, flip, body)
	draw_colored_polygon(poly, WHALE_BODY)
	# világos, barázdált torok és has
	var belly := _pts(pos, s, flip, _curve(Vector2(-38, 3), Vector2(-20, 11), Vector2(6, 7)) \
		+ _curve(Vector2(6, 7), Vector2(-14, 4), Vector2(-38, 3)))
	draw_colored_polygon(belly, WHALE_BELLY)
	for k in 4:
		var y := 5.0 + k * 1.3
		draw_polyline(_pts(pos, s, flip, [Vector2(-34, y - 1.5), Vector2(-20, y + 1.0), Vector2(-6 - k * 2, y)]),
			Color(WHALE_BODY, 0.55), 0.8, true)
	# mellúszó, szem, szájvonal
	draw_colored_polygon(_pts(pos, s, flip, [Vector2(-18, 6), Vector2(-9, 14), Vector2(-5, 13), Vector2(-12, 5)]), WHALE_BODY)
	draw_circle(_pts(pos, s, flip, [Vector2(-29, -1)])[0], 1.1 * s, CREAM)
	draw_polyline(_pts(pos, s, flip, [Vector2(-40, 1), Vector2(-30, 2.5), Vector2(-24, 1)]), INK, 0.9, true)
	_closed(poly, INK, 1.0)
	# vízvonal és gyűrűk
	var wl := PackedVector2Array()
	for i in 25:
		var t := i / 24.0
		wl.append(pos + Vector2(lerpf(-50, 58, t) * (-1.0 if flip else 1.0), 4.0 + sin(t * TAU * 3.0) * 1.0) * s)
	draw_polyline(wl, FOAM, 1.2, true)
	# kifújt pára: két ív és cseppek a fúvónyílás fölött
	var blow := _pts(pos, s, flip, [Vector2(-22, -14)])[0]
	for side in [-1.0, 1.0]:
		var arc := PackedVector2Array()
		for i in 10:
			var t := i / 9.0
			arc.append(blow + Vector2(side * t * 9.0 * (-1.0 if flip else 1.0), -sin(t * PI * 0.8) * 13.0 + t * 2.0) * s)
		draw_polyline(arc, FOAM, 1.2, true)
	for d in [Vector2(-7, -15), Vector2(7, -15), Vector2(-3, -19), Vector2(3, -20), Vector2(0, -14)]:
		draw_circle(blow + d * s, 0.9 * s, FOAM)

# ── Cápa: a vizet hasító hátúszó, alatta a víz alatt suhanó test árnyéka ──

func _shark(pos: Vector2, s: float, flip: bool) -> void:
	# víz alatti test (halvány sziluett)
	var body: Array = []
	body += _curve(Vector2(-26, 6), Vector2(-20, 1), Vector2(-4, 2))
	body += _curve(Vector2(-4, 2), Vector2(14, 3), Vector2(24, 6))
	body += [Vector2(34, 0), Vector2(31, 7), Vector2(35, 13), Vector2(24, 8)]
	body += _curve(Vector2(24, 8), Vector2(6, 12), Vector2(-14, 10))
	body += [Vector2(-10, 15), Vector2(-17, 10)]
	body += _curve(Vector2(-17, 10), Vector2(-24, 9), Vector2(-26, 6))
	draw_colored_polygon(_pts(pos, s, flip, body), Color(SHARK_BODY, 0.35))
	# a hátúszó a víz fölött: ívelt elülső él, homorú hátsó él
	var fin: Array = []
	fin += _curve(Vector2(-6, 2), Vector2(-3, -8), Vector2(5, -13))
	fin += _curve(Vector2(5, -13), Vector2(3, -5), Vector2(8, 2))
	var fp := _pts(pos, s, flip, fin)
	draw_colored_polygon(fp, SHARK_BODY)
	# a fény felőli él világosabb
	draw_polyline(_pts(pos, s, flip, _curve(Vector2(-5, 1), Vector2(-2.5, -7), Vector2(4.5, -12))), Color(CREAM, 0.45), 1.0, true)
	_closed(fp, INK, 1.0)
	# hullám, amit a cápa hasít, és a nyomvonala
	draw_polyline(_pts(pos, s, flip, [Vector2(-12, 3), Vector2(-7, 1.5), Vector2(-3, 2.5), Vector2(3, 2), Vector2(10, 3), Vector2(16, 2.5)]),
		FOAM, 1.3, true)
	for k in 3:
		var y := 4.0 + k * 2.5
		draw_line(_pts(pos, s, flip, [Vector2(14 + k * 5, y)])[0], _pts(pos, s, flip, [Vector2(30 + k * 7, y + 1)])[0],
			Color(FOAM, 0.45 - k * 0.12), 1.0, true)

# ── Hullámtaréjok: két-három rövid, íves, a végén bekunkorodó vonal ──

func _crests(pos: Vector2, s: float) -> void:
	_crest(pos, 34.0 * s, 1.0)
	_crest(pos + Vector2(9, 6) * s, 26.0 * s, 0.6)

# Egy hullámsor: a két végén elvékonyodó, kétszer hullámzó vonal, alatta halvány árnyékvonal
func _crest(pos: Vector2, width: float, strength: float) -> void:
	var pts := PackedVector2Array()
	var shadow := PackedVector2Array()
	for i in 29:
		var t := i / 28.0
		var envelope := sin(t * PI)
		var y := -sin(t * TAU * 2.0) * 2.4 * envelope
		pts.append(pos + Vector2((t - 0.5) * width, y))
		shadow.append(pos + Vector2((t - 0.5) * width + 1.0, y + 2.0))
	draw_polyline(shadow, Color(INK, 0.12 * strength), 1.0, true)
	draw_polyline(pts, Color(FOAM, FOAM.a * strength), 1.2, true)

# ── Szélrózsa ─────────────────────────────────────────────────

func _draw_compass(c: Vector2, r: float) -> void:
	# iránytűvonalak (portolán-térképek rumbvonalai)
	for i in 16:
		var a := i * PI / 8.0
		draw_line(c + Vector2(cos(a), sin(a)) * r * 1.3, c + Vector2(cos(a), sin(a)) * 900.0,
			Color(FOAM, 0.16 if i % 2 == 0 else 0.08), 1.0, true)
	draw_circle(c, r * 1.28, Color(CREAM, 0.16))
	draw_arc(c, r * 1.28, 0, TAU, 96, Color(CREAM, 0.7), 1.2, true)
	draw_arc(c, r * 1.16, 0, TAU, 96, Color(CREAM, 0.55), 0.8, true)
	# fokbeosztás 5 fokonként, a fő irányoknál hosszabb
	for i in 72:
		var a := i * TAU / 72.0
		var d := Vector2(cos(a), sin(a))
		var inner := 1.16 if i % 9 == 0 else (1.20 if i % 3 == 0 else 1.23)
		draw_line(c + d * r * inner, c + d * r * 1.28, Color(CREAM, 0.65), 0.8, true)
	# 16 mellékirány, 8 fél-irány, 4 fő irány – mindegyik kétszínű (fény és árnyék oldal)
	for i in 16:
		_point(c, i * PI / 8.0 + PI / 16.0, r * 0.42, r * 0.05, Color(CREAM, 0.8), Color(INK, 0.7))
	for i in 4:
		_point(c, i * PI / 2.0 + PI / 4.0, r * 0.72, r * 0.10, CREAM, INK)
	for i in 4:
		_point(c, i * PI / 2.0, r * 1.12, r * 0.15, CREAM, INK)
	draw_circle(c, r * 0.11, INK)
	draw_circle(c, r * 0.07, GOLD)
	var n_size := FONT.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
	var n_pos := c + Vector2(-n_size.x / 2.0, -r * 1.36)
	draw_string_outline(FONT, n_pos, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Color(INK, 0.8))
	draw_string(FONT, n_pos, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREAM)

# Egy csúcs: a bal fele világos, a jobb fele sötét (a régi szélrózsák árnyékolása)
func _point(c: Vector2, angle: float, length: float, width: float, light: Color, dark: Color) -> void:
	var d := Vector2(sin(angle), -cos(angle))
	var n := Vector2(-d.y, d.x)
	var tip := c + d * length
	draw_colored_polygon(PackedVector2Array([c, tip, c + n * width]), light)
	draw_colored_polygon(PackedVector2Array([c, c - n * width, tip]), dark)
	draw_polyline(PackedVector2Array([c + n * width, tip, c - n * width]), Color(INK, 0.9), 0.9, true)

# ── Hosszúhajó ─────────────────────────────────────────────────

func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _longship(pos: Vector2, s: float) -> void:
	var sc := Vector2(s, s)
	# nyomvonal a víz felszínén
	for i in 3:
		var y := 8.0 + i * 3.0
		draw_line(pos + Vector2(-44 + i * 6, y) * s, pos + Vector2(-20 + i * 4, y) * s, Color(FOAM, 0.35 - i * 0.08), 1.0, true)
	# evezők
	for i in 6:
		var x := -16.0 + i * 6.5
		draw_line(pos + Vector2(x, 1) * s, pos + Vector2(x - 5, 11) * s, Color(WOOD, 0.85), 1.0, true)
	# hajótest: ívelt gerinc és korlát, a far és az orr magasan felkunkorodik
	var hull := PackedVector2Array()
	for i in 17:
		hull.append(pos + _bezier(Vector2(-31, -15), Vector2(-26, 8), Vector2(0, 5), i / 16.0) * sc)
	for i in 17:
		hull.append(pos + _bezier(Vector2(0, 5), Vector2(26, 8), Vector2(32, -17), i / 16.0) * sc)
	for i in 17:
		hull.append(pos + _bezier(Vector2(30, -15), Vector2(22, 0), Vector2(0, -1), i / 16.0) * sc)
	for i in 17:
		hull.append(pos + _bezier(Vector2(0, -1), Vector2(-22, 0), Vector2(-29, -13), i / 16.0) * sc)
	draw_colored_polygon(hull, WOOD)
	# deszkasor (világosabb csík)
	var strake := PackedVector2Array()
	for i in 21:
		strake.append(pos + _bezier(Vector2(-27, -6), Vector2(0, 7), Vector2(28, -7), i / 20.0) * sc)
	draw_polyline(strake, WOOD_LIGHT, 1.2 * s, true)
	var outline := hull.duplicate()
	outline.append(hull[0])
	draw_polyline(outline, INK, 1.0, true)
	# sárkányfej az orron, csigavonal a faron
	draw_circle(pos + Vector2(33, -18) * s, 2.2 * s, WOOD)
	draw_line(pos + Vector2(33, -18) * s, pos + Vector2(37, -17) * s, WOOD, 1.6 * s, true)
	draw_arc(pos + Vector2(-32, -17) * s, 2.2 * s, 0.0, 5.0, 12, WOOD, 1.4 * s, true)
	# pajzsok a korlát mentén
	for i in 8:
		var p := pos + _bezier(Vector2(-22, -2), Vector2(0, 0), Vector2(23, -2), i / 7.0) * sc
		draw_circle(p, 2.3 * s, INK)
		draw_circle(p, 1.8 * s, GOLD if i % 2 == 0 else RED)
		draw_circle(p, 0.6 * s, INK)
	# árboc, vitorlarúd és a szélben dagadó, csíkos vitorla
	draw_line(pos + Vector2(0, -1) * s, pos + Vector2(0, -40) * s, WOOD, 1.6 * s, true)
	var sail := PackedVector2Array()
	for i in 9: sail.append(pos + _bezier(Vector2(-15, -35), Vector2(0, -38), Vector2(15, -35), i / 8.0) * sc)
	for i in 9: sail.append(pos + _bezier(Vector2(15, -35), Vector2(19, -22), Vector2(15, -10), i / 8.0) * sc)
	for i in 9: sail.append(pos + _bezier(Vector2(15, -10), Vector2(0, -6), Vector2(-15, -10), i / 8.0) * sc)
	for i in 9: sail.append(pos + _bezier(Vector2(-15, -10), Vector2(-11, -22), Vector2(-15, -35), i / 8.0) * sc)
	draw_colored_polygon(sail, CREAM)
	for k in 3:
		var x0 := -11.0 + k * 9.0
		var stripe := PackedVector2Array([pos + Vector2(x0, -36.5) * s, pos + Vector2(x0 + 4.5, -36.8) * s,
			pos + Vector2(x0 + 5.5, -7.3) * s, pos + Vector2(x0 + 1, -7.8) * s])
		draw_colored_polygon(stripe, RED)
	# a vitorla árnyékos (hátsó) fele
	var shade := PackedVector2Array([pos + Vector2(4, -37) * s, pos + Vector2(15, -35) * s, pos + Vector2(19, -22) * s,
		pos + Vector2(15, -10) * s, pos + Vector2(4, -7) * s])
	draw_colored_polygon(shade, Color(0.1, 0.1, 0.12, 0.16))
	var so := sail.duplicate()
	so.append(sail[0])
	draw_polyline(so, INK, 1.0, true)
	draw_line(pos + Vector2(-17, -35) * s, pos + Vector2(17, -35) * s, WOOD, 1.8 * s, true)
	# kötélzet
	draw_line(pos + Vector2(0, -40) * s, pos + Vector2(-29, -13) * s, INK_SOFT, 0.7, true)
	draw_line(pos + Vector2(0, -40) * s, pos + Vector2(30, -15) * s, INK_SOFT, 0.7, true)

# ── Bálna: a lemerülő bálna farka a víz fölött, körülötte gyűrűző hullámok ──

func _whale_tail(pos: Vector2, s: float) -> void:
	for i in 3:
		draw_arc(pos + Vector2(0, 6) * s, (14.0 + i * 7.0) * s, PI * 0.05, PI * 0.95, 24, Color(FOAM, 0.55 - i * 0.15), 1.1, true)
		draw_arc(pos + Vector2(0, 6) * s, (14.0 + i * 7.0) * s, PI * 1.05, PI * 1.95, 24, Color(FOAM, 0.25 - i * 0.07), 1.0, true)
	var tail := PackedVector2Array()
	# a farokszár, majd a két farokúszó (lebeny) íve
	var pts := [Vector2(-3, 6), Vector2(-3.5, -4), Vector2(-7, -10), Vector2(-15, -14), Vector2(-22, -13), Vector2(-19, -16),
		Vector2(-10, -18), Vector2(-3, -16), Vector2(0, -13), Vector2(3, -16), Vector2(10, -18), Vector2(19, -16),
		Vector2(22, -13), Vector2(15, -14), Vector2(7, -10), Vector2(3.5, -4), Vector2(3, 6)]
	for p in pts: tail.append(pos + p * s)
	draw_colored_polygon(tail, Color(0.20, 0.28, 0.34))
	# világosabb alsó rész és a széle
	draw_polyline(PackedVector2Array([pos + Vector2(-19, -14.5) * s, pos + Vector2(-10, -16) * s, pos + Vector2(-2, -14) * s]),
		Color(CREAM, 0.5), 1.0, true)
	draw_polyline(PackedVector2Array([pos + Vector2(2, -14) * s, pos + Vector2(10, -16) * s, pos + Vector2(19, -14.5) * s]),
		Color(CREAM, 0.5), 1.0, true)
	var o := tail.duplicate()
	o.append(tail[0])
	draw_polyline(o, INK, 1.0, true)
	# lecsorgó víz
	for d in [Vector2(-16, -9), Vector2(-12, -5), Vector2(14, -8), Vector2(17, -3)]:
		draw_circle(pos + d * s, 0.9 * s, FOAM)
