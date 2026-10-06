class_name BotNavigation
extends RefCounted
const DIRECTIONS := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func occupied(view: Dictionary, cell: Vector2i) -> bool:
	for unit: Dictionary in view.units:
		if unit.cell == cell:
			return true
	return false

static func passable(view: Dictionary, unit: Dictionary, cell: Vector2i, from: Vector2i, boat: bool) -> bool:
	if not view.tiles.has(cell):
		return false
	var tile: Dictionary = view.tiles[cell]
	if unit.flying:
		return true
	if tile.blocked:
		return false
	if tile.water:
		var structure: Dictionary = view.structures.get(cell, {})
		if structure.get("dock", false) and int(structure.owner) != int(view.seat):
			return false
		return boat or (unit.water and not unit.boat) or (distance(from, cell) == 1 and structure.get("dock", false))
	return unit.land and (not tile.mountain or BotObservation.has_tech(view, "climbing"))

static func clear_path(view: Dictionary, unit: Dictionary, target: Vector2i, movement: bool) -> bool:
	var start: Vector2i = unit.cell
	var steps := maxi(absi(target.x - start.x), absi(target.y - start.y))
	var previous := start
	for index in range(1, steps + 1):
		var cell := Vector2i(Vector2(start).lerp(Vector2(target), float(index) / steps).round())
		var checks: Array = []
		if cell != target:
			checks.append(cell)
		if cell.x != previous.x and cell.y != previous.y:
			checks.append(Vector2i(cell.x, previous.y))
			checks.append(Vector2i(previous.x, cell.y))
		for check_cell: Vector2i in checks:
			if not view.tiles.has(check_cell):
				return false
			var tile: Dictionary = view.tiles[check_cell]
			if movement:
				if not unit.flying and ((unit.boat and not tile.water) or (not unit.water and tile.water) or not passable(view, unit, check_cell, start, unit.boat)):
					return false
			elif tile.blocked:
				return false
		previous = cell
	return true

static func moves(view: Dictionary, unit: Dictionary, profile: BotProfile) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in unit.move:
		var cell: Vector2i = unit.cell + offset
		if not profile.allow_naval and view.tiles.get(cell, {}).get("water", false):
			continue
		if occupied(view, cell) or not passable(view, unit, cell, unit.cell, unit.boat):
			continue
		if clear_path(view, unit, cell, true):
			result.append(cell)
	return result

static func attacks(view: Dictionary, unit: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in unit.attack:
		var cell: Vector2i = unit.cell + offset
		if not view.visible.has(cell) or not view.tiles.has(cell) or view.tiles[cell].blocked:
			continue
		if maxi(absi(offset.x), absi(offset.y)) < int(unit.minimum):
			continue
		if clear_path(view, unit, cell, false):
			result.append(cell)
	return result

## Known-map route, including embark/disembark state. No authoritative occupancy.
static func route(view: Dictionary, unit: Dictionary, goal: Vector2i, profile: BotProfile) -> Array[Vector2i]:
	var start := Vector3i(unit.cell.x, unit.cell.y, 1 if unit.boat else 0)
	var queue: Array[Vector3i] = [start]
	var previous: Dictionary = {start: start}
	var found := start
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		var cell := Vector2i(current.x, current.y)
		if cell == goal:
			found = current
			break
		for offset: Vector2i in DIRECTIONS:
			var next := cell + offset
			if not passable(view, unit, next, cell, current.z == 1):
				continue
			if not profile.allow_naval and view.tiles[next].water:
				continue
			var boat: bool = bool(view.tiles[next].water) and (current.z == 1 or view.structures.get(next, {}).get("dock", false))
			var key := Vector3i(next.x, next.y, 1 if boat else 0)
			if previous.has(key):
				continue
			previous[key] = current
			queue.append(key)
	var result: Array[Vector2i] = []
	if found == start:
		return result
	while found != start:
		result.push_front(Vector2i(found.x, found.y))
		found = previous[found]
	return result
