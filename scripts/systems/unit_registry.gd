class_name UnitRegistry
extends RefCounted

## Creates/removes units while keeping match IDs and board occupancy synchronized.
## Notifies visibility and selection listeners through MatchManager.



## Creates a unit for a player at a free cell; invalid input or occupancy returns null.
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


## Assigns a stable match ID, binds ownership, updates occupancy, and refreshes vision.
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
	game.vision_sources_changed.emit()


## Releases occupancy and registry entries before notifying listeners and freeing the node.
func remove_unit(game: MatchManager, unit: Unit) -> void:
	if unit == null:
		return
	var removed_id: int = unit.unit_id
	game.board_manager.unregister_unit(unit)
	game.units.erase(removed_id)
	unit.hide()
	game.vision_sources_changed.emit()
	game.unit_removed.emit(removed_id)
	unit.queue_free()
