extends PanelContainer

## Only the local human's active turn gets a countdown. Bots and other LAN seats stay hidden.
@onready var game: MatchManager = get_tree().current_scene.get_node_or_null("MatchManager")
@onready var label: Label = $Time

func _ready() -> void:
	NumericFontManager.manage_numeric_control(label)
	refresh()

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	visible = (is_instance_valid(game) and game.turn_clock != null
		and game.current_phase in [MatchManager.Phase.PLAYER_TURN, MatchManager.Phase.TURN_TIMEOUT]
		and game.get_active_player() != null and not game.get_active_player().is_bot()
		and (not LanSession.active() or (LanSession.state == "playing" and game.active_player_id == LanSession.local_player_id)))
	if not visible:
		return
	var seconds := ceili(game.turn_clock.remaining)
	label.text = "YOUR TURN · %d:%02d" % [seconds / 60, seconds % 60]
	if LanSession.active() and LanSession.paused_for_disconnect:
		label.text += " · PAUSED"
	label.modulate = Color(1.0, 0.45, 0.35) if seconds <= 15 else Color.WHITE
