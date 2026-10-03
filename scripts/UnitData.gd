@tool
class_name UnitData
extends Resource

@export_group("Identity")
## Label for this unit's role. Blast Pattern, not this text, enables area attacks.
@export var type: String = ""
## Name shown in recruitment and unit previews.
@export var unit_name: String = ""

@export_group("Economy")
## Sugar spent to recruit this unit from a town.
@export var cost: int = 0
## Technology ID required before the unit can be recruited.
@export var required_technology_id: String = ""

@export_group("Stats")
## Damage the unit can take after its defence is depleted.
@export var health: int = 1
## Adds to the movement pattern's width and height; not a tile-distance radius.
@export var walk_range: int = 1:
	set(value):
		if walk_range == value:
			return
		walk_range = value
		emit_changed()
## Damage dealt to each unit hit, after defence absorbs damage.
@export var attack_damage: int = 1
## Adds to the attack pattern's width and height; not a tile-distance radius.
@export var attack_range: int = 1:
	set(value):
		if attack_range == value:
			return
		attack_range = value
		emit_changed()
## Absorbs incoming damage before health is reduced.
@export var defence: int = 0
## Minimum tile distance to a target. Set to 2 to exclude all eight neighboring tiles.
@export_range(0, 8, 1) var minimum_attack_distance: int = 0

@export_group("Area Attack")
## Blast shape around the chosen tile. Empty means a normal single-target attack.
## The chosen tile is included; the blast is clipped to targetable attack tiles.
@export var blast_pattern: RangePattern
## Adds to Blast Pattern's base width and height. Base (3, 3) plus 0 makes a 3x3 blast.
@export_range(0, 8, 1) var blast_radius: int = 1
## When on, the blast also damages allied units on targetable tiles.
@export var can_hit_allies: bool = false

@export_group("Attack Effects")
## Animation played before damage. Slash uses the Kenney arc; Meteor falls onto the chosen tile.
@export_enum("Slash", "Meteor") var attack_visual: int = 0

@export_group("Meteor Timing And Decals")
## Scene spawned at the chosen tile. Edit that scene for sprites, particles, KapowFX, and sounds.
@export var meteor_effect_scene: PackedScene
## Seconds from casting until the meteor lands and damage is applied.
@export_range(0.1, 5.0, 0.05) var meteor_effect_time: float = 0.5
## Image placed on every affected tile, including empty tiles. Use a transparent PNG.
@export var meteor_decal_texture: Texture2D
## Color and opacity applied to each decal sprite.
@export var meteor_decal_tint: Color = Color(0.22, 0.13, 0.09, 0.5)
## Size of each decal relative to one isometric tile.
@export_range(0.2, 2.0, 0.05) var meteor_decal_size_multiplier: float = 1.0
## Seconds relative to impact: negative appears early, positive appears afterward.
@export_range(-2.0, 2.0, 0.05) var meteor_decal_time_offset: float = -0.1
## Seconds for each decal to fade after it appears.
@export_range(0.1, 20.0, 0.1) var meteor_decal_fade_seconds: float = 5.0

@export_group("Terrain Movement")
## Allows movement over ordinary land. Standard ground units should leave this on.
@export var can_traverse_land: bool = true
## Enable for boats, amphibious units, or units granted water movement later.
@export var can_traverse_water: bool = false
## Enable for flying/ethereal units that ignore hard terrain obstacles.
## Board bounds and occupied destination cells still apply.
@export var ignores_terrain_blocking: bool = false

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
