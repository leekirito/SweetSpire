extends Node2D

var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func _enter_tree() -> void:
	var session := get_tree().root.get_node("GameSession")
	for id in [1, 2]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Test %d" % id
		player.tribe = load("res://scripts/data/Tribe/SABA.tres" if id == 1 else "res://scripts/data/Tribe/KAMOTE.tres")
		player.sugars = 100
		session.add_player(player)

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := self
	var game := scene.get_node("MatchManager") as MatchManager
	var board := game.board_manager
	var manager := game.structure_manager
	check(game.resources.size() >= 64, "Demo resources populated")
	check(game.buildings.size() > 7, "Demo neutral towns populated")
	var town: Building
	for candidate: Building in game.buildings.values():
		if candidate.owner_id == 1:
			town = candidate
	check(town != null, "Starting town exists")
	var player := game.get_player(1)
	var forest: Resources
	for candidate: Resources in game.resources.values():
		if candidate.controlling_building_id == town.building_id and candidate.data.resource_alias == "forest":
			forest = candidate
	check(forest != null, "Demo guarantees forest near starting town")
	if forest == null:
		get_tree().quit(1)
		return
	check(not manager.build(StructureManager.LUMBER, forest.current_cell, 1), "Forestry gates construction")
	player.unlock_technology("forestry")
	var before := player.sugars
	check(manager.build(StructureManager.LUMBER, forest.current_cell, 1), "Build lumber factory")
	check(player.sugars == before - 3, "Construction costs exactly 3 Sugar")
	check(town.current_exp == 1, "Construction grants 1 town EXP")
	check(manager.income_for(town) == 1, "Structure adds 1 round income")
	check(not manager.build(StructureManager.LUMBER, forest.current_cell, 1), "Duplicate build rejected")
	check(not game.request_collect_resource(forest.resource_instance_id, 1), "Built forest cannot also be collected")
	var expected := 0
	for owned: Building in game.buildings.values():
		if owned.owner_id == 1:
			expected += owned.by_turn_sugar + manager.income_for(owned)
	before = player.sugars
	game.collect_sugars()
	check(player.sugars == before + expected, "Round payout includes structures exactly once")
	# Isolated coastal strip added to the actual board, preserving the authored map.
	var shore := Vector2i(40, 40)
	var dock := Vector2i(41, 40)
	var lake := Vector2i(42, 40)
	var landing := Vector2i(43, 40)
	var ocean := Vector2i(41, 41)
	for cell: Vector2i in [shore, landing]:
		board.tile_map_layer.set_cell(cell, 39, Vector2i(4, 0))
	for cell: Vector2i in [dock, lake]:
		board.tile_map_layer.set_cell(cell, 6, Vector2i.ZERO)
	board.tile_map_layer.set_cell(ocean, 5, Vector2i.ZERO)
	board.astar_grid.region = board.tile_map_layer.get_used_rect()
	board.astar_grid.update()
	board._refresh_solid_cells()
	for cell: Vector2i in [dock, lake, ocean]:
		game.territory_manager.cell_to_building_id[cell] = town.building_id
	check(not manager.build(StructureManager.DOCK, dock, 1), "Sailing gates construction")
	player.unlock_technology("sailing")
	check(not manager.build(StructureManager.DOCK, ocean, 1), "Ocean construction rejected")
	check(not manager.build(StructureManager.DOCK, shore, 1), "Ground dock rejected")
	check(not manager.build(StructureManager.DOCK, dock, 2), "Other player cannot build")
	before = player.sugars
	player.sugars = 2
	check(not manager.build(StructureManager.DOCK, dock, 1), "Insufficient funds rejected")
	player.sugars = before
	check(manager.build(StructureManager.DOCK, dock, 1), "Build shore dock")
	var unit: Unit = game.units.values()[0]
	unit.owner_id = 1
	board.unregister_unit(unit)
	unit.global_position = board.cell_to_world(shore)
	board.register_unit(unit)
	unit.unit_health = 2
	unit.defence = 1
	unit.unit_damage = 7
	var original_pattern := unit.movement_pattern
	var original_range := unit.unit_walk_range
	check(board.can_move_to(unit, dock), "Land unit can enter friendly dock")
	check(board.is_cell_blocked_for_unit(lake, unit), "Land unit cannot enter ordinary water")
	unit.pixels_per_second = 100000
	check(game.request_move(unit.unit_id, dock), "Authoritative embark move")
	if unit.is_animating:
		await board.move_finished
	check(unit.is_embarked, "Dock transforms unit")
	check(unit.unit_health == 2 and unit.defence == 1 and unit.unit_damage == 7, "Stats preserved on embark")
	check(unit.movement_pattern == StructureManager.DOCK.boat_movement_pattern and unit.attack_range == 1, "Boat patterns applied")
	check(board.can_move_to(unit, landing), "Boat can land across water on ordinary shore")
	unit.has_moved = false
	check(game.request_move(unit.unit_id, landing), "Authoritative landing move")
	if unit.is_animating:
		await board.move_finished
	check(not unit.is_embarked and unit.movement_pattern == original_pattern and unit.unit_walk_range == original_range, "Landing restores original movement")
	check(unit.unit_health == 2 and unit.unit_damage == 7, "Landing does not heal or change attack strength")
	town.set_player_owner(2)
	check(not manager.can_use_dock(dock, 1) and manager.can_use_dock(dock, 2), "Dock follows captured town owner")
	check(manager.income_for(town) == 2, "Captured town retains both structure incomes")
	# Collect a fresh forest: sugar only, no EXP.
	town.set_player_owner(1)
	var extra := preload("res://scenes/entities/Resources/forest.tscn").instantiate() as Resources
	scene.add_child(extra)
	extra.global_position = board.cell_to_world(shore)
	game.register_resource(extra)
	extra.set_player_owner(1)
	extra.set_controlling_building(town.building_id)
	before = player.sugars
	var exp_before := town.current_exp
	check(game.request_collect_resource(extra.resource_instance_id, 1), "Forest collection succeeds with Forestry")
	check(player.sugars == before + 1 and town.current_exp == exp_before, "Forest grants sugar without EXP")
	ResourceChoices.open_tile(game, dock)
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("resource_action_popup").size() == 1, "Structure info popup opens")
	print("Structure regression: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
