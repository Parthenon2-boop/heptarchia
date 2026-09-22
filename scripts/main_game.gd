extends Control

# HEPTARCHIA – main_game.gd
# UI: térkép, provincia-panel (építés / toborzás), menetelés, diplomácia, krónika, játékmenü.
# Minden játékos-művelet a Net.request()-en megy át (egyjátékosban helyben, többjátékosban a
# gazdagépen fut le); a felület a Net.state_changed jelzésre frissül.
# Minden megjelenő szöveg a lang/*.json nyelvi fájlokból jön (tr / Localization.t).

const BUILDINGS := ["burh", "farm", "tower", "port", "mine", "mint", "market"]
const HISTORY_COLOR := "#6b1d0f"
const TOP_RESOURCES := ["silver", "food", "wood", "iron", "stability"]
const ICON_PATH := "res://assets/ui/icon_%s.png"
const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const SettingsPopup := preload("res://scripts/ui/settings_popup.gd")
const RealmPanel := preload("res://scripts/ui/realm_panel.gd")
const KnotDivider := preload("res://scripts/ui/knot_divider.gd")

enum GameMenu { SAVE, LOAD, SETTINGS, MAIN_MENU, QUIT, ACHIEVEMENTS }
const AchievementsPopup := preload("res://scripts/ui/achievements_popup.gd")

@onready var top_box:       HBoxContainer = %TopBox
@onready var lbl_year:      Label = %lbl_year

@onready var lbl_prov_name: Label  = %lbl_prov_name
@onready var lbl_prov_pop:  Label  = %lbl_prov_pop
@onready var lbl_prov_info: Label  = %lbl_prov_info
@onready var action_grid:   GridContainer = %action_grid
@onready var btn_move_army: Button = %btn_move_army
@onready var btn_attack:    Button = %btn_attack

@onready var lbl_witan_title: Label  = %lbl_witan_title
@onready var lbl_witan_1:     Label  = %lbl_witan_1
@onready var lbl_witan_2:     Label  = %lbl_witan_2
@onready var lbl_witan_3:     Label  = %lbl_witan_3
@onready var btn_witan_gift:  Button = %btn_witan_gift
@onready var lbl_dip_header:  Label  = %lbl_dip_header
@onready var lbl_locked_note: Label  = %lbl_locked_note
@onready var dip_buttons: Array = [%btn_dip_mercia, %btn_dip_northumbria, %btn_dip_east_anglia, %btn_dip_vikings]

@onready var lbl_chronicle_title: Label = %lbl_chronicle_title
@onready var txt_chronicle: RichTextLabel = %txt_chronicle
@onready var kronika_panel: Panel = $ChroniclePanel

@onready var lbl_battle_title: Label  = %lbl_battle_title
@onready var lbl_battle_desc:  Label  = %lbl_battle_desc
@onready var btn_shield_wall:  Button = %btn_shield_wall
@onready var btn_charge:       Button = %btn_charge
@onready var btn_pay_danegeld: Button = %btn_pay_danegeld

@onready var lbl_event_title: Label  = %lbl_event_title
@onready var lbl_event_desc:  Label  = %lbl_event_desc
@onready var btn_event_1:     Button = %btn_event_1
@onready var btn_event_2:     Button = %btn_event_2
@onready var btn_event_3:     Button = %btn_event_3
@onready var event_buttons: Array = [btn_event_1, btn_event_2, btn_event_3]

@onready var msg_lbl_title: Label  = %msg_lbl_title
@onready var msg_lbl_desc:  Label  = %msg_lbl_desc
@onready var msg_btn_ok:    Button = %msg_btn_ok

@onready var lbl_end_title:     Label  = %lbl_end_title
@onready var lbl_end_desc:      Label  = %lbl_end_desc
@onready var btn_restart:       Button = %btn_restart
@onready var btn_end_main_menu: Button = %btn_end_main_menu

@onready var btn_next_turn:    Button = %btn_next_turn
@onready var btn_game_menu:    MenuButton = %btn_game_menu

@onready var battle_popup:    Panel = $BattlePopup
@onready var event_popup:     Panel = $EventPopup
@onready var diplomacy_popup: Panel = $DiplomacyPopup
@onready var message_popup:   Panel = $MessagePopup
@onready var end_game_panel:  Panel = $EndGamePanel
@onready var dim:             ColorRect = $Dim
@onready var map_view                  = $MapView
@onready var flash_overlay:   ColorRect = $FlashOverlay

@onready var dip_lbl_title:    Label  = %dip_lbl_title
@onready var dip_lbl_status:   Label  = %dip_lbl_status
@onready var dip_lbl_hint:     Label  = %dip_lbl_hint
@onready var dip_btn_gift:     Button = %dip_btn_gift
@onready var dip_btn_marriage: Button = %dip_btn_marriage
@onready var dip_btn_vassal:   Button = %dip_btn_vassal
@onready var dip_btn_war:      Button = %dip_btn_war
@onready var dip_btn_peace:    Button = %dip_btn_peace
@onready var dip_btn_close:    Button = %dip_btn_close

var selected_province: String = ""
var selected_locked: String = ""       # kijelölt zárolt vidék nyelvi kulcsa
var battle_is_raid: bool = false
var attack_target: String = ""
var _attack_src_box: VBoxContainer = null   # a „honnan támadsz” jelölőnégyzetek
var _attack_src: Array = []                 # [{name, naval, on}]
var dip_target_faction: int = -1
var dip_factions: Array = []           # a diplomácia gombokhoz tartozó frakciók
var res_labels: Dictionary = {}
var res_boxes: Dictionary = {}
var action_buttons: Dictionary = {}   # kind -> {"button", "name", "content"}
var popups: Array = []
var settings: Panel
var msg_btn_decline: Button
var _menu_text_timer: SceneTreeTimer
var _message_queue: Array = []        # [{title, desc, proposal}]
var _current_proposal: Dictionary = {}
var _end_shown: bool = false
var _last_fx_id: int = 0              # az utolsó már megjelenített térképfelirat
var lbl_event_kind: Label
var lbl_amb_header: Label
var amb_labels: Array = []
var actions: Array = []               # a játékos kultúrájának építési / toborzási lehetőségei
var norse: bool = false
var homeland_popup: Panel
var hl_title: Label
var hl_desc: Label
var hl_btn_warriors: Button
var hl_btn_raid: Button
var hl_btn_gift: Button
var btn_homeland: Button
var btn_papal: Button
var papal_popup: Panel
var pp_title: Label
var pp_desc: Label
var pp_btn_gift: Button
var pp_btn_blessing: Button
var pp_btn_mediation: Button
var dip_btn_trade: Button
var dip_btn_map: Button       # „Mutasd a térképen”
var btn_ambush: Button        # rajtaütés az elvonuló ellenséges seregen
var _ambush_pick: Dictionary = {}   # melyik menetre üt rá (ambush_targets egy eleme)
var dip_grid: GridContainer
var dip_scroll: ScrollContainer
var btn_battle_cancel: Button
var btn_kegyelem: Button      # „Kegyelem”: az utolsó tartomány helyett hűbéressé fogadod
var lbl_utolso: Label         # figyelmeztetés, hogy ez a nép utolsó földje
var lbl_mission: Label
var achievements_popup: Panel
var _toast: PanelContainer
var _toast_label: Label
var _toast_queue: Array = []

const FX_COLORS := {
	"good": Color(0.62, 0.95, 0.55), "bad": Color(1.0, 0.45, 0.38), "gold": Color(1.0, 0.86, 0.45),
	"war": Color(1.0, 0.32, 0.25), "shield": Color(0.6, 0.8, 1.0), "neutral": Color(0.98, 0.94, 0.84)
}
const EFFECT_ORDER := ["silver", "food", "wood", "iron", "stability", "witan", "witan_0", "witan_1", "witan_2",
	"fyrd", "thegn", "defense", "population", "food_prod", "silver_prod", "church", "burhs", "levy",
	"truce_vikings", "peace_wessex", "danegeld", "war_vikings", "war_wessex", "ally_random", "fyrd_at", "raid",
	"hof", "ships", "homeland", "papal", "rome_journey", "war_on", "truce_on", "followup"]

func _ready() -> void:
	norse = GameManager.is_norse(GameManager.player_faction)
	var culture := GameManager.culture_of(GameManager.player_faction)
	Localization.culture = "" if culture == "english" else culture.to_upper()
	actions = GameManager.actions_for(GameManager.player_faction)
	settings = SettingsPopup.new()
	add_child(settings)
	settings.closed.connect(func(): _close_popup(settings))
	settings.language_changed.connect(_on_language_changed)
	achievements_popup = AchievementsPopup.new()
	add_child(achievements_popup)
	achievements_popup.closed.connect(func(): _close_popup(achievements_popup))
	popups = [battle_popup, event_popup, diplomacy_popup, message_popup, end_game_panel, settings, achievements_popup]
	for p in popups: p.hide()
	dim.hide()
	flash_overlay.hide()
	flash_overlay.color = Color(1, 1, 1, 0)
	map_view.province_clicked.connect(select_province)
	map_view.locked_region_clicked.connect(_on_locked_clicked)
	map_view.hover_text_provider = _hover_text
	_build_top_bar()
	_build_action_buttons()
	_build_message_buttons()
	_build_event_extras()
	_last_fx_id = GameManager.fx_counter
	_connect_ui()
	_build_side_panel()       # a bal panel: gombok, a tanács, a célok és a diplomácia saját ablakban
	_build_homeland_ui()      # a diplomácia-rács után kerül a helyére
	_build_papal_ui()
	_build_realm_panel()      # a gombok alatt: ország-tábla és teendők
	_apply_static_texts()
	Net.state_changed.connect(_on_state_changed)
	Net.command_result.connect(_on_command_result)
	Net.notification_received.connect(_on_notification)
	Net.session_ended.connect(_on_session_ended)
	update_all()
	AudioManager.play_music("game")
	# Oktatómód: a végigvezető ablak. Mindig a felület fölé kerül, és a
	# játékosnak magának kell megcsinálnia, amit kér.
	if GameManager.tutorial:
		var okt = preload("res://scripts/ui/tutorial.gd").new()
		add_child(okt)
		okt.inditsd(self)
	# a kiegészítők saját gombjai és ablakai (pl. viking portyák)
	DLC.hook("on_game_ui", [self])
	_check_pending.call_deferred()

func _connect_ui() -> void:
	btn_next_turn.pressed.connect(_on_next_turn)
	btn_move_army.pressed.connect(_on_move_army)
	btn_attack.pressed.connect(_on_attack)
	btn_witan_gift.pressed.connect(func(): Net.request("witan_gift"))
	btn_shield_wall.pressed.connect(func(): _on_tactic("shield_wall"))
	btn_charge.pressed.connect(func(): _on_tactic("charge"))
	btn_pay_danegeld.pressed.connect(func(): _on_tactic("danegeld"))
	for i in event_buttons.size():
		event_buttons[i].pressed.connect(_on_event_choice.bind(i))
	btn_restart.pressed.connect(_on_restart)
	btn_end_main_menu.pressed.connect(_on_main_menu)
	btn_game_menu.get_popup().id_pressed.connect(_on_game_menu_item)
	btn_game_menu.about_to_popup.connect(_refresh_game_menu)
	msg_btn_ok.pressed.connect(func(): _answer_message(true))
	dip_btn_gift.pressed.connect(func(): Net.request("gift", {"target": dip_target_faction}))
	dip_btn_marriage.pressed.connect(func(): Net.request("marriage", {"target": dip_target_faction}))
	dip_btn_vassal.pressed.connect(func(): Net.request("vassal", {"target": dip_target_faction}))
	dip_btn_war.pressed.connect(func(): Net.request("war", {"target": dip_target_faction}))
	# a béke gomb már nem azonnal küld: előbb megszabod, mit kérsz érte
	dip_btn_peace.pressed.connect(func(): open_peace_terms(dip_target_faction))
	dip_btn_close.pressed.connect(func(): _close_popup(diplomacy_popup))
	# Kereskedelmi egyezmény (a béke gomb alatt)
	dip_btn_trade = Button.new()
	dip_btn_peace.get_parent().add_child(dip_btn_trade)
	dip_btn_peace.get_parent().move_child(dip_btn_trade, dip_btn_peace.get_index() + 1)
	dip_btn_trade.pressed.connect(func(): Net.request("trade", {"target": dip_target_faction}))
	# „Mutasd a térképen”: a diplomácia ablakból a térkép odaugrik ahhoz az
	# országhoz – arra a tartományra, ami még az övé. Enélkül a játékosnak
	# kézzel kellett keresgélnie, hol van egyáltalán még földje.
	dip_btn_map = Button.new()
	dip_btn_trade.get_parent().add_child(dip_btn_map)
	dip_btn_trade.get_parent().move_child(dip_btn_map, dip_btn_trade.get_index() + 1)
	dip_btn_map.pressed.connect(_dip_show_on_map)
	_epit_dip_portre()
	_epit_kronika()
	_epit_tron_popup()
	_epit_bukas_popup()
	_epit_unrest_sort()
	_epit_beke_popup()
	# Rajtaütés a tartományod mellett elvonuló ellenséges seregen
	btn_ambush = Button.new()
	btn_ambush.theme_type_variation = &"ActionButton"
	btn_ambush.custom_minimum_size = Vector2(0, 38)
	btn_ambush.visible = false
	btn_attack.get_parent().add_child(btn_ambush)
	btn_attack.get_parent().move_child(btn_ambush, btn_attack.get_index() + 1)
	btn_ambush.pressed.connect(_on_ambush)
	# A többi királyság gombjai két oszlopban, görgethető listában (a jelenet négy gombja + kódból készülők)
	var first: Button = dip_buttons[0]
	var box := first.get_parent()
	dip_scroll = ScrollContainer.new()
	dip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dip_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	dip_scroll.custom_minimum_size = Vector2(0, 110)
	box.add_child(dip_scroll)
	box.move_child(dip_scroll, first.get_index())
	var spacer := box.get_node_or_null("Spacer2")
	if spacer: spacer.hide()
	dip_grid = GridContainer.new()
	dip_grid.columns = 2
	dip_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	dip_grid.add_theme_constant_override("h_separation", 4)
	dip_grid.add_theme_constant_override("v_separation", 4)
	dip_scroll.add_child(dip_grid)
	for b in dip_buttons:
		b.reparent(dip_grid)
	while dip_buttons.size() < GameManager.ALL_FACTIONS.size() - 1:
		var extra := Button.new()
		extra.name = "btn_dip_%d" % (dip_buttons.size() + 1)
		dip_grid.add_child(extra)
		dip_buttons.append(extra)
	for i in dip_buttons.size():
		var b: Button = dip_buttons[i]
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 32)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.add_theme_font_size_override("font_size", 13)
		b.pressed.connect(_on_dip_button.bind(i))
	# Támadás visszavonása: a csataablakban „Mégse” gomb (portyánál nem látszik – arra felelni kell)
	btn_battle_cancel = Button.new()
	btn_battle_cancel.pressed.connect(_on_battle_cancel)
	btn_pay_danegeld.get_parent().add_child(btn_battle_cancel)
	# „Kegyelem”: ha ez a nép UTOLSÓ tartománya, a roham helyett hűbéressé
	# fogadhatod – így nem tűnik el a térképről, és adót fizet neked.
	lbl_utolso = Label.new()
	lbl_utolso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_utolso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_utolso.add_theme_font_size_override("font_size", 13)
	lbl_utolso.add_theme_color_override("font_color", Color(0.98, 0.83, 0.42))
	lbl_utolso.visible = false
	btn_pay_danegeld.get_parent().add_child(lbl_utolso)
	btn_kegyelem = Button.new()
	btn_kegyelem.visible = false
	btn_kegyelem.pressed.connect(_on_kegyelem)
	btn_pay_danegeld.get_parent().add_child(btn_kegyelem)
	for b in [btn_shield_wall, btn_charge, btn_pay_danegeld, btn_battle_cancel, btn_kegyelem]:
		b.custom_minimum_size = Vector2(0, 42)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for b in [btn_attack, btn_move_army]:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_year.clip_text = true
	lbl_year.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl_prov_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_prov_pop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for p in [battle_popup, event_popup, diplomacy_popup, message_popup, end_game_panel]:
		p.set_meta("base_h", p.offset_bottom - p.offset_top)

# ── Felépítés ─────────────────────────────────────────────────

func _build_top_bar() -> void:
	for r in TOP_RESOURCES:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = MOUSE_FILTER_PASS
		var icon := TextureRect.new()
		icon.texture = load(ICON_PATH % r)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.size_flags_vertical = SIZE_SHRINK_CENTER
		icon.mouse_filter = MOUSE_FILTER_PASS
		var lbl := Label.new()
		lbl.add_theme_font_override("font", BOLD_FONT)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.mouse_filter = MOUSE_FILTER_PASS
		box.add_child(icon)
		box.add_child(lbl)
		top_box.add_child(box)
		res_labels[r] = lbl
		res_boxes[r] = box
	top_box.move_child(btn_game_menu, -1)

func _build_action_buttons() -> void:
	for kind in actions:
		var btn := Button.new()
		btn.theme_type_variation = &"ActionButton"
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 0)
		content.mouse_filter = MOUSE_FILTER_IGNORE
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_override("font", BOLD_FONT)
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.mouse_filter = MOUSE_FILTER_IGNORE
		# a hosszú épületnév ne lógjon ki a gombból (a teljes név a súgóban olvasható)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var cost := HBoxContainer.new()
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.add_theme_constant_override("separation", 2)
		cost.mouse_filter = MOUSE_FILTER_IGNORE
		content.add_child(name_lbl)
		content.add_child(cost)
		btn.add_child(content)
		btn.pressed.connect(_on_action.bind(kind))
		action_grid.add_child(btn)
		action_buttons[kind] = {"button": btn, "name": name_lbl, "content": content, "cost": cost, "cost_shown": null}
		GameManager.acting_faction = GameManager.player_faction
		_show_cost(kind, GameManager.level_costs(kind)[0] if kind in GameManager.LEVELED else GameManager.action_cost("", kind))

# A gomb költségsora (ikon + szám erőforrásonként); csak változáskor épül újra
func _show_cost(kind: String, c: Dictionary) -> void:
	var entry: Dictionary = action_buttons[kind]
	if entry["cost_shown"] == c: return
	entry["cost_shown"] = c
	var box: HBoxContainer = entry["cost"]
	for child in box.get_children():
		child.queue_free()
	for r in GameManager.RESOURCE_ORDER:
		if not c.has(r): continue
		var icon := TextureRect.new()
		icon.texture = load(ICON_PATH % r)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(14, 14)
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		var num := Label.new()
		num.text = str(c[r]) + " "
		num.add_theme_font_size_override("font_size", 13)
		num.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(icon)
		box.add_child(num)

# Az üzenetablak mellé "Elutasítom" gomb a más játékosoktól érkező ajánlatokhoz
func _build_message_buttons() -> void:
	var box: VBoxContainer = msg_btn_ok.get_parent()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	msg_btn_ok.reparent(row)
	msg_btn_decline = Button.new()
	msg_btn_decline.custom_minimum_size = Vector2(160, 40)
	msg_btn_decline.pressed.connect(func(): _answer_message(false))
	row.add_child(msg_btn_decline)

# Az eseményablak fölé a döntés fajtája, a Witan-panelbe a királyi célok
func _build_event_extras() -> void:
	lbl_event_kind = Label.new()
	lbl_event_kind.theme_type_variation = &"SmallLabel"
	lbl_event_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_event_kind.add_theme_color_override("font_color", Color(0.85, 0.66, 0.35))
	var box: VBoxContainer = lbl_event_title.get_parent()
	box.add_child(lbl_event_kind)
	box.move_child(lbl_event_kind, 0)
	for b in event_buttons:
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 15)

	var wbox: VBoxContainer = btn_witan_gift.get_parent()
	wbox.add_theme_constant_override("separation", 4)
	wbox.grow_vertical = GROW_DIRECTION_END
	# a panel szélessége kötött: a hosszú címek törjenek, ne lógjanak ki balra
	wbox.grow_horizontal = GROW_DIRECTION_END
	for l in [lbl_witan_title, lbl_dip_header]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for l in [lbl_witan_1, lbl_witan_2, lbl_witan_3]:
		l.add_theme_font_size_override("font_size", 14)
	# a zárolt vidékekről szóló megjegyzés helyét a célok kapják; súgóként megmarad
	lbl_locked_note.hide()
	var at := btn_witan_gift.get_index() + 1
	lbl_amb_header = Label.new()
	lbl_amb_header.theme_type_variation = &"HeaderLabel"
	lbl_amb_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_amb_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_amb_header.mouse_filter = MOUSE_FILTER_PASS
	wbox.add_child(lbl_amb_header)
	wbox.move_child(lbl_amb_header, at)
	for i in GameManager.AMBITION_SLOTS:
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", 14)
		l.mouse_filter = MOUSE_FILTER_PASS
		wbox.add_child(l)
		wbox.move_child(l, at + 1 + i)
		amb_labels.append(l)
	# A királyság nagy küldetése (végső célja) a királyi célok fölött, arany színnel
	lbl_mission = Label.new()
	lbl_mission.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_mission.add_theme_font_override("font", BOLD_FONT)
	lbl_mission.add_theme_font_size_override("font_size", 14)
	lbl_mission.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	lbl_mission.mouse_filter = MOUSE_FILTER_PASS
	wbox.add_child(lbl_mission)
	wbox.move_child(lbl_mission, at)
	_build_toast()

# ── A bal panel: nagy gombok, mindegyik a saját ablakát nyitja ──────
# A tanács (Witan / Thing / llys…), a királyi célok és a diplomácia listája nem fért el egymás alatt,
# ezért mindhárom egy-egy gombbá lett (a gombon a lényeg: támogatottság, a nagy küldetés állása,
# a háborúk száma), a részletek pedig saját ablakban nyílnak meg. A dip_scroll ezután egy láthatatlan
# horgony a bal panelen: az anyaország, Róma és a kiegészítők gombjai ez alá kerülnek, mint eddig.
var side_btn_witan: Button
var side_btn_goals: Button
var side_btn_dip: Button
var realm_panel: VBoxContainer     # ország-tábla + teendők a gombok alatt
var witan_popup: Panel
var goals_popup: Panel
var diplist_popup: Panel
var amb_desc_labels: Array = []
var lbl_mission_desc: Label

func _build_side_panel() -> void:
	var wbox: VBoxContainer = btn_witan_gift.get_parent()
	witan_popup = _make_side_popup(430, 340)
	goals_popup = _make_side_popup(470, 440)
	diplist_popup = _make_side_popup(470, 520)
	# a tanács ablaka
	var w_box: VBoxContainer = witan_popup.get_child(0)
	for n in [lbl_witan_title, lbl_witan_1, lbl_witan_2, lbl_witan_3, btn_witan_gift]:
		n.reparent(w_box)
	lbl_witan_title.theme_type_variation = &"HeaderLabel"
	lbl_witan_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [lbl_witan_1, lbl_witan_2, lbl_witan_3]:
		l.add_theme_font_size_override("font_size", 16)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn_witan_gift.custom_minimum_size = Vector2(0, 40)
	# a célok ablaka: a nagy küldetés és a királyi célok, alattuk a leírásuk és a jutalmuk
	var g_box: VBoxContainer = goals_popup.get_child(0)
	lbl_amb_header.reparent(g_box)
	lbl_mission.reparent(g_box)
	lbl_mission.add_theme_font_size_override("font_size", 16)
	lbl_mission_desc = _desc_label()
	g_box.add_child(lbl_mission_desc)
	for l in amb_labels:
		l.reparent(g_box)
		l.add_theme_font_size_override("font_size", 16)
		var d := _desc_label()
		g_box.add_child(d)
		amb_desc_labels.append(d)
	# a diplomácia ablaka: a királyságok görgethető listája (rákattintva a megszokott diplomáciai ablak)
	var d_box: VBoxContainer = diplist_popup.get_child(0)
	lbl_dip_header.reparent(d_box)
	lbl_dip_header.theme_type_variation = &"HeaderLabel"
	lbl_dip_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var list_scroll := dip_scroll
	list_scroll.reparent(d_box)
	list_scroll.custom_minimum_size = Vector2(0, 340)
	for b in dip_buttons:
		b.custom_minimum_size = Vector2(0, 38)
		b.add_theme_font_size_override("font_size", 15)
	for n in ["Knot1", "Knot2", "Spacer1", "Spacer2"]:
		var node := wbox.get_node_or_null(n)
		if node: node.hide()
	for p in [witan_popup, goals_popup, diplist_popup]:
		var close := Button.new()
		close.custom_minimum_size = Vector2(0, 40)
		close.pressed.connect(_close_popup.bind(p))
		close.set_meta("close_button", true)
		p.get_child(0).add_child(close)
	# a bal panel gombjai
	side_btn_witan = _side_button(wbox, func(): _open_popup(witan_popup))
	side_btn_goals = _side_button(wbox, func(): _open_popup(goals_popup))
	side_btn_dip = _side_button(wbox, func(): AudioManager.play_sfx_diplomacy(); _open_popup(diplist_popup))
	# a horgony: az anyaország, Róma és a kiegészítők gombjai ez alá kerülnek
	dip_scroll = ScrollContainer.new()
	dip_scroll.custom_minimum_size = Vector2.ZERO
	dip_scroll.mouse_filter = MOUSE_FILTER_IGNORE
	wbox.add_child(dip_scroll)
	wbox.move_child(dip_scroll, side_btn_dip.get_index() + 1)

# A bal panel alsó fele: az ország-tábla (uralkodó, birtokok, haderő, készletek kitartása)
# és a teendők listája. Görgethető, hogy kis ablakban se lógjon ki semmi.
func _build_realm_panel() -> void:
	# a bal panel doboza: a btn_witan_gift ekkor már a tanács ABLAKÁBAN van, ezért
	# a helyben maradó horgony (dip_scroll) szülőjéből indulunk ki
	var wbox: VBoxContainer = dip_scroll.get_parent()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 90)
	wbox.add_child(scroll)
	realm_panel = RealmPanel.new()
	realm_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(realm_panel)
	realm_panel.setup(self, BOLD_FONT)

func _make_side_popup(w: float, h: float) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(PRESET_CENTER)
	p.offset_left = -w / 2.0; p.offset_right = w / 2.0
	p.offset_top = -h / 2.0; p.offset_bottom = h / 2.0
	add_child(p)
	# a jelenet ablakai (diplomácia, üzenet…) fölötte nyílnak meg
	move_child(p, dim.get_index() + 1)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_left = 22; vb.offset_right = -22; vb.offset_top = 16; vb.offset_bottom = -18
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	p.set_meta("base_h", h)
	p.hide()
	popups.append(p)
	return p

# ── Trónváltás: az új király bemutatása ────────────────────────
#
# Ha a valódi történelem szerint meghal az uralkodód, középen felnyílik egy
# ablak: a nagy festett arckép, alatta a neve és a négysoros életrajza, hogy
# tudd, ki került a trónra. Az elődjéről egy sor emlékezik meg.

const TRON_PORTRE := 220.0

var tron_popup: Panel
var tron_cim: Label
var tron_portre: Control
var tron_nev: Label
var tron_leiras: Label
var tron_gomb: Button


func _epit_tron_popup() -> void:
	tron_popup = _make_side_popup(470, 560)
	var box: VBoxContainer = tron_popup.get_child(0)

	tron_cim = Label.new()
	tron_cim.theme_type_variation = &"HeaderLabel"
	tron_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tron_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tron_cim)

	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sor)
	tron_portre = preload("res://scripts/ui/ruler_portrait.gd").new()
	tron_portre.custom_minimum_size = Vector2(TRON_PORTRE, TRON_PORTRE)
	sor.add_child(tron_portre)

	tron_nev = Label.new()
	tron_nev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tron_nev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tron_nev.add_theme_font_size_override("font_size", 19)
	box.add_child(tron_nev)

	tron_leiras = _desc_label()
	tron_leiras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tron_leiras.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tron_leiras)

	tron_gomb = Button.new()
	tron_gomb.custom_minimum_size = Vector2(0, 42)
	tron_gomb.pressed.connect(func(): _close_popup(tron_popup))
	box.add_child(tron_gomb)


## Megmutatja az új királyt. A `vals` a GameManager.pending_succession tartalma.
func show_succession_popup(vals: Dictionary) -> void:
	if tron_popup == null: return
	var f := int(vals.get("faction", -1))
	var elozo := str(vals.get("elozo", ""))
	var uj := str(vals.get("uj", ""))
	if uj == "": return
	tron_cim.text = Localization.t("SUCCESSION_TITLE", [elozo])
	tron_portre.beallit(uj, GameManager.culture_of(f), GameManager.faction_color(f),
		GameManager.current_year)
	tron_nev.text = tr(uj)
	tron_nev.add_theme_color_override("font_color", GameManager.faction_color(f).lightened(0.35))
	# a négysoros életrajz; ha egy új uralkodónak még nincs, marad a koronázó mondat
	var bio := tr(uj + "_BIO")
	if bio == uj + "_BIO": bio = ""
	tron_leiras.text = Localization.t("SUCCESSION_BODY", [GameManager.faction_key(f), uj, GameManager.current_year])
	if bio != "": tron_leiras.text += "\n\n" + bio
	tron_gomb.text = tr("SUCCESSION_OK")
	AudioManager.play_sfx_diplomacy()
	_open_popup(tron_popup)


# ── Egy nép kiesése ────────────────────────────────────────────
#
# Ha elfoglalod valakinek az utolsó tartományát, a népe eltűnik a térképről.
# Ezt nem illik szó nélkül hagyni: felnyílik egy ablak a megadó uralkodóval.
# Az arcképe megfakulva jelenik meg – leteszi az övét, ahogy a krónikák írják.

var bukas_popup: Panel
var bukas_cim: Label
var bukas_portre: Control
var bukas_nev: Label
var bukas_leiras: Label
var bukas_gomb: Button


func _epit_bukas_popup() -> void:
	bukas_popup = _make_side_popup(460, 520)
	var box: VBoxContainer = bukas_popup.get_child(0)

	bukas_cim = Label.new()
	bukas_cim.theme_type_variation = &"HeaderLabel"
	bukas_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bukas_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(bukas_cim)

	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sor)
	bukas_portre = preload("res://scripts/ui/ruler_portrait.gd").new()
	bukas_portre.custom_minimum_size = Vector2(TRON_PORTRE * 0.85, TRON_PORTRE * 0.85)
	# a bukott király arcképe kifakul – ennyi marad belőle a krónikákban
	bukas_portre.modulate = Color(0.62, 0.58, 0.54)
	sor.add_child(bukas_portre)

	bukas_nev = Label.new()
	bukas_nev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bukas_nev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bukas_nev.add_theme_font_size_override("font_size", 18)
	bukas_nev.modulate = Color(0.82, 0.78, 0.72)
	box.add_child(bukas_nev)

	bukas_leiras = _desc_label()
	bukas_leiras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bukas_leiras.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(bukas_leiras)

	bukas_gomb = Button.new()
	bukas_gomb.custom_minimum_size = Vector2(0, 42)
	bukas_gomb.pressed.connect(func(): _close_popup(bukas_popup))
	box.add_child(bukas_gomb)


## Egy nép kiesését mutatja meg. A `vals` a GameManager.pending_elimination tartalma.
func show_elimination_popup(vals: Dictionary) -> void:
	if bukas_popup == null: return
	var f := int(vals.get("faction", -1))
	if f < 0: return
	var ruler := str(vals.get("ruler", ""))
	var hol := str(vals.get("province", ""))
	bukas_cim.text = Localization.t("REALM_FELL_TITLE", [GameManager.faction_key(f)])
	bukas_portre.visible = ruler != ""
	bukas_nev.visible = ruler != ""
	if ruler != "":
		bukas_portre.beallit(ruler, GameManager.culture_of(f), GameManager.faction_color(f),
			GameManager.current_year)
		bukas_nev.text = tr(ruler)
	bukas_leiras.text = Localization.t("REALM_FELL_BODY",
		[GameManager.faction_key(f), GameManager.province_label(hol), GameManager.current_year])
	bukas_gomb.text = tr("REALM_FELL_OK")
	AudioManager.play_sfx_victory()
	_open_popup(bukas_popup)


func _desc_label() -> Label:
	var d := Label.new()
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 13)
	d.modulate = Color(1, 1, 1, 0.78)
	return d

func _side_button(box: VBoxContainer, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.98, 0.88, 0.62))
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.pressed.connect(action)
	box.add_child(b)
	var last := -1
	for n in [side_btn_witan, side_btn_goals, side_btn_dip]:
		if n != null and n != b: last = maxi(last, n.get_index())
	box.move_child(b, last + 1)
	return b

# A gombok felirata: a tanács támogatottsága, a nagy küldetés állása, a háborúk száma
func _update_side_buttons() -> void:
	if side_btn_witan == null: return
	var pf := GameManager.player_faction
	side_btn_witan.text = Localization.t("SIDE_WITAN", [Localization.tc("WITAN_TITLE"), roundi(GameManager.witan_average_opinion())])
	side_btn_witan.tooltip_text = tr("SIDE_WITAN_TIP")
	var m: Dictionary = GameManager.mission_of(pf)
	var list: Array = GameManager.realms[pf].get("ambitions", [])
	if m.is_empty():
		side_btn_goals.text = Localization.t("SIDE_GOALS_PLAIN", ["AMBITIONS_TITLE", list.size()])
	else:
		var prog: Array = GameManager.mission_progress(pf)
		side_btn_goals.text = Localization.t("SIDE_GOALS", ["AMBITIONS_TITLE", prog[0], prog[1], list.size()])
	side_btn_goals.tooltip_text = tr("SIDE_GOALS_TIP")
	var wars := 0
	for f in GameManager.ALL_FACTIONS:
		if f != pf and GameManager.is_alive(f) and GameManager.is_at_war(pf, f): wars += 1
	side_btn_dip.text = Localization.t("SIDE_DIP_WARS", ["DIP_HEADER", wars]) if wars > 0 else tr("DIP_HEADER")
	side_btn_dip.tooltip_text = tr("SIDE_DIP_TIP")
	for p in [witan_popup, goals_popup, diplist_popup]:
		for c in p.get_child(0).get_children():
			if c is Button and c.has_meta("close_button"): c.text = tr("DIP_BTN_CLOSE")

# Felül középen felbukkanó értesítés (pl. új érdem); nem akasztja meg a játékot
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.mouse_filter = MOUSE_FILTER_IGNORE
	_toast.z_index = 60
	_toast.anchor_left = 0.5; _toast.anchor_right = 0.5
	_toast.offset_top = 58
	_toast.grow_horizontal = GROW_DIRECTION_BOTH
	_toast_label = Label.new()
	_toast_label.add_theme_font_override("font", BOLD_FONT)
	_toast_label.add_theme_font_size_override("font_size", 17)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	add_child(_toast)
	_toast.hide()

func _show_toast(text: String) -> void:
	_toast_queue.append(text)
	if not _toast.visible: _next_toast()

func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast.hide()
		return
	_toast_label.text = _toast_queue.pop_front()
	_toast.reset_size()
	_toast.offset_left = -_toast.size.x / 2.0
	_toast.offset_right = _toast.size.x / 2.0
	_toast.modulate.a = 0.0
	_toast.show()
	AudioManager.play_sfx_victory()
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.3)
	tw.tween_interval(3.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_next_toast)

# Dánoknak: "Dánia (anyaország)" gomb a diplomácia alatt és a segítségkérő ablak
# (csak akinek van tengerentúli anyaországa, lásd GameManager.HOMELAND_FACTIONS)
func _build_homeland_ui() -> void:
	if not GameManager.has_homeland(GameManager.player_faction): return
	btn_homeland = Button.new()
	btn_homeland.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	var box := dip_scroll.get_parent()
	box.add_child(btn_homeland)
	box.move_child(btn_homeland, dip_scroll.get_index() + 1)
	btn_homeland.clip_text = true
	btn_homeland.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn_homeland.pressed.connect(open_homeland)

	homeland_popup = Panel.new()
	homeland_popup.set_anchors_preset(PRESET_CENTER)
	homeland_popup.offset_left = -290; homeland_popup.offset_right = 290
	homeland_popup.offset_top = -270; homeland_popup.offset_bottom = 270
	add_child(homeland_popup)
	move_child(homeland_popup, message_popup.get_index())
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_left = 22; vb.offset_right = -22; vb.offset_top = 20; vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 10)
	homeland_popup.add_child(vb)
	hl_title = Label.new()
	hl_title.theme_type_variation = &"HeaderLabel"
	hl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hl_title)
	var knot := Control.new()
	knot.custom_minimum_size = Vector2(0, 14)
	knot.set_script(KnotDivider)
	vb.add_child(knot)
	hl_desc = Label.new()
	hl_desc.theme_type_variation = &"SubtitleLabel"
	hl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl_desc.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(hl_desc)
	hl_btn_warriors = Button.new()
	hl_btn_raid = Button.new()
	hl_btn_gift = Button.new()
	var close := Button.new()
	close.text = tr("DIP_BTN_CLOSE")
	for b in [hl_btn_warriors, hl_btn_raid, hl_btn_gift, close]:
		b.custom_minimum_size = Vector2(0, 40)
		vb.add_child(b)
	hl_btn_warriors.pressed.connect(func(): Net.request("homeland_help", {"kind": "warriors"}))
	hl_btn_raid.pressed.connect(func(): Net.request("homeland_help", {"kind": "raid"}))
	hl_btn_gift.pressed.connect(func(): Net.request("homeland_gift"))
	close.pressed.connect(func(): _close_popup(homeland_popup))
	popups.append(homeland_popup)
	homeland_popup.hide()

# Keresztény uralkodóknak: "✝ Róma" gomb a diplomácia alatt és a pápai ablak (ajándék, áldás, közvetítés)
func _build_papal_ui() -> void:
	if not GameManager.is_christian(GameManager.player_faction): return
	btn_papal = Button.new()
	btn_papal.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	btn_papal.clip_text = true
	btn_papal.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var box := dip_scroll.get_parent()
	box.add_child(btn_papal)
	box.move_child(btn_papal, dip_scroll.get_index() + 1)
	btn_papal.pressed.connect(open_papal)

	papal_popup = Panel.new()
	papal_popup.set_anchors_preset(PRESET_CENTER)
	papal_popup.offset_left = -290; papal_popup.offset_right = 290
	papal_popup.offset_top = -260; papal_popup.offset_bottom = 260
	add_child(papal_popup)
	move_child(papal_popup, message_popup.get_index())
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	vb.offset_left = 22; vb.offset_right = -22; vb.offset_top = 20; vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 10)
	papal_popup.add_child(vb)
	pp_title = Label.new()
	pp_title.theme_type_variation = &"HeaderLabel"
	pp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pp_title)
	var knot := Control.new()
	knot.custom_minimum_size = Vector2(0, 14)
	knot.set_script(KnotDivider)
	vb.add_child(knot)
	pp_desc = Label.new()
	pp_desc.theme_type_variation = &"SubtitleLabel"
	pp_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pp_desc.size_flags_vertical = SIZE_EXPAND_FILL
	vb.add_child(pp_desc)
	pp_btn_gift = Button.new()
	pp_btn_blessing = Button.new()
	pp_btn_mediation = Button.new()
	var close := Button.new()
	close.text = tr("DIP_BTN_CLOSE")
	for b in [pp_btn_gift, pp_btn_blessing, pp_btn_mediation, close]:
		b.custom_minimum_size = Vector2(0, 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(b)
	pp_btn_gift.pressed.connect(func(): Net.request("papal_gift"))
	pp_btn_blessing.pressed.connect(func(): Net.request("papal_blessing"))
	pp_btn_mediation.pressed.connect(func(): Net.request("papal_mediation"))
	close.pressed.connect(func(): _close_popup(papal_popup))
	papal_popup.set_meta("base_h", 520.0)
	popups.append(papal_popup)
	papal_popup.hide()

func open_papal() -> void:
	_refresh_papal_ui()
	AudioManager.play_sfx_diplomacy()
	_open_popup(papal_popup)

func _refresh_papal_ui() -> void:
	if papal_popup == null: return
	var gm = GameManager
	var r: Dictionary = gm.realms[gm.player_faction]
	var rel := int(r.get("papal", gm.PAPAL_START))
	pp_title.text = tr("PAPAL_TITLE")
	var lines: PackedStringArray = [
		Localization.t("PAPAL_POPE", [gm.pope()]),
		Localization.t("PAPAL_RELATION", [rel, gm.papal_opinion_key(rel)]),
		Localization.t("PAPAL_CHANCE", [roundi(gm.papal_chance() * 100)]),
	]
	# vallási egység: mennyire van egy hiten az ország
	var egyseg := gm.religious_unity(gm.player_faction)
	lines.append(Localization.t("PAPAL_UNITY", [egyseg]))
	if gm.is_excommunicated(gm.player_faction):
		lines.append("")
		lines.append(Localization.t("PAPAL_EXCOMM_LINE", [gm.pope(), gm.EXCOMM_LIFT_AT]))
	lines.append("")
	lines.append(tr("PAPAL_EFFECTS"))
	var away := int(r.get("king_away", 0))
	if away > 0:
		lines.append("")
		lines.append(Localization.t("PAPAL_KING_AWAY", [{"dur": away}]))
	var wait: int = gm.papal_wait()
	if wait > 0:
		lines.append(Localization.t("PAPAL_WAIT", [{"dur": wait}]))
	pp_desc.text = "\n".join(lines)
	var can := _can_act()
	pp_btn_gift.text = Localization.t("PAPAL_BTN_GIFT", [gm.PAPAL_GIFT])
	pp_btn_gift.disabled = not can or gm.silver < gm.PAPAL_GIFT
	pp_btn_blessing.text = tr("PAPAL_BTN_BLESSING")
	pp_btn_blessing.tooltip_text = tr("PAPAL_BLESSING_TIP")
	pp_btn_blessing.disabled = not can or wait > 0
	var target: int = gm._papal_mediation_target()
	pp_btn_mediation.text = Localization.t("PAPAL_BTN_MEDIATION", [gm.faction_key(target)]) if target >= 0 else tr("PAPAL_BTN_MEDIATION_NONE")
	pp_btn_mediation.tooltip_text = tr("PAPAL_MEDIATION_TIP")
	pp_btn_mediation.disabled = not can or wait > 0 or target < 0
	btn_papal.text = Localization.t("PAPAL_BUTTON", [rel])
	# a kiközösítés a gombon is látszódjon, ne csak az ablakban
	if gm.is_excommunicated(gm.player_faction):
		btn_papal.text = "⛓ " + btn_papal.text
		btn_papal.add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
		btn_papal.tooltip_text = Localization.t("PAPAL_EXCOMM_LINE", [gm.pope(), gm.EXCOMM_LIFT_AT])
	else:
		btn_papal.remove_theme_color_override("font_color")
		btn_papal.tooltip_text = ""
	btn_papal.tooltip_text = tr("PAPAL_BUTTON_TIP")
	var angry: bool = rel <= gm.PAPAL_HOSTILE
	btn_papal.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35) if angry else Color(1.0, 0.92, 0.6))

func _show_papal_result(r: Dictionary) -> void:
	var title := tr("PAPAL_TITLE")
	if not r.get("ok", false):
		var reason: String = r.get("reason", "")
		if reason != "": show_message(title, tr("PAPAL_REASON_" + reason))
		return
	if not r.get("accepted", false):
		AudioManager.play_sfx_defeat()
		show_message(title, Localization.t("PAPAL_REFUSED", [r.get("pope", "")]))
		return
	AudioManager.play_sfx_victory()
	if r.get("kind", "") == "papal_blessing":
		show_message(title, Localization.t("PAPAL_BLESSING_OK", [r.get("pope", "")]))
	else:
		show_message(title, Localization.t("PAPAL_MEDIATION_OK", [r.get("pope", ""),
			GameManager.faction_key(int(r.get("target", -1)))]))

func open_homeland() -> void:
	_refresh_homeland_ui()
	AudioManager.play_sfx_diplomacy()
	_open_popup(homeland_popup)

func _refresh_homeland_ui() -> void:
	if homeland_popup == null: return
	var gm = GameManager
	var r: Dictionary = gm.realms[gm.player_faction]
	var rel := int(r["homeland"])
	var offer: Dictionary = gm.homeland_offer()
	var lines: PackedStringArray = [
		Localization.t("HOMELAND_KING", [_homeland_name(), gm.homeland_king()]),
		Localization.t("HOMELAND_RELATION", [rel, gm.homeland_opinion_key(rel)]),
		Localization.t("HOMELAND_CHANCE", [roundi(gm.homeland_chance() * 100)]),
		"",
		Localization.t("HOMELAND_OFFER_WARRIORS", [offer["fyrd"], offer["thegn"], offer["ships"], {"dur": gm.HOMELAND_FLEET_TURNS}]),
		Localization.t("HOMELAND_OFFER_RAID_CONQUEST" if offer["conquest"] else "HOMELAND_OFFER_RAID", [int(offer["raid"]) * 8])
	]
	for fl in r["homeland_fleets"]:
		lines.append(Localization.t("HOMELAND_FLEET_ON_WAY", [fl["to"], {"dur": int(fl["turns"])}]))
	var wait: int = gm.homeland_wait()
	if wait > 0:
		lines.append(Localization.t("HOMELAND_WAIT", [{"dur": wait}]))
	hl_desc.text = "\n".join(lines)
	var can := _can_act() and wait == 0
	hl_btn_warriors.disabled = not can
	hl_btn_raid.disabled = not can or gm._homeland_raid_targets().is_empty()
	hl_btn_raid.tooltip_text = tr("HOMELAND_NO_TARGET") if gm._homeland_raid_targets().is_empty() else tr("HOMELAND_RAID_TIP")
	hl_btn_warriors.tooltip_text = tr("HOMELAND_WARRIORS_TIP")
	hl_btn_gift.disabled = not _can_act() or gm.silver < gm.HOMELAND_GIFT
	btn_homeland.text = Localization.t("HOMELAND_BUTTON_REL", [_homeland_name(), rel])
	var angry := rel <= GameManager.HOMELAND_WARN
	btn_homeland.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35) if angry else Color(1.0, 0.86, 0.45))
	if angry:
		hl_desc.text += "\n\n" + Localization.t("HOMELAND_WRATH_WARNING", [gm.HOMELAND_HOSTILE])

func _homeland_name() -> String:
	return GameManager.homeland_name_key(GameManager.player_faction)

func _show_homeland_result(r: Dictionary) -> void:
	var title := Localization.t("HOMELAND_TITLE", [_homeland_name()])
	if not r.get("ok", false):
		var reason: String = r.get("reason", "")
		if reason != "": show_message(title, tr("HOMELAND_REASON_" + reason))
		return
	var king: String = r.get("king", "")
	if not r.get("accepted", false):
		AudioManager.play_sfx_defeat()
		show_message(title, Localization.t("HOMELAND_REFUSED", [king]))
		return
	AudioManager.play_sfx_victory()
	if r.get("kind", "") == "raid":
		var text := Localization.t("HOMELAND_RAID_SENT", [king, r.get("target", ""), r.get("power", 0)])
		var rr: Dictionary = r.get("raid_result", {})
		if rr.is_empty():
			text += "\n\n" + tr("HOMELAND_RAID_PENDING")
		elif rr.get("paid_danegeld", false):
			text += "\n\n" + Localization.t("HOMELAND_RAID_GAFOL", [rr.get("loot", 0)])
		elif rr.get("won", true):
			text += "\n\n" + tr("HOMELAND_RAID_REPELLED")
		elif r.get("conquest", false):
			text += "\n\n" + Localization.t("HOMELAND_RAID_CONQUERED", [r.get("target", ""), rr.get("loot", 0)])
		else:
			text += "\n\n" + Localization.t("HOMELAND_RAID_LOOT", [rr.get("loot", 0)])
		show_message(title, text)
	else:
		show_message(title, Localization.t("HOMELAND_WARRIORS_SENT", [king, r.get("fyrd", 0), r.get("thegn", 0),
			r.get("ships", 0), r.get("to", ""), {"dur": int(r.get("turns", 2))}]))

# A jelenetben rögzített (nem változó) feliratok az aktuális nyelven
func _apply_static_texts() -> void:
	lbl_witan_title.text     = Localization.tc("WITAN_TITLE")
	lbl_chronicle_title.text = tr("CHRONICLE_TITLE")
	lbl_dip_header.text      = tr("DIP_HEADER")
	lbl_locked_note.text     = tr("LOCKED_NOTE")
	lbl_dip_header.tooltip_text = tr("LOCKED_NOTE")
	lbl_dip_header.mouse_filter = MOUSE_FILTER_PASS
	lbl_amb_header.text      = tr("AMBITIONS_TITLE")
	lbl_amb_header.tooltip_text = tr("AMBITIONS_TIP")
	# a felirata az update_witan_ui()-ban áll össze, mert az árat és a hatást is mutatja
	if btn_homeland:
		btn_homeland.text = Localization.t("HOMELAND_BUTTON", [_homeland_name()])
		btn_homeland.tooltip_text = Localization.t("HOMELAND_BUTTON_TIP", [_homeland_name()])
		hl_btn_warriors.text = tr("HOMELAND_BTN_WARRIORS")
		hl_btn_raid.text = tr("HOMELAND_BTN_RAID")
		hl_btn_gift.text = Localization.t("HOMELAND_BTN_GIFT", [GameManager.HOMELAND_GIFT])
		hl_title.text = Localization.t("HOMELAND_TITLE", [_homeland_name()])
	btn_game_menu.text       = tr("MENU_BUTTON")
	btn_end_main_menu.text   = tr("BTN_MAIN_MENU")
	btn_restart.text         = tr("BTN_RESTART")
	btn_shield_wall.text     = tr("BTN_SHIELD_WALL")
	btn_charge.text          = tr("BTN_CHARGE")
	btn_pay_danegeld.text    = tr("BTN_DANEGELD")
	btn_battle_cancel.text   = tr("BTN_CANCEL_ATTACK")
	msg_btn_decline.text     = tr("BTN_DECLINE")
	dip_btn_gift.text        = tr("DIP_BTN_GIFT")
	dip_btn_marriage.text    = tr("DIP_BTN_MARRIAGE")
	dip_btn_vassal.text      = tr("DIP_BTN_VASSAL")
	dip_btn_war.text         = tr("DIP_BTN_WAR")
	dip_btn_peace.text       = tr("DIP_BTN_PEACE")
	dip_btn_trade.text       = Localization.t("DIP_BTN_TRADE", [GameManager.PROPOSAL_COSTS["trade"]])
	dip_btn_trade.tooltip_text = Localization.t("DIP_TRADE_TIP", [roundi(GameManager.TRADE_BONUS * 100), roundi(GameManager.TRADE_MAX_BONUS * 100)])
	dip_btn_map.text         = tr("DIP_BTN_MAP")
	dip_btn_map.tooltip_text = tr("DIP_BTN_MAP_TIP")
	dip_btn_close.text       = tr("DIP_BTN_CLOSE")
	_refresh_game_menu()
	for r in TOP_RESOURCES:
		res_boxes[r].tooltip_text = tr("RES_" + r.to_upper())
	for kind in actions:
		action_buttons[kind]["name"].text = Localization.tc(GameManager.level_key(kind, 1)) if kind in GameManager.LEVELED else Localization.tc("ACT_" + kind.to_upper())

# ── UI frissítés ──────────────────────────────────────────────

func update_all() -> void:
	update_ui(); update_witan_ui(); update_chronicle_ui(); update_info_panel(); refresh_map()
	_update_diplomacy_buttons(); _update_turn_button(); update_ambitions_ui(); update_mission_ui()
	_update_side_buttons()
	if realm_panel: realm_panel.refresh()
	if diplomacy_popup.visible: _refresh_diplomacy_ui()
	if btn_homeland: _refresh_homeland_ui()
	DLC.hook("on_game_update", [self])
	if btn_papal: _refresh_papal_ui()
	_play_map_fx()
	for id in Achievements.check(GameManager.player_faction):
		_show_toast(Localization.t("ACH_UNLOCKED", ["ACH_" + id]))

func _on_state_changed() -> void:
	if not GameManager.realms.has(GameManager.player_faction): return
	update_all()
	# a parancs eredménye (csatajelentés) előbb jelenjen meg, mint a következő portya / esemény
	_check_pending.call_deferred()

func update_ui() -> void:
	var pf = GameManager.player_faction
	lbl_year.text = Localization.t("UI_YEAR", [GameManager.faction_key(pf), GameManager.current_year, GameManager.get_season_name()])
	var away := int(GameManager.realms[pf].get("king_away", 0))
	if away > 0: lbl_year.text += "  · " + Localization.t("UI_KING_AWAY", [{"dur": away}])
	var inc := GameManager.get_income()
	for r in ["silver", "food", "wood", "iron"]:
		res_labels[r].text = "%d  %s" % [GameManager.get(r), _signed(inc[r]) if inc[r] != 0 else "±0"]
		# ha a sereg többet eszik, mint amennyit a föld ad, pirosan jelez
		if inc[r] < 0: res_labels[r].add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
		else: res_labels[r].remove_theme_color_override("font_color")
	var up: Dictionary = GameManager.army_upkeep()
	var gross: Dictionary = GameManager.get_gross_income()
	for r in ["silver", "food"]:
		res_boxes[r].tooltip_text = tr("RES_" + r.to_upper()) + "\n" + \
			Localization.t("RES_UPKEEP_LINE", [gross[r], up[r], inc[r]])
	# a kereskedelmi egyezmények többlete minden termelésen
	var trade := roundi(GameManager.trade_bonus(pf) * 100)
	for r in ["silver", "food", "wood", "iron"]:
		if r in ["wood", "iron"]: res_boxes[r].tooltip_text = tr("RES_" + r.to_upper())
		if trade > 0: res_boxes[r].tooltip_text += "\n" + Localization.t("RES_TRADE_LINE", [trade, GameManager.trade_partners(pf).size()])
	# a hűbéresek adója külön sorban – eddig csak beleolvadt a bevételbe
	var hubersek: Array = GameManager.vassals_of(pf)
	if not hubersek.is_empty():
		res_boxes["silver"].tooltip_text += "\n" + Localization.t("RES_VASSAL_LINE",
			[GameManager.vassal_tribute(pf), hubersek.size()])
	res_labels["stability"].text = str(GameManager.stability)
	# A rend nem varázsszám: lássuk tételesen, mi mozgatja körről körre.
	GameManager.acting_faction = pf
	var valt := GameManager.stability_per_turn()
	res_labels["stability"].text += "  %s" % (_signed(valt) if valt != 0 else "±0")
	if valt < 0: res_labels["stability"].add_theme_color_override("font_color", Color(1.0, 0.45, 0.38))
	else: res_labels["stability"].remove_theme_color_override("font_color")
	var stab_sorok: Array = [tr("RES_STABILITY")]
	for m in GameManager.stability_factors():
		stab_sorok.append("%s   %s" % [_signed(int(m["value"])), tr(str(m["key"]))])
	if stab_sorok.size() == 1: stab_sorok.append(tr("STAB_NONE"))
	stab_sorok.append("─────")
	stab_sorok.append(Localization.t("STAB_TOTAL", [_signed(valt) if valt != 0 else "±0"]))
	if "stability" in res_boxes: res_boxes["stability"].tooltip_text = "\n".join(stab_sorok)

func update_witan_ui() -> void:
	var labels = [lbl_witan_1, lbl_witan_2, lbl_witan_3]
	for i in labels.size():
		var opinion: int = GameManager.witan[i]["opinion"]
		labels[i].text = Localization.t("WITAN_LINE", [GameManager.witan_member_key(GameManager.player_faction, i),
			GameManager.witan_opinion_label(opinion), opinion])
	# Az ajándék ára és hatása legyen kiírva, és ne lehessen ezüstöt a semmibe
	# önteni, ha már mindenki maximálisan támogat.
	var telitett := not GameManager.witan_gift_useful()
	btn_witan_gift.disabled = GameManager.silver < GameManager.WITAN_GIFT_COST or telitett or not _can_act()
	btn_witan_gift.text = Localization.t("WITAN_GIFT_BTN2",
		[GameManager.WITAN_GIFT_COST, GameManager.WITAN_GIFT_MIN, GameManager.WITAN_GIFT_MAX])
	if telitett:
		btn_witan_gift.tooltip_text = tr("WITAN_GIFT_FULL")
	elif GameManager.silver < GameManager.WITAN_GIFT_COST:
		btn_witan_gift.tooltip_text = Localization.t("WITAN_GIFT_POOR", [GameManager.WITAN_GIFT_COST])
	else:
		btn_witan_gift.tooltip_text = Localization.t("WITAN_GIFT_TIP",
			[GameManager.WITAN_GIFT_COST, GameManager.WITAN_GIFT_MIN, GameManager.WITAN_GIFT_MAX])

# A nagy küldetés sora: "★ Anglia egyesítése 5/15"; a súgóban a hiányzó provinciák és a jutalom
func update_mission_ui() -> void:
	var pf := GameManager.player_faction
	var m: Dictionary = GameManager.mission_of(pf)
	lbl_mission.visible = not m.is_empty()
	if lbl_mission_desc: lbl_mission_desc.visible = not m.is_empty()
	if m.is_empty(): return
	var key := "MISSION_" + str(m["id"])
	var prog: Array = GameManager.mission_progress(pf)
	var done: bool = GameManager.realms[pf].get("mission_done", false)
	lbl_mission.text = ("✔ " if done else "★ ") + Localization.t("MISSION_LINE", [key, prog[0], prog[1]])
	var missing: PackedStringArray = []
	for pname in m["provinces"]:
		if GameManager.provinces.get(pname, {}).get("faction", -1) != pf: missing.append(GameManager.province_label(pname))
	var tip := tr(key + "_DESC")
	if not missing.is_empty():
		tip += "\n\n" + Localization.t("MISSION_MISSING", [", ".join(missing)])
	tip += "\n" + Localization.t("AMBITION_REWARD", [effects_summary(GameManager.MISSION_REWARD)])
	lbl_mission.tooltip_text = tip
	# a célok ablakában a leírás látszik is (nem csak súgóban)
	if lbl_mission_desc:
		lbl_mission_desc.text = tip
		lbl_mission_desc.visible = true

func update_ambitions_ui() -> void:
	var list: Array = GameManager.realms[GameManager.player_faction].get("ambitions", [])
	for i in amb_labels.size():
		var l: Label = amb_labels[i]
		l.visible = i < list.size()
		if i < amb_desc_labels.size(): amb_desc_labels[i].visible = l.visible
		if not l.visible: continue
		var a: Dictionary = list[i]
		var data := GameManager.EventsData.ambition(str(a["id"]))
		if data.is_empty(): continue
		var cur := GameManager.ambition_stat(data["stat"])
		l.text = "♦ %s  %d/%d" % [Localization.tc("AMB_" + a["id"]), mini(cur, int(a["target"])), int(a["target"])]
		l.tooltip_text = Localization.t("AMB_%s_DESC" % a["id"], [int(a["target"])]) + "\n" + \
			Localization.t("AMBITION_REWARD", [effects_summary(data["reward"])])
		if i < amb_desc_labels.size(): amb_desc_labels[i].text = l.tooltip_text

# Térképen felúszó feliratok az új eseményekhez (építés, portya, hódítás, lázadás…)
func _play_map_fx() -> void:
	var pf := GameManager.player_faction
	for fx in GameManager.map_fx:
		if int(fx["id"]) <= _last_fx_id: continue
		var f := int(fx["f"])
		if f != -1 and f != pf: continue
		var text: String = effects_summary(fx["e"], ", ") if fx["k"] == "FX_EFFECTS" else Localization.t(fx["k"], fx["a"])
		if fx["k"] == "FX_AMBITION":
			text = Localization.t(fx["k"], fx["a"])
		map_view.spawn_floater(fx["p"], text, FX_COLORS.get(fx["c"], Color.WHITE))
	_last_fx_id = maxi(_last_fx_id, GameManager.fx_counter)

# Hatáslista olvasható összefoglalója, pl. "+30 ezüst, −5 stabilitás"
func effects_summary(efx: Dictionary, sep: String = " · ") -> String:
	var parts: PackedStringArray = []
	for key in EFFECT_ORDER:
		if not efx.has(key): continue
		# az anyaországgal való viszony csak annak számít, akinek van anyaországa
		if key == "homeland" and not GameManager.has_homeland(GameManager.player_faction): continue
		var v = efx[key]
		match key:
			"witan_0", "witan_1", "witan_2":
				parts.append(Localization.t("EFF_WITAN_MEMBER", [_signed(v),
					GameManager.witan_member_key(GameManager.player_faction, int(key.right(1)))]))
			"truce_vikings", "peace_wessex", "danegeld":
				parts.append(Localization.t("EFF_" + key.to_upper(), [{"dur": int(v)}]))
			"war_vikings", "war_wessex", "ally_random", "followup", "church", "hof", "rome_journey":
				parts.append(tr("EFF_" + key.to_upper()))
			"fyrd_at":
				parts.append(tr("EFF_FYRD_" + str(v).to_upper()))
			"war_on":
				parts.append(Localization.t("EFF_WAR_ON", [GameManager.faction_key(int(v))]))
			"truce_on":
				parts.append(Localization.t("EFF_TRUCE_ON", [GameManager.faction_key(int(v[0])), {"dur": int(v[1])}]))
			"raid":
				parts.append(Localization.t("EFF_RAID", [int(v) * 8]))
			"burhs", "levy":
				parts.append(Localization.t("EFF_" + key.to_upper(), [int(v)]))
			_:
				parts.append(Localization.t("EFF_" + key.to_upper(), [_signed(v)]))
	# a kiegészítők saját hatásai (EFF_<KULCS> szöveggel; a szöveges érték paraméterként)
	for key in efx:
		if key in EFFECT_ORDER or tr("EFF_" + key.to_upper()) == "EFF_" + key.to_upper(): continue
		var v = efx[key]
		parts.append(Localization.t("EFF_" + key.to_upper(), [v if v is String else _signed(v)]))
	return sep.join(parts) if not parts.is_empty() else tr("EFF_NONE")

func _signed(v) -> String:
	return ("+%d" % int(v)) if int(v) > 0 else ("−%d" % absi(int(v)))

func update_chronicle_ui() -> void:
	var all := GameManager.chronicle_for(GameManager.player_faction)
	var entries = all.slice(max(0, all.size() - KRONIKA_BEJEGYZES), all.size())
	var lines := PackedStringArray()
	for e in entries:
		var parts := GameManager.chronicle_parts(e)
		var body := str(parts[1]).replace("[", "[lb]")
		if GameManager.is_history_entry(e):
			# Történelmi érdekesség: sötétvörös, mint a kéziratok rubrikái
			body = "[color=%s]%s[/color]" % [HISTORY_COLOR, body]
		lines.append(body if parts[0] == "" else "[b]%s:[/b] %s" % [parts[0], body])
	txt_chronicle.text = "\n".join(lines)


# ── A krónika panel magassága ──────────────────────────────────
#
# Alapból alacsony, hogy a térképre lehessen figyelni; a fejléc jobb szélén lévő
# nyíllal összecsukható, a panel FELSŐ SZÉLÉT pedig egérrel föl-le lehet húzni.
# Ha nagyra húzod, a krónika végigolvasható – a görgetősáv visszavisz a korábbi
# évekhez, és amíg visszafelé olvasol, egy új bejegyzés nem ránt vissza a végére.

const KRONIKA_KICSI   := 40.0     # összecsukva: csak a fejléc
const KRONIKA_ALAP    := 116.0    # alapértelmezett (a régi 150 helyett)
const KRONIKA_MIN     := 90.0     # ennél kisebbre húzva csukódjon össze
const KRONIKA_ARANY   := 0.66     # legfeljebb a képernyő ekkora része (hogy végig lehessen olvasni)
const KRONIKA_FOGO    := 9.0      # a húzható sáv vastagsága a panel tetején
const KRONIKA_BEJEGYZES := 200    # ennyi bejegyzés marad a szövegben
const KRONIKA_TINTA := Color(0.35, 0.17, 0.08)   # a nyíl színe a pergamenen

var kronika_gomb: Button
var kronika_fogo: Control
var _kronika_magassag := KRONIKA_ALAP
var _kronika_elozo := KRONIKA_ALAP      # ide nyílik vissza az összecsukott panel
var _kronika_huzas := false
var _kronika_huz_y := 0.0
var _kronika_huz_h := 0.0


func _epit_kronika() -> void:
	if kronika_panel == null: return

	# húzható sáv a panel felső szélén
	kronika_fogo = Control.new()
	kronika_fogo.mouse_filter = Control.MOUSE_FILTER_STOP
	kronika_fogo.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	kronika_fogo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	kronika_fogo.offset_top = -KRONIKA_FOGO * 0.5
	kronika_fogo.offset_bottom = KRONIKA_FOGO * 0.5
	kronika_fogo.gui_input.connect(_kronika_fogo_esemeny)
	kronika_panel.add_child(kronika_fogo)

	# nyíl a fejléc jobb szélén: összecsuk / kinyit
	var fejlec := lbl_chronicle_title.get_parent()
	var sor := HBoxContainer.new()
	fejlec.add_child(sor)
	fejlec.move_child(sor, lbl_chronicle_title.get_index())
	lbl_chronicle_title.reparent(sor)
	lbl_chronicle_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kronika_gomb = Button.new()
	kronika_gomb.flat = true
	kronika_gomb.focus_mode = Control.FOCUS_NONE
	kronika_gomb.custom_minimum_size = Vector2(34, 24)
	# a pergamenen a halvány nyíl elveszne: sötét tintaszín, nagyobb betűvel
	kronika_gomb.add_theme_font_size_override("font_size", 18)
	for c in ["font_color", "font_focus_color"]:
		kronika_gomb.add_theme_color_override(c, KRONIKA_TINTA)
	for c in ["font_hover_color", "font_pressed_color"]:
		kronika_gomb.add_theme_color_override(c, KRONIKA_TINTA.lightened(0.35))
	kronika_gomb.pressed.connect(_kronika_valt)
	sor.add_child(kronika_gomb)

	# a görgetés maradjon ott, ahová a játékos tette: csak akkor ugrik a végére,
	# ha épp az alján áll
	var sav := txt_chronicle.get_v_scroll_bar()
	if sav != null: sav.value_changed.connect(_kronika_gorgetve)

	_kronika_allit(_kronika_magassag)


func _kronika_fogo_esemeny(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_kronika_huzas = event.pressed
		if event.pressed:
			_kronika_huz_y = kronika_fogo.get_global_mouse_position().y
			_kronika_huz_h = _kronika_magassag
	elif event is InputEventMouseMotion and _kronika_huzas:
		# fölfelé húzva nagyobb lesz, lefelé kisebb
		var delta := _kronika_huz_y - kronika_fogo.get_global_mouse_position().y
		_kronika_allit(_kronika_huz_h + delta)


func _kronika_valt() -> void:
	AudioManager.play_sfx_click()
	if _kronika_magassag <= KRONIKA_KICSI + 1.0:
		_kronika_allit(maxf(_kronika_elozo, KRONIKA_ALAP))
	else:
		_kronika_elozo = _kronika_magassag
		_kronika_allit(KRONIKA_KICSI)


func _kronika_allit(h: float) -> void:
	var felso := get_viewport_rect().size.y * KRONIKA_ARANY
	# a minimum alá húzva összecsukódik, félmagasságok nélkül
	if h < KRONIKA_MIN: h = KRONIKA_KICSI
	h = clampf(h, KRONIKA_KICSI, maxf(felso, KRONIKA_ALAP))
	_kronika_magassag = h
	kronika_panel.offset_top = -h
	if map_view: map_view.offset_bottom = -h
	var nyitva := h > KRONIKA_KICSI + 1.0
	txt_chronicle.visible = nyitva
	kronika_gomb.text = "▼" if nyitva else "▲"
	kronika_gomb.tooltip_text = tr("CHRONICLE_HIDE" if nyitva else "CHRONICLE_SHOW")


func _kronika_gorgetve(_ertek: float) -> void:
	var sav := txt_chronicle.get_v_scroll_bar()
	if sav == null: return
	# ha a játékos visszagörgetett, ne rángassuk vissza a végére új bejegyzésnél
	var alul := sav.value >= sav.max_value - sav.page - 2.0
	txt_chronicle.scroll_following = alul

func _can_act() -> bool:
	return GameManager.game_state == "playing"

func _set_action_state(kind: String, reason: String, extra_tip: String = "") -> void:
	var entry: Dictionary = action_buttons[kind]
	entry["button"].disabled = reason != ""
	entry["content"].modulate = Color(1, 1, 1, 0.45 if reason != "" else 1.0)
	var tip := Localization.tc("TIP_" + kind.to_upper())
	if extra_tip != "": tip += "\n\n" + extra_tip
	if reason != "": tip += "\n\n" + Localization.tc(reason)
	entry["button"].tooltip_text = tip

# A szintes épületek (egyház, kaszárnya) gombja mindig a következő szintet mutatja
func _update_level_button(kind: String, pname: String) -> String:
	var level: int = GameManager.provinces[pname][kind] if GameManager.provinces.has(pname) else 0
	var entry: Dictionary = action_buttons[kind]
	if level >= GameManager.level_max(kind):
		entry["name"].text = Localization.t("ACT_LEVEL_MAX", [GameManager.level_key(kind, level)])
		_show_cost(kind, {})
		return ""
	var next := level + 1
	entry["name"].text = Localization.tc(GameManager.level_key(kind, next))
	_show_cost(kind, GameManager.action_cost(pname, kind))
	if kind == "church":
		return Localization.t("TIP_CHURCH_NEXT", [GameManager.church_key(next),
			GameManager.CHURCH_STABILITY[next], GameManager.CHURCH_SILVER[next]])
	if kind == "farm":
		return Localization.t("TIP_FARM_NEXT", [GameManager.level_key("farm", next), GameManager.FARM_FOOD_LEVEL[next],
			GameManager.POP_CAP_FARM])
	if kind == "village":
		return Localization.t("TIP_VILLAGE_NEXT", [GameManager.level_key("village", next), GameManager.VILLAGE_WOOD[next],
			GameManager.VILLAGE_POP[next], GameManager.POP_CAP_VILLAGE, GameManager.POP_GROWTH_VILLAGE])
	if kind == "hof":
		return Localization.t("TIP_HOF_NEXT", [GameManager.hof_key(next),
			GameManager.HOF_STABILITY[next], GameManager.HOF_FAVOR[next]])
	return Localization.t("TIP_BARRACKS_NEXT", [GameManager.barracks_key(next),
		GameManager.BARRACKS_FYRD[next], GameManager.BARRACKS_THEGN[next], GameManager.BARRACKS_DEFENSE])

func update_info_panel() -> void:
	lbl_prov_pop.remove_theme_color_override("font_color")
	if selected_locked != "":
		lbl_prov_name.text = tr(selected_locked)
		lbl_prov_pop.text  = tr("LOCKED_TITLE")
		lbl_prov_info.text = tr("LOCKED_DESC")
		_disable_province_actions("REASON_LOCKED")
		return
	if selected_province.is_empty() or not GameManager.provinces.has(selected_province):
		lbl_prov_name.text = tr("INFO_SELECT")
		lbl_prov_pop.text  = ""
		lbl_prov_info.text = tr("INFO_HINT")
		_disable_province_actions("REASON_NOT_OWN")
		return

	var pname := selected_province
	var p = GameManager.provinces[pname]
	var pf = GameManager.player_faction
	var ip = (p["faction"] == pf)
	lbl_prov_name.text = GameManager.province_label(pname)
	lbl_prov_pop.text = Localization.t("INFO_POP", [GameManager.faction_key(p["faction"]), p["population"],
		GameManager.population_cap(pname), GameManager.population_growth(pname)])
	lbl_prov_pop.tooltip_text = Localization.t("TIP_POPULATION", [p["population"], GameManager.population_cap(pname),
		GameManager.population_growth(pname), GameManager.free_peasants(pname), GameManager.POP_FLOOR,
		GameManager.MEN_PER_FYRD, GameManager.MEN_PER_THEGN])
	lbl_prov_pop.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl_prov_pop.add_theme_color_override("font_color", GameManager.faction_color(p["faction"]).lightened(0.25))
	var buildings: PackedStringArray = []
	for b in BUILDINGS:
		if b == "farm": continue
		if p["has_" + b]: buildings.append(Localization.tc("ACT_" + b.to_upper()))
	# a szintes gazdaság és falu a szintje nevével
	for kind in ["farm", "village"]:
		if int(p.get(kind, 0)) > 0: buildings.append(Localization.tc(GameManager.level_key(kind, int(p[kind]))))
	var lines: PackedStringArray = [
		Localization.t("INFO_OLD_NAME", [GameManager.province_old_name(pname)]),
		Localization.t("INFO_UNITS", [p["fyrd"], p["thegn"], p["ships"]]),
		Localization.t("INFO_DEFENSE", [GameManager.calculate_defense_power(pname)]),
		Localization.t("INFO_BUILDINGS", [", ".join(buildings) if not buildings.is_empty() else tr("INFO_NONE")]),
		Localization.t("INFO_HOF", [GameManager.hof_key(p["hof"]) if p["hof"] > 0 else "INFO_NONE"]) if norse \
			else Localization.t("INFO_CHURCH", [GameManager.church_key(p["church"]) if p["church"] > 0 else "INFO_NONE"]),
		Localization.t("INFO_BARRACKS", [GameManager.barracks_key(p["barracks"]), GameManager.recruit_amount(pname, "fyrd"),
			GameManager.recruit_amount(pname, "thegn")]) if p["barracks"] > 0 else Localization.t("INFO_NO_BARRACKS"),
		Localization.t("INFO_PROD", [p["food_prod"], GameManager.province_silver(pname), p["wood_prod"]])
	]
	# a másik kultúra itt maradt épülete (pl. a dánok által elfoglalt katedrális)
	if norse and p["church"] > 0:
		lines.append(Localization.t("INFO_CHURCH", [GameManager.church_key(p["church"])]))
	elif not norse and p["hof"] > 0:
		lines.append(Localization.t("INFO_HOF", [GameManager.hof_key(p["hof"])]))
	if GameManager.CATHEDRAL_SEES.has(pname) and not norse:
		lines.append(Localization.t("INFO_SEE", [GameManager.CATHEDRAL_SEES[pname]]))
	var site_line := _monastery_line(pname)
	if site_line != "": lines.append(site_line)
	var tags: PackedStringArray = []
	if p["coastal"]: tags.append(tr("INFO_COASTAL"))
	if p["river"]: tags.append(tr("INFO_RIVER"))
	if GameManager.is_border_province(pname): tags.append(tr("INFO_BORDER"))
	if not tags.is_empty(): lines.append(" · ".join(tags))
	if GameManager.SILVER_MINES.has(pname):
		lines.append(Localization.t("INFO_SILVER_SITE", [GameManager.SILVER_MINES[pname]["site"]]))
	if pname in GameManager.MINT_SITES:
		lines.append(tr("INFO_MINT_SITE"))
	lbl_prov_info.text = "\n".join(lines)
	# Az elégedetlenség saját, színezett sort kap: zöldtől a vörösig, hogy egy
	# pillantásra látszódjon, hol forrong a föld.
	var elegedetlen := GameManager.unrest_of(pname)
	lbl_unrest.visible = ip or elegedetlen > 0
	if lbl_unrest.visible:
		lbl_unrest.text = Localization.t("INFO_UNREST", [elegedetlen, tr(_unrest_key(elegedetlen))])
		lbl_unrest.add_theme_color_override("font_color", _unrest_color(elegedetlen))
		lbl_unrest.tooltip_text = _unrest_tooltip(pname)

	var tips := {}
	for kind in GameManager.LEVELED:
		if action_buttons.has(kind): tips[kind] = _update_level_button(kind, pname)
	if p["barracks"] > 0 and ip:
		tips["fyrd"] = Localization.t("TIP_RECRUIT_AMOUNT", [GameManager.recruit_amount(pname, "fyrd"), "ACT_FYRD"]) \
			+ "\n" + Localization.t("TIP_RECRUIT_PEASANTS", [GameManager.recruit_men(pname, "fyrd"), GameManager.free_peasants(pname)]) \
			+ "\n" + Localization.t("TIP_UPKEEP_FYRD", [GameManager.UPKEEP_FYRD_FOOD, GameManager.UPKEEP_FREE_FYRD])
		tips["thegn"] = Localization.t("TIP_RECRUIT_AMOUNT", [GameManager.recruit_amount(pname, "thegn"), "ACT_THEGN"]) \
			+ "\n" + Localization.t("TIP_RECRUIT_PEASANTS", [GameManager.recruit_men(pname, "thegn"), GameManager.free_peasants(pname)]) \
			+ "\n" + Localization.t("TIP_UPKEEP_THEGN", [GameManager.UPKEEP_THEGN_SILVER, GameManager.UPKEEP_THEGN_FOOD])
	for kind in actions:
		_set_action_state(kind, GameManager.action_block_reason(pname, kind) if _can_act() else "REASON_GAME_OVER",
			tips.get(kind, ""))

	if GameManager.move_mode:
		btn_move_army.text = tr("BTN_MOVE_CANCEL")
		btn_move_army.disabled = false
	else:
		btn_move_army.text = tr("BTN_MOVE_ARMY")
		btn_move_army.disabled = (not ip) or not _can_act() or (p["fyrd"] == 0 and p["thegn"] == 0 and p["ships"] == 0)
	_refresh_ambush_button(pname, ip)
	if ip:
		btn_attack.disabled = true; btn_attack.text = tr("BTN_ATTACK")
	else:
		var nb = GameManager.get_player_neighbors_of(pname)
		var naval = GameManager.get_naval_sources(pname)
		var war = GameManager.is_at_war(pf, p["faction"])
		var ca  = (not nb.is_empty() or not naval.is_empty()) and war and not GameManager.move_mode and _can_act()
		btn_attack.disabled = not ca
		btn_attack.tooltip_text = tr("TIP_NAVAL_ATTACK")
		if not war and GameManager.is_norse(pf) and GameManager.is_naval_target(pname):
			# óészakiak: háború nélkül portyázhatnak (a Támadás gomb helyén, hogy ne kelljen új gomb)
			GameManager.acting_faction = pf
			var why := GameManager.plunder_block(pname)
			btn_attack.disabled = why != "" or GameManager.move_mode or not _can_act()
			if why == "":
				btn_attack.text = Localization.t("BTN_PLUNDER", [roundi(GameManager.plunder_chance(pname) * 100),
					GameManager.plunder_loot(pname)])
				btn_attack.tooltip_text = Localization.t("TIP_PLUNDER", [GameManager.plunder_source(pname),
					GameManager.PLUNDER_COOLDOWN / 4])
			else:
				btn_attack.text = tr("BTN_PLUNDER_OFF")
				btn_attack.tooltip_text = tr(why)
		elif not war:
			btn_attack.text = tr("BTN_ATTACK_NOT_WAR")
		elif ca:
			# a gombon a TEREPPEL együtt számolt erő álljon – ugyanaz, amivel a csata számol
			btn_attack.text = Localization.t("BTN_ATTACK_POWER", [GameManager.attack_power_against(nb, naval, pname), GameManager.calculate_defense_power(pname)])
			var terep := GameManager.terrain_of(pname)
			if terep != "":
				btn_attack.tooltip_text = Localization.t("TIP_TERRAIN_ATTACK",
					["TERRAIN_" + terep.to_upper(), roundi((1.0 - GameManager.terrain_atk_mult(pname)) * 100),
					roundi((GameManager.terrain_def_mult(pname) - 1.0) * 100)])
		else:
			btn_attack.text = tr("BTN_ATTACK_NO_NEIGHBOR")

## Rajtaütés gomb: csak akkor látszik, ha a KIJELÖLT saját tartományod
## helyőrsége elér egy épp elvonuló ellenséges sereget. Ha több ilyen menet
## van, a legerősebbet ajánlja fel – az a veszélyes.
func _refresh_ambush_button(pname: String, ip: bool) -> void:
	if btn_ambush == null: return
	_ambush_pick = {}
	if not ip or not _can_act() or GameManager.move_mode:
		btn_ambush.visible = false
		return
	GameManager.acting_faction = GameManager.player_faction
	var legjobb: Dictionary = {}
	for c in GameManager.ambush_targets():
		if not pname in (c["sources"] as Array): continue
		if legjobb.is_empty() or int(c["power"]) > int(legjobb["power"]): legjobb = c
	if legjobb.is_empty():
		btn_ambush.visible = false
		return
	_ambush_pick = legjobb
	var menet: Dictionary = GameManager.marches[int(legjobb["index"])]
	var eronk := int(GameManager.calculate_attack_power([pname]) * GameManager.AMBUSH_BONUS)
	btn_ambush.visible = true
	btn_ambush.disabled = false
	btn_ambush.text = Localization.t("BTN_AMBUSH", [eronk, int(legjobb["power"])])
	btn_ambush.tooltip_text = Localization.t("TIP_AMBUSH",
		[GameManager.faction_key(int(menet["faction"])), GameManager.province_label(str(legjobb["at"])),
		int(menet["fyrd"]) + int(menet["thegn"])])


func _on_ambush() -> void:
	if _ambush_pick.is_empty(): return
	Net.request("ambush", {"index": int(_ambush_pick["index"]), "sources": [selected_province]})


func _disable_province_actions(reason: String) -> void:
	for kind in GameManager.LEVELED:
		if not action_buttons.has(kind): continue
		action_buttons[kind]["name"].text = Localization.tc(GameManager.level_key(kind, 1))
		_show_cost(kind, GameManager.level_costs(kind)[0])
	for kind in actions:
		_set_action_state(kind, reason)
	btn_move_army.text = tr("BTN_MOVE_CANCEL") if GameManager.move_mode else tr("BTN_MOVE_ARMY")
	btn_move_army.disabled = not GameManager.move_mode
	btn_attack.text = tr("BTN_ATTACK")
	btn_attack.disabled = true

# A kör vége gomb: többjátékosban "kész" jelzés, és kiírja, hányan várnak még
func _update_turn_button() -> void:
	var pf := GameManager.player_faction
	if not GameManager.is_multiplayer:
		btn_next_turn.text = tr("BTN_NEXT_TURN")
		btn_next_turn.disabled = not _can_act()
		btn_next_turn.tooltip_text = ""
		return
	var active_humans: Array = []
	for f in GameManager.human_factions:
		if GameManager.realms[f]["status"] == "playing": active_humans.append(f)
	var ready_count := 0
	var waiting: PackedStringArray = []
	for f in active_humans:
		if f in GameManager.ready_factions: ready_count += 1
		else: waiting.append(GameManager.faction_name(f))
	var me_ready: bool = pf in GameManager.ready_factions
	btn_next_turn.text = Localization.t("BTN_WAITING" if me_ready else "BTN_END_TURN_MP", [ready_count, active_humans.size()])
	btn_next_turn.tooltip_text = Localization.t("MP_WAITING_FOR", [", ".join(waiting)]) if not waiting.is_empty() else ""
	btn_next_turn.disabled = not _can_act() or not GameManager.pending_raid.is_empty() or not GameManager.pending_event.is_empty()

# ── Térkép ────────────────────────────────────────────────────

## A diplomácia ablakból: a térkép odaugrik a kiválasztott királysághoz.
##
## Nem akármelyik tartományára, hanem oda, ahol MÉG van földje – a székhelyére,
## ha az övé, különben az első birtokára. Ha már egy tartománya sincs (legyőzték,
## vagy még a tengeren túl van), azt megmondjuk, és nem ugrunk sehova.
## Az uralkodó arcképe a diplomácia ablakban: a cím alá kerül, hogy látszódjon,
## kivel tárgyalsz. Ugyanaz a festett mellkép, mint a bal panelen, csak kisebb;
## a képre (és a névre) víve az egeret a négysoros életrajz jelenik meg.
const DIP_PORTRE_MERET := 132.0

var dip_portre_doboz: VBoxContainer
var dip_portre: Control
var dip_lbl_ruler: Label

func _epit_dip_portre() -> void:
	var box := dip_lbl_title.get_parent()
	if box == null: return
	dip_portre_doboz = VBoxContainer.new()
	dip_portre_doboz.add_theme_constant_override("separation", 2)
	dip_portre_doboz.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(dip_portre_doboz)
	box.move_child(dip_portre_doboz, dip_lbl_title.get_index() + 1)

	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	sor.mouse_filter = Control.MOUSE_FILTER_PASS
	dip_portre_doboz.add_child(sor)
	dip_portre = preload("res://scripts/ui/ruler_portrait.gd").new()
	dip_portre.custom_minimum_size = Vector2(DIP_PORTRE_MERET, DIP_PORTRE_MERET)
	dip_portre.mouse_filter = Control.MOUSE_FILTER_PASS
	sor.add_child(dip_portre)

	dip_lbl_ruler = Label.new()
	dip_lbl_ruler.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dip_lbl_ruler.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dip_lbl_ruler.add_theme_font_size_override("font_size", 13)
	dip_lbl_ruler.mouse_filter = Control.MOUSE_FILTER_PASS
	dip_portre_doboz.add_child(dip_lbl_ruler)


func _frissit_dip_portre(tf: int) -> void:
	if dip_portre_doboz == null: return
	var ruler := GameManager.historical_ruler(tf, GameManager.current_year)
	dip_portre_doboz.visible = ruler != ""
	if ruler == "": return
	var tip := GameManager.ruler_tooltip(ruler)
	dip_portre.beallit(ruler, GameManager.culture_of(tf), GameManager.faction_color(tf),
		GameManager.current_year)
	dip_portre.tooltip_text = tip
	dip_lbl_ruler.text = tr(ruler)
	dip_lbl_ruler.tooltip_text = tip
	dip_lbl_ruler.add_theme_color_override("font_color", GameManager.faction_color(tf).lightened(0.35))


func _dip_show_on_map() -> void:
	var tf := dip_target_faction
	if tf < 0: return
	var own: Array = GameManager.get_faction_provinces(tf)
	if own.is_empty():
		_show_toast(Localization.t("DIP_MAP_NO_LAND", [GameManager.faction_key(tf)]))
		return
	var cel: String = own[0]
	var szekhely: String = GameManager._capital_of(tf)
	if szekhely != "" and szekhely in own:
		cel = szekhely
	# Mindkét ablak bezárul – a listáé is –, különben a térkép marad takarva
	_close_popup(diplomacy_popup)
	if diplist_popup != null and diplist_popup.visible: _close_popup(diplist_popup)
	selected_province = cel
	# az EGÉSZ országot mutatjuk, nem csak a székhelyét
	map_view.center_on_provinces(own)
	map_view.set_selected(cel)
	map_view.flash_province(cel, GameManager.faction_color(tf).lightened(0.25))
	update_all()


func select_province(pname: String) -> void:
	if not GameManager.provinces.has(pname): return
	AudioManager.play_sfx_click()
	selected_locked = ""

	if GameManager.move_mode:
		var src := GameManager.move_source
		GameManager.cancel_move_mode()
		selected_province = pname
		if pname != src and not GameManager.find_march_route(src, pname).is_empty():
			Net.request("march", {"from": src, "to": pname})
		update_all()
		return

	selected_province = pname
	update_info_panel()
	refresh_map()
	_flash_province(pname, Color(1, 1, 1, 0.3))

func _on_locked_clicked(region_key: String) -> void:
	AudioManager.play_sfx_click()
	GameManager.cancel_move_mode()
	selected_province = ""
	selected_locked = region_key
	update_info_panel()
	refresh_map()

# ── A béke ára ─────────────────────────────────────────────────
#
# Eddig a béke csak fegyverszünet volt: „igen” vagy „nem”. Itt össze lehet
# állítani, MIT kérsz érte – sarcot, tartományt, hűbérséget, szövetségbontást –,
# vagy mit adsz, ha te állsz vesztésre. Az esély élőben frissül, tételesen.

var beke_popup: Panel
var beke_cim: Label
var beke_sarc: HSlider
var beke_sarc_cimke: Label
var beke_terulet: OptionButton
var beke_vazallus: CheckBox
var beke_szovetseg: OptionButton
var beke_fizet: HSlider
var beke_fizet_cimke: Label
var beke_esely: Label
var beke_kuld: Button
var beke_megse: Button
var beke_cel := -1


func _epit_beke_popup() -> void:
	beke_popup = _make_side_popup(500, 620)
	var box: VBoxContainer = beke_popup.get_child(0)

	beke_cim = Label.new()
	beke_cim.theme_type_variation = &"HeaderLabel"
	beke_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beke_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(beke_cim)

	var kovetel := _desc_label()
	kovetel.text = tr("PEACE_DEMAND_HEAD")
	box.add_child(kovetel)

	# sarc
	beke_sarc_cimke = Label.new()
	beke_sarc_cimke.add_theme_font_size_override("font_size", 13)
	box.add_child(beke_sarc_cimke)
	beke_sarc = HSlider.new()
	beke_sarc.min_value = 0
	beke_sarc.max_value = 300
	beke_sarc.step = 10
	beke_sarc.value_changed.connect(func(_v): _frissit_beke())
	box.add_child(beke_sarc)

	# tartomány
	var t_cim := Label.new()
	t_cim.text = tr("PEACE_DEMAND_LAND")
	t_cim.add_theme_font_size_override("font_size", 13)
	box.add_child(t_cim)
	beke_terulet = OptionButton.new()
	beke_terulet.item_selected.connect(func(_i): _frissit_beke())
	box.add_child(beke_terulet)

	beke_vazallus = CheckBox.new()
	beke_vazallus.text = tr("PEACE_DEMAND_VASSAL")
	beke_vazallus.toggled.connect(func(_b): _frissit_beke())
	box.add_child(beke_vazallus)

	var sz_cim := Label.new()
	sz_cim.text = tr("PEACE_DEMAND_BREAK")
	sz_cim.add_theme_font_size_override("font_size", 13)
	box.add_child(sz_cim)
	beke_szovetseg = OptionButton.new()
	beke_szovetseg.item_selected.connect(func(_i): _frissit_beke())
	box.add_child(beke_szovetseg)

	var ad := _desc_label()
	ad.text = tr("PEACE_OFFER_HEAD")
	box.add_child(ad)
	beke_fizet_cimke = Label.new()
	beke_fizet_cimke.add_theme_font_size_override("font_size", 13)
	box.add_child(beke_fizet_cimke)
	beke_fizet = HSlider.new()
	beke_fizet.min_value = 0
	beke_fizet.max_value = 300
	beke_fizet.step = 10
	beke_fizet.value_changed.connect(func(_v): _frissit_beke())
	box.add_child(beke_fizet)

	beke_esely = Label.new()
	beke_esely.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	beke_esely.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	beke_esely.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(beke_esely)

	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 8)
	box.add_child(sor)
	beke_megse = Button.new()
	beke_megse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beke_megse.custom_minimum_size = Vector2(0, 40)
	beke_megse.pressed.connect(func(): _close_popup(beke_popup))
	sor.add_child(beke_megse)
	beke_kuld = Button.new()
	beke_kuld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beke_kuld.custom_minimum_size = Vector2(0, 40)
	beke_kuld.pressed.connect(_beke_kuldes)
	sor.add_child(beke_kuld)


func open_peace_terms(tf: int) -> void:
	if beke_popup == null or tf < 0: return
	beke_cel = tf
	GameManager.acting_faction = GameManager.player_faction
	beke_cim.text = Localization.t("PEACE_TITLE", [GameManager.faction_key(tf)])
	beke_megse.text = tr("PEACE_CANCEL")
	beke_kuld.text = tr("PEACE_SEND")
	beke_vazallus.text = tr("PEACE_DEMAND_VASSAL")
	beke_vazallus.button_pressed = false
	beke_sarc.value = 0
	beke_sarc.max_value = maxi(10, int(GameManager.realms[tf]["silver"]))
	beke_fizet.value = 0
	beke_fizet.max_value = maxi(10, GameManager.silver)

	# az ő tartományaik, amiket kérni lehet
	beke_terulet.clear()
	beke_terulet.add_item(tr("PEACE_NONE"), 0)
	for p in GameManager.get_faction_provinces(tf):
		beke_terulet.add_item(GameManager.province_label(p))
		beke_terulet.set_item_metadata(beke_terulet.item_count - 1, p)
	beke_terulet.select(0)

	# a szövetségeseik, akiktől el lehet szakítani őket
	beke_szovetseg.clear()
	beke_szovetseg.add_item(tr("PEACE_NONE"), 0)
	for f in GameManager.ALL_FACTIONS:
		if f == tf or f == GameManager.player_faction or not GameManager.is_alive(f): continue
		if GameManager.is_ally(tf, f):
			beke_szovetseg.add_item(GameManager.faction_name(f))
			beke_szovetseg.set_item_metadata(beke_szovetseg.item_count - 1, f)
	beke_szovetseg.select(0)
	beke_szovetseg.disabled = beke_szovetseg.item_count <= 1

	_frissit_beke()
	_close_popup(diplomacy_popup)
	_open_popup(beke_popup)


## A pillanatnyilag beállított feltételek
func _beke_feltetelek() -> Dictionary:
	var t: Dictionary = {}
	if beke_sarc.value > 0: t["tribute"] = int(beke_sarc.value)
	if beke_fizet.value > 0: t["silver"] = int(beke_fizet.value)
	if beke_vazallus.button_pressed: t["vassal"] = true
	var ter = beke_terulet.get_selected_metadata()
	if ter != null and str(ter) != "": t["demand"] = str(ter)
	var sz = beke_szovetseg.get_selected_metadata()
	if sz != null: t["break_alliance"] = int(sz)
	return t


func _frissit_beke() -> void:
	if beke_cel < 0: return
	GameManager.acting_faction = GameManager.player_faction
	beke_sarc_cimke.text = Localization.t("PEACE_DEMAND_TRIBUTE", [int(beke_sarc.value)])
	beke_fizet_cimke.text = Localization.t("PEACE_OFFER_SILVER", [int(beke_fizet.value)])
	var t := _beke_feltetelek()
	var sorok: Array = []
	for m in GameManager.dip_modifiers(beke_cel, GameManager.DIP_BASE["peace"], t):
		sorok.append("%s   %s" % [_signed(int(m["value"])), tr(str(m["key"]))])
	sorok.append("─────")
	var esely := GameManager.acceptance_chance(beke_cel, GameManager.DIP_BASE["peace"], t)
	sorok.append(Localization.t("DIP_CHANCE_TOTAL", [roundi(esely * 100)]))
	beke_esely.text = "\n".join(sorok)
	beke_esely.add_theme_color_override("font_color",
		Color(0.62, 0.86, 0.55) if esely >= 0.5 else (Color(0.95, 0.85, 0.42) if esely >= 0.25 else Color(1.0, 0.45, 0.38)))
	beke_kuld.disabled = GameManager.silver < GameManager.PROPOSAL_COSTS["peace"] + int(beke_fizet.value)


func _beke_kuldes() -> void:
	if beke_cel < 0: return
	var t := _beke_feltetelek()
	_close_popup(beke_popup)
	Net.request("peace", {"target": beke_cel, "terms": t})


# ── Elégedetlenség a felületen ─────────────────────────────────

var lbl_unrest: Label       # a tartomány elégedetlensége, saját színezett sorban

## Az elégedetlenség sora NEM a görgethető szövegdobozba kerül (ott alul
## kiscrollozódna, és épp azt nem látnád, ami fontos), hanem közvetlenül alá,
## a panel saját oszlopába – így mindig szem előtt van.
func _epit_unrest_sort() -> void:
	var gorgeto := lbl_prov_info.get_parent()          # InfoScroll
	var oszlop := gorgeto.get_parent()                 # InfoBox (VBoxContainer)
	lbl_unrest = Label.new()
	lbl_unrest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_unrest.theme_type_variation = &"SmallLabel"
	lbl_unrest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_unrest.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl_unrest.visible = false
	oszlop.add_child(lbl_unrest)
	oszlop.move_child(lbl_unrest, gorgeto.get_index() + 1)

## Melyik szóval illetjük az adott elégedetlenséget?
func _unrest_key(ertek: int) -> String:
	if ertek >= GameManager.UNREST_LAZAD:   return "UNREST_L4"
	if ertek >= GameManager.UNREST_FORRONG: return "UNREST_L3"
	if ertek >= GameManager.UNREST_NYUGODT: return "UNREST_L2"
	return "UNREST_L1"

func _unrest_color(ertek: int) -> Color:
	if ertek >= GameManager.UNREST_LAZAD:   return Color(1.00, 0.36, 0.30)
	if ertek >= GameManager.UNREST_FORRONG: return Color(1.00, 0.62, 0.26)
	if ertek >= GameManager.UNREST_NYUGODT: return Color(0.95, 0.85, 0.42)
	return Color(0.62, 0.86, 0.55)

## Tételes magyarázat: mi hajtja föl, mi nyomja le, és mi következik belőle
func _unrest_tooltip(pname: String) -> String:
	var u := GameManager.unrest_of(pname)
	var sorok: Array = [Localization.t("UNREST_TIP_HEAD", [u, tr(_unrest_key(u))]), ""]
	for m in GameManager.unrest_factors(pname):
		sorok.append("%s   %s" % [_signed(int(m["value"])), tr(str(m["key"]))])
	var valt := GameManager.unrest_change(pname)
	sorok.append("─────")
	sorok.append(Localization.t("UNREST_TIP_TURN", [_signed(valt) if valt != 0 else "±0"]))
	var esely := GameManager.unrest_revolt_chance(pname)
	if esely > 0.0:
		sorok.append(Localization.t("UNREST_TIP_REVOLT", [roundi(esely * 100)]))
	else:
		sorok.append(Localization.t("UNREST_TIP_SAFE", [GameManager.UNREST_LAZAD]))
	return "\n".join(sorok)


func _hover_text(pname: String) -> String:
	var p = GameManager.provinces[pname]
	var text := "%s (%s) – %s" % [GameManager.province_label(pname), GameManager.province_old_name(pname), GameManager.faction_name(p["faction"])]
	var site := _monastery_line(pname)
	if site != "": text += "\n" + site
	# a táj: csak ha jellegzetes (hegyvidék, erdő, mocsár) – a síkságot nem írjuk ki
	var terep := GameManager.terrain_of(pname)
	if terep != "":
		text += "\n" + Localization.t("HOVER_TERRAIN",
			["TERRAIN_" + terep.to_upper(), roundi((GameManager.terrain_def_mult(pname) - 1.0) * 100),
			roundi((1.0 - GameManager.terrain_atk_mult(pname)) * 100)])
	# a forrongó föld a térképen is jelezze magát
	var u := GameManager.unrest_of(pname)
	if u >= GameManager.UNREST_NYUGODT:
		text += "\n" + Localization.t("HOVER_UNREST", [u, tr(_unrest_key(u))])
	if GameManager.move_mode and pname != GameManager.move_source:
		var route := GameManager.find_march_route(GameManager.move_source, pname)
		if route.is_empty():
			text += "\n" + tr("MOVE_UNREACHABLE")
		else:
			text += "\n" + Localization.t("HOVER_MARCH", [{"dur": route["turns"]}])
			if route["by_water"]: text += " " + tr("HOVER_BY_WATER")
	return text

# "✝ Lindisfarne kolostora" (kifosztva) – ha a provinciában nevezetes kolostor van
func _monastery_line(pname: String) -> String:
	for site in GameManager.MONASTERIES:
		if GameManager.MONASTERIES[site]["province"] != pname: continue
		var sacked: bool = ("SACKED_" + site) in GameManager.world_flags
		return Localization.t("INFO_MONASTERY_SACKED" if sacked else "INFO_MONASTERY", [site])
	return ""

func refresh_map() -> void:
	for pname in GameManager.provinces:
		var col := GameManager.faction_color(GameManager.provinces[pname]["faction"])
		if GameManager.move_mode:
			if pname == GameManager.move_source:
				col = Color(1, 1, 0.2)
			elif not GameManager.find_march_route(GameManager.move_source, pname).is_empty():
				col = Color(0.2, 1, 0.4)
			else:
				col = Color(0.55, 0.55, 0.55)
		map_view.set_province_color(pname, col)
	map_view.set_selected(selected_province)
	map_view.update_cities()
	map_view.set_marches(GameManager.marches)

func _flash_province(pname: String, col: Color) -> void:
	map_view.flash_province(pname, col)

func _flash_screen(col: Color) -> void:
	flash_overlay.color = col
	flash_overlay.show()
	var tw = create_tween()
	tw.tween_property(flash_overlay, "color:a", 0.0, 0.5)
	tw.tween_callback(flash_overlay.hide)

# ── Felugró ablakok, üzenetek ─────────────────────────────────

func _open_popup(p: Control) -> void:
	p.show()
	dim.show()
	if p.has_meta("base_h"): _fit_popup.call_deferred(p)

# Az ablak magassága a tartalomhoz igazodik, hogy egy szöveg se lógjon ki
# (legalább az eredeti méret, legfeljebb a képernyő magassága)
func _fit_popup(p: Control) -> void:
	await get_tree().process_frame
	if not p.visible or p.get_child_count() == 0: return
	var box := p.get_child(0) as Control
	var margin := box.offset_top - box.offset_bottom
	var need := box.get_combined_minimum_size().y + margin
	var h := clampf(need, float(p.get_meta("base_h")), get_viewport_rect().size.y - 16.0)
	p.offset_top = -h / 2.0
	p.offset_bottom = h / 2.0

func _close_popup(p: Control) -> void:
	p.hide()
	dim.visible = popups.any(func(x): return x.visible)
	if p == message_popup:
		_show_next_message()
		if not message_popup.visible: _check_pending()

# Üzenet sorba állítása; proposal = más játékos diplomáciai ajánlata (elfogad / elutasít)
func show_message(title: String, desc: String, proposal: Dictionary = {}) -> void:
	_message_queue.append({"title": title, "desc": desc, "proposal": proposal})
	if not message_popup.visible:
		_show_next_message()

func _show_next_message() -> void:
	if _message_queue.is_empty(): return
	var m: Dictionary = _message_queue.pop_front()
	_current_proposal = m["proposal"]
	msg_lbl_title.text = m["title"]
	msg_lbl_desc.text = m["desc"]
	msg_btn_ok.text = tr("BTN_ACCEPT") if not _current_proposal.is_empty() else tr("BTN_OK")
	msg_btn_decline.visible = not _current_proposal.is_empty()
	_open_popup(message_popup)

func _answer_message(accept: bool) -> void:
	if not _current_proposal.is_empty():
		Net.request("respond", {"from": _current_proposal["from"], "kind": _current_proposal["kind"], "accept": accept})
		_current_proposal = {}
	_close_popup(message_popup)

func _on_notification(note: Dictionary) -> void:
	var title := Localization.t(note["title"][0], note["title"][1])
	var desc := Localization.t(note["desc"][0], note["desc"][1])
	var data: Dictionary = note.get("data", {})
	if data.get("type", "") == "ambition":
		desc += "\n\n" + Localization.t("AMBITION_REWARD", [effects_summary(data.get("reward", {}))])
		AudioManager.play_sfx_victory()
	else:
		AudioManager.play_sfx_diplomacy()
	show_message(title, desc, data if data.get("type", "") == "proposal" else {})

# Nyitott portya / esemény / játék vége megjelenítése a szinkronizált állapot alapján
func _check_pending() -> void:
	if GameManager.game_state != "playing":
		if not _end_shown: _show_end_game(GameManager.game_state)
		return
	if message_popup.visible or event_popup.visible: return
	# a trónváltás mindent megelőz: előbb tudd meg, ki ül a trónon
	if not GameManager.pending_succession.is_empty() and not (tron_popup != null and tron_popup.visible):
		var vals: Dictionary = GameManager.pending_succession
		GameManager.pending_succession = {}
		show_succession_popup(vals)
		return
	if not GameManager.pending_elimination.is_empty() and not (bukas_popup != null and bukas_popup.visible):
		var bu: Dictionary = GameManager.pending_elimination
		GameManager.pending_elimination = {}
		show_elimination_popup(bu)
		return
	if not GameManager.pending_raid.is_empty() and not battle_popup.visible:
		show_raid_popup()
	elif not GameManager.pending_event.is_empty() and not event_popup.visible and not battle_popup.visible:
		show_event_popup()

# ── Parancsok eredménye ───────────────────────────────────────

func _on_command_result(result: Dictionary) -> void:
	var args: Dictionary = result.get("args", {})
	if result.get("cmd", "") == "dlc":
		DLC.hook("on_command_result", [self, result])
		return
	match result.get("cmd", ""):
		"plunder":
			var target: String = str(args.get("target", ""))
			if not result.get("ok", false):
				if result.has("reason"): show_message(GameManager.province_label(target), tr(str(result["reason"])))
			elif result.get("won", false):
				AudioManager.play_sfx_victory()
				show_message(Localization.t("PLUNDER_RESULT_TITLE", [GameManager.province_label(target)]),
					Localization.t("PLUNDER_RESULT_WON", [GameManager.province_label(target), result["loot"], result["lost_fyrd"]]))
			else:
				AudioManager.play_sfx_defeat()
				show_message(Localization.t("PLUNDER_RESULT_TITLE", [GameManager.province_label(target)]),
					Localization.t("PLUNDER_RESULT_CAUGHT", [GameManager.province_label(target), result["lost_fyrd"],
					result["lost_thegn"], GameManager.faction_key(int(result["owner"]))])
					+ ("\n\n" + Localization.t("PLUNDER_RESULT_WAR", [GameManager.faction_key(int(result["owner"]))]) if result.get("war", false) else ""))
		"build":
			if result.get("ok", false):
				if args.get("kind", "") in ["fyrd", "thegn"]:
					AudioManager.play_sfx_click()
				else:
					AudioManager.play_sfx_build()
					_flash_province(args.get("province", ""), Color(1.0, 0.9, 0.3, 0.8))
		"march":
			if result.get("ok", false):
				_flash_province(args.get("to", ""), Color(0.3, 1.0, 0.5, 0.7))
		"attack", "raid":
			if result.get("ok", false):
				if result.get("paid_danegeld", false):
					_flash_screen(Color(1, 0.8, 0.1, 0.4))
				elif result.get("won", false):
					_flash_screen(Color(0.2, 1.0, 0.3, 0.5))
					AudioManager.play_sfx_victory()
				else:
					_flash_screen(Color(1.0, 0.2, 0.2, 0.5))
					AudioManager.play_sfx_defeat()
				_show_battle_report(str(result["cmd"]), result)
		"event":
			if result.get("ok", false) and int(result.get("success", -1)) >= 0:
				var ok := int(result["success"]) == 1
				var prefix := "EVENT_" + str(result["id"])
				show_message(Localization.t(prefix + "_TITLE", result.get("event_args", [])),
					Localization.t("EVENT_OUTCOME_OK" if ok else "EVENT_OUTCOME_FAIL",
						["%s_C%d" % [prefix, int(result["choice"]) + 1]]) + "\n\n" + effects_summary(result["effects"], "\n"))
				if ok: AudioManager.play_sfx_victory()
				else: AudioManager.play_sfx_defeat()
		"witan_gift":
			if result.get("ok", false):
				AudioManager.play_sfx_diplomacy()
				# lássa a játékos, mit ért az ajándék
				_show_toast(Localization.t("WITAN_GIFT_DONE", [GameManager.witan_gift_last]))
		"gift":
			if result.get("ok", false): AudioManager.play_sfx_diplomacy()
		"spare":
			if result.get("ok", false):
				AudioManager.play_sfx_diplomacy()
				var tf := int(result.get("target", -1))
				show_message(tr("SPARED_TITLE"), Localization.t("SPARED_BODY", [GameManager.faction_key(tf)]))
		"homeland_help":
			if homeland_popup: _close_popup(homeland_popup)
			_show_homeland_result(result)
		"homeland_gift":
			if result.get("ok", false): AudioManager.play_sfx_diplomacy()
			_refresh_homeland_ui()
		"papal_gift":
			if result.get("ok", false): AudioManager.play_sfx_diplomacy()
			_refresh_papal_ui()
		"papal_blessing", "papal_mediation":
			if papal_popup: _close_popup(papal_popup)
			_show_papal_result(result)
		"peace", "marriage", "vassal", "trade":
			_show_dip_result(str(result["cmd"]).to_upper(), result)

# Csatajelentés: erők, veszteségek, bevonuló helyőrség / zsákmány
func _show_battle_report(cmd: String, r: Dictionary) -> void:
	var t: String = r.get("target", "")
	if t == "": return
	if cmd == "attack":
		var won: bool = r.get("won", false)
		var desc := Localization.t("REPORT_ATTACK_WON" if won else "REPORT_ATTACK_LOST",
			[t, r.get("attacker_power", 0), r.get("defender_power", 0), r.get("lost_fyrd", 0), r.get("lost_thegn", 0),
			r.get("enemy_fyrd", 0), r.get("enemy_thegn", 0), r.get("moved_fyrd", 0), r.get("moved_thegn", 0)])
		show_message(Localization.t("REPORT_TITLE_WON" if won else "REPORT_TITLE_LOST", [t]), desc)
	elif r.get("origin", "") == "rebels":
		var title := tr("CIVIL_WAR_TITLE")
		if r.get("paid_danegeld", false):
			show_message(title, Localization.t("REPORT_REBELS_BRIBED", [r.get("bribe", 0)]))
		elif r.get("won", false):
			show_message(title, Localization.t("REPORT_REBELS_CRUSHED", [t]))
		else:
			show_message(title, Localization.t("REPORT_REBELS_WON", [t]))
	elif r.has("site"):
		var site: String = r["site"]
		if r.get("won", false):
			show_message(Localization.t("RAID_TITLE_SITE", [site]), Localization.t("REPORT_SITE_SAVED", [site]))
		else:
			show_message(Localization.t("RAID_TITLE_SITE", [site]), Localization.t("REPORT_SITE_SACKED", [site, r.get("silver_lost", 0)]))
	elif not r.get("paid_danegeld", false):
		if r.get("won", false):
			show_message(Localization.t("REPORT_RAID_TITLE", [t]), Localization.t("REPORT_RAID_REPELLED", [t]))
		elif r.get("conquest", false) and GameManager.provinces.get(t, {}).get("faction", -1) != GameManager.player_faction:
			show_message(Localization.t("REPORT_RAID_TITLE", [t]), Localization.t("REPORT_RAID_CONQUERED", [t, r.get("silver_lost", 0)]))
		else:
			show_message(Localization.t("REPORT_RAID_TITLE", [t]), Localization.t("REPORT_RAID_PLUNDER", [t, r.get("silver_lost", 0)]))

func _on_action(kind: String) -> void:
	if selected_province.is_empty(): return
	Net.request("build", {"province": selected_province, "kind": kind})

func _on_move_army() -> void:
	if GameManager.move_mode:
		GameManager.cancel_move_mode()
		update_info_panel(); refresh_map()
		return
	if selected_province.is_empty() or not _can_act(): return
	var p = GameManager.provinces.get(selected_province, {})
	if p.get("faction") != GameManager.player_faction: return
	if p.get("fyrd", 0) == 0 and p.get("thegn", 0) == 0 and p.get("ships", 0) == 0: return
	GameManager.start_move_mode(selected_province)
	update_info_panel(); refresh_map()

# ── Csata ─────────────────────────────────────────────────────

func _on_attack() -> void:
	if selected_province.is_empty(): return
	var p = GameManager.provinces.get(selected_province, {})
	if p.get("faction") == GameManager.player_faction: return
	if not GameManager.is_at_war(GameManager.player_faction, p["faction"]):
		# óészakiak: portya háború nélkül
		if GameManager.is_norse(GameManager.player_faction):
			Net.request("plunder", {"target": selected_province})
		return
	var nb = GameManager.get_player_neighbors_of(selected_province)
	var naval = GameManager.get_naval_sources(selected_province)
	if nb.is_empty() and naval.is_empty(): return
	attack_target = selected_province
	battle_is_raid = false
	lbl_battle_title.text = Localization.t("BATTLE_TITLE", [attack_target])
	_build_attack_sources(nb, naval)
	_refresh_battle_numbers()
	btn_pay_danegeld.visible = false
	btn_battle_cancel.visible = true
	# Az utolsó tartományuk? Akkor szóljunk, és kínáljuk fel a kegyelmet.
	GameManager.acting_faction = GameManager.player_faction
	var utolso := GameManager.is_last_province(selected_province)
	lbl_utolso.visible = utolso
	btn_kegyelem.visible = utolso
	if utolso:
		var vf: int = p["faction"]
		lbl_utolso.text = Localization.t("LAST_STAND_WARN",
			[GameManager.faction_key(vf), GameManager.province_label(selected_province)])
		btn_kegyelem.text = Localization.t("BTN_SPARE", [GameManager.faction_key(vf)])
		btn_kegyelem.tooltip_text = Localization.t("BTN_SPARE_TIP", [GameManager.faction_key(vf)])
	AudioManager.play_sfx_battle()
	_open_popup(battle_popup)


func _on_kegyelem() -> void:
	var p: Dictionary = GameManager.provinces.get(attack_target, {})
	if p.is_empty(): return
	_close_popup(battle_popup)
	Net.request("spare", {"target": int(p["faction"])})

# ── Honnan induljon a roham? ───────────────────────────────────
#
# Eddig a játék MINDEN szomszédos tartomány helyőrségét bevetette, akár akartad,
# akár nem – és mind veszített is embert. Mostantól kipipálhatod, melyik vegyen
# részt: a kint hagyott tartomány otthon marad, és sértetlen is.
# Alapból mind be van jelölve, tehát aki nem törődik vele, a régi viselkedést kapja.

func _build_attack_sources(nb: Array, naval: Array) -> void:
	if _attack_src_box == null:
		_attack_src_box = VBoxContainer.new()
		_attack_src_box.add_theme_constant_override("separation", 0)
		var box := lbl_battle_desc.get_parent()
		box.add_child(_attack_src_box)
		box.move_child(_attack_src_box, lbl_battle_desc.get_index() + 1)
	for c in _attack_src_box.get_children():
		_attack_src_box.remove_child(c)
		c.queue_free()
	_attack_src.clear()
	# egyetlen lehetséges kiindulásnál nincs mit választani: ne zavarjuk a képet
	if nb.size() + naval.size() < 2:
		_attack_src_box.visible = false
		for n in nb: _attack_src.append({"name": n, "naval": false, "on": true})
		for n in naval: _attack_src.append({"name": n, "naval": true, "on": true})
		return
	_attack_src_box.visible = true
	var fej := Label.new()
	fej.text = tr("BATTLE_SOURCES")
	fej.add_theme_font_size_override("font_size", 14)
	fej.add_theme_color_override("font_color", Color(0.82, 0.72, 0.52))
	_attack_src_box.add_child(fej)
	for lista in [[nb, false], [naval, true]]:
		for n in lista[0]:
			var p: Dictionary = GameManager.provinces[n]
			var bejegyzes := {"name": n, "naval": bool(lista[1]), "on": true}
			_attack_src.append(bejegyzes)
			var cb := CheckBox.new()
			cb.button_pressed = true
			cb.add_theme_font_size_override("font_size", 14)
			var ero := GameManager.calculate_attack_power([n]) if not lista[1] \
				else GameManager.calculate_attack_power([], [n])
			cb.text = Localization.t("BATTLE_SOURCE_SEA" if lista[1] else "BATTLE_SOURCE_LAND",
				[n, ero, int(p["fyrd"]), int(p["thegn"])])
			cb.toggled.connect(func(on: bool):
				bejegyzes["on"] = on
				_refresh_battle_numbers())
			_attack_src_box.add_child(cb)

# A kijelölt tartományok listája (ezt kapja a parancs)
func _attack_source_names() -> Array:
	var r: Array = []
	for e in _attack_src:
		if e["on"]: r.append(e["name"])
	return r

# A támadóerő, a leírás és a harcmodor-gombok újraszámolása a pipák szerint
func _refresh_battle_numbers() -> void:
	if attack_target == "" or battle_is_raid: return
	var land: Array = []
	var naval: Array = []
	for e in _attack_src:
		if not e["on"]: continue
		if e["naval"]: naval.append(e["name"])
		else: land.append(e["name"])
	var atk: int = GameManager.calculate_attack_power(land, naval)
	var def: int = GameManager.calculate_defense_power(attack_target)
	# a MEGJELENŐ nevekkel, mint a jelölőnégyzeteken (790-ben Oxford még Dorchester)
	var sources: PackedStringArray = []
	for n in land: sources.append(GameManager.province_label(n))
	for n in naval: sources.append(Localization.t("BATTLE_BY_SEA", [n, GameManager.provinces[n]["ships"]]))
	var lines: PackedStringArray = [
		Localization.t("BATTLE_OUR_ARMY", [atk, ", ".join(sources) if not sources.is_empty() else tr("BATTLE_NO_SOURCE")]),
		Localization.t("BATTLE_DEFENDERS", [def]),
		"",
		tr("BATTLE_RULES")
	]
	lbl_battle_desc.text = "\n".join(lines)
	# a harcmodorok várható eredménye (a csata kimenetele az erőkből pontosan kiszámítható)
	btn_shield_wall.text = _tactic_text("BTN_SHIELD_WALL", atk * 1.5, def, atk * 1.5 > def)
	btn_charge.text = _tactic_text("BTN_CHARGE", atk * 1.2, def * 1.1, atk * 1.2 > def * 1.1)
	# mindent kipipálva nincs kivel támadni
	var van := not (land.is_empty() and naval.is_empty())
	btn_shield_wall.disabled = not van
	btn_charge.disabled = not van

# Harcmodor-gomb felirata: "Pajzsfal: 68 ⚔ 40 – győzelem"
func _tactic_text(key: String, ours: float, theirs: float, win: bool) -> String:
	return Localization.t("TACTIC_LINE", [key, roundi(ours), roundi(theirs), "OUTCOME_WIN" if win else "OUTCOME_LOSE"])

func _on_battle_cancel() -> void:
	AudioManager.play_sfx_click()
	attack_target = ""
	_close_popup(battle_popup)

func show_raid_popup() -> void:
	var raid: Dictionary = GameManager.pending_raid
	battle_is_raid = true
	# portyánál nincs mit választani: a támadás ránk jön
	if _attack_src_box != null: _attack_src_box.visible = false
	btn_shield_wall.disabled = false
	btn_charge.disabled = false
	attack_target = raid["target"]
	var origin: String = raid.get("origin", "danes")
	var punish := origin == "punish"
	var rebels := origin == "rebels"
	var site: String = raid.get("site", "")
	var king := GameManager.homeland_king_for(GameManager.player_faction)
	var atk: int = int(raid["strength"]) * 8
	var def: int = GameManager.raid_defense_for(raid)
	if site != "":
		lbl_battle_title.text = Localization.t("RAID_TITLE_SITE", [site])
	elif rebels:
		lbl_battle_title.text = Localization.t("RAID_TITLE_REBELS", [raid.get("base", attack_target)])
	else:
		lbl_battle_title.text = Localization.t("RAID_TITLE_" + origin.to_upper(), [attack_target, king])
	var lines: PackedStringArray = []
	if site != "":
		lines.append(Localization.t("RAID_SITE_DESC", [site, attack_target]))
	elif rebels:
		lines.append(Localization.t("RAID_REBELS_DESC", [raid.get("base", ""), attack_target]))
	lines.append(Localization.t("RAID_ENEMY", [atk]))
	lines.append(Localization.t("RAID_OUR_DEFENSE", [def, attack_target]))
	if site != "": lines.append(tr("RAID_SITE_DEFENSE_NOTE"))
	# mi történik vereség esetén
	lines.append("")
	if punish:
		lines.append(Localization.t("RAID_PUNISH_WARNING", [king, attack_target]))
	elif rebels:
		lines.append(tr("RAID_REBELS_WARNING"))
	elif site != "":
		lines.append(Localization.t("RAID_SITE_WARNING", [site]))
	elif raid.get("conquest", false):
		lines.append(Localization.t("RAID_CONQUEST_WARNING", [attack_target]))
	else:
		lines.append(tr("RAID_PLUNDER_WARNING"))
	lbl_battle_desc.text = "\n".join(lines)
	btn_shield_wall.text = _tactic_text("BTN_SHIELD_WALL", def * 1.5, atk, def * 1.5 >= atk)
	btn_charge.text = _tactic_text("BTN_CHARGE", def, atk * 0.7, def >= atk * 0.7)
	# fizetés: sarc (gafol), behódolás az anyaországnak vagy a trónkövetelő lefizetése
	var can_pay: bool = GameManager.raid_can_pay(raid)
	btn_pay_danegeld.visible = can_pay
	var price := 40
	if punish:
		price = GameManager.PUNISH_SUBMIT_COST
		btn_pay_danegeld.text = Localization.t("BTN_SUBMIT", [price])
	elif rebels:
		price = GameManager.rebel_bribe(int(raid["strength"]))
		btn_pay_danegeld.text = Localization.t("BTN_BRIBE", [price])
	else:
		btn_pay_danegeld.text = tr("BTN_DANEGELD")
	btn_pay_danegeld.disabled = GameManager.silver < price
	btn_pay_danegeld.tooltip_text = tr("REASON_NO_RESOURCES") if GameManager.silver < price else ""
	btn_battle_cancel.visible = false
	lbl_utolso.visible = false
	btn_kegyelem.visible = false
	AudioManager.play_sfx_viking()
	_open_popup(battle_popup)

# Esc: a támadás visszavonása (a portyára felelni kell, azt nem lehet bezárni)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and battle_popup.visible and not battle_is_raid:
		_on_battle_cancel()
		get_viewport().set_input_as_handled()

func _on_tactic(tactic: String) -> void:
	_close_popup(battle_popup)
	if battle_is_raid:
		Net.request("raid", {"tactic": tactic})
	elif tactic != "danegeld":
		# a kijelölt kiindulópontok is átmennek (többjátékosban a gazdagéphez)
		Net.request("attack", {"target": attack_target, "tactic": tactic,
			"sources": _attack_source_names()})

# ── Esemény ────────────────────────────────────────────────────

func show_event_popup() -> void:
	var ev: Dictionary = GameManager.pending_event
	if ev.is_empty(): return
	var data := GameManager.find_event(str(ev["id"]))
	if data.is_empty(): return
	var prefix := "EVENT_" + str(ev["id"])
	var args: Array = ev.get("args", [])
	var kind: String = ev.get("kind", "random")
	lbl_event_kind.text = Localization.t("EVENT_KIND_" + kind.to_upper(), [GameManager.current_year])
	lbl_event_title.text = Localization.t(prefix + "_TITLE", args)
	lbl_event_desc.text  = Localization.t(prefix + "_DESC", args)
	var choices: Array = data["choices"]
	for i in event_buttons.size():
		var b: Button = event_buttons[i]
		b.visible = i < choices.size()
		if not b.visible: continue
		b.text = Localization.t("%s_C%d" % [prefix, i + 1], args) + "\n" + _choice_summary(choices[i])
		b.tooltip_text = ""
	AudioManager.play_sfx_diplomacy()
	_open_popup(event_popup)

func _choice_summary(choice: Dictionary) -> String:
	if not choice.has("chance"):
		return "(" + effects_summary(choice.get("effects", {})) + ")"
	var text := Localization.t("EFF_CHANCE", [roundi(float(choice["chance"]) * 100)])
	if not choice.get("effects", {}).is_empty():
		text = effects_summary(choice["effects"]) + " · " + text
	return "(%s)\n%s %s  |  %s %s" % [text, tr("EFF_SUCCESS"), effects_summary(choice["success"]),
		tr("EFF_FAIL"), effects_summary(choice["fail"])]

func _on_event_choice(choice: int) -> void:
	_close_popup(event_popup)
	Net.request("event", {"choice": choice})

# ── Diplomácia ────────────────────────────────────────────────

# A diplomácia gombok a többi élő királyságot mutatják (a még meg nem jelent / kihalt nem látszik)
func _update_diplomacy_buttons() -> void:
	dip_factions = []
	for f in GameManager.ALL_FACTIONS:
		if f != GameManager.player_faction and GameManager.is_alive(f): dip_factions.append(f)
	for i in dip_buttons.size():
		var btn: Button = dip_buttons[i]
		btn.visible = i < dip_factions.size()
		if not btn.visible: continue
		var f: int = dip_factions[i]
		var human := GameManager.is_multiplayer and f in GameManager.human_factions
		btn.text = _dip_icons(f) + GameManager.faction_name(f) + (" ♦" if human else "")
		var tip := _dip_relation_text(f)
		if human: tip += ("\n" if tip != "" else "") + tr("MP_HUMAN_PLAYER")
		elif not GameManager.is_alive(f): tip += ("\n" if tip != "" else "") + tr("DIP_NO_LANDS")
		btn.tooltip_text = tip
		btn.modulate = Color(1, 1, 1, 1.0 if GameManager.is_alive(f) else 0.55)
		btn.add_theme_color_override("font_color", GameManager.faction_color(f).lightened(0.35))

# A királyság neve elé kerülő jelek: ⚔ háború, 🤝 szövetség, ⚖ kereskedelmi egyezmény.
# Szövetséges kereskedőpartnernél mindkettő látszik; háborúban nincs egyezmény.
func _dip_icons(f: int) -> String:
	var d := GameManager.get_diplomacy(GameManager.player_faction, f)
	var s := ""
	match int(d.get("state", -1)):
		GameManager.DiplomacyState.WAR:  s += "⚔"
		GameManager.DiplomacyState.ALLY: s += "🤝"
	if d.get("trade", false): s += "⚖"
	return s + " " if s != "" else ""

# A jelek jelentése a gomb súgójában
func _dip_relation_text(f: int) -> String:
	var pf := GameManager.player_faction
	var d := GameManager.get_diplomacy(pf, f)
	var lines: Array = []
	match int(d.get("state", -1)):
		GameManager.DiplomacyState.WAR:  lines.append("⚔ " + tr("DIP_STATE_WAR"))
		GameManager.DiplomacyState.ALLY: lines.append("🤝 " + tr("DIP_STATE_ALLY"))
		GameManager.DiplomacyState.VASSAL:
			# eddig a hűbéri viszonynak semmi jele nem volt a listán
			if GameManager.is_vassal_of(f, pf):
				lines.append("♛ " + tr("DIP_STATE_OUR_VASSAL"))
			elif GameManager.is_vassal_of(pf, f):
				lines.append("⚑ " + tr("DIP_STATE_OUR_LORD"))
	if d.get("trade", false): lines.append("⚖ " + tr("DIP_STATE_TRADE"))
	return "\n".join(lines)

func _on_dip_button(index: int) -> void:
	if index < dip_factions.size():
		open_diplomacy(dip_factions[index])

func open_diplomacy(target_faction: int) -> void:
	if target_faction == GameManager.player_faction: return
	dip_target_faction = target_faction
	_refresh_diplomacy_ui()
	AudioManager.play_sfx_diplomacy()
	_open_popup(diplomacy_popup)

func _refresh_diplomacy_ui() -> void:
	if dip_target_faction < 0: return
	var pf   = GameManager.player_faction
	var tf   = dip_target_faction
	var d    = GameManager.get_diplomacy(pf, tf)
	var state = d.get("state", -1)
	var proposed := GameManager.proposal_made_this_turn(tf)
	var human: bool = tf in GameManager.human_factions
	dip_lbl_title.text = Localization.t("DIP_TITLE", [GameManager.faction_key(tf)])
	_frissit_dip_portre(tf)
	var state_name = "?"
	match state:
		GameManager.DiplomacyState.WAR:     state_name = tr("DIP_STATE_WAR")
		GameManager.DiplomacyState.NEUTRAL: state_name = tr("DIP_STATE_NEUTRAL")
		GameManager.DiplomacyState.TRUCE:   state_name = Localization.t("DIP_STATE_TRUCE", [d.get("truce_turns", 0)])
		GameManager.DiplomacyState.ALLY:    state_name = tr("DIP_STATE_ALLY")
		GameManager.DiplomacyState.VASSAL:
			var lord := int(d.get("vassal_of", -1))
			state_name = tr("DIP_STATE_OUR_VASSAL") if lord == pf else (tr("DIP_STATE_OUR_LORD") if lord == tf else tr("DIP_STATE_VASSAL"))
	dip_lbl_status.text = Localization.t("DIP_STATUS", [state_name])
	var trading: bool = d.get("trade", false)
	if trading: dip_lbl_status.text += "\n" + Localization.t("DIP_TRADE_ACTIVE", [roundi(GameManager.TRADE_BONUS * 100)])
	# a hűbéri viszony nem csak cím: lássuk, mennyi adót hoz
	if GameManager.is_vassal_of(tf, pf):
		var ado := 0
		for pn in GameManager.get_faction_provinces(tf):
			ado += int(GameManager.provinces[pn]["silver_prod"]) / 3
		dip_lbl_status.text += "\n" + Localization.t("DIP_VASSAL_ACTIVE", [ado])
	elif GameManager.is_vassal_of(pf, tf):
		dip_lbl_status.text += "\n" + tr("DIP_LORD_ACTIVE")
	var ruler := GameManager.historical_ruler(tf, GameManager.current_year)
	var hint := Localization.t("DIP_RULER", [ruler]) if ruler != "" else ""
	# a sorra víve az egeret a másik király négysoros életrajza is előjön
	# (a Label alapból nem kap egeret, ezért kell a PASS)
	dip_lbl_hint.mouse_filter = Control.MOUSE_FILTER_PASS
	dip_lbl_hint.tooltip_text = GameManager.ruler_tooltip(ruler)
	if proposed:
		hint += "\n" + tr("REASON_ALREADY_PROPOSED")
	elif human:
		hint += "\n" + tr("MP_HUMAN_PLAYER")
	elif state == GameManager.DiplomacyState.WAR:
		hint += "\n" + Localization.t("DIP_CHANCE_PEACE", [roundi(GameManager.acceptance_chance(tf, 0.45) * 100)])
	else:
		hint += "\n" + Localization.t("DIP_CHANCE_MARRIAGE", [roundi(GameManager.acceptance_chance(tf, 0.5) * 100)])
		if not d.get("trade", false):
			hint += "\n" + Localization.t("DIP_CHANCE_TRADE", [roundi(GameManager.acceptance_chance(tf, 0.6) * 100)])
	dip_lbl_hint.text = hint.strip_edges()
	# Minden ajánlat mellé odatesszük, MIÉRT annyi az esélye – tételesen
	dip_btn_peace.tooltip_text    = _dip_reason_text(tf, GameManager.DIP_BASE["peace"])
	dip_btn_marriage.tooltip_text = _dip_reason_text(tf, GameManager.DIP_BASE["marriage"])
	dip_btn_trade.tooltip_text    = _dip_reason_text(tf, GameManager.DIP_BASE["trade"])
	dip_btn_vassal.tooltip_text   = _dip_reason_text(tf, GameManager.DIP_BASE["vassal"])
	dip_btn_gift.tooltip_text     = tr("DIP_GIFT_TIP")
	dip_btn_war.tooltip_text      = tr("DIP_WAR_TIP")
	var can := _can_act()
	dip_btn_gift.disabled     = not can or GameManager.silver < 30
	dip_btn_marriage.disabled = not can or proposed or GameManager.silver < 60 or state == GameManager.DiplomacyState.WAR or state == GameManager.DiplomacyState.ALLY
	dip_btn_vassal.disabled   = not can or proposed or GameManager.silver < 100 or state == GameManager.DiplomacyState.WAR or state == GameManager.DiplomacyState.VASSAL
	dip_btn_war.disabled      = not can or state == GameManager.DiplomacyState.WAR
	dip_btn_peace.disabled    = not can or proposed or GameManager.silver < 30 or state != GameManager.DiplomacyState.WAR
	dip_btn_trade.disabled    = not can or proposed or trading or GameManager.silver < GameManager.PROPOSAL_COSTS["trade"] \
		or state == GameManager.DiplomacyState.WAR

## Egy diplomáciai ajánlat esélyének TÉTELES indoklása a gomb súgójába:
## „+45 alapesély · +12 erősebb vagy · −20 tengeri nép · = 37%”.
## Így a játékos előre látja, mitől függ a válasz, nem csak egy puszta számot kap.
func _dip_reason_text(tf: int, base: float) -> String:
	GameManager.acting_faction = GameManager.player_faction
	var sorok: Array = []
	for m in GameManager.dip_modifiers(tf, base):
		sorok.append("%s   %s" % [_signed(int(m["value"])), tr(str(m["key"]))])
	sorok.append("─────")
	sorok.append(Localization.t("DIP_CHANCE_TOTAL",
		[roundi(GameManager.acceptance_chance(tf, base) * 100)]))
	return "\n".join(sorok)


func _show_dip_result(kind: String, result: Dictionary) -> void:
	var reason: String = result.get("reason", "")
	if reason == "INVALID": return
	var f := GameManager.faction_key(dip_target_faction)
	var key: String
	if reason == "SENT":
		key = "DIP_PROPOSAL_SENT"
		AudioManager.play_sfx_click()
	elif result.get("accepted", false):
		key = "DIP_%s_ACCEPTED" % kind
		AudioManager.play_sfx_diplomacy()
	else:
		key = "DIP_VASSAL_TOO_WEAK" if reason == "TOO_WEAK" else "DIP_%s_REJECTED" % kind
		AudioManager.play_sfx_battle()
	var szoveg := Localization.t(key, [f])
	# Az elutasítás ne legyen szótlan: lássuk, mi szólt ellene és mi mellette.
	var alap: float = GameManager.DIP_BASE.get(kind.to_lower(), -1.0)
	if not result.get("accepted", false) and reason == "" and alap > 0.0:
		szoveg += "\n\n" + tr("DIP_WHY") + "\n" + _dip_reason_text(dip_target_faction, alap)
	show_message(Localization.t("DIP_RESULT_TITLE", [f]), szoveg)

# ── Kör vége ──────────────────────────────────────────────────

func _on_next_turn() -> void:
	if not _can_act(): return
	GameManager.cancel_move_mode()
	var ready: bool = not GameManager.player_faction in GameManager.ready_factions
	Net.request("end_turn", {"ready": ready})

# ── Játékmenü (jobb felül): mentés, betöltés, beállítások ─────

func _refresh_game_menu() -> void:
	var popup := btn_game_menu.get_popup()
	popup.clear()
	popup.add_item(tr("BTN_SAVE"), GameMenu.SAVE)
	popup.set_item_disabled(popup.get_item_index(GameMenu.SAVE), GameManager.is_multiplayer)
	popup.add_item(tr("MENU_LOAD"), GameMenu.LOAD)
	popup.set_item_disabled(popup.get_item_index(GameMenu.LOAD), GameManager.is_multiplayer or not SaveManager.has_save())
	popup.add_item(tr("SETTINGS_TITLE"), GameMenu.SETTINGS)
	popup.add_item(tr("ACH_TITLE"), GameMenu.ACHIEVEMENTS)
	popup.add_separator()
	popup.add_item(tr("MP_LEAVE") if GameManager.is_multiplayer else tr("BTN_MAIN_MENU"), GameMenu.MAIN_MENU)
	popup.add_item(tr("MENU_QUIT"), GameMenu.QUIT)

func _on_game_menu_item(id: int) -> void:
	AudioManager.play_sfx_click()
	match id:
		GameMenu.SAVE:
			_flash_menu_text(tr("SAVE_OK") if SaveManager.save_game() else tr("SAVE_ERROR"))
		GameMenu.LOAD:
			if SaveManager.load_game():
				get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
		GameMenu.SETTINGS:
			settings.open()
			dim.show()
		GameMenu.ACHIEVEMENTS:
			achievements_popup.open()
			dim.show()
		GameMenu.MAIN_MENU:
			_on_main_menu()
		GameMenu.QUIT:
			Net.leave()
			get_tree().quit()

# Rövid visszajelzés a menügomb feliratában (pl. "Mentve!")
func _flash_menu_text(text: String) -> void:
	btn_game_menu.text = text
	_menu_text_timer = get_tree().create_timer(2.0)
	_menu_text_timer.timeout.connect(_restore_menu_text.bind(_menu_text_timer))

func _restore_menu_text(timer: SceneTreeTimer) -> void:
	if _menu_text_timer == timer:
		btn_game_menu.text = tr("MENU_BUTTON")

func _on_language_changed() -> void:
	_apply_static_texts()
	update_all()
	map_view.refresh_texts()

func _on_session_ended(reason: String) -> void:
	_message_queue.clear()
	show_message(tr("MP_TITLE"), tr(reason))
	msg_btn_ok.pressed.connect(_on_main_menu, CONNECT_ONE_SHOT)

# ── Játék vége ────────────────────────────────────────────────

## A játék vége. Bukásnál nem elég egy mondat: az uralkodó arcképe, a birodalom
## számvetése (hány év, meddig ért a legnagyobb kiterjedése, hány csata, hány
## tartomány) és az utolsó krónikasorok zárják le a játszmát.
func _show_end_game(state: String) -> void:
	_end_shown = true
	var pf := GameManager.player_faction
	var entries := GameManager.chronicle_for(pf)
	var last = GameManager.chronicle_text(entries.back()) if not entries.is_empty() else ""
	var args = [GameManager.current_year, GameManager.get_season_name(), last]
	var gyozelem := state == "won"
	if gyozelem:
		lbl_end_title.text = tr("END_WON_TITLE")
		lbl_end_desc.text  = Localization.t("END_WON_DESC", args)
		_flash_screen(Color(1, 0.9, 0.1, 0.6))
		AudioManager.play_sfx_victory()
	else:
		var deposed := state == "deposed"
		lbl_end_title.text = tr("END_DEPOSED_TITLE" if deposed else "END_LOST_TITLE")
		lbl_end_desc.text  = Localization.t("END_DEPOSED_DESC" if deposed else "END_LOST_DESC", args)
		_flash_screen(Color(0.8, 0.1, 0.1, 0.6))
		AudioManager.play_sfx_defeat()
	_epit_veg_szamvetes()
	var ruler := GameManager.historical_ruler(pf, GameManager.current_year)
	veg_portre.visible = ruler != ""
	if ruler != "":
		veg_portre.beallit(ruler, GameManager.culture_of(pf), GameManager.faction_color(pf),
			GameManager.current_year)
		veg_portre.modulate = Color.WHITE if gyozelem else Color(0.62, 0.58, 0.54)
		veg_portre.tooltip_text = GameManager.ruler_tooltip(ruler)
	var st: Dictionary = GameManager.realms[pf]["stats"]
	veg_szamvetes.text = "\n".join([
		Localization.t("END_STAT_YEARS", [GameManager.START_YEAR, GameManager.current_year,
			GameManager.current_year - GameManager.START_YEAR]),
		Localization.t("END_STAT_PEAK", [int(st.get("peak_provinces", 0))]),
		Localization.t("END_STAT_TAKEN", [int(st.get("provinces_taken", 0)), int(st.get("provinces_lost", 0))]),
		Localization.t("END_STAT_BATTLES", [int(st.get("battles_won", 0)), int(st.get("raids_repelled", 0))]),
	])
	# az utolsó néhány krónikasor: ez maradt a birodalomból
	var vegso: Array = []
	for e in entries.slice(maxi(0, entries.size() - 4), entries.size()):
		vegso.append(GameManager.chronicle_text(e))
	veg_kronika.text = "\n".join(vegso)
	btn_restart.visible = not GameManager.is_multiplayer
	_open_popup(end_game_panel)


var veg_portre: Control
var veg_szamvetes: Label
var veg_kronika: Label

func _epit_veg_szamvetes() -> void:
	if veg_portre != null: return
	var box := lbl_end_desc.get_parent()
	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sor)
	box.move_child(sor, lbl_end_title.get_index() + 1)
	veg_portre = preload("res://scripts/ui/ruler_portrait.gd").new()
	veg_portre.custom_minimum_size = Vector2(170, 170)
	veg_portre.mouse_filter = Control.MOUSE_FILTER_PASS
	sor.add_child(veg_portre)

	veg_szamvetes = Label.new()
	veg_szamvetes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	veg_szamvetes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	veg_szamvetes.add_theme_font_size_override("font_size", 14)
	veg_szamvetes.add_theme_color_override("font_color", Color(0.98, 0.88, 0.62))
	box.add_child(veg_szamvetes)
	box.move_child(veg_szamvetes, lbl_end_desc.get_index() + 1)

	veg_kronika = Label.new()
	veg_kronika.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	veg_kronika.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	veg_kronika.add_theme_font_size_override("font_size", 12)
	veg_kronika.modulate = Color(1, 1, 1, 0.72)
	box.add_child(veg_kronika)
	box.move_child(veg_kronika, veg_szamvetes.get_index() + 1)

func _on_restart() -> void:
	GameManager.new_game(GameManager.player_faction)
	for p in popups: p.hide()
	dim.hide()
	_end_shown = false
	_last_fx_id = 0
	selected_province = ""; selected_locked = ""
	GameManager.cancel_move_mode()
	update_all()

func _on_main_menu() -> void:
	Net.leave()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
