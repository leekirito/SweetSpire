extends CanvasLayer

## Displays bot activity while preserving the human perspective.
## Multiple-human Hotseat covers bot turns without pausing simulation.

@onready var game: MatchManager = get_parent()

func _ready() -> void:
	game.turn_started.connect(_refresh)
	game.match_ended.connect(func(_winner: int, _reason: String): hide())
	$Cover/Content/Leave.pressed.connect(_leave)

func _refresh(_seat: int, _round: int) -> void:
	var player := game.get_active_player()
	visible = player != null and player.is_bot() and game.current_phase == MatchManager.Phase.PLAYER_TURN
	var private_turn := GameSession.hotseat_mode and game.human_count() > 1
	$Cover.visible = private_turn
	$Status.visible = not private_turn
	if player != null:
		var text := "%s is taking their turn…" % player.player_name
		$Cover/Content/Message.text = text
		$Status.text = text
		NumericFontManager.manage_numeric_control($Cover/Content/Message)
		NumericFontManager.manage_numeric_control($Status)

func _leave() -> void:
	LanSession.leave()
	GameSession.clear_players()
	get_tree().change_scene_to_file("res://scenes/entities/UI/MainMenu.tscn")
