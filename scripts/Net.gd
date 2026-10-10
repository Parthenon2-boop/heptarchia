extends Node

# HEPTARCHIA – hálózat és parancskezelés
#
# Minden játékos-műveletet a request() visz végbe:
#   – egyjátékos módban azonnal, helyben (GameManager.execute),
#   – többjátékosban a gazdagép / szerver hajtja végre, majd a teljes állapotot minden kliensnek elküldi.
#
# Kapcsolat: ENet (UDP). Interneten a gazdagép UPnP-vel megpróbálja megnyitni a portot a routeren;
# ha ez nem sikerül, kézi porttovábbítás kell, vagy dedikált szerver egy nyilvános gépen:
#   godot --headless --path . -- --server --port=7777 [--upnp]
# A böngészős változatban (és ahol WebRTC van): szoba szobakóddal – WebRTC, lásd net_szoba.gd. A többi ugyanaz.

signal lobby_changed
signal state_changed
signal command_result(result: Dictionary)
signal notification_received(note: Dictionary)
signal game_started
signal connection_failed
signal session_ended(reason_key: String)
signal upnp_finished(success: bool, external_ip: String)
signal chat_received(msg: Dictionary)

signal elo_lista_valtozott                 # a futó élő csaták listája változott (a térkép jelzője)
signal elo_csata_nyilt(halo: Node)         # ezen a gépen egy élő csata nézete nyílik (hadvezérként vagy nézőként)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8
const PROTOCOL_VERSION := 21   # 21: szoba szobakóddal (WebRTC), a nagy csomagok darabolása ("_rpc_darab") · 20: az ostrom csatatere (a fjordi város mellett hegyfal) · 19: a csatatér tája (a cfg "taj": biom, elrendezés, falvak, hidak), egy katona = egy alak (a vezér testőrsége a seregből), lágyabb ütközés a saját blokkok közt · 18: uralkodóházak (gyermekek, házassági pár a "marriage" feltételeiben, öröklés) · 17: hadiköd és kémek ("spy" parancs, kémjelentések a realms-ben) · 16: éves körök (évek körönként), a meghódított város sorsa ("conquest" parancs), raktár és kincstár · 15: a fal tornyain átjáró védők (az ostrom útkeresése és rajza) · 14: városostrom (a város a csatatéren, ostromgépek, felmentő sereg, kitörés – az élő csata új mezői; a hadjárat ostromai) · 13: élő, közösen vezetett taktikai csata, tömörített állapot (12: lázadásveszély, kiesés/trónváltás értesítésként; 11: csevegés, kereskedelmi csere, hajóút; 10: ping-üzenetek)

var active: bool = false        # többjátékos munkamenet fut
var is_host: bool = false
var dedicated: bool = false     # szerver helyi játékos nélkül
var in_game: bool = false
var players: Dictionary = {}    # peer_id -> {"name": String, "faction": int, "ready": bool}
var external_ip: String = ""
var upnp_ok: bool = false
var upnp_cgnat: bool = false    # a router külső címe sem nyilvános (a szolgáltató is NAT mögé tesz)
var port: int = DEFAULT_PORT
var server_address: String = ""
## Folytatott (mentett) többjátékos hadjárat: csak a mentés emberi népei választhatók (a gazdagép a mentésből veszi,
## a lobbi adataival a kliensek is megkapják). Üres: új játék, minden nép választható.
var mentes_nepek: Array = []

var _upnp: UPNP
var _upnp_thread: Thread

# Ping: a gazdagép PING_IDOKOZ másodpercenként időbélyeget küld minden kliensnek, az visszaküldi,
# a gazdagép kiszámolja a kör-időt (ms), és a táblát mindenkinek szétküldi (Tab-os játékoslista).
const PING_IDOKOZ := 2.0
var pings: Dictionary = {}      # peer_id -> ms (a gazdagép saját sora nincs benne)
var _ping_ido: float = 0.0

const NetSzoba := preload("res://scripts/net_szoba.gd")
const WebFiok := preload("res://scripts/web_fiok.gd")
var szoba: Node = null          # a szobakódos (WebRTC) kapcsolat jelzései (net_szoba.gd)
var fiok: Node = null           # a böngészős változatban: a bejelentkezett fiók (web_fiok.gd)
var meghivo_kod: String = ""    # a böngészős változatban: a meghívó link szobakódja (egyszer használódik)

func _ready() -> void:
	szoba = NetSzoba.new()
	szoba.name = "Szoba"
	add_child(szoba)
	szoba.connect("hiba", _szoba_hiba)
	szoba.connect("kesz", func(_kod: String) -> void: lobby_changed.emit())
	szoba.connect("vendeg_peer", func(p: MultiplayerPeer) -> void: multiplayer.multiplayer_peer = p)
	if OS.has_feature("web"):
		fiok = WebFiok.new()
		fiok.name = "Fiok"
		add_child(fiok)
		# meghívó link (…/?szoba=K7PQM): a főmenü rögtön a lobbiba visz, a kód beírva
		meghivo_kod = NetSzoba.kod_tisztit(str(JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('szoba') || ''", true)))
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	var args := OS.get_cmdline_user_args()
	if "--server" in args:
		var p := DEFAULT_PORT
		for a in args:
			if a.begins_with("--port="): p = int(a.trim_prefix("--port="))
		_start_dedicated.call_deferred(p, "--upnp" in args)

# ── Munkamenet ─────────────────────────────────────────────────

func host_game(player_name: String, host_port: int, use_upnp: bool) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(host_port, MAX_CLIENTS)
	if err != OK: return err
	multiplayer.multiplayer_peer = peer
	active = true; is_host = true; in_game = false; port = host_port
	players = {}
	mentes_nepek = SaveManager.mp_nepek()
	if not dedicated:
		players[1] = {"name": _clean_name(player_name), "faction": _first_free_faction(), "ready": false}
	if use_upnp: _start_upnp(host_port)
	lobby_changed.emit()
	return OK

func join_game(player_name: String, address: String, join_port: int) -> int:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), join_port)
	if err != OK: return err
	multiplayer.multiplayer_peer = peer
	active = true; is_host = false; in_game = false; port = join_port
	server_address = address
	players = {}
	set_meta("pending_name", _clean_name(player_name))
	return OK

## Szoba nyitása szobakóddal (WebRTC): a kódot a szoba.kod adja, amint a jelzőcsatorna él (lobby_changed)
func host_szoba(player_name: String) -> int:
	leave()
	var peer: MultiplayerPeer = szoba.call("gazda_nyit")
	if peer == null: return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	active = true; is_host = true; in_game = false
	players = {}
	mentes_nepek = SaveManager.mp_nepek()
	players[1] = {"name": _clean_name(player_name), "faction": _first_free_faction(), "ready": false}
	lobby_changed.emit()
	return OK

## Csatlakozás szobakóddal: a gazdagép a jelzőcsatornán befogad, utána a kapcsolat közvetlenül épül fel
## (a multiplayer_peer a szoba vendeg_peer jelzésére áll be; a bejelentkezés innen a megszokott _rpc_hello)
func join_szoba(player_name: String, kod: String) -> int:
	leave()
	if NetSzoba.kod_tisztit(kod).length() != NetSzoba.KOD_HOSSZ: return ERR_INVALID_PARAMETER
	active = true; is_host = false; in_game = false
	server_address = NetSzoba.kod_tisztit(kod)
	players = {}
	set_meta("pending_name", _clean_name(player_name))
	szoba.call("vendeg_belep", kod)
	lobby_changed.emit()
	return OK

## Szobakódos munkamenet-e (a lobbi ehhez mást ír ki)
func szobas() -> bool:
	return active and szoba != null and int(szoba.get("mod")) != 0

func _szoba_hiba(kulcs: String) -> void:
	if not active: return
	var volt_jatek := in_game
	leave()
	session_ended.emit("MP_HOST_LEFT" if volt_jatek else kulcs)

func leave() -> void:
	if szoba != null: szoba.call("bezar")
	_darabok.clear()
	if _upnp:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false; is_host = false; in_game = false
	players = {}
	pings = {}
	mentes_nepek = []
	_chat_ido = {}
	_elo_takarit()
	GameManager.is_multiplayer = false

func _start_dedicated(p: int, use_upnp: bool) -> void:
	dedicated = true
	var err := host_game("", p, use_upnp)
	if err != OK:
		printerr("Heptarchia server: nem sikerült elindítani a szervert a %d porton (hiba %d)" % [p, err])
		get_tree().quit(1)
		return
	print("Heptarchia server fut: UDP port %d. A játékosok a szerver címével és ezzel a porttal csatlakozhatnak." % p)

func my_peer_id() -> int:
	return multiplayer.get_unique_id() if active else 1

func my_player() -> Dictionary:
	return players.get(my_peer_id(), {})

# Dedikált szervernél a legrégebben csatlakozott játékos indíthatja a játékot
func is_lobby_leader() -> bool:
	if not active: return false
	if is_host and not dedicated: return true
	var ids := players.keys()
	ids.sort()
	return not ids.is_empty() and ids[0] == my_peer_id()

func can_start() -> bool:
	if players.is_empty(): return false
	var used := {}
	for id in players:
		var pl: Dictionary = players[id]
		if not pl["ready"] or used.has(pl["faction"]): return false
		used[pl["faction"]] = true
	return true

func peer_for_faction(faction: int) -> int:
	for id in players:
		if players[id]["faction"] == faction: return id
	return 0

func _clean_name(n: String) -> String:
	n = n.strip_edges().left(20)
	return n if n != "" else "Thegn"

## A lobbiban választható népek (folytatott hadjáratnál a mentés népei)
func valaszthato_nepek() -> Array:
	return mentes_nepek if not mentes_nepek.is_empty() else GameManager.PLAYABLE_FACTIONS

func _first_free_faction(exclude_peer: int = 0) -> int:
	for f in valaszthato_nepek():
		if peer_for_faction(f) == 0 or peer_for_faction(f) == exclude_peer:
			return f
	return -1

# ── Kapcsolati események ───────────────────────────────────────

func _on_connected_to_server() -> void:
	_turelmes(1)
	_rpc_hello.rpc_id(1, get_meta("pending_name", "Thegn"), PROTOCOL_VERSION)

func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	session_ended.emit("MP_HOST_LEFT" if was_in_game else "MP_CONNECTION_LOST")

func _on_peer_connected(id: int) -> void:
	# a játékos a _rpc_hello üzenettel jelentkezik be
	if is_host: _turelmes(id)

## A kapcsolat türelmesebb: a térkép és a csatatér felépítése gyengébb gépen sokáig foglalhatja a szálat (a
## harmadik-negyedik játékos is egyszerre tölt) – ne bontsa a kapcsolatot 45 mp-en belül (az ENet alapja 5 mp: a
## gyengébb gép a térkép betöltése alatt kiesett). A szabályos kilépést így is azonnal észleli, csak a hirtelen
## megszakadt kapcsolatot később (élő csatában ennyi idő után veszi át a gép az oldalát).
const ENET_TIMEOUT := [32, 45000, 90000]
func _turelmes(id: int) -> void:
	if not multiplayer.multiplayer_peer is ENetMultiplayerPeer: return
	var p := (multiplayer.multiplayer_peer as ENetMultiplayerPeer).get_peer(id)
	if p != null: p.set_timeout(ENET_TIMEOUT[0], ENET_TIMEOUT[1], ENET_TIMEOUT[2])

func _on_peer_disconnected(id: int) -> void:
	if not is_host or not players.has(id): return
	var faction: int = players[id]["faction"]
	players.erase(id)
	pings.erase(id)
	print("Heptarchia: kilépett egy játékos (peer %d)" % id)
	if in_game:
		# az élő csatáiban a gép veszi át az oldalát (ha néző volt, egyszerűen kimarad)
		for cid in elo_csatak:
			(elo_csatak[cid]["gazda"] as Node).call("kilepett", id)
		if faction in GameManager.human_factions:
			GameManager.set_ai_controlled(faction)
			for f in GameManager.human_factions:
				GameManager.notify(f, "MP_TITLE", [], "MP_PLAYER_LEFT", [GameManager.faction_key(faction)])
		if GameManager.human_factions.is_empty() or players.is_empty():
			in_game = false
			_elo_takarit()
			print("Heptarchia: mindenki kilépett, a szerver visszaáll a lobbiba")
		elif GameManager.all_humans_ready() and elo_csatak.is_empty():
			GameManager.next_turn()
		_publish()
	_broadcast_lobby()

# ── Lobbi ──────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(player_name: String, version: int) -> void:
	if not is_host: return
	var sender := multiplayer.get_remote_sender_id()
	var reason := ""
	if version != PROTOCOL_VERSION: reason = "MP_VERSION_MISMATCH"
	elif in_game: reason = "MP_GAME_RUNNING"
	elif _first_free_faction() < 0: reason = "MP_LOBBY_FULL"
	if reason != "":
		_rpc_rejected.rpc_id(sender, reason)
		get_tree().create_timer(0.5).timeout.connect(_kick.bind(sender))
		return
	players[sender] = {"name": _clean_name(player_name), "faction": _first_free_faction(), "ready": false}
	print("Heptarchia: csatlakozott %s (peer %d)" % [players[sender]["name"], sender])
	# a kiegészítőknek egyezniük kell (más a térkép és a frakciók); ha nem, a kliens maga lép ki
	_rpc_dlcs.rpc_id(sender, DLC.active_ids())
	_broadcast_lobby()

@rpc("authority", "call_remote", "reliable")
func _rpc_dlcs(host_dlcs: Array) -> void:
	var sorted := host_dlcs.duplicate()
	sorted.sort()
	if sorted != DLC.active_ids():
		leave()
		session_ended.emit("MP_DLC_MISMATCH")

func _kick(peer: int) -> void:
	var mp := multiplayer.multiplayer_peer
	if mp != null and not mp is OfflineMultiplayerPeer:
		mp.disconnect_peer(peer)

@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	leave()
	session_ended.emit(reason)

func _broadcast_lobby() -> void:
	if not is_host: return
	var beall := elo_beall.duplicate()
	beall["mentes_nepek"] = mentes_nepek
	beall["ev_kor"] = ev_kor
	beall["ai_szint"] = ai_szint
	_rpc_lobby.rpc(players, beall)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(new_players: Dictionary, beall: Dictionary) -> void:
	players = new_players
	_elo_beall_be(beall)
	mentes_nepek = (beall.get("mentes_nepek", []) as Array).duplicate()
	ev_kor = int(beall.get("ev_kor", 1))
	ai_szint = str(beall.get("ai_szint", "eros"))
	lobby_changed.emit()

func set_faction(faction: int) -> void:
	if is_host: _host_set_faction(1, faction)
	else: _rpc_set_faction.rpc_id(1, faction)

func set_ready(ready: bool) -> void:
	if is_host: _host_set_ready(1, ready)
	else: _rpc_set_ready.rpc_id(1, ready)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_faction(faction: int) -> void:
	_host_set_faction(multiplayer.get_remote_sender_id(), faction)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_ready(ready: bool) -> void:
	_host_set_ready(multiplayer.get_remote_sender_id(), ready)

func _host_set_faction(peer: int, faction: int) -> void:
	if in_game or not players.has(peer) or not faction in valaszthato_nepek(): return
	var owner := peer_for_faction(faction)
	if owner != 0 and owner != peer: return
	players[peer]["faction"] = faction
	players[peer]["ready"] = false
	_broadcast_lobby()

func _host_set_ready(peer: int, ready: bool) -> void:
	if in_game or not players.has(peer): return
	players[peer]["ready"] = ready
	_broadcast_lobby()

func start_game() -> void:
	if is_host: _host_start(1)
	else: _rpc_start_request.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_start_request() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if dedicated:
		var ids := players.keys()
		ids.sort()
		if not ids.is_empty() and ids[0] == sender:
			_host_start(sender)

func _host_start(_requester: int) -> void:
	if not is_host or in_game or not can_start(): return
	var factions: Array = []
	for id in players:
		factions.append(players[id]["faction"])
	# folytatott hadjárat (a lobbi a gazdagép mentéséből indult), különben új
	if not (SaveManager.mp_folytatas != "" and SaveManager.mp_inditas(factions)):
		SaveManager.uj_hadjarat()
		GameManager.next_years_per_turn = ev_kor
		GameManager.next_ai_difficulty = ai_szint
		GameManager.new_game_multiplayer(factions)
	mentes_nepek = []
	# a gép rohamai az emberek tartományai ellen az emberek elé kerülnek (maguk vezethetik a védekezést)
	GameManager.taktikai_vedekezes = true
	in_game = true
	print("Heptarchia: a játék elindult, királyságok: %s" % str(factions))
	# szobakódos játéknál a szoba ezzel bezárul (a jelzőcsatorna; a kapcsolatok maradnak)
	if szoba != null: szoba.call("jelzes_vege")
	_nagy_kuld(0, DARAB_START, tomorit(GameManager.serialize_state()), players)
	if not dedicated:
		_enter_game(players[1]["faction"])

@rpc("authority", "call_remote", "reliable")
func _rpc_start(state: PackedByteArray, new_players: Dictionary) -> void:
	_start_be(state, new_players)

func _start_be(state: PackedByteArray, new_players: Dictionary) -> void:
	players = new_players
	in_game = true
	var adat: Variant = kibont(state)
	if typeof(adat) != TYPE_DICTIONARY: return
	GameManager.apply_state(adat)
	_enter_game(players.get(my_peer_id(), {}).get("faction", GameManager.PLAYABLE_FACTIONS[0]))

func _enter_game(faction: int) -> void:
	GameManager.player_faction = faction
	GameManager.cancel_move_mode()
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

# ── Parancsok ──────────────────────────────────────────────────

# Játékos-művelet kérése (építés, menetelés, támadás, diplomácia, kör vége…)
func request(cmd: String, args: Dictionary = {}) -> void:
	if not active:
		_handle(GameManager.player_faction, cmd, args, 0)
	elif is_host:
		_handle(players[1]["faction"], cmd, args, 1)
	else:
		_rpc_request.rpc_id(1, cmd, args)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(cmd: String, args: Dictionary) -> void:
	if not is_host or not in_game: return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender): return
	_handle(players[sender]["faction"], cmd, args, sender)

func _handle(faction: int, cmd: String, args: Dictionary, peer: int) -> void:
	var result: Dictionary
	# többjátékosban a taktikai csata eredményét csak a gazdagép élő csatája adhatja (lásd _elo_vege)
	if active: args.erase("tactical")
	var zar := _elo_zar(faction, cmd, args)
	if zar != "":
		result = {"cmd": cmd, "args": args, "ok": false, "reason": zar}
	elif cmd == "end_turn":
		result = _end_turn(faction, bool(args.get("ready", true)))
	else:
		result = GameManager.execute(faction, cmd, args)
	_publish()
	if peer <= 1:
		command_result.emit(result)
	else:
		_rpc_result.rpc_id(peer, result)

func _end_turn(faction: int, ready: bool) -> Dictionary:
	var result := {"cmd": "end_turn", "ok": true, "advanced": false}
	if not active:
		GameManager.next_turn()
		result["advanced"] = true
		return result
	if not faction in GameManager.human_factions: return result
	if ready:
		if not faction in GameManager.ready_factions:
			GameManager.ready_factions.append(faction)
	else:
		GameManager.ready_factions.erase(faction)
	if GameManager.all_humans_ready():
		# amíg élő csata folyik, a kör nem zárul le (a csata végén lép tovább, lásd _elo_vege)
		if not elo_csatak.is_empty():
			result["battles"] = elo_csatak.size()
			return result
		GameManager.next_turn()
		result["advanced"] = true
		print("Heptarchia: új kör – %d (%d. kör)" % [GameManager.current_year, GameManager.turn_count + 1])
	return result

## A hadjárat állapota a dróton tömörítve (zstd): ~520 KB helyett ~10–20 KB parancsonként – Hamachin is gyors,
## és az élő csata pillanatképei mellett sem foglalja le a vonalat. Az első 4 bájt az eredeti méret.
const ALLAPOT_MAX := 64 * 1024 * 1024
static func tomorit(v: Variant) -> PackedByteArray:
	var b := var_to_bytes(v)
	var r := PackedByteArray()
	r.resize(4)
	r.encode_u32(0, b.size())
	r.append_array(b.compress(FileAccess.COMPRESSION_ZSTD))
	return r

static func kibont(r: PackedByteArray) -> Variant:
	if r.size() < 4: return null
	var n := r.decode_u32(0)
	if n <= 0 or n > ALLAPOT_MAX: return null
	var b := r.slice(4).decompress(n, FileAccess.COMPRESSION_ZSTD)
	if b.size() != n: return null
	return bytes_to_var(b)

# Állapot és értesítések kiküldése
func _publish() -> void:
	var notes := GameManager.take_outbox()
	if active and is_host:
		_nagy_kuld(0, DARAB_ALLAPOT, tomorit(GameManager.serialize_state()))
	state_changed.emit()
	for note in notes:
		var f: int = note["faction"]
		if not active or (is_host and not dedicated and players.has(1) and players[1]["faction"] == f):
			notification_received.emit(note)
		else:
			var peer := peer_for_faction(f)
			if peer > 1:
				_rpc_notify.rpc_id(peer, note)

@rpc("authority", "call_remote", "reliable")
func _rpc_state(state: PackedByteArray) -> void:
	_allapot_be(state)

func _allapot_be(state: PackedByteArray) -> void:
	var data = kibont(state)
	if typeof(data) == TYPE_DICTIONARY:
		GameManager.apply_state(data)
		state_changed.emit()

# ── Nagy csomagok darabolása (WebRTC) ──────────────────────────
#
# A böngésző egy WebRTC-üzenetben legfeljebb ~256 KB-ot visz át (vegyes böngészőknél 64 KB-ot is csak), a
# Godot pedig nem darabol: a hadjárat állapota és az élő csata kezdőcsomagja ennél nagyobb is lehet. Ilyenkor
# DARAB_MAX méretű darabokban megy, a fogadó összerakja, és ugyanoda adja tovább, ahová egyben ment volna.
# ENet-en (asztali játék) minden marad a régiben.
const DARAB_MAX := 48 * 1024
const DARAB_ALLAPOT := 0
const DARAB_START := 1
const DARAB_TC := 2
var _darab_kov: int = 1
var _darabok: Dictionary = {}   # "küldő:sorszám" -> {"n": darabszám, "r": [darabok], "db": megjött}

func _darabolni() -> bool:
	return multiplayer.multiplayer_peer is WebRTCMultiplayerPeer

## Küldés (peer 0: mindenkinek). extra: a kezdőcsomagnál a játékosok listája
func _nagy_kuld(peer: int, fajta: int, adat: PackedByteArray, extra: Variant = null) -> void:
	if not _darabolni() or adat.size() <= DARAB_MAX:
		match fajta:
			DARAB_ALLAPOT:
				if peer == 0: _rpc_state.rpc(adat)
				else: _rpc_state.rpc_id(peer, adat)
			DARAB_START:
				if peer == 0: _rpc_start.rpc(adat, extra)
				else: _rpc_start.rpc_id(peer, adat, extra)
			DARAB_TC:
				_rpc_tc.rpc_id(peer, adat)
		return
	var sorszam := _darab_kov
	_darab_kov = _darab_kov % 1000000 + 1
	var n := ceili(adat.size() / float(DARAB_MAX))
	for i in n:
		var resz := adat.slice(i * DARAB_MAX, mini((i + 1) * DARAB_MAX, adat.size()))
		var e: Variant = extra if i == n - 1 else null
		# (az élő csata darabjai a csata csatornáján, hogy a sorrend a többi csataüzenettel együtt megmaradjon)
		if fajta == DARAB_TC: _rpc_darab_tc.rpc_id(peer, sorszam, i, n, resz)
		elif peer == 0: _rpc_darab.rpc(fajta, sorszam, i, n, resz, e)
		else: _rpc_darab.rpc_id(peer, fajta, sorszam, i, n, resz, e)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_darab(fajta: int, sorszam: int, i: int, n: int, resz: PackedByteArray, extra: Variant) -> void:
	_darab_be(fajta, sorszam, i, n, resz, extra)

@rpc("any_peer", "call_remote", "reliable", TC_CSATORNA)
func _rpc_darab_tc(sorszam: int, i: int, n: int, resz: PackedByteArray) -> void:
	_darab_be(DARAB_TC, sorszam, i, n, resz, null)

func _darab_be(fajta: int, sorszam: int, i: int, n: int, resz: PackedByteArray, extra: Variant) -> void:
	var sender := multiplayer.get_remote_sender_id()
	# a hadjárat állapotát és a kezdést csak a gazdagép küldheti
	if fajta != DARAB_TC and sender != 1: return
	if n < 1 or n > ALLAPOT_MAX / DARAB_MAX or i < 0 or i >= n or resz.size() > DARAB_MAX: return
	var kulcs := "%d:%d:%d" % [sender, fajta, sorszam]
	var d: Dictionary = _darabok.get(kulcs, {})
	if d.is_empty():
		# (egy küldőtől egyszerre csak egy félkész csomag fajtánként: a régebbi elveszett)
		for k in _darabok.keys():
			if str(k).begins_with("%d:%d:" % [sender, fajta]): _darabok.erase(k)
		d = {"n": n, "r": [], "db": 0}
		(d["r"] as Array).resize(n)
		_darabok[kulcs] = d
	if int(d["n"]) != n or d["r"][i] != null: return
	d["r"][i] = resz
	d["db"] = int(d["db"]) + 1
	if int(d["db"]) < n: return
	_darabok.erase(kulcs)
	var adat := PackedByteArray()
	for r in d["r"]: adat.append_array(r)
	match fajta:
		DARAB_ALLAPOT: _allapot_be(adat)
		DARAB_START:
			if typeof(extra) == TYPE_DICTIONARY: _start_be(adat, extra)
		DARAB_TC: _tc_be(sender, adat)

@rpc("authority", "call_remote", "reliable")
func _rpc_result(result: Dictionary) -> void:
	command_result.emit(result)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify(note: Dictionary) -> void:
	notification_received.emit(note)

# ── Csevegés (1.73) ────────────────────────────────────────────
#
# A kliens a gazdagépnek küldi az üzenetet; a gazdagép megnézi, kinek szól, és CSAK a
# címzetteknek továbbítja (a többiek gépére el sem jut – nem a kliens szűr).
#   "all"     – mindenki
#   "allies"  – a szövetségeseid: akivel szövetségben (házassági szövetségben is) vagy,
#               a hűbéreseid és a hűbérurad; a kereskedelmi partner nem
#   "private" – egyetlen játékos (target = a nemzete)
# A feladó mindig megkapja a saját üzenetét (így látja, hogy elment). Legfeljebb
# CHAT_MAX_LEN karakter, a BBCode-jelölések kiesnek, és játékosonként CHAT_BURST üzenet
# CHAT_WINDOW_MS alatt (a többi elvész, a feladó figyelmeztetést kap).

const CHAT_MAX_LEN := 200
const CHAT_BURST := 5
const CHAT_WINDOW_MS := 10000
var _chat_ido: Dictionary = {}      # peer -> [küldési idők ms]

## Üzenet küldése (a felület hívja)
func send_chat(to: String, target: int, text: String) -> void:
	if not active: return
	if is_host: _host_chat(1, to, target, text)
	else: _rpc_chat.rpc_id(1, to, target, text)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_chat(to: String, target: int, text: String) -> void:
	if not is_host: return
	_host_chat(multiplayer.get_remote_sender_id(), to, target, text)

## A szöveg tisztítása: egy sor, BBCode nélkül, legfeljebb CHAT_MAX_LEN karakter
static func chat_clean(text: String) -> String:
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	var s := re.sub(text, "", true)
	s = s.replace("[", "(").replace("]", ")")
	var ki := ""
	for i in s.length():
		var c := s.unicode_at(i)
		ki += " " if c < 32 or c == 127 else s[i]
	return ki.strip_edges().left(CHAT_MAX_LEN)

## Szövetségese-e `a`-nak `b` a csevegés szempontjából (szövetség, házasság, hűbéri viszony)
func chat_allied(a: int, b: int) -> bool:
	if a == b: return true
	var d: Dictionary = GameManager.get_diplomacy(a, b)
	if d.is_empty(): return false
	var st := int(d.get("state", -1))
	return st == GameManager.DiplomacyState.ALLY or st == GameManager.DiplomacyState.VASSAL \
		or bool(d.get("marriage", false))

## Kiknek (peer-azonosítók) megy az üzenet; a feladó mindig benne van
func chat_recipients(sender: int, to: String, target: int) -> Array:
	var ki: Array = []
	if not players.has(sender): return ki
	var sf := int(players[sender]["faction"])
	for id in players:
		var f := int(players[id]["faction"])
		var kap := int(id) == sender
		match to:
			"all": kap = true
			"allies": kap = kap or chat_allied(sf, f)
			"private": kap = kap or f == target
		if kap: ki.append(int(id))
	return ki

func _host_chat(sender: int, to: String, target: int, text: String) -> void:
	if not is_host or not in_game or not players.has(sender): return
	if not to in ["all", "allies", "private"]: return
	var sf := int(players[sender]["faction"])
	if to == "private" and (target == sf or peer_for_faction(target) == 0): return
	var clean := chat_clean(text)
	if clean == "": return
	# túl sűrűn ír: az üzenet elvész, a feladó szólást kap
	var most := Time.get_ticks_msec()
	var idok: Array = _chat_ido.get(sender, [])
	idok = idok.filter(func(t: int) -> bool: return most - t < CHAT_WINDOW_MS)
	if idok.size() >= CHAT_BURST:
		_chat_ido[sender] = idok
		_chat_deliver(sender, {"system": "CHAT_TOO_FAST"})
		return
	idok.append(most)
	_chat_ido[sender] = idok
	var msg := {"from": sf, "name": str(players[sender]["name"]), "text": clean, "to": to,
		"target": target if to == "private" else -1, "year": GameManager.current_year,
		"season": GameManager.current_season, "time": Time.get_time_string_from_system().left(5)}
	for peer in chat_recipients(sender, to, target):
		_chat_deliver(int(peer), msg)

func _chat_deliver(peer: int, msg: Dictionary) -> void:
	if peer == 1:
		if not dedicated: chat_received.emit(msg)
	else:
		_rpc_chat_msg.rpc_id(peer, msg)

@rpc("authority", "call_remote", "reliable")
func _rpc_chat_msg(msg: Dictionary) -> void:
	chat_received.emit(msg)

# ── Élő csata ──────────────────────────────────────────────────
#
# Többjátékosban a csatát élőben, közösen lehet vezetni (scripts/taktikai_csata/tc_halo*.gd):
#   – a játékos a csataablak „Csata vezetése” gombjával kéri (roham, a gép rohama elleni védekezés, portya,
#     rajtaütés); a gazdagép ellenőrzi, felépíti a csatát a saját állapotából, és elindítja (TcGazda);
#   – ha a másik fél is ember, ő vezeti a saját oldalát (a csatatér nála is megnyílik), különben a gép;
#   – a többi játékos választ: nézi (élőben, csak olvasva), vagy közben tovább intézi a tartományait; a kör
#     csak akkor zárul le, ha minden csata véget ért (_end_turn);
#   – a csatában álló tartományokhoz, menetekhez közben nem lehet nyúlni (_elo_zar), a két harcoló nemzet közt
#     a csata alatt nincs diplomácia;
#   – a csata végén a gazdagép a csata eredményével hajtja végre a parancsot (GameManager.execute(…, belso)),
#     így a jelentés, a hódítás, a krónika ugyanúgy megy, mint egyjátékos módban.
# Az üzenetek a TC_CSATORNA csatornán mennek (a hadjárat üzeneteit nem tartják fel).

const TcAdapter := preload("res://scripts/taktikai_csata/heptarchia_adapter.gd")
const TcGazda := preload("res://scripts/taktikai_csata/tc_halo_gazda.gd")
const TcHalo := preload("res://scripts/taktikai_csata/tc_halo.gd")
const TcKod := preload("res://scripts/taktikai_csata/tc_halo_kod.gd")
const TC_CSATORNA := 2
## a szünet korlátjai a lobbiban (csatánként, hadvezérenként): [db, mp]
const ELO_SZUNET_KORLATOK := [[3, 60], [5, 120], [1, 30], [10, 300]]

## a gazdagép beállítása (a lobbiban): kell-e a másik fél jóváhagyása a szünethez, a szünetek száma és hossza
var elo_beall: Dictionary = {"szunet_jovahagy": true, "szunet_db": 3, "szunet_mp": 60.0, "telep_mp": 90.0}
var elo_csatak: Dictionary = {}     # (gazdagép) csata id -> {"gazda", "cmd", "args", "f", "tamado_oldal", "frakciok", "zar_p", "zar_m", "menet"}
var elo_lista: Dictionary = {}      # (mindenki) csata id -> {"a", "b": a két oldal nemzete (-1: portyázók), "hely", "harcos": [nemzet…], "nevek"}
var elo_nezet: Node = null          # ezen a gépen nyitott nézet (TcHalo)
var _elo_kov: int = 1

func _elo_beall_be(d: Dictionary) -> void:
	for k in ["szunet_jovahagy", "szunet_db", "szunet_mp", "telep_mp"]:
		if d.has(k): elo_beall[k] = d[k]

## Az új játék tempója (a gazdagép állítja a lobbiban): hány évet lép a naptár egy kör alatt
var ev_kor: int = 1

## A gépi ellenfél ereje az új játékban (a gazdagép állítja a lobbiban)
var ai_szint: String = "eros"

func ai_szint_allit(s: String) -> void:
	if not is_host or in_game or not s in GameManager.AI_DIFFICULTIES: return
	ai_szint = s
	_broadcast_lobby()

func ev_kor_allit(n: int) -> void:
	if not is_host or in_game or not n in GameManager.YEARS_PER_TURN_CHOICES: return
	ev_kor = n
	_broadcast_lobby()

## A lobbiban (csak a gazdagép): a szünet szabályai
func elo_beall_allit(jovahagy: bool, korlat: int) -> void:
	if not is_host or in_game: return
	var k: Array = ELO_SZUNET_KORLATOK[clampi(korlat, 0, ELO_SZUNET_KORLATOK.size() - 1)]
	elo_beall["szunet_jovahagy"] = jovahagy
	elo_beall["szunet_db"] = int(k[0])
	elo_beall["szunet_mp"] = float(k[1])
	_broadcast_lobby()

## A kérés: a játékos maga vezeti a csatát. cmd: "attack" {target, land, naval} · "defend" {} · "raid" {} ·
## "ambush" {index, sources}
func elo_csata_ker(cmd: String, args: Dictionary) -> void:
	if not active: return
	if is_host: _host_elo_ker(1, cmd, args)
	else: _rpc_elo_ker.rpc_id(1, cmd, args)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_elo_ker(cmd: String, args: Dictionary) -> void:
	if not is_host: return
	_host_elo_ker(multiplayer.get_remote_sender_id(), cmd, args)

func _host_elo_ker(peer: int, cmd: String, args: Dictionary) -> void:
	if not in_game or not players.has(peer): return
	var f := int(players[peer]["faction"])
	var r := _elo_epit(f, cmd, args)
	if r.has("reason"):
		_elo_valasz(peer, {"cmd": "elo", "ok": false, "reason": r["reason"]})
		return
	var id := _elo_indit(r)
	_elo_valasz(peer, {"cmd": "elo", "ok": true, "id": id})

func _elo_valasz(peer: int, result: Dictionary) -> void:
	if peer == 1 and not dedicated: command_result.emit(result)
	elif peer > 1: _rpc_result.rpc_id(peer, result)

static func _str_lista(v: Variant) -> Array:
	var r: Array = []
	if typeof(v) != TYPE_ARRAY: return r
	for x in v:
		if typeof(x) == TYPE_STRING and not str(x) in r: r.append(str(x))
		if r.size() >= 32: break
	return r

## Harcol-e most a nemzet (hadvezérként) egy élő csatában
func elo_harcol(f: int) -> bool:
	for id in elo_lista:
		if f in (elo_lista[id]["harcos"] as Array): return true
	return false

## A csata felépítése a gazdagép állapotából (ugyanúgy, ahogy egyjátékosban a felület teszi):
## {"cfg", "cmd", "args", "f", "frakciok", "zar_p", "zar_m", "menet", "hely"} – vagy {"reason"}
func _elo_epit(f: int, cmd: String, args: Dictionary) -> Dictionary:
	var gm := GameManager
	if not f in gm.human_factions or str(gm.realms[f]["status"]) != "playing": return {"reason": "MP_BATTLE_INVALID"}
	if elo_harcol(f): return {"reason": "MP_BATTLE_BUSY"}
	var elozo_pf := gm.player_faction
	var elozo_af := gm.acting_faction
	gm.tulaj_valtozott()
	# (a felépítők a játékos nemzetét a player_faction-ből veszik: a kérő nemzete idejére átállítjuk)
	gm.player_faction = f
	var r := {}
	match cmd:
		"attack":
			var cel := str(args.get("target", ""))
			if not gm.provinces.has(cel): r = {"reason": "MP_BATTLE_INVALID"}
			else:
				var vedo := int(gm.provinces[cel]["faction"])
				var szomszed: Array = gm.get_player_neighbors_of(cel)
				var tengeri: Array = gm.get_naval_sources(cel)
				var land: Array = _str_lista(args.get("land", [])).filter(func(n: String) -> bool: return n in szomszed)
				var naval: Array = _str_lista(args.get("naval", [])).filter(func(n: String) -> bool: return n in tengeri)
				if vedo == f or not gm.is_at_war(f, vedo) or (land.is_empty() and naval.is_empty()):
					r = {"reason": "MP_BATTLE_INVALID"}
				else:
					# (a közös flotta miatt mindig az attack_preview: az a hajókat a kiinduló partokra gyűjti)
					var bp: Dictionary = gm.attack_preview(land, naval, cel, "charge").get("land", {})
					if bp.is_empty(): r = {"reason": "MP_BATTLE_INVALID"}
					else:
						r = {"cfg": TcAdapter.cfg_roham(gm, bp, cel, true), "cmd": "attack",
							"args": {"target": cel, "tactic": "charge", "sources": land + naval}, "frakciok": [f, vedo],
							"zar_p": [cel] + land + naval, "hely": cel}
		"defend":
			var d: Dictionary = gm.pending_defense
			var ap: Dictionary = gm.pending_defense_preview() if not d.is_empty() else {}
			var bp: Dictionary = ap.get("land", {})
			if bp.is_empty(): r = {"reason": "MP_BATTLE_INVALID"}
			else:
				var cel := str(d["target"])
				r = {"cfg": TcAdapter.cfg_roham(gm, bp, cel, false), "cmd": "defend", "args": {},
					"frakciok": [f, int(d["attacker"])], "zar_p": [cel] + _str_lista(d.get("sources", [])), "hely": cel}
		"raid":
			var raid: Dictionary = gm.pending_raid
			if raid.is_empty() or str(raid.get("site", "")) != "": r = {"reason": "MP_BATTLE_INVALID"}
			else:
				r = {"cfg": TcAdapter.cfg_portya(gm, raid), "cmd": "raid", "args": {"tactic": "shield_wall"},
					"frakciok": [f, int(raid.get("hodito", -1))], "zar_p": [str(raid["target"])], "hely": str(raid["target"])}
		"ambush":
			var idx := int(args.get("index", -1))
			var src := _str_lista(args.get("sources", []))
			var jo := false
			for t in gm.ambush_targets():
				if int(t["index"]) == idx and not src.is_empty():
					jo = true
					for p in src:
						if not p in (t["sources"] as Array): jo = false
			if not jo: r = {"reason": "MP_BATTLE_INVALID"}
			else:
				var m: Dictionary = gm.marches[idx]
				r = {"cfg": TcAdapter.cfg_rajtautes(gm, idx, src), "cmd": "ambush", "args": {"index": idx, "sources": src},
					"frakciok": [f, int(m["faction"])], "zar_p": src, "zar_m": [idx], "menet": m, "hely": gm.march_at(m)}
		"sally":
			# a városostrom kitörése (ostrom_kampany): az ostromlott város őrsége az ostromlók táborára tör
			var cel := str(args.get("target", ""))
			var o: Dictionary = gm.ostromok.get(cel, {})
			if o.is_empty() or not gm.provinces.has(cel) or int(gm.provinces[cel]["faction"]) != f \
					or int(o.get("kitores_kor", -1)) == int(gm.turn_index()) or gm.troops_of(gm.provinces[cel]) <= 0:
				r = {"reason": "MP_BATTLE_INVALID"}
			else:
				r = {"cfg": TcAdapter.cfg_kitores(gm, cel), "cmd": "sally", "args": {"target": cel},
					"frakciok": [f, int(o["tamado"])], "zar_p": [cel] + _str_lista(o.get("forrasok", [])), "hely": cel}
		_:
			r = {"reason": "MP_BATTLE_INVALID"}
	gm.player_faction = elozo_pf
	gm.acting_faction = elozo_af
	if r.has("reason"): return r
	# a másik oldal: ha ember, és épp nem vív másik csatát, ő vezeti
	var ellen := int(r["frakciok"][1])
	if ellen >= 0 and ellen in gm.human_factions and peer_for_faction(ellen) > 0 and elo_harcol(ellen):
		return {"reason": "MP_BATTLE_BUSY_TARGET"}
	r["f"] = f
	return r

## A csata indítása (gazdagép): a TcGazda és a résztvevők nézete; a csata azonosítóját adja
func _elo_indit(r: Dictionary) -> int:
	var id := _elo_kov
	_elo_kov = _elo_kov % 60000 + 1
	var cfg: Dictionary = r["cfg"]
	var fr: Array = r["frakciok"]
	var harc := [0, 0]
	var nevek := ["", ""]
	var harcos_f: Array = []
	var od: Array = cfg["oldalak"]
	for o in 2:
		var ff := int(fr[o])
		var s: Dictionary = od[o]
		# a résztvevők a saját nyelvükön látják (TcAdapter.halo_honosit)
		s["f"] = ff
		if ff < 0:
			for k in ["TC_RAIDERS", "TC_REBELS"]:
				if str(s.get("nev", "")) == tr(k): s["nev_k"] = k
		nevek[o] = str(s.get("nev", ""))
		if ff >= 0 and ff in GameManager.human_factions:
			var p := peer_for_faction(ff)
			if p > 0 and players.has(p):
				harc[o] = p
				harcos_f.append(ff)
				nevek[o] = str(players[p]["name"])
	cfg["cim_k"] = "TC_TITLE_AMBUSH" if str(r["cmd"]) == "ambush" else ("TC_TITLE_SALLY" if str(r["cmd"]) == "sally" else ("TC_TITLE_SIEGE" if bool(cfg.get("ostrom", false)) else "TC_TITLE"))
	cfg["cim_hely"] = str(r["hely"])
	for k in ["TC_RAM_NAME", "TC_PETARD_NAME"]:
		if str(cfg.get("kos_nev", "")) == tr(k): cfg["kos_k"] = k
	var gazda: Node = TcGazda.new()
	gazda.name = "EloCsata%d" % id
	gazda.set("csata_id", id)
	add_child(gazda)
	gazda.connect("vege", _elo_vege.bind(id))
	elo_csatak[id] = {"gazda": gazda, "cmd": r["cmd"], "args": r["args"], "f": r["f"],
		"tamado_oldal": int(cfg.get("tamado_oldal", 0)), "frakciok": fr, "zar_p": r.get("zar_p", []),
		"zar_m": r.get("zar_m", []), "menet": r.get("menet", null)}
	elo_lista[id] = {"a": int(fr[0]), "b": int(fr[1]), "hely": str(r["hely"]), "harcos": harcos_f, "nevek": nevek}
	print("Heptarchia: élő csata #%d – %s (%s), harcosok: %s" % [id, str(r["cmd"]), str(r["hely"]), str(harc)])
	gazda.call("indit", cfg, harc, nevek, elo_beall, _elo_kuld)
	_elo_lista_kuld()
	return id

## A gazdagép üzenete egy résztvevőnek (a saját gépén helyben)
func _elo_kuld(peer: int, adat: PackedByteArray) -> void:
	if peer == 1:
		if not dedicated: _elo_helyi.call_deferred(adat)
	elif players.has(peer):
		_nagy_kuld(peer, DARAB_TC, adat)

## A résztvevő üzenete a gazdagépnek
func _elo_fel(adat: PackedByteArray) -> void:
	if is_host:
		var cs: Dictionary = elo_csatak.get(TcKod.id_of(adat), {})
		if not cs.is_empty(): (cs["gazda"] as Node).call_deferred("uzenet", 1, adat)
	else:
		_rpc_tc.rpc_id(1, adat)

@rpc("any_peer", "call_remote", "reliable", TC_CSATORNA)
func _rpc_tc(adat: PackedByteArray) -> void:
	_tc_be(multiplayer.get_remote_sender_id(), adat)

func _tc_be(sender: int, adat: PackedByteArray) -> void:
	if is_host:
		var cs: Dictionary = elo_csatak.get(TcKod.id_of(adat), {})
		if not cs.is_empty(): (cs["gazda"] as Node).call("uzenet", sender, adat)
	elif sender == 1:
		_elo_helyi(adat)

## Üzenet ennek a gépnek a nézetéhez (a START új nézetet nyit)
func _elo_helyi(adat: PackedByteArray) -> void:
	var tipus := TcKod.tipus_of(adat)
	var id := TcKod.id_of(adat)
	if tipus == TcKod.START:
		var start: Variant = TcKod.var_of(adat)
		if typeof(start) != TYPE_DICTIONARY: return
		# (ha épp egy másik csatát nézett, az bezárul)
		if elo_nezet != null and is_instance_valid(elo_nezet):
			var regi: Node = elo_nezet
			if int(regi.get("en")) < 0: elo_nez_ki(int(regi.get("csata_id")))
			_elo_nezet_zar()
		var h: Node = TcHalo.new()
		h.set("csata_id", id)
		h.call("beallit", start)
		TcAdapter.halo_honosit(GameManager, h.get("cfg"))
		h.set("kuld", _elo_fel)
		h.set("kilepes", elo_nez_ki.bind(id))
		add_child(h)
		elo_nezet = h
		elo_csata_nyilt.emit(h)
	elif elo_nezet != null and is_instance_valid(elo_nezet) and int(elo_nezet.get("csata_id")) == id:
		elo_nezet.call("uzenet", adat)

## A nézet bezárult (a felület hívja, amikor a csatatér eltűnt)
func elo_nezet_bezart(h: Node) -> void:
	if h == elo_nezet: elo_nezet = null
	if is_instance_valid(h): h.queue_free()

func _elo_nezet_zar() -> void:
	if elo_nezet == null: return
	var h: Node = elo_nezet
	elo_nezet = null
	if not is_instance_valid(h): return
	var cs: Variant = h.get("csata")
	if cs != null and is_instance_valid(cs):
		# a felület visszakapja a térképet (befejezve jel), a csatatér eltűnik
		(cs as Node).call("_befejez")
	h.queue_free()

## Nézőként: a futó csata megnyitása / bezárása
func elo_nez(id: int) -> void:
	if not active or not elo_lista.has(id): return
	if is_host: _host_nez(1, id)
	else: _rpc_elo_nez.rpc_id(1, id, true)

func elo_nez_ki(id: int) -> void:
	if not active: return
	if is_host: _host_nez_ki(1, id)
	else: _rpc_elo_nez.rpc_id(1, id, false)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_elo_nez(id: int, be: bool) -> void:
	if not is_host: return
	var sender := multiplayer.get_remote_sender_id()
	if be: _host_nez(sender, id)
	else: _host_nez_ki(sender, id)

func _host_nez(peer: int, id: int) -> void:
	var cs: Dictionary = elo_csatak.get(id, {})
	if cs.is_empty() or not players.has(peer): return
	var f := int(players[peer]["faction"])
	var fr: Array = cs["frakciok"]
	if f == int(fr[0]) or f == int(fr[1]): return
	# a szövetséges néző csak a szövetségese látását kapja (ne súghasson neki); a semleges mindkét oldalét
	var sz0 := int(fr[0]) >= 0 and chat_allied(f, int(fr[0]))
	var sz1 := int(fr[1]) >= 0 and chat_allied(f, int(fr[1]))
	var nezet := -1
	var kotott := false
	if sz0 != sz1:
		nezet = 0 if sz0 else 1
		kotott = true
	(cs["gazda"] as Node).call("nezo_be", peer, nezet, kotott)

func _host_nez_ki(peer: int, id: int) -> void:
	var cs: Dictionary = elo_csatak.get(id, {})
	if not cs.is_empty(): (cs["gazda"] as Node).call("nezo_ki", peer)

## A csata véget ért (gazdagép): a parancs a csata eredményével, a jelentés a vezetőnek, a kör léphet tovább
func _elo_vege(e: Dictionary, id: int) -> void:
	var cs: Dictionary = elo_csatak.get(id, {})
	if cs.is_empty(): return
	elo_csatak.erase(id)
	elo_lista.erase(id)
	var gazda: Node = cs["gazda"]
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(gazda): gazda.queue_free())
	var f := int(cs["f"])
	var args: Dictionary = (cs["args"] as Dictionary).duplicate(true)
	args["tactical"] = TcAdapter.kampanyba(e, int(cs["tamado_oldal"]))
	var ok := true
	if str(cs["cmd"]) == "ambush":
		# a menet sorszáma közben elcsúszhatott (más menet véget ért): újra megkeressük
		var m: Variant = cs.get("menet", null)
		var idx := -1
		for i in GameManager.marches.size():
			if is_same(GameManager.marches[i], m): idx = i
		args["index"] = idx
		ok = idx >= 0
	var result: Dictionary = GameManager.execute(f, str(cs["cmd"]), args, true) if ok and in_game \
		else {"cmd": str(cs["cmd"]), "args": args, "ok": false, "reason": "MP_BATTLE_INVALID"}
	print("Heptarchia: élő csata #%d vége – győztes oldal %d (%s), a parancs: %s" % [id, int(e.get("gyoztes", -1)),
		str(e.get("ok", "")), str(result.get("ok", false))])
	_publish()
	_elo_valasz(peer_for_faction(f), result)
	_elo_lista_kuld()
	if in_game and elo_csatak.is_empty() and GameManager.all_humans_ready():
		GameManager.next_turn()
		_publish()

func _elo_lista_kuld() -> void:
	if not is_host: return
	if active: _rpc_elo_lista.rpc(elo_lista)
	elo_lista_valtozott.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_elo_lista(lista: Dictionary) -> void:
	elo_lista = lista
	elo_lista_valtozott.emit()

## Le van-e zárva a parancs, mert egy élő csata érinti: a csatában álló tartományok, a megtámadott menet; a két
## harcoló nemzet közti diplomácia; a csatát vezető ugyanarra a portyára / rohamra adott válasza
func _elo_zar(f: int, cmd: String, args: Dictionary) -> String:
	if elo_csatak.is_empty() or cmd == "end_turn": return ""
	var tart: Array = []
	for k in ["province", "from", "to", "target"]:
		if typeof(args.get(k)) == TYPE_STRING: tart.append(str(args[k]))
	for s in _str_lista(args.get("sources", [])): tart.append(s)
	var menet := int(args.get("index", -1)) if cmd == "ambush" else -1
	# az átirányítás és a menet feloszlatása: a megtámadott menethez a csata alatt nem lehet nyúlni
	# (az átirányítás a menet állandó azonosítóját küldi, nem a sorszámát)
	if cmd == "redirect": menet = GameManager.MenetIr.index(GameManager, int(args.get("march", -1)))
	elif cmd == "disband" and args.has("march_id"): menet = GameManager.MenetIr.index(GameManager, int(args.get("march_id", -1)))
	elif cmd == "disband" and args.has("march"): menet = int(args.get("march", -1))
	var menet_d: Variant = GameManager.marches[menet] if menet >= 0 and menet < GameManager.marches.size() else null
	var masik := -1
	for k in ["target", "from"]:
		if typeof(args.get(k)) in [TYPE_INT, TYPE_FLOAT]: masik = int(args[k])
	for id in elo_csatak:
		var cs: Dictionary = elo_csatak[id]
		for p in tart:
			if p in (cs["zar_p"] as Array): return "MP_BATTLE_LOCKED"
		if menet >= 0 and menet in (cs["zar_m"] as Array): return "MP_BATTLE_LOCKED"
		# (a sorszám a csata kezdete óta elcsúszhatott: a menet maga is számít)
		if menet_d != null and cs.get("menet") != null and is_same(cs["menet"], menet_d): return "MP_BATTLE_LOCKED"
		var fr: Array = cs["frakciok"]
		if f in fr and masik in fr and cmd in ["peace", "vassal", "marriage", "trade", "respond", "spare", "dissolve", "gift", "barter"]:
			return "MP_BATTLE_LOCKED"
		if f == int(cs["f"]) and cmd in ["raid", "defend"] and str(cs["cmd"]) in ["raid", "defend"]: return "MP_BATTLE_LOCKED"
	return ""

func _elo_takarit() -> void:
	for id in elo_csatak:
		var g: Node = elo_csatak[id]["gazda"]
		if is_instance_valid(g): g.queue_free()
	elo_csatak.clear()
	elo_lista.clear()
	_elo_nezet_zar()

## Mérés (teszthez): a gazdagép csatáinak sávszélessége, a nézet adatai
func elo_meres() -> Dictionary:
	var r := {}
	for id in elo_csatak: r[id] = (elo_csatak[id]["gazda"] as Node).call("meres")
	if elo_nezet != null and is_instance_valid(elo_nezet): r["nezet"] = elo_nezet.call("meres")
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var h: ENetConnection = (multiplayer.multiplayer_peer as ENetMultiplayerPeer).host
		if h != null:
			r["enet_ki"] = h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)
			r["enet_be"] = h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA)
	return r

# ── Ping ───────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not active or not is_host or multiplayer.multiplayer_peer is OfflineMultiplayerPeer: return
	_ping_ido += delta
	if _ping_ido < PING_IDOKOZ: return
	_ping_ido = 0.0
	var most := Time.get_ticks_msec()
	for id in players:
		if int(id) > 1: _rpc_ping.rpc_id(int(id), most)
	if not pings.is_empty(): _rpc_pings.rpc(pings)

@rpc("authority", "call_remote", "unreliable")
func _rpc_ping(ido: int) -> void:
	_rpc_pong.rpc_id(1, ido)

@rpc("any_peer", "call_remote", "unreliable")
func _rpc_pong(ido: int) -> void:
	if not is_host: return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender): return
	pings[sender] = maxi(0, Time.get_ticks_msec() - ido)

@rpc("authority", "call_remote", "unreliable")
func _rpc_pings(tabla: Dictionary) -> void:
	pings = tabla

# A játékos pingje ms-ban; -1, ha nincs mérés (a gazdagép saját sora, vagy még nem jött válasz)
func ping_of(peer: int) -> int:
	return int(pings.get(peer, -1))

# ── UPnP (automatikus porttovábbítás a routeren) ───────────────

func _start_upnp(p: int) -> void:
	if _upnp_thread and _upnp_thread.is_started(): return
	upnp_ok = false
	upnp_cgnat = false
	external_ip = ""
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_work.bind(p))

func _upnp_work(p: int) -> void:
	var upnp := UPNP.new()
	var ok := false
	var ip := ""
	if upnp.discover(2000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		var gateway := upnp.get_gateway()
		if gateway and gateway.is_valid_gateway():
			ok = upnp.add_port_mapping(p, p, "Heptarchia", "UDP", 0) == UPNP.UPNP_RESULT_SUCCESS
			ip = upnp.query_external_address()
	_upnp_done.call_deferred(ok, ip, upnp if ok else null)

func _upnp_done(ok: bool, ip: String, upnp: UPNP) -> void:
	_upnp_thread.wait_to_finish()
	_upnp = upnp
	upnp_ok = ok
	external_ip = ip
	upnp_cgnat = ok and ip != "" and is_private_ipv4(ip)
	if dedicated:
		print("Heptarchia UPnP: %s, külső IP: %s" % ["sikeres" if ok else "nem sikerült", ip if ip != "" else "?"])
		if upnp_cgnat:
			print("Heptarchia UPnP: a router külső címe sem nyilvános (%s), a szolgáltató is NAT mögé tesz – kívülről így nem érhető el a port." % ip)
	upnp_finished.emit(ok, ip)

# Magánhálózati (nem az internetről elérhető) IPv4-cím-e. A 100.64.0.0/10 a szolgáltatói
# NAT (CGNAT) tartománya: ilyenkor a UPnP „sikerül” a saját routeren, a port mégsem
# lesz kívülről elérhető, mert a szolgáltató oldalán van még egy NAT, amihez nem férünk.
func is_private_ipv4(ip: String) -> bool:
	var parts := ip.split(".")
	if parts.size() != 4: return false
	var a := int(parts[0])
	var b := int(parts[1])
	if a == 10 or a == 127: return true
	if a == 172 and b >= 16 and b <= 31: return true
	if a == 192 and b == 168: return true
	if a == 169 and b == 254: return true
	if a == 100 and b >= 64 and b <= 127: return true
	return false
