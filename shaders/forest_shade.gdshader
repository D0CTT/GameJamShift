shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.63, 0.73, 0.82, 1.0);
uniform float deep_brightness : hint_range(0.1, 1.0) = 0.25;
varying float world_z;

void vertex() {
    world_z = (MODEL_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
    float depth = smoothstep(5.5, 11.0, -world_z);
    vec3 cold = mix(vec3(1.0), vec3(0.72, 0.83, 1.0), depth);
    ALBEDO = base_color.rgb * cold * mix(1.0, deep_brightness, depth);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
    SPECULAR = 0.35;
}
