shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D texture_ao : hint_default_white, filter_nearest, repeat_enable;

// Настройки смешивания для Triplanar
uniform float triplanar_sharpness = 4.0;

// Масштаб UV вблизи (мелкая текстура) и вдали (крупная текстура)
uniform vec3 uv1_scale_close = vec3(0.4, 0.4, 0.4);
uniform vec3 uv1_scale_far = vec3(0.05, 0.05, 0.05);

// Дистанции, на которых начинается и заканчивается переход
uniform float min_distance = 15.0;
uniform float max_distance = 35.0;

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;

void vertex() {
	// Подготовка координат для Triplanar маппинга
	vec3 normal = abs(NORMAL);
	normal = pow(normal, vec3(triplanar_sharpness));
	normal /= dot(normal, vec3(1.0));
	uv1_power_normal = normal;

	// Вычисляем глобальные координаты вершины
	uv1_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos, vec3 p_scale) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.xy * p_scale.xy) * p_weights.z;
	samp += texture(p_sampler, p_triplanar_pos.xz * p_scale.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0) * p_scale.zy) * p_weights.x;
	return samp;
}

void fragment() {
	// В Godot длина VERTEX во фрагментном шейдере дает точную дистанцию от камеры до пикселя
	float dist = length(VERTEX);

	// smoothstep выдаст 0 вблизи (min_distance) и плавно перейдет в 1 вдали (max_distance)
	float blend = smoothstep(min_distance, max_distance, dist);

	// ---- ALBEDO ----
	vec4 albedo_close = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
	vec4 albedo_far = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
	// Смешиваем две текстуры в зависимости от дистанции
	vec4 albedo_tex = mix(albedo_close, albedo_far, blend);
	ALBEDO = albedo.rgb * albedo_tex.rgb;

	// ---- AMBIENT OCCLUSION (AO) ----
	vec4 ao_close = triplanar_texture(texture_ao, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
	vec4 ao_far = triplanar_texture(texture_ao, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
	AO = mix(ao_close.r, ao_far.r, blend);
	AO_LIGHT_AFFECT = 0.5;

	// ---- NORMAL MAP ----
	vec4 normal_close = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
	vec4 normal_far = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
	NORMAL_MAP = mix(normal_close.rgb, normal_far.rgb, blend);
}
