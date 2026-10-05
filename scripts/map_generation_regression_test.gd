extends "res://scripts/map/map_bootstrap.gd"

var checks := 0
var failures := 0

func _enter_tree() -> void:
	GameSession.clear_players()
	GameSession.map_seed = 260926
	for id in [1, 2]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Player %d" % id
		player.tribe = load("res://scripts/data/Tribe/MALAGKIT_DATA.tres")
		player.sugars = 20
		player.unlock_technology(player.tribe.starting_technology.technology_id)
		GameSession.add_player(player)
	if "--replay" in OS.get_cmdline_user_args():
		var generator := BiomeMapGenerator.new()
		var roster := [{"player_id": 1, "tribe_id": "malagkit"}, {"player_id": 2, "tribe_id": "malagkit"}]
		GameSession.map_manifest = JSON.parse_string(JSON.stringify(generator.generate(GameSession.map_seed, roster)))
		GameSession.require_map_manifest = true
	super._enter_tree()

func _ready() -> void:
	super._ready()
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game := $MatchManager as MatchManager
	var board := $BoardManager as BoardManager
	var fog := $FogOfWar as FogOfWar
	check(setup_error.is_empty(), "Generated map assembles: " + setup_error)
	check(game.current_phase == MatchManager.Phase.PLAYER_TURN, "Generated match reaches first turn")
	check(game.units.size() == 2, "Duplicate tribes both spawn a starting unit")
	check(game.buildings.size() == 17, "Only the 17 authored chunk towns exist")
	check(board.tile_map_layer.get_used_cells().size() == 1024, "Full finite terrain exists")
	check(fog.initialized and fog.fog_nodes.size() == 1024, "Fog is built from generated terrain")
	check(board.astar_grid.region == Rect2i(-1, -1, 32, 32), "Navigation sees generated map bounds")
	check($WaterEffects.get_used_cells().size() == board.water_cells.size(), "Water effects and board agree")
	for start: Dictionary in manifest.get("starts", []):
		var town := game.get_building(int(start.building_id))
		check(town != null and town.owner_id == int(start.player_id), "Manifest town ID/ownership survives registration")
		check(board.get_biome_name(town.current_cell) == "MALAGKIT", "Same-tribe players each get matching terrain")
		check(town.current_cell == Vector2i(start.cell[0], start.cell[1]), "Manifest town cell survives registration")
		var nearby := 0
		for resource: Resources in game.resources.values():
			if resource.owner_id == town.owner_id:
				nearby += 1
		check(nearby >= 3, "Starting territory owns its authored resources")
	for resource: Resources in game.resources.values():
		check(resource.resource_instance_id == int(resource.get_meta("map_entity_id")), "Stable authored resource ID")
	for y in range(10, 20):
		for x in range(10, 20):
			if x < 12 or y < 12 or x > 17 or y > 17:
				var cell := Vector2i(x, y)
				var outer_edge := x == 10 or y == 10 or x == 19 or y == 19
				check(board.water_cells.has(cell) if outer_edge else board.is_ocean(cell), "Center has shoreline water and a continuous inner ocean ring")
	var shore_lakes := 0
	for cell: Vector2i in board.water_cells:
		if not Rect2i(10, 10, 10, 10).has_point(cell) or board.is_ocean(cell):
			continue
		shore_lakes += 1
		check(not board.resources_occupied_cells.has(cell), "Shoreline lakes leave room for docks")
		var adjacent_land := false
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if board.is_cell_on_map(cell + step) and not board.water_cells.has(cell + step):
				adjacent_land = true
		check(adjacent_land, "Every dock lake borders land")
		var town_in_reach := false
		for town: Building in game.buildings.values():
			var distance := cell - town.current_cell
			if maxi(absi(distance.x), absi(distance.y)) <= 3:
				town_in_reach = true
		check(town_in_reach, "A town can claim each lake within its maximum territory radius")
	check(shore_lakes == 8, "Sweetspire has eight authored shoreline dock sites")
	# Exercise the actual construction rules on a north-shore lake.
	var coastal_town := game.get_building(board.building_occupied_cells[Vector2i(17, 7)])
	var player := game.get_player(game.active_player_id)
	coastal_town.set_player_owner(player.player_id)
	while coastal_town.building_level < 4:
		coastal_town.increase_level()
	player.unlock_technology("sailing")
	player.sugars = 100
	var dock_cell := Vector2i(17, 10)
	check(game.structure_manager.placement_error(StructureManager.DOCK, dock_cell, player.player_id).is_empty(), "An owned shoreline lake permits dock construction")
	check(game.structure_manager.build(StructureManager.DOCK, dock_cell, player.player_id), "Dock builds on generated shoreline")
	var generator := BiomeMapGenerator.new()
	check(generator.prepare(), "Starter catalog validates: " + generator.last_error)
	for biome: String in ChunkCatalog.BIOMES:
		check(generator.catalog.ids_for(biome).size() >= 2, "Every biome has multiple authored variants")
	var seen: Dictionary = {}
	for seed_value in 40:
		for first: String in ["saba", "malagkit", "kamote"]:
			for second: String in ["saba", "malagkit", "kamote"]:
				var roster := [{"player_id": 1, "tribe_id": first}, {"player_id": 2, "tribe_id": second}]
				var chosen := generator.generate(seed_value, roster)
				check(generator.validate(chosen, roster), "All tribe combinations validate: " + generator.last_error)
				check(chosen == generator.generate(seed_value, roster), "Fixed seed reproduces selections and starts")
				var received: Dictionary = JSON.parse_string(JSON.stringify(chosen))
				check(generator.build(received, roster) == generator.build(chosen, roster), "Host/client JSON manifests build identical cells/entities")
				check(chosen.starts[0].cell != chosen.starts[1].cell, "Starting towns never overlap")
				for chunk: Dictionary in chosen.chunks:
					seen[chunk.variant] = true
	check(seen.size() == 8, "Repeated seeds exercise every variant")
	for count in range(1, 9):
		var roster: Array = []
		for id in count:
			roster.append({"player_id": id + 1, "tribe_id": "saba"})
		check(generator.validate(generator.generate(17, roster), roster), "Supports 1–8 same-tribe players")
	var roster := [{"player_id": 1, "tribe_id": "saba"}, {"player_id": 2, "tribe_id": "kamote"}]
	var original := generator.generate(99, roster)
	for field: String in ["catalog", "version", "starts", "players", "chunks", "seed"]:
		var invalid := original.duplicate(true)
		invalid[field] = null
		check(not generator.validate(invalid, roster), "Rejects invalid " + field)
	for field: String in ["slot", "origin", "biome", "variant", "shore_edge", "rotation", "player_id"]:
		var invalid := original.duplicate(true)
		invalid.chunks[0][field] = null
		check(not generator.validate(invalid, roster), "Rejects malformed chunk " + field)
	var invalid := original.duplicate(true)
	invalid.chunks[8].variant = "saba_grove"
	check(not generator.validate(invalid, roster), "Rejects replacing Sweetspire with outer land")
	invalid = original.duplicate(true)
	invalid.starts[0].building_id = 999
	check(not generator.validate(invalid, roster), "Rejects forged starting towns")
	check(generator.generate(1, []).is_empty(), "Rejects empty roster")
	check(generator.generate(1, [roster[0], roster[0]]).is_empty(), "Rejects duplicate player IDs")
	var chunk := load(ChunkCatalog.SCENES[6]).instantiate() as BiomeChunk
	chunk.get_node("Ground").set_cell(Vector2i.ZERO, 26, Vector2i(2, 0))
	generator.catalog.errors.clear()
	generator.catalog._read_chunk(chunk)
	check(not generator.catalog.errors.is_empty(), "Rejects authored breaks in Sweetspire ocean ring")
	chunk.free()
	chunk = load(ChunkCatalog.SCENES[6]).instantiate() as BiomeChunk
	chunk.get_node("Ground").set_cell(Vector2i(1, 4), 6, Vector2i.ZERO)
	generator.catalog.errors.clear()
	generator.catalog._read_chunk(chunk)
	check(not generator.catalog.errors.is_empty(), "Lake bays cannot cut through the inner ocean ring")
	chunk.free()
	print("MAP GENERATION REGRESSION: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
