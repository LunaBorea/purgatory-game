shader_type canvas_item;

uniform sampler2D next_frame : source_color, filter_linear;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float eye_brightness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float glow_strength : hint_range(0.0, 1.5, 0.01) = 0.65;
varying vec4 vertex_tint;
const vec2 PIXEL_SIZE = vec2(1.0 / 1920.0, 1.0 / 1080.0);

void vertex() { vertex_tint = COLOR; }

bool near_eye(vec2 p, float margin) {
	return (p.x >= 207.0-margin && p.x <= 237.0+margin && p.y >= 263.0-margin && p.y <= 280.0+margin) ||
		(p.x >= 247.0-margin && p.x <= 265.0+margin && p.y >= 265.0-margin && p.y <= 283.0+margin) ||
		(p.x >= 546.0-margin && p.x <= 571.0+margin && p.y >= 317.0-margin && p.y <= 337.0+margin) ||
		(p.x >= 694.0-margin && p.x <= 718.0+margin && p.y >= 328.0-margin && p.y <= 346.0+margin) ||
		(p.x >= 732.0-margin && p.x <= 752.0+margin && p.y >= 332.0-margin && p.y <= 350.0+margin) ||
		(p.x >= 1393.0-margin && p.x <= 1426.0+margin && p.y >= 294.0-margin && p.y <= 311.0+margin) ||
		(p.x >= 1671.0-margin && p.x <= 1699.0+margin && p.y >= 342.0-margin && p.y <= 357.0+margin);
}

float light_mask_a(sampler2D image, vec2 uv, vec2 offset) {
	vec2 pos = uv / PIXEL_SIZE + offset;
	if (!near_eye(pos, 0.0)) { return 0.0; }
	vec4 sample_color = texture(image, uv + offset * PIXEL_SIZE);
	return smoothstep(0.10, 0.35, min(sample_color.r, min(sample_color.g, sample_color.b))) * sample_color.a;
}

vec4 illuminate_a(sampler2D image, vec2 uv) {
	vec4 color = texture(image, uv);
	vec2 pos = uv / PIXEL_SIZE;
	if (!near_eye(pos, 6.0)) { return color; }
	float center = light_mask_a(image, uv, vec2(0.0));
	float halo = center * 0.20;
	halo += (light_mask_a(image, uv, vec2(2.0, 0.0)) + light_mask_a(image, uv, vec2(-2.0, 0.0)) + light_mask_a(image, uv, vec2(0.0, 2.0)) + light_mask_a(image, uv, vec2(0.0, -2.0))) * 0.10;
	halo += (light_mask_a(image, uv, vec2(4.0, 0.0)) + light_mask_a(image, uv, vec2(-4.0, 0.0)) + light_mask_a(image, uv, vec2(0.0, 4.0)) + light_mask_a(image, uv, vec2(0.0, -4.0))) * 0.06;
	halo += (light_mask_a(image, uv, vec2(3.0, 3.0)) + light_mask_a(image, uv, vec2(-3.0, 3.0)) + light_mask_a(image, uv, vec2(3.0, -3.0)) + light_mask_a(image, uv, vec2(-3.0, -3.0))) * 0.04;
	// The darkest original pixels remain dark, including the black pupils.
	float preserve_dark = smoothstep(0.035, 0.08, max(color.r, max(color.g, color.b)));
	color.rgb = min(color.rgb + vec3(eye_brightness * center + glow_strength * halo * preserve_dark), vec3(0.95));
	return color;
}

float light_mask_b( vec2 uv, vec2 offset) {
	vec2 pos = uv / PIXEL_SIZE + offset;
	if (!near_eye(pos, 0.0)) { return 0.0; }
	vec4 sample_color = texture(next_frame, uv + offset * PIXEL_SIZE);
	return smoothstep(0.10, 0.35, min(sample_color.r, min(sample_color.g, sample_color.b))) * sample_color.a;
}

vec4 illuminate_b( vec2 uv) {
	vec4 color = texture(next_frame, uv);
	vec2 pos = uv / PIXEL_SIZE;
	if (!near_eye(pos, 6.0)) { return color; }
	float center = light_mask_b( uv, vec2(0.0));
	float halo = center * 0.20;
	halo += (light_mask_b( uv, vec2(2.0, 0.0)) + light_mask_b( uv, vec2(-2.0, 0.0)) + light_mask_b( uv, vec2(0.0, 2.0)) + light_mask_b( uv, vec2(0.0, -2.0))) * 0.10;
	halo += (light_mask_b( uv, vec2(4.0, 0.0)) + light_mask_b( uv, vec2(-4.0, 0.0)) + light_mask_b( uv, vec2(0.0, 4.0)) + light_mask_b( uv, vec2(0.0, -4.0))) * 0.06;
	halo += (light_mask_b( uv, vec2(3.0, 3.0)) + light_mask_b( uv, vec2(-3.0, 3.0)) + light_mask_b( uv, vec2(3.0, -3.0)) + light_mask_b( uv, vec2(-3.0, -3.0))) * 0.04;
	// The darkest original pixels remain dark, including the black pupils.
	float preserve_dark = smoothstep(0.035, 0.08, max(color.r, max(color.g, color.b)));
	color.rgb = min(color.rgb + vec3(eye_brightness * center + glow_strength * halo * preserve_dark), vec3(0.95));
	return color;
}

void fragment() {
	vec4 a = illuminate_a(TEXTURE, UV);
	vec4 b = illuminate_b(UV);
	float alpha = mix(a.a, b.a, frame_blend);
	vec3 premultiplied = mix(a.rgb * a.a, b.rgb * b.a, frame_blend);
	COLOR = vec4(alpha > 0.0 ? premultiplied / alpha : vec3(0.0), alpha) * vertex_tint;
}
