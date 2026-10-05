class_name FogOfWar
extends TileMapLayer

signal fog_updated
 
enum State { UNEXPLORED, EXPLORED, VISIBLE }
const CELL_SCENE: PackedScene = preload("res://scenes/fog/fog_cell.tscn")

@export var board: BoardManager
@export var game: MatchManager
## Starting vision at territory radius 1; each extra territory ring adds vision.
@export_range(0, 10, 1) var building_vision_radius: int = 2
@export_range(0.0, 1.0, 0.05) var transition_duration: float = 0.3
@export var unexplored_color := Color(0.055, 0.075, 0.12, 1.0)
@export var explored_color := Color(0.09, 0.13, 0.20, 0.58)
## Optional artwork fitted to each tile. Empty uses the polygon fog.
@export var fog_texture: Texture2D:
	set(value):
		fog_texture = value
		if is_node_ready():
			for cell: FogCell in fog_nodes.values():
				cell.set_fog_texture(value)

var explored_by_player: Dictionary = {}
var visible_by_player: Dictionary = {}
var fog_nodes: Dictionary[Vector2i, FogCell] = {}
var displayed_states: Dictionary[Vector2i, int] = {}
var viewing_player_id: int = -1
var initialized := false
var _elapsed := 0.0
var _refreshing := false

func _ready() -> void:
	z_index = 100
	y_sort_enabled = false
	collision_enabled = false
	navigation_enabled = false
	occlusion_enabled = false
	if board == null or game == null:
		push_error("FogOfWar requires Board and Game references.")
		return
	_build_layer()
	game.match_started.connect(_on_match_started)
	game.turn_started.connect(_on_turn_started)
	game.vision_sources_changed.connect(refresh)
	board.move_started.connect(_on_move_changed)
	board.move_finished.connect(_on_move_changed)
	game.technology_purchased.connect(_on_technology_changed)
	# Hide authored objects during setup, before the first player's view exists.
	for group: String in ["units", "buildings", "resources"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is CanvasItem:
				node.hide()

func _build_layer() -> void:
	var ground := board.tile_map_layer
	transform = ground.transform
	tile_set = TileSet.new()
	tile_set.tile_size = ground.tile_set.tile_size
	tile_set.tile_shape = ground.tile_set.tile_shape
	tile_set.tile_layout = ground.tile_set.tile_layout
	tile_set.tile_offset_axis = ground.tile_set.tile_offset_axis
	var source := TileSetScenesCollectionSource.new()
	var scene_id := source.create_scene_tile(CELL_SCENE)
	tile_set.add_source(source, 0)
	for cell: Vector2i in ground.get_used_cells():
		set_cell(cell, 0, Vector2i.ZERO, scene_id)
	update_internals()
	for child: Node in get_children():
		if child is FogCell:
			var cell := local_to_map(child.position)
			fog_nodes[cell] = child
			child.configure(Vector2(tile_set.tile_size), unexplored_color, explored_color, fog_texture)
			child.set_fog_state(State.UNEXPLORED, false, 0.0)
			displayed_states[cell] = State.UNEXPLORED

func _on_match_started() -> void:
	initialized = true
	refresh(true)

func _on_turn_started(_player_id: int, _round: int) -> void:
	# Never animate between player views: that would expose the previous view.
	refresh(true)

func _on_move_changed(_unit_id: int, _cell: Vector2i) -> void:
	refresh()

func _on_technology_changed(_player_id: int, _technology_id: String) -> void:
	refresh()

func _process(delta: float) -> void:
	if not initialized:
		return
	_elapsed += delta
	# Covers live Inspector range edits, ownership edits and structure changes.
	if _elapsed >= 0.1:
		_elapsed = 0.0
		refresh()
	# Moving enemy sprites are hidden according to their rendered cell too.
	_apply_unit_visibility()

func refresh(instant: bool = false) -> void:
	if not initialized or _refreshing:
		return
	_refreshing = true
	var next_views: Dictionary = {}
	for player: PlayerState in game.players:
		next_views[player.player_id] = {}
	for unit: Unit in game.units.values():
		if not next_views.has(unit.owner_id):
			continue
		var cells: Dictionary = next_views[unit.owner_id]
		cells[unit.current_cell] = true
		# These remain vision sources after the unit spends its turn actions.
		for cell: Vector2i in board.get_movement_vision_tiles(unit):
			cells[cell] = true
		for cell: Vector2i in board.get_attack_tiles(unit):
			cells[cell] = true
	for building: Building in game.buildings.values():
		var radius := building_vision_radius + maxi(0, building.territory_radius - 1)
		_reveal_building(next_views, building.owner_id, building.current_cell, radius)
	for structure: Structure in game.structure_manager.structures.values():
		var town := game.structure_manager.controlling_town(structure.current_cell)
		if town != null:
			# Outlying structures have no territory growth of their own.
			_reveal_building(next_views, town.owner_id, structure.current_cell, building_vision_radius)
	visible_by_player = next_views
	for player_id: int in next_views:
		var explored: Dictionary = explored_by_player.get(player_id, {})
		for cell: Vector2i in next_views[player_id]:
			if board.is_cell_on_map(cell):
				explored[cell] = true
		explored_by_player[player_id] = explored
	var switched := viewing_player_id != game.active_player_id
	viewing_player_id = game.active_player_id
	var view_changed := switched
	for cell: Vector2i in fog_nodes:
		var state := state_for(cell, viewing_player_id)
		if instant or switched or displayed_states.get(cell, -1) != state:
			fog_nodes[cell].set_fog_state(state, not (instant or switched), transition_duration)
			displayed_states[cell] = state
			view_changed = true
	_apply_entity_visibility()
	if view_changed:
		fog_updated.emit()
	_refreshing = false

func _reveal_building(views: Dictionary, player_id: int, center: Vector2i, radius: int) -> void:
	if not views.has(player_id):
		return
	var cells: Dictionary = views[player_id]
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell := center + Vector2i(x, y)
			if board.is_cell_on_map(cell):
				cells[cell] = true

func state_for(cell: Vector2i, player_id: int = -1) -> int:
	if player_id == -1:
		player_id = viewing_player_id
	if is_cell_visible(cell, player_id):
		return State.VISIBLE
	if is_cell_explored(cell, player_id):
		return State.EXPLORED
	return State.UNEXPLORED

func is_cell_visible(cell: Vector2i, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = viewing_player_id
	return visible_by_player.get(player_id, {}).has(cell)

func is_cell_explored(cell: Vector2i, player_id: int = -1) -> bool:
	if player_id == -1:
		player_id = viewing_player_id
	return explored_by_player.get(player_id, {}).has(cell)

func _apply_unit_visibility() -> void:
	for unit: Unit in game.units.values():
		var cell := board.cell_from_world(unit.global_position) if unit.is_animating else unit.current_cell
		unit.visible = is_cell_visible(cell)
		unit.refresh_tribe_outline(viewing_player_id)

func _apply_entity_visibility() -> void:
	_apply_unit_visibility()
	for building: Building in game.buildings.values():
		building.visible = is_cell_explored(building.current_cell)
	for resource: Resources in game.resources.values():
		# Constructed structures intentionally hide the resource underneath.
		resource.visible = is_cell_explored(resource.current_cell) and not game.structure_manager.structures.has(resource.current_cell)
	for structure: Structure in game.structure_manager.structures.values():
		structure.visible = is_cell_explored(structure.current_cell)
