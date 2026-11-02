class_name WatchLink
extends Node
## The Galaxy Watch as a stand-in for hand tracking while there is no headset (Siddharth, 2026-11-02). Desktop mode only, on
## when AETERNA_WATCH=1. watch/watch_bridge.py live sends UDP lines to this port on localhost:
##   q,x,y,z,w   the watch's rotation (Android game rotation vector), about 100 per second
##   p,down / p,up   the pinch and the release, found by the bridge's detector
## The wrist aims: the forearm direction becomes a pointer on the window, and the pinch is a left click, so everything the
## mouse does in the game (hover, press, hold, release) works unchanged. Keys: C centres the aim (point at the board first),
## X lets go if a release was missed. The watch moves the real mouse cursor, so leave the physical mouse alone while using it.

const PORT := 9101
const SMOOTHING := 0.35  # 1 = no smoothing; lower is steadier but lags
const SIGNAL_TIMEOUT := 1.0  # seconds without a packet before the status says so

var span := Vector2(50.0, 35.0)  # degrees of wrist turn that cross the whole window, sideways and up-down
var axis := Vector3(1, 0, 0)  # the forearm in the watch's frame: +x points at the fingers on the right wrist with the buttons toward the hand
var held := false

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep reading packets while the game is paused
	var err := _udp.bind(PORT, "127.0.0.1")
	if err != OK:
		push_warning("WatchLink: could not listen on port %d (error %d); is another game running?" % [PORT, err])
		set_process(false)
		return
	var env_span := OS.get_environment("AETERNA_WATCH_SPAN").split(",")
	if env_span.size() == 2:
		span = Vector2(float(env_span[0]), float(env_span[1]))
	match OS.get_environment("AETERNA_WATCH_AXIS"):
		"-x": axis = Vector3(-1, 0, 0)
		"y": axis = Vector3(0, 1, 0)
		"-y": axis = Vector3(0, -1, 0)
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(12, 8)
	_status.add_theme_color_override("font_color", Color8(0xFF, 0xF0, 0xC8))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 6)
	layer.add_child(_status)
	print("[watch] listening on localhost:%d (span %s degrees, forearm axis %s)" % [PORT, span, axis])


func _process(delta: float) -> void:
	_since_packet += delta
	while _udp.get_available_packet_count() > 0:
		_since_packet = 0.0
		_handle(_udp.get_packet().get_string_from_ascii().strip_edges())
	if held and _since_packet > SIGNAL_TIMEOUT:
		print("[watch] no packets for %.1f s while holding: letting go" % SIGNAL_TIMEOUT)
		_button(false)  # a dead stream must never leave the button down
	if _have_rotation:
		_aim()
	_status.text = _status_text()


func _handle(line: String) -> void:
	var parts := line.split(",")
	if parts.size() == 5 and parts[0] == "q":
		var q := Quaternion(float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]))
		if q.length_squared() > 0.5:
			_rotation = q.normalized()
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


func _status_text() -> String:
	if _since_packet > SIGNAL_TIMEOUT:
		return "Watch: no signal (is watch_bridge.py live running?)"
	return "Watch: %s | C centres the aim, X lets go" % ("holding" if held else "pointing")
