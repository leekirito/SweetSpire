class_name TribeData
extends Resource

## Starting rules and visual identity for a selectable tribe.
## Used by roster setup, initial research/unit assignment, and territory presentation.



@export_group("Identity")

## Stable lowercase tribe key used by rosters, map starts, and the LAN catalog.
@export var tribe_id: String = ""
## Player-facing tribe name.
@export var tribe_name: String = ""


@export_group("Starting Data")

## Research granted when initializing this tribe's player.
@export var starting_technology: TechnologyData
## Unit scene used for this tribe's initial unit.
@export var starting_unit_scene: PackedScene


@export_group("Visuals")

## Shared tribe artwork configuration.
@export var visuals: TribeVisualData

## Color used to display owned territory.
@export var territory_color: Color = Color.WHITE
## Color used to distinguish owned units.
@export var unit_outline_color: Color = Color.WHITE
