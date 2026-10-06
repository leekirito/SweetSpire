extends AIBaseState

## Delegates attack and other non-movement commands to AIController's shared execution path.

## Retained state entry point; gameplay commands share one validated executor.
func update(_delta: float) -> void:
	get_ai().execute_choice()
