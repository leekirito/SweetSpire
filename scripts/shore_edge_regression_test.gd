extends Node

var checks := 0
var failures := 0
const EDGE_CASES := [
	[BiomeChunk.ShoreEdge.TOP, Vector2i(7, 0), 5],
	[BiomeChunk.ShoreEdge.RIGHT, Vector2i(9, 7), 7],
	[BiomeChunk.ShoreEdge.BOTTOM, Vector2i(7, 9), 1],
	[BiomeChunk.ShoreEdge.LEFT, Vector2i(0, 7), 3],
]

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	var generator := BiomeMapGenerator.new()
	check(generator.prepare(), "Existing scenes remain valid: " + generator.last_error)
	var catalog := generator.catalog
	var originals := catalog.variants.duplicate(true)
	var coastal: Dictionary = {}
	for edge_case: Array in EDGE_CASES:
		var chunk := load(ChunkCatalog.SCENES[0]).instantiate() as BiomeChunk
		chunk.variant_id = "test_coast_%d" % edge_case[0]
		chunk.shore_edge = edge_case[0]
		var ground := chunk.get_node("Ground") as TileMapLayer
		ground.set_cell(edge_case[1], 6, Vector2i.ZERO)
		catalog.errors.clear()
		coastal[chunk.variant_id] = catalog._read_chunk(chunk)
		check(catalog.errors.is_empty(), "Declared lake edge validates: " + str(catalog.errors))
		catalog.variants[chunk.variant_id] = coastal[chunk.variant_id]
		for slot in 9:
			check(catalog.fits_slot(chunk.variant_id, slot) == (slot == int(edge_case[2])), "Each shore edge matches exactly one inward-facing side")
		chunk.shore_edge = BiomeChunk.ShoreEdge.NONE
		catalog.errors.clear()
		catalog._read_chunk(chunk)
		check(not catalog.errors.is_empty(), "Undeclared boundary lakes are rejected")
		chunk.shore_edge = (int(edge_case[0]) % 4) + 1
		catalog.errors.clear()
		catalog._read_chunk(chunk)
		check(not catalog.errors.is_empty(), "A lake on the wrong declared edge is rejected")
		chunk.shore_edge = edge_case[0]
		ground.set_cell(Vector2i.ZERO, 6, Vector2i.ZERO)
		catalog.errors.clear()
		catalog._read_chunk(chunk)
		check(not catalog.errors.is_empty(), "Coastal variants preserve land corners")
		chunk.free()
	var empty_coast := load(ChunkCatalog.SCENES[0]).instantiate() as BiomeChunk
	empty_coast.shore_edge = BiomeChunk.ShoreEdge.BOTTOM
	catalog.errors.clear()
	catalog._read_chunk(empty_coast)
	check(not catalog.errors.is_empty(), "Declared coast needs a painted lake on its edge")
	empty_coast.free()
	var offshore := load(ChunkCatalog.SCENES[0]).instantiate() as BiomeChunk
	offshore.shore_edge = BiomeChunk.ShoreEdge.TOP
	for cell: Vector2i in [Vector2i(6, 0), Vector2i(7, 0), Vector2i(8, 0), Vector2i(7, 1)]:
		offshore.get_node("Ground").set_cell(cell, 6, Vector2i.ZERO)
	catalog.errors.clear()
	catalog._read_chunk(offshore)
	check("needs adjacent walkable land for a dock" in "\n".join(catalog.errors), "Declared coastal lakes cannot lose land adjacency")
	offshore.free()
	# Force Saba players to use coastal scenes; other tribes can fill corners.
	catalog.variants = originals.duplicate(true)
	for id: String in catalog.ids_for("SABA"):
		catalog.variants.erase(id)
	catalog.variants.merge(coastal)
	catalog.signature = JSON.stringify(catalog.variants).sha256_text()
	var roster: Array = []
	for id in range(1, 5):
		roster.append({"player_id": id, "tribe_id": "saba"})
	for seed_value in 24:
		var manifest := generator.generate(seed_value, roster)
		check(not manifest.is_empty(), "All four coastal Saba players can be placed")
		if manifest.is_empty():
			continue
		check(generator.validate(manifest, roster), "Generated coasts validate")
		check(manifest == generator.generate(seed_value, roster), "Constrained placement remains seeded")
		var received: Dictionary = JSON.parse_string(JSON.stringify(manifest))
		check(generator.build(received, roster) == generator.build(manifest, roster), "Coast selections survive JSON replay")
		var built := generator.build(manifest, roster)
		var cells: Dictionary = {}
		for tile: Array in built.layers.Ground:
			cells[Vector2i(tile[0], tile[1])] = tile[2]
		for edge_case: Array in EDGE_CASES:
			var entry: Dictionary = manifest.chunks[edge_case[2]]
			check(entry.shore_edge == edge_case[0] and entry.player_id != -1, "Each player coast occupies its inward slot")
			var cell := Vector2i(entry.origin[0], entry.origin[1]) + Vector2i(edge_case[1])
			var direction: Vector2i = {1: Vector2i.UP, 2: Vector2i.RIGHT, 3: Vector2i.DOWN, 4: Vector2i.LEFT}[edge_case[0]]
			check(cells[cell] == 6 and cells[cell + direction] in [5, 6] and Rect2i(10, 10, 10, 10).has_point(cell + direction), "Painted lake directly faces Sweetspire water")
		var forged := manifest.duplicate(true)
		forged.chunks[1].variant = "test_coast_1"
		forged.chunks[1].shore_edge = BiomeChunk.ShoreEdge.TOP
		check(not generator.validate(forged, roster), "Clients reject an outward-facing variant")
		forged = manifest.duplicate(true)
		forged.chunks[1].shore_edge = BiomeChunk.ShoreEdge.NONE
		check(not generator.validate(forged, roster), "Clients reject forged shore metadata")
		forged = manifest.duplicate(true)
		forged.chunks[0].variant = "test_coast_3"
		forged.chunks[0].biome = "SABA"
		forged.chunks[0].shore_edge = BiomeChunk.ShoreEdge.BOTTOM
		check(not generator.validate(forged, roster), "Clients reject a coast in a corner slot")
	roster.append({"player_id": 5, "tribe_id": "saba"})
	check(generator.generate(1, roster).is_empty(), "Five coast-only players cannot fit four sides")
	check(not generator.last_error.is_empty(), "Impossible lobby reports a useful error")
	# A scarce coast-only tribe must still fit after an unrestricted player.
	for id: String in coastal:
		if id != "test_coast_3":
			catalog.variants.erase(id)
	catalog.signature = JSON.stringify(catalog.variants).sha256_text()
	roster = [{"player_id": 1, "tribe_id": "malagkit"}, {"player_id": 2, "tribe_id": "saba"}]
	for seed_value in 24:
		var manifest := generator.generate(seed_value, roster)
		check(not manifest.is_empty() and generator.validate(manifest, roster), "Backtracking fits the scarce shore slot")
		if manifest.is_empty():
			continue
		check(manifest.chunks[1].player_id == 2, "Restricted player always receives the matching side")
	# Without any unrestricted outer scenes, no corner can be filled.
	for id: String in catalog.variants.keys():
		if catalog.variants[id].biome != "SWEETSPIRE" and catalog.variants[id].shore_edge == BiomeChunk.ShoreEdge.NONE:
			catalog.variants.erase(id)
	check(generator.generate(1, [{"player_id": 1, "tribe_id": "saba"}]).is_empty(), "Missing corner content fails without selecting an invalid variant")
	print("SHORE EDGE REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
