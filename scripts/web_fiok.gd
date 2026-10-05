extends CanvasLayer

# HEPTARCHIA – fiók a böngészős változatban: csak bejelentkezett (regisztrált) játékos játszhat
#
# A belépés a weboldalon történik (web/shell.html, a honlap fiókrendszere: Supabase, ugyanaz a fiók, mint a
# ParthLauncherben); az oldal a játéknak a window.hepFiok objektumban adja át a munkamenetet:
#   hepFiok.token – a fiók érvényes hozzáférési tokenje (az oldal magától megújítja), hepFiok.nev – a fióknév,
#   hepFiok.kilep() – kijelentkezés (az oldal újratölt, és a belépőlap jön).
# A játék induláskor és utána 5 percenként a szerverrel is ellenőrizteti a tokent (/auth/v1/user). Ha nincs
# belépés, vagy a szerver elutasítja, egy minden fölött álló réteg letakarja a játékot (Belépés gomb).
# A többjátékos szoba jelzőcsatornája is ezzel a tokennel nyílik (privát Realtime-csatorna, lásd net_szoba.gd).
# Online (többjátékos) játék csak a meghívott fiókoknak: a szerver a heptarchia_online_engedelyes() függvénnyel
# dönt (a szobacsatornák szabályai is ezt használják – lásd a honlap server/supabase/schema_heptarchia_online.sql
# fájlját); a játék ugyanezt kérdezi meg, hogy a Többjátékos gombot letiltsa, és megmondja, miért.
#
# Fejlesztői próba: csak a hibakereső (debug) exportban, helyi gépen (?teszt=1) – a kiadott játékban nincs ilyen.

signal valtozott

const AUTH_URL := "https://gxvepswtairfqvosdcpb.supabase.co/auth/v1/user"
const ONLINE_URL := "https://gxvepswtairfqvosdcpb.supabase.co/rest/v1/rpc/heptarchia_online_engedelyes"
const ELLENORZES_MP := 300.0
const TOKEN_FIGYELES_MP := 2.0

## Csak a hivatalos oldalon fut (és fejlesztéskor a saját gépen): a máshová másolt változat nem indul el.
## (A szerverfüggvény is csak ezeknek az oldalaknak adja ki a játékcsomagot – lásd heptarchia-web.)
const ENGEDETT_OLDALAK := ["https://parthenon2-boop.github.io"]

enum Allapot { VAR, OK, NINCS, HALOZAT, IDEGEN }

var allapot: int = Allapot.VAR
var nev: String = ""
var token: String = ""
var teszt: bool = false
## Online (többjátékos) játék: -1 = még nem tudjuk (ellenőrzés folyik), 0 = nincs meghívva, 1 = meghívott fiók
var online: int = -1

var _http: HTTPRequest
var _http_online: HTTPRequest
var _online_tok: String = ""
var _online_ido: float = 0.0
var _ido: float = 0.0
var _figyel: float = 0.0
var _ellenoriz_tok: String = ""
var _reteg: Control
var _uzenet: Label
var _gomb_belep: Button
var _gomb_ujra: Button

func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.request_completed.connect(_valasz)
	add_child(_http)
	_http_online = HTTPRequest.new()
	_http_online.timeout = 20.0
	_http_online.request_completed.connect(_online_valasz)
	add_child(_http_online)
	_reteg_epit()
	if not _engedett_oldal():
		allapot = Allapot.IDEGEN
		set_process(false)
		_mutat()
		return
	_beolvas()
	if teszt:
		allapot = Allapot.OK
		# (a helyi próbában – fiók nélkül – az online játék is kipróbálható; ?online=0: a letiltott gomb próbája)
		online = 0 if str(JavaScriptBridge.eval("/[?&]online=0/.test(location.search) ? 'nem' : 'igen'", true)) == "nem" else 1
		_mutat()
		return
	_ellenoriz()

## Belépve-e (a szerver elfogadta a tokent)
func belepve() -> bool:
	return allapot == Allapot.OK

## Játszhat-e online (többjátékos szobában) ez a fiók – csak a meghívottak; a szerver is ellenőrzi
func online_engedelyes() -> bool:
	return allapot == Allapot.OK and online == 1

## Az online játék jogának megkérdezése a szervertől (a belépett fiók nevében; RLS-t tiszteletben tartó hívás)
func _online_ellenoriz() -> void:
	if teszt or token == "": return
	if _http_online.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	_online_tok = token
	var fej := ["apikey: " + preload("res://scripts/net_szoba.gd").ANON_KULCS, "Authorization: Bearer " + token,
		"Content-Type: application/json"]
	_http_online.request(ONLINE_URL, fej, HTTPClient.METHOD_POST, "{}")

func _online_valasz(eredmeny: int, kod: int, _fej: PackedStringArray, test: PackedByteArray) -> void:
	var regi := online
	if eredmeny != HTTPRequest.RESULT_SUCCESS or kod == 0 or kod >= 500:
		# hálózati hiba: ha már tudjuk, marad; különben a következő ellenőrzéskor újra
		pass
	elif kod == 200:
		online = 1 if test.get_string_from_utf8().strip_edges() == "true" else 0
	elif _online_tok == token:
		# (nincs ilyen függvény a szerveren, vagy elutasította: nem engedjük – a szerver amúgy sem engedné be)
		online = 0
	if online != regi: valtozott.emit()

func kilep() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.hepFiok && window.hepFiok.kilep()", true)

## A belépőlap (az oldal újratöltése: a belépés a weboldalon van)
func belepes_lap() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("location.reload()", true)

static func _engedett_oldal() -> bool:
	if not OS.has_feature("web"): return true
	var hol := str(JavaScriptBridge.eval("location.origin", true))
	if hol in ENGEDETT_OLDALAK: return true
	for h in ["http://localhost", "http://127.0.0.1"]:
		if hol == h or hol.begins_with(h + ":"): return true
	return false

func _beolvas() -> void:
	if not OS.has_feature("web"): return
	var s: Variant = JavaScriptBridge.eval("window.hepFiok ? JSON.stringify({t: window.hepFiok.token || '', " +
		"n: window.hepFiok.nev || '', p: !!window.hepFiok.teszt}) : ''", true)
	var d: Variant = JSON.parse_string(str(s)) if str(s) != "" else null
	if typeof(d) != TYPE_DICTIONARY: return
	token = str(d.get("t", ""))
	if str(d.get("n", "")) != "": nev = str(d["n"]).left(20)
	# a próbaüzem csak a hibakereső exportban, helyben él (az oldal is csak localhoston kapcsolja be)
	teszt = bool(d.get("p", false)) and OS.is_debug_build()

func _process(delta: float) -> void:
	if teszt: return
	_figyel += delta
	if _figyel >= TOKEN_FIGYELES_MP:
		_figyel = 0.0
		var regi := token
		_beolvas()
		if token != regi:
			# (az oldal megújította a tokent, vagy kijelentkezett egy másik lapon)
			valtozott.emit()
			if token == "":
				allapot = Allapot.NINCS
				_mutat()
	_ido += delta
	if _ido >= ELLENORZES_MP or (allapot == Allapot.HALOZAT and _ido >= 15.0):
		_ellenoriz()
	# az online jog kérdése nem ment át (hálózat): 15 mp múlva újra
	if allapot == Allapot.OK and online < 0:
		_online_ido += delta
		if _online_ido >= 15.0:
			_online_ido = 0.0
			_online_ellenoriz()

func _ellenoriz() -> void:
	_ido = 0.0
	if token == "":
		allapot = Allapot.NINCS
		_mutat()
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: return
	_ellenoriz_tok = token
	var fej := ["apikey: " + preload("res://scripts/net_szoba.gd").ANON_KULCS, "Authorization: Bearer " + token]
	if _http.request(AUTH_URL, fej) != OK:
		allapot = Allapot.HALOZAT if allapot != Allapot.OK else allapot
		_mutat()

func _valasz(eredmeny: int, kod: int, _fej: PackedStringArray, test: PackedByteArray) -> void:
	if eredmeny != HTTPRequest.RESULT_SUCCESS or kod >= 500 or kod == 0:
		# hálózati hiba: ha már be volt lépve, nem zavarjuk a játékot; induláskor szólunk
		if allapot != Allapot.OK: allapot = Allapot.HALOZAT
	elif kod == 200:
		allapot = Allapot.OK
		# (a meghívás menet közben is változhat: minden ellenőrzéskor újra megkérdezzük)
		_online_ellenoriz()
		var d: Variant = JSON.parse_string(test.get_string_from_utf8())
		if nev == "" and typeof(d) == TYPE_DICTIONARY and typeof(d.get("user_metadata")) == TYPE_DICTIONARY:
			nev = str(d["user_metadata"].get("username", "")).left(20)
	elif _ellenoriz_tok == token:
		# a szerver elutasította (lejárt, visszavont, felfüggesztett fiók)
		allapot = Allapot.NINCS
	_mutat()
	valtozott.emit()

# ── A takaró réteg ─────────────────────────────────────────────

func _reteg_epit() -> void:
	_reteg = ColorRect.new()
	(_reteg as ColorRect).color = Color(0.05, 0.035, 0.02, 0.97)
	_reteg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reteg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_reteg)
	var dob := VBoxContainer.new()
	dob.set_anchors_preset(Control.PRESET_CENTER)
	dob.offset_left = -300; dob.offset_right = 300; dob.offset_top = -110; dob.offset_bottom = 110
	dob.alignment = BoxContainer.ALIGNMENT_CENTER
	dob.add_theme_constant_override("separation", 16)
	_reteg.add_child(dob)
	var cim := Label.new()
	cim.text = "HEPTARCHIA"
	cim.theme_type_variation = &"TitleLabel"
	cim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dob.add_child(cim)
	_uzenet = Label.new()
	_uzenet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_uzenet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dob.add_child(_uzenet)
	var sor := HBoxContainer.new()
	sor.alignment = BoxContainer.ALIGNMENT_CENTER
	sor.add_theme_constant_override("separation", 12)
	dob.add_child(sor)
	_gomb_belep = Button.new()
	_gomb_belep.custom_minimum_size = Vector2(200, 42)
	_gomb_belep.pressed.connect(belepes_lap)
	sor.add_child(_gomb_belep)
	_gomb_ujra = Button.new()
	_gomb_ujra.custom_minimum_size = Vector2(200, 42)
	_gomb_ujra.pressed.connect(func() -> void:
		_beolvas()
		_ellenoriz())
	sor.add_child(_gomb_ujra)
	_mutat()

func _mutat() -> void:
	if _reteg == null: return
	_reteg.visible = allapot != Allapot.OK
	_gomb_belep.text = tr("WEB_LOGIN_BUTTON")
	_gomb_ujra.text = tr("WEB_RETRY")
	_gomb_ujra.visible = allapot == Allapot.HALOZAT
	match allapot:
		Allapot.VAR: _uzenet.text = tr("WEB_ACCOUNT_CHECKING")
		Allapot.HALOZAT: _uzenet.text = tr("WEB_ACCOUNT_OFFLINE")
		Allapot.IDEGEN: _uzenet.text = tr("WEB_WRONG_SITE")
		_: _uzenet.text = tr("WEB_ACCOUNT_REQUIRED")
	_gomb_belep.visible = allapot == Allapot.NINCS or allapot == Allapot.HALOZAT
