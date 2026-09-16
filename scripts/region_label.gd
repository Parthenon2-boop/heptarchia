extends Node2D

# HEPTARCHIA – zárolt vidék felirata (lakat + név) a térképen.
# A térkép-világ gyereke; a MapView a nagyítás reciprokával skálázza.

const FONT := preload("res://assets/ui/font_title.tres")
const FONT_SIZE := 17
const TEXT_COLOR := Color(0.86, 0.86, 0.88, 0.95)
const OUTLINE := Color(0.12, 0.12, 0.14, 0.9)

var region_key: String = ""

func _draw() -> void:
	var text := tr(region_key)
	var size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var total := size.x + 16.0
	var x0 := -total / 2.0
	# Lakat
	var lock_c := Vector2(x0 + 5.0, -4.0)
	draw_arc(lock_c + Vector2(0, -3), 3.2, PI, TAU, 10, OUTLINE, 3.4)
	draw_arc(lock_c + Vector2(0, -3), 3.2, PI, TAU, 10, TEXT_COLOR, 1.6)
	draw_rect(Rect2(lock_c + Vector2(-5, -3), Vector2(10, 8)), OUTLINE)
	draw_rect(Rect2(lock_c + Vector2(-4, -2), Vector2(8, 6)), TEXT_COLOR)
	draw_rect(Rect2(lock_c + Vector2(-0.8, 0), Vector2(1.6, 2.5)), OUTLINE)
	var pos := Vector2(x0 + 16.0, FONT.get_ascent(FONT_SIZE) / 2.0 - 4.0)
	draw_string_outline(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, OUTLINE)
	draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)
