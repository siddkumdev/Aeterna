shader_type spatial;
render_mode cull_back;
// The island's ground in the story: meadow soil and short turf, a trodden path to the village, the village square,
// rock where it gets steep, the cliff at the island's edge. Heights are baked into the mesh (StoryWorld.height).
#include "res://shaders/story/story_noise.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.20, 0.30, 0.09);
uniform vec3 grass_b : source_color = vec3(0.34, 0.40, 0.14);
uniform vec3 soil : source_color = vec3(0.26, 0.19, 0.12);
uniform vec3 rock : source_color = vec3(0.36, 0.33, 0.30);
uniform vec2 village = vec2(0.0, -17.0);
uniform float scorch = 0.0;  // the fall: the ground darkens and smoulders around the village

varying vec3 wp;

void vertex() {
	wp = VERTEX;
}

float path_d(vec2 p) {
	vec2 a = vec2(0.0, 1.5);
	vec2 b = village + vec2(0.0, 5.0);
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	float wob = sin(p.y * 0.35) * 0.8;
	return length(p - (a + ab * t) - vec2(wob, 0.0));
}

void fragment() {
	vec2 p = wp.xz;
	float big = fbm2(p * 0.06, 4);
	float mid = fbm2(p * 0.7, 3);
	float fine = vnoise2(p * 9.0);
	vec3 g = mix(grass_a, grass_b, smoothstep(0.3, 0.7, big));
	g *= 0.75 + 0.45 * mid;
	g = mix(g, g * vec3(1.15, 1.05, 0.7), smoothstep(0.55, 0.8, fbm2(p * 0.2 + 7.0, 3)));  // sun-dried patches
	float pd = path_d(p) - 0.9 - 0.4 * mid;
	float sq = length(p - village) - 6.5 - 1.2 * mid;
	float dirt = 1.0 - smoothstep(0.0, 0.8, min(pd, sq));
	vec3 earth = soil * (0.7 + 0.5 * mid) * (0.85 + 0.3 * fine);
	vec3 pebble = voronoi2(p * 7.0);
	earth = mix(earth, rock * (0.7 + 0.6 * pebble.z), smoothstep(0.32, 0.18, pebble.x) * 0.55 * dirt);
	float slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	vec3 n_ws = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float steep = smoothstep(0.25, 0.45, 1.0 - n_ws.y);
	vec3 stone = rock * (0.6 + 0.6 * fbm3(wp * 0.8, 4)) * (0.85 + 0.3 * fine);
	vec3 col = mix(g, earth, dirt);
	col = mix(col, stone, steep);
	col = mix(col, col * vec3(0.25, 0.2, 0.18), scorch * smoothstep(30.0, 6.0, length(p - village)) * (0.6 + 0.4 * mid));
	float edge = smoothstep(108.0, 112.0, length(p));
	col = mix(col, stone * 0.8, edge);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.8, dirt) + 0.06 * fine;
	SPECULAR = 0.3;
	// fine relief: a normal from the noise's slope
	float e = 0.05;
	float hx = vnoise2((p + vec2(e, 0.0)) * 3.0) - vnoise2((p - vec2(e, 0.0)) * 3.0);
	float hz = vnoise2((p + vec2(0.0, e)) * 3.0) - vnoise2((p - vec2(0.0, e)) * 3.0);
	NORMAL_MAP = normalize(vec3(-hx * 1.6, -hz * 1.6, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	AO = 0.75 + 0.25 * mid;
	AO_LIGHT_AFFECT = 0.4;
}
