class_name PlayerController
extends Node2D


# REFERENCES

@onready var match_manager: MatchManager = (
	$"../MatchManager"
)

@onready var board_manager: BoardManager = (
	$"../BoardManager"
)


# LOCAL SELECTION STATE

var selected_unit_id: int = -1

var attack_tiles: Array[Vector2i] = []


# SETUP

func _ready() -> void:
	board_manager.move_finished.connect(
		_on_move_finished
	)

	match_manager.turn_started.connect(
		_on_turn_started
	)

	match_manager.unit_removed.connect(
		_on_unit_removed
	)

# INPUT

## Routes a click by priority: selected-unit action, unit selection, town UI, then resource UI.
func _unhandled_input(event: InputEvent) -> void:
	if not (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		return

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)

	# A unit is already selected:
	# let it process movement / attack first.
	if selected_unit_id != -1:
		_handle_selected_unit_click(
			mouse_position
		)
		return


	# PRIORITY 1: UNIT

	var unit_id: int = (
		board_manager.get_unit_id_at_world(
			mouse_position
		)
	)

	if unit_id != -1:
		_try_select_unit(
			mouse_position
		)
		return


	# PRIORITY 2: BUILDING

	var building_id: int = (
		board_manager.get_building_id_at_world(
			mouse_position
		)
	)

	if building_id != -1:
		var building: Building = (
			match_manager.get_building(
				building_id
			)
		)

		if building != null and match_manager.active_player_id == building.owner_id:
			building.open_recruitment_ui()

		return
	var resource_id: int = (
	board_manager.get_resource_id_at_world(
		mouse_position
	)
	)
	print(
	"Clicked resource ID: ",
	resource_id
	)
	if resource_id != -1:

		var resource: Resources = (
			match_manager.get_resource(
				resource_id
			)
		)

		print(
			"Resource found: ",
			resource
		)

		if resource != null:

			resource.open_resource_choices(
				match_manager
			)

			return

# SELECTED UNIT INPUT

## Interprets a selected unit's next click as an attack, move, or deselection.
func _handle_selected_unit_click(
	mouse_position: Vector2
) -> void:

	var selected_unit: Unit = (
		match_manager.get_unit(
			selected_unit_id
		)
	)

	if selected_unit == null:
		deselect_unit()
		return

	if selected_unit.is_animating:
		return

	var clicked_unit_id: int = (
		board_manager.get_unit_id_at_world(
			mouse_position
		)
	)

	# ATTACK

	if clicked_unit_id != -1:

		var clicked_unit: Unit = (
			match_manager.get_unit(
				clicked_unit_id
			)
		)

		if (
			clicked_unit != null
			and clicked_unit.owner_id
				!= selected_unit.owner_id
			and clicked_unit.current_cell
				in attack_tiles
		):
			var attack_successful: bool = (
				match_manager.request_attack(
					selected_unit_id,
					clicked_unit_id
				)
			)

			if attack_successful:
				deselect_unit()

			return

	# MOVE

	if not selected_unit.has_moved:

		var target_cell: Vector2i = (
			board_manager.cell_from_world(
				mouse_position
			)
		)

		var move_successful: bool = (
			match_manager.request_move(
				selected_unit_id,
				target_cell
			)
		)

		if move_successful:

			# Keep the unit selected.
			# Attack targets are shown when
			# movement animation finishes.
			clear_highlights()

			return

	# INVALID CLICK

	deselect_unit()


# SELECT UNIT

## Selects only an actionable unit belonging to the active player.
func _try_select_unit(
	mouse_position: Vector2
) -> void:

	var unit_id: int = (
		board_manager.get_unit_id_at_world(
			mouse_position
		)
	)

	if unit_id == -1:
		return

	var unit: Unit = match_manager.get_unit(
		unit_id
	)

	if unit == null:
		return

	if unit.owner_id != match_manager.active_player_id:
		return

	if unit.is_animating:
		return

	if (
		unit.has_moved
		and unit.has_attacked
	):
		return

	selected_unit_id = unit_id

	_show_unit_options(
		unit
	)


# SHOW OPTIONS

func _show_unit_options(
	unit: Unit
) -> void:

	clear_highlights()


	# Movement

	if not unit.has_moved:

		board_manager.highlight_movement(
			unit
		)


	# Attack

	if not unit.has_attacked:

		_show_attack_options(
			unit
		)


## Highlights only attack cells that contain an enemy rather than every cell in range.
func _show_attack_options(
	unit: Unit
) -> void:

	attack_tiles = (
		board_manager.get_attack_tiles(
			unit
		)
	)

	for tile: Vector2i in attack_tiles:

		var target_id: int = (
			board_manager.get_unit_id_at_cell(
				tile
			)
		)

		if target_id == -1:
			continue

		var target: Unit = (
			match_manager.get_unit(
				target_id
			)
		)

		if target == null:
			continue

		if target.owner_id == unit.owner_id:
			continue

		board_manager.highlight_attack_cell(
			tile
		)


# MOVEMENT FINISHED

## Refreshes attack options after the unit reaches its authoritative destination.
func _on_move_finished(
	unit_id: int,
) -> void:

	if selected_unit_id != unit_id:
		return

	var unit: Unit = match_manager.get_unit(
		unit_id
	)

	if unit == null:
		deselect_unit()
		return

	clear_highlights()

	# Unit already moved, so now only show attack options.
	if not unit.has_attacked:

		_show_attack_options(
			unit
		)

# TURN CHANGED


func _on_turn_started(
	_player_id: int,
	_round_number: int
) -> void:

	deselect_unit()

# UNIT REMOVED

func _on_unit_removed(
	unit_id: int
) -> void:

	if selected_unit_id == unit_id:
		deselect_unit()

# SELECTION HELPERS

func clear_highlights() -> void:
	board_manager.clear_overlay()

	attack_tiles.clear()


func deselect_unit() -> void:
	clear_highlights()

	selected_unit_id = -1
	
	
