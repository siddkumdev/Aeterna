shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Hurt look (Siddharth 2026-11-16): below half HP an enemy is tinted darker and ink-coloured cracks run over its body.
// Used as the rig's material overlay; model-space position, so the cracks stay on the body as it moves. Palette ink only.

uniform vec3 ink : source_color = vec3(0.118, 0.102, 0.133);
uniform float tint = 0.3;     // how much the body darkens
uniform float freq = 80.0;    // crack lines per metre (set from the model's height)
varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float crack(vec3 p, vec3 axis, float warp) {
	float a = dot(p, axis) * freq + sin(p.y * freq * 1.7 + p.z * freq) * warp + sin(p.x * freq * 2.3) * warp * 0.6;
	return 1.0 - smoothstep(0.0, 0.07, abs(fract(a) - 0.5));
}

void fragment() {
	float c = crack(lp, normalize(vec3(1.0, 0.6, 0.3)), 0.8) + crack(lp, normalize(vec3(-0.4, 1.0, 0.8)), 0.6);
	float cell = hash(floor(lp * freq * 0.35));  // only some stretches are cracked
	c = clamp(c, 0.0, 1.0) * step(0.45, cell);
	ALBEDO = ink;
	ALPHA = clamp(tint + c * 0.85, 0.0, 0.95);
}
