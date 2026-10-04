extends VBoxContainer

# AZ URALKODÓHÁZ ablaka: a király, az örököse, a gyermekei és a testvérei, a házasságaik, és az igények
# (ahol a fiad egy fiú örökös nélküli király lányát vette el). Egy házasítható gyermek mellett a „Házasítás”
# gomb a lehetséges párokat sorolja fel (a többi udvar házasítható gyermekeit): esély, hozomány, és hogy a pár
# örökösödési igényt hoz-e. A kérés a "marriage" paranccsal megy (többjátékosban a gazdagépen dől el).
# Az adatok: scripts/dinasztia.gd (GameManager.Din). A MainGame egy középre nyíló ablakba (popup) teszi.

signal bezar

const ARANY := Color(0.98, 0.86, 0.5)
const HALVANY := Color(0.85, 0.82, 0.74)
const PIROS := Color(1.0, 0.5, 0.42)
const ZOLD := Color(0.62, 0.86, 0.62)
const MAX_JELOLT := 12

var game: Node
var _cim: Label
var _kiraly: Label
var _orokos: Label
var _scroll: ScrollContainer
var _lista: VBoxContainer
var _gomb_vissza: Button
var _gomb_bezar: Button
var _valasztott := -1          # a gyermek azonosítója, akinek párt keresünk (-1: a család látszik)

func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = SIZE_EXPAND_FILL
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cim)
	_kiraly = _cimke(15, ARANY)
	_kiraly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_kiraly)
	_orokos = _cimke(14)
	_orokos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_orokos)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 5)
	_scroll.add_child(_lista)
	var gombok := HBoxContainer.new()
	gombok.add_theme_constant_override("separation", 8)
	add_child(gombok)
	_gomb_vissza = Button.new()
	_gomb_vissza.custom_minimum_size = Vector2(0, 40)
	_gomb_vissza.size_flags_horizontal = SIZE_EXPAND_FILL
	_gomb_vissza.pressed.connect(func():
		_valasztott = -1
		frissit())
	gombok.add_child(_gomb_vissza)
	_gomb_bezar = Button.new()
	_gomb_bezar.custom_minimum_size = Vector2(0, 40)
	_gomb_bezar.size_flags_horizontal = SIZE_EXPAND_FILL
	_gomb_bezar.pressed.connect(func(): bezar.emit())
	gombok.add_child(_gomb_bezar)

func _cimke(meret: int, szin := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", meret)
	if szin.a > 0.0: l.add_theme_color_override("font_color", szin)
	l.mouse_filter = MOUSE_FILTER_PASS
	return l

func megnyit(g: Node) -> void:
	game = g
	_valasztott = -1
	frissit()

func frissit() -> void:
	if game == null: return
	var gm = GameManager
	var Din = gm.Din
	var pf: int = gm.player_faction
	gm.acting_faction = pf
	_cim.text = Localization.t("DIN_CIM", [gm.faction_key(pf)])
	_gomb_bezar.text = tr("DIP_BTN_CLOSE")
	_gomb_vissza.text = tr("DIN_VISSZA")
	_gomb_vissza.visible = _valasztott >= 0
	var nev: String = Din.kiraly_nev(gm, pf)
	_kiraly.text = Localization.t("DIN_KIRALY", [nev, Din.kiraly_kor(gm, pf)])
	var kn: Dictionary = Din.csalad(gm, pf).get("kiralyne", {})
	if not kn.is_empty() and Din.hivatkozas_el(gm, kn):
		_kiraly.text += "\n" + Localization.t("DIN_KIRALYNE", [kn.get("nev", ""), gm.faction_key(int(kn.get("f", pf)))])
	var o: Dictionary = Din.orokos(gm, pf)
	if not o.is_empty():
		_orokos.text = Localization.t("DIN_OROKOS", [Din.rovid(gm, o)])
		_orokos.add_theme_color_override("font_color", ZOLD)
	else:
		_orokos.text = tr("DIN_NINCS_OROKOS")
		_orokos.add_theme_color_override("font_color", PIROS)
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()
	if _valasztott >= 0: _jeloltek(gm, Din, pf)
	else: _csalad(gm, Din, pf)

# ── A család ────────────────────────────────────────────────────

func _csalad(gm, Din, pf: int) -> void:
	_fejlec(tr("DIN_GYEREKEK"))
	var gyerekek: Array = Din.gyermekei(gm, pf)
	if gyerekek.is_empty(): _lista.add_child(_halvany(tr("DIN_NINCS_GYEREK")))
	for gy in gyerekek: _sor(gm, Din, pf, gy)
	var testverek: Array = Din.testverei(gm, pf)
	if not testverek.is_empty():
		_fejlec(tr("DIN_TESTVEREK"))
		for gy in testverek: _sor(gm, Din, pf, gy)
	# a halottak egy sorban
	var halottak: Array = []
	for gy in Din.csalad(gm, pf).get("gyerekek", []):
		if not Din.el(gy): halottak.append(Localization.t("DIN_HALOTT", [gy["nev"], int(gy["halott"])]))
	if not halottak.is_empty(): _lista.add_child(_halvany(", ".join(halottak)))
	# igények: ahol a fiad (vagy te) egy fiú örökös nélküli király lányát vetted el
	var ig: Array = Din.igenyek(gm, pf)
	_fejlec(tr("DIN_IGENYEK"))
	if ig.is_empty(): _lista.add_child(_halvany(tr("DIN_NINCS_IGENY")))
	for i in ig:
		var l := _cimke(13, ZOLD)
		l.text = Localization.t("DIN_IGENY_SOR", [i["ferj"], i["lany"], gm.faction_key(int(i["t"])), Din.AI_OROKLES_MAX])
		_lista.add_child(l)
	_lista.add_child(_halvany(Localization.t("DIN_SZABALY", [Din.HAZASITHATO, Din.NAGYKORU])))

func _fejlec(szoveg: String) -> void:
	var l := _cimke(16, ARANY)
	l.text = szoveg
	_lista.add_child(l)

func _halvany(szoveg: String) -> Label:
	var l := _cimke(13, HALVANY)
	l.text = szoveg
	return l

func _doboz() -> HBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.13, 0.07, 0.75)
	sb.border_color = Color(0.62, 0.48, 0.25, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10; sb.content_margin_right = 10; sb.content_margin_top = 4; sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	_lista.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	return h

## Egy gyermek sora: neve, kora, állapota (örökös, kiskorú, házas – kivel), és a Házasítás gomb
func _sor(gm, Din, pf: int, gy: Dictionary) -> void:
	var h := _doboz()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var nev := _cimke(15, ARANY)
	nev.text = Din.rovid(gm, gy)
	v.add_child(nev)
	var allapot := _cimke(12, HALVANY)
	var reszek: Array = []
	if int(Din.orokos(gm, pf).get("id", -1)) == int(gy["id"]): reszek.append(tr("DIN_ALLAPOT_OROKOS"))
	var hz: Dictionary = gy.get("hazas", {})
	if not hz.is_empty():
		var hf := int(hz.get("f", -1))
		reszek.append(Localization.t("DIN_ALLAPOT_HAZAS" if Din.hivatkozas_el(gm, hz) else "DIN_ALLAPOT_OZVEGY",
			[hz.get("nev", ""), gm.faction_key(hf) if gm.realms.has(hf) else ""]))
	elif Din.kor(gm, gy) < Din.HAZASITHATO:
		reszek.append(tr("DIN_ALLAPOT_KISKORU"))
	else:
		reszek.append(tr("DIN_ALLAPOT_HAJADON" if not gy["fiu"] else "DIN_ALLAPOT_NOTLEN"))
	allapot.text = " · ".join(reszek)
	v.add_child(allapot)
	if Din.hazasithato(gm, gy):
		var b := Button.new()
		b.text = tr("DIN_HAZASITAS")
		b.custom_minimum_size = Vector2(150, 34)
		b.size_flags_vertical = SIZE_SHRINK_CENTER
		b.tooltip_text = tr("DIN_HAZASITAS_TIP_FIU" if gy["fiu"] else "DIN_HAZASITAS_TIP_LANY")
		b.disabled = not game._can_act()
		var id := int(gy["id"])
		b.pressed.connect(func():
			_valasztott = id
			frissit())
		h.add_child(b)

# ── A lehetséges párok ──────────────────────────────────────────

func _jeloltek(gm, Din, pf: int) -> void:
	var gy: Dictionary = Din.szemely(gm, pf, _valasztott)
	if not Din.hazasithato(gm, gy):
		_valasztott = -1
		frissit()
		return
	_fejlec(Localization.t("DIN_PART_KERES", [Din.rovid(gm, gy)]))
	_lista.add_child(_halvany(tr("DIN_PART_FIU_TIP" if gy["fiu"] else "DIN_PART_LANY_TIP")))
	var lehet: Array = []
	for t in gm.ALL_FACTIONS:
		if t == pf or not gm.is_alive(t) or gm.is_at_war(pf, t): continue
		for p in Din.jeloltek(gm, t, not gy["fiu"]):
			var terms := {"gyerek": int(gy["id"]), "par": int(p["id"])}
			var ember: bool = t in gm.human_factions
			var esely: float = 1.0 if ember else gm.acceptance_chance(t, float(gm.DIP_BASE["marriage"]), terms)
			var orokosno: bool = gy["fiu"] and Din.orokosno_e(gm, t, p)
			lehet.append({"t": t, "p": p, "terms": terms, "esely": esely, "orokosno": orokosno, "ember": ember})
	# az örökösnők elöl, aztán az esély szerint
	lehet.sort_custom(func(a, b):
		if bool(a["orokosno"]) != bool(b["orokosno"]): return bool(a["orokosno"])
		return float(a["esely"]) > float(b["esely"]))
	if lehet.is_empty(): _lista.add_child(_halvany(tr("DIN_NINCS_JELOLT")))
	for i in mini(lehet.size(), MAX_JELOLT):
		_jelolt_sor(gm, Din, pf, gy, lehet[i])

func _jelolt_sor(gm, Din, pf: int, gy: Dictionary, j: Dictionary) -> void:
	var t: int = j["t"]
	var p: Dictionary = j["p"]
	var h := _doboz()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var nev := _cimke(15, ARANY)
	nev.text = Localization.t("DIN_JELOLT", [Din.rovid(gm, p), gm.faction_key(t)])
	v.add_child(nev)
	var info := _cimke(12, HALVANY)
	var reszek: Array = []
	if j["orokosno"]: reszek.append(tr("DIN_JELOLT_OROKOSNO"))
	elif int(Din.orokos(gm, t).get("id", -1)) == int(p["id"]): reszek.append(tr("DIN_JELOLT_OROKOS"))
	# a hozomány: a lány udvara fizeti
	var ny: int = t if gy["fiu"] else pf
	var hoz: int = Din.hozomany(gm, ny)
	reszek.append(Localization.t("DIN_JELOLT_HOZOMANY_KAP" if gy["fiu"] else "DIN_JELOLT_HOZOMANY_AD", [hoz]))
	if Din.hit(gm, pf) != Din.hit(gm, t): reszek.append(Localization.t("DIN_JELOLT_VEGYES", [Din.VEGYES_HIT_STABILITAS]))
	reszek.append(tr("DIN_JELOLT_EMBER") if j["ember"] else Localization.t("DIN_JELOLT_ESELY", [roundi(float(j["esely"]) * 100)]))
	info.text = " · ".join(reszek)
	if j["orokosno"]: info.add_theme_color_override("font_color", ZOLD)
	v.add_child(info)
	var b := Button.new()
	b.text = Localization.t("DIN_MEGKER", [gm.PROPOSAL_COSTS["marriage"]])
	b.custom_minimum_size = Vector2(150, 34)
	b.size_flags_vertical = SIZE_SHRINK_CENTER
	var ok: String = gm._proposal_allowed("marriage", t)
	b.disabled = not game._can_act() or ok != "" or gm.proposal_made_this_turn(t)
	if gm.proposal_made_this_turn(t): b.tooltip_text = tr("REASON_ALREADY_PROPOSED")
	elif int(gm.silver) < int(gm.PROPOSAL_COSTS["marriage"]): b.tooltip_text = tr("DIN_OK_EZUST")
	var terms: Dictionary = j["terms"]
	b.pressed.connect(func():
		Net.request("marriage", {"target": t, "terms": terms})
		bezar.emit())
	h.add_child(b)
