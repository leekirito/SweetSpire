class_name ResourceChoices
extends Control

var resource: Resources
var match_manager: MatchManager
var cell: Vector2i
var actions: HBoxContainer
var subtitle: Label

static func open_tile(game: MatchManager, target: Vector2i) -> void:
	var town := game.structure_manager.controlling_town(target)
	if town == null or town.owner_id != game.active_player_id:
		return
	var ui := ResourceChoices.new()
	game.get_tree().current_scene.get_node("CanvasLayer").add_child(ui)
	ui.setup_tile(game, target)

func _ready() -> void:
	add_to_group("resource_action_popup")
	for old: Node in get_tree().get_nodes_in_group("resource_action_popup"):
		if old != self:
			old.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3500
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-235, -330)
	panel.custom_minimum_size = Vector2(470, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172820")
	style.border_color = Color("b7cb8f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	subtitle = Label.new()
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	column.add_child(subtitle)
	actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 26)
	column.add_child(actions)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	column.add_child(close)

func setup(new_resource: Resources, game: MatchManager) -> void:
	resource = new_resource
	setup_tile(game, resource.current_cell)

func setup_tile(game: MatchManager, target: Vector2i) -> void:
	match_manager = game
	cell = target
	game.turn_started.connect(func(_id: int, _round: int): queue_free())
	game.technology_purchased.connect(func(_id: int, _tech: String): _refresh())
	_refresh()

func _refresh() -> void:
	for child: Node in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var manager := match_manager.structure_manager
	var existing: Structure = manager.structures.get(cell)
	if existing != null:
		subtitle.text = "%s | +%d Sugar / round" % [existing.data.display_name, existing.data.sugar_per_round]
		var information := VBoxContainer.new()
		actions.add_child(information)
		var icon := TextureRect.new()
		icon.texture = existing.data.texture
		icon.custom_minimum_size = Vector2(100, 76)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		information.add_child(icon)
		var description := Label.new()
		description.text = "Enter from adjacent land to become a boat.\nLand on any shore to return to your original unit." if existing.data.converts_to_boat else "Supplies Sugar to its controlling town each round."
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.add_theme_font_size_override("font_size", 13)
		information.add_child(description)
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
			var reward := "+%d Sugar" % resource.data.collect_sugar if resource.data.collect_sugar > 0 else "+%d town EXP" % resource.data.exp
			_add_action(resource.sprite.texture, "Collect\n" + reward, reason, _collect)
		if resource.data.can_upgrade and not resource.is_upgraded:
			var reason := "" if player.has_technology(resource.data.upgrade_technology_id) else "Requires " + resource.data.upgrade_technology_id.capitalize()
			_add_action(resource.data.upgrade_texture if resource.data.upgrade_texture != null else resource.sprite.texture, "Upgrade", reason, _upgrade)
		if resource.data.resource_alias == "forest":
			_add_build_action(StructureManager.LUMBER)
		elif not resource.data.can_collect and not resource.data.can_upgrade:
			subtitle.text += " | No actions unlocked"
	elif match_manager.board_manager.water_cells.has(cell):
		_add_build_action(StructureManager.DOCK)

func _add_build_action(data: StructureData) -> void:
	var reason := match_manager.structure_manager.placement_error(data, cell, match_manager.active_player_id)
	_add_action(data.texture, "%s\n%d Sugar | +%d EXP\n+%d Sugar / round" % [data.display_name, data.sugar_cost, data.construction_exp, data.sugar_per_round], reason, func():
		if match_manager.structure_manager.build(data, cell, match_manager.active_player_id):
			queue_free()
		else:
			_refresh())

func _add_action(icon: Texture2D, caption: String, reason: String, callback: Callable) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 175
	actions.add_child(column)
	var button := Button.new()
	button.custom_minimum_size = Vector2(76, 76)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.expand_icon = true
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
	button.add_theme_constant_override("icon_max_width", 54)
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason if not reason.is_empty() else caption
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("395943") if state != "disabled" else Color("303c35")
		if state == "hover":
			style.bg_color = Color("60865c")
		style.border_color = Color("e6d6a0") if state != "disabled" else Color("647565")
		style.set_border_width_all(2)
		style.set_corner_radius_all(38)
		style.content_margin_left = 10
		style.content_margin_right = 10
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	column.add_child(button)
	var label := Label.new()
	label.text = caption + ("\n" + reason if not reason.is_empty() else "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	column.add_child(label)

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
