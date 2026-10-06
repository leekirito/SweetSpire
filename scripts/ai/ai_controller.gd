class_name AIController
extends Node2D
@export var controlled_player_id: int = 1
@export var match_manager: MatchManager
@export var profile: BotProfile = preload("res://scripts/ai/profiles/balanced.tres")
@onready var state_machine: StateMachine = $AIStateMachine
var memory := BotMemory.new()
var observation: Dictionary = {}
var candidates: Array = []
var chosen: Dictionary = {}
var unit_index := 0
var actions_taken := 0
var failures := 0
var delay := 0.0
var started_round := -1

func _ready() -> void:
	profile = profile.validated_copy()
	memory.rng.seed = int(match_manager.map_manifest.get("seed", GameSession.map_seed)) * 31 + controlled_player_id * 7919
	match_manager.turn_started.connect(_on_turn_started)

func permitted() -> bool:
	return is_instance_valid(match_manager) and match_manager.bot_can_act(controlled_player_id)

func settled() -> bool:
	return permitted() and not match_manager.combat_resolver.attack_in_progress and not match_manager._any_unit_animating()

func _process(delta: float) -> void:
	if permitted():
		delay = maxf(0.0, delay - delta)

func _on_turn_started(player_id: int, round_number: int) -> void:
	if not permitted() or player_id != controlled_player_id or started_round == round_number:
		return
	started_round = round_number
	memory.begin_round(round_number)
	actions_taken = 0
	failures = 0
	delay = profile.turn_intro_delay
	observation.clear()
	candidates.clear()
	state_machine.on_state_transition(&"ChooseUnit")

func prepare_decision() -> void:
	observation.clear()
	candidates.clear()
	unit_index = 0

func plan_step() -> void:
	if not settled() or delay > 0.0:
		return
	if actions_taken >= profile.max_actions_per_turn or failures >= profile.max_failed_retries:
		state_machine.on_state_transition(&"EndTurn")
		return
	if observation.is_empty():
		observation = BotObservation.capture(match_manager, controlled_player_id, memory)
		candidates = BotActions.economy(observation, profile)
	var worked := 0
	while unit_index < observation.units.size() and worked < profile.work_per_frame:
		var unit: Dictionary = observation.units[unit_index]
		unit_index += 1
		if unit.owner == controlled_player_id:
			candidates.append_array(BotStrategy.unit_actions(observation, unit, profile, memory))
			worked += 1
	if unit_index < observation.units.size():
		return
	chosen = BotDecision.choose(candidates, profile, memory)
	state_machine.on_state_transition(&"EndTurn" if chosen.action == "end_turn" else (&"Move" if chosen.action == "move" else &"Attack"))

func execute_choice() -> void:
	if not settled() or delay > 0.0:
		return
	var previous := Vector2i.ZERO
	if chosen.action == "move":
		var unit := match_manager.get_unit(int(chosen.id))
		if unit != null:
			previous = unit.current_cell
	var accepted := match_manager.execute_bot_command(controlled_player_id, chosen)
	actions_taken += 1
	if accepted:
		if chosen.action == "move":
			memory.previous_cells[int(chosen.id)] = previous
	else:
		failures += 1
		memory.rejected[BotMemory.command_key(chosen)] = true
	delay = profile.action_delay
	state_machine.on_state_transition(&"ChooseUnit")

func try_end_turn() -> void:
	if not permitted():
		state_machine.on_state_transition(&"Idle")
	elif settled() and delay <= 0.0:
		if match_manager.execute_bot_command(controlled_player_id, {"action": "end_turn"}):
			state_machine.on_state_transition(&"Idle")
