extends Panel

# HEPTARCHIA – Beállítások ablak (főmenü és játék közös).
# Négy fül: Játék (nyelv), Kép (ablakmód, felbontás, monitor, vsync), Hang, Többjátékos.
# A tartalmát kódból építi fel; a téma (bőrpanel, betűk) automatikusan érvényes rá.

signal language_changed
signal closed

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const GOLD := Color(0.80, 0.61, 0.29)

var _title: Label
var _tabs: TabContainer
var _btn_close: Button
var _btn_apply: Button

# Játék fül
var _lbl_language: Label
var _opt_language: OptionButton
# Kép fül
var _lbl_mode: Label
var _opt_mode: OptionButton
var _lbl_res: Label
var _opt_res: OptionButton
var _lbl_monitor: Label
var _opt_monitor: OptionButton
var _lbl_vsync: Label
var _chk_vsync: CheckButton
# Hang fül
var _lbl_music: Label
var _lbl_sfx: Label
var _chk_music: CheckButton
var _chk_sfx: CheckButton
var _sld_music: HSlider
var _sld_sfx: HSlider
# Többjátékos fül
var _lbl_name: Label
var _edit_name: LineEdit
var _lbl_port: Label
var _spin_port: SpinBox
var _lbl_upnp: Label
var _chk_upnp: CheckButton
var _lbl_mp_hint: Label

func _ready() -> void:
	set_anchors_preset(PRESET_CENTER)
	custom_minimum_size = Vector2(560, 420)
	offset_left = -280; offset_right = 280; offset_top = -215; offset_bottom = 215
	hide()

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_left = 22; box.offset_right = -22; box.offset_top = 18; box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	add_child(box)

	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var knot := KnotDivider.new()
	knot.custom_minimum_size = Vector2(0, 14)
	box.add_child(knot)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(_tabs)
	_build_game_tab()
	_build_display_tab()
	_build_audio_tab()
	_build_multiplayer_tab()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_btn_apply = Button.new()
	_btn_apply.custom_minimum_size = Vector2(170, 40)
	_btn_apply.pressed.connect(_apply_all)
	row.add_child(_btn_apply)
	_btn_close = Button.new()
	_btn_close.custom_minimum_size = Vector2(170, 40)
	_btn_close.pressed.connect(close)
	row.add_child(_btn_close)

	apply_texts()

func _tab_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	_tabs.add_child(grid)
	return grid

func _build_game_tab() -> void:
	var grid := _tab_grid()
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

func _build_display_tab() -> void:
	var grid := _tab_grid()
	_lbl_mode = Label.new()
	grid.add_child(_lbl_mode)
	_opt_mode = OptionButton.new()
	_opt_mode.size_flags_horizontal = SIZE_EXPAND_FILL
	_opt_mode.item_selected.connect(func(_i): _refresh_display_enabled())
	grid.add_child(_opt_mode)

	_lbl_res = Label.new()
	grid.add_child(_lbl_res)
	_opt_res = OptionButton.new()
	_opt_res.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(_opt_res)

	_lbl_monitor = Label.new()
	grid.add_child(_lbl_monitor)
	_opt_monitor = OptionButton.new()
	_opt_monitor.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(_opt_monitor)

	_lbl_vsync = Label.new()
	grid.add_child(_lbl_vsync)
	_chk_vsync = CheckButton.new()
	_chk_vsync.flat = true
	grid.add_child(_chk_vsync)

func _build_audio_tab() -> void:
	var grid := _tab_grid()
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

func _build_multiplayer_tab() -> void:
	var grid := _tab_grid()
	_lbl_name = Label.new()
	grid.add_child(_lbl_name)
	_edit_name = LineEdit.new()
	_edit_name.max_length = 20
	_edit_name.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(_edit_name)

	_lbl_port = Label.new()
	grid.add_child(_lbl_port)
	_spin_port = SpinBox.new()
	_spin_port.min_value = 1024
	_spin_port.max_value = 65535
	_spin_port.step = 1
	_spin_port.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(_spin_port)

	_lbl_upnp = Label.new()
	grid.add_child(_lbl_upnp)
	_chk_upnp = CheckButton.new()
	_chk_upnp.flat = true
	grid.add_child(_chk_upnp)

	_lbl_mp_hint = Label.new()
	_lbl_mp_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_mp_hint.add_theme_font_size_override("font_size", 14)
	_lbl_mp_hint.modulate = Color(1, 1, 1, 0.85)
	grid.add_child(_lbl_mp_hint)
	var spacer := Control.new()
	grid.add_child(spacer)

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
	_tabs.set_tab_title(0, tr("SETTINGS_TAB_GAME"))
	_tabs.set_tab_title(1, tr("SETTINGS_TAB_DISPLAY"))
	_tabs.set_tab_title(2, tr("SETTINGS_TAB_AUDIO"))
	_tabs.set_tab_title(3, tr("SETTINGS_TAB_MP"))
	_lbl_language.text = tr("MENU_LANGUAGE")
	_lbl_mode.text = tr("DISPLAY_MODE")
	_lbl_res.text = tr("DISPLAY_RESOLUTION")
	_lbl_monitor.text = tr("DISPLAY_MONITOR")
	_lbl_vsync.text = tr("DISPLAY_VSYNC")
	_lbl_music.text = tr("SETTINGS_MUSIC")
	_lbl_sfx.text = tr("SETTINGS_SFX")
	_lbl_name.text = tr("MP_NAME")
	_lbl_port.text = tr("MP_PORT")
	_lbl_upnp.text = tr("MP_UPNP")
	_lbl_mp_hint.text = tr("SETTINGS_MP_HINT")
	_btn_apply.text = tr("SETTINGS_APPLY")
	_btn_close.text = tr("DIP_BTN_CLOSE")
	_fill_mode_options()

func _fill_mode_options() -> void:
	var selected := _opt_mode.selected
	_opt_mode.clear()
	for mode in [GameSettings.WindowMode.WINDOWED, GameSettings.WindowMode.FULLSCREEN, GameSettings.WindowMode.BORDERLESS]:
		_opt_mode.add_item(tr(GameSettings.window_mode_key(mode)))
		_opt_mode.set_item_metadata(_opt_mode.item_count - 1, mode)
	_opt_mode.select(maxi(selected, 0))

func _fill_display_options() -> void:
	_fill_mode_options()
	for i in _opt_mode.item_count:
		if _opt_mode.get_item_metadata(i) == GameSettings.window_mode: _opt_mode.select(i)
	_opt_res.clear()
	var i := 0
	for r in GameSettings.available_resolutions():
		_opt_res.add_item("%d × %d" % [r.x, r.y])
		_opt_res.set_item_metadata(i, r)
		if r == GameSettings.resolution: _opt_res.select(i)
		i += 1
	_opt_monitor.clear()
	var names := GameSettings.monitor_names()
	for j in names.size():
		_opt_monitor.add_item(names[j])
		_opt_monitor.set_item_metadata(j, j)
	_opt_monitor.select(clampi(GameSettings.monitor, 0, maxi(0, names.size() - 1)))
	_opt_monitor.disabled = names.size() <= 1
	_chk_vsync.set_pressed_no_signal(GameSettings.vsync)
	_refresh_display_enabled()

func _refresh_display_enabled() -> void:
	var windowed: bool = _opt_mode.get_item_metadata(maxi(_opt_mode.selected, 0)) == GameSettings.WindowMode.WINDOWED
	_opt_res.disabled = not windowed

func open() -> void:
	# Az aktuális állapot betöltése jelzések kiváltása nélkül
	for i in _opt_language.item_count:
		if _opt_language.get_item_metadata(i) == Localization.current:
			_opt_language.select(i)
	_fill_display_options()
	_chk_music.set_pressed_no_signal(AudioManager.music_on)
	_chk_sfx.set_pressed_no_signal(AudioManager.sfx_on)
	_sld_music.set_value_no_signal(AudioManager.music_volume * 100.0)
	_sld_sfx.set_value_no_signal(AudioManager.sfx_volume * 100.0)
	_sld_music.editable = AudioManager.music_on
	_sld_sfx.editable = AudioManager.sfx_on
	_edit_name.text = GameSettings.player_name
	_spin_port.set_value_no_signal(GameSettings.port)
	_chk_upnp.set_pressed_no_signal(GameSettings.use_upnp)
	apply_texts()
	show()

# „Alkalmaz”: a kép és a többjátékos beállítások érvényesítése és mentése
func _apply_all() -> void:
	GameSettings.window_mode = _opt_mode.get_item_metadata(maxi(_opt_mode.selected, 0))
	if _opt_res.selected >= 0:
		GameSettings.resolution = _opt_res.get_item_metadata(_opt_res.selected)
	if _opt_monitor.selected >= 0:
		GameSettings.monitor = _opt_monitor.get_item_metadata(_opt_monitor.selected)
	GameSettings.vsync = _chk_vsync.button_pressed
	GameSettings.player_name = _edit_name.text.strip_edges()
	GameSettings.port = int(_spin_port.value)
	GameSettings.use_upnp = _chk_upnp.button_pressed
	GameSettings.apply()
	GameSettings.save_settings()
	AudioManager.play_sfx_click()
	_fill_display_options()

func close() -> void:
	_apply_all()
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
