class_name OpeningStage
extends Node3D
## The opening (sykeriin, 2026-11-14: "an immersive experience... cover the player's 360 view... as realistic as you
## can get it"; replaces the 2026-11-11 puppet theatre). You stand INSIDE the island at human scale, in a world built
## from code (scripts/story/story_world.gd): a meadow at dawn, the village ahead, the Dark Wood all round, the island's
## cliff and a sea of cloud below. Six chapters, each a new time of day; fades between them; captions low in your
## view, typed word by word with a voice "boop" per word for whoever speaks (narrator, Skotos, Maren). Its own sky and
## ambience; passthrough is off for the story only and comes back after. Words: docs/STORY.md ("The opening").
## Skip: let go, then hold a pinch (or the mouse / Space) for SKIP_HOLD; Esc skips at once.

signal finished

const SKIP_HOLD := 1.5
const EYE := 1.62  # m, the desktop camera's eye height
const CAPTION_DIST := 1.5
const WORD_GAP := 0.24  # s between typed words
const VOICE := {"narrator": "voice_narrator", "skotos": "voice_skotos", "maren": "voice_maren"}
const NAME := {"narrator": "", "skotos": "SKOTOS", "maren": "OLD MAREN"}
const NAME_COL := {"narrator": Color(1.0, 0.85, 0.55), "skotos": Color(0.78, 0.55, 1.0), "maren": Color(1.0, 0.7, 0.45)}

## Each chapter: a name, a mood, where to look (yaw in degrees, 0 = toward the village, 180 = behind you), the
## ambience loops, its length, and its lines [at s, speaker, text]. The cues (_cue_N) run alongside.
const CHAPTERS := [
	{"name": "I.  THE ISLAND", "mood": "predawn", "look": 0.0, "loops": ["story_meadow"], "len": 34.0, "lines": [
		[3.0, "narrator", "Past the edge of every map, a small island drifts on a sea of cloud."],
		[11.0, "narrator", "Twelve people live here. And one small god, who has watched over them for longer than anyone remembers. That god is you."],
		[19.0, "maren", "Morning, little one. Pip let the goats into the bakery again. Keep him alive till supper, would you?"],
		[27.0, "narrator", "Every prayer is a thread of light. Together, they weave the Veil."]]},
	{"name": "II.  THE FORGOTTEN", "mood": "dusk", "look": 180.0, "loops": ["story_dusk"], "len": 28.0, "lines": [
		[2.5, "narrator", "Now turn around. The wood behind you had a god of its own, once."],
		[10.0, "narrator", "Skotos. Their people stopped praying, one by one. Their temple sank into the roots, and their name was forgotten."],
		[18.5, "narrator", "A forgotten god does not die. They starve. And they watch the warm little lights of those still loved."]]},
	{"name": "III.  THE CURSE", "mood": "curse", "look": 180.0, "loops": ["story_dread"], "len": 34.0, "lines": [
		[3.0, "narrator", "Tonight, the hunger turned to spite."],
		[12.0, "skotos", "Little god. They love you. I remember how that felt."],
		[20.0, "skotos", "Every nightfall, your Veil will fail. Let us see how long they believe in a god who cannot keep the dark out."]]},
	{"name": "IV.  THE DARK COMES", "mood": "curse", "look": 0.0, "loops": ["story_dread"], "len": 30.0, "lines": [
		[2.0, "narrator", "The Veil cracked like ice, and broke."],
		[9.0, "narrator", "And out of the Dark Wood came the shades: ink and hunger, with eyes like coals."],
		[18.0, "narrator", "The people barred their doors and held their breath till dawn. The shades came back the next night. And the next."]]},
	{"name": "V.  YOUR TURN", "mood": "dawn", "look": 0.0, "loops": ["story_meadow"], "len": 44.0, "lines": [
		[3.0, "maren", "Little god... I don't know if you can hear an old woman. The children are frightened. So am I."],
		[10.0, "maren", "You've never once left us. Stay with us tonight. Please."],
		[17.0, "narrator", "She is praying to you. By day, build and help them. Their faith is your light, and your strength."],
		[27.0, "narrator", "Keep the cracked mirror close. Hold it up by day, look toward the Dark Wood, and it shows where the shades will come from tonight."],
		[38.0, "narrator", "Watch over them."]]},
]

var game
var world: StoryWorld
var _chapter := -1
var _t := 0.0
var _skipped := false
var _started := false
var _skip_t := 0.0
var _armed := false  # the skip only counts after every press that started the story is let go
var _cam: Camera3D  # the desktop camera (none in the headset)
var _old_cam: Camera3D
var _look_yaw := 0.0
var _fade: MeshInstance3D
var _fade_mat: StandardMaterial3D
var _cap: Node3D
var _cap_band: MeshInstance3D
var _cap_mat: ShaderMaterial
var _cap_name: Label3D
var _cap_text: Label3D
var _hint: Label3D
var _title: Node3D
var _words: PackedStringArray = []
var _speaker := ""
var _word_i := 0
var _word_t := 0.0
var _cap_hold := 0.0
var _lines_done := 0
var _loops := {}  # id -> AudioStreamPlayer
var _cued := {}
var _rng := RandomNumberGenerator.new()
var _cap_fade: Tween
var _saved := {}
var _stand := Vector3.ZERO
var _aerial := false
var _shake := 0.0  # desktop camera only; never shake the headset view
var _pitch := 0.0  # desktop camera tilt (down while over the village)
const AERIAL_TURN := 0.09  # rad/s: slow, so it stays comfortable in the headset
const AERIAL_HIGH := 24.0
const AERIAL_LOW := 13.0
const AERIAL_FAR := 24.0
const AERIAL_NEAR := 20.0


# ------------------------------------------------------------------ set up and tear down
func _ready() -> void:
	visible = false
	_rng.randomize()


func place(cam: Camera3D, fallback: Vector3) -> void:
	## Where you stand. In the headset: on the real floor under you, facing where you look. On the desktop: a camera
	## of our own at eye height.
	var at := fallback
	var f := Vector3(0, 0, -1)
	if cam:
		f = -cam.global_transform.basis.z
		at = cam.global_position
	f.y = 0.0
	f = f.normalized() if f.length() > 0.05 else Vector3(0, 0, -1)
	var floor_y := at.y - EYE
	if game and game._xr and game._xr_origin:
		floor_y = (game._xr_origin as Node3D).global_position.y
	global_position = Vector3(at.x, floor_y, at.z)
	rotation = Vector3(0, atan2(-f.x, -f.z), 0)  # local -Z (the village) is where you were looking


func _xr() -> bool:
	return game != null and game._xr and game._xr_cam != null


func _view_cam() -> Camera3D:
	return game._xr_cam if _xr() else _cam


func _enter() -> void:
	## Swap the game's room for the story's world: own sky (passthrough off), own light, no game ambience.
	world = StoryWorld.new()
	world.name = "World"
	add_child(world)
	if game:
		_saved["board"] = game.board.visible if game.board else false
		if game.board:
			game.board.visible = false
		if game.haze:
			_saved["haze"] = game.haze.visible
			game.haze.visible = false
		if game.lighting:
			var l: Node = game.lighting
			l.set_process(false)
			for c in l.get_children():
				if c is WorldEnvironment:
					_saved["we"] = c
					_saved["env"] = c.environment
					c.environment = world.env
				elif c is Light3D:
					_saved["light_%s" % c.name] = c.visible
					c.visible = false
		if game.audio:
			game.audio.set_scatter([], Callable())
	var vp := get_viewport()
	_saved["transparent"] = vp.transparent_bg
	vp.transparent_bg = false
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		_saved["blend"] = xr.environment_blend_mode
		if xr.get_supported_environment_blend_modes().has(XRInterface.XR_ENV_BLEND_MODE_OPAQUE):
			xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		if xr.has_method("is_passthrough_enabled") and xr.is_passthrough_enabled():
			_saved["passthrough"] = true
			xr.stop_passthrough()
	if not _saved.has("we"):  # no game lighting (a shot tool): bring our own environment
		var we := WorldEnvironment.new()
		we.environment = world.env
		add_child(we)
	if not _xr():
		_old_cam = vp.get_camera_3d()
		_cam = Camera3D.new()
		_cam.name = "StoryCamera"
		_cam.fov = 70.0
		_cam.near = 0.05
		_cam.far = 600.0
		add_child(_cam)
		_cam.position = Vector3(0, EYE, 0)
		_cam.current = true


func _leave() -> void:
	for id in _loops:
		(_loops[id] as AudioStreamPlayer).stop()
	var vp := get_viewport()
	vp.transparent_bg = _saved.get("transparent", vp.transparent_bg)
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		if _saved.has("blend"):
			xr.environment_blend_mode = _saved["blend"]
		if _saved.get("passthrough", false):
			xr.start_passthrough()
	if game:
		if _saved.has("we") and is_instance_valid(_saved["we"]):
			(_saved["we"] as WorldEnvironment).environment = _saved["env"]
		if game.lighting:
			game.lighting.set_process(true)
			for c in game.lighting.get_children():
				if c is Light3D and _saved.has("light_%s" % c.name):
					c.visible = _saved["light_%s" % c.name]
		if game.haze and _saved.has("haze"):
			game.haze.visible = _saved["haze"]
		if game.audio and game.has_method("_phase_sound"):
			game._phase_sound(0, game.phase)
	if _cam:
		_cam.current = false
		if is_instance_valid(_old_cam):
			_old_cam.current = true


# ------------------------------------------------------------------ the overlay: fade, captions, skip hint
func _build_overlay() -> void:
	var holder := _view_cam()
	_fade_mat = StandardMaterial3D.new()
	_fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fade_mat.no_depth_test = true
	_fade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fade_mat.render_priority = 100
	_fade_mat.albedo_color = Color(0, 0, 0, 1)
	var s := SphereMesh.new()
	s.radius = 0.3
	s.height = 0.6
	s.radial_segments = 16
	s.rings = 8
	_fade = MeshInstance3D.new()
	_fade.name = "Fade"
	_fade.mesh = s
	_fade.material_override = _fade_mat
	_fade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(_fade)
	_cap = Node3D.new()
	_cap.name = "Caption"
	add_child(_cap)
	_cap.top_level = true
	_cap_mat = ShaderMaterial.new()
	_cap_mat.shader = load("res://shaders/story/story_caption.gdshader")
	_cap_mat.set_shader_parameter("alpha", 0.0)
	_cap_mat.render_priority = 90
	var q := QuadMesh.new()
	q.size = Vector2(1.2, 0.26)
	_cap_mat.set_shader_parameter("size", q.size)
	_cap_band = MeshInstance3D.new()
	_cap_band.mesh = q
	_cap_band.material_override = _cap_mat
	_cap_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cap.add_child(_cap_band)
	_cap_name = _label(36, Vector3(0, 0.085, 0.002))
	_cap_name.font = UiFonts.title()
	_cap_text = _label(50, Vector3(0, -0.02, 0.002))
	_cap_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_text.width = 1050.0
	_cap_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_cap_text.position.y = 0.05
	_hint = _label(26, Vector3(0, -0.2, 0.002))
	_hint.modulate = Color(1, 0.9, 0.75, 0.0)
	_title = Node3D.new()
	_title.position = Vector3(0, 0.62, 0)
	_cap.add_child(_title)


func _label(px: int, at: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font_size = px
	l.pixel_size = 0.001
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = Color(1.0, 0.95, 0.86, 1.0)
	l.no_depth_test = true
	l.render_priority = 95
	l.outline_render_priority = 94
	l.shaded = false
	l.double_sided = false
	l.position = at
	l.text = ""
	_cap.add_child(l)
	return l


func _place_caption(delta: float, snap := false) -> void:
	## Lazily head-locked: it waits low in front of you and follows when you turn away.
	var cam := _view_cam()
	if cam == null:
		return
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.05:
		return
	f = f.normalized()
	var eye := cam.global_position
	var cur := _cap.global_position - eye
	cur.y = 0.0
	var dir := f
	if not snap and cur.length() > 0.05:
		var c := cur.normalized()
		var ang := c.signed_angle_to(f, Vector3.UP)
		dir = c.rotated(Vector3.UP, ang * minf(1.0, delta * (3.0 if absf(ang) > 0.45 else 0.6)))
	_cap.global_position = eye + dir * CAPTION_DIST + Vector3(0, -0.42, 0)
	_cap.global_rotation = Vector3(-0.25, atan2(-dir.x, -dir.z), 0)


func _say(speaker: String, text: String) -> void:
	if _cap_fade and _cap_fade.is_valid():
		_cap_fade.kill()  # a fade of the last line must not blank this one
	_speaker = speaker
	_words = text.split(" ", false)
	_word_i = 0
	_word_t = 0.0
	_cap_name.text = NAME[speaker]
	_cap_name.modulate = NAME_COL[speaker]
	_cap_text.text = ""
	_cap_text.outline_modulate.a = 0.85
	_cap_name.outline_modulate.a = 0.85
	_cap_text.modulate = Color(1.0, 0.95, 0.86) if speaker == "narrator" else NAME_COL[speaker].lerp(Color.WHITE, 0.55)
	_cap_hold = 0.0
	create_tween().tween_method(func(a): _cap_mat.set_shader_parameter("alpha", a), float(_cap_mat.get_shader_parameter("alpha")), 0.82, 0.4)


func _step_caption(delta: float) -> void:
	if _word_i < _words.size():
		_word_t -= delta
		if _word_t <= 0.0:
			var w := _words[_word_i]
			_word_i += 1
			_cap_text.text = " ".join(_words.slice(0, _word_i))
			_word_t = WORD_GAP * (1.35 if _speaker == "skotos" else 1.0) + (0.32 if w.ends_with(".") or w.ends_with(",") or w.ends_with(":") else 0.0)
			if _word_i % 2 == 1 or _speaker != "narrator":
				_voice(_speaker)
	elif _words.size() > 0:
		_cap_hold += delta
		if _cap_hold > 3.2:
			_words = []
			var tw := create_tween()
			_cap_fade = tw
			tw.tween_method(func(a): _cap_mat.set_shader_parameter("alpha", a), 0.82, 0.0, 0.6)
			tw.parallel().tween_property(_cap_text, "modulate:a", 0.0, 0.6)
			tw.parallel().tween_property(_cap_name, "modulate:a", 0.0, 0.6)
			# the outline fades too: fading only the fill left the words' black outlines behind ("the text turns black")
			tw.parallel().tween_property(_cap_text, "outline_modulate:a", 0.0, 0.45)
			tw.parallel().tween_property(_cap_name, "outline_modulate:a", 0.0, 0.45)


# ------------------------------------------------------------------ sound
func _sound(id: String, at := Vector3.INF, db := 0.0, range_m := 60.0, loop := false) -> Node:
	## The story's own players: the bank's 3D range is a tabletop's (8 m), the story's is a valley's.
	if game == null or game.audio == null or not game.audio.manifest.has(id):
		return null
	var bank: AudioBank = game.audio
	var m: Dictionary = bank.manifest[id]
	var files: Array = m["files"]
	var s := bank._stream(files[_rng.randi_range(0, files.size() - 1)]["file"], loop)
	if s == null:
		return null
	var p: Node
	if at != Vector3.INF:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = range_m
		p3.attenuation_filter_cutoff_hz = 20500.0
		p3.volume_db = db
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = db
		p = p2
	p.set("stream", s)
	p.set("bus", m["bus"])
	p.set("pitch_scale", 1.0 + _rng.randf_range(-float(m.get("vary", 0.0)), float(m.get("vary", 0.0))))
	add_child(p)
	if p is AudioStreamPlayer3D:
		(p as AudioStreamPlayer3D).global_position = at
	if not loop:
		p.finished.connect(p.queue_free)
	p.call("play")
	return p


func _voice(speaker: String) -> void:
	match speaker:
		"maren":
			_sound(VOICE[speaker], world.people[0].global_position + Vector3(0, 1.5, 0), -2.0, 40.0)
		"skotos":
			_sound(VOICE[speaker], Vector3.INF, 2.0)
		_:
			_sound(VOICE[speaker], Vector3.INF, -3.0)


func _set_loops(ids: Array) -> void:
	for id in _loops.keys():
		if not ids.has(id):
			var p: AudioStreamPlayer = _loops[id]
			_loops.erase(id)
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -50.0, 2.0)
			tw.tween_callback(p.queue_free)
	for id in ids:
		if not _loops.has(id):
			var p := _sound(id, Vector3.INF, -50.0, 0.0, true) as AudioStreamPlayer
			if p:
				_loops[id] = p
				create_tween().tween_property(p, "volume_db", 0.0, 2.5)


# ------------------------------------------------------------------ the show
func play() -> void:
	## Runs the whole opening; returns when it ends or is skipped.
	_enter()
	_build_overlay()
	visible = true
	_place_caption(0.0, true)
	_started = true
	await get_tree().process_frame  # the world's first frame (shaders compile) happens under black
	_hint.text = "Hold a pinch to skip the story"
	create_tween().tween_property(_hint, "modulate:a", 0.75, 1.0).set_delay(2.0)
	for ch in CHAPTERS.size():
		if _skipped:
			break
		_start_chapter(ch)
		_fade_to(0.0, 2.2 if ch == 0 else 1.4)
		var length: float = CHAPTERS[ch]["len"]
		while _t < length - 1.4 and not _skipped:
			await get_tree().process_frame
		if ch < CHAPTERS.size() - 1 and not _skipped:
			await _fade_to(1.0, 1.2).finished
	await _fade_to(1.0, 1.0 if not _skipped else 0.6).finished
	_leave()
	finished.emit()


func _fade_to(a: float, seconds: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(_fade_mat, "albedo_color:a", a, seconds)
	return tw


func _start_chapter(i: int) -> void:
	_chapter = i
	_t = 0.0
	_lines_done = 0
	_cued.clear()
	var c: Dictionary = CHAPTERS[i]
	world.set_mood(c["mood"], 0.0)
	_look_yaw = c["look"]
	if _cam:
		_cam.rotation = Vector3(-0.03, deg_to_rad(_look_yaw), 0)
	_set_loops(c["loops"])
	TitleCard.show_over(_title, Vector3.ZERO, c["name"], "", 4.5, 40)
	call("_enter_%d" % (i + 1))


func _process(delta: float) -> void:
	if not _started:
		return
	_t += delta
	_step_skip(delta)
	_place_caption(delta)
	_step_caption(delta)
	if _chapter < 0:
		return
	var lines: Array = CHAPTERS[_chapter]["lines"]
	if _lines_done < lines.size() and _t >= float(lines[_lines_done][0]):
		_say(lines[_lines_done][1], lines[_lines_done][2])
		_lines_done += 1
	call("_tick_%d" % (_chapter + 1), _t)
	if _cam:  # the desktop camera drifts slowly toward the chapter's view, with a breath of sway
		var want := deg_to_rad(_look_yaw) + sin(_t * 0.17) * 0.05
		_cam.rotation.y = lerp_angle(_cam.rotation.y, want, minf(1.0, delta * 0.8))
		var tilt := (_pitch * 0.85 if _aerial else -0.03) + sin(_t * 0.23) * 0.01
		_cam.rotation.x = lerpf(_cam.rotation.x, tilt, minf(1.0, delta * 2.0))
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - delta)
			_cam.rotation += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1) * 0.5) * _shake * 0.03


func _once(key: String, at_t: float) -> bool:
	## True the first frame _t passes at_t in this chapter.
	if _t >= at_t and not _cued.has(key):
		_cued[key] = true
		return true
	return false


func _step_skip(delta: float) -> void:
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)
	if game:
		for h in game._hands:
			if is_instance_valid(h) and h.is_pressing():
				held = true
	if Input.is_key_pressed(KEY_ESCAPE):
		_skipped = true
		return
	if not _armed:
		_armed = not held  # the pinch that pressed Wake is still down: wait for it to let go
		return
	_skip_t = _skip_t + delta if held else maxf(0.0, _skip_t - delta * 2.0)
	if _skip_t > 0.05:
		var n := int(clampf(_skip_t / SKIP_HOLD, 0.0, 1.0) * 10.0)
		_hint.text = "Skipping  " + "■".repeat(n) + "□".repeat(10 - n)
		_hint.modulate.a = 0.95
	elif _hint.text.begins_with("Skipping"):
		_hint.text = "Hold a pinch to skip the story"
	if _skip_t >= SKIP_HOLD:
		_skipped = true


# ------------------------------------------------------------------ I. the island: dawn over the meadow, the village waking
func _enter_1() -> void:
	world.set_mood("predawn", 0.0)
	world.set_mood("dawn", 12.0)
	world.veil_mat.set_shader_parameter("strength", 0.0)
	world.wind = 0.7


func _tick_1(t: float) -> void:
	if _once("morning", 13.0):
		world.set_mood("morning", 16.0)
	if _once("walk", 9.0):  # people go about the morning: water from the well, wood to the fire
		world.people[3].go(StoryWorld.VILLAGE + Vector3(-2.5, 0, 2.7))
		world.people[4].go(StoryWorld.FIRE_AT + Vector3(1.0, 0, 2.2))
		world.people[5].go(StoryWorld.VILLAGE + Vector3(2.0, 0, -6.5))
	if _once("pray", 19.5):
		for i in [0, 1, 2]:
			world.people[i].face(StoryWorld.STATUE_AT)
			world.people[i].set_pose("pray")
	if _once("faith", 26.0):
		world.motes.emitting = true
		_sound("story_rise", Vector3.INF, -6.0)
		create_tween().tween_method(func(v): world.veil_mat.set_shader_parameter("strength", v), 0.0, 1.0, 6.0)


# ------------------------------------------------------------------ II. the forgotten: dusk, the ruined temple in the wood behind you
func _enter_2() -> void:
	world.set_mood("dusk", 0.0)
	world.motes.emitting = false
	world.veil_mat.set_shader_parameter("strength", 0.75)
	world.wind = 1.3
	for p in world.people:
		p.set_pose("idle")
	world.surf.set_shader_parameter("window_glow", 1.4)


func _tick_2(t: float) -> void:
	if _once("rumble", 10.5):
		_sound("story_thunder", Vector3.INF, -12.0)
	if _once("dim", 18.0):
		world.set_mood("curse", 14.0)


# ------------------------------------------------------------------ III. the curse: Skotos rises out of the wood
func _enter_3() -> void:
	world.set_mood("curse", 0.0)
	world.skotos.visible = true
	world.skotos.position.y = StoryWorld.height(StoryWorld.SKOTOS_AT.x, StoryWorld.SKOTOS_AT.z) - 34.0
	world.wind = 2.0


func _tick_3(t: float) -> void:
	if _once("rise", 1.0):
		_sound("story_rise", Vector3.INF, -2.0)
		var tw := create_tween()
		tw.tween_property(world.skotos, "position:y", StoryWorld.height(StoryWorld.SKOTOS_AT.x, StoryWorld.SKOTOS_AT.z) - 3.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(world.skotos_eyes, "light_energy", 4.0, 9.0)
	if _once("thunder1", 6.0):
		_sound("story_thunder", Vector3.INF, -4.0)
	if _once("crack1", 15.0):
		_sound("story_crack", StoryWorld.VILLAGE + Vector3(0, 12, 0), 0.0, 80.0)
		world.veil_mat.set_shader_parameter("crack_at", Vector3(0.3, 0.8, 0.5).normalized())
		create_tween().tween_method(func(v): world.veil_mat.set_shader_parameter("crack", v), 0.0, 0.45, 2.0)
	if _once("crack2", 24.0):
		_sound("story_crack", StoryWorld.VILLAGE + Vector3(0, 12, 0), 0.0, 80.0)
		_sound("story_thunder", Vector3.INF, -2.0)
		create_tween().tween_method(func(v): world.veil_mat.set_shader_parameter("crack", v), 0.45, 0.85, 2.5)
	world.skotos.rotation.y = atan2(-StoryWorld.SKOTOS_AT.x, -StoryWorld.SKOTOS_AT.z) + sin(t * 0.3) * 0.06


# ------------------------------------------------------------------ IV. the fall: the Veil shatters, the dark comes, the roofs burn
func _enter_4() -> void:
	world.set_mood("curse", 0.0)
	world.skotos.visible = true
	world.skotos_eyes.light_energy = 4.0
	world.veil_mat.set_shader_parameter("crack", 0.9)
	world.veil_mat.set_shader_parameter("strength", 0.8)
	world.wind = 2.4


func _tick_4(t: float) -> void:
	if _once("shatter", 1.5):
		_sound("story_shatter", Vector3.INF, 0.0)
		world.shards.restart()
		world.shards.emitting = true
		_sound("story_thunder", Vector3.INF, 0.0)
		# more drama (the user, 2026-11-14): the cracks race over the dome, a blinding white-gold flash, the sky
		# shudders, then the Veil goes out
		var tw := create_tween()
		tw.tween_method(func(v): world.veil_mat.set_shader_parameter("crack", v), 0.9, 1.0, 0.15)
		tw.parallel().tween_method(func(v): world.veil_mat.set_shader_parameter("strength", v), 0.8, 2.5, 0.15)
		tw.tween_interval(0.5)  # hold the blazing, cracked dome a beat before it falls
		tw.tween_method(func(v): world.veil_mat.set_shader_parameter("strength", v), 2.5, 0.0, 2.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		var fl := create_tween()
		fl.tween_property(world.env, "adjustment_brightness", 2.6, 0.08)
		fl.tween_property(world.env, "adjustment_brightness", 1.0, 1.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
		_shake = 0.6
	if _once("beasts", 4.0):
		world.release_beasts()
		for i in range(1, world.people.size()):  # they run for their doors
			var h: Dictionary = world.houses[i % world.houses.size()]
			world.people[i].go(h["door"], "flee", 3.2)
		world.people[0].go(StoryWorld.VILLAGE + Vector3(0, 0, 0.8), "walk", 1.0)
	if _once("doors", 9.5):
		world.surf.set_shader_parameter("window_glow", 0.35)  # shutters closing
		_sound("story_thunder", Vector3.INF, -6.0)
	if _once("camp_out", 12.0):
		for g in world.camp:
			g.emitting = false


# ------------------------------------------------------------------ V. your turn: the shades wait at the edge; Maren prays to you, and dawn drives them back
func _enter_5() -> void:
	world.set_mood("curse", 0.0)
	world.set_mood("dawn", 14.0)
	world.hourglass.visible = false
	world.skotos.visible = false
	world.scorch = 0.0
	world.clock_rate = 1.0
	world.veil_mat.set_shader_parameter("crack", 0.9)
	world.veil_mat.set_shader_parameter("strength", 0.0)
	world.wind = 0.8
	# You stand in the village square, a few steps in front of your own statue (the user, 2026-11-14: "take us to the
	# center of the village, near where the statue is"). The world moves, not you, so this works in the headset too;
	# the chapter starts under black, so the jump is never seen.
	var stand := StoryWorld.VILLAGE + Vector3(-0.4, 0, 9.0)  # back far enough to see the whole shrine
	world.position = -Vector3(stand.x, StoryWorld.height(stand.x, stand.z), stand.z)
	_stand = stand
	var statue := StoryWorld.STATUE_AT
	for i in world.people.size():
		var p: StoryPerson = world.people[i]
		if i == 0:  # Maren kneels at the statue's feet, her back to you, praying to it and so to you
			var m := StoryWorld.VILLAGE + Vector3(0.1, 0, 0.1)
			p.place(Vector3(m.x, StoryWorld.height(m.x, m.z), m.z), 0.0)
			p.face(statue)
			continue
		if i in [1, 2, 5]:  # a few have come out to the square and stand with her (standing: the kneel reads badly side-on)
			var g := StoryWorld.VILLAGE + Vector3([-2.4, 2.3, 3.3][[1, 2, 5].find(i)], 0, [0.9, 1.2, 0.0][[1, 2, 5].find(i)])  # beside her, not in your view
			p.place(Vector3(g.x, StoryWorld.height(g.x, g.z), g.z), 0.0)
			p.face(statue)
			p.set_pose("idle")
			continue
		if i == 3:  # one watches from a doorway; the rest are still indoors
			p.set_pose("idle")
			var h: Dictionary = world.houses[2]
			p.place(h["door"], 0.0)
			p.face(statue)
		else:
			p.visible = false


func _tick_5(t: float) -> void:
	if _once("kneel", 2.0):
		world.people[0].set_pose("pray")
	if _once("dawn_back", 9.0):  # the light returns and the shades slink back into the wood
		world.recall_beasts()
		create_tween().tween_method(func(v): world.veil_mat.set_shader_parameter("strength", v), 0.0, 0.9, 8.0)
		create_tween().tween_method(func(v): world.veil_mat.set_shader_parameter("crack", v), 0.9, 0.0, 8.0)
	if _once("faith", 13.0):
		world.motes.emitting = true
		_sound("story_rise", Vector3.INF, -8.0)
	if _once("morning", 16.0):
		world.set_mood("morning", 12.0)
	# While the narrator explains your job, rise above the village and circle it slowly, then sink back to the square
	# (the user, 2026-11-14). The world turns under you, so the headset works too; black hides both jumps.
	if _once("up_fade", 16.4):
		_fade_to(1.0, 0.6)
	if _once("up", 17.0):
		_aerial = true
		_fade_to(0.0, 1.2)
	if _once("down_fade", 35.6):
		_fade_to(1.0, 0.6)
	if _once("down", 36.2):
		_aerial = false
		world.rotation.y = 0.0
		world.position = -Vector3(_stand.x, StoryWorld.height(_stand.x, _stand.z), _stand.z)
		_fade_to(0.0, 1.2)
	if _aerial:
		var k := clampf((t - 17.0) / 19.0, 0.0, 1.0)
		var a := (t - 17.0) * AERIAL_TURN
		var h := lerpf(AERIAL_HIGH, AERIAL_LOW, smoothstep(0.0, 1.0, k))  # from high above, down among the roofs
		var r := lerpf(AERIAL_FAR, AERIAL_NEAR, smoothstep(0.0, 1.0, k))
		var c := StoryWorld.VILLAGE
		c.y = StoryWorld.height(c.x, c.z)
		world.rotation.y = a
		world.position = Vector3(0, -h, -r) - world.basis * c
		_pitch = -atan2(h, r)
