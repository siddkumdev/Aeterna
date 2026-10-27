class_name TowerFx
extends Node3D
## The effects of one tower (M2, Siddharth 2026-10-27), built one tower at a time and approved in the game.
## Watches the tower: it changes nothing in it, so it can never alter a gameplay number.
##   Wizard Tower ("fire"): the floating orb is the power source. While the tower aims, the orb dims as the staff
##   charges (a glow growing at the staff knob and a stream of embers running orb -> staff); on the shot the staff
##   flashes and sheds embers, and the orb flares back to full. Without a target the orb idles full and the staff
##   keeps a faint glow. Magic stays black / orange / red.

var tower: Tower
var orb: OrbGlow
var _staff: MeshInstance3D
var _plume: MeshInstance3D  # the painted flame wrapping the staff while it charges
var _idle: CPUParticles3D   # embers drifting off the hat at rest
var _t := 0.0
var _shots := 0
var _charge := 0.0


static func attach(t: Tower, orb_anchor: Node3D) -> TowerFx:
	if t.kind != "fire" or orb_anchor == null:
		return null
	var fx := TowerFx.new()
	fx.name = "Fx"
	t.add_child(fx)
	fx.tower = t
	fx._build_wizard(orb_anchor)
	return fx


func _build_wizard(orb_anchor: Node3D) -> void:
	orb = OrbGlow.new()
	orb_anchor.add_child(orb)
	var d := 0.012
	if orb_anchor.has_meta("ew_size"):
		d = float(orb_anchor.get_meta("ew_size"))
	orb.setup(d)
	_staff = VfxKit.toon_fire(self, 0, Vector2.ONE * 0.02, 0.3, 1.6)  # the painted charge at the staff knob
	VfxKit.toon_set(_staff, "depth_bias", 0.02)  # nearer the camera so the hat and pillars never hide it
	_plume = VfxKit.toon_fire(self, 1, Vector2(0.02, 0.05), 0.0, 1.8)
	VfxKit.toon_set(_plume, "depth_bias", 0.02)
	_idle = VfxKit.trail(self, VfxKit.FIRE_ORANGE, VfxKit.INK, 3, 1.6, 0.003)
	_idle.position = Vector3(0, 0.1, 0)
	_idle.direction = Vector3.UP
	_idle.spread = 40.0
	_idle.initial_velocity_min = 0.004
	_idle.initial_velocity_max = 0.012
	_idle.gravity = Vector3.ZERO
	_shots = tower.shots_fired


func _staff_pos() -> Vector3:
	if tower.crew != null:
		return tower.crew.hand_point()
	return tower.global_position + Vector3(0, 0.06, 0)


func _process(delta: float) -> void:
	if tower == null or orb == null:
		return
	_t += delta
	_charge = 0.0
	if tower.aiming:
		_charge = clampf(1.0 - tower.cooldown / maxf(tower.interval, 0.01), 0.0, 1.0)
	orb.level = 1.0 - 0.75 * _charge  # the orb gives its power to the staff
	var sp := _staff_pos()
	var idle := 0.2 + 0.05 * sin(_t * 3.0)
	var glow := maxf(idle, _charge)
	_staff.global_position = sp
	VfxKit.toon_set(_staff, "size", Vector2.ONE * (0.012 + 0.03 * glow))
	VfxKit.toon_set(_staff, "energy", 0.15 + 1.0 * glow)
	_plume.global_position = sp + Vector3(0, 0.006 + 0.012 * _charge, 0)
	VfxKit.toon_set(_plume, "size", Vector2(0.018 + 0.022 * _charge, 0.016 + 0.024 * _charge))
	_plume.visible = _charge > 0.1
	VfxKit.toon_set(_plume, "energy", 1.1 * _charge * _charge)  # grows as the staff fills, gone when idle
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		_fired(sp)


func _fired(staff_pos: Vector3) -> void:
	orb.flare()
	var fx_root: Node = tower.game.shots_root
	VfxKit.toon_burst(fx_root, staff_pos, 0.1, "burst", 0.3)
	VfxKit.toon_burst(fx_root, staff_pos, 0.1, "ring", 0.3)  # a hard flat ring snaps out of the staff on release
	VfxKit.burst(fx_root, staff_pos, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 8, 0.05, 0.35, 0.004)
