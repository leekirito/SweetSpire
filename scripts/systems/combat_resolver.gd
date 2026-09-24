class_name CombatResolver
extends RefCounted
 

func request_move(game: MatchManager, unit_id: int, target_cell: Vector2i) -> bool:
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
	game.board_manager.animate_unit_move(unit, old_world_position, target_cell)
	return true


func request_attack(game: MatchManager, attacker_id: int, target_id: int) -> bool:
	var attacker: Unit = game.get_unit(attacker_id)
	var target: Unit = game.get_unit(target_id)
	if attacker == null or target == null:
		return false
	if attacker.owner_id != game.active_player_id or target.owner_id == game.active_player_id:
		return false
	if attacker.has_attacked or attacker.is_animating or target.is_animating:
		return false
	if target.current_cell not in game.board_manager.get_attack_tiles(attacker):
		return false

	target.take_damage(attacker.get_attack_damage())
	attacker.has_attacked = true
	attacker.has_moved = true

	if target.is_dead():
		game.remove_unit_authoritative(target)
		game.evaluate_eliminations()

	return true
