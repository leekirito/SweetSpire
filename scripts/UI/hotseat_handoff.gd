extends CanvasLayer

## Pass-the-device cover between human Hotseat turns.
## Pauses gameplay until Continue, with a delay to ignore the previous End Turn click.


var game: MatchManager
@onready var player_label: Label = $Black/Margin/Content/Player
@onready var continue_button: Button = $Black/Margin/Content/Continue
var holding := false

func _ready() -> void:
	continue_button.pressed.connect(func() -> void: game.continue_hotseat_turn())

## Names the incoming human, pauses gameplay, and delays Continue to ignore the End Turn release.
func show_for_player(player: PlayerState, round_number: int) -> void:
	player_label.text = "%s\nPLAYER %d · ROUND %d" % [player.player_name, player.player_id, round_number]
	NumericFontManager.manage_numeric_control(player_label)
	holding = true
	continue_button.disabled = true
	show()
	get_tree().paused = true
	# Ignore the End Turn click/release and rapid double-clicks.
	await get_tree().create_timer(0.3, true).timeout
	if holding:
		continue_button.disabled = false
		continue_button.grab_focus()

## Releases the privacy cover and resumes the tree after the new turn starts.
func dismiss() -> void:
	holding = false
	continue_button.release_focus()
	hide()
	get_tree().paused = false

func _exit_tree() -> void:
	if holding:
		get_tree().paused = false
