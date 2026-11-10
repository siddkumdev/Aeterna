class_name LensView
extends Node3D
## The Crystal Lens as a window you look through. A small SubViewport camera sits at your eye and looks through the
## glass; it draws the real island plus the Foresight overlay (render layer 2, which the main cameras do not draw),
## and the result is shown on the glass. Raise the lens and the future appears in it, nowhere else.
## Cost: one extra small render, switched off whenever the lens is down.

const OVERLAY_LAYER := 2  # render layer bit for Foresight drawings (VisualInstance3D.layers)
const VIEW_SIZE := Vector2i(448, 640)  # the glass is about 7 x 10 cm: same shape

var _vp: SubViewport
var _cam: Camera3D
var _quad: MeshInstance3D
var _glass: MeshInstance3D
var _mat: ShaderMaterial
var _active := false
var _fade := 0.0


func setup(lens: Node3D, centre_local: Vector3, glass_size: Vector2) -> void:
	## Called once, with the lens model, the glass centre in the model's own space and the glass's width x height (m).
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.transparent_bg = false
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.cull_mask = 0xFFFFF  # everything, including the Foresight overlay
	_vp.add_child(_cam)
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/lens_view.gdshader")
	_mat.set_shader_parameter("view", _vp.get_texture())
	_quad = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = glass_size
	_quad.mesh = qm
	_quad.material_override = _mat
	_quad.position = centre_local + Vector3(0, 0, 0.0016)  # just in front of the glass slab
	_quad.visible = false
	lens.add_child(_quad)
	for n in lens.find_children("*__glass", "MeshInstance3D", true, false):
		_glass = n  # the model's own glass slab: hidden while the window is on, so it does not cloud the view


func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_quad.visible = on
	if _glass:
		_glass.visible = not on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_fade = 0.0


func aim(eye: Vector3, glass_centre: Vector3) -> void:
	## Put the camera at the eye, looking through the middle of the glass (world space).
	if not _active or eye.distance_to(glass_centre) < 0.02:
		return
	_cam.global_position = eye
	_cam.look_at(glass_centre, Vector3.UP)
	_cam.near = eye.distance_to(glass_centre) + 0.006  # start just past the glass: the lens must not see itself
	_cam.fov = clampf(rad_to_deg(2.0 * atan(0.05 / maxf(eye.distance_to(glass_centre), 0.05))), 14.0, 60.0)  # the glass's height seen from the eye
	_fade = minf(1.0, _fade + get_process_delta_time() * 5.0)
	_mat.set_shader_parameter("fade", _fade)


func active() -> bool:
	return _active
