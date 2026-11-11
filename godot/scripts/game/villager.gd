class_name Villager
extends Node3D
## One villager (VillageLife decides where it goes). It walks a list of cells, does its job, runs home when night falls and
## comes back out at dawn. Cosmetic: nothing can hurt it and it never blocks anything. Ticked by VillageLife.

const WALK := 1.1  # cells per second
const RUN := 6.0  # the night sprint, "as fast" as they can
const SCALE := 0.7

var life  # VillageLife
var key := ""
var job := ""
var voice := ""  # which thoughts.json villager speaks through this one (StoryText)
var said := ""  # the last thought it spoke (the ledger shows it)
var taps := 0  # how many times it was tapped: which of its lines comes next
var home := 0
var rig: CharacterRig
var state := "stay"  # stay / go / startle / enter / inside / wait_out / exit
var claim := Vector3.INF  # a help request: stands here and waves (board-local)
var turn := 0  # which leg of its routine comes next

var _path: Array[Vector2i] = []
var _dest := Vector3.ZERO
var _speed := WALK
var _arrive_anim := "idle"
var _arrive_time := 1.0
var _face := Vector3.INF
var _wait := 0.0
var _yaw := 0.0
var _off := Vector3.ZERO  # keeps two walkers from sharing one line


func setup(life_node, model_key: String, job_name: String, home_house: int, family := "char") -> void:
	life = life_node
	key = model_key
	job = job_name
	home = home_house
	rig = CharacterRig.new()
	add_child(rig)
	rig.setup(key, family)
	rig.scale = Vector3.ONE * SCALE
	_off = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)) * GameConfig.CELL


func put(at: Vector3, anim: String, seconds: float, face := Vector3.INF) -> void:
	## Stands there at once.
	visible = true
	scale = Vector3.ONE
	position = at
	_stop(anim, seconds, face)


func go(path: Array[Vector2i], dest: Vector3, speed: float, anim: String, seconds: float, face := Vector3.INF) -> void:
	_path = path
	_dest = dest
	_speed = speed
	_arrive_anim = anim
	_arrive_time = seconds
	_face = face
	rig.anim = "walk"
	rig.gait = speed
	state = "go"


func run_home(door: Vector3, path: Array[Vector2i]) -> void:
	## Night falls: a startled jump, then a sprint to the door.
	claim = Vector3.INF
	if state == "inside" or state == "enter":
		return
	if state == "wait_out":
		state = "inside"
		return
	_path = path
	_dest = door
	_speed = RUN
	_arrive_anim = "idle"
	_arrive_time = 0.0
	_face = Vector3.INF
	_wait = randf_range(0.05, 0.4)
	rig.anim = "startle"
	rig.gait = 0.0
	state = "startle"


func come_out(after: float) -> void:
	## Dawn: back out of the door, one after the other.
	_wait = after
	state = "wait_out"


func thank() -> void:
	## The help request was done: cheers, then goes back to its day.
	claim = Vector3.INF
	if state == "stay" or state == "go":
		_stop("cheer", 2.2)


func wave_on(face: Vector3) -> void:
	_stop("wave", 3.0, face)


func tick(delta: float) -> void:
	match state:
		"inside":
			return
		"wait_out":
			_wait -= delta
			if _wait <= 0.0:
				visible = true
				position = life.exit_point(self)
				scale = Vector3.ONE * 0.001
				state = "exit"
				life.dust_at(position)
		"exit":
			scale = Vector3.ONE * minf(1.0, scale.x + delta / 0.2)
			if scale.x >= 1.0:
				life.next_goal(self)
		"startle":
			_wait -= delta
			if _wait <= 0.0:
				rig.anim = "walk"
				rig.gait = _speed
				state = "go"
		"enter":
			scale = Vector3.ONE * maxf(0.001, scale.x - delta / 0.12)
			if scale.x <= 0.0011:  # scale is stored in 32 bits, so it never quite equals 0.001
				visible = false
				state = "inside"
		"go":
			_walk(delta)
		_:
			_wait -= delta
			if _face != Vector3.INF:
				_turn_to(_face, delta)
			if _wait <= 0.0:
				life.next_goal(self)


func _walk(delta: float) -> void:
	var goal := NavGrid.cell_centre(_path[0]) + _off if not _path.is_empty() else _dest
	var to := goal - position
	to.y = 0.0
	var stride := _speed * GameConfig.CELL * delta
	_turn_to(goal, delta)
	if to.length() > stride:
		position += to.normalized() * stride
	elif not _path.is_empty():
		position = goal
		_path.remove_at(0)
	else:
		position = goal
		if _speed >= RUN and life.game.phase != Game.Phase.DAY:
			rig.gait = 0.0
			state = "enter"
		else:
			_stop(_arrive_anim, _arrive_time, _face)


func _stop(anim: String, seconds: float, face := Vector3.INF) -> void:
	rig.anim = anim
	rig.gait = 0.0
	_wait = seconds
	_face = face
	state = "stay"


func _turn_to(p: Vector3, delta: float) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.0001:
		_yaw = lerp_angle(_yaw, atan2(d.x, d.z), minf(1.0, delta * 9.0))
		rotation.y = _yaw
