extends Control

const Tolto := preload("res://scripts/ui/tolto.gd")

const SettingsPopup := preload("res://scripts/ui/settings_popup.gd")
const AchievementsPopup := preload("res://scripts/ui/achievements_popup.gd")

enum MenuItem { SETTINGS, QUIT, ACHIEVEMENTS }

@onready var btn_new_game:  Button = %btn_new_game
@onready var btn_multiplayer: Button = %btn_multiplayer
@onready var btn_load_game: Button = %btn_load_game
@onready var btn_quit:      Button = %btn_quit
var btn_tutorial: Button    # oktatómód – kódból készül, az Új játék mellé
@onready var btn_menu:      MenuButton = %btn_menu
@onready var faction_group: HBoxContainer = %faction_group
@onready var lbl_faction:   Label  = %lbl_faction
@onready var lbl_sub:       Label  = %lbl_sub
@onready var lbl_choose:    Label  = %lbl_choose

var selected_faction: int = 0
var faction_buttons := ButtonGroup.new()
var dim: ColorRect
var settings: Panel
var achievements: Panel

# A választható királyságok a GameManager.PLAYABLE_FACTIONS sorrendjében;
# leírásuk FACTION_DESC_<azonosító>, színük a térképszín világosabb változata
func _desc_key(f_id: int) -> String:
	return "FACTION_DESC_" + GameManager.faction_id(f_id)

func _color(f_id: int) -> Color:
	return GameManager.faction_color(f_id).lightened(0.2)

func _ready() -> void:
	Localization.culture = ""
	# a királyságok neve a kezdőév szerint (pl. frankok, nem normannok) – egy előző játék éve ne számítson
	GameManager.current_year = GameManager.START_YEAR
	btn_load_game.disabled = not SaveManager.has_save() or not SaveManager.save_matches_dlcs()
	if SaveManager.has_save() and btn_load_game.disabled:
		btn_load_game.tooltip_text = tr("SAVE_DLC_MISMATCH")
	btn_new_game.pressed.connect(_on_new_game)
	btn_multiplayer.pressed.connect(func():
		GameManager.tutorial = false
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn"))
	if Net.active: Net.leave()
	btn_load_game.pressed.connect(_on_load_game)
	btn_quit.pressed.connect(func(): get_tree().quit())
	btn_menu.get_popup().id_pressed.connect(_on_menu_item)
	# a négy nagy gomb két oszlopban, hogy a tizenhárom királyság leírása is kiférjen
	var vbox := btn_new_game.get_parent()
	var buttons := GridContainer.new()
	buttons.columns = 2
	buttons.add_theme_constant_override("h_separation", 10)
	buttons.add_theme_constant_override("v_separation", 8)
	vbox.add_child(buttons)
	vbox.move_child(buttons, btn_new_game.get_index())
	# Oktatómód: az Új játék mellé, hogy aki most ül le, rögtön lássa
	btn_tutorial = Button.new()
	btn_tutorial.pressed.connect(_on_tutorial)
	# ugyanaz a betű és szín, mint a jelenetben beállított nagy gomboké
	btn_tutorial.add_theme_font_override("font", btn_new_game.get_theme_font("font"))
	btn_tutorial.add_theme_font_size_override("font_size", btn_new_game.get_theme_font_size("font_size"))
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		btn_tutorial.add_theme_color_override(c, btn_new_game.get_theme_color(c))
	for b in [btn_new_game, btn_tutorial, btn_multiplayer, btn_load_game, btn_quit]:
		if b.get_parent() != null: b.reparent(buttons)
		else: buttons.add_child(b)
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 46)
	buttons.move_child(btn_tutorial, 1)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.hide()
	add_child(dim)
	settings = SettingsPopup.new()
	add_child(settings)
	settings.language_changed.connect(_apply_texts)
	settings.closed.connect(dim.hide)
	achievements = AchievementsPopup.new()
	add_child(achievements)
	achievements.closed.connect(dim.hide)

	_apply_texts()
	AudioManager.play_music("menu")

func _apply_texts() -> void:
	lbl_sub.text          = tr("MENU_SUBTITLE")
	lbl_choose.text       = tr("MENU_CHOOSE_FACTION")
	btn_new_game.text     = tr("MENU_NEW_GAME")
	btn_tutorial.text     = tr("MENU_TUTORIAL")
	btn_tutorial.tooltip_text = tr("MENU_TUTORIAL_TIP")
	btn_multiplayer.text  = tr("MENU_MULTIPLAYER")
	btn_load_game.text    = tr("MENU_LOAD")
	btn_quit.text         = tr("MENU_QUIT")
	btn_menu.text         = tr("MENU_BUTTON")
	var popup := btn_menu.get_popup()
	popup.clear()
	popup.add_item(tr("SETTINGS_TITLE"), MenuItem.SETTINGS)
	popup.add_item(tr("ACH_TITLE"), MenuItem.ACHIEVEMENTS)
	popup.add_separator()
	popup.add_item(tr("MENU_QUIT"), MenuItem.QUIT)
	_build_faction_buttons()
	_update_faction_label()

func _on_menu_item(id: int) -> void:
	AudioManager.play_sfx_click()
	match id:
		MenuItem.SETTINGS:
			dim.show()
			settings.open()
		MenuItem.ACHIEVEMENTS:
			dim.show()
			achievements.open()
		MenuItem.QUIT:
			get_tree().quit()

func _build_faction_buttons() -> void:
	for child in faction_group.get_children():
		faction_group.remove_child(child)
		child.queue_free()
	# tizenhárom királyság három sorban
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	faction_group.add_child(grid)
	for f_id in GameManager.PLAYABLE_FACTIONS:
		var btn := Button.new()
		var col: Color = _color(f_id)
		btn.text = GameManager.faction_name(f_id)
		btn.custom_minimum_size = Vector2(118, 36)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.tooltip_text = btn.text
		btn.add_theme_font_size_override("font_size", 14)
		btn.toggle_mode = true
		btn.button_group = faction_buttons
		btn.button_pressed = (f_id == selected_faction)
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			btn.add_theme_color_override(c, col)
		for c in ["font_pressed_color", "font_hover_pressed_color"]:
			btn.add_theme_color_override(c, col.lightened(0.35))
		btn.pressed.connect(func(): _select_faction(f_id))
		grid.add_child(btn)

func _select_faction(f_id: int) -> void:
	selected_faction = f_id
	_update_faction_label()
	AudioManager.play_sfx_click()

func _update_faction_label() -> void:
	var text := tr(_desc_key(selected_faction))
	var m: Dictionary = GameManager.mission_of(selected_faction)
	if not m.is_empty():
		text += "\n" + Localization.t("MENU_MISSION", ["MISSION_" + str(m["id"])])
	lbl_faction.text = text
	lbl_faction.add_theme_color_override("font_color", _color(selected_faction))

func _on_new_game() -> void:
	AudioManager.play_sfx_click()
	GameManager.tutorial = false
	# töltőképernyő: festmény és csík, amíg a világ megszületik
	Tolto.indit(get_tree(), func(): GameManager.new_game(selected_faction))

## Oktatómód: ugyanaz a játék, csak végigvezet rajta. Wessexszel indul, mert
## annak a helyzete a legegyszerűbb – van szárazföldi szomszédja, van kikötője,
## és nem kezd háborúban.
func _on_tutorial() -> void:
	AudioManager.play_sfx_click()
	GameManager.tutorial = true
	Tolto.indit(get_tree(), func(): GameManager.new_game(GameManager.Faction.WESSEX))

func _on_load_game() -> void:
	AudioManager.play_sfx_click()
	GameManager.tutorial = false
	if not SaveManager.has_save(): return
	Tolto.indit(get_tree(), func(): return SaveManager.load_game(), "LOADING_SAVE")
