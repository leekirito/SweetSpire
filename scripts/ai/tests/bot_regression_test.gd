extends Node
var checks := 0
var failures := 0
var game: MatchManager
var scene: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run")

func run() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	var menu = load("res://scenes/entities/UI/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	GameSession.map_seed = 12345
	menu.select_tribe(1, menu.saba_tribe)
	menu.select_tribe(2, menu.kamote_tribe)
	var card: Node = menu.hotseat_grid.get_child(1)
	card.get_node("Margin/Content/Controller").item_selected.emit(1)
	check(menu.hotseat_kinds[2] == "bot" and card.get_node("Margin/Content/Profile").visible, "Authored controls assign a bot")
	check(menu.prepare_hotseat_session() and GameSession.players[1].is_bot(), "Hotseat installs selected bot seat")
	menu.hotseat_kinds[1] = "bot"
	check(not menu.prepare_hotseat_session(), "At least one human required")
	menu.hotseat_kinds[1] = "human"
	check(menu.prepare_hotseat_session(), "Human plus bot is valid")
	menu.queue_free()
	await get_tree().process_frame
	scene = load("res://scenes/main/Main.tscn").instantiate()
	scene.tree_entered.connect(func(): get_tree().current_scene = scene, CONNECT_ONE_SHOT)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	game = scene.get_node("MatchManager")
	check(game.get_node("BotDirector").get_child_count() == 1, "Exactly one controller for bot seat")
	var bot: AIController = game.get_node("BotDirector").get_child(0)
	bot.profile.action_delay = 0
	bot.profile.turn_intro_delay = 0
	bot.profile.debug_decisions = true
	var memory := BotMemory.new()
	var view := BotObservation.capture(game, 2, memory)
	check(view.units.size() == 1 and view.units[0].owner == 2, "Unseen enemy unit is absent from bot observation")
	check(not view.has("players") and view.sugar == game.get_player(2).sugars, "Observation contains own economy only")
	var enemy: Unit = game.units.values()[0]
	var old_health := enemy.unit_health
	enemy.unit_health = 1
	check(BotObservation.capture(game, 2, memory).units == view.units, "Hidden enemy health cannot change bot decisions")
	enemy.unit_health = old_health
	var before: Vector2i = game.units.values()[1].current_cell
	check(game.request_end_turn(), "Human ends turn into bot")
	check(not get_tree().paused and not game.hotseat_handoff.visible, "Bot turn has no pass-device prompt")
	check(game.get_viewing_player_id() == 1, "Bot turn preserves human perspective")
	check(not LanSession.can_act() and not game.request_end_turn(), "Human commands blocked on bot turn")
	var deadline := Time.get_ticks_msec() + 30000
	while game.active_player_id == 2 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(game.active_player_id == 1 and game.current_round == 2, "Bot completes turn automatically")
	check(bot.actions_taken > 0 and bot.failures == 0, "Bot submits useful legal actions")
	check(game.units.values()[1].current_cell != before, "Bot explores")
	check(game.get_player(2).unlocked_technologies.size() > 1 or game.structure_manager.structures.size() > 0, "Bot develops its economy")
	bot.profile.debug_decisions = false
	var embarked := false
	deadline = Time.get_ticks_msec() + 90000
	while game.current_round < 14 and game.current_phase != MatchManager.Phase.GAME_OVER and Time.get_ticks_msec() < deadline:
		if game.active_player_id == 1 and not game._any_unit_animating():
			game.request_end_turn()
		for unit: Unit in game.units.values():
			if unit.owner_id == 2 and unit.is_embarked:
				embarked = true
		await get_tree().process_frame
	check(game.current_round >= 14 or game.current_phase == MatchManager.Phase.GAME_OVER, "Extended bot match does not stall")
	check(embarked, "Bot uses its dock to embark")
	print("BOT SOAK round=", game.current_round, " embarked=", embarked, " goals=", bot.memory.goals)
	scene.queue_free()
	await get_tree().process_frame
	GameSession.clear_players()
	# Mixed human/bot privacy in Regular, with a bot between the humans.
	GameSession.hotseat_mode = true
	GameSession.match_mode = GameSession.REGULAR
	GameSession.map_seed = 12345
	for id in [1, 2, 3]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Seat %d" % id
		player.controller_kind = "bot" if id == 2 else "human"
		player.tribe = LanCatalog.TRIBES["saba"]
		player.sugars = 20
		GameSession.add_player(player)
	scene = load("res://scenes/main/Main.tscn").instantiate()
	scene.tree_entered.connect(func(): get_tree().current_scene = scene, CONNECT_ONE_SHOT)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	game = scene.get_node("MatchManager")
	bot = game.get_node("BotDirector").get_child(0)
	bot.profile.action_delay = 0
	bot.profile.turn_intro_delay = 0
	bot.profile.max_actions_per_turn = 8
	var camera_position: Vector2 = scene.get_node("Camera2D").position
	check(game.request_end_turn(), "Mixed Hotseat starts bot turn")
	check(game.get_node("BotTurnStatus/Cover").visible and not get_tree().paused, "Privacy cover hides bot turn without pausing simulation")
	check(scene.get_node("Camera2D").position == camera_position, "Camera does not follow bot")
	deadline = Time.get_ticks_msec() + 30000
	while game.active_player_id == 2 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	check(game.active_player_id == 3 and game.hotseat_handoff.visible and get_tree().paused, "Next human receives the pass-device prompt")
	check(game.get_viewing_player_id() == 3 and game.fog_of_war.viewing_player_id == 1, "Previous view stays covered until human continues")
	check(game.continue_hotseat_turn() and game.get_viewing_player_id() == 3, "Continue restores incoming human turn")
	check(not game.get_node("BotTurnStatus").visible, "Bot cover clears on human turn")
	scene.queue_free()
	await get_tree().process_frame
	GameSession.clear_players()
	print("BOT REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
