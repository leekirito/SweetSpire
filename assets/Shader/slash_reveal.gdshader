shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float edge_softness : hint_range(0.001, 0.3) = 0.08;
uniform vec4 slash_color : source_color = vec4(1.0, 0.84, 0.52, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float mask = 1.0 - smoothstep(reveal, reveal + edge_softness, UV.x);
	COLOR = vec4(tex.rgb * slash_color.rgb, tex.a * slash_color.a * mask) * COLOR;
}
