class_name VictoryManager
extends RefCounted


func evaluate_eliminations(game: MatchManager) -> void:
	if game.current_phase == MatchManager.Phase.GAME_OVER:
		return

	for player: PlayerState in game.players:
		if game.eliminated_player_ids.has(player.player_id):
			continue
		if _player_has_buildings(game, player.player_id):
			continue
		if _player_has_units(game, player.player_id):
			continue

		game.eliminated_player_ids[player.player_id] = true
		game.player_eliminated.emit(player.player_id)

	var survivors: Array[PlayerState] = []
	for player: PlayerState in game.players:
		if not game.eliminated_player_ids.has(player.player_id):
			survivors.append(player)

	if survivors.size() == 1:
		game.finish_match_authoritative(survivors[0].player_id, "LAST PLAYER STANDING")


func evaluate_center_control(game: MatchManager) -> void:
	if game.current_phase == MatchManager.Phase.GAME_OVER:
		return

	var controller: PlayerState = get_center_controller(game)
	if controller == null:
		return

	controller.center_control_rounds += 1
	if controller.center_control_rounds >= game.center_control_rounds:
		game.finish_match_authoritative(
			controller.player_id,
			"CENTER HELD FOR %d ROUNDS" % game.center_control_rounds
		)


func get_center_controller(game: MatchManager) -> PlayerState:
	var unit_id: int = game.board_manager.get_unit_id_at_cell(game.sweetspire_center_cell)
	if unit_id == -1:
		return null

	var unit: Unit = game.get_unit(unit_id)
	if unit == null or game.eliminated_player_ids.has(unit.owner_id):
		return null
	return game.get_player(unit.owner_id)


func _player_has_buildings(game: MatchManager, player_id: int) -> bool:
	for building: Building in game.buildings.values():
		if is_instance_valid(building) and building.owner_id == player_id:
			return true
	return false


func _player_has_units(game: MatchManager, player_id: int) -> bool:
	for unit: Unit in game.units.values():
		if is_instance_valid(unit) and unit.owner_id == player_id:
			return true
	return false
