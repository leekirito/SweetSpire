extends MapBootstrap

## Reproduces overlapping claims and last-seen visibility through the real map,
## JSON snapshot path, construction UI, and Hotseat viewpoint changes.

var checks := 0
var failures := 0
var game: MatchManager
var fog_callbacks := 0
var nested_guard_held := true

func _enter_tree() -> void:
	GameSession.clear_players()
	GameSession.match_mode = GameSession.FOG_OF_WAR
	GameSession.map_seed = 2468
	for id in [1, 2, 3]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Knowledge test %d" % id
		player.tribe = LanCatalog.TRIBES[["saba", "kamote", "malagkit"][id - 1]]
		player.sugars = 100
		GameSession.add_player(player)
	super._enter_tree()

func _ready() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	print("KNOWLEDGE ", "PASS " if ok else "FAIL ", description)
	if not ok:
		failures += 1

func on_fog_update() -> void:
	fog_callbacks += 1
	nested_guard_held = nested_guard_held and game.fog_of_war._refreshing
	if fog_callbacks == 1:
		game.fog_of_war.refresh(true)

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	game = $MatchManager
	check(game.current_phase == MatchManager.Phase.PLAYER_TURN, "Generated map starts with three seats")
	var fog := game.fog_of_war
	fog.fog_updated.connect(on_fog_update)
	fog.refresh(true)
	check(fog_callbacks == 1 and nested_guard_held, "Fog listener attempts recursive refresh; guard prevents re-entry")
	fog.fog_updated.disconnect(on_fog_update)
	# Exercise the public recruitment wrapper and end-turn while a real network tween runs.
	LanSession.state = "playing"
	LanSession.hosting = true
	LanSession.local_player_id = 1
	LanSession.game = game
	var mover: Unit
	var starting_town: Building
	for unit: Unit in game.units.values():
		if unit.owner_id == 1:
			mover = unit
	for town: Building in game.buildings.values():
		if town.owner_id == 1:
			starting_town = town
	var destinations := game.board_manager.get_movement_tiles(mover)
	check(not destinations.is_empty() and game.request_move(mover.unit_id, destinations[0]), "LAN move is accepted through the public request")
	var old_count := game.units.size()
	var old_sugar := game.get_player(1).sugars
	var old_sequence := LanSession.next_command
	var prototype: Unit = LanCatalog.UNITS.fighter.instantiate()
	var cost := prototype.data.cost
	prototype.free()
	check(game.request_recruitment(starting_town.building_id, LanCatalog.UNITS.fighter), "Recruitment public wrapper succeeds in host mode")
	check(game.units.size() == old_count + 1 and old_sugar - game.get_player(1).sugars == cost and LanSession.next_command == old_sequence + 1, "Recruitment submits exactly once, creates one unit, and charges once")
	check(not mover.is_animating and mover.network_move_tween.is_running(), "Network movement tween runs without a logical animation lock")
	check(game.request_end_turn() and game.active_player_id == 2, "End Turn succeeds while the network movement tween is still running")
	LanSession.leave()
	game.active_player_id = 1
	game.active_player_index = 0
	for unit: Unit in game.units.values():
		game.remove_unit_authoritative(unit)
	await get_tree().process_frame
	for town: Building in game.buildings.values():
		town.make_neutral()
		town.building_level = 1
		town._update_territory_radius()
	game.territory_manager.cell_to_building_id.clear()
	var towns := game.get_all_buildings_for_network()
	game.territory_manager.rebuild_territories(towns)
	var a: Building
	var b: Building
	var target := Vector2i(-999, -999)
	# Use actual generated towns, with level-4 ranges overlapping on an empty land cell.
	for first: Building in towns:
		if a != null:
			break
		for second: Building in towns:
			if first.building_id >= second.building_id:
				continue
			for cell: Vector2i in game.territory_manager.get_territory_cells(first.current_cell, 3):
				var da := cell - first.current_cell
				var db := cell - second.current_cell
				if maxi(absi(da.x), absi(da.y)) <= 1 or maxi(absi(db.x), absi(db.y)) <= 1 or maxi(absi(db.x), absi(db.y)) > 3:
					continue
				if game.board_manager.is_cell_blocked(cell) or game.board_manager.water_cells.has(cell) or game.board_manager.building_occupied_cells.has(cell) or game.board_manager.resources_occupied_cells.has(cell):
					continue
				a = first
				b = second
				target = cell
				break
			if a != null:
				break
	check(a != null and b != null, "Generated towns have a legal shared expansion cell")
	if a == null:
		get_tree().quit(1)
		return
	a.conquer(game.get_player(1))
	b.conquer(game.get_player(3))
	game.territory_manager.rebuild_territories(towns)
	# B expands before A, legitimately keeping its earlier claim in their overlap.
	b.add_exp(9)
	a.add_exp(9)
	game.territory_manager.rebuild_territories(towns)
	# Seat 2 captures B after these enemy expansions occurred outside its sight.
	b.conquer(game.get_player(2))
	game.active_player_id = 2
	game.active_player_index = 1
	game.get_player(2).unlock_technology(StructureManager.FARM.required_technology_id)
	var host_claim := game.territory_manager.get_building_id_at_cell(target)
	var host_reason := game.structure_manager.placement_error(StructureManager.FARM, target, 2)
	check(host_claim == b.building_id and host_reason.is_empty(), "Host permits building on B's earlier expansion claim")
	# A guest first observes both towns after the expansions. Its prior unknown neutral towns had no claims.
	var codec := MatchSnapshot.new()
	var state: Dictionary = JSON.parse_string(JSON.stringify(codec.capture(game, 2)))
	check(state.towns.any(func(row: Dictionary): return int(row.id) == a.building_id and int(row.owner) == 1), "Capturing B reveals neighboring A in the real recipient snapshot")
	game.territory_manager.cell_to_building_id.clear()
	LanSession.state = "playing"
	LanSession.hosting = false
	LanSession.local_player_id = 2
	LanSession.game = game
	MatchSnapshot.apply(game, state)
	var guest_claim := game.territory_manager.get_building_id_at_cell(target)
	check(guest_claim == host_claim, "Guest preserves original claim at %s: host %d, guest %d" % [target, host_claim, guest_claim])
	# The differing owners make lost claim history block a legal construction request.
	var guest_reason := game.structure_manager.placement_error(StructureManager.FARM, target, 2)
	ResourceChoices.open_tile(game, target)
	check(guest_reason.is_empty() and get_tree().get_first_node_in_group("resource_action_popup") != null, "Guest allows the host-legal build and opens the action panel")
	print("KNOWLEDGE TERRITORY cells=", a.current_cell, " / ", b.current_cell, " overlap=", target, " host_claim=", host_claim, " guest_claim=", guest_claim)
	LanSession.leave()
	# Compare the same seat's local fog presentation with its transmitted remembered state.
	game.active_player_id = 1
	game.human_viewer_id = 1
	for town: Building in towns:
		town.make_neutral()
	a.conquer(game.get_player(2))
	var scout := game.spawn_unit(LanCatalog.UNITS.fighter, game.get_player(1), a.current_cell)
	fog.refresh(true)
	var remembered := MatchSnapshot.new()
	remembered.capture(game, 1)
	game.remove_unit_authoritative(scout)
	fog.refresh(true)
	check(fog.is_cell_explored(a.current_cell, 1) and not fog.is_cell_visible(a.current_cell, 1), "Town was seen, then left outside current sight")
	a.conquer(game.get_player(3))
	fog.refresh(true)
	var unseen := remembered.capture(game, 1)
	var old_owner := -1
	for row: Dictionary in unseen.towns:
		if int(row.id) == a.building_id:
			old_owner = int(row.owner)
	check(not a.visible and a.owner_id == 3 and old_owner == 2 and fog.memory_view.ghosts["town:%d" % a.building_id].texture == fog.knowledge.appearances[1]["town:%d" % a.building_id].texture, "Hidden live town retains authoritative owner 3 while both views remember owner 2")
	var remembered_texture: Texture2D = fog.memory_view.ghosts["town:%d" % a.building_id].texture
	check(remembered_texture == game.get_player(2).tribe.visuals.building_textures[a.data.building_type] and remembered_texture != a.sprite.texture, "Town ghost actually uses the last-seen tribe texture")
	# Switching humans must not overwrite another seat's memory or simulation state.
	GameSession.hotseat_mode = true
	game.active_player_id = 3
	game.human_viewer_id = 3
	fog.refresh(true)
	check(a.visible and fog.viewing_player_id == 3, "New owner's Hotseat view shows its live town")
	game.active_player_id = 1
	game.human_viewer_id = 1
	fog.refresh(true)
	check(not a.visible and fog.memory_view.ghosts["town:%d" % a.building_id].texture == remembered_texture and a.owner_id == 3, "Returning Hotseat human retains private memory without reverting live ownership")
	GameSession.hotseat_mode = false
	# Capture clears a player's actual claim but must not leak an unseen opponent's change.
	game.territory_manager.rebuild_territories(towns)
	fog.refresh(true)
	var hidden_claims: Dictionary = fog.knowledge.view(1).claims.duplicate(true)
	var hidden_town_texture := a.sprite.texture
	a.conquer(game.get_player(2))
	game.territory_manager.rebuild_territories(towns)
	fog.refresh(true)
	check(fog.knowledge.view(1).claims == hidden_claims, "Opponent capture outside sight does not change remembered borders")
	check(a.sprite.texture != hidden_town_texture and fog.memory_view.ghosts["town:%d" % a.building_id].texture == remembered_texture, "Unseen changes affect simulation art but not the displayed ghost")
	# Refresh current knowledge, then collect a visible resource out of the observer's sight.
	var resource: Resources = game.resources.values()[0]
	var resource_id := resource.resource_instance_id
	var resource_cell := resource.current_cell
	var resource_key := "resource:%d" % resource_id
	scout = game.spawn_unit(LanCatalog.UNITS.fighter, game.get_player(1), resource_cell)
	fog.refresh(true)
	check(fog.is_cell_visible(resource_cell, 1) and fog.knowledge.view(1).resources.has(resource_id), "Resource is recorded while seen")
	game.remove_unit_authoritative(scout)
	fog.refresh(true)
	var resource_texture: Texture2D = fog.knowledge.appearances[1][resource_key].texture
	game.board_manager.unregister_resource(resource)
	game.resources.erase(resource_id)
	resource.hide()
	resource.queue_free()
	fog.refresh(true)
	check(fog.memory_view.ghosts.has(resource_key) and fog.memory_view.ghosts[resource_key].visible and fog.memory_view.ghosts[resource_key].texture == resource_texture, "Unseen collection leaves the last-seen resource sprite")
	var resource_view := remembered.capture(game, 1)
	check(resource_view.resources.any(func(row: Dictionary): return int(row.id) == resource_id and not row.get("removed", false)), "Network observer retains the same unseen resource")
	scout = game.spawn_unit(LanCatalog.UNITS.fighter, game.get_player(1), resource_cell)
	fog.refresh(true)
	check(not fog.memory_view.ghosts.has(resource_key) and fog.knowledge.view(1).resources[resource_id].removed, "Revisiting reveals collection and removes the remembered sprite")
	game.remove_unit_authoritative(scout)
	# Build a structure in explored, unseen land; reveal it, then lose sight again.
	var structure := Structure.new()
	structure.data = StructureManager.FARM
	structure.current_cell = resource_cell
	structure.controlling_building_id = a.building_id
	add_child(structure)
	structure.global_position = game.board_manager.cell_to_world(resource_cell)
	game.structure_manager.structures[resource_cell] = structure
	fog.refresh(true)
	var structure_key := "structure:" + str(resource_cell)
	check(not structure.visible and not fog.memory_view.ghosts.has(structure_key), "Unseen enemy construction is not exposed on explored land")
	scout = game.spawn_unit(LanCatalog.UNITS.fighter, game.get_player(1), resource_cell)
	fog.refresh(true)
	check(structure.visible, "New construction appears when actually seen")
	game.remove_unit_authoritative(scout)
	fog.refresh(true)
	check(not structure.visible and fog.memory_view.ghosts[structure_key].visible, "Known structure has a remembered appearance after leaving sight")
	# Same knowledge survives JSON delivery to a guest, including collected-resource memory.
	var remembered_state: Dictionary = JSON.parse_string(JSON.stringify(remembered.capture(game, 1)))
	check(not JSON.stringify(remembered_state).contains("texture") and JSON.stringify(remembered_state).to_utf8_buffer().size() < LanSession.SETTINGS.max_packet_bytes, "Snapshot contains data only and fits the configured packet limit")
	LanSession.state = "playing"
	LanSession.hosting = false
	LanSession.local_player_id = 1
	LanSession.game = game
	MatchSnapshot.apply(game, remembered_state)
	check(not a.visible and fog.memory_view.ghosts["town:%d" % a.building_id].texture == remembered_texture, "Guest imported memory matches local last-seen town artwork")
	check(not structure.visible and fog.memory_view.ghosts[structure_key].visible, "Guest retains unseen structure memory without showing live objects")
	check(game.territory_manager.display_claims == fog.knowledge.view(1).claims, "Guest borders use the transmitted knowledge table")
	# An explicit unclaimed record must remove an older local ownership claim.
	var clear_state: Dictionary = remembered_state.duplicate(true)
	clear_state.claims = [{"cell": LanCatalog.xy(target), "town": -1, "owner": -1}]
	MatchSnapshot.apply(game, clear_state)
	check(game.territory_manager.get_building_id_at_cell(target) == -1, "Authoritative claim removal clears old guest territory")
	LanSession.leave()
	GameSession.match_mode = GameSession.REGULAR
	fog.refresh(true)
	check(a.visible and structure.visible and not fog.memory_view.ghosts["town:%d" % a.building_id].visible, "Regular mode displays current entities and hides memory proxies")
	print("KNOWLEDGE REGRESSION: %d checks, %d failures" % [checks, failures])
	await get_tree().process_frame
	get_tree().quit(1 if failures else 0)
