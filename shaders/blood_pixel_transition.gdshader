shader_type canvas_item;
render_mode unshaded;

uniform sampler2D previous_mask : filter_nearest, repeat_disable;
uniform float removal_progress : hint_range(0.0, 1.0) = 1.0;
uniform vec2 chunk_origin = vec2(0.0);

float hash_cell(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float erosion_field(vec2 p) {
	// World-space interpolation avoids repeating 32px tile borders. Evaluate
	// once per native pixel, never blur the texture or turn crimson translucent.
	vec2 cell = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec4 current = texture(TEXTURE, UV);
	vec4 old = texture(previous_mask, UV);
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE) + chunk_origin;
	float rank = clamp(erosion_field(pixel / 5.0) * 0.85 + hash_cell(pixel) * 0.15, 0.001, 0.999);
	// Ordered disappearance, never bilinear filtering or translucent crimson.
	// Gameplay already removed these pixels; this history is visual-only.
	float keep = step(smoothstep(0.0, 1.0, removal_progress), rank);
	bool was_blood = old.r > old.g + 0.1;
	COLOR = current.a > 0.0 ? current : (was_blood ? old * keep : current);
}
