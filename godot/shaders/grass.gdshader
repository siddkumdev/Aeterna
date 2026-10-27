shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Wavy grass tufts (M2, Siddharth 2026-10-27). One MultiMesh, one draw call. Blades sway in a slow wind (two sine
// waves plus a drifting gust, driven by world position so the whole meadow ripples together) and bend away from
// up to 16 "pushers": ground enemies, Guards and the hands. Colours come from the palette (see GrassField).

uniform vec3 root_col : source_color = vec3(0.365, 0.522, 0.282);  // leaf_green 5D8548
uniform vec3 mid_col : source_color = vec3(0.533, 0.745, 0.271);   // grass 88BE45, the saturated meadow green
uniform vec3 tip_col : source_color = vec3(0.553, 0.722, 0.353);   // leaf_light 8DB85A
uniform vec3 dry_col : source_color = vec3(0.855, 0.812, 0.361);   // leaf_yellow DACF5C
uniform vec3 gust_col : source_color = vec3(0.749, 0.941, 0.773);  // heal_green 7FE08A lightened 50% toward white: the wind's pale green
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 0.9;
uniform float wind_amp = 0.0052;   // metres of tip sway: a light breeze (Siddharth 2026-10-27)
uniform float push_strength = 0.011;
uniform int push_count = 0;
uniform vec4 pushers[16];          // xyz world position, w radius (m)
// Longbow gusts: a pulse that runs along the bolt's line. gusts = start xz + unit direction xz;
// gust_state = age (s), length (m), strength 0..1
uniform vec4 gusts[4];
uniform vec4 gust_state[4];
const float GUST_SPEED = 1.4;

varying float h;
varying float dry;
varying float tone;
varying float gtint;

void vertex() {
	h = clamp(UV.y, 0.0, 1.0);
	dry = COLOR.r;
	tone = COLOR.g;
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 wd = normalize(wind_dir);
	float ph = dot(base.xz, wd) * 34.0;
	float t = TIME * wind_speed;
	float sway = sin(t * 2.0 + ph) * 0.6 + sin(t * 3.3 + ph * 1.7 + 1.3) * 0.22 + sin(t * 0.5 + base.x * 8.0 + base.z * 6.0) * 0.45;
	vec2 off = wd * sway * wind_amp * h * h;
	float flatten = 0.0;
	for (int i = 0; i < 16; i++) {
		if (i >= push_count) {
			break;
		}
		vec4 p = pushers[i];
		vec2 d = base.xz - p.xz;
		float dist = length(d);
		float k = 1.0 - smoothstep(p.w * 0.35, p.w, dist);
		k *= 1.0 - smoothstep(0.012, 0.06, p.y - base.y);  // a hand held well above the grass leaves it alone
		vec2 away = dist > 0.0001 ? d / dist : vec2(1.0, 0.0);
		off += away * k * push_strength * h;
		flatten = max(flatten, k);
	}
	float gk = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 gs = gust_state[i];
		if (gs.z <= 0.0) {
			continue;
		}
		vec2 rel = base.xz - gusts[i].xy;
		vec2 gd = gusts[i].zw;
		float along = dot(rel, gd);
		float across = abs(rel.x * gd.y - rel.y * gd.x);
		float head = gs.x * GUST_SPEED;
		float k = (1.0 - smoothstep(0.0, 0.07, abs(along - head))) * (1.0 - smoothstep(0.012, 0.04, across));
		k *= step(0.0, along) * step(along, gs.y + 0.05) * gs.z;
		off += gd * k * 0.016 * h;
		gk = max(gk, k);
	}
	gtint = gk;
	VERTEX.y *= 1.0 - 0.45 * flatten * h;
	mat3 inv = inverse(mat3(MODEL_MATRIX));
	vec3 local = inv * vec3(off.x, 0.0, off.y);
	VERTEX.xz += local.xz;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);  // always lit like the ground, whichever side we see
	vec3 tip = mix(tip_col, dry_col, 0.18 + dry * 0.4);
	vec3 c = mix(root_col, mid_col, smoothstep(0.0, 0.5, h));  // dark root, saturated middle, bright tip: layered foliage
	c = mix(c, tip, smoothstep(0.45, 1.0, h));
	c *= 0.84 + 0.3 * tone;  // each clump a little lighter or darker
	ALBEDO = mix(c, gust_col, gtint * (0.35 + 0.65 * h));
	ROUGHNESS = 1.0;
}
