class_name CameraController
extends Camera2D

var zoom_tween: Tween
var target_zoom: Vector2
@export var focus_active_player_on_turn: bool = true


func _ready() -> void:
	target_zoom = zoom
	var game := get_node_or_null("../MatchManager") as MatchManager
	if game != null:
		game.turn_started.connect(_focus_player)
		game.match_started.connect(_initial_network_focus)

func _initial_network_focus() -> void:
	if LanSession.active():
		_focus_player(LanSession.local_player_id, 1)


func _focus_player(player_id: int, _round: int) -> void:
	if LanSession.active():
		if player_id != LanSession.local_player_id:
			return
	if not focus_active_player_on_turn:
		return
	var game := get_node("../MatchManager") as MatchManager
	if game.get_player(player_id) != null and game.get_player(player_id).is_bot():
		return
	if game.fog_of_war == null:
		return
	for unit: Unit in game.units.values():
		if unit.owner_id == player_id:
			global_position = game.board_manager.cell_to_world(unit.current_cell)
			return
	for building: Building in game.buildings.values():
		if building.owner_id == player_id:
			global_position = game.board_manager.cell_to_world(building.current_cell)
			return


## Smoothly zooms with the wheel and pans while the middle mouse button is held.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:

		var changed_zoom: bool = false

		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom += Vector2(0.1, 0.1)
			changed_zoom = true

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom -= Vector2(0.1, 0.1)
			changed_zoom = true

		if changed_zoom:
			target_zoom = target_zoom.clamp(
				Vector2(0.2, 0.2),
				Vector2(4.0, 4.0)
			)

			if zoom_tween:
				zoom_tween.kill()

			zoom_tween = create_tween()

			zoom_tween.set_trans(
				Tween.TRANS_QUAD
			)

			zoom_tween.set_ease(
				Tween.EASE_OUT
			)

			zoom_tween.tween_property(
				self,
				"zoom",
				target_zoom,
				0.2
			)

	if (
		event is InputEventMouseMotion
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	):
		position -= event.relative / zoom
