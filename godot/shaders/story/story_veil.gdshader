shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// The Veil over the village, seen from inside: threads of warm light woven from the villagers' faith, flowing up the
// dome. crack = 0..1 red-hot cracks spreading from `crack_at` (object space); strength fades the whole dome.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform float strength = 1.0;
uniform float crack = 0.0;
uniform vec3 crack_at = vec3(0.0, 1.0, 0.0);
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.3);
uniform vec3 red : source_color = vec3(0.91, 0.27, 0.17);
uniform float clock = 0.0;

varying vec3 lp;

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	float lat = asin(clamp(lp.y, -1.0, 1.0));
	float lon = atan(lp.z, lp.x);
	float warp = fbm2(vec2(lon * 3.0, lat * 3.0 - clock * 0.15), 3);
	float t1 = pow(abs(sin(lon * 48.0 + warp * 4.0 + lat * 6.0)), 40.0);
	float t2 = pow(abs(sin(lon * 48.0 - warp * 4.0 - lat * 6.0 + 1.3)), 40.0);
	float rise = pow(abs(sin(lat * 30.0 - clock * 0.6 + warp * 3.0)), 30.0);
	float f = 1.0 - abs(dot(NORMAL, VIEW));
	float body = (t1 + t2) * 0.35 + rise * 0.25 + pow(f, 3.0) * 0.6 + 0.04;
	body *= 0.6 + 0.6 * fbm2(vec2(lon * 6.0, lat * 6.0 + clock * 0.3), 3);
	// soft from inside: you stand under it, it must read as a glow in the air, not a cage
	vec3 c = gold * body * 0.32 * strength * smoothstep(-0.05, 0.12, lp.y);
	if (crack > 0.0) {
		float d = acos(clamp(dot(lp, normalize(crack_at)), -1.0, 1.0));
		vec3 v = voronoi2(vec2(lon, lat) * 7.0 + warp);
		float line = smoothstep(0.025, 0.0, v.y) * smoothstep(crack * 3.2, crack * 3.2 - 0.4, d);
		c += red * line * 1.6 * strength;
		c = mix(c, c * vec3(1.0, 0.5, 0.4), crack * 0.5);
	}
	ALBEDO = c;
}
