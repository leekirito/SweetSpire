class_name MatchCommands
extends RefCounted

## Whitelist and type-check before calling any gameplay entry point.
static func execute(game: MatchManager, seat: int, command: Dictionary) -> bool:
	if game.current_phase != MatchManager.Phase.PLAYER_TURN or seat != game.active_player_id:
		return false
	var kind: String = str(command.get("action", ""))
	var id: Variant = command.get("id", -1)
	if typeof(id) not in [TYPE_INT, TYPE_FLOAT] or float(id) != floor(float(id)):
		return false
	var target: Variant = command.get("cell", [0, 0])
	if not target is Array or target.size() != 2:
		return false
	for coordinate in target:
		if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or abs(float(coordinate)) > 10000 or float(coordinate) != floor(float(coordinate)):
			return false
	var key: String = str(command.get("key", ""))
	match kind:
		"move":
			return game.request_move(int(id), LanCatalog.cell(target))
		"attack":
			return game.request_attack_at_cell(int(id), LanCatalog.cell(target))
		"end_turn":
			return game.request_end_turn()
		"collect":
			return game.request_collect_resource(int(id), seat)
		"upgrade":
			return game.request_upgrade_resource(int(id), seat)
		"technology":
			return LanCatalog.TECHS.has(key) and game.request_purchase_technology(seat, LanCatalog.TECHS[key])
		"recruit":
			var town := game.get_building(int(id))
			if town == null or not LanCatalog.UNITS.has(key) or LanCatalog.UNITS[key] not in town.available_unit_types:
				return false
			return game.request_recruit_unit(int(id), LanCatalog.UNITS[key]) != null
		"build":
			return LanCatalog.STRUCTURES.has(key) and game.structure_manager.build(LanCatalog.STRUCTURES[key], LanCatalog.cell(target), seat)
	return false
