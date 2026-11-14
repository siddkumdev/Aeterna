shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque;
// A falling piece of the Veil: dark smoked glass that catches the sun as it tumbles, with a molten orange edge
// (magic is black / orange / red). COLOR comes from the particle's colour ramp (fades to alpha 0 at the end).
uniform float energy = 2.2;

void fragment() {
	float facing = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - facing, 2.5);
	ALBEDO = vec3(0.04, 0.015, 0.012);
	METALLIC = 0.85;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	EMISSION = COLOR.rgb * energy * (0.12 + 0.88 * rim);
	ALPHA = COLOR.a * (0.75 + 0.25 * rim);
}
