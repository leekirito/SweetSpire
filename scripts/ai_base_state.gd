class_name AIBaseState
extends BaseState


func get_ai() -> AIController:
	return state_machine.get_parent() as AIController
