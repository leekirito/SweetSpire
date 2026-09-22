extends Control

var selected_building: Building

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var choice1: Button = $Panel/Button
@onready var choice2: Button = $Panel/Button2
@onready var choice3: Button = $Panel/Button3

@onready var board_manager: BoardManager = $"../BoardManager"
@onready var match_manager: MatchManager = $"../MatchManager"


var units: Dictionary[String, PackedScene]


## Builds a lookup from authored unit-scene names for the popup buttons.
func setup(building: Building) -> void:
	selected_building = building

	print(
		building.available_unit_types
	)

	for unit: PackedScene in building.available_unit_types:

		var unit_name := (
			unit.resource_path
			.get_file()
			.get_basename()
		)

		units[unit_name] = unit

		print(
			"Name ",
			unit_name
		)


func _ready() -> void:
	animation_player.play("open")

	choice1.pressed.connect(
		_on_button_pressed.bind(
			choice1.text
		)
	)

	choice2.pressed.connect(
		_on_button_pressed.bind(
			choice2.text
		)
	)

	choice3.pressed.connect(
		_on_button_pressed.bind(
			choice3.text
		)
	)


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
