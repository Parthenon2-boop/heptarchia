class_name BuildingIcons
extends RefCounted

# HEPTARCHIA – épület- és akció-piktogramok
#
# Egy helyen rajzoljuk őket, hogy a jobb oldali panel, az építési gombok és a
# térkép városjelölője ugyanazt a képet mutassa. Minden ikon egy 16×16-os
# dobozban van megrajzolva (középpont: 0,0), a draw() a kívánt méretre nagyít.
# Bármelyik CanvasItemre rajzolható (Control vagy Node2D), sötét körvonallal,
# hogy pergamenen és térképen is kivehető legyen.

const OUTLINE := Color(0.18, 0.12, 0.06)
const STONE := Color(0.74, 0.72, 0.68)
const LIGHT_STONE := Color(0.90, 0.86, 0.76)
const ROOF := Color(0.62, 0.28, 0.15)
const WOOD := Color(0.58, 0.38, 0.20)
const DARK_WOOD := Color(0.38, 0.23, 0.12)
const GOLD := Color(0.97, 0.80, 0.33)
const WHEAT := Color(0.93, 0.76, 0.32)
const IRON := Color(0.70, 0.74, 0.80)
const SEA := Color(0.62, 0.78, 0.92)
const CLOTH_RED := Color(0.78, 0.22, 0.16)
const CLOTH_WHITE := Color(0.96, 0.93, 0.85)
const GREEN := Color(0.45, 0.62, 0.32)

## Az ismert ikonok (a többire nem rajzolunk semmit)
const KINDS := ["burh", "church", "hof", "farm", "village", "tower", "port", "mine", "mint", "market",
	"barracks", "ship", "fyrd", "thegn", "elite", "general", "order"]

static func has_icon(kind: String) -> bool:
	return kind in KINDS

static func draw(ci: CanvasItem, kind: String, center: Vector2, size: float = 16.0) -> void:
	var k := size / 16.0
	ci.draw_set_transform(center, 0.0, Vector2(k, k))
	match kind:
		"burh": _burh(ci)
		"church": _church(ci)
		"hof": _hof(ci)
		"farm": _farm(ci)
		"village": _village(ci)
		"tower": _tower(ci)
		"port": _anchor(ci)
		"mine": _pick(ci)
		"mint": _coin(ci)
		"market": _stall(ci)
		"barracks": _shield(ci)
		"ship": _ship(ci)
		"fyrd": _spear(ci)
		"thegn": _helmet(ci)
		"elite": _banner(ci)
		"general": _star(ci)
		"order": _scales(ci)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ── alapelemek ───────────────────────────────────────────────

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color) -> void:
	var o := Geometry2D.offset_polygon(pts, 1.1)
	if not o.is_empty(): ci.draw_colored_polygon(o[0], OUTLINE)
	ci.draw_colored_polygon(pts, fill)

static func _rect(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, fill: Color) -> void:
	_poly(ci, PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]), fill)

static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, OUTLINE, w + 2.0)
	ci.draw_line(a, b, col, w)

static func _circle(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ci.draw_circle(c, r + 1.1, OUTLINE)
	ci.draw_circle(c, r, fill)

static func _house(ci: CanvasItem, x0: float, x1: float, base: float, h: float, roof_h: float) -> void:
	_rect(ci, x0, base - h, x1, base, LIGHT_STONE)
	_poly(ci, PackedVector2Array([Vector2(x0 - 1, base - h), Vector2(x1 + 1, base - h),
		Vector2((x0 + x1) / 2.0, base - h - roof_h)]), ROOF)

# ── ikonok ───────────────────────────────────────────────────

static func _burh(ci: CanvasItem) -> void:
	_rect(ci, -6.5, -2, 6.5, 6.5, STONE)
	for x in [-6.5, -1.5, 3.5]:
		_rect(ci, x, -6, x + 3, -2, STONE)
	ci.draw_rect(Rect2(-1.3, 2, 2.6, 4.5), OUTLINE)

static func _church(ci: CanvasItem) -> void:
	_house(ci, -6, 2, 6.5, 6, 4)
	_rect(ci, 2, -4, 6, 6.5, LIGHT_STONE)
	_poly(ci, PackedVector2Array([Vector2(1.5, -4), Vector2(6.5, -4), Vector2(4, -8)]), ROOF)
	_line(ci, Vector2(4, -8), Vector2(4, -11.5), GOLD, 1.0)
	_line(ci, Vector2(2.6, -10.2), Vector2(5.4, -10.2), GOLD, 1.0)
	ci.draw_rect(Rect2(-3, 3, 2, 3.5), OUTLINE)

static func _hof(ci: CanvasItem) -> void:
	_rect(ci, -6.5, -1, 6.5, 6.5, WOOD)
	_poly(ci, PackedVector2Array([Vector2(-8, -1), Vector2(8, -1), Vector2(0, -7)]), DARK_WOOD)
	# faragott sárkányfejes oromzat
	_line(ci, Vector2(-2.5, -5), Vector2(1.5, -10), DARK_WOOD, 1.1)
	_line(ci, Vector2(2.5, -5), Vector2(-1.5, -10), DARK_WOOD, 1.1)
	ci.draw_rect(Rect2(-1.2, 2.5, 2.4, 4), OUTLINE)

static func _farm(ci: CanvasItem) -> void:
	# kéve: három szár, fölül kalászok, középen kötés
	for i in 3:
		var dx := (i - 1) * 3.0
		_line(ci, Vector2(dx * 0.4, 7), Vector2(dx, -3), WHEAT, 1.3)
		_poly(ci, PackedVector2Array([Vector2(dx - 1.6, -3), Vector2(dx, -8.5), Vector2(dx + 1.6, -3), Vector2(dx, -1.5)]), WHEAT)
	_line(ci, Vector2(-2.5, 2.5), Vector2(2.5, 2.5), WOOD, 1.4)

static func _village(ci: CanvasItem) -> void:
	_house(ci, -7, -1, 6.5, 5, 3.5)
	_house(ci, 0, 7, 6.5, 7, 4.5)
	ci.draw_rect(Rect2(2.7, 3, 1.8, 3.5), OUTLINE)

static func _tower(ci: CanvasItem) -> void:
	_rect(ci, -3.5, -4, 3.5, 7, STONE)
	_rect(ci, -5, -8, 5, -4, STONE)
	for x in [-5.0, -1.0, 3.0]:
		_rect(ci, x, -10, x + 2, -8, STONE)
	ci.draw_rect(Rect2(-0.8, -1, 1.6, 2.5), OUTLINE)

static func _anchor(ci: CanvasItem) -> void:
	_line(ci, Vector2(0, -6), Vector2(0, 6), IRON, 1.6)
	_line(ci, Vector2(-3.5, -3.5), Vector2(3.5, -3.5), IRON, 1.6)
	ci.draw_arc(Vector2(0, 1.5), 5.5, 0.25, PI - 0.25, 12, OUTLINE, 3.6)
	ci.draw_arc(Vector2(0, 1.5), 5.5, 0.25, PI - 0.25, 12, IRON, 1.6)
	_circle(ci, Vector2(0, -7.2), 1.6, SEA)

static func _pick(ci: CanvasItem) -> void:
	_line(ci, Vector2(-5, 7), Vector2(4, -4), WOOD, 1.8)
	var head := PackedVector2Array()
	for i in 9:
		var a := -PI * 0.95 + PI * 0.9 * i / 8.0
		head.append(Vector2(3, -2) + Vector2(cos(a + 0.8), sin(a + 0.8)) * 7.0)
	for i in range(8, -1, -1):
		var a := -PI * 0.95 + PI * 0.9 * i / 8.0
		head.append(Vector2(3, -2) + Vector2(cos(a + 0.8), sin(a + 0.8)) * 5.2)
	_poly(ci, head, IRON)

static func _coin(ci: CanvasItem) -> void:
	_circle(ci, Vector2.ZERO, 6.5, GOLD)
	ci.draw_arc(Vector2.ZERO, 4.6, 0.0, TAU, 20, Color(0.72, 0.52, 0.16), 1.0)
	ci.draw_line(Vector2(0, -2.8), Vector2(0, 2.8), Color(0.60, 0.42, 0.12), 1.2)
	ci.draw_line(Vector2(-2.8, 0), Vector2(2.8, 0), Color(0.60, 0.42, 0.12), 1.2)

static func _stall(ci: CanvasItem) -> void:
	_rect(ci, -6, 1, 6, 6.5, WOOD)
	_line(ci, Vector2(-6, -3), Vector2(-6, 6.5), DARK_WOOD, 1.0)
	_line(ci, Vector2(6, -3), Vector2(6, 6.5), DARK_WOOD, 1.0)
	# csíkos ponyva
	_poly(ci, PackedVector2Array([Vector2(-7.5, -3), Vector2(7.5, -3), Vector2(6, -7.5), Vector2(-6, -7.5)]), CLOTH_WHITE)
	for i in 3:
		var x := -6.0 + i * 4.5
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 1.2, -3), Vector2(x + 1.3, -3),
			Vector2(x + 1.1, -7.5), Vector2(x - 0.9, -7.5)]), CLOTH_RED)
	_circle(ci, Vector2(-2.5, -0.5), 1.3, GREEN)
	_circle(ci, Vector2(1.5, -0.5), 1.3, GOLD)

static func _shield(ci: CanvasItem) -> void:
	# kerek pajzs két keresztbe tett lándzsa előtt
	_line(ci, Vector2(-7, 7), Vector2(7, -7), WOOD, 1.2)
	_line(ci, Vector2(7, 7), Vector2(-7, -7), WOOD, 1.2)
	_circle(ci, Vector2.ZERO, 5.2, CLOTH_RED)
	ci.draw_arc(Vector2.ZERO, 3.6, 0.0, TAU, 18, GOLD, 1.0)
	_circle(ci, Vector2.ZERO, 1.4, IRON)

static func _ship(ci: CanvasItem) -> void:
	_poly(ci, PackedVector2Array([Vector2(-8, 2), Vector2(8, 2), Vector2(5, 6), Vector2(-5, 6)]), WOOD)
	_line(ci, Vector2(0, 2), Vector2(0, -8), DARK_WOOD, 1.0)
	_poly(ci, PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(5, 0), Vector2(-5, 0)]), CLOTH_WHITE)
	ci.draw_rect(Rect2(-5, -4.5, 10, 2), CLOTH_RED)

static func _spear(ci: CanvasItem) -> void:
	_line(ci, Vector2(-5, 7), Vector2(4, -5), WOOD, 1.3)
	_poly(ci, PackedVector2Array([Vector2(3, -3.5), Vector2(7, -8), Vector2(5.5, -2)]), IRON)
	_circle(ci, Vector2(-1, 2), 4.2, CLOTH_RED)
	_circle(ci, Vector2(-1, 2), 1.2, IRON)

static func _helmet(ci: CanvasItem) -> void:
	var dome := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		dome.append(Vector2(0, 1) + Vector2(cos(a), sin(a)) * 6.5)
	dome.append(Vector2(6.5, 5)); dome.append(Vector2(-6.5, 5))
	_poly(ci, dome, IRON)
	ci.draw_rect(Rect2(-1, 0, 2, 6), OUTLINE)    # orrvédő
	_line(ci, Vector2(-6.5, 1.5), Vector2(6.5, 1.5), GOLD, 1.0)
	_line(ci, Vector2(0, -5.5), Vector2(0, 1), GOLD, 1.0)

static func _banner(ci: CanvasItem) -> void:
	# hadi zászló: rúd, rajta fecskefarkú lobogó – a nép különleges csapata
	_line(ci, Vector2(-5, 7.5), Vector2(-5, -8), DARK_WOOD, 1.3)
	_poly(ci, PackedVector2Array([Vector2(-4.5, -7.5), Vector2(7, -6), Vector2(3.5, -3), Vector2(7, 0), Vector2(-4.5, 0.5)]), CLOTH_RED)
	_circle(ci, Vector2(-0.5, -3.5), 1.4, GOLD)
	_circle(ci, Vector2(-5, -8.8), 1.0, GOLD)

static func _star(ci: CanvasItem) -> void:
	# a hadvezér jele: ötágú csillag
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + PI * i / 5.0
		var r := 7.5 if i % 2 == 0 else 3.2
		pts.append(Vector2(cos(a), sin(a)) * r + Vector2(0, 0.8))
	_poly(ci, pts, GOLD)

static func _scales(ci: CanvasItem) -> void:
	_line(ci, Vector2(0, -7), Vector2(0, 6), GOLD, 1.2)
	_line(ci, Vector2(-4, 6.5), Vector2(4, 6.5), GOLD, 1.4)
	_line(ci, Vector2(-6.5, -5), Vector2(6.5, -5), GOLD, 1.2)
	for x in [-5.0, 5.0]:
		ci.draw_line(Vector2(x, -5), Vector2(x - 2.5, 0), OUTLINE, 1.0)
		ci.draw_line(Vector2(x, -5), Vector2(x + 2.5, 0), OUTLINE, 1.0)
		_poly(ci, PackedVector2Array([Vector2(x - 3, 0), Vector2(x + 3, 0), Vector2(x + 1.8, 2), Vector2(x - 1.8, 2)]), GOLD)


## Egy kész ikon-vezérlő a felülethez (pl. gombra, listába)
class Icon extends Control:
	var kind := ""
	var icon_size := 16.0

	func _init(k: String = "", s: float = 16.0) -> void:
		kind = k
		icon_size = s
		custom_minimum_size = Vector2(s + 2.0, s + 2.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		BuildingIcons.draw(self, kind, size / 2.0, icon_size)
