extends Node2D

# HEPTARCHIA – történelmi ezüstlelőhely jelölése a térképen (keresztbe tett csákány és kalapács).
# Halvány, amíg nincs bánya; ezüstösen csillog, ha a provinciában már működik.
# A térkép-világ gyereke; a MapView a nagyítás reciprokával skálázza.

const INK := Color(0.12, 0.08, 0.04)
const IDLE := Color(0.62, 0.60, 0.56, 0.75)
const ACTIVE := Color(0.92, 0.93, 0.97)
const HANDLE := Color(0.55, 0.36, 0.18)

var active: bool = false

func set_active(v: bool) -> void:
	if v != active:
		active = v
		queue_redraw()

func _tool(angle: float, head_is_pick: bool) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := dir.orthogonal()
	var a := -dir * 6.0
	var b := dir * 6.0
	var metal := ACTIVE if active else IDLE
	for pass_i in 2:
		var w_h := 3.6 if pass_i == 0 else 1.8
		var w_m := 4.4 if pass_i == 0 else 2.4
		var ch := INK if pass_i == 0 else (HANDLE if active else IDLE.darkened(0.25))
		var cm := INK if pass_i == 0 else metal
		draw_line(a, b, ch, w_h)
		if head_is_pick:
			draw_line(b - perp * 5.0 - dir * 1.5, b + perp * 5.0 - dir * 1.5, cm, w_m)
		else:
			draw_line(b - perp * 3.0, b + perp * 3.0, cm, w_m + 1.5)

func _draw() -> void:
	if active:
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.95, 0.7, 0.25))
	_tool(-PI * 0.75, true)
	_tool(-PI * 0.25, false)
