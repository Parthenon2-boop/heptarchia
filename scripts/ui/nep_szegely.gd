extends Control

# HEPTARCHIA – a térkép tetején és alján futó díszsáv a játszott nép kultúrája szerint:
#   norse     – Jörmungandr, a Midgard-kígyó (fent a jobb, lent a bal szélen a feje: a két sáv körbeöleli
#               a térképet, ahogy a mítoszban Midgardot)
#   english   – a Sutton Hoo-i ékszerek gránátberakása (cloisonné): arany cellák vörös gránáttal, kék üveggel
#   welsh     – kelta spirálok (triskelé) vörössel és zölddel
#   gaelic    – a Kells-i könyv spiráljai aranyban és bíborban
#   norman    – a bayeux-i kárpit szegélye: vászon alapon színes gyapjúval hímzett madarak és ferde osztók
#   byzantine – bíbor sáv aranygyöngysorral és drágakövekkel; latin – kozmata-mozaik
#   arab      – nyolcágú csillagok; steppe – honfoglalás kori palmetták (tarsolylemez)
#   egyéb     – fonatminta a nép színében
# Csak rajz: az egér átmegy rajta, a térkép ugyanúgy kezelhető.

var stilus := "norse"
var also := false                 # a lenti sáv (a kígyó feje ott a bal szélen van)
var szin := Color(0.80, 0.61, 0.29)   # a nép színe (a fonatmintához)

const SOTET := Color(0.08, 0.05, 0.03)
const ARANY := Color(0.84, 0.66, 0.30)
const ARANY_FENY := Color(1.0, 0.86, 0.50)

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 60.0 or h < 8.0: return
	match stilus:
		"norse": _kigyo(w, h)
		"english": _sutton_hoo(w, h)
		"welsh": _spiralok(w, h, Color(0.10, 0.16, 0.10), Color(0.78, 0.18, 0.14), Color(0.35, 0.62, 0.30))
		"gaelic": _spiralok(w, h, Color(0.12, 0.07, 0.14), Color(0.90, 0.72, 0.28), Color(0.62, 0.30, 0.55))
		"norman", "frankish": _bayeux(w, h)
		"byzantine": _mozaik(w, h, Color(0.26, 0.08, 0.28), ARANY, Color(0.75, 0.12, 0.16), Color(0.16, 0.55, 0.36))
		"latin": _mozaik(w, h, Color(0.86, 0.82, 0.74), Color(0.55, 0.12, 0.10), Color(0.12, 0.40, 0.25), Color(0.10, 0.10, 0.10))
		"arab": _csillagok(w, h)
		"steppe": _palmettak(w, h)
		_: _fonat(w, h)

func _alap(w: float, h: float, hatter: Color, vonal: Color) -> void:
	draw_rect(Rect2(0, 0, w, h), hatter)
	draw_line(Vector2(0, 1), Vector2(w, 1), vonal, 1.5)
	draw_line(Vector2(0, h - 1), Vector2(w, h - 1), vonal, 1.5)

# ── Óészaki: Jörmungandr ─────────────────────────────────────────
func _kigyo(w: float, h: float) -> void:
	if also: draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
	_alap(w, h, Color(0.12, 0.08, 0.05, 0.94), ARANY)
	var test := Color(0.24, 0.40, 0.30)
	var feny := Color(0.46, 0.64, 0.42)
	var pikkely := Color(0.12, 0.22, 0.16)
	var g := PackedVector2Array()
	var mid := h / 2.0
	var amp := h * 0.26
	var hossz := w - 36.0 * h / 16.0
	var x := 0.0
	while x <= hossz:
		var u := x / hossz
		var sim := smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.9, 1.0, u))
		g.append(Vector2(x + 8.0, mid + sin(x * 0.032) * amp * sim))
		x += 4.0
	var n := g.size()
	var vastag := h * 0.52
	for i in n - 1:
		var v := lerpf(2.0, vastag, smoothstep(0.0, 0.35, float(i) / float(n - 1)))
		draw_line(g[i], g[i + 1], SOTET, v + 3.0, true)
	for i in n - 1:
		var v := lerpf(1.2, vastag - 1.0, smoothstep(0.0, 0.35, float(i) / float(n - 1)))
		draw_line(g[i], g[i + 1], test, v, true)
		draw_line(g[i] + Vector2(0, -v * 0.22), g[i + 1] + Vector2(0, -v * 0.22), feny, maxf(v * 0.22, 0.6), true)
	for i in range(3, n - 2, 3):
		var v := lerpf(1.2, vastag - 1.0, smoothstep(0.0, 0.35, float(i) / float(n - 1)))
		if v < 4.0: continue
		var irany := (g[i + 1] - g[i - 1]).normalized()
		var normal := Vector2(-irany.y, irany.x)
		draw_arc(g[i] + normal * v * 0.12, v * 0.28, irany.angle() + PI * 0.15, irany.angle() + PI * 0.85, 5, pikkely, 1.0, true)
		if i % 6 == 0: draw_circle(g[i] - normal * v * 0.3, 0.9, ARANY)
	# a fej: nyitott állkapocs méregfogakkal, sarló alakú szem, fonatos taréj
	var s := h / 16.0
	var o := g[n - 1] + Vector2(4 * s, 0)
	var felso := PackedVector2Array([o + Vector2(-2, -6) * s, o + Vector2(10, -8) * s, o + Vector2(24, -5) * s,
		o + Vector2(32, -1) * s, o + Vector2(22, 0) * s, o + Vector2(8, 1) * s, o + Vector2(-2, 3) * s])
	var allkapocs := PackedVector2Array([o + Vector2(-2, 3) * s, o + Vector2(8, 2) * s, o + Vector2(20, 5) * s,
		o + Vector2(26, 8) * s, o + Vector2(12, 8) * s, o + Vector2(-1, 6) * s])
	for poly in [allkapocs, felso]:
		var kv: PackedVector2Array = poly.duplicate()
		kv.append(poly[0])
		draw_colored_polygon(poly, test)
		draw_polyline(kv, SOTET, 1.6, true)
	for fx in [14.0, 20.0]:
		draw_colored_polygon(PackedVector2Array([o + Vector2(fx, 0.5) * s, o + Vector2(fx + 2.0, 0.5) * s,
			o + Vector2(fx + 1.0, 4.0) * s]), Color(0.95, 0.92, 0.82))
	draw_circle(o + Vector2(9, -4) * s, 2.0 * s, SOTET)
	draw_circle(o + Vector2(9, -4) * s, 1.3 * s, Color(0.98, 0.78, 0.25))
	draw_line(o + Vector2(9, -5.2) * s, o + Vector2(9, -2.8) * s, SOTET, 0.8 * s)
	draw_circle(o + Vector2(27, -2.5) * s, 0.8 * s, SOTET)
	for k in 3:
		var c := o + Vector2(-1 - k * 4.5, -7 - (k % 2) * 1.5) * s
		draw_arc(c, 2.6 * s, PI, TAU, 8, SOTET, 2.4 * s, true)
		draw_arc(c, 2.6 * s, PI, TAU, 8, ARANY, 1.2 * s, true)

# ── Angol: Sutton Hoo gránátberakás ─────────────────────────────
func _sutton_hoo(w: float, h: float) -> void:
	_alap(w, h, Color(0.14, 0.09, 0.04, 0.95), ARANY)
	var granat := Color(0.55, 0.06, 0.07)
	var granat_feny := Color(0.85, 0.22, 0.18)
	var kek := Color(0.18, 0.36, 0.62)
	var cella := h * 1.15
	var x := 4.0
	var i := 0
	while x + cella <= w - 2.0:
		var t := 4.0
		var b := h - 4.0
		var m := cella * 0.5
		# „gomba” alakú lépcsős cella (a Sutton Hoo-i erszényfedél mintája)
		var poly := PackedVector2Array([Vector2(x + 1, b), Vector2(x + 1, t + 5), Vector2(x + m * 0.45, t + 5),
			Vector2(x + m * 0.45, t), Vector2(x + cella - m * 0.45, t), Vector2(x + cella - m * 0.45, t + 5),
			Vector2(x + cella - 1, t + 5), Vector2(x + cella - 1, b)])
		if i % 2 == 1:
			# minden második fejjel lefelé
			for k in poly.size(): poly[k].y = h - poly[k].y
		draw_colored_polygon(poly, granat)
		var feny := PackedVector2Array()
		for p in poly: feny.append(p.lerp(Vector2(x + m, h / 2.0), 0.45))
		draw_colored_polygon(feny, granat_feny * Color(1, 1, 1, 0.55))
		var kv := poly.duplicate()
		kv.append(poly[0])
		draw_polyline(kv, ARANY_FENY, 1.4, true)
		# kék üveg (millefiori) a cellák között
		var kx := x + cella + 2.5
		if kx + 3.0 < w - 2.0:
			draw_rect(Rect2(kx - 2.2, h / 2.0 - 2.2, 4.4, 4.4), kek)
			draw_rect(Rect2(kx - 2.2, h / 2.0 - 2.2, 4.4, 4.4), ARANY_FENY, false, 1.0)
		x += cella + 5.0
		i += 1

# ── Kelta: spirálok (triskelé) ───────────────────────────────────
func _spiralok(w: float, h: float, hatter: Color, fo: Color, masod: Color) -> void:
	_alap(w, h, hatter * Color(1, 1, 1, 0.95), fo)
	var r := h * 0.36
	var lepes := r * 2.9
	var x := lepes * 0.5
	var i := 0
	# a spirálokat összekötő hullámvonal
	var hull := PackedVector2Array()
	var hx := 0.0
	while hx <= w:
		hull.append(Vector2(hx, h / 2.0 + sin(hx / lepes * TAU) * r * 0.9))
		hx += 3.0
	draw_polyline(hull, SOTET, 3.2, true)
	draw_polyline(hull, masod, 1.6, true)
	while x < w:
		var c := Vector2(x, h / 2.0)
		draw_circle(c, r + 1.2, SOTET)
		draw_circle(c, r, hatter.lightened(0.08))
		# három spirálkar
		for kar in 3:
			var pts := PackedVector2Array()
			for k in 14:
				var u := float(k) / 13.0
				var szog := kar * TAU / 3.0 + u * PI * 1.4 + (i % 2) * 0.5
				pts.append(c + Vector2(cos(szog), sin(szog)) * r * (0.08 + u * 0.82))
			draw_polyline(pts, fo, 1.5, true)
		draw_circle(c, 1.1, masod)
		x += lepes
		i += 1

# ── Normann: a bayeux-i kárpit szegélye ─────────────────────────
func _bayeux(w: float, h: float) -> void:
	var vaszon := Color(0.88, 0.82, 0.68)
	var terrakotta := Color(0.66, 0.30, 0.20)
	var kekeszold := Color(0.24, 0.42, 0.40)
	var mustar := Color(0.78, 0.62, 0.24)
	var sotetkek := Color(0.20, 0.24, 0.40)
	draw_rect(Rect2(0, 0, w, h), vaszon)
	draw_line(Vector2(0, 1.2), Vector2(w, 1.2), terrakotta, 1.6)
	draw_line(Vector2(0, h - 1.2), Vector2(w, h - 1.2), terrakotta, 1.6)
	var mezo := h * 1.9
	var x := 0.0
	var i := 0
	var szinek := [terrakotta, kekeszold, mustar, sotetkek]
	while x < w:
		# ferde, kettős osztó
		var c1: Color = szinek[i % 4]
		var c2: Color = szinek[(i + 2) % 4]
		draw_line(Vector2(x, h - 3), Vector2(x + h * 0.5, 3), c1, 2.2, true)
		draw_line(Vector2(x + 3, h - 3), Vector2(x + 3 + h * 0.5, 3), c2, 1.4, true)
		# a mezőben felváltva madár és indás levél (a kárpit szegélyének mintái)
		var k := Vector2(x + mezo * 0.5 + h * 0.3, h / 2.0)
		if i % 2 == 0:
			# madár: test, szárny, nyak, csőr, láb – gyapjúszálszerű vonalakkal
			var mc: Color = szinek[(i + 1) % 4]
			draw_arc(k + Vector2(0, 1), h * 0.2, PI * 0.1, PI * 0.95, 8, mc, 1.6, true)
			draw_line(k + Vector2(-h * 0.2, 0), k + Vector2(-h * 0.05, -h * 0.28), mc, 1.4, true)
			draw_line(k + Vector2(h * 0.18, 0), k + Vector2(h * 0.28, -h * 0.18), mc, 1.4, true)
			draw_line(k + Vector2(h * 0.28, -h * 0.18), k + Vector2(h * 0.38, -h * 0.14), sotetkek, 1.2, true)
			draw_line(k + Vector2(-h * 0.04, h * 0.2), k + Vector2(-h * 0.06, h * 0.34), sotetkek, 1.0)
			draw_line(k + Vector2(h * 0.06, h * 0.2), k + Vector2(h * 0.08, h * 0.34), sotetkek, 1.0)
		else:
			var pts := PackedVector2Array()
			for q in 12:
				var u := float(q) / 11.0
				pts.append(k + Vector2((u - 0.5) * h * 0.7, sin(u * TAU) * h * 0.18))
			draw_polyline(pts, kekeszold, 1.5, true)
			draw_circle(k + Vector2(-h * 0.18, -h * 0.12), 1.6, mustar)
			draw_circle(k + Vector2(h * 0.18, h * 0.12), 1.6, terrakotta)
		x += mezo
		i += 1

# ── Bizánci / latin: mozaik gyöngysorral és drágakövekkel ─────────
func _mozaik(w: float, h: float, hatter: Color, keret: Color, ko1: Color, ko2: Color) -> void:
	_alap(w, h, hatter, keret)
	var gy := 3.2
	var x := gy
	while x < w:
		draw_circle(Vector2(x, 3.6), 1.3, keret)
		draw_circle(Vector2(x, h - 3.6), 1.3, keret)
		x += gy * 2.0
	var lepes := h * 1.3
	x = lepes * 0.5
	var i := 0
	while x < w:
		var c := Vector2(x, h / 2.0)
		var r := h * 0.28
		var roz := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 1.3, 0), c + Vector2(0, r), c + Vector2(-r * 1.3, 0)])
		draw_colored_polygon(roz, ko1 if i % 2 == 0 else ko2)
		var kv := roz.duplicate()
		kv.append(roz[0])
		draw_polyline(kv, keret, 1.3, true)
		draw_circle(c, 1.4, keret.lightened(0.3))
		x += lepes
		i += 1

# ── Arab: nyolcágú csillagok ────────────────────────────────────
func _csillagok(w: float, h: float) -> void:
	var hatter := Color(0.07, 0.20, 0.26)
	_alap(w, h, hatter, ARANY)
	var lepes := h * 1.2
	var x := lepes * 0.5
	var r := h * 0.34
	while x < w:
		var c := Vector2(x, h / 2.0)
		for fordul in [0.0, PI / 4.0]:
			var negyzet := PackedVector2Array()
			for k in 5:
				var a: float = fordul + PI / 4.0 + k * PI / 2.0
				negyzet.append(c + Vector2(cos(a), sin(a)) * r)
			draw_polyline(negyzet, ARANY, 1.3, true)
		draw_circle(c, r * 0.28, Color(0.72, 0.20, 0.18))
		if x + lepes < w: draw_line(c + Vector2(r, 0), c + Vector2(lepes - r, 0), ARANY * Color(1, 1, 1, 0.6), 1.0)
		x += lepes

# ── Sztyeppe: palmetták (a honfoglalás kori tarsolylemezek módján) ──
func _palmettak(w: float, h: float) -> void:
	_alap(w, h, Color(0.16, 0.10, 0.06, 0.95), ARANY)
	var lepes := h * 1.25
	var x := lepes * 0.5
	var i := 0
	while x < w:
		var alj := Vector2(x, h - 4.0)
		var fel := -1.0 if i % 2 == 0 else 1.0
		if fel > 0.0: alj = Vector2(x, 4.0)
		# a palmetta: középső levél és két kunkorodó oldallevél, sötét körvonallal (mint a vert ezüstlemezen)
		var csucs := alj + Vector2(0, fel * (h - 8.0))
		for rajz in [[SOTET, 3.4], [ARANY_FENY, 1.8]]:
			draw_line(alj, csucs, rajz[0], rajz[1], true)
			for oldal in [-1.0, 1.0]:
				var pts := PackedVector2Array()
				for k in 9:
					var u := float(k) / 8.0
					pts.append(alj + Vector2(oldal * sin(u * PI * 0.95) * h * 0.4, fel * u * (h - 9.0)))
				draw_polyline(pts, rajz[0], rajz[1], true)
				draw_circle(pts[pts.size() - 1], rajz[1] * 0.9, rajz[0])
		x += lepes
		i += 1

# ── Minden más nép: fonatminta a nép színében ─────────────────────
func _fonat(w: float, h: float) -> void:
	_alap(w, h, Color(0.10, 0.07, 0.05, 0.94), szin)
	var mid := h / 2.0
	var vastag := maxf(h * 0.13, 2.0)
	var amp := mid - vastag - 2.5
	var fel := h * 0.85
	var k := 0
	while (k - 0.5) * fel < w:
		var a0 := maxf((k - 0.5) * fel, 0.0)
		var a1 := minf((k + 0.5) * fel, w)
		var szalak: Array = []
		for irany in [1.0, -1.0]:
			var pts := PackedVector2Array()
			for i in 9:
				var x := lerpf(a0, a1, float(i) / 8.0)
				pts.append(Vector2(x, mid + irany * amp * sin(PI * x / fel)))
			szalak.append(pts)
		var alul: PackedVector2Array = szalak[0] if k % 2 == 0 else szalak[1]
		var felul: PackedVector2Array = szalak[1] if k % 2 == 0 else szalak[0]
		for pts in [alul, felul]:
			draw_polyline(pts, SOTET, vastag + 2.2, true)
			draw_polyline(pts, szin, vastag, true)
		k += 1
