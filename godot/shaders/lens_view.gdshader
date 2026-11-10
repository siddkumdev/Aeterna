shader_type spatial;
render_mode unshaded, cull_disabled;
// The Crystal Lens's window: what the lens camera sees (the island plus the Foresight overlay), cut to the glass's
// oval, with a cool Foresight tint (blue is Foresight's colour, art bible 6) and a bright rim. Palette: crystal_blue 3FB7D9.

uniform sampler2D view : source_color, filter_linear;
uniform vec3 tint : source_color = vec3(0.247, 0.718, 0.851);
uniform float strength = 0.35;
uniform float rim_glow = 1.1;
uniform float fade = 1.0;  // 0..1 while the glass wakes up

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float inside = 1.0 - smoothstep(0.94, 1.0, r);
	vec3 c = texture(view, UV).rgb;
	c = mix(c, c * vec3(0.72, 0.96, 1.2) + tint * 0.12, strength);
	float rim = smoothstep(0.80, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
	c += tint * rim * rim_glow;
	ALBEDO = c;
	ALPHA = inside * fade;
}
