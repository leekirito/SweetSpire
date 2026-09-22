extends AIBaseState


func enter() -> void:
	try_end_turn()


func update(_delta: float) -> void:
	try_end_turn()


## Retries until MatchManager confirms no movement animation is still active.
func try_end_turn() -> void:
	var ai: AIController = get_ai()


	if (
		ai.match_manager.active_player_id
		!= ai.controlled_player_id
	):
		transition.emit(
			&"Idle"
		)

		return


	var ended: bool = (
		ai.match_manager.request_end_turn()
	)


	if ended:
		transition.emit(
			&"Idle"
		)
