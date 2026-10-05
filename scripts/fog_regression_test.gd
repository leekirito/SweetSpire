extends Node2D

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game: MatchManager = $MatchManager
	var fog: FogOfWar = $FogOfWar
	# This fixture verifies radius growth independently of the scene's tuned default.
	fog.building_vision_radius = 2
	var board := game.board_manager
	check(fog.initialized, "Fog initializes after match setup")
	check(fog.fog_nodes.size() == board.tile_map_layer.get_used_cells().size(), "One scene node per ground cell")
	check(fog.viewing_player_id == game.active_player_id, "Fog follows active player")
	# Use the real board and systems, with controlled positions and ownership.
	for unit: Unit in game.units.values():
		unit.hide()
		unit.queue_free()
	game.units.clear()
	board.occupied_cells.clear()
	for building: Building in game.buildings.values():
		building.set_player_owner(-1)
	for x in range(8, 25):
		for y in range(8, 25):
			board.tile_map_layer.set_cell(Vector2i(x, y), 39, Vector2i.ZERO)
	board._setup_grid()
	board.mountain_cells.clear()
	fog.explored_by_player.clear()
	var p1 := game.players[0]
	var p2 := game.players[1]
	game.active_player_id = p1.player_id
	var scout := game.spawn_unit(p1.tribe.starting_unit_scene, p1, Vector2i(12, 12))
	var enemy := game.spawn_unit(p2.tribe.starting_unit_scene, p2, Vector2i(20, 20))
	enemy.walk_exact_dimensions_override = Vector2i(3, 3)
	enemy.attack_exact_dimensions_override = Vector2i(3, 3)
	enemy.movement_pattern = RangePattern.new()
	enemy.attack_pattern = RangePattern.new()
	scout.walk_exact_dimensions_override = Vector2i(3, 3)
	scout.attack_exact_dimensions_override = Vector2i(3, 3)
	scout.movement_pattern = RangePattern.new()
	scout.attack_pattern = RangePattern.new()
	fog.refresh(true)
	check(fog.state_for(scout.current_cell) == FogOfWar.State.VISIBLE, "Unit reveals its own cell")
	check(fog.state_for(Vector2i(11, 12)) == FogOfWar.State.VISIBLE, "Legal move/attack range reveals terrain")
	check(fog.state_for(enemy.current_cell) == FogOfWar.State.UNEXPLORED, "Distant terrain starts unexplored")
	check(not enemy.visible, "Enemy is hidden in opaque fog")
	check(not game.request_attack(scout.unit_id, enemy.unit_id), "Cannot attack a hidden enemy")
	# An occupied movement-range tile still supplies vision outside attack range.
	scout.walk_exact_dimensions_override = Vector2i(5, 5)
	board.commit_unit_move(enemy, Vector2i(14, 12))
	enemy.global_position = board.cell_to_world(enemy.current_cell)
	fog.refresh()
	check(enemy.current_cell not in board.get_attack_tiles(scout), "Enemy is outside attack range")
	check(fog.is_cell_visible(enemy.current_cell) and enemy.visible, "Movement vision reveals occupied tiles and enemies")
	check(not board.can_move_to(scout, enemy.current_cell), "Seeing an enemy does not allow moving onto it")
	check(not game.request_attack(scout.unit_id, enemy.unit_id), "Movement vision does not extend attack reach")
	board.commit_unit_move(enemy, Vector2i(20, 20))
	enemy.global_position = board.cell_to_world(enemy.current_cell)
	scout.walk_exact_dimensions_override = Vector2i(3, 3)
	fog.refresh()
	scout.has_moved = true
	scout.has_attacked = true
	fog.refresh()
	check(fog.is_cell_visible(Vector2i(11, 12)), "Spending actions does not remove vision")
	# A blocked destination outside attack range is not revealed by movement.
	scout.walk_exact_dimensions_override = Vector2i(5, 5)
	var blocked := Vector2i(14, 12)
	board.astar_grid.set_point_solid(blocked, true)
	fog.explored_by_player.clear()
	fog.refresh(true)
	check(not fog.is_cell_visible(blocked), "Illegal movement-only tile remains hidden")
	board.astar_grid.set_point_solid(blocked, false)
	fog.refresh()
	check(fog.is_cell_visible(blocked), "Unblocked legal movement tile gains vision")
	var old_cell := scout.current_cell
	board.commit_unit_move(scout, Vector2i(17, 12))
	scout.global_position = board.cell_to_world(scout.current_cell)
	fog.refresh()
	check(fog.state_for(old_cell) == FogOfWar.State.EXPLORED, "Leaving discovered terrain creates secondary fog")
	check(fog.fog_nodes[old_cell].fog_state == FogOfWar.State.EXPLORED, "Fog node grows into explored state")
	board.commit_unit_move(enemy, old_cell)
	enemy.global_position = board.cell_to_world(old_cell)
	fog.refresh()
	check(not enemy.visible, "Enemy is hidden in translucent fog")
	check(fog.is_cell_explored(old_cell), "Explored terrain memory is retained")
	check(not fog.is_cell_explored(Vector2i(24, 24)), "Untouched terrain stays unexplored")
	board.commit_unit_move(scout, old_cell + Vector2i.RIGHT)
	scout.global_position = board.cell_to_world(scout.current_cell)
	fog.refresh()
	check(enemy.visible, "Enemy appears when its tile is revealed again")
	check(fog.fog_nodes[old_cell].fog_state == FogOfWar.State.VISIBLE, "Revisited fog shrinks away")
	# Buildings keep vision without troops and gain rings with territory growth.
	var town: Building = game.buildings.values()[0]
	town.current_cell = Vector2i(21, 21)
	town.set_player_owner(p1.player_id)
	fog.refresh()
	check(fog.is_cell_visible(Vector2i(23, 23)), "Owned building reveals radius 2 including corners")
	check(not fog.is_cell_visible(Vector2i(24, 24)), "Building vision stops beyond radius 2")
	town.increase_level()
	check(fog.is_cell_visible(Vector2i(24, 24)), "Level 2 territory growth immediately expands vision to radius 3")
	check(not fog.is_cell_visible(Vector2i(25, 25)), "Radius 3 does not reveal the next ring")
	town.increase_level()
	check(not fog.is_cell_visible(Vector2i(25, 25)), "Level 3 without territory growth keeps the same vision")
	town.increase_level()
	check(fog.is_cell_visible(Vector2i(25, 25)), "Level 4 territory growth expands vision to radius 4")
	check(not fog.is_cell_visible(Vector2i(26, 26)), "Radius 4 stops at its boundary")
	town.set_player_owner(p2.player_id)
	fog.refresh()
	check(fog.state_for(Vector2i(23, 23)) == FogOfWar.State.EXPLORED, "Lost building no longer provides vision")
	check(fog.is_cell_visible(Vector2i(23, 23), p2.player_id), "New building owner gains vision")
	check(fog.state_for(Vector2i(25, 25)) == FogOfWar.State.EXPLORED, "Losing an upgraded town removes its expanded vision")
	check(fog.is_cell_visible(Vector2i(25, 25), p2.player_id), "Capturing an upgraded town grants its expanded vision")
	# Player changes are immediate, never tweened across private views.
	var p1_only := scout.current_cell + Vector2i.RIGHT
	game.active_player_id = p2.player_id
	game.turn_started.emit(p2.player_id, 1)
	check(fog.viewing_player_id == p2.player_id, "Turn signal switches perspective")
	check(not fog.is_cell_explored(p1_only, p2.player_id), "Players do not share explored memory")
	check(fog.fog_nodes[p1_only].cover.scale == Vector2.ONE, "Player switch covers private cells immediately")
	game.active_player_id = p1.player_id
	game.turn_started.emit(p1.player_id, 2)
	check(fog.state_for(Vector2i(23, 23)) == FogOfWar.State.EXPLORED, "Exploration survives a full player switch")
	# Actual animation completion and interrupted reversal.
	fog.set_process(false)
	var tile := fog.fog_nodes[Vector2i(24, 24)]
	tile.set_fog_state(FogOfWar.State.EXPLORED, false, 0.0)
	check(tile.cover.color.a > 0.0 and tile.cover.color.a < 1.0, "Secondary fog is translucent")
	tile.set_fog_state(FogOfWar.State.VISIBLE, true, 0.06)
	await get_tree().create_timer(0.03).timeout
	tile.set_fog_state(FogOfWar.State.EXPLORED, true, 0.06)
	await get_tree().create_timer(0.10).timeout
	check(tile.cover.visible and tile.cover.scale.is_equal_approx(Vector2.ONE), "Interrupted reveal grows back fully")
	tile.set_fog_state(FogOfWar.State.VISIBLE, true, 0.06)
	await get_tree().create_timer(0.10).timeout
	# Node2D clamps zero scale to a small nonzero value internally.
	check(not tile.cover.visible and tile.cover.scale.length() < 0.001, "Reveal animation shrinks fully away")
	tile.set_fog_state(FogOfWar.State.UNEXPLORED, false, 0.0)
	check(tile.cover.color.a == 1.0, "Unexplored cover is fully opaque")
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	fog.fog_texture = texture
	check(tile.fog_sprite.visible and tile.fog_sprite.texture == texture, "Layer texture reaches fog sprites")
	check(tile.cover.color.a == 0.0, "Sprite replaces polygon fill")
	check(tile.fog_sprite.scale == Vector2(4, 2), "Sprite fits tile dimensions")
	tile.set_fog_state(FogOfWar.State.EXPLORED, false, 0.0)
	check(is_equal_approx(tile.fog_sprite.modulate.a, fog.explored_color.a), "Sprite uses secondary fog opacity")
	tile.set_fog_state(FogOfWar.State.VISIBLE, true, 0.06)
	await get_tree().create_timer(0.10).timeout
	check(not tile.cover.visible, "Sprite shares shrink animation and hides with its parent")
	tile.set_fog_state(FogOfWar.State.EXPLORED, true, 0.06)
	await get_tree().create_timer(0.10).timeout
	check(tile.cover.visible and tile.cover.scale.is_equal_approx(Vector2.ONE), "Sprite shares grow animation")
	fog.fog_texture = null
	check(not tile.fog_sprite.visible and tile.cover.color == fog.explored_color, "Clearing texture restores polygon fallback")
	GameSession.match_mode = GameSession.REGULAR
	# Earlier checks moved this enemy next to the scout; isolate a distant target.
	board.commit_unit_move(enemy, scout.current_cell + Vector2i(6, 0))
	enemy.global_position = board.cell_to_world(enemy.current_cell)
	fog.refresh(true)
	check(fog.visible_by_player[p1.player_id].size() == board.tile_map_layer.get_used_cells().size(), "Regular reveals all terrain to player one")
	check(fog.visible_by_player[p2.player_id].size() == board.tile_map_layer.get_used_cells().size(), "Regular reveals all terrain to player two")
	check(enemy.visible and fog.state_for(Vector2i(24, 24)) == FogOfWar.State.VISIBLE, "Regular displays enemies and removes fog cover")
	check(enemy.current_cell not in game.get_visible_attack_tiles(scout), "Regular visibility does not extend attack range")
	GameSession.match_mode = GameSession.FOG_OF_WAR
	fog.refresh(true)
	check(not enemy.visible, "Fog mode still hides enemies outside vision")
	print("Fog regression: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
