extends VBoxContainer
## HEPTARCHIA – a bal panel alsó fele: ORSZÁG-TÁBLA és TEENDŐK.
##
## A tanács / célok / diplomácia gombok alatt felszabadult hely kitöltése. Két rész:
##   • Ország-tábla: az uralkodó, a birtokok és a haderő számokban, plusz az, hogy
##     meddig tart ki a kincstár és az élelem (ezt a felső sáv nem mutatja).
##   • Teendők: mi maradt még hátra ebben a körben (éhínség, védtelen határ, építés,
##     toborzás, elégedetlen tanács, lejáró béke). A sorokra kattintva a térkép
##     odaugrik, a tanácsnál a tanács ablaka nyílik meg.
##
## Minden felirat a nyelvi fájlokból jön (REALM_* és TODO_* kulcsok), és semmi nem
## lóghat ki: a tábla görgethető, a sorok levágják a túl hosszú szöveget.

const TODO_MAX := 6                       # ennél több sor már kilógna a panelből
const NAME_COLOR := Color(0.82, 0.72, 0.52)
const VALUE_COLOR := Color(0.98, 0.90, 0.68)
const WARN_COLOR := Color(1.0, 0.45, 0.38)
const NOTE_COLOR := Color(0.72, 0.86, 0.62)
const LOW_TURNS := 5                      # ennyi kör alatt már figyelmeztetünk

var game: Node                            # a main_game.gd

var _title: Label
var _ruler: Label
var _grid: GridContainer
var _rows := {}                           # kulcs -> Label (az érték oszlopa)
var _supply: Label
var _todo_head: Label
var _todo_rows: Array[Button] = []

const STATS := ["provinces", "burhs", "faith", "army", "ships"]


func setup(main_game: Node, bold_font: Font) -> void:
	game = main_game
	add_theme_constant_override("separation", 2)
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE

	var knot := Control.new()
	knot.set_script(load("res://scripts/ui/knot_divider.gd"))
	knot.custom_minimum_size = Vector2(0, 14)
	add_child(knot)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", bold_font)
	_title.add_theme_font_size_override("font_size", 15)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)

	_ruler = Label.new()
	_ruler.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ruler.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ruler.add_theme_font_size_override("font_size", 12)
	_ruler.add_theme_color_override("font_color", NAME_COLOR)
	_ruler.mouse_filter = MOUSE_FILTER_PASS
	add_child(_ruler)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 1)
	_grid.mouse_filter = MOUSE_FILTER_PASS
	add_child(_grid)
	for key in STATS:
		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", NAME_COLOR)
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		name_lbl.mouse_filter = MOUSE_FILTER_PASS
		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 12)
		val_lbl.add_theme_color_override("font_color", VALUE_COLOR)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.mouse_filter = MOUSE_FILTER_PASS
		_grid.add_child(name_lbl)
		_grid.add_child(val_lbl)
		_rows[key] = [name_lbl, val_lbl]

	_supply = Label.new()
	_supply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_supply.add_theme_font_size_override("font_size", 12)
	_supply.mouse_filter = MOUSE_FILTER_PASS
	add_child(_supply)

	_todo_head = Label.new()
	_todo_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_todo_head.add_theme_font_override("font", bold_font)
	_todo_head.add_theme_font_size_override("font_size", 13)
	_todo_head.add_theme_color_override("font_color", Color(0.97, 0.85, 0.53))
	add_child(_todo_head)

	for i in TODO_MAX:
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 22)
		b.add_theme_font_size_override("font_size", 12)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(_on_todo_pressed.bind(i))
		b.hide()
		add_child(b)
		_todo_rows.append(b)


# ── Frissítés ────────────────────────────────────────────────

func refresh() -> void:
	if game == null or not GameManager.realms.has(GameManager.player_faction): return
	var pf: int = GameManager.player_faction
	GameManager.acting_faction = pf
	_refresh_table(pf)
	_refresh_todo(pf)


func _refresh_table(pf: int) -> void:
	_title.text = GameManager.faction_name(pf)
	_title.add_theme_color_override("font_color", GameManager.faction_color(pf).lightened(0.35))
	var ruler := GameManager.historical_ruler(pf, GameManager.current_year)
	_ruler.text = tr(ruler) if ruler != "" else ""
	_ruler.tooltip_text = tr("REALM_RULER_TIP")

	var own: Array = GameManager.get_faction_provinces(pf)
	var fyrd := 0
	var thegn := 0
	var ships := 0
	var pop := 0
	var burhs := 0
	var faith := 0                      # templomszintek (óészakiaknál hof-szintek) összege
	var norse: bool = GameManager.is_norse(pf)
	for pname in own:
		var p: Dictionary = GameManager.provinces[pname]
		fyrd += int(p["fyrd"]); thegn += int(p["thegn"]); ships += int(p["ships"])
		pop += int(p["population"])
		if p["has_burh"]: burhs += 1
		faith += int(p["hof"] if norse else p["church"])
	# az úton lévő seregek is a királyságé
	for m in GameManager.marches:
		if int(m.get("faction", -1)) != pf: continue
		fyrd += int(m.get("fyrd", 0)); thegn += int(m.get("thegn", 0)); ships += int(m.get("ships", 0))

	_set_row("provinces", tr("REALM_PROVINCES"), str(own.size()), Localization.t("REALM_PROVINCES_TIP", [pop]))
	_set_row("burhs", tr("REALM_BURHS"), str(burhs), tr("REALM_BURHS_TIP"))
	_set_row("faith", tr("REALM_HOFS" if norse else "REALM_CHURCHES"), str(faith),
		tr("REALM_HOFS_TIP" if norse else "REALM_CHURCHES_TIP"))
	var strength: int = GameManager._faction_total_strength(pf)
	_set_row("army", tr("REALM_ARMY"), str(strength), Localization.t("REALM_ARMY_TIP", [fyrd, thegn, _rank_text(pf)]))
	_set_row("ships", tr("REALM_SHIPS"), str(ships), tr("REALM_SHIPS_TIP"))
	# a hajók sora csak annak látszik, akinek van kikötője vagy hajója (a szárazföldieknek felesleges)
	var show_ships := ships > 0 or GameManager._own_count("has_port") > 0
	for l in _rows["ships"]:
		l.visible = show_ships

	# meddig tart ki a kincstár és az éléskamra
	var inc: Dictionary = GameManager.get_income()
	var parts: PackedStringArray = []
	var warn := false
	for r in ["food", "silver"]:
		var delta := int(inc[r])
		if delta >= 0: continue
		var turns: int = int(floor(float(GameManager.get(r)) / float(-delta)))
		parts.append(Localization.t("REALM_LASTS", ["REALM_RES_" + r.to_upper(), turns]))
		if turns <= LOW_TURNS: warn = true
	if parts.is_empty():
		_supply.text = tr("REALM_SURPLUS")
		_supply.add_theme_color_override("font_color", NOTE_COLOR)
	else:
		_supply.text = "\n".join(parts)
		_supply.add_theme_color_override("font_color", WARN_COLOR if warn else NAME_COLOR)
	var up: Dictionary = GameManager.army_upkeep()
	_supply.tooltip_text = Localization.t("REALM_SUPPLY_TIP", [up["food"], up["silver"]])


func _set_row(key: String, name_text: String, value: String, tip: String) -> void:
	var pair: Array = _rows[key]
	pair[0].text = name_text
	pair[1].text = value
	pair[0].tooltip_text = tip
	pair[1].tooltip_text = tip


## Hányadik a játékos a sziget erősorrendjében
func _rank_text(pf: int) -> String:
	var list: Array = []
	for f in GameManager.ALL_FACTIONS:
		if GameManager.is_alive(f): list.append([GameManager._faction_total_strength(f), f])
	list.sort_custom(func(a, b): return a[0] > b[0])
	for i in list.size():
		if int(list[i][1]) == pf: return Localization.t("REALM_RANK", [i + 1, list.size()])
	return ""


# ── Teendők ─────────────────────────────────────────────────

## Egy teendő: {"text": String, "color": Color, "tip": String, "province": String, "popup": bool}
func _collect_todo(pf: int) -> Array:
	var list: Array = []
	if GameManager.game_state != "playing": return list
	var inc: Dictionary = GameManager.get_income()
	for r in ["food", "silver"]:
		var delta := int(inc[r])
		if delta >= 0: continue
		var turns: int = int(floor(float(GameManager.get(r)) / float(-delta)))
		if turns > LOW_TURNS: continue
		list.append({"text": Localization.t("TODO_RUNNING_OUT", ["REALM_RES_" + r.to_upper(), turns]),
			"tip": tr("TODO_RUNNING_OUT_TIP"), "color": WARN_COLOR, "province": "", "popup": ""})

	var own: Array = GameManager.get_faction_provinces(pf)
	# védtelen határvidék (csak ha van kivel háborúzni a szomszédban)
	for pname in own:
		if not GameManager.is_border_province(pname): continue
		var p: Dictionary = GameManager.provinces[pname]
		if int(p["fyrd"]) > 0 or int(p["thegn"]) > 0: continue
		var danger := false
		for f in GameManager.ALL_FACTIONS:
			if f != pf and GameManager.is_alive(f) and GameManager.is_at_war(pf, f): danger = true
		if not danger: continue
		list.append({"text": Localization.t("TODO_UNDEFENDED", [GameManager.province_label(pname)]),
			"tip": tr("TODO_UNDEFENDED_TIP"), "color": WARN_COLOR, "province": pname, "popup": ""})
		break

	# amit most meg lehet építeni / toborozni (a legolcsóbb kezd, hogy tényleg elérhető legyen)
	var build: Array = []
	var recruit := ""
	for pname in own:
		for kind in game.actions:
			if GameManager.action_block_reason(pname, kind) != "": continue
			if kind in ["fyrd", "thegn"]:
				if recruit == "": recruit = pname
				continue
			var c: Dictionary = GameManager.action_cost(pname, kind)
			var sum := 0
			for r in c: sum += int(c[r])
			build.append([sum, kind, pname])
	build.sort_custom(func(a, b): return a[0] < b[0])
	for i in mini(build.size(), 2):
		var kind: String = build[i][1]
		var pname: String = build[i][2]
		var label: String = Localization.tc(GameManager.level_key(kind, int(GameManager.provinces[pname].get(kind, 0)) + 1)) \
			if kind in GameManager.LEVELED else Localization.tc("ACT_" + kind.to_upper())
		list.append({"text": Localization.t("TODO_BUILD", [label, GameManager.province_label(pname)]),
			"tip": tr("TODO_BUILD_TIP"), "color": VALUE_COLOR, "province": pname, "popup": ""})
	if recruit != "":
		list.append({"text": Localization.t("TODO_RECRUIT", [GameManager.province_label(recruit)]),
			"tip": tr("TODO_RECRUIT_TIP"), "color": VALUE_COLOR, "province": recruit, "popup": ""})

	# elégedetlen tanács (van rá ezüstöd)
	if GameManager.witan_average_opinion() < 40.0 and GameManager.silver >= 20:
		list.append({"text": Localization.t("TODO_WITAN", [roundi(GameManager.witan_average_opinion())]),
			"tip": tr("TODO_WITAN_TIP"), "color": VALUE_COLOR, "province": "", "popup": "witan"})

	# hamarosan lejáró fegyverszünet
	for f in GameManager.ALL_FACTIONS:
		if f == pf or not GameManager.is_alive(f): continue
		var d: Dictionary = GameManager.get_diplomacy(pf, f)
		if d.is_empty() or int(d.get("state", -1)) != GameManager.DiplomacyState.TRUCE: continue
		var left := int(d.get("truce_turns", 0))
		if left <= 0 or left > 2: continue
		list.append({"text": Localization.t("TODO_TRUCE", [GameManager.faction_key(f), {"dur": left}]),
			"tip": tr("TODO_TRUCE_TIP"), "color": NAME_COLOR, "province": "", "popup": "dip"})
	return list


func _refresh_todo(pf: int) -> void:
	_todo_head.text = tr("TODO_TITLE")
	var list := _collect_todo(pf)
	if list.is_empty():
		list.append({"text": tr("TODO_ALL_DONE"), "tip": "", "color": NOTE_COLOR, "province": "", "popup": ""})
	for i in _todo_rows.size():
		var b: Button = _todo_rows[i]
		if i >= list.size():
			b.hide()
			b.set_meta("province", "")
			b.set_meta("popup", "")
			continue
		var item: Dictionary = list[i]
		b.text = str(item["text"])
		b.tooltip_text = str(item["tip"])
		b.add_theme_color_override("font_color", item["color"])
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		b.set_meta("province", str(item["province"]))
		b.set_meta("popup", str(item["popup"]))
		b.mouse_default_cursor_shape = CURSOR_POINTING_HAND if (item["province"] != "" or item["popup"] != "") \
			else CURSOR_ARROW
		b.show()


func _on_todo_pressed(i: int) -> void:
	if game == null or i >= _todo_rows.size(): return
	var b: Button = _todo_rows[i]
	var pname := str(b.get_meta("province", ""))
	var popup := str(b.get_meta("popup", ""))
	if pname != "":
		game.select_province(pname)
	elif popup == "witan":
		game._open_popup(game.witan_popup)
	elif popup == "dip":
		game._open_popup(game.diplist_popup)
