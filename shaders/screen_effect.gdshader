shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool enable_effect = true;
uniform float scanline_intensity : hint_range(0.0, 0.25) = 0.005;
uniform float scanline_count : hint_range(30.0, 360.0) = 90.0;
uniform float vignette_intensity : hint_range(0.1, 2.0) = 0.72;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.11;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.00025;
uniform float distortion : hint_range(0.0, 0.03) = 0.0005;

vec2 curve(vec2 uv) {
	vec2 centered = (uv - 0.5) * 2.0;
	centered.x *= 1.0 + pow(abs(centered.y) * distortion, 2.0);
	centered.y *= 1.0 + pow(abs(centered.x) * distortion, 2.0);
	return centered * 0.5 + 0.5;
}

void fragment() {
	vec2 pixel_grid = vec2(320.0, 180.0);
	vec2 uv = (floor(SCREEN_UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	if (!enable_effect) {
		COLOR = textureLod(screen_texture, uv, 0.0);
	} else {
		// Effects are evaluated on the native render grid. Curvature used to move
		// a world pixel between output cells and is intentionally presentation-only.
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			float pixel_shift = floor(chromatic_aberration * 320.0 + 0.5);
			vec2 channel_offset = vec2(pixel_shift / 320.0 * sign(uv.x - 0.5), 0.0);
			vec3 color = textureLod(screen_texture, uv, 0.0).rgb;
			// The default sub-pixel aberration rounds to zero on the 320px grid.
			// Avoid three identical full-screen samples unless a visible shift exists.
			if (pixel_shift > 0.5) {
				color.r = textureLod(screen_texture, uv - channel_offset, 0.0).r;
				color.b = textureLod(screen_texture, uv + channel_offset, 0.0).b;
			}
			color = clamp((color - vec3(0.5)) * 1.12 + vec3(0.5), vec3(0.0), vec3(1.0));
			float luminance = dot(color, vec3(0.299, 0.587, 0.114));
			color = mix(vec3(luminance), color, 0.96);
			float scanline = mod(floor(uv.y * 180.0), 2.0);
			color -= scanline * scanline_intensity;
			float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
			vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);
			color = mix(color, color * vignette, vignette_opacity);
			COLOR = vec4(color, 1.0);
		}
	}
}
