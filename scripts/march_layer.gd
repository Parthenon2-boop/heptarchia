extends Node2D

# HEPTARCHIA – úton lévő seregek rajzolása a térképen.
# A térkép-világ gyereke (együtt mozog vele); a vonalvastagságot és a jelölőket
# a nagyítás reciprokával rajzolja, így a képernyőn állandó méretűek.

const FONT := preload("res://assets/ui/font_bold.tres")
const INK := Color(0.10, 0.06, 0.03)
const TEXT := Color(0.98, 0.93, 0.80)
const WOOD := Color(0.35, 0.24, 0.15)          # hajótest
const WOOD_LIGHT := Color(0.52, 0.38, 0.24)    # a napos oldal
const SAIL := Color(0.90, 0.87, 0.78)          # vitorlavászon
const MarchIcons := preload("res://scripts/ui/march_icons.gd")

var marches: Array = []
var zoom: float = 1.0
# A térkép adja: víz van-e az adott térkép-képponton. Ha a sereg épp vízen jár
# (a szomszédos városok közti egyenes gyakran átvág egy öblön vagy szoroson),
# a katona helyett a nép saját hajója látszik.
var vizen: Callable = Callable()

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

# ── Hajók ──────────────────────────────────────────────────────
#
# Minden népnek saját hajója van, mert a korban tényleg más-más hajóval jártak:
#   norse   – hosszúhajó, faragott sárkányorral és csíkos vitorlával
#   gaelic  – curragh, bőrrel bevont bordás csónak, magas orral
#   welsh   – kisebb, egyárbócos parti hajó
#   norman  – nef: széles testű, palánkos, magas tatú
#   english – keel: zömök kereskedőhajó, oldalt kormánylapáttal
# A rajz a menetjelölő helyén áll, a haladás irányába fordulva (irany = ±1).
# A vitorlán a királyság színe látszik, hogy messziről is tudd, kié.

func _tukor(p: Array, irany: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(Vector2(v.x * irany, v.y))
	return out

func _test(pontok: Array, irany: float) -> void:
	var poly := _tukor(pontok, irany)
	draw_colored_polygon(Geometry2D.offset_polygon(poly, 1.6)[0], INK)
	draw_colored_polygon(poly, WOOD)

func _arboc(magas: float, col: Color, irany: float, csikos: bool) -> void:
	draw_line(Vector2(0, 0), Vector2(0, -magas), INK, 2.0)
	# a vitorla: vászon alapon a királyság színe
	var v := _tukor([Vector2(-7, -magas + 2), Vector2(7, -magas + 2), Vector2(8, -3), Vector2(-8, -3)], irany)
	draw_colored_polygon(Geometry2D.offset_polygon(v, 1.4)[0], INK)
	draw_colored_polygon(v, SAIL)
	if csikos:
		# óészaki csíkos vitorla
		for i in 3:
			var y := -magas + 5.0 + i * 4.0
			draw_line(Vector2(-7.6 * irany, y), Vector2(7.6 * irany, y), col, 2.2)
	else:
		var s := _tukor([Vector2(-5, -magas + 5), Vector2(5, -magas + 5), Vector2(5.6, -6), Vector2(-5.6, -6)], irany)
		draw_colored_polygon(s, col)

func _hajo(kultura: String, col: Color, irany: float) -> void:
	match kultura:
		"norse":
			# hosszúhajó: karcsú test, felkunkorodó orr és tat, sárkányfej
			_test([Vector2(-14, 0), Vector2(14, 0), Vector2(11, 6), Vector2(-11, 6)], irany)
			draw_line(Vector2(-14 * irany, 0), Vector2(-15 * irany, -8), WOOD_LIGHT, 2.2)
			draw_line(Vector2(14 * irany, 0), Vector2(16 * irany, -9), WOOD_LIGHT, 2.4)
			draw_colored_polygon(_tukor([Vector2(16, -9), Vector2(20, -11), Vector2(17, -6)], irany), WOOD_LIGHT)
			_arboc(17.0, col, irany, true)
			# pajzsok a palánkon
			for i in 5:
				draw_circle(Vector2((-9.0 + i * 4.5) * irany, 2.0), 1.8, col.darkened(0.15))
		"gaelic":
			# curragh: magas orrú, bordás bőrcsónak, árbóc nélkül is megvan
			_test([Vector2(-11, 0), Vector2(12, 0), Vector2(9, 7), Vector2(-9, 7)], irany)
			draw_line(Vector2(12 * irany, 0), Vector2(15 * irany, -10), WOOD_LIGHT, 2.2)
			draw_line(Vector2(-11 * irany, 0), Vector2(-13 * irany, -6), WOOD_LIGHT, 2.0)
			for i in 4:
				draw_line(Vector2((-7.0 + i * 4.5) * irany, 0.5), Vector2((-6.0 + i * 4.5) * irany, 6.5),
					WOOD_LIGHT, 1.2)
			_arboc(14.0, col, irany, false)
		"welsh":
			# parti hajó: kisebb test, egyetlen árbóc, magas tat
			_test([Vector2(-10, 0), Vector2(11, 0), Vector2(8, 6), Vector2(-8, 6)], irany)
			draw_line(Vector2(-10 * irany, 0), Vector2(-11 * irany, -7), WOOD_LIGHT, 2.2)
			_arboc(15.0, col, irany, false)
		"norman":
			# nef: széles test, magas orr- és tatvár
			_test([Vector2(-12, -1), Vector2(12, -1), Vector2(9, 7), Vector2(-9, 7)], irany)
			draw_colored_polygon(_tukor([Vector2(-12, -1), Vector2(-7, -1), Vector2(-7, -7), Vector2(-12, -7)], irany), WOOD_LIGHT)
			draw_colored_polygon(_tukor([Vector2(8, -1), Vector2(12, -1), Vector2(12, -6), Vector2(8, -6)], irany), WOOD_LIGHT)
			_arboc(16.0, col, irany, false)
		_:
			# keel: zömök kereskedőhajó, oldalt lógó kormánylapáttal
			_test([Vector2(-12, 0), Vector2(12, 0), Vector2(9, 7), Vector2(-9, 7)], irany)
			draw_line(Vector2(12 * irany, 0), Vector2(14 * irany, -6), WOOD_LIGHT, 2.2)
			draw_line(Vector2(-11 * irany, 1), Vector2(-14 * irany, 7), WOOD_LIGHT, 2.4)
			_arboc(15.0, col, irany, false)

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
		# Merre tart? A hajó orra abba az irányba néz, amerre a sereg halad.
		var elore := _point_along(pts, minf(progress + 0.02, 1.0))
		var irany := -1.0 if elore.x < pos.x else 1.0
		var hajon: bool = vizen.is_valid() and vizen.call(pos)
		draw_set_transform(pos, 0.0, Vector2(inv, inv))
		if hajon:
			# A sereg épp vízen jár: a katona helyett a nép saját hajója látszik.
			_hajo(GameManager.culture_of(int(m["faction"])), col, irany)
		else:
			MarchIcons.katona(self, col, irany)
		# A létszám az alak ALÁ kerül – sem a katonára, sem a hajóra nem fér rá
		# úgy, hogy ne takarja el a rajzot.
		var troops := str(GameManager.troops_of(m)) + (" ★" if m.get("general", false) else "")
		var tsz := FONT.get_string_size(troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		var ty := 20.0 if hajon else 17.0
		draw_string_outline(FONT, Vector2(-tsz.x / 2.0, ty), troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, INK)
		draw_string(FONT, Vector2(-tsz.x / 2.0, ty), troops, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		var dur := Localization.format_duration(int(m["turns_left"]))
		var dsz := FONT.get_string_size(dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string_outline(FONT, Vector2(-dsz.x / 2.0, ty + 16.0), dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, INK)
		draw_string(FONT, Vector2(-dsz.x / 2.0, ty + 16.0), dur, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
