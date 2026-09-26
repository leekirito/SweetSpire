extends Node2D
## Cosmetic debris: two drawing layers, no collision bodies or gameplay RNG.

@export_range(1, 24) var chunk_count: int = 8
## Maximum ground spread in world pixels. Isometric Y spread is half this.
## Zero keeps chunks directly above the impact point; height is unaffected.
@export_range(0.0, 512.0, 1.0, "or_greater") var scatter_radius: float = 80.0
## Chunk width and height in world pixels, before camera zoom.
@export_range(1.0, 128.0, 0.5) var min_chunk_size: float = 7.0
@export_range(1.0, 128.0, 0.5) var max_chunk_size: float = 13.0
## Each chunk chooses one palette color. Empty palettes use Chunk Color.
@export var chunk_colors: Array[Color] = [
	Color("bd3344"), Color("ed6575"), Color("8a2035")
]
## Fallback when the palette is empty.
@export var chunk_color: Color = Color("bd3344")
@export var initial_height: float = 105.0
@export var gravity: float = 850.0
@export_range(0.0, 0.8) var bounce_retention: float = 0.32
@export var lifetime: float = 1.5

class Chunk:
	var ground := Vector2.ZERO
	var velocity := Vector2.ZERO
	var height: float
	var rise_speed: float
	var size: float
	var color: Color
	var bounces: int = 0
	var settled: bool = false

var _chunks: Array[Chunk] = []
var _age: float = 0.0
var _back_layer: Node2D


func _ready() -> void:
	_back_layer = Node2D.new()
	_back_layer.name = "BehindUnit"
	_back_layer.z_as_relative = false
	_back_layer.z_index = z_index - 2
	add_child(_back_layer)
	_back_layer.draw.connect(_draw_chunks.bind(_back_layer, true))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index: int in range(chunk_count):
		var chunk := Chunk.new()
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		chunk.velocity = direction * rng.randf_range(45.0, 110.0) * maxf(scatter_radius, 0.0) / 80.0
		chunk.velocity.y *= 0.5
		chunk.height = initial_height + rng.randf_range(-12.0, 12.0)
		chunk.rise_speed = rng.randf_range(65.0, 180.0)
		chunk.size = rng.randf_range(
			maxf(1.0, minf(min_chunk_size, max_chunk_size)),
			maxf(1.0, maxf(min_chunk_size, max_chunk_size))
		)
		chunk.color = chunk_color if chunk_colors.is_empty() else chunk_colors[
			rng.randi_range(0, chunk_colors.size() - 1)
		]
		_chunks.append(chunk)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	# Small integration steps keep bounces stable during a slow frame.
	var remaining: float = minf(delta, 0.1)
	while remaining > 0.0:
		var step: float = minf(remaining, 1.0 / 120.0)
		remaining -= step
		for chunk: Chunk in _chunks:
			if chunk.settled:
				continue
			chunk.ground += chunk.velocity * step
			# Check the uncompressed ground plane, then project it back to isometric Y.
			var ground_plane := Vector2(chunk.ground.x, chunk.ground.y * 2.0)
			var radius: float = maxf(scatter_radius, 0.0)
			if ground_plane.length_squared() > radius * radius:
				ground_plane = ground_plane.limit_length(radius)
				chunk.ground = Vector2(ground_plane.x, ground_plane.y * 0.5)
				chunk.velocity = Vector2.ZERO
			chunk.rise_speed -= gravity * step
			chunk.height += chunk.rise_speed * step
			if chunk.height <= 0.0:
				chunk.height = 0.0
				chunk.bounces += 1
				chunk.velocity *= 0.45
				chunk.rise_speed = absf(chunk.rise_speed) * bounce_retention
				if chunk.bounces >= 2 or chunk.rise_speed < 25.0:
					chunk.settled = true
	queue_redraw()
	_back_layer.queue_redraw()


func _draw() -> void:
	_draw_chunks(self, false)


func _draw_chunks(layer: Node2D, behind: bool) -> void:
	var opacity: float = clampf((lifetime - _age) / 0.45, 0.0, 1.0)
	for chunk: Chunk in _chunks:
		if (chunk.ground.y < 0.0) != behind:
			continue
		var proximity: float = 1.0 - clampf(chunk.height / 220.0, 0.0, 0.8)
		var shadow_size := Vector2(chunk.size, chunk.size * 0.4) * proximity
		layer.draw_rect(Rect2(chunk.ground - shadow_size * 0.5, shadow_size),
			Color(0.08, 0.04, 0.06, 0.35 * opacity * proximity))
	for chunk: Chunk in _chunks:
		if (chunk.ground.y < 0.0) != behind:
			continue
		var point: Vector2 = (chunk.ground - Vector2(0.0, chunk.height)).round()
		var size := Vector2.ONE * chunk.size
		var color := chunk.color
		color.a *= opacity
		layer.draw_rect(Rect2(point - size * 0.5, size), color)
		layer.draw_rect(Rect2(point - size * 0.5, Vector2(chunk.size, 2.0)),
			Color(color.lightened(0.3), color.a))
