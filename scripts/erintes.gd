extends Node

# HEPTARCHIA – érintőképernyő (a böngészős változat telefonon és táblagépen)
#
# A Godot az érintésből magától csak bal egérgombot csinál (az első ujjból), így telefonon nem lehetne
# jobb klikkelni, nagyítani vagy a csatatéren a kamerát mozgatni. Itt saját fordítás van: az érintésből
# ugyanolyan egéresemények lesznek, mint gépen, így a játék többi része semmit sem tud az érintésről.
#
#   koppintás                    = bal klikk (két gyors koppintás ugyanott: dupla klikk)
#   hosszú nyomás (fél mp, helyben) = jobb klikk; utána húzva jobb húzás (a csatában: vonalba állás)
#   egy ujjal húzás              = bal húzás (a térkép görgetése, csúszka)
#                                  görgethető listán / panelen: görgetés (lendülettel)
#                                  a vezérlő erintes_huzas(pont) függvénye más gombot is kérhet (a taktikai
#                                  csatában az üres mezőn a középső gomb = a kamera mozgatása)
#   két ujj                      = csippentés: nagyítás · húzás: mozgatás · csavarás: forgatás – a vezérlő
#                                  erintes_gesztus(közép, szorzó, eltolás, forgás) függvénye kapja; ha nincs
#                                  ilyen, nagyító gesztus (InputEventMagnifyGesture) megy
#   a súgók (tooltip): a koppintás / hosszú nyomás helyén marad az „egér”, így a súgó ott megjelenik
#
# Csak a böngészős változatban, érintőképernyős eszközön kapcsol be (a betöltő oldal window.hepErinto
# jelzése vagy a Godot érintőképernyő-észlelése szerint); asztali változatban semmit sem csinál.

const KUSZOB := 14.0          # ennyi (felületi képpont) elmozdulás után már húzás, nem koppintás
const HOSSZU := 0.5           # hosszú nyomás (jobb klikk) ideje, mp
const DUPLA_IDO := 0.4        # két koppintás ennyin belül = dupla klikk
const DUPLA_TAV := 30.0
const LENDULET_FEKEZ := 5.0   # a görgetés lendületének csillapítása (1/mp)

enum { NINCS, VAR, BAL, KOZEP, JOBB, GORGET, GESZTUS, HALOTT }

var aktiv: bool = false
var _allapot: int = NINCS
var _ujjak: Dictionary = {}           # ujj sorszáma -> helye (a felület koordinátáiban)
var _elso: int = -1                   # az egy ujjas művelet ujja
var _kezd: Vector2 = Vector2.ZERO
var _kezd_ido: float = 0.0
var _kezd_kocka: int = 0              # a lenyomáskori képkocka sorszáma
var _eger: Vector2 = Vector2.ZERO     # ahol az „egér” utoljára volt
var _gomb_le: int = MOUSE_BUTTON_NONE
var _gorgeto: Control = null
var _lendulet: Vector2 = Vector2.ZERO
var _utolso_kopp_ido: float = -10.0
var _utolso_kopp: Vector2 = Vector2.ZERO
var _gesztus_cel: Object = null
var _g_kozep: Vector2 = Vector2.ZERO
var _g_tav: float = 0.0
var _g_szog: float = 0.0
var _jelzo: Control = null
var _fel_var: int = 0                 # a koppintás felengedése ennyi képkocka múlva megy (lásd _koppint)

func _ready() -> void:
	if not OS.has_feature("web"): return
	# (szövegként kérjük: a JavaScript-szám lebegőpontosként, a logikai érték számként jönne át)
	var jelzes := str(JavaScriptBridge.eval("window.hepErinto ? 'igen' : 'nem'", true))
	aktiv = jelzes == "igen" or DisplayServer.is_touchscreen_available()
	if not aktiv: return
	# az érintésből mi csinálunk egéreseményt (a Godot sajátja csak bal gombot tud)
	Input.emulate_mouse_from_touch = false
	var reteg := CanvasLayer.new()
	reteg.layer = 128
	add_child(reteg)
	_jelzo = Jelzo.new()
	reteg.add_child(_jelzo)

func _ido() -> float:
	return Time.get_ticks_msec() * 0.001

# ── Az érintések ─────────────────────────────────────────────────

func _input(ev: InputEvent) -> void:
	if not aktiv: return
	if ev is InputEventScreenTouch:
		_erintes(ev as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		_huzas(ev as InputEventScreenDrag)
		get_viewport().set_input_as_handled()

func _erintes(st: InputEventScreenTouch) -> void:
	if st.pressed:
		_ujjak[st.index] = st.position
		_fel_most()
		if _ujjak.size() == 1:
			_lendulet = Vector2.ZERO
			_elso = st.index
			_allapot = VAR
			_kezd = st.position
			_kezd_ido = _ido()
			_kezd_kocka = Engine.get_process_frames()
			# az „egér” odaáll (a térkép kiemelése, a súgó, a csatában az egység adatai)
			_mozgat(st.position)
		elif _ujjak.size() == 2:
			_gesztus_kezd()
		return
	_ujjak.erase(st.index)
	if st.index == _elso:
		match _allapot:
			VAR:
				if not st.canceled: _koppint()
			BAL, KOZEP, JOBB:
				_mozgat(st.position)
				_gomb(_gomb_le, false)
		_elso = -1
		# (elengedett görgetés: a lendület megmarad, a _process futtatja ki)
		if _allapot != GORGET: _lendulet = Vector2.ZERO
		_allapot = NINCS if _ujjak.is_empty() else HALOTT
	elif _allapot == GESZTUS:
		_allapot = NINCS if _ujjak.is_empty() else HALOTT
	if _ujjak.is_empty():
		if _allapot != NINCS: _allapot = NINCS
		_jelzo_ki()

func _huzas(sd: InputEventScreenDrag) -> void:
	if not _ujjak.has(sd.index): return
	var elozo: Vector2 = _ujjak[sd.index]
	_ujjak[sd.index] = sd.position
	if _allapot == GESZTUS:
		_gesztus_lep()
		return
	if sd.index != _elso: return
	match _allapot:
		VAR:
			if sd.position.distance_to(_kezd) > KUSZOB:
				_jelzo_ki()
				_huzas_kezd(sd.position)
		BAL, KOZEP, JOBB:
			_mozgat(sd.position)
		GORGET:
			var d := sd.position - elozo
			_gorget(d)
			# a lendület: az utolsó mozdulatok sebessége (simítva)
			var dt := maxf(1.0 / 120.0, get_process_delta_time())
			_lendulet = _lendulet.lerp(d / dt, 0.5)

## Az egy ujjas húzás eldől: görgetés, vagy egy egérgomb lenyomva (a kezdőpontban) és húzás
func _huzas_kezd(hol: Vector2) -> void:
	var cel := get_viewport().gui_get_hovered_control()
	_gorgeto = _gorgeto_keres(cel)
	if _gorgeto != null:
		_allapot = GORGET
		_lendulet = Vector2.ZERO
		_gorget(hol - _kezd)
		return
	var gomb := MOUSE_BUTTON_LEFT
	var kero := _keres(cel, "erintes_huzas")
	if kero != null: gomb = int(kero.call("erintes_huzas", _kezd))
	_allapot = KOZEP if gomb == MOUSE_BUTTON_MIDDLE else (JOBB if gomb == MOUSE_BUTTON_RIGHT else BAL)
	_gomb(gomb, true)
	_mozgat(hol)

func _koppint() -> void:
	var most := _ido()
	var dupla := most - _utolso_kopp_ido < DUPLA_IDO and _kezd.distance_to(_utolso_kopp) < DUPLA_TAV
	# gombon nincs dupla klikk: a gyors egymás utáni koppintás mind külön lenyomás legyen (pl. a + gomb)
	if get_viewport().gui_get_hovered_control() is BaseButton: dupla = false
	_utolso_kopp_ido = -10.0 if dupla else most
	_utolso_kopp = _kezd
	_gomb(MOUSE_BUTTON_LEFT, true, dupla)
	# A felengedés csak két képkocka múlva: a Godot a gomb fölötti „egér” állapotát képkockánként frissíti, és
	# ha a lenyomás és a felengedés ugyanabba a képkockába esik (gyors koppintás, akadozó kép), a gomb nem sül el.
	_fel_var = 2

## A függőben lévő koppintás felengedése (most)
func _fel_most() -> void:
	if _fel_var <= 0: return
	_fel_var = 0
	_gomb(MOUSE_BUTTON_LEFT, false)
func _process(delta: float) -> void:
	if not aktiv: return
	if _fel_var > 0:
		_fel_var -= 1
		if _fel_var == 0: _gomb(MOUSE_BUTTON_LEFT, false)
	if _allapot == VAR:
		var t := _ido() - _kezd_ido
		# (legalább néhány képkocka is teljen el, és a kép ne akadozzon: akadozó képnél a már felengedett ujj
		# jelzése csak a következő képkockában ér ide – a koppintásból ne legyen jobb klikk)
		if t >= HOSSZU and Engine.get_process_frames() - _kezd_kocka >= 4 and delta < 0.2:
			# hosszú nyomás: jobb klikk (a gomb lenyomva marad, amíg az ujj)
			_jelzo_ki()
			_allapot = JOBB
			_gomb(MOUSE_BUTTON_RIGHT, true)
		elif t > 0.15 and _jelzo != null:
			_jelzo.mutat(_kezd, (t - 0.15) / (HOSSZU - 0.15))
	elif _allapot != GORGET and _lendulet != Vector2.ZERO:
		# elengedett görgetés: lendülettel fut tovább, lassulva
		if _lendulet.length() < 20.0 or not is_instance_valid(_gorgeto):
			_lendulet = Vector2.ZERO
		else:
			_gorget(_lendulet * delta)
			_lendulet *= exp(-LENDULET_FEKEZ * delta)

# ── Két ujj: nagyítás, mozgatás, forgatás ─────────────────────────

func _gesztus_kezd() -> void:
	_jelzo_ki()
	# az egy ujjas művelet lezárul (a lenyomott gomb felenged)
	if _allapot in [BAL, KOZEP, JOBB]: _gomb(_gomb_le, false)
	_lendulet = Vector2.ZERO
	_allapot = GESZTUS
	_gesztus_cel = _keres(get_viewport().gui_get_hovered_control(), "erintes_gesztus")
	var k := _ket_ujj()
	_g_kozep = (k[0] + k[1]) * 0.5
	_g_tav = k[0].distance_to(k[1])
	_g_szog = (k[1] - k[0]).angle()

func _gesztus_lep() -> void:
	var k := _ket_ujj()
	var kozep: Vector2 = (k[0] + k[1]) * 0.5
	var tav: float = k[0].distance_to(k[1])
	var szog: float = (k[1] - k[0]).angle()
	var szorzo := tav / _g_tav if _g_tav > 8.0 and tav > 8.0 else 1.0
	var eltol := kozep - _g_kozep
	var forgas := wrapf(szog - _g_szog, -PI, PI) if tav > 40.0 else 0.0
	_g_kozep = kozep
	_g_tav = tav
	_g_szog = szog
	if _gesztus_cel != null and is_instance_valid(_gesztus_cel):
		_gesztus_cel.call("erintes_gesztus", kozep, szorzo, eltol, forgas)
	elif not is_equal_approx(szorzo, 1.0):
		var mg := InputEventMagnifyGesture.new()
		mg.position = _ablakba(kozep)
		mg.factor = szorzo
		Input.parse_input_event(mg)

func _ket_ujj() -> Array:
	var r: Array = []
	for i in _ujjak:
		r.append(_ujjak[i])
		if r.size() == 2: break
	while r.size() < 2: r.append(r[0] if not r.is_empty() else Vector2.ZERO)
	return r

# ── Görgetés ujjal ────────────────────────────────────────────────

## A vezérlő (vagy egy őse), amely ujjal görgethető: görgetősáv nélküli lista / panel, amelynek a tartalma
## nem fér ki. A csúszka és a görgetősáv maga nem (azt húzni kell).
func _gorgeto_keres(c: Control) -> Control:
	var n: Node = c
	while n != null and n is Control:
		if n is Range: return null
		if n is ScrollContainer or n is ItemList or n is RichTextLabel or n is TextEdit:
			if _gorgetheto(n as Control): return n as Control
		n = n.get_parent()
	return null

func _gorgetheto(c: Control) -> bool:
	for sav in _savok(c):
		if sav != null and (sav as ScrollBar).max_value - (sav as ScrollBar).page > 0.5: return true
	return false

func _savok(c: Control) -> Array:
	var v: ScrollBar = null
	var h: ScrollBar = null
	if c.has_method("get_v_scroll_bar"): v = c.call("get_v_scroll_bar")
	if c.has_method("get_h_scroll_bar"): h = c.call("get_h_scroll_bar")
	if c is ScrollContainer:
		var sc := c as ScrollContainer
		if sc.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED: v = null
		if sc.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED: h = null
	return [v, h]

func _gorget(d: Vector2) -> void:
	if _gorgeto == null or not is_instance_valid(_gorgeto): return
	# a vezérlő saját méretarányában (ha nagyítva van)
	var s := _gorgeto.get_global_transform_with_canvas().get_scale()
	var sav := _savok(_gorgeto)
	if sav[0] != null: (sav[0] as ScrollBar).value -= d.y / maxf(0.01, s.y)
	if sav[1] != null: (sav[1] as ScrollBar).value -= d.x / maxf(0.01, s.x)

# ── Egéresemények ─────────────────────────────────────────────────

## A felület (a nyújtott 1280×720-as alap) pontja az ablak képpontjaiban – az Input így várja
func _ablakba(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func _maszk() -> int:
	match _gomb_le:
		MOUSE_BUTTON_LEFT: return MOUSE_BUTTON_MASK_LEFT
		MOUSE_BUTTON_RIGHT: return MOUSE_BUTTON_MASK_RIGHT
		MOUSE_BUTTON_MIDDLE: return MOUSE_BUTTON_MASK_MIDDLE
	return 0

func _mozgat(hol: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _ablakba(hol)
	ev.global_position = ev.position
	ev.relative = ev.position - _ablakba(_eger)
	ev.screen_relative = ev.relative
	ev.button_mask = _maszk()
	_eger = hol
	Input.parse_input_event(ev)

func _gomb(gomb: int, le: bool, dupla: bool = false) -> void:
	if gomb == MOUSE_BUTTON_NONE: return
	# a lenyomás mindig a kezdőpontban (onnan indul a húzás), a felengedés ott, ahol az ujj van
	if le and _kezd != _eger: _mozgat(_kezd)
	_gomb_le = gomb if le else MOUSE_BUTTON_NONE
	var ev := InputEventMouseButton.new()
	ev.button_index = gomb as MouseButton
	ev.pressed = le
	ev.double_click = dupla
	ev.position = _ablakba(_eger)
	ev.global_position = ev.position
	ev.button_mask = _maszk()
	Input.parse_input_event(ev)

## A vezérlő vagy a legközelebbi őse, amelyiknek van ilyen függvénye
func _keres(c: Node, fv: String) -> Object:
	var n := c
	while n != null:
		if n.has_method(fv): return n
		n = n.get_parent()
	return null

# ── A hosszú nyomás jelzése: egy telő kör az ujj körül ──────────────

func _jelzo_ki() -> void:
	if _jelzo != null: _jelzo.mutat(Vector2.ZERO, -1.0)

class Jelzo extends Control:
	var hol: Vector2 = Vector2.ZERO
	var tele: float = -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func mutat(p: Vector2, t: float) -> void:
		if t < 0.0 and tele < 0.0: return
		hol = p
		tele = clampf(t, 0.0, 1.0) if t >= 0.0 else -1.0
		queue_redraw()

	func _draw() -> void:
		if tele < 0.0: return
		draw_arc(hol, 34.0, 0.0, TAU, 40, Color(0.0, 0.0, 0.0, 0.35), 7.0, true)
		draw_arc(hol, 34.0, -PI * 0.5, -PI * 0.5 + TAU * tele, 40, Color(0.94, 0.78, 0.42, 0.9), 4.0, true)
