class_name TribeVisualData
extends Resource


@export_group("Terrain")

@export var ground_source_id: int = -1
@export var ground_atlas_coordinate: Vector2i


@export_group("Buildings")

# Example keys:
# "base"
# "village"
# "farm"
# "lumber_camp"

@export var building_textures: Dictionary[String, Texture2D] = {}
