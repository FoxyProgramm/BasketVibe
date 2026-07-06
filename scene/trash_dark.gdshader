shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform float cube_height = 0.811;

varying float fixed_y;

void vertex() {
    fixed_y = VERTEX.y;
}

void fragment() {
    float gradient = (fixed_y + cube_height * 0.5) / cube_height;
    gradient = clamp(gradient, 0.0, 1.0);
    
    ALBEDO = vec3(0.0, 0.0, 0.0);
    ALPHA = 1.0 - gradient;
}