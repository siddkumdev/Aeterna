class_name InputRecorder
extends Node
## Records everything the player does in VR so a run can be replayed later without a headset (sykeriin, 2026-11-17:
## last session with the Quest 3). Runs on the headset, writes locally, no cable needed while playing.
##
## Files (user:// = /data/user/0/com.aeterna.game/files on the Quest; pull with tools/quest_capture.py):
##   rec/<stamp>.bin          header + fixed-size float32 frames (layout in the header JSON, see FIELDS below)
##   rec/<stamp>_events.jsonl one JSON object per line: pinch press/release, controller buttons, hand radii, marks
## Poses are in raw XR tracking space (the same space XRServer reports), so a replay can feed them back as trackers.
##
## Cost: one frame = FRAME_FLOATS (414) float32 (1.6 KB) at RATE Hz, appended to a byte buffer and written every FLUSH_S seconds.

const RATE := 36.0  # half the 72 Hz display: smooth enough to replay, half the writes
const FLUSH_S := 2.0
const MAGIC := "AETREC01"
const HANDS := ["left", "right"]
const BUTTONS: Array[StringName] = [&"trigger_click", &"grip_click", &"ax_button", &"by_button", &"menu_button", &"select_button"]
const JOINTS := 26  # XRHandTracker.HAND_JOINT_MAX
# per frame: t, head pos3+quat4, then per hand: aim ok + pos3 + quat4, grip ok + pos3 + quat4,
# trigger, grip, trigger_click, grip_click, hand_tracked, then JOINTS x (pos3 + quat4)
const PER_HAND := 1 + 7 + 1 + 7 + 5 + JOINTS * 7
const FRAME_FLOATS := 1 + 7 + PER_HAND * 2

var path := ""
var frames := 0
var _f: FileAccess
var _ev: FileAccess
var _buf := PackedFloat32Array()
var _acc := 0.0
var _flush_acc := 0.0
var _t0 := 0
var _radii_done := {}
var _buttons := {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://rec")
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	path = "user://rec/%s.bin" % stamp
	_f = FileAccess.open(path, FileAccess.WRITE)
	_ev = FileAccess.open("user://rec/%s_events.jsonl" % stamp, FileAccess.WRITE)
	if _f == null or _ev == null:
		push_warning("[rec] cannot write %s" % path)
		set_process(false)
		return
	_t0 = Time.get_ticks_usec()
	var header := {
		"magic": MAGIC, "rate_hz": RATE, "frame_floats": FRAME_FLOATS, "joints": JOINTS,
		"layout": "t, head(px,py,pz,qx,qy,qz,qw), per hand [left,right]: aim_ok, aim(p3,q4), grip_ok, grip(p3,q4), trigger, grip, trigger_click, grip_click, hand_tracked, joints[26](p3,q4) in XRHandTracker.HandJoint order",
		"space": "XR tracking space (XRServer), metres, Y up",
		"started_unix": Time.get_unix_time_from_system(),
		"started_local": Time.get_datetime_string_from_system(false, true),
		"device": OS.get_model_name(), "os": OS.get_name(), "godot": Engine.get_version_info().string,
		"world_scale": XRServer.world_scale,
		"refresh_hz": _refresh_rate(),
	}
	var hj := JSON.stringify(header).to_utf8_buffer()
	_f.store_buffer(MAGIC.to_ascii_buffer())
	_f.store_32(hj.size())
	_f.store_buffer(hj)
	_f.flush()
	print("[rec] recording to ", ProjectSettings.globalize_path(path))


func _refresh_rate() -> float:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.has_method("get_display_refresh_rate"):
		return xr.call("get_display_refresh_rate")
	return 0.0


func now() -> float:
	return (Time.get_ticks_usec() - _t0) / 1000000.0


## A labelled moment in the run (story chapter, game start, a crash-worthy state), written to the events file.
func mark(kind: String, data := {}) -> void:
	if _ev == null:
		return
	var d := data.duplicate()
	d["t"] = snappedf(now(), 0.001)
	d["kind"] = kind
	_ev.store_line(JSON.stringify(d))


func _process(delta: float) -> void:
	_acc += delta
	_flush_acc += delta
	_poll_buttons()
	if _acc >= 1.0 / RATE:
		_acc = fmod(_acc, 1.0 / RATE)
		_frame()
	if _flush_acc >= FLUSH_S:
		_flush_acc = 0.0
		_flush()


func _frame() -> void:
	var b := _buf
	b.append(now())
	_xf(b, XRServer.get_hmd_transform())
	for h in HANDS:
		var ct := XRServer.get_tracker(StringName(h + "_hand")) as XRPositionalTracker
		for pose_name in [&"aim", &"grip"]:
			var p: XRPose = ct.get_pose(pose_name) if ct else null
			var ok := p != null and p.has_tracking_data
			b.append(1.0 if ok else 0.0)
			_xf(b, p.transform if ok else Transform3D())
		for inp in [&"trigger", &"grip", &"trigger_click", &"grip_click"]:
			var v: Variant = ct.get_input(inp) if ct else null
			b.append(float(v) if v is float or v is bool or v is int else 0.0)
		var ht := XRServer.get_tracker(StringName("/user/hand_tracker/" + h)) as XRHandTracker
		var tracked := ht != null and ht.has_tracking_data
		b.append(1.0 if tracked else 0.0)
		for j in JOINTS:
			_xf(b, ht.get_hand_joint_transform(j) if tracked else Transform3D())
		if tracked and not _radii_done.has(h):
			_radii_done[h] = true  # the player's hand size, once: a replay sizes its hand from these
			var r := []
			for j in JOINTS:
				r.append(snappedf(ht.get_hand_joint_radius(j), 0.0001))
			mark("hand_radii", {"hand": h, "radii": r})
	frames += 1


func _xf(b: PackedFloat32Array, x: Transform3D) -> void:
	var q := x.basis.get_rotation_quaternion()
	b.append(x.origin.x); b.append(x.origin.y); b.append(x.origin.z)
	b.append(q.x); b.append(q.y); b.append(q.z); b.append(q.w)


func _poll_buttons() -> void:
	for h in HANDS:
		var ct := XRServer.get_tracker(StringName(h + "_hand")) as XRPositionalTracker
		if ct == null:
			continue
		var state: Array = _buttons.get(h, [false, false, false, false, false, false])
		for i in BUTTONS.size():
			var inp := BUTTONS[i]
			var v: Variant = ct.get_input(inp)
			var on: bool = v is bool and v
			if on != state[i]:
				state[i] = on
				_buttons[h] = state
				mark("press" if on else "release", {"hand": h, "input": String(inp)})


func _flush() -> void:
	if _f == null or _buf.is_empty():
		return
	_f.store_buffer(_buf.to_byte_array())
	_buf.clear()
	_f.flush()
	_ev.flush()


func _exit_tree() -> void:
	_flush()
	if _f:
		mark("end", {"frames": frames})
		_ev.flush()
		_f.close()
		_ev.close()
		_f = null
		_ev = null


func _notification(what: int) -> void:
	# the Quest pauses / kills apps from the system menu without _exit_tree: keep what is recorded so far
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_flush()
		mark("pause" if what != NOTIFICATION_WM_CLOSE_REQUEST else "close")
		if _ev:
			_ev.flush()
