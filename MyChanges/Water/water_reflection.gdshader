// MyChanges: a soft, calm mirror image of what is above the water (trees, ground,
// fog). It sways very gently, is tinted blue, and gets blurrier and fainter
// the deeper it goes. No stripes: the water's own animation stays the star.
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tint : source_color = vec3(0.62, 0.72, 0.88);
// How far (in screen widths) the reflection sways sideways.
uniform float sway = 0.0025;
uniform float blur = 2.5;

void fragment() {
	// Screen distance below the water surface (the top edge of this rectangle).
	float per_uv = dFdy(SCREEN_UV.y) / dFdy(UV.y);
	float depth = UV.y * per_uv;
	float surface = SCREEN_UV.y - depth;
	float d = abs(depth);

	// One slow, wide wave: gentle sway, no fine stripes.
	float wave = sin(SCREEN_UV.y * 40.0 - TIME * 0.8 + SCREEN_UV.x * 3.0);
	vec2 source = vec2(SCREEN_UV.x + wave * sway * (0.5 + d * 6.0), surface - depth);
	vec3 reflection = textureLod(screen_tex, source, blur + d * 10.0).rgb;

	float fade = (1.0 - smoothstep(0.0, 1.0, UV.y)) * smoothstep(0.0, 0.03, UV.y);
	float inside = step(0.0, source.y) * step(source.y, 1.0);
	COLOR = vec4(reflection * tint, strength * fade * inside);
}
