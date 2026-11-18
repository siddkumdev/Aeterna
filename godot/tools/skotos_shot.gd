extends SceneTree
## Skotos in the game, per phase (desktop window):
##   <godot console> --xr-mode off --path godot -s res://tools/skotos_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_p1_seat / p1_close / p1_face / p1_summon / p2_seat / p2_close / p2_top / p3_seat / p3_close / p3_face (night mood, seated board view and close-ups).
## and OUT_PREFIX_cutscene_*.png (the first-rewind cutscene display Skotos).

func _shoot(cam: Camera3D, g: Game, from: Vector3, at: Vector3, path: String, frames := 4) -> void:
	for b in get_nodes_in_group(Bubble.ACTIVE_GROUP):
		b.queue_free()  # no speech bubble over the boss
	g.lighting.set_mood("night", 0.0)  # review shots are in the real night mood
	cam.global_position = g.board.to_global(from)
	cam.look_at(g.board.to_global(at), Vector3.UP)
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix: String = args[0] if args.size() > 0 else "skotos_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 40:
		await process_frame
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	g.start_night()
	g.asleep = false
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 4), "boss")
	boss.slow(0.0001, 100000.0)
	g.warden = Warden.new(g, boss)
	for i in 60:
		await process_frame
	var bp := boss.position
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(bp.x, 0.1, bp.z), prefix + "_p1_seat.png")
	await _shoot(cam, g, bp + Vector3(0.0, 0.15, 0.5), bp + Vector3(0, 0.12, 0), prefix + "_p1_close.png")
	await _shoot(cam, g, bp + Vector3(0.0, 0.25, 0.22), bp + Vector3(0, 0.235, 0), prefix + "_p1_face.png")
	g.warden._timer = GameConfig.WARDEN_SUMMON_EVERY - 0.5  # the summon rings, then the Grunts out of root mounds
	for i in 40:
		await process_frame
	await _shoot(cam, g, bp + Vector3(0.0, 0.35, 0.55), bp + Vector3(0, 0.02, 0.0), prefix + "_p1_summon.png")
	for i in 50:
		await process_frame
	boss.take_damage(boss.hp + 1.0)  # phase 2
	for i in 60:
		await process_frame
	for c in g.warden.crystals:
		print("knot at ", c.position, " boss ", boss.position, " holder y ", c._knot_holder.position.y if c._knot_holder else "none", " visible ", c.visible, " cell ", c.cell)
	var vv: BossVeins = g.warden.veins
	print("vein mesh aabb ", vv._mesh.get_aabb(), " surfaces ", vv._mesh.get_surface_count(), " visible ", vv._mi.is_visible_in_tree(), " pos ", vv.global_position)
	print("veins ", g.warden.veins, " ", g.warden.veins.vein_count() if is_instance_valid(g.warden.veins) else -1)
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(bp.x, 0.1, bp.z), prefix + "_p2_seat.png")
	var kn: Enemy = g.warden.crystals[0]
	kn.take_damage(2.0)  # a hit: the knot flashes
	await _shoot(cam, g, kn.position + Vector3(0.0, 0.2, 0.3), kn.position + Vector3(0, 0.06, 0), prefix + "_p2_flash.png", 1)
	await _shoot(cam, g, bp + Vector3(0.0, 0.15, 0.5), bp + Vector3(0, 0.1, 0), prefix + "_p2_close.png")
	await _shoot(cam, g, bp + Vector3(0.0, 1.0, 0.25), bp + Vector3(0, 0.0, 0.03), prefix + "_p2_top.png")
	for c in g.warden.crystals.duplicate():
		if is_instance_valid(c):
			c.take_damage(99999.0)
	for i in 90:
		await process_frame
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(bp.x, 0.1, bp.z), prefix + "_p3_seat.png")
	await _shoot(cam, g, bp + Vector3(0.0, 0.15, 0.5), bp + Vector3(0, 0.12, 0), prefix + "_p3_close.png")
	await _shoot(cam, g, bp + Vector3(0.0, 0.25, 0.22), bp + Vector3(0, 0.235, 0), prefix + "_p3_face.png")
	print("phase %d form key %s" % [g.warden.phase if g.warden else -1, boss._rig.key])
	g.queue_free()
	await process_frame
	await _grove_shots(prefix)
	quit()


func _grove_shots(prefix: String) -> void:
	## Phase 4 "The Grove Awakens" on loop 2: seeds with their purple rings, a stranglered tower, the lash warning and a stunned tower.
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 40:
		await process_frame
	g._camera = null
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 48
	g.loop = 1
	g.loop_nights = 5
	g.night = 1
	g.faith = 5000
	g.try_build("fire", Vector2i(16, 11))
	g.try_build("crossbow", Vector2i(6, 11))
	g.try_build("fire", Vector2i(11, 16))
	g.start_night()
	g.asleep = false
	g._spawn_queue.clear()
	var boss: Enemy = g._spawn(Vector2i(12, 4), "boss")
	boss.slow(0.0001, 100000.0)
	g.warden = Warden.new(g, boss)
	g.warden._final_stand()
	g.warden.grove._seed_t = -100000.0
	g.warden.grove._lash_t = -100000.0
	for t in g.towers:
		t.cooldown = 100000.0  # the towers must not shoot the saplings dead before the camera sees them
	for i in 30:
		await process_frame
	var gr: Grove = g.warden.grove
	gr.plant_seeds()
	for d in gr.saplings:
		d["age"] = 3.0
	for i in 30:
		await process_frame
	var bp := boss.position
	var t0: Tower = g.towers[0]
	var tp := t0.position
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(0.0, 0.05, 0.1), prefix + "_p4_grove_seat.png")
	var s0: Enemy = gr.saplings[0]["e"]
	await _shoot(cam, g, s0.position + Vector3(0.0, 0.12, 0.2), s0.position + Vector3(0, 0.04, 0), prefix + "_p4_sapling_close.png")
	for d in gr.saplings:
		d["age"] = GameConfig.GROVE_SAPLING_GROW - 0.05
	for i in 40:
		await process_frame
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(0.0, 0.05, 0.1), prefix + "_p4_strangler_seat.png")
	await _shoot(cam, g, tp + Vector3(0.0, 0.18, 0.28), tp + Vector3(0, 0.05, 0), prefix + "_p4_strangler_close.png")
	gr._lash_line = {}
	gr._lash_t = GameConfig.GROVE_LASH_EVERY - GameConfig.GROVE_LASH_WARN
	for i in 20:
		await process_frame
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(0.0, 0.05, 0.1), prefix + "_p4_lash_warning.png", 2)
	await _shoot(cam, g, Vector3(0.0, 1.1, 0.35), Vector3(0.0, 0.0, 0.0), prefix + "_p4_lash_top.png", 1)
	gr._lash_line["t"] = GameConfig.GROVE_LASH_WARN - 0.001
	for i in 8:
		await process_frame
	await _shoot(cam, g, Vector3(0.0, 0.8, 1.25), Vector3(0.0, 0.05, 0.1), prefix + "_p4_lash_stun.png", 1)
	for t in g.towers:
		if t.stun_left > 0.0:
			await _shoot(cam, g, t.position + Vector3(0.0, 0.16, 0.26), t.position + Vector3(0, 0.05, 0), prefix + "_p4_stun_close.png", 1)
			break
	print("grove: saplings ", gr.saplings.size(), " strangled towers ", g.towers.filter(func(t): return t.strangled).size(), " stunned ", g.towers.filter(func(t): return t.stun_left > 0.0).size())
