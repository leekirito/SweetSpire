class_name MatchSnapshot
extends RefCounted

## Builds per-player snapshots and reconciles them on LAN guests.
## Remembers seen static entities without copying unseen changes or opponent economies.


## Copies this seat's economy, sight, visible units, and remembered static entities.
## Unseen changes must not enter the outgoing snapshot.
func capture(game: MatchManager, seat: int) -> Dictionary:
	var fog := game.fog_of_war
	fog.refresh(true)
	# The local view and network recipient share the same observation history.
	var memory: Dictionary = fog.knowledge.view(seat)
	var visible: Dictionary = fog.visible_by_player.get(seat, {})
	var units: Array = []
	for unit: Unit in game.units.values():
		if unit.owner_id == seat or visible.has(unit.current_cell):
			units.append({"id": unit.unit_id, "key": LanCatalog.unit_key(unit.scene_file_path), "owner": unit.owner_id, "cell": LanCatalog.xy(unit.current_cell), "hp": unit.unit_health, "defence": unit.defence, "moved": unit.has_moved, "attacked": unit.has_attacked, "boat": unit.is_embarked})
	var player := game.get_player(seat)
	var explored: Array = []
	var view: Array = []
	for cell: Vector2i in fog.explored_by_player.get(seat, {}):
		explored.append(LanCatalog.xy(cell))
	for cell: Vector2i in visible:
		view.append(LanCatalog.xy(cell))
	return {"clock": game.turn_clock.capture() if game.turn_clock != null else {}, "revision": LanSession.revision, "round": game.current_round, "active": game.active_player_id, "phase": int(game.current_phase), "winner": game.winner_id, "eliminated": game.eliminated_player_ids.keys(), "sugars": player.sugars, "tech": player.unlocked_technologies, "score": player.score, "center_rounds": player.center_control_rounds, "units": units, "towns": memory.towns.values(), "resources": memory.resources.values(), "structures": memory.structures.values(), "claims": memory.claims.values(), "explored": explored, "visible": view}

## Reconciles guest state and entities to the host snapshot; any animation is presentation only.
static func apply(game: MatchManager, state: Dictionary) -> void:
	var old_turn := game.active_player_id
	var old_round := game.current_round
	var first := game.current_phase == MatchManager.Phase.SETUP
	var player := game.get_player(LanSession.local_player_id)
	var old_tech := player.unlocked_technologies.duplicate()
	player.sugars = int(state.sugars)
	player.score = int(state.score)
	player.center_control_rounds = int(state.center_rounds)
	player.unlocked_technologies.assign(state.tech)
	game.current_round = int(state.round)
	game.active_player_id = int(state.active)
	for index in game.players.size():
		if game.players[index].player_id == game.active_player_id:
			game.active_player_index = index
	game.current_phase = int(state.phase)
	if game.turn_clock != null:
		game.turn_clock.apply_remote(state.get("clock", {}))
	game.eliminated_player_ids.clear()
	for id in state.eliminated:
		game.eliminated_player_ids[int(id)] = true
	for row: Dictionary in state.towns:
		var town := game.get_building(int(row.id))
		if town == null:
			continue
		if int(row.owner) == -1:
			town.make_neutral()
		else:
			town.set_player_owner(int(row.owner))
			town.apply_visual_theme(game.get_player(int(row.owner)).tribe)
		town.building_level = int(row.level)
		town.current_exp = int(row.exp)
		town.last_recruited_round = int(row.recruited)
		town._update_territory_radius()
		town._update_building_income()
		town._refresh_exp_bar()
	game.territory_manager.apply_known_claims(state.claims, game.get_all_buildings_for_network())
	for row: Dictionary in state.resources:
		var resource := game.get_resource(int(row.id))
		if resource == null:
			continue
		if row.get("removed", false):
			game.board_manager.unregister_resource(resource)
			game.resources.erase(resource.resource_instance_id)
			resource.hide()
			resource.queue_free()
		else:
			resource.owner_id = int(row.owner)
			resource.controlling_building_id = int(row.town)
			if row.upgraded and not resource.is_upgraded:
				resource.upgrade_resource()
	var known_structures: Dictionary = {}
	for row: Dictionary in state.structures:
		known_structures[LanCatalog.cell(row.cell)] = true
	for cell: Vector2i in game.structure_manager.structures.keys():
		if not known_structures.has(cell):
			var old: Structure = game.structure_manager.structures[cell]
			old.hide()
			old.queue_free()
			game.structure_manager.structures.erase(cell)
	for row: Dictionary in state.structures:
		var location := LanCatalog.cell(row.cell)
		if not game.structure_manager.structures.has(location):
			var structure := Structure.new()
			if LanCatalog.STRUCTURES[row.key].behavior_script != null:
				structure.set_script(LanCatalog.STRUCTURES[row.key].behavior_script)
			structure.data = LanCatalog.STRUCTURES[row.key]
			structure.current_cell = location
			structure.controlling_building_id = int(row.town)
			game.get_tree().current_scene.add_child(structure)
			structure.global_position = game.board_manager.cell_to_world(location)
			game.structure_manager.structures[location] = structure
		game.structure_manager.structures[location].controlling_building_id = int(row.town)
	var keep: Dictionary = {}
	for row: Dictionary in state.units:
		keep[int(row.id)] = true
	for id: int in game.units.keys():
		if not keep.has(id):
			game.remove_unit_authoritative(game.units[id])
	game.board_manager.occupied_cells.clear()
	for row: Dictionary in state.units:
		var id := int(row.id)
		var unit: Unit = game.units.get(id)
		var animate := unit != null and not first
		var old_position := unit.global_position if unit != null else Vector2.ZERO
		if unit == null:
			unit = LanCatalog.UNITS[row.key].instantiate()
			game.get_tree().current_scene.add_child(unit)
			unit.setup_player(game.get_player(int(row.owner)))
			unit.unit_id = id
			game.units[id] = unit
		unit.current_cell = LanCatalog.cell(row.cell)
		unit.global_position = game.board_manager.cell_to_world(unit.current_cell)
		game.board_manager.register_unit(unit)
		unit.unit_health = int(row.hp)
		unit.defence = int(row.defence)
		unit.has_moved = row.moved
		unit.has_attacked = row.attacked
		if row.boat and not unit.is_embarked:
			unit.embark(StructureManager.DOCK)
		elif not row.boat and unit.is_embarked:
			unit.disembark()
		unit.update_ui()
		if animate:
			unit.present_network_move(old_position)
	var fog := game.fog_of_war
	fog.knowledge.import_view(game, LanSession.local_player_id, state)
	fog.explored_by_player[LanSession.local_player_id] = {}
	fog.visible_by_player[LanSession.local_player_id] = {}
	for cell in state.explored:
		fog.explored_by_player[LanSession.local_player_id][LanCatalog.cell(cell)] = true
	for cell in state.visible:
		fog.visible_by_player[LanSession.local_player_id][LanCatalog.cell(cell)] = true
	fog.initialized = true
	fog.refresh(true)
	game.update_ui()
	game.refresh_resource_collectibility_authoritative()
	if first:
		game.match_started.emit()
	if first or old_turn != game.active_player_id or old_round != game.current_round:
		game.turn_started.emit(game.active_player_id, game.current_round)
	for tech: String in player.unlocked_technologies:
		if tech not in old_tech:
			game.technology_purchased.emit(player.player_id, tech)
	if int(state.winner) != -1 and game.winner_id == -1:
		game.winner_id = int(state.winner)
		game._show_match_result(game.winner_id, "MATCH COMPLETE")
		game.match_ended.emit(game.winner_id, "MATCH COMPLETE")
