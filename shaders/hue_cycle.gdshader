shader_type canvas_item;

uniform bool enable_cycle = true;
uniform float cycle_speed : hint_range(0.0, 1.0) = 0.08;
uniform float base_saturation : hint_range(0.0, 1.0) = 0.0;
uniform float base_value : hint_range(0.0, 1.0) = 0.24;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 pixel_uv = (floor(UV * texture_size) + vec2(0.5)) / max(texture_size, vec2(1.0));
	vec4 tex = texture(TEXTURE, pixel_uv);
	float phase = enable_cycle ? sin(TIME * cycle_speed * 6.2831853) * 0.035 : 0.0;
	float grain = fract(sin(dot(floor(pixel_uv * texture_size), vec2(12.9898, 78.233))) * 43758.5453);
	float value = clamp(base_value + phase + (grain - 0.5) * 0.035, 0.0, 1.0);
	COLOR = vec4(tex.rgb * vec3(value) * 2.0, tex.a) * COLOR;
}
