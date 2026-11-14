shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// The Veil over the village, seen from inside: threads of warm light woven from the villagers' faith, flowing up the
// dome. crack = 0..1 red-hot cracks spreading from `crack_at` (object space); strength fades the whole dome.
#include "res://shaders/story/story_noise.gdshaderinc"

uniform float strength = 1.0;
uniform float crack = 0.0;
uniform vec3 crack_at = vec3(0.0, 1.0, 0.0);
uniform vec3 gold : source_color = vec3(1.0, 0.72, 0.3);
uniform vec3 red : source_color = vec3(0.91, 0.27, 0.17);
uniform float clock = 0.0;
// Skotos's rift (the game's Veil has the same jagged purple line): a seam of purple-black spite that runs down from
// the top of the dome through the side facing the Dark Wood and right over to the other side. rift 0..1 = how far it
// has crept down; it throbs, and purple veins branch off it into the gold.
uniform float rift = 0.0;
uniform vec3 rift_dir = vec3(0.1, 0.0, 1.0);
uniform vec3 purple : source_color = vec3(0.612, 0.243, 0.690);

varying vec3 lp;

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	float lat = asin(clamp(lp.y, -1.0, 1.0));
	float lon = atan(lp.z, lp.x);
	float warp = fbm2(vec2(lon * 3.0, lat * 3.0 - clock * 0.15), 3);
	float t1 = pow(abs(sin(lon * 48.0 + warp * 4.0 + lat * 6.0)), 40.0);
	float t2 = pow(abs(sin(lon * 48.0 - warp * 4.0 - lat * 6.0 + 1.3)), 40.0);
	float rise = pow(abs(sin(lat * 30.0 - clock * 0.6 + warp * 3.0)), 30.0);
	float f = 1.0 - abs(dot(NORMAL, VIEW));
	float body = (t1 + t2) * 0.35 + rise * 0.25 + pow(f, 3.0) * 0.6 + 0.04;
	body *= 0.6 + 0.6 * fbm2(vec2(lon * 6.0, lat * 6.0 + clock * 0.3), 3);
	// soft from inside: you stand under it, it must read as a glow in the air, not a cage
	vec3 c = gold * body * 0.32 * strength * smoothstep(-0.05, 0.12, lp.y);
	if (crack > 0.0) {
		float d = acos(clamp(dot(lp, normalize(crack_at)), -1.0, 1.0));
		vec3 v = voronoi2(vec2(lon, lat) * 7.0 + warp);
		// The Veil is woven light, not glass: it frays rather than cracks. Soft, broken seams of light that flicker and
		// drift, with gaps along them, and the weave thins to nothing around each tear.
		float reach = smoothstep(crack * 3.2, crack * 3.2 - 0.4, d);
		float fray = smoothstep(0.4, 0.75, fbm2(vec2(lon, lat) * 14.0 + vec2(clock * 0.4, -clock * 0.25), 3));
		float flick = 0.6 + 0.4 * sin(clock * 7.0 + v.z * 40.0);
		float seam = smoothstep(0.05, 0.0, v.y) * reach * fray;
		float hole = smoothstep(0.12, 0.0, v.y) * reach;
		c *= 1.0 - hole * 0.7;  // the weave comes apart around the tear
		c += mix(red, purple, 0.6) * seam * 0.9 * flick * strength;  // the fraying is Skotos's too
		c = mix(c, c * vec3(1.0, 0.5, 0.4), crack * 0.5);
	}
	if (rift > 0.0) {
		vec3 side = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(rift_dir)));  // the rift's great circle passes over the top
		float along = atan(dot(lp, normalize(rift_dir)), lp.y);  // position along the circle, 0 at the top
		float jag = 0.07 * sin(along * 9.0 + 1.3) + 0.035 * sin(along * 23.0) + 0.015 * sin(along * 61.0 + clock * 0.5);
		float off = abs(asin(clamp(dot(lp, side), -1.0, 1.0)) - jag);
		float reached = smoothstep(rift * 1.7 + 0.02, rift * 1.7 - 0.12, abs(along));  // creeps down both ways from the top
		float throb = 0.75 + 0.25 * sin(clock * 3.0 - abs(along) * 6.0);
		float core = smoothstep(0.02, 0.0, off) * reached * (0.55 + 0.45 * smoothstep(0.3, 0.6, fbm2(vec2(along * 20.0, clock * 0.8), 2)));  // a smouldering seam, broken in places
		float halo = smoothstep(0.14, 0.0, off) * reached;
		vec3 vv = voronoi2(vec2(lon, lat) * 9.0 + 3.0);
		float wisp = smoothstep(0.35, 0.7, fbm2(vec2(lon, lat) * 12.0 - vec2(0.0, clock * 0.5), 3));
		float vein = smoothstep(0.04, 0.0, vv.y) * smoothstep(0.35, 0.0, off) * reached * rift * wisp;  // tendrils, not a net
		c *= 1.0 - halo * 0.6;  // the gold dims around the wound
		c += purple * (core * 3.0 + halo * 0.6 * throb + vein * 1.2 * throb) * max(strength, 0.6);
	}
	ALBEDO = c;
}
