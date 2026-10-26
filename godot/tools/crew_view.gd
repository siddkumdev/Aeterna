extends SceneTree
## Watch the tower crews live in a window (real time, nothing to learn):
##   <godot console> --xr-mode off --path godot -s res://tools/crew_view.gd
## Keys: 1 = Wizard Tower, 2 = Longbow Tower, 3 = Airship, Left / Right = turn the view, Up / Down = zoom,
## S = slow motion on / off, Esc = quit. The towers fire at a target that never dies.

var g: Game
var cam: Camera3D
var focus := 0
var yaw := 0.6
var dist := 0.17
var towers: Array = []
var targets: Array = []
var slow := false
var _was := {}


func _initialize() -> void:
	g = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	await process_frame
	await process_frame
	g.trust = 500
	g.try_build("fire", Vector2i(6, 12))
	g.try_build("crossbow", Vector2i(11, 12))
	g.try_build("airship", Vector2i(16, 12))
	g.night = 2
	g.start_night()
	g._spawn_queue.clear()
	g.set_process(false)  # the view ticks the game itself, so S can slow it
	towers = g.towers.duplicate()
	var spots := [[Vector2i(7, 9), "grunt", 0.0], [Vector2i(11, 9), "grunt", 0.0], [Vector2i(16, 10), "wisp", 0.06]]
	for s in spots:
		var e: Enemy = g._spawn(s[0], s[1], NavGrid.cell_centre(s[0]) + Vector3(0, s[2], 0))
		e.slow(0.0001, 1.0e9)
		e.hp = 1.0e9
		targets.append(e)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 35
	process_frame.connect(_tick)


func _tick() -> void:
	var dt := 0.016 * (0.25 if slow else 1.0)
	Engine.time_scale = 0.25 if slow else 1.0
	g.step(dt)
	var tw: Tower = towers[focus]
	var c := tw.crew.global_position + Vector3(0, 0.012, 0)
	cam.global_position = c + Vector3(sin(yaw), 0.55, cos(yaw)).normalized() * dist
	cam.look_at(c, Vector3.UP)
	if _edge(KEY_1):
		focus = 0
	if _edge(KEY_2):
		focus = 1
	if _edge(KEY_3):
		focus = 2
	if _edge(KEY_S):
		slow = not slow
	if _edge(KEY_ESCAPE):
		quit()
	if Input.is_key_pressed(KEY_LEFT):
		yaw -= 0.03
	if Input.is_key_pressed(KEY_RIGHT):
		yaw += 0.03
	if Input.is_key_pressed(KEY_UP):
		dist = maxf(0.06, dist - 0.002)
	if Input.is_key_pressed(KEY_DOWN):
		dist = minf(0.5, dist + 0.002)


func _edge(key: Key) -> bool:
	## true once when the key goes down (a SceneTree script gets no _input, so the keys are polled)
	var now := Input.is_key_pressed(key)
	var fired: bool = now and not _was.get(key, false)
	_was[key] = now
	return fired
