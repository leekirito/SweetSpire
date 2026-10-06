class_name BotMemory
extends RefCounted
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

func begin_round(value: int) -> void:
	if round_number == value:
		return
	round_number = value
	rejected.clear()

static func command_key(command: Dictionary) -> String:
	return JSON.stringify(command)
