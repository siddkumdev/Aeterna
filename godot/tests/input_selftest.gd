extends RefCounted
## Checks for the headset input layer (2026-11-18 overnight run): the recording replay driver (InputReplay), the
## always-visible god hand (GodHandVisual fallback), the pinch debounce (GameHand) and the palm direction. Called from
## game_selftest.gd:  await load("res://tests/input_selftest.gd").run(self)
## Everything is synthetic or built from the recorded hand templates; no recording file is needed.

const InputReplay := preload("res://scripts/game/input_replay.gd")
const Pose := preload("res://scripts/game/hand_fallback_pose.gd")
const DT := 1.0 / 72.0


static func run(t) -> void:
	GameConfig.FORCE_XR = true
	_palm(t)
	await _replay_and_hands(t)
	await _palm_through_game(t)
	GameConfig.FORCE_XR = false
	GameHand.debounce = true


# ---- synthetic recording ---------------------------------------------------------------------------------

static func _joints_at(grip: Transform3D, side: String, pose: String) -> Array:
	var tpl: Array = (Pose.new().get_script() as Script).get_script_constant_map()["%s_%s" % [side.to_upper(), pose.to_upper()]]
	var out: Array = []
	for p in tpl:
		out.append(grip * (p as Vector3))
	return out


static func _quat_to_floats(b: PackedFloat32Array, q: Quaternion) -> void:
	b.append(q.x); b.append(q.y); b.append(q.z); b.append(q.w)


static func _hand_floats(b: PackedFloat32Array, h: Dictionary) -> void:
	var grip: Transform3D = h.get("grip", Transform3D(Basis.IDENTITY, Vector3(0.1, 1.0, -0.4)))
	var ok: bool = h.get("pose_ok", true)
	var q := grip.basis.get_rotation_quaternion()
	for k in 2:  # aim, then grip pose (the same transform: only the validity matters here)
		b.append(1.0 if ok else 0.0)
		b.append(grip.origin.x); b.append(grip.origin.y); b.append(grip.origin.z)
		_quat_to_floats(b, q)
	b.append(float(h.get("trig", 0.0)))
	b.append(float(h.get("grip_val", 0.0)))
	b.append(0.0)  # trigger_click: the events file carries the booleans
	b.append(0.0)
	var tracked: bool = h.get("tracked", false)
	b.append(1.0 if tracked else 0.0)
	var jp: Array = h.get("joints", [])
	for j in InputReplay.JOINTS:
		var p: Vector3 = jp[j] if tracked and j < jp.size() else Vector3.ZERO
		b.append(p.x); b.append(p.y); b.append(p.z)
		_quat_to_floats(b, Quaternion.IDENTITY)


static func make(seconds: float, head: Vector3, left: Dictionary, right: Dictionary, events: Array) -> InputReplay:
	var floats := PackedFloat32Array()
	var n := int(seconds * 36.0) + 1
	for i in n:
		floats.append(i / 36.0)
		floats.append(head.x); floats.append(head.y); floats.append(head.z)
		_quat_to_floats(floats, Quaternion.IDENTITY)
		_hand_floats(floats, left)
		_hand_floats(floats, right)
	var rp := InputReplay.new()
	var header := {"frame_floats": 1 + 7 + InputReplay.PER_HAND * 2, "rate_hz": 36.0}
	if not rp.load_floats(header, floats, events):
		return null
	return rp


static func _ev(kind: String, hand: String, input: String, at: float) -> Dictionary:
	return {"kind": kind, "hand": hand, "input": input, "t": at}


# ---- palm direction (fix C) ---------------------------------------------------------------------------------

static func _palm_normal(tpl: Array) -> Vector3:
	## The same formula as Game.palm_pose (left hand): (little base - index base) x (middle base - wrist).
	return ((tpl[22] as Vector3) - (tpl[7] as Vector3)).cross((tpl[12] as Vector3) - (tpl[1] as Vector3)).normalized()


static func _palm(t) -> void:
	var fist: Array = Pose.LEFT_FIST
	var n := _palm_normal(fist)
	# recorded fingers curl TOWARD the palm: in a fist the middle fingertip lies on the +n side of its knuckle, so n leaves the palm
	t.check("palm normal formula leaves the palm (recorded left fist: curled fingertip on the +n side)", ((fist[15] as Vector3) - (fist[12] as Vector3)).dot(n) > 0.02)
	var open: Array = Pose.LEFT_OPEN
	var no := _palm_normal(open)
	t.check("palm normal also leaves the palm in the recorded open left hand (fingertip beyond the knuckle plane is level, curl test on the fist is the sign)", no.dot(n) > 0.8)


static func _palm_through_game(t) -> void:
	## A left palm held up (recorded open-hand template turned so its palm normal points up) opens the ledger path:
	## Game.palm_pose reads it as facing up; turned over it reads down.
	var g: Game = load("res://scripts/game/game.gd").new()
	t.root.add_child(g)
	await t.process_frame
	var n := _palm_normal(Pose.LEFT_OPEN)
	var up_q := Quaternion(n, Vector3.UP)
	var up_grip := Transform3D(Basis(up_q), Vector3(0.0, 0.9, -0.3))
	var down_grip := Transform3D(Basis(Quaternion(n, Vector3.DOWN)), Vector3(0.0, 0.9, -0.3))
	var rp: InputReplay = make(1.0, Vector3(0, 1.3, 0), {"tracked": true, "grip": up_grip, "joints": _joints_at(up_grip, "left", "open")}, {}, [])
	t.root.add_child(rp)
	rp.install(g._xr_cam)
	rp.apply(0.3)
	var pp: Array = g.palm_pose()
	t.check("recorded-hand palm up: palm_pose found and its normal points up", bool(pp[0]) and (pp[2] as Vector3).dot(Vector3.UP) > 0.95)
	# the same open hand rotated palm down
	var rp2: InputReplay = make(1.0, Vector3(0, 1.3, 0), {"tracked": true, "grip": down_grip, "joints": _joints_at(down_grip, "left", "open")}, {}, [])
	t.root.add_child(rp2)
	rp.uninstall()  # one replay owns the tracker names at a time
	rp2.install(g._xr_cam)
	rp2.apply(0.3)
	pp = g.palm_pose()
	t.check("recorded-hand palm down: palm_pose normal points down", bool(pp[0]) and (pp[2] as Vector3).dot(Vector3.UP) < -0.95)
	t.check("palm-up opening thresholds from the 11-17 recording (dot 0.65, hold 0.6 s: his tries peaked at 0.6-0.94 s)", is_equal_approx(GameConfig.PALM_UP_OPEN, 0.65) and is_equal_approx(GameConfig.PALM_UP_HOLD, 0.6))
	rp.queue_free()
	rp2.queue_free()
	g.queue_free()
	await t.process_frame


# ---- replay, fallback hand, debounce -----------------------------------------------------------------------

static func _rig(t) -> Dictionary:
	var origin := XROrigin3D.new()
	t.root.add_child(origin)
	var hands := {}
	for side in ["left", "right"]:
		var h := GameHand.new()
		h.tracker = StringName(side + "_hand")
		h.pose = &"aim"
		origin.add_child(h)
		hands[side] = h
	return {"origin": origin, "hands": hands}


static func _log(h: GameHand) -> Dictionary:
	var log := {"pressed": 0, "released": 0, "cancelled": 0}
	h.pressed.connect(func(_x): log["pressed"] += 1)
	h.released.connect(func(_x): log["released"] += 1)
	h.cancelled.connect(func(_x): log["cancelled"] += 1)
	return log


## Plays a recording through the rig from `from` to `to` in DT steps, stepping the hand node by hand too.
static func _play(rp: InputReplay, rig: Dictionary, from: float, to: float) -> void:
	var tt := from
	while tt < to:
		rp.apply(tt)
		for side in rig["hands"]:
			var h: GameHand = rig["hands"][side]
			h._process(DT)
			if h.visual != null:
				h.visual._process(DT)
		tt += DT


static func _replay_and_hands(t) -> void:
	var events := [
		_ev("press", "right", "trigger_click", 0.30), _ev("release", "right", "trigger_click", 0.80),  # one clean press
		_ev("press", "right", "trigger_click", 1.20), _ev("release", "right", "trigger_click", 1.50),  # flaps: released ...
		_ev("press", "right", "trigger_click", 1.55), _ev("release", "right", "trigger_click", 2.00),  # ... and back 50 ms later
		_ev("press", "right", "trigger_click", 2.50), _ev("release", "right", "trigger_click", 2.52),  # a 20 ms spike
		_ev("press", "right", "trigger_click", 3.00), _ev("release", "right", "trigger_click", 3.30),  # a slow re-press ...
		_ev("press", "right", "trigger_click", 3.60), _ev("release", "right", "trigger_click", 3.90),  # ... 300 ms later: two presses
		_ev("press", "right", "trigger_click", 4.30), _ev("release", "right", "trigger_click", 4.32),  # a 20 ms tap on a controller
	]
	var rp := make(4.5, Vector3(0, 1.3, 0), {"pose_ok": false}, {"trig": 0.0}, events)
	t.check("replay: synthetic recording loads (frames, duration)", rp != null and rp.frame_count() == 163 and absf(rp.duration - 4.5) < 0.05)
	t.root.add_child(rp)
	var rig := _rig(t)
	rp.install(null)
	await t.process_frame
	await t.process_frame
	var hr: GameHand = rig["hands"]["right"]
	var log := _log(hr)

	# sampling and seek
	var s1 := rp.sample(0.31)
	var s2 := rp.sample(0.31)
	t.check("replay: sampling is deterministic", (s1["head"] as Transform3D).is_equal_approx(s2["head"]))
	t.check("replay: press edge from the events file (pressed at 0.31, not at 0.29, released after 0.8)", rp.sample(0.31)["hands"]["right"]["trigger_click"] and not rp.sample(0.29)["hands"]["right"]["trigger_click"] and not rp.sample(0.81)["hands"]["right"]["trigger_click"])
	rp.apply(0.1)
	t.check("replay: the tracker receives the recorded pose (right hand at 0.1, 1.0, -0.4)", hr.global_position.distance_to(Vector3(0.1, 1.0, -0.4)) < 0.001)

	# clean press: pressed the moment it starts (no latency), released once the debounce passed
	_play(rp, rig, 0.0, 0.34)
	t.check("pinch: the first press arrives with no debounce latency", log["pressed"] == 1 and log["released"] == 0)
	_play(rp, rig, 0.34, 0.86)
	t.check("pinch: the release is held back while it could still be a flap", log["released"] == 0 and hr.is_press_continuing() and not hr.is_pressing())
	_play(rp, rig, 0.86, 0.95)
	t.check("pinch: a clean release arrives after the debounce window", log["pressed"] == 1 and log["released"] == 1 and not hr.is_pressing())

	# flap: release 50 ms before the re-press -> one continuous press
	_play(rp, rig, 0.95, 2.25)
	t.check("pinch: a release re-pressed within 100 ms stays one press (no grab-drop-grab)", log["pressed"] == 2 and log["released"] == 1 + 1 and hr.merged_presses == 1)
	# spike: 20 ms press -> cancelled, never played
	rp.untracked_as_hand = true  # this press comes from a hand-tracking pinch (hand profile), not a controller
	_play(rp, rig, 2.25, 2.85)
	rp.untracked_as_hand = false
	t.check("pinch: a 20 ms spike is cancelled, not played", log["pressed"] == 3 and log["cancelled"] == 1 and log["released"] == 2 and hr.spike_cancels == 1)
	# slow re-press (300 ms gap) is two real presses
	_play(rp, rig, 2.85, 4.2)
	t.check("pinch: presses 300 ms apart stay separate", log["pressed"] == 5 and log["released"] == 4)

	# the same 20 ms tap on a real controller is a real tap: played, not cancelled
	_play(rp, rig, 4.2, 4.48)
	t.check("pinch: a quick tap on a controller is still released (spike cancel is for hand pinches only)", log["pressed"] == 6 and log["released"] == 5 and log["cancelled"] == 1 and hr.spike_cancels == 1)

	# the old behaviour for comparison (and for the mouse hand): no debounce at all
	GameHand.debounce = false
	var hl: GameHand = rig["hands"]["left"]
	var log_off := _log(hr)
	rp.seek(0.0)
	await t.process_frame
	_play(rp, rig, 1.0, 2.1)
	t.check("pinch debounce off: the flap is two separate presses again", log_off["pressed"] == 2 and log_off["released"] == 2)
	GameHand.debounce = true

	rp.seek(0.5)
	hr._process(DT)
	rp.seek(0.805)
	hr._process(DT)
	t.check("is_pressing is the raw state: false as soon as the fingers let go (two-hand zoom must not see a just-released hand)", not hr.is_pressing() and hr.is_press_continuing())
	_play(rp, rig, 0.81, 0.95)
	# the released card must not follow the opening fingers: touch point frozen while the release is debounced
	rp.seek(0.5)
	hr._process(DT)  # pressed
	rp.seek(0.805)
	hr._process(DT)  # release begins
	var frozen := hr.touch_point()
	hr.global_position += Vector3(0.1, 0.0, 0.0)  # the fingers open and the hand drifts
	t.check("pinch: touch_point stays where the pinch was during the debounce window", hr.is_press_continuing() and hr.touch_point().distance_to(frozen) < 1e-6)
	_play(rp, rig, 0.81, 0.95)

	# hands always visible (fix A): untracked hand with a pose draws a hand, no pose draws nothing; tracked draws the joints
	await t.process_frame
	await t.process_frame
	t.check("god hand: the right hand node got its visual", hr.visual != null and is_instance_valid(hr.visual))
	if hr.visual != null:
		rp.apply(0.2)
		_play(rp, rig, 0.2, 0.28)
		t.check("god hand: untracked (controller) hand with a pose is drawn at the grip pose", hr.visual.fallback and hr.visual.visible and not hr.visual.tracked and hr.visual._bones.visible and not hr.visual._orb.visible)
		var open_pinch: float = hr.visual.pinch_strength
		t.check("god hand: fallback hand is open without trigger/grip (thumb-index gap wide)", open_pinch < 0.3)
		hr.visual.fallback_joints(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), 1.0, 0.0)
		hr.visual._pose()
		t.check("god hand: fallback hand pinches when the trigger is squeezed", hr.visual.pinch_strength > 0.8)
		hr.visual.fallback_joints(Transform3D(Basis.IDENTITY, Vector3(0, 1, 0)), 0.0, 1.0)
		var tip_open: float = ((Pose.RIGHT_OPEN[15] as Vector3) - (Pose.RIGHT_OPEN[1] as Vector3)).length()
		var tip_fist: float = (hr.visual._joints[15].origin - hr.visual._joints[1].origin).length()
		t.check("god hand: fallback fist curls the fingers (recorded fingertip nearer the wrist)", tip_fist < tip_open * 0.85)
	var hl_visual: GodHandVisual = hl.visual
	if hl_visual != null:
		_play(rp, rig, 0.2, 0.4)
		t.check("god hand: no pose at all (left hand untracked, no controller pose) draws no fallback hand", not hl_visual.fallback and hl_visual.fallback_grip_pose() == null)
	# tracked joints win over the fallback
	var grip := Transform3D(Basis.IDENTITY, Vector3(0.2, 1.0, -0.4))
	rp.uninstall()
	var rp3 := make(1.0, Vector3(0, 1.3, 0), {}, {"tracked": true, "grip": grip, "joints": _joints_at(grip, "right", "pinch")}, [])
	t.root.add_child(rp3)
	rp3.install(null)
	for side in rig["hands"]:  # the visuals cache their hand tracker: point them at the new one
		if (rig["hands"][side] as GameHand).visual != null:
			(rig["hands"][side] as GameHand).visual._tracker = null
	_play(rp3, rig, 0.2, 0.4)
	if hr.visual != null:
		t.check("god hand: tracked joints are drawn instead of the fallback", hr.visual.tracked and not hr.visual.fallback)
		t.check("god hand: tracked recorded pinch reads as a pinch (joint distance)", hr.visual.pinch_strength > 0.8)
	rp3.queue_free()
	rp.queue_free()
	(rig["origin"] as Node).queue_free()
	await t.process_frame
