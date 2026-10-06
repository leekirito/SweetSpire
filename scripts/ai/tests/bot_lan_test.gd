extends Node
var host := false
var solo := false
var elapsed := 0.0
var initialized := false
var done := false
var mode := GameSession.FOG_OF_WAR
var test_run := ""
var next_end := 0
var reconnected := false
var paused_actions := -1

func _ready() -> void:
	call_deferred("_start")

func _start() -> void:
	reparent(get_tree().root)
	var args := OS.get_cmdline_user_args()
	host = "--host" in args
	solo = "--solo" in args
	mode = GameSession.REGULAR if "--regular" in args else GameSession.FOG_OF_WAR
	for arg in args:
		if arg.begins_with("--test-run="):
			test_run = arg.get_slice("=", 1).validate_filename()
	test_run += "-solo" if solo else "-peers"
	if host:
		assert(LanSession.host_room("Host", "Bot LAN", 3, "saba", 29880, mode))
		assert(LanSession.add_bot())
		assert(LanSession.edit_bot(2, "Bot", "kamote", "balanced"))
		LanSession.choose("saba", true)
	else:
		assert(LanSession.join_room("127.0.0.1", "Guest", "malagkit", 29880))

func fail(message: String) -> void:
	push_error("BOT LAN: " + message)
	get_tree().quit(1)
	set_process(false)

func _process(delta: float) -> void:
	if done:
		_finish_if_complete()
		return
	elapsed += delta
	if elapsed > 100:
		fail("Timed out: " + LanSession.state + " active=" + str(LanSession.game.active_player_id if is_instance_valid(LanSession.game) else -1) + " round=" + str(LanSession.game.current_round if is_instance_valid(LanSession.game) else -1))
		return
	if LanSession.state == "lobby":
		if host:
			if LanSession.seats.size() == (2 if solo else 3) and LanSession.can_start():
				LanSession.start_match()
		else:
			for row: Dictionary in LanSession.seats:
				if int(row.id) == LanSession.local_player_id and not row.ready:
					LanSession.choose("malagkit", true)
		return
	if LanSession.state != "playing" or not is_instance_valid(LanSession.game):
		return
	var game: MatchManager = LanSession.game
	if not initialized:
		initialized = true
		if game.get_node("BotDirector").get_child_count() != (1 if host else 0):
			fail("Only host creates controller")
			return
		if not game.get_player(2).is_bot():
			fail("Bot kind missing from roster")
			return
		if host:
			var bot: AIController = game.get_node("BotDirector").get_child(0)
			bot.profile.action_delay = 0.05
			bot.profile.turn_intro_delay = 0.6
			bot.profile.debug_decisions = true
		elif game.execute_bot_command(2, {"action": "end_turn"}):
			fail("Guest executed bot action")
			return
	if not host and not reconnected and game.active_player_id == 2:
		reconnected = true
		LanSession.peer.close()
		LanSession.state = "reconnecting"
		LanSession._retry_elapsed = LanSession.SETTINGS.retry_interval
		return
	if host and LanSession.paused_for_disconnect:
		var count: int = game.get_node("BotDirector").get_child(0).actions_taken
		if paused_actions != -1 and count != paused_actions:
			fail("Bot acted while disconnected player was paused")
		paused_actions = count
		return
	if game.current_round >= 3 and not done:
		done = true
		if not host and not reconnected:
			fail("Reconnect test did not run")
			return
		if host and not solo and paused_actions == -1:
			fail("Host did not pause for reconnect")
			return
		if host and int(LanSession.last_commands.get(2, 0)) < 3:
			fail("Bot actions did not use ordered LAN commands")
			return
		if game.get_viewing_player_id() != LanSession.local_player_id:
			fail("Bot changed human perspective")
			return
		var path := "res://.godot/lan-tests/bot-%s-%s" % [test_run, "host" if host else "guest"]
		var marker := FileAccess.open(path, FileAccess.WRITE)
		marker.store_string("done")
		marker.close()
	if done:
		_finish_if_complete()
		return
	if LanSession.can_act() and Time.get_ticks_msec() >= next_end and not game._any_unit_animating():
		game.request_end_turn()
		next_end = Time.get_ticks_msec() + 100

func _finish_if_complete() -> void:
	var other := "res://.godot/lan-tests/bot-%s-%s" % [test_run, "guest" if host else "host"]
	if solo or FileAccess.file_exists(other):
		print("BOT LAN PASS: ", "host" if host else "guest", " mode=", mode, " revision=", LanSession.revision)
		get_tree().quit()
		set_process(false)
