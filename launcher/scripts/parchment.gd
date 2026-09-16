extends Control

# HEPTARCHIA LAUNCHER – pergamen háttér
# Bőrszerű alap, rajta pergamenlap: foltos árnyalatok, aranykeret, fonatos sarokdíszek.

const S := preload("res://scripts/style.gd")

var _noise := FastNoiseLite.new()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_noise.seed = 871
	_noise.frequency = 0.012
	resized.connect(queue_redraw)

func _draw() -> void:
	# bőr háttér
	draw_rect(Rect2(Vector2.ZERO, size), S.LEATHER)
	for i in 26:
		var y := size.y * i / 26.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.05), 1.0)

	# pergamenlap
	var page := Rect2(18, 18, size.x - 36, size.y - 36)
	draw_rect(page.grow(4), Color(0, 0, 0, 0.25))
	draw_rect(page, S.PARCH)
	# foltok, hogy ne legyen lapos
	for i in 120:
		var p := Vector2(page.position.x + randf_range(0, page.size.x), page.position.y + randf_range(0, page.size.y))
		var v := _noise.get_noise_2dv(p)
		draw_circle(p, 6.0 + absf(v) * 22.0, Color(S.PARCH_DARK, 0.05 + absf(v) * 0.06))
	# szélek sötétedése
	for i in 14:
		var t := i / 14.0
		var r := page.grow(-float(i))
		draw_rect(r, Color(0.55, 0.42, 0.26, 0.05 * (1.0 - t)), false, 1.0)

	# aranykeret és belső vonal
	draw_rect(page, S.GOLD_DARK, false, 3.0)
	draw_rect(page.grow(-6), Color(S.GOLD, 0.7), false, 1.0)

	# fonatos sarokdíszek
	for c in [Vector2(page.position.x, page.position.y), Vector2(page.end.x, page.position.y),
			Vector2(page.position.x, page.end.y), Vector2(page.end.x, page.end.y)]:
		var sx := 1.0 if c.x < size.x / 2.0 else -1.0
		var sy := 1.0 if c.y < size.y / 2.0 else -1.0
		_corner(c, sx, sy)

func _corner(c: Vector2, sx: float, sy: float) -> void:
	var o := c + Vector2(10 * sx, 10 * sy)
	for k in 3:
		var r := 4.0 + k * 4.0
		draw_arc(o, r, 0.0, TAU, 24, Color(S.GOLD_DARK, 0.85 - k * 0.2), 1.6, true)
	draw_circle(o, 2.4, S.RED)
