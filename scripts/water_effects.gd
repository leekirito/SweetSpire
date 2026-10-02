class_name WaterEffects
extends TileMapLayer

## The ground map remains the source of truth. This layer copies only water
## cells, keeping its shader separate from selection and cursor rendering.
@export var source_layer: TileMapLayer
@export var water_source_ids: Array[int] = [5]


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	clear()

	if source_layer == null:
		push_warning("WaterEffects has no source TileMapLayer.")
		return

	tile_set = source_layer.tile_set

	for cell: Vector2i in source_layer.get_used_cells():
		var source_id: int = source_layer.get_cell_source_id(cell)
		if source_id not in water_source_ids:
			continue

		set_cell(
			cell,
			source_id,
			source_layer.get_cell_atlas_coords(cell),
			source_layer.get_cell_alternative_tile(cell)
		)
