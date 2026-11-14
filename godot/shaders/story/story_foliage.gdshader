shader_type spatial;
render_mode cull_disabled;
// Branch and leaf cards for the story's trees (StoryWorld.card). The silhouette is cut in the shader, no textures:
// UV.x = along the branch (0 at the stem end, 1 at the tip), UV.y = across (0..1), UV2.x = 0 needle spray, 1 leaf
// cluster. COLOR.rgb = tint, COLOR.a = depth into the crown (0 outside, 1 at the trunk) for shading.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform float clock = 0.0;
uniform float wind = 1.0;
uniform float scorch = 0.0;

varying float kind;
varying vec3 wp;

void vertex() {
	kind = floor(UV2.x + 0.5);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// branches bob from the tip, more high in the crown
	float s = sin(clock * 1.3 + wp.x * 0.25 + wp.z * 0.2) * 0.6 + sin(clock * 3.1 + wp.y * 0.8) * 0.2;
	VERTEX.y += s * wind * 0.05 * UV.x * UV.x;
	VERTEX.x += s * wind * 0.03 * UV.x;
}

void fragment() {
	vec2 uv = UV;
	float across = abs(uv.y - 0.5) * 2.0;  // 0 on the stem, 1 at the card edge
	float mask;
	vec3 col = COLOR.rgb;
	if (kind < 0.5) {
		// a fir spray: a stem, side twigs angled toward the tip, and needles along every twig
		float env = (1.0 - uv.x * 0.75) * (0.75 + 0.25 * vnoise2(vec2(uv.x * 6.0, floor(uv.y * 2.0) * 3.1)));
		float twig_t = uv.x * 9.0 - across * 1.4;
		float twig = abs(fract(twig_t) - 0.5);
		float needles = vnoise2(vec2(uv.x * 140.0, across * 30.0));
		float shape = step(across, env) * step(0.08, uv.x);
		float stem = step(across, 0.05 * (1.0 - uv.x));
		mask = max(stem, shape * step(twig, 0.1 + 0.32 * needles) * step(0.35, needles + 0.4 * (1.0 - across)));
		col *= 0.7 + 0.5 * needles;
		col = mix(col, col * vec3(1.15, 1.25, 0.95), smoothstep(0.65, 1.0, uv.x) * 0.6);  // pale new growth at the tips
	} else {
		// a leaf cluster: voronoi cells, each a pointed leaf
		vec3 v = voronoi2(uv * vec2(5.0, 5.0));
		float leaf = 1.0 - smoothstep(0.18, 0.42, v.x * (1.0 + 0.35 * sin(v.z * 30.0)));
		mask = leaf * step(length(uv - 0.5) * 2.0, 0.95);
		col *= 0.65 + 0.6 * v.z;
		col *= mix(0.7, 1.0, smoothstep(0.0, 0.3, v.x));
	}
	float depth = COLOR.a;
	col *= mix(1.0, 0.35, depth);  // inside the crown is dark
	col = mix(col, col * vec3(0.3, 0.22, 0.15), scorch);
	ALBEDO = col;
	ALPHA = mask;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.55;  // the low sun through the needles
	AO = mix(1.0, 0.45, depth);
	AO_LIGHT_AFFECT = 0.5;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
