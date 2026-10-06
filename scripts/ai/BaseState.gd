class_name BaseState
extends Node

## Enter, exit, and update contract for StateMachine children.
## Subclasses request transitions instead of replacing themselves during a callback.


signal transition(new_state_name: StringName)

@export var scene_resource: PackedScene

var state_machine: StateMachine

func _ready()-> void:
	pass

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass
