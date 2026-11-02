extends SceneTree
## Test of the watch link without a watch (opens a window for a moment, not --headless):
##   <godot console> --xr-mode off --resolution 960x600 --path godot -s res://tools/watch_link_test.gd
## Sends the packets watch_bridge.py live would send and checks that the aim moves the pointer, the pinch presses and the
## release lets go. Prints PASS or the failures.

var _failures: Array[String] = []
var _presses := 0
var _releases := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures.append(what)


func _initialize() -> void:
	OS.set_environment("AETERNA_WATCH", "1")
	OS.set_environment("AETERNA_WATCH_PORT", "9199")  # not the real port: a bridge that is running must not feed the test
	OS.set_environment("AETERNA_WATCH_AXIS", "x")  # a saved calibration must not change what the test expects
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 10:
		await process_frame
	var link: WatchLink = g.get_node_or_null("watch_link")
	_check(link != null, "the game created the watch link")
	if link == null:
		quit(1)
		return
	g._mouse_hand.pressed.connect(func(_h): _presses += 1)
	g._mouse_hand.released.connect(func(_h): _releases += 1)
	var tx := PacketPeerUDP.new()
	tx.set_dest_address("127.0.0.1", link.port)

	var send_q := func(q: Quaternion):
		for i in 12:  # the smoothing needs a few packets to settle
			tx.put_packet(("q,%f,%f,%f,%f" % [q.x, q.y, q.z, q.w]).to_ascii_buffer())
			await process_frame
	var size := root.get_visible_rect().size

	await send_q.call(Quaternion.IDENTITY)
	var centre := root.get_mouse_position()
	print("centre at ", centre, " in a window of ", size)
	_check(centre.distance_to(size / 2.0) < 4.0, "the first aim is the middle of the window")

	await send_q.call(Quaternion(Vector3.BACK, deg_to_rad(-10.0)))  # turn right 10 degrees
	var right := root.get_mouse_position()
	var expect_dx := size.x * 10.0 / link.span.x
	print("turned right: ", right, " (expected about +", expect_dx, " px sideways)")
	_check(absf((right.x - centre.x) - expect_dx) < expect_dx * 0.15 and absf(right.y - centre.y) < 5.0, "turning the wrist right moves the pointer right by the span")

	await send_q.call(Quaternion(Vector3.BACK, deg_to_rad(10.0)))  # turn left 10 degrees
	var left := root.get_mouse_position()
	_check(left.x < centre.x - 5.0, "turning the wrist left moves the pointer left (" + str(left) + ")")

	await send_q.call(Quaternion(Vector3.UP, deg_to_rad(-8.0)))  # raise the forearm 8 degrees
	var up := root.get_mouse_position()
	var expect_dy := size.y * 8.0 / link.span.y
	print("raised: ", up, " (expected about -", expect_dy, " px)")
	_check(absf((centre.y - up.y) - expect_dy) < expect_dy * 0.15, "raising the forearm moves the pointer up by the span")

	tx.put_packet("p,down".to_ascii_buffer())
	for i in 3:
		await process_frame
	_check(_presses == 1 and link.held, "a pinch presses once")
	tx.put_packet("p,down".to_ascii_buffer())
	for i in 3:
		await process_frame
	_check(_presses == 1, "a second pinch while holding does nothing")
	tx.put_packet("p,up".to_ascii_buffer())
	for i in 3:
		await process_frame
	_check(_releases == 1 and not link.held, "the release lets go once")
	tx.put_packet("p,down".to_ascii_buffer())
	for i in 3:
		await process_frame
	link._input(_key(KEY_X))
	for i in 3:
		await process_frame
	_check(_releases == 2 and not link.held, "X lets go when a release was missed")

	tx.put_packet("p,down".to_ascii_buffer())
	for i in 3:
		await process_frame
	_check(link.held, "pinched again for the stall test")
	var started := Time.get_ticks_msec()
	while link.held and Time.get_ticks_msec() - started < 3000:
		await process_frame
	_check(not link.held, "a stream that goes quiet while holding lets go")

	await send_q.call(Quaternion(Vector3.BACK, deg_to_rad(-30.0)))
	link._input(_key(KEY_C))
	await send_q.call(Quaternion(Vector3.BACK, deg_to_rad(-30.0)))
	_check(root.get_mouse_position().distance_to(size / 2.0) < 6.0, "C makes the current aim the middle again")

	# calibration: whichever way round the strap is worn, the two moves must find the forearm axis in the watch's frame
	link.calib_seconds = 0.8
	link.config_path = "user://watch_link_test.cfg"  # never overwrite the real calibration
	for a in [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0.6, 0.8, 0), Vector3(0, -0.99, 0.1), Vector3(-0.8, 0, 0.6)]:
		a = a.normalized()
		link.calibrate()
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2000 and link._calib_stage > 0:
			var t := (Time.get_ticks_msec() - t0) / 1000.0
			var yaw := 0.0
			var pitch := 0.0
			if link._calib_stage == 1:
				pitch = deg_to_rad(25.0) * (1.0 - cos(TAU * 1.5 * t / 0.8)) / 2.0
			else:
				yaw = deg_to_rad(25.0) * sin(TAU * 1.5 * (t - 0.8) / 0.8)
			var q := _forearm(a, yaw, pitch, deg_to_rad(6.0) * sin(t * 5.0))
			tx.put_packet(("q,%f,%f,%f,%f" % [q.x, q.y, q.z, q.w]).to_ascii_buffer())
			await process_frame
		print("calibrated for ", a, " -> ", link.axis, "  ", link._calib_message)
		_check(link.axis.dot(a) > 0.97, "calibration finds the forearm axis " + str(a))

	print("PASS" if _failures.is_empty() else "FAILED: %d" % _failures.size())
	quit(0 if _failures.is_empty() else 1)


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _forearm(a: Vector3, yaw: float, pitch: float, roll: float) -> Quaternion:
	## The watch rotation when its axis a points along (yaw, pitch) in the world (x east, y north, z up), twisted by roll:
	## a rigid forearm, so it is the level pose turned by the pitch about east, then by the yaw about the vertical.
	var level := Quaternion(a.normalized(), Vector3(0, 1, 0))
	var turned := Quaternion(Vector3.BACK, -yaw) * Quaternion(Vector3.RIGHT, pitch) * level
	var d := turned * a.normalized()
	return Quaternion(d, roll) * turned
