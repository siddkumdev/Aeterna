shader_type spatial;
// The Veil (2026-11-10, plan Part D): the warm amber dome of faith over the island. A soft diagonal weave of light
// threads with a gentle shimmer and a brighter rim, drawn additively so it glows without hiding the island.
//   knit  0..1  how much of the dome exists; it grows up from the island edge (dawn) and recedes down (shatter)
//   crack 0..1  a jagged purple line (the Warden's colour) running down from the top of the dome (dusk)
// Colours are palette.json: lantern_glow, fire_yellow and crystal_purple.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 amber : source_color = vec4(0.965, 0.643, 0.365, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.831, 0.353, 1.0);
uniform vec4 warden : source_color = vec4(0.612, 0.243, 0.690, 1.0);
uniform float knit : hint_range(0.0, 1.0) = 1.0;
uniform float crack : hint_range(0.0, 1.0) = 0.0;
uniform float strength : hint_range(0.0, 2.0) = 0.4;
uniform float weave_scale = 22.0;
uniform float crack_seed = 0.0;  // changes where the crack runs, per loop

varying vec3 mpos;

void vertex() {
	mpos = VERTEX;
}

float thread(float x, float width) {
	// 1 on the thread's centre line, soft to 0 at the edge; x in thread units
	return 1.0 - smoothstep(0.0, width, abs(sin(x * 3.14159265)));
}

void fragment() {
	vec3 n = normalize(mpos);
	float u = atan(n.z, n.x);  // -pi..pi around the dome
	float v = n.y;  // 0 at the island edge .. 1 at the top

	// weave: two soft diagonal thread families on a stereographic grid (no bunching at the top), drifting slowly
	vec2 p = n.xz / (1.0 + n.y);
	float s = weave_scale * 0.5;
	float t1 = thread((p.x + p.y) * s + TIME * 0.05, 0.16);
	float t2 = thread((p.x - p.y) * s - TIME * 0.04, 0.16);
	float weave = max(t1, t2) * 0.55 + (t1 * t2) * 0.6;
	float shimmer = 0.78 + 0.22 * sin(TIME * 1.3 + u * 3.0 + v * 5.0);

	// rim glow: brighter where the surface turns away from the eye, and a warm base near the island edge
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float base = 0.06 + 0.5 * fres + 0.16 * (1.0 - v);

	// knit: grows up from the edge (v = 0) to the top (v = 1) with a soft front
	float front = knit * 1.15 - 0.05;
	float shown = 1.0 - smoothstep(front - 0.08, front, v);
	float edge_flash = smoothstep(0.0, 0.08, abs(v - front)) ;  // 0 on the knitting front: a bright seam
	float seam = (1.0 - edge_flash) * step(0.001, knit) * step(knit, 0.999);
	float lit = (base + weave * 0.55) * shimmer;

	// the crack: a jagged path down from the top; wider soft glow around a thin hot core
	float path_u = 0.9 + crack_seed + 0.55 * sin(v * 9.0 + crack_seed) + 0.22 * sin(v * 23.0 + 1.7 * crack_seed)
		+ 0.09 * sin(v * 61.0);
	float du = abs(mod(u - path_u + 3.14159265, 6.2831853) - 3.14159265);
	float reached = smoothstep(1.0 - crack - 0.05, 1.0 - crack + 0.02, v) * step(0.001, crack);
	float core = (1.0 - smoothstep(0.0, 0.025, du)) * reached;
	float halo = (1.0 - smoothstep(0.0, 0.2, du)) * reached;

	vec3 col = amber.rgb * lit * (1.0 - halo * 0.7);
	col += glow.rgb * seam * 0.7;
	col += warden.rgb * (core * 2.4 + halo * 0.5) * step(0.02, v);
	col *= shown;  // the crack lives on the dome: it goes when the dome goes
	ALBEDO = col * strength;
	ALPHA = 1.0;
}
