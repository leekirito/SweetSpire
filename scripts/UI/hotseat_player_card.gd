@tool
extends PanelContainer

@export_range(1, 8) var player_number: int = 1:
	set(value):
		player_number = value
		if is_node_ready():
			_update_title()

func _ready() -> void:
	_update_title()

func _update_title() -> void:
	$Margin/Content/Title.text = "PLAYER %d" % player_number
