class_name CenterControlHUD
extends Control


@onready var match_manager: MatchManager = get_node("../../MatchManager")
@onready var panel: PanelContainer = $Panel
@onready var owner_label: Label = $Panel/Margin/Content/Owner
@onready var progress_label: Label = $Panel/Margin/Content/Progress
@onready var segments: HBoxContainer = $Panel/Margin/Content/Segments

var displayed_player_id: int = -2
var displayed_progress: int = -1
var displayed_target: int = -1


func _ready() -> void:
	panel.visible = false
	match_manager.match_ended.connect(_on_match_ended)


## Polling keeps the HUD accurate immediately when a unit enters or leaves center.
func _process(_delta: float) -> void:
	if match_manager.current_phase == MatchManager.Phase.GAME_OVER:
		panel.visible = false
		return

	var controller: PlayerState = match_manager.get_center_controller()
	if controller == null:
		panel.visible = false
		displayed_player_id = -1
		return

	panel.visible = true
	var target: int = match_manager.get_center_control_target()
	if (
		controller.player_id == displayed_player_id
		and controller.center_control_rounds == displayed_progress
		and target == displayed_target
	):
		return

	displayed_player_id = controller.player_id
	displayed_progress = controller.center_control_rounds
	displayed_target = target
	_refresh(controller, target)


func _refresh(controller: PlayerState, target: int) -> void:
	owner_label.text = controller.player_name.to_upper() + " CONTROLS CENTER"
	owner_label.add_theme_color_override("font_color", controller.tribe.territory_color)
	progress_label.text = "%d / %d ROUNDS" % [controller.center_control_rounds, target]

	for child: Node in segments.get_children():
		child.queue_free()

	for index: int in range(target):
		var segment := ColorRect.new()
		segment.custom_minimum_size = Vector2(12.0, 6.0)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.color = (
			controller.tribe.territory_color
			if index < controller.center_control_rounds
			else Color(0.25, 0.29, 0.36, 0.85)
		)
		segments.add_child(segment)


func _on_match_ended(_winner_id: int, _victory_reason: String) -> void:
	panel.visible = false
