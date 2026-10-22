class_name Tower
extends Node3D
## A built tower (spec 7). Fires at the nearest enemy in range (slice choice, the spec does not set a
## targeting rule) and turns its head or swivel to face it. Towers cannot be damaged in this slice.
## Ticked by Game.step().

var game  # Game
var kind := "fire"
var cfg: Dictionary
var cell := Vector2i.ZERO
var cooldown := 0.0

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
		cooldown = cfg["interval"]
		var shot := Projectile.new()
		shot.game = game
		game.shots_root.add_child(shot)
		shot.launch(global_position + Vector3(0, _muzzle_h, 0), target, cfg, cfg["range"] * GameConfig.CELL)
		game.shots.append(shot)


func _nearest() -> Enemy:
	var best: Enemy = null
	var best_d: float = cfg["range"] * GameConfig.CELL
	for e in game.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var v: Vector3 = e.global_position - global_position
		var d := Vector2(v.x, v.z).length()
		if d <= best_d:
			best_d = d
			best = e
	return best
