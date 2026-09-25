extends CanvasLayer

# HEPTARCHIA – töltőképernyő (új játék, oktatómód, mentés betöltése)
#
# Egész képernyős festmény a korból, alul töltőcsík. A csík a valódi munkát követi:
#   1. a világ megteremtése (GameManager.new_game vagy a mentés betöltése),
#   2. a főjelenet betöltése a háttérben (ResourceLoader.load_threaded_*),
#   3. a térkép felépítése az első képkockákban.
# A képek (assets/loading/*.jpg) sorban váltják egymást: a sorrend egyszer megkeveredik,
# és amíg mind sorra nem került, egy sem ismétlődik (user://tolto.cfg jegyzi).
# A réteg a gyökérre kerül, így a jelenetváltáson is megmarad; a végén elhalványul.

const MAIN := "res://scenes/MainGame.tscn"
const KEPEK_MAPPA := "res://assets/loading"
const JEGYZET := "user://tolto.cfg"
const KERET := Color(0.84, 0.68, 0.36)
const SOTET := Color(0.10, 0.07, 0.05)

var _kep: TextureRect
var _csik: Control
var _felirat: Label
var _cel := 0.0            # ameddig a csíknak el kell jutnia
var _ertek := 0.0          # ahol most áll (lágyan követi a célt)

## Elindítja a töltést: `elokeszit` teremti meg a világot (igazat ad, ha sikerült),
## `szoveg_kulcs` a csík alatti felirat nyelvi kulcsa
static func indit(tree: SceneTree, elokeszit: Callable, szoveg_kulcs: String = "LOADING_WORLD") -> void:
	var t = load("res://scripts/ui/tolto.gd").new()
	tree.root.add_child(t)
	t._fut(elokeszit, szoveg_kulcs)

func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

func _epit(szoveg_kulcs: String) -> void:
	var hatter := ColorRect.new()
	hatter.color = Color.BLACK
	hatter.set_anchors_preset(Control.PRESET_FULL_RECT)
	hatter.mouse_filter = Control.MOUSE_FILTER_STOP      # a töltés alatt semmire se lehessen kattintani
	add_child(hatter)
	_kep = TextureRect.new()
	_kep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_kep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_kep.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_kep.texture = _kovetkezo_kep()
	_kep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatter.add_child(_kep)
	# alul sötét sáv, hogy a csík és a felirat mindig olvasható legyen
	var sav := TextureRect.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0))
	gr.set_color(1, Color(0, 0, 0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	sav.texture = gt
	sav.anchor_left = 0; sav.anchor_right = 1; sav.anchor_top = 0.72; sav.anchor_bottom = 1
	sav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatter.add_child(sav)
	_csik = Control.new()
	_csik.anchor_left = 0.12; _csik.anchor_right = 0.88; _csik.anchor_top = 1; _csik.anchor_bottom = 1
	_csik.offset_top = -82; _csik.offset_bottom = -54
	_csik.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_csik.draw.connect(_rajz_csik)
	hatter.add_child(_csik)
	_felirat = Label.new()
	_felirat.text = tr(szoveg_kulcs)
	_felirat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_felirat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_felirat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART     # keskeny ablakban se lógjon ki
	_felirat.clip_text = true
	_felirat.anchor_left = 0.05; _felirat.anchor_right = 0.95; _felirat.anchor_top = 1; _felirat.anchor_bottom = 1
	_felirat.offset_top = -46; _felirat.offset_bottom = -14
	_felirat.add_theme_font_size_override("font_size", 20)
	_felirat.add_theme_color_override("font_color", Color(0.97, 0.92, 0.80))
	_felirat.add_theme_color_override("font_outline_color", SOTET)
	_felirat.add_theme_constant_override("outline_size", 6)
	hatter.add_child(_felirat)

# A csík: a kezdőlap választóvonalának angolszász fonatmintája (knot_divider.gd). A teljes
# fonat halványan látszik, és ahogy halad a töltés, balról jobbra aranyszínűre „töltődik”;
# a haladás élén egy kis fény. Két végén rombusz, fölötte és alatta vékony aranyvonal.
const SZAL := Color(0.80, 0.61, 0.29)
const SZAL_FENY := Color(1.0, 0.84, 0.48)
const SZAL_HALVANY := Color(0.36, 0.28, 0.16, 0.9)
const SZEGELY := Color(0.10, 0.06, 0.03)

func _rajz_csik() -> void:
	var w := _csik.size.x
	var h := _csik.size.y
	var mid := h / 2.0
	var vastag := maxf(h * 0.13, 2.0)
	var periodus := h * 1.7
	_csik.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
	_csik.draw_line(Vector2(0, 0.5), Vector2(w, 0.5), Color(SZAL, 0.55), 1.0)
	_csik.draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(SZAL, 0.55), 1.0)
	var szel := 10.0                                   # a rombuszoknak
	var bent := w - 2.0 * szel
	_fonat(szel, szel + bent, mid, vastag, periodus, SZAL_HALVANY)
	var tele := bent * clampf(_ertek, 0.0, 1.0)
	if tele > 0.5:
		_fonat(szel, szel + tele, mid, vastag, periodus, SZAL, SZAL_FENY)
		# fény a haladás élén
		for i in 3:
			_csik.draw_circle(Vector2(szel + tele, mid), vastag * (3.2 - i), Color(1.0, 0.88, 0.55, 0.10 + 0.08 * i))
	for x in [szel * 0.5, w - szel * 0.5]:
		var d := PackedVector2Array([Vector2(x, mid - 6), Vector2(x + 4, mid), Vector2(x, mid + 6), Vector2(x - 4, mid)])
		_csik.draw_colored_polygon(d, SZAL)

# Két egymásba fonódó szál x0-tól x1-ig; minden kereszteződésnél felváltva a másik van felül
func _fonat(x0: float, x1: float, mid: float, vastag: float, periodus: float, szin: Color, csucs := Color(0, 0, 0, 0)) -> void:
	var fel := periodus / 2.0
	var amp := mid - vastag - 3.0
	var k := 0
	while (k - 0.5) * fel < x1 - x0:
		var a0 := x0 + maxf((k - 0.5) * fel, 0.0)
		var a1 := minf(x0 + (k + 0.5) * fel, x1)
		if a1 > a0:
			var szalak: Array = []
			for irany in [1.0, -1.0]:
				var pts := PackedVector2Array()
				for i in 9:
					var x := lerpf(a0, a1, float(i) / 8.0)
					pts.append(Vector2(x, mid + irany * amp * sin(PI * (x - x0) / fel)))
				szalak.append(pts)
			var alul: PackedVector2Array = szalak[0] if k % 2 == 0 else szalak[1]
			var felul: PackedVector2Array = szalak[1] if k % 2 == 0 else szalak[0]
			for pts in [alul, felul]:
				_csik.draw_polyline(pts, SZEGELY, vastag + 2.2, true)
				_csik.draw_polyline(pts, szin, vastag, true)
				if csucs.a > 0.0: _csik.draw_polyline(pts, Color(csucs, 0.45), maxf(vastag * 0.35, 1.0), true)
		k += 1

const BEUSZAS := 0.5          # ennyi idő alatt úszik be a menü fölé
const KIUSZAS := 0.8          # és ennyi alatt tűnik el a játék fölül

func _process(delta: float) -> void:
	if _csik == null: return
	# a csík lágyan, gyorsulva-lassulva követi a célt (nem lépcsőzve)
	_ertek = lerpf(_ertek, _cel, 1.0 - exp(-delta * 5.0))
	if absf(_ertek - _cel) < 0.002: _ertek = _cel
	_csik.queue_redraw()

func _fut(elokeszit: Callable, szoveg_kulcs: String) -> void:
	_epit(szoveg_kulcs)
	var tree := get_tree()
	# beúszás a menü fölé; csak ha már teljesen látszik, akkor jön a hosszú (akasztó) munka
	for c in get_children():
		if c is CanvasItem: c.modulate.a = 0.0
	var be := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for c in get_children():
		if c is CanvasItem: be.tween_property(c, "modulate:a", 1.0, BEUSZAS)
	await be.finished
	for i in 2: await tree.process_frame
	_cel = 0.15
	await tree.process_frame
	var ok = elokeszit.call()
	if ok is bool and not ok:
		_eltunik()
		return
	_ertek = maxf(_ertek, 0.3); _cel = 0.35
	ResourceLoader.load_threaded_request(MAIN)
	var halad := []
	while true:
		var st := ResourceLoader.load_threaded_get_status(MAIN, halad)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_cel = 0.35 + 0.4 * (float(halad[0]) if not halad.is_empty() else 0.0)
			await tree.process_frame
			continue
		break
	var jelenet = ResourceLoader.load_threaded_get(MAIN)
	_cel = 0.8
	await tree.process_frame
	if jelenet is PackedScene: tree.change_scene_to_packed(jelenet)
	else: tree.change_scene_to_file(MAIN)
	# a térkép és a felület az első képkockákban épül fel (a tengeri díszítés sütése is)
	for i in 8:
		await tree.process_frame
		_cel = 0.8 + 0.2 * (i + 1) / 8.0
	_cel = 1.0
	while _ertek < 0.999: await tree.process_frame
	# az első képkockák akadozása alatt még takarunk, csak utána úszunk ki
	for i in 4: await tree.process_frame
	await tree.create_timer(0.2).timeout
	_eltunik()

func _eltunik() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for c in get_children():
		if c is CanvasItem: tw.tween_property(c, "modulate:a", 0.0, KIUSZAS)
	tw.chain().tween_callback(queue_free)

# ── A képek sorrendje ──────────────────────────────────────────
static func kepek() -> Array:
	var r: Array = []
	var d := DirAccess.open(KEPEK_MAPPA)
	if d == null: return r
	for f in d.get_files():
		# exportált játékban a képek .import néven látszanak
		var nev := f.trim_suffix(".import")
		if nev.get_extension() in ["jpg", "png", "webp"] and not nev in r: r.append(nev)
	r.sort()
	return r

func _kovetkezo_kep() -> Texture2D:
	var lista := kepek()
	if lista.is_empty(): return null
	var cfg := ConfigFile.new()
	cfg.load(JEGYZET)
	var sor: Array = cfg.get_value("tolto", "sor", [])
	var hol := int(cfg.get_value("tolto", "hol", 0))
	# új kör (vagy megváltozott a képek listája): új keverés, de az előző kép ne legyen az első
	if hol >= sor.size() or sor.size() != lista.size() or not sor.all(func(x): return x in lista):
		var elozo = sor[hol - 1] if hol > 0 and hol <= sor.size() else ""
		sor = lista.duplicate()
		sor.shuffle()
		if sor.size() > 1 and sor[0] == elozo: sor.push_back(sor.pop_front())
		hol = 0
	var nev: String = sor[hol]
	cfg.set_value("tolto", "sor", sor)
	cfg.set_value("tolto", "hol", hol + 1)
	cfg.save(JEGYZET)
	return load(KEPEK_MAPPA + "/" + nev)
