extends Node

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	var board := BoardManager.new()
	board.tile_map_layer = TileMapLayer.new()
	board.tile_map_layer.tile_set = TileSet.new()
	board.add_child(board.tile_map_layer)
	board.astar_grid.region = Rect2i(0, 0, 7, 7)
	board.astar_grid.update()
	var player := PlayerState.new()
	var opponent := PlayerState.new()
	var unit := Unit.new()
	unit.player_state = player
	unit.current_cell = Vector2i(1, 3)
	unit.walk_exact_dimensions_override = Vector2i(7, 7)
	var mountain := Resources.new()
	mountain.data = preload("res://scripts/data/Resources/MountainData.tres")
	mountain.resource_instance_id = 1
	mountain.sprite = Sprite2D.new()
	mountain.collectible_outline = Sprite2D.new()
	mountain.add_child(mountain.sprite)
	mountain.add_child(mountain.collectible_outline)
	var peak := Vector2i(2, 3)
	var beyond := Vector2i(3, 3)
	mountain.global_position = board.cell_to_world(peak)
	board.register_resource(mountain)
	check(board.mountain_cells.has(peak), "Registered mountain is tracked")
	check(not board.can_move_to(unit, peak), "Land troop cannot enter a mountain without Climbing")
	check(peak not in board.get_movement_tiles(unit), "Mountain excluded from movement highlights")
	check(not board.can_move_to(unit, beyond), "Cannot cross a mountain to reach clear land")
	check(not board.has_clear_path(unit.current_cell, Vector2i(2, 4), unit), "Cannot cut a mountain corner")
	check(board.can_move_to(unit, Vector2i(1, 2)), "Ordinary land remains accessible")
	check(not board.is_cell_blocked(peak), "Mountain is not a universal obstacle")
	check(board.has_clear_path(unit.current_cell, beyond), "Attack line rules remain unchanged")
	opponent.unlock_technology("climbing")
	check(not board.can_move_to(unit, peak), "Another player's Climbing does not grant access")
	player.unlock_technology("climbing")
	check(board.can_move_to(unit, peak), "Existing troop gains mountain access immediately")
	check(peak in board.get_movement_tiles(unit), "Unlocked mountain appears in movement highlights")
	check(board.can_move_to(unit, beyond), "Climbing permits crossing mountains")
	board.occupied_cells[peak] = 99
	check(not board.can_move_to(unit, peak), "Climbing does not bypass occupied cells")
	board.occupied_cells.erase(peak)
	board.astar_grid.set_point_solid(peak, true)
	check(not board.can_move_to(unit, peak), "Climbing does not bypass solid obstacles")
	board.astar_grid.set_point_solid(peak, false)
	unit.can_traverse_land = false
	unit.can_traverse_water = true
	check(not board.can_move_to(unit, peak), "Naval-only units cannot enter mountain land")
	unit.can_traverse_land = true
	unit.is_embarked = true
	player.unlocked_technologies.clear()
	check(not board.can_move_to(unit, peak), "Boat cannot disembark onto mountain without Climbing")
	player.unlock_technology("climbing")
	check(board.can_move_to(unit, peak), "Boat can disembark onto mountain with Climbing")
	unit.is_embarked = false
	player.unlocked_technologies.clear()
	unit.ignores_terrain_blocking = true
	check(board.can_move_to(unit, peak), "Terrain-ignoring units keep their exemption")
	unit.ignores_terrain_blocking = false
	unit.player_state = null
	check(not board.can_move_to(unit, peak), "Missing owner cannot bypass Climbing")
	board.unregister_resource(mountain)
	check(not board.mountain_cells.has(peak), "Removing mountain clears restriction")
	check(board.can_move_to(unit, peak), "Former mountain tile becomes accessible")
	mountain.free()
	unit.free()
	player.free()
	opponent.free()
	board.free()
	print("Mountain movement regression: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
