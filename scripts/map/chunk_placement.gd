@tool
class_name ChunkPlacement
extends Marker2D

@export_enum("town", "forest", "mountain", "fruit", "animal", "fish") var kind: String = "town"
## One starting town per outer chunk. Ignored for neutral Sweetspire towns.
@export var starting_town: bool = false

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 28.0, Color.GOLD if starting_town else Color.CYAN)
		draw_string(ThemeDB.fallback_font, Vector2(32, 0), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
