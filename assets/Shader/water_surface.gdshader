shader_type canvas_item;
render_mode unshaded;

uniform vec4 surface_tint : source_color = vec4(0.06, 0.42, 0.70, 1.0);
uniform vec4 soft_light : source_color = vec4(0.20, 0.66, 0.83, 1.0);
uniform vec4 crest_light : source_color = vec4(0.66, 0.91, 0.96, 1.0);
uniform float flow_speed : hint_range(0.0, 3.0, 0.05) = 1.0;
uniform float surface_opacity : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float highlight_opacity : hint_range(0.0, 0.6, 0.01) = 0.40;
uniform float detail_scale : hint_range(0.002, 0.08, 0.001) = 0.018;
uniform float ripple_density : hint_range(0.0, 1.0, 0.05) = 0.72;

varying vec2 world_position;

float random_value(vec2 position) {
	return fract(sin(dot(position, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tile_mask = texture(TEXTURE, UV) * COLOR;
	float time = TIME * flow_speed;

	// Horizontal diamond of the 256 x 512 ocean and lake sprites.
	vec2 face = (UV - vec2(0.5, 420.0 / 512.0)) / vec2(0.5, 0.125);
	float diamond = abs(face.x) + abs(face.y);
	float edge_aa = max(fwidth(diamond), 0.001);
	float top_face = 1.0 - smoothstep(1.0 - edge_aa, 1.0, diamond);

	vec2 position = world_position * detail_scale / vec2(2.0, 1.0);
	// Sampling moves opposite the visible flow. With the 2:1 scale above,
	// this sends ripples down-left along the isometric water tiles.
	position += vec2(time * 0.165, -time * 0.165);
	// Measure pixel width BEFORE fract, row staggering, and random offsets.
	// Derivatives across those discontinuities produced horizontal streaks.
	float aa = max(fwidth(position.y), 0.002);
	position.x += floor(position.y) * 0.47;
	vec2 cell = floor(position);
	float seed = random_value(cell);
	float variation = random_value(cell + vec2(19.7, 8.3));
	vec2 local_position = fract(position) - vec2(0.5);
	local_position -= vec2(seed - 0.5, variation - 0.5) * 0.25;

	float half_length = mix(0.15, 0.28, seed);
	float along = local_position.x / half_length;
	float bob = sin(time * 0.85 + seed * 6.28318) * 0.025;
	float curve = 0.065 * (1.0 - along * along) + bob;
	float distance_to_crest = abs(local_position.y - curve);
	float end_fade = 1.0 - smoothstep(0.65, 1.0, abs(along));
	float stroke = 1.0 - smoothstep(0.020, 0.020 + aa, distance_to_crest);
	stroke *= end_fade;

	// Only the full curved ripple; no short, nearly flat companion dashes.
	float breathe = 0.62 + 0.38 * sin(time * 0.7 + variation * 6.28318);
	float ripple = stroke * breathe * step(seed, ripple_density);

	float wash = 0.5 + 0.5 * sin(world_position.x * 0.008
		+ sin(world_position.y * 0.012 + time * 0.22) * 1.8 - time * 0.3);
	float soft_highlight = smoothstep(0.48, 0.90, wash);
	vec3 base_color = mix(surface_tint.rgb, soft_light.rgb, soft_highlight * 0.55);
	float base_alpha = surface_opacity * (0.65 + soft_highlight * 0.35);
	float crest_alpha = ripple * highlight_opacity;
	float water_alpha = base_alpha + crest_alpha * (1.0 - base_alpha);
	vec3 water_color = mix(base_color, crest_light.rgb,
		crest_alpha / max(water_alpha, 0.0001));
	COLOR = vec4(water_color, tile_mask.a * top_face * water_alpha);
}
