shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.15, 0.65, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 3.0;

void fragment() {
	float center = texture(TEXTURE, UV).a;
	float around = 0.0;
	for (int radius = 1; radius <= 8; radius++) {
		if (float(radius - 1) >= outline_width) {
			break;
		}
		float distance = min(float(radius), outline_width);
		vec2 horizontal = vec2(TEXTURE_PIXEL_SIZE.x * distance, 0.0);
		vec2 vertical = vec2(0.0, TEXTURE_PIXEL_SIZE.y * distance);
		vec2 diagonal = TEXTURE_PIXEL_SIZE * distance * 0.70710678;
		around = max(around, texture(TEXTURE, UV + horizontal).a);
		around = max(around, texture(TEXTURE, UV - horizontal).a);
		around = max(around, texture(TEXTURE, UV + vertical).a);
		around = max(around, texture(TEXTURE, UV - vertical).a);
		around = max(around, texture(TEXTURE, UV + diagonal).a);
		around = max(around, texture(TEXTURE, UV - diagonal).a);
		around = max(around, texture(TEXTURE, UV + vec2(diagonal.x, -diagonal.y)).a);
		around = max(around, texture(TEXTURE, UV + vec2(-diagonal.x, diagonal.y)).a);
	}
	COLOR = vec4(outline_color.rgb, outline_color.a * around * (1.0 - center));
}
