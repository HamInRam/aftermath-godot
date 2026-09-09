shader_type canvas_item;
render_mode unshaded;

uniform sampler2D previous_mask : filter_nearest, repeat_disable;
uniform float removal_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 chunk_origin = vec2(0.0);

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	vec4 old = texture(previous_mask, UV);
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE) + chunk_origin;
	float rank = fract(sin(dot(pixel, vec2(12.9898, 78.233))) * 43758.5453);
	// Ordered disappearance, never bilinear filtering or translucent crimson.
	// Gameplay already removed these pixels; this history is visual-only.
	float keep = step(smoothstep(0.0, 1.0, removal_progress), rank);
	bool was_blood = old.r > old.g + 0.1;
	COLOR = current.a > 0.0 ? current : (was_blood ? old * keep : current);
}
