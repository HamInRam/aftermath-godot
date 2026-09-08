shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool enable_effect = true;
uniform float scanline_intensity : hint_range(0.0, 0.25) = 0.002;
uniform float scanline_count : hint_range(30.0, 360.0) = 90.0;
uniform float vignette_intensity : hint_range(0.1, 2.0) = 0.72;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.10;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.00025;
uniform float distortion : hint_range(0.0, 0.03) = 0.0005;
uniform float focus_amount : hint_range(0.0, 1.0) = 0.0;
uniform float blood_stance_amount : hint_range(0.0, 1.0) = 0.0;
uniform float noir_contrast : hint_range(1.0, 2.0) = 1.16;
uniform float grain_strength : hint_range(0.0, 0.08) = 0.0;
uniform float grayscale_steps : hint_range(16.0, 255.0) = 32.0;

vec2 curve(vec2 uv) {
	vec2 centered = (uv - 0.5) * 2.0;
	centered.x *= 1.0 + pow(abs(centered.y) * distortion, 2.0);
	centered.y *= 1.0 + pow(abs(centered.x) * distortion, 2.0);
	return centered * 0.5 + 0.5;
}

float pixel_noise(vec2 cell, float frame) {
	return fract(sin(dot(cell + vec2(frame * 7.0, frame * 13.0), vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Never resample an enlarged window back through a hard-coded 320x180 grid.
	// SCREEN_PIXEL_SIZE describes the actual render target, so glyph stems and
	// native pixels keep a one-to-one sample at every supported window size.
	vec2 pixel_grid = max(round(vec2(1.0) / SCREEN_PIXEL_SIZE), vec2(1.0));
	vec2 uv = (floor(SCREEN_UV * pixel_grid) + vec2(0.5)) / pixel_grid;
	vec3 raw_color = textureLod(screen_texture, uv, 0.0).rgb;
	vec3 color = raw_color;
	vec2 texel = vec2(1.0) / pixel_grid;
	float raw_luma = dot(raw_color, vec3(0.299, 0.587, 0.114));
	float edge_delta = 0.0;
	edge_delta = max(edge_delta, abs(raw_luma - dot(textureLod(screen_texture, uv + vec2(texel.x, 0.0), 0.0).rgb, vec3(0.299, 0.587, 0.114))));
	edge_delta = max(edge_delta, abs(raw_luma - dot(textureLod(screen_texture, uv - vec2(texel.x, 0.0), 0.0).rgb, vec3(0.299, 0.587, 0.114))));
	edge_delta = max(edge_delta, abs(raw_luma - dot(textureLod(screen_texture, uv + vec2(0.0, texel.y), 0.0).rgb, vec3(0.299, 0.587, 0.114))));
	edge_delta = max(edge_delta, abs(raw_luma - dot(textureLod(screen_texture, uv - vec2(0.0, texel.y), 0.0).rgb, vec3(0.299, 0.587, 0.114))));
	// Any isolated one-pixel mark or hard silhouette edge receives the untouched
	// grade. Film texture is only legal inside broad, already-flat colour fields.
	float native_pixel_protection = smoothstep(0.018, 0.085, edge_delta);
	if (enable_effect) {
		// Effects are evaluated on the native render grid. Curvature used to move
		// a world pixel between output cells and is intentionally presentation-only.
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			color = vec3(0.0);
		} else {
			float pixel_shift = floor(chromatic_aberration * pixel_grid.x + 0.5);
			vec2 channel_offset = vec2(pixel_shift / pixel_grid.x * sign(uv.x - 0.5), 0.0);
			// Registration echo is luminance-only. It creates lo-fi print instability
			// without violating the black/white/crimson palette with RGB fringes.
			if (pixel_shift > 0.5) {
				float left_luma = dot(textureLod(screen_texture, uv - channel_offset, 0.0).rgb, vec3(0.299, 0.587, 0.114));
				float right_luma = dot(textureLod(screen_texture, uv + channel_offset, 0.0).rgb, vec3(0.299, 0.587, 0.114));
				float center_luma = dot(color, vec3(0.299, 0.587, 0.114));
				color = vec3(left_luma * 0.18 + center_luma * 0.64 + right_luma * 0.18);
			}
		}
	}
	// Focus never blurs or warps the native pixel grid. The grade remains clearly
	// visible for the complete ability duration, then releases with focus_amount.
	vec2 centered = (uv - vec2(0.5)) * vec2(pixel_grid.x / pixel_grid.y, 1.0);
	float radial = length(centered);
	float edge = smoothstep(0.22, 0.80, radial);
	float breath = 0.5 + 0.5 * sin(TIME * 9.0);
	float focus_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 focus_tint = vec3(clamp((focus_luma - 0.5) * 1.16 + 0.55 + edge * 0.045, 0.0, 1.0));
	color = mix(color, focus_tint, focus_amount * (0.46 + edge * 0.18));
	float border_distance = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float border = 1.0 - smoothstep(0.0, 0.009, border_distance);
	vec3 focus_color = vec3(mix(0.58, 0.92, breath));
	color += focus_color * border * focus_amount * (0.24 + breath * 0.10);
	// A soft, continuously breathing perimeter replaces the old one-shot ring.
	float perimeter = smoothstep(0.46, 0.88, radial) * (1.0 - smoothstep(0.88, 1.06, radial));
	color += focus_color * perimeter * focus_amount * (0.025 + breath * 0.025);
	// Blood stance is a restrained crimson pressure at the perimeter. It never
	// blurs or recolors the playfield, preserving OTXO-like threat readability.
	vec3 blood_rim = vec3(0.78, 0.008, 0.025);
	color = mix(color, blood_rim, perimeter * blood_stance_amount * (0.10 + breath * 0.045));
	color += blood_rim * border * blood_stance_amount * 0.14;

	// Art-direction pass: one strict output contract. Everything becomes neutral
	// ink except authored crimson blood/danger. Legacy cyan, violet, amber and
	// venue tints are deliberately converted to luminance.
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float channel_max = max(color.r, max(color.g, color.b));
	float channel_min = min(color.r, min(color.g, color.b));
	float chroma = channel_max - channel_min;
	// Former cyan/magenta UI accents should become bright neutral ink, not muddy
	// mid-gray. Value-assisted luminance preserves their authored hierarchy while
	// the final output still contains no additional hue.
	luma = mix(luma, channel_max, clamp(chroma * 0.62, 0.0, 0.58));
	luma = clamp((luma - 0.5) * noir_contrast + 0.5, 0.0, 1.0);
	float fine_detail_protection = max(native_pixel_protection, smoothstep(0.56, 0.78, luma));
	if (enable_effect) luma += (pixel_noise(floor(uv * pixel_grid), floor(TIME * 12.0)) - 0.5) * grain_strength * (1.0 - fine_detail_protection);
	luma = floor(clamp(luma, 0.0, 1.0) * grayscale_steps + 0.5) / grayscale_steps;
	float red_delta = raw_color.r - max(raw_color.g, raw_color.b);
	float crimson_signal = step(0.18, raw_color.r) * step(0.19, red_delta) * (1.0 - step(0.35, raw_color.g)) * (1.0 - step(0.38, raw_color.b));
	float crimson_value = clamp(max(raw_color.r, luma * 0.74), 0.28, 1.0);
	color = vec3(luma);
	color = mix(color, vec3(crimson_value, crimson_value * 0.018, crimson_value * 0.035), crimson_signal);
	if (enable_effect) {
		float scanline = mod(floor(uv.y * pixel_grid.y), 2.0);
		// Bright one-pixel glyphs and icons stay untouched; scanlines live in the
		// world midtones where they cannot break letter stems into alternating rows.
		color -= scanline * scanline_intensity * (1.0 - fine_detail_protection);
		float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
		vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);
		color = mix(color, color * vignette, vignette_opacity);
	}
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
