extends Control

# TÖBBJÁTÉKOS – az élő csaták jelzője a térképen (a közös csatamodul része)
#   – felül középen: a most folyó élő csaták (amelyekben nem mi vezetjük az egyik oldalt), mindegyik mellett
#     „Nézem” gomb – bármikor át lehet ülni nézőnek;
#   – ha új csata indul: értesítés két gombbal – Nézem / Tovább játszom (a tartományaidat közben is
#     intézheted; a kör vége a csaták végére vár).

const ERTESITES_MP := 25.0

var _sav: VBoxContainer
var _ertesito: PanelContainer
var _ert_lbl: Label
var _ert_id: int = -1
var _ert_ido: float = 0.0
var _ismert: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_sav = VBoxContainer.new()
	_sav.add_theme_constant_override("separation", 4)
	_sav.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_sav)
	_ertesito = PanelContainer.new()
	_ertesito.visible = false
	add_child(_ertesito)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_ertesito.add_child(v)
	var cim := Label.new()
	cim.text = tr("MP_BATTLE_TITLE")
	cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cim.add_theme_font_size_override("font_size", 20)
	v.add_child(cim)
	_ert_lbl = Label.new()
	_ert_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ert_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ert_lbl.custom_minimum_size.x = 420
	v.add_child(_ert_lbl)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	var nez := Button.new()
	nez.text = tr("MP_BATTLE_WATCH")
	nez.custom_minimum_size = Vector2(150, 36)
	nez.pressed.connect(func() -> void:
		var id := _ert_id
		_ertesito.visible = false
		Net.elo_nez(id))
	h.add_child(nez)
	var tovabb := Button.new()
	tovabb.text = tr("MP_BATTLE_KEEP_PLAYING")
	tovabb.custom_minimum_size = Vector2(150, 36)
	tovabb.pressed.connect(func() -> void: _ertesito.visible = false)
	h.add_child(tovabb)
	Net.elo_lista_valtozott.connect(_frissit)
	_frissit()

func _process(delta: float) -> void:
	if _ertesito.visible:
		_ert_ido -= delta
		if _ert_ido <= 0.0: _ertesito.visible = false
	# a sáv felül középen, az értesítés alatta
	var w := get_viewport_rect().size.x
	_sav.reset_size()
	_sav.position = Vector2((w - _sav.size.x) * 0.5, 58.0)
	if _ertesito.visible:
		_ertesito.reset_size()
		_ertesito.position = Vector2((w - _ertesito.size.x) * 0.5, 64.0 + _sav.size.y)

## A csata két oldala és helye olvasható alakban
static func csata_szoveg(info: Dictionary) -> String:
	var nevek: PackedStringArray = []
	for k in ["a", "b"]:
		var f := int(info.get(k, -1))
		nevek.append(TranslationServer.translate(GameManager.faction_key(f)) if f >= 0 else TranslationServer.translate("TC_RAIDERS"))
	var hely := str(info.get("hely", ""))
	if GameManager.provinces.has(hely): hely = GameManager.province_label(hely)
	return Localization.t("MP_BATTLE_DESC", [nevek[0], nevek[1], hely])

func _frissit() -> void:
	for c in _sav.get_children(): c.queue_free()
	var pf := GameManager.player_faction
	var uj := -1
	for id in Net.elo_lista:
		var info: Dictionary = Net.elo_lista[id]
		if pf in (info.get("harcos", []) as Array): continue
		var sor := HBoxContainer.new()
		sor.add_theme_constant_override("separation", 8)
		var p := PanelContainer.new()
		p.add_child(sor)
		var l := Label.new()
		l.text = "⚔ " + Localization.t("MP_BATTLE_RUNNING", [csata_szoveg(info)])
		sor.add_child(l)
		var b := Button.new()
		b.text = tr("MP_BATTLE_WATCH")
		var cid := int(id)
		b.pressed.connect(func() -> void: Net.elo_nez(cid))
		var nezem: Variant = Net.elo_nezet
		b.disabled = nezem != null and is_instance_valid(nezem) and int((nezem as Node).get("csata_id")) == cid
		sor.add_child(b)
		_sav.add_child(p)
		if not _ismert.has(id): uj = cid
	_ismert = {}
	for id in Net.elo_lista: _ismert[id] = true
	if uj >= 0:
		_ert_id = uj
		_ert_ido = ERTESITES_MP
		_ert_lbl.text = Localization.t("MP_BATTLE_STARTED", [csata_szoveg(Net.elo_lista[uj])])
		_ertesito.visible = true
	elif _ert_id >= 0 and not Net.elo_lista.has(_ert_id):
		_ertesito.visible = false
