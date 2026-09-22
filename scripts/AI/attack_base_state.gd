extends AIBaseState


## Attacks the first enemy in range, or delegates to movement when no target is available.
func enter() -> void:
	var ai: AIController = get_ai()

	var unit: Unit = ai.selected_unit


	if unit == null:
		transition.emit(
			&"ChooseUnit"
		)
		return


	var enemy: Unit = find_enemy_in_range(
		ai,
		unit
	)


	if enemy != null:

		ai.target_unit = enemy

		var attacked: bool = (
			ai.match_manager.request_attack(
				unit.unit_id,
				enemy.unit_id
			)
		)

		if attacked:
			ai.mark_unit_processed(
				unit
			)

		transition.emit(
			&"ChooseUnit"
		)

		return


	# Unit already moved and still
	# cannot attack anything.
	if unit.has_moved:

		ai.mark_unit_processed(
			unit
		)

		transition.emit(
			&"ChooseUnit"
		)

		return


	# Nothing to attack yet.
	# Try moving.
	transition.emit(
		&"Move"
	)


## Returns a legal enemy target from MatchManager's authoritative unit registry.
func find_enemy_in_range(
	ai: AIController,
	unit: Unit
) -> Unit:

	var attack_cells: Array[Vector2i] = (
		ai.match_manager.board_manager.get_attack_tiles(
			unit
		)
	)


	for other: Unit in ai.match_manager.units.values():

		if other.owner_id == ai.controlled_player_id:
			continue

		if other.current_cell in attack_cells:
			return other


	return null
