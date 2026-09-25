extends Panel

# HEPTARCHIA – játékoslista többjátékos módban (a Tab lenyomva tartásáig látszik).
# Soronként: a királyság színe és a játékos neve, a nemzet, a viszony velem (színezve), a ping.
# A játékosok a Net.players-ből jönnek, a ping a Net.pings táblából (a gazdagép méri, és szétküldi).

const KnotDivider := preload("res://scripts/ui/knot_divider.gd")
const BOLD_FONT := preload("res://assets/ui/font_bold.tres")

const GOLD := Color(1.0, 0.84, 0.4)
const SZIN_HABORU := Color(1.0, 0.36, 0.28)
const SZIN_SZOVETSEG := Color(0.5, 0.92, 0.45)
const SZIN_HUBER := Color(0.78, 0.64, 1.0)
const SZIN_FEGYVERSZUNET := Color(0.6, 0.8, 1.0)
const SZIN_SEMLEGES := Color(0.82, 0.8, 0.74)
const SZIN_HALVANY := Color(0.62, 0.6, 0.56)

# oszlopszélességek (1280×720-on is elfér: 170+160+200+70 + 3×14 hézag + 2×22 margó = 686)
const SZ_NEV := 170
const SZ_NEMZET := 160
const SZ_VISZONY := 200
const SZ_PING := 70
const SOR_MAG := 24
const FRISSITES := 0.5          # látható állapotban ennyi másodpercenként frissül

var _doboz: VBoxContainer
var _cim: Label
var _racs: GridContainer
var _ido: float = 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_CENTER)
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 50
	hide()
	set_process(false)
	_doboz = VBoxContainer.new()
	_doboz.mouse_filter = MOUSE_FILTER_IGNORE
	_doboz.add_theme_constant_override("separation", 6)
	add_child(_doboz)
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_doboz.add_child(_cim)
	var csomo := KnotDivider.new()
	csomo.custom_minimum_size = Vector2(0, 14)
	csomo.mouse_filter = MOUSE_FILTER_IGNORE
	_doboz.add_child(csomo)
	_racs = GridContainer.new()
	_racs.columns = 4
	_racs.mouse_filter = MOUSE_FILTER_IGNORE
	_racs.add_theme_constant_override("h_separation", 14)
	_racs.add_theme_constant_override("v_separation", 4)
	_doboz.add_child(_racs)

# Többjátékos játékban vagyunk-e (csak ekkor van értelme a listának)
func aktiv() -> bool:
	return GameManager.is_multiplayer and Net.active

func mutat() -> void:
	_frissit()
	show()
	_ido = 0.0
	set_process(true)

func elrejt() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	_ido += delta
	if _ido >= FRISSITES:
		_ido = 0.0
		_frissit()

# A Tab-ot az _input fogja el, még a felület fókuszléptetése előtt; ha szövegmezőben
# (pl. csevegés, keresés) van a fókusz, a Tab az övé marad.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var k := event as InputEventKey
	if k.keycode != KEY_TAB: return
	if k.pressed:
		if visible:
			get_viewport().set_input_as_handled()   # az ismétlődő lenyomás se léptesse a fókuszt
			return
		if not aktiv() or k.alt_pressed or k.ctrl_pressed: return
		var fokusz := get_viewport().gui_get_focus_owner()
		if fokusz is LineEdit or fokusz is TextEdit: return
		mutat()
		get_viewport().set_input_as_handled()
	elif visible:
		elrejt()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	# Alt+Tab közben elmaradhat a felengedés: az ablak fókuszvesztésekor is eltűnik
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and visible:
		elrejt()

# A sorok sorrendje: én elöl, utána a többiek csatlakozási sorrendben
func jatekosok() -> Array:
	var en := Net.my_peer_id()
	var ids: Array = Net.players.keys()
	ids.sort_custom(func(a, b) -> bool:
		if int(a) == en: return true
		if int(b) == en: return false
		return int(a) < int(b))
	return ids

func sorok_szama() -> int:
	return floori(_racs.get_child_count() / 4.0) - 1

func _frissit() -> void:
	_cim.text = tr("MP_PLAYERS")
	for c in _racs.get_children():
		_racs.remove_child(c)
		c.queue_free()
	_fejlec(tr("MP_LISTA_NEV"), SZ_NEV + 22)
	_fejlec(tr("MP_LISTA_NEMZET"), SZ_NEMZET)
	_fejlec(tr("MP_LISTA_VISZONY"), SZ_VISZONY)
	_fejlec(tr("MP_LISTA_PING"), SZ_PING, HORIZONTAL_ALIGNMENT_RIGHT)
	var en := Net.my_peer_id()
	for id in jatekosok():
		var peer: int = int(id)
		var pl: Dictionary = Net.players[id]
		var f: int = int(pl.get("faction", -1))
		var nev: String = str(pl.get("name", "?"))
		var elo: bool = GameManager.realms.has(f) and GameManager.is_alive(f)
		var halvany := Color(1, 1, 1, 1.0 if elo else 0.55)
		# szín + név
		var nevsor := HBoxContainer.new()
		nevsor.mouse_filter = MOUSE_FILTER_IGNORE
		nevsor.add_theme_constant_override("separation", 8)
		nevsor.modulate = halvany
		var folt := ColorRect.new()
		folt.custom_minimum_size = Vector2(14, 14)
		folt.size_flags_vertical = SIZE_SHRINK_CENTER
		folt.color = GameManager.faction_color(f)
		folt.mouse_filter = MOUSE_FILTER_IGNORE
		nevsor.add_child(folt)
		var lnev := _cella(nev, SZ_NEV, GOLD if peer == en else Color(0.98, 0.94, 0.84))
		lnev.add_theme_font_override("font", BOLD_FONT)
		nevsor.add_child(lnev)
		_racs.add_child(nevsor)
		# nemzet
		var lnemz := _cella(GameManager.faction_name(f), SZ_NEMZET, GameManager.faction_color(f).lightened(0.35))
		lnemz.modulate = halvany
		_racs.add_child(lnemz)
		# viszony
		var visz: Array = viszony(f)
		var visz_szoveg: String = visz[0]
		var visz_szin: Color = visz[1]
		var lvisz := _cella(visz_szoveg, SZ_VISZONY, visz_szin)
		lvisz.modulate = halvany
		_racs.add_child(lvisz)
		# ping
		var ms: int = Net.ping_of(peer)
		var lping := _cella("—" if ms < 0 else "%d ms" % ms, SZ_PING, ping_szin(ms))
		lping.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_racs.add_child(lping)
	_meretez()

# A panel a tartalomhoz igazodik, a képernyő közepén
func _meretez() -> void:
	var m := _doboz.get_combined_minimum_size()
	var w := m.x + 44.0
	var h := m.y + 36.0
	offset_left = -w / 2.0; offset_right = w / 2.0
	offset_top = -h / 2.0; offset_bottom = h / 2.0
	_doboz.position = Vector2(22, 18)
	_doboz.size = m

func _fejlec(szoveg: String, szel: int, igazit: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l := _cella(szoveg, szel, SZIN_HALVANY)
	l.horizontal_alignment = igazit
	l.theme_type_variation = &"SmallLabel"
	_racs.add_child(l)

func _cella(szoveg: String, szel: int, szin: Color) -> Label:
	var l := Label.new()
	l.text = szoveg
	l.custom_minimum_size = Vector2(szel, SOR_MAG)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_color_override("font_color", szin)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	return l

# [szöveg, szín]: a királyság viszonya az enyémhez
func viszony(f: int) -> Array:
	var pf := GameManager.player_faction
	if f == pf: return [tr("MP_LISTA_TE"), GOLD]
	var d := GameManager.get_diplomacy(pf, f)
	var szoveg := tr("DIP_STATE_NEUTRAL")
	var szin := SZIN_SEMLEGES
	match int(d.get("state", -1)):
		GameManager.DiplomacyState.WAR:
			szoveg = tr("DIP_STATE_WAR"); szin = SZIN_HABORU
		GameManager.DiplomacyState.TRUCE:
			szoveg = Localization.t("DIP_STATE_TRUCE", [int(d.get("truce_turns", 0))]); szin = SZIN_FEGYVERSZUNET
		GameManager.DiplomacyState.ALLY:
			szoveg = tr("MP_LISTA_HAZASSAG") if d.get("marriage", false) else tr("DIP_STATE_ALLY")
			szin = SZIN_SZOVETSEG
		GameManager.DiplomacyState.VASSAL:
			szin = SZIN_HUBER
			if GameManager.is_vassal_of(f, pf): szoveg = tr("DIP_STATE_OUR_VASSAL")
			elif GameManager.is_vassal_of(pf, f): szoveg = tr("DIP_STATE_OUR_LORD")
			else: szoveg = tr("DIP_STATE_VASSAL")
	if d.get("trade", false): szoveg += " ⚖"
	return [szoveg, szin]

func ping_szin(ms: int) -> Color:
	if ms < 0: return SZIN_HALVANY
	if ms < 80: return Color(0.5, 0.92, 0.45)
	if ms < 200: return Color(1.0, 0.85, 0.35)
	return Color(1.0, 0.4, 0.32)
