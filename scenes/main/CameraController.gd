class_name CameraController
extends Camera2D

var zoom_tween: Tween
var target_zoom: Vector2


func _ready() -> void:
	target_zoom = zoom


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
