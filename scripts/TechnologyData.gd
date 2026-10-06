class_name TechnologyData
extends Resource

## Research identity, cost, prerequisite, and UI content.
## Descriptions explain unlocks; their effects also need implementation in gameplay systems.


@export_group("Identity")

## Stable research key referenced by gameplay requirements.
@export var technology_id: String = ""
## Player-facing research name.
@export var technology_name: String = ""
## Explanation shown by the technology UI.
@export var description: String = ""
## UI descriptions of unlocks. Gameplay effects must also be implemented in the relevant systems.
@export_multiline var unlock_effects: Array[String] = []


@export_group("Requirements")

## Sugar required to purchase this technology.
@export var cost: int = 0
## Research that must be owned first; null means no prerequisite.
@export var prerequisite_technology: TechnologyData


@export_group("Visuals")

## Artwork for the research button.
@export var icon: Texture2D
