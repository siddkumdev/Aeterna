class_name Enemy
extends Node3D
## One enemy, stand-in body (real models come with the character kit): dark ink shapes with ember eyes.
##   grunt     capsule
##   scout     small, thin, with a pointed hood; twice as fast
##   splitter  squat body under a wide mushroom cap; splits into 2 splitlings when it dies
##   splitling a small capsule
##   boss      the Warden, a Grunt 2.5x the size; immune to knockback. Warden (warden.gd) runs its three phases:
##             `shielded` blocks all damage, `on_zero` lets a phase end without dying
##   crystal   a Warden shield crystal: stands where Warden puts it, never moves or attacks, 40 HP
##   wisp      a small flying ink orb with a tail; rises out of the tree line and flies straight at the
##             nearest standing house, hovers over it and hits it. Only air attacks reach it.
##   tunneler  a squat digger; underground it is only a moving dirt mound (cannot be hit), it goes in a
##             straight line and pops up next to the nearest standing house, then fights like a Grunt
##   fog       a Grunt-like walker in pale mist grey; hidden from Foresight (step 3)
## Ground enemies walk cell to cell along their route to the nearest standing house, slightly off the centre
## line (their own `offset`, so a crowd spreads out), then hit the house. Ticked by Game.step(), never by _process, so the
## headless tests can run a night frame by frame.

signal died(enemy: Enemy)

const INK := Color(0.118, 0.102, 0.133)
const MIST := Color(0.62, 0.62, 0.64)
const DIRT := Color(0.36, 0.25, 0.17)
const MODELS := {"grunt": ["blightbark", "bark"], "fog": ["blightbark", "bark"], "scout": ["veilrunner", "veil"], "splitter": ["sporebloom", "spore"],
	"splitling": ["sporebud", "spore"], "wisp": ["lantern_spirit", "lantern"], "tunneler": ["mawdrill", "drill"],
	"boss": ["skotos_v02", "skotos"], "elite_mammoth": ["cinder_mammoth", "elite"], "elite_bear": ["gravemaw_bear", "elite"],
	"elite_orc": ["furnace_orc", "elite"]}
const ELITE_SCALE := 0.3
const BOSS_FORMS: Array[String] = ["skotos_v02", "skotos_p2_v01", "skotos_p3_v01", "skotos_p3_v01"]  # one per Warden phase (Siddharth 2026-11-18: reskin; shed-and-grow forms). A missing GLB falls back to the previous phase's body (see form_key).
const BOSS_SCALE := 0.65  # Skotos is 0.48 m tall at scale 1 (9.6 cells); x 0.65 = 0.31 m = about 2.3 cottages (0.14 m) tall, 0.23 m across: the village stays readable from the seat (player-critic 2026-11-18; was 0.9)
const KNOT_MODEL := "res://assets/boss/ew_boss_heartwood_knot_v01.glb"  # the real knot model, used when present; else the stand-in stump (_knot)
const BARK := Color(0.20, 0.14, 0.10)
const KNOT_SINK := 0.05
const KNOT_PILLAR := 0.12  # m: the light pillar over a knot
const KNOT_RISE := 0.4
const KNOT_GLOW := Color("B070E0")
const MODEL_SCALE := 0.75
# Tower-to-enemy juice (Siddharth 2026-11-16), looks only: the hit enemy's visual freezes for HIT_FREEZE[source] seconds,
# its body squashes and is nudged away from the shot. No damage, speed or timing number is touched.
const HIT_FREEZE := {"crossbow": 0.04, "guard": 0.04, "fire": 0.06, "airship": 0.09}
const FREEZE_GAP := 0.25    # seconds of game time: one freeze per enemy per 0.25 s, so a fast tower cannot hold it still
const SQUASH_TIME := 0.14
const SQUASH_Y := 0.07      # per unit strength (strength = freeze / 0.06); the rig's own hit lean adds 0.1 on top
const SQUASH_XZ := 0.05
const PUSH := 0.003         # metres per unit strength
const BOSS_JUICE := 0.4     # bosses are big: a smaller squash and push, the same freeze
const HURT_BELOW := 0.5

var game  # Game
var kind := "grunt"
var stats: Dictionary
var hp := 20.0
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var target_house := -1
var attacking := false
var alive := true
var offset := Vector3.ZERO  # board-local, within GameConfig.SPREAD cells of the cell centre
var height := 0.045
var is_boss := false
var shielded := false  # the Warden in phase 2: takes no damage while a crystal stands
var blocked_by: Guard  # a Guard that is fighting it: it stops and fights back
var on_zero := Callable()  # the Warden: returns true when 0 HP only ends a phase (it does not die)
var flying := false
var underground := false  # a Tunneler on its way: cannot be hit
var colour := INK
# status effects from cards: burning (Ember Shot, Hot Coals patches) and slowed (Heavy Bolts Legendary)
var burn_dps := 0.0
var burn_left := 0.0
var burn_spreads := false
var slow_left := 0.0
var slow_factor := 1.0

var _mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _spark_ms := 0  # last hit spark, so a fast tower does not spam them
var _dust_t := 0.0  # a Tunneler's mound drops a puff of dirt now and then
var _body: Node3D
var _vfx: BossVfx  # the Warden's effects (scripts/vfx/boss_vfx.gd)
var _rig: CharacterRig  # the real model and its animation (null when effects are off, or for the Warden and its crystals)
var _mound: MeshInstance3D
var _surface := Vector2i.ZERO  # where a Tunneler comes up
var max_hp := 20.0
var freezes := 0            # how many hit freezes were started (the self-test reads it)
var _age := 0.0             # game time this enemy has been stepped (the freeze gap runs on it)
var _freeze_at := -1000.0
var _jt := 0.0
var _js := 0.0
var _jdir := Vector3.ZERO
var _hurt := false
var _knot_holder: Node3D
var _knot_burst_done := false
var _knot_core: MeshInstance3D  # the bright purple heart (pulses, flashes white when hit)
var _knot_glow: MeshInstance3D
var _knot_ring: MeshInstance3D  # purple ground ring: "break this"
var _knot_flash := 0.0
var _knot_pillar: MeshInstance3D  # a thin soft purple light pillar over the knot: a separate target from the seat


func setup(enemy_kind: String, night: int, loop: int, rng: RandomNumberGenerator) -> void:
	## night and loop are 0-based; HP grows by HP_RAMP_PER_NIGHT each night and by LOOP_HP_STEP each loop.
	kind = enemy_kind
	stats = GameConfig.ENEMIES[kind]
	is_boss = stats.get("boss", false)
	flying = stats.get("flying", false)
	underground = stats.get("burrows", false)
	colour = MIST if stats.get("hidden", false) else INK
	_body = Node3D.new()
	add_child(_body)
	hp = stats["hp"] * (1.0 + GameConfig.HP_RAMP_PER_NIGHT * night) * (1.0 + GameConfig.LOOP_HP_STEP * loop)
	if stats.get("static", false):
		hp = stats["hp"]  # crystals do not scale with the night or the loop
	max_hp = hp
	var s := GameConfig.SPREAD * GameConfig.CELL
	offset = Vector3(rng.randf_range(-s, s), 0.0, rng.randf_range(-s, s))
	match kind:
		"scout":
			height = 0.036
			_capsule(0.008, 0.03)
			_cone(0.009, 0.014, 0.034)
			_eyes(0.0035, 0.024, 0.007)
		"splitter":
			height = 0.05
			_capsule(0.013, 0.034)
			_cap(0.024, 0.014, 0.036)
			_eyes(0.006, 0.024, 0.012)
		"splitling":
			height = 0.026
			_capsule(0.008, 0.024)
			_eyes(0.003, 0.017, 0.0072)
		"wisp":
			height = 0.024
			_ball(0.01, 0.012)
			_tail(0.006, 0.02, 0.012)
			_eyes(0.004, 0.014, 0.008)
		"tunneler":
			height = 0.04
			_capsule(0.015, 0.04)
			_cone(0.008, 0.012, 0.03)  # digging snout on top, tipped forward below
			_eyes(0.006, 0.028, 0.013)
			_mound = MeshInstance3D.new()
			var mm := SphereMesh.new()
			mm.radius = 0.018
			mm.height = 0.018
			mm.is_hemisphere = true
			_mound.mesh = mm
			_mound.material_override = ModelUtil.flat_material(DIRT)
			add_child(_mound)
			_body.visible = false
		"crystal":
			height = 0.06
			colour = Color(0.66, 0.45, 0.95)  # Warden purple, light enough to spot
			_crystal(0.012, 0.03, 0.04)
			if game != null and game.with_rig:
				_knot()
		"boss":
			height = 0.112
			_capsule(0.03, 0.112)
			_eyes(0.011, 0.08, 0.026)
		_:
			_capsule(0.012, 0.045)
			_eyes(0.0045, 0.032, 0.0102)
	if game != null and game.with_rig and MODELS.has(kind):
		_use_model()


static func form_key(i: int) -> String:
	## The model of Warden form i (0-based). A phase whose GLB is not there yet wears the previous phase's body.
	i = clampi(i, 0, BOSS_FORMS.size() - 1)
	while i > 0 and not ResourceLoader.exists(CharacterRig.model_path(BOSS_FORMS[i])):
		i -= 1
	return BOSS_FORMS[i]


func _use_model() -> void:
	## Durva's model instead of the stand-in shapes (test import 2026-11-03, her designs are awaiting approval).
	for c in _body.get_children():
		c.free()
	_mats.clear()
	_rig = CharacterRig.new()
	_body.add_child(_rig)
	_rig.setup(form_key(0) if is_boss else MODELS[kind][0], MODELS[kind][1])
	_rig.set_hurt(_hurt)
	_rig.scale = Vector3.ONE * (BOSS_SCALE if is_boss else (ELITE_SCALE if stats.get("elite", false) else MODEL_SCALE))
	if stats.get("elite", false):
		var fire := _rig.marker("flame_anchor")
		if fire:
			VfxKit.trail(fire, Color("F6A45D"), Color("E8452C"), 18, 0.9, 0.005).gravity = Vector3(0, 0.03, 0)
	if stats.get("hidden", false):
		_rig.set_misty()
	if is_boss:
		height = 0.22  # the chest knot sits at about 0.16 m: shots and sparks aim there, not at the stand-in capsule's height
	if is_boss and game != null and game.with_rig:
		_vfx = BossVfx.new()
		_vfx.setup(self)


func _knot() -> void:
	## Phase 2's shield pieces are heartwood knots: dark knotted stumps with a purple glowing core that burst up out of the
	## ground (the real model when it exists, else a stump built from primitives). Same HP and mechanics as the crystal.
	for c in _body.get_children():
		c.free()
	_mats.clear()
	var holder := Node3D.new()
	_body.add_child(holder)
	var core_parent: Node3D = holder
	if ResourceLoader.exists(KNOT_MODEL):
		var m: Node3D = load(KNOT_MODEL).instantiate()
		m.scale = Vector3.ONE * 1.5
		holder.add_child(m)
		for n in ModelUtil.walk(m):
			if n is Marker3D and str(n.name).ends_with("core_anchor"):
				core_parent = n
	else:
		var bark := ModelUtil.flat_material(BARK)
		var parts := [[0.016, 0.022, 0.034, Vector3(0, 0.017, 0)], [0.011, 0.015, 0.03, Vector3(0.007, 0.043, -0.003)],
			[0.007, 0.01, 0.022, Vector3(-0.011, 0.03, 0.006)]]
		for pr in parts:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = pr[0]
			cm.bottom_radius = pr[1]
			cm.height = pr[2]
			cm.radial_segments = 7
			cm.rings = 1
			mi.mesh = cm
			mi.material_override = bark
			mi.position = pr[3]
			mi.rotation = Vector3(0.18 * pr[3].x * 40.0, 0.4, -0.25 * pr[3].x * 40.0)
			holder.add_child(mi)
		core_parent.position = Vector3(0, 0.032, 0.014)
	var csz := float(core_parent.get_meta("ew_size", 0.02))
	_knot_glow = VfxKit.halo(core_parent, maxf(csz, 0.02) * 6.0, Color(KNOT_GLOW, 0.5))  # a soft purple light round the heart
	_knot_core = VfxKit.halo(core_parent, maxf(csz, 0.02) * 2.4, Color(KNOT_GLOW.lightened(0.2), 0.95), "disc")  # the bright heart
	_knot_core.position.z = 0.012
	_knot_ring = MeshInstance3D.new()  # a purple ring on the ground under it: a target
	_knot_ring.mesh = VfxKit.quad(1.0)
	var rm: StandardMaterial3D = VfxKit.material("ring").duplicate()
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.albedo_color = Color(KNOT_GLOW, 0.8)
	_knot_ring.material_override = rm
	_knot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_knot_ring.rotation.x = -PI / 2.0
	_knot_ring.scale = Vector3.ONE * 0.11
	_knot_ring.position.y = 0.012
	add_child(_knot_ring)
	_knot_pillar = MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.006
	pm.bottom_radius = 0.014
	pm.height = KNOT_PILLAR
	pm.radial_segments = 8
	pm.rings = 1
	pm.cap_top = false
	pm.cap_bottom = false
	_knot_pillar.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.albedo_color = Color(KNOT_GLOW, 0.3)
	_knot_pillar.material_override = pmat
	_knot_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_knot_pillar.position.y = KNOT_PILLAR * 0.5
	add_child(_knot_pillar)
	height = 0.06
	_knot_holder = holder
	holder.position.y = -KNOT_SINK  # bursts up out of the ground (step() raises it)


func knot_burst(world_pos: Vector3) -> void:
	## Bark splinters and a purple flash (spawn and break); looks only.
	var root := get_parent()
	if root == null or not is_inside_tree():
		return
	VfxKit.burst(root, world_pos + Vector3(0, 0.02, 0), BARK.lightened(0.25), BARK, 14, 0.07, 0.6, 0.006, -0.18, false)
	VfxKit.burst(root, world_pos + Vector3(0, 0.03, 0), KNOT_GLOW, Color("E8452C"), 8, 0.05, 0.5, 0.005, -0.05)
	VfxKit.flash(root, world_pos + Vector3(0, 0.03, 0), Color(KNOT_GLOW, 0.7), 0.06, 0.25)


func _capsule(r: float, h: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	m.mesh = cm
	m.position.y = h / 2.0
	_paint(m)


func _crystal(r: float, h: float, y: float) -> void:
	## a floating diamond: two cones base to base, centred at height y
	for flip in [1, -1]:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		m.mesh = cm
		m.position.y = y + flip * h / 2.0
		if flip == -1:
			m.rotation.x = PI
		_paint(m)


func _ball(r: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	m.position.y = y
	_paint(m)


func _tail(r: float, length: float, y: float) -> void:
	## a cone trailing behind (-Z) the body
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = length
	m.mesh = cm
	m.rotation.x = -PI / 2.0
	m.position = Vector3(0, y, -length / 2.0)
	_paint(m)


func _cone(r: float, h: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.position.y = y + h / 2.0
	_paint(m)


func _cap(r: float, h: float, y: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = h * 2.0
	sm.is_hemisphere = true
	m.mesh = sm
	m.position.y = y
	_paint(m)


func _paint(m: MeshInstance3D) -> void:
	var mat := ModelUtil.flat_material(colour)
	m.material_override = mat
	_mats.append(mat)
	_body.add_child(m)


func _eyes(spread: float, y: float, z: float) -> void:
	var eye_mat := ModelUtil.flat_material(Color8(0xFF, 0x8A, 0x2A), true)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = spread * 0.6
		em.height = spread * 1.2
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(side * spread, y, z)
		_body.add_child(eye)


func spawn_at(spawn_cell: Vector2i, at := Vector3.INF) -> void:
	cell = spawn_cell
	position = NavGrid.cell_centre(cell) + offset if at == Vector3.INF else at
	if flying:
		position.y = 1.5 * GameConfig.CELL  # rises out of the tree line
	elif _rig and at == Vector3.INF and not underground:
		_rig.rise(0.5)  # comes up out of the ground at the forest's edge
	_reroute()


func targetable(air: bool, ground: bool) -> bool:
	## Can an attack that hits air and/or ground reach this enemy right now?
	return alive and not underground and (air if flying else ground)


func _reroute() -> void:
	attacking = false
	if stats.get("static", false):
		return
	if flying or underground:
		target_house = game.nearest_house_to(position)
		path = []
		if underground and target_house != -1:
			_surface = game.surface_cell(target_house, position)  # the free cell by that house nearest to it
		return
	var r: Dictionary = game.nav.route(cell, game.standing_houses())
	if r.is_empty():
		path = []
		target_house = -1
		return
	target_house = r["house"]
	path = r["path"]
	if not path.is_empty() and path[0] == cell:
		path.remove_at(0)


func step(delta: float) -> void:
	if not alive:
		return
	_age += delta
	if _knot_holder != null:
		var k := clampf(_age / KNOT_RISE, 0.0, 1.0)
		var back := 1.0 + 2.7 * pow(k - 1.0, 3.0) + 1.7 * pow(k - 1.0, 2.0)  # ease out back: overshoots, settles
		_knot_holder.position.y = -KNOT_SINK * (1.0 - back)
		_knot_flash = maxf(0.0, _knot_flash - delta / 0.2)
		var pulse := 0.75 + 0.25 * sin(_age * 4.0 + position.x * 40.0)
		VfxKit.set_halo(_knot_core, 0.036 * (0.9 + 0.2 * pulse + 0.6 * _knot_flash), Color(KNOT_GLOW.lightened(0.2).lerp(Color.WHITE, _knot_flash), 0.95))
		VfxKit.set_halo(_knot_glow, 0.12 * (0.9 + 0.2 * pulse + 0.4 * _knot_flash), Color(KNOT_GLOW, 0.4 + 0.25 * pulse + 0.3 * _knot_flash))
		_knot_holder.scale = Vector3.ONE * (1.0 + 0.15 * _knot_flash)
		(_knot_ring.material_override as StandardMaterial3D).albedo_color = Color(KNOT_GLOW, 0.55 + 0.35 * pulse)
		(_knot_pillar.material_override as StandardMaterial3D).albedo_color = Color(KNOT_GLOW, (0.4 + 0.2 * pulse + 0.4 * _knot_flash) * minf(1.0, _age / KNOT_RISE))
		if not _knot_burst_done and is_inside_tree():
			_knot_burst_done = true  # the knot spawns on its spot: the burst fires there
			knot_burst(global_position)
	if _jt > 0.0:
		_tick_juice(delta)
	_sync_hurt()
	if _rig:
		_rig.anim = "attack" if attacking or blocked_by != null else ("idle" if target_house == -1 else "walk")
		_rig.gait = stats["speed"] * slow_factor
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			for m in _mats:
				m.albedo_color = colour
	if burn_left > 0.0:
		burn_left -= delta
		take_damage(burn_dps * delta, false)
		if not alive:
			return
	if underground and _mound != null and game != null and game.with_rig and is_inside_tree():
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.5
			if VfxKit.active_bursts() <= VfxKit.MAX_BURSTS - 8:  # keep room for the towers and spells
				VfxKit.toon_dust(get_parent(), global_position, 0.022)
	if slow_left > 0.0:
		slow_left -= delta
		if slow_left <= 0.0:
			slow_factor = 1.0
	if stats.get("static", false):
		return  # a crystal only stands there (Warden moves it)
	if blocked_by != null:
		if is_instance_valid(blocked_by) and blocked_by.alive and not underground:
			_face(position + (blocked_by.global_position - global_position))
			blocked_by.take_damage(stats["dps"] * delta)  # it fights the Guard instead of walking on
			return
		blocked_by = null
	if target_house == -1 or game.houses[target_house].is_shuttered:
		_reroute()
		if target_house == -1:
			return  # nothing left to reach: stands still until the night ends
	if attacking:
		game.houses[target_house].damage(stats["dps"] * delta)
		return
	var stride: float = stats["speed"] * slow_factor * GameConfig.CELL * delta
	if flying or underground:
		_move_straight(stride)
		return
	if path.is_empty():
		attacking = true
		_face(NavGrid.footprint_centre(game.houses[target_house].cell, GameConfig.TOWER_SIZE))
		return
	var goal := NavGrid.cell_centre(path[0]) + offset
	var to := goal - position
	_face(goal)
	if to.length() <= stride:
		position = goal
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * stride


func _move_straight(stride: float) -> void:
	## Flyers head for a point fly_height cells over the house; a Tunneler for its surfacing cell.
	var goal: Vector3
	if flying:
		goal = game.house_point(target_house) + offset + Vector3(0, stats["fly_height"] * GameConfig.CELL, 0)
	else:
		goal = NavGrid.cell_centre(_surface) + offset
	var to := goal - position
	_face(goal)
	if to.length() <= stride:
		position = goal
		cell = NavGrid.local_to_cell(position)
		if flying:
			attacking = true
		else:
			_pop_up()
	else:
		position += to.normalized() * stride
		cell = NavGrid.local_to_cell(position)


func _pop_up() -> void:
	underground = false
	if game != null:
		game.snd("tunneler_pop", global_position)
	if game != null and game.with_rig and is_inside_tree():
		VfxKit.toon_dust(get_parent(), global_position, 0.05)
		VfxKit.burst(get_parent(), global_position + Vector3(0, 0.01, 0), Color("7E6048"), Color("C2B49A"), 8, 0.05, 0.4, 0.005)
	cell = _surface
	_body.visible = true
	_mound.visible = false
	if _rig:
		_rig.rise(0.35)
	_reroute()


func _face(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.0001:
		rotation.y = atan2(d.x, d.z)


func take_damage(amount: float, flash := true, hit_sound := "", hit_weight := 0.0, hit_dir := Vector3.ZERO) -> void:
	## hit_sound: the caller's own sound ("" = none): a hit sounds like the tower or spell that made it, not like the enemy.
	## hit_weight (seconds of freeze, see HIT_FREEZE; 0 = none) and hit_dir (board-world direction of the shot) only drive the
	## hit juice (freeze, squash, push); they never change the damage.
	if not alive or shielded:
		return
	hp -= amount
	if _knot_holder != null:
		_knot_flash = 1.0  # the knot flashes white and swells when hit
	if flash and game != null:
		if hit_sound != "":
			game.snd(hit_sound, global_position)
	if flash:
		for m in _mats:
			m.albedo_color = Color8(0xFF, 0xE6, 0xC8)
		_flash = 0.08
		if _rig:
			_rig.hit()
		if hit_weight > 0.0:
			_juice(hit_weight, hit_dir)
		if _vfx:
			_vfx.hit_pulse()
		if game != null and game.with_rig and is_inside_tree() and Time.get_ticks_msec() - _spark_ms >= 120:
			_spark_ms = Time.get_ticks_msec()
			VfxKit.hit_spark(get_parent(), chest())
	if hp <= 0.0:
		if on_zero.is_valid() and on_zero.call():
			return  # a phase ended, the Warden lives on
		alive = false
		if _knot_holder != null and is_inside_tree():
			knot_burst(global_position)  # the heartwood knot breaks: bark splinters (BossVeins snaps its vein)
		if game != null and game.with_rig and is_inside_tree() and not is_boss and kind != "crystal":
			VfxKit.enemy_death(get_parent(), global_position, kind, flying, height)
			if game.kill_sparks != null:
				game.kill_sparks.spawn(global_position + Vector3(0, height * 0.6, 0))
		if _rig and is_inside_tree():  # the body stays behind a moment and topples
			_body.scale = Vector3.ONE  # the dying body must not inherit a squash or push in progress
			_body.position = Vector3.ZERO
			_rig.reparent(get_parent())
			_rig.die()
			_rig = null
		died.emit(self)
		queue_free()


func _juice(weight: float, dir: Vector3) -> void:
	_js = weight / 0.06 * (BOSS_JUICE if is_boss else 1.0)
	_jt = SQUASH_TIME
	_jdir = Vector3(dir.x, 0.0, dir.z).normalized()
	if _age - _freeze_at >= FREEZE_GAP:
		_freeze_at = _age
		freezes += 1
		if _rig:
			_rig.freeze(weight)


func _tick_juice(delta: float) -> void:
	## Squash and push on the body node (never the gameplay position), springing back over SQUASH_TIME.
	_jt = maxf(0.0, _jt - delta)
	var k := 0.0
	if _jt > 0.0:
		var u := 1.0 - _jt / SQUASH_TIME
		k = (1.0 - u) * (1.0 - u)
	_body.scale = Vector3(1.0 + SQUASH_XZ * _js * k, 1.0 - SQUASH_Y * _js * k, 1.0 + SQUASH_XZ * _js * k)
	var push := _jdir * PUSH * _js * k
	_body.position = global_transform.basis.inverse() * push if is_inside_tree() else push


func _sync_hurt() -> void:
	## Below half HP the enemy looks damaged (darker, cracked, limping); speed and path are unchanged.
	var h: bool = hp > 0.0 and hp < max_hp * HURT_BELOW and not is_boss and not stats.get("static", false)
	if h != _hurt:
		_hurt = h
		if _rig:
			_rig.set_hurt(h)


func set_form(i: int) -> void:
	## The Warden changes body with each phase (BOSS_FORMS). Does nothing while the stand-in capsule is shown.
	if _rig == null or not is_boss:
		return
	var old := _rig
	_rig = CharacterRig.new()
	_body.add_child(_rig)
	_rig.setup(form_key(i), "skotos")
	_rig.set_hurt(_hurt)
	_rig.scale = Vector3.ONE * BOSS_SCALE
	old.queue_free()
	if _vfx == null:
		_vfx = BossVfx.new()
		_vfx.setup(self)
	_vfx.enter_form(i, true)


func set_tint(c: Color) -> void:
	colour = c
	for m in _mats:
		m.albedo_color = c


func chest() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func ignite(dps: float, seconds: float, spreads: bool) -> void:
	## Burning does not stack: the stronger burn wins and the timer refreshes.
	burn_dps = maxf(burn_dps, dps)
	burn_left = maxf(burn_left, seconds)
	burn_spreads = burn_spreads or spreads


func slow(factor: float, seconds: float) -> void:
	slow_factor = minf(slow_factor, factor)
	slow_left = maxf(slow_left, seconds)


func knockback(from: Vector3) -> void:
	## Pushed 1 cell away from `from` (board-local), if that cell can be walked; then re-plans its route.
	if is_boss or flying or underground or not alive or stats.get("static", false):
		return
	var d := position - from
	d.y = 0.0
	if d.length() < 0.0001:
		return
	var step := Vector2i(roundi(d.normalized().x), roundi(d.normalized().z))
	var c := cell + step
	if not game.nav.astar.is_in_boundsv(c) or game.nav.astar.is_point_solid(c):
		return
	cell = c
	position = NavGrid.cell_centre(c) + offset
	_reroute()

