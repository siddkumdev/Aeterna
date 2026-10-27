shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Hand-painted toon fire (M2, Siddharth 2026-10-27): drawn like the moodboard's VFX section (#44, #31, #46): a
// flame shape in hard bands, a yellow core, orange body, red rim and dark ink cut-outs, all moving with scrolling noise.
// Three shapes on a flat quad:
//   mode 0  ORB     a swirling fire ball with flame tongues licking out (the Wizard's orb, the fireball head)
//   mode 1  PLUME   a flame rising from the bottom of the quad (uv.y 0 = base)
//   mode 2  COMET   a swept tail behind a head; uv.x 0 = tail tip, 1 = head; the quad lies along `axis` (world)
// Colours are palette: fire_yellow, lantern_glow, fire_red, ink. Magic is black / orange / red, never blue.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform int mode = 0;
uniform float energy : hint_range(0.0, 1.5) = 1.0;  // 0 = out, 1 = full
uniform float flow = 1.0;                            // how fast the fire moves
uniform float seed = 0.0;
uniform float alpha = 1.0;
uniform vec3 c_core : source_color = vec3(1.0, 0.831, 0.353);   // fire_yellow FFD45A
uniform vec3 c_hot : source_color = vec3(1.0, 0.965, 0.82);     // the white-hot centre (fire_yellow lightened)
uniform vec3 c_mid : source_color = vec3(0.965, 0.643, 0.365);  // lantern_glow F6A45D
uniform vec3 c_out : source_color = vec3(0.91, 0.271, 0.173);   // fire_red E8452C
uniform vec3 c_ink : source_color = vec3(0.067, 0.11, 0.188);   // ink 111C30
uniform vec3 axis = vec3(1.0, 0.0, 0.0);                        // comet direction, world space
uniform vec2 size = vec2(0.02, 0.02);                           // world size of the quad (along axis, across)
uniform float depth_bias = 0.004;                               // metres toward the camera, so a solid model never hides it

varying vec2 uv;

void vertex() {
	uv = vec2(UV.x, 1.0 - UV.y);  // uv.y = 0 at the bottom
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world;
	if (mode == 2) {
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 ax = normalize(axis);
		vec3 side = normalize(cross(ax, to_cam));
		world = centre + ax * (VERTEX.x - 0.38) * size.x + side * VERTEX.y * size.y;  // the head sits just ahead of the centre
	} else {
		world = centre + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	}
	world += normalize(CAMERA_POSITION_WORLD - centre) * depth_bias;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float nz(vec2 p) {
	return texture(noise, p).r;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float t = TIME * flow + seed;
	float v = 0.0;      // heat: higher is hotter
	float ink_cut = 0.0;
	if (mode == 0) {
		float r = length(p);
		float a = atan(p.y, p.x);
		// swirl: the noise is dragged round the centre, so bands curl like the painted orbs
		float sw = a + r * 3.2 - t * 2.4;
		vec2 sq = vec2(cos(sw), sin(sw)) * r * 0.6;
		float reach = 0.52 + 0.30 * nz(vec2(a * 0.32 + 0.5, t * 0.35)) + 0.16 * nz(vec2(a * 0.9, t * 0.9 + 3.0));
		reach *= (1.0 + 0.45 * max(p.y / max(r, 0.001), 0.0) * smoothstep(0.2, 0.7, r));  // tongues lick upward
		reach *= energy;
		v = (1.0 - r / max(reach, 0.01)) * 1.25 + (nz(sq + vec2(t * 0.1, 0.0)) - 0.5) * 0.7;
		ink_cut = nz(sq * 2.2 + vec2(0.0, t * 0.2) + 7.0);
	} else if (mode == 1) {
		float w = (1.0 - pow(uv.y, 0.8)) * (0.62 + 0.25 * energy) * energy + 0.02;
		float flick = nz(vec2(p.x * 0.5 + seed, uv.y * 1.1 - t * 0.9)) - 0.5;
		float sway = (nz(vec2(uv.y * 0.8, t * 0.3 + seed)) - 0.5) * 0.5 * uv.y;
		v = (1.0 - abs(p.x - sway) / w) * 1.1 - uv.y * 0.35 + flick * 0.8;
		ink_cut = nz(vec2(p.x * 1.6, uv.y * 1.6 - t * 0.6) + 5.0);
	} else {
		float x = uv.x;  // 0 tail, 1 head
		float prof = pow(x, 1.25) * 0.82 + 0.05;
		float wob = (nz(vec2(x * 2.0 - t * 1.4, 0.3)) - 0.5) * 0.35 * (1.0 - x);
		float d = abs(p.y - wob) / max(prof * energy, 0.01);
		float lick = nz(vec2(x * 3.0 - t * 2.2, p.y * 0.7 + seed)) - 0.5;
		v = (1.0 - d) * (0.55 + 0.9 * x) + lick * 0.7 * (0.3 + x);
		v *= smoothstep(0.0, 0.28, x);
		ink_cut = nz(vec2(x * 3.5 - t * 1.5, p.y * 1.5) + 9.0);
	}
	float aa = 0.025;
	float edge = smoothstep(0.02 - aa, 0.02 + aa, v);
	if (edge <= 0.0) {
		discard;
	}
	vec3 col = c_ink;
	col = mix(col, c_out, smoothstep(0.14 - aa, 0.14 + aa, v));
	col = mix(col, c_mid, smoothstep(0.38 - aa, 0.38 + aa, v));
	col = mix(col, c_core, smoothstep(0.66 - aa, 0.66 + aa, v));
	col = mix(col, c_hot, smoothstep(0.92 - aa, 0.92 + aa, v));
	// dark ink cut-outs inside the body, like the painted flames
	float inside = smoothstep(0.22, 0.30, v) * (1.0 - smoothstep(0.62, 0.70, v));
	col = mix(col, c_ink, inside * smoothstep(0.76 - aa, 0.76 + aa, ink_cut) * 0.9);
	ALBEDO = col;
	ALPHA = edge * alpha;
}
