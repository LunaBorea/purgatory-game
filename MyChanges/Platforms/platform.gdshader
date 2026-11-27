// MyChanges: colours a platform picture to fit its lane, and (for platforms standing
// in the water) makes the part under the water line faint, blue and see-through.
shader_type canvas_item;

// Colour grading so every platform matches its lane and the other platforms.
uniform vec3 tint : source_color = vec3(1.0);
uniform vec4 fog_color : source_color = vec4(0.3, 0.34, 0.42, 1.0);
uniform float fog : hint_range(0.0, 1.0) = 0.0;

// Soft moonlight on the walkable top of the lane you are standing on.
uniform float highlight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 highlight_color : source_color = vec3(0.82, 0.9, 1.0);
uniform float surface_y = 0.0;      // world y of the walkable top
uniform float highlight_depth = 14.0;

// Water.
uniform bool in_water = false;
uniform float water_y = 0.0;        // world y of the water line on this platform
uniform vec4 water_color : source_color = vec4(0.1, 0.14, 0.2, 1.0);
// How much of the platform you still see under the water (0 = nothing, 1 = all).
uniform float underwater_visibility : hint_range(0.0, 1.0) = 0.3;
uniform float underwater_fade = 45.0; // px: deeper parts fade out over this distance
uniform float wave_height = 1.2;
uniform float foam = 0.45;

varying vec2 world;
varying vec4 node_tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	node_tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = mix(c.rgb * tint, fog_color.rgb, fog);
	float a = c.a;

	float below_top = world.y - surface_y;
	float glow = highlight * (1.0 - smoothstep(0.0, highlight_depth, below_top)) * step(-6.0, below_top);
	rgb += highlight_color * glow * 0.3;

	if (in_water) {
		float wave = sin(world.x * 0.09 + TIME * 1.4) * wave_height
				+ sin(world.x * 0.031 - TIME * 0.9) * wave_height * 0.6;
		float depth = world.y - (water_y + wave);
		float under = smoothstep(-0.8, 1.2, depth);
		float deep = clamp(depth / underwater_fade, 0.0, 1.0);
		vec3 submerged = mix(rgb, water_color.rgb, 0.55 + 0.35 * deep);
		rgb = mix(rgb, submerged, under);
		a *= mix(1.0, underwater_visibility * (1.0 - 0.75 * deep), under);
		// A thin, soft light where the water touches the platform.
		float line = 1.0 - smoothstep(0.0, 1.6, abs(depth));
		rgb += vec3(0.7, 0.8, 0.95) * line * foam;
		a = max(a, c.a * line * 0.6);
	}
	COLOR = vec4(rgb, a) * node_tint;
}
