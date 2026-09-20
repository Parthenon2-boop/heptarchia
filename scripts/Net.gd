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

signal lobby_changed
signal state_changed
signal command_result(result: Dictionary)
signal notification_received(note: Dictionary)
signal game_started
signal connection_failed
signal session_ended(reason_key: String)
signal upnp_finished(success: bool, external_ip: String)

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 8
const PROTOCOL_VERSION := 9

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

var _upnp: UPNP
var _upnp_thread: Thread

func _ready() -> void:
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

func leave() -> void:
	if _upnp:
		_upnp.delete_port_mapping(port, "UDP")
		_upnp = null
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active = false; is_host = false; in_game = false
	players = {}
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

func _first_free_faction(exclude_peer: int = 0) -> int:
	for f in GameManager.PLAYABLE_FACTIONS:
		if peer_for_faction(f) == 0 or peer_for_faction(f) == exclude_peer:
			return f
	return -1

# ── Kapcsolati események ───────────────────────────────────────

func _on_connected_to_server() -> void:
	_rpc_hello.rpc_id(1, get_meta("pending_name", "Thegn"), PROTOCOL_VERSION)

func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	var was_in_game := in_game
	leave()
	session_ended.emit("MP_HOST_LEFT" if was_in_game else "MP_CONNECTION_LOST")

func _on_peer_connected(_id: int) -> void:
	pass   # a játékos a _rpc_hello üzenettel jelentkezik be

func _on_peer_disconnected(id: int) -> void:
	if not is_host or not players.has(id): return
	var faction: int = players[id]["faction"]
	players.erase(id)
	print("Heptarchia: kilépett egy játékos (peer %d)" % id)
	if in_game:
		if faction in GameManager.human_factions:
			GameManager.set_ai_controlled(faction)
			for f in GameManager.human_factions:
				GameManager.notify(f, "MP_TITLE", [], "MP_PLAYER_LEFT", [GameManager.faction_key(faction)])
		if GameManager.human_factions.is_empty() or players.is_empty():
			in_game = false
			print("Heptarchia: mindenki kilépett, a szerver visszaáll a lobbiba")
		elif GameManager.all_humans_ready():
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
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer)

@rpc("authority", "call_remote", "reliable")
func _rpc_rejected(reason: String) -> void:
	leave()
	session_ended.emit(reason)

func _broadcast_lobby() -> void:
	if not is_host: return
	_rpc_lobby.rpc(players)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_lobby(new_players: Dictionary) -> void:
	players = new_players
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
	if in_game or not players.has(peer) or not faction in GameManager.PLAYABLE_FACTIONS: return
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
	GameManager.new_game_multiplayer(factions)
	in_game = true
	print("Heptarchia: a játék elindult, királyságok: %s" % str(factions))
	_rpc_start.rpc(var_to_bytes(GameManager.serialize_state()), players)
	if not dedicated:
		_enter_game(players[1]["faction"])

@rpc("authority", "call_remote", "reliable")
func _rpc_start(state: PackedByteArray, new_players: Dictionary) -> void:
	players = new_players
	in_game = true
	GameManager.apply_state(bytes_to_var(state))
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
	if cmd == "end_turn":
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
		GameManager.next_turn()
		result["advanced"] = true
		print("Heptarchia: új kör – %d %d" % [GameManager.current_year, GameManager.current_season])
	return result

# Állapot és értesítések kiküldése
func _publish() -> void:
	var notes := GameManager.take_outbox()
	if active and is_host:
		_rpc_state.rpc(var_to_bytes(GameManager.serialize_state()))
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
	var data = bytes_to_var(state)
	if typeof(data) == TYPE_DICTIONARY:
		GameManager.apply_state(data)
		state_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rpc_result(result: Dictionary) -> void:
	command_result.emit(result)

@rpc("authority", "call_remote", "reliable")
func _rpc_notify(note: Dictionary) -> void:
	notification_received.emit(note)

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
