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
var _wisps: Array[MeshInstance3D] = []  # painted flame wisps spiralling from the base up to the orb
var _smoke_t := 0.0
var _idle: CPUParticles3D   # embers drifting off the hat at rest
var _t := 0.0
var _shots := 0
var _charge := 0.0
const WISPS := 6


static func attach(t: Tower, orb_anchor: Node3D, parts := {}, gate: Node3D = null) -> TowerFx:
	var fx := TowerFx.new()
	fx.name = "Fx"
	if t.kind == "fire" and orb_anchor != null:
		t.add_child(fx)
		fx.tower = t
		fx._build_wizard(orb_anchor)
		return fx
	if t.kind == "guard" and parts.has("banner"):
		t.add_child(fx)
		fx.tower = t
		fx._build_guard(parts, gate)
		return fx
	if t.kind == "crossbow":
		t.add_child(fx)
		fx.tower = t
		fx._build_bow()
		return fx
	fx.free()
	return null


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
	for i in WISPS:
		var w := VfxKit.toon_fire(self, 0, Vector2.ONE * 0.012, 0.8, 1.5)
		VfxKit.toon_set(w, "depth_bias", 0.012)
		_wisps.append(w)
	_idle = VfxKit.trail(orb_anchor, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 14, 1.6, 0.009)  # ember shower off the orb, clear of the hat
	_idle.position = Vector3(0, -0.004, 0)
	_idle.direction = Vector3.UP
	_idle.spread = 80.0
	_idle.initial_velocity_min = 0.01
	_idle.initial_velocity_max = 0.025
	_idle.gravity = Vector3.ZERO
	_shots = tower.shots_fired


func _staff_pos() -> Vector3:
	if tower.crew != null:
		return tower.crew.hand_point()
	return tower.global_position + Vector3(0, 0.06, 0)


func _process(delta: float) -> void:
	if tower == null:
		return
	if tower.kind == "guard":
		_process_guard(delta)
		return
	if tower.kind == "crossbow":
		_process_bow(delta)
		return
	if orb == null:
		return
	_t += delta
	_charge = 0.0
	if tower.aiming:
		_charge = clampf(1.0 - tower.cooldown / maxf(tower.interval, 0.01), 0.0, 1.0)
	orb.level = 1.0 - 0.75 * _charge  # the orb gives its power to the staff
	var sp := _staff_pos()
	var idle := 0.5 + 0.08 * sin(_t * 3.0)
	var glow := maxf(idle, _charge)
	_staff.global_position = sp
	VfxKit.toon_set(_staff, "size", Vector2.ONE * (0.012 + 0.03 * glow))
	VfxKit.toon_set(_staff, "energy", 0.15 + 1.0 * glow)
	_plume.global_position = sp + Vector3(0, 0.006 + 0.012 * _charge, 0)
	VfxKit.toon_set(_plume, "size", Vector2(0.014 + 0.026 * glow, 0.012 + 0.028 * glow))
	VfxKit.toon_set(_plume, "energy", 0.45 + 0.65 * _charge)  # a small steady flame at rest, full when charged  # grows as the staff fills, gone when idle
	_swirl()
	_smoke_t -= delta
	if _smoke_t <= 0.0:
		_smoke_t = 1.3 + randf() * 0.5
		VfxKit.toon_smoke(tower.game.shots_root, orb.global_position - Vector3(0.006, 0.03, 0), 0.04, 2.4)
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		_fired(sp)


func _fired(staff_pos: Vector3) -> void:
	orb.flare()
	var fx_root: Node = tower.game.shots_root
	VfxKit.toon_burst(fx_root, staff_pos, 0.1, "burst", 0.3)
	VfxKit.toon_burst(fx_root, staff_pos, 0.1, "ring", 0.3)  # a hard flat ring snaps out of the staff on release
	VfxKit.burst(fx_root, staff_pos, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 8, 0.05, 0.35, 0.004)


func _swirl() -> void:
	## The whole tower breathes magic: wisps spiral up round it from the base to the orb, widest at the foot.
	var base := tower.global_position
	var top := orb.global_position.y - base.y - 0.02
	for i in _wisps.size():
		var k := fmod(_t * 0.22 + float(i) / WISPS, 1.0)
		var a := _t * 1.5 + TAU * i / WISPS + k * 4.0
		var r := lerpf(0.04, 0.012, k)
		_wisps[i].global_position = base + Vector3(cos(a) * r, 0.015 + k * top, sin(a) * r)
		VfxKit.toon_set(_wisps[i], "energy", 0.15 + 0.85 * sin(PI * k) * (0.7 + 0.5 * _charge))
		VfxKit.toon_set(_wisps[i], "size", Vector2.ONE * (0.014 + 0.010 * sin(PI * k)))


# ---- Guard Tower: the gate leaves swing open as a Guard steps out, a dust puff, the banner flutters ----------------

var _door_l: Node3D
var _door_r: Node3D
var _banner: Node3D
var _gate: Node3D
var _door_open := 0.0   # 0 shut .. 1 open
var _door_hold := 0.0
var _door_home: Array[Basis] = []
var _banner_home := Basis.IDENTITY
var _guards_seen := 0
var _hearth_t := 0.0
var _forge: MeshInstance3D
var _chimney: Node3D  # the model's smoke_anchor: the flue opening on the armoury roof
const DOOR_SWING := 1.7  # radians (about 100 degrees)


func _build_guard(parts: Dictionary, gate: Node3D) -> void:
	_banner = parts["banner"]
	_banner_home = _banner.basis
	_door_l = parts.get("door_l")
	_door_r = parts.get("door_r")
	_gate = gate
	for d in [_door_l, _door_r]:
		_door_home.append(d.basis if d != null else Basis.IDENTITY)
	_guards_seen = tower.guards.size()
	for n in ModelUtil.walk(tower):
		if n is Marker3D and str(n.name).ends_with("smoke_anchor"):
			_chimney = n
	_forge = VfxKit.toon_fire(self, 0, Vector2.ONE * 0.012, 0.5, 1.4)  # forge glow under the armoury roof
	VfxKit.toon_set(_forge, "depth_bias", 0.012)


func _process_guard(delta: float) -> void:
	_t += delta
	# the banner: a slow sway with a quicker ripple, stronger when a fight is on
	var wind := 0.07 + (0.05 if tower.aiming else 0.0)
	_banner.basis = _banner_home * Basis.from_euler(Vector3(sin(_t * 1.9) * wind * 0.5, 0.0, sin(_t * 1.3) * wind + sin(_t * 5.1) * wind * 0.25))
	# the armoury: a flickering forge glow under the lean-to and hearth smoke rising out of the chimney
	var base := tower.global_position
	_forge.global_position = base + Vector3(0.0275, 0.016, 0.012)
	VfxKit.toon_set(_forge, "energy", 0.45 + 0.2 * sin(_t * 9.0) + 0.1 * sin(_t * 15.0))
	_hearth_t -= delta
	if _hearth_t <= 0.0:
		_hearth_t = 1.0 + randf() * 0.7
		VfxKit.toon_smoke(tower.game.shots_root, _chimney.global_position if _chimney != null else base + Vector3(0.032, 0.0535, -0.012), 0.03, 2.2)
	# a Guard stepping out opens the gate for a moment and puffs dust
	var n := tower.guards.size()
	if n > _guards_seen and tower.game.phase == Game.Phase.NIGHT:
		_door_hold = 0.8
		_dust()
	_guards_seen = n
	_door_hold = maxf(0.0, _door_hold - delta)
	_door_open = move_toward(_door_open, 1.0 if _door_hold > 0.0 else 0.0, delta * 4.0)
	if _door_l != null:
		_door_l.basis = _door_home[0] * Basis.from_euler(Vector3(0, -DOOR_SWING * _door_open, 0))
	if _door_r != null:
		_door_r.basis = _door_home[1] * Basis.from_euler(Vector3(0, DOOR_SWING * _door_open, 0))


func _dust() -> void:
	if _gate == null or not _gate.is_inside_tree():
		return
	VfxKit.toon_dust(tower.game.shots_root, _gate.global_position + Vector3(0, 0.018, 0.01), 0.08)


# ---- Longbow Tower: pale-green wind (moodboard #33): a little tornado round the loaded bolt, a gust ring on release ----

var _vortex: MeshInstance3D
var _bolt_at: Node3D  # the model's bolt_anchor (moves with the bolt)
var _ring_t := 0.0


func _build_bow() -> void:
	for n in ModelUtil.walk(tower):
		if n is Marker3D and str(n.name).ends_with("bolt_anchor"):
			_bolt_at = n
	_vortex = VfxKit.toon_wind(self, 0, Vector2(0.035, 0.06), 0.3, 1.2)
	VfxKit.toon_set(_vortex, "depth_bias", 0.015)
	_shots = tower.shots_fired


func _process_bow(delta: float) -> void:
	_t += delta
	var charge := 0.0
	if tower.aiming:
		charge = clampf(1.0 - tower.cooldown / maxf(tower.interval, 0.01), 0.0, 1.0)
	var at := _bolt_at.global_position if _bolt_at != null else tower.global_position + Vector3(0, 0.05, 0)
	# the wind stands up round the loaded bolt: a low curl at rest, a tall fierce one as the string comes back
	_vortex.global_position = at + Vector3(0, -0.01, 0)
	VfxKit.toon_set(_vortex, "size", Vector2(0.03 + 0.03 * charge, 0.04 + 0.04 * charge))
	VfxKit.toon_set(_vortex, "energy", 0.35 + 0.65 * charge + 0.05 * sin(_t * 4.0))
	# a faint breath of wind rings out across the ground now and then
	_ring_t -= delta
	if _ring_t <= 0.0:
		_ring_t = 2.2 + randf() * 0.8
		var foot := Vector3(tower.global_position.x, tower.game.board.global_position.y, tower.global_position.z)
		VfxKit.toon_wind_burst(tower.game.shots_root, foot, 0.11, "ring", 1.2)
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		_bow_fired(at)


func _bow_fired(at: Vector3) -> void:
	var root: Node = tower.game.shots_root
	VfxKit.toon_wind_burst(root, at, 0.09, "slash", 0.3)  # the string snaps: a white spark with slashes
	VfxKit.toon_wind_burst(root, at - Vector3(0, 0.02, 0), 0.12, "ring", 0.4)  # and a hard gust ring
