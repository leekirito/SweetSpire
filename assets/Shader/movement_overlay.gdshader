shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform vec4 highlight_color : source_color = vec4(0.18, 0.55, 1.0, 0.68);
uniform float pulse_speed : hint_range(0.0, 8.0) = 2.0;
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.12;

void fragment() {
	float pulse = 1.0 - pulse_strength * (0.5 + 0.5 * sin(TIME * pulse_speed));
	COLOR.rgb *= highlight_color.rgb;
	COLOR.a *= highlight_color.a * pulse;
}
