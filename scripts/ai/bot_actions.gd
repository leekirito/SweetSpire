class_name BotActions
extends RefCounted

## Scores collection, upgrades, useful prerequisite research, recruitment, and construction
## using the bot's copied knowledge and owned territory.

## Candidates contain only wire-safe commands and bounded utility scores.
static func offer(actions: Array, command: Dictionary, score: float, reason: String) -> void:
	if score > 0.0:
		actions.append({"command": command, "score": clampf(score, 0.0, 1.0), "reason": reason})

## Builds development options from copied knowledge; the authority revalidates each submission.
static func economy(view: Dictionary, profile: BotProfile) -> Array:
	var actions: Array = []
	var own_units := 0
	var own_towns := 0
	var docks := 0
	for unit: Dictionary in view.units:
		if unit.owner == view.seat:
			own_units += 1
	for town: Dictionary in view.towns:
		if town.owner == view.seat:
			own_towns += 1
	for structure: Dictionary in view.structures.values():
		if structure.owner == view.seat and structure.dock:
			docks += 1
	var possible_dock := false
	var build_cells: Array = view.territory.keys()
	build_cells.sort_custom(func(a: Vector2i, b: Vector2i): return distance_to_center(view, a) < distance_to_center(view, b) if distance_to_center(view, a) != distance_to_center(view, b) else (a.x < b.x if a.x != b.x else a.y < b.y))
	var desired: Dictionary = {}
	for tile: Dictionary in view.tiles.values():
		if tile.mountain:
			desired["climbing"] = 0.45 * profile.expansion_weight
			break
	for resource: Dictionary in view.resources:
		if resource.owner != view.seat or view.structures.has(resource.cell):
			continue
		if resource.collect:
			if BotObservation.has_tech(view, resource.collect_tech):
				var preservation := 0.6 if resource.kind in ["forest", "mountain"] else 1.0
				offer(actions, {"action": "collect", "id": resource.id}, minf(0.87, 0.65 * profile.economy_weight * preservation), "collect resources")
			else:
				desired[resource.collect_tech] = 0.58 * profile.economy_weight
		if resource.upgrade:
			if BotObservation.has_tech(view, resource.upgrade_tech):
				offer(actions, {"action": "upgrade", "id": resource.id}, 0.60 * profile.economy_weight, "upgrade resource")
			else:
				desired[resource.upgrade_tech] = 0.5 * profile.economy_weight
	# Placement candidates are generated from known terrain and own territory.
	for cell: Vector2i in build_cells:
		if not view.tiles.has(cell) or view.tiles[cell].blocked or BotNavigation.occupied(view, cell) or view.structures.has(cell):
			continue
		var town_cell := false
		for town: Dictionary in view.towns:
			town_cell = town_cell or town.cell == cell
		if town_cell:
			continue
		var resource: Dictionary = {}
		for entry: Dictionary in view.resources:
			if entry.cell == cell:
				resource = entry
				break
		var key := ""
		if view.tiles[cell].water:
			if profile.allow_naval and not view.tiles[cell].ocean and resource.is_empty():
				for direction: Vector2i in BotNavigation.DIRECTIONS:
					var neighbor: Dictionary = view.tiles.get(cell + direction, {})
					if not neighbor.is_empty() and not neighbor.water and not neighbor.blocked:
						key = "dock"
						possible_dock = true
		elif resource.get("kind", "") == "forest":
			key = "lumber_factory"
		elif resource.get("kind", "") == "mountain":
			key = "mining_den"
		elif resource.is_empty():
			key = "farm"
		if key.is_empty() or not profile.allow_construction:
			continue
		var data: StructureData = LanCatalog.STRUCTURES[key]
		var dock_priority := key == "dock" and docks == 0
		var value := 0.48 * profile.economy_weight * minf(1.4, float(profile.investment_horizon * data.sugar_per_round) / maxi(1, data.sugar_cost))
		if key == "dock":
			value = 0.86 * profile.sweetspire_weight if dock_priority else 0.15
			value -= minf(0.15, float(distance_to_center(view, cell)) / 1000.0)
		if not BotObservation.has_tech(view, data.required_technology_id):
			desired[data.required_technology_id] = maxf(float(desired.get(data.required_technology_id, 0.0)), value)
		elif view.sugar >= data.sugar_cost + (0 if dock_priority else profile.reserve_sugar):
			offer(actions, {"action": "build", "key": key, "cell": LanCatalog.xy(cell)}, value, "naval access" if dock_priority else "income investment")
	if profile.allow_naval and docks == 0 and possible_dock:
		desired["sailing"] = 0.82 * profile.sweetspire_weight
	if profile.allow_recruitment and own_units < own_towns * 2 + profile.coordination_limit:
		for town: Dictionary in view.towns:
			if town.owner != view.seat or town.recruited == view.round or BotNavigation.occupied(view, town.cell):
				continue
			for key: String in town.units:
				if not LanCatalog.UNITS.has(key) or (key == "caster" and not profile.allow_area_attacks):
					continue
				var prototype: Unit = LanCatalog.UNITS[key].instantiate()
				var data: UnitData = prototype.data
				prototype.free()
				var value := profile.recruitment_weight * (0.66 if own_units <= own_towns else 0.44)
				if key == "caster":
					value += 0.06
				if key == "pathfinder":
					value += 0.04 * profile.expansion_weight
				if not BotObservation.has_tech(view, data.required_technology_id):
					desired[data.required_technology_id] = maxf(float(desired.get(data.required_technology_id, 0)), value * 0.7)
				elif view.sugar >= data.cost + (0 if own_units <= own_towns else profile.reserve_sugar):
					offer(actions, {"action": "recruit", "id": town.id, "key": key}, value, "reinforce army")
	if profile.allow_research:
		# Traverse prerequisite chains; never value an unimplemented effect solely by its description.
		for id: String in desired:
			var tech: TechnologyData = LanCatalog.TECHS.get(id)
			if tech == null or BotObservation.has_tech(view, id):
				continue
			while tech.prerequisite_technology != null and not BotObservation.has_tech(view, tech.prerequisite_technology.technology_id):
				tech = tech.prerequisite_technology
			if view.sugar >= tech.cost:
				offer(actions, {"action": "technology", "key": tech.technology_id}, minf(0.9, float(desired[id]) * profile.research_weight), "research for a usable capability")
	return actions

## Returns the shortest Manhattan distance to an objective tile.
static func distance_to_center(view: Dictionary, cell: Vector2i) -> int:
	var result := 999999
	for center: Vector2i in view.center:
		result = mini(result, BotNavigation.distance(cell, center))
	return result
