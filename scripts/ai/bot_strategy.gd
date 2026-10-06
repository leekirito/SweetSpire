class_name BotStrategy
extends RefCounted

static func threat(view: Dictionary, cell: Vector2i, profile: BotProfile) -> float:
	var value := 0.0
	for enemy: Dictionary in view.units:
		if enemy.owner == view.seat:
			continue
		var radius := 1
		for offset: Vector2i in enemy.attack:
			radius = maxi(radius, maxi(absi(offset.x), absi(offset.y)))
		var distance := BotNavigation.distance(cell, enemy.cell)
		if distance <= radius + profile.lookahead_depth:
			value += float(enemy.damage) / maxf(1.0, float(distance))
	return value

static func unit_actions(view: Dictionary, unit: Dictionary, profile: BotProfile, memory: BotMemory) -> Array:
	var actions: Array = []
	var attacks := BotNavigation.attacks(view, unit)
	if not unit.attacked and (not unit.area or profile.allow_area_attacks):
		for cell: Vector2i in attacks:
			var hits: Array = [cell]
			if unit.area:
				for offset: Vector2i in unit.blast:
					if cell + offset in attacks:
						hits.append(cell + offset)
			var value := 0.0
			var enemy_hits := 0
			for target: Dictionary in view.units:
				if target.cell not in hits:
					continue
				var damage := minf(unit.damage, target.hp + target.shield)
				var benefit := damage / maxf(1.0, float(target.hp + target.shield))
				if target.owner != view.seat:
					enemy_hits += 1
					value += 0.30 + benefit * 0.38
				elif unit.area and unit.allies:
					value -= (0.30 + benefit * 0.38) * profile.friendly_fire_penalty
			if enemy_hits > 0:
				BotActions.offer(actions, {"action": "attack", "id": unit.id, "cell": LanCatalog.xy(cell)}, minf(0.94, value), "attack visible enemies")
	if unit.moved:
		return actions
	# Holding a town or the center matters at round end; do not wander away.
	for town: Dictionary in view.towns:
		if town.cell == unit.cell and town.owner != view.seat:
			return actions
	if unit.cell in view.center and float(unit.hp) / maxi(1, unit.max_hp) > profile.retreat_health_ratio:
		return actions
	var moves := BotNavigation.moves(view, unit, profile)
	if moves.is_empty():
		return actions
	var goal := choose_goal(view, unit, profile, memory)
	var path: Array[Vector2i] = goal.get("path", [])
	var low_health := float(unit.hp) / maxi(1, unit.max_hp) <= profile.retreat_health_ratio
	var current_threat := threat(view, unit.cell, profile)
	var candidates: Array = []
	for cell: Vector2i in moves:
		var progress := 0.0
		if not path.is_empty():
			var remaining := BotNavigation.distance(cell, path[-1])
			var original := BotNavigation.distance(unit.cell, path[-1])
			# Following a real route can temporarily move away from the destination.
			var on_path := path.find(cell)
			progress = (0.12 + minf(0.2, float(on_path + 1) * 0.035)) if on_path >= 0 else clampf(float(original - remaining) * 0.04, -0.1, 0.1)
		var frontier := 0
		for direction: Vector2i in BotNavigation.DIRECTIONS:
			if not view.tiles.has(cell + direction):
				frontier += 1
		var exposure := threat(view, cell, profile)
		var value := 0.22 + progress + frontier * 0.035 * profile.expansion_weight
		if not goal.is_empty():
			value += minf(0.18, float(goal.get("value", 0.0)) * 0.15)
		value -= exposure * (1.0 - profile.risk_tolerance) * profile.retaliation_weight * 0.06
		if low_health:
			value += (current_threat - exposure) * profile.defense_weight * 0.12
		if unit.boat and not view.tiles[cell].water and cell not in view.center:
			value -= 0.3
		if memory.previous_cells.get(unit.id) == cell:
			value -= 0.25
		if cell in view.center:
			value = 1.0 if view.center_rounds + 1 >= view.center_target else 0.93 * minf(1.0, profile.sweetspire_weight)
		for town: Dictionary in view.towns:
			if town.cell == cell and town.owner != view.seat:
				value = 0.92 * minf(1.0, profile.expansion_weight)
		if not profile.allow_naval and view.tiles[cell].water:
			continue
		BotActions.offer(candidates, {"action": "move", "id": unit.id, "cell": LanCatalog.xy(cell)}, value, str(goal.get("reason", "explore")))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score)
	actions.append_array(candidates.slice(0, profile.candidate_limit))
	return actions

static func choose_goal(view: Dictionary, unit: Dictionary, profile: BotProfile, memory: BotMemory) -> Dictionary:
	var old: Dictionary = memory.goals.get(unit.id, {})
	var threatened := threat(view, unit.cell, profile) >= profile.threat_response_threshold
	if not old.is_empty() and view.round - int(old.round) < profile.goal_commitment_turns and unit.cell != old.cell and not threatened and not BotNavigation.occupied(view, old.cell):
		var route := BotNavigation.route(view, unit, old.cell, profile)
		if not route.is_empty():
			return {"path": route, "value": old.value, "reason": old.reason}
	var targets: Array = []
	for town: Dictionary in view.towns:
		if town.owner != view.seat:
			targets.append({"cell": town.cell, "value": 1.2 * profile.expansion_weight, "reason": "capture town"})
		elif threat(view, town.cell, profile) >= profile.threat_response_threshold:
			targets.append({"cell": town.cell, "value": 1.5 * profile.defense_weight, "reason": "defend town"})
	for cell: Vector2i in view.center:
		if view.tiles.has(cell):
			targets.append({"cell": cell, "value": 1.8 * profile.sweetspire_weight, "reason": "hold Sweetspire"})
	var frontier: Array = []
	for cell: Vector2i in view.tiles:
		if view.tiles[cell].blocked:
			continue
		for direction: Vector2i in BotNavigation.DIRECTIONS:
			if not view.tiles.has(cell + direction):
				if not unit.boat or view.tiles[cell].water:
					frontier.append({"cell": cell, "value": (1.5 * profile.sweetspire_weight if unit.boat else 0.65 * profile.expansion_weight), "reason": "sail toward Sweetspire" if unit.boat else "explore"})
				break
	# Include nearby frontier options, with a centerward bias for crossing the ocean.
	frontier.sort_custom(func(a: Dictionary, b: Dictionary): return BotNavigation.distance(unit.cell, a.cell) * (0.1 if unit.boat else 1.0) + BotActions.distance_to_center(view, a.cell) * (1.0 if unit.boat else 0.2) < BotNavigation.distance(unit.cell, b.cell) * (0.1 if unit.boat else 1.0) + BotActions.distance_to_center(view, b.cell) * (1.0 if unit.boat else 0.2))
	targets.append_array(frontier.slice(0, 8))
	for cell: Vector2i in view.structures:
		if view.structures[cell].dock and view.structures[cell].owner == view.seat and profile.allow_naval and not unit.boat:
			targets.append({"cell": cell, "value": 1.1 * profile.sweetspire_weight, "reason": "embark at dock"})
	targets.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.value) / (3 + BotNavigation.distance(unit.cell, a.cell)) > float(b.value) / (3 + BotNavigation.distance(unit.cell, b.cell)))
	var best: Dictionary = {}
	var best_score := -INF
	for target: Dictionary in targets.slice(0, 12):
		if target.cell == unit.cell or BotNavigation.occupied(view, target.cell):
			continue
		var assigned := 0
		for id in memory.goals:
			if id != unit.id and memory.goals[id].cell == target.cell:
				assigned += 1
		var route := BotNavigation.route(view, unit, target.cell, profile)
		if route.is_empty():
			continue
		var score := float(target.value) / (3 + route.size())
		if assigned >= profile.coordination_limit:
			score *= 0.25
		if score > best_score:
			best_score = score
			best = {"path": route, "cell": target.cell, "value": target.value, "reason": target.reason}
	if not best.is_empty():
		memory.goals[unit.id] = {"cell": best.cell, "round": view.round, "value": best.value, "reason": best.reason}
	return best
