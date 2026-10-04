extends VBoxContainer

# A KÉMABLAK: kém küldése egy idegen tartományba vagy az egész országba (lásd scripts/kemek.gd).
#   – fölül a lopakodó kém animációja (scripts/ui/kem_anim.gd);
#   – a célpont, a viszony és amit most tudunk róla (érvényes kémjelentés, a hadiköd);
#   – a két küldetés gombja az árral és az esélyével (a súgóban az esély tételesen);
#   – a kockázat (lebukás, diplomáciai harag);
#   – a küldetés után ugyanitt az eredmény: a kém jelentése a pontos létszámmal, vagy a kudarc / a lebukás.
# A gombok a "spy" parancsot kérik (keres jel); a MainGame küldi el (többjátékosban a gazdagépen dől el).

signal keres(args: Dictionary)
signal bezar

const Kemek := preload("res://scripts/kemek.gd")
const KemAnim := preload("res://scripts/ui/kem_anim.gd")
const ANIM_MIN := 1.9          # a küldetés animációja legalább eddig tart, mielőtt az eredmény megjelenik

var _gm
var _pname := ""
var _tf := -1
var _anim: Control
var _cim: Label
var _info: Label
var _gomb_prov: Button
var _gomb_realm: Button
var _kockazat: Label
var _eredmeny: Label
var _zar: Button
var _indult := -1.0            # mikor indult a küldetés (ms), -1 ha nincs folyamatban

func _init() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = SIZE_EXPAND_FILL
	_anim = KemAnim.new()
	add_child(_anim)
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cim)
	_info = _cimke(14)
	add_child(_info)
	_gomb_prov = _gomb("kem_prov", "prov")
	_gomb_realm = _gomb("kem_realm", "realm")
	_kockazat = _cimke(13, Color(0.85, 0.78, 0.66))
	add_child(_kockazat)
	_eredmeny = _cimke(15, Color(0.98, 0.9, 0.66))
	_eredmeny.visible = false
	add_child(_eredmeny)
	var hely := Control.new()
	hely.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(hely)
	_zar = Button.new()
	_zar.name = "zar"
	_zar.custom_minimum_size = Vector2(0, 38)
	_zar.pressed.connect(func(): bezar.emit())
	add_child(_zar)

func _cimke(meret: int, szin: Color = Color(0.92, 0.86, 0.74)) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", meret)
	l.add_theme_color_override("font_color", szin)
	return l

func _gomb(nev: String, mod: String) -> Button:
	var b := Button.new()
	b.name = nev
	b.custom_minimum_size = Vector2(0, 40)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func(): _indit(mod))
	add_child(b)
	return b

## Megnyitás egy idegen tartományra
func mutat(gm, pname: String) -> void:
	_gm = gm
	_pname = pname
	_tf = int(gm.provinces[pname]["faction"])
	_indult = -1.0
	_anim.set("stilus", "burh")
	_anim.call("allit", "var")
	_eredmeny.visible = false
	_frissit()

func _frissit() -> void:
	var gm = _gm
	var pf: int = gm.player_faction
	gm.acting_faction = pf
	_zar.text = tr("DIP_BTN_CLOSE")
	_cim.text = Localization.t("KEM_ABLAK_CIM", [gm.province_label(_pname), gm.faction_key(_tf)])
	var sorok: Array = []
	var kor_p := maxi(0, int(gm.realms[pf].get("kemjelentes", {}).get("p:" + _pname, 0)) - int(gm.turn_index()))
	var kor_f := Kemek.orszag_jelentes_kor(gm, pf, _tf)
	if kor_f > 0: sorok.append(Localization.t("KEM_TUDAS_ORSZAG", [gm.faction_key(_tf), {"dur": kor_f}]))
	if kor_p > 0: sorok.append(Localization.t("KEM_TUDAS_PROV", [gm.province_label(_pname), {"dur": kor_p}]))
	if sorok.is_empty():
		var lat := Kemek.latas(gm, pf, _pname)
		sorok.append(tr("KEM_TUDAS_HATAR") if lat == 1 else tr("KEM_TUDAS_SEMMI"))
	sorok.append(tr("KEM_LEIRAS"))
	_info.text = "\n".join(sorok)
	for par in [[_gomb_prov, "prov"], [_gomb_realm, "realm"]]:
		var b: Button = par[0]
		var mod: String = par[1]
		var e := Kemek.esely(gm, pf, _tf, _pname, mod)
		b.text = Localization.t("KEM_GOMB_PROV" if mod == "prov" else "KEM_GOMB_REALM",
			[gm.province_label(_pname) if mod == "prov" else gm.faction_key(_tf), Kemek.ar(mod), roundi(e * 100.0)])
		var ok := Kemek.akadaly(gm, pf, _tf, _pname, mod)
		b.disabled = ok != "" or _indult >= 0.0
		var tip: Array = [Localization.t("KEM_GOMB_TIP_" + mod.to_upper(), [{"dur": int(Kemek.ERVENY[mod])}])]
		for m in Kemek.tetelek(gm, pf, _tf, _pname, mod):
			tip.append(Localization.t("KEM_TETEL", [str(m["key"]), ("+" if int(m["value"]) > 0 else "") + str(int(m["value"]))]))
		if ok != "": tip.append(tr(ok))
		b.tooltip_text = "\n".join(tip)
	_kockazat.text = Localization.t("KEM_KOCKAZAT", [roundi(Kemek.LEBUKAS * 100.0), gm.faction_key(_tf),
		-Kemek.HARAG, {"dur": Kemek.HARAG_KOROK}])

func _indit(mod: String) -> void:
	if _indult >= 0.0: return
	_indult = Time.get_ticks_msec()
	_anim.call("allit", "uton")
	_eredmeny.visible = true
	_eredmeny.text = tr("KEM_UTON")
	_eredmeny.add_theme_color_override("font_color", Color(0.85, 0.82, 0.74))
	_gomb_prov.disabled = true
	_gomb_realm.disabled = true
	keres.emit({"target": _tf, "province": _pname, "mod": mod})

## A gazdagép válasza (a MainGame hívja): az animáció végén az eredmény
func eredmeny(result: Dictionary) -> void:
	var eltelt := (Time.get_ticks_msec() - _indult) / 1000.0 if _indult >= 0.0 else ANIM_MIN
	if eltelt < ANIM_MIN and is_inside_tree():
		await get_tree().create_timer(ANIM_MIN - eltelt).timeout
	_indult = -1.0
	var szoveg := eredmeny_szoveg(_gm, result)
	if not result.get("ok", false):
		_anim.call("allit", "kudarc")
		_eredmeny.add_theme_color_override("font_color", Color(1.0, 0.7, 0.55))
	elif result.get("siker", false):
		_anim.call("allit", "siker")
		_eredmeny.add_theme_color_override("font_color", Color(0.75, 0.95, 0.7))
		AudioManager.play_sfx_victory()
	elif result.get("lebukott", false):
		_anim.call("allit", "lebukott")
		_eredmeny.add_theme_color_override("font_color", Color(1.0, 0.5, 0.42))
		AudioManager.play_sfx_defeat()
	else:
		_anim.call("allit", "kudarc")
		_eredmeny.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	_eredmeny.visible = true
	_eredmeny.text = szoveg
	_frissit()

## Az eredmény szövege (a kémablakon kívül üzenetként is)
static func eredmeny_szoveg(gm, result: Dictionary) -> String:
	if not result.get("ok", false): return Localization.tc(str(result.get("reason", "KEM_OK_ERVENYTELEN")))
	var tf := int(result.get("target", -1))
	var mod := str(result.get("mod", "prov"))
	var pname := str(result.get("province", ""))
	if result.get("siker", false):
		var o: Dictionary = Kemek.osszesit(gm, tf, pname, mod)
		var egysegek := _tetelenkent(Localization.t("INFO_UNITS", [int(o["fyrd"]), int(o["thegn"]), int(o["ships"])]))
		if int(o["elite"]) > 0: egysegek += "\n" + Localization.t("KEM_ELIT", [int(o["elite"])])
		var dur := {"dur": int(result.get("korok", 1))}
		if mod == "prov":
			return Localization.t("KEM_SIKER_PROV", [gm.province_label(pname), int(o["harcos"]), dur]) + "\n" + egysegek
		return Localization.t("KEM_SIKER_REALM", [gm.faction_key(tf), int(o["harcos"]), gm.get_faction_provinces(tf).size(),
			int(o["menetek"]), dur]) + "\n" + egysegek
	if result.get("lebukott", false):
		return Localization.t("KEM_LEBUKOTT", [gm.faction_key(tf), -int(result.get("harag", Kemek.HARAG)),
			{"dur": int(result.get("harag_korok", Kemek.HARAG_KOROK))}])
	return Localization.t("KEM_KUDARC", [gm.faction_key(tf)])

## „Fyrd: 3   Thegn: 1   Hajó: 0” → tételenként, a nullák nélkül (mint a tartomány dobozában)
static func _tetelenkent(s: String) -> String:
	var t := PackedStringArray()
	for d in s.split("   ", false):
		var e := d.strip_edges()
		if e.ends_with(": 0"): continue
		t.append(e)
	return " · ".join(t) if not t.is_empty() else s
