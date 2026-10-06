class_name CombatResolver
extends RefCounted

## Validates and resolves unit moves, attacks, area damage, and casualties.
## Local combat uses presentation impact timing; LAN resolves rules independently of playback.


const ATTACK_PRESENTATION: GDScript = preload("res://scripts/effects/attack_presentation.gd")
const DEATH_FLING: GDScript = preload("res://scripts/effects/death_fling.gd")

var attack_in_progress: bool = false

## Validates ownership and remaining movement, commits the destination, then presents motion.
func request_move(game: MatchManager, unit_id: int, target_cell: Vector2i) -> bool:
	if attack_in_progress:
		return false
	var unit: Unit = game.get_unit(unit_id)
	if unit == null or unit.owner_id != game.active_player_id:
		return false
	if unit.has_moved or unit.is_animating:
		return false
	if not game.board_manager.can_move_to(unit, target_cell):
		return false

	var old_world_position: Vector2 = unit.global_position
	unit.has_moved = true
	game.board_manager.commit_unit_move(unit, target_cell)
	game.structure_manager.on_unit_arrived(unit)
	if LanSession.active():
		unit.global_position = game.board_manager.cell_to_world(target_cell)
		unit.present_network_move(old_world_position)
		game.vision_sources_changed.emit()
	else:
		game.board_manager.animate_unit_move(unit, old_world_position, target_cell)
	return true


## Resolves the target unit's cell and delegates to tile-based validation.
func request_attack(game: MatchManager, attacker_id: int, target_id: int) -> bool:
	var target: Unit = game.get_unit(target_id)
	if target == null:
		return false
	return request_attack_at_cell(game, attacker_id, target.current_cell)


## Validates targeting, consumes movement/attack, and resolves ordinary or area damage.
## LAN applies state immediately; local combat waits for the presentation impact signal.
func request_attack_at_cell(game: MatchManager, attacker_id: int, target_cell: Vector2i) -> bool:
	if attack_in_progress:
		return false
	var attacker: Unit = game.get_unit(attacker_id)
	if attacker == null or attacker.owner_id != game.active_player_id:
		return false
	if attacker.has_attacked or attacker.is_animating:
		return false
	var targetable: Array[Vector2i] = game.get_visible_attack_tiles(attacker)
	if target_cell not in targetable:
		return false

	var target_cells: Array[Vector2i] = [target_cell]
	if attacker.has_area_attack():
		target_cells = game.board_manager.get_blast_cells(attacker, target_cell, targetable)
	var targets: Array[Unit] = []
	for cell: Vector2i in target_cells:
		var target: Unit = game.get_unit(game.board_manager.get_unit_id_at_cell(cell))
		if target == null:
			continue
		if target.owner_id == attacker.owner_id and (
			not attacker.has_area_attack() or not attacker.data.can_hit_allies
		):
			continue
		if target.is_animating:
			return false
		targets.append(target)
	if targets.is_empty() and not attacker.has_area_attack():
		return false

	attacker.has_attacked = true
	attacker.has_moved = true
	if LanSession.active():
		LanSession.present_attack(attacker, target_cell, target_cells)
		_on_attack_impact(game, targets, attacker.get_attack_damage())
		return true
	attacker.is_animating = true
	attack_in_progress = true
	var presentation: AttackPresentation = ATTACK_PRESENTATION.new()
	presentation.visible = game.is_cell_visible_to_player(attacker.current_cell, game.get_viewing_player_id()) or game.is_cell_visible_to_player(target_cell, game.get_viewing_player_id())
	game.get_tree().current_scene.add_child(presentation)
	presentation.decals_due.connect(_on_attack_decals_due.bind(
		game, target_cells, attacker.data.meteor_decal_texture,
		attacker.data.meteor_decal_tint,
		attacker.data.meteor_decal_size_multiplier,
		attacker.data.meteor_decal_fade_seconds
	))
	presentation.impact.connect(_on_attack_impact.bind(
		game, targets, attacker.get_attack_damage()
	))
	presentation.finished.connect(_on_attack_finished.bind(attacker))
	presentation.play_attack(
		attacker.global_position,
		game.board_manager.cell_to_world(target_cell),
		attacker.data,
		game.board_manager.get_cells_world_size(target_cells)
	)
	return true


## Applies damage, removes casualties, and checks elimination; feedback respects the viewer's sight.
func _on_attack_impact(
	game: MatchManager,
	targets: Array[Unit],
	damage: int
) -> void:
	var defeated: Array[Unit] = []
	for target: Unit in targets:
		if not is_instance_valid(target) or target.is_dead():
			continue
		var show_feedback := game.is_cell_visible_to_player(target.current_cell, game.get_viewing_player_id())
		target.take_damage(damage, show_feedback)
		if target.is_dead():
			defeated.append(target)
	for target: Unit in defeated:
		if game.is_cell_visible_to_player(target.current_cell, game.get_viewing_player_id()):
			var fling: DeathFling = DEATH_FLING.new()
			game.get_tree().current_scene.add_child(fling)
			fling.launch(target, game.board_manager)
		game.remove_unit_authoritative(target)
	if not defeated.is_empty():
		game.evaluate_eliminations()


## Creates decals only for affected cells visible to the human viewer.
func _on_attack_decals_due(
	game: MatchManager,
	target_cells: Array[Vector2i],
	decal_texture: Texture2D,
	tint: Color,
	size_multiplier: float,
	fade_seconds: float
) -> void:
	var visible_cells: Array[Vector2i] = []
	for cell: Vector2i in target_cells:
		if game.is_cell_visible_to_player(cell, game.get_viewing_player_id()):
			visible_cells.append(cell)
	game.board_manager.show_meteor_decals(visible_cells, decal_texture, tint, size_multiplier, fade_seconds)



func _on_attack_finished(attacker: Unit) -> void:
	attack_in_progress = false
	if is_instance_valid(attacker):
		attacker.is_animating = false
