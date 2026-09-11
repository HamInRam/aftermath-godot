shader_type canvas_item;
render_mode unshaded;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	float edge = min(min(UV.x, 1.0-UV.x), min(UV.y, 1.0-UV.y));
	float band = 1.0 - smoothstep(0.006, 0.065, edge);
	float value = pulse > 0.70 ? 1.0 : 0.0;
	COLOR = vec4(vec3(value), band * pulse * intensity * 0.30);
}
