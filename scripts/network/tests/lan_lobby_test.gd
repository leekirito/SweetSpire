extends Node
var checks := 0
var failures := 0

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LAN LOBBY: " + label)

func connect_guest() -> ENetMultiplayerPeer:
	var client := ENetMultiplayerPeer.new()
	client.create_client("127.0.0.1", 29877)
	for frame in 180:
		client.poll()
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			break
		await get_tree().process_frame
	return client

func send(client: ENetMultiplayerPeer, kind: String, data: Dictionary) -> void:
	client.set_target_peer(1)
	client.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	client.put_packet(JSON.stringify({"kind": kind, "data": data}).to_utf8_buffer())

func receive(client: ENetMultiplayerPeer, kind: String) -> Dictionary:
	for frame in 180:
		if client.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
			break
		client.poll()
		while client.get_available_packet_count() > 0:
			var packet: Dictionary = JSON.parse_string(client.get_packet().get_string_from_utf8())
			if packet.kind == kind:
				return packet.data
		await get_tree().process_frame
	return {}

func run() -> void:
	check(LanSession.host_room("Host", "Discovery test", 2, "saba", 29877), "host opens")
	var discovery := PacketPeerUDP.new()
	discovery.bind(0)
	discovery.set_dest_address("127.0.0.1", LanSession.SETTINGS.discovery_port)
	discovery.put_packet("SWEETSPIRE_LAN_DISCOVER_1".to_utf8_buffer())
	for frame in 180:
		if discovery.get_available_packet_count() > 0:
			break
		await get_tree().process_frame
	check(discovery.get_available_packet_count() > 0, "LAN discovery replies")
	if discovery.get_available_packet_count() > 0:
		var room: Dictionary = JSON.parse_string(discovery.get_packet().get_string_from_utf8())
		check(int(room.port) == 29877 and room.room == "Discovery test", "discovery identifies room and custom port")
	discovery.close()
	var wrong := await connect_guest()
	send(wrong, "hello", {"version": "old-build"})
	var rejected := await receive(wrong, "reject")
	check(str(rejected.get("message", "")).contains("Different game versions"), "mismatched build rejected")
	wrong.close()
	var client := await connect_guest()
	send(client, "hello", {"version": LanSession.compatibility, "name": "Guest", "tribe": "saba"})
	var welcome := await receive(client, "welcome")
	check(int(welcome.get("id", -1)) == 2, "guest gets stable seat")
	check(str(welcome.get("token", "")).length() == 48, "private reconnect token issued")
	check(LanSession.seats.size() == 2, "duplicate tribe allowed")
	LanSession.choose("saba", true)
	send(client, "choice", {"tribe": "saba", "ready": true})
	for frame in 30:
		client.poll()
		await get_tree().process_frame
	check(LanSession.can_start(), "all occupied seats ready")
	LanSession.choose_mode(GameSession.REGULAR)
	check(not LanSession.can_start() and LanSession.seats.all(func(row: Dictionary): return not row.ready), "host mode change clears everyone's readiness")
	check(LanSession._roster().mode == GameSession.REGULAR, "mode is included in shared lobby state")
	send(client, "mode", {"mode": GameSession.FOG_OF_WAR})
	for frame in 10:
		client.poll()
		await get_tree().process_frame
	check(LanSession.match_mode == GameSession.REGULAR, "guest cannot change the host's mode")
	LanSession.choose_mode("unknown")
	check(LanSession.match_mode == GameSession.REGULAR, "unknown mode rejected")
	send(client, "choice", {"tribe": "kamote", "ready": true})
	for frame in 30:
		client.poll()
		await get_tree().process_frame
	check(not LanSession.can_start(), "tribe change clears readiness")
	var full := await connect_guest()
	send(full, "hello", {"version": LanSession.compatibility, "name": "Extra", "tribe": "malagkit"})
	rejected = await receive(full, "reject")
	check(str(rejected.get("message", "")).contains("full"), "full lobby rejected")
	full.close()
	var remote: int = LanSession.peer_seats.keys()[0]
	LanSession.peer.disconnect_peer(remote)
	for frame in 30:
		if client.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
			client.poll()
		await get_tree().process_frame
	check(LanSession.seats.size() == 1 and LanSession.tokens.is_empty(), "departed lobby seat and token removed")
	client.close()
	LanSession.leave()
	check(not LanSession.active() and GameSession.hotseat_mode == false, "session cleans up to offline")
	print("LAN LOBBY: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
