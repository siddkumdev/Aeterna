class_name HandInput
extends XRController3D
## One hand. Works for real pinching hands (the action map routes pinch/grasp into trigger/grip)
## and for the simulator's controllers (trigger or grip). Uses the aim pose as a pointing ray,
## and falls back to a direct (reach-in) grab when the hand is touching an item.

var placer: TowerPlacer
var hand_id := "hand"
var pressed_actions := {}
var holding := false
var _direct := false
var _last_target := Vector3.ZERO

const PRESS_ACTIONS := ["trigger_click", "grip_click", "select_button"]


var _logged_floats := {}


func _ready() -> void:
	button_pressed.connect(_on_pressed)
	button_released.connect(_on_released)
	input_float_changed.connect(_on_float)
	profile_changed.connect(func(role): print("[hand %s] interaction profile: %s" % [hand_id, role]))
	tracking_changed.connect(func(tracking): print("[hand %s] tracking: %s" % [hand_id, tracking]))


func _on_float(action: String, value: float) -> void:
	## Diagnostics: log the first time each analog action crosses 0.5, to see how a simulated pinch arrives.
	if value > 0.5 and not _logged_floats.get(action, false):
		_logged_floats[action] = true
		print("[hand %s] analog '%s' = %.2f" % [hand_id, action, value])
	elif value < 0.2:
		_logged_floats[action] = false


func ray_origin() -> Vector3:
	return global_position


func ray_dir() -> Vector3:
	return -global_transform.basis.z


func _on_pressed(action: String) -> void:
	print("[hand %s] button pressed: %s" % [hand_id, action])
	if action not in PRESS_ACTIONS:
		return
	pressed_actions[action] = true
	if holding or placer == null:
		return
	var id := placer.pick_by_point(global_position)  # reaching in with the hand wins over the ray
	_direct = id != -1
	if id == -1:
		id = placer.pick_by_ray(ray_origin(), ray_dir())
	if placer.begin_hold(hand_id, id):
		holding = true
		print("[hand %s] picked item %d (%s)" % [hand_id, id, "direct" if _direct else "ray"])


func _on_released(action: String) -> void:
	pressed_actions.erase(action)
	if holding and pressed_actions.is_empty():
		var result := placer.end_hold(hand_id, _target())
		print("[hand %s] released -> %s" % [hand_id, result])
		holding = false
		_direct = false


func _target() -> Vector3:
	if _direct:
		_last_target = global_position
		return _last_target
	var board := placer.board
	var plane := Plane(board.global_transform.basis.y, board.global_position)
	var hit: Variant = plane.intersects_ray(ray_origin(), ray_dir())
	if hit != null:
		_last_target = hit
	return _last_target


func _process(_delta: float) -> void:
	if placer == null:
		return
	if holding:
		placer.update_hold(hand_id, _target())
	else:
		placer.set_hover(placer.pick_by_ray(ray_origin(), ray_dir()))
