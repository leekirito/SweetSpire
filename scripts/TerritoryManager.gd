class_name TerritoryManager
extends Node2D

## Tracks town claims, binds resources to those claims, and draws territory.
## Existing claims keep priority when town ranges overlap.





@onready var board_manager: BoardManager = (
	$"../BoardManager"
)



@export_group("Territory Visuals")

## Master switch for territory drawing, including fill.
@export var show_territory_borders: bool = true
## Draw translucent ownership fill inside the territory outline.
@export var show_territory_fill: bool = true

## Reserved neutral color; current territory drawing does not use this field.
@export var neutral_border_color: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)

## Main territory outline thickness in world pixels.
@export_range(1.0, 16.0, 0.5) var border_width: float = 4.0

@export var border_shadow_color: Color = Color(
	0.0,
	0.0,
	0.0,
	0.8
)

## Additional thickness of the outline's shadow.
@export_range(0.0, 12.0, 0.5) var border_shadow_extra_width: float = 2.5

## Opacity of the ownership fill.
@export_range(0.0, 0.5, 0.01) var territory_fill_alpha: float = 0.10
## Opacity of the outline highlight.
@export_range(0.0, 1.0, 0.05) var border_highlight_alpha: float = 0.45


# Cell -> Building ID
var cell_to_building_id: Dictionary[Vector2i,int] = {}


# Building ID -> Building
var buildings_by_id: Dictionary[int,Building] = {}

# Presentation uses the viewer's remembered claims, never another seat's live borders.
var display_claims: Dictionary = {}
var has_display_claims := false

## Install the host's filtered claim table without recomputing overlap priority.
func apply_known_claims(rows: Array, buildings: Array[Building]) -> void:
	buildings_by_id.clear()
	cell_to_building_id.clear()
	for building: Building in buildings:
		buildings_by_id[building.building_id] = building
		building.territory_cells.clear()
	for row: Dictionary in rows:
		var cell := LanCatalog.cell(row.cell)
		var town_id := int(row.town)
		if town_id == -1:
			continue
		cell_to_building_id[cell] = town_id
		var town: Building = buildings_by_id.get(town_id)
		if town != null:
			town.territory_cells.append(cell)
	queue_redraw()

## Detach presentation data from the changing per-seat memory dictionaries.
func set_display_claims(claims: Dictionary) -> void:
	if not has_display_claims or display_claims != claims:
		has_display_claims = true
		display_claims = claims.duplicate(true)
		queue_redraw()



func _ready() -> void:
	z_index = 1
	queue_redraw()
## Ranges may overlap. The lookup remembers the first active town to reach a cell.
func rebuild_territories(buildings: Array[Building]) -> void:
	buildings_by_id.clear()
	for building: Building in buildings:
		building.territory_cells.clear()
		buildings_by_id[building.building_id] = building
		if building.owner_id != -1:
			building.territory_cells = get_territory_cells(
				building.current_cell, building.territory_radius
			)

	# Keep prior claims rather than recalculating priority from registry order.
	for cell: Vector2i in cell_to_building_id.keys():
		var building: Building = buildings_by_id.get(cell_to_building_id[cell])
		if building == null or building.owner_id == -1 or cell not in building.territory_cells:
			cell_to_building_id.erase(cell)
	for building: Building in buildings:
		for cell: Vector2i in building.territory_cells:
			if not cell_to_building_id.has(cell):
				cell_to_building_id[cell] = building.building_id
	queue_redraw()

## Returns existing map cells within a square radius, regardless of terrain type.
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



## Existing resource claims belong to their town, not whichever range overlaps later.
func bind_resources_to_territories(resources: Array[Resources]) -> void:
	for resource: Resources in resources:
		var building: Building = buildings_by_id.get(resource.controlling_building_id)
		if building == null or building.owner_id == -1:
			building = buildings_by_id.get(get_building_id_at_cell(resource.current_cell))
		if building == null or building.owner_id == -1:
			resource.set_controlling_building(-1)
			resource.set_player_owner(-1)
		else:
			resource.set_controlling_building(building.building_id)
			resource.set_player_owner(building.owner_id)


## Activates a newly captured town's range and transfers its existing claims.
func update_resources_for_building(building: Building, resources: Array[Resources]) -> void:
	if building == null:
		return
	buildings_by_id[building.building_id] = building
	var buildings: Array[Building] = []
	buildings.assign(buildings_by_id.values())
	rebuild_territories(buildings)
	bind_resources_to_territories(resources)

## Returns the claiming town ID, or -1 for an unclaimed cell.
func get_building_id_at_cell(
	cell: Vector2i
) -> int:

	return cell_to_building_id.get(
		cell,
		-1
	)



func _draw() -> void:
	if not show_territory_borders or board_manager == null or board_manager.tile_map_layer == null:
		return
	var half_size := Vector2(board_manager.tile_map_layer.tile_set.tile_size) / 2.0
	var groups: Dictionary = {}
	var game := get_node_or_null("../MatchManager") as MatchManager
	if game == null:
		return
	var claims := display_claims
	if not has_display_claims:
		# Before the first fog view exists, reveal no authoritative ownership.
		return
	for cell: Vector2i in claims:
		var row: Dictionary = claims[cell]
		var owner := int(row.owner)
		if owner == -1:
			continue
		var key := Vector2i(int(row.town), owner)
		if not groups.has(key):
			groups[key] = []
		groups[key].append(cell)
	for key: Vector2i in groups:
		var player := game.get_player(key.y)
		if player == null or player.tribe == null:
			continue
		var cells: Array = groups[key]
		if show_territory_fill:
			_draw_claim_fill(cells, half_size, player.tribe.territory_color)
	for key: Vector2i in groups:
		var player := game.get_player(key.y)
		if player != null and player.tribe != null:
			_draw_building_border(groups[key], half_size, player.tribe.territory_color)

## Draw a remembered claim set without consulting live town level or ownership.
func _draw_claim_fill(cells: Array, half_size: Vector2, territory_color: Color) -> void:
	var fill_color := territory_color
	fill_color.a = territory_fill_alpha
	for cell: Vector2i in cells:
		var center := to_local(board_manager.cell_to_world(cell))
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -half_size.y), center + Vector2(half_size.x, 0.0),
			center + Vector2(0.0, half_size.y), center + Vector2(-half_size.x, 0.0)
		]), fill_color)
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

	# Fine highlight keeps the border readable over bright biome tiles.
	var highlight := color.lightened(0.35)
	highlight.a = border_highlight_alpha
	draw_line(
		from,
		to,
		highlight,
		maxf(1.0, border_width * 0.3),
		true
	)

## Draws only exposed diamond edges so adjacent territory cells share no internal border.
func _draw_building_border(
	cells: Array,
	half_size: Vector2,
	border_color: Color
) -> void:

	var territory_set: Dictionary[Vector2i,bool] = {}


	for cell: Vector2i in cells:

		territory_set[
			cell
		] = true


	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.UP,
		Vector2i.DOWN
	]


	for cell: Vector2i in cells:

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
