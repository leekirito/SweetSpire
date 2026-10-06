class_name BotObservation
extends RefCounted

## Boundary between authoritative match state and a bot's permitted knowledge.
## Planners receive copied dictionaries rather than live game entities.

## Only this adapter can see authoritative state. Planners receive copied data.
static func capture(game: MatchManager, seat: int, memory: BotMemory) -> Dictionary:
	var board := game.board_manager
	var player := game.get_player(seat)
	game.fog_of_war.refresh(true)
	var visible: Dictionary = game.fog_of_war.visible_by_player.get(seat, {})
	for cell: Vector2i in visible:
		if not board.is_cell_on_map(cell):
			continue
		memory.tiles[cell] = {"water": board.water_cells.has(cell), "ocean": board.is_ocean(cell), "blocked": board.is_cell_blocked(cell), "mountain": board.mountain_cells.has(cell)}
	for town: Building in game.buildings.values():
		if town.owner_id == seat or visible.has(town.current_cell) or int(memory.towns.get(town.building_id, {}).get("owner", -1)) == seat:
			var available: Array = []
			for scene: PackedScene in town.available_unit_types:
				available.append(LanCatalog.unit_key(scene.resource_path))
			memory.towns[town.building_id] = {"id": town.building_id, "cell": town.current_cell, "owner": town.owner_id, "recruited": town.last_recruited_round, "units": available}
	for id in memory.resources.keys():
		if visible.has(memory.resources[id].cell) and not game.resources.has(id):
			memory.resources.erase(id)
	for resource: Resources in game.resources.values():
		if resource.owner_id == seat or visible.has(resource.current_cell) or int(memory.resources.get(resource.resource_instance_id, {}).get("owner", -1)) == seat:
			memory.resources[resource.resource_instance_id] = {"id": resource.resource_instance_id, "cell": resource.current_cell, "owner": resource.owner_id, "kind": resource.data.resource_alias, "collect": resource.data.can_collect, "upgrade": resource.data.can_upgrade and not resource.is_upgraded, "collect_tech": resource.data.collect_technology_id, "upgrade_tech": resource.data.upgrade_technology_id, "sugar": resource.data.collect_sugar, "exp": resource.data.experience_reward}
	for cell in memory.structures.keys():
		if visible.has(cell) and not game.structure_manager.structures.has(cell):
			memory.structures.erase(cell)
	for cell: Vector2i in game.structure_manager.structures:
		var structure: Structure = game.structure_manager.structures[cell]
		var town := game.structure_manager.controlling_town(cell)
		if visible.has(cell) or (town != null and town.owner_id == seat):
			memory.structures[cell] = {"key": structure.data.structure_id, "owner": town.owner_id if town != null else -1, "dock": structure.data.converts_to_boat}
	var units: Array = []
	for id in game.units.keys():
		var unit: Unit = game.units[id]
		if unit.owner_id != seat and not visible.has(unit.current_cell):
			continue
		var move_pattern: RangePattern = unit.movement_pattern if unit.movement_pattern != null else board.default_range_pattern
		var attack_pattern: RangePattern = unit.attack_pattern if unit.attack_pattern != null else board.default_range_pattern
		units.append({"id": unit.unit_id, "owner": unit.owner_id, "cell": unit.current_cell, "hp": unit.unit_health, "max_hp": unit.data.health, "shield": unit.defence, "damage": unit.get_attack_damage(), "moved": unit.has_moved, "attacked": unit.has_attacked, "boat": unit.is_embarked, "land": unit.can_traverse_land, "water": unit.can_traverse_water, "flying": unit.ignores_terrain_blocking, "move": move_pattern.get_offsets(unit.unit_walk_range, unit.walk_base_dimensions_override, unit.walk_exact_dimensions_override), "attack": attack_pattern.get_offsets(unit.attack_range, unit.attack_base_dimensions_override, unit.attack_exact_dimensions_override), "minimum": 0 if unit.is_embarked else unit.data.minimum_attack_distance, "area": unit.has_area_attack(), "blast": unit.data.blast_pattern.get_offsets(unit.data.blast_radius) if unit.has_area_attack() else [], "allies": unit.data.can_hit_allies})
	units.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	var territory: Dictionary = {}
	for cell: Vector2i in memory.tiles:
		# Own territory is player information; never include an opponent's unseen territory.
		var town := game.structure_manager.controlling_town(cell)
		if town != null and town.owner_id == seat:
			territory[cell] = town.building_id
	var towns: Array = memory.towns.values().duplicate(true)
	towns.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	var resources: Array = memory.resources.values().duplicate(true)
	resources.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	return {"seat": seat, "round": game.current_round, "sugar": player.sugars, "tech": player.unlocked_technologies.duplicate(), "tiles": memory.tiles.duplicate(true), "visible": visible.duplicate(), "towns": towns, "resources": resources, "structures": memory.structures.duplicate(true), "territory": territory, "units": units, "center": game.get_center_cells(), "center_rounds": player.center_control_rounds, "center_target": game.center_control_rounds}

## Checks the copied unlock list, treating empty requirements as satisfied.
static func has_tech(view: Dictionary, id: String) -> bool:
	return id.is_empty() or id in view.tech
