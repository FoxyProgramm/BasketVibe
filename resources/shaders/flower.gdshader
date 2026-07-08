shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform float sway_amount = 1.03;
uniform float sway_speed = 1.2;
uniform sampler2D albedo_tex : source_color;

void vertex() {
    float height_factor = VERTEX.y;
    float sway = sin(TIME * sway_speed + INSTANCE_CUSTOM.x + VERTEX.x * 3.0 + VERTEX.z * 2.0) * sway_amount;
    VERTEX.x += sway * height_factor;
    VERTEX.z += sway * height_factor * 0.5;
}

void fragment() {
    vec4 tex = texture(albedo_tex, UV);
    ALBEDO = tex.rgb;
    ALPHA = tex.a;
}