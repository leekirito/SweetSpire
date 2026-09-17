class_name TechnologyData
extends Resource

@export_group("Identity")

@export var technology_id: String = ""
@export var technology_name: String = ""
@export var description: String = ""


@export_group("Requirements")

@export var cost: int = 0
@export var prerequisite_technology: TechnologyData


@export_group("Visuals")

@export var icon: Texture2D
