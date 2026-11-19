shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform float virtual_height : hint_range(180.0, 1080.0, 1.0) = 480.0;
uniform float color_levels : hint_range(8.0, 64.0, 1.0) = 32.0;
uniform float retro_mix : hint_range(0.0, 1.0) = 0.65;
uniform float vignette : hint_range(0.0, 0.6) = 0.16;
uniform float grain : hint_range(0.0, 0.05) = 0.008;
uniform float tension : hint_range(0.0, 1.0) = 0.0;
uniform float impact : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv * 2.0 - 1.0;
	float edge = smoothstep(0.32, 1.25, length(centered));
	// Soft, low-frequency displacement, not rapid flicker.
	uv.x += tension * 0.003 * sin(uv.y * 21.0 + TIME * 4.0);
	uv += centered * impact * 0.003;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float height = min(virtual_height, screen_size.y);
	vec2 grid = vec2(max(1.0, floor(height * screen_size.x / screen_size.y)), height);
	vec2 cell = floor(uv * grid);
	vec2 snapped = (cell + 0.5) / grid;
	vec2 sample_uv = clamp(mix(uv, snapped, retro_mix), SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
	vec3 col = texture(screen_tex, sample_uv).rgb;
	// Dither anchored to the pixel grid; black remains black.
	float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	float luminance = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float visible_grain = smoothstep(0.0, 0.08, luminance);
	vec3 quantized = floor(clamp(col + noise * grain * visible_grain, 0.0, 1.0) * color_levels + 0.5) / color_levels;
	col = mix(col, quantized, retro_mix * 0.55);
	col *= 1.0 - edge * clamp(vignette + tension * 0.18 + impact * 0.09, 0.0, 0.75);
	// Tints are multiplicative, so they do not reveal the scene in darkness.
	col *= mix(vec3(1.0), vec3(0.72, 0.90, 1.0), tension * edge * 0.45);
	col *= mix(vec3(1.0), vec3(1.08, 0.42, 0.42), damage * edge * 0.65);
	col *= mix(vec3(1.0), vec3(1.0, 1.05, 1.10), impact * (1.0 - damage) * 0.18);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
