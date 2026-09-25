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
	_epit_lapok()

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

# ── A menü lapjai ─────────────────────────────────────────────
# A fejléc (rúnák, cím, alcím, fonatdísz) mindig látszik; alatta egyszerre egy lap:
#   kezdőlap:    Egyjátékos · Többjátékos · Beállítások · Kilépés
#   egyjátékos:  Új játék · Betöltés · Oktatómód · Vissza
#   új játék:    a nemzetválasztó (a királyságok, a leírás és a nagy küldetés) · Indítás · Vissza
# Esc (vagy a Vissza gomb) egy lappal visszalép.
var lap_fo: VBoxContainer
var lap_egy: VBoxContainer
var lap_uj: VBoxContainer
var btn_egyjatekos: Button
var btn_beallitas: Button
var btn_uj_jatek: Button          # az egyjátékos lapon: a nemzetválasztóhoz visz
var btn_vissza_egy: Button
var btn_vissza_uj: Button

func _nagy_gomb(szel: float = 340.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = &"BigButton"
	b.custom_minimum_size = Vector2(szel, 48)
	b.size_flags_horizontal = SIZE_SHRINK_CENTER
	return b

func _uj_lap(vbox: Control) -> VBoxContainer:
	var l := VBoxContainer.new()
	l.add_theme_constant_override("separation", 10)
	l.alignment = BoxContainer.ALIGNMENT_CENTER
	l.size_flags_vertical = SIZE_EXPAND_FILL
	vbox.add_child(l)
	return l

func _epit_lapok() -> void:
	var vbox := btn_new_game.get_parent()
	lap_fo = _uj_lap(vbox)
	lap_egy = _uj_lap(vbox)
	lap_uj = _uj_lap(vbox)
	# kezdőlap
	btn_egyjatekos = _nagy_gomb()
	btn_egyjatekos.pressed.connect(func(): _lapra(lap_egy))
	btn_beallitas = _nagy_gomb()
	btn_beallitas.pressed.connect(func(): _on_menu_item(MenuItem.SETTINGS))
	lap_fo.add_child(btn_egyjatekos)
	for b in [btn_multiplayer, btn_beallitas, btn_quit]:
		if b.get_parent() != null: b.reparent(lap_fo)
		else: lap_fo.add_child(b)
	# egyjátékos
	btn_uj_jatek = _nagy_gomb()
	btn_uj_jatek.pressed.connect(func(): _lapra(lap_uj))
	btn_tutorial = _nagy_gomb()
	btn_tutorial.pressed.connect(_on_tutorial)
	btn_vissza_egy = _nagy_gomb()
	btn_vissza_egy.pressed.connect(func(): _lapra(lap_fo))
	lap_egy.add_child(btn_uj_jatek)
	btn_load_game.reparent(lap_egy)
	lap_egy.add_child(btn_tutorial)
	lap_egy.add_child(btn_vissza_egy)
	# új játék: a nemzetválasztó a jelenetből ide költözik, alul Vissza és Indítás
	lap_uj.alignment = BoxContainer.ALIGNMENT_BEGIN
	for n in [lbl_choose, faction_group, lbl_faction, vbox.get_node("Knot2")]: n.reparent(lap_uj)
	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	sor.add_theme_constant_override("separation", 12)
	lap_uj.add_child(sor)
	btn_vissza_uj = _nagy_gomb(200.0)
	btn_vissza_uj.pressed.connect(func(): _lapra(lap_egy))
	sor.add_child(btn_vissza_uj)
	btn_new_game.reparent(sor)
	btn_new_game.custom_minimum_size = Vector2(280, 48)
	btn_new_game.size_flags_horizontal = SIZE_SHRINK_CENTER
	for b in [btn_multiplayer, btn_quit, btn_load_game]:
		b.custom_minimum_size = Vector2(340, 48)
		b.size_flags_horizontal = SIZE_SHRINK_CENTER
	_lapra(lap_fo, false)

## Lapváltás egy rövid, lágy áttűnéssel
func _lapra(lap: VBoxContainer, hang: bool = true) -> void:
	if hang: AudioManager.play_sfx_click()
	for l in [lap_fo, lap_egy, lap_uj]:
		l.visible = l == lap
	lap.modulate.a = 0.0
	create_tween().tween_property(lap, "modulate:a", 1.0, 0.18)
	# az első gomb kapja a fókuszt (billentyűzettel is kezelhető)
	var elso: Button = {lap_fo: btn_egyjatekos, lap_egy: btn_uj_jatek, lap_uj: btn_new_game}[lap]
	if is_inside_tree(): elso.grab_focus.call_deferred()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not dim.visible:
		if lap_uj.visible: _lapra(lap_egy)
		elif lap_egy.visible: _lapra(lap_fo)
		get_viewport().set_input_as_handled()

func _apply_texts() -> void:
	lbl_sub.text          = tr("MENU_SUBTITLE")
	lbl_choose.text       = tr("MENU_CHOOSE_FACTION")
	btn_new_game.text     = tr("MENU_START")
	btn_egyjatekos.text   = tr("MENU_SINGLEPLAYER")
	btn_beallitas.text    = tr("SETTINGS_TITLE")
	btn_uj_jatek.text     = tr("MENU_NEW_GAME")
	btn_vissza_egy.text   = tr("MENU_BACK")
	btn_vissza_uj.text    = tr("MENU_BACK")
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

# A népek sávokban, kultúra szerint (GameManager.NEP_CSOPORTOK): balra a csoport neve, mellette a népek.
# Sok nép (a kiegészítőkkel) esetén a terület görgethető, hogy a panel alja ne lógjon ki.
const FAJ_SOR_MAX := 236.0

func _build_faction_buttons() -> void:
	for child in faction_group.get_children():
		faction_group.remove_child(child)
		child.queue_free()
	var gorget := ScrollContainer.new()
	gorget.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gorget.size_flags_horizontal = SIZE_EXPAND_FILL
	faction_group.add_child(gorget)
	var sorok := VBoxContainer.new()
	sorok.size_flags_horizontal = SIZE_EXPAND_FILL
	sorok.add_theme_constant_override("separation", 5)
	gorget.add_child(sorok)
	for cs in GameManager.csoportositva(GameManager.PLAYABLE_FACTIONS):
		var sor := HBoxContainer.new()
		sor.add_theme_constant_override("separation", 8)
		sorok.add_child(sor)
		var cim := Label.new()
		cim.text = tr("NEP_CSOPORT_" + str(cs[0]))
		cim.custom_minimum_size = Vector2(104, 0)
		cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cim.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cim.add_theme_font_size_override("font_size", 13)
		cim.add_theme_color_override("font_color", Color(0.86, 0.72, 0.45))
		sor.add_child(cim)
		var gombok := HFlowContainer.new()
		gombok.size_flags_horizontal = SIZE_EXPAND_FILL
		gombok.add_theme_constant_override("h_separation", 5)
		gombok.add_theme_constant_override("v_separation", 5)
		sor.add_child(gombok)
		for f_id in cs[1]:
			var btn := _faction_button(f_id)
			gombok.add_child(btn)
	# a görgetett terület magassága a tartalomhoz, de legfeljebb FAJ_SOR_MAX
	var igazit := func():
		gorget.custom_minimum_size.y = minf(sorok.get_combined_minimum_size().y, FAJ_SOR_MAX)
	sorok.minimum_size_changed.connect(igazit)
	igazit.call_deferred()

func _faction_button(f_id: int) -> Button:
	var btn := Button.new()
	var col: Color = _color(f_id)
	btn.text = GameManager.faction_name(f_id)
	btn.custom_minimum_size = Vector2(112, 30)
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
	return btn

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
