extends Node
## Plays an InputRecorder recording (godot/scripts/game/input_recorder.gd, tools/rec_read.py) back into the game as the
## input the game reads in the headset, with no headset (2026-11-18, overnight run, Siddharth delegated).
##
## What it feeds (the same objects OpenXR would feed):
##   - XRPositionalTracker "left_hand" / "right_hand": poses "aim" and "grip", inputs trigger, grip (floats) and
##     trigger_click, grip_click, ax_button, by_button, menu_button, select_button (bools; XRController3D turns them into
##     button_pressed / button_released, which GameHand reads). Bools come from the events file when there is one (exact
##     press times; the 36 Hz frames would miss a 20 ms spike), else from the frames.
##   - XRHandTracker "/user/hand_tracker/left" / ".../right": the 26 joints (when hand_tracked), radii from the
##     hand_radii event, flags, has_tracking_data.
##   - the head: head_node.transform (the XRCamera3D under the XROrigin3D, or any Node3D).
## The game needs its XR rig without OpenXR: set GameConfig.FORCE_XR = true BEFORE creating the Game.
## Time: `speed` scales it, seek(t) jumps, `fixed_dt` > 0 makes every _process advance exactly fixed_dt * speed (deterministic
## with --fixed-fps), step(dt) advances by hand (tests). The recording's space is XR tracking space (m, Y up).
## Untracked frames: the controller tracker's profile is a touch controller (a hand profile would make the game treat an
## untracked hand as lost), unless `untracked_as_hand` is set; tracked frames use the hand-interaction profile.

signal ended

const MAGIC := "AETREC01"
const JOINTS := 26
const HANDS := ["left", "right"]
const BUTTONS := ["trigger_click", "grip_click", "ax_button", "by_button", "menu_button", "select_button"]
const PER_HAND := 1 + 7 + 1 + 7 + 5 + JOINTS * 7
const TOUCH_PROFILE := "/interaction_profiles/oculus/touch_controller"
const HAND_PROFILE := "/interaction_profiles/ext/hand_interaction_ext"
const FLAGS_TRACKED := 15  # POSITION_VALID | POSITION_TRACKED | ORIENTATION_VALID | ORIENTATION_TRACKED

var header := {}
var events: Array = []
var duration := 0.0
var time := 0.0
var speed := 1.0
var playing := false
var loop := false
var fixed_dt := 0.0
var untracked_as_hand := false
var head_node: Node3D
var radii := {"left": [], "right": []}

var _d := PackedFloat32Array()
var _ff := 0
var _count := 0
var _trackers := {}  # "left"/"right" -> XRPositionalTracker
var _hand_trackers := {}  # "left"/"right" -> XRHandTracker
var _btn_times := {}  # "left|trigger_click" -> PackedFloat64Array of edge times (press, release, press, ...)
var _have_events := false
var _last_bool := {}  # "left|trigger_click" -> bool, what the tracker holds now


# ---- loading ---------------------------------------------------------------------------------------------

func load_file(path: String) -> bool:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.is_empty():
		push_warning("[replay] cannot open %s" % path)
		return false
	if path.ends_with(".gz"):
		raw = raw.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)  # a standard gzip file (open_compressed is Godot's own format)
	var ev_path := path.replace(".bin.gz", "_events.jsonl").replace(".bin", "_events.jsonl")
	var lines: Array = []
	if FileAccess.file_exists(ev_path):
		var ef := FileAccess.open(ev_path, FileAccess.READ)
		if ef != null:
			for l in ef.get_as_text().split("\n", false):
				var j: Variant = JSON.parse_string(l)
				if j is Dictionary:
					lines.append(j)
	return load_bytes(raw, lines)


func load_bytes(raw: PackedByteArray, event_list: Array = []) -> bool:
	if raw.size() < 12 or raw.slice(0, 8).get_string_from_ascii() != MAGIC:
		return false
	var n := raw.decode_u32(8)
	var h: Variant = JSON.parse_string(raw.slice(12, 12 + n).get_string_from_utf8())
	if not h is Dictionary:
		return false
	var body := raw.slice(12 + n)
	body.resize(body.size() / 4 * 4)
	return load_floats(h, body.to_float32_array(), event_list)


func load_floats(h: Dictionary, floats: PackedFloat32Array, event_list: Array = []) -> bool:
	header = h
	_ff = int(h.get("frame_floats", 0))
	if _ff != 1 + 7 + PER_HAND * 2:
		push_warning("[replay] unexpected frame layout (%d floats)" % _ff)
		return false
	_count = floats.size() / _ff
	_d = floats
	duration = _d[(_count - 1) * _ff] if _count > 0 else 0.0
	events = event_list
	_have_events = false
	_btn_times.clear()
	for e in events:
		var ed: Dictionary = e
		var kind := String(ed.get("kind", ""))
		if kind == "hand_radii":
			radii[String(ed["hand"])] = ed["radii"]
		elif kind == "press" or kind == "release":
			var key := "%s|%s" % [ed["hand"], ed["input"]]
			var arr: PackedFloat64Array = _btn_times.get(key, PackedFloat64Array())
			arr.append(float(ed["t"]))
			_btn_times[key] = arr  # packed arrays are values: write it back
			_have_events = true
	return _count > 1


func frame_count() -> int:
	return _count


## The recorded time of frame i.
func frame_time(i: int) -> float:
	return _d[i * _ff]


## Index of the last frame at or before t (binary search).
func frame_index(t: float) -> int:
	var lo := 0
	var hi := _count - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if _d[mid * _ff] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Times (s) of the events of one kind ("tower", "phase", "story_chapter", ...), with their dictionaries.
func events_of(kind: String) -> Array:
	return events.filter(func(e): return e.get("kind", "") == kind)


# ---- sampling --------------------------------------------------------------------------------------------

func _pose(i: int, k: int) -> Transform3D:
	var b := i * _ff + k
	return Transform3D(Basis(Quaternion(_d[b + 3], _d[b + 4], _d[b + 5], _d[b + 6]).normalized()), Vector3(_d[b], _d[b + 1], _d[b + 2]))


func _lerp_pose(i0: int, i1: int, a: float, k: int) -> Transform3D:
	var p0 := _pose(i0, k)
	if a <= 0.0 or i0 == i1:
		return p0
	var p1 := _pose(i1, k)
	return Transform3D(Basis(p0.basis.get_rotation_quaternion().slerp(p1.basis.get_rotation_quaternion(), a)), p0.origin.lerp(p1.origin, a))


func hand_base(side: String) -> int:
	return 8 + (PER_HAND if side == "right" else 0)


## Everything at recorded time t, interpolated between the two frames round it: head, per hand aim_ok/aim/grip_ok/grip/
## trigger/grip_val/tracked/joints (Array of 26 Transform3D, only when tracked) and the booleans (events when present).
func sample(t: float) -> Dictionary:
	t = clampf(t, 0.0, duration)
	var i0 := frame_index(t)
	var i1 := mini(i0 + 1, _count - 1)
	var t0 := frame_time(i0)
	var t1 := frame_time(i1)
	var a := 0.0 if t1 <= t0 else clampf((t - t0) / (t1 - t0), 0.0, 1.0)
	var out := {"t": t, "head": _lerp_pose(i0, i1, a, 1), "hands": {}}
	for side in HANDS:
		var k := hand_base(side)
		var b0 := i0 * _ff + k
		var b1 := i1 * _ff + k
		var aim_ok := _d[b0] > 0.5
		var grip_ok := _d[b0 + 8] > 0.5
		var tracked := _d[b0 + 20] > 0.5
		var h := {
			"aim_ok": aim_ok, "grip_ok": grip_ok, "tracked": tracked,
			"aim": _lerp_pose(i0, i1 if _d[b1] > 0.5 else i0, a, k + 1), "grip": _lerp_pose(i0, i1 if _d[b1 + 8] > 0.5 else i0, a, k + 9),
			"trigger": lerpf(_d[b0 + 16], _d[b1 + 16], a), "grip_val": lerpf(_d[b0 + 17], _d[b1 + 17], a),
			"trigger_click": _bool_at(side, "trigger_click", t, _d[b0 + 18] > 0.5),
			"grip_click": _bool_at(side, "grip_click", t, _d[b0 + 19] > 0.5),
		}
		for nm in ["ax_button", "by_button", "menu_button", "select_button"]:
			h[nm] = _bool_at(side, nm, t, false)
		if tracked:
			var both := _d[b1 + 20] > 0.5
			var jt: Array[Transform3D] = []
			for j in JOINTS:
				jt.append(_lerp_pose(i0, i1 if both else i0, a, k + 21 + j * 7))
			h["joints"] = jt
		(out["hands"] as Dictionary)[side] = h
	return out


func _bool_at(side: String, input: String, t: float, frame_value: bool) -> bool:
	if not _have_events:
		return frame_value
	var key := "%s|%s" % [side, input]
	if not _btn_times.has(key):
		return false
	var times: PackedFloat64Array = _btn_times[key]
	var lo := 0
	var hi := times.size()
	while lo < hi:  # edges at or before t
		var mid := (lo + hi) >> 1
		if times[mid] <= t:
			lo = mid + 1
		else:
			hi = mid
	return lo % 2 == 1  # an odd number of edges so far = pressed


# ---- feeding the game --------------------------------------------------------------------------------------

## Registers the trackers (once) and points the head at head_target. Call before the game's hands are built, or after:
## XRNode3D binds to a tracker whenever one with its name appears.
func install(head_target: Node3D = null) -> void:
	head_node = head_target
	for side in HANDS:
		if not _trackers.has(side):
			var tr := XRControllerTracker.new()
			tr.name = StringName(side + "_hand")
			tr.type = XRServer.TRACKER_CONTROLLER
			tr.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == "left" else XRPositionalTracker.TRACKER_HAND_RIGHT
			tr.profile = TOUCH_PROFILE
			XRServer.add_tracker(tr)
			_trackers[side] = tr
		if not _hand_trackers.has(side):
			var ht := XRHandTracker.new()
			ht.name = StringName("/user/hand_tracker/" + side)
			ht.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == "left" else XRPositionalTracker.TRACKER_HAND_RIGHT
			ht.hand_tracking_source = XRHandTracker.HAND_TRACKING_SOURCE_UNOBSTRUCTED
			ht.has_tracking_data = false
			XRServer.add_tracker(ht)
			_hand_trackers[side] = ht
	process_priority = -100


func uninstall() -> void:
	for side in HANDS:
		if _trackers.has(side):
			XRServer.remove_tracker(_trackers[side])
		if _hand_trackers.has(side):
			XRServer.remove_tracker(_hand_trackers[side])
	_trackers.clear()
	_hand_trackers.clear()
	_last_bool.clear()


func apply(t: float) -> void:
	## Writes the sample at time t into the trackers and the head.
	var s := sample(t)
	if head_node != null and is_instance_valid(head_node):
		head_node.transform = s["head"]
	for side in HANDS:
		var h: Dictionary = (s["hands"] as Dictionary)[side]
		var tr: XRPositionalTracker = _trackers.get(side)
		if tr == null:
			continue
		tr.profile = HAND_PROFILE if (h["tracked"] or untracked_as_hand) else TOUCH_PROFILE
		for pair in [["aim", "aim_ok"], ["grip", "grip_ok"]]:
			if h[pair[1]]:
				tr.set_pose(StringName(pair[0]), h[pair[0]], Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
			else:
				tr.invalidate_pose(StringName(pair[0]))
		tr.set_input(&"trigger", float(h["trigger"]))
		tr.set_input(&"grip", float(h["grip_val"]))
		for nm in BUTTONS:
			var on: bool = h[nm]
			var key := "%s|%s" % [side, nm]
			if on != _last_bool.get(key, false):
				_last_bool[key] = on
				tr.set_input(StringName(nm), on)
		var ht: XRHandTracker = _hand_trackers.get(side)
		if ht != null:
			if h["tracked"]:
				var rad: Array = radii[side]
				var jt: Array = h["joints"]
				for j in JOINTS:
					ht.set_hand_joint_transform(j, jt[j])
					ht.set_hand_joint_flags(j, FLAGS_TRACKED)
					ht.set_hand_joint_radius(j, float(rad[j]) if j < rad.size() else 0.01)
				ht.has_tracking_data = true
			else:
				ht.has_tracking_data = false
	time = t


func seek(t: float) -> void:
	apply(clampf(t, 0.0, duration))


func play(from := -1.0) -> void:
	if from >= 0.0:
		time = from
	playing = true


func step(dt: float) -> void:
	## Advance by dt of REAL time (scaled by speed) and apply. Ends (or loops) at the recording's end.
	apply(time + dt * speed)
	if time >= duration:
		if loop:
			time = 0.0
		else:
			playing = false
			ended.emit()


func _process(delta: float) -> void:
	if playing:
		step(fixed_dt if fixed_dt > 0.0 else delta)


func _exit_tree() -> void:
	uninstall()
