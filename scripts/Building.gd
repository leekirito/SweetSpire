class_name Building
extends Area2D


# ============================================================
# IDENTITY
# ============================================================

var building_id: int = -1
var current_cell: Vector2i
var current_exp: int = 0
const EXP_REQUIREMENTS := {
	1: 2,
	2: 3,
	3: 4,
	4: 5
}
# ============================================================
# OWNERSHIP
# ============================================================

var owner_id: int = -1

# Only controls THIS building's appearance.
var visual_tribe: TribeData = null


# ============================================================
# TERRITORY
# ============================================================

# Radius 1 = 3x3 territory.
@export var territory_radius: int = 1

# Filled automatically by TerritoryManager.
var territory_cells: Array[Vector2i] = []


# ============================================================
# STARTING TOWN RULES
# ============================================================

# Example:
# ["saba"]
#
# or:
# ["saba", "kamote"]
#
# Empty means this town cannot be selected
# as a starting town.

@export var allowed_starting_tribe_ids: Array[String] = []


# ============================================================
# DATA
# ============================================================

@export var data: BuildingData

@export var available_unit_types: Array[PackedScene] = [
	preload("uid://kyhenfdpjtn"),
	preload("uid://dw8n2deqnba4p"),
	preload("uid://bxt5sabvny8r7")
]


# ============================================================
# REFERENCES
# ============================================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var exp_backdrop: Panel = $ExpBackdrop
@onready var exp_segments: HBoxContainer = $ExpBackdrop/ExpSegments


var recruitment_ui: PackedScene = preload(
	"uid://cybja0bqnm471"
)

var by_turn_sugar: int

var building_level: int = 1
signal level_changed(
	building: Building
)

# ============================================================
# READY
# ============================================================

## Maps town level to the sugar paid at each round boundary.
func _update_building_income():

	#territory_radius = building_level
	match building_level:
		1, 2:
			by_turn_sugar = 2

		3, 4:
			by_turn_sugar = 5

		5:
			by_turn_sugar = 8

## Applies all level-dependent effects before notifying territory systems.
func increase_level() -> void:

	if building_level >= 5:
		return

	building_level += 1

	_update_territory_radius()
	_update_building_income()

	level_changed.emit(
		self
	)



func get_exp_required() -> int:
	if building_level >= 5:
		return 0

	return EXP_REQUIREMENTS.get(
		building_level,
		0
	)
	
func add_exp(amount: int) -> void:
	if building_level >= 5:
		return

	current_exp += amount

	check_level_up()
	_refresh_exp_bar(true)


## Shows this town's round income as rising world-space feedback.
func show_sugar_gain(amount: int) -> void:
	if amount <= 0:
		return

	var sugar_label := Label.new()
	sugar_label.text = "+" + str(amount) + " SUGAR"
	sugar_label.z_index = 2000
	sugar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sugar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sugar_label.custom_minimum_size = Vector2(180.0, 52.0)
	sugar_label.position = global_position + Vector2(-90.0, -245.0)
	sugar_label.pivot_offset = Vector2(90.0, 26.0)
	sugar_label.add_theme_font_size_override("font_size", 34)
	sugar_label.add_theme_color_override("font_color", Color("ffd166"))
	sugar_label.add_theme_color_override("font_outline_color", Color("4a2a0b"))
	sugar_label.add_theme_constant_override("outline_size", 8)

	get_tree().current_scene.add_child(sugar_label)
	sugar_label.scale = Vector2(0.72, 0.72)

	var tween := sugar_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		sugar_label,
		"position",
		sugar_label.position + Vector2(0.0, -90.0),
		1.0
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		sugar_label,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		sugar_label,
		"modulate:a",
		0.0,
		0.42
	).set_delay(0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(sugar_label.queue_free)

## Supports gaining enough EXP for multiple levels in one reward.
func check_level_up() -> void:
	while building_level < 5:

		var required_exp: int = get_exp_required()

		if current_exp < required_exp:
			break

		current_exp -= required_exp

		increase_level()

	
func _update_territory_radius() -> void:

	#territory_radius = building_level
	match building_level:
		1:
			territory_radius = 1

		2, 3:
			territory_radius = 2

		4, 5:
			territory_radius = 3
func _ready() -> void:

	add_to_group("buildings")


	if data == null:
		push_error(
			"BuildingData missing on: "
			+ name
		)

		return

	_update_territory_radius()
	_update_building_income()
	make_neutral()
	_refresh_exp_bar()


## Rebuilds the meter so one segment always represents one required EXP.
func _refresh_exp_bar(animate_fill: bool = false) -> void:
	if exp_segments == null:
		return

	for child: Node in exp_segments.get_children():
		exp_segments.remove_child(child)
		child.queue_free()

	var required_exp: int = get_exp_required()
	var segment_count: int = required_exp if required_exp > 0 else 5
	var filled_count: int = mini(current_exp, required_exp)

	if building_level >= 5:
		filled_count = segment_count

	var segment_gap: float = 5.0
	exp_segments.add_theme_constant_override("separation", int(segment_gap))
	var available_width := 124.0 - float((segment_count - 1)) * segment_gap
	var segment_width := available_width / float(segment_count)

	for index: int in range(segment_count):
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(segment_width, 12.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_color: Color = (
			Color("ffd166")
			if index < filled_count
			else Color("202838")
		)
		var segment_style := StyleBoxFlat.new()
		segment_style.bg_color = segment_color
		segment_style.border_color = (
			Color("fff0a8")
			if index < filled_count
			else Color("596579")
		)
		segment_style.set_border_width_all(1)
		segment_style.set_corner_radius_all(3)
		segment.add_theme_stylebox_override("panel", segment_style)

		exp_segments.add_child(segment)

		if animate_fill and index < filled_count:
			segment.modulate = Color(1.35, 1.35, 1.35, 1.0)
			segment.scale = Vector2(0.75, 1.0)
			segment.pivot_offset = segment.custom_minimum_size * 0.5
			var tween := segment.create_tween()
			tween.set_parallel(true)
			tween.tween_property(segment, "modulate", Color.WHITE, 0.22)
			tween.tween_property(segment, "scale", Vector2.ONE, 0.22).set_trans(
				Tween.TRANS_BACK
			).set_ease(Tween.EASE_OUT)


# ============================================================
# STARTING TOWN CHECK
# ============================================================

## Keeps authored starting-location restrictions in the town data.
func can_be_starting_base_for(
	tribe: TribeData
) -> bool:

	if tribe == null:
		return false


	return (
		tribe.tribe_id
		in allowed_starting_tribe_ids
	)


# ============================================================
# NEUTRAL
# ============================================================

func make_neutral() -> void:

	owner_id = -1
	visual_tribe = null


	if sprite != null:
		sprite.texture = data.neutral_texture

	if exp_backdrop != null:
		exp_backdrop.hide()


# ============================================================
# OWNERSHIP
# ============================================================

func set_player_owner(
	new_owner_id: int
) -> void:

	owner_id = new_owner_id

	if exp_backdrop != null:
		exp_backdrop.visible = owner_id != -1


# ============================================================
# VISUALS
# ============================================================

## Swaps only this town's art to the owning tribe's building texture.
func apply_visual_theme(
	tribe: TribeData
) -> void:

	if tribe == null:
		return


	if tribe.visuals == null:
		return


	visual_tribe = tribe


	var building_type: String = (
		data.building_type
	)


	if not tribe.visuals.building_textures.has(
		building_type
	):
		push_warning(
			"No "
			+ building_type
			+ " texture for tribe "
			+ tribe.tribe_name
		)

		return


	sprite.texture = (
		tribe.visuals.building_textures[
			building_type
		]
	)


# ============================================================
# CONQUER
# ============================================================

func conquer(
	player: PlayerState
) -> void:

	if player == null:
		return


	set_player_owner(
		player.player_id
	)


	# ONLY THIS BUILDING CHANGES APPEARANCE.
	apply_visual_theme(
		player.tribe
	)


# ============================================================
# RECRUITMENT
# ============================================================

## Spawns the town-specific recruitment popup near the selected building.
func open_recruitment_ui() -> void:

	var new_ui = (
		recruitment_ui.instantiate()
	)


	get_tree().current_scene.add_child(
		new_ui
	)


	new_ui.global_position = (
		global_position
		+ Vector2(0, -120)
	)


	new_ui.setup(
		self
	)
