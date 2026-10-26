class_name Guard
extends Node3D
## One Guard of a Guard Tower (Siddharth 2026-10-26). STAND-IN body (CrewMember, kind "guard") until Durva's
## characters exist. It stands at its post (a free cell touching its tower) and never wanders. When a ground enemy
## comes within `sight` cells of the post it walks up and fights it; ground enemies stop to fight a Guard that is hitting
## them (Enemy.blocked_by). When nothing is in sight, or the fight drags it more than `leash` cells from the post, it
## walks back. With the Shield Wall Legendary it can also hit flyers (a Wisp is hit when it is within reach on the
## board, its height is ignored). Ticked by Tower.step() -> Game.step(), like everything else.

signal died(guard: Guard)

var tower  # Tower
var index := 0  # which post of the tower
var hp := 30.0
var max_hp := 30.0
var alive := true
var target: Enemy
var state := "to_post"  # to_post / idle / chase / return

var _crew: CrewMember
var _cool := 0.0
var _ignore := false  # dragged past the leash: walks home before looking for the next enemy
var _cfg: Dictionary


func setup(t, post_index: int, health: float, cfg: Dictionary) -> void:
	tower = t
	index = post_index
	hp = health
	max_hp = health
	_cfg = cfg
	_crew = CrewMember.new()
	add_child(_crew)
	_crew.setup("guard")


func post() -> Vector3:
	return tower.post_point(index)


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func step(delta: float) -> void:
	if not alive:
		return
	var C := GameConfig.CELL
	_crew.walking = false
	_cool = maxf(0.0, _cool - delta * tower.game.spells.haste_at(tower.position))  # Rage rings speed the swing up
	var home := post()
	if target != null and (not is_instance_valid(target) or not target.alive or not target.targetable(tower.guards_air, true)):
		target = null
		state = "return"
	if target != null and _flat_dist(target.global_position, home) > _cfg["leash"] * C:
		_release()
		_ignore = true
		state = "return"
	if target == null and not _ignore:
		target = _find(home)
		if target != null:
			state = "chase"
	match state:
		"chase":
			var d := _flat_dist(target.global_position, global_position)
			if d > _cfg["reach"] * C:
				_walk(target.global_position, delta)
			else:
				_face(target.global_position)
				if target.blocked_by == null or not is_instance_valid(target.blocked_by) or not target.blocked_by.alive:
					target.blocked_by = self
				if _cool <= 0.0:
					_cool = _cfg["attack_interval"]
					target.take_damage(_cfg["guard_damage"])
					_crew.react(target.global_position)
		"return", "to_post":
			if _flat_dist(global_position, home) <= 0.002:
				global_position = Vector3(home.x, global_position.y, home.z)
				state = "idle"
				_ignore = false
			else:
				_walk(home, delta)
		_:
			if _flat_dist(global_position, home) > 0.004:
				state = "return"


func _find(home: Vector3) -> Enemy:
	var best: Enemy = null
	var best_d: float = _cfg["sight"] * GameConfig.CELL
	for e in tower.game.enemies:
		if not is_instance_valid(e) or not e.targetable(tower.guards_air, true):
			continue
		var d := _flat_dist(e.global_position, home)
		if d <= best_d:
			best_d = d
			best = e
	return best


func _walk(goal: Vector3, delta: float) -> void:
	var to := Vector3(goal.x - global_position.x, 0, goal.z - global_position.z)
	var stride: float = _cfg["guard_speed"] * GameConfig.CELL * delta
	_crew.walking = true
	_face(goal)
	if to.length() <= stride:
		global_position += to
	else:
		global_position += to.normalized() * stride


func _face(p: Vector3) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() > 0.0001:
		_crew.set_facing(atan2(d.x, d.z) - tower.global_rotation.y)


func _release() -> void:
	if target != null and is_instance_valid(target) and target.blocked_by == self:
		target.blocked_by = null
	target = null


func take_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0.0:
		die()


func die() -> void:
	alive = false
	_release()
	for e in tower.game.enemies:  # whoever was fighting it is free again
		if is_instance_valid(e) and e.blocked_by == self:
			e.blocked_by = null
	died.emit(self)
	queue_free()
