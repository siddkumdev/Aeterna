class_name Tower
extends Node3D
## A built tower (spec 7). Fires at the nearest enemy in range (slice choice, the spec does not set a
## targeting rule) and turns its head or swivel to face it. Towers cannot be damaged in this slice.
## Its numbers are the base stats from GameConfig.TOWERS changed by the ability cards the player holds
## (spec 15); they are worked out once when the tower is built, since cards only change between loops.
## Ticked by Game.step().

var game  # Game
var kind := "fire"
var cfg: Dictionary
var cell := Vector2i.ZERO
var cooldown := 0.0
var shots_fired := 0

# effective stats (base + cards)
var damage := 0.0
var interval := 1.0
var reach := 0.0  # m
var hits_air := false
var shot_mods := {}  # extras handed to each projectile: burn, knockback, patch, slow
var every_nth := 0  # Legendary "every Nth shot" bonus (Quick Fuse 5, Bellows 3), 0 = none

var _turn: Node3D
var _turn_home: Basis
var _muzzle_h := 0.1


func setup(tower_kind: String, top_left: Vector2i) -> void:
	kind = tower_kind
	cfg = GameConfig.TOWERS[kind]
	cell = top_left
	position = NavGrid.footprint_centre(cell, GameConfig.TOWER_SIZE)
	var model: Node3D = load(cfg["scene"]).instantiate()
	add_child(model)
	_muzzle_h = ModelUtil.bounds(model).end.y * 0.8
	var parts := ModelUtil.parts(model)
	_turn = parts.get(cfg["turn_part"])
	if _turn:
		_turn_home = _turn.basis
	_apply_cards()


func _apply_cards() -> void:
	damage = cfg["damage"]
	interval = cfg["interval"]
	var range_cells: float = cfg["range"]
	match kind:
		"fire":
			var q: int = game.card("quick_fuse")
			if q >= 0:
				interval /= 1.0 + Cards.value("quick_fuse", q) / 100.0
				every_nth = 5 if q == 2 else 0
			var e: int = game.card("ember_shot")
			if e >= 0:
				shot_mods["burn"] = Cards.value("ember_shot", e)
				shot_mods["burn_spreads"] = e == 2
		"brazier":
			var b: int = game.card("bellows")
			if b >= 0:
				interval /= 1.0 + Cards.value("bellows", b) / 100.0
				every_nth = 3 if b == 2 else 0
			var h: int = game.card("hot_coals")
			if h >= 0:
				damage = Cards.value("hot_coals", h)
				shot_mods["patch"] = h == 2
		"crossbow":
			var hb: int = game.card("heavy_bolts")
			if hb >= 0:
				damage = Cards.value("heavy_bolts", hb)
				shot_mods["slow"] = hb == 2
			var ld: int = game.card("long_draw")
			if ld >= 0:
				range_cells = Cards.value("long_draw", ld)
				hits_air = ld == 2
	reach = range_cells * GameConfig.CELL


func step(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var target := _nearest()
	if target == null:
		return
	if _turn:
		var d := target.global_position - global_position
		var a := atan2(d.x, d.z) - global_rotation.y
		_turn.basis = Basis(Vector3.UP, a) * _turn_home
	if cooldown <= 0.0:
		cooldown = interval
		shots_fired += 1
		var mods := shot_mods.duplicate()
		mods["damage"] = damage
		if every_nth > 0 and shots_fired % every_nth == 0:
			if kind == "fire":
				mods["damage"] = damage * 2.0
				mods["scale"] = 2.0
			elif kind == "brazier":
				mods["knockback"] = true
		var shot := Projectile.new()
		shot.game = game
		game.shots_root.add_child(shot)
		shot.launch(global_position + Vector3(0, _muzzle_h, 0), target, cfg, reach, mods)
		game.shots.append(shot)


func _nearest() -> Enemy:
	var best: Enemy = null
	var best_d: float = reach
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var v: Vector3 = e.global_position - global_position
		var d := Vector2(v.x, v.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best
