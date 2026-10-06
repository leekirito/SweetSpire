class_name TribeVisualData
extends Resource

## Tribe-specific terrain identifiers and town textures.
## Visual configuration does not transfer ownership or implement gameplay effects.



@export_group("Terrain")

## TileSet source identifier stored with this tribe's terrain configuration.
@export var ground_source_id: int = -1
## Atlas coordinate stored with this tribe's terrain configuration.
@export var ground_atlas_coordinate: Vector2i


@export_group("Buildings")

# Example keys:
# "base"
# "village"
# "farm"
# "lumber_camp"

## Town artwork keyed by BuildingData.building_type.
@export var building_textures: Dictionary[String, Texture2D] = {}
