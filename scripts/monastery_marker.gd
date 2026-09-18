extends Node2D

# HEPTARCHIA – nevezetes kolostor a térképen (Lindisfarne, Iona).
# Kis kőtemplom kereszttel és kerítéssel; ha a vikingek kifosztották, füstölgő rom.
# A térkép-világ gyereke; a MapView a nagyítás reciprokával skálázza.

const FONT := preload("res://assets/ui/font_italic.tres")
const FONT_SIZE := 13
const INK := Color(0.16, 0.10, 0.05)
const STONE := Color(0.93, 0.89, 0.79)
const ROOF := Color(0.46, 0.24, 0.14)
const GOLD := Color(0.97, 0.80, 0.33)
const FIRE := Color(0.95, 0.42, 0.12)
const SMOKE := Color(0.28, 0.26, 0.25, 0.55)
const TEXT_COLOR := Color(0.98, 0.94, 0.84)

var site_name: String = ""
var show_label: bool = true
var sacked: bool = false

func set_sacked(v: bool) -> void:
	if v != sacked:
		sacked = v
		queue_redraw()

func _poly(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(Geometry2D.offset_polygon(points, 1.1)[0], INK)
	draw_colored_polygon(points, fill)

func _draw() -> void:
	# a szent szigetet jelző halvány dicsfény
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.95, 0.75, 0.22 if not sacked else 0.0))
	if sacked:
		# leégett falak, lángok és füst
		_poly(PackedVector2Array([Vector2(-7, 4), Vector2(-7, -2), Vector2(-4, -4), Vector2(-3, 0), Vector2(0, -3),
			Vector2(2, 1), Vector2(5, -2), Vector2(7, 4)]), STONE.darkened(0.35))
		draw_circle(Vector2(-3, -6), 2.4, FIRE)
		draw_circle(Vector2(2, -7), 1.8, FIRE.lightened(0.2))
		draw_circle(Vector2(0, -12), 3.2, SMOKE)
		draw_circle(Vector2(3, -16), 2.6, SMOKE)
	else:
		# templomhajó nyeregtetővel, nyugati torony, kereszt
		_poly(PackedVector2Array([Vector2(-7, 4), Vector2(3, 4), Vector2(3, -2), Vector2(-7, -2)]), STONE)
		_poly(PackedVector2Array([Vector2(-8, -2), Vector2(4, -2), Vector2(-2, -6)]), ROOF)
		_poly(PackedVector2Array([Vector2(3, 4), Vector2(7, 4), Vector2(7, -7), Vector2(3, -7)]), STONE)
		draw_rect(Rect2(-3, 1, 2, 3), INK)
		for pass_i in 2:
			var c := INK if pass_i == 0 else GOLD
			var w := 2.6 if pass_i == 0 else 1.1
			draw_line(Vector2(5, -7), Vector2(5, -12), c, w)
			draw_line(Vector2(3, -10), Vector2(7, -10), c, w)
	if not show_label: return
	var pos := Vector2(11.0, FONT.get_ascent(FONT_SIZE) / 2.0 - 2.0)
	draw_string_outline(FONT, pos, site_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, INK)
	draw_string(FONT, pos, site_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
		TEXT_COLOR if not sacked else Color(1.0, 0.62, 0.5))
