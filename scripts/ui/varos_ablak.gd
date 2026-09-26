extends RefCounted

# HEPTARCHIA – a „Város tulajdonságai” ablak tartalma
#
# A jobb oldali tartomány-panelre (név, épületek sora, adatok) kattintva középen nyíló
# ablak (a keretet és a megnyitást a main_game.gd adja). Épületfajtánként egy sor: bal
# oldalt a fajta neve és állása, mellette a szintek láncolata piktogramokkal – felül az
# ikon, alatta a szint neve. A megépült szintek arany keretben, a nyíl után a következő
# fejlesztés az árával (zöld keretben), a későbbi szintek halványan.
# pl. [Kápolna] → [Kistemplom  ezüst 12] → [Templom] → …
# Idegen tartománynál csak megtekinthető: mi áll ott, ár nélkül.

const ICON_PATH := "res://assets/ui/icon_%s.png"
const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const KARTYA_W := 104.0
const IKON := 26.0
const ARANY := Color(0.97, 0.80, 0.33)
const KIEMELT := Color(1.0, 0.96, 0.82)     # a jobb panel neve, amíg az egér fölötte van
const ZOLD := Color(0.56, 0.86, 0.50)
const PIROS := Color(1.0, 0.45, 0.38)
const SZURKE := Color(0.62, 0.60, 0.56)

## A sorok: [kategória nyelvi kulcsa, épületfajták]. A szintes épületek (GameManager.LEVELED)
## egy-egy saját sort kapnak láncolattal, a többi (burh, kikötő, bánya…) egymás mellett áll.
const SOROK := [
	["VAROS_KAT_VEDELEM", ["burh", "tower"]],
	["VAROS_KAT_CHURCH", ["church"]],
	["VAROS_KAT_HOF", ["hof"]],
	["VAROS_KAT_FARM", ["farm"]],
	["VAROS_KAT_VILLAGE", ["village"]],
	["VAROS_KAT_KERESKEDELEM", ["port", "market", "mine", "mint"]],
	["VAROS_KAT_BARRACKS", ["barracks"]],
]

## A tartomány sorai adatként (a felület és a teszt is ebből dolgozik):
## [{kat, szintes, kind, elemek: [{kind, szint, nev, allapot: "kesz"|"kov"|"kesobb", ar, ok}]}]
static func sorok(pname: String) -> Array:
	var ki: Array = []
	if not GameManager.provinces.has(pname): return ki
	var p: Dictionary = GameManager.provinces[pname]
	var tulaj: int = int(p["faction"])
	var sajat: bool = tulaj == GameManager.player_faction
	var lehet: Array = GameManager.actions_for(tulaj)
	GameManager.acting_faction = GameManager.player_faction
	for s in SOROK:
		var fajtak: Array = s[1]
		var szintes: bool = fajtak.size() == 1 and fajtak[0] in GameManager.LEVELED
		var elemek: Array = []
		if szintes:
			var kind: String = fajtak[0]
			var szint: int = int(p.get(kind, 0))
			var epitheto: bool = kind in lehet
			if szint <= 0 and not epitheto: continue
			var legfelso: int = GameManager.level_max(kind)
			if kind == "church": legfelso = GameManager.church_limit(pname)
			if not epitheto: legfelso = szint
			legfelso = maxi(legfelso, szint)
			for i in range(1, legfelso + 1):
				var allapot := "kesz" if i <= szint else ("kov" if i == szint + 1 else "kesobb")
				elemek.append(_elem(pname, kind, i, Localization.tc(GameManager.level_key(kind, i)), allapot, sajat))
		else:
			for kind in fajtak:
				var megvan: bool = bool(p.get("has_" + str(kind), false))
				if not megvan and not (kind in lehet and _elerheto(pname, str(kind), p)): continue
				elemek.append(_elem(pname, str(kind), 1, Localization.tc("ACT_" + str(kind).to_upper()),
					"kesz" if megvan else "kov", sajat))
		if elemek.is_empty(): continue
		ki.append({"kat": s[0], "szintes": szintes, "kind": fajtak[0], "elemek": elemek})
	return ki

static func _elem(pname: String, kind: String, szint: int, nev: String, allapot: String, sajat: bool) -> Dictionary:
	var ar: Dictionary = {}
	var ok := ""
	if allapot == "kov" and sajat:
		ar = GameManager.action_cost(pname, kind)
		ok = GameManager.action_block_reason(pname, kind)
		if ok == "REASON_NO_RESOURCES": ok = ""   # ezt a pirosra színezett ár mutatja
	return {"kind": kind, "szint": szint, "nev": nev, "allapot": allapot, "ar": ar, "ok": ok}

## Megépülhet-e egyáltalán ebben a tartományban (a lelőhely, a víz, a határ szerint)
static func _elerheto(pname: String, kind: String, p: Dictionary) -> bool:
	match kind:
		"tower": return GameManager.is_border_province(pname)
		"port", "market": return bool(p["river"]) or bool(p["coastal"])
		"mine": return GameManager.SILVER_MINES.has(pname)
		"mint": return pname in GameManager.MINT_SITES
	return true

## Felépíti az ablak tartalmát a `box`-ba (fejléc, jelmagyarázat, görgethető sorok).
## A görgetőt adja vissza (a magasságát a hívó igazítja a képernyőhöz).
static func epit(box: VBoxContainer, pname: String) -> ScrollContainer:
	var p: Dictionary = GameManager.provinces[pname]
	var tulaj: int = int(p["faction"])
	var sajat: bool = tulaj == GameManager.player_faction
	# a nevek a tartomány népének kultúrája szerint (a dán földön hof, nem templom)
	var regi_kultura: String = Localization.culture
	var kult: String = GameManager.culture_of(tulaj)
	Localization.culture = "" if kult == "english" else kult.to_upper()
	var adat := sorok(pname)

	var cim := Label.new()
	cim.theme_type_variation = &"SmallLabel"
	cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cim.add_theme_color_override("font_color", ARANY)
	cim.text = TranslationServer.translate("VAROS_CIM")
	box.add_child(cim)
	var nev := Label.new()
	nev.theme_type_variation = &"HeaderLabel"
	nev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nev.text = GameManager.province_label(pname)
	box.add_child(nev)
	var al := Label.new()
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	al.add_theme_font_size_override("font_size", 15)
	al.add_theme_color_override("font_color", GameManager.faction_color(tulaj).lightened(0.3))
	al.text = "%s · %s" % [GameManager.faction_name(tulaj), GameManager.province_old_name(pname)]
	if not sajat: al.text += " · " + TranslationServer.translate("VAROS_IDEGEN")
	box.add_child(al)
	var jel := Label.new()
	jel.theme_type_variation = &"SmallLabel"
	jel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jel.add_theme_font_size_override("font_size", 13)
	jel.modulate = Color(1, 1, 1, 0.8)
	jel.text = TranslationServer.translate("VAROS_JELMAGYARAZAT" if sajat else "VAROS_JELMAGYARAZAT_IDEGEN")
	box.add_child(jel)
	box.add_child(HSeparator.new())

	var gorgeto := ScrollContainer.new()
	gorgeto.name = "VarosGorgeto"
	gorgeto.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gorgeto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gorgeto.custom_minimum_size = Vector2(0, minf(adat.size() * 104.0, 470.0))
	box.add_child(gorgeto)
	var lista := VBoxContainer.new()
	lista.name = "VarosSorok"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 6)
	gorgeto.add_child(lista)
	for i in adat.size():
		if i > 0:
			var vonal := ColorRect.new()
			vonal.color = Color(ARANY, 0.18)
			vonal.custom_minimum_size = Vector2(0, 1)
			vonal.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lista.add_child(vonal)
		lista.add_child(_sor(adat[i], sajat))
	Localization.culture = regi_kultura
	return gorgeto

static func _sor(s: Dictionary, sajat: bool) -> Control:
	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 10)
	sor.set_meta("varos_sor", str(s["kind"]))
	var bal := VBoxContainer.new()
	bal.custom_minimum_size = Vector2(128, 0)
	bal.alignment = BoxContainer.ALIGNMENT_CENTER
	bal.add_theme_constant_override("separation", 0)
	var kat := Label.new()
	kat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kat.custom_minimum_size = Vector2(128, 0)
	kat.add_theme_font_override("font", BOLD_FONT)
	kat.add_theme_font_size_override("font_size", 15)
	kat.text = Localization.tc(str(s["kat"]))
	bal.add_child(kat)
	var elemek: Array = s["elemek"]
	var kesz := 0
	var van_kov := false
	for e in elemek:
		if e["allapot"] == "kesz": kesz += 1
		elif e["allapot"] == "kov": van_kov = true
	var allas := Label.new()
	allas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	allas.custom_minimum_size = Vector2(128, 0)
	allas.theme_type_variation = &"SmallLabel"
	allas.add_theme_font_size_override("font_size", 13)
	if not van_kov and kesz == elemek.size():
		allas.text = TranslationServer.translate("VAROS_KESZ")
		allas.add_theme_color_override("font_color", ARANY)
	elif kesz == 0:
		allas.text = TranslationServer.translate("VAROS_NINCS")
		allas.add_theme_color_override("font_color", SZURKE)
	elif bool(s["szintes"]):
		allas.text = Localization.t("VAROS_SZINT", [kesz, elemek.size()])
	else:
		allas.text = Localization.t("VAROS_DB", [kesz, elemek.size()])
	allas.set_meta("varos_allas", true)
	bal.add_child(allas)
	sor.add_child(bal)

	var lanc := HBoxContainer.new()
	lanc.add_theme_constant_override("separation", 6 if bool(s["szintes"]) else 10)
	lanc.alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in elemek.size():
		var e: Dictionary = elemek[i]
		if i > 0 and bool(s["szintes"]):
			var nyil := Label.new()
			nyil.text = "→"
			nyil.set_meta("varos_nyil", true)
			nyil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nyil.add_theme_font_override("font", BOLD_FONT)
			nyil.add_theme_font_size_override("font_size", 22)
			# a következő fejlesztés előtti nyíl erős, a többi halványabb
			var kov: bool = e["allapot"] == "kov"
			nyil.add_theme_color_override("font_color", ZOLD if kov and sajat else Color(ARANY, 0.55 if e["allapot"] == "kesz" else 0.3))
			lanc.add_child(nyil)
		lanc.add_child(_kartya(e, sajat))
	sor.add_child(lanc)
	return sor

static func _kartya(e: Dictionary, sajat: bool) -> Control:
	var allapot: String = e["allapot"]
	var kov: bool = allapot == "kov" and sajat
	var pc := PanelContainer.new()
	pc.set_meta("varos_kartya", allapot)
	pc.custom_minimum_size = Vector2(KARTYA_W, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 4; sb.content_margin_right = 4
	sb.content_margin_top = 5; sb.content_margin_bottom = 5
	if allapot == "kesz":
		sb.bg_color = Color(0.36, 0.27, 0.10, 0.92)
		sb.border_color = ARANY
		sb.set_border_width_all(2)
	elif kov:
		sb.bg_color = Color(0.13, 0.20, 0.11, 0.92)
		sb.border_color = ZOLD
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.10, 0.09, 0.08, 0.75)
		sb.border_color = Color(SZURKE, 0.6)
		sb.set_border_width_all(1)
	pc.add_theme_stylebox_override("panel", sb)
	# a még nem elérhető (későbbi, vagy idegen földön a következő) szint halványan
	if allapot == "kesobb" or (allapot == "kov" and not sajat):
		pc.modulate = Color(1, 1, 1, 0.45)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var kind: String = e["kind"]
	if BuildingIcons.has_icon(kind):
		var ik := BuildingIcons.Icon.new(kind, IKON)
		ik.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ik)
	var nev := Label.new()
	nev.text = str(e["nev"])
	nev.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nev.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nev.custom_minimum_size = Vector2(KARTYA_W - 8.0, 0)
	nev.add_theme_font_size_override("font_size", 13)
	if allapot == "kesz": nev.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	v.add_child(nev)
	pc.tooltip_text = str(e["nev"])
	if allapot == "kesz":
		var m := Label.new()
		m.text = TranslationServer.translate("VAROS_MEGEPULT")
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.add_theme_font_size_override("font_size", 12)
		m.add_theme_color_override("font_color", ARANY)
		v.add_child(m)
	elif kov:
		var ok: String = e["ok"]
		var ar: Dictionary = e["ar"]
		if not ar.is_empty(): v.add_child(_ar_sor(ar))
		if ok != "":
			var o := Label.new()
			o.text = Localization.tc(ok)
			o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			o.custom_minimum_size = Vector2(KARTYA_W - 8.0, 0)
			o.add_theme_font_size_override("font_size", 11)
			o.add_theme_color_override("font_color", PIROS)
			v.add_child(o)
			pc.tooltip_text += "\n" + o.text
		else:
			pc.tooltip_text += "\n" + TranslationServer.translate("VAROS_KOVETKEZO")
	return pc

## Az ár erőforrásonként: ikon + szám (piros, ha nincs belőle elég)
static func _ar_sor(c: Dictionary) -> Control:
	var box := HFlowContainer.new()
	box.set_meta("varos_ar", true)
	box.alignment = FlowContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("h_separation", 4)
	box.add_theme_constant_override("v_separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in GameManager.RESOURCE_ORDER:
		if not c.has(r): continue
		var par := HBoxContainer.new()
		par.add_theme_constant_override("separation", 1)
		par.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = load(ICON_PATH % r)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(13, 13)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := Label.new()
		num.text = str(c[r])
		num.add_theme_font_size_override("font_size", 12)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var van: int = int(GameManager.get(r))
		if van < int(c[r]): num.add_theme_color_override("font_color", PIROS)
		par.add_child(icon)
		par.add_child(num)
		box.add_child(par)
	return box

## A jobb panel épületsorának végén álló kis „i” jel: jelzi, hogy a panel kattintható
class Jel extends Control:
	var kiemelt := false

	func _init() -> void:
		custom_minimum_size = Vector2(18, 18)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var k := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 1.0
		var szin := Color(1.0, 0.9, 0.5) if kiemelt else Color(0.97, 0.80, 0.33, 0.85)
		draw_circle(k, r, Color(0.18, 0.12, 0.06))
		draw_circle(k, r - 1.2, szin)
		# az „i”: egy pötty és egy szár
		var sot := Color(0.20, 0.13, 0.05)
		draw_circle(k + Vector2(0, -r * 0.45), r * 0.16, sot)
		draw_line(k + Vector2(0, -r * 0.12), k + Vector2(0, r * 0.55), sot, maxf(1.6, r * 0.28))
