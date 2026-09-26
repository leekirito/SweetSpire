class_name MatchManager
extends Node



signal match_started

signal turn_started(
	player_id: int,
	round_number: int
)

signal unit_removed(
	unit_id: int
)

signal technology_purchased(
	player_id: int,
	technology_id: String
)

signal player_eliminated(player_id: int)
signal match_ended(winner_id: int, victory_reason: String)

@export_category("Victory Conditions")
@export_range(1, 99, 1) var center_control_rounds: int = 3
## Exact board cell that represents the Sweetspire center.
@export var sweetspire_center_cell: Vector2i = Vector2i.ZERO
@onready var sugar_text: Label = $"../CanvasLayer/Control/Sugar"

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



enum Phase {
	SETUP,
	PLAYER_TURN,
	RESOURCE_SCORE_UPDATE,
	ROUND_END,
	GAME_OVER
}


var current_phase: Phase = Phase.SETUP

var current_round: int = 1



var players: Array[PlayerState] = []

var active_player_index: int = 0
var active_player_id: int = -1

var eliminated_player_ids: Dictionary[int, bool] = {}
var winner_id: int = -1




var units: Dictionary[int, Unit] = {}
var buildings: Dictionary[int, Building] = {}

var next_unit_id: int = 1
var next_building_id: int = 1

var resources: Dictionary[int,Resources] = {}


var next_resource_instance_id: int = 1

## Internal rule systems. MatchManager remains the sole authoritative façade.
var combat_resolver := CombatResolver.new()
var capture_manager := CaptureManager.new()
var economy_manager := EconomyManager.new()
var technology_manager := TechnologyManager.new()
var turn_manager := TurnManager.new()
var unit_registry := UnitRegistry.new()
var victory_manager := VictoryManager.new()
# ============================================================
# START
# ============================================================

func _ready() -> void:

	call_deferred(
		"_initialize_match"
	)


## Builds the authoritative runtime registries, assigns starting towns, and begins round one.
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

	_refresh_resource_collectibility()


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
	_refresh_resource_collectibility()


	match_started.emit()


	turn_started.emit(
		active_player_id,
		current_round
	)



## Discovers pre-placed resource nodes before ownership and territory are calculated.
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


## Internal-system accessors. State remains owned by this authoritative façade.
func get_all_resources_authoritative() -> Array[Resources]:
	return _get_all_resources()
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



## Assigns each player one unclaimed town allowed by their chosen tribe.
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



## Creates and registers a unit at a free board cell; all spawning should pass through here.
func spawn_unit(unit_scene: PackedScene, player: PlayerState, cell: Vector2i) -> Unit:
	return unit_registry.spawn_unit(self, unit_scene, player, cell)
func conquer_building(building_id: int, player_id: int) -> bool:
	return capture_manager.conquer_building(self, building_id, player_id)
func register_new_unit(unit: Unit) -> void:
	unit_registry.register_unit(self, unit)


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

## Rebuilds territory because a level change may alter several ownership boundaries.
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

	_refresh_resource_collectibility()

	# rebuild_territories already queues the updated fill and border redraw.

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


## Validates a player's move request before committing authoritative state and animation.
func request_move(unit_id: int, target_cell: Vector2i) -> bool:
	if current_phase != Phase.PLAYER_TURN:
		return false
	return combat_resolver.request_move(self, unit_id, target_cell)
func request_attack(attacker_id: int, target_id: int) -> bool:
	if current_phase != Phase.PLAYER_TURN:
		return false
	return combat_resolver.request_attack(self, attacker_id, target_id)


func remove_unit_authoritative(unit: Unit) -> void:
	unit_registry.remove_unit(self, unit)
func evaluate_eliminations() -> void:
	victory_manager.evaluate_eliminations(self)






func _evaluate_center_control() -> void:
	victory_manager.evaluate_center_control(self)






func get_center_controller() -> PlayerState:
	return victory_manager.get_center_controller(self)


func get_center_control_target() -> int:
	return center_control_rounds


func finish_match_authoritative(victor_id: int, victory_reason: String) -> void:
	if current_phase == Phase.GAME_OVER:
		return

	winner_id = victor_id
	current_phase = Phase.GAME_OVER
	active_player_id = -1
	_refresh_resource_collectibility()
	_show_match_result(victor_id, victory_reason)
	match_ended.emit(victor_id, victory_reason)


func _show_match_result(victor_id: int, victory_reason: String) -> void:
	var victor: PlayerState = get_player(victor_id)
	var victor_name: String = victor.player_name if victor != null else "PLAYER %d" % victor_id

	var result_layer := CanvasLayer.new()
	result_layer.name = "MatchResultLayer"
	result_layer.layer = 100
	get_tree().current_scene.add_child(result_layer)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.025, 0.04, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(backdrop)

	var result := Label.new()
	result.set_anchors_preset(Control.PRESET_CENTER)
	result.position = Vector2(-300.0, -90.0)
	result.size = Vector2(600.0, 180.0)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.text = "%s WINS!\n%s" % [victor_name.to_upper(), victory_reason]
	result.add_theme_font_size_override("font_size", 38)
	result.add_theme_color_override("font_color", Color("ffd166"))
	result.add_theme_color_override("font_outline_color", Color("351b12"))
	result.add_theme_constant_override("outline_size", 10)
	backdrop.add_child(result)


# TURN SYSTEM


## Rejects turn completion while unit animations could leave clients visually out of sync.
func request_end_turn() -> bool:
	return turn_manager.request_end_turn(self)
func request_upgrade_resource(resource_instance_id: int, player_id: int) -> bool:
	return economy_manager.request_upgrade_resource(self, resource_instance_id, player_id)
func collect_sugars() -> void:
	economy_manager.collect_sugars(self)
func request_collect_resource(resource_instance_id: int, player_id: int) -> bool:
	return economy_manager.request_collect_resource(self, resource_instance_id, player_id)
func _end_turn() -> void:
	turn_manager.end_turn(self)
func can_interact_with_resource(resource: Resources, player_id: int) -> bool:
	return economy_manager.can_interact_with_resource(self, resource, player_id)

func _start_player_turn() -> void:
	turn_manager.start_player_turn(self)
func get_resource(
	resource_instance_id: int
) -> Resources:

	if not resources.has(
		resource_instance_id
	):
		return null


	return resources[
		resource_instance_id
	]


## Keeps resource affordances synchronized with turn, ownership, and technology rules.
func _refresh_resource_collectibility() -> void:
	for resource: Resources in resources.values():
		if is_instance_valid(resource):
			resource.refresh_collectible_outline(self)


func refresh_resource_collectibility_authoritative() -> void:
	_refresh_resource_collectibility()
## Purchases and spawns a unit only from an owned, unoccupied town.
func request_recruit_unit(building_id: int, unit_scene: PackedScene) -> Unit:
	if current_phase != Phase.PLAYER_TURN:
		return null

	var unit: Unit = economy_manager.request_recruit_unit(self, building_id, unit_scene)
	if unit != null:
		update_ui()
	return unit
func can_purchase_technology(player_id: int, technology: TechnologyData) -> bool:
	return technology_manager.can_purchase(self, player_id, technology)


func request_purchase_technology(player_id: int, technology: TechnologyData) -> bool:
	if not technology_manager.purchase(self, player_id, technology):
		return false

	update_ui()
	_refresh_resource_collectibility()
	technology_purchased.emit(player_id, technology.technology_id)
	return true
func _reset_player_units(player_id: int) -> void:
	turn_manager.reset_player_units(self, player_id)


func _any_unit_animating() -> bool:
	return turn_manager.any_unit_animating(self)
func update_ui() -> void:
	var active_player: PlayerState = get_active_player()

	player_turn.text = (
		active_player.player_name.to_upper()
		if active_player != null
		else "PLAYER " + str(active_player_id)
	)

	round_text.text = (
		"Round "
		+ str(current_round)
	)

	if active_player != null:
		sugar_text.text = (
			str(active_player.sugars)
			+ "  SUGAR"
		)


func _on_button_button_down() -> void:

	request_end_turn()


## Captures towns occupied by enemy units when the round finishes.
func unit_conquer_building() -> void:
	capture_manager.capture_occupied_buildings(self)
