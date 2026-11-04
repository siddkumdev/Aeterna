class_name IslandWorkers
extends Node3D
## The villagers on the planks under the island (Siddharth 2026-10-29: "the workers should seem to channel the energy to it
## occasionally so that it makes it seem like they are maintaining it regularly"). Durva's characters stand at the underside's
## `worker_anchor`s and busy themselves; every so often a random one raises its tool, a thread of fire runs from the tool to the
## seed under the island, and the propulsion flares. Cosmetic. Black, orange and red only.

const CAST := [["fox_wizard", "crew_wizard"], ["builder_ant", "hammer"], ["horn_witch", "crew_wizard"]]
const SCALE := 1.6  # they work far from the seat, so they are drawn bigger than the villagers on the board
const RAISE := 0.5  # seconds the tool goes up before the thread leaves it
const RUN := 0.8  # seconds the thread takes to reach the seed
const FADE := 0.5
const GAP := Vector2(6.0, 14.0)  # seconds between channellings

var workers: Array[CharacterRig] = []
var channels := 0  # how many reached the seed

var _idle: Array[String] = []
var _thrust: IslandThrust
var _thrust_at: Node3D
var _wait := 0.0
var _who := -1
var _t := 0.0
var _thread: MeshInstance3D
var _spark: MeshInstance3D
var _mat: StandardMaterial3D


func setup(under: Node3D) -> void:
	for a in under.find_children("*", "Marker3D", true, false):
		if a.name.ends_with("thrust_anchor"):
			_thrust_at = a
			for c in a.get_children():
				if c is IslandThrust:
					_thrust = c
	var i := 0
	var anchors := under.find_children("*worker_anchor*", "Marker3D", true, false)
	for a: Marker3D in anchors:
		var rig := CharacterRig.new()
		a.add_child(rig)
		rig.setup(CAST[i % CAST.size()][0])
		rig.scale = Vector3.ONE * SCALE
		rig.anim = CAST[i % CAST.size()][1]
		_idle.append(rig.anim)
		var out := Vector3(a.position.x, 0, a.position.z).normalized() + Vector3(0, 0, 1)  # out from the wall and round to the seat
		rig.rotation.y = atan2(out.x, out.z)
		workers.append(rig)
		i += 1
	_mat = ModelUtil.flat_material(VfxKit.FIRE_RED, true, 0.9)  # not additive: on the pale rock that washes out to cream
	_mat.no_depth_test = true  # a vein of fire: it shows through the rock it runs along
	_thread = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.004
	cyl.bottom_radius = 0.004
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 1
	_thread.mesh = cyl
	_thread.material_override = _mat
	_thread.visible = false
	add_child(_thread)
	_spark = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.008
	ball.height = 0.016
	ball.radial_segments = 8
	ball.rings = 4
	_spark.mesh = ball
	_spark.material_override = _mat
	_spark.visible = false
	add_child(_spark)
	_wait = randf_range(1.0, GAP.x)


func channel_now(who := -1) -> void:
	if _who >= 0:
		workers[_who].anim = _idle[_who]
	_wait = 0.0
	_who = who if who >= 0 else randi() % workers.size()
	_t = 0.0
	workers[_who].anim = "channel"


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if workers.is_empty() or _thrust_at == null:
		return
	if _who < 0:
		_wait -= delta
		if _wait <= 0.0:
			channel_now()
		return
	var before := _t
	_t += delta
	var tip := _tool_tip(workers[_who])
	var end := _thrust_at.global_position
	var run := clampf((_t - RAISE) / RUN, 0.0, 1.0)
	var fade := clampf((_t - RAISE - RUN) / FADE, 0.0, 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var from_below := cam == null or cam.global_position.y < global_position.y  # from above it would cross the village: it shows through rock, so it would show through the board too
	_thread.visible = _t >= RAISE and from_below
	_spark.visible = _t >= RAISE and run < 1.0 and from_below
	if _t >= RAISE:
		_lay_thread(tip, tip.lerp(end, run))
		_spark.global_position = tip.lerp(end, run)
		_mat.albedo_color = Color(VfxKit.FIRE_RED, 0.9 * (1.0 - fade))
	if before < RAISE + RUN and _t >= RAISE + RUN:
		channels += 1
		if _thrust:
			_thrust.pulse()
		if is_inside_tree():
			VfxKit.burst(self, end, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 10, 0.1, 0.7, 0.012, -0.05)
	if fade >= 1.0:
		_thread.visible = false
		workers[_who].anim = _idle[_who]
		_who = -1
		_wait = randf_range(GAP.x, GAP.y)


func _tool_tip(rig: CharacterRig) -> Vector3:
	var tip := rig.marker("staff_tip_anchor")
	if tip:
		return tip.global_position
	var item: Node3D = rig.parts.get("item", rig.parts.get("arm_r"))
	return item.global_position + Vector3(0, 0.03, 0)


func _lay_thread(a: Vector3, b: Vector3) -> void:
	## Stretches the unit cylinder from a to b (world).
	var d := b - a
	var length := d.length()
	if length < 0.001:
		_thread.visible = false
		return
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	_thread.global_transform = Transform3D(Basis(x, y * length, x.cross(y)), a.lerp(b, 0.5))
