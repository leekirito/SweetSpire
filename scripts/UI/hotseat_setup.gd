@tool
extends Control

## Responsive columns for authored Hotseat cards, previewable in both editor and runtime.


## Available width in pixels required to display two columns of player cards.
@export var two_column_min_width: float = 850.0

func _ready() -> void:
	$ResponsiveLayout/Page/PlayersScroll.resized.connect(_resize_columns)
	_resize_columns()

func _resize_columns() -> void:
	var scroll := $ResponsiveLayout/Page/PlayersScroll
	scroll.get_node("Players").columns = 2 if scroll.size.x >= two_column_min_width else 1
