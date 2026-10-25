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
## The loop-2+ 4th phase from the spec is not built.

const PURPLE := Color(0.42, 0.25, 0.62)  # the Warden is purple (art bible); the shield tints it
const ENRAGED := Color(0.45, 0.1, 0.08)

var game  # Game
var boss: Enemy
var phase := 1
var crystals: Array[Enemy] = []

var _scale := 1.0  # the boss's night/loop HP scale, applied to the phase HP
var _timer := 0.0
var _spin := 0.0


func _init(g, b: Enemy) -> void:
	game = g
	boss = b
	_scale = b.hp / GameConfig.ENEMIES["boss"]["hp"]
	boss.stats = boss.stats.duplicate()  # phase 3 changes its speed and damage, not the shared config
	boss.on_zero = _phase_over


func step(delta: float) -> void:
	if not is_instance_valid(boss) or not boss.alive:
		game.warden = null
		return
	match phase:
		1:
			_timer += delta
			if _timer >= GameConfig.WARDEN_SUMMON_EVERY:
				_timer = 0.0
				for i in GameConfig.WARDEN_SUMMON_COUNT:
					var side := Vector3(GameConfig.CELL * 0.8 * (1 if i % 2 == 0 else -1), 0, GameConfig.CELL * 0.4 * i).rotated(Vector3.UP, boss.rotation.y)
					game._spawn(boss.cell, "grunt", boss.position + side)
		2:
			crystals = crystals.filter(func(c): return is_instance_valid(c) and c.alive)
			if crystals.is_empty():
				_enrage()
				return
			_spin += delta * 0.8
			for i in crystals.size():
				var a := _spin + TAU * i / crystals.size()
				crystals[i].position = boss.position + Vector3(cos(a), 0, sin(a)) * GameConfig.WARDEN_CRYSTAL_RING * GameConfig.CELL
		3:
			_timer += delta
			if _timer >= GameConfig.WARDEN_WISP_EVERY:
				_timer = 0.0
				var edges: Array = GameConfig.SPAWNS.keys()
				for i in GameConfig.WARDEN_WISP_COUNT:
					var cells: Array = GameConfig.SPAWNS[edges[game._rng.randi_range(0, edges.size() - 1)]]
					game._spawn(cells[game._rng.randi_range(0, cells.size() - 1)], "wisp")


func _phase_over() -> bool:
	## The boss reached 0 HP: true = the phase ended and it lives on, false = it dies (phase 3).
	if phase != 1:
		return false
	phase = 2
	_timer = 0.0
	boss.hp = 1.0
	boss.shielded = true
	boss.set_tint(PURPLE)
	for i in GameConfig.WARDEN_CRYSTALS:
		var c: Enemy = game._spawn(boss.cell, "crystal", boss.position)
		crystals.append(c)
	return true


func _enrage() -> void:
	phase = 3
	_timer = 0.0
	boss.shielded = false
	boss.hp = GameConfig.WARDEN_P3_HP * _scale
	boss.stats["speed"] = GameConfig.ENEMIES["boss"]["speed"] * GameConfig.WARDEN_ENRAGE
	boss.stats["dps"] = GameConfig.ENEMIES["boss"]["dps"] * GameConfig.WARDEN_ENRAGE
	boss.set_tint(ENRAGED)
