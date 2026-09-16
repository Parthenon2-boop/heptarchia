extends RefCounted

# HEPTARCHIA LAUNCHER – stílus
# A játék pergamen–bőr–arany palettájából épít témát, képfájlok nélkül (minden StyleBoxFlat).

const INK        := Color(0.10, 0.06, 0.03)
const LEATHER    := Color(0.21, 0.135, 0.08)
const LEATHER_LT := Color(0.37, 0.25, 0.14)
const GOLD       := Color(0.80, 0.61, 0.29)
const GOLD_DARK  := Color(0.52, 0.38, 0.17)
const GOLD_LIGHT := Color(0.97, 0.85, 0.53)
const PARCH      := Color(0.89, 0.81, 0.63)
const PARCH_DARK := Color(0.80, 0.71, 0.52)
const RED        := Color(0.60, 0.15, 0.09)
const TEXT_LIGHT := Color(0.94, 0.88, 0.73)
const TEXT_DARK  := Color(0.22, 0.13, 0.06)
const GREEN      := Color(0.30, 0.45, 0.20)

const FONT_TEXT   := "res://assets/fonts/EBGaramond.ttf"
const FONT_ITALIC := "res://assets/fonts/EBGaramond-Italic.ttf"
const FONT_TITLE  := "res://assets/fonts/UncialAntiqua-Regular.ttf"
const FONT_RUNES  := "res://assets/fonts/NotoSansRunic-Regular.ttf"

static func font(path: String) -> FontFile:
	return load(path)

static func _box(bg: Color, border: Color, width: int = 2, radius: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14; s.content_margin_right = 14
	s.content_margin_top = 8;   s.content_margin_bottom = 8
	return s

static func build_theme() -> Theme:
	var t := Theme.new()
	var text := font(FONT_TEXT)
	t.default_font = text
	t.default_font_size = 17

	# Gombok: bőrháttér, aranykeret
	t.set_stylebox("normal", "Button", _box(LEATHER_LT, GOLD_DARK))
	t.set_stylebox("hover", "Button", _box(Color(0.48, 0.33, 0.17), GOLD_LIGHT))
	t.set_stylebox("pressed", "Button", _box(Color(0.15, 0.09, 0.05), GOLD))
	t.set_stylebox("disabled", "Button", _box(Color(0.30, 0.26, 0.22), Color(0.42, 0.37, 0.31)))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	t.set_color("font_color", "Button", TEXT_LIGHT)
	t.set_color("font_hover_color", "Button", GOLD_LIGHT)
	t.set_color("font_pressed_color", "Button", GOLD_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(0.62, 0.58, 0.52))
	t.set_font_size("font_size", "Button", 18)

	# Panelek: pergamen
	t.set_stylebox("panel", "Panel", _box(PARCH, GOLD_DARK, 2, 4))
	t.set_stylebox("panel", "PanelContainer", _box(PARCH, GOLD_DARK, 2, 4))

	t.set_color("font_color", "Label", TEXT_DARK)
	t.set_color("default_color", "RichTextLabel", TEXT_DARK)
	t.set_stylebox("normal", "RichTextLabel", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	var edit := _box(Color(0.96, 0.92, 0.82), GOLD_DARK, 1, 3)
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", _box(Color(1, 0.98, 0.92), GOLD, 2, 3))
	t.set_color("font_color", "LineEdit", TEXT_DARK)
	t.set_color("caret_color", "LineEdit", INK)

	var pb_bg := _box(Color(0.32, 0.24, 0.16), GOLD_DARK, 1, 3)
	pb_bg.content_margin_left = 0; pb_bg.content_margin_right = 0
	var pb_fg := _box(Color(0.72, 0.52, 0.22), GOLD_LIGHT, 1, 3)
	pb_fg.content_margin_left = 0; pb_fg.content_margin_right = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_color("font_color", "ProgressBar", TEXT_LIGHT)

	t.set_stylebox("panel", "PopupPanel", _box(Color(0.24, 0.16, 0.09), GOLD, 3, 6))
	return t

# "Uncial" címfelirat stílusa egy Labelre
static func make_title(text_value: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text_value
	l.add_theme_font_override("font", font(FONT_TITLE))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
