extends CanvasLayer

# HEPTARCHIA – bevezető képsor: Alfréd király visszatekint (Winchester, 891 táján)
#
# Tíz festmény (assets/intro/01_alfred.jpg … 10_hajnal.jpg) lassú közelítéssel/úsztatással, lágy
# áttűnéssel; alul a felirat a játék nyelvén (INTRO_01 … INTRO_10, a jelenet címe INTRO_NN_TITLE).
# Alfréd szövegét a játék nyelvén felolvasás kíséri (assets/intro/hang/hu_NN.ogg, en_NN.ogg,
# de_NN.ogg – előállításuk: tools/intro/README.md); amelyik nyelvhez nincs hang, azon a képsor hang
# nélkül megy, a jelenet hosszát a szöveg hossza adja. Alatta halkan Wessex zenéje szól. A zene a „Zene”, a felolvasás a „Hangeffektek”
# kapcsolóját és hangerejét követi (AudioManager).
#
# Esc / szóköz / Enter / kattintás (érintés): a következő jelenet; az „Átugrás” gomb: az egész.
# Hiányzó kép helyén sötét háttér áll, hiányzó hang helyett a felirat ideje számít – semmi sem kötelező.
#
# Indítás:  Bevezeto.indit(szulo, elso)  – a főmenü hívja: az első indításkor magától (lásd
# magatol_indulhat), később a „Bevezető” gombbal. A végén a `vege` jelzés jön, a réteg felszabadul.

signal vege                          # lement vagy átugrották
signal jelenet_valtott(i: int)       # a felvevőnek (tools/intro/felvevo.gd)
signal hang_indult(i: int)

const JELENETEK := ["01_alfred", "02_het_kiralysag", "03_lindisfarne", "04_nagy_sereg", "05_york",
	"06_ashdown", "07_athelney", "08_edington", "09_burh", "10_hajnal"]
const KEP_MAPPA := "res://assets/intro/"
const HANG_MAPPA := "res://assets/intro/hang/"
const ZENE := "res://assets/audio/nepek/wessex.ogg"
const SETTINGS_PATH := "user://settings.cfg"

# A kép mozgása jelenetenként: [nagyítás az elején, a végén, fókusz az elején, a végén].
# A fókusz −1…1 (bal/fent … jobb/lent): a kép kilógó részéből ennyit tolunk el – a kép széle így
# soha nem látszik be. A 3:2-es festmény a 16:9-es képernyőn fölül-alul amúgy is túllóg: az a függőleges út.
const MOZGAS := [
	[1.00, 1.10, Vector2(0.0, -0.3), Vector2(0.15, 0.1)],     # Alfréd az írópultnál: lassú közelítés
	[1.12, 1.02, Vector2(-0.5, 0.4), Vector2(0.3, -0.2)],     # a hét királyság: távolodva végigúszunk rajta
	[1.02, 1.12, Vector2(0.6, 0.0), Vector2(-0.3, 0.2)],      # Lindisfarne: a hajóktól a kolostor felé
	[1.10, 1.02, Vector2(-0.6, 0.2), Vector2(0.5, 0.0)],      # a nagy sereg: a hajóhad hosszában
	[1.02, 1.13, Vector2(0.0, 0.5), Vector2(0.0, -0.4)],      # York: föl az égő falakra
	[1.12, 1.03, Vector2(0.2, 0.0), Vector2(-0.3, 0.1)],      # Ashdown: a pajzsfal mentén
	[1.03, 1.10, Vector2(-0.4, -0.3), Vector2(0.2, 0.3)],     # Athelney: le a mocsárba
	[1.00, 1.11, Vector2(0.3, 0.3), Vector2(-0.1, -0.1)],     # Edington: közelítés
	[1.12, 1.02, Vector2(0.5, 0.3), Vector2(-0.4, -0.2)],     # a burh-ök: távolodva
	[1.08, 1.00, Vector2(0.0, 0.5), Vector2(0.0, -0.5)]       # hajnal: föl az égre
]

const ATTUNES := 1.3          # két kép közti áttűnés (mp)
const NYITAS := 1.0           # az elején ennyi alatt jön elő a feketéből
const ZARAS := 1.4            # a végén ennyi alatt sötétül el
const HANG_ELOTT := 0.7       # a jelenet kezdete után ennyivel szólal meg a felolvasás
const HANG_UTAN := 0.9        # és ennyi csend van utána
const BETU_MP := 0.07         # hang nélkül: olvasási idő betűnként …
const OLVAS_ALAP := 2.2       # … meg ennyi; legalább OLVAS_MIN mp
const OLVAS_MIN := 6.0
const ZENE_HALK_DB := -9.0    # a zene a felolvasás alatt ennyivel halkabb a játék zenéjénél
const ZENE_CSAK_DB := -3.0    # felolvasás nélkül ennyivel
const HANG_DB := 1.0          # a felolvasás szintje a hangeffektek hangerejéhez képest
const SOTET := Color(0.07, 0.05, 0.035)
const ARANY := Color(0.93, 0.76, 0.42)
const KREM := Color(0.98, 0.94, 0.84)

var felvetel: bool = false    # a videó felvételéhez (tools/intro/felvevo.gd): nincs gomb, súgó és hang – a hangot utólag vágják alá

var _i: int = -1              # a futó jelenet
var _t: float = 0.0           # idő a jelenetben
var _hossz: float = 0.0
var _regi: int = -1           # az előző jelenet (amíg az áttűnés tart)
var _regi_t: float = 0.0
var _regi_hossz: float = 1.0
var _ossz_t: float = 0.0
var _zar_t: float = -1.0      # >= 0: a záró elsötétülés fut
var _hang_var: bool = false
var _utolso_lepes: float = -1.0
var _kepek: Array = []        # jelenetenként a kép (null: nincs betöltve vagy nincs meg)
var _kert := {}               # a háttérben töltődő képek útja
var _hangok: Array = []       # jelenetenként a felolvasás (vagy null)

var _alap: Control
var _vaszon: Control
var _cim: Label
var _felirat: Label
var _sugo: Label
var _gomb: Button
var _fekete: ColorRect
var _zene: AudioStreamPlayer
var _hang: AudioStreamPlayer
var _potkep: Texture2D

## A főmenü hívja. `elso`: a program első indításakor magától induló lejátszás – ilyenkor
## megjegyzi a user://settings.cfg-ben, hogy a játékos már látta.
static func indit(szulo: Node, elso: bool = false) -> Node:
	var b = load("res://scripts/ui/bevezeto.gd").new()
	if elso:
		megjegyez()
		print("Heptarchia: bevezető képsor (első indítás)")
	szulo.add_child(b)
	return b

static func latta() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK: return false
	return bool(cfg.get_value("general", "intro_seen", false))

static func megjegyez() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("general", "intro_seen", true)
	cfg.save(SETTINGS_PATH)

## Elindulhat-e magától a főmenü előtt? Csak a játékos saját, rendes indításakor, egyszer. Nem indul:
## ablak nélkül (szerver, a tesztek nagy része), szkriptes futásban (-s / --script: a _test szkriptjei és
## a felvevők), a motor filmfelvevő módjában (--write-movie), és ha a játék saját kapcsolót kapott (a „--”
## utániak, pl. --server). (A motor a maga kapcsolóit – --position, --fixed-fps, --quit-after – lenyeli,
## azok innen nem látszanak: ezekkel a főjelenet rendes indításnak számít.)
## A HEP_BEVEZETO környezeti változó próbához való: „0” = soha, „1” = a kapcsolók nem számítanak
## (az ablak nélküli futás és a mentett „már látta” jelzés ekkor is).
static func magatol_indulhat() -> bool:
	if DisplayServer.get_name() == "headless": return false
	var kenyszer := OS.get_environment("HEP_BEVEZETO")
	if kenyszer == "0": return false
	if kenyszer != "1":
		if OS.has_feature("movie") or not OS.get_cmdline_user_args().is_empty(): return false
		for a in OS.get_cmdline_args():
			if str(a) in ["-s", "--script"]: return false
	return not latta()

func _init() -> void:
	layer = 110           # a menü és ablakai fölött, a töltőképernyő (120) és az érintésjelző (128) alatt
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	_betolt()
	_epit()
	# a menü zenéje addig hallgat (első indításkor még el sem indult)
	AudioManager.music_player.stream_paused = true
	_zene = AudioStreamPlayer.new()
	add_child(_zene)
	_hang = AudioStreamPlayer.new()
	add_child(_hang)
	if not felvetel and ResourceLoader.exists(ZENE):
		var z: AudioStream = load(ZENE)
		if z is AudioStreamOggVorbis: (z as AudioStreamOggVorbis).loop = true
		_zene.stream = z
		_zene.volume_db = -60.0
	_hangero()
	_jelenet(0)

func _exit_tree() -> void:
	# akárhogy ér véget (a végére ért, átugrották, vagy a menüvel együtt szűnik meg): a játék zenéje visszajár
	if is_instance_valid(AudioManager) and AudioManager.music_player != null:
		AudioManager.music_player.stream_paused = false
	for ut in _kert: ResourceLoader.load_threaded_get(ut)      # a félbemaradt háttértöltés lezárása
	_kert.clear()

# ── Betöltés ─────────────────────────────────────────────────────

func _betolt() -> void:
	var nyelv: String = Localization.current
	for nev in JELENETEK:
		_kepek.append(null)          # a képek menet közben töltődnek (_kep_kell)
		var h: AudioStream = null
		var ut := HANG_MAPPA + nyelv + "_" + str(nev).substr(0, 2) + ".ogg"
		if ResourceLoader.exists(ut): h = load(ut)
		if h is AudioStreamOggVorbis: (h as AudioStreamOggVorbis).loop = false
		_hangok.append(h)

## Amíg egy jelenetnek nincs saját festménye, a töltőképek közül a témájához illő áll a helyén
## (nem másolat: ugyanaz a fájl, a játékcsomag nem nő tőle).
const TARTALEK_MAPPA := "res://assets/loading/"
const TARTALEK := ["04_scriptorium", "09_aratas", "02_partraszallas", "10_normann_flotta", "14_danegeld",
	"03_pajzsfal", "15_teli_falu", "07_koronazas", "08_burh", "20_kiraly_naplemente"]

static func kep_ut(i: int) -> String:
	var sajat := KEP_MAPPA + str(JELENETEK[i]) + ".jpg"
	if ResourceLoader.exists(sajat) or FileAccess.file_exists(sajat): return sajat
	return TARTALEK_MAPPA + str(TARTALEK[i]) + ".jpg"

## Melyik jelenetnek nincs meg a festménye (a nevek listája; üres, ha mind megvan)
static func hianyzo_kepek() -> Array:
	var ki: Array = []
	for i in JELENETEK.size():
		if not ResourceLoader.exists(kep_ut(i)) and not FileAccess.file_exists(kep_ut(i)): ki.append(JELENETEK[i])
	return ki

## Az i. jelenet képe legyen a memóriában; a régebbieket elengedjük. Egyszerre legfeljebb három festmény
## van betöltve (az előző, a mostani és a háttérben töltődő következő) – telefonon a tíz együtt sok volna.
func _kep_kell(i: int) -> void:
	for j in _kepek.size():
		if j < i - 1 or j > i: _kepek[j] = null
	if _kepek[i] == null: _kepek[i] = _kep(kep_ut(i))
	if i + 1 < JELENETEK.size():
		var kov := kep_ut(i + 1)
		if ResourceLoader.exists(kov) and not _kert.has(kov):
			_kert[kov] = true
			ResourceLoader.load_threaded_request(kov)

## A kép: importálva (a kiadott játékban mindig így), vagy – fejlesztés közben, ha a Godot még nem
## importálta – közvetlenül a fájlból. Ha nincs meg, null: a helyén sötét háttér lesz.
func _kep(ut: String) -> Texture2D:
	if ResourceLoader.exists(ut):
		if _kert.has(ut):
			_kert.erase(ut)
			return ResourceLoader.load_threaded_get(ut) as Texture2D      # (ha még tölt, megvárja)
		return load(ut) as Texture2D
	if FileAccess.file_exists(ut):
		var img := Image.load_from_file(ProjectSettings.globalize_path(ut))
		if img != null and not img.is_empty(): return ImageTexture.create_from_image(img)
	return null

## Szól-e felolvasás az i. jelenet alatt (van hangja, és a hangeffektek nincsenek kikapcsolva)
func _van_hang(i: int) -> bool:
	return _hangok[i] != null and (AudioManager.sfx_on or felvetel)

func _jelenet_hossz(i: int) -> float:
	if _van_hang(i): return HANG_ELOTT + (_hangok[i] as AudioStream).get_length() + HANG_UTAN
	var betu := tr("INTRO_" + str(JELENETEK[i]).substr(0, 2)).length()
	return maxf(OLVAS_MIN, OLVAS_ALAP + betu * BETU_MP)

# ── Felület ──────────────────────────────────────────────────────

func _epit() -> void:
	_alap = Control.new()
	_alap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_alap.mouse_filter = Control.MOUSE_FILTER_STOP           # alatta a menüre ne lehessen kattintani
	_alap.gui_input.connect(_kattintas)
	add_child(_alap)
	var hatter := ColorRect.new()
	hatter.color = Color.BLACK
	hatter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alap.add_child(hatter)
	# a képeket magunk rajzoljuk (tört képponttal): a Control-ok egész képpontra igazodnának, a lassú úszás rángana
	_vaszon = Control.new()
	_vaszon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vaszon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vaszon.clip_contents = true
	_vaszon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vaszon.draw.connect(_rajz)
	_alap.add_child(_vaszon)
	# kép híján: sötét, középen kicsit derengő háttér
	var g := Gradient.new()
	g.set_color(0, Color(0.20, 0.15, 0.10))
	g.set_color(1, Color(0.03, 0.02, 0.015))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.42)
	gt.fill_to = Vector2(1.0, 1.0)
	gt.width = 256; gt.height = 144
	_potkep = gt
	# alul sötét sáv, hogy a felirat bármilyen képen olvasható legyen
	var sav := TextureRect.new()
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	sg.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.9)])
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill_from = Vector2(0, 0); st.fill_to = Vector2(0, 1)
	st.width = 8; st.height = 128
	sav.texture = st
	sav.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sav.stretch_mode = TextureRect.STRETCH_SCALE
	sav.anchor_left = 0; sav.anchor_right = 1; sav.anchor_top = 0.52; sav.anchor_bottom = 1
	sav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alap.add_child(sav)
	# a cím és a felirat alulról fölfelé nő (a hosszabb szöveg több sort kap)
	var oszlop := VBoxContainer.new()
	oszlop.anchor_left = 0.09; oszlop.anchor_right = 0.91; oszlop.anchor_top = 1; oszlop.anchor_bottom = 1
	oszlop.offset_bottom = -44
	oszlop.grow_vertical = Control.GROW_DIRECTION_BEGIN
	oszlop.alignment = BoxContainer.ALIGNMENT_END
	oszlop.add_theme_constant_override("separation", 4)
	oszlop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alap.add_child(oszlop)
	_cim = Label.new()
	_cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cimbetu: Font = load("res://assets/ui/font_title.tres")
	if cimbetu != null: _cim.add_theme_font_override("font", cimbetu)
	_cim.add_theme_font_size_override("font_size", 25 if felvetel else 21)      # (a videóban nagyobb betű)
	_cim.add_theme_color_override("font_color", ARANY)
	_cim.add_theme_color_override("font_outline_color", SOTET)
	_cim.add_theme_constant_override("outline_size", 6)
	_cim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oszlop.add_child(_cim)
	_felirat = Label.new()
	_felirat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_felirat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_felirat.add_theme_font_size_override("font_size", 30 if felvetel else 25)
	_felirat.add_theme_constant_override("line_spacing", 1)
	_felirat.add_theme_color_override("font_color", KREM)
	_felirat.add_theme_color_override("font_outline_color", SOTET)
	_felirat.add_theme_constant_override("outline_size", 7)
	_felirat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oszlop.add_child(_felirat)
	_sugo = Label.new()
	_sugo.text = tr("INTRO_HINT_TOUCH") if Erintes.aktiv else tr("INTRO_HINT")
	_sugo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sugo.anchor_left = 0; _sugo.anchor_right = 1; _sugo.anchor_top = 1; _sugo.anchor_bottom = 1
	_sugo.offset_top = -32; _sugo.offset_bottom = -8
	_sugo.add_theme_font_size_override("font_size", 14)
	_sugo.add_theme_color_override("font_color", Color(KREM, 0.55))
	_sugo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alap.add_child(_sugo)
	_fekete = ColorRect.new()
	_fekete.color = Color.BLACK
	_fekete.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fekete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alap.add_child(_fekete)
	_gomb = Button.new()
	_gomb.text = tr("INTRO_SKIP")
	_gomb.focus_mode = Control.FOCUS_NONE                    # a szóköz a következő jelenet, ne ezt nyomja meg
	_gomb.anchor_left = 1; _gomb.anchor_right = 1
	_gomb.offset_left = -190; _gomb.offset_right = -18; _gomb.offset_top = 16; _gomb.offset_bottom = 54
	_gomb.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_gomb.modulate.a = 0.85
	_gomb.pressed.connect(atugras)
	_alap.add_child(_gomb)
	if felvetel:
		_sugo.hide()
		_gomb.hide()

func _rajz() -> void:
	if _regi >= 0: _rajz_kep(_regi, _regi_t / _regi_hossz, 1.0)
	if _i >= 0: _rajz_kep(_i, _t / _hossz, clampf(_t / ATTUNES, 0.0, 1.0) if _regi >= 0 else 1.0)

func _rajz_kep(i: int, u: float, alfa: float) -> void:
	var tex: Texture2D = _kepek[i] if _kepek[i] != null else _potkep
	var m: Array = MOZGAS[i]
	u = clampf(u, 0.0, 1.2)       # (az áttűnés alatt a régi kép még mozog tovább egy kicsit)
	var vs := _vaszon.size
	var ts := tex.get_size()
	var alap := maxf(vs.x / ts.x, vs.y / ts.y)          # kitölti a képernyőt (a túllógó rész levágva)
	var meret := ts * alap * maxf(1.0, lerpf(float(m[0]), float(m[1]), u))
	var fokusz := (m[2] as Vector2).lerp(m[3] as Vector2, u).clamp(-Vector2.ONE, Vector2.ONE)
	var kozep := vs / 2.0 - fokusz * (meret - vs) / 2.0
	_vaszon.draw_texture_rect(tex, Rect2(kozep - meret / 2.0, meret), false, Color(1, 1, 1, alfa))

# ── A képsor menete ──────────────────────────────────────────────

func _jelenet(i: int) -> void:
	_regi = _i
	_regi_t = _t
	_regi_hossz = maxf(_hossz, 0.01)
	_i = i
	_t = 0.0
	_hossz = _jelenet_hossz(i)
	_kep_kell(i)
	var sorszam := str(JELENETEK[i]).substr(0, 2)
	_cim.text = tr("INTRO_" + sorszam + "_TITLE")
	_felirat.text = tr("INTRO_" + sorszam)
	_hang.stop()
	_hang_var = _van_hang(i)
	jelenet_valtott.emit(i)

func _process(delta: float) -> void:
	_ossz_t += delta
	_hangero()
	if _zar_t >= 0.0:
		_zar_t += delta
		_fekete.modulate.a = clampf(_zar_t / ZARAS, 0.0, 1.0)
		if _zar_t >= ZARAS: _befejez()
		return
	_t += delta
	if _regi >= 0:
		_regi_t += delta
		if _t >= ATTUNES: _regi = -1
	if _hang_var and _t >= HANG_ELOTT:
		_hang_var = false
		hang_indult.emit(_i)
		if not felvetel:
			_hang.stream = _hangok[_i]
			_hang.play()
	_fekete.modulate.a = 1.0 - clampf(_ossz_t / NYITAS, 0.0, 1.0)
	# a felirat a kép után egy pillanattal úszik be, és a jelenet végén elhalványul
	var a := clampf((_t - 0.35) / 0.6, 0.0, 1.0) * clampf((_hossz - _t) / 0.5, 0.0, 1.0)
	_cim.modulate.a = a
	_felirat.modulate.a = a
	_vaszon.queue_redraw()
	if _t >= _hossz: tovabb()

## A következő jelenet (az utolsó után a vége)
func tovabb() -> void:
	if _zar_t >= 0.0: return
	if _i + 1 < JELENETEK.size(): _jelenet(_i + 1)
	else: atugras()

## Az egész átugrása: elsötétül, és vége
func atugras() -> void:
	if _zar_t >= 0.0: return
	_zar_t = 0.0
	_gomb.disabled = true

func _befejez() -> void:
	set_process(false)
	_hang.stop()
	_zene.stop()
	vege.emit()
	queue_free()

# ── Hang ─────────────────────────────────────────────────────────

func _hangero() -> void:
	if _zene == null: return
	# lágy indulás, a végén elhalkul
	var burok := clampf(_ossz_t / 1.5, 0.0, 1.0)
	if _zar_t >= 0.0: burok *= 1.0 - clampf(_zar_t / ZARAS, 0.0, 1.0)
	var szol: bool = AudioManager.music_on and _zene.stream != null
	if szol and not _zene.playing: _zene.play()
	elif not szol and _zene.playing: _zene.stop()
	var halk := ZENE_HALK_DB if (_i >= 0 and _hangok[_i] != null and AudioManager.sfx_on) else ZENE_CSAK_DB
	_zene.volume_db = AudioManager.MUSIC_BASE_DB + halk + linear_to_db(maxf(AudioManager.music_volume * burok, 0.0001))
	_hang.volume_db = HANG_DB + linear_to_db(maxf(AudioManager.sfx_volume, 0.001))
	if _zar_t >= 0.0: _hang.volume_db += linear_to_db(maxf(1.0 - _zar_t / (ZARAS * 0.5), 0.001))

# ── Bemenet ──────────────────────────────────────────────────────

func _lep() -> void:
	# (két gyors lenyomás ne ugorjon kettőt)
	if _ossz_t - _utolso_lepes < 0.2: return
	_utolso_lepes = _ossz_t
	tovabb()

func _kattintas(ev: InputEvent) -> void:
	if felvetel: return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: _lep()

func _input(ev: InputEvent) -> void:
	if felvetel: return
	# a billentyűzet a képsoré: alatta a menü se gombot, se Esc-et ne kapjon
	if ev is InputEventKey:
		if ev.pressed and not ev.echo and ev.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_RIGHT]:
			_lep()
		get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadButton:
		if ev.pressed: _lep()
		get_viewport().set_input_as_handled()
