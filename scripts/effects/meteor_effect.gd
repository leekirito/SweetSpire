class_name MeteorEffect
extends Node2D

## The caster data controls when impact happens; edit this scene for its look and sound.
## Starting position of the falling sprite and trail relative to the targeted tile.
@export var start_offset: Vector2 = Vector2(-180.0, -490.0)
## Additional size after fitting the meteor sprite to the full blast footprint.
@export_range(0.2, 3.0, 0.05) var size_multiplier: float = 1.0
## Base amount the meteor sprite rotates during its fall, in degrees.
@export_range(-720.0, 720.0, 1.0) var spin_degrees: float = 70.0
## Random amount added to or subtracted from Spin Degrees for each cast.
@export_range(0.0, 360.0, 1.0) var spin_variation_degrees: float = 45.0
## Start each meteor at a random angle while keeping its existing shader material.
@export var random_start_rotation: bool = true
## Randomly choose clockwise or counterclockwise spin for each cast.
@export var random_spin_direction: bool = true
## KapowFX scenes spawned at the landing point. Add or replace scenes here.
@export var impact_effect_scenes: Array[PackedScene] = [
	preload("res://assets/effects/kapowfx/effects/impact/shockwave.tscn"),
	preload("res://assets/effects/kapowfx/effects/impact/hit_burst.tscn")
]
## Additional size for the landing effects after they are fitted to the blast area.
@export_range(0.1, 3.0, 0.05) var impact_size_multiplier: float = 1.0
## Main color passed to each KapowFX landing effect.
@export var impact_main_color: Color = Color("ff9a3c")
## Secondary color passed to each KapowFX landing effect.
@export var impact_accent_color: Color = Color("ffb35a")
## Minimum time this scene remains after impact so particles and audio can finish.
@export_range(0.2, 10.0, 0.1) var linger_seconds: float = 1.0

@export_group("Standalone Preview")
## Play this effect automatically when MeteorEffect.tscn is run as the current scene.
@export var preview_when_run_alone: bool = true
## Repeat the preview after each landing.
@export var preview_loop: bool = true
## Fall duration used only by the standalone preview.
@export_range(0.1, 5.0, 0.05) var preview_effect_time: float = 2.0
## Approximate blast footprint used for preview sizing.
@export var preview_blast_world_size: Vector2 = Vector2(768.0, 384.0)
## Time between standalone preview loops.
@export_range(0.0, 5.0, 0.05) var preview_gap_seconds: float = 0.6
## Camera zoom used only when this effect scene is run alone.
@export var preview_camera_zoom: Vector2 = Vector2(0.8, 0.8)

@onready var meteor_sprite: Sprite2D = $MeteorSprite
@onready var trail: GPUParticles2D = $Trail
@onready var cast_audio: AudioStreamPlayer2D = $CastAudio
@onready var impact_audio: AudioStreamPlayer2D = $ImpactAudio

var _blast_world_size: Vector2
var _landed: bool = false
var _standalone_preview: bool = false
var _authored_sprite_rotation: float


func _ready() -> void:
	_authored_sprite_rotation = meteor_sprite.rotation
	call_deferred("_try_standalone_preview")


func _try_standalone_preview() -> void:
	if not preview_when_run_alone or get_tree().current_scene != self:
		return
	_standalone_preview = true
	var camera := Camera2D.new()
	add_child(camera)
	camera.position = start_offset * 0.5
	camera.zoom = preview_camera_zoom
	camera.make_current()
	_play_preview()


func _play_preview() -> void:
	if not is_inside_tree():
		return
	play_effect(global_position, global_position, preview_blast_world_size, preview_effect_time)
	get_tree().create_timer(preview_effect_time, false).timeout.connect(trigger_impact)


## Called by the attack timeline. Add child nodes or animations here as desired.
func play_effect(from_position: Vector2, target_position: Vector2, blast_world_size: Vector2, duration: float) -> void:
	global_position = target_position
	_blast_world_size = blast_world_size
	_landed = false
	meteor_sprite.show()
	meteor_sprite.position = start_offset
	var texture_size := meteor_sprite.texture.get_size() if meteor_sprite.texture != null else Vector2.ONE
	var footprint_size := maxf(blast_world_size.x, blast_world_size.y)
	var final_scale := footprint_size / maxf(texture_size.x, texture_size.y) * size_multiplier
	meteor_sprite.scale = Vector2.ONE * final_scale * 1.2
	var starting_rotation := _authored_sprite_rotation
	if random_start_rotation:
		starting_rotation += randf_range(-PI, PI)
	meteor_sprite.rotation = starting_rotation
	var spin_amount := spin_degrees + randf_range(-spin_variation_degrees, spin_variation_degrees)
	if random_spin_direction and randf() < 0.5:
		spin_amount = -spin_amount
	trail.position = start_offset
	trail.scale = Vector2.ONE * final_scale
	trail.restart()
	trail.emitting = true
	if cast_audio.stream != null:
		cast_audio.global_position = from_position
		cast_audio.play()
	var fall := create_tween()
	fall.set_parallel(true)
	fall.tween_property(meteor_sprite, "position", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(meteor_sprite, "scale", Vector2.ONE * final_scale, duration)
	fall.tween_property(meteor_sprite, "rotation", starting_rotation + deg_to_rad(spin_amount), duration)
	fall.tween_property(trail, "position", Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Called exactly when the attack applies damage.
func trigger_impact() -> void:
	if _landed:
		return
	_landed = true
	trail.emitting = false
	meteor_sprite.hide()
	if impact_audio.stream != null:
		impact_audio.play()
	var effect_size := maxf(_blast_world_size.x, _blast_world_size.y) / 340.0 * impact_size_multiplier
	for effect_scene: PackedScene in impact_effect_scenes:
		if effect_scene == null:
			continue
		var instance := effect_scene.instantiate()
		if not instance is Node2D:
			instance.queue_free()
			continue
		var effect := instance as Node2D
		if effect is FxEffect:
			effect.auto_play = false
			effect.size = effect_size
			effect.color_main = impact_main_color
			effect.color_accent = impact_accent_color
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position
		effect.z_index = 1500
		if effect is FxEffect:
			effect.play()
	var audio_length := impact_audio.stream.get_length() if impact_audio.stream != null else 0.0
	get_tree().create_timer(maxf(linger_seconds, audio_length), false).timeout.connect(_after_impact)


func _after_impact() -> void:
	if _standalone_preview:
		if preview_loop:
			get_tree().create_timer(preview_gap_seconds, false).timeout.connect(_play_preview)
	else:
		queue_free()
