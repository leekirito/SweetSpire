class_name ChunkCatalog
extends RefCounted

## Explicit catalog: exported games and peers use the same stable identifiers.
const SCENES: Array[String] = [
	"res://scenes/map/chunks/saba_grove.tscn",
	"res://scenes/map/chunks/saba_lagoon.tscn",
	"res://scenes/map/chunks/malagkit_terraces.tscn",
	"res://scenes/map/chunks/malagkit_pools.tscn",
	"res://scenes/map/chunks/kamote_ridge.tscn",
	"res://scenes/map/chunks/kamote_basin.tscn",
	"res://scenes/map/chunks/sweetspire_gardens.tscn",
	"res://scenes/map/chunks/sweetspire_sanctuary.tscn",
]
const SIZE := 10
const BIOMES := ["SABA", "MALAGKIT", "KAMOTE", "SWEETSPIRE"]
const LAND_SOURCES := {"SABA": [39], "MALAGKIT": [3, 24], "KAMOTE": [4, 23], "SWEETSPIRE": [26]}
const KINDS := ["town", "forest", "mountain", "fruit", "animal", "fish"]
const OUTER_BUDGET := {"town": 2, "forest": 3, "fruit": 3, "animal": 2, "mountain": 2, "fish": 2}
const CENTER_BUDGET := {"town": 1, "forest": 3, "fruit": 3, "animal": 2, "mountain": 2, "fish": 0}
const INWARD_EDGES := {1: BiomeChunk.ShoreEdge.BOTTOM, 3: BiomeChunk.ShoreEdge.LEFT, 5: BiomeChunk.ShoreEdge.TOP, 7: BiomeChunk.ShoreEdge.RIGHT}
var variants: Dictionary = {}
var errors: PackedStringArray = []
var signature: String = ""

func load_catalog(paths: Array[String] = SCENES) -> bool:
	variants.clear()
	errors.clear()
	for path: String in paths:
		var scene := load(path) as PackedScene
		if scene == null:
			errors.append("Cannot load chunk: " + path)
			continue
		var instance := scene.instantiate()
		var chunk := instance as BiomeChunk
		if chunk == null:
			errors.append("Chunk root must be BiomeChunk: " + path)
			instance.free()
			continue
		var data := _read_chunk(chunk)
		chunk.free()
		var id: String = data["id"]
		if id.is_empty() or variants.has(id):
			errors.append("Missing or duplicate variant ID: " + id)
		variants[id] = data
	for biome: String in BIOMES:
		if ids_for(biome).is_empty():
			errors.append("No variants for " + biome)
	# Include actual tile/entity data, not just a manually maintained version.
	signature = JSON.stringify(variants).sha256_text()
	return errors.is_empty()

func ids_for(biome: String, slot: int = -1) -> Array[String]:
	var result: Array[String] = []
	for id: String in variants:
		if variants[id]["biome"] == biome and (slot == -1 or fits_slot(id, slot)):
			result.append(id)
	result.sort()
	return result

func fits_slot(id: String, slot: int) -> bool:
	if not variants.has(id) or slot < 0 or slot > 8:
		return false
	var chunk: Dictionary = variants[id]
	if chunk.biome == "SWEETSPIRE":
		return slot == 8 and chunk.shore_edge == BiomeChunk.ShoreEdge.NONE
	if slot == 8:
		return false
	return chunk.shore_edge == BiomeChunk.ShoreEdge.NONE or chunk.shore_edge == INWARD_EDGES.get(slot, -1)

static func on_shore_edge(cell: Vector2i, edge: int) -> bool:
	# Corners touch a second seam, which must remain land.
	match edge:
		BiomeChunk.ShoreEdge.TOP:
			return cell.y == 0 and cell.x > 0 and cell.x < SIZE - 1
		BiomeChunk.ShoreEdge.RIGHT:
			return cell.x == SIZE - 1 and cell.y > 0 and cell.y < SIZE - 1
		BiomeChunk.ShoreEdge.BOTTOM:
			return cell.y == SIZE - 1 and cell.x > 0 and cell.x < SIZE - 1
		BiomeChunk.ShoreEdge.LEFT:
			return cell.x == 0 and cell.y > 0 and cell.y < SIZE - 1
	return false

func _read_chunk(chunk: BiomeChunk) -> Dictionary:
	var data := {"id": chunk.variant_id, "biome": chunk.biome_id, "revision": chunk.revision, "shore_edge": chunk.shore_edge, "layers": {}, "placements": []}
	if chunk.shore_edge not in BiomeChunk.ShoreEdge.values() or (chunk.biome_id == "SWEETSPIRE" and chunk.shore_edge != BiomeChunk.ShoreEdge.NONE):
		errors.append("Invalid Shore Edge (Sweetspire must use None): " + chunk.variant_id)
	var ground := chunk.get_node_or_null("Ground") as TileMapLayer
	if ground == null or ground.tile_set == null or chunk.biome_id not in BIOMES:
		errors.append("Invalid ground/biome: " + chunk.variant_id)
		return data
	for layer_name: String in ["Ground", "Decoration", "Obstacles"]:
		var layer := chunk.get_node_or_null(layer_name) as TileMapLayer
		var tiles: Array = []
		if layer != null:
			if layer.transform != Transform2D.IDENTITY or layer.tile_set != ground.tile_set:
				errors.append("Layers must share the ground TileSet and identity transform: " + chunk.variant_id)
			var cells := layer.get_used_cells()
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			for cell: Vector2i in cells:
				if not Rect2i(0, 0, SIZE, SIZE).has_point(cell) or layer.get_cell_tile_data(cell) == null:
					errors.append("Invalid tile in " + chunk.variant_id)
				var atlas := layer.get_cell_atlas_coords(cell)
				tiles.append([cell.x, cell.y, layer.get_cell_source_id(cell), atlas.x, atlas.y, layer.get_cell_alternative_tile(cell)])
		data["layers"][layer_name] = tiles
	var occupied: Dictionary = {}
	var budget: Dictionary = {"town": 0, "forest": 0, "fruit": 0, "animal": 0, "mountain": 0, "fish": 0}
	var start_count := 0
	var markers := chunk.get_node_or_null("Placements")
	if markers != null:
		for marker: Node in markers.get_children():
			if not marker is ChunkPlacement:
				errors.append("Use ChunkPlacement markers in " + chunk.variant_id)
				continue
			var cell := ground.local_to_map(chunk.to_local(marker.global_position))
			if occupied.has(cell) or not Rect2i(0, 0, SIZE, SIZE).has_point(cell) or marker.kind not in KINDS:
				errors.append("Overlapping or invalid placement in " + chunk.variant_id)
			occupied[cell] = marker.kind
			if budget.has(marker.kind):
				budget[marker.kind] += 1
			var tile := ground.get_cell_tile_data(cell)
			if tile == null or bool(tile.get_custom_data("water")) != (marker.kind == "fish"):
				errors.append("%s: %s at (%d,%d) requires %s." % [chunk.variant_id, marker.name, cell.x, cell.y, "water" if marker.kind == "fish" else "land"])
			if marker.starting_town:
				start_count += 1
				if marker.kind != "town" or cell != Vector2i(4, 4):
					errors.append("Starting town must be at (4,4): " + chunk.variant_id)
			data["placements"].append({"cell": [cell.x, cell.y], "kind": marker.kind, "start": marker.starting_town})
	data["placements"].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.cell[1] < b.cell[1] or (a.cell[1] == b.cell[1] and a.cell[0] < b.cell[0]))
	if start_count != (0 if chunk.biome_id == "SWEETSPIRE" else 1):
		errors.append("Wrong starting town count: " + chunk.variant_id)
	if budget != (CENTER_BUDGET if chunk.biome_id == "SWEETSPIRE" else OUTER_BUDGET):
		errors.append("Town/resource budget differs from other variants: " + chunk.variant_id)
	_validate_terrain(chunk, ground, occupied)
	return data

func _validate_terrain(chunk: BiomeChunk, ground: TileMapLayer, occupied: Dictionary) -> void:
	var center := chunk.biome_id == "SWEETSPIRE"
	var land: Dictionary = {}
	var obstacles := chunk.get_node_or_null("Obstacles") as TileMapLayer
	var coastal_lakes: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			var cell := Vector2i(x, y)
			var tile := ground.get_cell_tile_data(cell)
			if tile == null:
				errors.append("Ground must fill 10x10 cells: " + chunk.variant_id)
				continue
			var source := ground.get_cell_source_id(cell)
			var water := bool(tile.get_custom_data("water"))
			if source not in LAND_SOURCES[chunk.biome_id] and source not in [5, 6]:
				errors.append("Foreign biome tile: " + chunk.variant_id)
			# Mainland-facing shoreline can contain lake tiles for docks. The
			# inner ring stays ocean, so these bays never form a crossing.
			var boundary := x < 2 or y < 2 or x > 7 or y > 7
			var outer_edge := x == 0 or y == 0 or x == 9 or y == 9
			if center and boundary and source != 5 and not (outer_edge and source == 6):
				errors.append("Sweetspire requires a water boundary with an unbroken inner ocean ring: " + chunk.variant_id)
			if center and boundary and source == 6 and occupied.has(cell):
				errors.append("Keep shoreline lake tiles empty for docks: " + chunk.variant_id)
			if center and (x < 2 or y < 2 or x > 7 or y > 7) and obstacles != null and obstacles.get_cell_source_id(cell) != -1:
				errors.append("Keep Sweetspire's ocean boundary free of obstacles: " + chunk.variant_id)
			var blocked := bool(tile.get_custom_data("solid")) or (obstacles != null and obstacles.get_cell_source_id(cell) != -1)
			if occupied.has(cell) and blocked:
				errors.append("Placement is blocked: " + chunk.variant_id)
			if not water and not blocked and occupied.get(cell) != "mountain":
				land[cell] = true
			if not center and outer_edge:
				var coastal_lake := source == 6 and on_shore_edge(cell, chunk.shore_edge)
				if coastal_lake:
					coastal_lakes.append(cell)
				if (water and not coastal_lake) or blocked or occupied.has(cell):
					errors.append("%s: edge tile (%d,%d) must be clear land, or an empty lake on the declared Shore Edge (corners stay land)." % [chunk.variant_id, x, y])
	if not center and chunk.shore_edge != BiomeChunk.ShoreEdge.NONE and coastal_lakes.is_empty():
		errors.append("Paint at least one lake tile on the declared Shore Edge: " + chunk.variant_id)
	for cell: Vector2i in coastal_lakes:
		var adjacent_land := false
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if land.has(cell + step):
				adjacent_land = true
		if not adjacent_land:
			errors.append("%s: coastal lake (%d,%d) needs adjacent walkable land for a dock." % [chunk.variant_id, cell.x, cell.y])
	# All walkable land must connect to the start/objective without mountain technology.
	var visited: Dictionary = {}
	var pending: Array[Vector2i] = [Vector2i(4, 4)]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		if visited.has(cell) or not land.has(cell):
			continue
		visited[cell] = true
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			pending.append(cell + step)
	if visited.size() != land.size() or not visited.has(Vector2i(4, 4)):
		errors.append("Disconnected land/start in " + chunk.variant_id)
	if center:
		for cell: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]:
			if not land.has(cell) or occupied.has(cell):
				errors.append("Keep the 2x2 Sweetspire objective clear: " + chunk.variant_id)
	else:
		var nearby: Array = []
		for cell: Vector2i in occupied:
			if maxi(absi(cell.x - 4), absi(cell.y - 4)) == 1:
				nearby.append(occupied[cell])
		if "forest" not in nearby or "fruit" not in nearby or "animal" not in nearby:
			errors.append("Starting towns need nearby forest, fruit and animal: " + chunk.variant_id)
