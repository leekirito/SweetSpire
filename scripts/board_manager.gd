class_name BoardManager
extends Node2D

@export_group("Tilemap")

@export var tile_map_layer: TileMapLayer
@export var tile_map_overlay: TileMapLayer
@export var buildings_tile: TileMapLayer

@export var solid_custom_data_name: String = "solid"
@export var water_custom_data_name: String = "water"


@export_group("Obstacles")

@export var obstacle_layers: Array[TileMapLayer]
@export var extra_solid_cells: Array[Vector2i] = []


@export_group("Overlay")

@export var movement_source_id: int = 2
@export var attack_source_id: int = 0

@export var movement_atlas_coordinate: Vector2i = Vector2i.ZERO
@export var attack_atlas_coordinate: Vector2i = Vector2i.ZERO

@export_group("Debug")

@export var debug_draw: bool = true
@export var debug_show_coordinates: bool = true

@export var cell_border_color: Color = Color(
	0.2,
	0.5,
	0.9,
	0.5
)

@export var solid_color: Color = Color(
	0.8,
	0.2,
	0.2,
	0.35
)

@export var coordinate_offset: Vector2 = Vector2(-20, 5)
@export var coordinate_font_size: int = 16


signal move_started(
	unit_id: int,
	target_cell: Vector2i
)

signal move_finished(
	unit_id: int,
	final_cell: Vector2i
)


# BOARD DATA

var astar_grid := AStarGrid2D.new()

# Cell -> Unit ID
var occupied_cells: Dictionary[Vector2i, int] = {}


var building_occupied_cells: Dictionary[Vector2i, int] = {}

var resources_occupied_cells: Dictionary[Vector2i, int] = {}
var water_cells: Dictionary[Vector2i, bool] = {}
var structure_manager: StructureManager
@export var ocean_source_ids: Array[int] = [5]

func is_ocean(cell: Vector2i) -> bool:
	return tile_map_layer.get_cell_source_id(cell) in ocean_source_ids


var last_cursor_cell := Vector2i(
	999999,
	999999
)

var default_range_pattern := RangePattern.new()

@onready var cursor: TileMapLayer = %Cursor

# SETUP

func _ready() -> void:
	_setup_grid()

	queue_redraw()


## Mirrors the authored TileMap into the runtime navigation and collision grid.
func _setup_grid() -> void:
	if tile_map_layer == null:
		push_error("BoardManager has no TileMapLayer.")
		return

	if tile_map_layer.tile_set == null:
		push_error("Board TileMapLayer has no TileSet.")
		return

	var tile_set: TileSet = tile_map_layer.tile_set

	astar_grid.region = tile_map_layer.get_used_rect()

	astar_grid.cell_size = Vector2(
		tile_set.tile_size
	)

	astar_grid.cell_shape = _cell_shape_from_tileset(
		tile_set
	)

	astar_grid.diagonal_mode = (
		AStarGrid2D.DIAGONAL_MODE_NEVER
	)

	astar_grid.default_compute_heuristic = (
		AStarGrid2D.HEURISTIC_MANHATTAN
	)

	astar_grid.default_estimate_heuristic = (
		AStarGrid2D.HEURISTIC_MANHATTAN
	)

	astar_grid.update()

	_refresh_solid_cells()


func _cell_shape_from_tileset(
	tile_set: TileSet
) -> AStarGrid2D.CellShape:

	if tile_set.tile_shape != TileSet.TILE_SHAPE_ISOMETRIC:
		return AStarGrid2D.CELL_SHAPE_SQUARE

	match tile_set.tile_layout:

		TileSet.TILE_LAYOUT_DIAMOND_RIGHT:
			return AStarGrid2D.CELL_SHAPE_ISOMETRIC_RIGHT

		TileSet.TILE_LAYOUT_DIAMOND_DOWN:
			return AStarGrid2D.CELL_SHAPE_ISOMETRIC_DOWN

		_:
			return AStarGrid2D.CELL_SHAPE_ISOMETRIC_RIGHT


## Combines tile metadata, obstacle layers, and manual overrides into one blocked-cell map.
func _refresh_solid_cells() -> void:
	var rect: Rect2i = astar_grid.region
	water_cells.clear()

	var has_solid_data: bool = _has_custom_data_layer(
		tile_map_layer.tile_set,
		solid_custom_data_name
	)
	var has_water_data: bool = _has_custom_data_layer(
		tile_map_layer.tile_set,
		water_custom_data_name
	)

	# Ground


	for y in range(
		rect.position.y,
		rect.end.y
	):
		for x in range(
			rect.position.x,
			rect.end.x
		):
			var cell := Vector2i(x, y)

			var tile_data: TileData = (
				tile_map_layer.get_cell_tile_data(
					cell
				)
			)

			# No ground = blocked.
			if tile_data == null:
				astar_grid.set_point_solid(
					cell,
					true
				)
				continue

			var solid: bool = false
			var water: bool = false

			if has_water_data:
				water = bool(
					tile_data.get_custom_data(
						water_custom_data_name
					)
				)
				if water:
					water_cells[cell] = true

			if has_solid_data:
				solid = bool(
					tile_data.get_custom_data(
						solid_custom_data_name
					)
				)

			# Water is capability-dependent, so it must not become a universal
			# AStar obstacle. A water unit may enter it while land units cannot.
			astar_grid.set_point_solid(
				cell,
				solid and not water
			)

	# Obstacle TileMaps


	for obstacle_layer: TileMapLayer in obstacle_layers:

		if obstacle_layer == null:
			continue

		for obstacle_cell: Vector2i in obstacle_layer.get_used_cells():

			var world_pos: Vector2 = (
				obstacle_layer.to_global(
					obstacle_layer.map_to_local(
						obstacle_cell
					)
				)
			)

			var ground_cell: Vector2i = (
				cell_from_world(
					world_pos
				)
			)

			if astar_grid.is_in_boundsv(
				ground_cell
			):
				astar_grid.set_point_solid(
					ground_cell,
					true
				)

	# Manual blocked cells

	for cell: Vector2i in extra_solid_cells:

		if astar_grid.is_in_boundsv(cell):
			astar_grid.set_point_solid(
				cell,
				true
			)


func _has_custom_data_layer(
	tile_set: TileSet,
	layer_name: String
) -> bool:

	for i in range(
		tile_set.get_custom_data_layers_count()
	):
		if (
			tile_set.get_custom_data_layer_name(i)
			== layer_name
		):
			return true

	return false


# COORDINATES

## Converts scene-space positions to the single board coordinate system used by gameplay.
func cell_from_world(
	world_position: Vector2
) -> Vector2i:

	return tile_map_layer.local_to_map(
		tile_map_layer.to_local(
			world_position
		)
	)


func cell_to_world(
	cell: Vector2i
) -> Vector2:

	return tile_map_layer.to_global(
		tile_map_layer.map_to_local(
			cell
		)
	)

# UNIT REGISTRATION

func get_building_id_at_world(
	world_position: Vector2
) -> int:

	var cell := cell_from_world(
		world_position
	)

	return building_occupied_cells.get(
		cell,
		-1
	)
	
func get_resource_id_at_world(
	world_position: Vector2
) -> int:

	var cell := cell_from_world(
		world_position
	)

	return resources_occupied_cells.get(
		cell,
		-1
	)

## Snaps a unit to its cell and records exclusive occupancy.
func register_unit(unit: Unit) -> void:
	var cell: Vector2i = cell_from_world(
		unit.global_position
	)

	unit.current_cell = cell
	unit.target_cell = cell

	unit.global_position = cell_to_world(
		cell
	)

	occupied_cells[cell] = unit.unit_id
	
func register_building(building: Building) -> void:
	var cell: Vector2i = cell_from_world(
		building.global_position
	)

	building.current_cell = cell

	building.global_position = cell_to_world(
		cell
	)

	building_occupied_cells[cell] = building.building_id

func register_resource(
	resource: Resources
) -> void:

	var cell: Vector2i = cell_from_world(
		resource.global_position
	)


	resource.current_cell = cell
	resource.set_biome_from_source_id(
		tile_map_layer.get_cell_source_id(cell)
	)


	resource.global_position = cell_to_world(
		cell
	)


	resources_occupied_cells[
		cell
	] = resource.resource_instance_id


## Maps authored ground sources to the four visual land biomes.
func get_biome_name(cell: Vector2i) -> String:
	match tile_map_layer.get_cell_source_id(cell):
		4, 23:
			return "KAMOTE"
		3, 24:
			return "MALAGKIT"
		26:
			return "SWEETSPIRE"
		39:
			return "SABA"
		25:
			return "WATER"
		_:
			return "NEUTRAL"

func unregister_unit(unit: Unit) -> void:
	if occupied_cells.get(
		unit.current_cell,
		-1
	) == unit.unit_id:

		occupied_cells.erase(
			unit.current_cell
		)
func get_resource_id_at_cell(
	cell: Vector2i
) -> int:

	return resources_occupied_cells.get(
		cell,
		-1
	)


func is_cell_on_map(
	cell: Vector2i
) -> bool:

	if not astar_grid.is_in_boundsv(
		cell
	):
		return false


	return (
		tile_map_layer.get_cell_source_id(
			cell
		)
		!= -1
	)
func get_unit_id_at_cell(
	cell: Vector2i
) -> int:

	return occupied_cells.get(
		cell,
		-1
	)


func get_unit_id_at_world(
	world_position: Vector2
) -> int:

	var cell: Vector2i = cell_from_world(
		world_position
	)

	return get_unit_id_at_cell(
		cell
	)
# BLOCKING

func is_cell_blocked(
	cell: Vector2i
) -> bool:

	if not astar_grid.is_in_boundsv(cell):
		return true

	return astar_grid.is_point_solid(
		cell
	)


## Applies terrain capabilities without baking unit-specific rules into AStar.
func is_cell_blocked_for_unit(cell: Vector2i, unit: Unit) -> bool:
	if not astar_grid.is_in_boundsv(cell):
		return true
	if unit == null:
		return is_cell_blocked(cell)
	if unit.ignores_terrain_blocking:
		return false
	if is_cell_blocked(cell):
		return true
	var is_water := water_cells.has(cell)
	if is_water:
		if structure_manager != null and structure_manager.structures.has(cell):
			var structure: Structure = structure_manager.structures[cell]
			if structure.data.converts_to_boat and not structure_manager.can_use_dock(cell, unit.owner_id):
				return true
		if not unit.can_traverse_water and unit.can_traverse_land and structure_manager != null:
			var delta := cell - unit.current_cell
			if absi(delta.x) + absi(delta.y) == 1 and structure_manager.can_use_dock(cell, unit.owner_id):
				return false
		return not unit.can_traverse_water
	return not unit.can_traverse_land

# RANGE

## Returns cells inside square range that are not blocked by terrain or line of sight.
func get_square_tiles(
	tile_range: int,
	center: Vector2i
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = []

	for x in range(
		center.x - tile_range,
		center.x + tile_range + 1
	):
		for y in range(
			center.y - tile_range,
			center.y + tile_range + 1
		):

			var cell := Vector2i(
				x,
				y
			)

			if cell == center:
				continue

			if is_cell_blocked(cell):
				continue

			if not has_clear_path(
				center,
				cell
			):
				continue

			tiles.append(
				cell
			)

	return tiles
func unregister_resource(
	resource: Resources
) -> void:

	if resource == null:
		return


	if (
		resources_occupied_cells.get(
			resource.current_cell,
			-1
		)
		== resource.resource_instance_id
	):

		resources_occupied_cells.erase(
			resource.current_cell
		)

## Samples the straight line between cells and prevents passing through blocked corners.
func has_clear_path(
	start: Vector2i,
	target: Vector2i,
	movement_unit: Unit = null
) -> bool:

	var difference: Vector2i = (
		target - start
	)

	var steps: int = maxi(
		abs(difference.x),
		abs(difference.y)
	)

	if steps == 0:
		return true

	var previous_cell: Vector2i = start

	for i in range(
		1,
		steps + 1
	):

		var t: float = (
			float(i)
			/ float(steps)
		)

		var cell := Vector2i(
			roundi(
				lerpf(
					float(start.x),
					float(target.x),
					t
				)
			),
			roundi(
				lerpf(
					float(start.y),
					float(target.y),
					t
				)
			)
		)

		if cell != target:
			if _is_path_cell_blocked(cell, movement_unit):
				return false

		# Prevent cutting through diagonal corners.
		if (
			cell.x != previous_cell.x
			and cell.y != previous_cell.y
		):
			var side_x := Vector2i(
				cell.x,
				previous_cell.y
			)

			var side_y := Vector2i(
				previous_cell.x,
				cell.y
			)

			if (
				_is_path_cell_blocked(side_x, movement_unit)
				or _is_path_cell_blocked(side_y, movement_unit)
			):
				return false

		previous_cell = cell

	return true


func _is_path_cell_blocked(cell: Vector2i, movement_unit: Unit) -> bool:
	if movement_unit != null:
		if movement_unit.is_embarked and not water_cells.has(cell):
			return true
		if not movement_unit.can_traverse_water and water_cells.has(cell):
			return true
		return is_cell_blocked_for_unit(cell, movement_unit)
	return is_cell_blocked(cell)


## Filters geometric range to destinations not currently occupied by another unit.
func get_movement_tiles(
	unit: Unit
) -> Array[Vector2i]:

	var tiles: Array[Vector2i] = get_pattern_tiles(
		unit.movement_pattern,
		unit.unit_walk_range,
		unit.walk_base_dimensions_override,
		unit.walk_exact_dimensions_override,
		unit.current_cell,
		unit
	)

	var available_tiles: Array[Vector2i] = []

	for tile: Vector2i in tiles:

		if occupied_cells.has(tile):
			continue

		available_tiles.append(
			tile
		)

	return available_tiles


func get_attack_tiles(
	unit: Unit
) -> Array[Vector2i]:

	return get_pattern_tiles(
		unit.attack_pattern,
		unit.attack_range,
		unit.attack_base_dimensions_override,
		unit.attack_exact_dimensions_override,
		unit.current_cell
	)


## Converts a reusable shape resource into legal board cells.
func get_pattern_tiles(
	pattern: RangePattern,
	expansion: int,
	base_dimensions_override: Vector2i,
	exact_dimensions_override: Vector2i,
	center: Vector2i,
	movement_unit: Unit = null
) -> Array[Vector2i]:
	var selected_pattern: RangePattern = pattern if pattern != null else default_range_pattern
	var tiles: Array[Vector2i] = []

	for offset: Vector2i in selected_pattern.get_offsets(
		expansion,
		base_dimensions_override,
		exact_dimensions_override
	):
		var cell: Vector2i = center + offset
		if (is_cell_blocked_for_unit(cell, movement_unit) if movement_unit != null else is_cell_blocked(cell)):
			continue
		if not has_clear_path(center, cell, movement_unit):
			continue
		tiles.append(cell)

	return tiles
# MOVEMENT VALIDATION

func can_move_to(
	unit: Unit,
	target_cell: Vector2i
) -> bool:

	if unit == null:
		return false

	if unit.current_cell == target_cell:
		return false

	if is_cell_blocked_for_unit(target_cell, unit):
		return false

	if occupied_cells.has(target_cell):
		return false

	var valid_tiles: Array[Vector2i] = (
		get_movement_tiles(unit)
	)

	return target_cell in valid_tiles

# AUTHORITATIVE BOARD CHANGE

## Updates occupancy immediately; visual movement is deliberately handled separately.
func commit_unit_move(
	unit: Unit,
	target_cell: Vector2i
) -> void:

	occupied_cells.erase(
		unit.current_cell
	)

	unit.current_cell = target_cell
	unit.target_cell = target_cell

	occupied_cells[target_cell] = (
		unit.unit_id
	)

# VISUAL MOVEMENT

## Tweens a committed move and exposes start/finish signals for UI and turn safety.
func animate_unit_move(
	unit: Unit,
	start_world_position: Vector2,
	target_cell: Vector2i
) -> void:

	unit.is_animating = true

	move_started.emit(
		unit.unit_id,
		target_cell
	)

	var target_world_position: Vector2 = (
		cell_to_world(
			target_cell
		)
	)

	# The authoritative cell has already changed,
	# but visually start from the old position.
	unit.global_position = start_world_position

	var distance: float = (
		start_world_position.distance_to(
			target_world_position
		)
	)

	var duration: float = (
		distance
		/ unit.pixels_per_second
	)

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_LINEAR
	)

	tween.tween_property(
		unit,
		"global_position",
		target_world_position,
		duration
	)

	await tween.finished

	unit.global_position = target_world_position
	unit.is_animating = false

	move_finished.emit(
		unit.unit_id,
		target_cell
	)

# OVERLAY

func clear_overlay() -> void:
	tile_map_overlay.clear()


func highlight_movement(
	unit: Unit
) -> void:

	var tiles: Array[Vector2i] = (
		get_movement_tiles(unit)
	)

	for tile: Vector2i in tiles:
		tile_map_overlay.set_cell(
			tile,
			movement_source_id,
			movement_atlas_coordinate,
			0
		)


func highlight_attack_cell(
	cell: Vector2i
) -> void:

	tile_map_overlay.set_cell(
		cell,
		attack_source_id,
		attack_atlas_coordinate,
		0
	)
# CURSOR

func _input(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return

	var mouse_cell: Vector2i = (
		cell_from_world(
			get_global_mouse_position()
		)
	)

	if mouse_cell == last_cursor_cell:
		return

	cursor.erase_cell(
		last_cursor_cell
	)

	cursor.set_cell(
		mouse_cell,
		1,
		Vector2i.ZERO,
		0
	)

	last_cursor_cell = mouse_cell

# DEBUG

## Draws development-only cell coordinates and collision overlays.
func _draw() -> void:
	if not debug_draw:
		return

	var rect: Rect2i = astar_grid.region

	var tile_size: Vector2 = Vector2(
		tile_map_layer.tile_set.tile_size
	)

	var half_size: Vector2 = (
		tile_size / 2.0
	)

	var font: Font = ThemeDB.fallback_font

	for y in range(
		rect.position.y,
		rect.end.y
	):
		for x in range(
			rect.position.x,
			rect.end.x
		):

			var cell := Vector2i(
				x,
				y
			)

			var center: Vector2 = to_local(
				cell_to_world(cell)
			)

			var solid: bool = (
				is_cell_blocked(cell)
			)

			if solid:
				var points := PackedVector2Array([
					center + Vector2(
						0,
						-half_size.y
					),
					center + Vector2(
						half_size.x,
						0
					),
					center + Vector2(
						0,
						half_size.y
					),
					center + Vector2(
						-half_size.x,
						0
					)
				])

				draw_colored_polygon(
					points,
					solid_color
				)

				draw_polyline(
					points,
					cell_border_color,
					1.0,
					true
				)

			if debug_show_coordinates:

				var coordinate_text: String = (
					"(%d, %d)"
					% [
						cell.x,
						cell.y
					]
				)

				draw_string(
					font,
					center + coordinate_offset,
					coordinate_text,
					HORIZONTAL_ALIGNMENT_LEFT,
					-1,
					coordinate_font_size
				)
