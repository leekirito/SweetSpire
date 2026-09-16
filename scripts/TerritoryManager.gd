class_name TerritoryManager
extends Node2D


# ============================================================
# REFERENCES
# ============================================================

@onready var board_manager: BoardManager = (
	$"../BoardManager"
)


# ============================================================
# DEBUG VISUALS
# ============================================================

@export_group("Territory Visuals")

@export var show_territory_borders: bool = true
@export var show_territory_fill: bool = true

@export var neutral_border_color: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)

@export var border_width: float = 8.0

@export var border_shadow_color: Color = Color(
	0.0,
	0.0,
	0.0,
	0.8
)

@export var border_shadow_extra_width: float = 5.0

@export var territory_fill_alpha: float = 0.15

# ============================================================
# TERRITORY DATA
# ============================================================

# Cell -> Building ID
var cell_to_building_id: Dictionary[Vector2i,int] = {}


# Building ID -> Building
var buildings_by_id: Dictionary[int,Building] = {}


# ============================================================
# TERRITORY SETUP
# ============================================================
func _ready() -> void:
	z_index = 1
	queue_redraw()
func rebuild_territories(
	buildings: Array[Building]
) -> void:

	cell_to_building_id.clear()

	buildings_by_id.clear()


	# Clear previous territory data.

	for building: Building in buildings:

		building.territory_cells.clear()

		buildings_by_id[
			building.building_id
		] = building


	# Generate territory for every town.

	for building: Building in buildings:

		_register_building_territory(
			building
		)


	queue_redraw()


func _register_building_territory(
	building: Building
) -> void:

	var cells: Array[Vector2i] = (
		get_territory_cells(
			building.current_cell,
			building.territory_radius
		)
	)


	for cell: Vector2i in cells:

		# Prevent two towns controlling
		# exactly the same tile.
		if cell_to_building_id.has(
			cell
		):

			var existing_id: int = (
				cell_to_building_id[
					cell
				]
			)


			if existing_id != building.building_id:

				push_warning(
					"Territory overlap at "
					+ str(cell)
					+ " between building "
					+ str(existing_id)
					+ " and "
					+ str(building.building_id)
				)

				continue


		cell_to_building_id[
			cell
		] = building.building_id


		building.territory_cells.append(
			cell
		)


# ============================================================
# TERRITORY CELLS
# ============================================================

func get_territory_cells(
	center: Vector2i,
	radius: int
) -> Array[Vector2i]:

	var cells: Array[Vector2i] = []


	for x in range(
		center.x - radius,
		center.x + radius + 1
	):

		for y in range(
			center.y - radius,
			center.y + radius + 1
		):

			var cell := Vector2i(
				x,
				y
			)


			if not board_manager.is_cell_on_map(
				cell
			):
				continue


			cells.append(
				cell
			)


	return cells


# ============================================================
# RESOURCE TERRITORIES
# ============================================================

func bind_resources_to_territories(
	resources: Array[Resources]
) -> void:

	for resource: Resources in resources:

		var building_id: int = (
			cell_to_building_id.get(
				resource.current_cell,
				-1
			)
		)


		resource.set_controlling_building(
			building_id
		)


		# Resource belongs to no town.
		if building_id == -1:

			resource.set_player_owner(
				-1
			)

			continue


		var building: Building = (
			buildings_by_id.get(
				building_id
			)
		)


		if building == null:

			resource.set_player_owner(
				-1
			)

			continue


		resource.set_player_owner(
			building.owner_id
		)


func update_resources_for_building(
	building: Building,
	resources: Array[Resources]
) -> void:

	if building == null:
		return


	for resource: Resources in resources:

		if (
			resource.controlling_building_id
			!= building.building_id
		):
			continue


		resource.set_player_owner(
			building.owner_id
		)


	queue_redraw()


# ============================================================
# LOOKUP
# ============================================================

func get_building_id_at_cell(
	cell: Vector2i
) -> int:

	return cell_to_building_id.get(
		cell,
		-1
	)


# ============================================================
# DRAW TERRITORY BORDERS
# ============================================================

func _draw() -> void:

	if not show_territory_borders:
		return


	if board_manager == null:
		return


	if board_manager.tile_map_layer == null:
		return


	var tile_size: Vector2 = Vector2(
		board_manager
		.tile_map_layer
		.tile_set
		.tile_size
	)


	var half_size: Vector2 = (
		tile_size / 2.0
	)


	for building: Building in buildings_by_id.values():

		# Neutral towns do not draw territory borders.
		if building.owner_id == -1:
			continue

		# Safety check.
		if building.visual_tribe == null:
			continue

		var border_color: Color = (
			building
				.visual_tribe
				.territory_color
		)

		_draw_building_border(
			building,
			half_size,
			border_color
		)
func _draw_territory_line(
	from: Vector2,
	to: Vector2,
	color: Color
) -> void:

	# Dark outline underneath.
	draw_line(
		from,
		to,
		border_shadow_color,
		border_width + border_shadow_extra_width,
		true
	)

	# Actual territory color.
	draw_line(
		from,
		to,
		color,
		border_width,
		true
	)

func _draw_building_border(
	building: Building,
	half_size: Vector2,
	border_color: Color
) -> void:

	var territory_set: Dictionary[Vector2i,bool] = {}


	for cell: Vector2i in building.territory_cells:

		territory_set[
			cell
		] = true


	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.DOWN
	]


	for cell: Vector2i in building.territory_cells:

		var center: Vector2 = to_local(
			board_manager.cell_to_world(
				cell
			)
		)


		for direction: Vector2i in directions:

			var neighbor: Vector2i = (
				cell + direction
			)


			# Internal edge.
			if territory_set.has(
				neighbor
			):
				continue


			var neighbor_center: Vector2 = (
				to_local(
					board_manager.cell_to_world(
						neighbor
					)
				)
			)


			var delta: Vector2 = (
				neighbor_center
				- center
			)


			_draw_exposed_edge(
				center,
				delta,
				half_size,
				border_color
			)


func _draw_exposed_edge(
	center: Vector2,
	neighbor_delta: Vector2,
	half_size: Vector2,
	border_color: Color
) -> void:

	var top := (
		center
		+ Vector2(
			0,
			-half_size.y
		)
	)

	var right := (
		center
		+ Vector2(
			half_size.x,
			0
		)
	)

	var bottom := (
		center
		+ Vector2(
			0,
			half_size.y
		)
	)

	var left := (
		center
		+ Vector2(
			-half_size.x,
			0
		)
	)


	if (
		neighbor_delta.x > 0
		and neighbor_delta.y < 0
	):

		_draw_territory_line(
			top,
			right,
			border_color
		)

		return


	if (
		neighbor_delta.x > 0
		and neighbor_delta.y > 0
	):

		_draw_territory_line(
			right,
			bottom,
			border_color
		)

		return


	if (
		neighbor_delta.x < 0
		and neighbor_delta.y > 0
	):

		_draw_territory_line(
			bottom,
			left,
			border_color
		)

		return


	_draw_territory_line(
		left,
		top,
		border_color
	)
