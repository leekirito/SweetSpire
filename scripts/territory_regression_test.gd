extends Node

var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _ready() -> void:
	var board := BoardManager.new()
	board.tile_map_layer = TileMapLayer.new()
	board.add_child(board.tile_map_layer)
	board.tile_map_layer.tile_set = preload("res://assets/tilesets/Dungeon.tres")
	for x in range(9):
		for y in range(9):
			board.tile_map_layer.set_cell(Vector2i(x, y), 39, Vector2i.ZERO)
	board._setup_grid()
	var territories := TerritoryManager.new()
	territories.board_manager = board
	var early := Building.new()
	early.building_id = 20
	early.current_cell = Vector2i(3, 3)
	var late := Building.new()
	late.building_id = 10
	late.current_cell = Vector2i(5, 3)
	var resource := Resources.new()
	resource.current_cell = Vector2i(4, 3)
	var fresh := Resources.new()
	fresh.current_cell = Vector2i(6, 3)
	var resources: Array[Resources] = [resource, fresh]
	# Earlier registry order deliberately belongs to the town captured later.
	territories.rebuild_territories([late, early])
	territories.bind_resources_to_territories(resources)
	check(early.territory_cells.is_empty() and late.territory_cells.is_empty(), "Neutral towns have no territory")
	check(territories.cell_to_building_id.is_empty(), "Neutral towns reserve no cells")
	check(resource.controlling_building_id == -1 and resource.owner_id == -1, "Neutral towns claim no resources")
	early.owner_id = 1
	territories.update_resources_for_building(early, resources)
	check(early.territory_cells.size() == 9, "First captured town gains its full range")
	check(late.territory_cells.is_empty(), "Other neutral town still has no territory")
	check(resource.controlling_building_id == 20 and resource.owner_id == 1, "First captured town claims the overlapping resource")
	late.owner_id = 2
	territories.update_resources_for_building(late, resources)
	check(resource.current_cell in early.territory_cells and resource.current_cell in late.territory_cells, "Both town ranges include overlapping cells")
	check(late.territory_cells.size() == 9, "Later town range is not clipped")
	check(resource.controlling_building_id == 20 and resource.owner_id == 1, "Later capture cannot steal an existing resource")
	check(fresh.controlling_building_id == 10 and fresh.owner_id == 2, "Later town claims unclaimed resources")
	territories.rebuild_territories([late, early])
	territories.bind_resources_to_territories(resources)
	check(resource.controlling_building_id == 20, "Registry order cannot rewrite claim history")
	late.territory_radius = 3
	territories.rebuild_territories([late, early])
	territories.bind_resources_to_territories(resources)
	check(early.current_cell in late.territory_cells, "Expanded range can overlap another town")
	check(resource.controlling_building_id == 20, "Expansion cannot steal an already claimed resource")
	var added := Resources.new()
	added.current_cell = Vector2i(4, 4)
	territories.bind_resources_to_territories([added])
	check(added.controlling_building_id == 20, "New resource uses the first established claim")
	early.owner_id = 2
	territories.update_resources_for_building(early, resources)
	check(resource.controlling_building_id == 20 and resource.owner_id == 2, "Capturing the original town transfers its resource ownership")
	early.owner_id = -1
	territories.update_resources_for_building(early, resources)
	check(early.territory_cells.is_empty(), "Neutralized town loses its territory")
	check(resource.controlling_building_id == 10, "Neutralized town releases resources to an overlapping owned town")
	late.owner_id = -1
	territories.update_resources_for_building(late, resources)
	check(resource.controlling_building_id == -1 and fresh.owner_id == -1, "No owned town means resources are unclaimed")
	check(territories.cell_to_building_id.is_empty(), "All neutral towns leave no reserved cells")
	added.free()
	resource.free()
	fresh.free()
	early.free()
	late.free()
	territories.free()
	board.free()
	print("Territory regression: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
