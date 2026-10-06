class_name BotCatalog
extends RefCounted

## Approved profiles used by setup controls and LAN compatibility checks.
## Register duplicated profile resources here to make them selectable.

## Add an approved profile here after duplicating the resource in the Inspector.
const PROFILES := {"balanced": preload("res://scripts/ai/profiles/balanced.tres")}
## Returns an independent validated resource, using Balanced for an unknown ID.
static func profile(id: String) -> BotProfile:
	return PROFILES.get(id, PROFILES.balanced).validated_copy()
## Hashes registered profile values for LAN compatibility.
static func signature() -> String:
	var entries: Array = []
	for id in PROFILES:
		entries.append([id, PROFILES[id].signature()])
	return JSON.stringify(entries).sha256_text()
