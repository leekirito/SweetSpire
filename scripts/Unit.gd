class_name Unit
extends CharacterBody2D


@export var data: UnitData
@export var owner_id: int
@export var pixels_per_second: float = 300.0
var player_state: PlayerState
# Identity


var unit_id: int = -1


# Runtime Stats

var unit_walk_range: int = 1
var unit_name: String = ""
var unit_health: int = 1
var unit_damage: int = 1
var attack_range: int = 1
var defence: int = 0
var type: String = ""

# Turn State

var has_moved: bool = false
var has_attacked: bool = false
var is_animating: bool = false

# Board State

var current_cell: Vector2i
var target_cell: Vector2i


# Visuals

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("units")

	if data == null:
		push_error(
			"UnitData is not assigned to unit: " + name
		)
		return

	_load_data()


func _load_data() -> void:
	unit_walk_range = data.walk_range
	unit_name = data.unit_name
	unit_health = data.health
	unit_damage = data.attack_damage
	attack_range = data.attack_range
	defence = data.defence
	type = data.type
	
func setup_player(
	player: PlayerState
) -> void:

	player_state = player
	owner_id = player.player_id

	if sprite != null:
		sprite.texture = data.character_texture[
			player.tribe.tribe_name
		]


func take_damage(damage: int) -> void:
	var absorbed_damage: int = mini(
		defence,
		damage
	)

	defence -= absorbed_damage

	var remaining_damage: int = (
		damage - absorbed_damage
	)

	unit_health -= remaining_damage


func get_attack_damage() -> int:
	return unit_damage


func is_dead() -> bool:
	return unit_health <= 0
	
func is_under_a_town():
	pass
