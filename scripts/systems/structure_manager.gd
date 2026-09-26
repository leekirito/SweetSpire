class_name StructureManager
extends RefCounted

const DOCK: StructureData = preload("res://scripts/data/Structures/Dock.tres")
const LUMBER: StructureData = preload("res://scripts/data/Structures/LumberFactory.tres")
var structures: Dictionary[Vector2i, Structure] = {}
var game: MatchManager

func controlling_town(cell: Vector2i) -> Building:
	var existing: Structure = structures.get(cell)
	var town_id: int = existing.controlling_building_id if existing != null else game.territory_manager.get_building_id_at_cell(cell)
	return game.get_building(town_id)

func placement_error(data: StructureData, cell: Vector2i, player_id: int) -> String:
	if data not in [DOCK, LUMBER]:
		return "Unknown structure"
	if game.current_phase != MatchManager.Phase.PLAYER_TURN or game.active_player_id != player_id:
		return "Wait for your turn"
	var board := game.board_manager
	if not board.is_cell_on_map(cell) or board.is_cell_blocked(cell):
		return "Cannot build here"
	var town := controlling_town(cell)
	if town == null or town.owner_id != player_id:
		return "Build inside your territory"
	if structures.has(cell) or board.building_occupied_cells.has(cell) or board.occupied_cells.has(cell):
		return "Tile is occupied"
	var player := game.get_player(player_id)
	if player == null or not player.has_technology(data.required_technology_id):
		return "Requires " + data.required_technology_id.capitalize()
	var resource := game.get_resource(board.get_resource_id_at_cell(cell))
	match data.placement:
		StructureData.Placement.WATER:
			if not board.water_cells.has(cell) or board.is_ocean(cell) or resource != null:
				return "Requires non-ocean water"
			var shore := false
			for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor := cell + direction
				if board.is_cell_on_map(neighbor) and not board.water_cells.has(neighbor) and not board.is_cell_blocked(neighbor):
					shore = true
			if not shore:
				return "Requires adjacent land"
		StructureData.Placement.FOREST, StructureData.Placement.MOUNTAIN:
			var required := "forest" if data.placement == StructureData.Placement.FOREST else "mountain"
			if board.water_cells.has(cell) or resource == null or resource.data.resource_alias != required:
				return "Requires " + required
		StructureData.Placement.GROUND:
			if board.water_cells.has(cell) or resource != null:
				return "Requires clear ground"
	if player.sugars < data.sugar_cost:
		return "Requires %d Sugar" % data.sugar_cost
	return ""

func build(data: StructureData, cell: Vector2i, player_id: int) -> bool:
	if not placement_error(data, cell, player_id).is_empty():
		return false
	var town := controlling_town(cell)
	game.get_player(player_id).sugars -= data.sugar_cost
	var structure := Structure.new()
	if data.behavior_script != null:
		structure.set_script(data.behavior_script)
	structure.data = data
	structure.current_cell = cell
	structure.controlling_building_id = town.building_id
	structures[cell] = structure
	game.get_tree().current_scene.add_child(structure)
	structure.global_position = game.board_manager.cell_to_world(cell)
	# Preserve the resource underneath, but prevent harvesting it twice.
	var resource := game.get_resource(game.board_manager.get_resource_id_at_cell(cell))
	if resource != null:
		resource.hide()
	town.add_exp(data.construction_exp)
	game.update_ui()
	game.refresh_resource_collectibility_authoritative()
	return true

func can_use_dock(cell: Vector2i, player_id: int) -> bool:
	var structure: Structure = structures.get(cell)
	if structure == null or not structure.data.converts_to_boat:
		return false
	var town := controlling_town(cell)
	return town != null and town.owner_id == player_id

func income_for(town: Building) -> int:
	var income := 0
	for structure: Structure in structures.values():
		if structure.controlling_building_id == town.building_id:
			income += structure.data.sugar_per_round
	return income

func on_unit_arrived(unit: Unit) -> void:
	if not game.board_manager.water_cells.has(unit.current_cell):
		if unit.is_embarked:
			unit.disembark()
	var structure: Structure = structures.get(unit.current_cell)
	if structure != null:
		var town := controlling_town(unit.current_cell)
		if town != null and town.owner_id == unit.owner_id:
			structure.on_unit_entered(unit)
