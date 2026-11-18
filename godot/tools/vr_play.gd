extends SceneTree
## Plays Aeterna in VR mode like a seated human, with no headset (2026-11-18, Siddharth). The hands and head are the
## scripted player in vr_human.gd, fed through the real XR trackers (GameConfig.FORCE_XR), so every grab, pinch and
## tap goes through the same code as on the Quest. Each action is logged with whether the game reacted, and the head
## camera (Quest 3-like field of view) is saved before and after it.
##   <godot console> --xr-mode off --resolution 1300x1400 --path godot -s res://tools/vr_play.gd -- REC.bin.gz OUT_DIR [tutorial|tray|cutscene] [nojoints]
## REC gives the real seated head (and its sway). The log goes to OUT_DIR/vr_play_log.txt; FAIL lines are actions a
## player did correctly that the game did not take.

const VrHuman := preload("res://tools/vr_human.gd")

var out_dir := ""
var bot
var g: Game
var l: Launcher
var fails := 0
var shot_n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rec: String = args[0] if args.size() > 0 else "res://../quest_data/recordings/2026-11-18_17-48-09.bin.gz"
	out_dir = args[1] if args.size() > 1 else "res://../_work/vr_play"
	var mode: String = args[2] if args.size() > 2 else "tutorial"
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameConfig.FORCE_XR = true
	bot = VrHuman.new()
	if not bot.load_file(rec):
		print("vr_play: cannot load ", rec)
		quit(1)
		return
	bot.joints = not args.has("nojoints")
	_run(mode)


func _run(mode: String) -> void:
	l = load("res://scripts/ui/launcher.gd").new()
	root.add_child(l)
	root.add_child(bot)
	bot.install(null)
	bot.apply(bot.head_rec_t)
	for i in 40:
		await process_frame
	l._press_plaque("skip")
	l._skip = true
	for i in 30:
		await process_frame
	g = l.game
	g._xr_cam.fov = 96.0  # Quest 3, vertical, per eye (about)
	g._xr_cam.current = true
	bot.attach(g)
	for i in 10:
		await process_frame
	g._board_placed = false
	g._tray_placed = false
	g.place_seated_board()
	for i in 40:
		await process_frame
	await shot("start")
	match mode:
		"tray":
			await do_tray()
		"cutscene":
			await do_cutscene()
		_:
			await do_tutorial()
	var f := FileAccess.open(out_dir + "/vr_play_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(bot.log_lines) + "\nFAILS %d\n" % fails)
	f.close()
	print("VRH DONE fails=", fails)
	quit()


func shot(tag: String) -> void:
	await process_frame
	await process_frame
	shot_n += 1
	root.get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, shot_n, tag])


func check(ok: bool, what: String) -> bool:
	bot.note(("ok   " if ok else "FAIL ") + what)
	if not ok:
		fails += 1
	return ok


func wait_until(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await process_frame
		t += bot.get_process_delta_time()
	return cond.call()


# ---- places a player looks at -------------------------------------------------------------------------------------

func cell_world(c: Vector2i, up := 0.04) -> Vector3:
	return g.board.to_global(NavGrid.footprint_centre(c, Vector2i(2, 2)) + Vector3(0, up, 0))


func near_rim_point() -> Array:
	## The rim point nearest the player and the sideways direction along that edge (world).
	var e: Vector3 = g.board.to_local(bot.eye_world())
	var half: float = Game.HALF + 0.03
	var p: Vector3
	var along: Vector3
	if absf(e.x) > absf(e.z):
		p = Vector3(signf(e.x) * half, 0.0, 0.0)
		along = Vector3(0, 0, 1)
	else:
		p = Vector3(0.0, 0.0, signf(e.z) * half)
		along = Vector3(1, 0, 0)
	return [g.board.to_global(p), (g.board.global_transform.basis * along).normalized()]


# ---- the tutorial, as a player does it ---------------------------------------------------------------------------

func press_continue() -> void:
	var seen := await wait_until(func(): return l._cont != null and is_instance_valid(l._cont) and l._cont.visible, Launcher.MIN_STEP_S + 3.0)
	if not check(seen, "step %d: the Continue plaque appears" % l._step):
		return
	var before: int = l._step
	await bot.look(l._cont.global_position)
	await shot("s%02d_continue" % before)
	await bot.tap("right", l._cont.global_position)
	var moved := await wait_until(func(): return l._step != before, 1.0)
	check(moved, "step %d: tapping Continue moves on (now %d)" % [before, l._step])
	await bot.rest("right")


func step_done() -> bool:
	return l._step_done


func do_tutorial() -> void:
	var guard := 0
	while l._step < Launcher.HINTS.size() and guard < 40:
		guard += 1
		var s: int = l._step
		bot.note("STEP %d: %s" % [s, str(Launcher.HINTS[s]).left(90)])
		await shot("s%02d_hint" % s)
		if not l._step_done:
			for attempt in 3:
				await act(s)
				if await wait_until(step_done, 1.5) or l._step != s:
					break
				bot.note("     attempt %d did not finish step %d" % [attempt + 1, s])
			check(l._step_done or l._step != s, "step %d: the player's action is taken" % s)
			await shot("s%02d_after" % s)
		if l._step == s and s < Launcher.HOURGLASS_STEP:
			await press_continue()
		elif l._step == s:
			await wait_until(func(): return l._step != s, 60.0)
		if l._step == s:
			bot.note("stuck at step %d" % s)
			break


func act(s: int) -> void:
	match s:
		0, 1, Launcher.REBUILD_STEP:
			await place_card(0 if s != Launcher.REBUILD_STEP else 1)
		2:
			var r := near_rim_point()
			await bot.drag("right", r[0], r[0] + r[1] * 0.12, 0.9)
			check(true, "turned the rim by %.1f deg" % rad_to_deg(angle_difference(g.board.rotation.y, l._start_board_yaw)))
		3, 4:
			var v: Node3D = null
			if s == 3 and is_instance_valid(l._step3_quest):
				v = l._step3_quest.asker()
			elif g.life and not g.life.villagers.is_empty():
				v = g.life.villagers[0]
			if check(v != null, "step %d: a villager to tap" % s):
				var taps0: int = l._total_villager_taps()
				await bot.tap_node("right", v, Vector3(0, 0.035, 0))
				check(l._total_villager_taps() > taps0 or s == 3, "step %d: tapping the villager registers" % s)
		5:
			var lp: Vector3 = g.lens_grip_position()
			await bot.reach("right", lp)
			await bot.pinch("right", true)
			await bot.move_with("right", bot.eye_world().lerp(g.board.global_position, 0.45), 0.8)
			var shown := await wait_until(func(): return g.foresight.showing, 2.0)
			await shot("s05_lens_up")
			check(shown, "lens held up shows foresight")
			await bot.pinch("right", false)
		6:
			await grab_tray_handle()
		7:
			await bot.palm_up("left", true)
			var pp: Array = g.palm_pose()
			bot.note("     dbg palm: found=%s up=%.2f dist=%.2f below_eye=%.2f" % [pp[0], (pp[2] as Vector3).dot(Vector3.UP), (pp[1] as Vector3).distance_to(bot.eye_world()), bot.eye_world().y - (pp[1] as Vector3).y])
			var open := await wait_until(func(): return g.ledger != null and g.ledger.open, 2.0)
			await shot("s07_ledger")
			check(open, "palm up opens the ledger")
			await bot.palm_up("left", false)
			await bot.rest("left")
		Launcher.QUEST_STEP:
			await do_quest(l._quest_req)
		Launcher.SELL_STEP:
			if check(not g.towers.is_empty(), "a tower to sell"):
				var t: Node3D = g.towers[0]
				await bot.reach("right", t.global_position + Vector3(0, 0.05, 0))
				await bot.pinch("right", true)
				await bot.hold(GameConfig.CRUSH_HOLD + 0.5)
				await bot.pinch("right", false)
				check(not g.towers.has(t), "pinch-and-hold on a tower sells it")
		Launcher.HOURGLASS_STEP:
			var gp: Vector3 = g._fast_glass.global_position + Vector3(0, 0.03, 0)
			await bot.reach("right", gp)
			await bot.pinch("right", true)
			await bot.hold(GameConfig.FAST_HOLD + 0.4)
			await bot.pinch("right", false)
			check(g.day_fast or g.phase == Game.Phase.NIGHT, "holding the tray hourglass hurries the day")
			await bot.rest("right")
			await wait_until(func(): return g.phase == Game.Phase.NIGHT, 120.0)
		Launcher.NIGHT_STEP:
			var sc: Node3D = null
			for cd in g._tray.cards:
				if cd.data.get("kind", "") == "spell" and g.spells.is_ready(cd.data.get("id", "")):
					sc = cd
					break
			if check(sc != null, "a ready spell card on the tray"):
				var aim: Vector3 = g.board.global_position + Vector3(0, 0.06, 0)
				if not g.enemies.is_empty():
					aim = (g.enemies[0] as Node3D).global_position + Vector3(0, 0.06, 0)
				await bot.reach("right", sc.global_position)
				await bot.pinch("right", true)
				check(g._held_spell_cards.size() > 0, "pinching a spell card picks it up")
				await bot.move_with("right", aim, 0.7)
				await shot("spell_aim")
				await bot.pinch("right", false)
				await bot.hold(0.4)
				check(g.spells.cooldown.values().any(func(cd): return cd > 0.0), "letting go over the island casts the spell")
	await bot.rest("right")


func place_card(i: int) -> void:
	if g._tray.cards.is_empty():
		check(false, "the tray has cards")
		return
	var cd: Node3D = g._tray.cards[mini(i, g._tray.cards.size() - 1)]
	var n0 := g.towers.size()
	await bot.reach("right", cd.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.1)
	var held := g._held_card != null
	var rh: GameHand = g._hands[1]
	check(held, "pinching a card picks it up")
	var cell: Vector2i = Launcher.TUTORIAL_BUILD_CELL if i == 0 else Launcher.TUTORIAL_BUILD_CELL + Vector2i(-4, 2)
	await bot.move_with("right", cell_world(cell), 0.9)
	await shot("card_over_board")
	await bot.pinch("right", false)
	await bot.hold(0.3)
	if held:
		check(g.towers.size() > n0, "letting go over the grass builds the tower")


func grab_tray_handle() -> void:
	var hs: Array = g._tray.handles
	if not check(not hs.is_empty(), "the tray has handles"):
		return
	var e: Vector3 = bot.eye_world()
	var hnd: Node3D = hs[0]
	for h in hs:
		if is_instance_valid(h) and (h as Node3D).global_position.distance_to(e) < hnd.global_position.distance_to(e):
			hnd = h
	var yaw0: float = g._tray.global_rotation.y
	var p0: Vector3 = g._tray.global_position
	await bot.reach("right", hnd.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.15)
	check(g._tray_hand != null, "pinching the tray's handle grabs the tray")
	var side: Vector3 = (hnd.global_position - e).cross(Vector3.UP).normalized()
	await bot.move_with("right", hnd.global_position + side * 0.12 + Vector3(0, 0.03, 0), 0.8)
	await shot("tray_moved")
	bot.note("     tray moved %.3f m, turned %.1f deg while carried" % [g._tray.global_position.distance_to(p0), rad_to_deg(angle_difference(g._tray.global_rotation.y, yaw0))])
	await bot.pinch("right", false)


func do_tray() -> void:
	for k in 3:
		await grab_tray_handle()
		await bot.rest("right")
	await place_card(0)


func do_cutscene() -> void:
	## The first-rewind cutscene: only the story while it plays (no tray), then a big hourglass to grab.
	g.loop = 0
	g.night = 1  # as after a real fall: the tutorial has ended by then
	g._begin_rewind()
	await bot.hold(3.0)
	await shot("cutscene_story")
	check(g.is_cutscene() and not g._tray.visible, "during the story the tray is hidden")
	check(await wait_until(func(): return g._cutscene_glass_wait, 90.0), "the story ends waiting for the hourglass")
	await bot.hold(1.0)
	await shot("cutscene_glass")
	var glass: Node3D = g._big_glass
	if not check(glass != null and glass.visible, "a big hourglass is shown"):
		return
	bot.note("     glass %.2f m from the eye, %.2f m below it" % [glass.global_position.distance_to(bot.eye_world()), bot.eye_world().y - glass.global_position.y])
	await bot.reach("right", glass.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.3)
	check(not g._cutscene_glass_wait, "pinching the big hourglass turns it")
	await bot.hold(0.6)
	await shot("cutscene_turning")
	await bot.pinch("right", false)
	await bot.rest("right")
	check(await wait_until(func(): return not g.is_cutscene(), 6.0), "the cutscene ends after the turn")
	check(g._tray.visible and not glass.visible and g.loop == 1, "the tray is back, the glass gone, loop 2 begins")
	await bot.hold(1.5)
	await shot("cutscene_after")


func do_quest(r) -> void:
	if not check(r != null and is_instance_valid(r), "a tutorial quest exists"):
		return
	if not r.accepted:
		var a: Node3D = r.asker()
		await bot.look(a.global_position)
		await shot("quest_asker")
		var a0 := a.global_position
		await bot.tap_node("right", a, Vector3(0, 0.035, 0))
		bot.note("     the asker moved %.3f m during the reach" % a.global_position.distance_to(a0))
		check(r.accepted, "tapping the waving villager accepts the quest")
	await bot.hold(0.5)
	if r.done:
		return
	var ends: PackedVector3Array = r.trail_ends()
	var gp: Vector3 = r.grab_point()
	await bot.reach("right", gp)
	await bot.pinch("right", true)
	await bot.hold(0.1)
	check(r.held if "held" in r else true, "pinching the quest item picks it up")
	var goal: Vector3 = r.to_global(ends[1]) if ends.size() > 1 else gp
	await bot.move_with("right", goal + Vector3(0, 0.02, 0), 1.0)
	await shot("quest_carry")
	await bot.hold(0.3)
	await bot.pinch("right", false)
	await bot.hold(0.6)
	check(r.done, "carrying the item to its goal finishes the quest")
