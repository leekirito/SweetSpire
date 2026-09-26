class_name StructureData
extends Resource

enum Placement { GROUND, WATER, FOREST, MOUNTAIN }
@export var structure_id: String = ""
@export var display_name: String = ""
@export var placement: Placement = Placement.GROUND
@export var required_technology_id: String = ""
@export var sugar_cost: int = 3
@export var construction_exp: int = 1
@export var sugar_per_round: int = 1
@export var texture: Texture2D
## A custom Structure subclass can implement additional entry/round effects.
@export var behavior_script: Script
@export var converts_to_boat: bool = false
@export var boat_movement_pattern: RangePattern
@export var boat_attack_pattern: RangePattern
@export var boat_walk_range: int = 2
@export var boat_attack_range: int = 1
@export var boat_texture: Texture2D
