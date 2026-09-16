class_name Resources
extends Area2D


# ============================================================
# DATA
# ============================================================

@export var data: ResourceData
var base_sprite: Texture2D

# ============================================================
# RUNTIME IDENTITY
# ============================================================

var resource_instance_id: int = -1

var current_cell: Vector2i


# ============================================================
# OWNERSHIP
# ============================================================

var owner_id: int = -1

# Which town controls this resource.
var controlling_building_id: int = -1


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	add_to_group("resources")


	if data == null:

		push_error(
			"ResourceData missing on: "
			+ name
		)

		return


	make_neutral()


# ============================================================
# NEUTRAL
# ============================================================

func make_neutral() -> void:

	owner_id = -1
	controlling_building_id = -1


	if sprite != null:
		sprite.texture = base_sprite


# ============================================================
# TERRITORY OWNERSHIP
# ============================================================

func set_controlling_building(
	building_id: int
) -> void:

	controlling_building_id = building_id


func set_player_owner(
	new_owner_id: int
) -> void:

	owner_id = new_owner_id
