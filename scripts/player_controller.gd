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
var is_aiming: bool = false
var preview_cell: Vector2i = Vector2i(-999999, -999999)


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
	if match_manager.current_phase != MatchManager.Phase.PLAYER_TURN:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and is_aiming:
		_cancel_aim()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and is_aiming:
		var hovered_cell := board_manager.cell_from_world(get_global_mouse_position())
		if hovered_cell != preview_cell:
			_update_blast_preview(hovered_cell)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_toggle_aim()
		return
	if not (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		return

	var mouse_position: Vector2 = (
		get_global_mouse_position()
	)
	if not match_manager.is_cell_visible_to_player(
		board_manager.cell_from_world(mouse_position), match_manager.active_player_id
	):
		return
	if is_aiming:
		_handle_aim_click(board_manager.cell_from_world(mouse_position))
		return

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
	var clicked_cell := board_manager.cell_from_world(mouse_position)
	if match_manager.structure_manager.structures.has(clicked_cell) or (
		board_manager.water_cells.has(clicked_cell)
		and board_manager.get_resource_id_at_cell(clicked_cell) == -1
	):
		ResourceChoices.open_tile(match_manager, clicked_cell)
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
	ResourceChoices.open_tile(match_manager, clicked_cell)

# SELECTED UNIT INPUT

func _toggle_aim() -> void:
	if is_aiming:
		_cancel_aim()
		return
	var unit: Unit = match_manager.get_unit(selected_unit_id)
	if unit == null or unit.owner_id != match_manager.active_player_id:
		return
	if not unit.has_area_attack() or unit.has_attacked or unit.is_animating:
		return
	is_aiming = true
	_show_aim_options(unit)


func _cancel_aim() -> void:
	is_aiming = false
	preview_cell = Vector2i(-999999, -999999)
	var unit: Unit = match_manager.get_unit(selected_unit_id)
	if unit != null:
		_show_unit_options(unit)
	else:
		deselect_unit()


func _show_aim_options(unit: Unit) -> void:
	clear_highlights()
	attack_tiles = match_manager.get_visible_attack_tiles(unit)
	preview_cell = Vector2i(-999999, -999999)
	_update_blast_preview(board_manager.cell_from_world(get_global_mouse_position()))


func _update_blast_preview(cell: Vector2i) -> void:
	preview_cell = cell
	board_manager.clear_overlay()
	for target_cell: Vector2i in attack_tiles:
		board_manager.highlight_attack_cell(target_cell)
	if cell not in attack_tiles:
		return
	var unit: Unit = match_manager.get_unit(selected_unit_id)
	if unit == null:
		return
	for blast_cell: Vector2i in board_manager.get_blast_cells(unit, cell, attack_tiles):
		board_manager.highlight_blast_cell(blast_cell)


func _handle_aim_click(cell: Vector2i) -> void:
	if cell not in attack_tiles:
		return
	if match_manager.request_attack_at_cell(selected_unit_id, cell):
		deselect_unit()

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
	if not unit.range_configuration_changed.is_connected(_on_unit_range_configuration_changed):
		unit.range_configuration_changed.connect(_on_unit_range_configuration_changed)

	_show_unit_options(
		unit
	)


func _on_unit_range_configuration_changed(unit: Unit) -> void:
	if unit == null or unit.unit_id != selected_unit_id:
		return
	if is_aiming:
		_show_aim_options(unit)
	else:
		_show_unit_options(unit)


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

	if not unit.has_attacked and not unit.has_area_attack():

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
		if not match_manager.is_cell_visible_to_player(tile, unit.owner_id):
			continue

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
	_final_cell: Vector2i,
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
	if unit.has_area_attack():
		_show_unit_options(unit)
	elif not unit.has_attacked:

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
	is_aiming = false
	preview_cell = Vector2i(-999999, -999999)
	
	
