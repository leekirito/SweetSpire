class_name LanCatalog
extends RefCounted

const TRIBES := {
	"saba": preload("res://scripts/data/Tribe/SABA.tres"),
	"malagkit": preload("res://scripts/data/Tribe/MALAGKIT_DATA.tres"),
	"kamote": preload("res://scripts/data/Tribe/KAMOTE.tres")
}
const UNITS := {
	"fighter": preload("res://scenes/entities/player/Fighter.tscn"),
	"ranger": preload("res://scenes/entities/player/Ranger.tscn"),
	"pathfinder": preload("res://scenes/entities/player/Pathfinder.tscn"),
	"caster": preload("res://scenes/entities/player/Caster.tscn")
}
const STRUCTURES := {
	"dock": preload("res://scripts/data/Structures/Dock.tres"),
	"lumber_factory": preload("res://scripts/data/Structures/LumberFactory.tres"),
	"farm": preload("res://scripts/data/Structures/Farm.tres"),
	"mining_den": preload("res://scripts/data/Structures/MiningDen.tres")
}
const TECHS := TechnologyTreeUI.TECH_PATHS

static func unit_key(scene_path: String) -> String:
	for key: String in UNITS:
		if UNITS[key].resource_path == scene_path:
			return key
	return ""

static func cell(value: Variant) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func xy(value: Vector2i) -> Array:
	return [value.x, value.y]

## Hash authored rule values; textures/audio and editor-only metadata are excluded.
## Bump LanSettings.build_version whenever rule scripts change.
static func rules_signature() -> String:
	var rules: Array = [["bots", BotCatalog.signature()]]
	for catalog: Dictionary in [TRIBES, TECHS, STRUCTURES]:
		for key: String in catalog:
			rules.append([key, _rule_values(catalog[key])])
	for key: String in UNITS:
		var prototype: Unit = UNITS[key].instantiate()
		rules.append([key, _rule_values(prototype.data)])
		prototype.free()
	for path: String in ["res://scripts/data/Neutral_Building.tres", "res://scripts/data/Resources/AnimalData.tres", "res://scripts/data/Resources/FishData.tres", "res://scripts/data/Resources/ForestData.tres", "res://scripts/data/Resources/FruitData.tres", "res://scripts/data/Resources/MountainData.tres"]:
		rules.append(_rule_values(load(path)))
	return JSON.stringify(rules).sha256_text()

static func _rule_values(value: Variant) -> Variant:
	if value is Resource:
		if value is PackedScene:
			return value.resource_path
		if value is Texture or value is AudioStream or value is Script:
			return null
		var result: Dictionary = {}
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_") and property.name != "script":
				result[property.name] = _rule_values(value.get(property.name))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[str(key)] = _rule_values(value[key])
		return result
	if value is Array or value is PackedStringArray:
		var result: Array = []
		for entry in value:
			result.append(_rule_values(entry))
		return result
	return value
