extends Node2D

var failures := 0
var checks := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _enter_tree() -> void:
	var session := get_tree().root.get_node("GameSession")
	for id in [1, 2]:
		var player := PlayerState.new()
		player.player_id = id
		player.player_name = "Test %d" % id
		player.tribe = load("res://scripts/data/Tribe/SABA.tres" if id == 1 else "res://scripts/data/Tribe/KAMOTE.tres")
		player.sugars = 100
		session.add_player(player)


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var game := get_node("MatchManager") as MatchManager
	var board := game.board_manager
	var controller := get_node("PlayerController") as PlayerController
	game.fog_of_war = null
	var caster_cell := Vector2i(50, 50)
	var center := Vector2i(51, 53)
	var enemy_cell := Vector2i(50, 53)
	var second_enemy_cell := Vector2i(52, 53)
	var outside_enemy_cell := Vector2i(51, 54)
	var ally_cell := Vector2i(52, 52)
	var close_ally_cell := Vector2i(51, 50)
	var far_ally_cell := Vector2i(52, 49)
	for x in range(49, 54):
		for y in range(49, 55):
			board.tile_map_layer.set_cell(Vector2i(x, y), 39, Vector2i(4, 0))
	board.astar_grid.region = board.tile_map_layer.get_used_rect()
	board.astar_grid.update()
	board._refresh_solid_cells()
	var caster_scene := preload("res://scenes/entities/player/Caster.tscn")
	var fighter_scene := preload("res://scenes/entities/player/Fighter.tscn")
	var caster := game.spawn_unit(caster_scene, game.get_player(1), caster_cell)
	var enemy := game.spawn_unit(fighter_scene, game.get_player(2), enemy_cell)
	var second_enemy := game.spawn_unit(fighter_scene, game.get_player(2), second_enemy_cell)
	var outside_enemy := game.spawn_unit(fighter_scene, game.get_player(2), outside_enemy_cell)
	var ally := game.spawn_unit(fighter_scene, game.get_player(1), ally_cell)
	var close_ally := game.spawn_unit(fighter_scene, game.get_player(1), close_ally_cell)
	var far_ally := game.spawn_unit(fighter_scene, game.get_player(1), far_ally_cell)
	var ally_caster := game.spawn_unit(caster_scene, game.get_player(1), Vector2i(53, 50))
	check(caster != null and enemy != null and second_enemy != null and outside_enemy != null and ally != null and close_ally != null and far_ally != null and ally_caster != null, "Test units spawned")
	if caster == null or enemy == null or second_enemy == null or outside_enemy == null or ally == null or close_ally == null or far_ally == null or ally_caster == null:
		get_tree().quit(1)
		return
	var original_center := game.sweetspire_center_cell
	game.sweetspire_center_cell = caster_cell
	check(game.get_center_cells() == [Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)], "Center objective covers four tiles")
	check(game.get_center_controller() == game.get_player(1), "A unit on one center tile controls the objective")
	var contesting_enemy := game.spawn_unit(fighter_scene, game.get_player(2), Vector2i(51, 51))
	check(contesting_enemy != null, "Opponent can enter a different center tile")
	if contesting_enemy != null:
		check(game.get_center_controller() == null, "Opposing units contest the 2x2 center")
		game.remove_unit_authoritative(contesting_enemy)
		check(game.get_center_controller() == game.get_player(1), "Control returns when the opponent leaves")
	game.sweetspire_center_cell = original_center
	check(caster.defence_ui.visible == (caster.defence > 0), "Caster shield bar follows its configured Defence")
	ally_caster.defence = 2
	ally_caster.defence_ui.max_value = 2
	ally_caster.update_ui()
	check(ally_caster.defence_ui.visible, "Shield bar appears when a caster has Defence")
	caster.data.can_hit_allies = false
	caster.data.meteor_effect_time = 0.5
	caster.data.meteor_decal_time_offset = -0.1
	caster.data.meteor_decal_fade_seconds = 0.5
	check(caster.has_area_attack(), "Caster has area attack data")
	check(caster.data.blast_pattern.shape == RangePattern.Shape.SQUARE, "Caster keeps a square blast")
	var highlighted: Array[Vector2i] = game.get_visible_attack_tiles(caster)
	check(center in highlighted, "Empty target is in casting range")
	check(board.get_unit_id_at_cell(center) == -1, "Target tile is empty")
	check(board.movement_overlay != null and board.movement_overlay.material is ShaderMaterial, "Movement highlights have their own shader layer")
	board.highlight_blast_cell(center)
	board.highlight_attack_cell(center)
	check(board.movement_overlay.get_cell_source_id(center) == board.movement_source_id, "Blue blast preview uses the movement layer")
	check(board.tile_map_overlay.get_cell_source_id(center) == board.attack_source_id, "Red attack highlight stays on its own layer")
	board.clear_overlay()
	check(board.movement_overlay.get_cell_source_id(center) == -1 and board.tile_map_overlay.get_cell_source_id(center) == -1, "Clearing highlights resets both layers")
	check(enemy_cell in board.get_blast_cells(caster, center, highlighted), "Enemy is in blast")
	check(ally_cell in board.get_blast_cells(caster, center, highlighted), "Outer ally is in blast")
	var blast_cells := board.get_blast_cells(caster, center, highlighted)
	check(outside_enemy_cell not in highlighted, "Outside enemy is not highlighted")
	check(outside_enemy_cell not in board.get_blast_cells(caster, center, highlighted), "Blast cannot overflow red tiles")
	check(close_ally_cell not in highlighted, "Adjacent box is not targetable")
	controller.selected_unit_id = caster.unit_id
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	controller._unhandled_input(right_click)
	check(controller.is_aiming, "Right-click action enters Aim mode")
	controller._unhandled_input(right_click)
	check(not controller.is_aiming, "Right-click action cancels Aim mode")
	controller._unhandled_input(right_click)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	controller._unhandled_input(escape)
	check(not controller.is_aiming, "Escape cancels Aim mode")
	controller._unhandled_input(right_click)
	var enemy_before := enemy.unit_health + enemy.defence
	var second_enemy_before := second_enemy.unit_health + second_enemy.defence
	var outside_enemy_before := outside_enemy.unit_health + outside_enemy.defence
	var ally_before := ally.unit_health + ally.defence
	controller._handle_aim_click(center)
	check(enemy.unit_health + enemy.defence == enemy_before, "Cast waits for meteor impact before damage")
	var meteor_effect := _get_meteor_effect()
	check(meteor_effect != null, "Meteor effect scene exists before damage")
	var initial_meteor_rotation := 0.0
	if meteor_effect != null:
		check(meteor_effect.trail.emitting, "Meteor trail particles start with the effect")
		var meteor_sprite := meteor_effect.get_node_or_null("MeteorSprite") as Sprite2D
		var blast_size := board.get_cells_world_size(blast_cells)
		if meteor_sprite != null:
			initial_meteor_rotation = meteor_sprite.rotation
			var expected_scale := maxf(blast_size.x, blast_size.y) / maxf(meteor_sprite.texture.get_size().x, meteor_sprite.texture.get_size().y) * meteor_effect.size_multiplier * 1.2
			check(is_equal_approx(meteor_sprite.scale.x, expected_scale), "Meteor size follows the blast footprint")
	check(not game.request_end_turn(), "Turn cannot end during the attack animation")
	check(game.combat_resolver.attack_in_progress, "Combat remains locked until animation finishes")
	await get_tree().create_timer(0.22).timeout
	if meteor_effect != null:
		check(absf(meteor_effect.meteor_sprite.rotation - initial_meteor_rotation) > 0.01, "Meteor sprite spins while falling")
	await get_tree().create_timer(0.22).timeout
	check(enemy.unit_health + enemy.defence == enemy_before, "Early decals do not apply damage")
	check(_count_cracks(board) == blast_cells.size(), "Decals can appear before impact")
	await get_tree().create_timer(0.3).timeout
	check(enemy.unit_health + enemy.defence == enemy_before - caster.unit_damage, "Empty-tile cast damages enemy")
	check(second_enemy.unit_health + second_enemy.defence == second_enemy_before - caster.unit_damage, "One cast damages a second enemy")
	check(outside_enemy.unit_health + outside_enemy.defence == outside_enemy_before, "Enemy outside red tiles is not damaged")
	check(ally.unit_health + ally.defence == ally_before, "Friendly fire off protects ally")
	check(caster.has_attacked and caster.has_moved and not controller.is_aiming, "Cast spends actions and leaves Aim mode")
	check(not game.combat_resolver.attack_in_progress, "Combat unlocks after impact animation")
	if meteor_effect != null:
		check(not meteor_effect.trail.emitting, "Meteor trail particles stop at impact")
	check(_count_cracks(board) == blast_cells.size(), "Meteor leaves a decal on every blast tile")
	check(_has_crack_at(board, center), "Empty targeted tile receives a decal")
	check(_has_sprite_decal(board, caster.data.meteor_decal_texture), "Meteor decal uses the configured sprite")
	board.clear_overlay()
	check(_count_cracks(board) == blast_cells.size(), "Highlight refresh does not erase decals")
	await get_tree().create_timer(1.2).timeout
	check(_count_cracks(board) == 0, "Crack fades away after its configured duration")
	caster.data.meteor_decal_fade_seconds = 5.0
	caster.data.meteor_decal_time_offset = 0.25
	caster.has_attacked = false
	caster.has_moved = false
	caster.data.can_hit_allies = true
	check(not game.request_attack_at_cell(caster.unit_id, close_ally_cell), "Adjacent tile cannot be targeted")
	check(not caster.has_attacked, "Rejected close cast does not spend the attack")
	var close_ally_before := close_ally.unit_health + close_ally.defence
	var far_ally_before := far_ally.unit_health + far_ally.defence
	var caster_before := caster.unit_health + caster.defence
	var ally_caster_health_before := ally_caster.unit_health
	var second_center := Vector2i(52, 50)
	var second_blast := board.get_blast_cells(caster, second_center, game.get_visible_attack_tiles(caster))
	check(ally_caster.current_cell in second_blast, "Allied caster is inside the valid blast")
	check(game.request_attack_at_cell(caster.unit_id, second_center), "Second empty-tile cast accepted")
	check(far_ally.unit_health + far_ally.defence == far_ally_before, "Friendly fire waits for meteor impact")
	check(ally_caster.defence == 2, "Allied caster shield waits for impact")
	await get_tree().create_timer(0.7).timeout
	check(far_ally.unit_health + far_ally.defence == far_ally_before - caster.unit_damage, "Friendly fire on damages ally in red tiles")
	check(ally_caster.defence == 0 and ally_caster.unit_health == ally_caster_health_before, "Friendly meteor consumes allied caster shield before health")
	check(not ally_caster.defence_ui.visible, "Shield bar hides after allied caster shield is depleted")
	check(_count_cracks(board) == 0, "Positive decal offset waits until after damage")
	await get_tree().create_timer(0.15).timeout
	check(_count_cracks(board) == second_blast.size(), "Late decals appear on every blast tile")
	check(close_ally.unit_health + close_ally.defence == close_ally_before, "Close ally stays safe with friendly fire on")
	check(caster.unit_health + caster.defence == caster_before, "Caster cannot hit himself")
	check(not game.request_attack_at_cell(close_ally.unit_id, Vector2i(51, 51)), "Ordinary units cannot attack empty tiles")
	var ordinary_enemy := game.spawn_unit(fighter_scene, game.get_player(2), Vector2i(51, 51))
	check(ordinary_enemy != null, "Ordinary attack target spawned")
	if ordinary_enemy != null:
		var ordinary_before := ordinary_enemy.unit_health + ordinary_enemy.defence
		check(game.request_attack(close_ally.unit_id, ordinary_enemy.unit_id), "Ordinary single-target attack still works")
		check(ordinary_enemy.unit_health + ordinary_enemy.defence == ordinary_before, "Slash waits for impact before damage")
		await get_tree().create_timer(0.45).timeout
		check(ordinary_enemy.unit_health + ordinary_enemy.defence == ordinary_before - close_ally.unit_damage, "Single-target attack damages only its target")
		ordinary_enemy.unit_health = 1
		ordinary_enemy.defence = 0
		var defeated_id := ordinary_enemy.unit_id
		var defeated_texture := ordinary_enemy.sprite.texture
		var victims: Array[Unit] = [ordinary_enemy]
		game.combat_resolver._on_attack_impact(game, victims, 99)
		check(game.get_unit(defeated_id) == null, "Defeated unit leaves the board immediately")
		var death_fling: DeathFling
		for child: Node in get_tree().current_scene.get_children():
			if child is DeathFling:
				death_fling = child
				break
		check(death_fling != null, "Defeated sprite continues as a separate animation")
		if death_fling != null:
			check((death_fling.get_child(0) as Sprite2D).texture == defeated_texture, "Death animation uses the defeated unit's sprite")
			check(not board.tile_map_layer.get_used_rect().has_point(board.cell_from_world(death_fling.destination)), "Defeated sprite flies beyond the board")
			await get_tree().create_timer(1.5).timeout
			check(not is_instance_valid(death_fling), "Death animation cleans itself up")
	var player := game.get_player(1)
	player.unlock_technology("marksmanship")
	player.unlock_technology("pathfinding")
	player.unlock_technology("runecraft")
	var town: Building
	for building: Building in game.buildings.values():
		if building.owner_id == 1:
			town = building
			break
	check(town != null, "Player has a starting town")
	if town != null:
		var popup := preload("res://scenes/UI/Recruit.tscn").instantiate()
		add_child(popup)
		popup.setup(town)
		check(
			popup.choices.size() == 4
			and popup.units.has("Caster")
			and popup.choices[3].visible
			and popup.choices[3].get_meta("unit_key", "") == "Caster",
			"Recruitment shows a fourth Caster choice"
		)
		popup.queue_free()
	print("Caster regression: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _count_cracks(board: BoardManager) -> int:
	var count := 0
	for child: Node in board.tile_map_overlay.get_children():
		if child is Sprite2D and child.is_in_group("meteor_decals"):
			count += 1
	return count


func _has_crack_at(board: BoardManager, cell: Vector2i) -> bool:
	for child: Node in board.tile_map_overlay.get_children():
		if child is Sprite2D and child.is_in_group("meteor_decals") and (child as Node2D).global_position.is_equal_approx(board.cell_to_world(cell)):
			return true
	return false


func _has_sprite_decal(board: BoardManager, texture: Texture2D) -> bool:
	for child: Node in board.tile_map_overlay.get_children():
		if child is Sprite2D and child.is_in_group("meteor_decals") and (child as Sprite2D).texture == texture:
			return true
	return false


func _get_meteor_effect() -> MeteorEffect:
	for child: Node in get_tree().current_scene.get_children():
		if child is MeteorEffect:
			return child
	return null
