shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D sprite_texture : filter_nearest, source_color;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_thickness : hint_range(1.0, 15.0) = 2.0;

void fragment() {
	// Определяем размер пикселя текстуры для "пиксельно-идеальной" обводки
	vec2 tex_size = vec2(textureSize(sprite_texture, 0));
	vec2 pixel_size = 1.0 / tex_size;

	vec4 col = texture(sprite_texture, UV);

	float a = 0.0;
	int thickness = int(round(outline_thickness));

	// Сканируем соседей (от 1 до 15 пикселей вокруг, динамически)
	for (int x = -15; x <= 15; x++) {
		for (int y = -15; y <= 15; y++) {
			if (abs(x) > thickness || abs(y) > thickness) continue;
			if (x == 0 && y == 0) continue;
			a += texture(sprite_texture, UV + vec2(float(x), float(y)) * pixel_size).a;
		}
	}

	// Четкая граница: если рядом есть непрозрачный пиксель (a > 0.1), а текущий прозрачный (col.a < 0.1)
	float outline = step(0.1, a) * step(col.a, 0.1);

	if (col.a > 0.1) {
		ALBEDO = col.rgb;
		ALPHA = col.a;
	} else if (outline > 0.0) {
		// Добавляем эффект пульсации (мигания) обводки для супер-заметности
		float pulse = sin(TIME * 8.0) * 0.2 + 0.8;
		ALBEDO = outline_color.rgb * pulse;
		ALPHA = outline_color.a;
	} else {
		ALPHA = 0.0;
	}
}
