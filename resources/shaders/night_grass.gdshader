shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;


uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform sampler2D texture_normal : hint_normal, filter_nearest, repeat_enable;
uniform sampler2D texture_ao : hint_default_white, filter_nearest, repeat_enable;

uniform float triplanar_sharpness = 4.0;
uniform vec3 uv1_scale_close = vec3(0.4, 0.4, 0.4);
uniform vec3 uv1_scale_far = vec3(0.05, 0.05, 0.05);
uniform float min_distance = 15.0;
uniform float max_distance = 35.0;

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;

void vertex() {
    float height = 0.0;
    
    // 12 крупных бугров, которые перекрывают друг друга
    vec2 bumps[12];
    bumps[0] = vec2(0.2, 0.1);
    bumps[1] = vec2(0.5, 0.15);
    bumps[2] = vec2(0.8, 0.2);
    bumps[3] = vec2(0.15, 0.4);
    bumps[4] = vec2(0.45, 0.45);
    bumps[5] = vec2(0.75, 0.4);
    bumps[6] = vec2(0.1, 0.7);
    bumps[7] = vec2(0.4, 0.75);
    bumps[8] = vec2(0.7, 0.7);
    bumps[9] = vec2(0.25, 0.9);
    bumps[10] = vec2(0.55, 0.9);
    bumps[11] = vec2(0.85, 0.85);
    
    float radii[12] = float[](0.25, 0.28, 0.25, 0.28, 0.3, 0.28, 0.25, 0.28, 0.25, 0.28, 0.25, 0.28);
    float heights_arr[12] = float[](0.6, 0.8, 0.5, 0.7, 1.0, 0.6, 0.8, 0.9, 0.5, 0.7, 0.6, 0.8);
    
    for (int j = 0; j < 12; j++) {
        float dist = length(UV - bumps[j]);
        if (dist < radii[j]) {
            float t = 1.0 - (dist / radii[j]);
            t = t * t * (3.0 - 2.0 * t);
            height += heights_arr[j] * t * 2.7;
        }
    }
    
    // Добавляем мелкие неровности поверх
    vec2 small_bumps[8];
    small_bumps[0] = vec2(0.05, 0.05);
    small_bumps[1] = vec2(0.3, 0.2);
    small_bumps[2] = vec2(0.6, 0.1);
    small_bumps[3] = vec2(0.9, 0.35);
    small_bumps[4] = vec2(0.15, 0.55);
    small_bumps[5] = vec2(0.5, 0.6);
    small_bumps[6] = vec2(0.8, 0.55);
    small_bumps[7] = vec2(0.35, 0.85);
    
    float small_radii[8] = float[](0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18, 0.18);
    float small_heights[8] = float[](0.3, 0.4, 0.3, 0.4, 0.3, 0.4, 0.3, 0.4);
    
    for (int k = 0; k < 8; k++) {
        float dist = length(UV - small_bumps[k]);
        if (dist < small_radii[k]) {
            float t = 1.0 - (dist / small_radii[k]);
            t = t * t * (3.0 - 2.0 * t);
            height += small_heights[k] * t * 1.4;
        }
    }
    
    VERTEX.y += height;
    
    vec3 normal = abs(NORMAL);
    normal = pow(normal, vec3(triplanar_sharpness));
    normal /= dot(normal, vec3(1.0));
    uv1_power_normal = normal;

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
    float dist = length(VERTEX);
    float blend = smoothstep(min_distance, max_distance, dist);

    vec4 albedo_close = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
    vec4 albedo_far = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
    vec4 albedo_tex = mix(albedo_close, albedo_far, blend);
    ALBEDO = albedo.rgb * albedo_tex.rgb;

    vec4 ao_close = triplanar_texture(texture_ao, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
    vec4 ao_far = triplanar_texture(texture_ao, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
    AO = mix(ao_close.r, ao_far.r, blend);
    AO_LIGHT_AFFECT = 0.0;

    vec4 normal_close = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos, uv1_scale_close);
    vec4 normal_far = triplanar_texture(texture_normal, uv1_power_normal, uv1_triplanar_pos, uv1_scale_far);
    NORMAL_MAP = mix(normal_close.rgb, normal_far.rgb, blend);
}