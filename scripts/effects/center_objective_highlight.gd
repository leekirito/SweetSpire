class_name CenterObjectiveHighlight
extends Node2D

## Cosmetic shader diamonds for the four objective cells.
## VictoryManager owns occupation and scoring.


const HIGHLIGHT_SHADER: Shader = preload("res://assets/Shader/center_objective.gdshader")

@export_group("Center Highlight")
## Soft color across each of the four objective tiles.
@export var fill_color: Color = Color(0.9, 0.68, 0.18, 0.16)
## Brighter rim around each objective tile.
@export var edge_color: Color = Color(1.0, 0.84, 0.32, 0.75)
## Width of the rim as a fraction of each tile.
@export_range(0.01, 0.3, 0.01) var edge_width: float = 0.09
## How quickly the highlight brightens and dims.
@export_range(0.0, 8.0, 0.1) var pulse_speed: float = 2.0
## Amount of brightness change during the pulse.
@export_range(0.0, 1.0, 0.05) var pulse_strength: float = 0.25

@onready var game: MatchManager = get_node("../MatchManager")
@onready var board: BoardManager = get_node("../BoardManager")


func _ready() -> void:
	var tile_size := Vector2(board.tile_map_layer.tile_set.tile_size)
	var half_width := tile_size.x * 0.5
	var half_height := tile_size.y * 0.5
	var diamond := PackedVector2Array([
		Vector2(0.0, -half_height),
		Vector2(half_width, 0.0),
		Vector2(0.0, half_height),
		Vector2(-half_width, 0.0),
	])
	var uv := PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5),
	])
	var material := ShaderMaterial.new()
	material.shader = HIGHLIGHT_SHADER
	material.set_shader_parameter("fill_color", fill_color)
	material.set_shader_parameter("edge_color", edge_color)
	material.set_shader_parameter("edge_width", edge_width)
	material.set_shader_parameter("pulse_speed", pulse_speed)
	material.set_shader_parameter("pulse_strength", pulse_strength)
	for cell: Vector2i in game.get_center_cells():
		var tile := Polygon2D.new()
		tile.name = "CenterTile_%d_%d" % [cell.x, cell.y]
		tile.polygon = diamond
		tile.uv = uv
		tile.material = material
		add_child(tile)
		tile.global_position = board.cell_to_world(cell)
