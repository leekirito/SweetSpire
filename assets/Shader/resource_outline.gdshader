shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.15, 0.65, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
	float center = texture(TEXTURE, UV).a;
	float around = 0.0;
	around = max(around, texture(TEXTURE, UV + vec2(size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV - vec2(size.x, 0.0)).a);
	around = max(around, texture(TEXTURE, UV + vec2(0.0, size.y)).a);
	around = max(around, texture(TEXTURE, UV - vec2(0.0, size.y)).a);
	around = max(around, texture(TEXTURE, UV + size).a);
	around = max(around, texture(TEXTURE, UV - size).a);
	around = max(around, texture(TEXTURE, UV + vec2(size.x, -size.y)).a);
	around = max(around, texture(TEXTURE, UV + vec2(-size.x, size.y)).a);
	COLOR = vec4(outline_color.rgb, outline_color.a * around * (1.0 - center));
}
