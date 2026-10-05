extends Node

var players: Array[PlayerState] = []
const FOG_OF_WAR := "fog_of_war"
const REGULAR := "regular"
const MATCH_MODES := [FOG_OF_WAR, REGULAR]
var match_mode: String = FOG_OF_WAR:
	set(value):
		match_mode = value if value in MATCH_MODES else FOG_OF_WAR

## -1 chooses a fresh seed. Set a nonnegative value to reproduce a map.
var map_seed: int = -1
## Wire-safe authoritative setup, retained for replay and future host delivery.
var map_manifest: Dictionary = {}
## Manifest-driven local/replay setup; LAN guests use network_map instead.
var require_map_manifest: bool = false
## Local pass-the-device presentation; never enabled by network setup.
var hotseat_mode: bool = false
var network_map: Dictionary = {}


## Discards player state from a previous match before starting a new one.
func clear_players() -> void:
	match_mode = FOG_OF_WAR
	network_map.clear()
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
