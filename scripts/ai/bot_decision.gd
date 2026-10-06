class_name BotDecision
extends RefCounted
static func choose(candidates: Array, profile: BotProfile, memory: BotMemory) -> Dictionary:
	var unique: Dictionary = {}
	for candidate: Dictionary in candidates:
		var key := BotMemory.command_key(candidate.command)
		if memory.rejected.has(key):
			continue
		if not unique.has(key) or candidate.score > unique[key].score:
			unique[key] = candidate
	var sorted: Array = unique.values()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score if a.score != b.score else BotMemory.command_key(a.command) < BotMemory.command_key(b.command))
	if sorted.is_empty():
		return {"action": "end_turn"}
	var chosen: Dictionary = sorted[0]
	var mistake := false
	if memory.cooldown > 0:
		memory.cooldown -= 1
	elif chosen.score < 0.95 and memory.rng.randf() < profile.mistake_chance:
		var alternatives: Array = []
		for candidate: Dictionary in sorted.slice(1, profile.alternative_count + 1):
			if chosen.score - candidate.score <= profile.max_score_loss:
				alternatives.append(candidate)
		if not alternatives.is_empty():
			chosen = alternatives[memory.rng.randi_range(0, alternatives.size() - 1)]
			memory.cooldown = profile.mistake_cooldown
			mistake = true
	if profile.debug_decisions:
		print("BOT decision: ", chosen.reason, " score=", chosen.score, " imperfect=", mistake, " command=", chosen.command)
	return chosen.command
