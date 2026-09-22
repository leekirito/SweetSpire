class_name TribeData
extends Resource


@export_group("Identity")

@export var tribe_id: String = ""
@export var tribe_name: String = ""


@export_group("Starting Data")

@export var starting_technology: TechnologyData
@export var starting_unit_scene: PackedScene


@export_group("Visuals")

@export var visuals: TribeVisualData

@export var territory_color: Color = Color.WHITE
