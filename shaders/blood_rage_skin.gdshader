shader_type canvas_item;
render_mode unshaded;

uniform float flow_clock = 0.0;
varying vec2 skin_position;

void vertex() {
	skin_position = VERTEX;
}

void fragment() {
	vec2 cell = floor(skin_position + vec2(0.001));
	float luminance = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	// Quantized rivulets travel over the existing silhouette, never a rectangle.
	float lane = floor(mod(cell.x * 3.0, 7.0));
	float stream = mod(cell.y + floor(flow_clock * 13.0) + lane, 9.0);
	float bright = step(6.0, stream);
	float red = mix(0.48, 0.88, clamp(luminance, 0.0, 1.0));
	red = mix(red, 1.0, bright * 0.8);
	if (luminance < 0.08) red *= 0.55;
	COLOR = vec4(red, 0.008, 0.035, COLOR.a);
}
