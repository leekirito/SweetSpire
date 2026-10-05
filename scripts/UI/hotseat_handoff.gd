extends CanvasLayer

var game: MatchManager
var player_label: Label
var continue_button: Button
var holding := false

func _ready() -> void:
	name = "HotseatHandoff"
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(black)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	black.add_child(margin)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)
	var heading := Label.new()
	heading.text = "PASS TO THE NEXT PLAYER"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 24)
	content.add_child(heading)
	player_label = Label.new()
	player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_label.add_theme_font_size_override("font_size", 36)
	content.add_child(player_label)
	var hint := Label.new()
	hint.text = "Continue when you're ready to take your turn."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.custom_minimum_size = Vector2(260, 56)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(func() -> void: game.continue_hotseat_turn())
	content.add_child(continue_button)
	hide()

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

func dismiss() -> void:
	holding = false
	continue_button.release_focus()
	hide()
	get_tree().paused = false

func _exit_tree() -> void:
	if holding:
		get_tree().paused = false
