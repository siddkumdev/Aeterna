shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Painted fire in the style of moodboard #44 (Siddharth 2026-11-04, Wizard Tower redo): long flowing strands, yellow as the
// main colour, orange and red toward the edge, a soft glow round it. No ink outline and no black blotches.
//   mode 0  ORB    a ball wound from strands, licks trailing off it (the Wizard's orb, the fireball's head)
//   mode 1  RING   a ring of flame at `radius` of the quad: flat in the world, or facing the camera with `face_camera`
//   mode 2  COMET  a teardrop with a long tail thinning to a point; uv.x 0 = tail tip, 1 = head; lies along `axis`
//   mode 3  CLOUD  a puffy fire cloud that swells and burns away from inside as `progress` runs 0 to 1 (the impact)
//   mode 4  LICK   a flame running along a ribbon mesh (see PaintedRibbon): UV.x along it, NORMAL = its direction
// Colours are the palette's fire_yellow and fire_red and blends of them. Magic is black / orange / red, never blue.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform int mode = 0;
uniform float energy = 1.0;     // ORB: how full; COMET, RING: how thick
uniform float progress = 0.0;   // CLOUD: 0 to 1 over its life
uniform float radius = 0.7;     // RING: 0 to 1 of the quad's half width
uniform bool face_camera = false;  // RING
uniform float head = 0.5;       // LICK: where along the ribbon the flame is, 0 to 1
uniform float lick_len = 0.3;   // LICK: how much of the ribbon it covers
uniform float flow = 1.0;
uniform float phase = 0.0;      // for fire whose speed changes: keep flow still and add up the time here, or a new flow jumps the whole pattern
uniform float seed = 0.0;
uniform float alpha = 1.0;
uniform float glow = 0.08;      // strength of the soft glow outside the shape
uniform vec3 c_yellow : source_color = vec3(1.0, 0.831, 0.353);  // fire_yellow FFD45A
uniform vec3 c_red : source_color = vec3(0.91, 0.271, 0.173);    // fire_red E8452C
uniform vec3 axis = vec3(1.0, 0.0, 0.0);
uniform vec2 size = vec2(0.02, 0.02);
uniform float depth_bias = 0.004;

varying vec2 uv;

const vec3 LOBES[8] = {
	vec3(0.0, -0.05, 0.40), vec3(-0.36, -0.12, 0.34), vec3(0.36, -0.14, 0.34), vec3(-0.20, 0.22, 0.32),
	vec3(0.22, 0.20, 0.32), vec3(-0.54, -0.32, 0.26), vec3(0.54, -0.34, 0.26), vec3(0.0, -0.36, 0.34)
};

void vertex() {
	uv = vec2(UV.x, 1.0 - UV.y);  // uv.y = 0 at the bottom
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world;
	if (mode == 1 && !face_camera) {
		world = centre + vec3(VERTEX.x * size.x, 0.0, VERTEX.y * size.y);
	} else if (mode == 2) {
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 ax = normalize(axis);
		vec3 side = normalize(cross(ax, to_cam));
		world = centre + ax * (VERTEX.x - 0.38) * size.x + side * VERTEX.y * size.y;  // the head sits just ahead of the centre
	} else if (mode == 4) {
		vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 along = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 side = cross(along, normalize(CAMERA_POSITION_WORLD - at));  // not normalised: thins as it turns toward the camera instead of folding
		world = at + side * (UV.y - 0.5) * size.y;
		centre = at;
	} else {
		world = centre + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	}
	world += normalize(CAMERA_POSITION_WORLD - centre) * depth_bias;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float nz(vec2 p) {
	return texture(noise, p).r;
}

// The noise is soft, so its contrast is stretched into narrow strands.
float strands(float n) {
	return smoothstep(0.34, 0.66, n);
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float t = TIME * flow + phase + seed;
	float v = -1.0;       // heat: above 0 is inside the fire, higher is hotter
	float line = 0.0;     // darker strands painted through the body

	if (mode == 0) {
		float r = length(p);
		float a = atan(p.y, p.x);
		float sw = a + r * 3.0 - t * 2.2;  // spirals: the noise is read along them, so it draws long curled strands
		vec2 q = vec2(cos(sw), sin(sw));
		float s = mix(0.55, nz(q * 0.4 + vec2(r * 0.09 + seed * 0.013, 0.31)), smoothstep(0.0, 0.16, r));  // the spirals meet at the centre: calm it, or it shows a star
		float rim = nz(vec2(cos(a - t * 0.9), sin(a - t * 0.9)) * 0.14 + vec2(0.55, seed * 0.017));
		float reach = (0.44 + 0.36 * (rim - 0.5) + 0.12) * energy;  // the edge rolls gently
		float body = 1.0 - r / max(reach, 0.01);
		float wind = strands(s);  // 0 in the dark strands, 1 in the bright ones
		v = body * 0.42 + wind * 0.5 * smoothstep(0.0, 0.3, body) + 0.02;
		v += 0.25 * smoothstep(0.6, 1.0, body);  // a hot heart
		if (body < 0.0) {
			v = body * 1.2;
		}
		line = 0.0;
	} else if (mode == 1) {
		float r = length(p);
		float a = atan(p.y, p.x);
		vec2 c = vec2(cos(a), sin(a));
		float n1 = nz(c * 0.2 + vec2(t * 0.09, seed * 0.011));
		float n2 = nz(c * 0.42 - vec2(t * 0.17, seed * 0.019));
		float d = r - radius;
		float reach = d > 0.0 ? 0.04 + 0.24 * strands(n1) * strands(n2 + 0.08) : 0.05;  // tongues on the outside, a clean inner edge
		v = (1.0 - abs(d) / max(reach * energy, 0.005)) * (0.42 + 0.2 * strands(n2));
		line = 0.0;
	} else if (mode == 2) {
		float x = uv.x;  // 0 tail, 1 head
		float bend = (nz(vec2(x * 0.28 - t * 0.2, 0.3 + seed * 0.01)) - 0.5) * 1.1 * (1.0 - x) * (1.0 - x);
		float prof = pow(x, 1.6) * 0.8 + 0.01;
		prof *= 1.0 - smoothstep(0.86, 1.0, x) * 0.7;  // the head rounds off
		float y = p.y - bend;
		float s = nz(vec2(x * 0.22 - t * 0.55, y * 0.55 / max(prof, 0.12) + seed * 0.01));
		float body = 1.0 - abs(y) / max(prof * energy, 0.005);
		v = body < 0.0 ? body : body * 0.32 + strands(s) * 0.42 * smoothstep(0.0, 0.25, body) + 0.02 + 0.5 * smoothstep(0.82, 0.98, x) * smoothstep(0.3, 0.8, body);
		v -= (1.0 - smoothstep(0.0, 0.8, x)) * (1.0 - strands(s)) * 0.8;  // the tail breaks into strands toward its tip
		line = 0.0;
		// thin speed lines thrown clear of the body, as on the painted comet
		float sl = nz(vec2(y * 0.75 + seed * 0.01, x * 0.03 - t * 0.04));
		float speed = (1.0 - smoothstep(0.0, 0.012, abs(sl - 0.5))) * smoothstep(0.15, 0.4, x) * (1.0 - smoothstep(0.55, 0.85, x)) * (1.0 - smoothstep(0.3, 0.55, abs(y)));
		v = max(v, speed * 0.16 - (1.0 - speed));
	} else if (mode == 3) {
		float k = progress;
		float grow = 1.0 - pow(1.0 - min(k * 2.2, 1.0), 3.0);
		vec2 q = (p - vec2(0.0, 0.08 * k)) / max(0.38 + 0.62 * grow, 0.01);  // swells, rises a little as it burns
		q += (vec2(nz(q * 0.12 + vec2(seed * 0.01, 0.2)), nz(q * 0.12 + vec2(0.7, seed * 0.01))) - 0.5) * 0.28;
		float field = 0.0;
		for (int i = 0; i < 8; i++) {
			vec3 l = LOBES[i];
			float f = max(0.0, 1.0 - length(q - l.xy) / (l.z * 1.45));
			field += f * f;
		}
		float best = field - 0.42 + (nz(q * 0.34 + vec2(seed * 0.02, 0.6)) - 0.5) * 0.3;
		float s = nz(q * 0.42 + vec2(seed * 0.013, -t * 0.05));
		float burn = smoothstep(0.42, 1.0, k);
		float hole = nz(q * 0.14 + vec2(0.4, seed * 0.017));  // burns away in ragged patches from the heart
		v = best < 0.0 ? best * 2.0 : min(best * 0.5, 0.1) + strands(s) * 0.42 * smoothstep(0.0, 0.2, best) + 0.02 - burn * 0.3 + 0.12 * smoothstep(0.6, 1.1, best) * (1.0 - burn);
		v = min(v, (hole - burn * 0.95 - 0.02) * 3.0);
		line = 0.0;
	} else {
		float x = uv.x;
		float d = (x - head) / max(lick_len, 0.01);  // +1 at the tip, -1 at the tail end
		float tip = 1.0 - smoothstep(0.0, 1.0, d);
		float tail = smoothstep(-1.0, -0.1, d);
		float prof = tip * tail * 0.95 * smoothstep(0.0, 0.05, x) * (1.0 - smoothstep(0.95, 1.0, x));
		float s = nz(vec2(x * 0.7 - t * 0.5, p.y * 0.12 + seed * 0.01));
		v = (1.0 - abs(p.y) / max(prof, 0.005)) * 0.34 + strands(s) * 0.14;
		if (prof < 0.01) {
			v = -1.0;
		}
		line = (1.0 - smoothstep(0.0, 0.03, abs(s - 0.5))) * 0.7;
	}

	float aa = 0.02;
	float inside = smoothstep(0.0 - aa, 0.0 + aa, v);
	float halo = 0.0;
	if (mode == 0 || mode == 3) {
		float fall = 1.0 - smoothstep(0.35, 0.98, length(p));  // round, and zero before the quad's edge
		halo = glow * fall * fall * (mode == 3 ? 0.4 * (1.0 - progress) : 1.0);
	}
	if (inside <= 0.0 && halo <= 0.004) {
		discard;  // kept on purpose: without it the empty part of each quad washed the whole frame out
	}
	// Held below full brightness on purpose: the night's bloom bleaches anything brighter to cream.
	vec3 deep = mix(c_red, vec3(0.067, 0.11, 0.188), 0.3) * 0.8;
	vec3 red = c_red * 0.82;
	vec3 orange = vec3(0.86, 0.40, 0.09);
	vec3 yellow = vec3(0.92, 0.64, 0.14);
	vec3 pale = vec3(1.0, 0.82, 0.38);
	float w = v - line * 0.2;
	vec3 col = deep;
	col = mix(col, red, smoothstep(0.07 - aa, 0.07 + aa, w));
	col = mix(col, orange, smoothstep(0.17 - aa, 0.17 + aa, w));
	col = mix(col, yellow, smoothstep(0.46 - aa, 0.46 + aa, w));
	col = mix(col, pale, smoothstep(0.98 - aa, 0.98 + aa, w));
	ALBEDO = mix(red, col, inside);
	float fade = mode == 3 ? 1.0 - smoothstep(0.78, 1.0, progress) : 1.0;  // the cloud thins away instead of vanishing
	ALPHA = max(inside, halo) * alpha * fade;
}
