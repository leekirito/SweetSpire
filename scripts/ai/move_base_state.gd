extends AIBaseState

## Delegates the chosen movement command to AIController, including waits and failure handling.

## Retained state entry point; gameplay commands share one validated executor.
func update(_delta: float) -> void:
	get_ai().execute_choice()
