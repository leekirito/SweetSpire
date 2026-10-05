extends Node2D
var checks := 0
var failures := 0
var sequence := 0
var game: MatchManager

func _enter_tree() -> void:
	GameSession.clear_players()
	for id in [1, 2]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Test %d" % id
		player.tribe = LanCatalog.TRIBES["saba" if id == 1 else "kamote"]
		player.sugars = 100
		GameSession.add_player(player)

func _ready() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("LAN RULES: " + label)

func command(value: Dictionary, seat: int = 1) -> bool:
	sequence += 1
	return LanSession._execute(seat, sequence, value)

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	game = $MatchManager
	LanSession.hosting = true
	LanSession.state = "playing"
	LanSession.local_player_id = 1
	LanSession.game = game
	LanSession.seats = [LanSession._seat(1, "Host", "saba"), LanSession._seat(2, "Guest", "kamote")]
	var board := game.board_manager
	var player := game.get_player(1)
	var guest := game.get_player(2)
	var unit: Unit
	var enemy: Unit
	var town: Building
	for item: Unit in game.units.values():
		if item.owner_id == 1:
			unit = item
		else:
			enemy = item
	for item: Building in game.buildings.values():
		if item.owner_id == 1:
			town = item
	check(unit != null and enemy != null and town != null, "spawn roster")
	check(not command({"action": "end_turn"}, 2), "host rejects guest outside its turn")
	check(not command({"action": "move", "id": enemy.unit_id, "cell": [0, 0]}), "cannot command another seat's unit")
	check(not command({"action": "move", "id": unit.unit_id, "cell": [0.5, 0]}), "fractional cell rejected")
	check(not command({"action": "move", "id": "bad", "cell": [0, 0]}), "malformed ID rejected")
	check(not command({"action": "technology", "key": "res://scripts/network/lan_session.gd"}), "paths cannot become catalog IDs")
	LanSession.paused_for_disconnect = true
	check(not command({"action": "end_turn"}), "pause blocks host too")
	LanSession.paused_for_disconnect = false
	var before := player.sugars
	check(command({"action": "technology", "key": "fishing"}), "purchase through dispatcher")
	check(not LanSession._execute(1, sequence, {"action": "technology", "key": "wilderness"}), "duplicate sequence rejected even with altered body")
	check(player.sugars == before - 3, "purchase charged exactly once")
	check(not command({"action": "technology", "key": "fishing"}), "already-owned purchase rejected")
	var options := board.get_movement_tiles(unit)
	check(not options.is_empty(), "starting unit can move")
	check(command({"action": "move", "id": unit.unit_id, "cell": LanCatalog.xy(options[0])}), "move through dispatcher")
	check(unit.has_moved and not unit.is_animating, "authoritative move does not wait for animation")
	check(not command({"action": "move", "id": unit.unit_id, "cell": LanCatalog.xy(town.current_cell)}), "second move rejected")
	check(command({"action": "recruit", "id": town.building_id, "key": "fighter"}), "recruit through dispatcher")
	check(not command({"action": "recruit", "id": town.building_id, "key": "fighter"}), "duplicate recruit rejected")
	for key: String in LanCatalog.TECHS:
		player.unlock_technology(key)
	var forest: Resources
	var harvest: Resources
	var upgrade: Resources
	for item: Resources in game.resources.values():
		LanSession.resource_cells[item.resource_instance_id] = item.current_cell
		if item.owner_id != 1:
			continue
		if item.data.resource_alias == "forest":
			forest = item
		elif item.data.can_collect:
			harvest = item
		if item.data.can_upgrade:
			upgrade = item
	check(forest != null and harvest != null, "authored start has build and harvest options")
	if upgrade != null:
		check(command({"action": "upgrade", "id": upgrade.resource_instance_id}), "resource upgrade through dispatcher")
	if forest != null:
		check(command({"action": "build", "key": "lumber_factory", "cell": LanCatalog.xy(forest.current_cell)}), "structure through dispatcher")
		check(not command({"action": "build", "key": "lumber_factory", "cell": LanCatalog.xy(forest.current_cell)}), "duplicate structure rejected")
	if harvest != null:
		var id := harvest.resource_instance_id
		check(command({"action": "collect", "id": id}), "harvest through dispatcher")
		check(not game.resources.has(id), "harvest removed from authoritative registry")
		var snapshot := LanSession.snapshot_codec.capture(game, 1)
		check(snapshot.resources.any(func(row: Dictionary): return int(row.id) == id and row.get("removed", false)), "visible resource removal replicated")
	var private_view := LanSession.snapshot_codec.capture(game, 2)
	check(int(private_view.sugars) == guest.sugars, "snapshot economy belongs to recipient")
	for row: Dictionary in private_view.units:
		check(int(row.owner) == 2 or game.is_cell_visible_to_player(LanCatalog.cell(row.cell), 2), "snapshot excludes hidden enemies")
	check(not private_view.has("players") and not private_view.has("manifest"), "no other economies or spawn assignments in snapshot")
	# Combat on a controlled patch, including a lethal hit, then snapshot replay.
	for x in range(70, 76):
		for y in range(70, 76):
			board.tile_map_layer.set_cell(Vector2i(x, y), 39, Vector2i(4, 0))
	board.astar_grid.region = board.tile_map_layer.get_used_rect()
	board.astar_grid.update()
	board._refresh_solid_cells()
	var fighter := game.spawn_unit(LanCatalog.UNITS.fighter, player, Vector2i(71, 71))
	var target := game.spawn_unit(LanCatalog.UNITS.fighter, guest, Vector2i(72, 71))
	target.unit_health = 1
	target.defence = 0
	var target_id := target.unit_id
	game.fog_of_war.refresh(true)
	check(command({"action": "attack", "id": fighter.unit_id, "cell": [72, 71]}), "attack through dispatcher")
	check(not game.units.has(target_id), "lethal damage committed before presentation finishes")
	check(not game.combat_resolver.attack_in_progress, "cosmetic effects never lock authoritative rules")
	check(not command({"action": "attack", "id": fighter.unit_id, "cell": [72, 71]}), "spent attack rejected")
	unit.embark(StructureManager.DOCK)
	var own_view := LanSession.snapshot_codec.capture(game, 1)
	check(own_view.units.any(func(row: Dictionary): return int(row.id) == unit.unit_id and row.boat), "embarkation encoded")
	check(command({"action": "end_turn"}), "host ends turn")
	check(game.active_player_id == 2, "turn advances")
	check(command({"action": "end_turn"}, 2), "guest ends turn on server")
	check(game.current_round == 2, "round advances once")
	# The recipient is told it lost an owned town even when that removes its vision.
	LanSession.snapshot_codec.capture(game, 2)
	var lost_town: Building
	for item: Building in game.buildings.values():
		if item.owner_id == 2:
			lost_town = item
	game.remove_unit_authoritative(enemy)
	game.capture_manager.conquer_building(game, lost_town.building_id, 1)
	var loss_view := LanSession.snapshot_codec.capture(game, 2)
	check(loss_view.towns.any(func(row: Dictionary): return int(row.id) == lost_town.building_id and int(row.owner) == 1), "loss of owned town replicated after vision disappears")
	game.evaluate_eliminations()
	check(game.winner_id == 1 and game.eliminated_player_ids.has(2), "elimination produces victory")
	# JSON replay into a client view exercises actual wire numeric conversion.
	own_view = JSON.parse_string(JSON.stringify(LanSession.snapshot_codec.capture(game, 1)))
	LanSession.hosting = false
	game.current_phase = MatchManager.Phase.SETUP
	game.winner_id = -1
	MatchSnapshot.apply(game, own_view)
	check(unit.is_embarked, "snapshot restores boat form")
	check(player.sugars == int(own_view.sugars), "snapshot restores private Sugar")
	check(game.fog_of_war.viewing_player_id == 1, "snapshot keeps local viewpoint")
	check(game.current_phase == MatchManager.Phase.GAME_OVER and game.winner_id == 1, "snapshot restores victory")
	check(game.structure_manager.structures.size() == own_view.structures.size(), "structures survive snapshot replay")
	print("LAN RULES: %d checks, %d failures" % [checks, failures])
	await get_tree().create_timer(1.0).timeout
	LanSession.leave()
	get_tree().quit(1 if failures else 0)
