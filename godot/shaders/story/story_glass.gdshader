shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
// The hourglass's blown glass: nearly clear, bright fresnel edges, a faint warm inner glow while time turns.
uniform vec3 tint : source_color = vec3(0.92, 0.88, 0.8);
uniform float glow = 0.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = tint * 0.15;
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = vec3(1.0, 0.75, 0.35) * glow * (0.3 + f);
	ALPHA = clamp(0.08 + f * 0.8, 0.0, 1.0);
}
