extends Control

var selected_building: Building
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var choice1: Button = $Panel/Button
@onready var choice2: Button = $Panel/Button2
@onready var choice3: Button = $Panel/Button3
@onready var board_manager: BoardManager = $"../BoardManager"
@onready var match_manager: MatchManager = $"../MatchManager"


var units: Dictionary[String, PackedScene]

var building_tile: Vector2i

func setup(building: Building) -> void:
	selected_building = building

	print(
		building.available_unit_types
	)
	building_tile = building.current_cell
	for unit in building.available_unit_types:
		var unit_name := unit.resource_path.get_file().get_basename()

		units[unit_name] = unit
		print("Name ", unit_name)
			

func _ready() -> void:
	animation_player.play("open")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index  == MOUSE_BUTTON_LEFT:
		queue_free()

func _on_button_pressed() -> void:

	var player: PlayerState = (
		match_manager.get_player(
			selected_building.owner_id
		)
	)


	if player == null:
		return


	match_manager.spawn_unit(
		units["Fighter"],
		player,
		building_tile
	)


	queue_free()



func _on_button_2_pressed() -> void:

	var player: PlayerState = (
		match_manager.get_player(
			selected_building.owner_id
		)
	)


	if player == null:
		return


	match_manager.spawn_unit(
		units["Ranger"],
		player,
		building_tile
	)


	queue_free()


func _on_button_3_pressed() -> void:

	var player: PlayerState = (
		match_manager.get_player(
			selected_building.owner_id
		)
	)


	if player == null:
		return


	match_manager.spawn_unit(
		units["Pathfinder"],
		player,
		building_tile
	)


	queue_free()

	
