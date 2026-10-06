class_name BotCatalog
extends RefCounted
## Add an approved profile here after duplicating the resource in the Inspector.
const PROFILES := {"balanced": preload("res://scripts/ai/profiles/balanced.tres")}
static func profile(id: String) -> BotProfile:
	return PROFILES.get(id, PROFILES.balanced).validated_copy()
static func signature() -> String:
	var entries: Array = []
	for id in PROFILES:
		entries.append([id, PROFILES[id].signature()])
	return JSON.stringify(entries).sha256_text()
