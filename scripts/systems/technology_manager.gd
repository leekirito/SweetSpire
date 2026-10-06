class_name TechnologyManager
extends RefCounted

## Checks research prerequisites, active-turn ownership, and affordability.
## Purchases charge Sugar once and record the unlock on PlayerState.



## Checks the active seat, prerequisite, duplicate unlock, and available Sugar.
func can_purchase(game: MatchManager, player_id: int, technology: TechnologyData) -> bool:
	if game.current_phase != MatchManager.Phase.PLAYER_TURN or game.active_player_id != player_id:
		return false
	if technology == null:
		return false

	var player: PlayerState = game.get_player(player_id)
	if player == null or player.has_technology(technology.technology_id):
		return false
	if (
		technology.prerequisite_technology != null
		and not player.has_technology(technology.prerequisite_technology.technology_id)
	):
		return false
	return player.sugars >= technology.cost


## Charges Sugar and records the unlock, restoring the cost if unlocking fails.
func purchase(game: MatchManager, player_id: int, technology: TechnologyData) -> bool:
	if not can_purchase(game, player_id, technology):
		return false

	var player: PlayerState = game.get_player(player_id)
	player.sugars -= technology.cost
	if not player.unlock_technology(technology.technology_id):
		player.sugars += technology.cost
		return false
	return true
