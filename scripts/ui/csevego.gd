extends Control

# HEPTARCHIA – csevegés többjátékos módban (1.73).
#
# A térkép bal alsó sarkában egy gomb („Csevegés”) és az Enter nyitja; nyitva az üzenetek
# listája (az utolsó CSEV_MAX), a címzett (Mindenki / Szövetségeseim / egy játékos), a szövegmező
# és a Küldés gomb. Zárva az új üzenetek pár másodpercig áttűnő sávban látszanak a gomb fölött.
# Az üzenet a gazdagépen át megy (Net.send_chat): az dönti el, kinek jut el – a kliens nem
# szűr, más gépére el sem jut, ami nem neki szól. Egyjátékos módban a csevegés nem látszik.
#
# Az Enter-t az _input fogja el (a felület előtt), de csak akkor, ha nincs nyitva ablak
# (a main_game ablakai az Entert maguknak kezelik: üzenet, csatajelentés, város) és nem
# szövegmezőben van a fókusz – így egy fókuszban maradt gombot (pl. Kör vége) sem nyom meg.

const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const CSEV_MAX := 50              # ennyi üzenet marad meg
const ATTUNES_IDO := 8.0          # zárva ennyi másodpercig látszik egy új üzenet
const ATTUNES_SOR := 4            # zárva legfeljebb ennyi sor
const SZEL := 440.0
const MAG := 250.0
const ARANY := Color(1.0, 0.84, 0.4)

var game: Control                 # a MainGame (az ablakok és a térkép helye miatt)
var nyitva := false
var uzenetek: Array = []          # a megkapott üzenetek (Net.chat_received)
var _friss: Array = []            # [üzenet, érkezés ideje] a zárt állapot áttűnő sávjához

var gomb: Button
var panel: PanelContainer
var tortenet: RichTextLabel
var cimzett: OptionButton
var mezo: LineEdit
var kuld: Button
var sav: RichTextLabel            # zárt állapotban az új üzenetek
var _cim: Label

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	gomb = Button.new()
	gomb.name = "CsevegoGomb"
	gomb.focus_mode = Control.FOCUS_NONE
	gomb.custom_minimum_size = Vector2(0, 30)
	gomb.add_theme_font_size_override("font_size", 14)
	gomb.pressed.connect(valt)
	add_child(gomb)

	sav = RichTextLabel.new()
	sav.name = "CsevegoSav"
	sav.bbcode_enabled = true
	sav.fit_content = true
	sav.scroll_active = false
	sav.mouse_filter = MOUSE_FILTER_IGNORE
	sav.add_theme_font_size_override("normal_font_size", 14)
	sav.add_theme_font_size_override("bold_font_size", 14)
	sav.add_theme_font_size_override("italics_font_size", 14)
	# halvány sötét alap, hogy a térkép fölött is olvasható legyen
	var alap := StyleBoxFlat.new()
	alap.bg_color = Color(0.06, 0.04, 0.02, 0.55)
	alap.set_corner_radius_all(4)
	alap.set_content_margin_all(5)
	sav.add_theme_stylebox_override("normal", alap)
	sav.add_theme_font_override("bold_font", BOLD_FONT)
	sav.add_theme_color_override("default_color", Color(0.98, 0.94, 0.84))
	sav.add_theme_constant_override("outline_size", 4)
	sav.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.02, 0.95))
	add_child(sav)

	panel = PanelContainer.new()
	panel.name = "CsevegoPanel"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.06, 0.035, 0.9)
	st.set_border_width_all(1)
	st.border_color = Color(0.62, 0.46, 0.2, 0.9)
	st.set_corner_radius_all(5)
	st.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", st)
	panel.visible = false
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var fej := HBoxContainer.new()
	box.add_child(fej)
	_cim = Label.new()
	_cim.add_theme_font_override("font", BOLD_FONT)
	_cim.add_theme_font_size_override("font_size", 15)
	_cim.add_theme_color_override("font_color", ARANY)
	_cim.size_flags_horizontal = SIZE_EXPAND_FILL
	fej.add_child(_cim)
	var zar := Button.new()
	zar.text = "×"
	zar.flat = true
	zar.focus_mode = Control.FOCUS_NONE
	zar.custom_minimum_size = Vector2(26, 22)
	zar.pressed.connect(bezar)
	fej.add_child(zar)
	tortenet = RichTextLabel.new()
	tortenet.name = "CsevegoTortenet"
	tortenet.bbcode_enabled = true
	tortenet.scroll_following = true
	tortenet.selection_enabled = true
	tortenet.size_flags_vertical = SIZE_EXPAND_FILL
	tortenet.custom_minimum_size = Vector2(0, 120)
	tortenet.add_theme_font_size_override("normal_font_size", 14)
	tortenet.add_theme_font_size_override("bold_font_size", 14)
	tortenet.add_theme_font_size_override("italics_font_size", 14)
	tortenet.add_theme_font_override("bold_font", BOLD_FONT)
	tortenet.add_theme_color_override("default_color", Color(0.95, 0.9, 0.8))
	box.add_child(tortenet)
	cimzett = OptionButton.new()
	cimzett.name = "CsevegoCimzett"
	cimzett.clip_text = true
	cimzett.focus_mode = Control.FOCUS_NONE
	cimzett.add_theme_font_size_override("font_size", 14)
	box.add_child(cimzett)
	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 6)
	box.add_child(sor)
	mezo = LineEdit.new()
	mezo.name = "CsevegoMezo"
	mezo.max_length = Net.CHAT_MAX_LEN
	mezo.size_flags_horizontal = SIZE_EXPAND_FILL
	mezo.add_theme_font_size_override("font_size", 15)
	mezo.text_submitted.connect(func(_t: String): kuldes())
	mezo.gui_input.connect(_mezo_bill)
	sor.add_child(mezo)
	kuld = Button.new()
	kuld.focus_mode = Control.FOCUS_NONE
	kuld.add_theme_font_size_override("font_size", 14)
	kuld.pressed.connect(kuldes)
	sor.add_child(kuld)

	Net.chat_received.connect(_uzenet_jott)
	Net.lobby_changed.connect(_frissit_cimzettek)
	szovegek()
	_frissit_cimzettek()
	_frissit_tortenet()
	visible = aktiv()

## Többjátékos játékban vagyunk-e (egyjátékosban nincs csevegés)
func aktiv() -> bool:
	return GameManager.is_multiplayer and Net.active

func szovegek() -> void:
	gomb.text = "💬 " + tr("CHAT_BUTTON")
	gomb.tooltip_text = tr("CHAT_BUTTON_TIP")
	_cim.text = tr("CHAT_TITLE")
	mezo.placeholder_text = Localization.t("CHAT_PLACEHOLDER", [Net.CHAT_MAX_LEN])
	kuld.text = tr("CHAT_SEND")
	_frissit_cimzettek()

func valt() -> void:
	if nyitva: bezar()
	else: nyit()

func nyit() -> void:
	if not aktiv(): return
	nyitva = true
	_frissit_cimzettek()
	panel.visible = true
	sav.visible = false
	_frissit_tortenet()
	_igazit()
	mezo.grab_focus()

func bezar() -> void:
	nyitva = false
	panel.visible = false
	if mezo.has_focus(): mezo.release_focus()
	_igazit()

func _mezo_bill(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		bezar()
		mezo.accept_event()

## Van-e nyitott ablak a játékban (akkor az Enter az ablaké)
func _ablak_nyitva() -> bool:
	if game == null: return false
	var d = game.get("dim")
	return d is Control and (d as Control).visible

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not visible: return
	var k := event as InputEventKey
	if not k.pressed or k.echo: return
	if k.keycode != KEY_ENTER and k.keycode != KEY_KP_ENTER: return
	if nyitva or _ablak_nyitva(): return
	var fokusz := get_viewport().gui_get_focus_owner()
	if fokusz is LineEdit or fokusz is TextEdit: return
	nyit()
	get_viewport().set_input_as_handled()

## A címzettek: Mindenki, Szövetségeseim, és a többi játékos egyenként
func _frissit_cimzettek() -> void:
	if cimzett == null: return
	var elozo = cimzett.get_selected_metadata() if cimzett.item_count > 0 else null
	cimzett.clear()
	cimzett.add_item(tr("CHAT_TO_ALL"))
	cimzett.set_item_metadata(0, ["all", -1])
	cimzett.add_item(tr("CHAT_TO_ALLIES"))
	cimzett.set_item_metadata(1, ["allies", -1])
	var en := Net.my_peer_id()
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		if int(id) == en: continue
		var pl: Dictionary = Net.players[id]
		var f := int(pl.get("faction", -1))
		cimzett.add_item(Localization.t("CHAT_TO_PLAYER", [str(pl.get("name", "?")), GameManager.faction_key(f)]))
		cimzett.set_item_metadata(cimzett.item_count - 1, ["private", f])
	var valaszt := 0
	for i in cimzett.item_count:
		if elozo != null and str(cimzett.get_item_metadata(i)) == str(elozo): valaszt = i
	cimzett.select(valaszt)

func kuldes() -> void:
	var s := mezo.text.strip_edges()
	if s == "":
		bezar()
		return
	var m = cimzett.get_selected_metadata()
	var kinek: Array = m if m is Array else ["all", -1]
	Net.send_chat(str(kinek[0]), int(kinek[1]), s)
	mezo.text = ""
	mezo.grab_focus()

func _uzenet_jott(msg: Dictionary) -> void:
	uzenetek.append(msg)
	while uzenetek.size() > CSEV_MAX: uzenetek.pop_front()
	_friss.append([msg, Time.get_ticks_msec() / 1000.0])
	while _friss.size() > ATTUNES_SOR: _friss.pop_front()
	_frissit_tortenet()
	if not nyitva: _frissit_sav()

## Egy üzenet egy sorban: [idő] Név (nemzet) → kinek: szöveg. A szöveg BBCode nélkül
## (a gazdagép kiszedi, és itt is kiírás előtt semlegesítjük).
func sor_szoveg(msg: Dictionary) -> String:
	if msg.has("system"):
		return "[color=#e0a070][i]%s[/i][/color]" % _esc(tr(str(msg["system"])))
	var f := int(msg.get("from", -1))
	var szin := GameManager.faction_color(f).lightened(0.35).to_html(false)
	var kinek := ""
	match str(msg.get("to", "all")):
		"allies": kinek = " [color=#8fd07a]→ %s[/color]" % _esc(tr("CHAT_TAG_ALLIES"))
		"private":
			var t := int(msg.get("target", -1))
			kinek = " [color=#c9a2ff]→ %s[/color]" % _esc(Localization.t("CHAT_TAG_PRIVATE",
				[_nev_nemzethez(t) if t != GameManager.player_faction else tr("MP_YOU")]))
	# (egy kör egy év: az évszak 1.81 óta nincs a dátumban)
	var ido := "%d · %s" % [int(msg.get("year", 0)), str(msg.get("time", ""))]
	return "[color=#9a8c74]%s[/color] [b][color=#%s]%s[/color][/b]%s: %s" % [_esc(ido), szin,
		_esc(str(msg.get("name", "?"))), kinek, _esc(str(msg.get("text", "")))]

func _nev_nemzethez(f: int) -> String:
	for id in Net.players:
		if int(Net.players[id].get("faction", -1)) == f: return str(Net.players[id].get("name", "?"))
	return GameManager.faction_name(f)

static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")

func _frissit_tortenet() -> void:
	if tortenet == null: return
	var sorok: PackedStringArray = []
	for m in uzenetek: sorok.append(sor_szoveg(m))
	if sorok.is_empty(): sorok.append("[color=#9a8c74][i]%s[/i][/color]" % _esc(tr("CHAT_EMPTY")))
	tortenet.text = "\n".join(sorok)

func _frissit_sav() -> void:
	var most := Time.get_ticks_msec() / 1000.0
	var sorok: PackedStringArray = []
	var uj: Array = []
	for e in _friss:
		if most - float(e[1]) < ATTUNES_IDO:
			uj.append(e)
			sorok.append(sor_szoveg(e[0]))
	_friss = uj
	sav.text = "\n".join(sorok)
	sav.visible = not nyitva and not sorok.is_empty()
	_igazit()

func _process(_delta: float) -> void:
	var kell := aktiv()
	if visible != kell: visible = kell
	if not kell: return
	_igazit()
	if not nyitva and not _friss.is_empty():
		var most := Time.get_ticks_msec() / 1000.0
		var legujabb := float(_friss[_friss.size() - 1][1])
		# az utolsó két másodpercben elhalványul
		sav.modulate.a = clampf((ATTUNES_IDO - (most - legujabb)) / 2.0, 0.0, 1.0)
		if most - float(_friss[0][1]) >= ATTUNES_IDO: _frissit_sav()

## A térkép bal alsó sarkához igazodik (a krónika magassága változhat)
func _igazit() -> void:
	var mv = game.get("map_view") if game != null else null
	var r := Rect2(Vector2(220, 48), Vector2(800, 520))
	if mv is Control: r = (mv as Control).get_global_rect()
	var bal := r.position.x + 14.0
	var lent := r.end.y - 12.0
	var gm := gomb.get_combined_minimum_size()
	gomb.size = gm
	gomb.position = Vector2(bal, lent - gm.y)
	var mag := minf(MAG, r.size.y - gm.y - 30.0)
	var szel := minf(SZEL, r.size.x - 28.0)
	panel.size = Vector2(szel, mag)
	panel.position = Vector2(bal, lent - gm.y - 6.0 - mag)
	sav.size = Vector2(szel, 0)
	sav.position = Vector2(bal, lent - gm.y - 6.0 - sav.get_content_height())
