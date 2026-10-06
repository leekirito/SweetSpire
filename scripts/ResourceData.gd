class_name ResourceData
extends Resource

## Authored rewards, research requirements, and artwork for a resource kind.
## Resources stores the ownership and upgrade state of each placed instance.



@export_group("Identity")

## Authored resource-kind identifier, separate from a placed entity's match ID.
@export var resource_id: int = 0
## Gameplay kind used by rules, such as forest or mountain.
@export var resource_alias: String = ""


@export_group("Progression")

## Town EXP awarded when this resource is collected or upgraded.
@export var experience_reward: int = 1
## Sugar awarded to the owning player when collected.
@export var collect_sugar: int = 0
## Whether the resource offers collection when other requirements are satisfied.
@export var can_collect: bool = true


@export_group("Technology")

## Required research for collection; empty means no research requirement.
@export var collect_technology_id: String = ""
## Required research for upgrading; empty means no research requirement.
@export var upgrade_technology_id: String = ""

## Whether this resource supports a one-time upgrade.
@export var can_upgrade: bool = true


@export_group("Visuals")

## Optional artwork shown after upgrading.
@export var upgrade_texture: Texture2D
## Artwork keyed by uppercase biome name, such as SABA or KAMOTE.
@export var biome_textures: Dictionary[String, Texture2D]
