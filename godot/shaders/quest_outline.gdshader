shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;
// Quest outline (Siddharth 2026-11-16): a warm pulsing inverted-hull outline on the item of a quest the player has
// started. Palette fire_yellow <-> lantern_glow, never blue. One extra draw per mesh; no lights, no shadows, no transparency.

uniform vec3 colour_a : source_color = vec3(1.0, 0.831, 0.353);   // fire_yellow FFD45A
uniform vec3 colour_b : source_color = vec3(0.965, 0.643, 0.365); // lantern_glow F6A45D
uniform float width = 0.008;  // clip units (0.4 percent of the screen height per side, about 3 px at 1000x640 and 8 px per eye on a Quest): constant on screen at any scale
uniform float speed = 4.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize(mat3(MODELVIEW_MATRIX) * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	float len = length(dir);
	if (len > 0.0001) {
		dir /= len;
		float pulse = 0.75 + 0.25 * sin(TIME * speed);
		clip.xy += dir * width * pulse * clip.w;
	}
	clip.z -= 0.0008 * clip.w;  // pushed slightly back (reverse-Z): flat meshes like the kite do not speckle against their own hull
	POSITION = clip;
}

void fragment() {
	float p = 0.5 + 0.5 * sin(TIME * speed);
	ALBEDO = mix(colour_a, colour_b, p);
}
