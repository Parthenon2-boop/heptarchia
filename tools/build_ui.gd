extends SceneTree

# HEPTARCHIA – angolszász UI grafika generátor
# Paneleket (bőr + aranykeret + vörös pöttyözés), gombokat, pergament, nyersanyag-ikonokat
# és a teljes Godot témát (betűtípusokkal) állítja elő az assets/ui mappába.
#
# Futtatás a projekt mappájából (a 2. lépés importálja a frissen rajzolt képeket):
#   1) godot --headless --path . -s res://tools/build_ui.gd -- images
#   2) godot --headless --path . --import
#   3) godot --headless --path . -s res://tools/build_ui.gd -- theme

const OUT := "res://assets/ui/"
const FONTS := "res://assets/fonts/"

const INK        := Color(0.10, 0.06, 0.03)
const LEATHER    := Color(0.21, 0.135, 0.08)
const GOLD       := Color(0.80, 0.61, 0.29)
const GOLD_DARK  := Color(0.52, 0.38, 0.17)
const GOLD_LIGHT := Color(0.97, 0.85, 0.53)
const PARCH      := Color(0.89, 0.81, 0.63)
const RED        := Color(0.60, 0.15, 0.09)
const TEXT_LIGHT := Color(0.94, 0.88, 0.73)
const TEXT_DARK  := Color(0.22, 0.13, 0.06)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "images" in args:
		_build_images()
	if "theme" in args:
		_build_theme()
	if "stability" in args:     # csak a stabilitás ikonja (a többi kép változatlan marad)
		_save(_icon(_draw_stability), "icon_stability")
		_scaled_preview(_icon(_draw_stability)).save_png(OS.get_user_data_dir() + "/shots/stability_preview.png")
	quit()

# ── Képek ──────────────────────────────────────────────────────

func _build_images() -> void:
	_save(_make_panel(), "panel")
	_save(_make_parchment(), "parchment")
	_save(_make_button(Color(0.37, 0.25, 0.14), Color(0.20, 0.12, 0.07), GOLD, GOLD_DARK), "button_normal")
	_save(_make_button(Color(0.48, 0.33, 0.17), Color(0.27, 0.17, 0.09), GOLD_LIGHT, GOLD), "button_hover")
	_save(_make_button(Color(0.15, 0.09, 0.05), Color(0.27, 0.18, 0.10), GOLD_LIGHT, GOLD_DARK), "button_pressed")
	_save(_make_button(Color(0.23, 0.20, 0.17), Color(0.15, 0.13, 0.11), Color(0.36, 0.32, 0.27), Color(0.25, 0.22, 0.19)), "button_disabled")
	_save(_icon(_draw_silver), "icon_silver")
	_save(_icon(_draw_food), "icon_food")
	_save(_icon(_draw_wood), "icon_wood")
	_save(_icon(_draw_iron), "icon_iron")
	_save(_icon(_draw_stability), "icon_stability")
	print("UI images written to ", OUT)

func _save(img: Image, name: String) -> void:
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))

func _seamless_noise(size: int, freq: float, seed_value: int) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	return n.get_seamless_image(size, size)

func _frame(img: Image, inset: int, col: Color) -> void:
	var w := img.get_width() - 1 - inset
	var h := img.get_height() - 1 - inset
	for x in range(inset, w + 1):
		img.set_pixel(x, inset, col); img.set_pixel(x, h, col)
	for y in range(inset, h + 1):
		img.set_pixel(inset, y, col); img.set_pixel(w, y, col)

func _dots(img: Image, inset: int, step: int, col: Color) -> void:
	var w := img.get_width() - 1 - inset
	var h := img.get_height() - 1 - inset
	for x in range(inset, w + 1, step):
		img.set_pixel(x, inset, col); img.set_pixel(x, h, col)
	for y in range(inset, h + 1, step):
		img.set_pixel(inset, y, col); img.set_pixel(w, y, col)

# Díszes sarok: aranyozott négyzet, benne rombusz és vörös pötty (kéziratok iniciáléinak stílusa)
func _corner_boss(img: Image, ox: int, oy: int, size: int) -> void:
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var col: Color
			var edge := x == 0 or y == 0 or x == size - 1 or y == size - 1
			var d := absf(x - c) + absf(y - c)
			if edge: col = INK
			elif x == 1 or y == 1 or x == size - 2 or y == size - 2: col = GOLD_LIGHT
			elif d <= 1.2: col = RED
			elif d <= c - 1.5: col = GOLD
			elif d <= c - 0.5: col = INK
			else: col = GOLD_DARK
			img.set_pixel(ox + x, oy + y, col)

func _make_panel() -> Image:
	const S := 96
	const M := 16          # textúramargó; a közép 64 px-es, varratmentesen ismétlődő
	var noise := _seamless_noise(64, 0.05, 7)
	var grain := _seamless_noise(64, 0.22, 11)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var v := noise.get_pixel(posmod(x - M, 64), posmod(y - M, 64)).r - 0.5
			var g := grain.get_pixel(posmod(x - M, 64), posmod(y - M, 64)).r - 0.5
			var k := 1.0 + v * 0.45 + g * 0.15
			img.set_pixel(x, y, Color(LEATHER.r * k, LEATHER.g * k, LEATHER.b * k))
	_frame(img, 0, INK)
	_frame(img, 1, GOLD_DARK)
	_frame(img, 2, GOLD_LIGHT)
	_frame(img, 3, GOLD)
	_frame(img, 4, GOLD_DARK)
	_frame(img, 5, INK)
	_dots(img, 8, 4, RED)
	for pos in [Vector2i(0, 0), Vector2i(S - 14, 0), Vector2i(0, S - 14), Vector2i(S - 14, S - 14)]:
		_corner_boss(img, pos.x, pos.y, 14)
	return img

func _make_parchment() -> Image:
	const S := 96
	const M := 16
	var noise := _seamless_noise(64, 0.04, 23)
	var fine := _seamless_noise(64, 0.3, 5)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var v := noise.get_pixel(posmod(x - M, 64), posmod(y - M, 64)).r - 0.5
			var f := fine.get_pixel(posmod(x - M, 64), posmod(y - M, 64)).r - 0.5
			var k := 1.0 + v * 0.16 + f * 0.05
			img.set_pixel(x, y, Color(PARCH.r * k, PARCH.g * k, PARCH.b * (k - 0.02)))
	var brown := Color(0.36, 0.23, 0.12)
	_frame(img, 0, INK)
	_frame(img, 1, brown)
	_frame(img, 2, Color(0.55, 0.39, 0.22))
	_frame(img, 5, RED)
	_dots(img, 8, 4, Color(RED, 0.8))
	for pos in [Vector2i(0, 0), Vector2i(S - 12, 0), Vector2i(0, S - 12), Vector2i(S - 12, S - 12)]:
		_corner_boss(img, pos.x, pos.y, 12)
	return img

func _make_button(top: Color, bottom: Color, border: Color, border_inner: Color) -> Image:
	const W := 48
	const H := 32
	var grain := _seamless_noise(48, 0.2, 3)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var base := top.lerp(bottom, float(y) / float(H - 1))
		for x in W:
			var k := 1.0 + (grain.get_pixel(x, y).r - 0.5) * 0.12
			img.set_pixel(x, y, Color(base.r * k, base.g * k, base.b * k))
	_frame(img, 0, INK)
	_frame(img, 1, border)
	_frame(img, 2, border_inner)
	for x in range(3, W - 3):   # felső fényél
		img.set_pixel(x, 3, img.get_pixel(x, 3).lightened(0.12))
	for p in [Vector2i(0, 0), Vector2i(W - 1, 0), Vector2i(0, H - 1), Vector2i(W - 1, H - 1)]:
		img.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
	return img

# ── Ikonok (20×20, 4×4 szuperszemplinggel) ─────────────────────

# Nagyított előnézet (ellenőrzéshez, sötét háttéren); a projektbe nem kerül
func _scaled_preview(src: Image) -> Image:
	var img := Image.create(160, 160, false, Image.FORMAT_RGBA8)
	img.fill(LEATHER)
	var big := src.duplicate()
	big.resize(160, 160, Image.INTERPOLATE_NEAREST)
	img.blend_rect(big, Rect2i(0, 0, 160, 160), Vector2i.ZERO)
	return img

func _icon(painter: Callable) -> Image:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	painter.call(img)
	return img

func _layer(img: Image, shape: Callable, col: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var hits := 0
			for sy in 4:
				for sx in 4:
					if shape.call(x + (sx + 0.5) / 4.0, y + (sy + 0.5) / 4.0):
						hits += 1
			if hits == 0: continue
			var a := col.a * hits / 16.0
			var dst := img.get_pixel(x, y)
			var out_a := a + dst.a * (1.0 - a)
			var r := (col.r * a + dst.r * dst.a * (1.0 - a)) / out_a
			var g := (col.g * a + dst.g * dst.a * (1.0 - a)) / out_a
			var b := (col.b * a + dst.b * dst.a * (1.0 - a)) / out_a
			img.set_pixel(x, y, Color(r, g, b, out_a))

func _circle(cx: float, cy: float, r: float) -> Callable:
	return func(x: float, y: float) -> bool: return Vector2(x - cx, y - cy).length() <= r

func _ring(cx: float, cy: float, r0: float, r1: float) -> Callable:
	return func(x: float, y: float) -> bool:
		var d := Vector2(x - cx, y - cy).length()
		return d >= r0 and d <= r1

func _rect(x0: float, y0: float, x1: float, y1: float) -> Callable:
	return func(x: float, y: float) -> bool: return x >= x0 and x <= x1 and y >= y0 and y <= y1

func _capsule(a: Vector2, b: Vector2, r: float) -> Callable:
	return func(x: float, y: float) -> bool:
		return Geometry2D.get_closest_point_to_segment(Vector2(x, y), a, b).distance_to(Vector2(x, y)) <= r

func _ellipse(cx: float, cy: float, rx: float, ry: float, angle_deg: float) -> Callable:
	var ang := deg_to_rad(angle_deg)
	return func(x: float, y: float) -> bool:
		var p := Vector2(x - cx, y - cy).rotated(-ang)
		return (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry) <= 1.0

func _polygon(points: PackedVector2Array) -> Callable:
	return func(x: float, y: float) -> bool: return Geometry2D.is_point_in_polygon(Vector2(x, y), points)

func _draw_silver(img: Image) -> void:
	_layer(img, _circle(10, 10, 9.3), INK)
	_layer(img, _circle(10, 10, 8.2), Color(0.80, 0.81, 0.84))
	_layer(img, _ring(10, 10, 5.4, 6.4), Color(0.52, 0.53, 0.58))
	_layer(img, _rect(9.2, 5.6, 10.8, 14.4), Color(0.45, 0.46, 0.51))
	_layer(img, _rect(5.6, 9.2, 14.4, 10.8), Color(0.45, 0.46, 0.51))
	_layer(img, _circle(6.8, 6.6, 1.7), Color(1, 1, 1, 0.75))

func _draw_food(img: Image) -> void:
	var grain := Color(0.95, 0.77, 0.30)
	var grains := [[10.0, 3.6, 0.0], [7.3, 7.2, -35.0], [12.7, 7.2, 35.0],
		[7.3, 11.0, -35.0], [12.7, 11.0, 35.0], [7.5, 14.8, -35.0], [12.5, 14.8, 35.0]]
	_layer(img, _capsule(Vector2(10, 6), Vector2(10, 19), 1.3), INK)
	for gr in grains:
		_layer(img, _ellipse(gr[0], gr[1], 2.6, 3.4, gr[2]), INK)
	_layer(img, _capsule(Vector2(10, 6), Vector2(10, 18.6), 0.6), Color(0.72, 0.55, 0.22))
	for gr in grains:
		_layer(img, _ellipse(gr[0], gr[1], 1.7, 2.5, gr[2]), grain)

func _draw_log(img: Image, y: float, x0: float, x1: float, r: float) -> void:
	_layer(img, _capsule(Vector2(x0 + r, y), Vector2(x1 - r, y), r + 1.0), INK)
	_layer(img, _capsule(Vector2(x0 + r, y), Vector2(x1 - r, y), r), Color(0.50, 0.31, 0.16))
	_layer(img, _circle(x1 - r, y, r + 0.2), INK)
	_layer(img, _circle(x1 - r, y, r - 0.7), Color(0.84, 0.65, 0.42))
	_layer(img, _ring(x1 - r, y, r * 0.35, r * 0.55), Color(0.60, 0.42, 0.24))

func _draw_wood(img: Image) -> void:
	_draw_log(img, 6.5, 3.5, 18.5, 3.2)
	_draw_log(img, 13.8, 1.5, 16.5, 3.2)

func _draw_iron(img: Image) -> void:
	var body := PackedVector2Array([Vector2(6, 6), Vector2(14, 6), Vector2(17.5, 15), Vector2(2.5, 15)])
	var top := PackedVector2Array([Vector2(6, 6), Vector2(14, 6), Vector2(15.2, 9), Vector2(4.8, 9)])
	_layer(img, _polygon(Geometry2D.offset_polygon(body, 1.2)[0]), INK)
	_layer(img, _polygon(body), Color(0.40, 0.42, 0.47))
	_layer(img, _polygon(top), Color(0.64, 0.66, 0.72))

func _draw_stability(img: Image) -> void:
	# Behajlított, izmos kar (erő és rend): felkar dagadó bicepsszel, felfelé álló alkar, ökölbe szorított kéz,
	# az alkaron aranykarperec
	var skin := Color(0.97, 0.77, 0.56)
	var shade := Color(0.84, 0.59, 0.39)
	var upper_a := Vector2(1.0, 16.6)
	var upper_b := Vector2(12.4, 16.0)
	var fore_b := Vector2(15.2, 6.4)
	# tuskontúr
	_layer(img, _capsule(upper_a, upper_b, 3.4), INK)
	_layer(img, _ellipse(7.2, 12.4, 6.0, 4.8, -8.0), INK)
	_layer(img, _capsule(upper_b, fore_b, 3.4), INK)
	_layer(img, _ellipse(15.0, 4.2, 4.4, 3.9, -10.0), INK)
	# bőr
	_layer(img, _capsule(upper_a, upper_b, 2.4), shade)
	_layer(img, _ellipse(7.2, 12.4, 5.0, 3.8, -8.0), skin)
	_layer(img, _capsule(upper_b, fore_b, 2.4), skin)
	_layer(img, _ellipse(15.0, 4.2, 3.4, 2.9, -10.0), skin)
	# az ököl ujjai
	_layer(img, _capsule(Vector2(12.4, 3.2), Vector2(15.6, 2.8), 0.4), Color(INK, 0.75))
	_layer(img, _capsule(Vector2(12.2, 5.2), Vector2(15.4, 5.0), 0.4), Color(INK, 0.75))
	# a bicepsz fénye és a könyökhajlat árnyéka
	_layer(img, _ellipse(6.0, 10.8, 2.4, 1.1, -12.0), Color(1.0, 0.95, 0.84, 0.9))
	_layer(img, _ellipse(12.0, 12.6, 1.0, 1.8, 20.0), Color(shade, 0.9))
	# aranykarperec
	_layer(img, _capsule(Vector2(12.3, 9.6), Vector2(16.9, 10.6), 1.0), INK)
	_layer(img, _capsule(Vector2(12.5, 9.6), Vector2(16.7, 10.5), 0.5), GOLD_LIGHT)
# ── Téma ───────────────────────────────────────────────────────

func _tex_box(path: String, margin: int, content: Vector4, tile: bool) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin; sb.texture_margin_right = margin
	sb.texture_margin_top = margin; sb.texture_margin_bottom = margin
	sb.content_margin_left = content.x; sb.content_margin_top = content.y
	sb.content_margin_right = content.z; sb.content_margin_bottom = content.w
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb

func _font(file: String, weight: int, path: String, fallbacks: Array = []) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(FONTS + file)
	if weight > 0:
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if not fallbacks.is_empty():
		fv.fallbacks = fallbacks
	ResourceSaver.save(fv, OUT + path, ResourceSaver.FLAG_CHANGE_PATH)
	return fv

func _build_theme() -> void:
	var body   := _font("EBGaramond.ttf", 500, "font_body.tres")
	var bold   := _font("EBGaramond.ttf", 650, "font_bold.tres")
	var italic := _font("EBGaramond-Italic.ttf", 500, "font_italic.tres")
	var title  := _font("UncialAntiqua-Regular.ttf", 0, "font_title.tres", [bold])
	var runic  := _font("NotoSansRunic-Regular.ttf", 0, "font_runic.tres", [body])

	var th := Theme.new()
	th.default_font = body
	th.default_font_size = 17

	var sb_panel := _tex_box(OUT + "panel.png", 16, Vector4(14, 12, 14, 12), true)
	var sb_parch := _tex_box(OUT + "parchment.png", 16, Vector4(16, 10, 16, 10), true)
	var sb_tip := _tex_box(OUT + "parchment.png", 16, Vector4(12, 8, 12, 8), true)
	th.set_stylebox("panel", "Panel", sb_panel)
	th.set_stylebox("panel", "PanelContainer", sb_panel)
	th.set_stylebox("panel", "PopupMenu", sb_panel)
	th.set_stylebox("panel", "TooltipPanel", sb_tip)

	th.set_color("font_color", "Label", TEXT_LIGHT)
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	th.set_constant("shadow_offset_x", "Label", 1)
	th.set_constant("shadow_offset_y", "Label", 1)

	var btn_boxes := {
		"normal": _tex_box(OUT + "button_normal.png", 8, Vector4(10, 5, 10, 5), false),
		"hover": _tex_box(OUT + "button_hover.png", 8, Vector4(10, 5, 10, 5), false),
		"pressed": _tex_box(OUT + "button_pressed.png", 8, Vector4(10, 6, 10, 4), false),
		"disabled": _tex_box(OUT + "button_disabled.png", 8, Vector4(10, 5, 10, 5), false),
	}
	for t in ["Button", "OptionButton"]:
		th.set_stylebox("normal", t, btn_boxes["normal"])
		th.set_stylebox("hover", t, btn_boxes["hover"])
		th.set_stylebox("pressed", t, btn_boxes["pressed"])
		th.set_stylebox("hover_pressed", t, btn_boxes["pressed"])
		th.set_stylebox("disabled", t, btn_boxes["disabled"])
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
		th.set_font("font", t, bold)
		th.set_font_size("font_size", t, 16)
		th.set_color("font_color", t, TEXT_LIGHT)
		th.set_color("font_hover_color", t, GOLD_LIGHT)
		th.set_color("font_pressed_color", t, GOLD_LIGHT)
		th.set_color("font_hover_pressed_color", t, GOLD_LIGHT)
		th.set_color("font_focus_color", t, TEXT_LIGHT)
		th.set_color("font_disabled_color", t, Color(0.56, 0.51, 0.43))

	var hover_flat := StyleBoxFlat.new()
	hover_flat.bg_color = Color(GOLD, 0.25)
	th.set_stylebox("hover", "PopupMenu", hover_flat)
	th.set_font("font", "PopupMenu", bold)
	th.set_color("font_color", "PopupMenu", TEXT_LIGHT)
	th.set_color("font_hover_color", "PopupMenu", GOLD_LIGHT)

	th.set_font("font", "TooltipLabel", body)
	th.set_font_size("font_size", "TooltipLabel", 15)
	th.set_color("font_color", "TooltipLabel", TEXT_DARK)
	th.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))

	var line := StyleBoxLine.new()
	line.color = GOLD_DARK
	line.thickness = 1
	th.set_stylebox("separator", "HSeparator", line)

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(0.45, 0.30, 0.16, 0.8)
	grabber.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.2, 0.1, 0.15)
	track.set_corner_radius_all(3)
	th.set_stylebox("grabber", "VScrollBar", grabber)
	th.set_stylebox("grabber_hover", "VScrollBar", grabber)
	th.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	th.set_stylebox("scroll", "VScrollBar", track)

	th.set_color("default_color", "RichTextLabel", TEXT_LIGHT)

	# Típusváltozatok
	th.set_type_variation("HeaderLabel", "Label")
	th.set_font("font", "HeaderLabel", title)
	th.set_font_size("font_size", "HeaderLabel", 21)
	th.set_color("font_color", "HeaderLabel", GOLD_LIGHT)

	th.set_type_variation("TitleLabel", "Label")
	th.set_font("font", "TitleLabel", title)
	th.set_font_size("font_size", "TitleLabel", 66)
	th.set_color("font_color", "TitleLabel", GOLD_LIGHT)
	th.set_color("font_outline_color", "TitleLabel", INK)
	th.set_constant("outline_size", "TitleLabel", 10)
	th.set_constant("shadow_offset_y", "TitleLabel", 3)

	th.set_type_variation("RuneLabel", "Label")
	th.set_font("font", "RuneLabel", runic)
	th.set_font_size("font_size", "RuneLabel", 24)
	th.set_color("font_color", "RuneLabel", GOLD)

	th.set_type_variation("SubtitleLabel", "Label")
	th.set_font("font", "SubtitleLabel", italic)
	th.set_font_size("font_size", "SubtitleLabel", 21)

	th.set_type_variation("SmallLabel", "Label")
	th.set_font_size("font_size", "SmallLabel", 15)

	th.set_type_variation("ParchmentPanel", "Panel")
	th.set_stylebox("panel", "ParchmentPanel", sb_parch)

	th.set_type_variation("ParchmentHeader", "Label")
	th.set_font("font", "ParchmentHeader", title)
	th.set_font_size("font_size", "ParchmentHeader", 18)
	th.set_color("font_color", "ParchmentHeader", RED)
	th.set_color("font_shadow_color", "ParchmentHeader", Color(0, 0, 0, 0))

	th.set_type_variation("ChronicleText", "RichTextLabel")
	th.set_font("normal_font", "ChronicleText", italic)
	th.set_font("italics_font", "ChronicleText", italic)
	th.set_font("bold_font", "ChronicleText", bold)
	th.set_font_size("normal_font_size", "ChronicleText", 17)
	th.set_font_size("bold_font_size", "ChronicleText", 16)
	th.set_color("default_color", "ChronicleText", TEXT_DARK)

	th.set_type_variation("BigButton", "Button")
	th.set_font("font", "BigButton", title)
	th.set_font_size("font_size", "BigButton", 22)

	th.set_type_variation("ActionButton", "Button")
	th.set_font_size("font_size", "ActionButton", 14)

	var err := ResourceSaver.save(th, OUT + "anglo_saxon_theme.tres")
	print("Theme saved: ", err == OK)
