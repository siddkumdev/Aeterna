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
		"rim_e": 0.45, "elev": 16.0, "az": 25.0, "fog": Color("F8CDB4"), "fog_d": 0.35, "sat": 0.95, "con": 1.0,
		"exp": 1.0, "glow": 0.25, "thr": 0.95},
	"day": {"key": Color("FFD898"), "key_e": 1.35, "amb": Color("86B4BC"), "amb_e": 0.6, "rim": Color("FFD07A"),
		"rim_e": 0.35, "elev": 48.0, "az": -35.0, "fog": Color("D6EBF5"), "fog_d": 0.2, "sat": 1.0, "con": 1.04,
		"exp": 1.0, "glow": 0.15, "thr": 1.1},
	"dusk": {"key": Color("F29A9A"), "key_e": 0.7, "amb": Color("9C3EB0"), "amb_e": 1.0, "rim": Color("DA8990"),
		"rim_e": 0.8, "elev": 24.0, "az": -55.0, "fog": Color("9C6A9E"), "fog_d": 0.45, "sat": 1.0, "con": 1.04,
		"exp": 0.95, "glow": 0.6, "thr": 0.75},
	"night": {"key": Color("8FB0D8"), "key_e": 0.4, "amb": Color("3A5A9A"), "amb_e": 0.75, "rim": Color("5A86B0"),
		"rim_e": 0.6, "elev": 55.0, "az": 25.0, "fog": Color("16203A"), "fog_d": 0.5, "sat": 0.55, "con": 1.08,
		"exp": 0.8, "glow": 1.2, "thr": 0.55, "moon": true},
}
const BLEND := 1.5  # s to move from one mood to the next
const DAWN_HOLD := 8.0  # s of dawn before the day light takes over
const DUSK_HOLD := 4.0  # s of dusk before night falls

var env: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var current := ""
var _seq: Tween
var _fade: Tween
var _move: Tween  # sun <-> moon swap
var _turn: Tween  # the sun's slow travel


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


func set_mood(mood: String, seconds := BLEND, turn := -1.0) -> void:
	## Moves the colours and the grade to a mood over `seconds` (instantly when 0), and the sun toward the mood's
	## position over `turn` seconds (default: `seconds`). Between sun and moon (night <-> any other mood), and into a
	## new dawn, the light never swings across the sky: it dims out, moves while dark, and comes back up.
	var was_moon: bool = PRESETS.get(current, {}).get("moon", false)
	var current_was := current
	current = mood
	var p: Dictionary = PRESETS[mood]
	var colours := {
		sun: {"light_color": p["key"]},
		rim: {"light_color": p["rim"], "light_energy": p["rim_e"]},
		env: {"ambient_light_color": p["amb"], "ambient_light_energy": p["amb_e"], "fog_light_color": p["fog"],
			"fog_density": p["fog_d"], "adjustment_saturation": p["sat"], "adjustment_contrast": p["con"],
			"glow_intensity": p["glow"], "tonemap_exposure": p["exp"], "glow_hdr_threshold": p["thr"]},
	}
	for t in [_fade, _move]:
		if t and t.is_valid():
			t.kill()
	if seconds <= 0.0 or not is_inside_tree():
		for obj in colours:
			for prop in colours[obj]:
				obj.set(prop, colours[obj][prop])
		sun.light_energy = p["key_e"]
		_aim(_sun_quat(p), 0.0)
		return
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for obj in colours:
		for prop in colours[obj]:
			_fade.tween_property(obj, prop, colours[obj][prop], seconds)
	if was_moon != p.get("moon", false) or (mood == "dawn" and current_was != "dawn"):
		# swap sun and moon (or start a new sunrise): fade the light out, move it in the dark, fade it back in
		_move = create_tween().set_trans(Tween.TRANS_SINE)
		_move.tween_property(sun, "light_energy", 0.0, seconds * 0.45)
		_move.tween_callback(_aim.bind(_sun_quat(p), 0.0))
		_move.tween_property(sun, "light_energy", p["key_e"], seconds * 0.55)
	else:
		_fade.tween_property(sun, "light_energy", p["key_e"], seconds)
		_aim(_sun_quat(p), seconds if turn == -1.0 else turn)


func play(first: String, then: String, hold: float) -> void:
	## A mood that eases into the next after `hold` seconds (dawn -> day, dusk -> night). A later call cancels it.
	## At dawn the sun keeps rising the whole time (one slow, steady climb from the east into the day position).
	if _seq and _seq.is_valid():
		_seq.kill()
	var climb: bool = not PRESETS[first].get("moon", false) and not PRESETS[then].get("moon", false) and first == "dawn"
	set_mood(first, BLEND * 1.5, -1.0 if climb else hold)  # at dusk the sun sinks slowly over the whole hold
	if not is_inside_tree():
		return
	_seq = create_tween()
	if climb:
		_seq.tween_interval(BLEND * 1.5)  # the dawn colours settle, then the sun climbs steadily into the day
		_seq.tween_callback(_aim.bind(_sun_quat(PRESETS[then]), hold + BLEND * 2.0 - BLEND * 1.5))
		_seq.tween_interval(hold - BLEND * 1.5)
		_seq.tween_callback(func(): set_mood(then, BLEND * 2.0, -2.0))
	else:
		_seq.tween_interval(hold)
		_seq.tween_callback(set_mood.bind(then, BLEND * 2.0))


func _sun_quat(p: Dictionary) -> Quaternion:
	return Basis.from_euler(Vector3(deg_to_rad(-p["elev"]), deg_to_rad(p["az"]), 0.0)).get_rotation_quaternion()


func _aim(q: Quaternion, seconds: float) -> void:
	## Turns the sun (and the rim light, which always comes from opposite it) toward q. seconds < -1 = leave it.
	if seconds < -1.0:
		return
	var rim_q := Quaternion(Vector3.UP, PI) * q  # same height, opposite side
	if _turn and _turn.is_valid():
		_turn.kill()
	if seconds <= 0.0 or not is_inside_tree():
		sun.quaternion = q
		rim.quaternion = rim_q
		return
	_turn = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_turn.tween_property(sun, "quaternion", q, seconds)
	_turn.tween_property(rim, "quaternion", rim_q, seconds)
