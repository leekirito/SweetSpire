extends Node

var players: Array[PlayerState] = []


func clear_players() -> void:
	for player: PlayerState in players:
		if is_instance_valid(player):
			player.queue_free()

	players.clear()


func add_player(player: PlayerState) -> void:
	add_child(player)
	players.append(player)
