class_name BiomeMapGenerator
extends RefCounted

const VERSION := 2
const SLOT_ORIGINS := [[0, 0], [10, 0], [20, 0], [20, 10], [20, 20], [10, 20], [0, 20], [0, 10], [10, 10]]
var catalog := ChunkCatalog.new()
var last_error: String = ""

func prepare() -> bool:
	if not catalog.load_catalog():
		last_error = "\n".join(catalog.errors)
		return false
	return true

## Pure data only. Call on the host; clients consume the returned manifest.
func generate(seed_value: int, roster: Array) -> Dictionary:
	last_error = ""
	if not _integer(seed_value):
		_fail("Map seed must fit in a signed 32-bit integer.")
		return {}
	if not _valid_roster(roster):
		return {}
	if catalog.variants.is_empty() and not prepare():
		return {}
	var sorted_roster := roster.duplicate(true)
	sorted_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.player_id < b.player_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Opposite cardinal slots first, then opposite corners for larger lobbies.
	var offset := rng.randi_range(0, 3) * 2
	var slot_order: Array[int] = []
	for index: int in [1, 5, 3, 7, 0, 4, 2, 6]:
		slot_order.append((index + offset) % 8)
	for slot in 8:
		if _biomes_for_slot(slot).is_empty():
			_fail("No compatible variants for outer slot %d. Keep unrestricted (Shore Edge: None) variants for corner slots." % slot)
			return {}
	var assignments: Dictionary = {}
	if not _assign_players(sorted_roster, 0, slot_order, assignments):
		_fail("Cannot give every selected player a matching biome and shore direction. Add unrestricted variants or more shore directions for the selected tribes.")
		return {}
	var chunks: Array = []
	var used: Dictionary = {}
	for slot in 9:
		var available_biomes: Array[String] = ["SWEETSPIRE"]
		if slot != 8:
			available_biomes = _biomes_for_slot(slot)
		var biome: String = available_biomes[rng.randi_range(0, available_biomes.size() - 1)]
		if assignments.has(slot):
			biome = String(assignments[slot].tribe_id).to_upper()
		var choices := catalog.ids_for(biome, slot)
		var unused: Array[String] = []
		for id: String in choices:
			if not used.has(id):
				unused.append(id)
		if not unused.is_empty():
			choices = unused
		var variant: String = choices[rng.randi_range(0, choices.size() - 1)]
		used[variant] = true
		chunks.append({"slot": slot, "origin": SLOT_ORIGINS[slot].duplicate(), "biome": biome, "variant": variant, "shore_edge": catalog.variants[variant].shore_edge, "rotation": 0, "player_id": assignments[slot].player_id if assignments.has(slot) else -1})
	var manifest := {"version": VERSION, "catalog": catalog.signature, "seed": seed_value, "players": sorted_roster, "chunks": chunks, "starts": []}
	manifest.starts = _expand(chunks).starts
	return manifest

func _biomes_for_slot(slot: int) -> Array[String]:
	var result: Array[String] = []
	for biome: String in ["SABA", "MALAGKIT", "KAMOTE"]:
		if not catalog.ids_for(biome, slot).is_empty():
			result.append(biome)
	return result

## Preserve the usual opposite-side preference when possible, but backtrack
## instead of rejecting a feasible lobby because a scarce shore slot was taken.
func _assign_players(roster: Array, index: int, slot_order: Array[int], assignments: Dictionary) -> bool:
	if index == roster.size():
		return true
	var player: Dictionary = roster[index]
	for slot: int in slot_order:
		if assignments.has(slot) or catalog.ids_for(String(player.tribe_id).to_upper(), slot).is_empty():
			continue
		assignments[slot] = player
		if _assign_players(roster, index + 1, slot_order, assignments):
			return true
		assignments.erase(slot)
	return false

## Validate the host's explicit choices; never reroll on receipt or on failure.
## JSON round-trips are supported, with no Nodes, Resources or Vector2 values.
func validate(manifest: Dictionary, roster: Array) -> bool:
	last_error = ""
	if catalog.variants.is_empty() and not prepare():
		return false
	if not _valid_roster(roster):
		return false
	if manifest.get("version") != VERSION or manifest.get("catalog") != catalog.signature:
		return _fail("Map version or chunk catalog differs from this build.")
	if not _integer(manifest.get("seed")) or not manifest.get("players") is Array:
		return _fail("Invalid map seed or roster.")
	var sorted_roster := roster.duplicate(true)
	sorted_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.player_id < b.player_id)
	if not _wire_equal(manifest.players, sorted_roster):
		return _fail("Manifest roster does not match the selected players/tribes.")
	var chunks: Variant = manifest.get("chunks")
	if not chunks is Array or chunks.size() != 9:
		return _fail("The map requires eight outer chunks and one center.")
	var assigned: Dictionary = {}
	for slot in 9:
		var entry: Variant = chunks[slot]
		if not entry is Dictionary:
			return _fail("Invalid chunk entry.")
		if not _integer(entry.get("slot")) or not _integer(entry.get("rotation")) or entry.get("slot") != slot or not _wire_equal(entry.get("origin"), SLOT_ORIGINS[slot]) or entry.get("rotation") != 0:
			return _fail("Invalid chunk slot, origin or orientation.")
		if not entry.get("variant") is String or not catalog.variants.has(entry.variant):
			return _fail("Unknown chunk variant.")
		var biome: String = catalog.variants[entry.variant].biome
		if entry.get("biome") != biome or (biome == "SWEETSPIRE") != (slot == 8):
			return _fail("Sweetspire must occupy only the center slot.")
		if not _integer(entry.get("shore_edge")) or entry.shore_edge != catalog.variants[entry.variant].shore_edge or not catalog.fits_slot(entry.variant, slot):
			return _fail("Chunk shore direction does not face Sweetspire in slot %d." % slot)
		if not _integer(entry.get("player_id")):
			return _fail("Invalid starting player.")
		var player_id := int(entry.player_id)
		if player_id != -1:
			if slot == 8 or assigned.has(player_id):
				return _fail("Players need distinct outer starting chunks.")
			var found := false
			for player: Dictionary in roster:
				if player.player_id == player_id and String(player.tribe_id).to_upper() == biome:
					found = true
			if not found:
				return _fail("Starting biome does not match the player's tribe.")
			assigned[player_id] = true
	if assigned.size() != roster.size():
		return _fail("Every player must have a starting chunk.")
	if not _wire_equal(manifest.get("starts"), _expand(chunks).starts):
		return _fail("Starting placements do not match the authored chunks.")
	return true

func build(manifest: Dictionary, roster: Array) -> Dictionary:
	if not validate(manifest, roster):
		return {}
	return _expand(manifest.chunks)

func _expand(chunks: Array) -> Dictionary:
	var result := {"layers": {"Ground": [], "Decoration": [], "Obstacles": []}, "entities": [], "starts": []}
	var town_id := 0
	var resource_id := 0
	# An additional ocean border closes the finite map's outside edge.
	for y in range(-1, 31):
		for x in range(-1, 31):
			if x == -1 or y == -1 or x == 30 or y == 30:
				result.layers.Ground.append([x, y, 5, 0, 0, 0])
	for entry: Dictionary in chunks:
		var chunk: Dictionary = catalog.variants[entry.variant]
		var origin := Vector2i(int(entry.origin[0]), int(entry.origin[1]))
		for layer_name: String in chunk.layers:
			for tile: Array in chunk.layers[layer_name]:
				result.layers[layer_name].append([origin.x + int(tile[0]), origin.y + int(tile[1]), tile[2], tile[3], tile[4], tile[5]])
		for placement: Dictionary in chunk.placements:
			var cell: Array = [origin.x + int(placement.cell[0]), origin.y + int(placement.cell[1])]
			var id: int
			if placement.kind == "town":
				town_id += 1
				id = town_id
			else:
				resource_id += 1
				id = resource_id
			result.entities.append({"id": id, "kind": placement.kind, "cell": cell, "tribe_id": String(chunk.biome).to_lower() if placement.start else ""})
			if placement.start and entry.player_id != -1:
				result.starts.append({"player_id": int(entry.player_id), "building_id": id, "cell": cell})
	return result

func _valid_roster(roster: Array) -> bool:
	if roster.is_empty() or roster.size() > 8:
		return _fail("Chunk maps support 1 to 8 players.")
	var ids: Dictionary = {}
	for player: Variant in roster:
		if not player is Dictionary or not _integer(player.get("player_id")) or player.player_id <= 0:
			return _fail("Players require positive integer IDs.")
		if ids.has(int(player.player_id)) or player.get("tribe_id") not in ["saba", "malagkit", "kamote"]:
			return _fail("Duplicate player ID or unsupported tribe.")
		ids[int(player.player_id)] = true
	return true

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= 2147483647.0

## JSON represents integers as floats. Compare structure without accepting
## numeric strings, truncated fractions, extra keys or different array order.
func _wire_equal(a: Variant, b: Variant) -> bool:
	if _integer(a) and _integer(b):
		return int(a) == int(b)
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not _wire_equal(a[index], b[index]):
				return false
		return true
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _wire_equal(a[key], b[key]):
				return false
		return true
	return a == b

func _fail(message: String) -> bool:
	last_error = message
	return false
