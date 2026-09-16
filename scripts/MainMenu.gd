extends CanvasLayer

@export var saba_tribe: TribeData
@export var malagkit_tribe: TribeData
@export var kamote_tribe: TribeData

var selected_tribes: Dictionary[int, TribeData] = {}


func _ready() -> void:
	$Control/Button2.pressed.connect(
		select_tribe.bind(
			1,
			saba_tribe
		)
	)

	$Control/Button3.pressed.connect(
		select_tribe.bind(
			1,
			malagkit_tribe
		)
	)

	$Control/Button4.pressed.connect(
		select_tribe.bind(
			1,
			kamote_tribe
		)
	)

	$Control/Button5.pressed.connect(
		select_tribe.bind(
			2,
			saba_tribe
		)
	)

	$Control/Button6.pressed.connect(
		select_tribe.bind(
			2,
			malagkit_tribe
		)
	)

	$Control/Button7.pressed.connect(
		select_tribe.bind(
			2,
			kamote_tribe
		)
	)
	
	$Control/Button.pressed.connect(
		start_game
	)
func select_tribe(
	player_id: int,
	tribe: TribeData
) -> void:

	selected_tribes[player_id] = tribe

	print(
		"Player ",
		player_id,
		" selected ",
		tribe.tribe_name
	)
	
func start_game() -> void:
	if not selected_tribes.has(1):
		print("Player 1 has not selected a tribe.")
		return

	if not selected_tribes.has(2):
		print("Player 2 has not selected a tribe.")
		return

	GameSession.clear_players()

	var player_1 := PlayerState.new()
	player_1.player_id = 1
	player_1.player_name = "Player 1"
	player_1.tribe = selected_tribes[1]
	player_1.sugars = 5

	player_1.unlocked_technologies.append(
		player_1.tribe.starting_technology
	)

	GameSession.add_player(
		player_1
	)


	var player_2 := PlayerState.new()
	player_2.player_id = 2
	player_2.player_name = "Player 2"
	player_2.tribe = selected_tribes[2]
	player_2.sugars = 5

	player_2.unlocked_technologies.append(
		player_2.tribe.starting_technology
	)

	GameSession.add_player(
		player_2
	)


	get_tree().change_scene_to_file(
		"res://scenes/main/Main.tscn"
	)
