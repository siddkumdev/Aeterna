shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// A falling piece of the Veil: a sliver of its light (the user, 2026-11-14: "more like light"), a hot gold core that
// cools to orange and fades out as it falls (magic is black / orange / red). COLOR comes from the particle ramp.
uniform float energy = 1.3;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	// molten light: hot gold at the rim, deep orange-red in the body, never white
	vec3 hot = mix(vec3(0.9, 0.22, 0.04), vec3(1.0, 0.62, 0.18), rim) * mix(vec3(1.0), COLOR.rgb, 0.3);
	ALBEDO = hot * energy * COLOR.a * (0.5 + 0.5 * rim);
}
