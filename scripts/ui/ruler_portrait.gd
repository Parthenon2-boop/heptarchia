extends Control

## HEPTARCHIA – uralkodói arckép a király neve alá.
##
## A Birodalom festett királyképeinek a mintájára készül: NÉGYZETES, a teljes
## felületet kitöltő mellkép, nem érem. Ugyanaz a hármas értékrend, mint amott –
## tompa belső tér a háttérben, világos arc középen, sötét palást alul –, és
## ugyanúgy van rangjelzője (korona vagy sisak) meg prémgallérja.
##
## Nincsenek festett képeink, és nem is kellenek: a játékban minden rajz kódból
## készül (épületek, városjelölők, tengeri díszek), ez is úgy. A vonásokat az
## uralkodó nyelvi kulcsából vetett véletlen adja, tehát ugyanaz a király mindig
## ugyanúgy néz ki – mentés és betöltés után, és a hálózat másik gépén is.
##
## A rétegek sorrendje fontos: hosszú haj → arc → szakáll → vonások → bajusz →
## hajtető → fejfedő. Ha a hajat vagy a szakállt a vonások UTÁN rajzolnánk,
## eltakarnák a szemet és a szájat.
##
## A KULTÚRA szabja meg a fejfedőt és a hajviseletet:
##   english / welsh – leveles korona, rövidre nyírt haj, hermelingallér
##   norse           – orrvédős sisak, hosszú fonott szakáll, prémgallér
##   norman          – orrvédős sisak, nyírt tarkó, borotvált áll
##   gaelic          – aranyabroncs, hosszú haj és bajusz
##   byzantine       – gyöngyös diadém, oldalt lógó gyöngyfüggőkkel
##   slavic/baltic/steppe – prémes süveg

const INK := Color(0.10, 0.07, 0.05)
const BOR := Color(0.85, 0.70, 0.56)        # arcszín
const BOR_ARNY := Color(0.67, 0.51, 0.40)
const BOR_FENY := Color(0.95, 0.84, 0.71)
const ARANY := Color(0.83, 0.66, 0.30)
const ARANY_FENY := Color(0.97, 0.87, 0.55)
const VAS := Color(0.58, 0.60, 0.65)
const PREM := Color(0.92, 0.89, 0.83)       # hermelin
const SZOR := Color(0.38, 0.27, 0.18)       # egyszerű prém
const HATTER_VIL := Color(0.46, 0.40, 0.32)
const HATTER_SOT := Color(0.15, 0.12, 0.10)
# hajszínek: a véletlen ezek közül választ
const HAJ := [Color(0.18, 0.12, 0.08), Color(0.33, 0.20, 0.11), Color(0.50, 0.34, 0.15),
	Color(0.62, 0.50, 0.30), Color(0.72, 0.70, 0.66)]
# az ékkövek a koronán és a paláston
const KOVEK := [Color(0.74, 0.14, 0.16), Color(0.15, 0.33, 0.63), Color(0.14, 0.47, 0.27)]
# Uralkodónők: nekik nem növesztünk szakállt, és mindig hosszú hajat kapnak.
const NOI := ["RULER_AETHELFLAED", "RULER_AELFWYNN", "RULER_RUS_OLGA",
	"RULER_BYZ_IRENE", "RULER_BYZ_IRENE_CONSTANTINE", "RULER_BYZ_THEODORA"]

var kultura: String = "english"
var kulcs: String = ""                      # az uralkodó nyelvi kulcsa (RULER_…)
var szin: Color = Color(0.7, 0.6, 0.4)      # a királyság színe – a paláston


func beallit(uj_kulcs: String, uj_kultura: String, uj_szin: Color) -> void:
	if kulcs == uj_kulcs and kultura == uj_kultura and szin == uj_szin:
		return
	kulcs = uj_kulcs
	kultura = uj_kultura
	szin = uj_szin
	queue_redraw()


func _rng() -> RandomNumberGenerator:
	var g := RandomNumberGenerator.new()
	g.seed = hash(kulcs)
	return g


## Tojásdad fejforma: felül szélesebb koponya, lefelé keskenyedő áll.
func _fej_poly(kp: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		var sy := sin(a)
		var keskeny := 1.0 - 0.24 * maxf(0.0, sy)
		out.append(kp + Vector2(cos(a) * rx * keskeny, sy * ry))
	return out


## Félkör alakú kupola (a koponyatetőhöz, sisakhoz, hajhoz). Az ív a bal
## szélétől a jobb széléig megy, majd a két alsó sarok zárja a sokszöget.
func _kupola(kp: Vector2, rx: float, ry: float, also_y: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var a := PI + PI * float(i) / float(n)
		out.append(kp + Vector2(cos(a) * rx, sin(a) * ry))
	# az ív jobb vége (rx, 0) és bal vége (-rx, 0) magasságában zárunk lefelé
	out.append(kp + Vector2(rx, also_y))
	out.append(kp + Vector2(-rx, also_y))
	return out


## Sapka: ugyanaz, mint a kupola, csak a kp fölött ér véget (also_y negatív).
## Nem lehet a kupolát negatív aljjal használni: akkor a záró élek átvágnák az
## ívet, és a háromszögelés elszállna („Invalid polygon data").
func _sapka(kp: Vector2, rx: float, ry: float, also_y: float) -> PackedVector2Array:
	var t := clampf(also_y / ry, -0.999, 0.0)
	var a0 := PI - asin(t)
	var a1 := TAU + asin(t)
	var out := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var a: float = a0 + (a1 - a0) * float(i) / float(n)
		out.append(kp + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _draw() -> void:
	if kulcs == "":
		return
	var g := _rng()
	var w := size.x
	var h := size.y
	var s := minf(w, h)

	# ── az alak mérete és helye ──
	var fej_kp := Vector2(w * 0.5, h * 0.40)
	var rx := s * 0.190                      # fél fejszélesség
	var ry := s * 0.235                      # fél fejmagasság
	var vall_y := h * 0.76                   # innen indul a palást

	var no: bool = kulcs in NOI
	var haj_szin: Color = HAJ[g.randi() % HAJ.size()]
	var szakall: bool = not no and g.randf() < (0.92 if kultura == "norse" else 0.55)
	var hosszu_haj: bool = no or kultura == "gaelic" or kultura == "byzantine" or kultura == "norse"

	_hatter(w, h, s)
	if hosszu_haj:
		_haj_oldalt(fej_kp, rx, ry, haj_szin)
	_nyak(fej_kp, rx, ry, vall_y)
	_palast(w, h, vall_y, s, g)
	_gallér(w, vall_y, s)
	_fej(fej_kp, rx, ry)
	if szakall:
		_szakall(fej_kp, rx, ry, haj_szin)
	_vonasok(fej_kp, rx, ry, g)
	if szakall or (kultura == "gaelic" and not no):
		_bajusz(fej_kp, rx, ry, haj_szin)
	_fejfedo(fej_kp, rx, ry, haj_szin, g)

	# ── a kép széle: vékony tus, hogy elváljon a pergamentől ──
	draw_rect(Rect2(0, 0, w, h), INK, false, maxf(1.0, s * 0.014))


## Tompa, meleg belső tér: fent világosabb, lent sötét, a hátfalon egy boltív.
## A királyság színe csak éppen átüt rajta, hogy minden nemzet képe más legyen.
func _hatter(w: float, h: float, s: float) -> void:
	var savok := 28
	for i in savok:
		var t := float(i) / float(savok - 1)
		var col := HATTER_VIL.lerp(HATTER_SOT, t * t).lerp(szin.darkened(0.60), 0.20)
		draw_rect(Rect2(0.0, h * t - 1.0, w, h / float(savok) + 2.0), col, true)
	# boltív a fej mögött – ettől lesz belső tere a képnek
	var iv_kp := Vector2(w * 0.5, h * 0.44)
	draw_colored_polygon(_kupola(iv_kp, s * 0.34, s * 0.34, h),
		Color(HATTER_SOT.r, HATTER_SOT.g, HATTER_SOT.b, 0.45))
	draw_arc(iv_kp, s * 0.34, PI, TAU, 28, Color(HATTER_VIL.r, HATTER_VIL.g, HATTER_VIL.b, 0.55),
		maxf(1.0, s * 0.012))


func _nyak(fej_kp: Vector2, rx: float, ry: float, vall_y: float) -> void:
	var all_y := fej_kp.y + ry * 0.88
	var fel := rx * 0.46
	draw_rect(Rect2(fej_kp.x - fel, all_y, fel * 2.0, vall_y - all_y + rx * 0.4), BOR_ARNY, true)
	draw_rect(Rect2(fej_kp.x - fel * 0.60, all_y, fel * 1.20, vall_y - all_y + rx * 0.4), BOR, true)


## Palást: a kép alsó negyedét tölti ki, a királyság színében, középen
## aranyhímzéssel. Ez a kép legsötétebb sávja.
func _palast(w: float, h: float, vall_y: float, s: float, g: RandomNumberGenerator) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * -0.06, h + 2.0), Vector2(w * 0.00, vall_y + s * 0.10),
		Vector2(w * 0.20, vall_y - s * 0.02), Vector2(w * 0.5, vall_y - s * 0.05),
		Vector2(w * 0.80, vall_y - s * 0.02), Vector2(w * 1.00, vall_y + s * 0.10),
		Vector2(w * 1.06, h + 2.0)]), szin.darkened(0.50))
	# a bal váll felől jön a fény
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.00, vall_y + s * 0.10), Vector2(w * 0.20, vall_y - s * 0.02),
		Vector2(w * 0.28, h + 2.0), Vector2(w * -0.06, h + 2.0)]), szin.darkened(0.36))
	# aranyhímzés a mell közepén
	var kx := w * 0.5
	draw_rect(Rect2(kx - s * 0.050, vall_y + s * 0.06, s * 0.100, h - vall_y), ARANY.darkened(0.30), true)
	draw_rect(Rect2(kx - s * 0.026, vall_y + s * 0.06, s * 0.052, h - vall_y), ARANY, true)
	var y := vall_y + s * 0.11
	while y < h:
		draw_circle(Vector2(kx, y), maxf(1.0, s * 0.017), KOVEK[g.randi() % KOVEK.size()])
		y += s * 0.080


## Gallér: a keresztény királyoknak hermelin (fehér, fekete farkocskákkal),
## a többieknek sima prém. A vállvonalat követi, nem különálló folt.
func _gallér(w: float, vall_y: float, s: float) -> void:
	var hermelin := not (kultura == "norse" or kultura == "slavic" or kultura == "baltic"
		or kultura == "steppe")
	var col := PREM if hermelin else SZOR
	# Keskeny, lefelé szélesedő szalag a nyaktól a váll felé: V alakot zár be,
	# ahogy a festett képeken a prémgallér. Nem vállap, ezért rövid és ferde.
	for oldal: float in [-1.0, 1.0]:
		var bx := w * 0.5 + oldal * s * 0.055
		var kx := w * 0.5 + oldal * s * 0.30
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx, vall_y - s * 0.075),
			Vector2(bx + oldal * s * 0.075, vall_y - s * 0.065),
			Vector2(kx, vall_y + s * 0.105),
			Vector2(kx - oldal * s * 0.055, vall_y + s * 0.135),
			Vector2(bx, vall_y + s * 0.005)]), col)
		# sötétebb belső él – ettől van vastagsága
		draw_line(Vector2(bx, vall_y - s * 0.075), Vector2(kx, vall_y + s * 0.105),
			col.darkened(0.32), maxf(1.0, s * 0.012))
	if hermelin:
		for i in 4:
			var oldal := -1.0 if i < 2 else 1.0
			var t := float(i % 2)
			var x := w * 0.5 + oldal * s * (0.115 + 0.085 * t)
			var y := vall_y + s * (0.005 + 0.055 * t)
			draw_rect(Rect2(x - s * 0.009, y, s * 0.018, s * 0.032), Color(0.16, 0.14, 0.13), true)


func _fej(fej_kp: Vector2, rx: float, ry: float) -> void:
	# árnyékos oldal, majd rá a megvilágított arc
	draw_colored_polygon(_fej_poly(fej_kp + Vector2(rx * 0.09, ry * 0.03), rx, ry), BOR_ARNY)
	draw_colored_polygon(_fej_poly(fej_kp, rx * 0.97, ry * 0.98), BOR)
	# a fény balról-felülről érkezik
	draw_colored_polygon(_fej_poly(fej_kp + Vector2(-rx * 0.14, -ry * 0.12), rx * 0.70, ry * 0.70),
		Color(BOR_FENY.r, BOR_FENY.g, BOR_FENY.b, 0.50))
	# fülek
	for oldal: float in [-1.0, 1.0]:
		draw_circle(Vector2(fej_kp.x + oldal * rx * 0.95, fej_kp.y + ry * 0.10), rx * 0.16, BOR_ARNY)


## Szakáll: az állkapcsot fogja körbe. A szájnak marad helye – a vonásokat
## ezután rajzoljuk, tehát a száj a szakállra kerül.
func _szakall(fej_kp: Vector2, rx: float, ry: float, haj_szin: Color) -> void:
	var hossz := ry * (1.55 if kultura == "norse" else 1.22)
	# Az állkapocs vonalát követi: oldalt a fül alatt kezdődik, középen csak a
	# száj ALATT ér fel – így a száj és az orr szabadon marad.
	draw_colored_polygon(PackedVector2Array([
		fej_kp + Vector2(-rx * 0.97, ry * 0.16),
		fej_kp + Vector2(-rx * 0.86, ry * 0.66),
		fej_kp + Vector2(-rx * 0.42, hossz),
		fej_kp + Vector2(rx * 0.42, hossz),
		fej_kp + Vector2(rx * 0.86, ry * 0.66),
		fej_kp + Vector2(rx * 0.97, ry * 0.16),
		fej_kp + Vector2(rx * 0.68, ry * 0.58),
		fej_kp + Vector2(-rx * 0.68, ry * 0.58)]), haj_szin)
	# néhány sötétebb tincs, hogy ne legyen lapos folt
	for i in 5:
		var x := fej_kp.x + (-0.40 + 0.20 * i) * rx
		draw_line(Vector2(x, fej_kp.y + ry * 0.86), Vector2(x, fej_kp.y + hossz - ry * 0.10),
			haj_szin.darkened(0.28), maxf(1.0, rx * 0.045))
	if kultura == "norse":
		# fonat a szakáll végén
		draw_rect(Rect2(fej_kp.x - rx * 0.15, fej_kp.y + hossz - ry * 0.20, rx * 0.30, ry * 0.15), ARANY, true)


## Szem, szemöldök, orr, száj – ezektől lesz arca, és nem csak feje.
func _vonasok(fej_kp: Vector2, rx: float, ry: float, g: RandomNumberGenerator) -> void:
	var szem_y := fej_kp.y - ry * 0.02
	var szem_x := rx * 0.40
	var szem_r := maxf(1.2, rx * 0.165)
	for oldal: float in [-1.0, 1.0]:
		var kp := Vector2(fej_kp.x + oldal * szem_x, szem_y)
		draw_circle(kp, szem_r, Color(0.96, 0.94, 0.90))
		draw_circle(kp + Vector2(oldal * szem_r * 0.10, 0.0), szem_r * 0.58, Color(0.30, 0.23, 0.15))
		draw_circle(kp + Vector2(oldal * szem_r * 0.10, 0.0), szem_r * 0.26, INK)
		# felső szemhéj
		draw_line(kp + Vector2(-szem_r * 1.15, -szem_r * 0.80), kp + Vector2(szem_r * 1.15, -szem_r * 0.80),
			BOR_ARNY.darkened(0.30), maxf(1.0, rx * 0.045))
		# szemöldök
		draw_line(kp + Vector2(-szem_r * 1.25, -szem_r * 1.85), kp + Vector2(szem_r * 1.25, -szem_r * 2.15),
			INK.lightened(0.18), maxf(1.2, rx * 0.080))
	# orr: árnyékvonal és tő
	draw_line(fej_kp + Vector2(-rx * 0.05, ry * 0.06), fej_kp + Vector2(-rx * 0.12, ry * 0.36),
		BOR_ARNY.darkened(0.10), maxf(1.0, rx * 0.070))
	draw_line(fej_kp + Vector2(-rx * 0.14, ry * 0.38), fej_kp + Vector2(rx * 0.11, ry * 0.40),
		BOR_ARNY.darkened(0.16), maxf(1.0, rx * 0.060))
	# száj
	draw_line(fej_kp + Vector2(-rx * 0.28, ry * 0.62), fej_kp + Vector2(rx * 0.28, ry * 0.62),
		Color(0.50, 0.26, 0.22), maxf(1.2, rx * 0.080))
	# arccsont-árnyék
	for oldal: float in [-1.0, 1.0]:
		draw_circle(Vector2(fej_kp.x + oldal * rx * 0.60, fej_kp.y + ry * 0.28), rx * 0.19,
			Color(BOR_ARNY.r, BOR_ARNY.g, BOR_ARNY.b, 0.30))
	# néhány ránc az idősebbeknek
	if g.randf() < 0.45:
		for oldal: float in [-1.0, 1.0]:
			draw_line(Vector2(fej_kp.x + oldal * rx * 0.22, fej_kp.y + ry * 0.40),
				Vector2(fej_kp.x + oldal * rx * 0.40, fej_kp.y + ry * 0.64),
				Color(BOR_ARNY.r, BOR_ARNY.g, BOR_ARNY.b, 0.50), maxf(1.0, rx * 0.045))


func _bajusz(fej_kp: Vector2, rx: float, ry: float, haj_szin: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		fej_kp + Vector2(-rx * 0.58, ry * 0.44),
		fej_kp + Vector2(rx * 0.58, ry * 0.44),
		fej_kp + Vector2(rx * 0.46, ry * 0.58),
		fej_kp + Vector2(-rx * 0.46, ry * 0.58)]), haj_szin.darkened(0.10))


## A fülek mellett leomló haj – ez a fej MÖGÉ kerül, ezért rajzoljuk legelöl.
func _haj_oldalt(fej_kp: Vector2, rx: float, ry: float, haj_szin: Color) -> void:
	for oldal: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			fej_kp + Vector2(oldal * rx * 0.55, -ry * 0.90),
			fej_kp + Vector2(oldal * rx * 1.24, -ry * 0.34),
			fej_kp + Vector2(oldal * rx * 1.14, ry * 0.92),
			fej_kp + Vector2(oldal * rx * 0.58, ry * 0.40)]), haj_szin.darkened(0.12))


## Hajtető: csak a koponya felső részét fedi. A szemöldök a fej közepétől
## nagyjából -0,29 ry magasan van, ezért a hajnak e fölött véget kell érnie –
## különben eltakarja a szemet.
func _haj_teto(fej_kp: Vector2, rx: float, ry: float, haj_szin: Color) -> void:
	draw_colored_polygon(_sapka(fej_kp + Vector2(0.0, -ry * 0.06), rx * 1.02, ry * 0.94, -ry * 0.34),
		haj_szin)
	# homlokba hulló tincs
	draw_colored_polygon(PackedVector2Array([
		fej_kp + Vector2(-rx * 0.96, -ry * 0.40),
		fej_kp + Vector2(-rx * 0.22, -ry * 0.50),
		fej_kp + Vector2(rx * 0.96, -ry * 0.62),
		fej_kp + Vector2(rx * 0.96, -ry * 0.74),
		fej_kp + Vector2(-rx * 0.96, -ry * 0.70)]), haj_szin.darkened(0.20))


func _fejfedo(fej_kp: Vector2, rx: float, ry: float, haj_szin: Color, g: RandomNumberGenerator) -> void:
	match kultura:
		"norse", "norman":
			_sisak(fej_kp, rx, ry)
		"gaelic":
			_haj_teto(fej_kp, rx, ry, haj_szin)
			_abroncs(fej_kp, rx, ry, g, false)
		"byzantine":
			_haj_teto(fej_kp, rx, ry, haj_szin)
			_abroncs(fej_kp, rx, ry, g, false)
			# gyöngyfüggők a diadém két oldalán
			for oldal: float in [-1.0, 1.0]:
				var x := fej_kp.x + oldal * rx * 1.08
				var y := fej_kp.y - ry * 0.46
				draw_line(Vector2(x, y), Vector2(x, y + ry * 0.90), Color(0.96, 0.94, 0.90),
					maxf(1.2, rx * 0.09))
				for i in 4:
					draw_circle(Vector2(x, y + ry * (0.20 + 0.23 * i)), maxf(1.2, rx * 0.10),
						Color(0.99, 0.98, 0.95))
		"slavic", "baltic", "steppe":
			_haj_teto(fej_kp, rx, ry, haj_szin)
			# prémes süveg
			draw_colored_polygon(_kupola(fej_kp + Vector2(0.0, -ry * 0.56), rx * 0.92, ry * 0.80,
				ry * 0.34), szin.darkened(0.34))
			draw_rect(Rect2(fej_kp.x - rx * 1.04, fej_kp.y - ry * 0.92, rx * 2.08, ry * 0.34), SZOR, true)
			draw_rect(Rect2(fej_kp.x - rx * 1.04, fej_kp.y - ry * 0.92, rx * 2.08, ry * 0.34), INK,
				false, maxf(1.0, rx * 0.04))
		_:
			_haj_teto(fej_kp, rx, ry, haj_szin)
			_abroncs(fej_kp, rx, ry, g, true)


func _sisak(fej_kp: Vector2, rx: float, ry: float) -> void:
	draw_colored_polygon(_kupola(fej_kp + Vector2(0.0, -ry * 0.16), rx * 1.08, ry * 1.04, ry * 0.36),
		VAS)
	# fénycsík a sisak tetején
	draw_line(fej_kp + Vector2(-rx * 0.55, -ry * 0.98), fej_kp + Vector2(rx * 0.15, -ry * 1.12),
		VAS.lightened(0.40), maxf(1.2, rx * 0.11))
	# abroncs és orrvédő
	draw_rect(Rect2(fej_kp.x - rx * 1.08, fej_kp.y - ry * 0.40, rx * 2.16, ry * 0.22),
		VAS.darkened(0.30), true)
	draw_rect(Rect2(fej_kp.x - rx * 0.10, fej_kp.y - ry * 0.40, rx * 0.20, ry * 0.58),
		VAS.darkened(0.16), true)
	draw_rect(Rect2(fej_kp.x - rx * 1.08, fej_kp.y - ry * 0.40, rx * 2.16, ry * 0.22), INK,
		false, maxf(1.0, rx * 0.04))


## Korona: aranyabroncs, rajta ékkövek; a keresztényeknél leveles csúcsokkal.
func _abroncs(fej_kp: Vector2, rx: float, ry: float, g: RandomNumberGenerator, csucsos: bool) -> void:
	var y := fej_kp.y - ry * 0.82
	var m := ry * 0.32
	if csucsos:
		for i in 5:
			var x := fej_kp.x + (-0.80 + i * 0.40) * rx
			var mag := ry * (0.58 if i % 2 == 0 else 0.40)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - rx * 0.19, y + m * 0.5), Vector2(x + rx * 0.19, y + m * 0.5),
				Vector2(x, y - mag)]), ARANY)
			draw_circle(Vector2(x, y - mag * 0.40), maxf(1.0, rx * 0.07), KOVEK[g.randi() % KOVEK.size()])
	draw_rect(Rect2(fej_kp.x - rx * 1.06, y, rx * 2.12, m), ARANY, true)
	draw_rect(Rect2(fej_kp.x - rx * 1.06, y, rx * 2.12, m * 0.32), ARANY_FENY, true)
	draw_rect(Rect2(fej_kp.x - rx * 1.06, y, rx * 2.12, m), INK, false, maxf(1.0, rx * 0.04))
	for i in 3:
		var x := fej_kp.x + (-0.58 + i * 0.58) * rx
		draw_circle(Vector2(x, y + m * 0.58), maxf(1.2, rx * 0.095), KOVEK[g.randi() % KOVEK.size()])
