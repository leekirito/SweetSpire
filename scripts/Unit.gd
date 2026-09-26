class_name Unit
extends CharacterBody2D

signal range_configuration_changed(unit: Unit)

const HIT_BURST: PackedScene = preload("res://scenes/effects/HitBurst.tscn")

@export var data: UnitData
@export var owner_id: int
@export var pixels_per_second: float = 300.0

var player_state: PlayerState
# Identity


var unit_id: int = -1


# Runtime Stats

var unit_walk_range: int = 1
var unit_name: String = ""
var unit_health: int = 1
var unit_damage: int = 1
var attack_range: int = 1
var defence: int = 0
var type: String = ""
var movement_pattern: RangePattern
var attack_pattern: RangePattern
var walk_base_dimensions_override: Vector2i = Vector2i.ZERO
var attack_base_dimensions_override: Vector2i = Vector2i.ZERO
var walk_exact_dimensions_override: Vector2i = Vector2i.ZERO
var attack_exact_dimensions_override: Vector2i = Vector2i.ZERO

# Turn State

var has_moved: bool = false
var has_attacked: bool = false
var is_animating: bool = false

# Board State

var current_cell: Vector2i
var target_cell: Vector2i


# Visuals

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_ui: ProgressBar = $Health
@onready var defence_ui: ProgressBar = $Defence
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var walk_trail: GPUParticles2D = $GPUParticles2D

#vfx
@export var shake_strength: float = 0.0
@export var shake_decay: float = 5.0
@export_group("Walk Trail")
@export var walk_trail_enabled: bool = true
var _sprite_rest_position: Vector2
var _health_rest_position: Vector2
var _defence_rest_position: Vector2

func _ready() -> void:
	add_to_group("units")
	walk_trail.emitting = false

	if data == null:
		push_error(
			"UnitData is not assigned to unit: " + name
		)
		return

	_load_data()
	if not data.changed.is_connected(_on_unit_data_changed):
		data.changed.connect(_on_unit_data_changed)
	_connect_pattern_change_signals()

	health_ui.max_value = unit_health
	health_ui.value = unit_health
	defence_ui.max_value = defence
	defence_ui.value = defence
	_sprite_rest_position = sprite.position
	_health_rest_position = health_ui.position
	_defence_rest_position = defence_ui.position

func _process(delta: float) -> void:
	if walk_trail != null:
		walk_trail.emitting = walk_trail_enabled and is_animating

	if shake_strength > 0.0:
		# Reduce shake strength over time
		shake_strength = move_toward(shake_strength, 0.0, shake_decay * delta)

		# Shake presentation children only. The root position is authoritative board state.
		var shake_offset := Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		sprite.position = _sprite_rest_position + shake_offset
		health_ui.position = _health_rest_position + shake_offset
		defence_ui.position = _defence_rest_position + shake_offset
	else:
		sprite.position = _sprite_rest_position
		health_ui.position = _health_rest_position
		defence_ui.position = _defence_rest_position

func apply_shake(strength: float = 10.0) -> void:
	shake_strength = strength

## Copies immutable design data into mutable per-match combat stats.
func _load_data() -> void:
	unit_walk_range = data.walk_range
	unit_name = data.unit_name
	unit_health = data.health
	unit_damage = data.attack_damage
	attack_range = data.attack_range
	defence = data.defence
	type = data.type
	movement_pattern = data.movement_pattern
	attack_pattern = data.attack_pattern
	walk_base_dimensions_override = data.walk_base_dimensions_override
	attack_base_dimensions_override = data.attack_base_dimensions_override
	walk_exact_dimensions_override = data.walk_exact_dimensions_override
	attack_exact_dimensions_override = data.attack_exact_dimensions_override


## Keeps editor-time UnitData changes visible on units that already exist in a test match.
## Combat health and defence are deliberately not reset when a resource is edited.
func _on_unit_data_changed() -> void:
	_refresh_range_configuration()
	_connect_pattern_change_signals()
	range_configuration_changed.emit(self)


func _refresh_range_configuration() -> void:
	unit_walk_range = data.walk_range
	attack_range = data.attack_range
	movement_pattern = data.movement_pattern
	attack_pattern = data.attack_pattern
	walk_base_dimensions_override = data.walk_base_dimensions_override
	attack_base_dimensions_override = data.attack_base_dimensions_override
	walk_exact_dimensions_override = data.walk_exact_dimensions_override
	attack_exact_dimensions_override = data.attack_exact_dimensions_override


func _connect_pattern_change_signals() -> void:
	for pattern: RangePattern in [movement_pattern, attack_pattern]:
		if pattern == null:
			continue
		if not pattern.changed.is_connected(_on_range_pattern_changed):
			pattern.changed.connect(_on_range_pattern_changed)


func _on_range_pattern_changed() -> void:
	_refresh_range_configuration()
	range_configuration_changed.emit(self)
	
## Assigns runtime ownership and selects the texture for the player's tribe.
func setup_player(
	player: PlayerState
) -> void:

	player_state = player
	owner_id = player.player_id

	if sprite != null:
		sprite.texture = data.character_texture[
			player.tribe.tribe_name
		]


## Consumes defence before health, then refreshes the unit bars.
## Applies damage and spawns readable combat feedback at the unit's world position.
func take_damage(damage: int) -> int:
	audio.play()
	var durability_before: int = defence + unit_health

	var absorbed_damage: int = mini(
		defence,
		damage
	)

	defence -= absorbed_damage

	var remaining_damage: int = (
		damage - absorbed_damage
	)

	unit_health -= remaining_damage
	update_ui()

	var applied_damage: int = mini(
		damage,
		durability_before
	)
	apply_shake()
	_show_damage_number(applied_damage)
	if applied_damage > 0:
		var burst := HIT_BURST.instantiate() as Node2D
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
	return applied_damage


## Creates a punchy world-space number that rises and fades independently of the unit.
func _show_damage_number(damage: int) -> void:
	if damage <= 0:
		return

	var damage_label := Label.new()
	damage_label.text = "-" + str(damage)
	damage_label.z_index = 2000
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.custom_minimum_size = Vector2(140.0, 64.0)
	damage_label.position = global_position + Vector2(-70.0, -245.0)
	damage_label.pivot_offset = Vector2(70.0, 32.0)
	damage_label.add_theme_font_size_override("font_size", 48)
	damage_label.add_theme_color_override("font_color", Color("ffd166"))
	damage_label.add_theme_color_override("font_outline_color", Color("541f17"))
	damage_label.add_theme_constant_override("outline_size", 10)

	get_tree().current_scene.add_child(damage_label)
	damage_label.scale = Vector2(0.65, 0.65)

	var tween := damage_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		damage_label,
		"position",
		damage_label.position + Vector2(0.0, -105.0),
		0.85
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		damage_label,
		"scale",
		Vector2.ONE,
		0.16
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		damage_label,
		"modulate:a",
		0.0,
		0.38
	).set_delay(0.47).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(damage_label.queue_free)


func get_attack_damage() -> int:
	return unit_damage


func is_dead() -> bool:
	return unit_health <= 0
	
func update_ui()->void:
	health_ui.value = unit_health
	defence_ui.value = defence
	
