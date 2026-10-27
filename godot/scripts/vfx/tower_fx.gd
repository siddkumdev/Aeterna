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
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		_fired(sp)


func _fired(staff_pos: Vector3) -> void:
	orb.flare()
	var fx_root: Node = tower.game.shots_root
	VfxKit.toon_burst(fx_root, staff_pos, 0.07, "burst", 0.3)
	VfxKit.burst(fx_root, staff_pos, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 8, 0.05, 0.35, 0.004)
