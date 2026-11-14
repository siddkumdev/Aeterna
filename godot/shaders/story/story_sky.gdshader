shader_type sky;
// The story's whole sky, all 360 degrees: a scattering gradient, the sun and its glow, two cloud layers drifting over
// you, a sea of cloud BELOW the horizon (the island floats), stars and the moon at night. The director tweens the
// uniforms from chapter to chapter (dawn, dusk, the curse, the fall, the rewind).
#include "res://shaders/story/story_noise.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 0.2, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
uniform float sun_size = 0.9994;
uniform vec3 zenith : source_color = vec3(0.25, 0.42, 0.75);
uniform vec3 horizon : source_color = vec3(0.95, 0.75, 0.55);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.86, 0.72);
uniform vec3 cloud_shade : source_color = vec3(0.45, 0.42, 0.5);
uniform float cover = 0.45;
uniform float stars = 0.0;
uniform vec3 moon_dir = vec3(0.4, 0.5, 0.6);
uniform float moon = 0.0;
uniform float curse = 0.0;  // 0..1: the sky bruises purple, a slow storm turns over the Dark Wood
uniform vec3 curse_color : source_color = vec3(0.32, 0.12, 0.42);
uniform float burn = 0.0;  // 0..1: the night sky over a burning village
uniform float flow = 1.0;  // cloud drift speed and direction (negative = the rewind)
uniform float exposure = 1.0;
uniform float clock = 0.0;  // the director's own time (so the rewind can run clouds backwards)

vec3 clouds(vec3 d, vec3 base, float up) {
	// one layer on a flat plane above (up = 1) or below (up = -1) the viewer
	vec2 uv = d.xz / max(abs(d.y), 0.035) * (up > 0.0 ? 0.55 : 0.9);
	vec2 drift = vec2(clock * 0.012, clock * 0.004) * flow;
	float n = fbm2(uv + drift, AT_CUBEMAP_PASS ? 3 : 5);
	float wisps = fbm2(uv * 3.1 - drift * 1.7, 3);
	float c = smoothstep(1.0 - cover - 0.15, 1.0 - cover + 0.3, n * 0.8 + wisps * 0.35);
	float lit = clamp(dot(normalize(vec3(d.x, 0.0, d.z) + 0.001), normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 0.001)) * 0.5 + 0.5, 0.0, 1.0);
	float thick = smoothstep(0.3, 1.0, n);
	vec3 col = mix(cloud_lit, cloud_shade, thick * 0.75 + (1.0 - lit) * 0.25);
	col += sun_color * pow(lit, 6.0) * (1.0 - thick) * 0.6 * clamp(sun_dir.y + 0.3, 0.0, 1.0);
	float fade = up > 0.0 ? smoothstep(0.0, 0.18, d.y) : smoothstep(0.0, 0.08, -d.y);
	return mix(base, col, c * fade);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 s = normalize(sun_dir);
	float h = clamp(d.y, -1.0, 1.0);
	// scattering: a bright horizon band falling to the zenith colour; warmer toward the sun
	float toward = clamp(dot(d, s) * 0.5 + 0.5, 0.0, 1.0);
	vec3 base = mix(horizon, zenith, pow(clamp(h, 0.0, 1.0), 0.45));
	base += sun_color * pow(toward, 8.0) * 0.45 * clamp(1.0 - h * 1.5, 0.0, 1.0);
	base = mix(base, base * (1.0 - curse) + curse_color * (0.4 + 0.6 * h), curse * clamp(1.0 - h * 0.3, 0.0, 1.0));
	base = mix(base, vec3(0.55, 0.12, 0.05) * (1.4 - h), burn * clamp(1.0 - h * 1.2, 0.0, 1.0));
	vec3 col = base;
	if (h < 0.0) {
		// the sea of cloud the island floats on, lit by the same sky
		vec3 under = mix(horizon * 0.9, cloud_shade * 0.55, clamp(-h * 2.5, 0.0, 1.0));
		col = clouds(d, under, -1.0);
	} else {
		if (stars > 0.0 && !AT_CUBEMAP_PASS) {
			vec3 q = d * 220.0;
			vec3 cell = floor(q);
			float r = h31(cell);
			float tw = 0.6 + 0.4 * sin(clock * (2.0 + r * 4.0) + r * 40.0);
			float st = smoothstep(0.985, 1.0, r) * smoothstep(0.42, 0.0, length(fract(q) - 0.5)) * tw;
			float band = fbm3(d * 3.0, 3);  // a faint river of stars
			col += vec3(1.0, 0.92, 0.85) * st * stars * (0.6 + band) + vec3(0.25, 0.2, 0.3) * band * band * stars * 0.12 * h;
		}
		col = clouds(d, col, 1.0);
	}
	float sd = dot(d, s);
	col += sun_color * smoothstep(sun_size, sun_size + 0.0003, sd) * 18.0;  // the disc
	col += sun_color * pow(max(sd, 0.0), 220.0) * 1.6 + sun_color * pow(max(sd, 0.0), 12.0) * 0.18;
	if (moon > 0.0) {
		float md = dot(d, normalize(moon_dir));
		float disc = smoothstep(0.99955, 0.9997, md);
		float mare = fbm3(d * 60.0, 3);
		col += vec3(0.95, 0.9, 0.82) * disc * (0.8 + 0.4 * mare) * 2.5 * moon + vec3(0.6, 0.55, 0.6) * pow(max(md, 0.0), 300.0) * 0.4 * moon;
	}
	if (curse > 0.0 && h > 0.0 && !AT_CUBEMAP_PASS) {
		// a slow wound of light in the clouds over the Dark Wood
		float rift = fbm2(d.xz / max(d.y, 0.05) * 1.3 + vec2(clock * 0.03, 0.0), 4);
		col += curse_color * 1.6 * smoothstep(0.62, 0.8, rift) * curse * smoothstep(0.0, 0.3, h);
	}
	COLOR = col * exposure;
}
