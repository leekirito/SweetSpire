@tool
extends Button

## Authored technology button previewing a TechnologyData resource in the editor and game.

## The scene owns geometry; the resource supplies the preview and live values.
@export var technology: TechnologyData:
	set(value):
		technology = value
		if is_node_ready():
			refresh_content()

func _ready() -> void:
	refresh_content()

## Copies research icon, description, and price into the authored button controls.
func refresh_content() -> void:
	if technology == null:
		return
	tooltip_text = technology.description
	$Icon.texture = technology.icon
	$Cost.text = str(technology.cost) + " S"
