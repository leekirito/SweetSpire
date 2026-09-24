class_name TurnManager
extends RefCounted


func request_end_turn(game: MatchManager) -> bool:
	if game.current_phase != MatchManager.Phase.PLAYER_TURN:
		return false
	if any_unit_animating(game):
		return false

	end_turn(game)
	return true


func end_turn(game: MatchManager) -> void:
	if game.players.is_empty():
		return

	var next_index: int = game.active_player_index
	var round_completed: bool = false
	for _step: int in range(game.players.size()):
		next_index += 1
		if next_index >= game.players.size():
			next_index = 0
			round_completed = true
		if not game.eliminated_player_ids.has(game.players[next_index].player_id):
			break

	if round_completed:
		game.capture_manager.capture_occupied_buildings(game)
		game.evaluate_eliminations()
		if game.current_phase == MatchManager.Phase.GAME_OVER:
			return

		game.victory_manager.evaluate_center_control(game)
		if game.current_phase == MatchManager.Phase.GAME_OVER:
			return

		game.current_round += 1
		game.economy_manager.collect_sugars(game)

	game.active_player_index = next_index
	game.active_player_id = game.players[next_index].player_id
	start_player_turn(game)


func start_player_turn(game: MatchManager) -> void:
	game.current_phase = MatchManager.Phase.PLAYER_TURN
	reset_player_units(game, game.active_player_id)
	game.update_ui()
	game.refresh_resource_collectibility_authoritative()
	game.turn_started.emit(game.active_player_id, game.current_round)


func reset_player_units(game: MatchManager, player_id: int) -> void:
	for unit: Unit in game.units.values():
		if unit.owner_id == player_id:
			unit.has_moved = false
			unit.has_attacked = false


func any_unit_animating(game: MatchManager) -> bool:
	for unit: Unit in game.units.values():
		if unit.is_animating:
			return true
	return false
