extends CanvasLayer

## HEPTARCHIA – OKTATÓMÓD.
##
## Lépésről lépésre végigvezet a játékon: kiemeli a felület egy-egy részét,
## elmagyarázza, mire való, és néhol meg is várja, hogy tényleg megcsináld.
##
## Hogyan van felépítve?
##   • A lépések a LEPESEK tömbben vannak, sorban. Mindegyikhez tartozik egy
##     cím és egy szöveg (nyelvi kulcs), és megadható hozzá egy CÉL: a felület
##     egy csomópontja, amit kiemelünk.
##   • Ha egy lépéshez `varj` is tartozik, a Tovább gomb addig nem jelenik meg,
##     amíg a játékos tényleg meg nem csinálja (tartományt választ, épít, kört
##     zár). Így nem lehet végigkattintani anélkül, hogy bármit is kipróbálnál.
##   • A kiemelés nem takar: az ablak mindig a cél MÁSIK oldalára kerül, hogy
##     lásd, amiről beszél.
##
## Bármikor kiléphetsz belőle: a Kihagyom gombbal vagy Esc-cel.

const KERET := Color(0.98, 0.83, 0.42)
const ARNYEK := Color(0.05, 0.04, 0.03, 0.55)
const PANEL_BG := Color(0.16, 0.12, 0.08, 0.97)
const SZOVEG := Color(0.96, 0.92, 0.82)
const CIM := Color(0.98, 0.85, 0.50)

# cel:    a kiemelendő csomópont egyedi neve a MainGame jelenetben ("" = nincs)
# varj:   mire várunk, mielőtt tovább lehet lépni ("" = elég a Tovább gomb)
#         "tartomany"  – válassz ki egy tartományt a térképen
#         "epites"     – épüljön vagy toborzódjon valami
#         "tanacs"     – nyisd meg a tanács ablakát
#         "diplomacia" – nyisd meg a diplomáciát
#         "kor"        – záruljon le egy kör
#
# A lényeg: ahol `varj` van, ott a Tovább gomb LETILTVA marad, amíg a játékos
# tényleg meg nem csinálja. Nem lehet végigkattintani anélkül, hogy kipróbálnád.
const LEPESEK := [
	{"cel": "", "kulcs": "TUT_1", "varj": ""},
	{"cel": "lbl_year", "kulcs": "TUT_2", "varj": ""},
	{"cel": "lbl_prov_name", "kulcs": "TUT_3", "varj": "tartomany"},
	{"cel": "lbl_prov_info", "kulcs": "TUT_4", "varj": ""},
	{"cel": "action_grid", "kulcs": "TUT_5", "varj": "epites"},
	{"cel": "btn_move_army", "kulcs": "TUT_6", "varj": ""},
	{"cel": "btn_attack", "kulcs": "TUT_7", "varj": ""},
	{"cel": "lbl_witan_title", "kulcs": "TUT_8", "varj": "tanacs"},
	{"cel": "lbl_dip_header", "kulcs": "TUT_9", "varj": "diplomacia"},
	{"cel": "txt_chronicle", "kulcs": "TUT_10", "varj": ""},
	{"cel": "btn_next_turn", "kulcs": "TUT_11", "varj": "kor"},
	{"cel": "", "kulcs": "TUT_12", "varj": ""},
]

var main: Node = null                 # a main_game.gd
var _lepes := 0
var _var_ra := ""
var _kor_indulas := 0
var _epites_indulas := 0

var _fatyol: Control
var _panel: PanelContainer
var _cim: Label
var _szoveg: RichTextLabel
var _szamlalo: Label
var _tovabb: Button
var _kihagy: Button
var _cel_rect := Rect2()


func inditsd(jatek: Node) -> void:
	main = jatek
	layer = 90
	_epit()
	_mutat()


func _epit() -> void:
	_fatyol = Control.new()
	# A CanvasLayer nem Control, így a horgonyok nem méreteznek: a fátyol méretét
	# magunknak kell a képernyőére állítanunk (és ablakméretezéskor követnünk).
	_fatyol.mouse_filter = Control.MOUSE_FILTER_IGNORE   # ne fogja el a kattintást
	_fatyol.draw.connect(_rajzol_fatyol)
	add_child(_fatyol)
	_fatyol.size = _kepernyo()

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(430, 0)
	var stilus := StyleBoxFlat.new()
	stilus.bg_color = PANEL_BG
	stilus.border_color = KERET
	stilus.set_border_width_all(2)
	stilus.set_corner_radius_all(8)
	stilus.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", stilus)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)

	_cim = Label.new()
	_cim.add_theme_font_size_override("font_size", 19)
	_cim.add_theme_color_override("font_color", CIM)
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_cim)

	# RichTextLabel, hogy a szövegben a **kiemelés** tényleg vastagon jelenjen meg
	_szoveg = RichTextLabel.new()
	_szoveg.bbcode_enabled = true
	_szoveg.fit_content = true
	_szoveg.scroll_active = false
	_szoveg.add_theme_font_size_override("normal_font_size", 14)
	_szoveg.add_theme_font_size_override("bold_font_size", 14)
	_szoveg.add_theme_color_override("default_color", SZOVEG)
	_szoveg.custom_minimum_size = Vector2(400, 0)
	v.add_child(_szoveg)

	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 10)
	v.add_child(sor)

	_szamlalo = Label.new()
	_szamlalo.add_theme_font_size_override("font_size", 13)
	_szamlalo.add_theme_color_override("font_color", Color(0.72, 0.66, 0.52))
	_szamlalo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_szamlalo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sor.add_child(_szamlalo)

	_kihagy = Button.new()
	_kihagy.pressed.connect(_kilep)
	sor.add_child(_kihagy)

	_tovabb = Button.new()
	_tovabb.pressed.connect(_kovetkezo)
	sor.add_child(_tovabb)


func _mutat() -> void:
	if _lepes >= LEPESEK.size():
		_kilep()
		return
	var l: Dictionary = LEPESEK[_lepes]
	_cim.text = tr(str(l["kulcs"]) + "_C")
	_szoveg.text = _vastag(tr(str(l["kulcs"]) + "_T"))
	_szamlalo.text = "%d / %d" % [_lepes + 1, LEPESEK.size()]
	_kihagy.text = tr("TUT_SKIP")
	_var_ra = str(l["varj"])
	if _var_ra == "kor":
		_kor_indulas = GameManager.turn_index()
	elif _var_ra == "epites":
		_epites_indulas = _epitett()
	_frissit_gomb()
	_igazit()


## A nyelvi fájlokban **csillagpárral** jelöljük azt a mondatot, ami a TEENDŐ.
## Itt lesz belőle vastag, arany szedés – a betűtípusnak nincs külön félkövér
## változata, ezért a szín viszi el a kiemelést.
func _vastag(sz: String) -> String:
	var ki := ""
	var nyitva := false
	var reszek := sz.split("**")
	for i in reszek.size():
		if i > 0:
			ki += "[b][color=#%s]" % CIM.to_html(false) if not nyitva else "[/color][/b]"
			nyitva = not nyitva
		ki += str(reszek[i])
	if nyitva: ki += "[/color][/b]"
	return ki


func _frissit_gomb() -> void:
	var kesz := _var_ra == "" or _teljesult()
	_tovabb.disabled = not kesz
	if kesz:
		_tovabb.text = tr("TUT_DONE") if _lepes == LEPESEK.size() - 1 else tr("TUT_NEXT")
	else:
		_tovabb.text = tr("TUT_WAIT_" + _var_ra.to_upper())


func _teljesult() -> bool:
	if main == null: return false
	match _var_ra:
		"tartomany":  return str(main.selected_province) != ""
		"epites":     return _epitett() > _epites_indulas
		"tanacs":     return _nyitva(main.get("witan_popup"))
		"diplomacia": return _nyitva(main.get("diplist_popup"))
		"kor":        return GameManager.turn_index() > _kor_indulas
	return true


func _nyitva(n: Variant) -> bool:
	return n is CanvasItem and (n as CanvasItem).visible


## Mindaz, amit egy fejlesztés megnövel: épületszintek, helyőrség, hajók.
## Ha ez a szám nő, a játékos tényleg megnyomott egy fejlesztést – mindegy,
## melyiket, mert a kezdőtartományban nem mind elérhető (fyrdet például csak
## kaszárnya után lehet toborozni).
const SZAMLALT := ["fyrd", "thegn", "defense", "ships", "church", "barracks",
	"village", "farm", "hof"]
const IGEN_NEM := ["has_burh", "has_market", "has_tower", "has_port", "has_mine", "has_mint"]

func _epitett() -> int:
	var n := 0
	for p in GameManager.get_faction_provinces(GameManager.player_faction):
		var d: Dictionary = GameManager.provinces[p]
		for k in SZAMLALT:
			n += int(d.get(k, 0))
		for k in IGEN_NEM:
			if d.get(k, false): n += 1
	return n


func _kovetkezo() -> void:
	_lepes += 1
	_mutat()


func _kilep() -> void:
	# ha a játékos a menüből újratölti ezt a játékot, ne kezdődjön elölről
	GameManager.tutorial = false
	queue_free()


func _process(_delta: float) -> void:
	if _var_ra != "":
		_frissit_gomb()
	_igazit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_kilep()


## A panel a cél MÁSIK oldalára kerül, hogy ne takarja el azt, amiről beszél.
func _kepernyo() -> Vector2:
	var vp := _fatyol.get_viewport() if _fatyol != null else null
	return vp.get_visible_rect().size if vp != null else Vector2(1280, 720)


func _igazit() -> void:
	var kepernyo := _kepernyo()
	if _fatyol != null and _fatyol.size != kepernyo:
		_fatyol.size = kepernyo
	var c: Control = _keres()
	if c == null:
		_cel_rect = Rect2()
		_panel.position = (kepernyo - _panel.size) * 0.5
	else:
		_cel_rect = Rect2(c.global_position, c.size)
		var jobbra := _cel_rect.position.x + _cel_rect.size.x + 24.0
		var balra := _cel_rect.position.x - _panel.size.x - 24.0
		var x := jobbra if jobbra + _panel.size.x < kepernyo.x else balra
		if x < 0.0: x = clampf(_cel_rect.get_center().x - _panel.size.x * 0.5, 12.0, kepernyo.x - _panel.size.x - 12.0)
		var y := clampf(_cel_rect.get_center().y - _panel.size.y * 0.5, 12.0, kepernyo.y - _panel.size.y - 12.0)
		_panel.position = Vector2(x, y)
	_fatyol.queue_redraw()


func _keres() -> Control:
	if main == null or _lepes >= LEPESEK.size(): return null
	var nev := str(LEPESEK[_lepes]["cel"])
	if nev == "": return null
	var n := main.get_node_or_null("%" + nev)
	return n as Control if n is Control and (n as Control).visible else null


## Sötétítjük a képernyőt, a kiemelt rész KÖRÜL – magát a célt nem takarjuk,
## hogy látszódjon és kattintható maradjon.
func _rajzol_fatyol() -> void:
	var m := _fatyol.size
	if _cel_rect.size == Vector2.ZERO:
		_fatyol.draw_rect(Rect2(Vector2.ZERO, m), ARNYEK)
		return
	var r := _cel_rect.grow(6.0)
	_fatyol.draw_rect(Rect2(0, 0, m.x, r.position.y), ARNYEK)
	_fatyol.draw_rect(Rect2(0, r.position.y + r.size.y, m.x, m.y - r.position.y - r.size.y), ARNYEK)
	_fatyol.draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), ARNYEK)
	_fatyol.draw_rect(Rect2(r.position.x + r.size.x, r.position.y, m.x - r.position.x - r.size.x, r.size.y), ARNYEK)
	_fatyol.draw_rect(r, KERET, false, 2.5)
