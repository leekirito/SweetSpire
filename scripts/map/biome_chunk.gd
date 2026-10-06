@tool
class_name BiomeChunk
extends Node2D

## Metadata for a hand-painted 10x10 biome variant.
## ChunkCatalog validates its layers, placements, and shoreline direction.


## Paint Ground, Decoration and Obstacles in local cells (0,0) through (9,9).
## All gameplay placements belong under Placements and use ChunkPlacement.
@export_enum("SABA", "MALAGKIT", "KAMOTE", "SWEETSPIRE") var biome_id: String = "SABA"
## Unique catalog key for this authored variant; change it when duplicating a scene.
@export var variant_id: String = ""
## Authored content revision included in the catalog fingerprint.
@export var revision: int = 1

enum ShoreEdge { NONE, TOP, RIGHT, BOTTOM, LEFT }
## Tile-grid directions, not screen directions. A declared edge faces Sweetspire.
## None keeps the variant eligible for any outer slot and requires land seams.
@export_enum("None", "Top (-Y)", "Right (+X)", "Bottom (+Y)", "Left (-X)") var shore_edge: int = ShoreEdge.NONE
