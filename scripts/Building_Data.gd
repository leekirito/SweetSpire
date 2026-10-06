class_name BuildingData
extends Resource

## Reusable town identity and neutral artwork.
## Runtime ownership, experience, and income progression live on Building.



@export_group("Identity")

## Key used to look up tribe-specific town artwork.
@export var building_type: String = "base"
## Display name for this town type.
@export var building_name: String = "Base"




@export_group("Visuals")

## Artwork used while the town has no owner.
@export var neutral_texture: Texture2D
