class_name WatchLink
extends Node
## The Galaxy Watch as a stand-in for hand tracking while there is no headset (Siddharth, 2026-11-02). Desktop mode only, on
## when AETERNA_WATCH=1. watch/watch_bridge.py live sends UDP lines to this port on localhost:
##   q,x,y,z,w   the watch's rotation (Android game rotation vector), about 100 per second
##   p,down / p,up   the pinch and the release, found by the bridge's detector
## The wrist aims: the forearm direction becomes a pointer on the window, and the pinch is a left click, so everything the
## mouse does in the game (hover, press, hold, release) works unchanged. Keys: C centres the aim (point at the board first),
## X lets go if a release was missed, K calibrates which way the forearm points in the watch's own frame (see below). The watch moves the real mouse cursor, so leave the physical mouse alone while using it.

const PORT := 9101
const SMOOTHING := 0.35  # 1 = no smoothing; lower is steadier but lags
const SIGNAL_TIMEOUT := 1.0  # seconds without a packet before the status says so

var span := Vector2(50.0, 35.0)  # degrees of wrist turn that cross the whole window, sideways and up-down
var axis := Vector3(1, 0, 0)  # the forearm in the watch's frame: +x points at the fingers on the right wrist with the buttons toward the hand
var port := PORT  # AETERNA_WATCH_PORT overrides it (the test uses another so a live bridge cannot disturb it)
var held := false
var config_path := "user://watch_link.cfg"  # where the calibrated axis is kept
var calib_seconds := 6.0  # length of each of the two calibration moves

var _udp := PacketPeerUDP.new()
var _rotation := Quaternion.IDENTITY
var _have_rotation := false
var _yaw := 0.0
var _pitch := 0.0
var _yaw0 := 0.0
var _pitch0 := 0.0
var _position := Vector2.ZERO
var _since_packet := 99.0
var _status: Label
var _calib_stage := 0  # 0 off, 1 raise and lower the forearm, 2 sweep it left and right
var _calib_time := 0.0
var _calib_prev := Quaternion.IDENTITY
var _calib_have_prev := false
var _calib_rows: Array = []  # covariance of the turning axis, as three rows
var _calib_pitch_axis := Vector3.ZERO
var _calib_quats: Array[Quaternion] = []
var _calib_message := ""


func _ready() -> void:
	if OS.get_environment("AETERNA_WATCH_PORT") != "":
		port = int(OS.get_environment("AETERNA_WATCH_PORT"))
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep reading packets while the game is paused
	var err := _udp.bind(port, "127.0.0.1")
	if err != OK:
		push_warning("WatchLink: could not listen on port %d (error %d); is another game running?" % [port, err])
		set_process(false)
		return
	_load_axis()
	var env_span := OS.get_environment("AETERNA_WATCH_SPAN").split(",")
	if env_span.size() == 2:
		span = Vector2(float(env_span[0]), float(env_span[1]))
	match OS.get_environment("AETERNA_WATCH_AXIS"):
		"-x": axis = Vector3(-1, 0, 0)
		"y": axis = Vector3(0, 1, 0)
		"-y": axis = Vector3(0, -1, 0)
		"x": axis = Vector3(1, 0, 0)
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(12, 8)
	_status.add_theme_color_override("font_color", Color8(0xFF, 0xF0, 0xC8))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status)
	print("[watch] listening on localhost:%d (span %s degrees, forearm axis %s)" % [port, span, axis])


func _process(delta: float) -> void:
	_since_packet += delta
	while _udp.get_available_packet_count() > 0:
		_since_packet = 0.0
		_handle(_udp.get_packet().get_string_from_ascii().strip_edges())
	if held and _since_packet > SIGNAL_TIMEOUT:
		print("[watch] no packets for %.1f s while holding: letting go" % SIGNAL_TIMEOUT)
		_button(false)  # a dead stream must never leave the button down
	if _calib_stage > 0:
		_calib_time += delta
		if _calib_time >= calib_seconds:
			_calib_next()
	if _have_rotation and _calib_stage == 0:  # during calibration the big moves must not drive the game
		_aim()
	_status.text = _status_text()


func _handle(line: String) -> void:
	var parts := line.split(",")
	if parts.size() == 5 and parts[0] == "q":
		var q := Quaternion(float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
		if q.length_squared() > 0.5:
			_rotation = q.normalized()
			if _calib_stage > 0:
				_calib_feed(_rotation)
			if not _have_rotation:
				_have_rotation = true
				_yaw = _pointing_yaw()
				_pitch = _pointing_pitch()
				centre()
	elif parts.size() == 2 and parts[0] == "p":
		if parts[1] == "down":
			_button(true)
		elif parts[1] == "up":
			_button(false)


func _pointing() -> Vector3:
	return _rotation * axis  # the forearm in the world (x east, y north, z up)


func _pointing_yaw() -> float:
	var v := _pointing()
	return atan2(v.x, v.y)


func _pointing_pitch() -> float:
	return asin(clampf(_pointing().z, -1.0, 1.0))


func centre() -> void:
	## Whatever the wrist points at now becomes the middle of the window.
	_yaw0 = _yaw
	_pitch0 = _pitch


func _aim() -> void:
	_yaw += wrapf(_pointing_yaw() - _yaw, -PI, PI) * SMOOTHING
	_pitch += (_pointing_pitch() - _pitch) * SMOOTHING
	var size := get_viewport().get_visible_rect().size
	var x := size.x * (0.5 + rad_to_deg(wrapf(_yaw - _yaw0, -PI, PI)) / span.x)
	var y := size.y * (0.5 - rad_to_deg(_pitch - _pitch0) / span.y)
	var target := Vector2(clampf(x, 0.0, size.x - 1.0), clampf(y, 0.0, size.y - 1.0))
	if target.distance_to(_position) < 0.5:
		return
	_position = target
	Input.warp_mouse(target)  # the game reads the real cursor position (get_mouse_position ignores injected motion)


func _button(down: bool) -> void:
	if down and _calib_stage > 0:
		return  # no clicks while calibrating
	if down == held:
		return
	held = down
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = down
	click.position = _position
	click.global_position = _position
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(click)


func _notification(what: int) -> void:
	if (what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT) and held:
		_button(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			centre()
		elif event.keycode == KEY_X and held:
			_button(false)
		elif event.keycode == KEY_K:
			calibrate()


func calibrate() -> void:
	## Finds which way the forearm points in the watch's own frame, so the strap can be worn any way round. Two moves of
	## calib_seconds each: raise and lower the forearm (turns about the sideways axis), then sweep it left and right (turns
	## about the vertical axis). The forearm is perpendicular to both turning axes, so it is their cross product.
	if not _have_rotation:
		_calib_message = "Calibration needs the watch signal first."
		return
	_button(false)
	_calib_stage = 0
	_calib_next()


func _calib_next() -> void:
	var finished := _calib_stage
	var axis_found := _calib_top_axis() if finished > 0 else Vector3.ZERO  # before the sums are cleared
	_calib_time = 0.0
	_calib_have_prev = false
	_calib_rows = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	if finished == 0:
		_calib_stage = 1
		_calib_quats.clear()
	elif finished == 1:
		_calib_pitch_axis = axis_found
		_calib_stage = 2
	else:
		_calib_stage = 0
		_calib_finish(axis_found)


func _calib_feed(q: Quaternion) -> void:
	if _calib_stage == 1:
		_calib_quats.append(q)
	if _calib_have_prev:
		var dq := _calib_prev.inverse() * q  # the turn since the last sample, in the watch's own frame
		if dq.w < 0.0:
			dq = -dq
		var w := Vector3(dq.x, dq.y, dq.z) * 2.0  # small-angle turning vector
		for i in 3:
			_calib_rows[i] += w * w[i]
	_calib_prev = q
	_calib_have_prev = true


func _calib_top_axis() -> Vector3:
	var v := Vector3(1.0, 0.7, 0.3).normalized()
	for i in 40:
		var nv := Vector3(_calib_rows[0].dot(v), _calib_rows[1].dot(v), _calib_rows[2].dot(v))
		if nv.length() < 1e-9:
			return Vector3.ZERO
		v = nv.normalized()
	return v


func _calib_finish(yaw_axis: Vector3) -> void:
	var cross := _calib_pitch_axis.cross(yaw_axis)
	if _calib_pitch_axis == Vector3.ZERO or yaw_axis == Vector3.ZERO or cross.length() < 0.8:
		_calib_message = "Calibration failed: the two moves looked alike. Press K and try again (raise-lower, then left-right)."
		return
	var a := cross.normalized()
	# the first moves start level: the side the pitch went further to is up
	var n := mini(10, _calib_quats.size())
	if n < 10:
		_calib_message = "Calibration failed: too few samples."
		return
	var start := 0.0
	for i in n:
		start += _pitch_of(_calib_quats[i], a)
	start /= n
	var hi := start
	var lo := start
	for q in _calib_quats:
		var p := _pitch_of(q, a)
		hi = maxf(hi, p)
		lo = minf(lo, p)
	if hi - lo < deg_to_rad(5.0):
		_calib_message = "Calibration failed: the forearm barely moved up and down. Press K and try again."
		return
	if start - lo > hi - start:
		a = -a
	axis = a
	_save_axis()
	_calib_message = "Calibrated: forearm axis (%.2f, %.2f, %.2f), saved." % [a.x, a.y, a.z]
	print("[watch] ", _calib_message)
	_yaw = _pointing_yaw()
	_pitch = _pointing_pitch()
	centre()


func _pitch_of(q: Quaternion, a: Vector3) -> float:
	return asin(clampf((q * a).z, -1.0, 1.0))


func _load_axis() -> void:
	if OS.get_environment("AETERNA_WATCH_AXIS") != "":
		return  # an explicit setting wins over the saved calibration
	var cfg := ConfigFile.new()
	if cfg.load(config_path) == OK:
		var saved: Variant = cfg.get_value("watch", "axis", null)
		if saved is Vector3 and (saved as Vector3).length() > 0.5:
			axis = (saved as Vector3).normalized()


func _save_axis() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("watch", "axis", axis)
	cfg.save(config_path)


func _status_text() -> String:
	if _since_packet > SIGNAL_TIMEOUT:
		return "Watch: no signal (is watch_bridge.py live running?)"
	if _calib_stage == 1:
		return "CALIBRATING 1/2: start level, FIRST raise your forearm up, then lower it back, again and again (%.0f s)" % maxf(calib_seconds - _calib_time, 0.0)
	if _calib_stage == 2:
		return "CALIBRATING 2/2: keep it level and sweep your forearm left and right (%.0f s)" % maxf(calib_seconds - _calib_time, 0.0)
	if _since_packet > SIGNAL_TIMEOUT:
		return "Watch: no signal (is watch_bridge.py live running?)"
	return "Watch: %s | C centres, X lets go, K calibrates%s" % ["holding" if held else "pointing", ("
" + _calib_message) if _calib_message != "" else ""]
