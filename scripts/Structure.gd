class_name Structure
extends Node2D

var data: StructureData
var current_cell: Vector2i
var controlling_building_id: int = -1

func _ready() -> void:
	var art := Sprite2D.new()
	art.texture = data.texture
	art.position.y = -55
	add_child(art)
	z_index = 2

func on_unit_entered(unit: Unit) -> void:
	if data.converts_to_boat and not unit.is_embarked:
		unit.embark(data)

func on_round_end(_game: MatchManager) -> void:
	pass
