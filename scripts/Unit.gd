class_name Unit
extends CharacterBody2D

## One live unit's ownership, combat stats, range configuration, and feedback.
## UnitData supplies defaults; match systems authorize actions and BoardManager owns occupancy.


signal range_configuration_changed(unit: Unit)

const HIT_BURST: PackedScene = preload("res://scenes/effects/HitBurst.tscn")

## Shared unit defaults copied into this unit's runtime state.
@export var data: UnitData
## Owning player seat ID; this is not a network peer ID.
@export var owner_id: int
## World-space movement speed for local presentation.
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
var can_traverse_land: bool = true
var can_traverse_water: bool = false
var ignores_terrain_blocking: bool = false
var is_embarked: bool = false
var _land_form: Dictionary = {}
var _boat_data: StructureData

# Turn State

var has_moved: bool = false
var has_attacked: bool = false
var is_animating: bool = false
var network_move_tween: Tween

## Board cells are already committed. This tween is purely local presentation.
func present_network_move(from_position: Vector2) -> void:
	if network_move_tween != null:
		network_move_tween.kill()
	var destination := global_position
	if from_position.is_equal_approx(destination):
		return
	global_position = from_position
	network_move_tween = create_tween()
	network_move_tween.tween_property(self, "global_position", destination, LanSession.SETTINGS.move_duration)

# Board State

var current_cell: Vector2i
var target_cell: Vector2i


# Visuals

@onready var sprite: Sprite2D = $Sprite2D
@onready var tribe_outline: Sprite2D = $TribeOutline
@onready var health_ui: ProgressBar = $Health
@onready var defence_ui: ProgressBar = $Defence
@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var walk_trail: GPUParticles2D = $GPUParticles2D

#vfx
## Current cosmetic shake amplitude.
@export var shake_strength: float = 0.0
## Rate at which cosmetic shake fades.
@export var shake_decay: float = 5.0
@export_group("Walk Trail")
## Enable cosmetic movement trails.
@export var walk_trail_enabled: bool = true
@export_group("Tribe Outline")
## Opacity of the ownership outline.
@export_range(0.0, 1.0, 0.05) var outline_opacity: float = 1.0:
	set(value):
		outline_opacity = value
		_update_outline_shader()
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
	defence_ui.visible = defence > 0
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
	tribe_outline.position = sprite.position

## Starts cosmetic sprite shake without changing board occupancy.
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
	can_traverse_land = data.can_traverse_land
	can_traverse_water = data.can_traverse_water
	ignores_terrain_blocking = data.ignores_terrain_blocking


## Keeps editor-time UnitData changes visible on units that already exist in a test match.
## Combat health and defence are deliberately not reset when a resource is edited.
func _on_unit_data_changed() -> void:
	_refresh_range_configuration()
	_connect_pattern_change_signals()
	range_configuration_changed.emit(self)


func _refresh_range_configuration() -> void:
	if is_embarked:
		return
	unit_walk_range = data.walk_range
	attack_range = data.attack_range
	movement_pattern = data.movement_pattern
	attack_pattern = data.attack_pattern
	walk_base_dimensions_override = data.walk_base_dimensions_override
	attack_base_dimensions_override = data.attack_base_dimensions_override
	walk_exact_dimensions_override = data.walk_exact_dimensions_override
	attack_exact_dimensions_override = data.attack_exact_dimensions_override
	can_traverse_land = data.can_traverse_land
	can_traverse_water = data.can_traverse_water
	ignores_terrain_blocking = data.ignores_terrain_blocking


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
	if tribe_outline != null:
		var outline_material := tribe_outline.material.duplicate() as ShaderMaterial
		tribe_outline.material = outline_material
		_update_outline_shader()
		refresh_tribe_outline(owner_id)


func _update_outline_shader() -> void:
	if not is_node_ready() or tribe_outline == null or player_state == null:
		return
	var outline_material := tribe_outline.material as ShaderMaterial
	if outline_material == null:
		return
	var color := player_state.tribe.unit_outline_color
	color.a *= outline_opacity
	outline_material.set_shader_parameter("outline_color", color)


## Keeps the outline tied to the displayed sprite and the current player's view.
func refresh_tribe_outline(viewing_player_id: int) -> void:
	if tribe_outline == null or sprite == null:
		return
	tribe_outline.texture = sprite.texture
	tribe_outline.offset = sprite.offset
	tribe_outline.visible = (
		player_state != null
		and viewing_player_id != -1
		and (viewing_player_id != owner_id or (not has_moved and not has_attacked))
	)


## Consumes defence before health, then refreshes the unit bars.
## Applies damage and spawns readable combat feedback at the unit's world position.
func take_damage(damage: int, show_feedback: bool = true) -> int:
	if show_feedback:
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
	if not show_feedback:
		return applied_damage
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


## A blast pattern enables area attacks only while the unit is not embarked.
func has_area_attack() -> bool:
	return not is_embarked and data != null and data.blast_pattern != null


func is_dead() -> bool:
	return unit_health <= 0
	
func update_ui()->void:
	health_ui.value = unit_health
	defence_ui.value = defence
	defence_ui.visible = defence > 0
	

## Only locomotion/presentation change. Health, damage, defence, owner and action flags survive.
func embark(boat: StructureData) -> void:
	if is_embarked:
		return
	for key: String in ["unit_name", "type", "unit_walk_range", "attack_range", "movement_pattern", "attack_pattern", "walk_base_dimensions_override", "attack_base_dimensions_override", "walk_exact_dimensions_override", "attack_exact_dimensions_override", "can_traverse_land", "can_traverse_water", "ignores_terrain_blocking"]:
		_land_form[key] = get(key)
	_land_form["texture"] = sprite.texture
	_land_form["offset"] = sprite.offset
	_boat_data = boat
	is_embarked = true
	unit_name = "Boat"
	type = "boat"
	unit_walk_range = boat.boat_walk_range
	attack_range = boat.boat_attack_range
	movement_pattern = boat.boat_movement_pattern
	attack_pattern = boat.boat_attack_pattern
	# Existing RangePattern uses base + range dimensions. These bases give symmetric radii.
	walk_base_dimensions_override = Vector2i.ONE * (unit_walk_range + 1)
	attack_base_dimensions_override = Vector2i.ONE * (attack_range + 1)
	walk_exact_dimensions_override = Vector2i.ZERO
	attack_exact_dimensions_override = Vector2i.ZERO
	can_traverse_land = true
	can_traverse_water = true
	ignores_terrain_blocking = false
	if boat.boat_texture != null:
		sprite.texture = boat.boat_texture
		sprite.offset = Vector2(0, -60)
	range_configuration_changed.emit(self)

## Restores the saved land form while preserving combat stats and spent actions.
func disembark() -> void:
	if not is_embarked:
		return
	for key: String in _land_form:
		if key not in ["texture", "offset"]:
			set(key, _land_form[key])
	sprite.texture = _land_form["texture"]
	sprite.offset = _land_form["offset"]
	is_embarked = false
	_boat_data = null
	_land_form.clear()
	range_configuration_changed.emit(self)
