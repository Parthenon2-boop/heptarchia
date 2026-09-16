extends Control

const SettingsPopup := preload("res://scripts/ui/settings_popup.gd")

enum MenuItem { SETTINGS, QUIT }

@onready var btn_new_game:  Button = %btn_new_game
@onready var btn_multiplayer: Button = %btn_multiplayer
@onready var btn_load_game: Button = %btn_load_game
@onready var btn_quit:      Button = %btn_quit
@onready var btn_menu:      MenuButton = %btn_menu
@onready var faction_group: HBoxContainer = %faction_group
@onready var lbl_faction:   Label  = %lbl_faction
@onready var lbl_sub:       Label  = %lbl_sub
@onready var lbl_choose:    Label  = %lbl_choose

var selected_faction: int = 0
var faction_buttons := ButtonGroup.new()
var dim: ColorRect
var settings: Panel

# Frakció -> leírás nyelvi kulcsa és szín (a név GameManager.faction_name-ből jön)
const FACTION_INFO = {
	0: {"desc": "FACTION_DESC_WESSEX",      "color": Color(0.45, 0.62, 1.0)},
	1: {"desc": "FACTION_DESC_MERCIA",      "color": Color(1.0, 0.82, 0.25)},
	2: {"desc": "FACTION_DESC_NORTHUMBRIA", "color": Color(0.75, 0.52, 1.0)},
	3: {"desc": "FACTION_DESC_EAST_ANGLIA", "color": Color(0.45, 0.88, 0.5)},
	4: {"desc": "FACTION_DESC_VIKINGS",     "color": Color(1.0, 0.42, 0.38)},
	6: {"desc": "FACTION_DESC_NORWEGIANS",  "color": Color(1.0, 0.64, 0.3)},
	5: {"desc": "FACTION_DESC_NORMANS",     "color": Color(0.4, 0.85, 0.85)},
	7: {"desc": "FACTION_DESC_WALES",       "color": Color(0.95, 0.55, 0.8)}
}

func _ready() -> void:
	Localization.culture = ""
	btn_load_game.disabled = not SaveManager.has_save()
	btn_new_game.pressed.connect(_on_new_game)
	btn_multiplayer.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Lobby.tscn"))
	if Net.active: Net.leave()
	btn_load_game.pressed.connect(_on_load_game)
	btn_quit.pressed.connect(func(): get_tree().quit())
	btn_menu.get_popup().id_pressed.connect(_on_menu_item)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.hide()
	add_child(dim)
	settings = SettingsPopup.new()
	add_child(settings)
	settings.language_changed.connect(_apply_texts)
	settings.closed.connect(dim.hide)

	_apply_texts()
	AudioManager.play_music("menu")

func _apply_texts() -> void:
	lbl_sub.text          = tr("MENU_SUBTITLE")
	lbl_choose.text       = tr("MENU_CHOOSE_FACTION")
	btn_new_game.text     = tr("MENU_NEW_GAME")
	btn_multiplayer.text  = tr("MENU_MULTIPLAYER")
	btn_load_game.text    = tr("MENU_LOAD")
	btn_quit.text         = tr("MENU_QUIT")
	btn_menu.text         = tr("MENU_BUTTON")
	var popup := btn_menu.get_popup()
	popup.clear()
	popup.add_item(tr("SETTINGS_TITLE"), MenuItem.SETTINGS)
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
		MenuItem.QUIT:
			get_tree().quit()

func _build_faction_buttons() -> void:
	for child in faction_group.get_children():
		faction_group.remove_child(child)
		child.queue_free()
	# nyolc királyság két sorban
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	faction_group.add_child(grid)
	for f_id in FACTION_INFO:
		var btn := Button.new()
		var col: Color = FACTION_INFO[f_id]["color"]
		btn.text = GameManager.faction_name(f_id)
		btn.custom_minimum_size = Vector2(132, 38)
		btn.add_theme_font_size_override("font_size", 15)
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
	var info = FACTION_INFO.get(selected_faction, {})
	lbl_faction.text = tr(info.get("desc", ""))
	lbl_faction.add_theme_color_override("font_color", info.get("color", Color.WHITE))

func _on_new_game() -> void:
	AudioManager.play_sfx_click()
	GameManager.new_game(selected_faction)
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_load_game() -> void:
	AudioManager.play_sfx_click()
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
