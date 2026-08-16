shader_type canvas_item;

uniform bool enable_cycle = true;
uniform float cycle_speed : hint_range(0.0, 1.0) = 0.08;
uniform float base_saturation : hint_range(0.0, 1.0) = 0.62;
uniform float base_value : hint_range(0.0, 1.0) = 0.48;

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 0.6666667, 0.3333333, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 tint = enable_cycle ? hsv2rgb(vec3(fract(TIME * cycle_speed), base_saturation, base_value)) : vec3(0.24, 0.16, 0.3);
	COLOR = vec4(tex.rgb * tint * 2.0, tex.a) * COLOR;
}
