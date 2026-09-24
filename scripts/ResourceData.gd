class_name ResourceData
extends Resource


@export_group("Identity")

@export var resource_id: int = 0
@export var resource_alias: String = ""


@export_group("Progression")

@export var exp: int = 1


@export_group("Technology")

@export var collect_technology_id: String = ""
@export var upgrade_technology_id: String = ""

@export var can_upgrade: bool = true


@export_group("Visuals")

@export var upgrade_texture: Texture2D
@export var biome_textures: Dictionary[String, Texture2D]
