class_name GameHand
extends XRController3D
## One hand in the slice: the aim pose is a pointing ray, a pinch (trigger_click) or grasp (grip_click)
## presses whatever the ray points at (a button or a board cell). Same action map as the spike's HandInput.

signal pressed(hand: GameHand)

const PRESS_ACTIONS := ["trigger_click", "grip_click", "select_button"]

var _down := {}


func _ready() -> void:
	button_pressed.connect(func(action: String):
		if action in PRESS_ACTIONS:
			if _down.is_empty():
				pressed.emit(self)
			_down[action] = true)
	button_released.connect(func(action: String): _down.erase(action))
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
	add_child(ray)


func ray_origin() -> Vector3:
	return global_position


func ray_dir() -> Vector3:
	return -global_transform.basis.z
