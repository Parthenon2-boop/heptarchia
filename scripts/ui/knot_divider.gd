@tool
extends Control

# HEPTARCHIA – angolszász fonatminta (két egymásba fonódó szál) díszítő elválasztónak.
# Minden kereszteződésnél felváltva a másik szál kerül felülre.

@export var strand_color: Color = Color(0.80, 0.61, 0.29):
	set(v): strand_color = v; queue_redraw()
@export var outline_color: Color = Color(0.10, 0.06, 0.03):
	set(v): outline_color = v; queue_redraw()
@export var period: float = 22.0:
	set(v): period = maxf(v, 6.0); queue_redraw()
@export var thickness: float = 2.2:
	set(v): thickness = v; queue_redraw()

const SEGMENT_STEPS := 8

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if custom_minimum_size.y < 14.0:
		custom_minimum_size.y = 14.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _strand(x0: float, x1: float, sign_: float, mid: float, amp: float, half: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in SEGMENT_STEPS + 1:
		var x := lerpf(x0, x1, float(i) / SEGMENT_STEPS)
		pts.append(Vector2(x, mid + sign_ * amp * sin(PI * x / half)))
	return pts

func _draw() -> void:
	var w := size.x
	var mid := size.y / 2.0
	var amp := mid - thickness - 1.5
	var half := period / 2.0
	draw_line(Vector2(0, 1), Vector2(w, 1), Color(strand_color, 0.35), 1.0)
	draw_line(Vector2(0, size.y - 1), Vector2(w, size.y - 1), Color(strand_color, 0.35), 1.0)
	# Szegmensek csúcstól csúcsig; mindegyikben pontosan egy kereszteződés van
	var k := 0
	while (k - 0.5) * half < w:
		var x0 := maxf((k - 0.5) * half, 0.0)
		var x1 := minf((k + 0.5) * half, w)
		var a := _strand(x0, x1, 1.0, mid, amp, half)
		var b := _strand(x0, x1, -1.0, mid, amp, half)
		var under := a if k % 2 == 0 else b
		var over := b if k % 2 == 0 else a
		for pts in [under, over]:
			draw_polyline(pts, outline_color, thickness + 2.2, true)
			draw_polyline(pts, strand_color, thickness, true)
		k += 1
	# Végek: kis rombuszok
	for x in [3.0, w - 3.0]:
		var d := PackedVector2Array([Vector2(x, mid - 4), Vector2(x + 3, mid), Vector2(x, mid + 4), Vector2(x - 3, mid)])
		draw_colored_polygon(d, strand_color)
