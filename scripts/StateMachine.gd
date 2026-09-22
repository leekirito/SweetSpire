class_name StateMachine
extends Node


@export var current_state: BaseState

var states: Dictionary = {}

var transition_queued: bool = false
var queued_state_name: StringName


## Registers child states, connects transitions, and starts the configured initial state.
func _ready() -> void:
	set_process(false)
	set_physics_process(false)

	for child in get_children():

		if child is BaseState:
			child.state_machine = self

			states[child.name] = child

			child.transition.connect(
				on_state_transition
			)

		else:
			push_warning(
				"State machine contains a non-state child node"
			)


	await owner.ready


	if current_state == null:
		push_error("No Initial State Set")
		return


	current_state.enter()

	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	if current_state == null:
		return

	current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state == null:
		return

	current_state.physics_update(delta)


## Defers transitions so a state cannot replace itself midway through its own callback.
func on_state_transition(
	new_state_name: StringName
) -> void:

	queued_state_name = new_state_name

	if transition_queued:
		return

	transition_queued = true

	call_deferred(
		"_apply_transition"
	)


## Exits the old state and enters the queued state once per frame.
func _apply_transition() -> void:
	transition_queued = false

	var new_state: BaseState = states.get(
		queued_state_name
	)


	if new_state == null:
		push_warning(
			"State does not exist: "
			+ str(queued_state_name)
		)
		return


	if new_state == current_state:
		return


	print(
		"AI STATE: ",
		current_state.name if current_state else "NONE",
		" -> ",
		new_state.name
	)


	if current_state != null:
		current_state.exit()


	current_state = new_state

	current_state.enter()
