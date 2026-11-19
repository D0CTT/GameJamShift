shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled;

uniform vec4 marker_color : source_color = vec4(1.0, 0.045, 0.065, 1.0);
uniform float fill_opacity : hint_range(0.0, 1.0) = 0.32;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	ALBEDO = marker_color.rgb;
	ALPHA = mix(fill_opacity, edge_opacity, edge) * marker_color.a;
}
