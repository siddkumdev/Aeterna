shader_type canvas_item;
// Folds two cubes of 90 degree views (one per eye) into a top/bottom equirect frame. Used by tools/pano_clip.gd.

uniform sampler2D face_0_0 : filter_linear; uniform sampler2D face_0_1 : filter_linear; uniform sampler2D face_0_2 : filter_linear;
uniform sampler2D face_0_3 : filter_linear; uniform sampler2D face_0_4 : filter_linear; uniform sampler2D face_0_5 : filter_linear;
uniform sampler2D face_1_0 : filter_linear; uniform sampler2D face_1_1 : filter_linear; uniform sampler2D face_1_2 : filter_linear;
uniform sampler2D face_1_3 : filter_linear; uniform sampler2D face_1_4 : filter_linear; uniform sampler2D face_1_5 : filter_linear;
uniform vec3 fwd_0; uniform vec3 fwd_1; uniform vec3 fwd_2; uniform vec3 fwd_3; uniform vec3 fwd_4; uniform vec3 fwd_5;
uniform vec3 up_0; uniform vec3 up_1; uniform vec3 up_2; uniform vec3 up_3; uniform vec3 up_4; uniform vec3 up_5;
uniform vec3 right_0; uniform vec3 right_1; uniform vec3 right_2; uniform vec3 right_3; uniform vec3 right_4; uniform vec3 right_5;

vec2 face_uv(vec3 d, vec3 f, vec3 u, vec3 r) {
	float z = dot(d, f);
	return vec2(0.5 + 0.5 * dot(d, r) / z, 0.5 - 0.5 * dot(d, u) / z);
}

vec3 pick(int eye, vec3 d) {
	vec3 F[6] = vec3[](fwd_0, fwd_1, fwd_2, fwd_3, fwd_4, fwd_5);
	vec3 U[6] = vec3[](up_0, up_1, up_2, up_3, up_4, up_5);
	vec3 R[6] = vec3[](right_0, right_1, right_2, right_3, right_4, right_5);
	int best = 0;
	float bz = -2.0;
	for (int i = 0; i < 6; i++) {
		float z = dot(d, F[i]);
		if (z > bz) { bz = z; best = i; }
	}
	vec2 uv = face_uv(d, F[best], U[best], R[best]);
	if (eye == 0) {
		if (best == 0) return texture(face_0_0, uv).rgb;
		if (best == 1) return texture(face_0_1, uv).rgb;
		if (best == 2) return texture(face_0_2, uv).rgb;
		if (best == 3) return texture(face_0_3, uv).rgb;
		if (best == 4) return texture(face_0_4, uv).rgb;
		return texture(face_0_5, uv).rgb;
	}
	if (best == 0) return texture(face_1_0, uv).rgb;
	if (best == 1) return texture(face_1_1, uv).rgb;
	if (best == 2) return texture(face_1_2, uv).rgb;
	if (best == 3) return texture(face_1_3, uv).rgb;
	if (best == 4) return texture(face_1_4, uv).rgb;
	return texture(face_1_5, uv).rgb;
}

void fragment() {
	int eye = UV.y < 0.5 ? 0 : 1;
	float v = fract(UV.y * 2.0);
	float lon = (UV.x - 0.5) * 2.0 * PI;  // centre of the frame looks forward (-Z)
	float lat = (0.5 - v) * PI;
	vec3 d = vec3(sin(lon) * cos(lat), sin(lat), -cos(lon) * cos(lat));
	COLOR = vec4(pick(eye, d), 1.0);
}
