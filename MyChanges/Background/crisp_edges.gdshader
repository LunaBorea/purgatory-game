// MyChanges: tightens soft painted edges so silhouettes look sharp on screen
// (always about 1 screen pixel of smoothing, at any size).
// Can also repaint the silhouette in one colour (used for the far ground and lane grass).
shader_type canvas_item;

// Where the outline sits (0..1 of the picture's transparency). Lower keeps thin twigs.
uniform float threshold : hint_range(0.05, 0.95) = 0.4;
// 1 = fully crisp, 0 = the original picture.
uniform float sharpness : hint_range(0.0, 1.0) = 1.0;
// Width of the smooth edge in screen pixels.
uniform float edge_softness : hint_range(0.3, 3.0) = 1.0;
// Paint the whole silhouette in `color` instead of the picture's own colours.
uniform bool recolor = false;
uniform vec4 color : source_color = vec4(1.0);

// The node's own tint (modulate), without the picture's colour mixed in.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float w = max(fwidth(c.a) * edge_softness, 0.0005);
	float crisp = smoothstep(threshold - w, threshold + w, c.a);
	vec3 rgb = recolor ? color.rgb : c.rgb;
	COLOR = vec4(rgb, mix(c.a, crisp, sharpness)) * tint;
}
