class_name Grove
extends RefCounted
## Skotos phase 4 on loop 2+: "The Grove Awakens" (Claude's design, Siddharth delegated 2026-11-18; numbers are GameConfig stand-ins).
##   Seeds: every GROVE_SEED_EVERY s, GROVE_SEEDS seeds land on open ground near towers. A seed is a sapling (an Enemy of kind
##   "crystal", so towers and spells already hit it) that grows for GROVE_SAPLING_GROW s. A sapling still alive then becomes a
##   strangler (same Enemy, more HP) that wraps the nearest tower in roots: that tower cannot fire until the strangler dies.
##   Branch lash: every GROVE_LASH_EVERY s a purple line is drawn from Skotos across the board; GROVE_LASH_WARN s later every
##   tower it crosses is stunned for GROVE_LASH_STUN s.
## Guard towers (kind "spawner") never shoot, so they are neither stunned nor strangled. Ticked by Warden.step() in phase 4.

const PURPLE := Color("9C3EB0")  # palette crystal_purple: the Warden
const BRIGHT := Color("B070E0")
const BARK := Color(0.5, 0.36, 0.22)  # lighter than the boss's bark so a stem reads against the grass
const LEAF := Color(0.36, 0.52, 0.2)

var game  # Game
var warden: Warden
var saplings: Array[Dictionary] = []  # {"e": Enemy, "age": float, "strangler": bool, "tower": Tower held or null, "vis": Node3D, "ring": MeshInstance3D, "roots": Node3D, "hp": float}
var _seed_t := 0.0
var _lash_t := 0.0
var _lash_line: Dictionary = {}  # {"a": Vector3, "b": Vector3, "t": float, "mi": MeshInstance3D}
var _fx: Array[Node] = []  # stun marks and other loose visuals, freed in cleanup()
var _stun_marks := {}  # Tower -> Node3D
var _clock := 0.0
static var _mats := {}  # slot -> shared flat material
var seeds_planted := 0  # counted for tests


func _init(g, w: Warden) -> void:
	game = g
	warden = w
	_seed_t = GameConfig.GROVE_SEED_EVERY - GameConfig.GROVE_SEED_FIRST
	_lash_t = 0.0


func step(delta: float) -> void:
	_clock += delta
	_seed_t += delta
	if _seed_t >= GameConfig.GROVE_SEED_EVERY:
		_seed_t = 0.0
		plant_seeds()
	_lash_t += delta
	if _lash_line.is_empty() and _lash_t >= GameConfig.GROVE_LASH_EVERY - GameConfig.GROVE_LASH_WARN:
		_start_lash()
	if not _lash_line.is_empty():
		_step_lash(delta)
	_step_saplings(delta)
	_step_marks()


# ------------------------------------------------------------------ seeds

func _towers() -> Array:
	return game.towers.filter(func(t): return is_instance_valid(t) and t.cfg["kind"] != "spawner")


func _local(n: Node3D) -> Vector3:
	var root: Node3D = warden.boss.get_parent()
	return root.to_local(n.global_position) if root != null and n.is_inside_tree() else n.position


func _seed_spot() -> Vector3:
	## Open ground 1.5-3 cells from a random tower (anywhere on the board when there are none), off houses, the centre and other seeds.
	var root: Node3D = warden.boss.get_parent()
	var towers := _towers()
	var half: float = float(game.HALF) - GameConfig.CELL * 3.0
	var best := Vector3.INF
	var best_clear := -1.0
	for attempt in 10:
		var c := Vector3.ZERO
		if towers.is_empty():
			c = Vector3(game._rng.randf_range(-half, half), 0.0, game._rng.randf_range(-half, half))
		else:
			var t: Tower = towers[game._rng.randi_range(0, towers.size() - 1)]
			var a: float = game._rng.randf() * TAU
			var r: float = game._rng.randf_range(GameConfig.GROVE_SEED_MIN_CELLS, GameConfig.GROVE_SEED_MAX_CELLS) * GameConfig.CELL
			c = _local(t) + Vector3(cos(a), 0.0, sin(a)) * r
		c.x = clampf(c.x, -half, half)
		c.z = clampf(c.z, -half, half)
		c.y = 0.0
		var clear := 0.2
		for h in game.houses:
			if is_instance_valid(h):
				var hp := _local(h)
				clear = minf(clear, Vector2(c.x - hp.x, c.z - hp.z).length())
		for t in towers:
			var tp := _local(t)
			clear = minf(clear, Vector2(c.x - tp.x, c.z - tp.z).length() - GameConfig.CELL)
		for s in saplings:
			if is_instance_valid(s["e"]):
				clear = minf(clear, Vector2(c.x - s["e"].position.x, c.z - s["e"].position.z).length())
		clear = minf(clear, Vector2(c.x, c.z).length())  # the shrine and statue at the centre
		if clear > best_clear:
			best_clear = clear
			best = c
		if clear >= GameConfig.CELL * 1.2:
			break
	return best


func plant_seeds() -> void:
	if saplings.size() + GameConfig.GROVE_SEEDS > GameConfig.GROVE_MAX_LIVE:
		return  # at the cap: this planting is skipped
	for i in GameConfig.GROVE_SEEDS:
		var at := _seed_spot()
		var e: Enemy = game._spawn(warden.boss.cell, "crystal", at)
		if e == null:
			continue
		e.hp = GameConfig.GROVE_SAPLING_HP
		e.max_hp = e.hp
		var d := {"e": e, "age": 0.0, "tower": null, "strangler": false, "vis": null, "ring": null, "roots": null, "hp": e.hp}
		if game.with_rig:
			_dress_sapling(d)
		saplings.append(d)
		seeds_planted += 1
	game.snd("root_grow", warden.boss.global_position)


static func _mat(slot: String, c: Color) -> StandardMaterial3D:
	## One shared flat material per colour slot.
	if not _mats.has(slot):
		_mats[slot] = ModelUtil.flat_material(c)
	return _mats[slot]


func _bark_cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _leaf(parent: Node3D, r: float, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.5
	sm.radial_segments = 7
	sm.rings = 3
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _dress_sapling(d: Dictionary) -> void:
	var e: Enemy = d["e"]
	for n in [e._knot_holder, e._knot_ring]:  # the heartwood knot look is not used for the grove (its purple beam stays: a target marker above the grass)
		if n != null:
			n.visible = false
	var ring := MeshInstance3D.new()  # the purple ground ring: a seed has been planted here
	ring.mesh = VfxKit.quad(1.0)
	var rm: StandardMaterial3D = VfxKit.material("ring").duplicate()
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.albedo_color = Color(BRIGHT, 0.8)
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.rotation.x = -PI / 2.0
	ring.scale = Vector3.ONE * 0.13
	ring.position.y = 0.03  # above the grass blades
	e.add_child(ring)
	d["ring"] = ring
	var vis := Node3D.new()  # the sapling: a twisted bark stem with a few leaf clumps; scaled up as it grows
	var bark := _mat("_bark_light_mat", BARK.lightened(0.1))
	var leaf := _mat("_leaf_mat", LEAF)
	_bark_cyl(vis, 0.004, 0.007, 0.03, Vector3(0, 0.015, 0), Vector3(0, 0, 0.12), bark)
	_bark_cyl(vis, 0.003, 0.004, 0.026, Vector3(0.004, 0.04, 0), Vector3(0, 0.6, -0.3), bark)
	_bark_cyl(vis, 0.002, 0.003, 0.02, Vector3(-0.004, 0.058, 0.002), Vector3(0.3, 0.2, 0.35), bark)
	_leaf(vis, 0.011, Vector3(0.0, 0.07, 0), leaf)
	_leaf(vis, 0.008, Vector3(0.012, 0.05, 0.004), leaf)
	_leaf(vis, 0.008, Vector3(-0.011, 0.055, -0.003), leaf)
	vis.scale = Vector3.ONE * 0.15
	vis.position.y = 0.0
	e.add_child(vis)
	d["vis"] = vis
	VfxKit.burst(e.get_parent(), e.global_position + Vector3(0, 0.01, 0), BARK.lightened(0.25), BRIGHT, 8, 0.05, 0.5, 0.004, -0.12, false)


func _step_saplings(delta: float) -> void:
	var keep: Array[Dictionary] = []
	for d in saplings:
		var e: Enemy = d["e"]
		if not is_instance_valid(e) or not e.alive:
			_free_visuals(d)
			if d["tower"] != null and is_instance_valid(d["tower"]):
				_release(d["tower"])
			continue
		keep.append(d)
		d["age"] += delta
		var is_strangler: bool = d["strangler"]
		var vis: Node3D = d["vis"]
		if game.with_rig and vis != null:
			if e.hp < d["hp"]:
				vis.scale *= 0.9  # a hit makes it flinch; the growth below restores it
			d["hp"] = e.hp
			var grow := 1.0 if is_strangler else clampf(d["age"] / GameConfig.GROVE_SAPLING_GROW, 0.0, 1.0)
			var target := (0.15 + 0.85 * grow) * 1.3
			if is_strangler:
				target = 1.7
			vis.scale = vis.scale.lerp(Vector3.ONE * target, minf(1.0, delta * 8.0))
			var ring: MeshInstance3D = d["ring"]
			if ring != null:
				var pulse := 0.5 + 0.5 * sin(_clock * 6.0 + d["age"])
				(ring.material_override as StandardMaterial3D).albedo_color = Color(BRIGHT, 0.5 + 0.4 * pulse)
				ring.scale = Vector3.ONE * (0.13 + (0.05 if is_strangler else 0.0))
		if not is_strangler and d["age"] >= GameConfig.GROVE_SAPLING_GROW:
			_become_strangler(d)
	saplings = keep


func _become_strangler(d: Dictionary) -> void:
	var e: Enemy = d["e"]
	var best: Tower = null
	var best_d := INF
	for t in _towers():
		var dist := Vector2(_local(t).x - e.position.x, _local(t).z - e.position.z).length()
		var free_bonus := 0.0 if not t.strangled else 1.0  # prefer a tower nobody holds yet
		if dist + free_bonus < best_d:
			best_d = dist + free_bonus
			best = t
	e.hp = GameConfig.GROVE_STRANGLER_HP
	e.max_hp = e.hp
	d["hp"] = e.hp
	d["strangler"] = true  # grown; with no tower to hold it is just a tree
	d["tower"] = best
	if best == null:
		return
	best.strangled = true
	game.snd("root_grow", best.global_position)
	if game.with_rig:
		_dress_strangler(d, best)


func _dress_strangler(d: Dictionary, t: Tower) -> void:
	var e: Enemy = d["e"]
	var old: Node3D = d["vis"]
	if old != null:
		old.queue_free()
	var vis := Node3D.new()  # bigger twisted trunk with two forks and a leaf crown
	var bark := _mat("_bark_mat", BARK)
	var leaf := _mat("_leaf_dark_mat", LEAF.darkened(0.1))
	_bark_cyl(vis, 0.007, 0.012, 0.04, Vector3(0, 0.02, 0), Vector3(0, 0, 0.1), bark)
	_bark_cyl(vis, 0.005, 0.008, 0.035, Vector3(0.006, 0.05, 0), Vector3(0, 0.5, -0.35), bark)
	_bark_cyl(vis, 0.004, 0.006, 0.03, Vector3(-0.007, 0.06, 0.003), Vector3(0.3, 0.2, 0.45), bark)
	_bark_cyl(vis, 0.003, 0.005, 0.026, Vector3(0.0, 0.085, -0.005), Vector3(-0.2, 0.9, -0.1), bark)
	_leaf(vis, 0.014, Vector3(0.0, 0.1, 0), leaf)
	_leaf(vis, 0.01, Vector3(0.016, 0.075, 0.004), leaf)
	_leaf(vis, 0.01, Vector3(-0.015, 0.08, -0.004), leaf)
	vis.scale = Vector3.ONE * 0.6
	e.add_child(vis)
	d["vis"] = vis
	# the roots: three twisted bands round the tower's base plus tendrils running to the strangler
	var roots := Node3D.new()
	t.add_child(roots)
	var rm := _mat("_bark_mat", BARK)
	for i in 3:
		var tm := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.052 + 0.004 * i
		tor.outer_radius = 0.06 + 0.004 * i
		tor.rings = 10
		tor.ring_segments = 5
		tm.mesh = tor
		tm.material_override = rm
		tm.position = Vector3(0, 0.012 + 0.028 * i, 0)
		tm.rotation = Vector3(0.12 * (i - 1), 0.9 * i, -0.1 * (i - 1))
		roots.add_child(tm)
	var to_s := _local_dir(t, e)
	for k in 3:
		var tendril := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var span := Vector2(to_s.x, to_s.z).length()
		cm.top_radius = 0.003
		cm.bottom_radius = 0.005
		cm.height = span
		cm.radial_segments = 5
		cm.rings = 1
		tendril.mesh = cm
		tendril.material_override = rm
		var ang := atan2(to_s.x, to_s.z) + 0.25 * (k - 1)
		tendril.position = Vector3(sin(ang), 0.0, cos(ang)) * span * 0.5 + Vector3(0, 0.006 + 0.004 * k, 0)
		tendril.basis = Basis(Vector3.UP, ang) * Basis(Vector3.RIGHT, PI / 2.0)
		roots.add_child(tendril)
	d["roots"] = roots
	VfxKit.burst(e.get_parent(), t.global_position + Vector3(0, 0.03, 0), BARK.lightened(0.25), BRIGHT, 14, 0.07, 0.6, 0.006, -0.15, false)


func _local_dir(t: Tower, e: Enemy) -> Vector3:
	## From the tower to the strangler, in the tower's own (unscaled) frame.
	return Vector3(e.position.x - _local(t).x, 0.0, e.position.z - _local(t).z)


func _free_visuals(d: Dictionary) -> void:
	for k in ["roots"]:
		if d[k] != null and is_instance_valid(d[k]):
			d[k].queue_free()
	# vis and ring are children of the enemy and go with it


func _release(t: Tower) -> void:
	## A strangler fell: its tower fires again (unless another strangler still holds it).
	for d in saplings:
		if d["tower"] == t and is_instance_valid(d["e"]) and d["e"].alive:
			return
	t.strangled = false


# ------------------------------------------------------------------ branch lash

func _start_lash() -> void:
	var root: Node3D = warden.boss.get_parent()
	var from: Vector3 = warden.boss.position + Vector3(0, 0.004, 0)
	var towers := _towers()
	var aim := Vector3.ZERO
	if not towers.is_empty():
		aim = _local(towers[game._rng.randi_range(0, towers.size() - 1)])
	var dir := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
	if dir.length() < 0.01:
		dir = Vector3(-from.x, 0.0, -from.z)
	if dir.length() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var to: Vector3 = from + dir * (float(game.HALF) * 2.0 + 0.2)
	_lash_line = {"a": from, "b": to, "t": 0.0, "mi": null, "struck": false}
	if game.with_rig and root != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var span := from.distance_to(to)
		bm.size = Vector3(GameConfig.GROVE_LASH_HALF_WIDTH * GameConfig.CELL * 2.0, 0.002, span)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(PURPLE, 0.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.position = (from + to) * 0.5
		mi.basis = Basis(Vector3.UP, atan2(dir.x, dir.z))
		_lash_line["mi"] = mi
		if warden.boss._vfx != null:
			warden.boss._vfx.cast(GameConfig.GROVE_LASH_WARN + 0.5)


func _step_lash(delta: float) -> void:
	_lash_line["t"] += delta
	var t: float = _lash_line["t"]
	var mi: MeshInstance3D = _lash_line["mi"]
	if not _lash_line["struck"]:
		if mi != null:
			var k := t / GameConfig.GROVE_LASH_WARN
			var pulse := 0.6 + 0.4 * sin(t * 18.0)
			(mi.material_override as StandardMaterial3D).albedo_color = Color(BRIGHT, 0.55 * pulse * minf(1.0, k * 4.0))
		if t >= GameConfig.GROVE_LASH_WARN:
			_strike()
	else:
		if mi != null:
			var f := clampf((t - GameConfig.GROVE_LASH_WARN) / 0.3, 0.0, 1.0)
			(mi.material_override as StandardMaterial3D).albedo_color = Color(Color.WHITE.lerp(BRIGHT, f), 0.9 * (1.0 - f))
		if t >= GameConfig.GROVE_LASH_WARN + 0.3:
			if mi != null:
				mi.queue_free()
			_lash_line = {}


func lash_crosses(t: Tower, a: Vector3, b: Vector3) -> bool:
	var p := _local(t)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var u := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (ap - ab * u).length() <= GameConfig.GROVE_LASH_HALF_WIDTH * GameConfig.CELL


func _strike() -> void:
	_lash_line["struck"] = true
	_lash_t = 0.0  # strike to strike is exactly GROVE_LASH_EVERY
	var a: Vector3 = _lash_line["a"]
	var b: Vector3 = _lash_line["b"]
	game.snd("boss_roar", warden.boss.global_position)
	for t in _towers():
		if lash_crosses(t, a, b):
			t.stun_left = GameConfig.GROVE_LASH_STUN
			if game.with_rig:
				VfxKit.burst(t.get_parent(), t.global_position + Vector3(0, 0.05, 0), BRIGHT, BARK.lightened(0.3), 12, 0.07, 0.5, 0.005, -0.1)


# ------------------------------------------------------------------ stun look

func _step_marks() -> void:
	if not game.with_rig:
		return
	for t: Tower in game.towers:
		if not is_instance_valid(t) or t.cfg["kind"] == "spawner":
			continue
		var marked: bool = _stun_marks.has(t) and is_instance_valid(_stun_marks[t])
		if t.stun_left > 0.0 and not marked:
			var holder := Node3D.new()
			var dome := MeshInstance3D.new()  # a dark purple veil over the tower: dimmed
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.12
			sm.radial_segments = 10
			sm.rings = 5
			dome.mesh = sm
			var dm := StandardMaterial3D.new()
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.albedo_color = Color(0.12, 0.05, 0.2, 0.42)
			dome.material_override = dm
			dome.position.y = 0.05
			dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(dome)
			for i in 3:
				var star := VfxKit.halo(holder, 0.02, Color(BRIGHT, 0.95), "disc")
				star.name = "star%d" % i
			t.add_child(holder)
			_stun_marks[t] = holder
			marked = true
		if marked:
			var h: Node3D = _stun_marks[t]
			if t.stun_left > 0.0:
				t.wobble = sin(_clock * 28.0) * 0.06 * minf(1.0, t.stun_left * 2.0)
				for i in 3:
					var s := h.get_node_or_null("star%d" % i)
					if s != null:
						var a := _clock * 5.0 + TAU * i / 3.0
						s.position = Vector3(cos(a) * 0.05, 0.13 + 0.01 * sin(a * 2.0), sin(a) * 0.05)
			else:
				t.wobble = 0.0
				h.queue_free()
				_stun_marks.erase(t)


# ------------------------------------------------------------------ cleanup

func cleanup() -> void:
	## Boss dead, phase over, night over or rewound: every sapling, strangler, root, line and stun goes.
	for d in saplings:
		_free_visuals(d)
		var e = d["e"]
		if is_instance_valid(e) and e.alive:
			e.alive = false  # silent: no died signal, no death sound or burst
			game.enemies.erase(e)
			e.queue_free()
	saplings.clear()
	if not _lash_line.is_empty():
		var mi = _lash_line.get("mi")
		if mi != null and is_instance_valid(mi):
			mi.queue_free()
		_lash_line = {}
	for t in _stun_marks:
		if is_instance_valid(_stun_marks[t]):
			_stun_marks[t].queue_free()
	_stun_marks.clear()
	for t in game.towers:
		if is_instance_valid(t):
			t.release_grove()
