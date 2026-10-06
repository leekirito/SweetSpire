@tool
class_name RangePattern
extends Resource

## Reusable tile-offset geometry for movement, attacks, and blasts.
## BoardManager separately applies terrain, occupancy, and path restrictions.



enum Shape {
	SQUARE,
	CROSS,
	DIAGONAL,
	LINE,
	AREA
}

enum LineAxis {
	HORIZONTAL,
	VERTICAL
}

## Square fills the box; Cross uses its rows and columns; Diagonal uses diagonals;
## Line uses one axis; Area forms a diamond.
@export var shape: Shape = Shape.SQUARE:
	set(value):
		if shape == value:
			return
		shape = value
		emit_changed()
## Starting width (X) and height (Y). The range or blast radius is added to both.
## For a 3x3 blast with Blast Radius 0, set this to (3, 3).
@export var base_dimensions: Vector2i = Vector2i(2, 2):
	set(value):
		if base_dimensions == value:
			return
		base_dimensions = value
		emit_changed()
## Direction used only when Shape is Line; ignored for Square and other shapes.
@export var line_axis: LineAxis = LineAxis.HORIZONTAL:
	set(value):
		if line_axis == value:
			return
		line_axis = value
		emit_changed()


## Returns shape offsets excluding the origin. Exact dimensions override base plus expansion.
## Even dimensions put the extra row/column on the positive side.
func get_offsets(
	expansion: int,
	base_dimensions_override: Vector2i = Vector2i.ZERO,
	exact_dimensions_override: Vector2i = Vector2i.ZERO
) -> Array[Vector2i]:
	var dimensions: Vector2i = exact_dimensions_override
	if dimensions.x <= 0 or dimensions.y <= 0:
		var selected_base: Vector2i = base_dimensions_override
		if selected_base.x <= 0 or selected_base.y <= 0:
			selected_base = base_dimensions
		dimensions = selected_base + Vector2i.ONE * maxi(expansion, 0)

	dimensions.x = maxi(dimensions.x, 1)
	dimensions.y = maxi(dimensions.y, 1)

	# Even dimensions have their extra column/row on the positive (right/down) side.
	var minimum := Vector2i(
		-floori(float(dimensions.x - 1) / 2.0),
		-floori(float(dimensions.y - 1) / 2.0)
	)
	var offsets: Array[Vector2i] = []

	for local_x: int in range(dimensions.x):
		for local_y: int in range(dimensions.y):
			var offset := minimum + Vector2i(local_x, local_y)
			if offset == Vector2i.ZERO:
				continue
			if _includes_offset(offset, dimensions):
				offsets.append(offset)

	return offsets


func _includes_offset(offset: Vector2i, dimensions: Vector2i) -> bool:
	match shape:
		Shape.CROSS:
			return offset.x == 0 or offset.y == 0
		Shape.DIAGONAL:
			return absi(offset.x) == absi(offset.y)
		Shape.LINE:
			return offset.y == 0 if line_axis == LineAxis.HORIZONTAL else offset.x == 0
		Shape.AREA:
			# Match the actual bounds, including the extra cell of even-sized areas.
			var radius_x := maxf(float(floori(float(dimensions.x) / 2.0) if offset.x >= 0 else floori(float(dimensions.x - 1) / 2.0)), 1.0)
			var radius_y := maxf(float(floori(float(dimensions.y) / 2.0) if offset.y >= 0 else floori(float(dimensions.y - 1) / 2.0)), 1.0)
			return absf(float(offset.x)) / radius_x + absf(float(offset.y)) / radius_y <= 1.0
		_:
			return true
