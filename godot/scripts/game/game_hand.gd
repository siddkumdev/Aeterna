class_name GameHand
extends XRController3D
## One hand in the slice: the aim pose is a pointing ray, a pinch (trigger_click) or grasp (grip_click)
## presses whatever the ray points at (a button or a board cell). Same action map as the spike's HandInput.
## On the desktop the MOUSE HAND is one of these too: Game moves it to where the mouse points at the hand
## height set with the wheel, and calls pressed/released itself; its ray is the camera's mouse ray.

signal pressed(hand: GameHand)
signal released(hand: GameHand)  # the last held pinch/grasp let go

const PRESS_ACTIONS := ["trigger_click", "grip_click", "select_button"]

var show_ray := true  # the long pointing ray (off for the mouse hand)
var camera: Camera3D  # set for the mouse hand: the ray follows the mouse instead of the node's rotation
var bubble: MeshInstance3D  # the reach bubble: how close an object must be to be grabbed (debug aid)

var _down := {}
var _bubble_mat: StandardMaterial3D


func _ready() -> void:
	button_pressed.connect(func(action: String):
		if action in PRESS_ACTIONS:
			if _down.is_empty():
				pressed.emit(self)
			_down[action] = true)
	button_released.connect(func(action: String):
		if _down.has(action):
			_down.erase(action)
			if _down.is_empty():
				released.emit(self))
	var tip := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.016
	tip.mesh = sm
	add_child(tip)
	var ray := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(0.002, 0.002, 0.8)
	ray.mesh = rb
	ray.position = Vector3(0, 0, -0.4)
	ray.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF0, 0xC8), true, 0.5)
	ray.visible = show_ray
	add_child(ray)


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


func press() -> void:
	## The mouse hand's pinch (a real hand gets this from the action map).
	if _down.is_empty():
		pressed.emit(self)
	_down["mouse"] = true


func release() -> void:
	if _down.has("mouse"):
		_down.erase("mouse")
		if _down.is_empty():
			released.emit(self)


func ray_origin() -> Vector3:
	if camera:
		return camera.project_ray_origin(get_viewport().get_mouse_position())
	return global_position


func ray_dir() -> Vector3:
	if camera:
		return camera.project_ray_normal(get_viewport().get_mouse_position())
	return -global_transform.basis.z
