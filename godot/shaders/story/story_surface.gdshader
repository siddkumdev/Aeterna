shader_type spatial;
render_mode cull_back;
// Every solid thing in the story with one shader, so a whole village bakes into one mesh (one draw). UV2.x = the
// material kind, COLOR.rgb = tint (with baked occlusion). All detail is computed in object space, no textures:
//  0 plaster  1 stone  2 timber/bark  3 thatch  4 cloth  5 skin  6 hair  7 brass  8 pine needles  9 leaves
// 10 ember glow (eyes)  11 lit window  12 rock  13 iron/dark metal
#include "res://shaders/story/story_noise.gdshaderinc"

uniform float window_glow = 1.0;
uniform float ember_glow = 1.0;
uniform float wind = 1.0;
uniform float clock = 0.0;
uniform float scorch = 0.0;

varying vec3 lp;
varying vec3 ln;
varying float kind;

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	kind = floor(UV2.x + 0.5);
	if (kind == 8.0 || kind == 9.0) {  // boughs and leaves move with the wind, more at the top
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float s = sin(clock * 1.1 + w.x * 0.2 + w.z * 0.15) * 0.5 + sin(clock * 2.7 + w.y) * 0.15;
		VERTEX.x += s * wind * 0.03 * max(VERTEX.y, 0.0) * 0.4;
	}
}

vec2 proj(vec3 p, vec3 n) {
	vec3 a = abs(n);
	return a.y > a.x && a.y > a.z ? p.xz : (a.x > a.z ? p.zy : p.xy);
}

// How much of a detail at `freq` cycles per metre survives at this pixel: 1 when it spans several pixels, 0 when it
// would alias. Fine noise fades to its average with distance instead of shimmering.
float keep(float freq, float px) {
	return 1.0 - smoothstep(0.25, 0.6, px * freq);
}

void fragment() {
	float px = length(fwidth(lp));
	vec3 tint = COLOR.rgb;
	vec3 col = tint;
	float rough = 0.85;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	vec3 back = vec3(0.0);
	float ao = 1.0;
	vec2 q = proj(lp, ln);
	if (kind == 0.0) {  // lime plaster: patchy, damp and grimy near the ground
		float n = fbm3(lp * 2.5, 4);
		col = tint * (0.82 + 0.3 * n) * (0.94 + 0.06 * mix(0.5, vnoise3(lp * 40.0), keep(40.0, px)));
		col *= mix(0.6, 1.0, smoothstep(0.0, 0.9, lp.y + 0.3 * n));
		rough = 0.95;
	} else if (kind == 1.0) {  // dressed stone with mortar, moss in the cracks and on top
		vec3 v = voronoi2(q * vec2(3.2, 4.4));
		float mortar = mix(0.8, smoothstep(0.02, 0.09, v.y), keep(30.0, px));
		col = tint * (0.7 + 0.5 * v.z) * (0.8 + 0.35 * fbm3(lp * 6.0, 3));
		col = mix(tint * 0.3, col, mortar);
		float moss = smoothstep(0.55, 0.75, fbm3(lp * 1.7 + 4.0, 3)) * clamp(ln.y + 0.4, 0.0, 1.0);
		col = mix(col, vec3(0.18, 0.24, 0.08) * (0.7 + 0.5 * mix(0.5, vnoise3(lp * 30.0), keep(30.0, px))), moss);
		ao = mix(0.45, 1.0, mortar);
		rough = 0.9;
	} else if (kind == 2.0) {  // wood: grain running along the beam, checks and knots
		vec3 a = abs(ln);
		vec2 g = a.y > 0.5 ? lp.xz : vec2(lp.x + lp.z, lp.y);
		float grain = fbm2(vec2(g.x * 26.0, g.y * 1.5), 3);
		float rings = mix(0.5, sin(grain * 24.0) * 0.5 + 0.5, keep(120.0, px));
		col = tint * (0.6 + 0.35 * rings + 0.25 * vnoise3(lp * 3.0));
		col *= mix(0.55, 1.0, mix(0.9, smoothstep(0.02, 0.06, fract(grain * 7.0)), keep(90.0, px)));
		rough = 0.8;
	} else if (kind == 3.0) {  // thatch: straw bundles laid in courses, dark between, greyed by weather
		float course = mix(0.6, fract(lp.y * 7.0 + fbm3(lp * 3.0, 2) * 0.6), keep(20.0, px));
		float straw = mix(0.5, vnoise2(vec2((lp.x + lp.z) * 70.0, lp.y * 6.0)), keep(70.0, px));
		col = tint * (0.55 + 0.6 * straw) * mix(0.45, 1.0, smoothstep(0.0, 0.35, course));
		col = mix(col, vec3(0.32, 0.31, 0.27), smoothstep(0.45, 0.8, fbm3(lp * 1.3, 3)) * 0.6);
		ao = mix(0.5, 1.0, course);
		rough = 1.0;
	} else if (kind == 4.0) {  // woven wool and linen
		// soft folds and wear, no fine weave (it shimmered into stripes at a distance)
		float folds = fbm3(vec3(lp.x * 6.0, lp.y * 2.5, lp.z * 6.0), 3);
		col = tint * (0.9 + 0.12 * folds);  // low contrast, so no contour rings
		rough = 0.95;
		back = col * 0.15;
	} else if (kind == 5.0) {  // skin: warm, blotchy, light passes through the edges
		float b = fbm3(lp * 30.0, 3);
		col = tint * (0.95 + 0.06 * b);  // even skin: a faint grain, no blotches
		col = mix(col, col * vec3(1.05, 0.92, 0.9), smoothstep(0.45, 0.7, fbm3(lp * 6.0, 2)) * 0.25);
		rough = 0.6;
		back = tint * vec3(0.35, 0.16, 0.12) * 0.35;  // a little warm light through the ears and fingers
	} else if (kind == 6.0) {  // hair
		float s = mix(0.5, vnoise2(vec2((lp.x + lp.z) * 140.0, lp.y * 8.0)), keep(140.0, px));
		col = tint * (0.6 + 0.6 * s);
		rough = 0.5;
	} else if (kind == 7.0) {  // brass: polished where held, tarnished in the hollows
		float t = fbm3(lp * 5.0, 3);
		col = mix(tint, tint * vec3(0.45, 0.5, 0.35), smoothstep(0.55, 0.8, t));
		metal = 1.0;
		rough = 0.25 + 0.35 * t;
	} else if (kind == 8.0) {  // pine needles: dark, speckled with lighter new growth
		float n = mix(0.5, vnoise3(lp * 22.0), keep(22.0, px));
		col = tint * (0.55 + 0.7 * n) * (0.8 + 0.3 * fbm3(lp * 2.0, 2));
		rough = 0.9;
		back = col * 0.35;
		ao = 0.7 + 0.3 * n;
	} else if (kind == 9.0) {  // broadleaf canopy: clustered leaves
		vec3 v = voronoi2(q * 9.0);
		col = tint * (0.55 + 0.6 * v.z) * mix(0.5, 1.0, smoothstep(0.0, 0.25, v.x));
		rough = 0.75;
		back = col * 0.5;
	} else if (kind == 10.0) {  // ember glow (eyes, coals)
		col = tint * 0.2;
		emit = tint * 6.0 * ember_glow * (0.8 + 0.2 * sin(clock * 9.0 + lp.x * 30.0));
	} else if (kind == 11.0) {  // a lit window: warm glass with lead mullions and a flickering lamp inside
		vec2 u = fract(UV * vec2(2.0, 3.0));
		float bar = smoothstep(0.0, 0.06, min(min(u.x, 1.0 - u.x), min(u.y, 1.0 - u.y)));
		float flick = 0.85 + 0.15 * sin(clock * 7.0 + lp.x * 13.0) * sin(clock * 3.1 + lp.z * 7.0);
		col = vec3(0.05);
		emit = tint * 3.2 * window_glow * flick * bar * (0.7 + 0.3 * (1.0 - UV.y));
		rough = 0.2;
	} else if (kind == 12.0) {  // boulders: weathered, lichen and moss on the top
		float n = fbm3(lp * 1.8, 4);
		col = tint * (0.55 + 0.7 * n) * (0.85 + 0.25 * mix(0.5, vnoise3(lp * 25.0), keep(25.0, px)));
		float lich = smoothstep(0.62, 0.66, vnoise3(lp * 7.0));
		col = mix(col, vec3(0.62, 0.6, 0.45), lich * 0.6);
		col = mix(col, vec3(0.16, 0.22, 0.07), smoothstep(0.35, 0.8, ln.y) * smoothstep(0.45, 0.65, n));
		rough = 0.92;
		ao = 0.7 + 0.3 * n;
	} else if (kind == 13.0) {  // forged iron
		col = tint * (0.7 + 0.4 * fbm3(lp * 12.0, 3));
		metal = 0.8;
		rough = 0.6;
	} else if (kind == 14.0) {  // bone: pitted, yellowed and dirty in the hollows
		float n = fbm3(lp * 30.0, 3);
		col = tint * (0.78 + 0.3 * n);
		col = mix(col, col * vec3(0.7, 0.62, 0.48), smoothstep(0.55, 0.3, n));
		rough = 0.55;
		ao = 0.75 + 0.25 * n;
	} else if (kind == 15.0) {  // ink hide: near-black, a faint oily sheen and dull ember veins
		float n = fbm3(lp * 9.0 + vec3(0.0, clock * 0.15, 0.0), 3);
		col = tint * (0.8 + 0.4 * n);
		emit += vec3(1.0, 0.3, 0.06) * smoothstep(0.62, 0.7, n) * 0.6;
		rough = 0.35;
	}
	col *= 1.0 - scorch * 0.6 * float(kind < 4.0);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emit;
	BACKLIGHT = back;
	AO = ao;
	AO_LIGHT_AFFECT = 0.5;
}
