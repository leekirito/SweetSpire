class_name EconomyManager
extends RefCounted


func can_interact_with_resource(
	game: MatchManager,
	resource: Resources,
	player_id: int
) -> bool:
	if game.current_phase != MatchManager.Phase.PLAYER_TURN:
		return false
	if game.active_player_id != player_id or resource == null:
		return false
	if game.structure_manager.structures.has(resource.current_cell):
		return false
	if resource.owner_id != player_id or resource.controlling_building_id == -1:
		return false

	var building: Building = game.get_building(resource.controlling_building_id)
	return building != null and building.owner_id == player_id


func request_upgrade_resource(
	game: MatchManager,
	resource_instance_id: int,
	player_id: int
) -> bool:
	var resource: Resources = game.get_resource(resource_instance_id)
	if not can_interact_with_resource(game, resource, player_id):
		return false
	if resource.is_upgraded or not resource.data.can_upgrade:
		return false

	var player: PlayerState = game.get_player(player_id)
	if player == null or not player.has_technology(resource.data.upgrade_technology_id):
		return false

	var building: Building = game.get_building(resource.controlling_building_id)
	if building == null:
		return false

	building.add_exp(resource.data.exp)
	resource.upgrade_resource()
	return true


func collect_sugars(game: MatchManager) -> void:
	for building: Building in game.buildings.values():
		if building.owner_id == -1:
			continue
		var player: PlayerState = game.get_player(building.owner_id)
		if player == null:
			push_warning("No player found for building owner: " + str(building.owner_id))
			continue
		var income := building.by_turn_sugar + game.structure_manager.income_for(building)
		player.sugars += income
		building.show_sugar_gain(income)
	for structure: Structure in game.structure_manager.structures.values():
		structure.on_round_end(game)


func request_collect_resource(
	game: MatchManager,
	resource_instance_id: int,
	player_id: int
) -> bool:
	var resource: Resources = game.get_resource(resource_instance_id)
	if not can_interact_with_resource(game, resource, player_id):
		return false

	var player: PlayerState = game.get_player(player_id)
	if player == null or not resource.data.can_collect or not player.has_technology(resource.data.collect_technology_id):
		return false

	var building: Building = game.get_building(resource.controlling_building_id)
	if building == null:
		return false

	building.add_exp(resource.data.exp)
	player.sugars += resource.data.collect_sugar
	game.update_ui()
	game.board_manager.unregister_resource(resource)
	game.resources.erase(resource.resource_instance_id)
	resource.collect_resource()
	return true


func request_recruit_unit(
	game: MatchManager,
	building_id: int,
	unit_scene: PackedScene
) -> Unit:
	var building: Building = game.get_building(building_id)
	if building == null or building.owner_id != game.active_player_id:
		return null

	var player: PlayerState = game.get_active_player()
	if player == null:
		return null
	if game.board_manager.get_unit_id_at_cell(building.current_cell) != -1:
		return null

	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		return null
	if unit.data == null:
		unit.queue_free()
		return null
	if not player.has_technology(unit.data.required_technology_id):
		unit.queue_free()
		return null
	if player.sugars < unit.data.cost:
		unit.queue_free()
		return null

	player.sugars -= unit.data.cost
	game.get_tree().current_scene.add_child(unit)
	unit.setup_player(player)
	unit.global_position = game.board_manager.cell_to_world(building.current_cell)
	game.register_new_unit(unit)
	return unit



