class_name Warden
extends RefCounted
## The boss's three phases (Siddharth 2026-10-25: a simple 3-phase Warden for M1; all numbers in GameConfig are
## stand-ins). Ticked by Game.step() while the boss is alive.
##   1  The Warden walks to the houses and summons Grunts beside it every WARDEN_SUMMON_EVERY seconds. When its
##      phase HP is gone the phase ends instead of the Warden dying.
##   2  Shielded by WARDEN_CRYSTALS crystals that ring it and travel with it. It takes no damage until every
##      crystal is broken (towers and spells hit them like any ground enemy).
##   3  Enraged (speed and damage x WARDEN_ENRAGE) with a fresh WARDEN_P3_HP; Wisps rise from random forest
##      edges every WARDEN_WISP_EVERY seconds. Killing it ends the night.
##   4  (the user, 2026-11-11: four forms, A -> B -> C -> D) The final stand: it blooms. Thorn vines (WARDEN_VINES,
##      stand-in crystals) ring it; while any stands it heals WARDEN_VINE_HEAL HP a second. Killing it ends the night.
## Each phase is its own body: Enemy.BOSS_FORMS[phase - 1]. NOT built yet: the vines slowing the towers' fire.

const WARDEN_VINES := 3  # phase 4: how many vines (stand-in crystals) ring it
const WARDEN_VINE_HEAL := 2.0  # phase 4: HP a second healed while a vine stands
const WARDEN_P4_HP := 150.0  # phase 4 HP (before the night/loop scale)

const PURPLE := Color(0.42, 0.25, 0.62)  # the Warden is purple (art bible); the shield tints it
const ENRAGED := Color(0.45, 0.1, 0.08)

var game  # Game
var boss: Enemy
var phase := 1
var crystals: Array[Enemy] = []

var _scale := 1.0  # the boss's night/loop HP scale, applied to the phase HP
var _timer := 0.0
var _spin := 0.0
var _telegraphed := false  # phase 1: the summon rings are showing
var grove: Grove  # phase 4 on loop 2+ (GameConfig.GROVE_FROM_LOOP): seeds, stranglers, branch lash
var veins: BossVeins  # phase 2 and 4: the glowing roots between Skotos and his knots (looks only)

const KNOT_RING := 0.28  # m from Skotos: well outside his root mantle (radius about 0.12 m at BOSS_SCALE 0.65), on the arc toward the board centre
const SUMMON_TELEGRAPH := 0.7  # seconds before a summon that the purple rings show (the summon itself is not delayed)


func _init(g, b: Enemy) -> void:
	game = g
	boss = b
	_scale = b.hp / GameConfig.ENEMIES["boss"]["hp"]
	boss.stats = boss.stats.duplicate()  # phase 3 changes its speed and damage, not the shared config
	boss.on_zero = _phase_over


func step(delta: float) -> void:
	if not is_instance_valid(boss) or not boss.alive:
		for c in crystals:  # shield crystals or vines still standing go with it
			if is_instance_valid(c) and c.alive:
				c.take_damage(99999.0, false)
		crystals.clear()
		cleanup()
		game.warden = null
		return
	match phase:
		1:
			_timer += delta
			if _timer >= GameConfig.WARDEN_SUMMON_EVERY - SUMMON_TELEGRAPH and not _telegraphed:
				_telegraphed = true
				if game.with_rig and boss._vfx != null:
					boss._vfx.cast(SUMMON_TELEGRAPH + 0.6)
					for i in GameConfig.WARDEN_SUMMON_COUNT:
						BossVfx.telegraph(boss.get_parent(), _summon_pos(i), GameConfig.CELL * 0.55, SUMMON_TELEGRAPH + 0.2)
			if _timer >= GameConfig.WARDEN_SUMMON_EVERY:
				_timer = 0.0
				_telegraphed = false
				for i in GameConfig.WARDEN_SUMMON_COUNT:
					var at := _summon_pos(i)
					if game.with_rig:
						BossVfx.root_mound(boss.get_parent(), at)  # the Grunt pushes up out of a root mound
					var gr: Enemy = game._spawn(boss.cell, "grunt", at)
					if game.with_rig and gr != null and gr._rig != null:
						gr._rig.rise(0.5)  # up out of the mound
		2:
			crystals = crystals.filter(func(c): return is_instance_valid(c) and c.alive)
			if crystals.is_empty():
				_enrage()
				return
			# the knots stand still where they burst up (clear ground, see _knot_spots); they no longer orbit
		4:
			if grove != null:
				grove.step(delta)
			crystals = crystals.filter(func(c): return is_instance_valid(c) and c.alive)
			_spin += delta * 1.2
			for i in crystals.size():
				var a := _spin + TAU * i / crystals.size()
				crystals[i].position = boss.position + Vector3(cos(a), 0, sin(a)) * KNOT_RING
			if not crystals.is_empty():
				boss.hp = minf(boss.hp + WARDEN_VINE_HEAL * _scale * delta, WARDEN_P4_HP * _scale)
		3:
			_timer += delta
			if _timer >= GameConfig.WARDEN_WISP_EVERY:
				_timer = 0.0
				var edges: Array = GameConfig.SPAWNS.keys()
				for i in GameConfig.WARDEN_WISP_COUNT:
					var cells: Array = GameConfig.SPAWNS[edges[game._rng.randi_range(0, edges.size() - 1)]]
					var w: Enemy = game._spawn(cells[game._rng.randi_range(0, cells.size() - 1)], "wisp")
					if game.with_rig and w != null:
						BossVfx.leaf_swirl(w.get_parent(), w.position)  # rises from the tree line in a swirl of leaves


func cleanup() -> void:
	## Phase over, boss dead, night over or rewound: the Grove's saplings, stranglers, roots, lash line and stuns go.
	if grove != null:
		grove.cleanup()
		grove = null


func _knot_spots(n: int) -> Array[Vector3]:
	## Open ground round Skotos for the phase-2 knots (Siddharth/player-critic 2026-11-18): outside his root mantle, on the board,
	## away from houses and towers. Tries three rings and picks the clearest spots at least 0.14 m apart; a fallback keeps the
	## plain ring if nothing is clear.
	var root := boss.get_parent()
	var blockers: Array[Vector3] = []
	for h in game.houses:
		if is_instance_valid(h):
			blockers.append(root.to_local(h.global_position) if root else h.position)
	for t in game.towers:
		if is_instance_valid(t):
			blockers.append(root.to_local(t.global_position) if root else t.position)
	blockers.append(Vector3.ZERO)  # the shrine and statue at the board centre
	# an arc IN FRONT of him (toward the board centre and the player), +-60 degrees, so the knots read as separate targets
	var to_centre := Vector2(-boss.position.x, -boss.position.z)
	var base := to_centre.angle() if to_centre.length() > 0.01 else PI / 2.0
	var out: Array[Vector3] = []
	var slots: Array = []
	for i in n:
		slots.append(deg_to_rad(-60.0 + 120.0 * i / maxf(n - 1.0, 1.0)))
	for sl: float in slots:
		var best := -1.0
		var best_at := Vector3.INF
		for da in [0.0, -12.0, 12.0, -24.0, 24.0]:
			for r in [KNOT_RING, KNOT_RING + 0.05, KNOT_RING - 0.05]:
				var ang := base + sl + deg_to_rad(da)
				var at: Vector3 = boss.position + Vector3(cos(ang), 0, sin(ang)) * r
				if absf(at.x) > 0.5 or absf(at.z) > 0.5:
					continue
				var clear := 0.2
				for bl in blockers:
					clear = minf(clear, Vector2(at.x - bl.x, at.z - bl.z).length())
				for o in out:
					clear = minf(clear, Vector2(at.x - o.x, at.z - o.z).length() * 1.4)
				var score := clear - absf(da) * 0.001 - absf(r - KNOT_RING) * 0.3
				if score > best:
					best = score
					best_at = at
		if best_at != Vector3.INF:
			out.append(best_at)
	var k := 0
	while out.size() < n:  # fallback: an even ring
		var a := TAU * k / float(n)
		out.append(boss.position + Vector3(cos(a), 0, sin(a)) * KNOT_RING)
		k += 1
	return out


func _summon_pos(i: int) -> Vector3:
	var side := Vector3(GameConfig.CELL * 0.8 * (1 if i % 2 == 0 else -1), 0, GameConfig.CELL * 0.4 * i).rotated(Vector3.UP, boss.rotation.y)
	return boss.position + side


func _grow_veins() -> void:
	## Looks only: glowing roots between Skotos and each heartwood knot until it breaks.
	if game.with_rig:
		if is_instance_valid(veins):
			veins.queue_free()
		veins = BossVeins.attach(boss, crystals)


func _phase_over() -> bool:
	## The boss reached 0 HP: true = the phase ended and it lives on, false = it dies (phase 3).
	if phase == 3:
		_final_stand()
		return true
	if phase == 4:
		# the fall is never won (Siddharth 2026-11-17, no killable last-loop Warden): it keeps a sliver of life and the doom starts
		boss.hp = 1.0
		if game.night_time >= 10.0:
			game.night_time = maxf(game.night_time, GameConfig.DOOM_AT - 1.5)
			game._spawn_queue.clear()
		return true
	phase = 2
	boss.set_form(1)
	_timer = 0.0
	boss.hp = 1.0
	boss.shielded = true
	boss.set_tint(PURPLE)
	var spots := _knot_spots(GameConfig.WARDEN_CRYSTALS)
	for i in GameConfig.WARDEN_CRYSTALS:
		var c: Enemy = game._spawn(boss.cell, "crystal", spots[i])
		crystals.append(c)  # a heartwood knot (Enemy._knot), standing on open ground round him
	_grow_veins()
	return true


func _enrage() -> void:
	phase = 3
	_timer = 0.0
	boss.shielded = false
	boss.hp = GameConfig.WARDEN_P3_HP * _scale
	boss.stats["speed"] = GameConfig.ENEMIES["boss"]["speed"] * GameConfig.WARDEN_ENRAGE
	boss.stats["dps"] = GameConfig.ENEMIES["boss"]["dps"] * GameConfig.WARDEN_ENRAGE
	boss.set_tint(ENRAGED)
	boss.set_form(2)


func _final_stand() -> void:
	phase = 4
	_timer = 0.0
	boss.hp = WARDEN_P4_HP * _scale
	boss.set_tint(PURPLE)
	boss.set_form(3)
	for i in WARDEN_VINES:
		crystals.append(game._spawn(boss.cell, "crystal", boss.position))
	_grow_veins()
	if game.loop >= GameConfig.GROVE_FROM_LOOP:
		grove = Grove.new(game, self)  # The Grove Awakens (loop 2+): on top of the vines
