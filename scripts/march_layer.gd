extends Node2D

# HEPTARCHIA – úton lévő seregek rajzolása a térképen.
# A térkép-világ gyereke (együtt mozog vele); a vonalvastagságot és a jelölőket
# a nagyítás reciprokával rajzolja, így a képernyőn állandó méretűek.

const FONT := preload("res://assets/ui/font_bold.tres")
const INK := Color(0.10, 0.06, 0.03)
const TEXT := Color(0.98, 0.93, 0.80)

var marches: Array = []
var zoom: float = 1.0

func set_data(new_marches: Array, new_zoom: float) -> void:
	marches = new_marches
	zoom = new_zoom
	queue_redraw()

func _point_along(pts: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var target := total * clampf(t, 0.0, 1.0)
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if target <= seg or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf(target / maxf(seg, 0.001), 0.0, 1.0))
		target -= seg
	return pts[0]

func _draw() -> void:
	var inv := 1.0 / zoom
	for m in marches:
		var pts := PackedVector2Array()
		for pname in m["path"]:
			pts.append(GameManager.CITY_POS[pname])
		if pts.size() < 2: continue
		var col := GameManager.faction_color(int(m["faction"]))
		if m["returning"]:
			col = Color(0.85, 0.3, 0.25)
		for i in pts.size() - 1:
			draw_dashed_line(pts[i], pts[i + 1], INK, 4.0 * inv, 7.0 * inv)
			draw_dashed_line(pts[i], pts[i + 1], col, 2.2 * inv, 7.0 * inv)
		# Célzászló
		var dest := pts[pts.size() - 1]
		draw_set_transform(dest, 0.0, Vector2(inv, inv))
		draw_line(Vector2(0, 0), Vector2(0, -18), INK, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(1, -18), Vector2(11, -14), Vector2(1, -10)]), col)
		# Sereg jelölő a haladás arányában
		var total := int(m["turns_total"])
		var progress := float(total - int(m["turns_left"])) / float(maxi(total, 1))
		var pos := _point_along(pts, progress)
		draw_set_transform(pos, 0.0, Vector2(inv, inv))
		var shield := PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(9, 1), Vector2(0, 11), Vector2(-9, 1)])
		draw_colored_polygon(Geometry2D.offset_polygon(shield, 2.0)[0], INK)
		draw_colored_polygon(shield, col)
		var troops := str(int(m["fyrd"]) + int(m["thegn"]))
		var tsz := FONT.get_string_size(troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string_outline(FONT, Vector2(-tsz.x / 2.0, 4), troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, INK)
		draw_string(FONT, Vector2(-tsz.x / 2.0, 4), troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		var dur := Localization.format_duration(int(m["turns_left"]))
		var dsz := FONT.get_string_size(dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string_outline(FONT, Vector2(-dsz.x / 2.0, 26), dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, INK)
		draw_string(FONT, Vector2(-dsz.x / 2.0, 26), dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
