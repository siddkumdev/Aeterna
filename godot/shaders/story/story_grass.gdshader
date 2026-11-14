shader_type spatial;
render_mode cull_disabled;
// Meadow grass, one clump of blades per instance (StoryWorld._grass). UV.y = height up the blade (0 root, 1 tip).
// INSTANCE_CUSTOM: r = colour shift, g = dryness, b = wind phase. The wind is gusts rolling across the meadow.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform vec3 root_col : source_color = vec3(0.07, 0.11, 0.03);
uniform vec3 tip_a : source_color = vec3(0.40, 0.50, 0.16);
uniform vec3 tip_b : source_color = vec3(0.62, 0.58, 0.26);
uniform float wind = 1.0;
uniform float clock = 0.0;
uniform float scorch = 0.0;
uniform vec2 village = vec2(0.0, -17.0);

varying float up;
varying vec3 tint;
varying float burnt;

void vertex() {
	up = UV.y;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = fbm2(w.xz * 0.08 - vec2(clock * 0.35, clock * 0.12), 2);
	float sway = (sin(clock * 1.7 + INSTANCE_CUSTOM.b * 6.28 + w.x * 0.4) * 0.25 + gust * 1.2) * wind;
	float bend = up * up;
	vec3 dir_ws = vec3(0.8, 0.0, 0.35) * sway * bend * 0.22;
	VERTEX += transpose(mat3(MODEL_MATRIX)) * dir_ws / max(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), 0.0001);
	VERTEX.y -= bend * abs(sway) * 0.05;
	tint = mix(tip_a, tip_b, INSTANCE_CUSTOM.g) * (0.8 + 0.4 * INSTANCE_CUSTOM.r) * (0.85 + 0.3 * gust);
	burnt = scorch * smoothstep(30.0, 6.0, length(w.xz - village));
}

void fragment() {
	vec3 col = mix(root_col, tint, smoothstep(0.0, 0.85, up));
	col = mix(col, col * vec3(0.18, 0.14, 0.1), burnt);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	SPECULAR = 0.35;
	BACKLIGHT = col * 0.6;  // sun through the blades
	AO = mix(0.35, 1.0, up);
	AO_LIGHT_AFFECT = 0.6;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
