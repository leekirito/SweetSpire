class_name ResourceChoices
extends Control

## Context actions for a resource or construction cell.
## Shows eligibility and submits requests; shared rules revalidate execution.


var resource: Resources
var match_manager: MatchManager
var cell: Vector2i
@onready var actions: HBoxContainer = $Panel/Content/Actions
@onready var subtitle: Label = $Panel/Content/Subtitle

## Opens contextual construction information only inside the active player's territory.
static func open_tile(game: MatchManager, target: Vector2i) -> void:
	var town := game.structure_manager.controlling_town(target)
	if town == null or town.owner_id != game.active_player_id:
		return
	var ui := load("res://scenes/UI/resource_choices.tscn").instantiate() as ResourceChoices
	game.get_tree().current_scene.get_node("CanvasLayer").add_child(ui)
	ui.setup_tile(game, target)

func _ready() -> void:
	add_to_group("resource_action_popup")
	for old: Node in get_tree().get_nodes_in_group("resource_action_popup"):
		if old != self:
			old.queue_free()
	$Panel/Content/Close.pressed.connect(queue_free)

func setup(new_resource: Resources, game: MatchManager) -> void:
	resource = new_resource
	setup_tile(game, resource.current_cell)

## Binds the target cell and closes the popup on turn changes.
func setup_tile(game: MatchManager, target: Vector2i) -> void:
	match_manager = game
	cell = target
	game.turn_started.connect(func(_id: int, _round: int):
		hide()
		queue_free()
	)
	game.technology_purchased.connect(func(_id: int, _tech: String): _refresh())
	_refresh()

## Rebuilds available collection, upgrade, construction, or structure-information choices.
func _refresh() -> void:
	for child: Node in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var manager := match_manager.structure_manager
	var existing: Structure = manager.structures.get(cell)
	if existing != null:
		subtitle.text = "%s | +%d Sugar / round" % [existing.data.display_name, existing.data.sugar_per_round]
		var information := preload("res://scenes/UI/StructureInfo.tscn").instantiate()
		actions.add_child(information)
		information.get_node("Icon").texture = existing.data.texture
		information.get_node("Description").text = "Enter from adjacent land to become a boat.\nLand on any shore to return to your original unit." if existing.data.converts_to_boat else "Supplies Sugar to its controlling town each round."
		return
	var player := match_manager.get_active_player()
	if player == null:
		queue_free()
		return
	subtitle.text = "Choose an action"
	if is_instance_valid(resource):
		subtitle.text = resource.data.resource_alias.capitalize()
		if resource.data.can_collect:
			var reason := ""
			if not player.has_technology(resource.data.collect_technology_id):
				reason = "Requires " + resource.data.collect_technology_id.capitalize()
			elif not match_manager.can_interact_with_resource(resource, player.player_id):
				reason = "Unavailable"
			var reward := "+%d Sugar" % resource.data.collect_sugar if resource.data.collect_sugar > 0 else "+%d town EXP" % resource.data.experience_reward
			_add_action(resource.sprite.texture, "Collect\n" + reward, reason, _collect)
		if resource.data.can_upgrade and not resource.is_upgraded:
			var reason := "" if player.has_technology(resource.data.upgrade_technology_id) else "Requires " + resource.data.upgrade_technology_id.capitalize()
			_add_action(resource.data.upgrade_texture if resource.data.upgrade_texture != null else resource.sprite.texture, "Upgrade", reason, _upgrade)
		if resource.data.resource_alias == "forest":
			_add_build_action(StructureManager.LUMBER)
		elif resource.data.resource_alias == "mountain":
			_add_build_action(StructureManager.MINE)
		elif not resource.data.can_collect and not resource.data.can_upgrade:
			subtitle.text += " | No actions unlocked"
	elif match_manager.board_manager.water_cells.has(cell):
		_add_build_action(StructureManager.DOCK)
	else:
		_add_build_action(StructureManager.FARM)

func _add_build_action(data: StructureData) -> void:
	var reason := match_manager.structure_manager.placement_error(data, cell, match_manager.active_player_id)
	_add_action(data.texture, "%s\n%d Sugar | +%d EXP\n+%d Sugar / round" % [data.display_name, data.sugar_cost, data.construction_exp, data.sugar_per_round], reason, func():
		if match_manager.structure_manager.build(data, cell, match_manager.active_player_id):
			queue_free()
		else:
			_refresh())

func _add_action(icon: Texture2D, caption: String, reason: String, callback: Callable) -> void:
	var column := preload("res://scenes/UI/ResourceAction.tscn").instantiate()
	actions.add_child(column)
	var button: Button = column.get_node("Button")
	# Resource sprites include tall transparent canvas space for isometric placement.
	# Crop only the button's view so the actual collectible remains readable.
	if icon != null:
		var picture := icon.get_image()
		if picture != null:
			var cropped := AtlasTexture.new()
			cropped.atlas = icon
			cropped.region = picture.get_used_rect()
			button.icon = cropped
		else:
			button.icon = icon
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason if not reason.is_empty() else caption
	button.pressed.connect(callback)
	column.get_node("Caption").text = caption + ("\n" + reason if not reason.is_empty() else "")

func _collect() -> void:
	if is_instance_valid(resource) and match_manager.request_collect_resource(resource.resource_instance_id, resource.owner_id):
		queue_free()
	else:
		_refresh()

func _upgrade() -> void:
	if is_instance_valid(resource) and match_manager.request_upgrade_resource(resource.resource_instance_id, resource.owner_id):
		queue_free()
	else:
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		queue_free()
