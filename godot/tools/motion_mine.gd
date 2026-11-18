extends SceneTree
## Mines the team's real Quest recordings (quest_data/recordings/*.bin.gz) for human motion the VR bot replays
## (2026-11-18, the user: "look at my real hand movements and head movements"). Writes res://tools/motion_lib.json:
##   reaches   every real reach that ended in a pinch, as a path normalised to its own start->end (u along it, v up,
##             w sideways, all / distance), sampled at 60 Hz, with its distance and duration (right-hand frame;
##             the bot mirrors w for the left hand);
##   trigger   the mean trigger value round a pinch (-0.25 s .. +0.15 s), the real closing curve;
##   holds     pinch hold durations (s);
##   head      a long stretch of the head's small motion (yaw, pitch, roll and position minus their 0.8 s average),
##             30 Hz, and the head's turn speeds (main-sequence pairs: amplitude rad, peak rad/s, duration s).
##   <godot console> --headless --xr-mode off --path godot -s res://tools/motion_mine.gd -- <recordings dir>

const Replay := preload("res://scripts/game/input_replay.gd")
const HZ := 60.0


func _initialize() -> void:
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ProjectSettings.globalize_path("res://../quest_data/recordings")
	var reaches: Array = []
	var trig_sum := PackedFloat32Array()
	trig_sum.resize(25)
	var trig_n := 0
	var holds: Array = []
	var head_best: Array = []
	var sacc: Array = []
	var files := DirAccess.get_files_at(dir)
	for fn in files:
		if not fn.ends_with(".bin.gz"):
			continue
		var r: Node = Replay.new()
		if not r.load_file(dir + "/" + fn):
			r.free()
			continue
		var n_before := reaches.size()
		_mine(r, reaches, trig_sum, holds, sacc)
		trig_n += _trig_count
		var hd := _head_clip(r)
		if hd.size() > head_best.size():
			head_best = hd
		print("%s: %.0f s, %d frames, %d reaches" % [fn, r.duration, r.frame_count(), reaches.size() - n_before])
		r.free()
	var trig: Array = []
	for i in trig_sum.size():
		trig.append(snappedf(trig_sum[i] / maxf(trig_n, 1), 0.001))
	var out := {"made": "2026-11-18 from %d recordings" % files.size(), "hz": HZ, "reaches": reaches, "trigger": trig,
		"trigger_hz": 100.0, "holds": holds, "head_hz": 30.0, "head": head_best, "saccades": sacc}
	var f := FileAccess.open("res://tools/motion_lib.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	var ds: Array = reaches.map(func(x): return x["d"])
	var ts: Array = reaches.map(func(x): return x["dur"])
	ds.sort()
	ts.sort()
	print("reaches %d (distance median %.2f m, duration median %.2f s), pinches %d, holds %d, head clip %.0f s, saccades %d" % [
		reaches.size(), ds[ds.size() / 2] if ds.size() > 0 else 0.0, ts[ts.size() / 2] if ts.size() > 0 else 0.0, trig_n, holds.size(), head_best.size() / 30.0, sacc.size()])
	quit()


var _trig_count := 0


func _point(r: Node, i: int, side: String) -> Array:
	## [tracked/has pose, pinch point]: the mid of thumb and index tips when the hand is tracked, else the aim origin.
	var k: int = r.hand_base(side)
	var b: int = i * r._ff + k
	if r._d[b + 20] > 0.5:
		return [true, (r._pose(i, k + 21 + 5 * 7).origin + r._pose(i, k + 21 + 10 * 7).origin) * 0.5]
	if r._d[b] > 0.5:
		return [true, r._pose(i, k + 1).origin]
	return [false, Vector3.ZERO]


func _mine(r: Node, reaches: Array, trig_sum: PackedFloat32Array, holds: Array, sacc: Array) -> void:
	_trig_count = 0
	var n: int = r.frame_count()
	for side in ["left", "right"]:
		var k: int = r.hand_base(side)
		var was := false
		var press_t := -1.0
		for i in range(1, n):
			var b: int = i * r._ff + k
			var on: bool = r._d[b + 16] > 0.85 or r._d[b + 18] > 0.5
			if on and not was:
				press_t = r.frame_time(i)
				var rc := _reach_before(r, i, side)
				if not rc.is_empty():
					reaches.append(rc)
				# the trigger's closing curve, 100 Hz, -0.25 .. +0.0 s
				var ok := true
				var vals := PackedFloat32Array()
				for s in 25:
					var tt: float = press_t - 0.25 + s * 0.01
					var j: int = r.frame_index(tt)
					if absf(r.frame_time(j) - tt) > 0.05:
						ok = false
						break
					vals.append(r._d[j * r._ff + k + 16])
				if ok and vals[0] < 0.4:
					for s in 25:
						trig_sum[s] += vals[s]
					_trig_count += 1
			elif not on and was and press_t >= 0.0:
				var hd: float = r.frame_time(i) - press_t
				if hd > 0.04 and hd < 3.0:
					holds.append(snappedf(hd, 0.01))
			was = on
	# head turns: angular speed peaks (yaw/pitch) over a 30 Hz grid
	var prev := Vector3.INF
	var t := 0.0
	var run_amp := 0.0
	var run_peak := 0.0
	var run_t := 0.0
	while t < r.duration:
		var fw: Vector3 = -(r.sample(t)["head"] as Transform3D).basis.z
		if prev != Vector3.INF:
			var w: float = prev.angle_to(fw) * 30.0
			if w > 0.35:
				run_amp += w / 30.0
				run_peak = maxf(run_peak, w)
				run_t += 1.0 / 30.0
			elif run_t > 0.0:
				if run_amp > 0.08 and run_t < 1.5:
					sacc.append([snappedf(run_amp, 0.001), snappedf(run_peak, 0.01), snappedf(run_t, 0.01)])
				run_amp = 0.0
				run_peak = 0.0
				run_t = 0.0
		prev = fw
		t += 1.0 / 30.0


func _reach_before(r: Node, i_press: int, side: String) -> Dictionary:
	## The movement that ended in this pinch: back from the press while the pinch point moves (> 4 cm/s, 0.1 s window).
	var t_end: float = r.frame_time(i_press)
	var pe: Array = _point(r, i_press, side)
	if not pe[0]:
		return {}
	var t0 := t_end
	var t := t_end
	while t > t_end - 2.0:
		var a: Array = _point(r, r.frame_index(t - 0.1), side)
		var b: Array = _point(r, r.frame_index(t), side)
		if not a[0] or not b[0]:
			return {}
		if ((b[1] as Vector3) - (a[1] as Vector3)).length() / 0.1 < 0.04 and t < t_end - 0.12:
			break
		t0 = t - 0.1
		t -= 1.0 / HZ
	var A: Vector3 = _point(r, r.frame_index(t0), side)[1]
	var B: Vector3 = pe[1]
	var d := A.distance_to(B)
	var dur := t_end - t0
	if d < 0.05 or d > 0.8 or dur < 0.2 or dur > 2.0:
		return {}
	var e1 := (B - A) / d
	var e2 := (Vector3.UP - e1 * e1.dot(Vector3.UP))
	if e2.length() < 0.1:
		return {}
	e2 = e2.normalized()
	var e3 := e1.cross(e2)
	if side == "left":
		e3 = -e3  # stored as a right hand; the bot mirrors it back for the left
	var path: Array = []
	var s := 0.0
	while s <= dur + 0.0001:
		var p: Array = _point(r, r.frame_index(t0 + s), side)
		var q: Vector3 = ((p[1] as Vector3) - A) / d
		path.append([snappedf(q.dot(e1), 0.001), snappedf(q.dot(e2), 0.001), snappedf(q.dot(e3), 0.001)])
		s += 1.0 / HZ
	# sanity: a reach goes most of the way there and does not wander far off its line
	var maxoff := 0.0
	for q in path:
		maxoff = maxf(maxoff, Vector2(q[1], q[2]).length())
	if maxoff > 0.6 or absf(float(path[path.size() - 1][0]) - 1.0) > 0.05:
		return {}
	return {"d": snappedf(d, 0.001), "dur": snappedf(dur, 0.001), "side": side, "path": path}


func _head_clip(r: Node) -> Array:
	## The head's small motion over the whole recording: yaw/pitch/roll and position minus their 0.8 s average, 30 Hz.
	## Only stretches with a live head (it holds still when the headset is off) count; the longest one is kept.
	var raw: Array = []
	var t := 0.0
	while t < r.duration:
		var h: Transform3D = r.sample(t)["head"]
		var e := h.basis.get_euler()
		raw.append([e.y, e.x, e.z, h.origin])
		t += 1.0 / 30.0
	var out: Array = []
	var best: Array = []
	var W := 12
	for i in range(W, raw.size() - W):
		var m := Vector3.ZERO
		var mp := Vector3.ZERO
		for j in range(i - W, i + W + 1):
			m += Vector3(angle_difference(raw[i][0], raw[j][0]), raw[j][1] - raw[i][1], raw[j][2] - raw[i][2])
			mp += raw[j][3]
		m /= (2 * W + 1)
		mp /= (2 * W + 1)
		var res := Vector3(-m.x, -m.y, -m.z)  # this frame minus the average round it
		var pres: Vector3 = raw[i][3] - mp
		var live: bool = (raw[i][3] as Vector3).distance_to(raw[i - 1][3]) > 0.00001
		if live and res.length() < 0.15 and pres.length() < 0.05:
			out.append([snappedf(res.x, 0.0001), snappedf(res.y, 0.0001), snappedf(res.z, 0.0001), snappedf(pres.x, 0.0001), snappedf(pres.y, 0.0001), snappedf(pres.z, 0.0001)])
		else:
			if out.size() > best.size():
				best = out
			out = []
	if out.size() > best.size():
		best = out
	return best.slice(0, mini(best.size(), 30 * 240))  # four minutes is plenty
