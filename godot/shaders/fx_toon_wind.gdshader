shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Hand-painted toon wind (M2, Siddharth 2026-10-27): the Longbow's pale-green wind, drawn like moodboard #33: black ink
// swept blades with pale white-green highlights and a ring of tiny streaks on the ground. STREAKS, never sparkles
// (decided 2026-10-18), and always whiter than heal_green so it never reads as healing.
//   mode 0  VORTEX   a small tornado standing on the quad's bottom edge (uv.y 0 = base): ink blades with pale highlights
//   mode 1  STREAKS  two swept streaks along `axis` (uv.x 0 = tail tip, 1 = head): the bolt's gust trail
//   mode 2  RING     flat ring of broken streaks on the ground, `progress` 0 -> 1 (lay flat)
//   mode 3  SLASH    a pierce flash: pale slashes whipping out of a white spark, `progress` 0 -> 1

uniform sampler2D noise : repeat_enable, filter_linear;
uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 1.5) = 1.0;
uniform float flow = 1.0;
uniform float seed = 0.0;
uniform float alpha = 0.55;  // see-through: the wind is a light touch, never hides the tower or the enemy
uniform vec3 c_hi : source_color = vec3(0.957, 1.0, 0.961);     // the whitest streak
uniform vec3 c_pale : source_color = vec3(0.749, 0.941, 0.773); // BFF0C5 (heal_green lightened toward white)
uniform vec3 c_green : source_color = vec3(0.561, 0.863, 0.69); // 8FDCB0, the deepest wind tone, still paler than heal_green
uniform vec3 c_ink : source_color = vec3(0.067, 0.11, 0.188);
uniform vec3 axis = vec3(1.0, 0.0, 0.0);
uniform vec2 size = vec2(0.02, 0.02);
uniform float depth_bias = 0.004;

varying vec2 uv;

void vertex() {
	uv = vec2(UV.x, 1.0 - UV.y);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world;
	if (mode == 1) {
		vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
		vec3 ax = normalize(axis);
		vec3 side = normalize(cross(ax, to_cam));
		world = centre + ax * (VERTEX.x - 0.38) * size.x + side * VERTEX.y * size.y;
	} else if (mode == 2) {
		world = centre + vec3(VERTEX.x * size.x, 0.0, VERTEX.y * size.y);
	} else {
		world = centre + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	}
	if (mode != 2) {
		world += normalize(CAMERA_POSITION_WORLD - centre) * depth_bias;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float nz(vec2 p) {
	return texture(noise, p).r;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float t = TIME * flow + seed;
	float aa = 0.03;
	float vis = 0.0;
	vec3 col = c_ink;
	if (mode == 0) {
		float y = uv.y;
		float sway = (nz(vec2(y * 0.7, t * 0.25 + seed)) - 0.5) * 0.35 * y;
		float hw = mix(0.12, 0.95, pow(y, 0.85)) * (0.35 + 0.65 * energy);
		float u = (p.x - sway) / max(hw, 0.01);
		float v = nz(vec2(u * 0.55 + y * 1.5 - t * 0.7, y * 2.0 + seed));
		float inside = (1.0 - abs(u)) + (v - 0.5) * 0.55;
		float cap = 1.0 - smoothstep(0.88, 1.0, y);  // the top frays away
		vis = step(0.0, inside) * step(0.0, cap + (v - 0.5) * 0.6);
		col = c_ink;
		col = mix(col, c_green, smoothstep(0.58 - aa, 0.58 + aa, v) * smoothstep(0.1, 0.4, y));
		col = mix(col, c_pale, smoothstep(0.72 - aa, 0.72 + aa, v));
		col = mix(col, c_hi, smoothstep(0.86 - aa, 0.86 + aa, v));
		col = mix(col, c_pale, (1.0 - smoothstep(0.0, 0.12, y)) * 0.9);  // a bright foot where it meets the ground
	} else if (mode == 1) {
		float x = uv.x;
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float lane = (fi - 0.5) * 0.5;
			float start = 0.08 + fi * 0.17 + 0.1 * nz(vec2(fi * 3.1, seed));
			float wob = (nz(vec2(x * 2.2 - t * 1.6 + fi * 7.0, fi)) - 0.5) * 0.22 * (1.0 - x);
			float w = (0.05 + 0.1 * smoothstep(start, 1.0, x)) * 0.8;
			float d = abs(p.y - lane - wob) / w;
			float on = step(start, x) * (1.0 - smoothstep(0.9, 1.0, d));
			if (on > vis) {
				vis = on;
				col = d > 0.62 ? c_ink : (d > 0.3 ? c_green : (d > 0.12 ? c_pale : c_hi));
				if (x < start + 0.22) {
					col = d > 0.5 ? c_ink : c_pale;  // thin pointed tail
				}
			}
		}
		vis *= energy > 0.02 ? 1.0 : 0.0;
	} else if (mode == 2) {
		float r = length(p);
		float a = atan(p.y, p.x);
		float pr = clamp(progress, 0.0, 1.0);
		float ease = 1.0 - pow(1.0 - pr, 3.0);
		float R = mix(0.25, 0.92, ease);
		float fade = 1.0 - smoothstep(0.55, 1.0, pr);
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float Ri = R * (1.0 - 0.18 * fi);
			float th = mix(0.075, 0.018, pr);
			float dir = fi == 0.0 ? 1.0 : -1.0;
			float arc = nz(vec2(a * 1.4 + seed + fi * 5.0 + dir * pr * 2.5, fi * 0.37));
			float gate = step(0.42 - 0.12 * fi, arc) * step(pr * 0.7, arc + 0.35);
			float d = abs(r - Ri) / th;
			float on = gate * (1.0 - smoothstep(0.85, 1.0, d)) * fade;
			if (on > vis) {
				vis = on;
				col = d > 0.7 ? c_ink : (d > 0.38 ? c_green : c_pale);
				col = mix(col, c_hi, step(0.82, arc) * step(d, 0.4));
			}
		}
		// small flecks thrown off the ring
		float fleck = step(0.8, nz(vec2(a * 6.0 + seed, floor(r * 9.0)))) * step(abs(r - R * 0.78), 0.05) * fade;
		if (fleck > vis) {
			vis = fleck;
			col = c_pale;
		}
	} else {
		float r = length(p);
		float a = atan(p.y, p.x);
		float pr = clamp(progress, 0.0, 1.0);
		float sw = a + r * 1.6 + seed;  // slashes curve like the tornado blades
		float k = abs(sin(sw * 3.5));
		float len = mix(0.15, 0.98, 1.0 - pow(1.0 - min(pr * 1.6, 1.0), 2.5));
		float inner = max(0.0, pr * 1.2 - 0.2) * len;
		float wedge = pow(k, 6.0);
		float on = step(inner, r) * step(r, len * (0.3 + 0.7 * wedge)) * step(0.25, wedge + 0.3 * (1.0 - r / max(len, 0.01)));
		on *= 1.0 - smoothstep(0.5, 1.0, pr);
		float spark_r = mix(0.16, 0.02, pr);
		if (r < spark_r && pr < 0.5) {
			vis = 1.0;
			col = r < spark_r * 0.55 ? c_hi : c_pale;
		} else if (on > 0.5) {
			vis = 1.0;
			col = wedge > 0.55 ? c_pale : (r > len * 0.72 ? c_green : c_ink);
		}
	}
	if (vis < 0.5) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
