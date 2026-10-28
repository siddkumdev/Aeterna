shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Hand-painted toon burst (M2, Siddharth 2026-10-27, moodboard #31 and #47): one quad, one `progress` 0 -> 1.
//   mode 0  BURST   a cel-shaded explosion cloud with dark ink blotches that dissolves away, with sharp pale shards
//                   shooting out of it and thin glowing arcs
//   mode 1  RING    a flat flaming ring on the ground that swells and thins out (lay the quad flat)
// Palette: fire_yellow, lantern_glow, fire_red, ink, with wall_cream for the shards.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform int mode = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform float alpha = 1.0;
uniform float hold = 0.0;  // 1 = a standing ring (Rage): thin, fixed radius, never fades; `progress` only moves its teeth
uniform float shards = 1.0;  // 0 for smoke: no spikes
uniform vec3 c_core : source_color = vec3(1.0, 0.831, 0.353);
uniform vec3 c_mid : source_color = vec3(0.965, 0.643, 0.365);
uniform vec3 c_out : source_color = vec3(0.91, 0.271, 0.173);
uniform vec3 c_ink : source_color = vec3(0.067, 0.11, 0.188);
uniform vec3 c_shard : source_color = vec3(0.957, 0.894, 0.722);  // wall_cream F4E4B8
uniform vec2 size = vec2(0.05, 0.05);
uniform float depth_bias = 0.004;

varying vec2 uv;

void vertex() {
	uv = vec2(UV.x, 1.0 - UV.y);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 world;
	if (mode == 1) {
		world = centre + vec3(VERTEX.x * size.x, 0.0, VERTEX.y * size.y);  // flat on the ground
	} else {
		world = centre + INV_VIEW_MATRIX[0].xyz * VERTEX.x * size.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y * size.y;
	}
	if (mode == 0) {
		world += normalize(CAMERA_POSITION_WORLD - centre) * depth_bias;
	}
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

float nz(vec2 p) {
	return texture(noise, p).r;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float aa = 0.03;
	float pr = clamp(progress, 0.0, 1.0);
	float ease = 1.0 - pow(1.0 - pr, 3.0);  // fast out, slow settle
	vec3 col = c_ink;
	float vis = 0.0;
	if (mode == 0) {
		// the cloud: a lumpy disc that swells, then dissolves along the noise
		float Rc = mix(0.14, 0.58, ease);
		float lump = nz(p * 1.3 + seed) - 0.5;
		float d = r - Rc * (1.0 + 0.55 * lump);
		float body = 1.0 - smoothstep(-aa, aa, d);
		float depth = clamp(-d / max(Rc, 0.01), 0.0, 1.0);
		float dissolve = smoothstep(0.35, 1.0, pr);
		float keep = smoothstep(dissolve - 0.05, dissolve + 0.05, nz(p * 2.1 + seed + 3.0) * 0.8 + 0.1);
		col = mix(c_out, c_mid, smoothstep(0.18 - aa, 0.18 + aa, depth));
		col = mix(col, c_core, smoothstep(0.48 - aa, 0.48 + aa, depth) * (1.0 - smoothstep(0.35, 0.8, pr)));
		float blot = smoothstep(0.62 - aa, 0.62 + aa, nz(p * 2.6 + seed + 11.0));
		col = mix(col, c_ink, blot * smoothstep(0.1, 0.25, depth) * 0.85);
		vis = body * keep;
		// shards: sharp pale spikes that shoot out of the cloud and thin to nothing
		float spikes = 9.0;
		float ang = abs(sin(a * spikes * 0.5 + seed * 3.0));
		float len = mix(0.2, 0.98, 1.0 - pow(1.0 - clamp(pr * 1.5, 0.0, 1.0), 2.5));
		float inner = max(0.0, pr * 1.1 - 0.15) * len;
		float sp = pow(ang, 14.0) * 1.0;  // narrow wedges
		float in_spike = step(inner, r) * step(r, len * (0.35 + 0.65 * sp)) * step(0.35, sp + 0.35 * (1.0 - r / max(len, 0.01)));
		float spike_fade = 1.0 - smoothstep(0.55, 1.0, pr);
		if (shards > 0.5 && in_spike * spike_fade > 0.5 && vis < 0.5) {
			col = c_shard;
			vis = 1.0;
		}
	} else {
		// the ring: an annulus of flame on the ground; its teeth lick outward
		bool st = hold > 0.5;
		float R = st ? 0.82 : mix(0.25, 0.85, ease);
		float teeth = (nz(vec2(a * 0.6 + seed, pr * 0.5)) - 0.5) * 0.3 + (nz(vec2(a * 1.7, pr * 0.8 + 2.0)) - 0.5) * 0.12;
		teeth *= st ? 0.3 : 1.0;
		float thick = st ? 0.05 : mix(0.16, 0.03, pr);
		float rr = abs(r - R * (1.0 + teeth)) / max(thick, 0.005);
		float body = 1.0 - smoothstep(1.0 - aa * 4.0, 1.0 + aa * 4.0, rr);
		col = mix(c_out, c_mid, smoothstep(0.55, 0.6, 1.0 - rr));
		col = mix(col, c_core, smoothstep(0.82, 0.86, 1.0 - rr));
		float blot = smoothstep(0.7, 0.74, nz(vec2(a * 1.3 + seed, r * 3.0) + 5.0));
		col = mix(col, c_ink, blot * 0.8);
		vis = st ? body : body * (1.0 - smoothstep(0.6, 1.0, pr));
	}
	if (vis < 0.5) {
		discard;
	}
	ALBEDO = col;
	ALPHA = alpha;
}
