shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Smoke: chimney smoke, the fall's smoke columns and the dark that pours off Skotos. billboard = camera-facing particle
// (INSTANCE_CUSTOM.y = age); otherwise a mesh (Skotos's body) whose edges dissolve into rolling smoke with a rim of
// Warden purple.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform bool billboard = true;
uniform vec3 smoke_col : source_color = vec3(0.35, 0.33, 0.32);
uniform vec3 rim_col : source_color = vec3(0.54, 0.36, 0.78);
uniform float rim = 0.0;
uniform float density = 0.6;
uniform float clock = 0.0;
uniform float lit = 1.0;

varying float age;
varying vec3 lp;
varying float seed;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = fract(float(INSTANCE_ID) * 0.618);
	lp = VERTEX;
	if (billboard) {
		float sx = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sx, INV_VIEW_MATRIX[2] * sx, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	} else {
		float n = fbm3(VERTEX * 0.35 + vec3(0.0, -clock * 0.4, 0.0), 3);
		VERTEX += NORMAL * (n - 0.5) * 1.6;
	}
}

void fragment() {
	float a;
	vec3 c = smoke_col * COLOR.rgb;
	if (billboard) {
		vec2 uv = UV * 2.0 - 1.0;
		float n = fbm2(uv * 1.8 + vec2(seed * 7.0, clock * 0.25 + seed), 4);
		a = smoothstep(1.0, 0.2, length(uv) + (0.5 - n) * 0.7);
		a *= smoothstep(0.0, 0.15, age) * (1.0 - age) * density * COLOR.a;
		c *= 0.7 + 0.5 * n;
	} else {
		float n = fbm3(lp * 0.5 + vec3(0.0, -clock * 0.6, clock * 0.1), 4);
		float f = 1.0 - abs(dot(NORMAL, VIEW));
		a = density * smoothstep(0.15, 0.55, n + 0.25 - f * 0.4);
		c *= 0.4 + 0.6 * n;
		EMISSION = rim_col * pow(f, 2.5) * rim * 2.5 * (0.5 + n);
	}
	ALBEDO = c * lit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = clamp(a, 0.0, 1.0);
}
