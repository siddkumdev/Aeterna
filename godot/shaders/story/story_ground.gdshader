shader_type spatial;
render_mode cull_back;
// The island's ground in the story: one even meadow colour (the user, 2026-11-17: "just make it a uniform color"; the
// patches, path and stone read as white blotches in the headset). Heights are baked into the mesh (StoryWorld.height).
// Flat colour, no per-pixel noise: also the cheapest ground for the Quest.

uniform vec3 grass : source_color = vec3(0.533, 0.745, 0.271);  // the game's palette "grass" (88BE45), as on the board
uniform vec2 village = vec2(0.0, -17.0);
uniform float scorch = 0.0;  // the fall: the ground darkens around the village

varying float v_burn;

void vertex() {
	v_burn = smoothstep(30.0, 6.0, length(VERTEX.xz - village));  // the mesh is in world space (no transform)
}

void fragment() {
	ALBEDO = mix(grass, grass * vec3(0.25, 0.2, 0.18), scorch * v_burn);
	ROUGHNESS = 0.92;
	SPECULAR = 0.3;
}
