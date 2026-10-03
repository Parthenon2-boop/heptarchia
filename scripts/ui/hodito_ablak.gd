extends VBoxContainer

# A MEGHÓDÍTOTT VÁROS SORSA (1.81): a roham vagy a megadás után a hódító dönt – kifosztás, megtorlás vagy
# megszállás. Minden lehetőségnél a tényleges számok állnak (GameManager.conquest_options): mennyi ezüst,
# hány lakos marad, hogyan változik a lázadás veszélye, mi vész oda, és ki haragszik meg érte.
# A gombok a "conquest" parancsot küldik (többjátékosban a gazdagépen dől el). A MainGame egy középre
# nyíló ablakba (popup) teszi.

signal valasztott(target: String, choice: String)

const SORREND := ["sack", "massacre", "occupy"]
const SZIN := {"sack": Color(1.0, 0.82, 0.35), "massacre": Color(0.92, 0.45, 0.4), "occupy": Color(0.62, 0.86, 1.0)}

var _cim: Label
var _bevezeto: Label
var _sorok: VBoxContainer
var _megjegyzes: Label
var _target := ""

func _init() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = SIZE_EXPAND_FILL
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cim)
	_bevezeto = Label.new()
	_bevezeto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bevezeto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_bevezeto)
	_sorok = VBoxContainer.new()
	_sorok.add_theme_constant_override("separation", 10)
	add_child(_sorok)
	_megjegyzes = Label.new()
	_megjegyzes.theme_type_variation = &"SmallLabel"
	_megjegyzes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_megjegyzes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_megjegyzes.modulate = Color(0.85, 0.82, 0.74)
	add_child(_megjegyzes)

## A döntés megjelenítése egy függő hódításhoz (GameManager.pending_conquest)
func mutat(gm, entry: Dictionary) -> void:
	_target = str(entry.get("target", ""))
	var opts: Dictionary = gm.conquest_options(entry)
	var p: Dictionary = gm.provinces.get(_target, {})
	_cim.text = Localization.t("CONQ_TITLE", [gm.province_label(_target)])
	var elozo := int(entry.get("from", -1))
	_bevezeto.text = Localization.t("CONQ_INTRO", [gm.province_label(_target), int(p.get("population", 0)),
		int(entry.get("unrest", 0)), gm.faction_key(elozo) if elozo >= 0 else "FACTION_UNKNOWN"])
	for c in _sorok.get_children():
		_sorok.remove_child(c)
		c.queue_free()
	var idegen: bool = int(p.get("core", -1)) != int(p.get("faction", -1))
	for c in SORREND:
		if not opts.has(c): continue
		var o: Dictionary = opts[c]
		var doboz := VBoxContainer.new()
		doboz.add_theme_constant_override("separation", 2)
		_sorok.add_child(doboz)
		var gomb := Button.new()
		gomb.text = tr("CONQ_%s_BTN" % c.to_upper())
		gomb.custom_minimum_size = Vector2(0, 38)
		gomb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for k in ["font_color", "font_hover_color", "font_focus_color"]:
			gomb.add_theme_color_override(k, SZIN[c])
		gomb.tooltip_text = tr("CONQ_%s_DESC" % c.to_upper())
		gomb.pressed.connect(func(): valasztott.emit(_target, c))
		gomb.name = "gomb_" + c
		doboz.add_child(gomb)
		var leiras := Label.new()
		leiras.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		leiras.add_theme_font_size_override("font_size", 14)
		leiras.text = _reszletek(gm, c, o, idegen)
		doboz.add_child(leiras)
	_megjegyzes.text = tr("CONQ_NOTE")

func _reszletek(gm, c: String, o: Dictionary, idegen: bool) -> String:
	var sorok: Array = [tr("CONQ_%s_DESC" % c.to_upper())]
	var adat: Array = [Localization.t("CONQ_SILVER", [int(o["silver"])]),
		Localization.t("CONQ_POP", [int(o["pop_before"]), int(o["pop_after"]), int(o["pop_loss"])])]
	sorok.append(" · ".join(adat))
	var kockazat := Localization.t("CONQ_RISK", [int(o["unrest_before"]), int(o["unrest"])])
	if idegen:
		kockazat += " " + Localization.t("CONQ_RISK_CHANCE", [roundi(gm.revolt_chance_for(int(o["unrest"])) * 100.0)])
	sorok.append(kockazat)
	var trend := int(o["trend"])
	if trend > 0: sorok.append(Localization.t("CONQ_TREND_UP", [trend, int(o["turns"])]))
	elif trend < 0: sorok.append(Localization.t("CONQ_TREND_DOWN", [-trend, int(o["turns"])]))
	if str(o.get("damage", "")) != "": sorok.append(Localization.t("CONQ_DAMAGE", [str(o["damage"])]))
	if c == "massacre":
		var rokon := 0
		for f in gm.ALL_FACTIONS:
			if f != gm.player_faction and gm.is_alive(f) and gm.culture_of(f) == str(o.get("grudge", "")): rokon += 1
		sorok.append(Localization.t("CONQ_GRUDGE", [rokon, gm.CONQ_MASSACRE_DIPMOD, gm.CONQ_MASSACRE_GRUDGE_TURNS,
			-gm.CONQ_MASSACRE_STABILITY]))
	return "\n".join(sorok)
