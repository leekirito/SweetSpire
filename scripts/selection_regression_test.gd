extends Node2D
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _enter_tree() -> void:
	for id in [1, 2]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Test %d" % id
		player.tribe = load("res://scripts/data/Tribe/SABA.tres" if id == 1 else "res://scripts/data/Tribe/KAMOTE.tres")
		GameSession.add_player(player)

func _ready() -> void:
	get_tree().root.size = Vector2i(1152, 648)
	call_deferred("run")

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game: MatchManager = $MatchManager
	var board := game.board_manager
	var controller: PlayerController = $PlayerController
	game.fog_of_war = null
	for unit: Unit in game.units.values():
		board.unregister_unit(unit)
		unit.hide()
	for x in range(49, 56):
		for y in range(49, 56):
			board.tile_map_layer.set_cell(Vector2i(x, y), 39, Vector2i(4, 0))
	board._setup_grid()
	var fighter := preload("res://scenes/entities/player/Fighter.tscn")
	var first := game.spawn_unit(fighter, game.get_player(1), Vector2i(50, 50))
	var second := game.spawn_unit(fighter, game.get_player(1), Vector2i(53, 50))
	var enemy := game.spawn_unit(fighter, game.get_player(2), Vector2i(51, 51))
	controller._handle_board_click(first.global_position)
	controller._handle_board_click(board.cell_to_world(Vector2i(50, 51)))
	check(first.has_moved and controller.selected_unit_id == first.unit_id, "Movement keeps the unit selected for an attack")
	while first.is_animating:
		await get_tree().process_frame
	controller._handle_board_click(second.global_position)
	check(controller.selected_unit_id == second.unit_id, "One click switches from a moved unit to another ally")
	controller._handle_board_click(second.global_position)
	check(controller.selected_unit_id == -1, "Clicking the selected unit still deselects it")
	controller._handle_board_click(first.global_position)
	first.is_animating = true
	controller._handle_board_click(second.global_position)
	check(controller.selected_unit_id == first.unit_id, "Clicks during movement animation remain blocked")
	first.is_animating = false
	var town: Building
	for candidate: Building in game.buildings.values():
		if candidate.owner_id == 1:
			town = candidate
			break
	controller._handle_board_click(town.global_position)
	var popup := _recruitment_popup()
	check(popup != null and controller.selected_unit_id == -1, "One click opens a town after moving a unit")
	if popup != null:
		# Exercise real GUI hit testing outside the recruitment buttons.
		$Camera2D.position = second.global_position
		$Camera2D.zoom = Vector2.ONE
		$Camera2D.reset_smoothing()
		$Camera2D.force_update_scroll()
		await get_tree().process_frame
		await _click_world(second.global_position)
		check(controller.selected_unit_id == second.unit_id, "Recruitment backdrop lets a single map click select a unit")
		check(not is_instance_valid(popup), "Outside click dismisses the old recruitment popup")
	var resource: Resources = game.resources.values()[0]
	resource.set_controlling_building(town.building_id)
	resource.owner_id = 1
	controller.deselect_unit()
	controller._handle_board_click(first.global_position)
	controller._handle_board_click(resource.global_position)
	check(get_tree().get_first_node_in_group("resource_action_popup") != null, "One click opens a resource after moving a unit")
	for ui in get_tree().get_nodes_in_group("resource_action_popup"):
		ui.queue_free()
	await get_tree().process_frame
	# A guest must not submit an invalid move into an allied unit's occupied cell.
	first.has_moved = false
	controller._handle_board_click(first.global_position)
	LanSession.state = "playing"
	LanSession.game = game
	LanSession.local_player_id = 1
	LanSession.hosting = false
	var sequence := LanSession.next_command
	controller._handle_board_click(second.global_position)
	check(controller.selected_unit_id == second.unit_id, "LAN guest switches allies in one click before moving")
	check(not LanSession.pending_command and LanSession.next_command == sequence, "Selection does not submit a move to the host")
	LanSession.leave()
	controller._handle_board_click(first.global_position)
	controller._handle_board_click(enemy.global_position)
	check(first.has_attacked and controller.selected_unit_id == -1, "A valid enemy click still attacks instead of changing selection")
	print("SELECTION REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func _recruitment_popup() -> Control:
	for child in get_children():
		if child.get_script() == preload("res://scripts/recruitment_ui.gd"):
			return child
	return null

func _click_world(world: Vector2) -> void:
	var position_on_screen := get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = position_on_screen
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = position_on_screen
	click.global_position = position_on_screen
	click.pressed = true
	get_viewport().push_input(click, true)
	await get_tree().process_frame
	click = click.duplicate()
	click.pressed = false
	get_viewport().push_input(click, true)
	await get_tree().process_frame
