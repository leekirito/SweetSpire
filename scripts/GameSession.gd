extends Node

var players: Array[PlayerState] = []


## Discards player state from a previous match before starting a new one.
func clear_players() -> void:
	for player: PlayerState in players:
		if is_instance_valid(player):
			player.queue_free()

	players.clear()


## Owns PlayerState nodes across scene changes through this autoload.
func add_player(player: PlayerState) -> void:
	add_child(player)
	players.append(player)
