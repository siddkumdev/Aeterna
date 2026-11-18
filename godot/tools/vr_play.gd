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
var clumsy := false  # firstloop: a first-time player who reads slowly, hesitates and sometimes misses
var rng := RandomNumberGenerator.new()
var mon: Node  # vr_monitor.gd: the timed event log (sounds, messages, text overlaps, things at the face)
var _day_done := -1
var normal := false  # playthrough: a player who knows the game, 1x speed, defends night 1, then lets the village fall


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
	mon = load("res://tools/vr_monitor.gd").new()
	root.add_child(mon)
	mon.setup(g, l, bot, out_dir + "/events.txt")
	rng.seed = 7
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
		"abuse":
			await do_abuse()
		"playthrough":
			normal = true
			bot.aim_error = 0.004
			await do_firstloop()
		"firstloop":
			clumsy = true
			bot.aim_error = 0.012
			await do_firstloop()
		_:
			await do_tutorial()
	var f := FileAccess.open(out_dir + "/vr_play_log.txt", FileAccess.WRITE)
	f.store_string("\n".join(bot.log_lines) + "\nFAILS %d\n" % fails)
	f.close()
	if mon:
		mon.flush()
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
	if clumsy:
		await bot.hold(rng.randf_range(1.0, 2.5))  # takes a moment to notice it
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
		if clumsy:
			await read_pause()
			if rng.randf() < 0.35:
				await fumble()
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
				check(not is_instance_valid(t) or not g.towers.has(t), "pinch-and-hold on a tower sells it")
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
	place_note()
	check(g.is_cutscene() and not g._tray.visible, "during the story the tray is hidden")
	check(await wait_until(func(): return g._cutscene_glass_wait, 90.0), "the story ends waiting for the hourglass")
	await bot.hold(1.0)
	await shot("cutscene_glass")
	var glass: Node3D = g._big_glass
	if not check(glass != null and glass.visible, "a big hourglass is shown"):
		return
	place_note()
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


# ---- a first-time player through the whole first loop (clumsy) -----------------------------------------------------

func read_pause() -> void:
	## Reads the line over the island before doing anything.
	await bot.look(g.board.global_position + Vector3(0, 0.35, 0))
	await bot.hold(rng.randf_range(1.5, 3.5))


func fumble() -> void:
	## A pinch in the air a few cm off: what a newcomer does before they learn where the pinch lands.
	var p: Vector3 = bot.eye_world().lerp(g.board.global_position, 0.35) + Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.05, 0.03), rng.randf_range(-0.05, 0.05))
	bot.note("     (clumsy) pinches the air")
	await bot.reach("right", p)
	await bot.pinch("right", true)
	await bot.hold(0.25)
	await bot.pinch("right", false)
	await bot.hold(rng.randf_range(0.4, 1.0))


func glance() -> void:
	var p: Vector3 = g.board.global_position + Vector3(rng.randf_range(-0.4, 0.4), 0.05, rng.randf_range(-0.4, 0.4))
	await bot.look(p)
	await bot.hold(rng.randf_range(0.5, 1.5))


func do_firstloop() -> void:
	await do_tutorial()
	bot.note("TUTORIAL OVER: phase %d night %d" % [g.phase, g.night])
	var loop0: int = g.loop
	var t0 := Time.get_ticks_msec()
	var last_phase := -1
	var phase_t := 0.0
	while g.loop == loop0:
		if Time.get_ticks_msec() - t0 > 60 * 60 * 1000:
			check(false, "the first loop ends within an hour of play")
			break
		if int(g.phase) != last_phase:
			last_phase = int(g.phase)
			phase_t = Time.get_ticks_msec()
		elif (Time.get_ticks_msec() - phase_t) > 600 * 1000:
			check(false, "phase %d is stuck for 10 minutes" % last_phase)
			break
		if g.is_cutscene():
			await cutscene_turn()
			continue
		match g.phase:
			Game.Phase.NIGHT:
				await night_turn()
			Game.Phase.DAY:
				await day_turn()
			Game.Phase.CARDS:
				await cards_turn()
			_:
				await bot.hold(0.5)
	check(g.loop == loop0 + 1, "the first loop ends and loop 2 begins")
	await bot.hold(3.0)
	await shot("loop2_start")
	await glance()
	await bot.hold(8.0)


func night_turn() -> void:
	if normal and g.night > 0:  # the loss is on purpose: watch the village fall
		var foes: Array = g.enemies.filter(func(e): return is_instance_valid(e))
		if not foes.is_empty():
			await bot.look((foes[rng.randi_range(0, foes.size() - 1)] as Node3D).global_position)
		else:
			await bot.look(g.board.global_position)
		await bot.hold(rng.randf_range(2.0, 3.5))
		return
	var ready: Array = []
	for cd in g._tray.cards:
		if cd.data.get("kind", "") == "spell" and g.spells.is_ready(cd.data.get("id", "")):
			ready.append(cd)
	var live: Array = g.enemies.filter(func(e): return is_instance_valid(e))
	if ready.is_empty() or live.is_empty():
		if not live.is_empty():
			await bot.look((live[rng.randi_range(0, live.size() - 1)] as Node3D).global_position)
		await bot.hold(rng.randf_range(1.0, 2.5))
		return
	var sc: Node3D = ready[rng.randi_range(0, ready.size() - 1)]
	var target: Node3D = live[rng.randi_range(0, live.size() - 1)]
	var id: String = sc.data.get("id", "")
	await bot.look(sc.global_position)
	if clumsy and rng.randf() < 0.2:
		await fumble()
	await bot.reach("right", sc.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.1)
	var held: bool = g._held_spell_cards.size() > 0
	check(held, "night %d: pinching the %s card picks it up" % [g.night + 1, id])
	if not held:
		await bot.pinch("right", false)
		await bot.rest("right")
		return
	var aim: Vector3 = target.global_position + Vector3(rng.randf_range(-0.03, 0.03), 0.05, rng.randf_range(-0.03, 0.03)) if is_instance_valid(target) else g.board.global_position
	if clumsy and rng.randf() < 0.12:
		bot.note("     (clumsy) lets go of the spell half way")
		aim = bot.hand_point("right").lerp(aim, 0.5)
	await bot.look(aim)
	await bot.move_with("right", aim, rng.randf_range(0.6, 1.1))
	await bot.pinch("right", false)
	await bot.hold(0.4)
	bot.note("     cast %s: cooldown %s" % [id, "started" if not g.spells.is_ready(id) else "NOT started (no cast)"])
	await bot.rest("right")
	await bot.hold(rng.randf_range(0.8, 2.0))


func build_one() -> void:
	var cards: Array = g._tray.cards.filter(func(cd): return cd.data.get("kind", "") == "tower")
	if cards.is_empty():
		return
	var cd: Node3D = cards[rng.randi_range(0, cards.size() - 1)]
	var id: String = cd.data.get("id", "")
	var spots: Array[Vector2i] = []
	for x in GameConfig.SIZE - 1:
		for y in GameConfig.SIZE - 1:
			if g.can_build(id, Vector2i(x, y)):
				spots.append(Vector2i(x, y))
	var c := Vector2i(rng.randi_range(2, GameConfig.SIZE - 4), rng.randi_range(2, GameConfig.SIZE - 4))
	if not spots.is_empty() and (not clumsy or rng.randf() > 0.2):
		c = spots[rng.randi_range(0, spots.size() - 1)]
	else:
		bot.note("     (clumsy) drops the card on any spot")
	var n0: int = g.towers.size()
	await bot.look(cd.global_position)
	await bot.reach("right", cd.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.1)
	if not check(g._held_card != null or g.selected != "", "day %d: pinching the %s card picks it up" % [g.night + 1, id]):
		await bot.pinch("right", false)
		await bot.rest("right")
		return
	await bot.look(cell_world(c))
	await bot.move_with("right", cell_world(c), 1.0)
	await bot.pinch("right", false)
	await bot.hold(0.5)
	bot.note("     %s on %s (buildable %s, faith %d): %s" % [id, str(c), str(g.can_build(id, c)) if g.towers.size() == n0 else "-", g.faith, "BUILT" if g.towers.size() > n0 else "not built, msg: " + str(g.last_message).left(80)])
	await bot.rest("right")


func day_turn() -> void:
	if _day_done == g.night:
		if normal:
			await glance()  # 1x: the day runs out by itself while the player looks round
		else:
			await bot.hold(1.0)
		return
	_day_done = g.night
	bot.note("DAY %d: faith %d, towers %d, requests %d" % [g.night + 1, g.faith, g.towers.size(), g.requests.size()])
	await shot("day%d_start" % (g.night + 1))
	await read_pause()
	await glance()
	for r in g.requests.duplicate():
		if is_instance_valid(r) and not r.done and g.phase == Game.Phase.DAY:
			await do_quest(r)
			await bot.rest("right")
	for k in (rng.randi_range(2, 3) if not normal or g.night == 0 else 0):  # playthrough: builds on day 1 only
		if g.phase == Game.Phase.DAY:
			await build_one()
	await shot("day%d_built" % (g.night + 1))
	if g.phase == Game.Phase.DAY and not normal:
		await glance()
		var gp: Vector3 = g._fast_glass.global_position + Vector3(0, 0.03, 0)
		await bot.look(gp)
		await bot.reach("right", gp)
		await bot.pinch("right", true)
		await bot.hold(GameConfig.FAST_HOLD + 0.4)
		await bot.pinch("right", false)
		check(g.day_fast or g.phase == Game.Phase.NIGHT, "day %d: holding the tray hourglass hurries the day" % (g.night + 1))
		await bot.rest("right")


func cards_turn() -> void:
	await bot.hold(0.5)
	if g.is_cutscene() or g.phase != Game.Phase.CARDS:
		return
	await shot("cards_offer")
	await read_pause()
	var cards: Array = g._tray.cards
	if not check(not cards.is_empty(), "the card offer is on the tray"):
		await bot.hold(2.0)
		return
	var cd: Node3D = cards[rng.randi_range(0, cards.size() - 1)]
	await bot.look(cd.global_position)
	await bot.hold(rng.randf_range(1.0, 2.0))
	await bot.reach("right", cd.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.3)
	await bot.pinch("right", false)
	check(g.phase != Game.Phase.CARDS or g.is_cutscene(), "pinching an offered card chooses it")
	await bot.rest("right")


func cutscene_turn() -> void:
	await shot("cutscene_start")
	var told := await wait_until(func(): return g._cutscene_glass_wait or not g.is_cutscene(), 120.0)
	check(told, "the cutscene's story ends and asks for the hourglass")
	if not g._cutscene_glass_wait:
		return
	await bot.hold(rng.randf_range(2.0, 3.5))
	await shot("cutscene_glass")
	var glass: Node3D = g._big_glass
	if not check(glass != null and glass.visible, "a big hourglass is shown"):
		return
	if clumsy and rng.randf() < 0.5:
		bot.note("     (clumsy) pinches beside the hourglass")
		await bot.reach("right", glass.global_position + Vector3(0.14, 0.0, 0.0))
		await bot.pinch("right", true)
		await bot.hold(0.25)
		await bot.pinch("right", false)
		await bot.hold(1.0)
	await bot.reach("right", glass.global_position)
	await bot.pinch("right", true)
	await bot.hold(0.4)
	await bot.pinch("right", false)
	check(not g._cutscene_glass_wait, "pinching the big hourglass turns it")
	await bot.rest("right")
	await wait_until(func(): return not g.is_cutscene(), 8.0)


# ---- abuse: what a first-timer does by accident ---------------------------------------------------------------------

func state(tag: String) -> void:
	## After each abuse case: nothing left held, the tray where the player can reach it.
	var tray_d: float = g._tray.global_position.distance_to(bot.eye_world()) if g._tray else -1.0
	var ok: bool = g._held_card == null and g._held_spell_cards.is_empty() and g._tray_hand == null and (g._tray == null or not g._tray.visible or tray_d < 0.9)
	check(ok, "%s: afterwards nothing is stuck in a hand (held card %s, spells held %d, tray held %s, tray %.2f m from the eye, towers %d)" % [
		tag, str(g._held_card != null), g._held_spell_cards.size(), str(g._tray_hand != null), tray_d, g.towers.size()])
	await shot("abuse_" + tag)


func spam(side: String, points: Array, n: int) -> void:
	for i in n:
		var p: Vector3 = points[i % points.size()]
		await bot.reach(side, p, false, 0.12)
		await bot.pinch(side, true)
		await bot.hold(0.06)
		await bot.pinch(side, false)
		await bot.hold(0.04)


func spell_cards() -> Array:
	return g._tray.cards.filter(func(cd): return cd.data.get("kind", "") == "spell")


func tower_cards() -> Array:
	return g._tray.cards.filter(func(cd): return cd.data.get("kind", "") == "tower")


func do_abuse() -> void:
	await do_tutorial()
	bot.note("ABUSE: tutorial over, phase %d night %d" % [g.phase, g.night])
	# --- night: spam the spell cards, two hands casting at once
	if OS.get_cmdline_user_args().has("dayonly"):
		bot.note("dayonly: night 1 played normally")
		while g.phase == Game.Phase.NIGHT:
			await night_turn()
	elif g.phase == Game.Phase.NIGHT:
		var pts: Array = spell_cards().map(func(cd): return (cd as Node3D).global_position)
		pts.append(g.board.global_position + Vector3(0, 0.05, 0))
		bot.note("A1 spam-pinch 25x over spell cards and the island at night")
		await spam("right", pts, 25)
		await bot.rest("right")
		await bot.hold(1.0)
		await state("night_spam")
		var sc := spell_cards()
		if sc.size() >= 2:
			bot.note("A2 both hands pick a spell and drop them on the island together")
			await bot.reach("left", sc[0].global_position)
			await bot.reach("right", sc[1].global_position)
			await bot.pinch("left", true)
			await bot.pinch("right", true)
			await bot.hold(0.2)
			bot.note("     spells held: %d" % g._held_spell_cards.size())
			var aim: Vector3 = g.board.global_position + Vector3(0, 0.06, 0)
			bot.move_with("left", aim + Vector3(-0.1, 0, 0), 0.8)
			await bot.move_with("right", aim + Vector3(0.1, 0, 0), 0.8)
			await bot.pinch("left", false)
			await bot.pinch("right", false)
			await bot.hold(0.5)
			await bot.rest("left")
			await bot.rest("right")
			await state("two_spells")
		bot.note("A3 a spell picked, then the hand is lost for 2 s")
		sc = spell_cards().filter(func(cd): return g.spells.is_ready(cd.data.get("id", "")))
		if not sc.is_empty():
			await bot.reach("right", sc[0].global_position)
			await bot.pinch("right", true)
			await bot.move_with("right", g.board.global_position + Vector3(0, 0.15, 0), 0.5)
			bot.lost["right"] = true
			await bot.hold(2.0)
			await bot.pinch("right", false)
			bot.lost["right"] = false
			await bot.rest("right")
			await bot.hold(0.6)
			await state("spell_hand_lost")
		while g.phase == Game.Phase.NIGHT:
			await night_turn()  # keep defending so a day comes
	if g.phase == Game.Phase.CARDS:
		bot.note("night 1 was lost: picking a card and turning the glass, the day tests run on loop 2's first day")
		await cards_turn()
		await wait_until(func(): return g.is_cutscene(), 5.0)
		if g.is_cutscene():
			await cutscene_turn()
		await wait_until(func(): return g.phase == Game.Phase.DAY and not g.is_cutscene(), 20.0)
		await bot.hold(4.0)
	if not check(g.phase == Game.Phase.DAY and not g.is_cutscene(), "a day comes, so the day tests can run (phase %d)" % g.phase):
		return
	await bot.hold(2.0)
	# --- day
	var tc := tower_cards()
	bot.note("B1 spam-pinch 30x over tower cards, the hourglass and the island")
	var pts2: Array = tc.map(func(cd): return (cd as Node3D).global_position)
	pts2.append(g._fast_glass.global_position + Vector3(0, 0.03, 0))
	pts2.append(cell_world(Vector2i(10, 10)))
	await spam("right", pts2, 30)
	await bot.rest("right")
	await bot.hold(1.0)
	await state("day_spam")
	tc = tower_cards()
	if not tc.is_empty():
		bot.note("B2 both hands pinch the same tower card, then pull apart and let go over the island")
		var n0: int = g.towers.size()
		await bot.reach("left", tc[0].global_position)
		await bot.reach("right", tc[0].global_position)
		await bot.pinch("left", true)
		await bot.pinch("right", true)
		await bot.hold(0.2)
		bot.move_with("left", cell_world(Vector2i(6, 14)), 0.9)
		await bot.move_with("right", cell_world(Vector2i(16, 14)), 0.9)
		await bot.pinch("left", false)
		await bot.pinch("right", false)
		await bot.hold(0.5)
		bot.note("     towers built: %d" % (g.towers.size() - n0))
		check(g.towers.size() - n0 <= 1, "one card held by two hands builds at most one tower")
		await bot.rest("left")
		await bot.rest("right")
		await state("two_hands_one_card")
	bot.note("B3 left hand carries the tray while the right picks a card off it")
	var h0: Node3D = g._tray.handles[0]
	await bot.reach("left", h0.global_position)
	await bot.pinch("left", true)
	await bot.hold(0.2)
	bot.move_with("left", h0.global_position + Vector3(-0.1, 0.03, 0.02), 1.5)
	tc = tower_cards()
	if not tc.is_empty():
		await bot.reach_node("right", tc[0])
		await bot.pinch("right", true)
		await bot.move_with("right", cell_world(Vector2i(12, 8)), 0.8)
		await bot.pinch("right", false)
	await bot.pinch("left", false)
	await bot.hold(0.5)
	await bot.rest("left")
	await bot.rest("right")
	await state("tray_and_card")
	bot.note("B4 a tower card picked, then the hand is lost for 2 s, comes back open")
	tc = tower_cards()
	if not tc.is_empty():
		await bot.reach("right", tc[0].global_position)
		await bot.pinch("right", true)
		await bot.move_with("right", cell_world(Vector2i(12, 12)) + Vector3(0, 0.1, 0), 0.6)
		bot.lost["right"] = true
		await bot.hold(2.0)
		await bot.pinch("right", false)
		bot.lost["right"] = false
		await bot.rest("right")
		await bot.hold(0.6)
		await state("card_hand_lost")
	bot.note("B5 the tray carried, then the hand is lost for 2 s")
	h0 = g._tray.handles[0]
	await bot.reach("left", h0.global_position)
	await bot.pinch("left", true)
	await bot.move_with("left", h0.global_position + Vector3(0.12, 0.05, -0.05), 0.6)
	bot.lost["left"] = true
	await bot.hold(2.0)
	await bot.pinch("left", false)
	bot.lost["left"] = false
	await bot.rest("left")
	await bot.hold(0.6)
	await state("tray_hand_lost")
	bot.note("B6 palm up for the ledger while the other hand holds a card")
	tc = tower_cards()
	if not tc.is_empty():
		await bot.reach("right", tc[0].global_position)
		await bot.pinch("right", true)
		await bot.palm_up("left", true)
		await bot.hold(1.5)
		bot.note("     ledger open: %s" % str(g.ledger != null and g.ledger.open))
		await shot("abuse_ledger_with_card")
		await bot.palm_up("left", false)
		await bot.rest("left")
		await bot.move_with("right", cell_world(Vector2i(14, 6)), 0.8)
		await bot.pinch("right", false)
		await bot.rest("right")
		await state("ledger_with_card")
	for lean in [["lean left", Vector3(-0.35, 0, 0)], ["stand up", Vector3(0, 0.45, 0)], ["lean into the island", Vector3(0, -0.2, -0.45)], ["turn away (look behind)", Vector3.ZERO]]:
		bot.note("C lean: " + lean[0])
		bot.head_offset = lean[1]
		if lean[0].begins_with("turn"):
			await bot.look(bot.eye_world() + Vector3(0, 0, 1.0))
		else:
			await bot.look(g.board.global_position)
		await bot.hold(3.0)
		await shot("abuse_" + lean[0].replace(" ", "_"))
		var tray_d: float = g._tray.global_position.distance_to(bot.eye_world())
		bot.note("     tray %.2f m from the eye, ledger open %s" % [tray_d, str(g.ledger != null and g.ledger.open)])
	bot.head_offset = Vector3.ZERO
	await bot.look(g.board.global_position)
	await bot.hold(2.0)
	await state("after_leaning")
	# --- the cutscene, spammed
	bot.note("D cutscene: pinches everywhere during the story, then both hands on the hourglass")
	if g.is_cutscene() or g.phase != Game.Phase.DAY:
		check(false, "the cutscene test starts from a day (phase %d)" % g.phase)
		return
	g.loop = 0
	var loop0: int = g.loop
	g._begin_rewind()
	await bot.hold(2.0)
	var pts3: Array = [g.board.global_position + Vector3(0, 0.05, 0), bot.eye_world() + Vector3(0, -0.25, -0.3), g._tray.global_position]
	await spam("right", pts3, 20)
	await bot.rest("right")
	check(g.is_cutscene() and not g._cutscene_glass_wait, "pinching during the story does not skip or break it")
	await wait_until(func(): return g._cutscene_glass_wait, 120.0)
	await bot.hold(1.0)
	var glass: Node3D = g._big_glass
	if glass:
		bot.reach("left", glass.global_position + Vector3(-0.02, 0, 0))
		await bot.reach("right", glass.global_position + Vector3(0.02, 0, 0))
		bot.pinch("left", true)
		await bot.pinch("right", true)
		await bot.hold(0.3)
		await spam("right", [glass.global_position], 6)
		await bot.pinch("left", false)
		await bot.rest("left")
		await bot.rest("right")
	await wait_until(func(): return not g.is_cutscene(), 10.0)
	await bot.hold(2.0)
	check(g.loop == loop0 + 1, "two hands and spam on the hourglass rewind exactly once (loop %d -> %d)" % [loop0, g.loop])
	await state("after_cutscene")


func place_note() -> void:
	## Where the cutscene's caption and hourglass sit for the player's eye (distance, and angle below straight ahead).
	var e: Vector3 = bot.eye_world()
	for n in [g.board.get_node_or_null("FallCaption"), g._big_glass]:
		if n and is_instance_valid(n) and (n as Node3D).visible:
			var v: Vector3 = (n as Node3D).global_position - e
			bot.note("     PLACE %s: %.2f m from the eye, %.0f deg below level, scale %.2f, eye board-local %s" % [n.name, v.length(), rad_to_deg(-atan2(v.y, Vector2(v.x, v.z).length())), (n as Node3D).scale.x, str(g.board.to_local(e))])


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
