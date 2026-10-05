extends Node

# HEPTARCHIA – többjátékos szoba szobakóddal (WebRTC), elsősorban a böngészős változathoz
#
# A böngésző nem tud UDP-portot nyitni (ENet), ezért ott a játékosok WebRTC-vel kapcsolódnak egymáshoz:
#   – a gazdagép szobát nyit, és kap egy rövid szobakódot (pl. K7PQM), ezt elküldi a barátainak;
#   – a csatlakozó beírja a kódot; a két gép a kapcsolat felépítéséhez szükséges adatokat (SDP, ICE) a
#     Supabase Realtime nyilvános üzenetcsatornáján („hep-<kód>”) cseréli ki – ez csak a jelzés, a játék
#     forgalma utána közvetlenül a gépek közt megy (WebRTC adatcsatorna), ugyanúgy, mint ENet-tel;
#   – a csatornához a projekt nyilvános (anon) kulcsa kell, ami a honlapon is ott van – nem titok.
# A többi (lobbi, parancsok, élő csata) változatlanul a Net.gd-ben fut: a WebRTCMultiplayerPeer ugyanúgy
# MultiplayerPeer, mint az ENet; a gazdagép az 1-es azonosító, a vendégek 2-től kapnak számot.
#
# Asztali gépen a WebRTC-hez a webrtc-native kiegészítő (GDExtension) kellene; amíg nincs a játék mellett,
# ott a szoba nem érhető el (elerheto()), és a megszokott IP-cím + port marad.
#
# A jelzések (a csatornán JSON): {"r": "g" (gazdagép) | "v" (vendég), "t": típus, "k": a vendég kulcsa, …}
#   v → g  "join" {v: protokoll}         csatlakozni szeretne (2 mp-enként ismétli, amíg választ nem kap)
#   g → v  "ok"   {id}                   befogadva, ez lesz az azonosítója; utána jön az ajánlat
#   g → v  "nem"  {ok: nyelvi kulcs}      elutasítva (más verzió, már fut a játék)
#   g ↔ v  "sdp"  {tipus, sdp}           a kapcsolat leírása (ajánlat / válasz)
#   g ↔ v  "ice"  {m, i, n}              kapcsolódási jelölt
#   g → g  "van" / "foglalt"             új szoba: foglalt-e már a kód (ritka egyezés esetén új kód)

signal kesz(kod: String)        # a gazdagép szobája megnyílt / új kódot kapott
signal hiba(kulcs: String)      # a szoba vagy a csatlakozás nem sikerült (nyelvi kulcs)
signal vendeg_peer(peer: WebRTCMultiplayerPeer)   # a vendég azonosítót kapott: ez lesz a multiplayer_peer

const JELZO_URL := "wss://gxvepswtairfqvosdcpb.supabase.co/realtime/v1/websocket"
## a Supabase-projekt nyilvános (anon) kulcsa – a honlap és a launcher is ezt használja, csak olvasásra/jelzésre jó
const ANON_KULCS := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4dmVwc3d0YWlyZnF2b3NkY3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk4MzQyMzYsImV4cCI6MjEwNTQxMDIzNn0.9A86POfj49aRynE3rerz4nMbfds7xny6GLuRePpgSSI"
const KOD_BETUK := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # (nincs 0/O, 1/I: diktálva se tévesszék el)
const KOD_HOSSZ := 5
## nyilvános STUN-szerverek (a gépek így tudják meg a saját külső címüket) – ez az alap, közvetítő nélkül
const ICE_SZERVEREK := [{"urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302",
	"stun:stun.cloudflare.com:3478"]}]
## Közvetítő (TURN) szerver: szigorú hálózatok (mobilnet, iskolai / céges hálózat) között a két gép közvetlenül
## nem ér össze, a forgalom ilyenkor a közvetítőn megy át. A hozzá való rövid életű belépőt a honlap
## heptarchia-turn szerverfüggvénye adja (csak bejelentkezett, meghívott fióknak); ha nem ad, marad az alap.
const ICE_URL := "https://gxvepswtairfqvosdcpb.supabase.co/functions/v1/heptarchia-turn"
const ICE_VAR_MP := 5.0         # legfeljebb ennyit várunk a szerverlistára, mielőtt a kapcsolat épülni kezd
## a Net.gd az 1. és a 2. csatornát is használja (a 2. az élő csatáé): a WebRTC-nél ezeket külön meg kell nyitni
const CSATORNAK := [MultiplayerPeer.TRANSFER_MODE_RELIABLE, MultiplayerPeer.TRANSFER_MODE_RELIABLE]
const SZIVVERES_MP := 25.0      # a Realtime-kapcsolat életben tartása
const JOIN_ISMETLES_MP := 2.0
const SZOBA_KERES_MP := 15.0    # ennyi ideig keresi a vendég a szobát
const KAPCSOLODAS_MP := 30.0    # a befogadás után ennyi idő alatt kell felépülnie a közvetlen kapcsolatnak

enum Mod { NINCS, GAZDA, VENDEG }

var mod: int = Mod.NINCS
var kod: String = ""
var rtc: WebRTCMultiplayerPeer = null

var _ws: WebSocketPeer = null
var _topic: String = ""
var _bent: bool = false         # a csatornához csatlakozva (phx_join válasz megjött)
var _ref: int = 0
var _sziv: float = 0.0
var _ujra: float = -1.0         # gazdagép: a megszakadt jelzőkapcsolat újranyitása ennyi mp múlva
# gazdagép
var _vendegek: Dictionary = {}  # vendég kulcsa -> {"id": int, "conn": WebRTCPeerConnection, "ido": float, "kesz": bool}
var _kov_id: int = 2
var _kod_ellenorzes: float = 0.0
# vendég
var _kulcs: String = ""
var _conn: WebRTCPeerConnection = null
var _ido: float = 0.0           # mióta keresi a szobát / mióta kapcsolódik
var _join_ido: float = 0.0
var _befogadva: bool = false
# a kapcsolódáshoz használt szerverek (STUN + a szervertől kapott TURN)
var _ice: Array = ICE_SZERVEREK
var _ice_http: HTTPRequest = null
var _ice_fut: bool = false      # a szerverlista kérése úton van
var _ice_mp: float = 0.0        # mióta

## A szerverlista (a közvetítő belépőjével) lekérése – szobanyitáskor és csatlakozáskor, mindig frissen
func _ice_ker() -> void:
	_ice = ICE_SZERVEREK
	var tok := _token()
	if _proba() or tok == "": return
	if _ice_http == null:
		_ice_http = HTTPRequest.new()
		_ice_http.timeout = 8.0
		_ice_http.request_completed.connect(_ice_valasz)
		add_child(_ice_http)
	if _ice_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED: _ice_http.cancel_request()
	var fej := ["apikey: " + ANON_KULCS, "Authorization: Bearer " + tok, "Content-Type: application/json"]
	_ice_fut = _ice_http.request(ICE_URL, fej, HTTPClient.METHOD_POST, "{}") == OK
	_ice_mp = 0.0

func _ice_valasz(eredmeny: int, kod_http: int, _fej: PackedStringArray, test: PackedByteArray) -> void:
	_ice_fut = false
	if eredmeny != HTTPRequest.RESULT_SUCCESS or kod_http != 200: return
	var d: Variant = JSON.parse_string(test.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("iceServers")) != TYPE_ARRAY: return
	var lista: Array = []
	for s in d["iceServers"]:
		if typeof(s) == TYPE_DICTIONARY and s.has("urls"): lista.append(s)
	if not lista.is_empty(): _ice = lista

## Megvan-e már a szerverlista (vagy eleget vártunk rá): addig a kapcsolat nem kezd épülni
func _ice_kesz() -> bool:
	return not _ice_fut or _ice_mp > ICE_VAR_MP

## Van-e WebRTC ezen a gépen (a böngészőben mindig; asztali gépen csak a webrtc-native kiegészítővel)
static func elerheto() -> bool:
	if OS.has_feature("web"): return true
	return ClassDB.class_exists("WebRTCLibPeerConnection")   # (a webrtc-native kiegészítő osztálya)

## A beírt kód egységesítése (nagybetű, szóköz és kötőjel nélkül); ha idegen karakter van benne, üres
static func kod_tisztit(s: String) -> String:
	var r := ""
	for c in s.strip_edges().to_upper():
		if c in " -": continue
		if not c in KOD_BETUK: return ""
		r += c
	return r if r.length() == KOD_HOSSZ else ""

static func uj_kod() -> String:
	var r := ""
	for i in KOD_HOSSZ: r += KOD_BETUK[randi() % KOD_BETUK.length()]
	return r

# ── Gazdagép ───────────────────────────────────────────────────

## Szobát nyit: a WebRTC-gazdagép (ezt a Net teszi multiplayer_peer-ré), a kód a `kesz` jelzéssel jön
func gazda_nyit() -> WebRTCMultiplayerPeer:
	bezar()
	rtc = WebRTCMultiplayerPeer.new()
	if rtc.create_server(CSATORNAK) != OK:
		rtc = null
		return null
	mod = Mod.GAZDA
	kod = uj_kod()
	_ice_ker()
	_jelzo_nyit()
	return rtc

## A játék elindult: új játékos már nem jöhet, a jelzőcsatorna bezárul (a kapcsolatok maradnak)
func jelzes_vege() -> void:
	_jelzo_zar()
	_ujra = -1.0

# ── Vendég ─────────────────────────────────────────────────────

func vendeg_belep(szoba_kod: String) -> void:
	bezar()
	mod = Mod.VENDEG
	kod = kod_tisztit(szoba_kod)
	var k := PackedByteArray()
	for i in 8: k.append(randi() % 256)
	_kulcs = k.hex_encode()
	_ido = 0.0
	_join_ido = JOIN_ISMETLES_MP
	_befogadva = false
	_ice_ker()
	_jelzo_nyit()

# ── Közös ──────────────────────────────────────────────────────

## Minden lezárása (a Net.leave hívja); a multiplayer_peer-t a Net zárja
func bezar() -> void:
	_jelzo_zar()
	for k in _vendegek:
		var c: WebRTCPeerConnection = _vendegek[k]["conn"]
		if c != null and not bool(_vendegek[k]["kesz"]): c.close()
	_vendegek.clear()
	_conn = null
	rtc = null
	mod = Mod.NINCS
	kod = ""
	_kov_id = 2
	_ujra = -1.0
	_befogadva = false

func _uj_kapcsolat(vendeg_kulcs: String) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	if c.initialize({"iceServers": _ice}) != OK: return null
	c.session_description_created.connect(func(tipus: String, sdp: String) -> void:
		c.set_local_description(tipus, sdp)
		_kuld({"t": "sdp", "k": vendeg_kulcs, "tipus": tipus, "sdp": sdp}))
	c.ice_candidate_created.connect(func(m: String, i: int, n: String) -> void:
		_kuld({"t": "ice", "k": vendeg_kulcs, "m": m, "i": i, "n": n}))
	return c

func _process(delta: float) -> void:
	if mod == Mod.NINCS: return
	if _ice_fut: _ice_mp += delta
	if _ws != null:
		_ws.poll()
		match _ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				if _csatlakozas_var: _csatorna_be()
				_token_frissit()
				while _ws != null and _ws.get_available_packet_count() > 0:
					_fogad(_ws.get_packet().get_string_from_utf8())
				_sziv += delta
				if _sziv >= SZIVVERES_MP:
					_sziv = 0.0
					_ws_kuld({"topic": "phoenix", "event": "heartbeat", "payload": {}, "ref": _uj_ref()})
			WebSocketPeer.STATE_CLOSED:
				_ws = null
				_bent = false
				if mod == Mod.GAZDA:
					_ujra = 3.0
				elif not _befogadva:
					_hiba("MP_SIGNAL_FAILED")
					return
	elif _ujra >= 0.0:
		_ujra -= delta
		if _ujra < 0.0: _jelzo_nyit()
	if mod == Mod.GAZDA: _gazda_lepes(delta)
	elif mod == Mod.VENDEG: _vendeg_lepes(delta)

func _gazda_lepes(delta: float) -> void:
	if _kod_ellenorzes > 0.0:
		_kod_ellenorzes -= delta
	# a félbemaradt kapcsolódások takarítása; a felépült kapcsolatokat a WebRTCMultiplayerPeer viszi tovább
	for k in _vendegek.keys():
		var v: Dictionary = _vendegek[k]
		if bool(v["kesz"]): continue
		var id := int(v["id"])
		if rtc != null and rtc.has_peer(id) and bool(rtc.get_peer(id).get("connected", false)):
			v["kesz"] = true
			continue
		v["ido"] = float(v["ido"]) + delta
		if float(v["ido"]) > KAPCSOLODAS_MP:
			if rtc != null and rtc.has_peer(id): rtc.remove_peer(id)
			_vendegek.erase(k)

func _vendeg_lepes(delta: float) -> void:
	_ido += delta
	if not _befogadva:
		if _bent and _ice_kesz():
			_join_ido += delta
			if _join_ido >= JOIN_ISMETLES_MP:
				_join_ido = 0.0
				_kuld({"t": "join", "k": _kulcs, "v": Net.PROTOCOL_VERSION})
		if _ido > SZOBA_KERES_MP:
			_hiba("MP_ROOM_NOT_FOUND")
		return
	if rtc == null: return
	if rtc.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		# a közvetlen kapcsolat él: a jelzőcsatornára nincs többé szükség
		if _ws != null: _jelzo_zar()
	elif _ido > KAPCSOLODAS_MP:
		_hiba("MP_WEBRTC_FAILED")

func _hiba(kulcs: String) -> void:
	bezar()
	hiba.emit(kulcs)

# ── Jelzések fogadása ──────────────────────────────────────────

func _fogad(szoveg: String) -> void:
	var m: Variant = JSON.parse_string(szoveg)
	if typeof(m) != TYPE_DICTIONARY: return
	var ev := str(m.get("event", ""))
	if ev == "phx_reply" and str(m.get("topic", "")) == _topic and not _bent:
		var p: Dictionary = m.get("payload", {}) if typeof(m.get("payload")) == TYPE_DICTIONARY else {}
		if str(p.get("status", "")) != "ok":
			# a privát csatornára csak bejelentkezett, az online játékra meghívott fiók léphet be (RLS); a többi
			# hiba: a jelzés nem érhető el
			var r := JSON.stringify(p).to_lower()
			if "authoriz" in r or "permission" in r:
				var f: Node = Net.get("fiok")
				_hiba("WEB_ONLINE_INVITE_ONLY" if f != null and not bool(f.call("online_engedelyes")) else "MP_ROOM_AUTH_FAILED")
			else:
				_hiba("MP_SIGNAL_FAILED")
			return
		_bent = true
		if mod == Mod.GAZDA:
			# a kód foglaltságának ellenőrzése: ha egy másik gazdagép válaszol, új kódot választunk
			_kod_ellenorzes = 2.0
			_kuld({"t": "van"})
			kesz.emit(kod)
		return
	if (ev == "phx_error" or ev == "phx_close") and str(m.get("topic", "")) == _topic:
		# a szerver bezárta a csatornát (pl. lejárt token): a gazdagép újra belép, a még várakozó vendég feladja
		_jelzo_zar()
		if mod == Mod.GAZDA: _ujra = 3.0
		elif not _befogadva: _hiba("MP_SIGNAL_FAILED")
		return
	if ev != "broadcast": return
	var b: Variant = m.get("payload", {})
	if typeof(b) != TYPE_DICTIONARY or typeof(b.get("payload")) != TYPE_DICTIONARY: return
	var j: Dictionary = b["payload"]
	if mod == Mod.GAZDA: _gazda_fogad(j)
	elif mod == Mod.VENDEG and str(j.get("r", "")) == "g": _vendeg_fogad(j)

func _gazda_fogad(j: Dictionary) -> void:
	var t := str(j.get("t", ""))
	if str(j.get("r", "")) == "g":
		if t == "van": _kuld({"t": "foglalt"})
		elif t == "foglalt" and _kod_ellenorzes > 0.0:
			# (ritka) a kód már egy másik szobáé: új kód, új csatorna
			kod = uj_kod()
			_jelzo_zar()
			_jelzo_nyit()
		return
	var k := str(j.get("k", ""))
	if k == "" or k.length() > 32: return
	match t:
		"join":
			if int(j.get("v", -1)) != Net.PROTOCOL_VERSION:
				_kuld({"t": "nem", "k": k, "ok": "MP_VERSION_MISMATCH"})
				return
			if Net.in_game:
				_kuld({"t": "nem", "k": k, "ok": "MP_GAME_RUNNING"})
				return
			if _vendegek.has(k):
				# ismételt kérés (a válaszunk még úton volt): ugyanaz az azonosító
				_kuld({"t": "ok", "k": k, "id": int(_vendegek[k]["id"])})
				return
			# (a szerverlista még úton van: a vendég 2 mp múlva újra kér, addigra megjön)
			if not _ice_kesz(): return
			var id := _kov_id
			_kov_id += 1
			var c := _uj_kapcsolat(k)
			if c == null or rtc == null or rtc.add_peer(c, id) != OK:
				_kuld({"t": "nem", "k": k, "ok": "MP_WEBRTC_FAILED"})
				return
			_vendegek[k] = {"id": id, "conn": c, "ido": 0.0, "kesz": false}
			_kuld({"t": "ok", "k": k, "id": id})
			c.create_offer()
		"sdp":
			var v: Dictionary = _vendegek.get(k, {})
			if not v.is_empty() and not bool(v["kesz"]):
				(v["conn"] as WebRTCPeerConnection).set_remote_description(str(j.get("tipus", "")), str(j.get("sdp", "")))
		"ice":
			var v: Dictionary = _vendegek.get(k, {})
			if not v.is_empty() and not bool(v["kesz"]):
				(v["conn"] as WebRTCPeerConnection).add_ice_candidate(str(j.get("m", "")), int(j.get("i", 0)), str(j.get("n", "")))

func _vendeg_fogad(j: Dictionary) -> void:
	if str(j.get("k", "")) != _kulcs: return
	match str(j.get("t", "")):
		"ok":
			if _befogadva: return
			var id := int(j.get("id", 0))
			if id < 2: return
			rtc = WebRTCMultiplayerPeer.new()
			if rtc.create_client(id, CSATORNAK) != OK:
				_hiba("MP_WEBRTC_FAILED")
				return
			_conn = _uj_kapcsolat(_kulcs)
			if _conn == null or rtc.add_peer(_conn, 1) != OK:
				_hiba("MP_WEBRTC_FAILED")
				return
			_befogadva = true
			_ido = 0.0
			vendeg_peer.emit(rtc)
		"nem":
			_hiba(str(j.get("ok", "MP_CONNECT_FAILED")))
		"sdp":
			# a gazdagép ajánlata: a válasz magától elkészül (session_description_created)
			if _conn != null: _conn.set_remote_description(str(j.get("tipus", "")), str(j.get("sdp", "")))
		"ice":
			if _conn != null: _conn.add_ice_candidate(str(j.get("m", "")), int(j.get("i", 0)), str(j.get("n", "")))

# ── A jelzőcsatorna (Supabase Realtime, Phoenix-protokoll) ─────

func _jelzo_nyit() -> void:
	_jelzo_zar()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 256 * 1024
	_ws.outbound_buffer_size = 256 * 1024
	if _ws.connect_to_url(JELZO_URL + "?apikey=" + ANON_KULCS + "&vsn=1.0.0") != OK:
		_ws = null
		if mod == Mod.GAZDA: _ujra = 5.0
		else: _hiba.call_deferred("MP_SIGNAL_FAILED")
		return
	_topic = "realtime:hep-" + kod
	_bent = false
	_sziv = 0.0
	_csatlakozas_var = true

var _csatlakozas_var: bool = false   # a websocket megnyílása után kell elküldeni a csatlakozást
var _kuldott_token: String = ""

## A csatlakozás a csatornához (a websocket megnyílásakor egyszer). A szoba csatornája PRIVÁT: csak érvényes
## fióktokennel lehet belépni (a Supabase realtime.messages RLS-szabályai csak a bejelentkezett fiókokat
## engedik be – lásd a honlap server/supabase/schema_heptarchia_web.sql fájlját); névtelenül nem.
## (A hibakereső export helyi próbájában – fiók nélkül – nyilvános csatorna.)
func _csatorna_be() -> void:
	_csatlakozas_var = false
	var payload := {"config": {"broadcast": {"self": false, "ack": false}, "presence": {"key": ""}, "private": not _proba()}}
	var tok := _token()
	if tok != "" and not _proba(): payload["access_token"] = tok
	_kuldott_token = tok
	_ws_kuld({"topic": _topic, "event": "phx_join", "ref": _uj_ref(), "join_ref": "1", "payload": payload})

## A fiók tokenje (a böngészős változatban a web_fiok.gd adja); a megújult tokent a csatorna is megkapja
func _token() -> String:
	var f: Node = Net.get("fiok")
	return str(f.get("token")) if f != null else ""

func _proba() -> bool:
	var f: Node = Net.get("fiok")
	return f == null or bool(f.get("teszt"))

func _token_frissit() -> void:
	if _ws == null or not _bent or _proba(): return
	var tok := _token()
	if tok == "" or tok == _kuldott_token: return
	_kuldott_token = tok
	_ws_kuld({"topic": _topic, "event": "access_token", "ref": _uj_ref(), "join_ref": "1", "payload": {"access_token": tok}})

func _jelzo_zar() -> void:
	_csatlakozas_var = false
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _bent:
			_ws_kuld({"topic": _topic, "event": "phx_leave", "payload": {}, "ref": _uj_ref(), "join_ref": "1"})
		_ws.close()
	_ws = null
	_bent = false

func _kuld(j: Dictionary) -> void:
	if _ws == null or not _bent: return
	j["r"] = "g" if mod == Mod.GAZDA else "v"
	_ws_kuld({"topic": _topic, "event": "broadcast", "ref": _uj_ref(), "join_ref": "1",
		"payload": {"type": "broadcast", "event": "sig", "payload": j}})

func _ws_kuld(m: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(m))

func _uj_ref() -> String:
	_ref += 1
	return str(_ref)
