shader_type spatial;
// Passthrough haze (2026-11-10, plan Part D): a big inverted sphere around the play space. Seen from inside, it lays a
// soft warm gradient (honey at the floor, rose overhead) over the REAL room, so the room reads dimmed and hazy while the
// game stays crisp: the dome is far behind the board, so the depth test lets every game object cover it.
// Colours are palette.json: shell_gold (honey) and cloth_rose (rose).
render_mode unshaded, cull_front, depth_draw_never, fog_disabled, blend_mix;

uniform vec4 honey : source_color = vec4(0.910, 0.722, 0.227, 1.0);
uniform vec4 rose : source_color = vec4(0.898, 0.541, 0.627, 1.0);
uniform float alpha_bottom : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_top : hint_range(0.0, 1.0) = 0.35;
uniform float fade : hint_range(0.0, 1.0) = 1.0;  // 0 = no haze, 1 = full (eased in when passthrough starts)

varying float h;

void vertex() {
	h = normalize(VERTEX).y;
}

void fragment() {
	float t = smoothstep(-0.6, 0.8, h);
	ALBEDO = mix(honey.rgb, rose.rgb, t);
	ALPHA = mix(alpha_bottom, alpha_top, t) * fade;
}
