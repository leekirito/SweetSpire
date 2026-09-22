class_name ResourceChoices
extends Control


@onready var collect: Button = (
	$HBoxContainer/Collect
)

@onready var upgrade: Button = (
	$HBoxContainer/Upgrade
)


var resource: Resources

var match_manager: MatchManager


func _ready() -> void:

	collect.pressed.connect(
		on_collect_pressed
	)

	upgrade.pressed.connect(
		on_upgrade_pressed
	)


## Reflects technology and upgrade eligibility; MatchManager remains the final authority.
func setup(
	new_resource: Resources,
	new_match_manager: MatchManager
) -> void:

	resource = new_resource

	match_manager = new_match_manager


	if resource == null:
		queue_free()
		return


	var player: PlayerState = (
		match_manager.get_player(
			resource.owner_id
		)
	)


	if player == null:
		queue_free()
		return


	# -----------------------------
	# COLLECT
	# -----------------------------

	var can_collect: bool = (
		player.has_technology(
			resource.data.collect_technology_id
		)
	)


	collect.disabled = not can_collect


	# -----------------------------
	# UPGRADE
	# -----------------------------

	var has_upgrade_technology: bool = (
		player.has_technology(
			resource.data.upgrade_technology_id
		)
	)


	upgrade.visible = (
		resource.data.can_upgrade
		and not resource.is_upgraded
		and has_upgrade_technology
	)


## Requests collection by stable resource and owner IDs rather than mutating the node directly.
func on_collect_pressed() -> void:

	if resource == null:
		return


	var success: bool = (
		match_manager.request_collect_resource(
			resource.resource_instance_id,
			resource.owner_id
		)
	)


	if success:
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.is_pressed()
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		queue_free()
## Requests an authoritative upgrade and closes after the request succeeds.
func on_upgrade_pressed() -> void:

	if resource == null:
		return


	var success: bool = (
		match_manager.request_upgrade_resource(
			resource.resource_instance_id,
			resource.owner_id
		)
	)


	if success:
		queue_free()
