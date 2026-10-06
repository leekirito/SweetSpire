extends AIBaseState
func update(_delta: float) -> void:
	get_ai().try_end_turn()
