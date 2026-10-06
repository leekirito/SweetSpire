class_name PlayerState
extends Node

## Mutable state for one human or bot seat: tribe, currency, research, and score.
## Owned by GameSession. player_id identifies a seat, not an ENet peer.



var player_id: int
var player_name: String = ""
var controller_kind: String = "human"
var bot_profile_id: String = "balanced"

## Whether this seat is assigned to a bot controller.
func is_bot() -> bool:
	return controller_kind == "bot"

var tribe: TribeData

var sugars: int = 0
var score: int = 0
## Completed rounds spent controlling the Sweetspire center.
## Progress is cumulative and is not lost when control changes.
var center_control_rounds: int = 0

var unlocked_technologies: Array[String] = []


func _ready() -> void:
	# Starting technologies are assigned by the match setup.
	# Do not grant the full technology tree here: resource affordances
	# and collection authorization both depend on genuine unlock state.
	pass


## An empty requirement is satisfied; other IDs must be in the player's unlock list.
func has_technology(
	technology_id: String
) -> bool:

	if technology_id.is_empty():
		return true

	return technology_id in unlocked_technologies


## Adds a nonempty unlock once; false means empty or already owned.
func unlock_technology(technology_id: String) -> bool:
	if technology_id.is_empty() or has_technology(technology_id):
		return false

	unlocked_technologies.append(technology_id)
	return true
