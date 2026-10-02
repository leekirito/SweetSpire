class_name FogCell
extends Node2D

## Scene tile owned by FogOfWar. Visibility rules apply before animation.
var fog_state: int = 0
var transition: Tween
@onready var cover: Polygon2D = $Cover
@onready var fog_sprite: Sprite2D = $Cover/Sprite
var fog_texture: Texture2D
var tile_size := Vector2(256, 128)
var unknown_color := Color(0.055, 0.075, 0.12, 1.0)
var explored_color := Color(0.09, 0.13, 0.20, 0.58)

func _ready() -> void:
	configure(tile_size, unknown_color, explored_color)

func configure(size: Vector2, unexplored: Color, explored: Color, texture: Texture2D = null) -> void:
	tile_size = size
	unknown_color = unexplored
	explored_color = explored
	if cover == null:
		return
	var half := size * 0.5
	cover.polygon = PackedVector2Array([
		Vector2(0, -half.y), Vector2(half.x, 0),
		Vector2(0, half.y), Vector2(-half.x, 0)
	])
	set_fog_texture(texture)

## The polygon is also the animation parent, so both visuals share the tween.
func set_fog_texture(texture: Texture2D) -> void:
	fog_texture = texture
	if fog_sprite == null:
		return
	fog_sprite.texture = texture
	fog_sprite.visible = texture != null
	if texture != null:
		var size := texture.get_size()
		fog_sprite.scale = tile_size / Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	_apply_color(unknown_color if fog_state == 0 else explored_color)

func _apply_color(color: Color) -> void:
	cover.color = color if fog_texture == null else Color.TRANSPARENT
	# Preserve the sprite's artwork; only its opacity follows the fog state.
	fog_sprite.modulate = Color(1.0, 1.0, 1.0, color.a)

func set_fog_state(next_state: int, animate: bool, duration: float) -> void:
	if cover == null:
		return
	fog_state = next_state
	if transition != null:
		transition.kill()
	var clear := next_state == 2
	var target_scale := Vector2.ZERO if clear else Vector2.ONE
	var target_color := unknown_color if next_state == 0 else explored_color
	if not animate or duration <= 0.0:
		cover.scale = target_scale
		cover.visible = not clear
		_apply_color(target_color)
		return
	cover.visible = true
	if not clear:
		_apply_color(target_color)
	transition = create_tween()
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(cover, "scale", target_scale, duration)
	if clear:
		transition.tween_callback(func(): cover.visible = false)
