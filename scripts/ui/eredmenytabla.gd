extends RefCounted

# HEPTARCHIA – az Eredménytábla ablak tartalma (1.74)
#
# Minden élő nép (és a már kiesett emberi játékosok) a pontszámuk szerint sorban:
# helyezés, nép, és a pontszám tételei – Föld, Nép, Fejlettség, Kincstár, Haderő,
# Dicsőség, Összesen. A pontozás a GameManager.realm_score-ban van (ott a leírása is).
# A te néped aranyszínű, a többi emberi játékos (többjátékosban) világoskék és „(játékos)”
# jelet kap; a kiesett nép halvány.

const BOLD_FONT := preload("res://assets/ui/font_bold.tres")
const ARANY := Color(1.0, 0.84, 0.4)
const JATEKOS := Color(0.62, 0.84, 1.0)
const ALAP := Color(0.96, 0.92, 0.82)
const HALV := Color(0.66, 0.62, 0.56)

## A pontszám tételei a táblázat oszlopaiban (nyelvi kulcs, realm_score mező)
const OSZLOPOK := [["SCORE_COL_LAND", "land"], ["SCORE_COL_PEOPLE", "people"], ["SCORE_COL_BUILD", "build"],
	["SCORE_COL_TREASURY", "treasury"], ["SCORE_COL_ARMY", "army"], ["SCORE_COL_GLORY", "glory"],
	["SCORE_COL_TOTAL", "total"]]

## Felépíti a tartalmat a `box`-ba; a görgetőt adja vissza. `max_sor`: legfeljebb ennyi nép
## (a te néped és az emberi játékosok akkor is látszanak, ha lejjebb vannak)
static func epit(box: VBoxContainer, max_sor: int = 60) -> ScrollContainer:
	var cim := Label.new()
	cim.name = "EredmenyCim"
	cim.theme_type_variation = &"HeaderLabel"
	cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cim.text = TranslationServer.translate("SCORE_TITLE")
	box.add_child(cim)
	var tabla := GameManager.scoreboard()
	var pf := GameManager.player_faction
	var al := Label.new()
	al.name = "EredmenyAlcim"
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	al.add_theme_font_size_override("font_size", 14)
	al.add_theme_color_override("font_color", ARANY)
	var hely := 0
	for i in tabla.size():
		if int(tabla[i]["faction"]) == pf: hely = i + 1
	al.text = Localization.t("SCORE_YOUR_RANK", [hely, tabla.size(), GameManager.current_year]) if hely > 0 \
		else Localization.t("SCORE_COUNT", [tabla.size(), GameManager.current_year])
	box.add_child(al)
	var magyar := Label.new()
	magyar.name = "EredmenyMagyarazat"
	magyar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magyar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	magyar.theme_type_variation = &"SmallLabel"
	magyar.add_theme_font_size_override("font_size", 12)
	magyar.modulate = Color(1, 1, 1, 0.75)
	magyar.text = TranslationServer.translate("SCORE_HOW")
	box.add_child(magyar)

	var gorgeto := ScrollContainer.new()
	gorgeto.name = "EredmenyGorgeto"
	gorgeto.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	gorgeto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gorgeto.custom_minimum_size = Vector2(0, 360)
	box.add_child(gorgeto)
	var racs := GridContainer.new()
	racs.name = "EredmenyRacs"
	racs.columns = 2 + OSZLOPOK.size()
	racs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	racs.add_theme_constant_override("h_separation", 12)
	racs.add_theme_constant_override("v_separation", 3)
	gorgeto.add_child(racs)
	# fejléc
	racs.add_child(_cella("#", HALV, 28, true))
	racs.add_child(_cella(TranslationServer.translate("SCORE_COL_REALM"), HALV, 220, false))
	for o in OSZLOPOK:
		var l := _cella(TranslationServer.translate(str(o[0])), HALV, 62, true)
		l.tooltip_text = TranslationServer.translate(str(o[0]) + "_TIP")
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		racs.add_child(l)
	var db := 0
	for i in tabla.size():
		var sor: Dictionary = tabla[i]
		var f := int(sor["faction"])
		var ember: bool = sor["human"]
		if db >= max_sor and f != pf and not ember: continue
		db += 1
		var sz: Dictionary = sor["score"]
		var szin := ARANY if f == pf else (JATEKOS if ember else ALAP)
		var nev := GameManager.faction_name(f)
		if ember and f != pf and GameManager.is_multiplayer: nev += " " + TranslationServer.translate("SCORE_PLAYER_TAG")
		if not bool(sor["alive"]): nev += " " + TranslationServer.translate("SCORE_FALLEN_TAG")
		var halvany := 1.0 if bool(sor["alive"]) else 0.55
		var h := _cella(str(i + 1) + ".", szin, 28, true)
		h.modulate.a = halvany
		racs.add_child(h)
		var nevsor := HBoxContainer.new()
		nevsor.add_theme_constant_override("separation", 6)
		nevsor.modulate.a = halvany
		var folt := ColorRect.new()
		folt.custom_minimum_size = Vector2(12, 12)
		folt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		folt.color = GameManager.faction_color(f)
		nevsor.add_child(folt)
		var ln := _cella(nev, szin, 202, false)
		if f == pf or ember: ln.add_theme_font_override("font", BOLD_FONT)
		nevsor.add_child(ln)
		nevsor.set_meta("eredmeny_nep", f)
		racs.add_child(nevsor)
		for o in OSZLOPOK:
			var c := _cella(str(int(sz[str(o[1])])), szin if str(o[1]) == "total" else (szin if f == pf else ALAP), 62, true)
			if str(o[1]) == "total": c.add_theme_font_override("font", BOLD_FONT)
			c.modulate.a = halvany
			racs.add_child(c)
	return gorgeto

static func _cella(szoveg: String, szin: Color, szel: int, jobbra: bool) -> Label:
	var l := Label.new()
	l.text = szoveg
	l.custom_minimum_size = Vector2(szel, 22)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if jobbra else HORIZONTAL_ALIGNMENT_LEFT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", szin)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
