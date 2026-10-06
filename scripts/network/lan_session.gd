extends Node

## Persistent LAN hosting, discovery, lobby, command, and reconnect lifecycle.
## The host owns simulation; guests request actions and receive filtered snapshots.
## Seat IDs, peer IDs, and command sequence numbers have separate roles.

## Transport/session lifecycle only. Rules and state codecs live beside this file.
signal changed
signal notice(message: String)
signal rooms_changed
signal command_finished(accepted: bool)

const SETTINGS: LanSettings = preload("res://scripts/network/lan_settings.tres")
var peer: ENetMultiplayerPeer
var discovery: PacketPeerUDP
var hosting := false
var state := "offline"
var local_player_id := -1
var seats: Array = []
var capacity := 8
var room_name := ""
var match_mode: String = GameSession.REGULAR
var turn_duration: int = 120
var address := ""
var port := 0
var display_name := ""
var selected_tribe := "saba"
var reconnect_token := ""
var compatibility := ""
var peer_seats: Dictionary = {}
var loaded: Dictionary = {}
var tokens: Dictionary = {}
var last_commands: Dictionary = {}
var next_command := 1
var revision := 0
var game: MatchManager
var executing := false
var snapshot_codec := MatchSnapshot.new()
var resource_cells: Dictionary = {}
var bootstrap: Dictionary = {}
var pending_snapshot: Dictionary = {}
var rooms: Dictionary = {}
var error_message := ""
var pending_command := false
var paused_for_disconnect := false
var _hello_sent := false
var _connect_elapsed := 0.0
var _retry_elapsed := 0.0
var _discovery_elapsed := 0.0
var _load_elapsed := 0.0
var _disconnect_elapsed := 0.0
var _pending_elapsed := 0.0
var _peer_budgets: Dictionary = {}
var _handshake_deadlines: Dictionary = {}
var _rejected: Dictionary = {}
var room_access := LanRoomAccess.new()
var private_room := false
var join_password := ""
var discovery_available := false

## Reports an active network lifecycle, including an ended session still owning a match scene.
func active() -> bool:
	return state in ["loading", "playing", "reconnecting"] or (state == "ended" and is_instance_valid(game))

## Reports whether this device is a guest in the active network lifecycle.
func client() -> bool:
	return active() and not hosting

## Checks local human-turn access, pending commands, and disconnect pauses.
func can_act() -> bool:
	if not active():
		var local_game := get_tree().current_scene.get_node_or_null("MatchManager") if get_tree().current_scene != null else null
		return local_game == null or local_game.can_human_act()
	return (state == "playing" and not paused_for_disconnect and not pending_command and is_instance_valid(game) and game.active_player_id == local_player_id and game.can_human_act())

## Combines protocol/build versions with catalog/rule fingerprints before joining or hosting.
func prepare_compatibility() -> bool:
	var generator := BiomeMapGenerator.new()
	if not generator.prepare():
		fail(generator.last_error)
		return false
	# Catalog signature is calculated by generation; no global RNG is used.
	var sample := generator.generate(1, [{"player_id": 1, "tribe_id": "saba"}])
	if sample.is_empty():
		fail(generator.last_error)
		return false
	compatibility = "%d/%s/%s/%s" % [SETTINGS.protocol_version, SETTINGS.build_version, str(sample.catalog), LanCatalog.rules_signature()]
	return true

## Creates an ENet host and initial seat; automatic hosting can fall back to another open port.
func host_room(player_name: String, title: String, count: int, tribe: String, custom_port: int = 0, mode: String = GameSession.REGULAR) -> bool:
	leave()
	if not prepare_compatibility():
		return false
	peer = ENetMultiplayerPeer.new()
	port = custom_port if custom_port > 0 else SETTINGS.game_port
	var result := peer.create_server(port, SETTINGS.max_players + 8)
	if result != OK and custom_port == 0:
		peer = ENetMultiplayerPeer.new()
		result = peer.create_server(0, SETTINGS.max_players + 8)
	if result != OK:
		fail("Could not host. This port may already be in use.")
		peer = null
		return false
	port = peer.host.get_local_port()
	hosting = true
	state = "lobby"
	local_player_id = 1
	match_mode = mode if mode in GameSession.MATCH_MODES else GameSession.REGULAR
	capacity = clampi(count, 2, SETTINGS.max_players)
	room_name = title.strip_edges().left(32)
	if room_name.is_empty():
		room_name = "Sweetspire game"
	seats = [_seat(1, player_name, tribe)]
	peer.peer_disconnected.connect(_peer_left)
	peer.peer_connected.connect(func(id: int): _handshake_deadlines[id] = Time.get_ticks_msec() + int(SETTINGS.connect_timeout * 1000))
	_setup_discovery(true)
	changed.emit()
	return true

## Stores endpoint and player choices, then begins the connection handshake.
func join_room(host_address: String, player_name: String, tribe: String, custom_port: int = 0, password: String = "") -> bool:
	leave()
	var endpoint := LanAddress.parse(host_address, custom_port if custom_port > 0 else SETTINGS.game_port)
	if endpoint.is_empty():
		fail("Enter a host address and a port between 1 and 65535.")
		return false
	if not prepare_compatibility():
		return false
	address = endpoint.address
	join_password = password.left(64)
	display_name = player_name.strip_edges().left(24)
	selected_tribe = tribe
	port = int(endpoint.port)
	return _connect()

func _connect() -> bool:
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		peer = null
		fail("Could not connect. Check the host address.")
		return false
	if state != "reconnecting":
		state = "connecting"
	_hello_sent = false
	_connect_elapsed = 0.0
	changed.emit()
	return true

func _seat(id: int, title: String, tribe: String) -> Dictionary:
	return {"kind": "human", "profile": "balanced", "id": id, "name": title.strip_edges().left(24) if not title.strip_edges().is_empty() else "Player %d" % id, "tribe": tribe if LanCatalog.TRIBES.has(tribe) else "saba", "ready": false, "connected": true}

## Closes transport/discovery and resets session state for safe return to local setup.
func leave() -> void:
	if hosting and peer != null:
		_broadcast("closed", {"message": "The host closed the game."})
		peer.poll()
	if peer != null:
		peer.close()
	peer = null
	if discovery != null:
		discovery.close()
	discovery = null
	discovery_available = false
	private_room = false
	room_access.configure(false)
	join_password = ""
	state = "offline"
	match_mode = GameSession.REGULAR
	turn_duration = 120
	hosting = false
	game = null
	local_player_id = -1
	seats.clear()
	peer_seats.clear()
	tokens.clear()
	loaded.clear()
	last_commands.clear()
	_peer_budgets.clear()
	_handshake_deadlines.clear()
	_rejected.clear()
	snapshot_codec = MatchSnapshot.new()
	resource_cells.clear()
	bootstrap.clear()
	rooms.clear()
	pending_snapshot.clear()
	reconnect_token = ""
	revision = 0
	next_command = 1
	pending_command = false
	paused_for_disconnect = false
	error_message = ""
	changed.emit()

func fail(message: String) -> void:
	error_message = message
	notice.emit(message)
	changed.emit()

func _send(to: int, kind: String, data: Dictionary = {}) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	peer.set_target_peer(to)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var bytes := JSON.stringify({"kind": kind, "data": data}).to_utf8_buffer()
	if bytes.size() <= SETTINGS.max_packet_bytes:
		peer.put_packet(bytes)

func _broadcast(kind: String, data: Dictionary = {}) -> void:
	for remote: int in peer_seats:
		_send(remote, kind, data)

func _roster() -> Dictionary:
	return {"seats": seats, "capacity": capacity, "room": room_name, "mode": match_mode, "turn_duration": turn_duration, "private": private_room, "paused": paused_for_disconnect, "loaded": loaded.keys()}

## Applies host-only lobby settings and resets human readiness when rules change.
func configure_room(title: String, count: int, mode: String, is_private: bool, password: String = "", seconds: int = 0) -> bool:
	if seconds == 0:
		seconds = turn_duration
	if seconds not in GameSession.TURN_DURATIONS:
		return false
	if not hosting or state != "lobby" or count < maxi(2, seats.size()) or count > SETTINGS.max_players or mode not in GameSession.MATCH_MODES:
		return false
	var rules_changed := capacity != count or match_mode != mode or private_room != is_private or turn_duration != seconds
	room_name = title.strip_edges().left(32)
	if room_name.is_empty():
		room_name = "Sweetspire game"
	capacity = count
	match_mode = mode
	turn_duration = seconds
	if private_room != is_private or (is_private and password != room_access.password):
		room_access.configure(is_private, password.left(64))
	private_room = is_private
	if rules_changed:
		for row: Dictionary in seats:
			row.ready = row.get("kind", "human") == "bot"
	error_message = ""
	_publish_lobby()
	return true

func rename_player(title: String) -> void:
	if state != "lobby":
		return
	if hosting:
		_set_name(local_player_id, title)
	else:
		_send(1, "name", {"name": title.left(24)})

func _set_name(id: int, title: String) -> void:
	for row: Dictionary in seats:
		if int(row.id) == id:
			row.name = title.strip_edges().left(24) if not title.strip_edges().is_empty() else "Player %d" % id
	_publish_lobby()

## Removes a non-host human lobby seat and invalidates its reconnect token.
func kick_player(seat: int) -> bool:
	if not hosting or state != "lobby" or seat == local_player_id:
		return false
	for remote: int in peer_seats.keys():
		if int(peer_seats[remote]) == seat:
			_send(remote, "kicked", {"message": "You were removed by the host."})
			_peer_left(remote)
			_rejected[remote] = Time.get_ticks_msec() + 500
			return true
	return false

func choose_mode(mode: String) -> void:
	if not hosting or state != "lobby" or mode not in GameSession.MATCH_MODES or mode == match_mode:
		return
	match_mode = mode
	for row: Dictionary in seats:
		row.ready = false
	_publish_lobby()

func _publish_lobby() -> void:
	_broadcast("roster", _roster())
	changed.emit()

## Submits the local human's tribe and ready state.
func choose(tribe: String, ready: bool) -> void:
	if state != "lobby" or not LanCatalog.TRIBES.has(tribe):
		return
	if hosting:
		_set_choice(local_player_id, tribe, ready)
	else:
		_send(1, "choice", {"tribe": tribe, "ready": ready})

func _set_choice(id: int, tribe: String, ready: bool) -> void:
	for row: Dictionary in seats:
		if int(row.id) == id:
			row.ready = ready if row.tribe == tribe else false
			row.tribe = tribe
	_publish_lobby()

## Requires a host lobby with at least two connected ready seats; bots count as ready.
func can_start() -> bool:
	if not hosting or state != "lobby" or seats.size() < 2:
		return false
	for row: Dictionary in seats:
		if not row.ready or not row.connected:
			return false
	return true

## Generates the host map, broadcasts bootstrap data, installs players, and opens Main.
func start_match() -> bool:
	if not can_start():
		return false
	var roster: Array = []
	for row: Dictionary in seats:
		roster.append({"player_id": int(row.id), "tribe_id": row.tribe})
	var generator := BiomeMapGenerator.new()
	var manifest := generator.generate(int(Time.get_unix_time_from_system()) & 0x7fffffff, roster)
	var assembled := generator.build(manifest, roster)
	if assembled.is_empty():
		fail(generator.last_error)
		return false
	# Shared authored terrain, no starting-player assignments in guest bootstrap.
	var entities: Array = []
	for row: Dictionary in assembled.entities:
		entities.append({"id": row.id, "kind": row.kind, "cell": row.cell, "tribe_id": ""})
	bootstrap = {"layers": assembled.layers, "entities": entities}
	resource_cells.clear()
	for row: Dictionary in entities:
		if row.kind != "town":
			resource_cells[int(row.id)] = LanCatalog.cell(row.cell)
	state = "loading"
	_load_elapsed = 0.0
	loaded.clear()
	_broadcast("start", {"map": bootstrap, "roster": _roster()})
	_install_players()
	GameSession.map_manifest = manifest
	_open_match()
	return true

func _install_players() -> void:
	GameSession.clear_players()
	GameSession.match_mode = match_mode
	GameSession.turn_duration = turn_duration
	for row: Dictionary in seats:
		var player := PlayerState.new()
		player.player_id = int(row.id)
		player.player_name = row.name
		player.controller_kind = row.get("kind", "human")
		player.bot_profile_id = row.get("profile", "balanced")
		player.tribe = LanCatalog.TRIBES[row.tribe]
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		GameSession.add_player(player)

func _open_match() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
	changed.emit()

## Binds the new MatchManager and reports this device's loading completion.
func attach_match(value: MatchManager) -> void:
	game = value
	if hosting:
		loaded[1] = true
		_try_begin()
	else:
		_send(1, "loaded")
		if not pending_snapshot.is_empty():
			_apply_snapshot(pending_snapshot)
			pending_snapshot.clear()

## Starts/resumes when required human peers load; bots have no network loading handshake.
func _try_begin() -> void:
	if not hosting or not is_instance_valid(game):
		return
	for row: Dictionary in seats:
		if row.get("kind", "human") == "bot":
			continue
		if game.eliminated_player_ids.has(int(row.id)) and not row.connected:
			continue
		if not loaded.get(int(row.id), false) or not row.connected:
			return
	state = "playing"
	paused_for_disconnect = false
	game.current_phase = MatchManager.Phase.PLAYER_TURN if game.winner_id == -1 else MatchManager.Phase.GAME_OVER
	if game.turn_clock != null:
		game.turn_clock.start_turn()
	revision += 1
	_publish_lobby()
	publish_state()
	game.turn_started.emit(game.active_player_id, game.current_round)

## Submits one local-human command with a sequence number; guest acceptance is asynchronous.
func submit(command: Dictionary) -> bool:
	if not can_act():
		return false
	var sequence := next_command
	next_command += 1
	if hosting:
		return _execute(local_player_id, sequence, command)
	pending_command = true
	_pending_elapsed = 0.0
	_send(1, "command", {"seq": sequence, "command": command})
	changed.emit()
	return true

## Rejects duplicate sequences and paused state, runs rules, and publishes accepted changes.
func _execute(seat: int, sequence: int, command: Dictionary) -> bool:
	if sequence <= int(last_commands.get(seat, 0)) or state != "playing" or paused_for_disconnect or not is_instance_valid(game):
		return false
	last_commands[seat] = sequence
	executing = true
	var accepted := GameCommands.execute(game, seat, command)
	executing = false
	if accepted:
		revision += 1
		publish_state()
	return accepted

## Sends each loaded peer its filtered snapshot and refreshes host presentation.
func publish_state() -> void:
	if not hosting or not is_instance_valid(game):
		return
	for remote: int in peer_seats:
		if loaded.get(int(peer_seats[remote]), false):
			_send(remote, "snapshot", snapshot_codec.capture(game, int(peer_seats[remote])))
	game.update_ui()
	game.fog_of_war.refresh(true)
	changed.emit()

## Frequent small clock updates avoid retransmitting entities every second.
func broadcast_clock() -> void:
	if hosting and is_instance_valid(game) and game.turn_clock != null:
		_broadcast("clock", game.turn_clock.capture())

func _apply_snapshot(data: Dictionary) -> void:
	if int(data.get("revision", -1)) < revision:
		return
	if not is_instance_valid(game):
		pending_snapshot = data
		return
	revision = int(data.revision)
	state = "playing"
	MatchSnapshot.apply(game, data)
	changed.emit()

## Releases a lobby seat or pauses an ongoing match for human reconnection.
func _peer_left(remote: int) -> void:
	room_access.pending.erase(remote)
	_peer_budgets.erase(remote)
	_handshake_deadlines.erase(remote)
	_rejected.erase(remote)
	if not peer_seats.has(remote):
		return
	var seat := int(peer_seats[remote])
	peer_seats.erase(remote)
	if state == "lobby":
		for token in tokens.keys():
			if int(tokens[token]) == seat:
				tokens.erase(token)
		for index in range(seats.size() - 1, -1, -1):
			if int(seats[index].id) == seat:
				seats.remove_at(index)
	else:
		for row: Dictionary in seats:
			if int(row.id) == seat:
				row.connected = false
		loaded.erase(seat)
		if not is_instance_valid(game) or (game.winner_id == -1 and not game.eliminated_player_ids.has(seat)):
			paused_for_disconnect = true
			_disconnect_elapsed = 0.0
	_publish_lobby()

## Dispatches messages according to sender identity and host/guest role.
func _receive(sender: int, kind: String, data: Dictionary) -> void:
	if hosting:
		if kind == "auth":
			var hello := room_access.authenticate(sender, str(data.get("proof", "")))
			if hello.is_empty():
				_reject(sender, "Incorrect or expired room password. Try again.")
			else:
				_accept(sender, hello, true)
			return
		if kind == "hello":
			_accept(sender, data)
			return
		if not peer_seats.has(sender):
			return
		var seat := int(peer_seats[sender])
		match kind:
			"name":
				if state == "lobby" and data.get("name") is String:
					_set_name(seat, data.name)
			"choice":
				if state == "lobby" and data.get("tribe", "") is String and LanCatalog.TRIBES.has(data.tribe) and data.get("ready") is bool:
					_set_choice(seat, data.tribe, data.ready)
			"loaded":
				if state in ["loading", "playing"] and not loaded.get(seat, false):
					loaded[seat] = true
					_publish_lobby()
					_try_begin()
			"command":
				if data.get("command") is Dictionary and typeof(data.get("seq")) in [TYPE_INT, TYPE_FLOAT] and float(data.seq) == floor(float(data.seq)) and float(data.seq) > 0 and float(data.seq) < 9007199254740991:
					var accepted := _execute(seat, int(data.seq), data.command)
					_send(sender, "result", {"accepted": accepted})
			"sync":
				if is_instance_valid(game):
					_send(sender, "snapshot", snapshot_codec.capture(game, seat))
	else:
		if sender != 1:
			return
		match kind:
			"challenge":
				if state in ["connecting", "reconnecting"] and data.get("nonce") is String:
					_send(1, "auth", {"proof": LanRoomAccess.proof(join_password, data.nonce)})
			"welcome":
				local_player_id = int(data.id)
				reconnect_token = data.token
				next_command = int(data.next)
				_set_roster(data.roster)
				if data.get("in_match", false):
					if is_instance_valid(game):
						state = "playing"
						_send(1, "loaded")
					else:
						state = "loading"
						_load_elapsed = 0.0
				else:
					state = "lobby"
				changed.emit()
			"roster":
				_set_roster(data)
			"start":
				state = "loading"
				_load_elapsed = 0.0
				_set_roster(data.roster)
				bootstrap = data.map
				_install_players()
				GameSession.network_map = bootstrap
				_open_match()
			"clock":
				if is_instance_valid(game) and game.turn_clock != null:
					game.turn_clock.apply_remote(data)
			"snapshot":
				_apply_snapshot(data)
			"result":
				pending_command = false
				changed.emit()
				command_finished.emit(bool(data.accepted))
				if not data.accepted:
					fail("That action is no longer available. Try again.")
			"attack_fx":
				if is_instance_valid(game):
					_play_attack(data)
			"closed", "reject", "kicked":
				if peer != null:
					peer.close()
				peer = null
				state = "ended"
				pending_command = false
				if kind == "kicked":
					reconnect_token = ""
				fail(str(data.get("message", "Connection ended.")))

func _set_roster(data: Dictionary) -> void:
	private_room = bool(data.get("private", false))
	match_mode = str(data.get("mode", GameSession.REGULAR))
	GameSession.match_mode = match_mode
	GameSession.turn_duration = int(data.get("turn_duration", 120))
	turn_duration = GameSession.turn_duration
	seats = data.seats
	capacity = int(data.capacity)
	room_name = data.room
	paused_for_disconnect = bool(data.paused)
	loaded.clear()
	for id in data.get("loaded", []):
		loaded[int(id)] = true
	changed.emit()

## Checks compatibility/access before assigning a seat or restoring a reconnect-token seat.
func _accept(remote: int, data: Dictionary, authenticated: bool = false) -> void:
	if peer_seats.has(remote):
		return
	if str(data.get("version", "")) != compatibility:
		_reject(remote, "Different game versions. Use the same Windows build.")
		return
	var token := str(data.get("token", ""))
	var seat := -1
	if state in ["playing", "loading"] and tokens.has(token):
		seat = int(tokens[token])
		if seat in peer_seats.values():
			# The private token proves the seat; replace a stale ENet connection.
			for old_remote in peer_seats.keys():
				if int(peer_seats[old_remote]) == seat:
					_peer_left(old_remote)
					peer.disconnect_peer(old_remote, true)
		for row: Dictionary in seats:
			if int(row.id) == seat:
				row.connected = true
	elif state == "lobby" and seats.size() < capacity:
		if private_room and not authenticated:
			_send(remote, "challenge", {"nonce": room_access.challenge(remote, data)})
			return
		seat = 2
		var ids: Array = []
		for row: Dictionary in seats:
			ids.append(int(row.id))
		while seat in ids:
			seat += 1
		seats.append(_seat(seat, str(data.get("name", "")), str(data.get("tribe", ""))))
		token = Crypto.new().generate_random_bytes(24).hex_encode()
		tokens[token] = seat
	else:
		_reject(remote, "The room is full or the match has already started.")
		return
	peer_seats[remote] = seat
	_handshake_deadlines.erase(remote)
	_send(remote, "welcome", {"id": seat, "token": token, "next": int(last_commands.get(seat, 0)) + 1, "roster": _roster(), "in_match": state != "lobby"})
	if state != "lobby" and not data.get("has_match", false):
		_send(remote, "start", {"map": bootstrap, "roster": _roster()})
	_publish_lobby()

func _reject(remote: int, message: String) -> void:
	_send(remote, "reject", {"message": message})
	_rejected[remote] = Time.get_ticks_msec() + 500

## Applies a per-peer packet budget to bound excessive message processing.
func _allow_packet(remote: int) -> bool:
	var now := Time.get_ticks_msec()
	var budget: Dictionary = _peer_budgets.get(remote, {"at": now, "remaining": 40.0})
	budget.remaining = minf(40.0, float(budget.remaining) + (now - int(budget.at)) * 0.02)
	budget.at = now
	var allowed := float(budget.remaining) >= 1.0
	if allowed:
		budget.remaining -= 1.0
	_peer_budgets[remote] = budget
	return allowed and not _rejected.has(remote)

## Cosmetic events never mutate rules or determine when a turn may end.
func present_attack(attacker: Unit, target: Vector2i, cells: Array[Vector2i]) -> void:
	var event := {"key": LanCatalog.unit_key(attacker.scene_file_path), "from": LanCatalog.xy(attacker.current_cell), "to": LanCatalog.xy(target), "cells": []}
	for cell in cells:
		event.cells.append(LanCatalog.xy(cell))
	for row: Dictionary in seats:
		var seat := int(row.id)
		if not game.is_cell_visible_to_player(attacker.current_cell, seat):
			continue
		var visible := true
		for cell in cells:
			visible = visible and game.is_cell_visible_to_player(cell, seat)
		if not visible:
			continue
		if seat == local_player_id:
			_play_attack(event)
		else:
			for remote: int in peer_seats:
				if int(peer_seats[remote]) == seat:
					_send(remote, "attack_fx", event)

func _play_attack(event: Dictionary) -> void:
	var scene: PackedScene = LanCatalog.UNITS[event.key]
	var prototype: Unit = scene.instantiate()
	var data := prototype.data
	prototype.free()
	var cells: Array[Vector2i] = []
	for cell in event.cells:
		cells.append(LanCatalog.cell(cell))
	var presentation := AttackPresentation.new()
	get_tree().current_scene.add_child(presentation)
	presentation.play_attack(game.board_manager.cell_to_world(LanCatalog.cell(event.from)), game.board_manager.cell_to_world(LanCatalog.cell(event.to)), data, game.board_manager.get_cells_world_size(cells))

func _process(delta: float) -> void:
	_process_discovery(delta)
	if peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer.poll()
		if hosting:
			for remote in _handshake_deadlines.keys():
				if Time.get_ticks_msec() > int(_handshake_deadlines[remote]):
					peer.disconnect_peer(remote, true)
					_peer_left(remote)
			for remote in _rejected.keys():
				if Time.get_ticks_msec() > int(_rejected[remote]):
					peer.disconnect_peer(remote, true)
					_peer_left(remote)
		var connection := peer.get_connection_status()
		if not hosting and connection == MultiplayerPeer.CONNECTION_CONNECTED and not _hello_sent:
			_hello_sent = true
			_send(1, "hello", {"version": compatibility, "name": display_name, "tribe": selected_tribe, "token": reconnect_token, "has_match": is_instance_valid(game)})
		for _packet in SETTINGS.packets_per_frame:
			if peer == null or peer.get_available_packet_count() == 0:
				break
			var sender := peer.get_packet_peer()
			var bytes := peer.get_packet()
			if hosting and not _allow_packet(sender):
				continue
			if bytes.size() > SETTINGS.max_packet_bytes:
				continue
			var packet: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if packet is Dictionary and packet.get("kind") is String and packet.get("data") is Dictionary:
				_receive(sender, packet.kind, packet.data)
	if not hosting and peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED and state in ["playing", "loading", "lobby"]:
		if state == "lobby":
			state = "ended"
			fail("The host is no longer available.")
		else:
			state = "reconnecting"
			pending_command = false
			_retry_elapsed = 0.0
			changed.emit()
	if state in ["connecting", "reconnecting"]:
		_connect_elapsed += delta
		if state == "connecting" and _connect_elapsed > SETTINGS.connect_timeout:
			if peer != null:
				peer.close()
			peer = null
			state = "ended"
			fail("No response. Check the address, same Wi-Fi, and Windows Private-network firewall permission.")
		elif state == "reconnecting":
			_retry_elapsed += delta
			if _retry_elapsed > SETTINGS.retry_interval:
				_retry_elapsed = 0.0
				_connect()
	if state == "loading":
		_load_elapsed += delta
		if _load_elapsed > SETTINGS.load_timeout:
			if hosting:
				_broadcast("closed", {"message": "A player could not load the match. Please create a new lobby."})
			state = "ended"
			fail("Match loading timed out. Return to the menu and try again.")
	if paused_for_disconnect:
		_disconnect_elapsed += delta
	if pending_command:
		_pending_elapsed += delta
		if _pending_elapsed > SETTINGS.connect_timeout:
			pending_command = false
			_send(1, "sync")
			fail("The action response was delayed. Refreshing the match.")
			changed.emit()

func _setup_discovery(as_host: bool) -> void:
	if discovery != null:
		discovery.close()
	discovery = PacketPeerUDP.new()
	discovery.set_broadcast_enabled(true)
	var result := ERR_CANT_CREATE
	for slot in SETTINGS.discovery_slots if as_host else 1:
		result = discovery.bind(SETTINGS.discovery_port + slot if as_host else 0)
		if result == OK:
			break
	discovery_available = result == OK
	if result != OK:
		discovery = null
		return
	_discovery_elapsed = SETTINGS.discovery_interval

## Starts nearby discovery for a guest browser.
func scan_rooms() -> void:
	if not hosting:
		_setup_discovery(false)

func _process_discovery(delta: float) -> void:
	if discovery == null:
		return
	_discovery_elapsed += delta
	if not hosting and _discovery_elapsed >= SETTINGS.discovery_interval:
		_discovery_elapsed = 0.0
		for destination: String in ["255.255.255.255", "127.0.0.1"]:
			for slot in SETTINGS.discovery_slots:
				discovery.set_dest_address(destination, SETTINGS.discovery_port + slot)
				discovery.put_packet("SWEETSPIRE_LAN_DISCOVER_1".to_utf8_buffer())
	for _packet in 16:
		if discovery.get_available_packet_count() == 0:
			break
		var bytes := discovery.get_packet()
		var ip := discovery.get_packet_ip()
		var source_port := discovery.get_packet_port()
		if hosting and not private_room and state == "lobby" and bytes.get_string_from_utf8() == "SWEETSPIRE_LAN_DISCOVER_1":
			discovery.set_dest_address(ip, source_port)
			discovery.put_packet(JSON.stringify({"game": "sweetspire", "room": room_name, "count": seats.size(), "capacity": capacity, "port": port, "mode": match_mode, "version": compatibility}).to_utf8_buffer())
		elif not hosting and bytes.size() < 1024:
			var row: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			if row is Dictionary and row.get("game") == "sweetspire" and row.get("room") is String and typeof(row.get("port")) == TYPE_FLOAT:
				if typeof(row.get("count")) != TYPE_FLOAT or typeof(row.get("capacity")) != TYPE_FLOAT or row.port < 1 or row.port > 65535:
					continue
				row.address = ip
				row.seen = Time.get_ticks_msec()
				rooms[ip + ":" + str(row.port)] = row
				rooms_changed.emit()
	for key in rooms.keys():
		if Time.get_ticks_msec() - int(rooms[key].seen) > int(SETTINGS.room_expiry * 1000):
			rooms.erase(key)
			rooms_changed.emit()
## Uses ordered host execution and snapshot publication for an authorized bot command.
func execute_bot(seat: int, command: Dictionary) -> bool:
	if not hosting or not is_instance_valid(game) or not game.bot_executing or not game.bot_can_act(seat):
		return false
	return _execute(seat, int(last_commands.get(seat, 0)) + 1, command)

## Adds a ready bot to a free host-lobby seat and resets human readiness.
func add_bot() -> bool:
	if not hosting or state != "lobby" or seats.size() >= capacity:
		return false
	var ids: Array = []
	for row: Dictionary in seats:
		ids.append(int(row.id))
	var id := 2
	while id in ids:
		id += 1
	var row := _seat(id, "Bot %d" % id, "saba")
	row.kind = "bot"
	row.profile = "balanced"
	row.ready = true
	seats.append(row)
	_bot_roster_changed()
	return true

## Validates bot profile/tribe and changes its host-managed lobby settings.
func edit_bot(id: int, title: String, tribe: String, profile_id: String) -> bool:
	if not hosting or state != "lobby" or not LanCatalog.TRIBES.has(tribe) or not BotCatalog.PROFILES.has(profile_id):
		return false
	for row: Dictionary in seats:
		if int(row.id) == id and row.get("kind", "human") == "bot":
			row.name = title.strip_edges().left(24) if not title.strip_edges().is_empty() else "Bot %d" % id
			row.tribe = tribe
			row.profile = profile_id
			_bot_roster_changed()
			return true
	return false

## Frees a bot seat in the lobby; it cannot remove or replace a human.
func remove_bot(id: int) -> bool:
	if not hosting or state != "lobby":
		return false
	for index in seats.size():
		if int(seats[index].id) == id and seats[index].get("kind", "human") == "bot":
			seats.remove_at(index)
			_bot_roster_changed()
			return true
	return false

func _bot_roster_changed() -> void:
	for row: Dictionary in seats:
		row.ready = row.get("kind", "human") == "bot"
	seats.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	_publish_lobby()
