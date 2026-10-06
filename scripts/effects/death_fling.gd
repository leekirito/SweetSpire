class_name DeathFling
extends Node2D

## Visual copy of a defeated unit that can animate after the real unit leaves the registries.


## A visual copy that survives after the defeated unit leaves the board.
var destination: Vector2
var _sprite: Sprite2D


## Copies the defeated unit's sprite and animates the copy beyond the board.
func launch(unit: Unit, board: BoardManager) -> void:
	global_position = unit.global_position
	z_index = 1200
	_sprite = Sprite2D.new()
	_sprite.texture = unit.sprite.texture
	_sprite.position = unit.sprite.position
	_sprite.offset = unit.sprite.offset
	_sprite.scale = unit.sprite.scale
	_sprite.flip_h = unit.sprite.flip_h
	_sprite.flip_v = unit.sprite.flip_v
	_sprite.hframes = unit.sprite.hframes
	_sprite.vframes = unit.sprite.vframes
	_sprite.frame = unit.sprite.frame
	_sprite.modulate = unit.sprite.modulate
	_sprite.material = unit.sprite.material
	add_child(_sprite)

	var outward := _outward_direction(board)
	destination = _exit_point(board, outward)
	var sideways := Vector2(-outward.y, outward.x)
	var first_hop := global_position + Vector2(randf_range(-65.0, 65.0), -randf_range(80.0, 150.0))
	var second_hop := global_position.lerp(destination, 0.48) + sideways * randf_range(-110.0, 110.0) + Vector2.UP * 100.0
	var duration := randf_range(1.05, 1.4)

	var flight := create_tween()
	flight.tween_property(self, "global_position", first_hop, duration * 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	flight.tween_property(self, "global_position", second_hop, duration * 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(self, "global_position", destination, duration * 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flight.finished.connect(queue_free)

	var spin := create_tween()
	var angle := _sprite.rotation
	var direction := -1.0 if randf() < 0.5 else 1.0
	for fraction in [0.16, 0.22, 0.18, 0.21, 0.23]:
		angle += direction * randf_range(0.6, 1.5) * TAU
		spin.tween_property(_sprite, "rotation", angle, duration * fraction).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		direction *= -1.0 if randf() < 0.65 else 1.0

	var fade := create_tween()
	fade.tween_interval(duration * 0.78)
	fade.tween_property(_sprite, "modulate:a", 0.0, duration * 0.22)


func _outward_direction(board: BoardManager) -> Vector2:
	var bounds := _board_bounds(board)
	var direction := global_position - bounds.get_center()
	if direction.length_squared() < 1.0:
		direction = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	return (direction.normalized() + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * 0.22).normalized()


func _exit_point(board: BoardManager, direction: Vector2) -> Vector2:
	var bounds := _board_bounds(board)
	var distance := INF
	if direction.x > 0.001:
		distance = minf(distance, (bounds.end.x - global_position.x) / direction.x)
	elif direction.x < -0.001:
		distance = minf(distance, (bounds.position.x - global_position.x) / direction.x)
	if direction.y > 0.001:
		distance = minf(distance, (bounds.end.y - global_position.y) / direction.y)
	elif direction.y < -0.001:
		distance = minf(distance, (bounds.position.y - global_position.y) / direction.y)
	return global_position + direction * (maxf(distance, 0.0) + 400.0)


func _board_bounds(board: BoardManager) -> Rect2:
	var used := board.tile_map_layer.get_used_rect()
	var top_left := used.position
	var bottom_right := used.position + used.size - Vector2i.ONE
	var corners := [
		top_left,
		Vector2i(bottom_right.x, top_left.y),
		Vector2i(top_left.x, bottom_right.y),
		bottom_right,
	]
	var minimum := board.cell_to_world(corners[0])
	var maximum := minimum
	for cell: Vector2i in corners:
		var world := board.cell_to_world(cell)
		minimum = minimum.min(world)
		maximum = maximum.max(world)
	return Rect2(minimum, maximum - minimum)
