class_name Resources
extends Area2D


@export var data: ResourceData
@export var base_sprite: Texture2D

@export var resource_choices_scene: PackedScene


var resource_instance_id: int = -1

var current_cell: Vector2i

var owner_id: int = -1

var controlling_building_id: int = -1

var is_upgraded: bool = false


@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:

	add_to_group("resources")


	if data == null:

		push_error(
			"ResourceData missing on: "
			+ name
		)

		return


	make_neutral()


func make_neutral() -> void:

	owner_id = -1
	controlling_building_id = -1


	if sprite != null:
		sprite.texture = base_sprite


func set_controlling_building(
	building_id: int
) -> void:

	controlling_building_id = building_id


func set_player_owner(
	new_owner_id: int
) -> void:

	owner_id = new_owner_id


func collect_resource() -> void:

	queue_free()


## Marks the resource upgraded and applies its optional upgraded appearance.
func upgrade_resource() -> void:

	if is_upgraded:
		return


	is_upgraded = true


	if (
		sprite != null
		and data.upgrade_texture != null
	):
		sprite.texture = data.upgrade_texture


## Performs local eligibility checks before presenting actions; MatchManager revalidates requests.
func open_resource_choices(
	match_manager: MatchManager
) -> void:

	print("Clicked resource: ", name)
	print("Resource owner: ", owner_id)
	print("Active player: ", match_manager.active_player_id)
	print("Controlling building: ", controlling_building_id)
	if match_manager == null:
		return


	# Neutral resources cannot be controlled.
	if owner_id == -1:
		print("BLOCKED: Resource is neutral")
		return


	# Only the owning player may interact with it.
	if owner_id != match_manager.active_player_id:
		print("BLOCKED: Not resource owner's turn")
		return


	# Its controlling town must still belong
	# to the same player.
	var building: Building = (
		match_manager.get_building(
			controlling_building_id
		)
	)


	if building == null:
		return


	if building.owner_id != owner_id:
		return


	if resource_choices_scene == null:
		push_error(
			"No ResourceChoices scene assigned."
		)
		return


	var new_ui: ResourceChoices = (
		resource_choices_scene.instantiate()
		as ResourceChoices
	)
	var canvas_layer: CanvasLayer = (
	get_tree().current_scene.get_node(
		"CanvasLayer"
	)
	)


	canvas_layer.add_child(
	new_ui
	)



	new_ui.setup(
	self,
	match_manager
	)
