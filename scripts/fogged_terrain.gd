extends TileMapLayer

## Hides unexplored terrain artwork through runtime tile modulation.
## Keeps raised sprites and cliff faces from showing through the separate fog cover.


func _ready() -> void:
	var fog := get_node_or_null("../FogOfWar") as FogOfWar
	if fog != null:
		fog.fog_updated.connect(notify_runtime_tile_data_update)

## Hide the whole unknown terrain sprite, including raised art and cliff faces.
## The separate fog scene tiles supply the opaque cover and reveal animation.
func _use_tile_data_runtime_update(_coords: Vector2i) -> bool:
	return true

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	var fog := get_node_or_null("../FogOfWar") as FogOfWar
	if fog != null and not fog.is_cell_explored(coords):
		tile_data.modulate.a = 0.0
