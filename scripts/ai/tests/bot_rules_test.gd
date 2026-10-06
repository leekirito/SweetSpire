extends Node
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BOT RULES: " + message)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var profile := BotCatalog.profile("balanced")
	profile.reserve_sugar = -9
	profile.mistake_chance = 4
	var validated := profile.validated_copy()
	check(validated.reserve_sugar == 0 and validated.mistake_chance == 1, "Profile values are clamped on load")
	check(BotCatalog.profile("balanced").reserve_sugar == 3, "Runtime changes do not mutate source profile")
	profile = BotCatalog.profile("balanced")
	var signature := profile.signature()
	profile.risk_tolerance += 0.1
	check(profile.signature() != signature, "Profile settings affect compatibility signature")
	var memory := BotMemory.new()
	memory.rng.seed = 12
	profile.mistake_chance = 1
	profile.max_score_loss = 0.15
	profile.mistake_cooldown = 2
	var actions := [
		{"command": {"action": "move", "id": 1, "cell": [1, 0]}, "score": 0.8, "reason": "best"},
		{"command": {"action": "move", "id": 1, "cell": [0, 1]}, "score": 0.7, "reason": "reasonable"},
		{"command": {"action": "move", "id": 1, "cell": [-1, 0]}, "score": 0.1, "reason": "bad"}]
	check(BotDecision.choose(actions, profile, memory) == actions[1].command, "Mistakes choose a bounded reasonable alternative")
	check(BotDecision.choose(actions, profile, memory) == actions[0].command, "Cooldown prevents consecutive mistakes")
	actions[0].score = 1.0
	memory.cooldown = 0
	check(BotDecision.choose(actions, profile, memory) == actions[0].command, "Immediate winning priority is protected")
	memory.rejected[BotMemory.command_key(actions[0].command)] = true
	check(BotDecision.choose(actions, profile, memory) != actions[0].command, "Rejected command is not retried")
	memory.begin_round(2)
	check(memory.rejected.is_empty(), "Failures can be reconsidered on later turns")
	var unit := {"id": 1, "owner": 2, "cell": Vector2i.ZERO, "hp": 10, "max_hp": 10, "shield": 0, "damage": 4, "moved": false, "attacked": false, "boat": false, "land": true, "water": false, "flying": false, "move": [Vector2i.RIGHT, Vector2i(2, 0)], "attack": [Vector2i.RIGHT, Vector2i(2, 0)], "minimum": 0, "area": false, "blast": [], "allies": false}
	var view := {"seat": 2, "round": 1, "sugar": 100, "tech": [], "tiles": {}, "visible": {}, "structures": {}, "units": [unit], "towns": [], "resources": [], "territory": {}, "center": [Vector2i(4, 0)], "center_rounds": 0, "center_target": 3}
	for x in 5:
		var cell := Vector2i(x, 0)
		view.tiles[cell] = {"water": x in [1, 2, 3], "ocean": x in [2, 3], "blocked": false, "mountain": false}
		view.visible[cell] = true
	check(BotNavigation.moves(view, unit, profile).is_empty(), "Land unit cannot enter open water")
	view.structures[Vector2i(1, 0)] = {"dock": true, "owner": 2}
	check(BotNavigation.moves(view, unit, profile) == [Vector2i(1, 0)], "Land unit boards only adjacent friendly dock")
	check(BotNavigation.route(view, unit, Vector2i(4, 0), profile).size() == 4, "Route crosses ocean through dock to land")
	view.structures[Vector2i(1, 0)].owner = 1
	check(BotNavigation.route(view, unit, Vector2i(4, 0), profile).is_empty(), "Enemy dock cannot grant boat travel")
	view.structures[Vector2i(1, 0)].owner = 2
	view.tiles.erase(Vector2i(3, 0))
	check(BotNavigation.route(view, unit, Vector2i(4, 0), profile).is_empty(), "Route cannot inspect undiscovered terrain")
	view.tiles[Vector2i(3, 0)] = {"water": true, "ocean": true, "blocked": false, "mountain": false}
	unit.boat = true
	unit.water = true
	unit.cell = Vector2i(2, 0)
	unit.move = [Vector2i.RIGHT, Vector2i(2, 0)]
	check(Vector2i(4, 0) in BotNavigation.moves(view, unit, profile), "Embarked unit can land across a clear water path")
	profile.allow_naval = false
	check(Vector2i(3, 0) not in BotNavigation.moves(view, unit, profile), "Naval capability toggle is respected")
	profile.allow_naval = true
	unit.cell = Vector2i.ZERO
	unit.move = [Vector2i.RIGHT]
	unit.boat = false
	unit.water = false
	for cell in view.tiles:
		view.tiles[cell].water = false
	var enemy := unit.duplicate(true)
	enemy.id = 2
	enemy.owner = 1
	enemy.cell = Vector2i(1, 0)
	view.units.append(enemy)
	unit.attacked = false
	var candidates := BotStrategy.unit_actions(view, unit, profile, BotMemory.new())
	check(candidates.any(func(candidate: Dictionary): return candidate.command.action == "attack"), "Bot attacks visible enemy")
	view.visible.erase(enemy.cell)
	candidates = BotStrategy.unit_actions(view, unit, profile, BotMemory.new())
	check(not candidates.any(func(candidate: Dictionary): return candidate.command.action == "attack"), "Bot does not target hidden enemy")
	view.visible[enemy.cell] = true
	unit.area = true
	unit.blast = [Vector2i.LEFT, Vector2i.RIGHT]
	unit.allies = true
	var ally := unit.duplicate(true)
	ally.id = 3
	ally.cell = Vector2i(2, 0)
	view.units.append(ally)
	profile.friendly_fire_penalty = 3
	candidates = BotStrategy.unit_actions(view, unit, profile, BotMemory.new())
	check(not candidates.any(func(candidate: Dictionary): return candidate.command.action == "attack"), "Bot avoids blast that harms ally more than enemy")
	# Development candidates must cover all implemented structure/resource actions.
	view.units = []
	view.structures = {}
	view.tech = LanCatalog.TECHS.keys()
	view.resources = []
	view.territory = {}
	view.towns = [{"id": 1, "owner": 2, "cell": Vector2i(9, 0), "recruited": 0, "units": LanCatalog.UNITS.keys()}]
	for x in range(5, 10):
		var cell := Vector2i(x, 0)
		view.tiles[cell] = {"water": x == 8, "ocean": false, "blocked": false, "mountain": x == 6}
		view.visible[cell] = true
		view.territory[cell] = 1
	for x in [5, 6]:
		view.resources.append({"id": x, "cell": Vector2i(x, 0), "owner": 2, "kind": "forest" if x == 5 else "mountain", "collect": true, "upgrade": true, "collect_tech": "", "upgrade_tech": "", "sugar": 1, "exp": 1})
	profile = BotCatalog.profile("balanced")
	var economy := BotActions.economy(view, profile)
	for key in ["farm", "lumber_factory", "mining_den", "dock"]:
		check(economy.any(func(candidate: Dictionary): return candidate.command.action == "build" and candidate.command.key == key), "Can plan " + key)
	for action in ["collect", "upgrade", "recruit"]:
		check(economy.any(func(candidate: Dictionary): return candidate.command.action == action), "Can plan " + action)
	view.tech = []
	economy = BotActions.economy(view, profile)
	check(economy.any(func(candidate: Dictionary): return candidate.command.action == "technology"), "Plans research for missing capabilities")
	view.units = [unit]
	unit.area = false
	unit.cell = Vector2i(3, 0)
	unit.move = [Vector2i.RIGHT]
	unit.attacked = true
	view.center_rounds = 2
	var winning := BotDecision.choose(BotStrategy.unit_actions(view, unit, profile, BotMemory.new()), profile, BotMemory.new())
	check(winning.action == "move" and winning.cell == [4, 0], "Bot takes an available winning center position")
	unit.cell = Vector2i(4, 0)
	check(BotStrategy.unit_actions(view, unit, profile, BotMemory.new()).is_empty(), "Healthy bot holds center through round end")
	print("BOT RULES: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
