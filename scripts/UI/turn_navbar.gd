class_name TurnNavbar
extends Control

## Coordinates the technology modal and End Turn button.
## MatchManager and LanSession remain responsible for purchase authorization.


@onready var technology_button: Button = $BottomNav/Technology
@onready var technology_tree: Control = $TechnologyTree
@onready var match_manager: MatchManager = get_tree().current_scene.get_node("MatchManager")
@onready var end_turn_button: Button = get_tree().current_scene.get_node_or_null("CanvasLayer/Control/Button")


func _ready() -> void:
	technology_button.pressed.connect(_open_technology_tree)
	technology_tree.closed.connect(_close_technology_tree)
	technology_tree.visibility_changed.connect(_sync_technology_modal)
	match_manager.turn_started.connect(_on_turn_started)
	LanSession.changed.connect(_sync_technology_modal)
	_on_turn_started(match_manager.active_player_id, match_manager.current_round)


func _open_technology_tree() -> void:
	# GUI hit testing follows sibling order, independently of visual z_index.
	move_to_front()
	var player: PlayerState = match_manager.get_viewing_player()
	technology_tree.open_for_player(player)
	$BottomNav.hide()
	technology_tree.get_node("Close").grab_focus()


func _sync_technology_modal() -> void:
	if end_turn_button != null:
		end_turn_button.disabled = technology_tree.visible or match_manager.current_phase != MatchManager.Phase.PLAYER_TURN or not LanSession.can_act()


func _close_technology_tree() -> void:
	technology_tree.hide()
	$BottomNav.visible = match_manager.current_phase == MatchManager.Phase.PLAYER_TURN


func _on_turn_started(_player_id: int, _round_number: int) -> void:
	technology_tree.hide()
	$BottomNav.visible = match_manager.current_phase == MatchManager.Phase.PLAYER_TURN
	_sync_technology_modal()
