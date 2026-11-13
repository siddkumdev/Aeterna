shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_always, shadows_disabled;

// God-hand skin (docs/VFX_NOTES.md X-GH1): soft translucent ember-gold, a bright rim where the hand turns away from
// the eye, and a slow shimmer drifting over the surface. Palette only: fire_red edge, lantern_glow body,
// fire_yellow core. Never blue. Cheap on purpose (Quest): one fresnel, one value-noise lookup, no textures.

uniform vec4 core_color : source_color = vec4(1.0, 0.831, 0.353, 1.0);   // palette fire_yellow  FFD45A
uniform vec4 body_color : source_color = vec4(0.965, 0.643, 0.365, 1.0); // palette lantern_glow F6A45D
uniform vec4 edge_color : source_color = vec4(0.910, 0.271, 0.173, 1.0); // palette fire_red     E8452C
uniform float rim_power : hint_range(0.5, 6.0) = 1.7;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.97;  // solid inside, so the joint balls and tubes do not show through each other
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.18;  // the see-through, glowing edge
uniform float shimmer_speed = 0.35;
uniform float shimmer_amount : hint_range(0.0, 1.0) = 0.3;
uniform float pinch : hint_range(0.0, 1.0) = 0.0;  // 0 open hand .. 1 pinching: the whole hand glows hotter

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
	// slow drifting shimmer, in world space so it flows across the fingers instead of sticking to each bone
	float n = vnoise(world_pos * 38.0 + vec3(0.0, -TIME * shimmer_speed * 4.0, TIME * shimmer_speed));
	float glow = 1.0 + (n - 0.5) * 2.0 * shimmer_amount;
	vec3 inner = mix(body_color.rgb, core_color.rgb, clamp(pinch * 0.8 + n * 0.25, 0.0, 1.0));
	// body gold -> deep ember red toward the silhouette, which also fades out: a hand of warm light, not a glove
	vec3 col = mix(inner, edge_color.rgb, smoothstep(0.15, 0.95, fres)) * glow * (1.0 + pinch * 0.35);
	col *= 0.8 + 0.3 * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);  // a little top-light so the fingers read as round, not flat
	ALBEDO = clamp(col, vec3(0.0), vec3(0.95));
	ALPHA = clamp(mix(base_alpha, rim_alpha, smoothstep(0.6, 1.0, fres)) * (0.95 + n * 0.1), 0.0, 1.0);
}
