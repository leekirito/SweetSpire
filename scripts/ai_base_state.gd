class_name AIBaseState
extends BaseState

## Base class for AI scene states, providing typed access to the owning AIController.



## Returns the state machine's owning bot controller.
func get_ai() -> AIController:
	return state_machine.get_parent() as AIController
