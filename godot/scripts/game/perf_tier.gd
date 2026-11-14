class_name PerfTier
extends RefCounted
## Per-device quality for the Meta Quest family (the user, 2026-11-14: hold 72 fps with no lag on every Quest, old ones too).
## Tiers: HIGH = Quest 3 / 3S / Pro, LOW = Quest 2 / Quest 1 / anything unknown on Android, DESKTOP = PC and simulator.
## apply() runs once at start; govern() runs each frame and steps quality down (never back up within a session)
## when the frame rate stays under the target, so a busy night on an old headset still holds its frames.

enum { DESKTOP, LOW, HIGH }

const TARGET_HZ := 72.0
const DIP_FPS := 68.0  # under this for DIP_HOLD seconds = one step down
const DIP_HOLD := 3.0
const MAX_STEP := 3

static var tier := DESKTOP
static var step := 0  # how many downgrades the governor has made
static var _dip_t := 0.0
static var _settle_t := 0.0


static func detect() -> int:
	if OS.get_name() != "Android":
		return DESKTOP
	var model := OS.get_model_name().to_lower()
	for hi in ["quest 3", "quest pro", "eureka", "panther", "seacliff"]:  # product names and Meta's codenames
		if hi in model:
			return HIGH
	return LOW


static func name_of(t: int) -> String:
	return ["desktop", "low", "high"][t]


static func apply(vp: Viewport, env: Environment, sun: DirectionalLight3D, xr: Object) -> void:
	## Sets the starting quality for this device. Desktop keeps everything.
	tier = detect()
	step = 0
	_dip_t = 0.0
	_settle_t = 4.0  # loading hitches are not lag
	if xr != null and "display_refresh_rate" in xr:
		xr.set("display_refresh_rate", TARGET_HZ)  # ask the headset for 72 Hz explicitly
	Engine.physics_ticks_per_second = int(TARGET_HZ)
	Engine.max_physics_steps_per_frame = 2
	print("[perf] tier=%s model=%s" % [name_of(tier), OS.get_model_name()])
	if tier == DESKTOP:
		return
	if env:
		# bloom is a full-screen pass for each eye: on a tiled mobile GPU it costs more than the whole board. The
		# emissive colours stay bright without it.
		env.glow_enabled = false
		env.adjustment_enabled = false
	if sun:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL  # one cascade, not four
		sun.directional_shadow_max_distance = 2.2
		sun.shadow_enabled = tier == HIGH
	RenderingServer.directional_shadow_atlas_set_size(2048 if tier == HIGH else 1024, true)
	if vp:
		vp.msaa_3d = Viewport.MSAA_2X if tier == HIGH else Viewport.MSAA_DISABLED
		vp.scaling_3d_scale = 1.0 if tier == HIGH else 0.9
	if xr != null and "foveation_level" in xr:
		xr.set("foveation_level", 2 if tier == HIGH else 3)


static func govern(delta: float, vp: Viewport, sun: DirectionalLight3D, xr: Object) -> void:
	## One step down after DIP_HOLD seconds under DIP_FPS: shadows off, then stronger foveation, then a lower render scale.
	if tier == DESKTOP or step >= MAX_STEP:
		return
	if _settle_t > 0.0:
		_settle_t -= delta
		return
	var fps := Engine.get_frames_per_second()
	_dip_t = _dip_t + delta if fps < DIP_FPS else maxf(0.0, _dip_t - delta)
	if _dip_t < DIP_HOLD:
		return
	_dip_t = 0.0
	_settle_t = 3.0
	step += 1
	match step:
		1:
			if sun:
				sun.shadow_enabled = false
			if vp:
				vp.msaa_3d = Viewport.MSAA_DISABLED
		2:
			if xr != null and "foveation_level" in xr:
				xr.set("foveation_level", 3)
		3:
			if vp:
				vp.scaling_3d_scale = maxf(0.75, vp.scaling_3d_scale - 0.12)
	print("[perf] fps=%d under %d: quality step %d" % [fps, int(DIP_FPS), step])
