extends Control

# HEPTARCHIA – többjátékos lobbi: játék létrehozása / csatlakozás, frakcióválasztás, indítás.
# A felületet kódból építi fel; a téma automatikusan érvényes rá.

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const SETTINGS_PATH := "user://settings.cfg"

var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _name_edit: LineEdit
var _host_port: SpinBox
var _upnp_check: CheckBox
var _address_edit: LineEdit
var _join_port: SpinBox
var _status: Label
var _info: Label
var _player_list: VBoxContainer
var _faction_opt: OptionButton
var _ready_check: CheckButton
var _start_btn: Button
var _title: Label
var _labels: Dictionary = {}     # nyelvi kulcs -> Label/Button (a feliratok frissítéséhez)

func _ready() -> void:
	_build()
	Net.lobby_changed.connect(_refresh)
	Net.connection_failed.connect(func(): _set_status(tr("MP_CONNECT_FAILED")))
	Net.session_ended.connect(_on_session_ended)
	Net.upnp_finished.connect(func(_ok: bool, _ip: String): _refresh())
	_refresh()

# ── Felépítés ──────────────────────────────────────────────────

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.025)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(bg)
	var map := TextureRect.new()
	map.texture = load("res://terkep.png")
	map.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map.modulate = Color(0.55, 0.43, 0.3, 0.45)
	add_child(map)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -360; panel.offset_right = 360
	panel.offset_top = -310; panel.offset_bottom = 310
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.add_theme_font_size_override("font_size", 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_title)
	var knot := KnotDivider.new()
	knot.custom_minimum_size = Vector2(0, 14)
	root.add_child(knot)

	# Csatlakozás / létrehozás
	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 10)
	root.add_child(_connect_box)

	var name_row := _row(_connect_box)
	_label(name_row, "MP_NAME")
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_edit.max_length = 20
	_name_edit.text = GameSettings.player_name
	name_row.add_child(_name_edit)

	_header(_connect_box, "MP_HOST_HEADER")
	var host_row := _row(_connect_box)
	_label(host_row, "MP_PORT")
	_host_port = _port_box(host_row)
	_upnp_check = CheckBox.new()
	_upnp_check.button_pressed = GameSettings.use_upnp
	_upnp_check.size_flags_horizontal = SIZE_EXPAND_FILL
	_labels["MP_UPNP"] = _upnp_check
	host_row.add_child(_upnp_check)
	var host_btn := Button.new()
	host_btn.custom_minimum_size = Vector2(170, 38)
	host_btn.pressed.connect(_on_host)
	_labels["MP_HOST_BUTTON"] = host_btn
	host_row.add_child(host_btn)

	_header(_connect_box, "MP_JOIN_HEADER")
	var join_row := _row(_connect_box)
	_label(join_row, "MP_ADDRESS")
	_address_edit = LineEdit.new()
	_address_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_address_edit.text = GameSettings.last_address if GameSettings.last_address != "" else "127.0.0.1"
	join_row.add_child(_address_edit)
	_join_port = _port_box(join_row)
	var join_btn := Button.new()
	join_btn.custom_minimum_size = Vector2(170, 38)
	join_btn.pressed.connect(_on_join)
	_labels["MP_JOIN_BUTTON"] = join_btn
	join_row.add_child(join_btn)

	var hint := Label.new()
	hint.theme_type_variation = &"SmallLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.85, 0.82, 0.74)
	_labels["MP_INTERNET_HINT"] = hint
	_connect_box.add_child(hint)

	# Lobbi
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 10)
	_lobby_box.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_lobby_box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.theme_type_variation = &"SmallLabel"
	_lobby_box.add_child(_info)
	_header(_lobby_box, "MP_PLAYERS")
	_player_list = VBoxContainer.new()
	_player_list.size_flags_vertical = SIZE_EXPAND_FILL
	_lobby_box.add_child(_player_list)
	var me_row := _row(_lobby_box)
	_label(me_row, "MP_YOUR_FACTION")
	_faction_opt = OptionButton.new()
	_faction_opt.size_flags_horizontal = SIZE_EXPAND_FILL
	_faction_opt.item_selected.connect(_on_faction_selected)
	me_row.add_child(_faction_opt)
	_ready_check = CheckButton.new()
	_ready_check.flat = true
	_ready_check.toggled.connect(func(on: bool): Net.set_ready(on))
	_labels["MP_READY"] = _ready_check
	me_row.add_child(_ready_check)

	var bottom := _row(root)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_start_btn = Button.new()
	_start_btn.theme_type_variation = &"BigButton"
	_start_btn.custom_minimum_size = Vector2(220, 46)
	_start_btn.pressed.connect(func(): Net.start_game())
	_labels["MP_START"] = _start_btn
	bottom.add_child(_start_btn)
	var back := Button.new()
	back.theme_type_variation = &"BigButton"
	back.custom_minimum_size = Vector2(220, 46)
	back.pressed.connect(_on_back)
	_labels["MP_BACK"] = back
	bottom.add_child(back)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	root.add_child(_status)

func _row(parent: Control) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r

func _label(parent: Control, key: String) -> Label:
	var l := Label.new()
	l.custom_minimum_size = Vector2(90, 0)
	_labels[key] = l
	parent.add_child(l)
	return l

func _header(parent: Control, key: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"HeaderLabel"
	_labels[key] = l
	parent.add_child(l)

func _port_box(parent: Control) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = 1024; s.max_value = 65535; s.step = 1
	s.value = GameSettings.port if GameSettings.port > 0 else Net.DEFAULT_PORT
	s.custom_minimum_size = Vector2(110, 0)
	parent.add_child(s)
	return s

# ── Frissítés ──────────────────────────────────────────────────

func _refresh() -> void:
	_title.text = tr("MP_TITLE")
	for key in _labels:
		_labels[key].text = tr(key)
	_connect_box.visible = not Net.active
	_lobby_box.visible = Net.active
	_start_btn.visible = Net.active and Net.is_lobby_leader()
	_start_btn.disabled = not Net.can_start()
	if not Net.active: return

	# Kapcsolati információ
	if Net.is_host:
		var lan := ", ".join(_lan_addresses())
		if Net.upnp_ok and Net.external_ip != "":
			_info.text = Localization.t("MP_HOST_INFO_UPNP", [Net.external_ip, Net.port, lan])
			# a port megnyílt a saját routeren, de a szolgáltató is NAT mögé tesz: kívülről így sem megy
			if Net.upnp_cgnat:
				_info.text += "\n" + Localization.t("MP_HOST_INFO_CGNAT", [Net.external_ip])
		else:
			_info.text = Localization.t("MP_HOST_INFO", [Net.port, lan])
	else:
		_info.text = Localization.t("MP_CLIENT_INFO", [Net.server_address, Net.port]) if not Net.players.is_empty() \
			else tr("MP_CONNECTING")

	# Játékosok
	for c in _player_list.get_children():
		c.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id in ids:
		var pl: Dictionary = Net.players[id]
		var l := Label.new()
		var mark := "✓" if pl["ready"] else "…"
		l.text = "%s  %s – %s%s" % [mark, pl["name"], GameManager.faction_name(pl["faction"]),
			"  (" + tr("MP_YOU") + ")" if id == Net.my_peer_id() else ""]
		l.add_theme_color_override("font_color", GameManager.faction_color(pl["faction"]).lightened(0.3))
		_player_list.add_child(l)

	# Saját frakció és kész állapot
	var me := Net.my_player()
	_faction_opt.clear()
	var i := 0
	for f in GameManager.PLAYABLE_FACTIONS:
		_faction_opt.add_item(GameManager.faction_name(f), f)
		var owner := Net.peer_for_faction(f)
		_faction_opt.set_item_disabled(i, owner != 0 and owner != Net.my_peer_id())
		if not me.is_empty() and me["faction"] == f:
			_faction_opt.select(i)
		i += 1
	_faction_opt.disabled = me.is_empty()
	_ready_check.disabled = me.is_empty()
	_ready_check.set_pressed_no_signal(not me.is_empty() and me["ready"])

func _lan_addresses() -> Array:
	var r: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			r.append(a)
	return r

func _set_status(text: String) -> void:
	_status.text = text

# ── Események ──────────────────────────────────────────────────

func _on_host() -> void:
	_remember()
	var err := Net.host_game(_name_edit.text, int(_host_port.value), _upnp_check.button_pressed)
	_set_status(tr("MP_UPNP_WORKING") if err == OK and _upnp_check.button_pressed else
		("" if err == OK else Localization.t("MP_HOST_FAILED", [int(_host_port.value)])))
	_refresh()

func _on_join() -> void:
	_remember()
	if _address_edit.text.strip_edges() == "":
		_set_status(tr("MP_NEED_ADDRESS"))
		return
	var err := Net.join_game(_name_edit.text, _address_edit.text, int(_join_port.value))
	_set_status(tr("MP_CONNECTING") if err == OK else tr("MP_CONNECT_FAILED"))
	_refresh()

func _on_session_ended(reason: String) -> void:
	_set_status(tr(reason))
	_refresh()

func _on_faction_selected(index: int) -> void:
	Net.set_faction(_faction_opt.get_item_id(index))

func _on_back() -> void:
	if Net.active:
		Net.leave()
		_set_status("")
		_refresh()
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

# A lobbiban használt értékek a Beállításokba is elmentődnek (Beállítások -> Többjátékos fül)
func _remember() -> void:
	GameSettings.player_name = _name_edit.text.strip_edges()
	GameSettings.port = int(_host_port.value)
	GameSettings.use_upnp = _upnp_check.button_pressed
	GameSettings.last_address = _address_edit.text.strip_edges()
	GameSettings.save_settings()
