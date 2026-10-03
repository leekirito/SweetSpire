shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 fill_color : source_color = vec4(0.9, 0.68, 0.18, 0.16);
uniform vec4 edge_color : source_color = vec4(1.0, 0.84, 0.32, 0.75);
uniform float edge_width : hint_range(0.01, 0.3) = 0.09;
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
uniform float pulse_strength : hint_range(0.0, 1.0) = 0.25;

void fragment() {
	float diamond = abs(UV.x * 2.0 - 1.0) + abs(UV.y * 2.0 - 1.0);
	float border = smoothstep(1.0 - edge_width, 1.0, diamond);
	float pulse = 1.0 - pulse_strength + pulse_strength * (0.5 + 0.5 * sin(TIME * pulse_speed));
	COLOR = mix(fill_color, edge_color, border);
	COLOR.a *= pulse;
}
