shader_type spatial;
render_mode unshaded, fog_disabled;

varying vec3 sphere_normal;

void vertex() {
    sphere_normal = NORMAL;
}

float mare(vec3 n, vec3 center, float width) {
    float d = length(n - normalize(center));
    return 1.0 - smoothstep(width * 0.45, width, d);
}

void fragment() {
    vec3 n = normalize(sphere_normal);
    float markings = 0.18 * mare(n, vec3(-0.12, -0.40, -1.0), 0.37);
    markings += 0.15 * mare(n, vec3(0.48, -0.72, -0.83), 0.25);
    markings += 0.10 * mare(n, vec3(0.58, -0.16, -0.9), 0.20);
    markings += 0.08 * mare(n, vec3(-0.55, -0.60, -0.85), 0.16);
    float surface_noise = sin(n.x * 31.0 + n.z * 14.0) * sin(n.y * 34.0 - n.z * 19.0) * 0.025;
    ALBEDO = vec3(0.79, 0.86, 0.96) * (1.0 - markings + surface_noise);
}
