extends Control

## HEPTARCHIA – kis uralkodóportré a király neve alá.
##
## Nincsenek festett képeink, és nem is kellenek: a játékban minden rajz kódból
## készül (épületek, városjelölők, tengeri díszek), ez is úgy. A vonásokat az
## uralkodó nyelvi kulcsából vetett véletlen adja, tehát ugyanaz a király mindig
## ugyanúgy néz ki – mentés és betöltés után, és a hálózat másik gépén is.
##
## A KULTÚRA szabja meg a fejfedőt és a hajviseletet:
##   english / welsh – abroncskorona, rövidre nyírt haj
##   norse           – szarv nélküli, orrvédős sisak, hosszú fonott szakáll
##   norman          – orrvédős sisak, nyírt tarkó, borotvált áll
##   gaelic          – aranyabroncs, hosszú haj és bajusz
##   byzantine       – gyöngyös diadém (a kiegészítők népeinél)
##   slavic/baltic/steppe – prémes süveg

const INK := Color(0.12, 0.08, 0.05)
const BOR := Color(0.85, 0.71, 0.58)        # arcszín
const BOR_ARNY := Color(0.70, 0.56, 0.44)
const ARANY := Color(0.86, 0.70, 0.36)
const VAS := Color(0.62, 0.64, 0.68)
const PREM := Color(0.42, 0.30, 0.20)
# hajszínek: a véletlen ezek közül választ
const HAJ := [Color(0.24, 0.17, 0.11), Color(0.38, 0.24, 0.13), Color(0.55, 0.40, 0.18),
	Color(0.62, 0.52, 0.34), Color(0.72, 0.70, 0.66)]

var kultura: String = "english"
var kulcs: String = ""                      # az uralkodó nyelvi kulcsa (RULER_…)
var szin: Color = Color(0.7, 0.6, 0.4)      # a királyság színe – a köpenyen


func beallit(uj_kulcs: String, uj_kultura: String, uj_szin: Color) -> void:
	if kulcs == uj_kulcs and kultura == uj_kultura and szin == uj_szin:
		return
	kulcs = uj_kulcs
	kultura = uj_kultura
	szin = uj_szin
	queue_redraw()


## Kör alakú sokszög – ehhez vágjuk a köpenyt, hogy ne lógjon ki az éremből.
func _kor_poly(kp: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		out.append(kp + Vector2(cos(a), sin(a)) * r)
	return out


func _rng() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = hash(kulcs)
	return g


func _draw() -> void:
	if kulcs == "":
		return
	var g := _rng()
	var w := size.x
	var h := size.y
	var kp := Vector2(w * 0.5, h * 0.5)
	var r := minf(w, h) * 0.5 - 1.0

	# ── keret: kör alakú érem, a királyság színével ──
	draw_circle(kp, r, INK)
	draw_circle(kp, r - 1.2, szin.darkened(0.55))
	draw_circle(kp, r - 2.6, Color(0.16, 0.12, 0.09))

	# ── váll és köpeny ──
	# Az érembe VÁGVA: enélkül a köpeny kilógott a kör alól.
	var vall := PackedVector2Array([
		kp + Vector2(-r * 0.92, r * 1.30), kp + Vector2(-r * 0.54, r * 0.20),
		kp + Vector2(r * 0.54, r * 0.20), kp + Vector2(r * 0.92, r * 1.30)])
	for darab in Geometry2D.intersect_polygons(vall, _kor_poly(kp, r - 2.6)):
		draw_colored_polygon(darab, szin.darkened(0.25))

	# ── arc ──
	var arc_sz := r * 0.50
	var arc_kp := kp + Vector2(0.0, -r * 0.10)
	draw_circle(arc_kp + Vector2(r * 0.06, r * 0.04), arc_sz, BOR_ARNY)
	draw_circle(arc_kp, arc_sz, BOR)

	var haj_szin: Color = HAJ[g.randi() % HAJ.size()]
	var szakall: bool = g.randf() < (0.85 if kultura == "norse" else 0.55)

	# ── szakáll (az áll körül; az arcnak maradjon szabad fele) ──
	if szakall:
		var hossz := arc_sz * (1.20 if kultura == "norse" else 0.98)
		draw_colored_polygon(PackedVector2Array([
			arc_kp + Vector2(-arc_sz * 0.88, arc_sz * 0.24),
			arc_kp + Vector2(arc_sz * 0.88, arc_sz * 0.24),
			arc_kp + Vector2(arc_sz * 0.52, hossz),
			arc_kp + Vector2(-arc_sz * 0.52, hossz)]), haj_szin)
	# bajusz mindenkinek, akinek szakálla van, és a gaeleknek külön is
	if szakall or kultura == "gaelic":
		draw_rect(Rect2(arc_kp.x - arc_sz * 0.62, arc_kp.y + arc_sz * 0.06, arc_sz * 1.24, arc_sz * 0.20),
			haj_szin.darkened(0.12), true)

	# ── szem ──
	var szem_y := arc_kp.y - arc_sz * 0.18
	for oldal in [-1.0, 1.0]:
		draw_circle(Vector2(arc_kp.x + oldal * arc_sz * 0.36, szem_y), maxf(1.0, arc_sz * 0.13), INK)

	# ── haj és fejfedő kultúránként ──
	match kultura:
		"norse", "norman":
			# orrvédős sisak
			var sisak := PackedVector2Array([
				arc_kp + Vector2(-arc_sz * 1.06, -arc_sz * 0.12),
				arc_kp + Vector2(-arc_sz * 0.86, -arc_sz * 1.02),
				arc_kp + Vector2(arc_sz * 0.86, -arc_sz * 1.02),
				arc_kp + Vector2(arc_sz * 1.06, -arc_sz * 0.12)])
			draw_colored_polygon(sisak, VAS)
			draw_line(arc_kp + Vector2(0, -arc_sz * 1.02), arc_kp + Vector2(0, arc_sz * 0.02), VAS.darkened(0.3), maxf(1.4, arc_sz * 0.20))
			draw_line(arc_kp + Vector2(-arc_sz * 1.0, -arc_sz * 0.16), arc_kp + Vector2(arc_sz * 1.0, -arc_sz * 0.16),
				VAS.lightened(0.25), maxf(1.2, arc_sz * 0.14))
		"gaelic":
			_haj_hosszu(arc_kp, arc_sz, haj_szin)
			_abroncs(arc_kp, arc_sz, ARANY, false)
		"byzantine":
			_haj_hosszu(arc_kp, arc_sz, haj_szin)
			_abroncs(arc_kp, arc_sz, ARANY, false)
			# gyöngyfüggők a diadém két oldalán
			for oldal in [-1.0, 1.0]:
				draw_line(arc_kp + Vector2(oldal * arc_sz * 0.96, -arc_sz * 0.40),
					arc_kp + Vector2(oldal * arc_sz * 0.96, arc_sz * 0.30), Color(0.95, 0.93, 0.88), maxf(1.0, arc_sz * 0.12))
		"slavic", "baltic", "steppe":
			# prémes süveg
			draw_colored_polygon(PackedVector2Array([
				arc_kp + Vector2(-arc_sz * 0.94, -arc_sz * 0.44),
				arc_kp + Vector2(-arc_sz * 0.74, -arc_sz * 1.32),
				arc_kp + Vector2(arc_sz * 0.74, -arc_sz * 1.32),
				arc_kp + Vector2(arc_sz * 0.94, -arc_sz * 0.44)]), szin.darkened(0.35))
			draw_rect(Rect2(arc_kp.x - arc_sz * 1.0, arc_kp.y - arc_sz * 0.62, arc_sz * 2.0, arc_sz * 0.34), PREM, true)
		_:
			_haj_rovid(arc_kp, arc_sz, haj_szin)
			_abroncs(arc_kp, arc_sz, ARANY, true)

	# ── a körvonal záródjon: vékony tus a peremen ──
	draw_arc(kp, r - 2.0, 0.0, TAU, 32, INK, 1.2)


func _haj_rovid(arc_kp: Vector2, arc_sz: float, haj_szin: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		arc_kp + Vector2(-arc_sz * 1.0, -arc_sz * 0.20),
		arc_kp + Vector2(-arc_sz * 0.82, -arc_sz * 0.94),
		arc_kp + Vector2(arc_sz * 0.82, -arc_sz * 0.94),
		arc_kp + Vector2(arc_sz * 1.0, -arc_sz * 0.20)]), haj_szin)


func _haj_hosszu(arc_kp: Vector2, arc_sz: float, haj_szin: Color) -> void:
	# a fülek mellett leomló haj
	for oldal in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			arc_kp + Vector2(oldal * arc_sz * 0.72, -arc_sz * 0.80),
			arc_kp + Vector2(oldal * arc_sz * 1.10, -arc_sz * 0.30),
			arc_kp + Vector2(oldal * arc_sz * 1.02, arc_sz * 0.72),
			arc_kp + Vector2(oldal * arc_sz * 0.66, arc_sz * 0.30)]), haj_szin)
	_haj_rovid(arc_kp, arc_sz, haj_szin)


func _abroncs(arc_kp: Vector2, arc_sz: float, col: Color, csucsos: bool) -> void:
	var y := arc_kp.y - arc_sz * 0.74
	draw_rect(Rect2(arc_kp.x - arc_sz * 0.98, y, arc_sz * 1.96, arc_sz * 0.28), col, true)
	draw_rect(Rect2(arc_kp.x - arc_sz * 0.98, y, arc_sz * 1.96, arc_sz * 0.28), INK, false, 1.0)
	if csucsos:
		# három kis liliom az abroncson
		for i in 3:
			var x := arc_kp.x + (-0.62 + i * 0.62) * arc_sz
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - arc_sz * 0.16, y), Vector2(x + arc_sz * 0.16, y),
				Vector2(x, y - arc_sz * 0.34)]), col)
