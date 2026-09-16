extends Node2D

# HEPTARCHIA – tengeri díszek, ahogy a régi kéziratos térképeken:
# hullámok, delfinek, bálna, egy viking hosszúhajó és szélrózsa iránytűvonalakkal.
# A térkép-világ gyereke (a térképpel együtt nagyul); a sea_decor shader levágja a szárazföldre eső részt.

const FONT := preload("res://assets/ui/font_bold.tres")
const INK := Color(0.42, 0.30, 0.19, 0.85)
const INK_FAINT := Color(0.42, 0.30, 0.19, 0.22)
const PAPER := Color(0.93, 0.88, 0.76, 0.92)
const SHADE := Color(0.62, 0.52, 0.39, 0.92)
const LIGHT := Color(0.86, 0.79, 0.65, 0.95)
const RED := Color(0.62, 0.20, 0.13, 0.9)

const COMPASS := Vector2(150, 560)
const COMPASS_R := 40.0
const WAVES := [Vector2(700, 118), Vector2(862, 330), Vector2(905, 205), Vector2(78, 178), Vector2(250, 118),
	Vector2(474, 566), Vector2(742, 360), Vector2(300, 610), Vector2(60, 400), Vector2(935, 520), Vector2(420, 250)]

func _draw() -> void:
	_draw_compass(COMPASS, COMPASS_R)
	for w in WAVES:
		_wave(w, 26.0)
	_whale(Vector2(835, 262), 1.0)
	_dolphin(Vector2(230, 470), 0.9, false)
	_dolphin(Vector2(760, 140), 0.8, true)
	_longship(Vector2(625, 175), 0.9)

# ── Hullám: két egymás alatti hullámvonal ─────────────────────

func _wave(pos: Vector2, width: float) -> void:
	for row in 2:
		var pts := PackedVector2Array()
		var off := Vector2(4.0 * row, 5.0 * row)
		for i in 17:
			var x := width * i / 16.0
			pts.append(pos + off + Vector2(x, -2.2 * sin(x * 0.55)))
		draw_polyline(pts, INK, 1.1, true)

# ── Szélrózsa ─────────────────────────────────────────────────

func _draw_compass(c: Vector2, r: float) -> void:
	# iránytűvonalak (portolán-térképek rumbvonalai)
	for i in 16:
		var a := i * PI / 8.0
		draw_line(c, c + Vector2(cos(a), sin(a)) * 900.0, INK_FAINT if i % 2 == 1 else Color(INK, 0.3), 1.0)
	draw_circle(c, r * 1.08, PAPER)
	draw_arc(c, r * 1.08, 0, TAU, 72, INK, 1.6, true)
	draw_arc(c, r * 0.95, 0, TAU, 72, INK, 0.8, true)
	for i in 32:
		var a := i * TAU / 32.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * (0.95 if i % 2 == 0 else 1.0), c + d * r * 1.08, INK, 0.8)
	# 8 mellékirány, majd a 4 fő égtáj
	for i in 8:
		_point(c, i * PI / 4.0 + PI / 8.0, r * 0.45, r * 0.07)
	for i in 4:
		_point(c, i * PI / 2.0 + PI / 4.0, r * 0.66, r * 0.11)
	for i in 4:
		_point(c, i * PI / 2.0, r * 1.0, r * 0.16)
	draw_circle(c, r * 0.09, INK)
	draw_circle(c, r * 0.05, Color(0.97, 0.80, 0.33))
	var n_size := FONT.get_string_size("N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string_outline(FONT, c + Vector2(-n_size.x / 2.0, -r * 1.14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, PAPER)
	draw_string(FONT, c + Vector2(-n_size.x / 2.0, -r * 1.14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

# Egy csúcs: bal fele sötét, jobb fele világos (a régi szélrózsák árnyékolása)
func _point(c: Vector2, angle: float, length: float, width: float) -> void:
	var d := Vector2(sin(angle), -cos(angle))
	var n := Vector2(-d.y, d.x)
	var tip := c + d * length
	var left := c + n * width
	var right := c - n * width
	draw_colored_polygon(PackedVector2Array([c, tip, left]), SHADE)
	draw_colored_polygon(PackedVector2Array([c, right, tip]), LIGHT)
	draw_polyline(PackedVector2Array([left, tip, right]), INK, 1.0, true)

# ── Állatok ───────────────────────────────────────────────────

func _shape(center: Vector2, pts: Array, s: float, flip: bool, fill: Color) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(center + Vector2(p.x * (-1.0 if flip else 1.0), p.y) * s)
	draw_colored_polygon(out, fill)
	var outline := out.duplicate()
	outline.append(out[0])
	draw_polyline(outline, INK, 1.2, true)
	return out

func _local(center: Vector2, p: Vector2, s: float, flip: bool) -> Vector2:
	return center + Vector2(p.x * (-1.0 if flip else 1.0), p.y) * s

func _dolphin(pos: Vector2, s: float, flip: bool) -> void:
	var body := [Vector2(24, 0), Vector2(18, -3), Vector2(10, -6), Vector2(2, -7), Vector2(-4, -13), Vector2(-6, -6),
		Vector2(-12, -4), Vector2(-18, -1), Vector2(-22, -1), Vector2(-28, -6), Vector2(-25, 0), Vector2(-28, 6),
		Vector2(-22, 2), Vector2(-16, 3), Vector2(-6, 4), Vector2(4, 4), Vector2(12, 3), Vector2(18, 1)]
	_shape(pos, body, s, flip, LIGHT)
	draw_circle(_local(pos, Vector2(15, -2), s, flip), 1.0 * s, INK)
	draw_line(_local(pos, Vector2(24, 0), s, flip), _local(pos, Vector2(17, 0.8), s, flip), INK, 1.0, true)
	draw_polyline(PackedVector2Array([_local(pos, Vector2(5, 3), s, flip), _local(pos, Vector2(1, 9), s, flip),
		_local(pos, Vector2(-2, 4), s, flip)]), INK, 1.0, true)
	# hullám alatta
	_wave(pos + Vector2(-20, 12) * s, 40.0 * s)

func _whale(pos: Vector2, s: float) -> void:
	# kifújó bálna, a farka kiemelkedik a vízből
	var body := [Vector2(-34, 2), Vector2(-30, -8), Vector2(-20, -14), Vector2(-4, -16), Vector2(12, -13), Vector2(24, -7),
		Vector2(30, -3), Vector2(36, -5), Vector2(44, -15), Vector2(42, -5), Vector2(51, -3), Vector2(40, 1),
		Vector2(34, 4), Vector2(20, 8), Vector2(0, 10), Vector2(-20, 9), Vector2(-30, 6)]
	_shape(pos, body, s, false, SHADE)
	for i in 5:
		draw_line(pos + Vector2(-28 + i * 5, 5) * s, pos + Vector2(-20 + i * 5, 8) * s, Color(INK, 0.6), 0.9, true)
	draw_circle(pos + Vector2(-23, -4) * s, 1.3 * s, INK)
	draw_polyline(PackedVector2Array([pos + Vector2(-34, 2) * s, pos + Vector2(-24, 3) * s, pos + Vector2(-14, 1) * s]), INK, 1.0, true)
	# kifújt víz
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(pos + Vector2(-12 + side * (t * 11.0), -16 - sin(t * PI * 0.8) * 16.0 + t * 4.0) * s)
		draw_polyline(pts, INK, 1.1, true)
	for d in [Vector2(-25, -22), Vector2(1, -22), Vector2(-20, -30), Vector2(-4, -31)]:
		draw_circle(pos + d * s, 1.0 * s, INK)
	_wave(pos + Vector2(-44, 13) * s, 34.0 * s)
	_wave(pos + Vector2(8, 13) * s, 34.0 * s)

func _longship(pos: Vector2, s: float) -> void:
	# hajótest sárkányfejes orral és farral
	var hull := [Vector2(-30, -12), Vector2(-24, -3), Vector2(-18, 3), Vector2(18, 3), Vector2(24, -3), Vector2(30, -14),
		Vector2(22, -2), Vector2(-22, -2)]
	_shape(pos, hull, s, false, SHADE)
	# pajzsok a hajó oldalán
	for i in 7:
		draw_circle(pos + Vector2(-15 + i * 5, -1) * s, 1.9 * s, Color(0.93, 0.80, 0.40, 0.95) if i % 2 == 0 else RED)
	# árboc és csíkos vitorla
	draw_line(pos + Vector2(0, -2) * s, pos + Vector2(0, -34) * s, INK, 1.4, true)
	var sail := PackedVector2Array([pos + Vector2(-13, -31) * s, pos + Vector2(13, -31) * s, pos + Vector2(15, -9) * s, pos + Vector2(-15, -9) * s])
	draw_colored_polygon(sail, PAPER)
	for i in 3:
		var x0 := -13.0 + i * 9.0
		draw_colored_polygon(PackedVector2Array([pos + Vector2(x0 + 1, -31) * s, pos + Vector2(x0 + 5, -31) * s,
			pos + Vector2(x0 + 5.5, -9) * s, pos + Vector2(x0 + 0.5, -9) * s]), RED)
	var so := sail.duplicate()
	so.append(sail[0])
	draw_polyline(so, INK, 1.1, true)
	_wave(pos + Vector2(-34, 6) * s, 68.0 * s)
