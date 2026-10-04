extends Node

# TAKTIKAI CSATA – a lejátszható csata ablaka (a térkép fölé nyíló réteg)
#
# Használat (a játék adaptere hívja):
#   var cs = preload("res://scripts/taktikai_csata/tc_csata.gd").new()
#   get_tree().root.add_child(cs)
#   cs.befejezve.connect(func(eredmeny): ...)
#   cs.indit(cfg)          # cfg: lásd TcSzim.beallit (benne "ostrom", "stilus"), plusz "cim" (az ablak címe)
# A rajz a tc_nezet (katonaalakok: tc_alakok), a hangok a tc_hang dolga.
# A csata végén a `befejezve` jel a TcSzim.eredmeny() szótárát adja át, és a réteg eltűnik.
#
# Irányítás (Total War-szerűen, egyszerűsítve):
#   bal klikk: kijelölés (Shift / Ctrl: hozzáad), bal húzás: dobozos kijelölés, Ctrl+A: mind
#   jobb klikk: menj ide (lépésben; dupla jobb klikk: futva) / támadd meg (ha ellenségre kattintasz) /
#   ostromnál a kapura: törd be (kos, gyalogság); jobb húzás: vonalba állás, arccal előre
#   felállításkor: a kijelölt egységeket bal egérrel húzva is lehet mozgatni a saját sávban
#   alakzat (a parancssor gombjai is – csak azok, amelyeket a kijelöltek népe ismer, a népük nevén):
#     C zárt rend · Q falanx / pajzsfal / szarisszás falanx / sparabara / pavéza · T teknős · V ék (cuneus) ·
#     X laza rend · O kantabriai kör
#   E / U: a nép különleges képessége (csatakiáltás, színlelt visszavonulás, a vonalak váltása, portyázás…)
#   F: tüzelés szabadon / tartva · R: futás / lépés · B: tartalék
#   Szóköz: szünet · 1 / 2 / 3: sebesség (1×, 2×, 4×) · G: csoport · Backspace: állj · F1 / ?: súgó
#   kamera: WASD / nyilak / a képernyő széle / középső egérgomb húzása, görgő: nagyítás
#
# ÁTVITEL MÁS JÁTÉKBA: a mappa önálló. A szövegek a TC_* nyelvi kulcsok (tr()), a típusok a tc_adat.gd-ben;
# a játékhoz csak egy adapter kell, ami a seregeket erre a formára hozza, és az eredményt visszaírja.

const A := preload("res://scripts/taktikai_csata/tc_adat.gd")
const T := preload("res://scripts/taktikai_csata/tc_taktika.gd")
const Szim := preload("res://scripts/taktikai_csata/tc_szim.gd")
const NezetS := preload("res://scripts/taktikai_csata/tc_nezet.gd")
const HangS := preload("res://scripts/taktikai_csata/tc_hang.gd")
const Alakok := preload("res://scripts/taktikai_csata/tc_alakok.gd")
const BEALLITAS := "user://taktikai_csata.cfg"
const ZOOM_MIN := 0.45
const ZOOM_MAX := 12.0
# az alakzatok sorrendje a parancssorban (a gomb a kijelöltek népének nevén, lásd tc_taktika)
const ALAKZAT_SOR := ["", "falanx", "sarissa", "sparabara", "pavez", "karosor", "teknos", "ek", "laza", "vonal", "carre",
	"tercio", "szekervar", "oszlop", "kor"]

signal befejezve(eredmeny: Dictionary)

var szim: Szim = null
# élő többjátékos csata (tc_halo): a szimuláció a házigazdán fut, itt egy báb; en: a vezetett oldal (-1: néző)
var halo: Node = null
var en: int = 0
var nezet: NezetS = null
var vilag_reteg: CanvasLayer = null
var ui_reteg: CanvasLayer = null
var gyors: float = 1.0
var szunet: bool = false
var automata: bool = false        # a játékos oldalát is az MI vezeti (tesztekhez)
var _gyujto: float = 0.0
var kijelolt: Dictionary = {}
var _csoport_kov: int = 1
var _cfg: Dictionary = {}

# kamera
var kam_poz: Vector2 = Vector2(A.TER_W * 0.5, A.TER_H * 0.6)
var kam_zoom: float = 0.9
# sima nagyítás: a görgő a célt állítja, a kamera odasimul (a kurzor alatti pont helyben marad)
var kam_cel_zoom: float = 0.9
# 2,5D: a kamera a függőleges tengely körül forgatható (0: a játékos serege mögül); a cél felé simul
var kam_forgas: float = 0.0
var kam_cel_forgas: float = 0.0
var kam_alap_forgas: float = 0.0       # a saját sereg mögül (a felső oldalnak 180°)
var _zoom_pont: Vector2 = Vector2.ZERO
var _zoom_lep: bool = false
var _utolso_zoom: float = 0.9
# rázkódás (roham, kapu betörése a kamera közelében)
var _razkodas: float = 0.0
# egér
var _bal_le: bool = false
var _bal_kezd: Vector2 = Vector2.ZERO
var _telepit_huz: bool = false
var _huz_eltolas: Dictionary = {}
var _jobb_le: bool = false
var _jobb_dupla: bool = false
var _jobb_kezd: Vector2 = Vector2.ZERO
var _jobb_kezd_kep: Vector2 = Vector2.ZERO
var _kozep_le: bool = false
var _utolso_eger: Vector2 = Vector2.ZERO

# felület
var ui: Control = null
var fogo: Control = null
var lbl_cim: Label = null
var lbl_ido: Label = null
var ero_sav: Control = null
var btn_szunet: Button = null
var btn_seb: Array = []
var btn_vissza: Button = null
var btn_indit: Button = null
var _vissza_biztos: bool = false
var kartya_sor: HBoxContainer = null
var kartyak: Array = []
var telep_panel: PanelContainer = null
var lbl_szunet: Label = null
var esemeny_rtl: RichTextLabel = null
var _esemeny_szam: int = 0
var _esemeny_sorok: Array = []
var sugo_panel: PanelContainer = null      # a részletes súgó (csak kérésre)
var sugo_tipp: PanelContainer = null       # a kétsoros tipp az első csata elején
var _tipp_ido: float = 0.0
var _sugo_gorgo: ScrollContainer = null
var _sugo_lista: VBoxContainer = null
var eredmeny_panel: PanelContainer = null
var minimap: Control = null
var info_lbl: Label = null
var parancs_sor: PanelContainer = null
var _alakzat_gombok: Dictionary = {}     # alakzat -> Button
var _kepesseg_gombok: Dictionary = {}    # képesség -> Button
var _taktika_doboz: HBoxContainer = null # az alakzat- és képességgombok (a kijelöltek népe szerint épül)
var _taktika_kulcs: String = ""
var _lat_ido: float = 0.0                # a felállításkor is frissül a látás
var btn_tuz: Button = null
var btn_fut: Button = null
var btn_tartalek: Button = null
var lbl_ostrom: Label = null
var hang: Node = null
var _kos_hang: Dictionary = {}

var _ui_frissitve: int = 0
var sim_us: int = 0                # az utolsó képkocka szimulációs ideje (µs) – a mérőnek

const FELSO_M := 46.0
const ALSO_M := 112.0

# ── Indítás ──────────────────────────────────────────────────────

func indit(cfg: Dictionary) -> void:
	_cfg = cfg
	if halo != null:
		szim = halo.szim_keszit(cfg)
	else:
		szim = Szim.new()
		szim.beallit(cfg)
	automata = bool(cfg.get("automata", false))
	if automata: szim.oldalak[0]["ai"] = true
	var hatter := CanvasLayer.new()
	hatter.layer = 59
	add_child(hatter)
	var sotet := ColorRect.new()
	sotet.color = Color(0.1, 0.09, 0.07)
	sotet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sotet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hatter.add_child(sotet)
	vilag_reteg = CanvasLayer.new()
	vilag_reteg.layer = 60
	add_child(vilag_reteg)
	nezet = NezetS.new()
	vilag_reteg.add_child(nezet)
	nezet.kijelolt = kijelolt
	nezet.nezo = nezo_oldal()
	for o in 2: nezet.szin[o] = szim.oldalak[o]["szin"]
	nezet.beallit(szim)
	hang = HangS.new()
	hang.csata = self
	add_child(hang)
	ui_reteg = CanvasLayer.new()
	ui_reteg.layer = 61
	add_child(ui_reteg)
	_epit_ui()
	# a kamera a saját sávunkra néz (a felső oldal mögül: elforgatva)
	var so := nezo_oldal()
	var s := szim.sav(so)
	if so == 1:
		kam_poz = Vector2(s.get_center().x, s.end.y + 90.0)
		kam_alap_forgas = PI
		kam_forgas = PI
		kam_cel_forgas = PI
	else:
		kam_poz = Vector2(s.get_center().x, s.position.y - 90.0)
	kam_zoom = 0.9
	_kamera_frissit()
	_kartyak_epit()
	_frissit_ui()
	if not _sugo_latta(): _tipp_mutat()
	if halo != null:
		halo.ui_epit(self)
		halo.betoltve()

## Akinek a szemével nézzük a csatát: a vezetett oldal, a nézőnek a választott látás (mindkettőnél az alsó)
func nezo_oldal() -> int:
	if en >= 0: return en
	if halo != null: return maxi(int(halo.nezet_oldal), 0)
	return 0

## A néző másik látást választott (a házigazda már aszerint küldi)
func nezo_valt(_n: int) -> void:
	if nezet != null: nezet.nezo = nezo_oldal()

func _process(delta: float) -> void:
	if szim == null: return
	_kamera_mozgas(delta)
	_zoom_simit(delta)
	if _razkodas > 0.0:
		_razkodas = maxf(0.0, _razkodas - delta * 3.0)
		_kamera_frissit()
	if halo != null:
		# élő többjátékos csata: a báb a házigazda pillanatképeiből lép (a szünet, a sebesség is onnan)
		halo.frissit(delta)
		szunet = halo.szunet
		gyors = halo.gyors
		if telep_panel != null and szim.fazis != "telepites":
			telep_panel.queue_free()
			telep_panel = null
			if hang != null: hang.szol("kurt", null, -3.0)
		_uj_esemenyek()
		nezet.alfa = halo.alfa
		nezet.ido_lep = halo.ido_lep
	# felállításkor is látszik, amit a csapatok látnak (a mozgatásukkal változik)
	elif szim.fazis == "telepites":
		_lat_ido -= delta
		if _lat_ido <= 0.0:
			_lat_ido = 0.3
			szim.lathatosag_frissit()
	if halo == null:
		if szim.fazis == "csata" and not szunet:
			_gyujto += minf(delta, 0.1) * gyors
			var db := 0
			var t_sim := Time.get_ticks_usec()
			while _gyujto >= Szim.LEPES and db < 12:
				szim.lep()
				_gyujto -= Szim.LEPES
				db += 1
			if db >= 12: _gyujto = 0.0
			sim_us = Time.get_ticks_usec() - t_sim
			_uj_esemenyek()
		nezet.alfa = clampf(_gyujto / Szim.LEPES, 0.0, 1.0) if szim.fazis == "csata" else 1.0
		nezet.ido_lep = minf(delta, 0.1) * gyors if (szim.fazis == "csata" and not szunet) else 0.0
	var vm := _kepernyo()
	# a kép négy sarka a talajon (ferde vetítés: a látómező a talajon paralelogramma), kicsit bővítve: a kép
	# alsó széle alatt álló alakok feje még belelóg
	var lr := Rect2(vilagba(Vector2.ZERO), Vector2.ZERO)
	for q in [Vector2(vm.x, 0.0), vm, Vector2(0.0, vm.y)]: lr = lr.expand(vilagba(q))
	nezet.lathato_ter = lr.grow(8.0)
	# a kamera forgatása a cél felé simul
	if absf(angle_difference(kam_forgas, kam_cel_forgas)) > 0.0005:
		kam_forgas = lerp_angle(kam_forgas, kam_cel_forgas, clampf(delta * 7.0, 0.0, 1.0))
		if absf(angle_difference(kam_forgas, kam_cel_forgas)) <= 0.0005: kam_forgas = kam_cel_forgas
		_kamera_frissit()
	if hang != null:
		hang.frissit(delta, szim, szim.fazis == "csata" and not szunet)
		# a faltörő kos ütései (a kos lendületének becsapódásaira, lásd TcNezet._kos_lendul)
		if szim.ostrom and nezet != null:
			for hol in nezet.kos_utesek: hang.kos_utes(hol)
			nezet.kos_utesek.clear()
	_frissit_ui()
	if sugo_tipp != null:
		_tipp_ido -= delta
		if _tipp_ido <= 0.0: _tipp_el()
	_vsync_igazit(delta)
	if szim.fazis == "vege" and eredmeny_panel == null:
		_uj_esemenyek()
		_eredmeny_mutat()

# ── Alkalmazkodó vsync ──
# Az ANGLE (Direct3D 11: a Godot ezt használja az Intel HD kártyákon) vsyncje a 16,7 ms-nál csak kicsit lassabb
# képkockát is a következő függőleges visszafutásig tartja: 60 Hz-es kijelzőn 60 helyett rögtön 30 kép/mp (a
# nagy csatákban 23-27 ms-os képkockák mind 33 ms-osak lettek). Ha a csata tartósan nem fér bele a kijelző
# frissítésébe, a vsync a csata idejére kikapcsol, és a képkockaszámot a kijelző frissítése korlátozza (mint az
# adaptív vsync); ha újra belefér, visszakapcsol. A csata végén az eredeti beállítás áll vissza.
var _vs_eredeti: int = -1
var _vs_max_fps: int = 0
var _vs_ki: bool = false
var _vs_valt: int = 0
var _vs_ido: float = 0.0
var _vs_db: int = 0

func _vsync_igazit(delta: float) -> void:
	if DisplayServer.get_name() == "headless": return
	if _vs_eredeti < 0:
		_vs_eredeti = DisplayServer.window_get_vsync_mode()
		_vs_max_fps = Engine.max_fps
	if _vs_eredeti == DisplayServer.VSYNC_DISABLED: return
	_vs_ido += delta
	_vs_db += 1
	if _vs_ido < 1.5: return
	var atlag := _vs_ido / float(_vs_db)
	_vs_ido = 0.0
	_vs_db = 0
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz < 30.0: hz = 60.0
	var keret := 1.0 / hz
	if not _vs_ki and atlag > keret * 1.15:
		_vs_ki = true
		_vs_valt += 1
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = roundi(hz)
	elif _vs_ki and atlag < keret * 1.03 and _vs_valt < 3:
		# (ha többször is visszaesett, a csata végéig kikapcsolva marad: ne villogjon)
		_vs_ki = false
		_vsync_vissza()

func _vsync_vissza() -> void:
	if _vs_eredeti < 0: return
	DisplayServer.window_set_vsync_mode(_vs_eredeti)
	Engine.max_fps = _vs_max_fps

func _exit_tree() -> void:
	if _vs_ki:
		_vs_ki = false
		_vsync_vissza()

## Tesztekhez: a csata léptetése a képkockáktól függetlenül (mp, a játékidőben)
func leptet(mp: float) -> void:
	var n := int(mp / Szim.LEPES)
	for i in n:
		if szim.fazis != "csata": break
		szim.lep()
	_uj_esemenyek()

# ── Kamera ───────────────────────────────────────────────────────

func _kamera_frissit() -> void:
	var vm := _kepernyo()
	kam_zoom = clampf(kam_zoom, ZOOM_MIN, ZOOM_MAX)
	# a kép ne lógjon ki a csatatérről (ha elfér rajta): a látómező a talajon (elforgatva, a rövidüléssel)
	# befoglaló téglalapja
	var hw := vm.x * 0.5 / kam_zoom
	var hh := (vm.y - FELSO_M - ALSO_M) * 0.5 / kam_zoom
	var cf0 := absf(cos(kam_forgas))
	var sf0 := absf(sin(kam_forgas))
	var fel := Vector2(cf0 * hw + sf0 * hh / Alakok.KF, sf0 * hw + cf0 * hh / Alakok.KF)
	kam_poz.x = clampf(kam_poz.x, fel.x, A.TER_W - fel.x) if fel.x * 2.0 < A.TER_W else A.TER_W * 0.5
	kam_poz.y = clampf(kam_poz.y, fel.y, A.TER_H - fel.y) if fel.y * 2.0 < A.TER_H else A.TER_H * 0.5
	var kozep := Vector2(vm.x * 0.5, FELSO_M + (vm.y - FELSO_M - ALSO_M) * 0.5)
	var rez := Vector2.ZERO
	if _razkodas > 0.01:
		var tm := float(Time.get_ticks_msec()) * 0.001
		rez = Vector2(sin(tm * 71.0), cos(tm * 53.0)) * _razkodas * 4.0
	# 2,5D ferde vetítés: a talaj a kamera forgatásával elfordítva, függőlegesen megrövidülve (a kamera kissé
	# hátulról, felülről néz); az álló alakokat a rajzoló fordítja a képernyő felé
	var cf := cos(kam_forgas)
	var sf := sin(kam_forgas)
	var xa := Vector2(cf, -sf * Alakok.KF) * kam_zoom
	var ya := Vector2(sf, cf * Alakok.KF) * kam_zoom
	vilag_reteg.transform = Transform2D(xa, ya, kozep + rez - xa * kam_poz.x - ya * kam_poz.y)
	nezet.nagyitas = kam_zoom
	nezet.vetites(kam_forgas, kam_poz, (vm.y - FELSO_M - ALSO_M) * 0.5 / (kam_zoom * Alakok.KF))
	# ha kívülről (nem a sima nagyítás) állították a nagyítást, a cél is az legyen
	if not _zoom_lep and absf(kam_zoom - _utolso_zoom) > 0.0001: kam_cel_zoom = kam_zoom
	_utolso_zoom = kam_zoom

func _kepernyo() -> Vector2:
	return ui.size if ui != null and ui.size.x > 10.0 else Vector2(1280, 720)

func vilagba(kep: Vector2) -> Vector2:
	return vilag_reteg.transform.affine_inverse() * kep

func kepre(v: Vector2) -> Vector2:
	return vilag_reteg.transform * v

func _kamera_mozgas(delta: float) -> void:
	var ir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): ir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): ir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): ir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): ir.y += 1.0
	# a képernyő széle (csak ha az ablak az előtérben van, és nincs lenyomva gomb; érintőképernyőn nem: ott az
	# „egér” a koppintás helyén marad)
	if DisplayServer.window_is_focused() and not _bal_le and not _jobb_le and ui != null and not erintos():
		var m := ui.get_local_mouse_position()
		var vm := _kepernyo()
		if m.x >= 0.0 and m.y >= 0.0 and m.x <= vm.x and m.y <= vm.y:
			if m.x < 8.0: ir.x -= 1.0
			elif m.x > vm.x - 8.0: ir.x += 1.0
			if m.y < 6.0: ir.y -= 1.0
			elif m.y > vm.y - 6.0: ir.y += 1.0
	if ir != Vector2.ZERO:
		var n := ir.normalized()
		kam_poz += _kep_irany(n) * 620.0 * delta / kam_zoom
		_kamera_frissit()

## Érintőképernyős (böngészős, telefonos) játék: a játék /root/Erintes csomópontja fordítja az érintést
## egéreseményekre (ha a játékban nincs ilyen, ez mindig hamis)
func erintos() -> bool:
	var e := get_node_or_null("/root/Erintes")
	return e != null and bool(e.get("aktiv"))

## Érintőképernyőn: az egy ujjas húzás a mezőn a kamerát mozgatja (középső gomb); felállításkor a saját
## egységen bal gomb (az egység áthelyezése), a felület gombjain és paneljein is bal
func erintes_huzas(kep: Vector2) -> int:
	if szim == null or get_viewport().gui_get_hovered_control() != fogo: return MOUSE_BUTTON_LEFT
	if szim.fazis == "telepites" and en >= 0 and _blokk_itt(vilagba(kep), en) != null: return MOUSE_BUTTON_LEFT
	return MOUSE_BUTTON_MIDDLE

## Érintőképernyőn a két ujjas gesztus: csippentés = nagyítás, húzás = mozgatás, csavarás = forgatás
func erintes_gesztus(kozep: Vector2, szorzo: float, eltol: Vector2, forgas: float) -> void:
	if szim == null or eredmeny_panel != null: return
	if not is_equal_approx(szorzo, 1.0): _nagyit(szorzo, kozep)
	kam_poz -= _kep_irany(eltol) / kam_zoom
	# (az ujjakkal együtt: az óramutató járásával egyező csavarás a képet is arra forgatja)
	if forgas != 0.0:
		kam_forgas = wrapf(kam_forgas - forgas, -PI, PI)
		kam_cel_forgas = kam_forgas
	_kamera_frissit()

## Egy képernyő-irány (képpontban) a talajon (a kamera forgatása és a rövidülés szerint)
func _kep_irany(v: Vector2) -> Vector2:
	return nezet._ux * v.x + nezet._uv * v.y

func _nagyit(szorzo: float, kep_pont: Vector2) -> void:
	kam_cel_zoom = clampf(kam_cel_zoom * szorzo, ZOOM_MIN, ZOOM_MAX)
	_zoom_pont = kep_pont

# a nagyítás a cél felé simul (a kurzor alatti világpont helyben marad)
func _zoom_simit(delta: float) -> void:
	if absf(kam_cel_zoom - kam_zoom) < 0.0005: return
	var elotte := vilagba(_zoom_pont)
	_zoom_lep = true
	var k := clampf(delta * 14.0, 0.0, 1.0)
	kam_zoom = exp(lerpf(log(kam_zoom), log(kam_cel_zoom), k))
	if absf(kam_cel_zoom - kam_zoom) < 0.0005: kam_zoom = kam_cel_zoom
	_kamera_frissit()
	var utana := vilagba(_zoom_pont)
	kam_poz += elotte - utana
	_kamera_frissit()
	_zoom_lep = false

# ── Egér ─────────────────────────────────────────────────────────

func _blokk_itt(v: Vector2, csak_oldal: int = -1) -> Szim.Blokk:
	# (2,5D: az alakok a talppontjuk fölött látszanak – a kurzor alatti talajpont mögött is keres, a képen
	# lefelé, egy alaknyi magasságig)
	for k in 3:
		var b := _blokk_itt1(v + nezet._uv * (float(k) * 1.6 * Alakok.CZ), csak_oldal)
		if b != null: return b
	return null

func _blokk_itt1(v: Vector2, csak_oldal: int = -1) -> Szim.Blokk:
	var legjobb: Szim.Blokk = null
	var d := INF
	for b in szim.blokkok:
		if b.allapot >= Szim.KIVONULT: continue
		if csak_oldal >= 0 and b.oldal != csak_oldal: continue
		if not szim.lathato(b, nezo_oldal()): continue
		var loc := (v - b.poz).rotated(-(b.irany.angle() + PI * 0.5))
		var tures := 5.0 / kam_zoom
		if absf(loc.x) <= b.szel * 0.5 + tures and absf(loc.y) <= b.mely * 0.5 + tures + 6.0 / kam_zoom:
			var x := v.distance_squared_to(b.poz)
			if x < d:
				d = x
				legjobb = b
	return legjobb

func _fogo_input(ev: InputEvent) -> void:
	if szim == null or eredmeny_panel != null: return
	# a nyitott súgón kívülre kattintva a súgó bezárul (ez a kattintás csak bezár)
	if sugo_panel != null and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_sugo(false)
		fogo.accept_event()
		return
	if ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		_utolso_eger = mm.position
		var v := vilagba(mm.position)
		var b := _blokk_itt(v)
		nezet.rajta = b.id if b != null else -1
		_info(b, mm.position)
		if _kozep_le:
			if mm.alt_pressed or mm.shift_pressed:
				# Alt / Shift + középső gomb: forgatás
				kam_forgas = wrapf(kam_forgas + mm.relative.x * 0.006, -PI, PI)
				kam_cel_forgas = kam_forgas
			else:
				kam_poz -= _kep_irany(mm.relative) / kam_zoom
			_kamera_frissit()
		if _bal_le:
			if _telepit_huz:
				for id in _huz_eltolas:
					szim.telepit(int(id), v + _huz_eltolas[id])
			elif mm.position.distance_to(_bal_kezd) > 6.0:
				var a := vilagba(_bal_kezd)
				nezet.doboz = Rect2(a, Vector2.ZERO).expand(v)
				nezet.doboz_lathato = true
		if _jobb_le and mm.position.distance_to(_jobb_kezd_kep) > 12.0 and not kijelolt.is_empty():
			nezet.vonal_lathato = true
			nezet.vonal_a = _jobb_kezd
			nezet.vonal_b = v
			nezet.vonal_elonezet = _vonal_elonezet(_jobb_kezd, v)
		return
	if not ev is InputEventMouseButton: return
	var mb := ev as InputEventMouseButton
	var v := vilagba(mb.position)
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed: _nagyit(1.12, mb.position)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed: _nagyit(1.0 / 1.12, mb.position)
		MOUSE_BUTTON_MIDDLE:
			_kozep_le = mb.pressed
		MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_bal_le = true
				_bal_kezd = mb.position
				var b := _blokk_itt(v, en) if en >= 0 else null
				var tobb := mb.shift_pressed or mb.ctrl_pressed
				if mb.double_click and b != null:
					_valaszt_tipus(b)
					return
				if b != null:
					if tobb:
						if kijelolt.has(b.id): _kijelol_ki(b)
						else: _kijelol_be(b)
					elif not kijelolt.has(b.id):
						kijelolt.clear()
						_kijelol_be(b)
					# felállításkor a kijelöltek húzhatók
					if szim.fazis == "telepites" and kijelolt.has(b.id):
						_telepit_huz = true
						_huz_eltolas.clear()
						for id in kijelolt:
							var x := szim.blokk(int(id))
							if x != null: _huz_eltolas[id] = x.poz - v
			else:
				if _bal_le and not _telepit_huz:
					if nezet.doboz_lathato:
						if not (mb.shift_pressed or mb.ctrl_pressed): kijelolt.clear()
						for b in szim.blokkok:
							if b.oldal == en and b.aktiv() and nezet.doboz.has_point(b.poz): _kijelol_be(b)
					elif (en < 0 or _blokk_itt(v, en) == null) and not (mb.shift_pressed or mb.ctrl_pressed):
						kijelolt.clear()
				_bal_le = false
				_telepit_huz = false
				nezet.doboz_lathato = false
				_kartyak_frissit()
		MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_jobb_le = true
				_jobb_dupla = mb.double_click
				_jobb_kezd = v
				_jobb_kezd_kep = mb.position
			else:
				if _jobb_le and not kijelolt.is_empty():
					var ids := kijelolt.keys()
					if nezet.vonal_lathato:
						szim.parancs_vonal(ids, _jobb_kezd, v)
					else:
						var e := _blokk_itt(v, 1 - en)
						var kapu := _kapu_itt(v)
						var fal := _fal_itt(v)
						if e != null and szim.fazis == "csata":
							szim.parancs_tamad(ids, e.id)
						elif kapu >= 0 and szim.fazis == "csata":
							szim.parancs_kapu(ids, kapu)
						elif fal != Vector2.INF and szim.parancs_fal(ids, fal):
							# a falra kattintva: a kos a falszakaszt (a közeli kaput) töri, a többi oda megy
							var tobbi: Array = []
							for id in ids:
								var x := szim.blokk(int(id))
								if x != null and x.parancs != "fal" and x.parancs != "kapu": tobbi.append(id)
							if not tobbi.is_empty(): szim.parancs_mozog(tobbi, v, Vector2.ZERO, _jobb_dupla)
						else:
							# dupla jobb klikk: futva
							szim.parancs_mozog(ids, v, Vector2.ZERO, _jobb_dupla)
					_parancssor_frissit()
				_jobb_le = false
				_jobb_dupla = false
				nezet.vonal_lathato = false

## Ostromnál: a még álló kapu a pont közelében (a sorszáma), különben -1 – csak a támadónak
func _kapu_itt(v: Vector2) -> int:
	if not szim.ostrom or en < 0 or szim.vedo == en: return -1
	# (2,5D: a kapuszárny a fal síkjában a magasba nyúlik – a kurzor alatti talajpont a kapu talppontja mögött is
	# lehet, a képen felfelé, a kapu magasságáig)
	for z in [0.0, NezetS.FAL_Z * 0.35, NezetS.FAL_Z * 0.7]:
		var q: Vector2 = v + nezet._uv * (Alakok.CZ * float(z))
		for i in szim.terkep.kapuk.size():
			var k: Dictionary = szim.terkep.kapuk[i]
			if float(k["hp"]) > 0.0 and q.distance_to(k["p"]) < A.CELLA * 1.8: return i
	return -1

## Ostromnál: a kurzor alatt (a 2,5D vetítésben a fal magasságáig) a település fala – a talppontja, különben INF
## (csak a támadónak)
func _fal_itt(v: Vector2) -> Vector2:
	if not szim.ostrom or en < 0 or szim.vedo == en: return Vector2.INF
	for z in [0.0, NezetS.FAL_Z * 0.5, NezetS.FAL_Z]:
		var q: Vector2 = v + nezet._uv * (Alakok.CZ * float(z))
		var t := szim.terkep.cella(q)
		if t == A.FAL or t == A.TORONY or t == A.KAPU: return q
	return Vector2.INF

func _vonal_elonezet(a: Vector2, c: Vector2) -> Array:
	var lista: Array = []
	for id in kijelolt:
		var b := szim.blokk(int(id))
		if b != null and b.aktiv(): lista.append(b)
	if lista.is_empty(): return []
	var vv := c - a
	var ir := vv.orthogonal().normalized()
	if ir.dot(Szim.elore(maxi(en, 0))) < 0.0: ir = -ir
	var tengely := vv.normalized()
	var ossz := 0.0
	for b in lista: ossz += (b as Szim.Blokk).szel
	var hely := maxf(vv.length(), ossz + 8.0 * (lista.size() - 1))
	var koz := (hely - ossz) / float(maxi(1, lista.size() - 1)) if lista.size() > 1 else 0.0
	var x := -hely * 0.5
	var r: Array = []
	lista.sort_custom(func(p: Szim.Blokk, q: Szim.Blokk) -> bool: return p.poz.dot(tengely) < q.poz.dot(tengely))
	for b in lista:
		var bb: Szim.Blokk = b
		var p := (a + c) * 0.5 + tengely * (x + bb.szel * 0.5) if lista.size() > 1 else (a + c) * 0.5
		x += bb.szel + koz
		r.append([p, ir, bb.szel, bb.mely])
	return r

# az egér alatti egység neve, létszáma és morálja (a mező fölött, a kurzor mellett)
func _info(b: Szim.Blokk, hol: Vector2) -> void:
	if b == null:
		info_lbl.visible = false
		return
	var ell := "" if b.oldal == nezo_oldal() else Localization_t("TC_ENEMY", [""]).strip_edges() + " "
	info_lbl.text = ell + kartya_tipp(b).replace("\n", "  ·  ")
	info_lbl.add_theme_color_override("font_color", Color(0.75, 0.87, 1.0) if b.oldal == nezo_oldal() else Color(1.0, 0.75, 0.68))
	info_lbl.visible = true
	info_lbl.reset_size()
	info_lbl.position = Vector2(clampf(hol.x + 16.0, 4.0, _kepernyo().x - info_lbl.size.x - 4.0), hol.y + 18.0)

func _kijelol_be(b: Szim.Blokk) -> void:
	if b.oldal != en: return
	kijelolt[b.id] = true
	if b.csoport >= 0:
		for x in szim.blokkok:
			if x.oldal == en and x.csoport == b.csoport and x.aktiv(): kijelolt[x.id] = true

func _kijelol_ki(b: Szim.Blokk) -> void:
	kijelolt.erase(b.id)

# dupla kattintás: az összes ugyanilyen típusú saját egység
func _valaszt_tipus(b: Szim.Blokk) -> void:
	kijelolt.clear()
	for x in szim.blokkok:
		if x.oldal == en and x.aktiv() and x.tipus == b.tipus: kijelolt[x.id] = true
	_kartyak_frissit()

# ── Billentyűk ───────────────────────────────────────────────────

func _input(ev: InputEvent) -> void:
	if szim == null: return
	# az első kattintás (bárhol, a „Bővebben…”-en kívül) eltünteti a tippet – a kattintást nem nyeli el
	if sugo_tipp != null and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] \
			and not sugo_tipp.get_global_rect().has_point((ev as InputEventMouseButton).position):
		_tipp_el()
	if not ev is InputEventKey: return
	var k := ev as InputEventKey
	# a térkép gyorsbillentyűi ne fussanak a csata alatt
	get_viewport().set_input_as_handled()
	if not k.pressed or k.echo: return
	if eredmeny_panel != null:
		if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_ESCAPE: _befejez()
		return
	# „?” (billentyűzetkiosztástól függetlenül: a magyaron Shift+vessző) – a részletes súgó
	if k.unicode == 63:
		_sugo(sugo_panel == null)
		return
	match k.keycode:
		KEY_SPACE:
			if szim.fazis == "telepites": _indit_csata()
			else: _szunet_valt()
		KEY_1: _sebesseg(1.0)
		KEY_2: _sebesseg(2.0)
		KEY_3: _sebesseg(4.0)
		KEY_G: _csoport()
		KEY_BACKSPACE: szim.parancs_all(kijelolt.keys())
		KEY_C: alakzat("")
		KEY_Q: alakzat("falanx")
		KEY_T: alakzat("teknos")
		KEY_V: alakzat("ek")
		KEY_X: alakzat("laza")
		KEY_O: alakzat("oszlop")
		KEY_K: alakzat("carre")
		KEY_N: alakzat("vonal")
		KEY_E: kepesseg_betu(0)
		KEY_U: kepesseg_betu(1)
		KEY_F: tuz_valt()
		KEY_R: futas_valt()
		KEY_B: tartalek_valt()
		KEY_F1, KEY_H: _sugo(sugo_panel == null)
		KEY_ESCAPE:
			if sugo_panel != null: _sugo(false)
			else:
				kijelolt.clear()
				_kartyak_frissit()
		KEY_A:
			if k.ctrl_pressed:
				for b in szim.blokkok:
					if b.oldal == en and b.aktiv(): kijelolt[b.id] = true
				_kartyak_frissit()
		KEY_COMMA: kam_cel_forgas = wrapf(kam_cel_forgas - PI * 0.25, -PI, PI)
		KEY_PERIOD: kam_cel_forgas = wrapf(kam_cel_forgas + PI * 0.25, -PI, PI)
		KEY_HOME: kam_cel_forgas = kam_alap_forgas
		KEY_EQUAL, KEY_KP_ADD: _nagyit(1.15, _kepernyo() * 0.5)
		KEY_MINUS, KEY_KP_SUBTRACT: _nagyit(1.0 / 1.15, _kepernyo() * 0.5)

func _csoport() -> void:
	if kijelolt.is_empty(): return
	# ha mind egy csoportban vannak: a csoport felbomlik; különben új csoport
	var elso := -2
	var egy := true
	for id in kijelolt:
		var b := szim.blokk(int(id))
		if b == null: continue
		if elso == -2: elso = b.csoport
		elif b.csoport != elso: egy = false
	var uj := -1 if (egy and elso >= 0) else _csoport_kov
	if uj >= 0: _csoport_kov += 1
	for id in kijelolt:
		var b := szim.blokk(int(id))
		if b != null: b.csoport = uj
	_kartyak_frissit()

## A kijelöltek alakzata ("" zárt rend, "falanx", "teknos", "ek", "laza"…; a család betűje szerint a népük
## megfelelő alakzata, pl. Q: szarisszás falanx, sparabara) – amelyik nem ismeri, marad
func alakzat(nev: String) -> void:
	if kijelolt.is_empty(): return
	szim.parancs_alakzat(kijelolt.keys(), nev)
	_parancssor_frissit()
	_kartyak_frissit()

## Tüzelés szabadon / tartva (a lövészeknél): ha bármelyik szabadon tüzel, mind tartja, különben mind szabad
func tuz_valt() -> void:
	var szabad := false
	for b in _kijelolt_blokkok():
		if b.lovo and b.tuz_szabad: szabad = true
	szim.parancs_tuz(kijelolt.keys(), not szabad)
	_parancssor_frissit()

func futas_valt() -> void:
	var fut := false
	for b in _kijelolt_blokkok():
		if b.futas: fut = true
	szim.parancs_futas(kijelolt.keys(), not fut)
	_parancssor_frissit()

func tartalek_valt() -> void:
	var t := false
	for b in _kijelolt_blokkok():
		if b.tartalek: t = true
	szim.parancs_tartalek(kijelolt.keys(), not t)
	_parancssor_frissit()
	_kartyak_frissit()

func _kijelolt_blokkok() -> Array:
	var r: Array = []
	for id in kijelolt:
		var b := szim.blokk(int(id))
		if b != null and b.aktiv(): r.append(b)
	return r

func _sebesseg(s: float) -> void:
	if halo != null:
		# élő csata: a házigazda dönt (ember ember ellen a másik fél jóváhagyásával)
		halo.sebesseg_ker(s)
		return
	gyors = s
	szunet = false

func _szunet_valt() -> void:
	if halo != null:
		halo.szunet_ker()
		return
	szunet = not szunet

func _indit_csata() -> void:
	if szim.fazis != "telepites": return
	if halo != null:
		# élő csata: „kész” (a csata akkor indul, ha mindkét fél kész, vagy lejárt a felállítás ideje)
		halo.kesz_valt()
		return
	szim.indit()
	if hang != null: hang.szol("kurt", null, -3.0)
	if telep_panel != null:
		telep_panel.queue_free()
		telep_panel = null

func _visszavonul() -> void:
	if szim.fazis != "csata": return
	if not _vissza_biztos:
		_vissza_biztos = true
		btn_vissza.text = tr("TC_WITHDRAW_SURE")
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			_vissza_biztos = false
			if is_instance_valid(btn_vissza): btn_vissza.text = tr("TC_WITHDRAW"))
		return
	szim.visszavonul(en)

# ── Felület ──────────────────────────────────────────────────────

func _panel_stilus(alfa: float = 0.92) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.07, alfa)
	sb.border_color = Color(0.62, 0.50, 0.30)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10; sb.content_margin_right = 10
	sb.content_margin_top = 6; sb.content_margin_bottom = 6
	return sb

func _cimke(szoveg: String, meret: int = 15, szin: Color = Color(0.95, 0.88, 0.72)) -> Label:
	var l := Label.new()
	l.text = szoveg
	l.add_theme_font_size_override("font_size", meret)
	l.add_theme_color_override("font_color", szin)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _gomb(szoveg: String, f: Callable, szel: float = 0.0) -> Button:
	var b := Button.new()
	b.text = szoveg
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	if szel > 0.0: b.custom_minimum_size = Vector2(szel, 30)
	b.pressed.connect(f)
	return b

func _epit_ui() -> void:
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_reteg.add_child(ui)
	ui.resized.connect(_kamera_frissit)
	fogo = Control.new()
	fogo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fogo.mouse_filter = Control.MOUSE_FILTER_STOP
	fogo.gui_input.connect(_fogo_input)
	ui.add_child(fogo)
	# ── felső sáv ──
	var felso := PanelContainer.new()
	felso.add_theme_stylebox_override("panel", _panel_stilus())
	felso.set_anchors_preset(Control.PRESET_TOP_WIDE)
	felso.custom_minimum_size = Vector2(0, FELSO_M)
	ui.add_child(felso)
	var sor := HBoxContainer.new()
	sor.add_theme_constant_override("separation", 10)
	felso.add_child(sor)
	lbl_cim = _cimke(str(_cfg.get("cim", "")), 16)
	lbl_cim.custom_minimum_size.x = 250
	lbl_cim.clip_text = true
	sor.add_child(lbl_cim)
	ero_sav = EroSav.new()
	ero_sav.csata = self
	ero_sav.custom_minimum_size = Vector2(240, 22)
	ero_sav.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ero_sav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ero_sav.tooltip_text = tr("TC_BALANCE_TIP")
	sor.add_child(ero_sav)
	lbl_ido = _cimke("", 15)
	lbl_ido.custom_minimum_size.x = 96
	lbl_ido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sor.add_child(lbl_ido)
	# az időjárás, a napszak (és hatása a súgóban)
	var idk := "TC_WEATHER_" + szim.idojaras.to_upper()
	var lbl_idj := _cimke(tr(idk), 14, Color(0.85, 0.88, 0.95) if szim.idojaras != "alkony" else Color(1.0, 0.8, 0.6))
	# (a súgóban a látótáv is: a harc ködében ez sokat számít)
	lbl_idj.tooltip_text = tr(idk + "_TIP") + "\n" + Localization_t("TC_SIGHT_TIP", [roundi(float(A.LATAS_IDO.get(szim.idojaras, 1.0)) * 100.0)])
	# (a táj: a biom és a csatatér elrendezése – lásd tc_taj.gd)
	lbl_idj.tooltip_text += "\n" + tr("TC_BIOME_" + szim.terkep.biom.to_upper()) + " · " + tr("TC_LAYOUT_" + szim.terkep.sablon.to_upper())
	# (a nagyon nagy csatában egy alak több katonát jelent: a kártyán a valódi létszám)
	if nezet != null and nezet.alak_oszto > 1.01:
		lbl_idj.tooltip_text += "\n" + Localization_t("TC_FIGURE_SCALE", [snappedf(nezet.alak_oszto, 0.1)])
	lbl_idj.mouse_filter = Control.MOUSE_FILTER_PASS
	sor.add_child(lbl_idj)
	if szim.ostrom:
		lbl_ostrom = _cimke("", 14, Color(1.0, 0.85, 0.6))
		lbl_ostrom.tooltip_text = tr("TC_SIEGE_TIP")
		lbl_ostrom.mouse_filter = Control.MOUSE_FILTER_PASS
		sor.add_child(lbl_ostrom)
	btn_szunet = _gomb("II", _szunet_valt, 40)
	btn_szunet.tooltip_text = tr("TC_PAUSE_TIP")
	sor.add_child(btn_szunet)
	for s in [[1.0, "1×"], [2.0, "2×"], [4.0, "4×"]]:
		var sv: float = s[0]
		var b := _gomb(str(s[1]), func() -> void: _sebesseg(sv), 40)
		b.tooltip_text = tr("TC_SPEED_TIP")
		btn_seb.append([b, sv])
		sor.add_child(b)
	btn_vissza = _gomb(tr("TC_WITHDRAW"), _visszavonul)
	btn_vissza.tooltip_text = tr("TC_WITHDRAW_TIP")
	sor.add_child(btn_vissza)
	var sg := _gomb("?", func() -> void: _sugo(sugo_panel == null), 34)
	sg.tooltip_text = tr("TC_HELP_TITLE") + " (F1)"
	sor.add_child(sg)
	# ── alsó sáv: az egységkártyák ──
	var also := PanelContainer.new()
	also.add_theme_stylebox_override("panel", _panel_stilus())
	also.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	also.offset_top = -ALSO_M
	ui.add_child(also)
	var also_sor := HBoxContainer.new()
	also_sor.add_theme_constant_override("separation", 8)
	also.add_child(also_sor)
	var gorgo := ScrollContainer.new()
	gorgo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gorgo.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	also_sor.add_child(gorgo)
	kartya_sor = HBoxContainer.new()
	kartya_sor.add_theme_constant_override("separation", 4)
	gorgo.add_child(kartya_sor)
	minimap = Minimap.new()
	minimap.csata = self
	minimap.custom_minimum_size = Vector2(150, 96)
	minimap.tooltip_text = tr("TC_MINIMAP_TIP")
	also_sor.add_child(minimap)
	# ── parancssor: alakzat, tüzelés, futás, tartalék (a kijelöltekre) ──
	parancs_sor = PanelContainer.new()
	parancs_sor.add_theme_stylebox_override("panel", _panel_stilus(0.9))
	parancs_sor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	parancs_sor.offset_left = 8
	parancs_sor.offset_top = -ALSO_M - 46
	parancs_sor.offset_bottom = -ALSO_M - 4
	parancs_sor.visible = false
	ui.add_child(parancs_sor)
	var ps := HBoxContainer.new()
	ps.add_theme_constant_override("separation", 4)
	parancs_sor.add_child(ps)
	_taktika_doboz = HBoxContainer.new()
	_taktika_doboz.add_theme_constant_override("separation", 4)
	ps.add_child(_taktika_doboz)
	var elv := VSeparator.new()
	ps.add_child(elv)
	btn_tuz = _gomb(tr("TC_FIRE_FREE"), tuz_valt)
	btn_tuz.tooltip_text = tr("TC_FIRE_TIP") + "  [F]"
	ps.add_child(btn_tuz)
	btn_fut = _gomb(tr("TC_WALK"), futas_valt)
	btn_fut.tooltip_text = tr("TC_RUN_TIP") + "  [R]"
	ps.add_child(btn_fut)
	btn_tartalek = _gomb(tr("TC_RESERVE"), tartalek_valt)
	btn_tartalek.tooltip_text = tr("TC_RESERVE_TIP") + "  [B]"
	ps.add_child(btn_tartalek)
	# ── események (bal oldalt) ──
	esemeny_rtl = RichTextLabel.new()
	esemeny_rtl.bbcode_enabled = true
	esemeny_rtl.fit_content = true
	esemeny_rtl.scroll_active = false
	esemeny_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	esemeny_rtl.position = Vector2(12, FELSO_M + 10)
	esemeny_rtl.size = Vector2(360, 140)
	esemeny_rtl.add_theme_font_size_override("normal_font_size", 14)
	esemeny_rtl.add_theme_constant_override("outline_size", 4)
	esemeny_rtl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ui.add_child(esemeny_rtl)
	# ── az egér alatti egység adatai ──
	info_lbl = _cimke("", 13)
	info_lbl.add_theme_constant_override("outline_size", 5)
	info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	info_lbl.visible = false
	ui.add_child(info_lbl)
	# ── szünet felirat ──
	lbl_szunet = _cimke(tr("TC_PAUSED"), 28, Color(1.0, 0.92, 0.6))
	lbl_szunet.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_szunet.position.y = FELSO_M + 14
	lbl_szunet.add_theme_constant_override("outline_size", 6)
	lbl_szunet.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ui.add_child(lbl_szunet)
	# ── felállítás ──
	telep_panel = PanelContainer.new()
	telep_panel.add_theme_stylebox_override("panel", _panel_stilus(0.95))
	ui.add_child(telep_panel)
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", 6)
	telep_panel.add_child(tb)
	var tc := _cimke(tr("TC_DEPLOY_TITLE"), 20, Color(1.0, 0.9, 0.55))
	tc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(tc)
	var th := _cimke(tr("TC_DEPLOY_HINT_TOUCH" if erintos() else "TC_DEPLOY_HINT"), 14)
	th.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	th.custom_minimum_size.x = 440
	th.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tb.add_child(th)
	var ti := _gomb(tr("TC_START"), _indit_csata)
	btn_indit = ti
	ti.custom_minimum_size = Vector2(0, 36)
	ti.add_theme_font_size_override("font_size", 17)
	tb.add_child(ti)
	telep_panel.position = Vector2(0, FELSO_M + 8)
	_kozepre(telep_panel)

func _kozepre(p: Control, y: float = -1.0) -> void:
	await get_tree().process_frame
	if not is_instance_valid(p): return
	var vm := _kepernyo()
	p.reset_size()
	p.position.x = (vm.x - p.size.x) * 0.5
	if y >= 0.0: p.position.y = y
	elif y < -1.5: p.position.y = (vm.y - p.size.y) * 0.5

func _frissit_ui() -> void:
	if lbl_ido == null: return
	var t := int(szim.ido)
	var k := int(szim.ido_korlat)
	lbl_ido.text = "%d:%02d / %d:%02d" % [t / 60, t % 60, k / 60, k % 60]
	lbl_szunet.visible = szunet and szim.fazis == "csata"
	btn_szunet.text = "▶" if szunet else "II"
	for par in btn_seb:
		var b: Button = par[0]
		b.modulate = Color(1.0, 0.9, 0.45) if float(par[1]) == gyors and not szunet else Color(1, 1, 1, 0.75)
	btn_vissza.disabled = szim.fazis != "csata"
	# a sávok, a térképecske és a kártyák másodpercenként ötször frissülnek (gyenge gépen is olcsó)
	var most := Time.get_ticks_msec()
	if most - _ui_frissitve >= 200:
		_ui_frissitve = most
		ero_sav.queue_redraw()
		minimap.queue_redraw()
		for kk in kartyak: (kk as Control).queue_redraw()
		_parancssor_frissit()
		if lbl_ostrom != null:
			# a kapuk (a fő-, az oldal-, a fellegvár kapuja), a tér és a fellegvár elfoglalása, a felmentő sereg, az akna
			var s := ""
			var allo := 0
			var kulso := 0
			for i in szim.terkep.kapuk.size():
				var kk: Dictionary = szim.terkep.kapuk[i]
				var hp := float(kk["hp"])
				if bool(kk.get("fellegvar", false)):
					s += "%s: %s   " % [tr("TC_SIEGE_CITADEL_GATE"), ("%d%%" % roundi(hp)) if hp > 0.0 else tr("TC_SIEGE_BROKEN")]
					continue
				kulso += 1
				if hp > 0.0: allo += 1
				if i == 0: s += "%s: %s   " % [tr("TC_SIEGE_GATE"), ("%d%%" % roundi(hp)) if hp > 0.0 else tr("TC_SIEGE_BROKEN")]
			if kulso > 1: s += Localization_t("TC_SIEGE_GATES", [allo, kulso]) + "   "
			if not szim.terkep.resek.is_empty(): s += Localization_t("TC_SIEGE_BREACHES", [szim.terkep.resek.size() / 3]) + "   "
			if szim.foter_kesz: s += tr("TC_SIEGE_PLAZA_TAKEN") + "   "
			elif szim.foter_ido > 0.0: s += Localization_t("TC_SIEGE_PLAZA", [int(ceil(A.FOTER_IDO * (A.FOTER_KESZ if szim.terkep.fellegvar != Vector2.INF else 1.0) - szim.foter_ido))]) + "   "
			if szim.fellegvar_ido > 0.0: s += Localization_t("TC_SIEGE_CITADEL", [int(ceil(A.FELLEGVAR_IDO - szim.fellegvar_ido))]) + "   "
			if szim.felmentes_ido > szim.ido:
				var fm := int(ceil(szim.felmentes_ido - szim.ido))
				s += Localization_t("TC_SIEGE_RELIEF", ["%d:%02d" % [fm / 60, fm % 60]]) + "   "
			for bb in szim.blokkok:
				if bb.oldal == nezo_oldal() and bb.gep == "akna" and bb.akna > 0.0 and bb.aktiv():
					s += Localization_t("TC_SIEGE_MINE", [roundi(bb.akna / A.AKNA_IDO * 100.0)]) + "   "
			lbl_ostrom.text = s.strip_edges()

## A parancssor gombjai a kijelöltek szerint: csak azok az alakzatok és képességek, amelyeket a kijelöltek (a
## népük) ismernek, a népük nevén (pl. a germánoknál a falanx pajzsfal, a makedónoknál szarisszás falanx), a
## súgóban a harcmodor rövid leírása; kiemelve, ami most be van állítva
func _parancssor_frissit() -> void:
	if parancs_sor == null: return
	var lista := _kijelolt_blokkok()
	parancs_sor.visible = not lista.is_empty() and szim.fazis != "vege"
	if lista.is_empty(): return
	_taktika_gombok(lista)
	for nev in _alakzat_gombok:
		var gb: Button = _alakzat_gombok[nev]
		var tudja := 0
		var ilyen := 0
		for b in lista:
			if str(nev) in szim.alakzat_lista(b):
				tudja += 1
				if b.alakzat == str(nev): ilyen += 1
		gb.disabled = tudja == 0
		gb.modulate = Color(1.0, 0.88, 0.4) if ilyen > 0 and ilyen == tudja else Color(1, 1, 1, 0.85 if tudja > 0 else 0.45)
	for nev in _kepesseg_gombok:
		var gb: Button = _kepesseg_gombok[nev]
		var kesz := 0
		var be := 0
		var tudja := 0
		var hatra := 999.0
		for b in lista:
			if not str(nev) in b.kepesseg: continue
			tudja += 1
			if szim.kepesseg_kesz(b, str(nev)): kesz += 1
			else: hatra = minf(hatra, szim.kepesseg_hatra(b, str(nev)))
			if (str(nev) == "portyaz" and b.portyaz) or (str(nev) == "beszivargas" and b.beszivarog): be += 1
		var nev_sz := tr(T.kepesseg_kulcs(str(nev)))
		gb.text = nev_sz if (kesz > 0 or hatra > 900.0) else "%s (%d)" % [nev_sz, int(ceil(hatra))]
		gb.disabled = tudja == 0 or (kesz == 0 and not str(nev) in T.KAPCSOLOK) or (szim.fazis != "csata" and not str(nev) in T.KAPCSOLOK)
		gb.modulate = Color(1.0, 0.88, 0.4) if be > 0 else Color(1, 1, 1, 0.9 if not gb.disabled else 0.5)
	var lovok := 0
	var szabad := false
	var fut := false
	var tart := false
	for b in lista:
		if b.lovo:
			lovok += 1
			if b.tuz_szabad: szabad = true
		if b.futas: fut = true
		if b.tartalek: tart = true
	btn_tuz.visible = lovok > 0
	btn_tuz.text = tr("TC_FIRE_FREE") if szabad else tr("TC_FIRE_HOLD")
	btn_tuz.modulate = Color(1, 1, 1) if szabad else Color(1.0, 0.6, 0.5)
	btn_fut.text = tr("TC_RUN") if fut else tr("TC_WALK")
	btn_fut.modulate = Color(1.0, 0.88, 0.4) if fut else Color(1, 1, 1, 0.85)
	btn_tartalek.modulate = Color(1.0, 0.88, 0.4) if tart else Color(1, 1, 1, 0.85)

# az alakzat- és képességgombok újraépítése, ha a kijelöltek ismerete (a gombok halmaza) változott
func _taktika_gombok(lista: Array) -> void:
	var alakz: Array = []
	var kep: Array = []
	var neva := {}
	for b in lista:
		var bb: Szim.Blokk = b
		for x in szim.alakzat_lista(bb):
			if not x in alakz:
				alakz.append(x)
				neva[x] = T.alakzat_kulcs(str(x), bb.tipus, bb.kinezet, bb.doktrina)
		for k in bb.kepesseg:
			if not k in kep: kep.append(k)
	var rend: Array = []
	for x in ALAKZAT_SOR:
		if x in alakz: rend.append(x)
	var kulcs := "|".join(rend) + "#" + "|".join(kep) + "#" + str(neva)
	if kulcs == _taktika_kulcs: return
	_taktika_kulcs = kulcs
	for ch in _taktika_doboz.get_children(): ch.queue_free()
	_alakzat_gombok.clear()
	_kepesseg_gombok.clear()
	for x in rend:
		var nev: String = x
		var k := str(neva[nev])
		var gb := _gomb(tr(k), func() -> void: alakzat(nev))
		gb.tooltip_text = tr(k + "_TIP") + "  [" + str(T.BETU.get(nev, "")) + "]"
		_alakzat_gombok[nev] = gb
		_taktika_doboz.add_child(gb)
	if not kep.is_empty():
		_taktika_doboz.add_child(VSeparator.new())
	for x in kep:
		var nev: String = x
		var k := T.kepesseg_kulcs(nev)
		var gb := _gomb(tr(k), func() -> void: kepesseg(nev))
		# a gyorsbillentyű: a blokk első képessége E, a második U
		var betu := "E"
		for b in lista:
			var i := (b as Szim.Blokk).kepesseg.find(nev)
			if i >= 0:
				betu = str(T.KEPESSEG_BETU[mini(i, T.KEPESSEG_BETU.size() - 1)])
				break
		gb.tooltip_text = tr(k + "_TIP") + "  [" + betu + "]"
		gb.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
		_kepesseg_gombok[nev] = gb
		_taktika_doboz.add_child(gb)

## A kijelöltek különleges képessége (név szerint)
func kepesseg(nev: String) -> void:
	if kijelolt.is_empty(): return
	szim.parancs_kepesseg(kijelolt.keys(), nev)
	_parancssor_frissit()
	_kartyak_frissit()

## A gyorsbillentyű (E: az első, U: a második képesség) – minden kijelölt a saját képességét
func kepesseg_betu(sorszam: int) -> void:
	var cs: Dictionary = {}
	for b in _kijelolt_blokkok():
		var bb: Szim.Blokk = b
		if sorszam < bb.kepesseg.size():
			var k := str(bb.kepesseg[sorszam])
			if not cs.has(k): cs[k] = []
			(cs[k] as Array).append(bb.id)
	for k in cs: szim.parancs_kepesseg(cs[k], str(k))
	_parancssor_frissit()
	_kartyak_frissit()

func _uj_esemenyek() -> void:
	var fontos := ["TC_EV_ROUT", "TC_EV_RALLY", "TC_EV_GENERAL_FELL", "TC_EV_BRACED", "TC_EV_WITHDRAW", "TC_EV_DESTROYED",
		"TC_EV_AMBUSH", "TC_EV_GATE", "TC_EV_WALL", "TC_EV_PLAZA", "TC_EV_TOWER", "TC_EV_WARCRY", "TC_EV_FEIGN",
		"TC_EV_FEIGN_TURN", "TC_EV_RELIEF", "TC_EV_HAMMER", "TC_EV_LANCE", "TC_EV_LANCE_HIT", "TC_EV_OBLIQUE", "TC_EV_SMOKE",
		"TC_EV_RAMPAGE", "TC_EV_BREACH", "TC_EV_TOWER_DOCK", "TC_EV_TOWER_DOWN", "TC_EV_MINE", "TC_EV_PLAZA_TAKEN", "TC_EV_CITADEL",
		"TC_EV_RELIEF_ARRIVES"]
	while _esemeny_szam < szim.esemenyek.size():
		var e: Dictionary = szim.esemenyek[_esemeny_szam]
		_esemeny_szam += 1
		var kulcs := str(e["kulcs"])
		if hang != null: hang.esemeny(e, nezo_oldal())
		# a közeli nagy becsapódás megrázza a képet
		if kulcs in ["TC_EV_CHARGE", "TC_EV_GATE", "TC_EV_BREACH", "TC_EV_MINE", "TC_EV_TOWER_DOWN"] and e.has("poz") and not szunet:
			var d := (e["poz"] as Vector2).distance_to(kam_poz)
			var r := 420.0 / maxf(kam_zoom, 0.3)
			if d < r: _razkodas = maxf(_razkodas, (1.0 - d / r) * (0.6 if kulcs == "TC_EV_CHARGE" else 0.9) * clampf(kam_zoom, 0.6, 1.6))
		if not kulcs in fontos: continue
		var sajat := int(e["oldal"]) == nezo_oldal()
		var szin := "#9fc8ff" if sajat else "#ff9a8a"
		var szoveg := ""
		match kulcs:
			"TC_EV_ROUT": szoveg = Localization_t("TC_EV_ROUT", [e["nev"]])
			"TC_EV_RALLY": szoveg = Localization_t("TC_EV_RALLY", [e["nev"]])
			"TC_EV_GENERAL_FELL": szoveg = Localization_t("TC_EV_GENERAL_FELL", [e["nev"]])
			"TC_EV_BRACED": szoveg = Localization_t("TC_EV_BRACED", [e["nev"]])
			"TC_EV_WITHDRAW": szoveg = tr("TC_EV_WITHDRAW") if not sajat else tr("TC_EV_WITHDRAW_OWN")
			"TC_EV_DESTROYED": szoveg = Localization_t("TC_EV_DESTROYED", [e["nev"]])
			"TC_EV_AMBUSH": szoveg = Localization_t("TC_EV_AMBUSH", [e["nev"]])
			"TC_EV_WALL": szoveg = Localization_t("TC_EV_WALL", [e["nev"]])
			"TC_EV_RELIEF_ARRIVES":
				# a védő szemszögéből: nekünk jó, ha a mi felmentő seregünk érkezett
				szoveg = tr(kulcs + ("_OWN" if sajat else ""))
				sajat = true
			"TC_EV_GATE", "TC_EV_PLAZA", "TC_EV_TOWER", "TC_EV_BREACH", "TC_EV_TOWER_DOCK", "TC_EV_TOWER_DOWN", "TC_EV_MINE", "TC_EV_PLAZA_TAKEN", "TC_EV_CITADEL":
				# ezek a támadó szemszögéből: nekünk jó, ha mi ostromlunk
				szoveg = tr(kulcs + ("_OWN" if sajat else ""))
				sajat = true
				szin = "#9fc8ff" if int(szim.vedo) != nezo_oldal() else "#ff9a8a"
			_:
				# a harcmodorok eseményei (csatakiáltás, színlelt visszavonulás, a vonalak váltása, kopjás roham…)
				szoveg = Localization_t(kulcs, [e["nev"]])
		if not sajat and kulcs != "TC_EV_WITHDRAW": szoveg = Localization_t("TC_ENEMY", [szoveg])
		_esemeny_sorok.append([szim.ido, "[color=%s]%s[/color]" % [szin, szoveg]])
	# a régi sorok 12 mp után eltűnnek
	while not _esemeny_sorok.is_empty() and (szim.ido - float(_esemeny_sorok[0][0]) > 12.0 or _esemeny_sorok.size() > 6):
		_esemeny_sorok.pop_front()
	var s := ""
	for x in _esemeny_sorok: s += str(x[1]) + "\n"
	if esemeny_rtl.text != s: esemeny_rtl.text = s

## {0}, {1}… helyettesítés (a modul nem függ a játék Localization autoloadjától)
func Localization_t(kulcs: String, args: Array) -> String:
	var s := tr(kulcs)
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s

# ── Egységkártyák ────────────────────────────────────────────────

func _kartyak_epit() -> void:
	for c in kartya_sor.get_children(): c.queue_free()
	kartyak.clear()
	for b in szim.blokkok:
		if b.oldal != en: continue
		var k := Kartya.new()
		k.csata = self
		k.blokk_id = b.id
		k.custom_minimum_size = Vector2(72, 88)
		kartya_sor.add_child(k)
		kartyak.append(k)
	_kartyak_frissit()

func _kartyak_frissit() -> void:
	for kk in kartyak: (kk as Control).queue_redraw()
	_parancssor_frissit()

func kartya_kattint(id: int, tobb: bool, dupla: bool) -> void:
	var b := szim.blokk(id)
	if b == null or not b.aktiv(): return
	if dupla:
		kam_poz = b.poz
		_kamera_frissit()
		return
	if tobb:
		if kijelolt.has(id): kijelolt.erase(id)
		else: _kijelol_be(b)
	else:
		kijelolt.clear()
		_kijelol_be(b)
	_kartyak_frissit()

func tipus_nev(t: String) -> String:
	match t:
		"levy": return tr("TC_TYPE_LEVY")
		"spear": return tr("TC_TYPE_SPEAR")
		"heavy_inf": return tr("TC_TYPE_HEAVY_INF")
		"light_inf": return tr("TC_TYPE_LIGHT_INF")
		"shock": return tr("TC_TYPE_SHOCK")
		"archer": return tr("TC_TYPE_ARCHER")
		"horse_archer": return tr("TC_TYPE_HORSE_ARCHER")
		"light_cav": return tr("TC_TYPE_LIGHT_CAV")
		"heavy_cav": return tr("TC_TYPE_HEAVY_CAV")
		"chariot": return tr("TC_TYPE_CHARIOT")
		"chariot_archer": return tr("TC_TYPE_CHARIOT_ARCHER")
		"elephant": return tr("TC_TYPE_ELEPHANT")
		"general": return tr("TC_TYPE_GENERAL")
		"ram": return tr("TC_TYPE_RAM")
		"siege_tower": return tr("TC_TYPE_SIEGE_TOWER")
		"catapult": return tr("TC_TYPE_CATAPULT")
		"trebuchet": return tr("TC_TYPE_TREBUCHET")
		"sapper": return tr("TC_TYPE_SAPPER")
	return t

func alakzat_nev(nev: String, b: Szim.Blokk = null) -> String:
	if b != null: return tr(T.alakzat_kulcs(nev, b.tipus, b.kinezet, b.doktrina))
	return tr(T.alakzat_kulcs(nev, "", "", ""))

func kartya_tipp(b: Szim.Blokk) -> String:
	var s := "%s (%s)\n" % [b.nev, tipus_nev(b.tipus)]
	s += Localization_t("TC_CARD_MEN", [int(ceil(b.letszam)), b.kezdo]) + "\n"
	var mk := "TC_MORALE_STEADY"
	if b.allapot == Szim.MENEKUL: mk = "TC_MORALE_ROUTING"
	elif b.moral < 25.0: mk = "TC_MORALE_WAVERING"
	elif b.moral < 50.0: mk = "TC_MORALE_SHAKEN"
	s += Localization_t("TC_CARD_MORALE", [int(maxf(b.moral, 0.0)), tr(mk)])
	if b.loszer_kezdo > 0: s += "\n" + Localization_t("TC_CARD_AMMO", [b.loszer, b.loszer_kezdo])
	if b.kos: return s
	s += "\n" + Localization_t("TC_CARD_FORMATION", [alakzat_nev(b.alakzat, b)])
	if b.farad > 0.15: s += "  ·  " + Localization_t("TC_CARD_FATIGUE", [roundi(b.farad * 100.0)])
	var jelek: Array = []
	if b.tartalek: jelek.append(tr("TC_CARD_RESERVE"))
	if b.lovo and not b.tuz_szabad: jelek.append(tr("TC_CARD_HOLD_FIRE"))
	if b.futas: jelek.append(tr("TC_RUN"))
	if b.oldal == nezo_oldal():
		if b.rejtett: jelek.append(tr("TC_CARD_HIDDEN"))
		elif not b.felderitve and szim.fazis == "csata": jelek.append(tr("TC_CARD_UNSEEN"))
	if b.portyaz: jelek.append(tr("TC_ABIL_SKIRMISH"))
	if b.beszivarog: jelek.append(tr("TC_ABIL_INFILTRATE"))
	if b.duh_ido > szim.ido: jelek.append(tr("TC_CARD_FRENZY"))
	# a csapat saját vonásai (dán bárd, berzerker, vadon, lovag, ívelt lövés, számszeríj)
	var jgy: Variant = b.get("jegyek")
	if jgy is Array:
		for jg in jgy: jelek.append(tr("TC_TRAIT_" + str(jg).to_upper()))
	if b.rendezetlen > szim.ido: jelek.append(tr("TC_CARD_DISORDER"))
	if not jelek.is_empty(): s += "\n" + ", ".join(jelek)
	# a nép harcmodora és a képességei
	if b.doktrina != "" and b.oldal == nezo_oldal():
		s += "\n" + Localization_t("TC_CARD_DOCTRINE", [tr(T.doktrina_kulcs(b.doktrina))])
	return s

class Kartya extends Control:
	var csata: Node = null
	var blokk_id: int = -1
	var _nev: TextLine = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		# a név egy sorban, ha nem fér ki: …
		var b = csata.szim.blokk(blokk_id)
		_nev = TextLine.new()
		_nev.add_string(str(b.nev) if b != null else "", ThemeDB.fallback_font, 10)
		_nev.width = custom_minimum_size.x - 6.0
		_nev.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_nev.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	func _get_tooltip(_p: Vector2) -> String:
		var b = csata.szim.blokk(blokk_id)
		return csata.kartya_tipp(b) if b != null else ""

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				csata.kartya_kattint(blokk_id, mb.shift_pressed or mb.ctrl_pressed, mb.double_click)
				accept_event()

	func _draw() -> void:
		var b = csata.szim.blokk(blokk_id)
		if b == null: return
		tooltip_text = " "      # hogy a _get_tooltip meghívódjon
		var r := Rect2(Vector2.ZERO, size)
		var c: Color = csata.nezet.szin[csata.nezo_oldal()]
		var el: bool = b.allapot >= 4
		var fut: bool = b.allapot == 3
		var hat := c.darkened(0.45)
		if el: hat = Color(0.18, 0.16, 0.14)
		elif fut: hat = Color(0.45, 0.42, 0.38)
		draw_rect(r, hat)
		# a jel nagyban
		csata.nezet.jel(self, b.tipus, Vector2(size.x * 0.5, 26), 26.0, Color(1, 1, 1, 0.35 if el else 0.95), 2.0)
		var f := ThemeDB.fallback_font
		if _nev != null: _nev.draw(get_canvas_item(), Vector2(3, 44), Color(0.95, 0.9, 0.8, 0.5 if el else 1.0))
		draw_string(f, Vector2(3, 68), str(int(ceil(b.letszam))), HORIZONTAL_ALIGNMENT_CENTER, size.x - 6, 13, Color(1, 1, 1, 0.5 if el else 1.0))
		# létszám és morál sáv
		var arany: float = clampf(b.letszam / float(maxi(b.kezdo, 1)), 0.0, 1.0)
		var mor: float = clampf(b.moral / 100.0, 0.0, 1.0)
		draw_rect(Rect2(4, 73, size.x - 8, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(4, 73, (size.x - 8) * arany, 5), Color(0.45, 0.85, 0.35))
		draw_rect(Rect2(4, 80, size.x - 8, 5), Color(0, 0, 0, 0.6))
		var mc := Color(0.35, 0.65, 1.0) if b.moral >= 50.0 else (Color(1.0, 0.8, 0.25) if b.moral >= 25.0 else Color(1.0, 0.3, 0.2))
		draw_rect(Rect2(4, 80, (size.x - 8) * mor, 5), mc)
		if b.csoport >= 0:
			draw_string(f, Vector2(4, 12), "G%d" % b.csoport, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.9, 0.5))
		# alakzat, tartalék, tűz tartva (betűjel a kártya bal szélén)
		var jel: String = NezetS.alakzat_jel(str(b.alakzat))
		if b.tartalek: jel += "R"
		if b.lovo and not b.tuz_szabad: jel += "H"
		if b.futas: jel += "»"
		if jel != "":
			draw_string_outline(f, Vector2(3, 40), jel, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(3, 40), jel, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.45))
		if b.loszer_kezdo > 0:
			draw_string(f, Vector2(size.x - 22, 12), str(b.loszer), HORIZONTAL_ALIGNMENT_RIGHT, 18, 10, Color(0.9, 0.9, 0.9))
		var kij: bool = csata.kijelolt.has(blokk_id)
		draw_rect(r, Color(1.0, 0.92, 0.35) if kij else Color(0.5, 0.4, 0.25), false, 3.0 if kij else 1.0)
		if fut:
			draw_string(f, Vector2(0, 44), "!", HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1, 0.3, 0.2))

class EroSav extends Control:
	var csata: Node = null

	func _draw() -> void:
		if csata == null or csata.szim == null: return
		var a: float = csata.szim.ero(0)
		var b: float = csata.szim.ero(1)
		var ossz := maxf(a + b, 1.0)
		var w := size.x * a / ossz
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(0, 2, w, size.y - 4), csata.nezet.szin[0])
		draw_rect(Rect2(w, 2, size.x - w, size.y - 4), csata.nezet.szin[1])
		draw_line(Vector2(size.x * 0.5, 0), Vector2(size.x * 0.5, size.y), Color(1, 1, 1, 0.5), 1.0)
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.62, 0.5, 0.3), false, 1.5)
		var f := ThemeDB.fallback_font
		var ka: float = csata.szim.kezdo_ero(0)
		var kb: float = csata.szim.kezdo_ero(1)
		draw_string_outline(f, Vector2(6, size.y - 6), "%d%%" % roundi(100.0 * a / maxf(ka, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(6, size.y - 6), "%d%%" % roundi(100.0 * a / maxf(ka, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		draw_string_outline(f, Vector2(size.x - 46, size.y - 6), "%d%%" % roundi(100.0 * b / maxf(kb, 1.0)), HORIZONTAL_ALIGNMENT_RIGHT, 40, 12, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(size.x - 46, size.y - 6), "%d%%" % roundi(100.0 * b / maxf(kb, 1.0)), HORIZONTAL_ALIGNMENT_RIGHT, 40, 12, Color.WHITE)

class Minimap extends Control:
	var csata: Node = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		var nyom := false
		var p := Vector2.ZERO
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			nyom = true
			p = (ev as InputEventMouseButton).position
		elif ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			nyom = true
			p = (ev as InputEventMouseMotion).position
		if nyom:
			csata.kam_poz = Vector2(p.x / size.x * 1400.0, p.y / size.y * 900.0)
			csata._kamera_frissit()
			accept_event()

	func _draw() -> void:
		if csata == null or csata.nezet == null or csata.nezet.terep_tex == null: return
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(csata.nezet.terep_tex, r, false)
		var sx := size.x / 1400.0
		var sy := size.y / 900.0
		# a harc köde: csak amit a saját sereg lát; a szem elől tévesztett ellenség utolsó ismert helye üres keret
		var sz: RefCounted = csata.szim
		for b in sz.blokkok:
			if b.oldal != csata.nezo_oldal() and not sz.lathato(b, csata.nezo_oldal()) and b.latva > -90.0 and sz.ido - b.latva < 90.0 and sz.fazis != "vege":
				var cg: Color = csata.nezet.szin[b.oldal]
				cg.a = 0.7 * (1.0 - (sz.ido - b.latva) / 90.0) + 0.2
				draw_rect(Rect2(b.lat_poz.x * sx - 2, b.lat_poz.y * sy - 1.5, 4, 3), cg, false, 1.0)
		for b in sz.blokkok:
			if b.allapot >= 4: continue
			if not sz.lathato(b, csata.nezo_oldal()) and sz.fazis != "vege": continue
			var c: Color = csata.nezet.szin[b.oldal]
			if b.allapot == 3: c = c.lerp(Color.WHITE, 0.5)
			draw_rect(Rect2(b.poz.x * sx - 2, b.poz.y * sy - 1.5, 4, 3), c)
		# a kamera látómezeje
		var vm: Vector2 = csata._kepernyo()
		var sar := PackedVector2Array()
		for q in [Vector2(0, 46), Vector2(vm.x, 46), Vector2(vm.x, vm.y - 112), Vector2(0, vm.y - 112), Vector2(0, 46)]:
			var w: Vector2 = csata.vilagba(q)
			sar.append(Vector2(clampf(w.x * sx, 0.0, size.x), clampf(w.y * sy, 0.0, size.y)))
		draw_polyline(sar, Color(1, 1, 0.7, 0.9), 1.0)
		draw_rect(r, Color(0.62, 0.5, 0.3), false, 1.5)

# ── Súgó ─────────────────────────────────────────────────────────

# Az első csata elején csak egy kétsoros tipp az alsó sáv fölött: nem fog meg kattintást, ~10 mp után vagy az első
# kattintásra elhalványul. A részletes súgó csak kérésre nyílik (?, F1, H, a felső sáv ? gombja vagy a tipp
# „Bővebben…”-je): jobb oldalt, görgethető, lenyitható szakaszokkal; Esc, × vagy a csatatérre kattintás zárja.
const TIPP_IDO := 10.0
const SUGO_SZEL := 390.0

func _sugo_latta() -> bool:
	var cf := ConfigFile.new()
	if cf.load(BEALLITAS) != OK: return false
	return bool(cf.get_value("sugo", "tipp_latta", false))

## A súgó szakaszai: az első sor a cím, a többi a pontok
func _sugo_reszek() -> Array:
	var r := [tr("TC_HELP_SEL"), tr("TC_HELP_ORDERS"), tr("TC_HELP_FORM"), tr("TC_HELP_CAM"), tr("TC_HELP_FOG"),
		tr("TC_HELP_TIPS"), tr("TC_HELP_SIEGE")]
	# érintőképernyőn elöl az érintés szakasza
	if erintos(): r.push_front(tr("TC_HELP_TOUCH"))
	return r

func _tipp_mutat() -> void:
	if sugo_tipp != null or ui == null: return
	var cf := ConfigFile.new()
	cf.load(BEALLITAS)
	cf.set_value("sugo", "tipp_latta", true)
	cf.save(BEALLITAS)
	sugo_tipp = PanelContainer.new()
	var sb := _panel_stilus(0.72)
	sb.set_border_width_all(1)
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	sugo_tipp.add_theme_stylebox_override("panel", sb)
	sugo_tipp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# középen, közvetlenül az alsó sáv fölött (felfelé nő)
	sugo_tipp.anchor_left = 0.5; sugo_tipp.anchor_right = 0.5
	sugo_tipp.anchor_top = 1.0; sugo_tipp.anchor_bottom = 1.0
	sugo_tipp.offset_top = -ALSO_M - 6.0; sugo_tipp.offset_bottom = -ALSO_M - 6.0
	sugo_tipp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sugo_tipp.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(sugo_tipp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sugo_tipp.add_child(v)
	v.add_child(_cimke(tr("TC_HINT_TOUCH" if erintos() else "TC_HINT_1"), 15))
	var s2 := HBoxContainer.new()
	s2.add_theme_constant_override("separation", 6)
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s2)
	s2.add_child(_cimke(tr("TC_HINT_2_TOUCH" if erintos() else "TC_HINT_2"), 15))
	var tovabb := LinkButton.new()
	tovabb.text = tr("TC_HINT_MORE")
	tovabb.focus_mode = Control.FOCUS_NONE
	tovabb.add_theme_font_size_override("font_size", 15)
	tovabb.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	tovabb.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.6))
	tovabb.pressed.connect(func() -> void: _sugo(true))
	s2.add_child(tovabb)
	_tipp_ido = TIPP_IDO

func _tipp_el() -> void:
	if sugo_tipp == null: return
	var t := sugo_tipp
	sugo_tipp = null
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 0.0, 0.6)
	tw.tween_callback(t.queue_free)

func _sugo(be: bool) -> void:
	if not be:
		if sugo_panel != null:
			sugo_panel.queue_free()
			sugo_panel = null
			_sugo_gorgo = null
			_sugo_lista = null
		_tipp_el()
		return
	if sugo_panel != null or ui == null: return
	_tipp_el()
	sugo_panel = PanelContainer.new()
	sugo_panel.add_theme_stylebox_override("panel", _panel_stilus(0.94))
	# jobb oldalt, a felső sáv alatt
	sugo_panel.anchor_left = 1.0; sugo_panel.anchor_right = 1.0
	sugo_panel.offset_left = -SUGO_SZEL - 8.0; sugo_panel.offset_right = -8.0
	sugo_panel.offset_top = FELSO_M + 8.0; sugo_panel.offset_bottom = FELSO_M + 8.0
	sugo_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui.add_child(sugo_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	sugo_panel.add_child(v)
	var fej := HBoxContainer.new()
	v.add_child(fej)
	var c := _cimke(tr("TC_HELP_TITLE"), 18, Color(1.0, 0.9, 0.55))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fej.add_child(c)
	var zar := _gomb("×", func() -> void: _sugo(false), 30)
	zar.tooltip_text = "Esc"
	fej.add_child(zar)
	_sugo_gorgo = ScrollContainer.new()
	_sugo_gorgo.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_sugo_gorgo)
	_sugo_lista = VBoxContainer.new()
	_sugo_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sugo_lista.add_theme_constant_override("separation", 1)
	_sugo_gorgo.add_child(_sugo_lista)
	var elso := true
	for resz in _sugo_reszek():
		var sorok := str(resz).split("\n")
		var cim := sorok[0]
		var gomb := Button.new()
		gomb.flat = true
		gomb.focus_mode = Control.FOCUS_NONE
		gomb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		gomb.add_theme_font_size_override("font_size", 15)
		gomb.add_theme_color_override("font_color", Color(1.0, 0.84, 0.5))
		gomb.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
		gomb.add_theme_color_override("font_pressed_color", Color(1.0, 0.84, 0.5))
		_sugo_lista.add_child(gomb)
		var torzs := _cimke("\n".join(sorok.slice(1)), 14, Color(0.93, 0.89, 0.8))
		torzs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		torzs.custom_minimum_size.x = SUGO_SZEL - 44.0
		torzs.visible = elso
		_sugo_lista.add_child(torzs)
		gomb.text = ("▾ " if elso else "▸ ") + cim
		gomb.pressed.connect(func() -> void:
			torzs.visible = not torzs.visible
			gomb.text = ("▾ " if torzs.visible else "▸ ") + cim
			_sugo_meret.call_deferred())
		elso = false
	_sugo_meret.call_deferred()

## A görgethető rész magassága a tartalomhoz igazodik, de a két sáv közé fér
func _sugo_meret() -> void:
	if sugo_panel == null or _sugo_gorgo == null or _sugo_lista == null: return
	var max_m := _kepernyo().y - FELSO_M - ALSO_M - 70.0
	_sugo_gorgo.custom_minimum_size = Vector2(SUGO_SZEL - 24.0, minf(_sugo_lista.get_combined_minimum_size().y, max_m))
	sugo_panel.reset_size()

# ── Vége ─────────────────────────────────────────────────────────

func _eredmeny_mutat() -> void:
	var e := szim.eredmeny()
	var gyoz := int(e["gyoztes"]) == nezo_oldal()
	eredmeny_panel = PanelContainer.new()
	eredmeny_panel.add_theme_stylebox_override("panel", _panel_stilus(0.97))
	ui.add_child(eredmeny_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	eredmeny_panel.add_child(v)
	var c := _cimke(tr("TC_RESULT_WON") if gyoz else tr("TC_RESULT_LOST"), 30,
		Color(0.6, 1.0, 0.5) if gyoz else Color(1.0, 0.45, 0.35))
	if en < 0 and halo != null:
		# a néző: ki győzött
		var gy := clampi(int(e["gyoztes"]), 0, 1)
		c.text = Localization_t("TC_NET_SIDE_WON", [str(szim.oldalak[gy]["nev"])])
		c.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var ok := str(e["ok"])
	var miert := ""
	match ok:
		"rout": miert = tr("TC_WHY_ROUT_WON") if gyoz else tr("TC_WHY_ROUT_LOST")
		"timeout": miert = tr("TC_WHY_TIMEOUT_WON") if gyoz else tr("TC_WHY_TIMEOUT_LOST")
		"withdraw": miert = tr("TC_WHY_WITHDREW_WON") if gyoz else tr("TC_WHY_WITHDREW_LOST")
		"capture": miert = tr("TC_WHY_CAPTURE_WON") if gyoz else tr("TC_WHY_CAPTURE_LOST")
	var ml := _cimke(miert, 15)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ml)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 22)
	v.add_child(g)
	for s in ["", tr("TC_RESULT_MEN"), tr("TC_RESULT_FALLEN"), tr("TC_RESULT_LEFT")]:
		g.add_child(_cimke(s, 14, Color(0.85, 0.72, 0.5)))
	for o in 2:
		var kezdo := 0
		var elesett := 0
		var od: Dictionary = e["oldalak"][o]
		for k in od["kezdo"]:
			kezdo += int(od["kezdo"][k])
			elesett += int(od["elesett"].get(k, 0))
		var nev := str(szim.oldalak[o]["nev"])
		g.add_child(_cimke(nev if nev != "" else (tr("TC_RESULT_OURS") if o == nezo_oldal() else tr("TC_RESULT_THEIRS")), 15, szim.oldalak[o]["szin"].lightened(0.3)))
		g.add_child(_cimke(str(kezdo), 15))
		g.add_child(_cimke(str(elesett), 15))
		g.add_child(_cimke(str(kezdo - elesett), 15))
	for o in 2:
		if bool(szim.oldalak[o]["vezer_elesett"]):
			var vl := _cimke(Localization_t("TC_RESULT_GENERAL_FELL", [szim.oldalak[o]["vezer_nev"]]), 15, Color(1.0, 0.75, 0.5))
			vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(vl)
	var jegy := _cimke(tr("TC_RESULT_NOTE"), 13, Color(0.8, 0.75, 0.65))
	jegy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jegy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	jegy.custom_minimum_size.x = 460
	v.add_child(jegy)
	var b := _gomb(tr("TC_CONTINUE"), _befejez)
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 17)
	v.add_child(b)
	_kozepre(eredmeny_panel, -2.0)

var _kesz: bool = false

func _befejez() -> void:
	if _kesz: return
	_kesz = true
	befejezve.emit(szim.eredmeny())
	queue_free()
