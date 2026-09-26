class_name DemoMap
extends RefCounted

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
		player.sugars = 5
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		session.add_player(player)

## Seeded scatter is repeatable and never overwrites authored map entities.
static func populate(game: MatchManager, seed_value: int) -> void:
	var board := game.board_manager
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var occupied: Dictionary[Vector2i, bool] = {}
	var town_cells: Array[Vector2i] = []
	for node: Node in game.get_tree().get_nodes_in_group("buildings"):
		var town := node as Building
		var cell := board.cell_from_world(town.global_position)
		town_cells.append(cell)
		occupied[cell] = true
	for node: Node in game.get_tree().get_nodes_in_group("resources"):
		occupied[board.cell_from_world((node as Node2D).global_position)] = true
	var cells := board.tile_map_layer.get_used_cells()
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temporary := cells[i]
		cells[i] = cells[j]
		cells[j] = temporary
	var added_towns := 0
	for cell: Vector2i in cells:
		if added_towns >= 4:
			break
		if occupied.has(cell) or board.water_cells.has(cell) or board.is_cell_blocked(cell):
			continue
		var near_town := false
		for other: Vector2i in town_cells:
			if maxi(absi(cell.x - other.x), absi(cell.y - other.y)) < 7:
				near_town = true
		if near_town:
			continue
		var town := preload("res://scenes/entities/buildings/neutral_building.tscn").instantiate() as Building
		game.get_tree().current_scene.add_child(town)
		town.global_position = board.cell_to_world(cell)
		town_cells.append(cell)
		occupied[cell] = true
		added_towns += 1
	# Guarantee at least one forest near every town where an empty land tile exists.
	for town_cell: Vector2i in town_cells:
		for cell: Vector2i in cells:
			if maxi(absi(cell.x - town_cell.x), absi(cell.y - town_cell.y)) > 1:
				continue
			if occupied.has(cell) or board.water_cells.has(cell) or board.is_cell_blocked(cell):
				continue
			_spawn_resource(game, "forest", cell)
			occupied[cell] = true
			break
	var count := 0
	var kinds := ["forest", "mountain", "fruit", "animal"]
	for cell: Vector2i in cells:
		if count >= 64:
			break
		if occupied.has(cell) or board.water_cells.has(cell) or board.is_cell_blocked(cell):
			continue
		_spawn_resource(game, kinds[count % kinds.size()], cell)
		occupied[cell] = true
		count += 1

static func _spawn_resource(game: MatchManager, kind: String, cell: Vector2i) -> void:
	var scene := load("res://scenes/entities/Resources/" + kind + ".tscn") as PackedScene
	var resource := scene.instantiate() as Resources
	game.get_tree().current_scene.add_child(resource)
	resource.global_position = game.board_manager.cell_to_world(cell)
