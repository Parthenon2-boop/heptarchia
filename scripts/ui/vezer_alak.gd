extends RefCounted

# A hadvezér alakja a csatacsíkon (scripts/ui/csata_csik.gd): egyszerű, kódból rajzolt figura a sereg élén, a nép
# színével – lovas, az ókorban harci szekeres vagy gyalogos is lehet –, a neve a feje fölött.
#   VezerAlak.rajzol(vaszon, talppont, magasság, szín, irány (+1 jobbra néz, −1 balra), stílus, idő, átlátszóság, név, betű)
# stílus: "lovas", "szeker", "gyalog" (hajón, vagy ahol még nem ültek lóra)

const INK := Color(0.10, 0.07, 0.05)
const BOR := Color(0.86, 0.70, 0.55)
const LO := Color(0.36, 0.25, 0.16)
const LO_VIL := Color(0.52, 0.38, 0.25)
const FEM := Color(0.84, 0.82, 0.76)
const ARANY := Color(0.93, 0.78, 0.36)

static func _sz(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * a)

## A figura. p: a talppont (a föld szintje, a figura közepe alatt), h: a teljes magasság
static func rajzol(ci: CanvasItem, p: Vector2, h: float, szin: Color, irany: float, stilus: String, t: float, alfa: float = 1.0,
		nev: String = "", font: Font = null, nev_dy: float = 0.0) -> void:
	if alfa <= 0.01 or h < 8.0: return
	var s := h / 40.0                      # a rajz 40 egység magas
	var d := 1.0 if irany >= 0.0 else -1.0
	var ring := sin(t * 7.0) * 0.8 * s      # a ló lépte
	var fej_y := 0.0
	match stilus:
		"gyalog":
			fej_y = _ember(ci, p + Vector2(0, 0), s, d, szin, alfa, true)
		"szeker":
			_lo(ci, p + Vector2(9.0 * s * d, ring * 0.5), s * 0.85, d, t, alfa)
			# a szekér: kerék, kosár, rúd
			var k := p + Vector2(-8.0 * s * d, -5.0 * s)
			ci.draw_line(k + Vector2(4.0 * s * d, -1.0 * s), p + Vector2(8.0 * s * d, -9.0 * s), _sz(INK, alfa), 1.5 * s)
			ci.draw_rect(Rect2(k + Vector2(-5.0 * s, -8.0 * s), Vector2(10.0 * s, 7.0 * s)), _sz(szin.darkened(0.25), alfa))
			ci.draw_rect(Rect2(k + Vector2(-5.0 * s, -8.0 * s), Vector2(10.0 * s, 7.0 * s)), _sz(INK, alfa), false, 1.0)
			ci.draw_circle(k, 5.0 * s, _sz(INK, alfa))
			ci.draw_circle(k, 3.6 * s, _sz(Color(0.55, 0.40, 0.22), alfa))
			for i in 4:
				var a := t * 6.0 * d + float(i) * PI / 4.0
				ci.draw_line(k - Vector2(cos(a), sin(a)) * 3.6 * s, k + Vector2(cos(a), sin(a)) * 3.6 * s, _sz(INK, alfa), 1.0)
			fej_y = _ember(ci, k + Vector2(0, -7.0 * s), s * 0.8, d, szin, alfa, false)
		_:
			_lo(ci, p + Vector2(0, ring * 0.5), s, d, t, alfa)
			fej_y = _ember(ci, p + Vector2(-1.0 * s * d, -15.0 * s + ring), s * 0.8, d, szin, alfa, false)
	if nev != "" and font != null:
		var m := 13
		var w := font.get_string_size(nev, HORIZONTAL_ALIGNMENT_LEFT, -1, m).x
		# a név a figura fölött, a sereg belseje felé igazítva (a csatatér közepén a két név ne érjen össze)
		var x := p.x - w + 12.0 * s if d > 0.0 else p.x - 12.0 * s
		var vw: float = ci.size.x if ci is Control else 100000.0
		x = clampf(x, 2.0, maxf(2.0, vw - w - 2.0))
		var y := fej_y - 6.0 * s + nev_dy
		ci.draw_string_outline(font, Vector2(x, y), nev, HORIZONTAL_ALIGNMENT_LEFT, -1, m, 4, _sz(INK, alfa))
		ci.draw_string(font, Vector2(x, y), nev, HORIZONTAL_ALIGNMENT_LEFT, -1, m, _sz(ARANY, alfa))

# a ló (a talppont a hasa alatt): törzs, nyak, fej, lábak, farok
static func _lo(ci: CanvasItem, p: Vector2, s: float, d: float, t: float, alfa: float) -> void:
	var test := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		test.append(p + Vector2(cos(a) * 11.0 * s, -15.0 * s + sin(a) * 5.0 * s))
	for i in 4:
		var x := (-8.0 + float(i) * 5.2) * s * d
		var leng := sin(t * 7.0 + float(i) * 1.7) * 2.2 * s
		ci.draw_line(p + Vector2(x, -12.0 * s), p + Vector2(x + leng * d, 0), _sz(INK, alfa), 2.2 * s)
		ci.draw_line(p + Vector2(x, -12.0 * s), p + Vector2(x + leng * d, -0.5 * s), _sz(LO, alfa), 1.2 * s)
	ci.draw_colored_polygon(test, _sz(LO, alfa))
	ci.draw_polyline(test + PackedVector2Array([test[0]]), _sz(INK, alfa), 1.0)
	# nyak és fej
	var nyak := PackedVector2Array([p + Vector2(7.0 * s * d, -18.0 * s), p + Vector2(13.0 * s * d, -27.0 * s),
		p + Vector2(18.5 * s * d, -24.0 * s), p + Vector2(15.5 * s * d, -22.5 * s), p + Vector2(11.5 * s * d, -14.0 * s)])
	ci.draw_colored_polygon(nyak, _sz(LO_VIL, alfa))
	ci.draw_polyline(nyak + PackedVector2Array([nyak[0]]), _sz(INK, alfa), 1.0)
	ci.draw_line(p + Vector2(9.0 * s * d, -22.0 * s), p + Vector2(12.0 * s * d, -27.0 * s), _sz(INK, alfa), 1.6 * s)   # sörény
	# farok
	ci.draw_line(p + Vector2(-10.5 * s * d, -16.0 * s), p + Vector2(-15.0 * s * d, -9.0 * s + sin(t * 5.0) * s), _sz(INK, alfa), 1.8 * s)

# a vezér (a talppont a lába / a nyereg): köpeny a nép színével, sisak forgóval, felemelt kard. Visszaadja a feje tetejét (y)
static func _ember(ci: CanvasItem, p: Vector2, s: float, d: float, szin: Color, alfa: float, labbal: bool) -> float:
	var csipo := p + Vector2(0, -9.0 * s if labbal else 0.0)
	if labbal:
		ci.draw_line(csipo, p + Vector2(-2.5 * s, 0), _sz(INK, alfa), 2.4 * s)
		ci.draw_line(csipo, p + Vector2(2.5 * s, 0), _sz(INK, alfa), 2.4 * s)
	else:
		ci.draw_line(csipo, csipo + Vector2(2.0 * s * d, 7.0 * s), _sz(INK, alfa), 2.4 * s)      # a láb a ló oldalán
	var vall := csipo + Vector2(0, -11.0 * s)
	# köpeny (hátrafelé lobog) és törzs
	var kopeny := PackedVector2Array([vall + Vector2(-1.0 * s * d, 0), csipo + Vector2(-7.0 * s * d, 1.0 * s), csipo + Vector2(-1.0 * s * d, 0)])
	ci.draw_colored_polygon(kopeny, _sz(szin.darkened(0.2), alfa))
	var torzs := PackedVector2Array([vall + Vector2(-3.2 * s, 0), vall + Vector2(3.2 * s, 0), csipo + Vector2(2.6 * s, 0), csipo + Vector2(-2.6 * s, 0)])
	ci.draw_colored_polygon(torzs, _sz(szin, alfa))
	ci.draw_polyline(torzs + PackedVector2Array([torzs[0]]), _sz(INK, alfa), 1.0)
	# fej, sisak, forgó
	var fej := vall + Vector2(0.5 * s * d, -3.6 * s)
	ci.draw_circle(fej, 3.2 * s, _sz(INK, alfa))
	ci.draw_circle(fej, 2.5 * s, _sz(BOR, alfa))
	ci.draw_arc(fej, 2.9 * s, PI, TAU, 8, _sz(FEM, alfa), 1.6 * s)
	ci.draw_line(fej + Vector2(0, -3.0 * s), fej + Vector2(-2.5 * s * d, -6.5 * s), _sz(Color(0.78, 0.16, 0.14), alfa), 2.0 * s)
	# a felemelt kard
	var kez := vall + Vector2(5.0 * s * d, -2.0 * s)
	ci.draw_line(vall + Vector2(2.5 * s * d, 1.0 * s), kez, _sz(INK, alfa), 1.8 * s)
	ci.draw_line(kez, kez + Vector2(4.0 * s * d, -8.0 * s), _sz(INK, alfa), 2.2 * s)
	ci.draw_line(kez, kez + Vector2(4.0 * s * d, -8.0 * s), _sz(FEM, alfa), 1.1 * s)
	return fej.y - 6.5 * s
