class_name Launcher
extends Node
## The start of the game (docs/STORY.md, scene by scene). The real island floats asleep under fireflies with the
## title above it and two wooden plaques: Wake and Skip story. Wake plays the
## immersive opening (scripts/ui/opening_stage.gd), then wakes the game and walks the player through the first day with small hints
## (pick up a card, set it on the grass, help someone, tap a villager, start the night).
## It owns no game rules: it only drives Game's public state (asleep, press_override) and reads it.

const AUTO_START := 6.0  # s of title before the story begins on its own
const GOLD := Color("F2B630")  # rarity_gold
const GLOW := Color("FFD45A")  # fire_yellow
const OUTLINE := Color("5B2920")  # wood_dark
const TUTORIAL_HINT_POS := Vector3(0, 0.20, 0)  # local to Game.hud_root: behind the table, follows its position but not its turn
const TUTORIAL_BUILD_CELL := Vector2i(17, 11)
const HINTS := [
	"Pinch a glowing tower card on your tray.",
	"Drop the card on the golden ring by the road.",
	"Grab a brass handle on the board rim and spin the island.",
	"Someone is praying! Tap the villager under the golden mote.",
	"Tap a villager walking the path to hear their thoughts.",
	"Lift the mirror on your tray and look at the dark trees.",
	"Grab a brass handle at either end of your card tray to move and turn it.",
	"Zoom: pinch both hands in the air beside the island, then spread them apart. Close them to push it away.",
	"Turn your left palm up to open your ledger: quests, cards and how to play.",
	"Changed your mind? Pinch a tower on the board and HOLD it until it crumbles: you get its faith back.",
	"Now build a tower again: pinch a glowing card and drop it on the golden ring.",
	"Hold the hourglass to call Night 1. At night, tap it again for 2x speed.",
	"Night 1! Pinch Fire Orb or Boulder and drop it on the shades!",
]

static var prefer_controllers := false  # placeholder for the Hands / Controllers plaque

var game: Game
var _title: Node3D
var _plaques := {}  # id -> Plaque
var _state := "title"  # title / narrating / playing
var _skip := false
var _step := 0
var _step_time := 0.0
var _card: TitleCard
var _t := 0.0
var _hint_root: Node3D
var _helped_at_step := 0
var _step3_quest: HelpRequest
var _hint_card: TitleCard
var _cue_root: Node3D
var _target_ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_scale := 1.0
var _ghost_timer := 0.0
var _active_ghost: GhostHand
var _extra_ghosts: Array[GhostHand] = []  # the zoom step's second hand
var _start_board_yaw := 0.0
var _start_board_pos := Vector3.ZERO
var _taps_at_step := 0
var _step_entered := -1
var _step_done := false  # this step's action is done; the next one starts when the player taps Continue (the user, 2026-11-18: do not rush)
var _towers_at_step := 0
var _cont: Plaque
const MIN_STEP_S := 4.0  # a step can be completed (Continue shows) no sooner than this
const SELL_STEP := 9
const REBUILD_STEP := 10
const HOURGLASS_STEP := 11
const NIGHT_STEP := 12
var _last_run_serial := -1
var _auto_at := -1.0  # when the story starts by itself (the title shows a few seconds first)
var _xr_rig: Node3D  # headset: the plaques float in front of you (placed once), not on the island's front edge


func _ready() -> void:
	UiFonts.install()
	game = Game.new()
	game.name = "Game"
	add_child(game)
	for i in 4:
		await get_tree().process_frame
	game.asleep = true
	var stale := game.board.get_node_or_null("Bubble")  # the first prayer was spoken before the title came up
	if stale:
		stale.queue_free()
	game.press_override = _on_press
	if game.lighting:
		game.lighting.set_mood("night", 0.05)  # the island sleeps under the Veil until you wake it
	if game.life:
		game.life._nightfall()  # everyone is indoors
	_build_title()
	_auto_at = AUTO_START


func _build_title() -> void:
	## 2026-11-11 (the user: "starting it up is boring"): night over the sleeping island, the Veil glowing, fireflies,
	## the gilded name, and one large Wake plaque that breathes. The Tale sits small beside it.
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	_title = Node3D.new()
	_title.name = "Title"
	game.board.add_child(_title)
	_card = TitleCard.show_over(_title, Vector3(0, 0.34, -0.1), "AETERNA", "a tiny god, a tiny land", -1.0, 132)
	var wake := Plaque.make("Wake")
	wake.position = Vector3(0, 0.06, half + 0.1)
	wake.rotation_degrees.x = -50
	wake.scale = Vector3.ONE * 1.7
	_title.add_child(wake)
	_plaques["wake"] = wake
	# The Tale parchment is gone (sykeriin 2026-11-14): Wake plays the story; this one goes straight to the game.
	var skip := Plaque.make("Skip story")
	skip.position = Vector3(0.32, 0.03, half + 0.1)
	skip.rotation_degrees.x = -50
	skip.scale = Vector3.ONE * 0.8
	_title.add_child(skip)
	_plaques["skip"] = skip
	if game._xr:
		_xr_rig = Node3D.new()
		_xr_rig.name = "TitleRig"
		_xr_rig.visible = false  # shown when the headset's pose is known (_place_xr_rig)
		game.add_child(_xr_rig)
		for id in ["wake", "skip"]:
			var pl: Node3D = _plaques[id]
			pl.get_parent().remove_child(pl)
			_xr_rig.add_child(pl)
			pl.rotation_degrees = Vector3(-30, 0, 0)
		(_plaques["wake"] as Node3D).position = Vector3(-0.11, 0, 0)
		(_plaques["wake"] as Node3D).scale = Vector3.ONE * 1.5
		(_plaques["skip"] as Node3D).position = Vector3(0.26, -0.03, 0.02)
		(_plaques["skip"] as Node3D).scale = Vector3.ONE * 0.85
	_title.add_child(_fireflies())
	if game.veil:
		game.veil.snap(1.0, 0.0)


func _fireflies() -> CPUParticles3D:
	var f := CPUParticles3D.new()
	f.amount = 28
	f.lifetime = 7.0
	f.preprocess = 7.0
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(0.55, 0.05, 0.55)
	f.position = Vector3(0, 0.12, 0)
	f.direction = Vector3.UP
	f.spread = 180.0
	f.initial_velocity_min = 0.004
	f.initial_velocity_max = 0.012
	f.gravity = Vector3.ZERO
	var m := SphereMesh.new()
	m.radius = 0.0022
	m.height = 0.0044
	m.material = ModelUtil.flat_material(GLOW, true)
	f.mesh = m
	return f


func _place_xr_rig() -> void:
	## Once, when the headset pose exists: half a metre ahead, a little below the eyes, turned to face you.
	var cam: Camera3D = game._xr_cam
	if _xr_rig == null or cam == null or _xr_rig.visible:
		return
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.1:
		return
	f = f.normalized()
	_xr_rig.global_position = cam.global_position + f * 0.5 + Vector3(0, -0.2, 0)
	_xr_rig.rotation.y = atan2(-f.x, -f.z)
	_xr_rig.visible = true
	game.place_seated_board()


func _process(delta: float) -> void:
	_t += delta
	if _auto_at >= 0.0 and _state == "title":  # the whole story starts by itself; hovering Skip story pauses it
		var skip_hot := _plaques.has("skip") and (_plaques["skip"] as Plaque).hot
		if not skip_hot:
			_auto_at -= delta
			if _auto_at < 0.0:
				_press_plaque("wake")
	elif _state != "title":
		_auto_at = -1.0
	if _state != "playing":
		_place_xr_rig()
	if _state != "playing":
		for id in _plaques.keys():
			if not is_instance_valid(_plaques[id]):  # check before the typed assign: a freed plaque errored every frame on the Quest
				_plaques.erase(id)
				continue
			var p: Plaque = _plaques[id]
			var hot := false
			for h in game._hands:
				hot = hot or p.hit_point(h.touch_point(), maxf(0.02, _touch_pad())) or p.hit_ray(h.ray_origin(), h.ray_dir())
			if game._mouse_hand:
				hot = hot or p.hit_point(game._mouse_hand.global_position)
			if game._camera:
				var m := get_viewport().get_mouse_position()
				hot = hot or p.hit_ray(game._camera.project_ray_origin(m), game._camera.project_ray_normal(m))
			p.hot = hot
			if id == "wake":
				p.scale = Vector3.ONE * (1.7 + 0.08 * sin(_t * 2.2))  # it breathes: press me
	elif game != null and is_instance_valid(game) and (_last_run_serial != game.run_serial or (game.loop == 0 and _step < HINTS.size())):
		_tutorial(delta)


func _on_press(world: Vector3, origin: Vector3, dir: Vector3) -> bool:
	## Game asks us first. true = we used the press.
	if _state == "playing":
		if _cont != null and is_instance_valid(_cont) and _cont.visible and (_cont.hit_point(world, _touch_pad()) or _cont.hit_ray(origin, dir)):
			game.snd("menu_open")
			_advance()
			return true
		return false
	if _state == "narrating":
		_skip = true
		return true
	var touched := ""  # a fingertip on a plaque beats the ray; the nearest plaque wins when the pads overlap
	var best := INF
	for id in _plaques:
		if not is_instance_valid(_plaques[id]):
			continue
		var p: Plaque = _plaques[id]
		if p.hit_point(world, _touch_pad()) and p.global_position.distance_to(world) < best:
			best = p.global_position.distance_to(world)
			touched = id
	if touched == "":
		for id in _plaques:
			if is_instance_valid(_plaques[id]) and (_plaques[id] as Plaque).hit_ray(origin, dir):
				touched = id
				break
	if touched != "":
		_press_plaque(touched)
		return true
	return true  # nothing else can be pressed while the title is up


func _touch_pad() -> float:
	## How far outside a plaque a press still counts: wider in the real headset (GameConfig.XR_PLAQUE_PAD).
	return GameConfig.XR_PLAQUE_PAD if game._xr and not game.easy_reach else 0.012


func _press_plaque(id: String) -> void:
	if _state != "title":  # one press only: a press registered twice must not start the story twice
		return
	game.snd("menu_open")
	match id:
		"wake":
			_wake(true)
		"skip":
			_wake(false)




func _wake(story := true) -> void:
	## story = true: the immersive opening (scripts/ui/opening_stage.gd), then the first dawn. false (Skip story): the
	## first dawn straight away.
	_state = "narrating"
	_skip = false
	_title.visible = false
	if _xr_rig:
		_xr_rig.queue_free()  # the title plaques live on this rig in VR: forget them with it
		_xr_rig = null
		_plaques.clear()
	var v: VeilDome = game.veil
	game.board.visible = false
	if v:
		v.snap(0.0, 0.0)
	if story:
		var stage := OpeningStage.new()
		stage.game = game
		stage.name = "OpeningStage"
		game.add_child(stage)
		var cam: Camera3D = game._xr_cam if game._xr_cam else get_viewport().get_camera_3d()
		stage.place(cam, game.board.global_position + Vector3(0, 0.5, 1.0))
		await stage.play()
		_skip = stage._skipped
		stage.queue_free()
	else:
		_skip = true
	game.board.visible = true
	if game.lighting:
		game.lighting.set_mood("dawn", 0.5)
	if game.life:
		game.life._morning()
	game._set_light(0)
	if v:
		v.snap(1.0, 0.0)
	if game.life and _skip:
		game.life._morning()
	game.snd("dawn_bell")
	_title.queue_free()
	_plaques.clear()
	game._board_placed = false
	game._tray_placed = false
	game.asleep = false
	_state = "playing"
	game.say_at_shrine(StoryText.prayer(0, 0))
	_step = 0
	_step_time = 0.0
	_step_entered = -1
	_last_run_serial = game.run_serial
	_enter_step(0)


func _hint(line: String) -> void:
	## The tutorial, in the world and big, from the moment the story ends (the user, 2026-11-11: "the tutorial needs to be
	## there when the game starts, not only in the ledger"). One gilded line over the island, its own parent so the story's
	## title cards never replace it.
	if _hint_root == null or not is_instance_valid(_hint_root):
		_hint_root = Node3D.new()
		_hint_root.name = "HintRoot"
		game.update_hud_root()
		game.hud_root.add_child(_hint_root)
	_hint_card = TitleCard.show_over(_hint_root, TUTORIAL_HINT_POS, line, "%d of %d" % [mini(_step + 1, HINTS.size()), HINTS.size()], -1.0, 54)


func _end_hints() -> void:
	if _hint_card and is_instance_valid(_hint_card):
		_hint_card.dismiss()
	_hint_card = null
	_clear_ghost()
	if is_instance_valid(_cont):
		_cont.queue_free()
	_cont = null
	if is_instance_valid(game):
		game.tutorial_hold = false
	if is_instance_valid(_cue_root):
		_cue_root.queue_free()
	_cue_root = null
	_target_ring = null
	_ring_mat = null
	if is_instance_valid(game):
		game.set_tutorial_spotlight("")


func _ensure_cues() -> void:
	if not is_instance_valid(game) or not game.with_rig:
		return
	if _cue_root == null or not is_instance_valid(_cue_root):
		_cue_root = Node3D.new()
		_cue_root.name = "TutorialCues"
		game.add_child(_cue_root)
	if _target_ring == null or not is_instance_valid(_target_ring):
		_target_ring = MeshInstance3D.new()
		_target_ring.name = "TargetRing"
		var tor := TorusMesh.new()
		tor.inner_radius = 0.050
		tor.outer_radius = 0.072
		tor.rings = 32
		tor.ring_segments = 12
		_target_ring.mesh = tor
		_ring_mat = ModelUtil.flat_material(Color(GLOW.r, GLOW.g, GLOW.b, 0.92), true)
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.no_depth_test = false
		_ring_mat.emission_enabled = true
		_ring_mat.emission = GLOW
		_ring_mat.emission_energy_multiplier = 1.65
		_ring_mat.render_priority = 24
		_target_ring.material_override = _ring_mat
		_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cue_root.add_child(_target_ring)


func _clear_ghost() -> void:
	if is_instance_valid(_active_ghost):
		_active_ghost.queue_free()
	_active_ghost = null
	for g in _extra_ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_extra_ghosts.clear()


func _total_villager_taps() -> int:
	if game == null or game.life == null:
		return 0
	var total := 0
	for v in game.life.villagers:
		total += v.taps
	return total


func _nearest_villager_pos() -> Vector3:
	if game == null or game.life == null:
		return game.board.to_global(Vector3(0, 0.03, 0))
	var anchor := game.board.to_global(Vector3(0, 0, Game.HALF * 0.5))
	var best_pos := Vector3.INF
	var best_d := INF
	for v in game.life.villagers:
		if is_instance_valid(v) and v.visible:
			var d := v.global_position.distance_squared_to(anchor)
			if d < best_d:
				best_d = d
				best_pos = v.global_position + Vector3(0, 0.02, 0)
	return best_pos if best_pos != Vector3.INF else game.board.to_global(Vector3(0, 0.03, 0))


func tutorial_build_cell() -> Vector2i:
	## Picks an open front/east 2x2 grass cell for the first tutorial tower so seeded props never block it.
	if game == null or not is_instance_valid(game) or game.nav == null:
		return TUTORIAL_BUILD_CELL
	var standing := game.standing_houses()
	for c in [TUTORIAL_BUILD_CELL, Vector2i(16, 11), Vector2i(11, 3), Vector2i(9, 3), Vector2i(5, 11)]:
		if game.nav.can_build(c, GameConfig.TOWER_SIZE, standing):
			return c
	for y in range(2, 20):
		for x in range(2, 20):
			var c := Vector2i(x, y)
			if game.nav.can_build(c, GameConfig.TOWER_SIZE, standing):
				return c
	return TUTORIAL_BUILD_CELL


func _open_quest() -> HelpRequest:
	## The quest the player can do now: the first open one, a prayer first.
	var best: HelpRequest = null
	for r in game.requests:
		if is_instance_valid(r) and not r.done:
			if r.kind == "prayer":
				return r
			if best == null:
				best = r
	return best


func _ensure_open_quest() -> HelpRequest:
	## Tutorial step 3 needs a visible prayer quest even when another quest is open or a house has no free villager.
	for r in game.requests:
		if is_instance_valid(r) and not r.done and r.kind == "prayer":
			return r
	if game.phase != Game.Phase.DAY:
		return null
	game.quest_plan = game.quest_plan.filter(func(q): return q.get("kind", "") != "prayer")
	var open_houses: Array = game.standing_houses().filter(func(h): return not game.requests.any(func(r): return is_instance_valid(r) and r.house == h))  # never a house that already has a quest
	var home := -1
	for h in open_houses:  # prefer a house that has a free villager to ask
		if game.life != null and game.life.villagers.any(func(v): return v.home == h and v.claim == Vector3.INF):
			home = h
			break
	if home < 0 and not open_houses.is_empty():
		home = open_houses[0]  # no free villager there: a stand-in kneels by the statue instead
	return game._post_quest("prayer", home) if home >= 0 else null


func _step_line(idx: int) -> String:
	if idx == 3:
		var q := _open_quest()
		if q != null and q.kind != "prayer":
			return "Someone needs help! " + String(HelpRequest.HOW.get(q.kind, ""))
	return HINTS[idx]


func _ring_target_for_step() -> Array:
	## Returns [world_pos, ring_scale, visible] for the active tutorial step's golden cue ring.
	if game == null or not is_instance_valid(game):
		return [Vector3.ZERO, 1.0, false]
	match _step:
		0, 1, REBUILD_STEP:
			return [game.board.to_global(NavGrid.footprint_centre(tutorial_build_cell(), GameConfig.TOWER_SIZE) + Vector3(0, 0.025, 0)), 1.0, true]
		2:
			var rim_pos := game._rim_handles[0].global_position if not game._rim_handles.is_empty() and is_instance_valid(game._rim_handles[0]) \
				else game.board.to_global(Vector3(0, 0.004, Game.HALF + 0.032))
			return [rim_pos + Vector3(0, 0.022, 0), 0.9, true]
		3:
			var q_pos := game.board.to_global(Vector3(0, 0.03, 0))
			var oq := _open_quest()
			if oq != null:
				q_pos = oq.focus_point() + Vector3(0, 0.02, 0)
			return [q_pos, 0.65, true]
		4:
			return [_nearest_villager_pos(), 0.65, true]
		5:
			var l_pos := game.lens_grip_position() if game._lens else Vector3.INF
			if l_pos == Vector3.INF:
				return [Vector3.ZERO, 0.55, false]
			return [l_pos + Vector3(0, 0.018, 0), 0.55, true]
		6:
			if game._tray == null or game._tray.handles.is_empty() or not is_instance_valid(game._tray.handles[1]):
				return [Vector3.ZERO, 0.55, false]
			return [game._tray.handles[1].global_position + Vector3(0, 0.02, 0), 0.55, true]
		7:
			return [game.board.to_global(Vector3(0, 0.12, Game.HALF + 0.12)), 0.8, true]
		8:
			if game.ledger != null and game.ledger.open:
				return [Vector3.ZERO, 0.55, false]
			return [game._eye() + Vector3(game.board.global_position.x - game._eye().x, 0, game.board.global_position.z - game._eye().z).normalized() * 0.3 + Vector3(-0.12, -0.3, 0), 0.6, true]
		SELL_STEP:
			if game.towers.is_empty() or not is_instance_valid(game.towers[0]):
				return [Vector3.ZERO, 0.55, false]
			return [game.towers[0].global_position + Vector3(0, 0.02, 0), 0.7, true]
		HOURGLASS_STEP:
			if game._fast_glass == null or not is_instance_valid(game._fast_glass):
				return [Vector3.ZERO, 0.55, false]
			return [game._fast_glass.global_position + Vector3(0, 0.022, 0), 0.55, true]
		NIGHT_STEP:
			for e in game.enemies:
				if is_instance_valid(e) and e.alive:
					return [e.global_position + Vector3(0, 0.02, 0), 1.0, true]
			var north: Array = GameConfig.SPAWNS["north"]
			return [game.board.to_global(NavGrid.cell_centre(north[north.size() / 2]) + Vector3(0, 0.015, 0)), 1.0, true]
	return [Vector3.ZERO, 1.0, false]


func _update_ring() -> void:
	_ensure_cues()
	if _target_ring == null or not is_instance_valid(_target_ring):
		return
	var info := _ring_target_for_step()
	info[2] = info[2] and not _step_done
	_target_ring.visible = info[2]
	if not info[2]:
		return
	_target_ring.global_position = info[0]
	_ring_scale = info[1]
	var s := _ring_scale * (1.0 + 0.12 * sin(_t * 5.0))
	_target_ring.scale = Vector3(s, s * 0.35, s)
	if _ring_mat:
		_ring_mat.albedo_color.a = 0.72 + 0.20 * sin(_t * 5.0)


func _spawn_step_ghost() -> void:
	_ensure_cues()
	_clear_ghost()
	if _cue_root == null or not game.with_rig:
		return
	var info := _ring_target_for_step()
	if not info[2]:
		return
	var target: Vector3 = info[0]
	match _step:
		0:
			if game._tray and not game._tray.cards.is_empty() and is_instance_valid(game._tray.cards[0]):
				var tb := Basis(Vector3.UP, atan2(game._tray.global_transform.basis.z.x, game._tray.global_transform.basis.z.z))
				var from_pos := game._tray.cards[0].global_position + tb * Vector3(-0.046, 0.016, -0.008)
				_active_ghost = GhostHand.carry(_cue_root, from_pos, from_pos + tb * Vector3(0.014, 0.042, -0.032))
				_active_ghost.basis = tb * Basis.from_euler(Vector3(deg_to_rad(28.0), 0.0, deg_to_rad(-28.0)))
			else:
				_active_ghost = GhostHand.hover(_cue_root, target + Vector3(0, 0.03, 0))
		1, REBUILD_STEP:
			var pick: Card3D = null
			if game._tray:
				for c in game._tray.cards:
					if is_instance_valid(c):
						if pick == null:
							pick = c
						if String(c.data.get("id", "")) == game.selected:
							pick = c
							break
			if pick != null:
				_active_ghost = GhostHand.carry(_cue_root, pick.global_position + Vector3(0, 0.02, 0), target + Vector3(0, 0.025, 0))
			else:
				_active_ghost = GhostHand.hover(_cue_root, target + Vector3(0, 0.025, 0))
		2:
			_active_ghost = GhostHand.carry(_cue_root, target + Vector3(-0.07, 0.01, 0), target + Vector3(0.07, 0.01, 0))
		3:
			var gq := _open_quest()
			if gq != null and is_instance_valid(gq._ghost):
				return
			_active_ghost = GhostHand.tap(_cue_root, target + Vector3(0, 0.015, 0))
		4:
			_active_ghost = GhostHand.tap(_cue_root, target + Vector3(0, 0.015, 0))
		5:
			_active_ghost = GhostHand.carry(_cue_root, target, target + Vector3(0, 0.14, -0.05))
		6:
			var side := game._tray.global_transform.basis.x.normalized()
			_active_ghost = GhostHand.carry(_cue_root, target + Vector3(0, 0.01, 0), target + side * 0.06 + Vector3(0, 0.01, -0.04))
		7:
			var across := game.board.global_transform.basis.x.normalized()
			_active_ghost = GhostHand.carry(_cue_root, target - across * 0.05, target - across * 0.2)
			var pair := GhostHand.carry(_cue_root, target + across * 0.05, target + across * 0.2)
			_extra_ghosts.append(pair)
		8:
			_active_ghost = GhostHand.hover(_cue_root, target)
		SELL_STEP:
			_active_ghost = GhostHand.hover(_cue_root, target + Vector3(0, 0.04, 0))
		HOURGLASS_STEP:
			_active_ghost = GhostHand.hover(_cue_root, target + Vector3(0, 0.02, 0))
		NIGHT_STEP:
			var from_at := game._tray.cards[0].global_position + Vector3(0, 0.02, 0) if game._tray and not game._tray.cards.is_empty() and is_instance_valid(game._tray.cards[0]) \
				else target + Vector3(0, 0.08, 0.08)
			_active_ghost = GhostHand.carry(_cue_root, from_at, target + Vector3(0, 0.03, 0))
	if is_instance_valid(_active_ghost):
		if _active_ghost._mat:
			_active_ghost._mat.albedo_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.85 if _step == 0 else 0.68)
			_active_ghost._mat.emission_enabled = false
		if _step != HOURGLASS_STEP:
			_active_ghost.scale = Vector3.ONE * 1.4
		for g in _extra_ghosts:
			if is_instance_valid(g) and g._mat:
				g._mat.albedo_color = _active_ghost._mat.albedo_color if _active_ghost._mat else GOLD
				g._mat.emission_enabled = false
				g.scale = Vector3.ONE * 1.4


func _enter_step(idx: int) -> void:
	_step = idx
	_step_time = 0.0
	_step_entered = idx
	_step_done = false
	_towers_at_step = game.towers.size()
	if is_instance_valid(_cont):
		_cont.visible = false
	game.tutorial_hold = idx < HOURGLASS_STEP
	if idx == 0:
		game.day_time = 0.0  # the day starts at its full length when the tutorial begins
	_clear_ghost()
	_ghost_timer = 0.08
	if _step >= HINTS.size():
		_end_hints()
		return
	if _step == 3:
		_helped_at_step = game._helped
		_step3_quest = _ensure_open_quest()
	else:
		_step3_quest = null
	_hint(_step_line(_step))
	var spotlights := ["cards", "cards", "rim", "board", "board", "lens", "tray", "zoom", "ledger", "board", "cards", "hourglass", "spells"]
	game.set_tutorial_spotlight(spotlights[_step])
	match _step:
		2:
			_start_board_yaw = game.board.rotation.y
			_start_board_pos = game.board.global_position
		3:
			pass
		4:
			_taps_at_step = _total_villager_taps()
	_update_ring()


func _tutorial(delta: float) -> void:
	## Interactive, step-gated tutorial: highlights the active target with a golden ring + GhostHand, never silently times out.
	if game == null or not is_instance_valid(game):
		return
	if _last_run_serial != game.run_serial:
		_last_run_serial = game.run_serial
		if game.loop == 0 and game.night == 0 and game.phase == Game.Phase.DAY:
			_enter_step(0)
			return
	if _step >= HINTS.size():
		return
	if game.loop > 0 or game.night > 0 or game.phase in [Game.Phase.CARDS, Game.Phase.DONE]:
		_step = HINTS.size()
		_end_hints()
		return
	if _step_entered != _step:
		_enter_step(_step)
	if game.phase == Game.Phase.NIGHT and _step < NIGHT_STEP:
		_enter_step(NIGHT_STEP)
		return
	_step_time += delta
	_ghost_timer -= delta
	if _ghost_timer <= 0.0 and not is_instance_valid(_active_ghost) and not _step_done:
		_spawn_step_ghost()
		_ghost_timer = 2.8
	_update_ring()
	if _step == 1 and game.towers.is_empty() and game._held_card == null and game.selected == "":
		_enter_step(0)
		return
	var done := _step_done
	if not done:
		match _step:
			0:
				done = game._held_card != null or game.selected != "" or not game.towers.is_empty()
			1:
				done = not game.towers.is_empty()
				if done:
					game.spawn_tutorial_shade(game.towers[0])
			2:
				done = not game._rim_hands.is_empty() \
					or absf(angle_difference(game.board.rotation.y, _start_board_yaw)) > 0.03 \
					or game.board.global_position.distance_to(_start_board_pos) > 0.015
			3:
				if not is_instance_valid(_step3_quest):
					_step3_quest = _ensure_open_quest()
					if _step3_quest != null:
						_hint(_step_line(3))
				done = is_instance_valid(_step3_quest) and _step3_quest.done
			4:
				done = _total_villager_taps() > _taps_at_step
			5:
				done = game.foresight.showing or game.phase != Game.Phase.DAY
			6:
				done = game._tray_hand != null or not game._xr  # mouse play has no hands to grab or zoom with
			7:
				done = (not game._zoom_hands.is_empty() and absf(game._zoom_d - game._zoom_d0) > GameConfig.ZOOM_DEADZONE) or not game._xr
			8:
				done = (game.ledger != null and game.ledger.open) or not game._xr
			SELL_STEP:
				done = game.towers.size() < _towers_at_step or _towers_at_step == 0
			REBUILD_STEP:
				done = not game.towers.is_empty()
			HOURGLASS_STEP:
				done = game.phase == Game.Phase.NIGHT
			NIGHT_STEP:
				done = game.spells.cooldown.values().any(func(cd): return cd > 0.0) or game.phase != Game.Phase.NIGHT
	if done and not _step_done:
		_step_done = true
		if _step >= HOURGLASS_STEP:
			_advance()  # the night steps flow on their own
			return
		game.snd("trust_chime")
		_hint("Well done! Take your time, then tap Continue.")
	if _step_done:
		_update_continue()


func _advance() -> void:
	if _step + 1 >= HINTS.size():
		_step = HINTS.size()
		game.snd("trust_chime")
		game.last_message = "Well struck! Defend the village till dawn."
		game._refresh_ui()
		_end_hints()
	else:
		_enter_step(_step + 1)


func _update_continue() -> void:
	## The Continue plaque under the tutorial text, shown MIN_STEP_S after the step began and once its action is done. It
	## turns to face the player and is pressed like the title's plaques (a fingertip, or the pinch ray).
	if _cont == null or not is_instance_valid(_cont):
		_cont = Plaque.make("Continue")
		game.update_hud_root()
		game.hud_root.add_child(_cont)
		_cont.position = Vector3(0, 0.03, 0)
	_cont.visible = _step_done and _step_time >= MIN_STEP_S
	if not _cont.visible:
		return
	var eye := game._eye()
	var d := eye - _cont.global_position
	_cont.global_transform = Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)) * Basis(Vector3.RIGHT, deg_to_rad(-30.0)) * Basis.from_scale(Vector3.ONE * 2.2 * game.hud_root.scale.x), _cont.global_position)
	var hot := false
	for h in game._hands:
		hot = hot or _cont.hit_point(h.touch_point(), maxf(0.02, _touch_pad())) or _cont.hit_ray(h.ray_origin(), h.ray_dir())
	if game._camera and not game._xr:
		var m := get_viewport().get_mouse_position()
		hot = hot or _cont.hit_ray(game._camera.project_ray_origin(m), game._camera.project_ray_normal(m))
	_cont.hot = hot
