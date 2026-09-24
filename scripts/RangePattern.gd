class_name RangePattern
extends Resource


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

@export var shape: Shape = Shape.SQUARE
## The numeric walk/attack range is added to both dimensions.
## With the default (2, 2), range 1 produces a 3x3 footprint.
@export var base_dimensions: Vector2i = Vector2i(2, 2)
@export var line_axis: LineAxis = LineAxis.HORIZONTAL


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
			var radius_x := maxf(float(dimensions.x - 1) / 2.0, 1.0)
			var radius_y := maxf(float(dimensions.y - 1) / 2.0, 1.0)
			return absf(float(offset.x)) / radius_x + absf(float(offset.y)) / radius_y <= 1.0
		_:
			return true
