extends Node

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs need a real viewport size for GUI hit testing.
	get_tree().root.size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	var menu = load("res://scenes/entities/UI/MainMenu.tscn").instantiate()
	get_tree().root.add_child(menu)
	GameSession.map_seed = 12345
	check(menu.hotseat_player_count == 2, "Default setup has two players")
	check(menu.hotseat_start.disabled, "Cannot start before choosing tribes")
	for count in range(1, 9):
		menu.set_hotseat_player_count(count)
		check(menu.hotseat_grid.get_child_count() == count, "Player count controls visible cards")
		for id in range(1, count + 1):
			menu.select_tribe(id, menu.saba_tribe)
		check(not menu.hotseat_start.disabled, "All selected tribes enable start")
		check(menu.prepare_hotseat_session(), "Selected roster has a valid map")
		check(GameSession.players.size() == count, "Session contains exactly the selected number")
		check(GameSession.hotseat_mode, "Menu enables hotseat mode")
		check(GameSession.map_manifest.starts.size() == count, "All players have assigned spawns")
	menu.hotseat_names[1] = "Mika"
	menu.set_hotseat_player_count(1)
	check(menu.selected_tribes[8] == menu.saba_tribe, "Reducing count preserves hidden choices")
	check(menu.prepare_hotseat_session() and GameSession.players.size() == 1, "Hidden players are excluded from solo session")
	check(GameSession.players[0].player_name == "Mika", "Custom player name is applied")
	menu.set_hotseat_player_count(8)
	check(menu.prepare_hotseat_session(), "Returning to eight restores chosen roster")
	menu.queue_free()
	await get_tree().process_frame
	var scene = load("res://scenes/main/Main.tscn").instantiate()
	scene.tree_entered.connect(func() -> void: get_tree().current_scene = scene, CONNECT_ONE_SHOT)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var game := scene.get_node("MatchManager") as MatchManager
	check(game.current_phase == MatchManager.Phase.PLAYER_TURN, "Eight-player match begins")
	check(game.players.size() == 8 and game.units.size() == 8, "Eight players receive units")
	var cover := game.hotseat_handoff
	check(cover != null and not cover.visible, "Handoff starts hidden")
	var original_view := game.fog_of_war.viewing_player_id
	var original_camera: Vector2 = scene.get_node("Camera2D").position
	var unit: Unit = game.units.values()[0]
	unit.is_animating = true
	check(not game.request_end_turn() and not cover.visible, "Rejected end-turn requests do not show the cover")
	unit.is_animating = false
	check(game.request_end_turn(), "First player can end turn")
	check(game.current_phase == MatchManager.Phase.HOTSEAT_HANDOFF and cover.visible and get_tree().paused, "Black cover pauses the game during handoff")
	check(game.active_player_id == 2 and "Player 2" in cover.player_label.text, "Handoff names the actual next player")
	check(game.fog_of_war.viewing_player_id == original_view and scene.get_node("Camera2D").position == original_camera, "Next player's view waits for confirmation")
	check(cover.continue_button.disabled, "End Turn release cannot immediately dismiss the cover")
	check(not game.request_end_turn(), "Repeated end-turn requests are rejected")
	check(not game.request_move(unit.unit_id, unit.current_cell + Vector2i.RIGHT), "Gameplay commands are blocked during handoff")
	await get_tree().create_timer(0.35, true).timeout
	check(not cover.continue_button.disabled, "Continue becomes available while paused")
	var click := InputEventMouseButton.new()
	click.position = cover.continue_button.get_global_rect().get_center()
	click.global_position = click.position
	click.button_index = MOUSE_BUTTON_LEFT
	var motion := InputEventMouseMotion.new()
	motion.position = click.position
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	check(not cover.visible and not get_tree().paused and game.current_phase == MatchManager.Phase.PLAYER_TURN, "Continue reveals and resumes gameplay")
	check(game.fog_of_war.viewing_player_id == 2, "Continue changes fog to the incoming player")
	check(not game.continue_hotseat_turn(), "Double continuation cannot advance a second turn")
	for id in range(3, 9):
		check(game.request_end_turn() and game.active_player_id == id, "Hotseat advances through all player slots")
		check(cover.visible, "Each new player gets a cover")
		game.continue_hotseat_turn()
	check(game.request_end_turn() and game.active_player_id == 1 and game.current_round == 2, "Eight-player round wraps once")
	check("Mika" in cover.player_label.text, "Handoff uses the custom name")
	game.continue_hotseat_turn()
	game.eliminated_player_ids[2] = true
	check(game.request_end_turn() and game.active_player_id == 3, "Eliminated players are skipped")
	game.continue_hotseat_turn()
	# Reset to a solo match and verify rounds and the center objective remain playable.
	scene.queue_free()
	await get_tree().process_frame
	GameSession.clear_players()
	GameSession.hotseat_mode = true
	var solo := PlayerState.new()
	solo.player_id = 1
	solo.player_name = "Solo"
	solo.tribe = load("res://scripts/data/Tribe/SABA.tres")
	GameSession.add_player(solo)
	scene = load("res://scenes/main/Main.tscn").instantiate()
	scene.tree_entered.connect(func() -> void: get_tree().current_scene = scene, CONNECT_ONE_SHOT)
	get_tree().root.add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	game = scene.get_node("MatchManager")
	check(game.request_end_turn(), "Solo player can finish a round")
	check(game.current_phase == MatchManager.Phase.PLAYER_TURN and game.current_round == 2, "Solo does not instantly win by elimination")
	check(not game.hotseat_handoff.visible and not get_tree().paused, "Solo skips the handoff cover")
	unit = game.units.values()[0]
	game.board_manager.commit_unit_move(unit, game.sweetspire_center_cell)
	for round_index in game.center_control_rounds:
		game.request_end_turn()
	check(game.current_phase == MatchManager.Phase.GAME_OVER and game.winner_id == 1, "Solo can win by holding Sweetspire")
	check(not game.hotseat_handoff.visible, "Victory does not open a handoff")
	scene.queue_free()
	await get_tree().process_frame
	GameSession.clear_players()
	check(not GameSession.hotseat_mode, "Session reset does not leak hotseat mode")
	print("HOTSEAT REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
