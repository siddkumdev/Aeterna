shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, blend_mix;
// The soft dark band behind a caption (rounded, feathered edges), always over the world.
uniform float alpha = 0.0;
uniform vec2 size = vec2(1.0, 0.2);

void fragment() {
	vec2 p = (UV - 0.5) * size;
	vec2 h = size * 0.5 - vec2(0.06);
	float d = length(max(abs(p) - h, 0.0));
	ALBEDO = vec3(0.02, 0.015, 0.02);
	ALPHA = alpha * 0.62 * smoothstep(0.06, 0.0, d);
}
