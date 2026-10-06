class_name StructureData
extends Resource

## Construction, income, artwork, and optional dock/boat configuration.
## StructureManager enforces placement and costs; Structure supplies behavior hooks.


enum Placement { GROUND, WATER, FOREST, MOUNTAIN }
## Stable construction key used by the catalog and commands.
@export var structure_id: String = ""
## Player-facing improvement name.
@export var display_name: String = ""
## Terrain or resource category required at the construction cell.
@export var placement: Placement = Placement.GROUND
## Research needed to build; empty means no requirement.
@export var required_technology_id: String = ""
## Sugar charged after construction is validated.
@export var sugar_cost: int = 3
## EXP granted to the controlling town when built.
@export var construction_exp: int = 1
## Recurring Sugar contributed to the controlling town's income.
@export var sugar_per_round: int = 1
## Artwork for the constructed improvement.
@export var texture: Texture2D
## A custom Structure subclass can implement additional entry/round effects.
@export var behavior_script: Script
## Enable the base Structure entry hook to embark an arriving land unit.
@export var converts_to_boat: bool = false
## Movement geometry applied while embarked.
@export var boat_movement_pattern: RangePattern
## Attack geometry applied while embarked.
@export var boat_attack_pattern: RangePattern
## Movement range applied while embarked.
@export var boat_walk_range: int = 2
## Attack range applied while embarked.
@export var boat_attack_range: int = 1
## Optional unit artwork applied while embarked.
@export var boat_texture: Texture2D
