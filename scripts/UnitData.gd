@tool
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
@export var walk_range: int = 1:
	set(value):
		if walk_range == value:
			return
		walk_range = value
		emit_changed()
@export var attack_damage: int = 1
@export var attack_range: int = 1:
	set(value):
		if attack_range == value:
			return
		attack_range = value
		emit_changed()
@export var defence: int = 0

@export_group("Range Patterns")
## Leave a pattern empty to use the default square pattern.
@export var movement_pattern: RangePattern:
	set(value):
		if movement_pattern == value:
			return
		movement_pattern = value
		emit_changed()
@export var attack_pattern: RangePattern:
	set(value):
		if attack_pattern == value:
			return
		attack_pattern = value
		emit_changed()
## Optional custom bases. The numeric range is still added to these dimensions.
@export var walk_base_dimensions_override: Vector2i = Vector2i.ZERO:
	set(value):
		if walk_base_dimensions_override == value:
			return
		walk_base_dimensions_override = value
		emit_changed()
@export var attack_base_dimensions_override: Vector2i = Vector2i.ZERO:
	set(value):
		if attack_base_dimensions_override == value:
			return
		attack_base_dimensions_override = value
		emit_changed()
## Optional final dimensions: X = columns, Y = rows (including the unit's cell).
## For a 4x3 walk footprint, set (4, 3). Set (0, 0) to use base + walk_range.
## Both components must be positive. Exact dimensions ignore the numeric range.
@export var walk_exact_dimensions_override: Vector2i = Vector2i.ZERO:
	set(value):
		if walk_exact_dimensions_override == value:
			return
		walk_exact_dimensions_override = value
		emit_changed()
## X = columns, Y = rows. Set (0, 0) to use base + attack_range.
@export var attack_exact_dimensions_override: Vector2i = Vector2i.ZERO:
	set(value):
		if attack_exact_dimensions_override == value:
			return
		attack_exact_dimensions_override = value
		emit_changed()

@export_group("Visuals")
@export var character_texture: Dictionary[String, Texture2D]
