class_name Building
extends Area2D


# ============================================================
# IDENTITY
# ============================================================

var building_id: int = -1
var current_cell: Vector2i


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

func _update_building_income():
	
	#territory_radius = building_level
	match building_level:
		1, 2:
			by_turn_sugar = 2

		3, 4:
			by_turn_sugar = 5

		5:
			by_turn_sugar = 8

func increase_level() -> void:

	if building_level >= 5:
		return

	building_level += 1

	_update_territory_radius()
	_update_building_income()

	level_changed.emit(
		self
	)
	
	
func _update_territory_radius() -> void:

	#territory_radius = building_level
	match building_level:
		1, 2:
			territory_radius = 1

		3, 4:
			territory_radius = 2

		5:
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


# ============================================================
# STARTING TOWN CHECK
# ============================================================

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


# ============================================================
# OWNERSHIP
# ============================================================

func set_player_owner(
	new_owner_id: int
) -> void:

	owner_id = new_owner_id


# ============================================================
# VISUALS
# ============================================================

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
