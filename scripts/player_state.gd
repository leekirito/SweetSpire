class_name PlayerState
extends Node


var player_id: int
var player_name: String = ""
var tribe: TribeData

var sugars: int = 0
var score: int = 0

var unlocked_technologies: Array[String] = []


func _ready() -> void:
	unlocked_technologies = [
		"wilderness",
		"marksmanship",
		"forestry",
		"fishing",
		"sailing",
		"navigation",
		"pathfinding",
		"pathways",
		"expedition",
		"harvesting",
		"cultivation",
		"restoration",
		"climbing",
		"mining",
		"runecraft"
	]


func has_technology(
	technology_id: String
) -> bool:

	if technology_id.is_empty():
		return true

	return technology_id in unlocked_technologies
