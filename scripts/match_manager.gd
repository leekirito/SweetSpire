class_name MatchManager
extends Node


# ============================================================
# SIGNALS
# ============================================================

signal match_started

signal turn_started(
	player_id: int,
	round_number: int
)

signal unit_removed(
	unit_id: int
)


# ============================================================
# REFERENCES
# ============================================================

@onready var board_manager: BoardManager = (
	$"../BoardManager"
)

@onready var territory_manager: TerritoryManager = (
	$"../TerritoryManager"
)

@onready var player_turn: Label = (
	$"../CanvasLayer/Control/Player"
)

@onready var round_text: Label = (
	$"../CanvasLayer/Control/Round"
)


# ============================================================
# MATCH PHASE
# ============================================================

enum Phase {
	SETUP,
	PLAYER_TURN,
	RESOURCE_SCORE_UPDATE,
	ROUND_END,
	GAME_OVER
}


var current_phase: Phase = Phase.SETUP

var current_round: int = 1


# ============================================================
# PLAYERS
# ============================================================

var players: Array[PlayerState] = []

var active_player_index: int = 0
var active_player_id: int = -1


# ============================================================
# REGISTRIES
# ============================================================

var units: Dictionary[int, Unit] = {}
var buildings: Dictionary[int, Building] = {}

var next_unit_id: int = 1
var next_building_id: int = 1

var resources: Dictionary[int,Resources] = {}


var next_resource_instance_id: int = 1
# ============================================================
# START
# ============================================================

func _ready() -> void:

	call_deferred(
		"_initialize_match"
	)


func _initialize_match() -> void:

	# Get the PlayerStates created
	# by the Main Menu.

	players = GameSession.players


	if players.is_empty():

		push_error(
			"No players were created in GameSession."
		)

		return


	# Register every building already
	# placed on the map.
	#
	# They should all initially be neutral.

	_register_buildings()

	_register_resources()


	var all_buildings: Array[Building] = (
		_get_all_buildings()
	)


	var all_resources: Array[Resources] = (
		_get_all_resources()
	)


	# Calculate each town's territory.

	territory_manager.rebuild_territories(
		all_buildings
	)


	# Connect resources to the town
	# whose territory contains them.

	territory_manager.bind_resources_to_territories(
		all_resources
	)


	# Now assign player starting towns.

	var setup_successful: bool = (
		_setup_random_starting_bases()
	)


	if not setup_successful:
		return


	# Start with the first player.

	active_player_index = 0

	active_player_id = players[
		active_player_index
	].player_id


	current_phase = Phase.PLAYER_TURN


	update_ui()


	match_started.emit()


	turn_started.emit(
		active_player_id,
		current_round
	)


# ============================================================
# PLAYER LOOKUP
# ============================================================
func _register_resources() -> void:

	var nodes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"resources"
		)
	)


	for node: Node in nodes:

		if node is not Resources:
			continue


		var resource: Resources = (
			node as Resources
		)


		register_resource(
			resource
		)


func register_resource(
	resource: Resources
) -> void:

	if resource == null:
		return


	resource.resource_instance_id = (
		next_resource_instance_id
	)


	next_resource_instance_id += 1


	resources[
		resource.resource_instance_id
	] = resource


	board_manager.register_resource(
		resource
	)
	
func _get_all_buildings() -> Array[Building]:

	var result: Array[Building] = []


	for building: Building in buildings.values():

		result.append(
			building
		)


	return result


func _get_all_resources() -> Array[Resources]:

	var result: Array[Resources] = []


	for resource: Resources in resources.values():

		result.append(
			resource
		)


	return result
func get_player(
	player_id: int
) -> PlayerState:

	for player: PlayerState in players:

		if player.player_id == player_id:
			return player


	return null


func get_active_player() -> PlayerState:

	if players.is_empty():
		return null


	if (
		active_player_index < 0
		or active_player_index >= players.size()
	):
		return null


	return players[
		active_player_index
	]


# ============================================================
# STARTING BASES
# ============================================================

func _setup_random_starting_bases() -> bool:

	for player: PlayerState in players:

		if player.tribe == null:

			push_error(
				"Player "
				+ str(player.player_id)
				+ " has no tribe."
			)

			return false


		var candidates: Array[Building] = []


		# Find towns specifically allowed
		# for THIS player's tribe.

		for building: Building in buildings.values():

			# Already taken by another player.
			if building.owner_id != -1:
				continue


			if not building.can_be_starting_base_for(
				player.tribe
			):
				continue


			candidates.append(
				building
			)


		if candidates.is_empty():

			push_error(
				"No available starting town for tribe: "
				+ player.tribe.tribe_name
			)

			return false


		var starting_base: Building = (
			candidates.pick_random()
		)


		if not _assign_starting_base(
			player,
			starting_base
		):

			return false


	return true


func _assign_starting_base(
	player: PlayerState,
	starting_base: Building
) -> bool:

	if player == null:
		return false


	if starting_base == null:
		return false


	# Claim the town.
	#
	# This changes ONLY the town's own sprite.

	starting_base.conquer(
		player
	)


	# Resources controlled by this town
	# now belong to the same player.

	territory_manager.update_resources_for_building(
		starting_base,
		_get_all_resources()
	)


	# Redraw border using tribe color.

	territory_manager.queue_redraw()


	# Spawn starting troop.

	var starting_unit: Unit = (
		_spawn_starting_unit(
			player,
			starting_base
		)
	)


	if starting_unit == null:
		return false


	return true

func _spawn_starting_unit(
	player: PlayerState,
	starting_base: Building
) -> Unit:

	if player == null:
		return null


	if player.tribe == null:

		push_error(
			"Player has no tribe."
		)

		return null


	if player.tribe.starting_unit_scene == null:

		push_error(
			"Tribe "
			+ player.tribe.tribe_name
			+ " has no starting unit scene."
		)

		return null


	return spawn_unit(
		player.tribe.starting_unit_scene,
		player,
		starting_base.current_cell
	)


# ============================================================
# UNIT SPAWNING
# ============================================================

func spawn_unit(
	unit_scene: PackedScene,
	player: PlayerState,
	cell: Vector2i
) -> Unit:

	if unit_scene == null:

		push_error(
			"Unit scene is null."
		)

		return null


	if player == null:

		push_error(
			"PlayerState is null."
		)

		return null


	# Prevent two units occupying the same cell.

	if (
		board_manager.get_unit_id_at_cell(
			cell
		)
		!= -1
	):

		push_warning(
			"Cannot spawn unit. Cell is already occupied: "
			+ str(cell)
		)

		return null


	var unit: Unit = (
		unit_scene.instantiate()
		as Unit
	)


	if unit == null:

		push_error(
			"Unit scene root is not a Unit."
		)

		return null


	# Add to the game world.

	get_tree().current_scene.add_child(
		unit
	)


	# Give the unit its owning PlayerState.
	# This also handles owner_id and tribe visuals.

	unit.setup_player(
		player
	)


	# Place the unit exactly on the requested cell.

	unit.global_position = (
		board_manager.cell_to_world(
			cell
		)
	)


	# Register ID and board occupancy.

	register_new_unit(
		unit
	)


	return unit

func conquer_building(
	building_id: int,
	player_id: int
) -> bool:

	var building: Building = (
		get_building(
			building_id
		)
	)


	var player: PlayerState = (
		get_player(
			player_id
		)
	)


	if building == null:
		return false


	if player == null:
		return false


	# Change town owner + town appearance.

	building.conquer(
		player
	)


	# Every resource controlled by that town
	# changes owner too.

	territory_manager.update_resources_for_building(
		building,
		_get_all_resources()
	)


	return true
# ============================================================
# UNIT REGISTRATION
# ============================================================

func register_new_unit(
	unit: Unit
) -> void:

	if unit == null:
		return


	# This also lets your OLD recruitment UI
	# continue working for now.
	#
	# If the unit was manually given owner_id,
	# resolve its PlayerState automatically.

	if unit.player_state == null:

		var player: PlayerState = (
			get_player(
				unit.owner_id
			)
		)


		if player == null:

			push_error(
				"No PlayerState for unit owner: "
				+ str(unit.owner_id)
			)

			return


		unit.setup_player(
			player
		)


	unit.unit_id = next_unit_id

	next_unit_id += 1


	units[
		unit.unit_id
	] = unit


	board_manager.register_unit(
		unit
	)


# ============================================================
# BUILDING REGISTRATION
# ============================================================

func _register_buildings() -> void:

	var nodes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"buildings"
		)
	)


	for node: Node in nodes:

		if node is not Building:
			continue


		var building: Building = (
			node as Building
		)


		register_building(
			building
		)


func register_building(
	building: Building
) -> void:

	if building == null:
		return


	building.building_id = (
		next_building_id
	)

	next_building_id += 1


	buildings[
		building.building_id
	] = building


	board_manager.register_building(
		building
	)


	building.level_changed.connect(
		_on_building_level_changed
	)

func _on_building_level_changed(
	_building: Building
) -> void:

	var all_buildings: Array[Building] = (
		_get_all_buildings()
	)

	var all_resources: Array[Resources] = (
		_get_all_resources()
	)


	# Recalculate every town's territory.
	#
	# This is safer because a larger town
	# may now touch another town's territory.

	territory_manager.rebuild_territories(
		all_buildings
	)


	# Resources may now belong to a
	# different town.

	territory_manager.bind_resources_to_territories(
		all_resources
	)


	# Refresh visual borders.

	territory_manager.queue_redraw()
# ============================================================
# LOOKUP
# ============================================================

func get_unit(
	unit_id: int
) -> Unit:

	if not units.has(
		unit_id
	):
		return null


	return units[
		unit_id
	]


func get_building(
	building_id: int
) -> Building:

	if not buildings.has(
		building_id
	):
		return null


	return buildings[
		building_id
	]


# ============================================================
# MOVE REQUEST
# ============================================================

func request_move(
	unit_id: int,
	target_cell: Vector2i
) -> bool:

	if current_phase != Phase.PLAYER_TURN:
		return false


	var unit: Unit = get_unit(
		unit_id
	)


	if unit == null:
		return false


	if unit.owner_id != active_player_id:
		return false


	if unit.has_moved:
		return false


	if unit.is_animating:
		return false


	if not board_manager.can_move_to(
		unit,
		target_cell
	):
		return false


	var old_world_position: Vector2 = (
		unit.global_position
	)


	# Authoritative state update.

	unit.has_moved = true


	board_manager.commit_unit_move(
		unit,
		target_cell
	)


	# Visual animation.

	board_manager.animate_unit_move(
		unit,
		old_world_position,
		target_cell
	)


	return true


# ============================================================
# ATTACK REQUEST
# ============================================================

func request_attack(
	attacker_id: int,
	target_id: int
) -> bool:

	if current_phase != Phase.PLAYER_TURN:
		return false


	var attacker: Unit = get_unit(
		attacker_id
	)

	var target: Unit = get_unit(
		target_id
	)


	if attacker == null:
		return false


	if target == null:
		return false


	if attacker.owner_id != active_player_id:
		return false


	if target.owner_id == active_player_id:
		return false


	if attacker.has_attacked:
		return false


	if attacker.is_animating:
		return false


	if target.is_animating:
		return false


	var attack_tiles: Array[Vector2i] = (
		board_manager.get_attack_tiles(
			attacker
		)
	)


	if target.current_cell not in attack_tiles:
		return false


	# Authoritative combat.

	target.take_damage(
		attacker.get_attack_damage()
	)


	attacker.has_attacked = true
	attacker.has_moved = true


	if target.is_dead():

		_remove_unit(
			target
		)


	return true


# ============================================================
# REMOVE UNIT
# ============================================================

func _remove_unit(
	unit: Unit
) -> void:

	if unit == null:
		return


	var removed_id: int = (
		unit.unit_id
	)


	board_manager.unregister_unit(
		unit
	)


	units.erase(
		removed_id
	)


	unit_removed.emit(
		removed_id
	)


	unit.queue_free()


# TURN SYSTEM


func request_end_turn() -> bool:

	if current_phase != Phase.PLAYER_TURN:
		return false


	if _any_unit_animating():
		return false


	_end_turn()


	return true

func collect_sugars() -> void:

	for building: Building in buildings.values():

		# Neutral towns generate nothing for a player.
		if building.owner_id == -1:
			continue


		var player: PlayerState = get_player(
			building.owner_id
		)


		if player == null:
			push_warning(
				"No player found for building owner: "
				+ str(building.owner_id)
			)
			continue


		player.sugars += building.by_turn_sugar


		print(
			player.player_name,
			" received ",
			building.by_turn_sugar,
			" sugar from ",
			building.name
		)

func _end_turn() -> void:

	active_player_index += 1


	if active_player_index >= players.size():
		unit_conquer_building()
		active_player_index = 0

		current_round += 1
		collect_sugars()
		


	active_player_id = players[
		active_player_index
	].player_id


	_start_player_turn()


func _start_player_turn() -> void:

	current_phase = Phase.PLAYER_TURN


	_reset_player_units(
		active_player_id
	)


	update_ui()


	turn_started.emit(
		active_player_id,
		current_round
	)


func _reset_player_units(
	player_id: int
) -> void:

	for unit: Unit in units.values():

		if unit.owner_id != player_id:
			continue


		unit.has_moved = false
		unit.has_attacked = false


func _any_unit_animating() -> bool:

	for unit: Unit in units.values():

		if unit.is_animating:
			return true


	return false

# UI

func update_ui() -> void:

	player_turn.text = (
		"Player: "
		+ str(active_player_id)
	)


	round_text.text = (
		"Round "
		+ str(current_round)
	)


func _on_button_button_down() -> void:

	request_end_turn()


func unit_conquer_building():
	for tile in board_manager.occupied_cells:
		if board_manager.building_occupied_cells.has(tile):
			if get_building(board_manager.building_occupied_cells[tile]).owner_id != get_unit(board_manager.occupied_cells[tile]).owner_id:
				conquer_building(board_manager.building_occupied_cells[tile], get_unit(board_manager.occupied_cells[tile]).owner_id)
