class_name TurnNavbar
extends Control

@onready var technology_button: Button = $BottomNav/Technology
@onready var technology_tree: Control = $TechnologyTree
@onready var match_manager: MatchManager = get_tree().current_scene.get_node("MatchManager")


func _ready() -> void:
	technology_button.pressed.connect(_open_technology_tree)
	technology_tree.closed.connect(_close_technology_tree)
	match_manager.turn_started.connect(_on_turn_started)
	_on_turn_started(match_manager.active_player_id, match_manager.current_round)


func _open_technology_tree() -> void:
	var player: PlayerState = match_manager.get_active_player()
	technology_tree.open_for_player(player)
	$BottomNav.hide()


func _close_technology_tree() -> void:
	technology_tree.hide()
	$BottomNav.visible = match_manager.current_phase == MatchManager.Phase.PLAYER_TURN


func _on_turn_started(_player_id: int, _round_number: int) -> void:
	technology_tree.hide()
	$BottomNav.visible = match_manager.current_phase == MatchManager.Phase.PLAYER_TURN
