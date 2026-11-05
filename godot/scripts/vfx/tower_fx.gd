class_name TowerFx
extends Node3D
## The effects of one tower (M2, Siddharth 2026-10-27), built one tower at a time and approved in the game.
## Watches the tower: it changes nothing in it, so it can never alter a gameplay number.
##   Wizard Tower ("fire", redone 2026-11-04 in the style of moodboard #44): the floating orb is the source. Flames climb round
##   the tower to it; while the tower aims the orb swells and spins faster and a ring of flame closes in on it; on the shot the
##   fireball leaves the orb, which collapses and fills up again, and a ring runs outward. Magic stays black / orange / red.

var tower: Tower
var orb: OrbGlow
var _staff: MeshInstance3D
var _ring: MeshInstance3D   # the flame ring that closes in on the orb as the shot nears
var _licks: Array[MeshInstance3D] = []  # flames climbing round the tower from the base to the orb
var _orb_size := 0.012
var _lick_phase := 0.0
var _t := 0.0
var _shots := 0
var _charge := 0.0
const LICKS := 2
const LICK_POINTS := 28


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
	if t.kind == "airship" and parts.has("ship"):
		t.add_child(fx)
		fx.tower = t
		fx._build_ship(parts)
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
	_orb_size = d
	_staff = VfxKit.paint(self, 0, Vector2.ONE * 0.022, 0.9, 1.2)  # a small flame in the staff's socket: the wizard feeds the orb
	VfxKit.toon_set(_staff, "depth_bias", 0.01)
	_ring = VfxKit.paint(orb_anchor, 1, Vector2.ONE * d * 3.6, 0.0, 1.2)  # a flame ring closes in on the orb as the shot nears
	VfxKit.toon_set(_ring, "depth_bias", 0.015)
	VfxKit.toon_set(_ring, "face_camera", true)  # always a circle round the orb: lying flat it shrinks to a scratch from the side
	_ring.visible = false
	var orb_at := tower.to_local(orb_anchor.global_position)
	var top := orb_at.y - 0.02
	for i in LICKS:
		var pts := PackedVector3Array()
		for j in LICK_POINTS:
			var k := float(j) / (LICK_POINTS - 1)
			var a := TAU * i / LICKS + k * TAU * 1.25
			var r := lerpf(0.066, 0.014, k)  # clears the hat's brim, then follows the cone in to the orb
			var centre := Vector3(orb_at.x, 0, orb_at.z) * k  # the orb sits off the tower's axis: the flames end in it
			pts.append(centre + Vector3(cos(a) * r, 0.015 + k * top, sin(a) * r))
		var lick := VfxKit.paint_ribbon(self, pts, 0.01, 1.0)
		VfxKit.toon_set(lick, "depth_bias", 0.012)
		VfxKit.toon_set(lick, "lick_len", 0.2)
		_licks.append(lick)
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
	if tower.kind == "airship":
		_process_ship(delta)
		return
	if orb == null:
		return
	_t += delta
	_charge = 0.0
	if tower.aiming:
		_charge = clampf(1.0 - tower.cooldown / maxf(tower.interval, 0.01), 0.0, 1.0)
	orb.charge = _charge
	_staff.global_position = _staff_pos()
	var closing := smoothstep(0.6, 1.0, _charge)
	_ring.visible = closing > 0.0
	if _ring.visible:
		VfxKit.toon_set(_ring, "radius", lerpf(0.82, 0.2, closing * closing))
		VfxKit.toon_set(_ring, "energy", lerpf(0.3, 1.0, closing))
	_lick_phase += delta * (0.2 + 0.25 * _charge)
	for i in _licks.size():  # each flame climbs from the foot of the tower to the orb, one after another
		var k := fmod(_lick_phase + float(i) / LICKS, 1.0)
		VfxKit.toon_set(_licks[i], "head", -0.2 + 1.6 * k)
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		_fired(orb.global_position)


func _fired(at: Vector3) -> void:
	orb.fired()
	var fx_root: Node = tower.game.shots_root
	VfxKit.paint_ring(fx_root, at, _orb_size * 5.0, 0.3, true)
	VfxKit.burst(fx_root, at, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 8, 0.05, 0.4, 0.004, 0.0, false)  # not additive: on pale ground that burns out to white


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


# ---- Airship: the burner flame under the balloon, the muzzle flash and smoke, the balloon bobbing on its tether ------

var _ship: Node3D
var _flag: Node3D
var _ship_home := Transform3D.IDENTITY
var _flag_home := Basis.IDENTITY
var _burner: MeshInstance3D
var _burner_at: Node3D  # the model's burner_anchor, in the balloon's mouth
var _muzzle_at: Node3D  # the model's muzzle_anchor on the barrel


func _build_ship(parts: Dictionary) -> void:
	_ship = parts["ship"]
	_ship_home = _ship.transform
	_flag = parts.get("flag")
	if _flag != null:
		_flag_home = _flag.basis
	for n in ModelUtil.walk(tower):
		if n is Marker3D and str(n.name).ends_with("burner_anchor"):
			_burner_at = n
		elif n is Marker3D and str(n.name).ends_with("muzzle_anchor"):
			_muzzle_at = n
	_burner = VfxKit.toon_fire(self, 1, Vector2(0.014, 0.024), 0.5, 1.6)
	VfxKit.toon_set(_burner, "depth_bias", 0.012)
	_shots = tower.shots_fired


func _process_ship(delta: float) -> void:
	_t += delta
	var charge := 0.0
	if tower.aiming:
		charge = clampf(1.0 - tower.cooldown / maxf(tower.interval, 0.01), 0.0, 1.0)
	# the moored balloon bobs and sways a little (kept under 3 mm so the rope still reaches its bow)
	var bob := Vector3(0, 0.0025 * sin(_t * 1.4), 0)
	var sway := Basis.from_euler(Vector3(sin(_t * 0.9) * 0.025, 0.0, sin(_t * 1.1) * 0.025))
	_ship.transform = Transform3D(_ship_home.basis * sway, _ship_home.origin + bob)
	if _flag != null:
		_flag.basis = _flag_home * Basis.from_euler(Vector3(0.0, sin(_t * 3.1) * 0.2 + sin(_t * 7.3) * 0.05, sin(_t * 2.2) * 0.06))
	# the burner: a small steady flame, roaring up as the cannon charges a shot
	if _burner_at != null:
		_burner.global_position = _burner_at.global_position
	VfxKit.toon_set(_burner, "energy", 0.4 + 0.5 * charge + 0.08 * sin(_t * 8.0))
	VfxKit.toon_set(_burner, "size", Vector2(0.012 + 0.008 * charge, 0.02 + 0.014 * charge))
	if tower.shots_fired != _shots:
		_shots = tower.shots_fired
		if _muzzle_at != null:
			var root: Node = tower.game.shots_root
			VfxKit.toon_burst(root, _muzzle_at.global_position, 0.05, "burst", 0.2)  # the flash
			VfxKit.toon_smoke(root, _muzzle_at.global_position, 0.035, 1.3)  # and a puff of smoke
