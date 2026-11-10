class_name HazeDome
extends MeshInstance3D
## Passthrough support and the warm haze over the real room (plan Part D, 2026-11-10).
## try_enable_passthrough() asks OpenXR for alpha blend and makes the viewport and the Environment background
## transparent, so the Quest's passthrough camera feed shows behind the game. It only does anything when an OpenXR
## interface is running and offers ALPHA_BLEND; on the desktop and in the Meta XR Simulator it returns false and
## nothing changes (the opaque grey stand-in background stays).
## The dome itself is hidden until set_active(true): it is the "dim, warm, hazy" overlay for passthrough only.
## Add it under the game root, centred on the board; call set_active(Lighting.enable_passthrough()) after the rig exists.

const HONEY := Color("E8B83A")  # palette.json shell_gold
const ROSE := Color("E58AA0")  # palette.json cloth_rose
const RADIUS := 6.0  # m: far behind the board and the player's reach, so game objects always cover it
const FADE_IN := 2.0  # s for the haze to settle in when passthrough starts

var _mat: ShaderMaterial
var _tween: Tween


static func try_enable_passthrough(vp: Viewport, env: Environment) -> bool:
	## True when the headset now shows the real room behind the game.
	var xr := XRServer.find_interface("OpenXR")
	if xr == null or not xr.is_initialized():
		return false
	if xr.has_method("is_passthrough_supported") and xr.is_passthrough_supported() and not xr.is_passthrough_enabled():
		xr.start_passthrough()  # Meta passthrough (project setting xr/openxr/extensions/meta/passthrough)
	var modes: Array = xr.get_supported_environment_blend_modes()
	if not modes.has(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND) and not (xr.has_method("is_passthrough_enabled") and xr.is_passthrough_enabled()):
		return false
	if modes.has(XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND):
		xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	vp.transparent_bg = true
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	return true


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh = sphere
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/haze_dome.gdshader")
	_mat.set_shader_parameter("honey", HONEY)
	_mat.set_shader_parameter("rose", ROSE)
	_mat.set_shader_parameter("fade", 0.0)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func set_active(on: bool) -> void:
	## Shows the haze (eased in) or hides it.
	if _tween:
		_tween.kill()
	if not on:
		visible = false
		return
	visible = true
	_mat.set_shader_parameter("fade", 0.0)
	_tween = create_tween()
	_tween.tween_method(func(v: float): _mat.set_shader_parameter("fade", v), 0.0, 1.0, FADE_IN)
