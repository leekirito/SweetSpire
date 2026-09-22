extends AIBaseState


## Selects the next idle friendly unit, ending the turn when none remain.
func enter() -> void:
	var ai: AIController = get_ai()

	ai.selected_unit = null

	for unit: Unit in ai.match_manager.units.values():

		if unit.owner_id != ai.controlled_player_id:
			continue

		if ai.is_unit_processed(unit):
			continue

		if unit.is_animating:
			continue

		ai.selected_unit = unit
		break


	if ai.selected_unit == null:
		transition.emit(
			&"EndTurn"
		)
		return


	transition.emit(
		&"Attack"
	)
