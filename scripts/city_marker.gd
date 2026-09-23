extends Node2D

# HEPTARCHIA – városjelölő
# A térkép-világ gyereke, így együtt mozog a térképpel.
# A MapView a nagyítás reciprokával skálázza, ezért a képernyőn állandó méretű.

const FONT := preload("res://assets/ui/font_bold.tres")
const FONT_SIZE := 15
const OUTLINE := Color(0.18, 0.12, 0.06)
const TEXT_COLOR := Color(0.98, 0.94, 0.84)
const STONE := Color(0.72, 0.70, 0.66)
const CHURCH_STONE := Color(0.90, 0.86, 0.76)
const ROOF := Color(0.52, 0.25, 0.14)
const GOLD := Color(0.97, 0.80, 0.33)
const CHURCH_ORIGIN := Vector2(-10, 6)   # az egyházi épület jobb alsó sarka a jelölőhöz képest

var city_name: String = ""
var label_side: String = "below"   # below / above / left / right
var color: Color = Color.WHITE
var has_burh: bool = false
var church: int = 0
var has_tower: bool = false
var has_port: bool = false
var army: int = 0
var hof: int = 0
var norse: bool = false        # dán/norvég gazda: cölöpös tábor, és a pogány szentély látszik
var norman: bool = false       # normann gazda: mottás vár
var selected: bool = false
var hovered: bool = false
# Az eddig a térképen nem látszó épületek: kis piktogramsorként jelennek meg
# (a burh, a templom/hof, az őrtorony és a kikötő saját rajzot kap)
var extras: Array = []

const EXTRA_ICON := 10.0      # a piktogramok mérete a képernyőn
const EXTRA_STEP := 11.5

const WOOD := Color(0.55, 0.36, 0.20)
const DARK_WOOD := Color(0.36, 0.22, 0.12)
const RUNE_RED := Color(0.75, 0.18, 0.12)
const TURF := Color(0.42, 0.52, 0.30)

func set_state(p: Dictionary) -> void:
	var c := GameManager.faction_color(p["faction"])
	var troops: int = p["fyrd"] + p["thegn"]
	var n := GameManager.is_norse(int(p["faction"]))
	var nm := int(p["faction"]) == GameManager.Faction.NORMANS
	var h: int = p.get("hof", 0)
	var ex: Array = []
	if int(p.get("farm", 0)) > 0: ex.append("farm")
	if int(p.get("village", 0)) > 0: ex.append("village")
	if int(p.get("barracks", 0)) > 0: ex.append("barracks")
	if p.get("has_market", false): ex.append("market")
	if p.get("has_mint", false): ex.append("mint")
	if c == color and p["has_burh"] == has_burh and p["church"] == church and h == hof and n == norse and nm == norman \
			and p["has_tower"] == has_tower and p["has_port"] == has_port and troops == army and ex == extras:
		return
	color = c; has_burh = p["has_burh"]; church = p["church"]; hof = h; norse = n; norman = nm
	has_tower = p["has_tower"]; has_port = p["has_port"]; army = troops; extras = ex
	queue_redraw()

func set_selected(v: bool) -> void:
	if v != selected:
		selected = v; queue_redraw()

func set_hovered(v: bool) -> void:
	if v != hovered:
		hovered = v; queue_redraw()

func _draw() -> void:
	# a gazda kultúrájának szent helye látszik (dán uralom alatt a hof, egyébként a templom)
	if hof > 0 and (norse or church == 0):
		_draw_hof(hof)
	elif church > 0:
		_draw_church(church)

	if selected:
		draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.85, 0.3, 0.85))
	elif hovered:
		draw_circle(Vector2.ZERO, 11.0, Color(1.0, 1.0, 1.0, 0.45))

	if has_burh and norman:
		# Mottás vár: földhalom, rajta fatorony, körülötte cölöpkerítés (bailey)
		_shape(PackedVector2Array([Vector2(-10, 6), Vector2(-6, -1), Vector2(6, -1), Vector2(10, 6)]), Color(0.55, 0.45, 0.30))
		_box(-3.5, -9, 3.5, -1, color)
		_box(-4.5, -11, 4.5, -8.5, color)
		draw_rect(Rect2(-1, -5, 2, 3), OUTLINE)
	elif has_burh and norse:
		# Erődített tábor: hegyes cölöpkerítés
		for i in 5:
			var x := -8.0 + i * 4.0
			var stake := PackedVector2Array([Vector2(x - 1.8, 6), Vector2(x + 1.8, 6), Vector2(x + 1.8, -4), Vector2(x, -8), Vector2(x - 1.8, -4)])
			_shape(stake, color)
		draw_line(Vector2(-10, -1), Vector2(10, -1), OUTLINE, 1.5)
	elif has_burh:
		# Kis vár: fal + három pártázat
		var wall := Rect2(-7, -4, 14, 10)
		var merlons := [Rect2(-7, -8, 3, 4), Rect2(-1.5, -8, 3, 4), Rect2(4, -8, 3, 4)]
		draw_rect(wall.grow(1.5), OUTLINE)
		for m in merlons: draw_rect(m.grow(1.5), OUTLINE)
		draw_rect(wall, color)
		for m in merlons: draw_rect(m, color)
		draw_rect(Rect2(-1.5, 1, 3, 5), OUTLINE)   # kapu
	else:
		draw_circle(Vector2.ZERO, 6.5, OUTLINE)
		draw_circle(Vector2.ZERO, 5.0, color)

	if has_tower:
		# Őrtorony a jobb felső saroknál
		var t := Rect2(9, -15, 5, 9)
		draw_rect(t.grow(1.2), OUTLINE)
		draw_rect(t, STONE)
		draw_rect(Rect2(8, -17, 7, 3).grow(1.0), OUTLINE)
		draw_rect(Rect2(8, -17, 7, 3), STONE)

	if has_port:
		# Horgony a jobb oldalon
		var a := Vector2(19, -2)
		for pass_i in 2:
			var col := OUTLINE if pass_i == 0 else Color(0.75, 0.85, 0.95)
			var w := 3.0 if pass_i == 0 else 1.3
			draw_line(a + Vector2(0, -4), a + Vector2(0, 4), col, w)
			draw_line(a + Vector2(-2.5, -2.5), a + Vector2(2.5, -2.5), col, w)
			draw_arc(a + Vector2(0, 1), 3.5, 0.3, PI - 0.3, 8, col, w)

	if army > 0:
		var bpos := Vector2(9, 6)
		var txt := str(army)
		draw_circle(bpos, 6.5, OUTLINE)
		var tsz := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(FONT, bpos + Vector2(-tsz.x / 2.0, 4.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT_COLOR)

	# a többi épület kis piktogramsora a jelölő fölött (ha ott a név, akkor alatta)
	if not extras.is_empty():
		var y := 26.0 if label_side == "above" else -25.0
		var x0 := -(extras.size() - 1) * EXTRA_STEP / 2.0 + 4.0
		for i in extras.size():
			BuildingIcons.draw(self, extras[i], Vector2(x0 + i * EXTRA_STEP, y), EXTRA_ICON)

	var size := FONT.get_string_size(city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var asc := FONT.get_ascent(FONT_SIZE)
	var pos: Vector2
	match label_side:
		"above": pos = Vector2(-size.x / 2.0, -14.0)
		"left":  pos = Vector2(-16.0 - size.x, asc / 2.0 - 2.0)
		"right": pos = Vector2(26.0, asc / 2.0 - 2.0)
		_:       pos = Vector2(-size.x / 2.0, 13.0 + asc)
	draw_string_outline(FONT, pos, city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, OUTLINE)
	draw_string(FONT, pos, city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT_COLOR)

# ── Egyházi épületek (1 kápolna … 6 katedrális) ────────────────
# Oldalnézeti rajz a jelölőtől balra; jobb alsó sarka a CHURCH_ORIGIN pont.

func _shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(Geometry2D.offset_polygon(points, 1.1)[0], OUTLINE)
	draw_colored_polygon(points, fill)

func _box(x0: float, y0: float, x1: float, y1: float, fill: Color) -> void:
	_shape(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), fill)

func _roof(x0: float, x1: float, y: float, peak: float) -> void:
	_shape(PackedVector2Array([Vector2(x0 - 1, y), Vector2(x1 + 1, y), Vector2((x0 + x1) / 2.0, peak)]), ROOF)

func _spire(x0: float, x1: float, y: float, peak: float) -> void:
	_shape(PackedVector2Array([Vector2(x0 - 0.5, y), Vector2(x1 + 0.5, y), Vector2((x0 + x1) / 2.0, peak)]), ROOF)

func _cross(top: Vector2, col: Color) -> void:
	draw_line(top + Vector2(0, 0), top + Vector2(0, -4.5), OUTLINE, 2.6)
	draw_line(top + Vector2(-2, -3), top + Vector2(2, -3), OUTLINE, 2.6)
	draw_line(top + Vector2(0, -0.3), top + Vector2(0, -4.2), col, 1.1)
	draw_line(top + Vector2(-1.7, -3), top + Vector2(1.7, -3), col, 1.1)

func _door(x: float) -> void:
	draw_rect(Rect2(x - 1, -3, 2, 3), OUTLINE)

# ── Óészaki szent helyek (1 vé … 5 királyi szentély) ────────────

# Faragott sárkányfejes oromzat: két keresztbe futó léc a tető csúcsán
func _gable(top: Vector2) -> void:
	for pass_i in 2:
		var col := OUTLINE if pass_i == 0 else DARK_WOOD
		var w := 2.6 if pass_i == 0 else 1.1
		draw_line(top + Vector2(-2.5, 2), top + Vector2(1.5, -3), col, w)
		draw_line(top + Vector2(2.5, 2), top + Vector2(-1.5, -3), col, w)

func _hall(x0: float, x1: float, h: float, peak: float) -> void:
	_box(x0, -h, x1, 0, WOOD)
	_shape(PackedVector2Array([Vector2(x0 - 1.5, -h), Vector2(x1 + 1.5, -h), Vector2((x0 + x1) / 2.0, -peak)]), DARK_WOOD)

func _runestone(x: float, h: float) -> void:
	_shape(PackedVector2Array([Vector2(x - 2, 0), Vector2(x + 2, 0), Vector2(x + 1.6, -h), Vector2(x, -h - 1.5), Vector2(x - 1.6, -h)]), STONE)
	draw_line(Vector2(x - 0.8, -h + 2), Vector2(x + 0.8, -2), RUNE_RED, 0.9)
	draw_line(Vector2(x + 0.8, -h + 2), Vector2(x - 0.8, -2), RUNE_RED, 0.9)

func _draw_hof(level: int) -> void:
	draw_set_transform(CHURCH_ORIGIN, 0.0, Vector2(1.1, 1.1))
	match level:
		1:  # vé: szent kőkör
			for i in 5:
				var a := PI + PI * i / 4.0
				var c := Vector2(-5, -1) + Vector2(cos(a) * 5.0, sin(a) * 2.0)
				draw_circle(c, 1.6, OUTLINE)
				draw_circle(c, 1.0, STONE)
			_runestone(-5, 6)
		2:  # hörgr: felhalmozott kőoltár
			_shape(PackedVector2Array([Vector2(-11, 0), Vector2(0, 0), Vector2(-3, -5), Vector2(-5.5, -8), Vector2(-8, -5)]), STONE)
			draw_circle(Vector2(-5.5, -9), 1.4, RUNE_RED)   # áldozati tűz
		3:  # hof: áldozócsarnok
			_hall(-11, 0, 5, 10)
			_gable(Vector2(-5.5, -10))
			_door(-5.5)
		4:  # nagy hof: hosszú csarnok két oromzattal és rúnakővel
			_hall(-15, 0, 6, 11)
			_gable(Vector2(-7.5, -11))
			_door(-7.5)
			_runestone(-18, 8)
		_:  # királyi szentély: csarnok, sírhalom és rúnakő (Jelling)
			_shape(PackedVector2Array([Vector2(-26, 0), Vector2(-24, -4), Vector2(-21, -6), Vector2(-18, -4), Vector2(-16, 0)]), TURF)
			_hall(-14, 0, 6, 12)
			_gable(Vector2(-7, -12))
			_door(-7)
			_runestone(-19.5, 10)
			draw_circle(Vector2(-7, -14.5), 1.2, GOLD)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_church(level: int) -> void:
	draw_set_transform(CHURCH_ORIGIN, 0.0, Vector2(1.1, 1.1))
	match level:
		1:  # kápolna
			_box(-7, -5, 0, 0, CHURCH_STONE)
			_roof(-7, 0, -5, -9)
			_cross(Vector2(-3.5, -9), TEXT_COLOR)
			_door(-3.5)
		2:  # kistemplom harangtoronnyal
			_box(-10, -6, 0, 0, CHURCH_STONE)
			_roof(-10, 0, -6, -10)
			_box(-6, -13, -4, -9.5, CHURCH_STONE)
			_cross(Vector2(-5, -13), TEXT_COLOR)
			_door(-5)
		3:  # templom nyugati toronnyal
			_box(-10, -6, 0, 0, CHURCH_STONE)
			_roof(-10, 0, -6, -9.5)
			_box(-15, -13, -10, 0, CHURCH_STONE)
			_spire(-15, -10, -13, -17)
			_cross(Vector2(-12.5, -17), TEXT_COLOR)
			_door(-12.5)
		4:  # nagytemplom (minster): hosszú hajó, nyugati és középtorony
			_box(-14, -7, 0, 0, CHURCH_STONE)
			_roof(-14, 0, -7, -11)
			_box(-9, -15, -5, -9, CHURCH_STONE)
			_spire(-9, -5, -15, -19)
			_box(-19, -14, -14, 0, CHURCH_STONE)
			_spire(-19, -14, -14, -18)
			_cross(Vector2(-7, -19), TEXT_COLOR)
			_door(-16.5)
		5:  # bazilika: apszis és kupola
			_box(-15, -7, 0, 0, CHURCH_STONE)
			_roof(-15, 0, -7, -10)
			var apse := PackedVector2Array()
			for i in 9:
				var a := -PI / 2.0 + PI * i / 8.0
				apse.append(Vector2(0, -3.5) + Vector2(cos(a), sin(a)) * 3.5)
			_shape(apse, CHURCH_STONE)
			var dome := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				dome.append(Vector2(-7.5, -9) + Vector2(cos(a), sin(a)) * 4.5)
			_shape(dome, Color(0.62, 0.66, 0.70))
			_cross(Vector2(-7.5, -13.5), GOLD)
			_door(-11)
		_:  # katedrális: két nyugati torony és magas középtorony
			_box(-16, -8, 0, 0, CHURCH_STONE)
			_roof(-16, 0, -8, -12)
			_box(-10, -17, -6, -10, CHURCH_STONE)
			_spire(-10, -6, -17, -23)
			_box(-24, -16, -20, 0, CHURCH_STONE)
			_box(-20, -16, -16, 0, CHURCH_STONE)
			_spire(-24, -20, -16, -21)
			_spire(-20, -16, -16, -21)
			draw_circle(Vector2(-18, -9), 1.8, OUTLINE)   # rózsaablak
			draw_circle(Vector2(-18, -9), 1.0, GOLD)
			_cross(Vector2(-8, -23), GOLD)
			_door(-18)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
