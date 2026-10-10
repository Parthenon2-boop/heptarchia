extends VBoxContainer

# A HADVEZÉREK ablaka (scripts/hadvezer.gd): a saját vezérek arcképpel, csillagokkal, jelleggel, vonásokkal, korral,
# hírnévvel, hűséggel és tartózkodási hellyel; gombok: áthelyezés, jutalom, cím, leváltás, új vezér kinevezése.
# Alatta a foglyaink (váltságdíj, szabadon engedés, kivégzés, átcsábítás), a fogságban lévő vezéreink (a kért
# váltságdíj kifizetése / elutasítása) és az ajánlkozó zsoldosvezérek (felfogadás).
# Minden lépés a "hadvezer" parancsot kéri (keres jel); a MainGame küldi el (többjátékosban a gazdagépen dől el).
# A lista görgethető, a jobb szélén hely marad a görgetősávnak (kis képernyőn se lógjon a szövegre).

signal keres(args: Dictionary)
signal bezar

const RulerPortrait := preload("res://scripts/ui/ruler_portrait.gd")
const ARANY := Color(0.98, 0.86, 0.5)
const HALVANY := Color(0.85, 0.82, 0.74)
const PIROS := Color(1.0, 0.5, 0.42)
const ZOLD := Color(0.62, 0.86, 0.62)
const PORTRE := 62.0
const MAX_CEL := 60

var _cim: Label
var _lista: VBoxContainer
var _gomb_vissza: Button
var _gomb_bezar: Button
var _athelyez := -1            # annak a vezérnek az azonosítója, akinek célt választunk (-1: a lista látszik)

func _init() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = SIZE_EXPAND_FILL
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cim.mouse_filter = MOUSE_FILTER_PASS
	add_child(_cim)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# a jobb szélen hely a görgetősávnak
	var margo := MarginContainer.new()
	margo.size_flags_horizontal = SIZE_EXPAND_FILL
	margo.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margo)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	margo.add_child(_lista)
	var gombok := HBoxContainer.new()
	gombok.add_theme_constant_override("separation", 8)
	add_child(gombok)
	_gomb_vissza = Button.new()
	_gomb_vissza.name = "megse"
	_gomb_vissza.custom_minimum_size = Vector2(0, 38)
	_gomb_vissza.size_flags_horizontal = SIZE_EXPAND_FILL
	_gomb_vissza.pressed.connect(func():
		_athelyez = -1
		frissit())
	gombok.add_child(_gomb_vissza)
	_gomb_bezar = Button.new()
	_gomb_bezar.name = "zar"
	_gomb_bezar.custom_minimum_size = Vector2(0, 38)
	_gomb_bezar.size_flags_horizontal = SIZE_EXPAND_FILL
	_gomb_bezar.pressed.connect(func(): bezar.emit())
	gombok.add_child(_gomb_bezar)

func megnyit() -> void:
	_athelyez = -1
	frissit()

func _cimke(szoveg: String, meret: int, szin := Color(0, 0, 0, 0), tipp := "") -> Label:
	var l := Label.new()
	l.text = szoveg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", meret)
	if szin.a > 0.0: l.add_theme_color_override("font_color", szin)
	l.mouse_filter = MOUSE_FILTER_PASS
	l.tooltip_text = tipp
	return l

func _gomb(szoveg: String, tipp: String, args: Dictionary, tiltva := false) -> Button:
	var b := Button.new()
	b.text = szoveg
	b.tooltip_text = tipp
	b.disabled = tiltva
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 30)
	b.pressed.connect(func(): keres.emit(args))
	return b

func _fejlec(szoveg: String) -> void:
	var sep := HSeparator.new()
	_lista.add_child(sep)
	var l := _cimke(szoveg, 15, ARANY)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lista.add_child(l)

## A vezér neve a csillagaival
static func nev(g: Dictionary) -> String:
	return "%s %s" % [TranslationServer.translate(str(g.get("nev", ""))), "★".repeat(int(g.get("szint", 1)))]

## A vezér súgója: az ismertetője (ha történelmi személy), a jelleme és a vonásai tételesen
static func sugo(g: Dictionary) -> String:
	var sorok: PackedStringArray = []
	var kulcs := str(g.get("kulcs", ""))
	if kulcs != "":
		var bio := TranslationServer.translate(kulcs + "_BIO")
		if str(bio) != kulcs + "_BIO": sorok.append(str(bio))
	var j := "GEN_TRAIT_" + str(g.get("jelleg", "")).to_upper()
	sorok.append(Localization.t("HV_KEPESSEG_TIP", [int(g.get("szint", 1)) * 5, j + "_DESC"]))
	for v in g.get("vonasok", []):
		var vk := "HV_VONAS_" + str(v).to_upper()
		sorok.append("• %s: %s" % [TranslationServer.translate(vk), TranslationServer.translate(vk + "_DESC")])
	return "\n".join(sorok)

func _portre(g: Dictionary, f: int) -> Control:
	var gm = GameManager
	var p := RulerPortrait.new()
	p.custom_minimum_size = Vector2(PORTRE, PORTRE)
	p.size_flags_vertical = SIZE_SHRINK_BEGIN
	p.mouse_filter = MOUSE_FILTER_PASS
	p.csak_sajat_kep = true
	var kulcs := str(g.get("kulcs", ""))
	p.beallit(kulcs if kulcs != "" else "GEN_%s_%d" % [str(g.get("nev", "")), int(g.get("id", 0))],
		gm.culture_of(f), gm.faction_color(f), gm.current_year)
	p.tooltip_text = sugo(g)
	return p

# a név, a jelleg és a vonások egy vezérről (a saját vezér, a fogoly és a zsoldos sorában is)
func _adatok(g: Dictionary, doboz: VBoxContainer, elso_sor: String) -> void:
	var gm = GameManager
	var n := _cimke(elso_sor, 15, ARANY, sugo(g))
	doboz.add_child(n)
	var reszek: PackedStringArray = [tr("GEN_TRAIT_" + str(g.get("jelleg", "")).to_upper())]
	for v in g.get("vonasok", []): reszek.append(tr("HV_VONAS_" + str(v).to_upper()))
	reszek.append(Localization.t("HV_SOR_KOR", [gm.Hv.kor(gm, g)]))
	doboz.add_child(_cimke(" · ".join(reszek), 13, HALVANY, sugo(g)))

func frissit() -> void:
	var gm = GameManager
	var Hv = gm.Hv
	var pf: int = gm.player_faction
	if not gm.realms.has(pf): return
	gm.acting_faction = pf
	for c in _lista.get_children():
		_lista.remove_child(c)
		c.queue_free()
	_gomb_bezar.text = tr("DIP_BTN_CLOSE")
	_gomb_vissza.text = tr("HV_MEGSE")
	_gomb_vissza.visible = _athelyez >= 0
	var l: Array = Hv.lista(gm, pf)
	_cim.text = Localization.t("HV_ABLAK_CIM", [l.size(), Hv.keret(gm, pf)])
	_cim.tooltip_text = tr("HV_ABLAK_KERET_TIP")
	var ezust := int(gm.realms[pf]["silver"])
	if _athelyez >= 0:
		_celok(Hv.keres(gm, pf, _athelyez))
		return
	if l.is_empty(): _lista.add_child(_cimke(tr("HV_ABLAK_NINCS"), 14, HALVANY))
	var most := int(gm.turn_index())
	for g in l:
		var sor := HBoxContainer.new()
		sor.add_theme_constant_override("separation", 10)
		_lista.add_child(sor)
		sor.add_child(_portre(g, pf))
		var d := VBoxContainer.new()
		d.size_flags_horizontal = SIZE_EXPAND_FILL
		d.add_theme_constant_override("separation", 1)
		sor.add_child(d)
		_adatok(g, d, nev(g))
		# hírnév, hűség (a súgóban, hogy merre tart és miért), hol van
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		d.add_child(h)
		var hir := _cimke(Localization.t("HV_HIRNEV", [int(g.get("hirnev", 0))]), 13, Color(0, 0, 0, 0),
			tr("HV_HIRNEV_TIP") + "\n" + Localization.t("HV_GYOZELMEK", [int(g.get("gyoz", 0)), gm.Csata.GENERAL_WINS_TO_RISE]))
		hir.size_flags_horizontal = SIZE_SHRINK_BEGIN
		hir.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(hir)
		var hus := int(g.get("huseg", 0))
		var cel: Dictionary = Hv.huseg_cel(gm, pf, g)
		var tip: PackedStringArray = []
		if not g.get("zs", false):
			tip.append(Localization.t("HV_HUSEG_TIP", [int(cel["cel"])]))
			for t in cel["tetelek"]: tip.append("  " + Localization.t("HV_HUSEG_TETEL", [str(t[0]), "%+d" % int(t[1])]))
		tip.append(Localization.t("HV_HUSEG_VESZELY", [Hv.HUSEG_FIGYELMEZTET, Hv.HUSEG_VESZELY]))
		var hl := _cimke(Localization.t("HV_HUSEG", [hus]), 13,
			PIROS if hus < Hv.HUSEG_FIGYELMEZTET else (ZOLD if hus >= 60 else Color(0, 0, 0, 0)), "\n".join(tip))
		hl.size_flags_horizontal = SIZE_SHRINK_BEGIN
		hl.autowrap_mode = TextServer.AUTOWRAP_OFF
		h.add_child(hl)
		var hol := str(g.get("hol", ""))
		var ut: Dictionary = g.get("ut", {})
		var holsz := gm.province_label(hol) if hol != "" else tr("HV_MENETEL")
		if not ut.is_empty():
			holsz = Localization.t("HV_UTON", [gm.province_label(str(ut.get("to", ""))), {"dur": maxi(1, int(ut.get("kor", most)) - most)}])
		var hh := _cimke(Localization.t("HV_HOL", [holsz]), 13)
		hh.clip_text = true
		hh.autowrap_mode = TextServer.AUTOWRAP_OFF
		hh.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(hh)
		var jelzok: PackedStringArray = []
		if g.get("zs", false): jelzok.append(Localization.t("HV_ZSOLDOS", [int(g.get("zsold", 0))]))
		if g.get("cim", false): jelzok.append(tr("HV_CIMZETT"))
		if Hv.megrendult(gm, g): jelzok.append(Localization.t("HV_MEGRENDULT", [{"dur": int(g.get("megr", most)) - most}]))
		if not jelzok.is_empty():
			d.add_child(_cimke(" · ".join(jelzok), 12, PIROS if Hv.megrendult(gm, g) else HALVANY, tr("HV_MEGRENDULT_TIP") if Hv.megrendult(gm, g) else ""))
		var gs := HFlowContainer.new()
		gs.add_theme_constant_override("h_separation", 6)
		d.add_child(gs)
		var id := int(g.get("id", -1))
		var b := Button.new()
		b.name = "athelyez_%d" % id
		b.text = tr("HV_BTN_ATHELYEZ")
		b.tooltip_text = tr("HV_TIP_ATHELYEZ")
		b.add_theme_font_size_override("font_size", 13)
		b.custom_minimum_size = Vector2(0, 30)
		b.disabled = hol == "" or gm.get_faction_provinces(pf).size() < 2
		b.pressed.connect(func():
			_athelyez = id
			frissit())
		gs.add_child(b)
		var ja: int = Hv.jutalom_ar(g)
		gs.add_child(_gomb(Localization.t("HV_BTN_JUTALOM", [ja]),
			Localization.t("HV_TIP_JUTALOM", [ja, 8 if g.get("zs", false) else Hv.JUTALOM_HUSEG]),
			{"tett": "jutalom", "id": id}, ezust < ja or int(g.get("jut_kor", -1)) == most))
		if not g.get("zs", false):
			var ca: int = Hv.cim_ar(g)
			gs.add_child(_gomb(Localization.t("HV_BTN_CIM", [ca]), Localization.t("HV_TIP_CIM", [ca, Hv.CIM_HUSEG, Hv.CIM_TARTOS]),
				{"tett": "cim", "id": id}, ezust < ca or g.get("cim", false)))
		gs.add_child(_gomb(tr("HV_BTN_LEVALT"), tr("HV_TIP_LEVALT"), {"tett": "levalt", "id": id}))
	# új vezér kinevezése (ha van hely): a súgóban, hogy ki állna be
	if Hv.van_hely(gm, pf):
		var ar: int = Hv.kinevezes_ar(gm, pf)
		var jel: Array = Hv.jeloltek(gm, Hv.nep_kulcs(gm, pf))
		var szoveg := Localization.t("HV_BTN_KINEVEZ", [ar])
		var tipp := tr("HV_TIP_KINEVEZ")
		if not jel.is_empty():
			var s: Array = jel[0]
			szoveg = Localization.t("HV_BTN_KINEVEZ_NEV", [str(s[4]), "★".repeat(int(s[5])), ar])
			tipp += "\n" + sugo({"kulcs": str(s[4]), "szint": int(s[5]), "jelleg": str(s[6]), "vonasok": s[7]})
		var kb := _gomb(szoveg, tipp, {"tett": "kinevez"}, ezust < ar)
		kb.name = "kinevez"
		_lista.add_child(kb)
	# a foglyaink
	var fl: Array = Hv.foglyok(gm, pf)
	if not fl.is_empty():
		_fejlec(tr("HV_FOGLYOK_CIM"))
		for e in fl:
			var g: Dictionary = e["g"]
			var nf := int(e["nep"])
			var sor := HBoxContainer.new()
			sor.add_theme_constant_override("separation", 10)
			_lista.add_child(sor)
			sor.add_child(_portre(g, nf))
			var d := VBoxContainer.new()
			d.size_flags_horizontal = SIZE_EXPAND_FILL
			sor.add_child(d)
			_adatok(g, d, Localization.t("HV_FOGOLY_SOR", [str(g.get("nev", "")), "★".repeat(int(g.get("szint", 1))), gm.faction_key(nf)]))
			if int(e.get("ar", 0)) > 0: d.add_child(_cimke(Localization.t("HV_VALTSAG_KERVE", [int(e["ar"])]), 12, HALVANY))
			var gs := HFlowContainer.new()
			gs.add_theme_constant_override("h_separation", 6)
			d.add_child(gs)
			var id := int(g.get("id", -1))
			var va: int = Hv.valtsagdij(g)
			var el: bool = gm.realms.has(nf) and gm.is_alive(nf)
			gs.add_child(_gomb(Localization.t("HV_BTN_VALTSAG", [va]), Localization.t("HV_TIP_VALTSAG", [va]),
				{"tett": "valtsag", "id": id}, not el or most - int(e.get("kert", -99)) < 3))
			gs.add_child(_gomb(tr("HV_BTN_SZABADON"), tr("HV_TIP_SZABADON"), {"tett": "szabadon", "id": id}))
			gs.add_child(_gomb(tr("HV_BTN_KIVEGEZ"), tr("HV_TIP_KIVEGEZ"), {"tett": "kivegez", "id": id}))
			gs.add_child(_gomb(Localization.t("HV_BTN_ATCSABIT", [roundi(float(Hv.atcsabitas_esely(e)) * 100.0)]), tr("HV_TIP_ATCSABIT"),
				{"tett": "atcsabit", "id": id}, e.get("probalt", false) or not Hv.van_hely(gm, pf)))
	# a fogságban lévő vezéreink
	var fogva: Array = Hv.fogsagban(gm, pf)
	if not fogva.is_empty():
		_fejlec(tr("HV_FOGSAGBAN_CIM"))
		for x in fogva:
			var e: Dictionary = x["e"]
			var g: Dictionary = e["g"]
			var tf := int(x["fogva"])
			var sor := HBoxContainer.new()
			sor.add_theme_constant_override("separation", 10)
			_lista.add_child(sor)
			sor.add_child(_portre(g, pf))
			var d := VBoxContainer.new()
			d.size_flags_horizontal = SIZE_EXPAND_FILL
			sor.add_child(d)
			_adatok(g, d, Localization.t("HV_FOGSAGBAN_SOR", [str(g.get("nev", "")), "★".repeat(int(g.get("szint", 1))), gm.faction_key(tf)]))
			var ar := int(e.get("ar", 0))
			if ar <= 0:
				d.add_child(_cimke(tr("HV_FOGSAG_VAR"), 12, HALVANY))
				continue
			var gs := HFlowContainer.new()
			gs.add_theme_constant_override("h_separation", 6)
			d.add_child(gs)
			var id := int(g.get("id", -1))
			gs.add_child(_gomb(Localization.t("HV_BTN_FIZET", [ar]), "", {"tett": "valtsag_valasz", "fogva": tf, "id": id, "accept": true}, ezust < ar))
			gs.add_child(_gomb(tr("HV_BTN_ELUTASIT"), "", {"tett": "valtsag_valasz", "fogva": tf, "id": id, "accept": false}))
	# az ajánlkozó zsoldosvezérek
	var aj: Array = Hv.ajanlatok(gm, pf)
	if not aj.is_empty():
		_fejlec(tr("HV_ZSOLDOSOK_CIM"))
		for g in aj:
			var sor := HBoxContainer.new()
			sor.add_theme_constant_override("separation", 10)
			_lista.add_child(sor)
			sor.add_child(_portre(g, pf))
			var d := VBoxContainer.new()
			d.size_flags_horizontal = SIZE_EXPAND_FILL
			sor.add_child(d)
			_adatok(g, d, nev(g))
			var fa: int = Hv.foglalo(g)
			var zb := _gomb(Localization.t("HV_BTN_FELFOGAD", [fa, Hv.zsold(g)]),
				Localization.t("HV_TIP_FELFOGAD", [fa, Hv.zsold(g), Hv.zsoldos_csapat(g)]),
				{"tett": "zsoldos", "nev": str(g.get("nev", ""))}, ezust < fa or not Hv.van_hely(gm, pf))
			zb.size_flags_horizontal = SIZE_SHRINK_BEGIN
			d.add_child(zb)

# Az áthelyezés célja: a saját tartományok, elöl a legnagyobb sereggel (és hogy hány kör az út)
func _celok(g: Dictionary) -> void:
	var gm = GameManager
	var pf: int = gm.player_faction
	if g.is_empty() or str(g.get("hol", "")) == "":
		_athelyez = -1
		frissit()
		return
	var c := _cimke(Localization.t("HV_ATHELYEZ_CIM", [nev(g)]), 15, ARANY)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lista.add_child(c)
	var hol := str(g["hol"])
	var sorok: Array = []
	for pname in gm.get_faction_provinces(pf):
		if str(pname) == hol: continue
		sorok.append([int(gm.troops_of(gm.provinces[pname])), str(pname)])
	sorok.sort_custom(func(a, b): return a[0] > b[0])
	for i in mini(sorok.size(), MAX_CEL):
		var pname: String = sorok[i][1]
		var ido: int = gm.Hv.athelyezes_ido(gm, hol, pname)
		var b := Button.new()
		b.name = "cel_" + pname
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
		b.text = Localization.t("HV_ATHELYEZ_SOR", [gm.province_label(pname), {"dur": ido}, int(sorok[i][0])])
		b.pressed.connect(func():
			var id := _athelyez
			_athelyez = -1
			keres.emit({"tett": "athelyez", "id": id, "to": pname}))
		_lista.add_child(b)
