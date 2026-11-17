shader_type spatial;
render_mode cull_back;
// The island's ground in the story: meadow soil and short turf, a trodden path to the village, the village square,
// rock where it gets steep, the cliff at the island's edge. Heights are baked into the mesh (StoryWorld.height).
// Quest cost (sykeriin, 2026-11-17: the ground alone cost 24 ms a frame): the broad patterns are worked out per
// vertex (the mesh is dense near the player), only the fine grain and relief stay per pixel.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform vec3 grass_a : source_color = vec3(0.20, 0.30, 0.09);
uniform vec3 grass_b : source_color = vec3(0.34, 0.40, 0.14);
uniform vec3 soil : source_color = vec3(0.26, 0.19, 0.12);
uniform vec3 rock : source_color = vec3(0.36, 0.33, 0.30);
uniform vec2 village = vec2(0.0, -17.0);
uniform float scorch = 0.0;  // the fall: the ground darkens and smoulders around the village

varying vec3 wp;
varying vec3 v_grass;
varying vec3 v_stone;
varying float v_mid;
varying float v_steep;
varying float v_burn;
varying float v_edge;

float path_d(vec2 p) {
	vec2 a = vec2(0.0, 1.5);
	vec2 b = village + vec2(0.0, 5.0);
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0);
	float wob = sin(p.y * 0.35) * 0.8;
	return length(p - (a + ab * t) - vec2(wob, 0.0));
}

void vertex() {
	wp = VERTEX;
	vec2 p = wp.xz;
	float big = fbm2(p * 0.06, 3);
	float mid = fbm2(p * 0.7, 2);
	vec3 g = mix(grass_a, grass_b, smoothstep(0.3, 0.7, big));
	g *= 0.75 + 0.45 * mid;
	g = mix(g, g * vec3(1.15, 1.05, 0.7), smoothstep(0.55, 0.8, fbm2(p * 0.2 + 7.0, 2)));  // sun-dried patches
	v_grass = g;
	v_mid = mid;
	v_steep = smoothstep(0.25, 0.45, 1.0 - NORMAL.y);  // the mesh is in world space (no transform)
	v_stone = rock * (0.6 + 0.6 * fbm2(p * 0.8 + wp.y * 0.3, 3));
	v_burn = smoothstep(30.0, 6.0, length(p - village)) * (0.6 + 0.4 * mid);
	v_edge = smoothstep(108.0, 112.0, length(p));
}

void fragment() {
	vec2 p = wp.xz;
	float fine = vnoise2(p * 9.0);
	float pd = path_d(p) - 0.9 - 0.4 * v_mid;  // per pixel: the path's edge is sharper than the mesh
	float sq = length(p - village) - 6.5 - 1.2 * v_mid;
	float v_dirt = 1.0 - smoothstep(0.0, 0.8, min(pd, sq));
	vec3 earth = soil * (0.7 + 0.5 * v_mid) * (0.85 + 0.3 * fine);
	vec3 stone = v_stone * (0.85 + 0.3 * fine);
	vec3 col = mix(v_grass * (0.9 + 0.2 * fine), earth, v_dirt);
	col = mix(col, stone, v_steep);
	col = mix(col, col * vec3(0.25, 0.2, 0.18), scorch * v_burn);
	col = mix(col, stone * 0.8, v_edge);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.8, v_dirt) + 0.06 * fine;
	SPECULAR = 0.3;
	// fine relief from one extra pair of lookups (forward differences against `n0`)
	float n0 = vnoise2(p * 3.0);
	float hx = vnoise2((p + vec2(0.05, 0.0)) * 3.0) - n0;
	float hz = vnoise2((p + vec2(0.0, 0.05)) * 3.0) - n0;
	NORMAL_MAP = normalize(vec3(-hx * 3.2, -hz * 3.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	AO = 0.75 + 0.25 * v_mid;
	AO_LIGHT_AFFECT = 0.4;
}
