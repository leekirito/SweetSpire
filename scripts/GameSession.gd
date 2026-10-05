extends Node

var players: Array[PlayerState] = []

## -1 chooses a fresh seed. Set a nonnegative value to reproduce a map.
var map_seed: int = -1
## Wire-safe authoritative setup, retained for replay and future host delivery.
var map_manifest: Dictionary = {}
## Future joining peers set this before opening Main; never generate locally.
var require_map_manifest: bool = false
## Local pass-the-device presentation; never enabled by network setup.
var hotseat_mode: bool = false


## Discards player state from a previous match before starting a new one.
func clear_players() -> void:
	map_manifest.clear()
	require_map_manifest = false
	hotseat_mode = false
	for player: PlayerState in players:
		if is_instance_valid(player):
			player.queue_free()

	players.clear()


## Owns PlayerState nodes across scene changes through this autoload.
func add_player(player: PlayerState) -> void:
	add_child(player)
	players.append(player)
