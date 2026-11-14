shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The game's own village models in the story, lit like the rest of the valley instead of the board's toon look:
// the same palette colours (atlas, nearest), with weathering in world space so a big wall is not one flat swatch:
// patchy tone, grime toward the ground, a little sheen on top faces. No fine noise (it would shimmer in VR).
#include "res://shaders/story/story_noise.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest;
uniform float scorch = 0.0;

varying vec3 wp;
varying vec3 wn;
varying float hy;  // height above the model's base, m

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hy = wp.y - MODEL_MATRIX[3].y;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = texture(atlas, UV).rgb;
	float n = fbm3(wp * 0.9, 3);
	float m = fbm3(wp * 3.5 + 7.0, 2);
	col *= 0.86 + 0.24 * n + 0.08 * m;  // weathered, uneven paint and wood
	col = mix(col * vec3(0.62, 0.56, 0.5), col, smoothstep(0.0, 1.1, hy + 0.3 * n));  // damp, dirty low down
	col *= 1.0 - scorch * 0.6;
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.6, smoothstep(0.6, 0.95, wn.y)) - 0.1 * m;
	SPECULAR = 0.35;
	AO = 0.75 + 0.25 * n;
	AO_LIGHT_AFFECT = 0.4;
}
