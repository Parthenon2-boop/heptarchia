extends Control

# HEPTARCHIA – többjátékos lobbi: játék létrehozása / csatlakozás, frakcióválasztás, indítás.
# A felületet kódból építi fel; a téma automatikusan érvényes rá.

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const NetSzoba := preload("res://scripts/net_szoba.gd")
const Kepernyohoz := preload("res://scripts/ui/kepernyohoz.gd")
const SETTINGS_PATH := "user://settings.cfg"

var _kod_edit: LineEdit              # szoba: a barát szobakódja
var _szoba_sor: HBoxContainer        # szoba: a kód és a másolás gombjai a lobbiban (gazdagép)
var _szoba_kod: Label

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
var _elo_jovahagy: CheckBox          # élő csata: a szünethez kell-e a másik fél jóváhagyása (a gazdagép állítja)
var _elo_korlat: OptionButton        # élő csata: a szünetek száma és hossza
var _elo_info: Label
var _ev_kor: OptionButton            # az új játék tempója: évek körönként (a gazdagép állítja)
var _ev_kor_info: Label
var _ai_szint: OptionButton          # a gépi ellenfél ereje (a gazdagép állítja)
var _start_btn: Button
var _title: Label
var _folytatas: Label               # folytatott (mentett) hadjárat: melyik, és mely népek választhatók
var _folytatas_el: Button            # a gazdagép mégis új játékot indít
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
	# kis képernyőn (telefon, nagyobb felület-méret) arányosan kisebb, hogy az alsó gombok is látsszanak
	Kepernyohoz.bekot(panel)
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
	var foly_sor := _row(root)
	_folytatas = Label.new()
	_folytatas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_folytatas.size_flags_horizontal = SIZE_EXPAND_FILL
	_folytatas.add_theme_color_override("font_color", Color(1.0, 0.84, 0.4))
	foly_sor.add_child(_folytatas)
	_folytatas_el = Button.new()
	_folytatas_el.size_flags_vertical = SIZE_SHRINK_CENTER
	_folytatas_el.pressed.connect(_on_folytatas_el)
	_labels["MP_RESUME_DROP"] = _folytatas_el
	foly_sor.add_child(_folytatas_el)

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
	# a böngészőben a játékos neve a fiókneve (csak bejelentkezve lehet játszani)
	if _fiok_nev() != "":
		_name_edit.text = _fiok_nev()
		_name_edit.editable = false
		_name_edit.tooltip_text = tr("MP_ACCOUNT_NAME_TIP")

	# szoba szobakóddal (WebRTC): a böngészőben ez az egyetlen mód, asztali gépen csak a webrtc-native kiegészítővel
	if _szoba_lehet(): _build_szoba()
	# IP-cím és port (ENet): a böngésző nem tud ilyen kapcsolatot nyitni
	if not OS.has_feature("web"): _build_ip()

	# Lobbi
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 10)
	_lobby_box.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(_lobby_box)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.theme_type_variation = &"SmallLabel"
	_lobby_box.add_child(_info)
	if _szoba_lehet(): _build_szoba_lobbi()
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
	# élő csata (közösen vezetett taktikai csata): a szünet szabályai – a gazdagép állítja, a többiek látják
	var elo_row := _row(_lobby_box)
	_elo_jovahagy = CheckBox.new()
	_elo_jovahagy.size_flags_horizontal = SIZE_EXPAND_FILL
	_elo_jovahagy.toggled.connect(func(_on: bool): _elo_beall_kuld())
	_labels["MP_LIVE_PAUSE_APPROVAL"] = _elo_jovahagy
	elo_row.add_child(_elo_jovahagy)
	_label(elo_row, "MP_LIVE_PAUSE_LIMIT")
	_elo_korlat = OptionButton.new()
	_elo_korlat.item_selected.connect(func(_i: int): _elo_beall_kuld())
	elo_row.add_child(_elo_korlat)
	_elo_info = Label.new()
	_elo_info.theme_type_variation = &"SmallLabel"
	_elo_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lobby_box.add_child(_elo_info)
	# a játszma tempója: a gazdagép választja, a többiek látják
	var ido_row := _row(_lobby_box)
	_label(ido_row, "MENU_YEARS_PER_TURN")
	_ev_kor = OptionButton.new()
	_ev_kor.item_selected.connect(func(i: int): Net.ev_kor_allit(_ev_kor.get_item_id(i)))
	ido_row.add_child(_ev_kor)
	_label(ido_row, "MENU_AI_LEVEL")
	_ai_szint = OptionButton.new()
	_ai_szint.item_selected.connect(func(i: int): Net.ai_szint_allit(GameManager.AI_DIFFICULTIES[_ai_szint.get_item_id(i)]))
	ido_row.add_child(_ai_szint)
	_ev_kor_info = Label.new()
	_ev_kor_info.theme_type_variation = &"SmallLabel"
	_lobby_box.add_child(_ev_kor_info)

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
	if _labels.has("MP_ROOM_HINT") and _fiok_nev() != "":
		_labels["MP_ROOM_HINT"].text += "\n" + Localization.t("MP_ACCOUNT_SHOW", [_fiok_nev()])
	_connect_box.visible = not Net.active
	_lobby_box.visible = Net.active
	_start_btn.visible = Net.active and Net.is_lobby_leader()
	_start_btn.disabled = not Net.can_start()
	_frissit_folytatas()
	if not Net.active: return

	# Kapcsolati információ
	if _szoba_sor != null:
		var kod := str(Net.szoba.get("kod"))
		_szoba_sor.visible = Net.szobas() and Net.is_host and not Net.in_game and kod != ""
		_szoba_kod.text = Localization.t("MP_ROOM_CODE_SHOW", [kod])
	if Net.szobas():
		if Net.is_host:
			_info.text = tr("MP_ROOM_HOST_LOBBY") if bool(Net.szoba.get("_bent")) else tr("MP_ROOM_OPENING")
		else:
			_info.text = Localization.t("MP_ROOM_CLIENT_INFO", [Net.server_address]) if not Net.players.is_empty() \
				else Localization.t("MP_ROOM_JOINING", [Net.server_address])
		if _fiok_nev() != "": _info.text += "\n" + Localization.t("MP_ACCOUNT_SHOW", [_fiok_nev()])
		# a „nyílik…” / „csatlakozás…” felirat eltűnik, amint a szoba él, illetve bent vagyunk
		if _status.text in [tr("MP_ROOM_OPENING"), tr("MP_CONNECTING")] and \
				((Net.is_host and bool(Net.szoba.get("_bent"))) or (not Net.is_host and not Net.players.is_empty())):
			_set_status("")
	elif Net.is_host:
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
	for f in Net.valaszthato_nepek():
		_faction_opt.add_item(GameManager.faction_name(f), f)
		var owner := Net.peer_for_faction(f)
		_faction_opt.set_item_disabled(i, owner != 0 and owner != Net.my_peer_id())
		if not me.is_empty() and me["faction"] == f:
			_faction_opt.select(i)
		i += 1
	_faction_opt.disabled = me.is_empty()
	_ready_check.disabled = me.is_empty()
	_ready_check.set_pressed_no_signal(not me.is_empty() and me["ready"])
	# az élő csata szabályai
	var host_all := Net.is_host and not Net.in_game
	_elo_jovahagy.get_parent().visible = host_all
	_elo_jovahagy.set_pressed_no_signal(bool(Net.elo_beall["szunet_jovahagy"]))
	_elo_korlat.clear()
	var valasztott := 0
	for ki in Net.ELO_SZUNET_KORLATOK.size():
		var k: Array = Net.ELO_SZUNET_KORLATOK[ki]
		_elo_korlat.add_item(Localization.t("MP_LIVE_PAUSE_PRESET", [int(k[0]), int(k[1])]), ki)
		if int(k[0]) == int(Net.elo_beall["szunet_db"]) and int(k[1]) == int(Net.elo_beall["szunet_mp"]): valasztott = ki
	_elo_korlat.select(valasztott)
	# a tempó (évek körönként)
	_ev_kor.get_parent().visible = host_all
	_ev_kor.tooltip_text = tr("MENU_YEARS_PER_TURN_TIP")
	_ev_kor.clear()
	for n in GameManager.YEARS_PER_TURN_CHOICES: _ev_kor.add_item(tr("YPT_%d" % n), n)
	_ev_kor.select(maxi(0, GameManager.YEARS_PER_TURN_CHOICES.find(Net.ev_kor)))
	_ai_szint.tooltip_text = tr("MENU_AI_LEVEL_TIP")
	_ai_szint.clear()
	for j in GameManager.AI_DIFFICULTIES.size():
		_ai_szint.add_item(tr("AI_LEVEL_" + str(GameManager.AI_DIFFICULTIES[j]).to_upper()), j)
	_ai_szint.select(maxi(0, GameManager.AI_DIFFICULTIES.find(Net.ai_szint)))
	_ev_kor_info.visible = not host_all and SaveManager.mp_folytatas == ""
	_ev_kor_info.text = Localization.t("MP_YEARS_PER_TURN_INFO", [tr("YPT_%d" % Net.ev_kor)]) + " · " + \
		Localization.t("MP_AI_LEVEL_INFO", [tr("AI_LEVEL_" + Net.ai_szint.to_upper())])
	_elo_info.text = Localization.t("MP_LIVE_RULES", [tr("MP_LIVE_APPROVAL_ON") if bool(Net.elo_beall["szunet_jovahagy"]) else tr("MP_LIVE_APPROVAL_OFF"),
		int(Net.elo_beall["szunet_db"]), int(Net.elo_beall["szunet_mp"])])

func _elo_beall_kuld() -> void:
	Net.elo_beall_allit(_elo_jovahagy.button_pressed, _elo_korlat.get_selected_id())

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
	# máshoz csatlakozik: a saját mentett hadjárata nem folytatódik
	SaveManager.mp_folytatas = ""
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
		SaveManager.mp_folytatas = ""
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

## A folytatott hadjárat sora: a gazdagépnél a mentés neve és éve, mindenkinél a választható népek
func _frissit_folytatas() -> void:
	var nepek: Array = Net.mentes_nepek if Net.active else SaveManager.mp_nepek()
	var sajat := SaveManager.mp_folytatas != "" and (not Net.active or Net.is_host)
	_folytatas.get_parent().visible = sajat or (Net.active and not nepek.is_empty())
	_folytatas_el.visible = sajat and not Net.in_game
	var nevek: Array = []
	for f in nepek: nevek.append(GameManager.faction_name(int(f)))
	if sajat:
		var m := SaveManager.leiras(SaveManager.mp_folytatas)
		_folytatas.text = tr("MP_RESUME_INFO").format([SaveManager.cim(m) + " · " + SaveManager.ev_szoveg(m), ", ".join(nevek)])
	else:
		_folytatas.text = tr("MP_RESUME_CLIENT").format([", ".join(nevek)])

func _on_folytatas_el() -> void:
	SaveManager.mp_folytatas = ""
	if Net.active and Net.is_host and not Net.in_game:
		Net.mentes_nepek = []
		Net._broadcast_lobby()
	_refresh()

# A lobbiban használt értékek a Beállításokba is elmentődnek (Beállítások -> Többjátékos fül)
func _remember() -> void:
	GameSettings.player_name = _name_edit.text.strip_edges()
	GameSettings.port = int(_host_port.value)
	GameSettings.use_upnp = _upnp_check.button_pressed
	GameSettings.last_address = _address_edit.text.strip_edges()
	GameSettings.save_settings()

## Szoba szobakóddal (WebRTC): nyitás, illetve belépés a barát kódjával
func _build_szoba() -> void:
	_header(_connect_box, "MP_ROOM_HOST_HEADER")
	var nyit_sor := _row(_connect_box)
	var nyit_info := Label.new()
	nyit_info.theme_type_variation = &"SmallLabel"
	nyit_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nyit_info.size_flags_horizontal = SIZE_EXPAND_FILL
	_labels["MP_ROOM_HOST_INFO"] = nyit_info
	nyit_sor.add_child(nyit_info)
	var nyit := Button.new()
	nyit.custom_minimum_size = Vector2(170, 38)
	nyit.pressed.connect(_on_szoba_nyit)
	_labels["MP_ROOM_HOST_BUTTON"] = nyit
	nyit_sor.add_child(nyit)

	_header(_connect_box, "MP_ROOM_JOIN_HEADER")
	var be_sor := _row(_connect_box)
	_label(be_sor, "MP_ROOM_CODE")
	_kod_edit = LineEdit.new()
	_kod_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_kod_edit.max_length = 8
	_kod_edit.placeholder_text = "K7PQM"
	_kod_edit.add_theme_font_size_override("font_size", 22)
	_kod_edit.text = Net.meghivo_kod
	Net.meghivo_kod = ""
	_kod_edit.text_changed.connect(func(t: String) -> void:
		var c := _kod_edit.caret_column
		_kod_edit.text = t.to_upper()
		_kod_edit.caret_column = c)
	_kod_edit.text_submitted.connect(func(_t: String) -> void: _on_szoba_be())
	be_sor.add_child(_kod_edit)
	var be := Button.new()
	be.custom_minimum_size = Vector2(170, 38)
	be.pressed.connect(_on_szoba_be)
	_labels["MP_ROOM_JOIN_BUTTON"] = be
	be_sor.add_child(be)
	if OS.has_feature("web"): _labels["MP_ROOM_HINT"] = _hint(_connect_box)

func _hint(parent: Control) -> Label:
	var hint := Label.new()
	hint.theme_type_variation = &"SmallLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(0.85, 0.82, 0.74)
	parent.add_child(hint)
	return hint

## A szoba kódja és a meghívó link a lobbiban (a gazdagépnek): másolás gombokkal
func _build_szoba_lobbi() -> void:
	_szoba_sor = _row(_lobby_box)
	_szoba_kod = Label.new()
	_szoba_kod.add_theme_font_size_override("font_size", 30)
	_szoba_kod.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	_szoba_kod.size_flags_horizontal = SIZE_EXPAND_FILL
	_szoba_sor.add_child(_szoba_kod)
	var masol := Button.new()
	masol.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(str(Net.szoba.get("kod")))
		_set_status(tr("MP_ROOM_COPIED")))
	_labels["MP_ROOM_COPY_CODE"] = masol
	_szoba_sor.add_child(masol)
	if OS.has_feature("web"):
		var link := Button.new()
		link.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(_meghivo_link())
			_set_status(tr("MP_ROOM_LINK_COPIED")))
		_labels["MP_ROOM_COPY_LINK"] = link
		_szoba_sor.add_child(link)

func _meghivo_link() -> String:
	var hol := str(JavaScriptBridge.eval("location.origin + location.pathname", true))
	return hol + "?szoba=" + str(Net.szoba.get("kod"))

func _szoba_lehet() -> bool:
	return NetSzoba.elerheto()

func _fiok_nev() -> String:
	return str(Net.fiok.get("nev")) if Net.fiok != null else ""

## Böngészőben az online játék csak a meghívott fiókoknak (a szerver is ellenőrzi; itt csak szólunk előre)
func _online_tilos() -> bool:
	if Net.fiok == null or bool(Net.fiok.call("online_engedelyes")): return false
	_set_status(tr("WEB_ONLINE_INVITE_ONLY"))
	return true

func _on_szoba_nyit() -> void:
	if _online_tilos(): return
	_remember_name()
	var err := Net.host_szoba(_name_edit.text)
	_set_status(tr("MP_ROOM_OPENING") if err == OK else tr("MP_SIGNAL_FAILED"))
	_refresh()

func _on_szoba_be() -> void:
	if _online_tilos(): return
	_remember_name()
	# máshoz csatlakozik: a saját mentett hadjárata nem folytatódik
	SaveManager.mp_folytatas = ""
	var err := Net.join_szoba(_name_edit.text, _kod_edit.text)
	_set_status(tr("MP_CONNECTING") if err == OK else tr("MP_ROOM_BAD_CODE"))
	_refresh()

func _remember_name() -> void:
	if _name_edit.editable:
		GameSettings.player_name = _name_edit.text.strip_edges()
		GameSettings.save_settings()

## Új játék / csatlakozás IP-címmel és porttal (ENet, asztali gépen)
func _build_ip() -> void:
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
