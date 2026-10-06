extends AIBaseState

## Waits until the bot can legally finish its turn, then returns to Idle.

func update(_delta: float) -> void:
	get_ai().try_end_turn()
