class_name UnitData
extends Resource

@export_group("Identity")
@export var type: String = ""
@export var unit_name: String = ""

@export_group("Economy")
@export var cost: int = 0
@export var required_technology_id: String = ""

@export_group("Stats")
@export var health: int = 1
@export var walk_range: int = 1
@export var attack_damage: int = 1
@export var attack_range: int = 1
@export var defence: int = 0

@export_group("Range Patterns")
## Leave a pattern empty to use the default square pattern.
@export var movement_pattern: RangePattern
@export var attack_pattern: RangePattern
## Optional custom bases. The numeric range is still added to these dimensions.
@export var walk_base_dimensions_override: Vector2i = Vector2i.ZERO
@export var attack_base_dimensions_override: Vector2i = Vector2i.ZERO
## Optional final dimensions. These intentionally ignore the numeric range.
@export var walk_exact_dimensions_override: Vector2i = Vector2i.ZERO
@export var attack_exact_dimensions_override: Vector2i = Vector2i.ZERO

@export_group("Visuals")
@export var character_texture: Dictionary[String, Texture2D]
