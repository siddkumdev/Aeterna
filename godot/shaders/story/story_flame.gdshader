shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Fire, sparks and glowing shards as camera-facing particles (GPUParticles3D draw pass). The particle's colour
// (process material colour ramp) tints it; INSTANCE_CUSTOM.y = its age 0..1. mode 0 = a licking flame tongue,
// 1 = a round spark or mote, 2 = a sharp turning shard of the broken Veil.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform int mode = 0;
uniform float energy = 3.0;
uniform float clock = 0.0;

varying float age;
varying float seed;
varying vec4 tint;

void vertex() {
	age = INSTANCE_CUSTOM.y;
	seed = fract(INSTANCE_CUSTOM.x * 0.123 + float(INSTANCE_ID) * 0.618);
	tint = COLOR;
	{
		float sx = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sx, INV_VIEW_MATRIX[2] * sx, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float a = 0.0;
	if (mode == 0) {
		float n = fbm2(vec2(uv.x * 2.0 + seed * 9.0, uv.y * 1.5 + clock * 3.5), 3);
		float shape = 1.0 - length(vec2(uv.x * (1.6 + uv.y * 0.9), (uv.y + 0.3) * 0.85));
		a = smoothstep(0.0, 0.5, shape + (n - 0.5) * 0.9);
		float core = smoothstep(0.25, 0.9, shape + n * 0.3);
		vec3 hot = mix(tint.rgb, vec3(1.0, 0.93, 0.7), core);
		ALBEDO = hot * energy * a * (1.0 - age) * tint.a;
	} else if (mode == 1) {
		a = smoothstep(1.0, 0.0, length(uv));
		a = a * a;
		ALBEDO = tint.rgb * energy * a * tint.a * (0.7 + 0.3 * sin(clock * 20.0 + seed * 40.0));
	} else {
		float an = seed * 6.28 + clock * (seed - 0.5) * 3.0;
		vec2 r = mat2(vec2(cos(an), sin(an)), vec2(-sin(an), cos(an))) * uv;
		float edge = 1.0 - (abs(r.x) * 1.8 + abs(r.y));
		if (edge < 0.0) discard;
		ALBEDO = tint.rgb * energy * (0.4 + 0.6 * smoothstep(0.3, 0.0, edge)) * tint.a * (1.0 - age * 0.8);
	}
}
