shader_type canvas_item;
// Desktop-only soft vignette (lighting pass, 2026-10-28): darkens the corners toward ink, never the centre.
uniform float strength = 0.32;
uniform vec3 tint : source_color = vec3(0.067, 0.11, 0.188);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 0.85;
	float d = smoothstep(0.75, 1.45, length(p));
	COLOR = vec4(tint, d * strength);
}
