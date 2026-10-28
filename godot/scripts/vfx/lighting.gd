class_name Lighting
extends Node3D
## Board lighting and post-processing (M2 polish; plan decided by Claude 2026-10-28 on Siddharth's "go with what's
## best", his review to follow). Four moods from art/art_bible.md 6a / palette.json "lighting", moved through the game:
##   dawn  at the start of every build day, easing into day (colours only)
##   day   the rest of the day (and the card screen)
##   dusk  the first seconds of a night ("the forest stirs"), easing into night
##   night moonlight; windows, lanterns and fire carry the scene
## The sun is STATIC (Siddharth 2026-10-28: "the only time it moves is when the player presses start night"):
## it stands at the day position all day, and only when a night starts does it sink to the dusk position and fade
## out. The moon is its own fixed light that fades in for the night and out at dawn; the sun is put back at the day
## position while it is dark, so nobody sees it move back.
## Lights: sun (shadowed), moon (no shadow), one rim light from behind (no shadow), a colour ambient. The environment adds a filmic
## tonemap, a per-mood saturation/contrast grade, bloom that only bright glowing things reach, and depth fog
## that tints the forest ring. Passthrough rule: nothing here touches the background, so the real room is never
## graded; the vignette is a desktop-only overlay (game.gd).
## Numbers are first-pass and tuned by eye from renders; the key/ambient/rim colours are palette.json's.

const PRESETS := {
	# key = sun/moon colour, amb = ambient (shadow fill), rim = back light; *_e = energies
	# fog = colour the far forest fades toward; sat/con = colour grade; exp = exposure; glow = bloom strength; thr = how bright a pixel must be to bloom (low at night: only lit windows and fire are bright then)
	"dawn": {"key": Color("FFB890"), "key_e": 1.05, "amb": Color("9A84C8"), "amb_e": 0.95, "rim": Color("F8A890"),
		"rim_e": 0.45, "fog": Color("F8B0A0"), "fog_d": 0.5, "sat": 0.88, "con": 1.0,
		"exp": 1.0, "glow": 0.25, "thr": 0.95},
	"day": {"key": Color("FFD898"), "key_e": 1.35, "amb": Color("86B4BC"), "amb_e": 0.6, "rim": Color("FFD07A"),
		"rim_e": 0.35, "fog": Color("D6EBF5"), "fog_d": 0.2, "sat": 1.0, "con": 1.04,
		"exp": 1.0, "glow": 0.15, "thr": 1.1},
	"dusk": {"key": Color("F29A9A"), "key_e": 0.7, "amb": Color("9C3EB0"), "amb_e": 1.0, "rim": Color("DA8990"),
		"rim_e": 0.8, "fog": Color("9C6A9E"), "fog_d": 0.45, "sat": 1.0, "con": 1.04,
		"exp": 0.95, "glow": 0.6, "thr": 0.75},
	"night": {"key": Color("8FB0D8"), "key_e": 0.4, "amb": Color("3A5A9A"), "amb_e": 0.75, "rim": Color("5A86B0"),
		"rim_e": 0.6, "fog": Color("16203A"), "fog_d": 0.5, "sat": 0.55, "con": 1.08,
		"exp": 0.8, "glow": 1.2, "thr": 0.55, "moon": true},
}
# light directions: (elevation, azimuth) in degrees; az 0 = from the player's side, + = from the right
const SUN_DAY := Vector2(48.0, -35.0)
const SUN_SET := Vector2(20.0, -50.0)  # where it has sunk to by the end of dusk
const MOON := Vector2(55.0, 25.0)
const BLEND := 1.5  # s to move from one mood to the next
const DAWN_HOLD := 6.0  # s of dawn before the day light takes over
const DUSK_HOLD := 4.0  # s of dusk before night falls

var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var moon: DirectionalLight3D
var current := ""
var _seq: Tween
var _fade: Tween
var _sink: Tween  # the sun going down at dusk: its only movement


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
	sun.quaternion = _quat(SUN_DAY)
	moon = DirectionalLight3D.new()  # fixed, fades in for the night
	moon.light_specular = 0.0
	moon.quaternion = _quat(MOON)
	add_child(moon)
	rim = DirectionalLight3D.new()  # a warm edge from behind the board, opposite the day sun, fixed; no shadow
	rim.light_specular = 0.0
	rim.quaternion = Quaternion(Vector3.UP, PI) * _quat(Vector2(25.0, SUN_DAY.y))
	add_child(rim)
	set_mood("day", 0.0)


func _process(_delta: float) -> void:
	## A light at zero energy is switched off, so the Quest never shades with it (the moon by day, the sun at night).
	sun.visible = sun.light_energy > 0.01
	moon.visible = moon.light_energy > 0.01


func stop_sequence() -> void:
	## Cancels a pending dusk -> night or dawn -> day, so a screen that ends the night keeps its own mood.
	_stop(_seq)
	_stop(_sink)


func set_mood(mood: String, seconds := BLEND) -> void:
	## Moves the colours, the grade and the sun/moon brightness to a mood over `seconds` (instantly when 0).
	## Lights never turn here (see the header); dusk's sinking sun is started by play().
	current = mood
	var p: Dictionary = PRESETS[mood]
	var night: bool = p.get("moon", false)
	var to := {
		sun: {"light_color": p["key"], "light_energy": 0.0 if night else p["key_e"]},
		moon: {"light_color": p["key"], "light_energy": p["key_e"] if night else 0.0},
		rim: {"light_color": p["rim"], "light_energy": p["rim_e"]},
		env: {"ambient_light_color": p["amb"], "ambient_light_energy": p["amb_e"], "fog_light_color": p["fog"],
			"fog_density": p["fog_d"], "adjustment_saturation": p["sat"], "adjustment_contrast": p["con"],
			"glow_intensity": p["glow"], "tonemap_exposure": p["exp"], "glow_hdr_threshold": p["thr"]},
	}
	if not night and mood != "dusk" and not sun.quaternion.is_equal_approx(_quat(SUN_DAY)):
		# back to the day position while it is dark, so nobody sees it move (after a very short night it may still
		# be lit: then it goes dark first and fades back in from the day position)
		_stop(_sink)
		sun.light_energy = 0.0
		sun.quaternion = _quat(SUN_DAY)
	_stop(_fade)
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
	## Dusk is the one time the sun moves: it sinks from the day position over the hold, then night fades it out.
	_stop(_seq)
	set_mood(first, BLEND * 2.0 if first == "dawn" else BLEND)  # a sunrise fades in gently
	if not is_inside_tree():
		return
	if first == "dusk":
		_stop(_sink)
		_sink = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_sink.tween_property(sun, "quaternion", _quat(SUN_SET), hold + BLEND)
	_seq = create_tween()
	_seq.tween_interval(hold)
	_seq.tween_callback(set_mood.bind(then, BLEND * 2.0))


func _quat(elev_az: Vector2) -> Quaternion:
	return Basis.from_euler(Vector3(deg_to_rad(-elev_az.x), deg_to_rad(elev_az.y), 0.0)).get_rotation_quaternion()


static func _stop(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()
