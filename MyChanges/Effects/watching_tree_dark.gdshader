// MyChanges: copy of Assets/Objects/WatchingTree/tree_blend.gdshader (by the team) with two changes:
//  1. body_tint darkens the tree so it sits in the night forest like the other trees,
//     while the eyes keep their full glow.
//  2. No "TEXTURE passed to a function" (that printed an error in the console).
// Used automatically by MyChanges/Effects/teammate_art.gd; the original file is not touched.
shader_type canvas_item;

uniform sampler2D next_frame : source_color, filter_linear;
uniform float frame_blend : hint_range(0.0, 1.0) = 0.0;
uniform float eye_brightness : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float glow_strength : hint_range(0.0, 1.5, 0.01) = 0.65;
// Colour multiplied onto the tree (not onto the eyes).
uniform vec3 body_tint : source_color = vec3(0.5, 0.55, 0.68);
// How much the tree fades into the night mist (like the trees behind it).
uniform vec4 mist_color : source_color = vec4(0.16, 0.19, 0.25, 1.0);
uniform float mist : hint_range(0.0, 1.0) = 0.12;

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

float eye_light(vec4 s, vec2 pos) {
	if (!near_eye(pos, 0.0)) { return 0.0; }
	return smoothstep(0.10, 0.35, min(s.r, min(s.g, s.b))) * s.a;
}

// Darkens the tree, keeps the eyes, adds the eye glow. `center`/`halo` come from eye_light.
vec4 shade(vec4 color, float center, float halo) {
	float preserve_dark = smoothstep(0.035, 0.08, max(color.r, max(color.g, color.b)));
	vec3 body = mix(color.rgb * body_tint, mist_color.rgb, mist * color.a);
	color.rgb = mix(body, color.rgb, center);
	color.rgb = min(color.rgb + vec3(eye_brightness * center + glow_strength * halo * preserve_dark), vec3(0.95));
	return color;
}

void fragment() {
	// Same sample pattern as the original: centre, 4 at 2 px, 4 at 4 px, 4 diagonal at 3 px.
	vec2 offsets[13] = vec2[](
		vec2(0.0), vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(0.0, -2.0),
		vec2(4.0, 0.0), vec2(-4.0, 0.0), vec2(0.0, 4.0), vec2(0.0, -4.0),
		vec2(3.0, 3.0), vec2(-3.0, 3.0), vec2(3.0, -3.0), vec2(-3.0, -3.0));
	float weights[13] = float[](0.20, 0.10, 0.10, 0.10, 0.10, 0.06, 0.06, 0.06, 0.06, 0.04, 0.04, 0.04, 0.04);

	vec2 pos = UV / PIXEL_SIZE;
	vec4 a = texture(TEXTURE, UV);
	vec4 b = texture(next_frame, UV);
	float center_a = 0.0; float halo_a = 0.0;
	float center_b = 0.0; float halo_b = 0.0;
	if (near_eye(pos, 6.0)) {
		for (int i = 0; i < 13; i++) {
			vec2 p = pos + offsets[i];
			vec2 uv = UV + offsets[i] * PIXEL_SIZE;
			float la = eye_light(texture(TEXTURE, uv), p);
			float lb = eye_light(texture(next_frame, uv), p);
			halo_a += la * weights[i];
			halo_b += lb * weights[i];
			if (i == 0) { center_a = la; center_b = lb; }
		}
	}
	a = shade(a, center_a, halo_a);
	b = shade(b, center_b, halo_b);
	float alpha = mix(a.a, b.a, frame_blend);
	vec3 premultiplied = mix(a.rgb * a.a, b.rgb * b.a, frame_blend);
	COLOR = vec4(alpha > 0.0 ? premultiplied / alpha : vec3(0.0), alpha) * vertex_tint;
}
