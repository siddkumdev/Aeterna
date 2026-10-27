class_name Projectile
extends Node3D
## One shot (spec 7). Ticked by Game.step().
##   single: fireball homes on its target and hits only it.
##   splash: cannonball is lobbed at where the target stood and hits every enemy within `splash` cells.
##   pierce: wind bolt flies straight for the tower's range and hits every enemy it passes within
##           `pierce_width` cells, each once.

var game  # Game
var kind := "single"
var damage := 0.0
var speed := 1.0  # m/s
var target: Enemy
var splash := 0.0  # m
var width := 0.0  # m
var done := false
var mods := {}  # card extras from the tower: damage, scale, burn, burn_spreads, knockback, patch, slow

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _flight := 1.0
var _left := 0.0
var _dir := Vector3.ZERO
var _hit := {}
var _fx_kind := ""
var _fx_scale := 1.0
var _glow: MeshInstance3D   # the painted fire head
var _trail: MeshInstance3D  # the painted comet tail
var _last := Vector3.ZERO


func launch(from: Vector3, enemy: Enemy, cfg: Dictionary, reach: float, shot_mods := {}) -> void:
	kind = cfg["kind"]
	mods = shot_mods
	damage = mods.get("damage", cfg["damage"])
	speed = cfg["shot_speed"] * GameConfig.CELL
	splash = cfg.get("splash", 0.0) * GameConfig.CELL
	width = cfg.get("pierce_width", 0.0) * GameConfig.CELL
	target = enemy
	_from = from
	global_position = from
	_to = enemy.chest()
	if kind == "splash":
		_to = enemy.global_position
		_flight = maxf(0.05, _from.distance_to(_to) / speed)
	elif kind == "pierce":
		_dir = _to - _from
		_dir.y = 0.0
		_dir = _dir.normalized()
		_left = reach
		look_at(global_position + _dir, Vector3.UP, true)
	var res = load(cfg["shot"])
	if res:
		var m: Node3D = res.instantiate()
		m.scale = Vector3.ONE * mods.get("scale", 1.0) * cfg.get("shot_scale", 1.0)
		add_child(m)
	_fx_kind = cfg.get("fx", "")
	_fx_scale = mods.get("scale", 1.0) * cfg.get("shot_scale", 1.0)
	if _fx_kind == "fireball":
		# the dark core is wrapped in painted fire (X02): an orb-shaped head and a swept comet tail (moodboard #44/#31)
		var k := _fx_scale
		_glow = VfxKit.toon_fire(self, 0, Vector2(0.05, 0.05) * k, 1.0, 1.4)
		_trail = VfxKit.toon_fire(self, 2, Vector2(0.14, 0.05) * k, 1.0, 1.2)
		_last = from
	elif _fx_kind == "wind":
		# the bolt rides a gust: three swept pale-green streaks behind it (moodboard #33; streaks, never sparkles)
		_trail = VfxKit.toon_wind(self, 1, Vector2(0.14, 0.035) * _fx_scale, 1.0, 1.4)
		_last = from


func step(delta: float) -> void:
	if done:
		return
	_aim_tail()
	match kind:
		"single":
			if is_instance_valid(target) and target.alive:
				_to = target.chest()
			var to := _to - global_position
			var stride := speed * delta
			if to.length() <= stride:
				if is_instance_valid(target) and target.targetable(mods.get("air", false), mods.get("ground", true)):
					_hit_enemy(target)
				_finish()
			else:
				global_position += to.normalized() * stride
		"splash":
			_t += delta / _flight
			var p := _from.lerp(_to, minf(_t, 1.0))
			p.y += 4.0 * (0.03 + _from.distance_to(_to) * 0.25) * _t * (1.0 - _t)
			global_position = p
			if _t >= 1.0:
				var centre: Vector3 = game.board.to_local(_to)
				for e in game.enemies.duplicate():
					if is_instance_valid(e) and _can_hit(e) and _flat(e.global_position - _to) <= splash:
						_hit_enemy(e)
						if mods.get("knockback", false) and is_instance_valid(e) and e.alive:
							e.knockback(centre)
				if mods.get("patch", false):
					game.add_patch(centre, splash, 2.0, 2.0)  # Hot Coals Legendary: 2 damage/s for 2 s
				_finish()
		"pierce":
			var stride := minf(speed * delta, _left)
			var a := global_position
			var b := a + _dir * stride
			for e in game.enemies.duplicate():
				if is_instance_valid(e) and _can_hit(e) and not _hit.has(e) and _seg_dist(e.global_position, a, b) <= width:
					_hit[e] = true
					_hit_enemy(e)
			global_position = b
			_left -= stride
			if _left <= 0.0:
				_finish()


func _aim_tail() -> void:
	if _trail == null:
		return
	var v := global_position - _last
	_last = global_position
	if v.length() > 0.0001:
		VfxKit.toon_set(_trail, "axis", v.normalized())


func _can_hit(e: Enemy) -> bool:
	return e.targetable(mods.get("air", false), mods.get("ground", true))


func _hit_enemy(e: Enemy) -> void:
	var dmg := damage
	if not e.flying:
		dmg *= mods.get("ground_mult", 1.0)
	if mods.has("burn"):
		e.ignite(mods["burn"], 3.0, mods.get("burn_spreads", false))  # Ember Shot: burn for 3 s
	if mods.get("slow", false):
		e.slow(0.7, 2.0)  # Heavy Bolts Legendary: 30% slower for 2 s
	if _fx_kind == "wind" and game != null and is_inside_tree():
		VfxKit.toon_wind_burst(game.shots_root, e.chest(), 0.045, "slash", 0.25)  # the pierce flash
	e.take_damage(dmg)


func _finish() -> void:
	done = true
	_impact_fx()
	queue_free()


func _impact_fx() -> void:
	if game == null or not is_inside_tree():
		return
	if _fx_kind == "fireball":
		var s := _fx_scale
		VfxKit.toon_burst(game.shots_root, global_position + Vector3(0, 0.03, 0) * s, 0.17 * s, "burst", 0.5)
		var ground := Vector3(global_position.x, game.board.global_position.y, global_position.z)
		VfxKit.toon_burst(game.shots_root, ground, maxf(0.08, splash * 2.2), "ring", 0.5)


static func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	## Distance on the board plane from p to the segment a-b.
	var p2 := Vector2(p.x, p.z)
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var ab := b2 - a2
	var t := 0.0 if ab.length_squared() == 0.0 else clampf((p2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p2.distance_to(a2 + ab * t)
