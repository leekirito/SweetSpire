extends SceneTree

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func _init() -> void:
	var pattern := RangePattern.new()
	var small := pattern.get_offsets(1)
	var large := pattern.get_offsets(2)
	check(small.size() == 8, "Range 1 square must contain 8 destinations in 3x3")
	check(large.size() == 15, "Range 2 square must contain 15 destinations in 4x4")
	check(Vector2i(-1, -1) in large and Vector2i(2, 2) in large, "Even footprint bounds")
	check(Vector2i.ZERO not in large, "Unit's own cell must be excluded")
	var rectangle := pattern.get_offsets(99, Vector2i.ZERO, Vector2i(4, 3))
	check(rectangle.size() == 11, "Exact 4x3 must ignore numeric range")
	check(Vector2i(2, 1) in rectangle and Vector2i(2, 2) not in rectangle, "X is columns, Y is rows")
	check(pattern.get_offsets(1, Vector2i(3, 2)) == rectangle, "Custom base still adds range")
	check(pattern.get_offsets(1, Vector2i.ZERO, Vector2i(4, 0)) == small, "Incomplete override falls back")
	var expected_counts := [15, 6, 5, 3, 7]
	for shape: int in range(5):
		pattern.shape = shape
		check(pattern.get_offsets(2).size() == expected_counts[shape], "Range 2 shape %s" % shape)
	pattern.shape = RangePattern.Shape.LINE
	pattern.line_axis = RangePattern.LineAxis.VERTICAL
	check(Vector2i(0, 2) in pattern.get_offsets(2), "Vertical line orientation")
	var data := UnitData.new()
	var unit := Unit.new()
	unit.data = data
	unit._load_data()
	data.changed.connect(unit._on_unit_data_changed)
	data.walk_range = 2
	data.attack_range = 3
	data.walk_exact_dimensions_override = Vector2i(4, 3)
	check(unit.unit_walk_range == 2 and unit.attack_range == 3, "Live numeric range refresh")
	check(unit.walk_exact_dimensions_override == Vector2i(4, 3), "Live exact dimensions refresh")
	data.movement_pattern = pattern
	var notifications := [0]
	unit.range_configuration_changed.connect(func(_unit: Unit): notifications[0] += 1)
	pattern.base_dimensions = Vector2i(4, 4)
	check(notifications[0] == 1, "Pattern edits notify existing units")
	unit.free()
	for path: String in ["warrior", "archer", "Pathfinder"]:
		var configured: UnitData = load("res://scripts/data/Units/%s.tres" % path)
		check(configured.movement_pattern.base_dimensions == Vector2i(2, 2), path + " movement base")
		check(configured.attack_pattern.base_dimensions == Vector2i(2, 2), path + " attack base")
	print("Range regression failures: ", failures)
	quit(1 if failures else 0)
