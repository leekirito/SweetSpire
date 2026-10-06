class_name AttackPresentation
extends Node2D

signal impact
signal decals_due
signal finished

const SLASH_TEXTURE: Texture2D = preload("res://assets/effects/kenney_particle_pack/slash_01.png")
const SLASH_SHADER: Shader = preload("res://assets/Shader/slash_reveal.gdshader")
const METEOR_VISUAL := 1

var _impact_position: Vector2
var _meteor_attack: bool
var _unit_data: UnitData
var _meteor_effect: Node2D


## Plays the windup first. The impact signal is the only damage timing cue.
func play_attack(
	from_position: Vector2,
	target_position: Vector2,
	unit_data: UnitData,
	blast_world_size: Vector2
) -> void:
	_impact_position = target_position
	_unit_data = unit_data
	_meteor_attack = unit_data.attack_visual == METEOR_VISUAL
	z_index = 1500
	if _meteor_attack:
		_play_meteor(from_position, blast_world_size)
	else:
		_play_slash(from_position)


func _play_slash(from_position: Vector2) -> void:
	var slash := Sprite2D.new()
	slash.texture = SLASH_TEXTURE
	slash.position = _impact_position
	slash.scale = Vector2.ONE * 0.12
	slash.rotation = (_impact_position - from_position).angle() - PI / 2.0
	var slash_material := ShaderMaterial.new()
	slash_material.shader = SLASH_SHADER
	slash_material.set_shader_parameter("reveal", 0.0)
	slash.material = slash_material
	add_child(slash)

	var animation := create_tween()
	animation.set_parallel(true)
	animation.tween_method(
		func(value: float) -> void: slash_material.set_shader_parameter("reveal", value),
		0.0, 1.0, 0.22
	)
	animation.tween_property(slash, "scale", Vector2.ONE * 0.42, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	animation.tween_property(slash, "rotation", slash.rotation + 0.6, 0.22)
	animation.chain().tween_callback(_emit_impact)
	animation.tween_property(slash, "modulate:a", 0.0, 0.16)
	animation.chain().tween_callback(_finish)


func _play_meteor(from_position: Vector2, blast_world_size: Vector2) -> void:
	if visible and _unit_data.meteor_effect_scene != null:
		var instance := _unit_data.meteor_effect_scene.instantiate()
		if instance is Node2D:
			_meteor_effect = instance
			get_tree().current_scene.add_child(_meteor_effect)
			_meteor_effect.global_position = _impact_position
			if _meteor_effect.has_method("play_effect"):
				_meteor_effect.call("play_effect", from_position, _impact_position, blast_world_size, _unit_data.meteor_effect_time)
		else:
			instance.queue_free()
			push_warning("Meteor effect scene root must be a Node2D.")
	var effect_time := _unit_data.meteor_effect_time
	var decal_time := maxf(0.0, effect_time + _unit_data.meteor_decal_time_offset)
	var damage_clock := create_tween()
	damage_clock.tween_interval(effect_time)
	damage_clock.tween_callback(_emit_impact)
	var decal_clock := create_tween()
	decal_clock.tween_interval(decal_time)
	decal_clock.tween_callback(func() -> void: decals_due.emit())
	var finish_clock := create_tween()
	finish_clock.tween_interval(maxf(effect_time, decal_time) + 0.02)
	finish_clock.tween_callback(_finish)


func _emit_impact() -> void:
	if _meteor_attack:
		if is_instance_valid(_meteor_effect) and _meteor_effect.has_method("trigger_impact"):
			_meteor_effect.call("trigger_impact")
	elif visible:
		Fx.spawn("impact_spark", _impact_position, {"size": 0.7})
	impact.emit()


func _finish() -> void:
	finished.emit()
	queue_free()
