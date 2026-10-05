@tool
class_name BiomeChunk
extends Node2D

## Paint Ground, Decoration and Obstacles in local cells (0,0) through (9,9).
## All gameplay placements belong under Placements and use ChunkPlacement.
@export_enum("SABA", "MALAGKIT", "KAMOTE", "SWEETSPIRE") var biome_id: String = "SABA"
@export var variant_id: String = ""
@export var revision: int = 1

enum ShoreEdge { NONE, TOP, RIGHT, BOTTOM, LEFT }
## Tile-grid directions, not screen directions. A declared edge faces Sweetspire.
## None keeps the variant eligible for any outer slot and requires land seams.
@export_enum("None", "Top (-Y)", "Right (+X)", "Bottom (+Y)", "Left (-X)") var shore_edge: int = ShoreEdge.NONE
