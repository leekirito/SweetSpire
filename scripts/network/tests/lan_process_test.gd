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
	if host:
		assert(LanSession.host_room("Host", "LAN test", expected, "saba", 29876, mode))
		LanSession.choose("saba", true)
	else:
		# Exercise compatibility after a different resource/instance creation order.
		var menu: Node = load("res://scenes/entities/UI/MainMenu.tscn").instantiate()
		get_tree().root.add_child(menu)
		menu.queue_free()
		assert(LanSession.join_room("127.0.0.1", "Guest", "kamote", 29876))

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
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
		return
	if stage == 0:
		check(GameSession.match_mode == mode, "everyone uses the host's selected mode")
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
		check(game.get_player(me).has_technology("fishing"), "reconnect preserved technology")
		check(game.get_unit(my_unit).current_cell == moved_cell, "reconnect preserved movement")
		if not host:
			check(game.request_end_turn(), "rejoined player can finish turn")
		stage = 6
