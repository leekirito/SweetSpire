class_name CaptureManager
extends RefCounted


func conquer_building(game: MatchManager, building_id: int, player_id: int) -> bool:
	var building: Building = game.get_building(building_id)
	var player: PlayerState = game.get_player(player_id)
	if building == null or player == null:
		return false

	building.conquer(player)
	game.territory_manager.update_resources_for_building(
		building,
		game.get_all_resources_authoritative()
	)
	game.refresh_resource_collectibility_authoritative()
	return true


func capture_occupied_buildings(game: MatchManager) -> void:
	for cell: Vector2i in game.board_manager.occupied_cells:
		if not game.board_manager.building_occupied_cells.has(cell):
			continue

		var building: Building = game.get_building(game.board_manager.building_occupied_cells[cell])
		var unit: Unit = game.get_unit(game.board_manager.occupied_cells[cell])
		if building != null and unit != null and building.owner_id != unit.owner_id:
			conquer_building(game, building.building_id, unit.owner_id)
