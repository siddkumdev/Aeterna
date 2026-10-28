class_name Lighting
extends Node3D
## Board lighting and post-processing (M2 polish; plan decided by Claude 2026-10-28 on Siddharth's "go with what's
## best", his review to follow). Four moods from art/art_bible.md 6a / palette.json "lighting", moved through the game:
##   dawn  at the start of every build day, easing into day
##   day   the rest of the day (and the card screen)
##   dusk  the first seconds of a night ("the forest stirs"), easing into night
##   night moonlight; windows, lanterns and fire carry the scene
## One sun (shadowed) + one rim light from behind (no shadow) + a colour ambient. The environment adds a filmic
## tonemap, a per-mood saturation/contrast grade, bloom that only bright glowing things reach, and depth fog
## that tints the forest ring. Passthrough rule: nothing here touches the background, so the real room is never
## graded; the vignette is a desktop-only overlay (game.gd).
## Numbers are first-pass and tuned by eye from renders; the key/ambient/rim colours are palette.json's.

const PRESETS := {
	# key = sun/moon colour, amb = ambient (shadow fill), rim = back light; *_e = energies
	# elev/az = sun height and direction in degrees (az 0 = from the player's side, + = from the right)
	# fog = colour the far forest fades toward; sat/con = colour grade; exp = exposure; glow = bloom strength; thr = how bright a pixel must be to bloom (low at night: only lit windows and fire are bright then)
	"dawn": {"key": Color("FFD9B0"), "key_e": 1.1, "amb": Color("7E86B8"), "amb_e": 0.75, "rim": Color("F8CDB4"),
		"rim_e": 0.45, "elev": 32.0, "az": 60.0, "fog": Color("F8CDB4"), "fog_d": 0.35, "sat": 0.95, "con": 1.0,
		"exp": 1.0, "glow": 0.25, "thr": 0.95},
	"day": {"key": Color("FFD898"), "key_e": 1.35, "amb": Color("86B4BC"), "amb_e": 0.6, "rim": Color("FFD07A"),
		"rim_e": 0.35, "elev": 48.0, "az": -35.0, "fog": Color("D6EBF5"), "fog_d": 0.2, "sat": 1.0, "con": 1.04,
		"exp": 1.0, "glow": 0.15, "thr": 1.1},
	"dusk": {"key": Color("F29A9A"), "key_e": 0.7, "amb": Color("9C3EB0"), "amb_e": 1.0, "rim": Color("DA8990"),
		"rim_e": 0.8, "elev": 30.0, "az": -65.0, "fog": Color("9C6A9E"), "fog_d": 0.45, "sat": 1.0, "con": 1.04,
		"exp": 0.95, "glow": 0.6, "thr": 0.75},
	"night": {"key": Color("8FB0D8"), "key_e": 0.4, "amb": Color("3A5A9A"), "amb_e": 0.75, "rim": Color("5A86B0"),
		"rim_e": 0.6, "elev": 55.0, "az": 25.0, "fog": Color("16203A"), "fog_d": 0.5, "sat": 0.55, "con": 1.08,
		"exp": 0.8, "glow": 1.2, "thr": 0.55},
}
const BLEND := 1.5  # s to move from one mood to the next
const DAWN_HOLD := 5.0  # s of dawn before the day light takes over
const DUSK_HOLD := 4.0  # s of dusk before night falls

var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var current := ""
var _seq: Tween
var _fade: Tween


func build(fog_from: float) -> void:
	## fog_from = metres from the camera to the board's near edge (the fog starts a little past the board centre).
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(0x80, 0x7E, 0x7A)  # stands in for passthrough
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 4.0
	env.adjustment_enabled = true
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.95  # only things brighter than lit cream walls bloom: fire, windows, spell effects
	env.glow_bloom = 0.0
	env.glow_strength = 1.3
	for i in range(7):  # wide soft halos (the small levels alone barely show at this scale)
		env.set_glow_level(i, [0.0, 0.0, 0.6, 1.0, 1.0, 0.8, 0.0][i])
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = fog_from + 0.45
	env.fog_depth_end = fog_from + 1.6
	env.fog_depth_curve = 1.5
	env.fog_sky_affect = 0.0  # never the background (passthrough)
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4.0
	add_child(sun)
	rim = DirectionalLight3D.new()  # a warm edge from behind the board, no shadow
	rim.light_specular = 0.0
	add_child(rim)
	set_mood("day", 0.0)


func set_mood(mood: String, seconds := BLEND) -> void:
	## Moves every light and the grade to a mood (instantly when seconds is 0).
	current = mood
	var p: Dictionary = PRESETS[mood]
	var basis := Basis.from_euler(Vector3(deg_to_rad(-p["elev"]), deg_to_rad(p["az"]), 0.0))
	var rim_basis := Basis.from_euler(Vector3(deg_to_rad(-25.0), deg_to_rad(p["az"] + 180.0), 0.0))
	var to := {
		sun: {"light_color": p["key"], "light_energy": p["key_e"], "quaternion": basis.get_rotation_quaternion()},
		rim: {"light_color": p["rim"], "light_energy": p["rim_e"], "quaternion": rim_basis.get_rotation_quaternion()},
		env: {"ambient_light_color": p["amb"], "ambient_light_energy": p["amb_e"], "fog_light_color": p["fog"],
			"fog_density": p["fog_d"], "adjustment_saturation": p["sat"], "adjustment_contrast": p["con"],
			"glow_intensity": p["glow"], "tonemap_exposure": p["exp"], "glow_hdr_threshold": p["thr"]},
	}
	if _fade and _fade.is_valid():
		_fade.kill()
	if seconds <= 0.0 or not is_inside_tree():
		for obj in to:
			for prop in to[obj]:
				obj.set(prop, to[obj][prop])
		return
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for obj in to:
		for prop in to[obj]:
			_fade.tween_property(obj, prop, to[obj][prop], seconds)


func play(first: String, then: String, hold: float) -> void:
	## A mood that eases into the next after `hold` seconds (dawn -> day, dusk -> night). A later call cancels it.
	if _seq and _seq.is_valid():
		_seq.kill()
	set_mood(first)
	if not is_inside_tree():
		return
	_seq = create_tween()
	_seq.tween_interval(hold)
	_seq.tween_callback(set_mood.bind(then, BLEND * 2.0))
