extends Control

var selected_building: Building

@onready var choice1: Button = $Panel/Button
@onready var choice2: Button = $Panel/Button2
@onready var choice3: Button = $Panel/Button3
@onready var choices: Array[Button] = [choice1, choice2, choice3]

@onready var preview_panel: PanelContainer = $Panel/PreviewPanel
@onready var preview_name: Label = $Panel/PreviewPanel/Margin/VBox/UnitName
@onready var preview_type: Label = $Panel/PreviewPanel/Margin/VBox/UnitType
@onready var preview_stats: Label = $Panel/PreviewPanel/Margin/VBox/Stats
@onready var preview_cost: Label = $Panel/PreviewPanel/Margin/VBox/Cost

@onready var board_manager: BoardManager = $"../BoardManager"
@onready var match_manager: MatchManager = $"../MatchManager"


var units: Dictionary[String, PackedScene]


## Builds a lookup from authored unit-scene names for the popup buttons.
func setup(building: Building) -> void:
	selected_building = building
	units.clear()
	var owner: PlayerState = match_manager.get_player(building.owner_id)
	var available_units: Array[PackedScene] = []

	for unit_scene: PackedScene in building.available_unit_types:
		var candidate: Unit = unit_scene.instantiate() as Unit

		if candidate == null or candidate.data == null:
			if candidate != null:
				candidate.free()
			continue

		var technology_id: String = candidate.data.required_technology_id
		var is_unlocked := (
			owner != null
			and owner.has_technology(technology_id)
		)
		candidate.free()

		if is_unlocked:
			available_units.append(unit_scene)

	for index: int in range(choices.size()):
		var choice: Button = choices[index]

		if index >= available_units.size():
			choice.hide()
			continue

		var unit: PackedScene = available_units[index]

		var unit_name := (
			unit.resource_path
			.get_file()
			.get_basename()
		)

		units[unit_name] = unit
		_configure_choice(choice, unit_name, unit)

	_animate_visible_choices()


func _ready() -> void:
	preview_panel.hide()

	for choice: Button in choices:
		choice.pressed.connect(_on_choice_pressed.bind(choice))
		choice.mouse_entered.connect(_on_choice_hovered.bind(choice))
		choice.mouse_exited.connect(_on_choice_unhovered.bind(choice))
		choice.focus_entered.connect(_on_choice_hovered.bind(choice))
		choice.focus_exited.connect(_on_choice_unhovered.bind(choice))


## Opens only the unlocked choices and sends each one directly to its final slot.
func _animate_visible_choices() -> void:
	var visible_choices: Array[Button] = []
	for choice: Button in choices:
		if choice.visible:
			visible_choices.append(choice)

	var target_positions: Array[Vector2] = []
	match visible_choices.size():
		1:
			target_positions = [Vector2(-84.5, -225.0)]
		2:
			target_positions = [
				Vector2(-205.0, -190.0),
				Vector2(36.0, -190.0)
			]
		3:
			target_positions = [
				Vector2(-283.0, -142.0),
				Vector2(-87.0, -250.0),
				Vector2(120.0, -142.0)
			]

	for index: int in range(visible_choices.size()):
		var choice: Button = visible_choices[index]
		choice.position = Vector2(-84.5, -81.5)
		choice.scale = Vector2(0.025, 0.025)

		var tween := choice.create_tween()
		tween.set_parallel(true)
		tween.tween_property(
			choice,
			"position",
			target_positions[index],
			0.42
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			choice,
			"scale",
			Vector2.ONE,
			0.42
		).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fills a recruit medallion from the scene's UnitData resource.
func _configure_choice(
	choice: Button,
	unit_key: String,
	unit_scene: PackedScene
) -> void:
	var unit: Unit = unit_scene.instantiate() as Unit

	if unit == null or unit.data == null:
		choice.hide()
		if unit != null:
			unit.free()
		return

	var unit_data: UnitData = unit.data
	choice.set_meta("unit_key", unit_key)
	choice.set_meta("unit_data", unit_data)
	choice.tooltip_text = unit_data.unit_name + " : " + str(unit_data.cost) + " sugar"
	choice.text = ""

	var portrait: TextureRect = choice.get_node("Portrait")
	var price: Label = choice.get_node("PriceBadge/Price")
	var tribe_name := ""
	var owner: PlayerState = match_manager.get_player(selected_building.owner_id)

	if owner != null and owner.tribe != null:
		tribe_name = owner.tribe.tribe_name

	if unit_data.character_texture.has(tribe_name):
		portrait.texture = unit_data.character_texture[tribe_name]
	elif not unit_data.character_texture.is_empty():
		portrait.texture = unit_data.character_texture.values()[0]

	price.text = str(unit_data.cost) + " S"
	unit.free()


func _on_choice_pressed(choice: Button) -> void:
	if not choice.has_meta("unit_key"):
		return

	_on_button_pressed(str(choice.get_meta("unit_key")))


## Shows the hovered unit's live gameplay values in the preview card.
func _on_choice_hovered(choice: Button) -> void:
	if not choice.has_meta("unit_data"):
		return

	var unit_data: UnitData = choice.get_meta("unit_data") as UnitData

	if unit_data == null:
		return

	preview_name.text = unit_data.unit_name.to_upper()
	preview_type.text = unit_data.type
	preview_stats.text = (
		"HEALTH  %d     ATTACK  %d\nDEFENCE  %d     MOVE  %d\nRANGE  %d"
		% [
			unit_data.health,
			unit_data.attack_damage,
			unit_data.defence,
			unit_data.walk_range,
			unit_data.attack_range
		]
	)
	preview_cost.text = "RECRUIT FOR  %d  SUGAR" % unit_data.cost
	preview_panel.show()
	preview_panel.modulate.a = 0.0
	preview_panel.scale = Vector2(0.97, 0.97)

	var tween := preview_panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(preview_panel, "modulate:a", 1.0, 0.12)
	tween.tween_property(
		preview_panel,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_choice_unhovered(choice: Button) -> void:
	if choice.is_hovered() or choice.has_focus():
		return

	preview_panel.hide()


func _unhandled_input(
	event: InputEvent
) -> void:

	if (
		event is InputEventMouseButton
		and event.is_pressed()
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		queue_free()


## Sends the purchase request to MatchManager and closes only after success.
func _on_button_pressed(
	unit_name: String
) -> void:

	if selected_building == null:
		return

	if not units.has(unit_name):
		return


	var purchased_unit: Unit = (
		match_manager.request_recruit_unit(
			selected_building.building_id,
			units[unit_name]
		)
	)


	if purchased_unit == null:
		print(
			"Could not purchase ",
			unit_name
		)

		return


	print(
		"Purchased ",
		unit_name
	)


	queue_free()
