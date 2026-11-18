extends "res://scripts/game/input_replay.gd"
## A scripted seated player for testing in VR without a headset (2026-11-18, Siddharth: "test VR like a human would").
##
## It drives the SAME objects OpenXR drives on the Quest (the controller trackers "left_hand"/"right_hand", the
## XRHandTrackers, the head camera), so the game runs its real XR code: GameHand pinch hysteresis and debounce, the
## one-euro pose filter, reach radii, tray/card/rim/villager grabs. Nothing in the game is called directly.
##
## How it is human:
##   - the head: the real seated head of a Quest recording (position and its small sway), turned to look at what the
##     hand is going for, at a human neck speed;
##   - reaches: minimum-jerk movement, longer for further targets (Fitts), landing with a few mm to ~1 cm of aim error
##     and a small physiological tremor;
##   - pinches: the trigger value ramps closed over ~0.1 s and open again, crossing the runtime's click thresholds;
##   - the hand shape: with `joints` on, the 26 joints are the recorded open/pinch/fist hands from the Quest
##     (HandFallbackPose), so pinch strength, the drawn pinch point and palm-up all come from real hand geometry.
##     With `joints` off it is the mode the Quest sent most of the time in the 11-17 recording (aim pose, no joints).
## It cannot judge: lens optics, real MSDF sharpness in the headset, comfort, how heavy things feel.

const HandPose := preload("res://scripts/game/hand_fallback_pose.gd")

var game: Node
var origin: Node3D
var joints := true
var aim_error := 0.006  # m, 1 sigma per axis, where a reach lands around its target
var tremor := 0.0015  # m
var head_rec_t := 120.0  # where in the recording the head is taken from (it plays on from there, for the sway)
var look_target := Vector3.INF
var head_offset := Vector3.ZERO  # stress tests: leaning, standing up (origin space, m)
var lost := {}  # stress tests: side -> true while that hand's tracking is gone
var log_lines: PackedStringArray = []
var rng := RandomNumberGenerator.new()

var _clock := 0.0
var _head_yaw := 0.0
var _head_pitch := -0.55
var _h := {}  # side -> state


func _init() -> void:
	rng.seed = 18112026
	for side in HANDS:
		_h[side] = {"pos": Vector3.ZERO, "from": Vector3.ZERO, "to": Vector3.ZERO, "t": 1.0, "dur": 0.0, "trig": 0.0,
			"trig_to": 0.0, "click": false, "grip": 0.0, "palm_up": false, "shown": true, "placed": false}


func attach(g: Node) -> void:
	game = g
	origin = g._xr_origin
	install(g._xr_cam)
	for side in HANDS:
		_h[side]["pos"] = rest_point(side)
		_h[side]["to"] = _h[side]["pos"]
		_h[side]["placed"] = true


func note(s: String) -> void:
	var line := "[%6.2f] %s" % [_clock, s]
	log_lines.append(line)
	print("VRH ", line)


# ---- where things are -------------------------------------------------------------------------------------------

func head_transform() -> Transform3D:
	var base: Transform3D = sample(head_rec_t + _clock * 0.0)["head"] if _count > 0 else Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))
	var sway: Vector3 = Vector3.ZERO
	if _count > 0:
		var tt := fposmod(head_rec_t + _clock, maxf(duration - 1.0, 1.0))
		sway = (sample(tt)["head"].origin - base.origin).limit_length(0.03)  # the recorded small head motion, not its big moves
	var o: Vector3 = base.origin + sway + head_offset
	return Transform3D(Basis.from_euler(Vector3(_head_pitch, _head_yaw, 0.0)), o)


func eye_world() -> Vector3:
	return origin.global_transform * head_transform().origin


func rest_point(side: String) -> Vector3:
	## Hands resting low, near the body, as a seated player does between actions.
	var ht := head_transform()
	var fwd := Vector3(-sin(_head_yaw), 0, -cos(_head_yaw))
	var right := Vector3(cos(_head_yaw), 0, -sin(_head_yaw))
	var local := ht.origin + Vector3(0, -0.42, 0) + fwd * 0.22 + right * (0.17 if side == "right" else -0.17)
	return origin.global_transform * local


# ---- actions (await them) ---------------------------------------------------------------------------------------

func reach(side: String, world: Vector3, exact := false, dur := -1.0) -> void:
	var s: Dictionary = _h[side]
	var target := world
	if not exact:
		target += Vector3(rng.randfn(0.0, aim_error), rng.randfn(0.0, aim_error * 0.7), rng.randfn(0.0, aim_error))
	var d: float = (s["pos"] as Vector3).distance_to(target)
	s["from"] = s["pos"]
	s["to"] = target
	s["t"] = 0.0
	s["dur"] = dur if dur > 0.0 else clampf(0.25 + 0.16 * log(1.0 + d / 0.01) / log(2.0), 0.25, 1.3)  # Fitts' law
	look_target = world
	while float(s["t"]) < 1.0:
		await get_tree().process_frame
	await hold(0.06)  # a short settle, as a hand does before it pinches


func reach_node(side: String, n: Node3D, offset := Vector3.ZERO) -> void:
	## Reach for something that may be moving (a walking villager): the hand homes in on where it is now.
	var err := Vector3(rng.randfn(0.0, aim_error), rng.randfn(0.0, aim_error * 0.7), rng.randfn(0.0, aim_error))
	_h[side]["follow"] = [n, offset + err]
	await reach(side, n.global_position + offset + err, true)
	_h[side]["follow"] = null


func tap_node(side: String, n: Node3D, offset := Vector3.ZERO) -> void:
	await reach_node(side, n, offset)
	await pinch(side, true)
	await hold(0.12)
	await pinch(side, false)


func move_with(side: String, world: Vector3, dur := 0.7) -> void:
	## A deliberate drag while pinching: no aim error, slower.
	await reach(side, world, true, dur)


func pinch(side: String, on: bool) -> void:
	_h[side]["trig_to"] = 1.0 if on else 0.0
	await hold(0.28 if on else 0.18)  # the fingers close (or open), then the game's PRESS_HOLD (0.2 s) / release debounce run


func hold(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()


func tap(side: String, world: Vector3) -> void:
	await reach(side, world)
	await pinch(side, true)
	await hold(0.12)
	await pinch(side, false)


func drag(side: String, from: Vector3, to: Vector3, dur := 0.8) -> void:
	await reach(side, from)
	await pinch(side, true)
	await hold(0.1)
	await move_with(side, to, dur)
	await hold(0.1)
	await pinch(side, false)


func rest(side: String) -> void:
	await reach(side, rest_point(side), true, 0.5)


func palm_up(side: String, on: bool) -> void:
	_h[side]["palm_up"] = on
	if on:
		await reach(side, origin.global_transform * (head_transform().origin + Vector3(0, -0.30, 0)) + Vector3(-sin(_head_yaw), 0, -cos(_head_yaw)) * 0.30, true, 0.6)
	await hold(1.0 if on else 0.2)


func look(world: Vector3) -> void:
	look_target = world
	await hold(0.5)


func hand_point(side: String) -> Vector3:
	return _h[side]["pos"]


# ---- per frame --------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if origin == null or not is_instance_valid(origin):
		return
	var dt := fixed_dt * speed if fixed_dt > 0.0 else delta
	_clock += dt
	_tick_head(dt)
	for side in HANDS:
		_tick_hand(side, dt)


func _tick_head(dt: float) -> void:
	if look_target != Vector3.INF:
		var eye := eye_world()
		var v := origin.global_transform.basis.inverse() * (look_target - eye)
		var want_yaw := atan2(-v.x, -v.z)
		var want_pitch := clampf(atan2(v.y, Vector2(v.x, v.z).length()) * 0.8, -1.0, 0.2)  # eyes do the last part
		var k := 1.0 - exp(-dt * 5.0)
		_head_yaw = lerp_angle(_head_yaw, want_yaw, k)
		_head_pitch = lerpf(_head_pitch, want_pitch, k)
	if head_node != null and is_instance_valid(head_node):
		head_node.transform = head_transform()


func _tick_hand(side: String, dt: float) -> void:
	var s: Dictionary = _h[side]
	var fol = s.get("follow")
	if fol != null and is_instance_valid(fol[0]):
		s["to"] = (fol[0] as Node3D).global_position + fol[1]
		look_target = s["to"]
	if float(s["t"]) < 1.0:
		s["t"] = minf(float(s["t"]) + dt / maxf(float(s["dur"]), 0.01), 1.0)
		var u: float = s["t"]
		var mj := u * u * u * (10.0 - 15.0 * u + 6.0 * u * u)  # minimum-jerk profile
		s["pos"] = (s["from"] as Vector3).lerp(s["to"], mj)
	var p: Vector3 = s["pos"] + Vector3(sin(_clock * 51.0 + 1.3), sin(_clock * 47.0), cos(_clock * 43.0 + 0.7)) * tremor
	var step := dt / 0.10
	s["trig"] = move_toward(float(s["trig"]), float(s["trig_to"]), step)
	var trig: float = s["trig"]
	if not bool(s["click"]) and trig >= 0.85:
		s["click"] = true
	elif bool(s["click"]) and trig <= 0.55:
		s["click"] = false
	var inv: Transform3D = origin.global_transform.affine_inverse()
	var p_local: Vector3 = inv * p
	var shoulder_local := head_transform().origin + Vector3(0, -0.25, 0) + Vector3(cos(_head_yaw), 0, -sin(_head_yaw)) * (0.18 if side == "right" else -0.18)
	var dir := (p_local - shoulder_local)
	if dir.length() < 0.05:
		dir = Vector3(0, -0.3, -1)
	var aim_b := Basis.looking_at(dir.normalized(), Vector3.UP)
	var aim_q: Quaternion = HandPose.RIGHT_AIM_Q if side == "right" else HandPose.LEFT_AIM_Q
	var aim_o: Vector3 = HandPose.RIGHT_AIM if side == "right" else HandPose.LEFT_AIM
	var aig := Transform3D(Basis(aim_q), aim_o)  # the aim pose in grip space
	var grip_b: Basis = aim_b * aig.basis.inverse()
	var shape := _shape(side, trig, float(s["grip"]))
	if bool(s["palm_up"]):
		# turn the hand over until its palm (measured the way the game measures it, from the joints) faces up
		var pts0: Array = shape[0]
		var n_g: Vector3 = (pts0[22] - pts0[7]).cross(pts0[12] - pts0[1])
		if side == "right":
			n_g = -n_g
		var n_w: Vector3 = (grip_b * n_g).normalized()
		var ax := n_w.cross(Vector3.UP)
		if ax.length() > 0.0001:
			grip_b = Basis(ax.normalized(), n_w.angle_to(Vector3.UP)) * grip_b
		elif n_w.y < 0.0:
			grip_b = Basis(Vector3.FORWARD, PI) * grip_b
	var grip_t: Transform3D
	if joints:
		var mid: Vector3 = (shape[0][5] + shape[0][10]) * 0.5  # the drawn pinch point (thumb tip, index tip) in grip space
		grip_t = Transform3D(grip_b, p_local - grip_b * mid)
	else:
		grip_t = Transform3D(grip_b, p_local - grip_b * aim_o)
	var aim_t: Transform3D = grip_t * aig
	var tr: XRPositionalTracker = _trackers.get(side)
	if tr == null:
		return
	if lost.get(side, false):
		tr.invalidate_pose(&"aim")
		tr.invalidate_pose(&"grip")
		var lh: XRHandTracker = _hand_trackers.get(side)
		if lh:
			lh.has_tracking_data = false
		return
	tr.profile = HAND_PROFILE if joints else TOUCH_PROFILE
	tr.set_pose(&"aim", aim_t, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tr.set_pose(&"grip", grip_t, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	tr.set_input(&"trigger", trig)
	tr.set_input(&"grip", float(s["grip"]))
	var key := side + "|trigger_click"
	if bool(s["click"]) != bool(_last_bool.get(key, false)):
		_last_bool[key] = s["click"]
		tr.set_input(&"trigger_click", s["click"])
	var ht: XRHandTracker = _hand_trackers.get(side)
	if ht == null:
		return
	if joints:
		var pts: Array = shape[0]
		var pq: Quaternion = shape[1]
		for j in JOINTS:
			var jt := grip_t * Transform3D(Basis(pq) if j == 0 else Basis.IDENTITY, pts[j])
			ht.set_hand_joint_transform(j, jt)
			ht.set_hand_joint_flags(j, FLAGS_TRACKED)
			ht.set_hand_joint_radius(j, float(GodHandVisual.FALLBACK_RADII[j]))
		ht.has_tracking_data = true
	else:
		ht.has_tracking_data = false


func _shape(side: String, trig: float, grip: float) -> Array:
	var r := side == "right"
	var open: Array = HandPose.RIGHT_OPEN if r else HandPose.LEFT_OPEN
	var pin: Array = HandPose.RIGHT_PINCH if r else HandPose.LEFT_PINCH
	var fist: Array = HandPose.RIGHT_FIST if r else HandPose.LEFT_FIST
	var wt := smoothstep(0.1, 0.9, trig)
	var wg := smoothstep(0.1, 0.9, grip)
	var q: Quaternion = (HandPose.RIGHT_OPEN_PALM if r else HandPose.LEFT_OPEN_PALM).slerp(HandPose.RIGHT_PINCH_PALM if r else HandPose.LEFT_PINCH_PALM, wt)
	var pts: Array = []
	for i in JOINTS:
		pts.append((open[i] as Vector3).lerp(pin[i], wt).lerp(fist[i], wg))
	return [pts, q]
