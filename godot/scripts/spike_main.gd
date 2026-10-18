extends Node3D
## XR feasibility spike (throwaway). Initialises OpenXR, builds a 12x12-cell board (1 cell = 0.05 m),
## places benchmark models on 2x2-cell footprints, and logs what the XR runtime provides.

const CELL := 0.05
const BOARD_CELLS := 12
const LOG_PATH := "user://spike_log.txt"

var xr_interface: XRInterface
var log_lines: PackedStringArray = []
var placer: TowerPlacer
var hands: Array[HandInput] = []


func _log(msg: String) -> void:
	print("[spike] ", msg)
	log_lines.append(msg)


func _ready() -> void:
	_init_xr()
	_build_rig()
	_build_board()
	_place_models()
	XRServer.tracker_added.connect(func(n, t): _log("tracker added: %s (type %d)" % [n, t]))
	XRServer.tracker_removed.connect(func(n, t): _log("tracker removed: %s" % n))
	await get_tree().create_timer(3.0).timeout
	_report()


func _init_xr() -> void:
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null:
		_log("FAIL: OpenXR interface not found")
		return
	if not xr_interface.is_initialized():
		_log("OpenXR found but not initialised, trying initialize()")
		xr_interface.initialize()
	if xr_interface.is_initialized():
		get_viewport().use_xr = true
		_log("OpenXR initialised. interface=%s" % xr_interface.get_name())
		_log("system info: %s" % str(xr_interface.get_system_info()))
		_log("capabilities: %d" % xr_interface.get_capabilities())
		_log("render size: %s" % str(xr_interface.get_render_target_size()))
	else:
		_log("FAIL: OpenXR could not initialise (no headset/runtime?)")


func _build_rig() -> void:
	var origin := XROrigin3D.new()
	origin.name = "XROrigin3D"
	add_child(origin)
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.2, 0)  # seated eye height
	origin.add_child(cam)
	for hand in ["left_hand", "right_hand"]:
		var c := HandInput.new()
		c.tracker = hand
		c.pose = &"aim"  # pointing ray; the pinch/grasp/trigger actions all arrive as button signals
		c.hand_id = hand
		c.name = hand
		origin.add_child(c)
		hands.append(c)
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.02
		sm.height = 0.04
		m.mesh = sm
		c.add_child(m)
		var ray := MeshInstance3D.new()  # visible pointing ray, 0.8 m long
		var rb := BoxMesh.new()
		rb.size = Vector3(0.003, 0.003, 0.8)
		ray.mesh = rb
		ray.position = Vector3(0, 0, -0.4)
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(1, 1, 0.6, 0.6)
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ray.material_override = rm
		c.add_child(ray)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.12, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment = e
	add_child(env)


func _board_root() -> Node3D:
	var r: Node3D = get_node_or_null("Board")
	if r == null:
		r = Node3D.new()
		r.name = "Board"
		# table height 0.75 m, 0.5 m in front of the player; the board is 12 cells = 0.6 m wide
		r.position = Vector3(0, 0.75, -0.55)
		add_child(r)
	return r


func _build_board() -> void:
	var board := _board_root()
	var size := CELL * BOARD_CELLS
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, 0.01, size)
	slab.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7FA84A")
	slab.material_override = mat
	slab.position = Vector3(0, -0.005, 0)
	board.add_child(slab)
	# grid lines
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(BOARD_CELLS + 1):
		var p := -size / 2.0 + i * CELL
		im.surface_add_vertex(Vector3(p, 0.001, -size / 2.0))
		im.surface_add_vertex(Vector3(p, 0.001, size / 2.0))
		im.surface_add_vertex(Vector3(-size / 2.0, 0.001, p))
		im.surface_add_vertex(Vector3(size / 2.0, 0.001, p))
	im.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = im
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.15, 0.3, 0.1)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lines.material_override = lm
	board.add_child(lines)


func cell_to_local(cx: int, cz: int, w: int = 2, d: int = 2) -> Vector3:
	## Centre of a w x d cell footprint whose top-left cell is (cx, cz); board centred at origin.
	var size := CELL * BOARD_CELLS
	return Vector3(-size / 2.0 + (cx + w / 2.0) * CELL, 0.0, -size / 2.0 + (cz + d / 2.0) * CELL)


func _place_models() -> void:
	var board := _board_root()
	placer = TowerPlacer.new()
	placer.name = "TowerPlacer"
	add_child(placer)
	placer.setup(board)
	# [model path, top-left cell, footprint cells, model height (m, from tools/check_assets.gd), scale].
	# Real towers (synced with tools/sync_to_godot.py); the old benchmark models are in assets/_old.
	var spots := [
		["res://assets/defense/ew_defense_fire_tower_v07.glb", Vector2i(3, 5), Vector2i(2, 2), 0.139, 1.0],
		["res://assets/defense/ew_defense_bomb_tower_v06.glb", Vector2i(7, 5), Vector2i(2, 2), 0.077, 1.0],
	]
	for sp in spots:
		var res = load(sp[0])
		if res == null:
			_log("model failed to load: %s" % sp[0])
			continue
		var wrap := Node3D.new()
		var model: Node3D = res.instantiate()
		model.scale = Vector3.ONE * sp[4]
		wrap.add_child(model)
		var id := placer.add_item(wrap, sp[1], sp[2], sp[3])
		_log("placed %s at cell %s (item %d)" % [sp[0].get_file(), str(sp[1]), id])
	for h in hands:
		h.placer = placer


func _report() -> void:
	_log("fps: %d" % Engine.get_frames_per_second())
	_log("trackers: %s" % str(XRServer.get_trackers(XRServer.TRACKER_ANY).keys()))
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.close()
	_log("log written to %s" % ProjectSettings.globalize_path(LOG_PATH))
	if OS.get_cmdline_user_args().has("--quit-after-report"):
		get_tree().quit()
