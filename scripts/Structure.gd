class_name Structure
extends Node2D

## A constructed improvement attached to a controlling town.
## Custom behavior scripts can extend the unit-entry and round-end hooks.


var data: StructureData
var current_cell: Vector2i
var controlling_building_id: int = -1
## Main visual sampled by fog memory; custom behaviors may provide their own sprite.
var sprite: Sprite2D

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = data.texture
	sprite.position.y = -55
	add_child(sprite)
	z_index = 2

## Default dock behavior: embark an arriving unit that is not already a boat.
func on_unit_entered(unit: Unit) -> void:
	if data.converts_to_boat and not unit.is_embarked:
		unit.embark(data)

## Extension hook called after round income; the base implementation has no extra effect.
func on_round_end(_game: MatchManager) -> void:
	pass
