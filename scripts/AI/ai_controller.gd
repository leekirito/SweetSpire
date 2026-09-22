class_name AIController
extends Node2D


@export var controlled_player_id: int = 1
@export var match_manager: MatchManager

@onready var state_machine: StateMachine = $AIStateMachine


var player_state: PlayerState

var selected_unit: Unit
var target_unit: Unit
var target_cell: Vector2i

var processed_unit_ids: Array[int] = []


func _ready() -> void:
	if match_manager == null:
		push_error("AI has no MatchManager assigned.")
		return

	print("AIController READY")
	print("AI will control player ID: ", controlled_player_id)

	match_manager.match_started.connect(
		_on_match_started
	)

	match_manager.turn_started.connect(
		_on_turn_started
	)


## Resolves the configured player only after MatchManager has built its registries.
func _on_match_started() -> void:
	player_state = match_manager.get_player(
		controlled_player_id
	)

	if player_state == null:
		push_error(
			"AI could not find player ID: "
			+ str(controlled_player_id)
		)
		return

	print(
		"AI successfully attached to: ",
		player_state.player_name,
		" ID: ",
		player_state.player_id
	)


## Resets per-turn AI memory and starts decision-making only on the controlled turn.
func _on_turn_started(
	player_id: int,
	round_number: int
) -> void:

	print(
		"Turn started: Player ",
		player_id,
		" | AI controls ",
		controlled_player_id
	)

	if player_id != controlled_player_id:
		return

	print("THIS IS THE AI'S TURN")

	processed_unit_ids.clear()

	selected_unit = null
	target_unit = null

	state_machine.on_state_transition(
		&"ChooseUnit"
	)


## Prevents the state machine from selecting the same unit twice in one turn.
func mark_unit_processed(unit: Unit) -> void:
	if unit == null:
		return

	if unit.unit_id not in processed_unit_ids:
		processed_unit_ids.append(unit.unit_id)


func is_unit_processed(unit: Unit) -> bool:
	if unit == null:
		return true

	return unit.unit_id in processed_unit_ids
