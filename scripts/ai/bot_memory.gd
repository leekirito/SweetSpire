class_name BotMemory
extends RefCounted

## Per-bot knowledge and decision history retained across turns.
## Stores known map/entities, commitments, previous moves, failed commands, and seeded RNG.

var tiles: Dictionary = {}
var towns: Dictionary = {}
var resources: Dictionary = {}
var structures: Dictionary = {}
var goals: Dictionary = {}
var previous_cells: Dictionary = {}
var rejected: Dictionary = {}
var round_number := -1
var cooldown := 0
var rng := RandomNumberGenerator.new()

## Clears rejected commands on a new round while retaining knowledge and goal history.
func begin_round(value: int) -> void:
	if round_number == value:
		return
	round_number = value
	rejected.clear()

## Serializes internally constructed commands for deduplication and failed-command tracking.
static func command_key(command: Dictionary) -> String:
	return JSON.stringify(command)
