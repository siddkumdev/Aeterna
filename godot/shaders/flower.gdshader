shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Meadow flowers and clover (M2, Siddharth 2026-10-27), drawn with the grass: same wind, same pushers. Two MultiMeshes
// share this shader. UV.x says which part of the mesh a vertex is: 0 stem, 1 petals (instance colour),
// 2 flower centre (INSTANCE_CUSTOM), 3 clover pad (instance colour). UV.y = 0 at the root, 1 at the top of the stem.
// Palette: petals wall_cream / flower_pink / flower_yellow / roof_orange, centres flower_yellow / roof_orange,
// stems leaf_green to leaf_light, clover leaf_light and leaf_green (the GDScript converts the hexes to linear).

uniform vec3 stem_root : source_color = vec3(0.365, 0.522, 0.282);  // leaf_green 5D8548
uniform vec3 stem_tip : source_color = vec3(0.553, 0.722, 0.353);   // leaf_light 8DB85A
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 0.9;
uniform float wind_amp = 0.0052;
uniform float push_strength = 0.011;
uniform int push_count = 0;
uniform vec4 pushers[16];

varying float h;
varying float part;
varying vec3 petal;
varying vec3 centre;

void vertex() {
	h = clamp(UV.y, 0.0, 1.0);
	part = UV.x;
	petal = COLOR.rgb;
	centre = INSTANCE_CUSTOM.rgb;
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
		k *= 1.0 - smoothstep(0.012, 0.06, p.y - base.y);
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
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	vec3 c = mix(stem_root, stem_tip, h);
	if (part > 2.5) {
		c = petal;
	} else if (part > 1.5) {
		c = centre;
	} else if (part > 0.5) {
		c = petal;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
