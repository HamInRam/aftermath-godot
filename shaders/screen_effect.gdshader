shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool enable_effect = true;
uniform float scanline_intensity : hint_range(0.0, 0.25) = 0.045;
uniform float scanline_count : hint_range(30.0, 360.0) = 90.0;
uniform float vignette_intensity : hint_range(0.1, 2.0) = 0.55;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.28;
uniform float chromatic_aberration : hint_range(0.0, 0.02) = 0.004;
uniform float distortion : hint_range(0.0, 0.03) = 0.006;

vec2 curve(vec2 uv) {
	vec2 centered = (uv - 0.5) * 2.0;
	centered.x *= 1.0 + pow(abs(centered.y) * distortion, 2.0);
	centered.y *= 1.0 + pow(abs(centered.x) * distortion, 2.0);
	return centered * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (!enable_effect) {
		COLOR = textureLod(screen_texture, uv, 0.0);
	} else {
		uv = curve(uv);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			vec2 channel_offset = vec2(chromatic_aberration * (uv.x - 0.5), 0.0);
			vec3 color;
			color.r = textureLod(screen_texture, uv - channel_offset, 0.0).r;
			color.g = textureLod(screen_texture, uv, 0.0).g;
			color.b = textureLod(screen_texture, uv + channel_offset, 0.0).b;
			float scanline = sin(uv.y * scanline_count * 6.2831853) * 0.5 + 0.5;
			color -= scanline * scanline_intensity;
			float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
			vignette = clamp(pow(16.0 * vignette, vignette_intensity), 0.0, 1.0);
			color = mix(color, color * vignette, vignette_opacity);
			COLOR = vec4(color, 1.0);
		}
	}
}
