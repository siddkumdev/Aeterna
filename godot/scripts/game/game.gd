class_name Game
extends Node3D
## First playable slice (scope decided 2026-10-22): Day = spend trust on towers, Night = Grunts walk
## from the forest gaps to the houses, Dawn = income and repairs. Five nights, then "loop complete"
## (no boss, spells, Foresight or villagers yet). Runs in the Meta XR Simulator (hand rays, pinch) or on
## the desktop with the mouse when OpenXR is not running.
##
## Desktop keys: 1 / 2 / 3 pick a tower, left click builds, Esc or right click cancels, Enter or Space
## starts the night, Tab toggles x3 speed, R restarts the run.
##
## Everything moving is ticked from step(), so tests/game_selftest.gd can play whole nights headless.

signal phase_changed(phase: int)

enum Phase { DAY, NIGHT, LOST, DONE }

const BOARD_POS := Vector3(0, 0.75, -0.55)  # table height, in front of a seated player (as in the spike)
# Lighting presets from art/art_bible.md (key colour, ambient colour, energy)
const DAY_LIGHT := [Color("FFEBC8"), Color("9DBBD0"), 0.8]
const NIGHT_LIGHT := [Color("8FB0D8"), Color("203C52"), 0.35]

## false = no camera, hands or input (headless tests build the game without them)
var with_rig := true
var run_seed := 1

var board: Node3D
var nav: NavGrid
var houses: Array[House] = []
var towers: Array[Tower] = []
var enemies: Array[Enemy] = []
var shots: Array[Projectile] = []
var shots_root: Node3D
var trust := GameConfig.START_TRUST
var night := 0  # 0-based
var phase := Phase.DAY
var night_time := 0.0
var selected := ""  # tower kind being placed, "" = none
var speed := 1.0
var last_message := ""

var _spawn_queue: Array = []  # [{"t": s, "cell": Vector2i}], sorted by time
var _towers_root: Node3D
var _enemies_root: Node3D
var _grid_lines: MeshInstance3D
var _ghost: Node3D
var _ghost_plate: MeshInstance3D
var _ghost_models := {}
var _ghost_ring: MeshInstance3D
var _hover_cell := Vector2i(-1, -1)
var _buttons := {}  # id -> {"node", "mat", "label", "box": AABB (board-local)}
var _hud: Label3D
var _msg: Label3D
var _sun: DirectionalLight3D
var _env: Environment
var _camera: Camera3D
var _hands: Array[GameHand] = []
var _active_hand: GameHand
var _xr := false


func _ready() -> void:
	if with_rig:
		_xr = _init_xr()
	_build_lights()
	board = Node3D.new()
	board.name = "Board"
	board.position = BOARD_POS
	add_child(board)
	WorldBuilder.build_island(board)
	WorldBuilder.build_forest(board, 7)
	_grid_lines = WorldBuilder.build_grid_lines(board)
	_towers_root = _child(board, "Towers")
	_enemies_root = _child(board, "Enemies")
	shots_root = _child(board, "Shots")
	_build_houses()
	_build_ghost()
	_build_ui()
	if with_rig:
		_build_rig()
	new_run(run_seed)


func _child(parent: Node, n: String) -> Node3D:
	var c := Node3D.new()
	c.name = n
	parent.add_child(c)
	return c


# ---------------------------------------------------------------- run, phases

func new_run(rng_seed: int) -> void:
	run_seed = rng_seed
	for t in towers:
		t.queue_free()
	towers.clear()
	_clear_night()
	nav = NavGrid.new()
	for h in houses:
		h.repair()
	trust = GameConfig.START_TRUST
	night = 0
	speed = 1.0
	Engine.time_scale = 1.0
	_set_phase(Phase.DAY, "Day 1. Spend trust on towers, then start the night.")


func _set_phase(p: int, message: String) -> void:
	phase = p
	last_message = message
	if p != Phase.DAY:
		select("")
	_set_light(NIGHT_LIGHT if p == Phase.NIGHT else DAY_LIGHT)
	_refresh_ui()
	phase_changed.emit(p)


func start_night() -> bool:
	if phase != Phase.DAY:
		return false
	night_time = 0.0
	_spawn_queue.clear()
	for g in WavePlan.groups_for(night, run_seed):
		var gap: Array = GameConfig.SPAWNS[g["spawn"]]
		for i in range(g["count"]):
			_spawn_queue.append({"t": g["time"] + i * GameConfig.IN_GROUP_GAP, "cell": gap[i % gap.size()]})
	_spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	_set_phase(Phase.NIGHT, "Night %d. They come from the forest." % (night + 1))
	return true


func _end_night() -> void:
	var standing := standing_houses().size()
	var income := standing * GameConfig.DAWN_TRUST_PER_HOUSE + GameConfig.NIGHT_CLEAR_TRUST
	trust += income
	for h in houses:
		h.repair()
	_clear_night()
	night += 1
	if night >= GameConfig.NIGHT_BUDGETS.size():
		_set_phase(Phase.DONE, "Dawn. All %d nights held: loop complete (the boss is not in this slice). R = new run." % night)
	else:
		_set_phase(Phase.DAY, "Dawn. %d houses stood: +%d trust. Day %d." % [standing, income, night + 1])


func _clear_night() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for s in shots:
		if is_instance_valid(s):
			s.queue_free()
	shots.clear()
	_spawn_queue.clear()


func standing_houses() -> Array[int]:
	var out: Array[int] = []
	for h in houses:
		if not h.is_shuttered:
			out.append(h.index)
	return out


func step(delta: float) -> void:
	## One game tick. Only the night moves; building happens on input.
	if phase != Phase.NIGHT:
		return
	night_time += delta
	while not _spawn_queue.is_empty() and _spawn_queue[0]["t"] <= night_time:
		_spawn(_spawn_queue.pop_front()["cell"])
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.step(delta)
	for t in towers:
		t.step(delta)
	for s in shots.duplicate():
		if is_instance_valid(s) and not s.done:
			s.step(delta)
	shots = shots.filter(func(s): return is_instance_valid(s) and not s.done)
	if phase != Phase.NIGHT:
		return  # a house falling can end the night inside the loop above
	var stuck := enemies.all(func(e): return e.target_house == -1)
	if _spawn_queue.is_empty() and (enemies.is_empty() or stuck):
		_end_night()
	else:
		_refresh_hud()


func _spawn(cell: Vector2i) -> void:
	var e := Enemy.new()
	e.game = self
	_enemies_root.add_child(e)
	e.spawn_at(cell)
	e.died.connect(func(en): enemies.erase(en))
	enemies.append(e)


func _on_house_shuttered(_h: House) -> void:
	var down := houses.size() - standing_houses().size()
	if down >= GameConfig.HOUSES_LOST_AT and phase == Phase.NIGHT:
		_set_phase(Phase.LOST, "Night %d lost: %d houses shuttered. R = new run." % [night + 1, down])


# ---------------------------------------------------------------- building

func select(kind: String) -> void:
	selected = kind if phase == Phase.DAY else ""
	_grid_lines.visible = selected != ""
	for k in _ghost_models:
		_ghost_models[k].visible = k == selected
	if selected != "":
		_draw_ring(GameConfig.TOWERS[selected]["range"] * GameConfig.CELL)
	_update_ghost()
	_refresh_ui()


func can_build(kind: String, cell: Vector2i) -> bool:
	return phase == Phase.DAY and trust >= GameConfig.TOWERS[kind]["cost"] \
		and nav.can_build(cell, GameConfig.TOWER_SIZE, standing_houses())


func try_build(kind: String, cell: Vector2i) -> bool:
	if not can_build(kind, cell):
		return false
	trust -= GameConfig.TOWERS[kind]["cost"]
	nav.add_tower(cell, GameConfig.TOWER_SIZE)
	var t := Tower.new()
	t.game = self
	_towers_root.add_child(t)
	t.setup(kind, cell)
	towers.append(t)
	last_message = "%s built. %d trust left." % [GameConfig.TOWERS[kind]["name"], trust]
	if trust < GameConfig.TOWERS[kind]["cost"]:
		select("")
	_update_ghost()
	_refresh_ui()
	return true


func _build_houses() -> void:
	var scenes: Array[PackedScene] = []
	for p in GameConfig.HOUSE_SCENES:
		scenes.append(load(p))
	var root := _child(board, "Houses")
	var centre := Vector2(GameConfig.SIZE, GameConfig.SIZE) / 2.0
	for i in GameConfig.HOUSE_CELLS.size():
		var c: Vector2i = GameConfig.HOUSE_CELLS[i]
		var h := House.new()
		root.add_child(h)
		h.position = NavGrid.footprint_centre(c, GameConfig.TOWER_SIZE)
		# door (+Z in the model) toward the open village centre, in 90 degree steps
		var d := centre - (Vector2(c) + Vector2.ONE)
		h.rotation.y = (PI / 2.0 if d.x > 0 else -PI / 2.0) if absf(d.x) > absf(d.y) else (0.0 if d.y > 0 else PI)
		h.setup(scenes[i % scenes.size()], i, c)
		h.shuttered.connect(_on_house_shuttered)
		houses.append(h)


func _build_ghost() -> void:
	_ghost = _child(board, "Ghost")
	_ghost_plate = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(GameConfig.CELL * 2 - 0.004, 0.002, GameConfig.CELL * 2 - 0.004)
	_ghost_plate.mesh = pm
	_ghost_plate.position.y = 0.001
	_ghost_plate.material_override = ModelUtil.flat_material(Color.GREEN, true, 0.45)
	_ghost.add_child(_ghost_plate)
	for k in GameConfig.TOWER_ORDER:
		var m: Node3D = load(GameConfig.TOWERS[k]["scene"]).instantiate()
		m.visible = false
		_ghost.add_child(m)
		_ghost_models[k] = m
	_ghost_ring = MeshInstance3D.new()
	_ghost_ring.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF4, 0xDC), true, 0.7)
	_ghost.add_child(_ghost_ring)
	_ghost.visible = false


func _draw_ring(r: float) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(65):
		var a := TAU * i / 64.0
		im.surface_add_vertex(Vector3(cos(a) * r, 0.003, sin(a) * r))
	im.surface_end()
	_ghost_ring.mesh = im


func _update_ghost() -> void:
	var show := selected != "" and _hover_cell.x >= 0
	_ghost.visible = show
	if not show:
		return
	_ghost.position = NavGrid.footprint_centre(_hover_cell, GameConfig.TOWER_SIZE)
	var ok := can_build(selected, _hover_cell)
	(_ghost_plate.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.35, 0.45) if ok else Color(0.95, 0.25, 0.2, 0.45)


# ---------------------------------------------------------------- pointer (mouse or hand ray)

func _ray_to_board(origin: Vector3, dir: Vector3) -> Array:
	## The ray in board-local space: [origin, dir].
	var inv := board.global_transform.affine_inverse()
	return [inv * origin, (inv.basis * dir).normalized()]


func _button_at(origin: Vector3, dir: Vector3) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var inv: Transform3D = b["node"].global_transform.affine_inverse()
		if b["node"].visible and b["box"].intersects_ray(inv * origin, inv.basis * dir) != null:
			return id
	return ""


func _cell_at(origin: Vector3, dir: Vector3) -> Vector2i:
	## Top-left cell of the 2 x 2 footprint centred under the ray, or (-1, -1) off the board.
	var r := _ray_to_board(origin, dir)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(r[0], r[1])
	if hit == null:
		return Vector2i(-1, -1)
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	if absf(hit.x) > half or absf(hit.z) > half:
		return Vector2i(-1, -1)
	var c := NavGrid.local_to_cell(hit - Vector3(GameConfig.CELL / 2.0, 0, GameConfig.CELL / 2.0))
	return c.clamp(Vector2i.ZERO, Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))


func _hover(origin: Vector3, dir: Vector3) -> void:
	var over := _button_at(origin, dir)
	for id in _buttons:
		_buttons[id]["hover"] = id == over
	var c := _cell_at(origin, dir) if over == "" else Vector2i(-1, -1)
	if c != _hover_cell:
		_hover_cell = c
		_update_ghost()
	_refresh_buttons()


func _press(origin: Vector3, dir: Vector3) -> void:
	var b := _button_at(origin, dir)
	if b != "":
		_press_button(b)
		return
	if selected == "":
		return
	var c := _cell_at(origin, dir)
	if c.x < 0:
		select("")
	elif not try_build(selected, c):
		if trust < GameConfig.TOWERS[selected]["cost"]:
			last_message = "Not enough trust."
		else:
			last_message = "Can't build there (blocked, or it would cut the forest off from every house)."
		_refresh_ui()


func _press_button(id: String) -> void:
	match id:
		"night":
			start_night()
		"restart":
			new_run(run_seed + 1)
		_:
			select("" if selected == id else id)


func _unhandled_input(event: InputEvent) -> void:
	if not with_rig:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1, KEY_2, KEY_3:
				_press_button(GameConfig.TOWER_ORDER[event.keycode - KEY_1])
			KEY_ESCAPE:
				select("")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_night()
			KEY_TAB:
				speed = 3.0 if speed == 1.0 else 1.0
				_refresh_hud()
			KEY_R:
				new_run(run_seed + 1)
	elif event is InputEventMouseButton and event.pressed and _camera and not _xr:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_press(_camera.project_ray_origin(event.position), _camera.project_ray_normal(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			select("")


func _process(delta: float) -> void:
	step(delta * speed)
	if not with_rig:
		return
	if _xr:
		if _active_hand:
			_hover(_active_hand.ray_origin(), _active_hand.ray_dir())
	elif _camera:
		var m := get_viewport().get_mouse_position()
		_hover(_camera.project_ray_origin(m), _camera.project_ray_normal(m))


# ---------------------------------------------------------------- UI (3D, so it works in the headset too)

func _build_ui() -> void:
	var ui := _child(board, "UI")
	var specs := []
	for k in GameConfig.TOWER_ORDER:
		specs.append([k, "%s\n%d trust" % [GameConfig.TOWERS[k]["name"], GameConfig.TOWERS[k]["cost"]]])
	specs.append(["night", "Start night"])
	specs.append(["restart", "New run"])
	var w := 0.1
	var gap := 0.012
	var x0 := -(4 * w + 3 * gap) / 2.0 + w / 2.0
	for i in specs.size():
		var id: String = specs[i][0]
		# a small sign leaning back toward the player, in front of the island's south edge
		var node := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.05, 0.008)
		node.mesh = bm
		var mat := ModelUtil.flat_material(Color8(0xC8, 0x8A, 0x4E))
		node.material_override = mat
		var slot := 3 if id == "restart" else i  # New run takes Start night's place once the run is over
		node.position = Vector3(x0 + slot * (w + gap), 0.0, 0.345)
		node.rotation_degrees.x = -50
		ui.add_child(node)
		var label := Label3D.new()
		label.text = specs[i][1]
		label.font_size = 36
		label.pixel_size = 0.00042
		label.outline_size = 8
		label.modulate = Color8(0x2A, 0x1E, 0x16)
		label.outline_modulate = Color8(0xFF, 0xF1, 0xDA)
		label.position = Vector3(0, 0, 0.0045)
		node.add_child(label)
		_buttons[id] = {"node": node, "mat": mat, "label": label, "hover": false, "box": AABB(-bm.size / 2.0, bm.size)}
	_hud = _make_label(ui, Vector3(0, 0.26, -0.33), 56)
	_msg = _make_label(ui, Vector3(0, 0.225, -0.33), 40)


func _make_label(parent: Node3D, pos: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0005
	l.outline_size = 10
	l.modulate = Color8(0xFF, 0xF1, 0xDA)
	l.outline_modulate = Color8(0x2A, 0x1E, 0x16)
	l.position = pos
	l.rotation_degrees.x = -20  # tipped toward the seated player's eyes
	l.no_depth_test = true  # always readable over the forest
	l.render_priority = 10
	parent.add_child(l)
	return l


func _refresh_ui() -> void:
	_refresh_hud()
	_refresh_buttons()


func _refresh_hud() -> void:
	if _hud == null:
		return
	var phase_name: String = ["Day", "Night", "Lost", "Done"][phase]
	var t := "%s %d   |   Trust %d   |   Houses %d/%d" % [phase_name, night + 1, trust, standing_houses().size(), houses.size()]
	if phase == Phase.NIGHT:
		t += "   |   Grunts %d" % (enemies.size() + _spawn_queue.size())
	if speed > 1.0:
		t += "   |   x%d" % int(speed)
	_hud.text = t
	_msg.text = last_message


func _refresh_buttons() -> void:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var day := phase == Phase.DAY
		var c := Color8(0xC8, 0x8A, 0x4E)
		match id:
			"night":
				b["node"].visible = day
				c = Color8(0x5E, 0x4A, 0x7A) if day else c
			"restart":
				b["node"].visible = phase == Phase.LOST or phase == Phase.DONE
			_:
				b["node"].visible = true
				if not day or trust < GameConfig.TOWERS[id]["cost"]:
					c = Color8(0x8A, 0x84, 0x7C)
				elif selected == id:
					c = Color8(0xF0, 0xB0, 0x4A)
		if b["hover"]:
			c = c.lightened(0.25)
		b["mat"].albedo_color = c


# ---------------------------------------------------------------- world, light, rig

func _build_lights() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color8(0x80, 0x7E, 0x7A)  # stands in for passthrough
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.rotation_degrees = Vector3(-50, -35, 0)
	add_child(_sun)


func _set_light(preset: Array) -> void:
	if _sun == null:
		return
	var tw := create_tween().set_parallel() if is_inside_tree() else null
	var key: Color = preset[0]
	var amb: Color = preset[1]
	var energy: float = preset[2] * 1.6
	if tw:
		tw.tween_property(_sun, "light_color", key, 1.2)
		tw.tween_property(_sun, "light_energy", energy, 1.2)
		tw.tween_property(_env, "ambient_light_color", amb, 1.2)
	else:
		_sun.light_color = key
		_sun.light_energy = energy
		_env.ambient_light_color = amb


func _init_xr() -> bool:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		get_viewport().use_xr = true
		print("[game] OpenXR running: hand rays + pinch")
		return true
	print("[game] OpenXR not running: desktop mode (mouse + keys)")
	return false


func _build_rig() -> void:
	if not _xr:
		_camera = Camera3D.new()
		_camera.fov = 62.0
		add_child(_camera)
		_camera.position = Vector3(0, 1.2, 0.05)
		_camera.look_at(BOARD_POS + Vector3(0, 0.03, 0.02))
		return
	var origin := XROrigin3D.new()
	add_child(origin)
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.2, 0)  # seated eye height
	origin.add_child(cam)
	for hand in ["left_hand", "right_hand"]:
		var c := GameHand.new()
		c.tracker = hand
		c.pose = &"aim"
		c.name = hand
		origin.add_child(c)
		c.pressed.connect(func(h: GameHand):
			_active_hand = h
			_press(h.ray_origin(), h.ray_dir()))
		_hands.append(c)
	_active_hand = _hands[1]
