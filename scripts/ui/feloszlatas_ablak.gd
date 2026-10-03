extends VBoxContainer

# CSAPATOK FELOSZLATÁSA (1.81): ha sok a katona és fogy az élelem.
#   – egy tartomány csapatai fajtánként, mennyiséggel (a hatás előre kiírva: élelem, ezüst, lakosság, védelem;
#     háborús határon figyelmeztet);
#   – az úton lévő seregek egészben;
#   – éhezéskor egy gomb: annyi egység, amennyi az élelmezés hiányát megszünteti (GameManager.famine_plan),
#     megerősítéssel.
# A gombok a "disband" parancsot kérik (kérés jel); a MainGame küldi el (többjátékosban a gazdagépen dől el).

signal keres(args: Dictionary)
signal bezar

var _gm
var _pname := ""
var _cim: Label
var _ehseg: VBoxContainer
var _tart: VBoxContainer
var _menetek: VBoxContainer
var _megerosit: HBoxContainer

func _init() -> void:
	add_theme_constant_override("separation", 8)
	size_flags_vertical = SIZE_EXPAND_FILL
	_cim = Label.new()
	_cim.theme_type_variation = &"HeaderLabel"
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_cim)
	_ehseg = VBoxContainer.new()
	_ehseg.add_theme_constant_override("separation", 4)
	add_child(_ehseg)
	_tart = VBoxContainer.new()
	_tart.add_theme_constant_override("separation", 4)
	add_child(_tart)
	_menetek = VBoxContainer.new()
	_menetek.add_theme_constant_override("separation", 4)
	add_child(_menetek)
	var zar := Button.new()
	zar.custom_minimum_size = Vector2(0, 38)
	zar.text = tr("DIP_BTN_CLOSE")
	zar.pressed.connect(func(): bezar.emit())
	zar.name = "zar"
	add_child(zar)

static func _torol(c: Node) -> void:
	for x in c.get_children():
		c.remove_child(x)
		x.queue_free()

func _cimke(szoveg: String, meret: int = 14, szin: Color = Color(0.92, 0.86, 0.74)) -> Label:
	var l := Label.new()
	l.text = szoveg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", meret)
	l.add_theme_color_override("font_color", szin)
	return l

func _nev(kind: String) -> String:
	if kind == "fyrd" or kind == "thegn": return Localization.tc("ACT_" + kind.to_upper())
	return tr(_gm.Csata.unit_key(kind))

## Megnyitás: a kijelölt (saját) tartomány csapataival, és ha éhezik az ország, az egygombos megoldással
func mutat(gm, pname: String) -> void:
	_gm = gm
	_pname = pname
	(get_node("zar") as Button).text = tr("DIP_BTN_CLOSE")
	var pf: int = gm.player_faction
	gm.acting_faction = pf
	var sajat: bool = gm.provinces.has(pname) and int(gm.provinces[pname]["faction"]) == pf
	_cim.text = Localization.t("DISBAND_TITLE", [gm.province_label(pname)]) if sajat else tr("DISBAND_TITLE_REALM")
	_epit_ehseg()
	_torol(_tart)
	if sajat: _epit_tartomany()
	_epit_menetek()

func _epit_ehseg() -> void:
	_torol(_ehseg)
	_megerosit = null
	var inc: Dictionary = _gm.get_income()
	if int(inc["food"]) >= 0: return
	var t: Dictionary = _gm.famine_plan()
	var korok := int(_gm.food) / maxi(1, -int(inc["food"]))
	_ehseg.add_child(_cimke(Localization.t("DISBAND_FAMINE_INFO", [-int(inc["food"]), int(_gm.food), korok]), 15, Color(1.0, 0.6, 0.45)))
	if int(t["units"]) <= 0:
		_ehseg.add_child(_cimke(tr("DISBAND_FAMINE_NONE")))
		return
	var sorok: Array = []
	for e in t["plan"]:
		sorok.append(Localization.t("DISBAND_PLAN_LINE", [_gm.province_label(str(e["p"])), int(e["n"]), _nev(str(e["kind"]))]))
	_ehseg.add_child(_cimke("\n".join(sorok)))
	if int(t["left"]) > 0: _ehseg.add_child(_cimke(Localization.t("DISBAND_FAMINE_LEFT", [int(t["left"])])))
	var gomb := Button.new()
	gomb.name = "ehseg_gomb"
	gomb.custom_minimum_size = Vector2(0, 40)
	gomb.text = Localization.t("DISBAND_FAMINE_BTN", [int(t["units"])])
	gomb.add_theme_color_override("font_color", Color(1.0, 0.8, 0.45))
	_ehseg.add_child(gomb)
	# megerősítés: a gomb helyén igen / mégse
	_megerosit = HBoxContainer.new()
	_megerosit.add_theme_constant_override("separation", 8)
	_megerosit.visible = false
	var kerdes := _cimke(Localization.t("DISBAND_CONFIRM", [int(t["units"])]), 14, Color(1.0, 0.85, 0.5))
	kerdes.size_flags_horizontal = SIZE_EXPAND_FILL
	_megerosit.add_child(kerdes)
	var igen := Button.new()
	igen.name = "igen"
	igen.text = tr("DISBAND_YES")
	igen.custom_minimum_size = Vector2(110, 36)
	igen.pressed.connect(func(): keres.emit({"auto": "famine"}))
	_megerosit.add_child(igen)
	var nem := Button.new()
	nem.text = tr("DISBAND_NO")
	nem.custom_minimum_size = Vector2(110, 36)
	nem.pressed.connect(func():
		_megerosit.visible = false
		gomb.visible = true)
	_megerosit.add_child(nem)
	_ehseg.add_child(_megerosit)
	gomb.pressed.connect(func():
		gomb.visible = false
		_megerosit.visible = true)
	_ehseg.add_child(HSeparator.new())

func _epit_tartomany() -> void:
	var p: Dictionary = _gm.provinces[_pname]
	var fajtak: Dictionary = _gm.disband_kinds(p)
	if fajtak.is_empty():
		_tart.add_child(_cimke(tr("DISBAND_NONE_HERE")))
		return
	_tart.add_child(_cimke(tr("DISBAND_HINT"), 13, Color(0.85, 0.82, 0.74)))
	for kind in fajtak:
		var sor := HBoxContainer.new()
		sor.add_theme_constant_override("separation", 8)
		_tart.add_child(sor)
		var nev := _cimke(Localization.t("DISBAND_ROW", [_nev(str(kind)), int(fajtak[kind])]), 15)
		nev.size_flags_horizontal = SIZE_EXPAND_FILL
		sor.add_child(nev)
		var db := SpinBox.new()
		db.min_value = 1
		db.max_value = int(fajtak[kind])
		db.value = int(fajtak[kind])
		db.custom_minimum_size = Vector2(90, 0)
		sor.add_child(db)
		var gomb := Button.new()
		gomb.text = tr("DISBAND_BTN")
		gomb.name = "gomb_" + str(kind)
		gomb.custom_minimum_size = Vector2(120, 34)
		sor.add_child(gomb)
		var hatas := _cimke("", 13, Color(0.8, 0.9, 0.75))
		_tart.add_child(hatas)
		var frissit := func(_v = 0.0):
			hatas.text = _hatas_szoveg(str(kind), int(db.value))
		db.value_changed.connect(frissit)
		frissit.call()
		gomb.pressed.connect(func(): keres.emit({"province": _pname, "kind": str(kind), "n": int(db.value)}))

func _hatas_szoveg(kind: String, n: int) -> String:
	var h: Dictionary = _gm.disband_effect(_pname, kind, n)
	var s := Localization.t("DISBAND_EFFECT", [int(h["food"]), int(h["silver"]), int(h["pop"]), int(h["defense"])])
	if bool(h["war"]): s += "\n" + tr("DISBAND_WAR_WARN")
	return s

func _epit_menetek() -> void:
	_torol(_menetek)
	var pf: int = _gm.player_faction
	var van := false
	for i in _gm.marches.size():
		var m: Dictionary = _gm.marches[i]
		if int(m["faction"]) != pf: continue
		if not van:
			_menetek.add_child(HSeparator.new())
			_menetek.add_child(_cimke(tr("DISBAND_MARCHES"), 14, Color(0.98, 0.88, 0.62)))
			van = true
		var sor := HBoxContainer.new()
		sor.add_theme_constant_override("separation", 8)
		_menetek.add_child(sor)
		var l := _cimke(Localization.t("DISBAND_MARCH_ROW", [_gm.province_label(str(m["from"])), _gm.province_label(str(m["to"])),
			_gm.troops_of(m)]))
		l.size_flags_horizontal = SIZE_EXPAND_FILL
		sor.add_child(l)
		var gomb := Button.new()
		gomb.text = tr("DISBAND_BTN")
		gomb.custom_minimum_size = Vector2(120, 34)
		var idx: int = i
		gomb.pressed.connect(func(): keres.emit({"march": idx}))
		sor.add_child(gomb)
