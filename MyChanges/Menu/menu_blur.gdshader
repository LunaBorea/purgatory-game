// MyChanges: the game behind the menu, softly blurred and a little darker.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// 0 = no effect, 1 = full effect (animated when the menu opens / closes).
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur : hint_range(0.0, 5.0) = 2.6;
uniform float darkness : hint_range(0.0, 1.0) = 0.42;
uniform vec4 shade : source_color = vec4(0.015, 0.02, 0.035, 1.0);

void fragment() {
	float lod = blur * amount;
	vec2 step_size = SCREEN_PIXEL_SIZE * exp2(lod) * 0.85;
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float w = exp(-float(x * x + y * y) / 4.5);
			sum += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * step_size, lod).rgb * w;
			total += w;
		}
	}
	vec3 c = sum / total;
	c = mix(c, shade.rgb, darkness * amount);
	// Darker towards the edges, so the eye goes to the menu.
	vec2 d = (UV - 0.5) * vec2(1.5, 1.0);
	c *= 1.0 - smoothstep(0.3, 0.9, length(d)) * 0.45 * amount;
	COLOR = vec4(c, 1.0);
}
