class_name PlayerState
extends Node

var player_id: int
var player_name: String = ""
var tribe: TribeData
var sugars: int = 0
var unlocked_technologies: Array[TechnologyData] = []
var score: int = 0


func has_technology(id: String)-> bool:
	for technology: TechnologyData in unlocked_technologies:
		if technology.technology_id == id:
			return true
	return false
	
