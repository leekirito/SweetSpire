class_name DemoMap
extends RefCounted

## Seeded fallback population for authored demo maps and default editor players.
## Manifest-driven chunk bootstrap normally replaces this population path in Main.


const BIOMES: Array[String] = ["SABA", "KAMOTE", "MALAGKIT", "SWEETSPIRE"]
const LAND_RESOURCE_KINDS: Array[String] = ["forest", "mountain", "fruit", "animal"]
const TOWNS_PER_BIOME := 3
const RESOURCES_PER_TOWN := 3
const LAND_RESOURCES_PER_BIOME := 20
const FISH_COUNT := 24

## Running Main directly in the editor should also produce a playable demo.
static func ensure_players(session: Node) -> void:
	if not session.players.is_empty():
		return
	var tribes := ["SABA", "KAMOTE"]
	for index in range(tribes.size()):
		var player := PlayerState.new()
		player.player_id = index + 1
		player.player_name = "Player %d" % player.player_id
		player.tribe = load("res://scripts/data/Tribe/%s.tres" % tribes[index])
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		session.add_player(player)

## Seeded generation balances towns and resources across the four land biomes.
static func populate(game: MatchManager, seed_value: int) -> void:
	var board := game.board_manager
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var occupied: Dictionary[Vector2i, bool] = {}
	var resource_kinds: Dictionary[Vector2i, String] = {}
	var town_cells: Array[Vector2i] = []
	for node: Node in game.get_tree().get_nodes_in_group("buildings"):
		var town := node as Building
		var cell := board.cell_from_world(town.global_position)
		town_cells.append(cell)
		occupied[cell] = true
	for node: Node in game.get_tree().get_nodes_in_group("resources"):
		var resource := node as Resources
		var cell := board.cell_from_world(resource.global_position)
		occupied[cell] = true
		resource_kinds[cell] = resource.data.resource_alias
	var cells := board.tile_map_layer.get_used_cells()
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary := cells[i]
		cells[i] = cells[j]
		cells[j] = temporary
	for biome: String in BIOMES:
		var count := 0
		for town_cell: Vector2i in town_cells:
			if board.get_biome_name(town_cell) == biome:
				count += 1
		while count < TOWNS_PER_BIOME:
			var selected := _find_town_cell(board, cells, biome, town_cells, occupied)
			if selected == Vector2i(-999999, -999999):
				push_warning("Could not place %d towns in %s" % [TOWNS_PER_BIOME, biome])
				break
			var town := preload("res://scenes/entities/buildings/neutral_building.tscn").instantiate() as Building
			game.get_tree().current_scene.add_child(town)
			town.global_position = board.cell_to_world(selected)
			town_cells.append(selected)
			occupied[selected] = true
			count += 1

	# Each town gets its own cluster inside its initial one-tile territory.
	for town_cell: Vector2i in town_cells:
		var nearby: Array[String] = []
		for resource_cell: Vector2i in resource_kinds:
			if _distance(resource_cell, town_cell) <= 1 and resource_kinds[resource_cell] != "fish":
				nearby.append(resource_kinds[resource_cell])
		if "forest" not in nearby:
			if _place_near_town(game, cells, town_cell, "forest", occupied, resource_kinds):
				nearby.append("forest")
		while nearby.size() < RESOURCES_PER_TOWN:
			var kind := "fruit" if nearby.size() % 2 == 1 else "animal"
			if not _place_near_town(game, cells, town_cell, kind, occupied, resource_kinds):
				break
			nearby.append(kind)

	# Scatter an equal minimum amount in every biome instead of consuming one global quota.
	for biome: String in BIOMES:
		var count := 0
		for resource_cell: Vector2i in resource_kinds:
			if board.get_biome_name(resource_cell) == biome:
				count += 1
		for cell: Vector2i in cells:
			if count >= LAND_RESOURCES_PER_BIOME:
				break
			if occupied.has(cell) or board.get_biome_name(cell) != biome or board.water_cells.has(cell) or board.is_cell_blocked(cell):
				continue
			var kind := LAND_RESOURCE_KINDS[count % LAND_RESOURCE_KINDS.size()]
			_spawn_resource(game, kind, cell)
			occupied[cell] = true
			resource_kinds[cell] = kind
			count += 1

	var fish_count := 0
	for cell: Vector2i in cells:
		if fish_count >= FISH_COUNT:
			break
		if occupied.has(cell) or not board.water_cells.has(cell) or board.is_ocean(cell):
			continue
		_spawn_resource(game, "fish", cell)
		occupied[cell] = true
		fish_count += 1


static func _find_town_cell(board: BoardManager, cells: Array[Vector2i], biome: String, towns: Array[Vector2i], occupied: Dictionary[Vector2i, bool]) -> Vector2i:
	for minimum_spacing: int in [5, 4, 3, 2]:
		var best := Vector2i(-999999, -999999)
		var best_score := -1
		for cell: Vector2i in cells:
			if occupied.has(cell) or board.get_biome_name(cell) != biome or board.water_cells.has(cell) or board.is_cell_blocked(cell):
				continue
			var nearest := 999999
			for town_cell: Vector2i in towns:
				nearest = mini(nearest, _distance(cell, town_cell))
			if nearest < minimum_spacing:
				continue
			var open_neighbors := _free_neighbor_count(board, cell, occupied)
			if open_neighbors < RESOURCES_PER_TOWN:
				continue
			var score := nearest * 10 + open_neighbors
			if score > best_score:
				best = cell
				best_score = score
		if best_score >= 0:
			return best
	return Vector2i(-999999, -999999)


static func _free_neighbor_count(board: BoardManager, center: Vector2i, occupied: Dictionary[Vector2i, bool]) -> int:
	var count := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cell := center + Vector2i(dx, dy)
			if board.is_cell_on_map(cell) and not occupied.has(cell) and not board.water_cells.has(cell) and not board.is_cell_blocked(cell):
				count += 1
	return count


static func _place_near_town(game: MatchManager, cells: Array[Vector2i], town_cell: Vector2i, kind: String, occupied: Dictionary[Vector2i, bool], resource_kinds: Dictionary[Vector2i, String]) -> bool:
	var board := game.board_manager
	for same_biome: bool in [true, false]:
		for cell: Vector2i in cells:
			if _distance(cell, town_cell) > 1 or occupied.has(cell) or board.water_cells.has(cell) or board.is_cell_blocked(cell):
				continue
			if same_biome and board.get_biome_name(cell) != board.get_biome_name(town_cell):
				continue
			_spawn_resource(game, kind, cell)
			occupied[cell] = true
			resource_kinds[cell] = kind
			return true
	return false


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

static func _spawn_resource(game: MatchManager, kind: String, cell: Vector2i) -> void:
	var scene := load("res://scenes/entities/Resources/" + kind + ".tscn") as PackedScene
	var resource := scene.instantiate() as Resources
	game.get_tree().current_scene.add_child(resource)
	resource.global_position = game.board_manager.cell_to_world(cell)
