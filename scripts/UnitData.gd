class_name UnitData
extends Resource

@export_group("Identity")
@export var type: String = ""
@export var unit_name: String = ""

@export_group("Economy")
@export var cost: int = 0

@export_group("Stats")
@export var health: int = 1
@export var walk_range: int = 1
@export var attack_damage: int = 1
@export var attack_range: int = 1
@export var defence: int = 0

@export_group("Visuals")
@export var character_texture: Dictionary[String, Texture2D]
