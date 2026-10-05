class_name MapBootstrap
extends Node2D

@export var enabled: bool = true
var manifest: Dictionary = {}
var setup_error: String = ""

## Main's root enters before children: finish assembly before terrain caches.
func _enter_tree() -> void:
	if not enabled:
		return
	var root := self
	var game := root.get_node("MatchManager") as MatchManager
	game.populate_demo_map = false
	if LanSession.client():
		if GameSession.network_map.is_empty():
			_fail("Waiting for the host map.")
			return
		_apply_map(GameSession.network_map)
		return
	if GameSession.require_map_manifest and GameSession.map_manifest.is_empty():
		_fail("Waiting for the host map manifest; local generation is disabled.")
		return
	if not GameSession.require_map_manifest:
		DemoMap.ensure_players(GameSession)
	var roster: Array = []
	for player: PlayerState in GameSession.players:
		roster.append({"player_id": player.player_id, "tribe_id": player.tribe.tribe_id if player.tribe != null else ""})
	var generator := BiomeMapGenerator.new()
	if not generator.prepare():
		_fail(generator.last_error)
		return
	manifest = GameSession.map_manifest.duplicate(true)
	if manifest.is_empty():
		var seed_value: int = GameSession.map_seed
		if seed_value < 0:
			seed_value = int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec() & 0x7fffffff)
			seed_value &= 0x7fffffff
		manifest = generator.generate(seed_value, roster)
	var assembled := generator.build(manifest, roster)
	if assembled.is_empty():
		_fail(generator.last_error)
		return
	_apply_map(assembled)

func _apply_map(assembled: Dictionary) -> void:
	var root := self
	var game := root.get_node("MatchManager") as MatchManager
	# Validation completes before replacing any authored scene content.
	for child: Node in root.get_children():
		if child is Building or child is Resources:
			root.remove_child(child)
			child.free()
	for layer_name: String in ["Ground", "Obstacles", "Buildings", "Decoration"]:
		var layer := root.get_node_or_null(layer_name) as TileMapLayer
		if layer == null:
			continue
		layer.clear()
		for tile: Array in assembled.layers.get(layer_name, []):
			layer.set_cell(Vector2i(tile[0], tile[1]), tile[2], Vector2i(tile[3], tile[4]), tile[5])
	var ground := root.get_node("Ground") as TileMapLayer
	var entities := Node2D.new()
	entities.name = "GeneratedEntities"
	entities.y_sort_enabled = true
	root.add_child(entities)
	for placement: Dictionary in assembled.entities:
		var path: String = "res://scenes/entities/buildings/neutral_building.tscn" if placement.kind == "town" else "res://scenes/entities/Resources/%s.tscn" % placement.kind
		var entity := (load(path) as PackedScene).instantiate() as Node2D
		entity.name = "%s_%d" % [placement.kind, placement.id]
		entity.set_meta("map_entity_id", int(placement.id))
		if entity is Building:
			entity.allowed_starting_tribe_ids.clear()
			if not String(placement.tribe_id).is_empty():
				entity.allowed_starting_tribe_ids.append(placement.tribe_id)
		entities.add_child(entity)
		entity.position = ground.transform * ground.map_to_local(Vector2i(placement.cell[0], placement.cell[1]))
	game.sweetspire_center_cell = Vector2i(14, 14)
	game.map_manifest = manifest.duplicate(true)
	GameSession.map_manifest = manifest.duplicate(true)

func _fail(message: String) -> void:
	setup_error = message
	get_node("MatchManager").map_setup_error = message
	push_error("Map setup failed: " + message)

func _ready() -> void:
	if setup_error.is_empty():
		return
	$MapSetupError/Message.text = "MAP SETUP FAILED\n" + setup_error
	$MapSetupError.show()
