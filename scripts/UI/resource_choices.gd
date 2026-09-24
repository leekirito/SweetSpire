class_name ResourceChoices
extends Control


@onready var collect: Button = (
	$HBoxContainer/Collect
)

@onready var upgrade: Button = (
	$HBoxContainer/Upgrade
)
@onready var backdrop: Panel = $Backdrop
@onready var title: Label = $Backdrop/Title
@onready var subtitle: Label = $Backdrop/Subtitle


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

	_apply_biome_theme(resource.biome_name)
	title.text = resource.data.resource_alias.to_upper()
	subtitle.text = (
		resource.biome_name + " BIOME  •  +"
		+ str(resource.data.exp) + " TOWN EXP"
	)


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
	collect.text = "COLLECT" if can_collect else "TECH REQUIRED"


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


## Colors the action card to echo the ground biome under the selected resource.
func _apply_biome_theme(biome: String) -> void:
	var tint := Color.WHITE

	match biome:
		"KAMOTE":
			tint = Color("ffe1c2")
		"MALAGKIT":
			tint = Color("fff4d1")
		"SWEETSPIRE":
			tint = Color("f3dcff")
		"SABA":
			tint = Color("dcf2c5")

	backdrop.modulate = tint


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
