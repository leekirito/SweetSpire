extends AIBaseState


var waiting_for_movement: bool = false


## Chooses the legal move that most reduces distance to the nearest capturable town.
func enter() -> void:
	var ai: AIController = get_ai()
	var unit: Unit = ai.selected_unit

	print("=== MOVE ===")

	if unit == null:
		transition.emit(&"ChooseUnit")
		return


	var target_building: Building = find_nearest_target_building(
		ai,
		unit
	)


	if target_building == null:
		print("No building target found.")

		ai.mark_unit_processed(unit)
		transition.emit(&"ChooseUnit")
		return


	print(
		"Target building: ",
		target_building.building_id,
		" at ",
		target_building.current_cell
	)


	var movement_tiles: Array[Vector2i] = (
		ai.match_manager.board_manager.get_movement_tiles(
			unit
		)
	)


	if movement_tiles.is_empty():
		print("No valid movement tiles.")

		ai.mark_unit_processed(unit)
		transition.emit(&"ChooseUnit")
		return


	var best_cell: Vector2i = movement_tiles[0]
	var best_distance: float = INF


	for cell: Vector2i in movement_tiles:

		var distance: float = (
			Vector2(cell).distance_to(
				Vector2(target_building.current_cell)
			)
		)

		if distance < best_distance:
			best_distance = distance
			best_cell = cell


	print(
		"AI moving Unit ",
		unit.unit_id,
		" from ",
		unit.current_cell,
		" to ",
		best_cell
	)


	var moved: bool = (
		ai.match_manager.request_move(
			unit.unit_id,
			best_cell
		)
	)


	print("Move accepted: ", moved)


	if not moved:
		ai.mark_unit_processed(unit)
		transition.emit(&"ChooseUnit")
		return


	waiting_for_movement = true


## Waits for the movement tween before evaluating a follow-up attack.
func update(_delta: float) -> void:
	if not waiting_for_movement:
		return

	var ai: AIController = get_ai()
	var unit: Unit = ai.selected_unit

	if unit == null:
		waiting_for_movement = false
		transition.emit(&"ChooseUnit")
		return


	# Wait for BoardManager's tween.
	if unit.is_animating:
		return


	waiting_for_movement = false

	# After moving, see if an enemy is now attackable.
	transition.emit(&"Attack")


## Picks the closest neutral or enemy town as the AI's expansion target.
func find_nearest_target_building(
	ai: AIController,
	unit: Unit
) -> Building:

	var closest: Building = null
	var closest_distance: float = INF


	for building: Building in ai.match_manager.buildings.values():

		# Ignore our own towns.
		if building.owner_id == ai.controlled_player_id:
			continue


		var distance: float = (
			Vector2(unit.current_cell).distance_to(
				Vector2(building.current_cell)
			)
		)


		if distance < closest_distance:
			closest_distance = distance
			closest = building


	return closest
