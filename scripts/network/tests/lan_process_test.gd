extends Node
var host := false
var expected := 2
var stage := 0
var clock := 0.0
var moved_cell := Vector2i.ZERO
var my_unit := -1
var reconnect_done := false
var frames := 0
var mode: String = GameSession.FOG_OF_WAR
var test_run := ""

func _ready() -> void:
	set_process(false)
	call_deferred("_start")

func _start() -> void:
	# Survive the transition from the runner to Main.
	reparent(get_tree().root)
	set_process(true)
	var args := OS.get_cmdline_user_args()
	host = "--host" in args
	mode = GameSession.REGULAR if "--regular" in args else GameSession.FOG_OF_WAR
	for arg in args:
		if arg.begins_with("--players="):
			expected = int(arg.get_slice("=", 1))
		elif arg.begins_with("--test-run="):
			test_run = arg.get_slice("=", 1).validate_filename()
	if host:
		assert(LanSession.host_room("Host", "LAN test", expected, "saba", 29876, mode))
		check(LanSession.configure_room("LAN test", expected, mode, false, "", 180), "host chooses three-minute turns")
		if "--private" in args:
			assert(LanSession.configure_room("Private test", expected, mode, true, "process-secret"))
		LanSession.choose("saba", true)
	else:
		# Exercise compatibility after a different resource/instance creation order.
		var menu: Node = load("res://scenes/entities/UI/MainMenu.tscn").instantiate()
		get_tree().root.add_child(menu)
		menu.queue_free()
		assert(LanSession.join_room("127.0.0.1", "Guest", "kamote", 29876, "process-secret" if "--private" in args else ""))

func check(value: bool, label: String) -> void:
	if not value:
		push_error("LAN CHECK FAILED: " + label)
		get_tree().quit(1)
	else:
		print("LAN CHECK PASS: ", label)

func _process(delta: float) -> void:
	clock += delta
	frames += 1
	if clock > 120.0:
		push_error("LAN TEST TIMED OUT: " + str(stage) + " " + LanSession.state + " " + LanSession.error_message)
		get_tree().quit(1)
	if LanSession.state == "lobby":
		if not host:
			var ready := false
			for row: Dictionary in LanSession.seats:
				if int(row.id) == LanSession.local_player_id:
					ready = row.ready
			if not ready:
				LanSession.choose("kamote", true)
		elif LanSession.seats.size() == expected and LanSession.can_start():
			check(LanSession.start_match(), "host starts ready lobby")
		return
	if LanSession.state != "playing" or not is_instance_valid(LanSession.game) or LanSession.paused_for_disconnect:
		return
	var game: MatchManager = LanSession.game
	var me := LanSession.local_player_id
	if stage >= 5 and game.current_round >= 3:
		print("LAN PROCESS SUCCESS ", "HOST" if host else "GUEST", " seat=", me)
		set_process(false)
		var completed := await _wait_for_test_peers(me)
		get_tree().quit(0 if completed else 1)
		return
	if stage == 0:
		check(GameSession.match_mode == mode, "everyone uses the host's selected mode")
		check(GameSession.turn_duration == 180 and LanSession.turn_duration == 180, "everyone receives host timer setting")
		check(game.turn_clock.remaining > 0 and game.turn_clock.remaining <= 180, "initial authoritative timer received")
		if mode == GameSession.REGULAR:
			check(game.units.size() == expected, "Regular replicates every starting unit")
			check(game.fog_of_war.visible_by_player[me].size() == game.board_manager.tile_map_layer.get_used_cells().size(), "Regular reveals whole map on each device")
		check(game.players.size() == expected, "correct roster")
		check(game.fog_of_war.viewing_player_id == me, "local fog remains local")
		check(not game.map_setup_error, "valid map")
		if not host:
			check(not LanSession.submit({"action": "end_turn"}), "guest cannot end host turn")
		for unit: Unit in game.units.values():
			if unit.owner_id == me:
				my_unit = unit.unit_id
		check(my_unit > 0, "own starting unit")
		stage = 1
	if not LanSession.can_act():
		return
	if stage == 1:
		var unit := game.get_unit(my_unit)
		var options := game.board_manager.get_movement_tiles(unit)
		check(not options.is_empty(), "movement options")
		moved_cell = options[0]
		check(game.request_move(my_unit, moved_cell), "move submitted")
		stage = 2
	elif stage == 2:
		check(game.get_unit(my_unit).current_cell == moved_cell, "authoritative movement applied")
		check(game.request_purchase_technology(me, LanCatalog.TECHS["fishing"]), "technology purchase submitted")
		stage = 3
	elif stage == 3:
		check(game.get_player(me).has_technology("fishing"), "technology state applied")
		check(game.get_player(me).sugars == 17, "technology charged once")
		if host:
			game.turn_clock.advance(181)
			check(game.active_player_id != me, "host deadline advances turn across real peers")
		else:
			check(game.request_end_turn(), "turn submitted")
		stage = 4
	elif stage == 4 and game.current_round >= 2:
		check(game.fog_of_war.viewing_player_id == me, "view after full round")
		if host:
			# Let guests exercise token-based reconnection while the host is running.
			check(game.request_end_turn(), "second round host end")
			stage = 5
		elif not reconnect_done:
			reconnect_done = true
			LanSession.peer.close()
			LanSession.state = "reconnecting"
			LanSession._retry_elapsed = LanSession.SETTINGS.retry_interval
			stage = 5
	elif stage == 5:
		check(GameSession.match_mode == mode, "reconnect preserves match mode")
		check(GameSession.turn_duration == 180 and game.turn_clock.remaining > 0 and game.turn_clock.remaining <= 180, "reconnect preserves timer configuration and live countdown")
		check(game.get_player(me).has_technology("fishing"), "reconnect preserved technology")
		check(game.get_unit(my_unit).current_cell == moved_cell, "reconnect preserved movement")
		if not host:
			check(game.request_end_turn(), "rejoined player can finish turn")
		stage = 6

func _wait_for_test_peers(me: int) -> bool:
	# Keep successful peers connected until every process has observed the final
	# snapshot. Otherwise an early test exit pauses slower peers during teardown.
	if test_run.is_empty():
		await get_tree().create_timer(3.0).timeout
		return true
	var prefix := "res://.godot/lan-tests/completion-%s-" % test_run
	var marker := FileAccess.open(prefix + str(me), FileAccess.WRITE)
	marker.store_string("complete")
	marker.close()
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline:
		var complete := true
		for seat in range(1, expected + 1):
			complete = complete and FileAccess.file_exists(prefix + str(seat))
		if complete:
			return true
		await get_tree().create_timer(0.1).timeout
	push_error("LAN completion barrier timed out")
	return false
