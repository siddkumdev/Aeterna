shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Wavy grass tufts (M2, Siddharth 2026-10-27). One MultiMesh, one draw call. Blades sway in a slow wind (two sine
// waves plus a drifting gust, driven by world position so the whole meadow ripples together) and bend away from
// up to 16 "pushers": ground enemies, Guards and the hands. Colours come from the palette (see GrassField).

uniform vec3 root_col : source_color = vec3(0.365, 0.522, 0.282);  // leaf_green 5D8548
uniform vec3 tip_col : source_color = vec3(0.553, 0.722, 0.353);   // leaf_light 8DB85A
uniform vec3 dry_col : source_color = vec3(0.855, 0.812, 0.361);   // leaf_yellow DACF5C
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 1.0;
uniform float wind_amp = 0.0042;   // metres of tip sway
uniform float push_strength = 0.011;
uniform int push_count = 0;
uniform vec4 pushers[16];          // xyz world position, w radius (m)

varying float h;
varying float dry;

void vertex() {
	h = clamp(UV.y, 0.0, 1.0);
	dry = COLOR.r;
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
	VERTEX.y *= 1.0 - 0.45 * flatten * h;
	mat3 inv = inverse(mat3(MODEL_MATRIX));
	vec3 local = inv * vec3(off.x, 0.0, off.y);
	VERTEX.xz += local.xz;
}

void fragment() {
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);  // always lit like the ground, whichever side we see
	vec3 tip = mix(tip_col, dry_col, dry * 0.4);
	ALBEDO = mix(root_col, tip, h);
	ROUGHNESS = 1.0;
}
