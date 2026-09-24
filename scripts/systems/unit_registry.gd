class_name UnitRegistry
extends RefCounted


func spawn_unit(
	game: MatchManager,
	unit_scene: PackedScene,
	player: PlayerState,
	cell: Vector2i
) -> Unit:
	if unit_scene == null or player == null:
		return null
	if game.board_manager.get_unit_id_at_cell(cell) != -1:
		return null

	var unit: Unit = unit_scene.instantiate() as Unit
	if unit == null:
		return null

	game.get_tree().current_scene.add_child(unit)
	unit.setup_player(player)
	unit.global_position = game.board_manager.cell_to_world(cell)
	register_unit(game, unit)
	return unit


func register_unit(game: MatchManager, unit: Unit) -> void:
	if unit == null:
		return
	if unit.player_state == null:
		var player: PlayerState = game.get_player(unit.owner_id)
		if player == null:
			push_error("No PlayerState for unit owner: " + str(unit.owner_id))
			return
		unit.setup_player(player)

	unit.unit_id = game.next_unit_id
	game.next_unit_id += 1
	game.units[unit.unit_id] = unit
	game.board_manager.register_unit(unit)


func remove_unit(game: MatchManager, unit: Unit) -> void:
	if unit == null:
		return
	var removed_id: int = unit.unit_id
	game.board_manager.unregister_unit(unit)
	game.units.erase(removed_id)
	game.unit_removed.emit(removed_id)
	unit.queue_free()
