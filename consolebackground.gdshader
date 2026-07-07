shader_type canvas_item;

uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);
uniform float scanline_amount = 0.3;

void fragment() {
    vec4 col = bg_color;
    
    float scanline = sin(UV.y * 400.0) * 0.5 + 0.5;
    col.a -= scanline * scanline_amount * 0.3;
    
    float noise = fract(sin(dot(UV, vec2(12.9898, 78.233))) * 43758.5453);
    col.rgb += noise * 0.03;
    
    COLOR = col;
}