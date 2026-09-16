extends Panel

# HEPTARCHIA – Beállítások ablak (főmenü és játék közös): nyelv, zene, hangeffektek.
# A tartalmát kódból építi fel; a téma (bőrpanel, betűk) automatikusan érvényes rá.

signal language_changed
signal closed

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const GOLD := Color(0.80, 0.61, 0.29)

var _title: Label
var _lbl_language: Label
var _lbl_music: Label
var _lbl_sfx: Label
var _opt_language: OptionButton
var _chk_music: CheckButton
var _chk_sfx: CheckButton
var _sld_music: HSlider
var _sld_sfx: HSlider
var _btn_close: Button

func _ready() -> void:
	set_anchors_preset(PRESET_CENTER)
	custom_minimum_size = Vector2(460, 280)
	offset_left = -230; offset_right = 230; offset_top = -140; offset_bottom = 140
	hide()

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 26; box.offset_right = -26; box.offset_top = 20; box.offset_bottom = -20
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var knot := KnotDivider.new()
	knot.custom_minimum_size = Vector2(0, 14)
	box.add_child(knot)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(grid)

	_lbl_language = Label.new()
	grid.add_child(_lbl_language)
	_opt_language = OptionButton.new()
	_opt_language.size_flags_horizontal = SIZE_EXPAND_FILL
	var i := 0
	for code in Localization.LANGUAGES:
		_opt_language.add_item(Localization.LANGUAGES[code])
		_opt_language.set_item_metadata(i, code)
		i += 1
	_opt_language.item_selected.connect(_on_language_selected)
	grid.add_child(_opt_language)

	_lbl_music = Label.new()
	grid.add_child(_lbl_music)
	var music_row := _audio_row()
	_chk_music = music_row[0]; _sld_music = music_row[1]
	grid.add_child(music_row[2])
	_chk_music.toggled.connect(_on_music_toggled)
	_sld_music.value_changed.connect(func(v: float): AudioManager.set_music_volume(v / 100.0))

	_lbl_sfx = Label.new()
	grid.add_child(_lbl_sfx)
	var sfx_row := _audio_row()
	_chk_sfx = sfx_row[0]; _sld_sfx = sfx_row[1]
	grid.add_child(sfx_row[2])
	_chk_sfx.toggled.connect(_on_sfx_toggled)
	_sld_sfx.value_changed.connect(func(v: float): AudioManager.set_sfx_volume(v / 100.0))
	_sld_sfx.drag_ended.connect(func(_c: bool): AudioManager.play_sfx_click())

	_btn_close = Button.new()
	_btn_close.custom_minimum_size = Vector2(170, 40)
	_btn_close.size_flags_horizontal = SIZE_SHRINK_CENTER
	_btn_close.pressed.connect(close)
	box.add_child(_btn_close)

	apply_texts()

# [CheckButton, HSlider, HBoxContainer]
func _audio_row() -> Array:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	var chk := CheckButton.new()
	chk.flat = true
	var sld := HSlider.new()
	sld.min_value = 0; sld.max_value = 100; sld.step = 1
	sld.size_flags_horizontal = SIZE_EXPAND_FILL
	sld.size_flags_vertical = SIZE_SHRINK_CENTER
	sld.custom_minimum_size = Vector2(150, 20)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.08, 0.05)
	track.border_color = Color(0.52, 0.38, 0.17)
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3; track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(3)
	fill.content_margin_top = 3; fill.content_margin_bottom = 3
	sld.add_theme_stylebox_override("slider", track)
	sld.add_theme_stylebox_override("grabber_area", fill)
	sld.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(chk)
	row.add_child(sld)
	return [chk, sld, row]

func apply_texts() -> void:
	_title.text = tr("SETTINGS_TITLE")
	_lbl_language.text = tr("MENU_LANGUAGE")
	_lbl_music.text = tr("SETTINGS_MUSIC")
	_lbl_sfx.text = tr("SETTINGS_SFX")
	_btn_close.text = tr("DIP_BTN_CLOSE")

func open() -> void:
	# Az aktuális állapot betöltése jelzések kiváltása nélkül
	for i in _opt_language.item_count:
		if _opt_language.get_item_metadata(i) == Localization.current:
			_opt_language.select(i)
	_chk_music.set_pressed_no_signal(AudioManager.music_on)
	_chk_sfx.set_pressed_no_signal(AudioManager.sfx_on)
	_sld_music.set_value_no_signal(AudioManager.music_volume * 100.0)
	_sld_sfx.set_value_no_signal(AudioManager.sfx_volume * 100.0)
	_sld_music.editable = AudioManager.music_on
	_sld_sfx.editable = AudioManager.sfx_on
	apply_texts()
	show()

func close() -> void:
	hide()
	closed.emit()

func _on_music_toggled(on: bool) -> void:
	AudioManager.set_music_on(on)
	_sld_music.editable = on

func _on_sfx_toggled(on: bool) -> void:
	AudioManager.set_sfx_on(on)
	_sld_sfx.editable = on

func _on_language_selected(index: int) -> void:
	Localization.set_language(_opt_language.get_item_metadata(index))
	AudioManager.play_sfx_click()
	apply_texts()
	language_changed.emit()
