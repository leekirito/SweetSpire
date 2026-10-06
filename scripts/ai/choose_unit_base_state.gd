extends AIBaseState
func enter() -> void:
	get_ai().prepare_decision()
func update(_delta: float) -> void:
	get_ai().plan_step()
