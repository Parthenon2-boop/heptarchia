extends "res://scripts/ui/bevezeto.gd"

# HEPTARCHIA – záróképsor és stáblista: a korszak végén (1066) a winchesteri krónikás leteszi a tollat
#
# Ugyanaz a lejátszó, mint a bevezetőé (scripts/ui/bevezeto.gd), csak a jelenetei mások: öt festmény
# a töltőképek közül (assets/loading – nem másolat, a játékcsomag nem nő tőle), felirat OUTRO_01 …
# OUTRO_05 (a cím OUTRO_NN_TITLE), felolvasás a játék nyelvén: assets/zaro/hang/<nyelvkód>_NN.ogg
# (előállítása: tools/intro/README.md, „A záróképsor”); amelyik nyelvhez nincs hang, azon felirattal megy.
# Az utolsó jelenet után a képre ráúszik a stáblista, és lentről fölfelé végiggördül; a zene alatta szól tovább.
#
# Esc / szóköz / Enter / kattintás: a következő jelenet (a stáblistán: gyorsabban gördül); „Átugrás”: az egész.
#
# Indítás:  ZaroKepsor.zaro(szulo)                 – a korszak végén (main_game.gd, _show_end_game)
#           ZaroKepsor.zaro(szulo, true)           – csak a stáblista (a főmenü „Stáblista” gombja)
# A végén a `vege` jelzés jön, a réteg felszabadul.

const ZARO_JELENETEK := ["01_kronikas", "02_ket_flotta", "03_hastings", "04_koronazas", "05_naplemente"]
const ZARO_TARTALEK := ["04_scriptorium", "10_normann_flotta", "16_hastings", "07_koronazas", "20_kiraly_naplemente"]
const ZARO_MOZGAS := [
	[1.00, 1.10, Vector2(0.3, -0.2), Vector2(0.0, 0.1)],      # a krónikás az írópultnál: lassú közelítés
	[1.10, 1.02, Vector2(-0.5, 0.2), Vector2(0.5, -0.1)],     # a flotta: a hajók hosszában a part felé
	[1.02, 1.12, Vector2(-0.4, 0.3), Vector2(0.2, -0.2)],     # Hastings: föl a dombra, a pajzsfalra
	[1.10, 1.00, Vector2(0.0, -0.4), Vector2(0.0, 0.2)],      # a koronázás: távolodva
	[1.00, 1.08, Vector2(-0.3, 0.0), Vector2(0.4, 0.1)]       # naplemente: a király mögül a táj felé
]

# A stáblista sorai: [fajta, szöveg]. A fajta: "cim" (a játék neve), "al" (alcím), "szerep" (a munka
# neve – fordítási kulcs), "nev" (név – nem fordítjuk), "kis" (apró sor – fordítási kulcs), "koz" (térköz)
const STABLISTA := [
	["cim", "HEPTARCHIA"],
	["al", "CREDITS_SUBTITLE"],
	["koz", ""],
	["szerep", "CREDITS_STUDIO"],
	["nev", "Parthenon Studio"],
	["koz", ""],
	["szerep", "CREDITS_DEVELOPER"],
	["nev", "Erdélyi Bence Endre"],
	["koz", ""],
	["szerep", "CREDITS_TESTERS"],
	["nev", "Vető Olivér"],
	["nev", "Tóth Máté Benedek"],
	["koz", ""],
	["szerep", "CREDITS_NARRATOR"],
	["nev", "Victor"],
	["koz", ""],
	["szerep", "CREDITS_SOURCES"],
	["kis", "CREDITS_SOURCES_LIST"],
	["koz", ""],
	["szerep", "CREDITS_FONTS"],
	["nev", "Uncial Antiqua · EB Garamond · Noto Sans Runic"],
	["nev", "Noto Sans Symbols · DejaVu Sans"],
	["kis", "CREDITS_FONTS_LICENSE"],
	["koz", ""],
	["szerep", "CREDITS_ENGINE"],
	["nev", "Godot Engine"],
	["kis", "CREDITS_ENGINE_LICENSE"],
	["koz", ""],
	["koz", ""],
	["al", "CREDITS_THANKS"],
	["koz", ""],
	["kis", "CREDITS_COPYRIGHT"],
]

const GORDULES := 46.0        # a stáblista sebessége (képpont/mp 720 magas képernyőn)
const GYORS := 4.0            # lenyomásra ennyiszer gyorsabban gördül
const STAB_ATTUNES := 1.6     # ennyi alatt sötétül el a kép a stáblista mögött

var csak_stablista: bool = false
var _stab: Control = null     # a stáblista (amíg nem indult el: null)
var _stab_t: float = 0.0
var _oszlop: VBoxContainer
var _gyors_ig: float = -1.0   # eddig (_ossz_t) gördül gyorsan

static func zaro(szulo: Node, stablista_csak: bool = false) -> Node:
	var z = load("res://scripts/ui/zaro_kepsor.gd").new()
	z.csak_stablista = stablista_csak
	szulo.add_child(z)
	return z

func _init() -> void:
	super()
	jelenetek = ZARO_JELENETEK
	mozgas = ZARO_MOZGAS
	tartalek = ZARO_TARTALEK
	kulcs_elotag = "OUTRO_"
	kep_mappa = "res://assets/zaro/"
	hang_mappa = "res://assets/zaro/hang/"

func _indul() -> void:
	if csak_stablista: _stablista()
	else: _jelenet(0)

func _utolso_utan() -> void:
	_stablista()

# ── A stáblista ──────────────────────────────────────────────────

func _stablista() -> void:
	if _stab != null: return
	_hang.stop()
	_hang_var = false
	_cim.hide()
	_felirat.hide()
	_sugo.hide()
	_stab = Control.new()
	_stab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stab.clip_contents = true
	_stab.modulate.a = 0.0
	var hatter := ColorRect.new()
	hatter.color = Color(0, 0, 0, 0.88)
	hatter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stab.add_child(hatter)
	_oszlop = VBoxContainer.new()
	_oszlop.anchor_left = 0.1; _oszlop.anchor_right = 0.9
	_oszlop.alignment = BoxContainer.ALIGNMENT_BEGIN
	_oszlop.add_theme_constant_override("separation", 6)
	_oszlop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stab.add_child(_oszlop)
	var cimbetu: Font = load("res://assets/ui/font_title.tres")
	for sor in STABLISTA:
		_oszlop.add_child(_stab_sor(str(sor[0]), str(sor[1]), cimbetu))
	# a gomb és az elsötétítő a stáblista fölött maradjon
	_alap.add_child(_stab)
	_alap.move_child(_stab, _fekete.get_index())
	_stab_t = 0.0
	_oszlop.position.y = _alap.size.y           # a képernyő alja alól indul
	if csak_stablista: _fekete.modulate.a = 1.0

func _stab_sor(fajta: String, szoveg: String, cimbetu: Font) -> Control:
	if fajta == "koz":
		var k := Control.new()
		k.custom_minimum_size = Vector2(0, 34)
		k.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return k
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_outline_color", SOTET)
	l.add_theme_constant_override("outline_size", 5)
	match fajta:
		"cim":
			l.text = szoveg
			if cimbetu != null: l.add_theme_font_override("font", cimbetu)
			l.add_theme_font_size_override("font_size", 58)
			l.add_theme_color_override("font_color", ARANY)
		"al":
			l.text = tr(szoveg)
			if cimbetu != null: l.add_theme_font_override("font", cimbetu)
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", KREM)
		"szerep":
			l.text = tr(szoveg)
			if cimbetu != null: l.add_theme_font_override("font", cimbetu)
			l.add_theme_font_size_override("font_size", 19)
			l.add_theme_color_override("font_color", ARANY)
		"nev":
			l.text = szoveg
			l.add_theme_font_size_override("font_size", 27)
			l.add_theme_color_override("font_color", KREM)
		_:
			l.text = tr(szoveg)
			l.add_theme_font_size_override("font_size", 15)
			l.add_theme_color_override("font_color", Color(KREM, 0.7))
	return l

func _process(delta: float) -> void:
	if _stab == null or _zar_t >= 0.0:
		super(delta)
		return
	_ossz_t += delta
	_stab_t += delta
	_hangero()
	_vaszon.queue_redraw()
	if csak_stablista: _fekete.modulate.a = 1.0 - clampf(_ossz_t / NYITAS, 0.0, 1.0)
	_stab.modulate.a = clampf(_stab_t / STAB_ATTUNES, 0.0, 1.0)
	# a képernyő magasságához mért sebesség (telefonon és nagy kijelzőn is ugyanannyi ideig tart)
	var seb := GORDULES * _alap.size.y / 720.0
	if _ossz_t < _gyors_ig: seb *= GYORS
	if _stab_t > STAB_ATTUNES * 0.5: _oszlop.position.y -= seb * delta
	# ha az utolsó sor is kiment fölül: vége
	if _oszlop.position.y + _oszlop.size.y < -10.0: atugras()

func tovabb() -> void:
	if _stab == null:
		super()
		return
	# a stáblistán a lenyomás egy darabig gyorsít (a kihagyás az „Átugrás” gomb)
	_gyors_ig = _ossz_t + 1.2

func _hangero() -> void:
	super()
	# a stáblista alatt nincs felolvasás: a zene a teljes (csak zenés) hangerőn szól
	if _stab != null and _zene != null:
		var burok := clampf(_ossz_t / 1.5, 0.0, 1.0)
		if _zar_t >= 0.0: burok *= 1.0 - clampf(_zar_t / ZARAS, 0.0, 1.0)
		_zene.volume_db = AudioManager.MUSIC_BASE_DB + ZENE_CSAK_DB + linear_to_db(maxf(AudioManager.music_volume * burok, 0.0001))
