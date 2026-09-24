extends SceneTree


func _init() -> void:
	var data: UnitData = load("res://scripts/data/Units/Pathfinder.tres")
	print("walk_range=", data.walk_range)
	print("base=", data.movement_pattern.base_dimensions)
	print("base_override=", data.walk_base_dimensions_override)
	print("exact_override=", data.walk_exact_dimensions_override)
	var offsets := data.movement_pattern.get_offsets(
		data.walk_range,
		data.walk_base_dimensions_override,
		data.walk_exact_dimensions_override
	)
	print("offsets=", offsets)
	quit()
