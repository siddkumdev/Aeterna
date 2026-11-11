class_name GameHand
extends XRController3D
## One hand in the slice. In VR it is drawn as a glowing god-hand (GodHandVisual, scripts/game/god_hand_visual.gd);
## the old pointing ray and tip ball are gone: the ray stays only as an INVISIBLE far-grab fallback, and a faint
## ember thread shows while a pinch is held. A pinch (trigger_click) or grasp (grip_click) presses whatever is
## in reach or the ray points at (a button or a board cell). Same action map as the spike's HandInput.
## On the desktop the MOUSE HAND is one of these too: Game moves it to where the mouse points at the hand
## height set with the wheel, and calls pressed/released itself; its ray is the camera's mouse ray.
##
## Hand-tracking comfort (2026-11-10, god-hands plan C1):
## - Pinch hysteresis on the real thumb/index distance: a hand-tracked pinch presses at >= PINCH_PRESS and only
##   lets go at <= PINCH_RELEASE, so a wobbling pinch does not drop what you hold. The runtime's own
##   trigger_click still works (controllers, the simulator); the joint pinch is added to it and holds the
##   press while the fingers are still close.
## - A one-euro filter on the aim pose (steady when you hold still, quick when you move).
## - poked(node): the index fingertip touching a node of the group "ew_pokable" (radius = meta "poke_radius",
##   default POKE_RADIUS m) fires once per touch. For plaques and villagers.

signal pressed(hand: GameHand)
signal released(hand: GameHand)
signal cancelled(hand: GameHand)  # the press ended because tracking was lost, not because the player let go  # the last held pinch/grasp let go
signal poked(node: Node3D)  # the index fingertip touched a node of the group "ew_pokable"

const PRESS_ACTIONS := ["trigger_click", "grip_click", "select_button"]
const PINCH_PRESS := 0.85  # joint pinch value (1 = tips touching) that presses
const PINCH_RELEASE := 0.55  # ... and the lower value that lets go
const POKE_RADIUS := 0.02  # m from the fingertip to a pokable node's origin
const POKE_GROUP := &"ew_pokable"
# one-euro filter (position in m, rotation in radians): a low cutoff steadies a still hand, beta opens it up when moving
const FILTER_MIN_CUTOFF := 1.6  # Hz
const FILTER_BETA_POS := 9.0  # extra Hz per m/s of hand speed
const FILTER_BETA_ROT := 1.2  # extra Hz per rad/s of turn
const FILTER_D_CUTOFF := 1.0  # Hz, smoothing of the speed estimate

var show_ray := true  # the long pointing ray (off for the mouse hand); in VR it is invisible
var camera: Camera3D  # set for the mouse hand: the ray follows the mouse instead of the node's rotation
var bubble: MeshInstance3D  # the reach bubble: how close an object must be to be grabbed (debug aid)
var visual: GodHandVisual  # the god-hand (VR only)

var _down := {}
var _bubble_mat: StandardMaterial3D
var _ray: MeshInstance3D
var _thread_mat: StandardMaterial3D
var _xr_live := false
var _pinching := false
var _poking := {}  # node instance id -> true while the fingertip is still on it
var _f_ready := false
var _f_pos := Vector3.ZERO
var _f_vel := Vector3.ZERO
var _f_quat := Quaternion.IDENTITY
var _f_prev_raw_pos := Vector3.ZERO
var _f_prev_raw_quat := Quaternion.IDENTITY
var _orb: MeshInstance3D  # the controller-only stand-in


func _ready() -> void:
	var xr := XRServer.find_interface("OpenXR")
	_xr_live = xr != null and xr.is_initialized()
	button_pressed.connect(func(action: String):
		if action in PRESS_ACTIONS:
			_press_key(action))
	button_released.connect(func(action: String):
		_release_key(action))
	# the far-grab ray: kept for aiming, but not drawn (the hand itself is the pointer)
	_ray = MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.0015, 0.0015, 0.8)
	_ray.mesh = rb
	_ray.position = Vector3(0, 0, -0.4)
	_thread_mat = ModelUtil.flat_material(Color8(0xF6, 0xA4, 0x5D), true, 0.35)  # palette lantern_glow
	_ray.material_override = _thread_mat
	_ray.visible = false
	add_child(_ray)
	if _xr_live and camera == null:
		_make_visual()
	elif camera == null and not _xr_live:
		_make_desktop_tip()


func _make_visual() -> void:
	visual = GodHandVisual.new()
	visual.side = "left" if String(tracker).begins_with("left") else "right"
	visual.controller = self
	visual.name = "god_hand_" + visual.side
	# a sibling under the XROrigin: the joint transforms are in the origin's space
	var host := get_parent()
	if host != null:
		host.add_child.call_deferred(visual)


var press_started_ms := -1  # Time.get_ticks_msec() when the current press began


func _make_desktop_tip() -> void:
	## Desktop/simulator without OpenXR: keep a small warm tip so the hand can be seen (the mouse hand is
	## moved by Game).
	_orb = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	_orb.mesh = sm
	_orb.material_override = ModelUtil.flat_material(Color8(0xFF, 0xD4, 0x5A), true, 0.9)  # palette fire_yellow
	add_child(_orb)


func _press_key(key: String) -> void:
	if _down.is_empty():
		press_started_ms = Time.get_ticks_msec()
		pressed.emit(self)
	_down[key] = true
	_show_thread(true)


func _release_key(key: String, lost := false) -> void:
	## lost: the hand stopped being tracked mid-pinch, so whatever it held is dropped back, never played.
	if _down.has(key):
		_down.erase(key)
		if _down.is_empty():
			if lost:
				cancelled.emit(self)
			else:
				released.emit(self)
			_show_thread(false)


func _show_thread(on: bool) -> void:
	## The faint ember thread: only while pinching at range (nothing within the reach bubble's grab).
	if _ray != null and _xr_live and camera == null:
		_ray.visible = on and show_ray


func _process(delta: float) -> void:
	if camera == null and _xr_live:
		_smooth_pose(delta)
	_update_pinch()
	_update_poke()


func _smooth_pose(delta: float) -> void:
	## One-euro filter on this node's pose (the XR runtime sets the raw pose before _process).
	if delta <= 0.0:
		return
	var raw := global_transform
	var raw_pos := raw.origin
	var raw_quat := raw.basis.get_rotation_quaternion()
	if not _f_ready or raw_pos.distance_to(_f_pos) > 0.5:  # first frame, or the hand jumped (re-tracked): snap
		_f_pos = raw_pos
		_f_quat = raw_quat
		_f_vel = Vector3.ZERO
		_f_prev_raw_pos = raw_pos
		_f_prev_raw_quat = raw_quat
		_f_ready = true
		return
	var a_d := _alpha(FILTER_D_CUTOFF, delta)
	var raw_vel := (raw_pos - _f_prev_raw_pos) / delta
	_f_vel = _f_vel.lerp(raw_vel, a_d)
	var cutoff := FILTER_MIN_CUTOFF + FILTER_BETA_POS * _f_vel.length()
	_f_pos = _f_pos.lerp(raw_pos, _alpha(cutoff, delta))
	var ang := _f_prev_raw_quat.angle_to(raw_quat) / delta
	var cutoff_r := FILTER_MIN_CUTOFF + FILTER_BETA_ROT * ang
	_f_quat = _f_quat.slerp(raw_quat, _alpha(cutoff_r, delta))
	_f_prev_raw_pos = raw_pos
	_f_prev_raw_quat = raw_quat
	global_transform = Transform3D(Basis(_f_quat), _f_pos)


static func _alpha(cutoff: float, dt: float) -> float:
	var tau := 1.0 / (TAU * cutoff)
	return 1.0 / (1.0 + tau / dt)


func _update_pinch() -> void:
	## The joint pinch with hysteresis, added to whatever the runtime reports.
	if visual == null or not visual.tracked:
		if _pinching:
			_pinching = false
			_release_key("pinch", true)  # tracking lost (grace over): a cancel, not a release
		return
	var s := visual.pinch_strength
	if not _pinching and s >= PINCH_PRESS:
		_pinching = true
		_press_key("pinch")
	elif _pinching and s <= PINCH_RELEASE:
		_pinching = false
		_release_key("pinch")


func _update_poke() -> void:
	if visual == null or not visual.tracked:
		return
	var tip := visual.index_tip_global()
	for n in get_tree().get_nodes_in_group(POKE_GROUP):
		var nd := n as Node3D
		if nd == null or not nd.is_inside_tree():
			continue
		var r: float = float(nd.get_meta("poke_radius", POKE_RADIUS))
		var d := nd.global_position.distance_to(tip)
		var id := nd.get_instance_id()
		if d <= r and not _poking.has(id):
			_poking[id] = true
			poked.emit(nd)
		elif d > r * 1.6 and _poking.has(id):
			_poking.erase(id)


func make_bubble(radius: float) -> void:
	## A faint sphere round the hand showing the grab reach; set_bubble_hot lights it when something can be grabbed.
	bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	bubble.mesh = sm
	_bubble_mat = ModelUtil.flat_material(Color8(0xFF, 0xF0, 0xC8), true, 0.12)
	bubble.material_override = _bubble_mat
	add_child(bubble)


func set_bubble_hot(hot: bool) -> void:
	if _bubble_mat:
		_bubble_mat.albedo_color = Color8(0xFF, 0xB0, 0x3C, 0x66) if hot else Color8(0xFF, 0xF0, 0xC8, 0x1E)
	if visual:
		visual.set_hot(hot)  # the fingertips glow hotter when something can be grabbed


func press() -> void:
	## The mouse hand's pinch (a real hand gets this from the action map).
	_press_key("mouse")


func release() -> void:
	_release_key("mouse")


func is_pressing() -> bool:
	## A pinch, grasp or mouse press is being held.
	return not _down.is_empty()


func pressed_within(seconds: float) -> bool:
	## A press is held and began less than `seconds` ago (the UI rig holds still only for that short window).
	return is_pressing() and press_started_ms >= 0 and Time.get_ticks_msec() - press_started_ms < int(seconds * 1000.0)


func touch_point() -> Vector3:
	## Where this hand touches things: for a tracked hand, between the thumb and index tips the player sees (the
	## runtime's aim pose sits a few cm away from the drawn fingers). Controllers, the mouse hand and a hand that
	## has lost tracking: this node's own position, as before.
	if GameConfig.DRAWN_PINCH_TOUCH and camera == null and visual != null and is_instance_valid(visual) and visual.tracked and visual.is_inside_tree():
		return (visual.thumb_tip_global() + visual.index_tip_global()) * 0.5
	return global_position


func ray_origin() -> Vector3:
	if camera:
		return camera.project_ray_origin(get_viewport().get_mouse_position())
	return touch_point()


func ray_dir() -> Vector3:
	if camera:
		return camera.project_ray_normal(get_viewport().get_mouse_position())
	return -global_transform.basis.z
