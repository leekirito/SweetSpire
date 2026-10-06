extends Node
func _ready() -> void:
	call_deferred("run")

func run() -> void:
	GameSession.clear_players()
	GameSession.hotseat_mode = true
	GameSession.map_seed = 87654
	GameSession.match_mode = GameSession.REGULAR if "--regular" in OS.get_cmdline_user_args() else GameSession.FOG_OF_WAR
	for id in range(1, 9):
		var player := PlayerState.new()
		player.player_id = id
		player.controller_kind = "human" if id == 2 else "bot"
		player.player_name = "Seat %d" % id
		player.tribe = LanCatalog.TRIBES[["saba", "malagkit", "kamote"][(id - 1) % 3]]
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		GameSession.add_player(player)
	var scene: Node = load("res://scenes/main/Main.tscn").instantiate()
	scene.tree_entered.connect(func(): get_tree().current_scene = scene, CONNECT_ONE_SHOT)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var game: MatchManager = scene.get_node("MatchManager")
	assert(game.get_node("BotDirector").get_child_count() == 7)
	for bot: AIController in game.get_node("BotDirector").get_children():
		bot.profile.action_delay = 0
		bot.profile.turn_intro_delay = 0
		bot.profile.max_actions_per_turn = 12
	var deadline := Time.get_ticks_msec() + 100000
	while game.current_round < 2 and Time.get_ticks_msec() < deadline:
		if game.active_player_id == 2 and not game._any_unit_animating():
			game.request_end_turn()
		await get_tree().process_frame
	var success := game.current_round == 2 and game.get_viewing_player_id() == 2 and not get_tree().paused
	for bot: AIController in game.get_node("BotDirector").get_children():
		success = success and bot.started_round >= 1 and bot.failures == 0
	print("BOT EIGHT SEATS: ", "PASS" if success else "FAIL", " round=", game.current_round, " mode=", GameSession.match_mode)
	scene.queue_free()
	await get_tree().process_frame
	GameSession.clear_players()
	get_tree().quit(0 if success else 1)
