class_name Game
extends Node3D
## The game loop (spec 6 + 15). Day = spend trust on towers and help villagers (requests, done by hand);
## Night = enemies walk from the forest gaps to the houses; Dawn = income (+5 per standing house, +10 x night
## for clearing it) and +10 HP for each house (damage carries over). A loop is 5 nights + a boss night
## (the 3-phase Warden). Beating the boss offers 3 ability cards (keep 1); losing a night offers 1
## Common card. Either way the hourglass turns: the next loop starts, harder, with trust, towers and damage
## reset but cards kept. A run is 5 loops. Runs in the Meta XR Simulator (hand
## rays, pinch) or on the desktop with the mouse when OpenXR is not running.
##
## Desktop = a MOUSE HAND: it follows the mouse at a height the wheel sets (a stem and a ring show where it is above
## the board), left click is its pinch. It uses the same code as the VR hands: pinch near the lens, a request prop or a
## spell token to grab it, anywhere else to press what the mouse points at (signs, board cells). While a tower, Sell or
## a spell is armed, clicks only place/cast. A faint bubble round the hand shows the grab reach (lights up when
## something can be grabbed): on in the desktop and in the simulator (AETERNA_EASY_REACH=1), reach doubled there.
## Spells (night): keys 1-5 or the signs pick Fire Orb, Boulder Drop, Storm Cloud, Rage or Root Ward, then click the
## board to cast (mouse wheel sets the Boulder's drop height). VR: pinch a spell's token on the table, move your hand
## over the board and let go (the boulder falls from the height you let go).
## Requests: drag a request's prop with the mouse (VR: pinch it and move your hand), let go to finish.
## Desktop keys: 1 / 2 / 3 / 4 pick a tower (1-3 pick a card when cards are offered), 5 = sell (then click a tower), left click builds, Esc or right click cancels, Enter or Space
## starts the night, Tab toggles x2 speed (a player option, also a sign during the night), R restarts the run.
## Debug builds only: F5 toggles x5, F6 x10 and F7 x50 (for testing, not part of the game).
## Foresight: hold L to look through the Crystal Lens during the day (in VR: grab the lens on the table's right
## corner and hold it up; it shows the groups you look toward).
##
## Everything moving is ticked from step(), so tests/game_selftest.gd can play whole nights headless.

signal phase_changed(phase: int)

enum Phase { DAY, NIGHT, CARDS, DONE }

# Table height; the 1.2 m board's near edge sits 0.25 m in front of a seated player
const BOARD_POS := Vector3(0, 0.75, -0.85)
const HALF := GameConfig.SIZE * GameConfig.CELL / 2.0
const MAX_TICK := 0.05  # fast speeds run several small steps a frame, so nothing skips past a target

## false = no camera, hands or input (headless tests build the game without them)
var with_rig := true
var run_seed := 1

var board: Node3D
var nav: NavGrid
var grass: GrassField
var _path_tiles: Array[Rect2] = []
var _prop_points: Array[Vector2] = []
var decor_cells: Array[Vector2i] = []  # cells under village props: they block towers, not enemies
var houses: Array[House] = []
var towers: Array[Tower] = []
var enemies: Array[Enemy] = []
var shots: Array[Projectile] = []
var shots_root: Node3D
var trust := GameConfig.START_TRUST
var night := 0  # 0-based, within the loop; GameConfig.BOSS_NIGHT is the boss night
var loop := 0  # 0-based; a run is GameConfig.LOOPS_PER_RUN loops
var cards := {}  # ability cards held: id -> rarity (0 Common, 1 Rare, 2 Legendary); kept through the loop
var offers: Array[Dictionary] = []  # cards on the table during Phase.CARDS
var loop_won := false  # how the current loop ended (beat the boss, or lost a night)
var phase := Phase.DAY
var night_time := 0.0
var selected := ""  # tower kind being placed, "" = none
var speed := 1.0  # 1 or 2 for the player (2026-10-22, Siddharth); 5 and 10 are debug only
var last_message := ""

var foresight: Foresight
var spells: Spells
var spell_sel := ""  # the spell armed with a sign or key, waiting for a click on the board
var spell_height := GameConfig.SPELLS["boulder"]["default_height"]  # the Boulder's drop height (cells) for mouse casts
var _held_spell := ""  # VR: the spell token in a hand
var _held_spell_hand: GameHand
var requests: Array[HelpRequest] = []
var _requests_root: Node3D
var _held_req: HelpRequest  # the request prop being moved
var _held_req_hand: GameHand  # the hand holding it, or null for the mouse
var closed_spawn := ""  # Foresight tier 3 rewrite: the gap closed for the coming night

var _lens: Node3D  # the Crystal Lens model (spec 13)
var _lens_rest := Transform3D.IDENTITY  # where it lies when nobody holds it (board-local)
var _lens_grip := Vector3.ZERO  # the grip anchor in the lens model's own space
var _lens_hand: GameHand  # the hand holding it, or null
var _xr_cam: XRCamera3D
var easy_reach := false  # desktop and simulator: grab distances x GameConfig.EASY_REACH and the reach bubbles show
var _mouse_hand: GameHand  # desktop only
var _hand_height := 0.03  # m above the board: set with the mouse wheel
var _hand_stem: MeshInstance3D
var _hand_ring: MeshInstance3D
var _patches: Array = []  # burning ground (Hot Coals Legendary): {"pos", "r", "dps", "left"}
var _held_tonight := false  # Sturdy Homes Legendary: one house held at 1 HP per night
var _hourglass: Node3D
var warden: Warden  # the boss's phases, while the Warden is alive (null otherwise)
var _spawn_queue: Array = []  # [{"t": s, "cell": Vector2i, "kind": String}], sorted by time
var _rng := RandomNumberGenerator.new()  # seeded per night: cluster sizes, gap cells, walking offsets
var _towers_root: Node3D
var _enemies_root: Node3D
var _grid_lines: MeshInstance3D
var _ghost: Node3D
var _ghost_plate: MeshInstance3D
var _ghost_models := {}
var _ghost_ring: MeshInstance3D
var _hover_cell := Vector2i(-1, -1)
var _hover_board_cell := Vector2i(-1, -1)  # the single cell under the pointer (for selling)
var _buttons := {}  # id -> {"node", "mat", "label", "box": AABB (board-local)}
var _hud: Label3D
var _msg: Label3D
var lighting: Lighting  # the four moods, tonemap, bloom and fog (scripts/vfx/lighting.gd)
var _camera: Camera3D
var _hands: Array[GameHand] = []
var _active_hand: GameHand
var _xr := false


func _ready() -> void:
	if with_rig:
		_xr = _init_xr()
		easy_reach = not _xr or OS.get_environment("AETERNA_EASY_REACH") == "1"
	_build_lights()
	board = Node3D.new()
	board.name = "Board"
	board.position = BOARD_POS
	add_child(board)
	WorldBuilder.build_island(board)
	WorldBuilder.build_forest(board, 7)
	_grid_lines = WorldBuilder.build_grid_lines(board)
	_towers_root = _child(board, "Towers")
	_enemies_root = _child(board, "Enemies")
	shots_root = _child(board, "Shots")
	_build_houses()
	var dressing := VillageDresser.build(board, 11)
	decor_cells = dressing["decor"]
	_path_tiles = dressing["tiles"]
	_prop_points = dressing["props"]
	_build_ghost()
	spells = Spells.new()
	spells.name = "Spells"
	spells.game = self
	board.add_child(spells)
	foresight = Foresight.new()
	foresight.name = "Foresight"
	foresight.game = self
	board.add_child(foresight)
	_requests_root = _child(board, "Requests")
	_build_ui()
	_build_lens()
	if with_rig:
		_build_rig()
	new_run(run_seed)


func _child(parent: Node, n: String) -> Node3D:
	var c := Node3D.new()
	c.name = n
	parent.add_child(c)
	return c


# ---------------------------------------------------------------- run, phases

func new_run(rng_seed: int) -> void:
	run_seed = rng_seed
	loop = 0
	cards = {}
	offers = []
	speed = 1.0
	_start_loop("Day 1. Spend trust on towers, then start the night.")


func _start_loop(message: String) -> void:
	## Everything the time loop resets (spec 15): night counter, trust, towers, village damage.
	for t in towers:
		t.queue_free()
	towers.clear()
	_clear_night()
	nav = NavGrid.new()
	for c in decor_cells:
		nav.kind[c] = "decor"
	if grass == null:
		grass = GrassField.build(board, nav, _path_tiles, _prop_points, 5)
	else:
		grass.refresh(nav)
	var sturdy := card("sturdy_homes")
	for h in houses:
		h.max_hp = GameConfig.HOUSE_HP * (1.0 + (Cards.value("sturdy_homes", sturdy) / 100.0 if sturdy >= 0 else 0.0))
		h.repair()
	var pockets := card("deep_pockets")
	trust = GameConfig.START_TRUST + (int(Cards.value("deep_pockets", pockets)) if pockets >= 0 else 0)
	night = 0
	closed_spawn = ""
	_set_phase(Phase.DAY, message)


func card(id: String) -> int:
	## Rarity of a held card, or -1 when it is not held.
	return cards.get(id, -1)


func _set_phase(p: int, message: String) -> void:
	phase = p
	last_message = message
	if p != Phase.DAY:
		select("")
	if p != Phase.NIGHT and spells:
		spell_sel = ""
		spells.hide_aim()
	if foresight and foresight.showing:
		set_lens(false)  # the lens only reads the coming night; it goes blank when the day ends
	if _requests_root and p == Phase.DAY:
		_post_requests()
	elif _requests_root:
		_clear_requests()
	_set_light(p)
	_refresh_ui()
	phase_changed.emit(p)


func start_night() -> bool:
	if phase != Phase.DAY:
		return false
	night_time = 0.0
	_spawn_queue.clear()
	spells.reset()
	_rng.seed = run_seed * 31 + night
	_held_tonight = false
	for g in night_plan():
		# a group leaves the forest in clusters of 2-3 that come out together, each from a random cell of the gap
		var gap: Array = GameConfig.SPAWNS[g["spawn"]]
		var list: Array = g["enemies"]
		var i := 0
		var t: float = g["time"]
		while i < list.size():
			var n := mini(_rng.randi_range(GameConfig.CLUSTER_SIZE.x, GameConfig.CLUSTER_SIZE.y), list.size() - i)
			for j in range(n):
				var c: Vector2i = gap[_rng.randi_range(0, gap.size() - 1)]
				_spawn_queue.append({"t": t + _rng.randf_range(0.0, 0.4), "cell": c, "kind": list[i + j]})
			i += n
			t += GameConfig.CLUSTER_GAP
	_spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	if night == GameConfig.BOSS_NIGHT:
		_set_phase(Phase.NIGHT, "Boss night. The Warden comes.")
	else:
		_set_phase(Phase.NIGHT, "Night %d. They come from the forest." % (night + 1))
	return true


func night_plan() -> Array[Dictionary]:
	## The coming night's groups (WavePlan), with a Foresight rewrite applied (a closed spawn's groups come
	## from the next edge instead) and, on the boss night, the boss as its own group. What Foresight reveals.
	var plan := WavePlan.groups_for(night, run_seed, loop)
	if night == GameConfig.BOSS_NIGHT:
		var edges: Array = GameConfig.SPAWNS.keys()
		var r := RandomNumberGenerator.new()
		r.seed = run_seed * 131 + loop * 7 + night
		plan.append({"time": GameConfig.BOSS_DELAY, "spawn": edges[r.randi_range(0, edges.size() - 1)], "enemies": ["boss"]})
	if closed_spawn != "":
		var keys: Array = GameConfig.SPAWNS.keys()
		for g in plan:
			if g["spawn"] == closed_spawn:
				g["spawn"] = keys[(keys.find(closed_spawn) + 1) % keys.size()]
	return plan


func foresight_tier() -> int:
	return GameConfig.FORESIGHT_TIER_BY_LOOP[mini(loop, GameConfig.FORESIGHT_TIER_BY_LOOP.size() - 1)]


func close_spawn(spawn: String) -> bool:
	## Foresight top-tier rewrite: close one forest gap for the coming night, once per night.
	if phase != Phase.DAY or foresight_tier() < GameConfig.FORESIGHT_TIERS or closed_spawn != "" or not GameConfig.SPAWNS.has(spawn):
		return false
	closed_spawn = spawn
	last_message = "The lens rewrites the night: the %s path is closed. Its enemies take the next one." % spawn
	if foresight.showing:
		foresight.refresh()
	_refresh_ui()
	return true


func nearest_house_to(p: Vector3) -> int:
	## Straight-line nearest standing house (flyers and Tunnelers do not follow the ground routes).
	var best := -1
	var best_d := INF
	for i in standing_houses():
		var d := Vector2(house_point(i).x - p.x, house_point(i).z - p.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best


func house_point(i: int) -> Vector3:
	return NavGrid.footprint_centre(houses[i].cell, GameConfig.TOWER_SIZE)


func surface_cell(house: int, p: Vector3) -> Vector2i:
	## Where a Tunneler heading for `house` from `p` comes up: the free cell next to the house closest to p.
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in nav.goals_of(house):
		var d := Vector2(NavGrid.cell_centre(c).x - p.x, NavGrid.cell_centre(c).z - p.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func _post_requests() -> void:
	## The day's requests: one of each kind, on different standing houses, in a seeded order.
	_clear_requests()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 53 + loop * 11 + night
	var where: Array = standing_houses()
	var kinds: Array = GameConfig.REQUESTS.keys()
	for arr in [where, kinds]:
		for i in range(arr.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = arr[i]
			arr[i] = arr[j]
			arr[j] = t
	for i in range(mini(GameConfig.REQUESTS_PER_DAY, mini(where.size(), kinds.size()))):
		var r := HelpRequest.new()
		r.game = self
		_requests_root.add_child(r)
		r.setup(kinds[i], where[i], _lantern_spot(where[i], rng) if kinds[i] == "lantern" else Vector3.ZERO)
		requests.append(r)


func _open_at(c: Vector2i) -> bool:
	## A cell with a clear cell on every side: not forest, house, tower or spawn, and none of those next to it
	## (what stands next to a prop can hide it from the seat).
	if c.x < 2 or c.y < 2 or c.x > GameConfig.SIZE - 3 or c.y > GameConfig.SIZE - 3:
		return false
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if nav.kind.has(c + Vector2i(dx, dy)):
				return false
	return true


func open_ground_near(p: Vector3) -> Vector3:
	## Centre of the nearest open cell to a board-local point (rings of growing size round it).
	var c := NavGrid.local_to_cell(p)
	for r in range(0, GameConfig.SIZE):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if _open_at(n) and Vector2(dx, dy).length() < best_d:
					best_d = Vector2(dx, dy).length()
					best = n
		if best.x >= 0:
			return NavGrid.cell_centre(best)
	return p


func _lantern_spot(house: int, rng: RandomNumberGenerator) -> Vector3:
	## Open grass LANTERN_DISTANCE cells from the house: not a house, tower, forest or spawn cell.
	var centre := house_point(house)
	for i in range(60):
		var a := rng.randf() * TAU
		var d := rng.randf_range(GameConfig.LANTERN_DISTANCE.x, GameConfig.LANTERN_DISTANCE.y) * GameConfig.CELL
		var p := centre + Vector3(cos(a), 0, sin(a)) * d
		var c := NavGrid.local_to_cell(p)
		if _open_at(c):
			return NavGrid.cell_centre(c)
	return centre + Vector3(0, 0, 3.0 * GameConfig.CELL)


func _clear_requests() -> void:
	_held_req = null
	_held_req_hand = null
	for r in requests:
		r.queue_free()
	requests.clear()


func reach(metres: float) -> float:
	## A grab distance, doubled where easy reach is on.
	return metres * (GameConfig.EASY_REACH if easy_reach else 1.0)


func grabbable_near(world: Vector3) -> bool:
	## Is anything a pinch here would pick up (the lens, a request prop, a spell token) within reach?
	if placing():
		return false
	if _lens and _lens_hand == null and world.distance_to(lens_grip_position()) <= reach(GameConfig.LENS_GRAB_REACH):
		return true
	if request_near(world) != null:
		return true
	return phase == Phase.NIGHT and _held_spell == "" and spells.token_near(world) != ""


func placing() -> bool:
	## A tower, Sell or a spell is armed: clicks place or cast instead of grabbing.
	return selected != "" or spell_sel != ""


func request_near(world: Vector3) -> HelpRequest:
	## The open request whose prop is nearest to a hand, within REQUEST_GRAB_REACH.
	var best: HelpRequest = null
	var best_d := reach(GameConfig.REQUEST_GRAB_REACH)
	for r in requests:
		var d := r.grab_point().distance_to(world)
		if not r.done and d <= best_d:
			best_d = d
			best = r
	return best


func grab_request(r: HelpRequest, hand: GameHand = null) -> bool:
	if phase != Phase.DAY or r == null or _held_req != null or not r.grab():
		return false
	_held_req = r
	_held_req_hand = hand
	select("")
	return true


func release_request() -> bool:
	## Let go of the held prop; pays the reward when that finished the request.
	if _held_req == null:
		return false
	var r := _held_req
	_held_req = null
	_held_req_hand = null
	if not r.release():
		return false
	trust += r.reward
	last_message = "%s: thank you! +%d trust" % [GameConfig.REQUESTS[r.kind]["name"], r.reward]
	_refresh_ui()
	return true


func _update_held() -> void:
	if _held_spell != "" and _held_spell_hand:
		var local := board.to_local(_held_spell_hand.global_position)
		var b: Dictionary = GameConfig.SPELLS["boulder"]
		var inside := absf(local.x) <= HALF and absf(local.z) <= HALF
		if inside:
			spells.show_aim(_held_spell, local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
		else:
			spells.hide_aim()
		spells.tokens[_held_spell].global_position = _held_spell_hand.global_position  # the token rides in the hand
	if _held_req == null:
		return
	if _held_req_hand:
		_held_req.move_to(board.to_local(_held_req_hand.global_position))


func cast_spell(id: String, pos: Vector3, height := -1.0) -> bool:
	## Casts a spell at a board-local position; says why when it cannot. The height is for the Boulder (-1 = the
	## mouse height).
	if phase != Phase.NIGHT:
		return false
	if not spells.is_ready(id):
		last_message = "%s is still cooling down (%d s)." % [GameConfig.SPELLS[id]["name"], ceili(spells.cooldown[id])]
		_refresh_ui()
		return false
	var ok := spells.cast(id, pos, spell_height if height < 0.0 else height)
	if ok:
		last_message = "%s!" % GameConfig.SPELLS[id]["name"]
	_refresh_ui()
	return ok


func pick_spell(id: String) -> void:
	## Arms a spell (or puts it down again); only at night.
	if phase != Phase.NIGHT or not GameConfig.SPELLS.has(id):
		return
	spell_sel = "" if spell_sel == id else id
	if spell_sel == "":
		spells.hide_aim()
	_refresh_ui()


func _end_night() -> void:
	## The night was cleared: every enemy spawned and defeated with fewer than 3 houses shuttered.
	var standing := standing_houses().size()
	var income := standing * GameConfig.DAWN_TRUST_PER_HOUSE + GameConfig.NIGHT_CLEAR_TRUST_PER_NIGHT * (night + 1)
	if card("deep_pockets") == 2 and standing == houses.size():
		income += 5  # Deep Pockets Legendary: no house shuttered tonight
	trust += income
	for h in houses:
		h.heal(GameConfig.DAWN_REPAIR)  # damage carries over (Siddharth 2026-10-23)
	for t in towers:
		if t.cfg["kind"] == "spawner":
			t.refill()  # stand-in: the Guards are all back, at full health, by morning
	_clear_night()
	if night == GameConfig.BOSS_NIGHT:
		_end_loop(true)
		return
	night += 1
	closed_spawn = ""
	var next :="Boss night next." if night == GameConfig.BOSS_NIGHT else "Day %d." % (night + 1)
	_set_phase(Phase.DAY, "Dawn. %d houses stood: +%d trust. %s" % [standing, income, next])


func _end_loop(won: bool) -> void:
	## Beat the boss: 3 cards, keep 1. Lost a night: 1 Common card. The last loop of the run offers none.
	loop_won = won
	_clear_night()
	if loop + 1 >= GameConfig.LOOPS_PER_RUN:
		var how := "The Warden falls. Run complete!" if won else "Night %d of loop %d lost. Run over." % [night + 1, loop + 1]
		_set_phase(Phase.DONE, how + " New run = R or the sign.")
		return
	_rng.seed = run_seed * 977 + loop
	offers = Cards.offers(cards, 3 if won else 1, _rng, not won)
	if offers.is_empty():
		_rewind()
		return
	var head := "The Warden falls! Choose 1 card to keep." if won else "Night %d lost. The hourglass gives you a card." % (night + 1)
	_set_phase(Phase.CARDS, head)


func choose_card(i: int) -> bool:
	if phase != Phase.CARDS or i < 0 or i >= offers.size():
		return false
	var o: Dictionary = offers[i]
	cards[o["id"]] = o["rarity"]  # a duplicate is only offered at a higher rarity, so this upgrades it
	offers = []
	_rewind()
	return true


func _rewind() -> void:
	loop += 1
	_play_hourglass()
	var kept := ", ".join(cards.keys().map(func(k): return "%s (%s)" % [Cards.POOL[k]["name"], Cards.RARITY_NAMES[cards[k]]]))
	_start_loop("The hourglass turns. Loop %d: enemies are tougher. Cards kept: %s" % [loop + 1, kept if kept != "" else "none"])


func _play_hourglass() -> void:
	## STAND-IN for the rewind effect (VFX come later): the hourglass model rises over the board, turns, hides.
	if _hourglass == null or not is_inside_tree():
		return
	_hourglass.visible = true
	_hourglass.position = Vector3(0, 0.05, 0)
	_hourglass.rotation = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_hourglass, "position:y", 0.3, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hourglass, "rotation:z", PI, 0.9).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.4)
	tw.tween_callback(func(): _hourglass.visible = false)


func _clear_night() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	warden = null
	for s in shots:
		if is_instance_valid(s):
			s.queue_free()
	shots.clear()
	_spawn_queue.clear()
	_patches.clear()
	if spells:
		spells.clear_effects()
	spell_sel = ""
	_held_spell = ""


func standing_houses() -> Array[int]:
	var out: Array[int] = []
	for h in houses:
		if not h.is_shuttered:
			out.append(h.index)
	return out


func set_speed(s: float) -> void:
	speed = s
	_refresh_ui()


func step(delta: float) -> void:
	## One game tick. Only the night moves; building happens on input.
	if phase != Phase.NIGHT:
		return
	night_time += delta
	while not _spawn_queue.is_empty() and _spawn_queue[0]["t"] <= night_time:
		var ev: Dictionary = _spawn_queue.pop_front()
		var born := _spawn(ev["cell"], ev["kind"])
		if ev["kind"] == "boss":
			warden = Warden.new(self, born)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.step(delta)
	if warden:
		warden.step(delta)
	for t in towers:
		t.step(delta)
	spells.step(delta)
	for pt in _patches:
		pt["left"] -= delta
		for e in enemies.duplicate():
			if is_instance_valid(e) and e.targetable(false, true) and Vector2(e.position.x - pt["pos"].x, e.position.z - pt["pos"].z).length() <= pt["r"]:
				e.take_damage(pt["dps"] * delta, false)
	_patches = _patches.filter(func(pt): return pt["left"] > 0.0)
	for s in shots.duplicate():
		if is_instance_valid(s) and not s.done:
			s.step(delta)
	shots = shots.filter(func(s): return is_instance_valid(s) and not s.done)
	if phase != Phase.NIGHT:
		return  # a house falling can end the night inside the loop above
	var stuck := enemies.all(func(e): return e.target_house == -1)
	if _spawn_queue.is_empty() and (enemies.is_empty() or stuck):
		_end_night()
	else:
		_refresh_hud()


func _spawn(cell: Vector2i, kind: String, at := Vector3.INF) -> Enemy:
	var e := Enemy.new()
	e.game = self
	e.setup(kind, night, loop, _rng)
	_enemies_root.add_child(e)
	e.spawn_at(cell, at)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	return e


func add_patch(pos: Vector3, radius: float, dps: float, seconds: float) -> void:
	_patches.append({"pos": pos, "r": radius, "dps": dps, "left": seconds})


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	if e.burn_left > 0.0 and e.burn_spreads:
		# Ember Shot Legendary: the burn passes to the nearest enemy within 1 cell
		var best: Enemy = null
		var best_d := GameConfig.CELL
		for o in enemies:
			if is_instance_valid(o) and o.alive and o.position.distance_to(e.position) <= best_d:
				best_d = o.position.distance_to(e.position)
				best = o
		if best:
			best.ignite(e.burn_dps, 3.0, true)
	if e.stats.has("splits_into") and phase == Phase.NIGHT:
		for i in range(e.stats["split_count"]):
			var side := Vector3(GameConfig.CELL * 0.3 * (1 if i == 0 else -1), 0, 0).rotated(Vector3.UP, e.rotation.y)
			_spawn(e.cell, e.stats["splits_into"], e.position + side)


func _on_house_shuttered(_h: House) -> void:
	var down := houses.size() - standing_houses().size()
	if down >= GameConfig.HOUSES_LOST_AT and phase == Phase.NIGHT:
		_end_loop(false)


func _hold_check(_h: House) -> bool:
	## Sturdy Homes Legendary: once per night, the first house that would be shuttered holds at 1 HP.
	if card("sturdy_homes") == 2 and not _held_tonight:
		_held_tonight = true
		return true
	return false


# ---------------------------------------------------------------- building

func select(kind: String) -> void:
	## A tower kind to place, "sell" to pick towers to sell, or "" for nothing.
	selected = kind if phase == Phase.DAY else ""
	_grid_lines.visible = selected != ""
	for k in _ghost_models:
		_ghost_models[k].visible = k == selected
	_ghost_ring.visible = selected != "sell"
	if selected != "" and selected != "sell":
		_draw_ring(GameConfig.TOWERS[selected]["range"] * GameConfig.CELL)
	_update_ghost()
	_refresh_ui()


func tower_at(cell: Vector2i) -> Tower:
	for t in towers:
		if NavGrid.footprint(t.cell, GameConfig.TOWER_SIZE).has(cell):
			return t
	return null


func sell_value(t: Tower) -> int:
	var cost: int = GameConfig.TOWERS[t.kind]["cost"]
	return cost if t.built_night == night else int(cost * GameConfig.SELL_LATER)


func sell(t: Tower) -> bool:
	## Day only: the tower goes, its cells open up again, and trust comes back (sell_value).
	if phase != Phase.DAY or t == null or not towers.has(t):
		return false
	var back := sell_value(t)
	trust += back
	nav.remove_tower(t.cell, GameConfig.TOWER_SIZE)
	grass.refresh(nav)
	towers.erase(t)
	VfxKit.build_pop(shots_root, t.global_position)
	t.queue_free()
	last_message = "%s sold: +%d trust." % [GameConfig.TOWERS[t.kind]["name"], back]
	if foresight.showing:
		foresight.refresh()
	_update_ghost()
	_refresh_ui()
	return true


func can_build(kind: String, cell: Vector2i) -> bool:
	return phase == Phase.DAY and trust >= GameConfig.TOWERS[kind]["cost"] and not at_max(kind) \
		and nav.can_build(cell, GameConfig.TOWER_SIZE, standing_houses())


func at_max(kind: String) -> bool:
	## Spec 7: some kinds have a board limit (at most 2 Airships).
	return towers.filter(func(t): return t.kind == kind).size() >= GameConfig.TOWERS[kind].get("max", 999)


func try_build(kind: String, cell: Vector2i) -> bool:
	if not can_build(kind, cell):
		return false
	trust -= GameConfig.TOWERS[kind]["cost"]
	nav.add_tower(cell, GameConfig.TOWER_SIZE)
	grass.refresh(nav)
	var t := Tower.new()
	t.game = self
	_towers_root.add_child(t)
	t.setup(kind, cell)
	t.built_night = night
	towers.append(t)
	VfxKit.build_pop(shots_root, t.global_position)
	for r in requests:
		r.dodge(NavGrid.footprint(cell, GameConfig.TOWER_SIZE))
	last_message = "%s built. %d trust left." % [GameConfig.TOWERS[kind]["name"], trust]
	if trust < GameConfig.TOWERS[kind]["cost"] or at_max(kind):
		select("")
	if foresight.showing:
		foresight.refresh()  # a new tower can change the routes the lens draws
	_update_ghost()
	_refresh_ui()
	return true


func _build_houses() -> void:
	var scenes: Array[PackedScene] = []
	for p in GameConfig.HOUSE_SCENES:
		scenes.append(load(p))
	var root := _child(board, "Houses")
	var centre := Vector2(GameConfig.SIZE, GameConfig.SIZE) / 2.0
	for i in GameConfig.HOUSE_CELLS.size():
		var c: Vector2i = GameConfig.HOUSE_CELLS[i]
		var h := House.new()
		root.add_child(h)
		h.position = NavGrid.footprint_centre(c, GameConfig.TOWER_SIZE)
		# door (+Z in the model) toward the open village centre, in 90 degree steps
		var d := centre - (Vector2(c) + Vector2.ONE)
		h.rotation.y = (PI / 2.0 if d.x > 0 else -PI / 2.0) if absf(d.x) > absf(d.y) else (0.0 if d.y > 0 else PI)
		h.setup(scenes[i % scenes.size()], i, c)
		h.shuttered.connect(_on_house_shuttered)
		h.hold_check = _hold_check
		houses.append(h)


func _build_ghost() -> void:
	_ghost = _child(board, "Ghost")
	_ghost_plate = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(GameConfig.CELL * 2 - 0.004, 0.002, GameConfig.CELL * 2 - 0.004)
	_ghost_plate.mesh = pm
	_ghost_plate.position.y = 0.001
	_ghost_plate.material_override = ModelUtil.flat_material(Color.GREEN, true, 0.45)
	_ghost.add_child(_ghost_plate)
	for k in GameConfig.TOWER_ORDER:
		var m: Node3D = load(GameConfig.TOWERS[k]["scene"]).instantiate()
		m.visible = false
		_ghost.add_child(m)
		_ghost_models[k] = m
	_ghost_ring = MeshInstance3D.new()
	_ghost_ring.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF4, 0xDC), true, 0.7)
	_ghost.add_child(_ghost_ring)
	_ghost.visible = false


func _draw_ring(r: float) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in range(65):
		var a := TAU * i / 64.0
		im.surface_add_vertex(Vector3(cos(a) * r, 0.003, sin(a) * r))
	im.surface_end()
	_ghost_ring.mesh = im


func _update_ghost() -> void:
	if selected == "sell":
		# an orange plate over the tower under the pointer
		# a plate wider than the tower's base so its rim shows round it, and the refund in the message line
		var t := tower_at(_hover_board_cell)
		_ghost.visible = t != null
		_ghost_plate.scale = Vector3(1.6, 1, 1.6)
		if t:
			_ghost.position = NavGrid.footprint_centre(t.cell, GameConfig.TOWER_SIZE)
			(_ghost_plate.material_override as StandardMaterial3D).albedo_color = Color(0.95, 0.6, 0.2, 0.6)
			var when := "built today: full cost" if t.built_night == night else "half cost after a night"
			_msg.text = "Sell %s: +%d trust (%s)" % [GameConfig.TOWERS[t.kind]["name"], sell_value(t), when]
		elif _msg:
			_msg.text = "Pick a tower to sell. Full cost back on the day it was built, half after that."
		return
	_ghost_plate.scale = Vector3.ONE
	var show := selected != "" and _hover_cell.x >= 0
	_ghost.visible = show
	if not show:
		return
	_ghost.position = NavGrid.footprint_centre(_hover_cell, GameConfig.TOWER_SIZE)
	var ok := can_build(selected, _hover_cell)
	(_ghost_plate.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.35, 0.45) if ok else Color(0.95, 0.25, 0.2, 0.45)


# ---------------------------------------------------------------- pointer (mouse or hand ray)

func _ray_to_board(origin: Vector3, dir: Vector3) -> Array:
	## The ray in board-local space: [origin, dir].
	var inv := board.global_transform.affine_inverse()
	return [inv * origin, (inv.basis * dir).normalized()]


func _button_at(origin: Vector3, dir: Vector3) -> String:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var inv: Transform3D = b["node"].global_transform.affine_inverse()
		if b["node"].visible and b["box"].intersects_ray(inv * origin, inv.basis * dir) != null:
			return id
	return ""


func _board_cell_at(origin: Vector3, dir: Vector3) -> Vector2i:
	## The cell under the ray, or (-1, -1) off the board.
	var r := _ray_to_board(origin, dir)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(r[0], r[1])
	if hit == null:
		return Vector2i(-1, -1)
	var c := NavGrid.local_to_cell(hit)
	return c if c.x >= 0 and c.y >= 0 and c.x < GameConfig.SIZE and c.y < GameConfig.SIZE else Vector2i(-1, -1)


func _cell_at(origin: Vector3, dir: Vector3) -> Vector2i:
	## Top-left cell of the 2 x 2 footprint centred under the ray, or (-1, -1) off the board.
	var r := _ray_to_board(origin, dir)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(r[0], r[1])
	if hit == null:
		return Vector2i(-1, -1)
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	if absf(hit.x) > half or absf(hit.z) > half:
		return Vector2i(-1, -1)
	var c := NavGrid.local_to_cell(hit - Vector3(GameConfig.CELL / 2.0, 0, GameConfig.CELL / 2.0))
	return c.clamp(Vector2i.ZERO, Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))


func _hover(origin: Vector3, dir: Vector3) -> void:
	var over := _button_at(origin, dir)
	for id in _buttons:
		_buttons[id]["hover"] = id == over
	var c := _cell_at(origin, dir) if over == "" else Vector2i(-1, -1)
	var bc := _board_cell_at(origin, dir) if over == "" else Vector2i(-1, -1)
	if spell_sel != "":
		var sr := _ray_to_board(origin, dir)
		var sh: Variant = Plane(Vector3.UP, 0.0).intersects_ray(sr[0], sr[1])
		if over == "" and sh != null and absf(sh.x) <= HALF and absf(sh.z) <= HALF:
			spells.show_aim(spell_sel, sh, spell_height)
		else:
			spells.hide_aim()
	if c != _hover_cell or bc != _hover_board_cell:
		_hover_cell = c
		_hover_board_cell = bc
		_update_ghost()
	_refresh_buttons()


func _press(origin: Vector3, dir: Vector3) -> void:
	var b := _button_at(origin, dir)
	if b != "":
		_press_button(b)
		return
	if spell_sel != "":
		var sr := _ray_to_board(origin, dir)
		var sh: Variant = Plane(Vector3.UP, 0.0).intersects_ray(sr[0], sr[1])
		if sh == null or absf(sh.x) > HALF or absf(sh.z) > HALF:
			pick_spell(spell_sel)  # pointing off the board puts the spell down
		elif cast_spell(spell_sel, sh):
			spell_sel = ""
			spells.hide_aim()
			_refresh_ui()
		return
	if selected == "":
		return
	if selected == "sell":
		var bc := _board_cell_at(origin, dir)
		if bc.x < 0:
			select("")
		elif not sell(tower_at(bc)):
			last_message = "Pick a tower to sell."
			_refresh_ui()
		return
	var c := _cell_at(origin, dir)
	if c.x < 0:
		select("")
	elif not try_build(selected, c):
		if at_max(selected):
			last_message = "At most %d of those on the board." % GameConfig.TOWERS[selected]["max"]
		elif trust < GameConfig.TOWERS[selected]["cost"]:
			last_message = "Not enough trust."
		else:
			last_message = "Can't build there (blocked, or it would cut the forest off from every house)."
		_refresh_ui()


func _press_button(id: String) -> void:
	if id.begins_with("card"):
		choose_card(int(id.substr(4)))
		return
	if id.begins_with("close_"):
		close_spawn(id.substr(6))
		return
	if id.begins_with("spell_"):
		pick_spell(id.substr(6))
		return
	match id:
		"night":
			start_night()
		"restart":
			new_run(run_seed + 1)
		"speed":
			set_speed(1.0 if speed == 2.0 else 2.0)
		_:
			if GameConfig.TOWERS.has(id) and selected != id:
				# a grey sign does nothing but say why (2026-10-23: it used to pick up a tower that could never be placed)
				if at_max(id):
					last_message = "At most %d of those on the board. Sell one to move it." % GameConfig.TOWERS[id]["max"]
					_refresh_ui()
					return
				if trust < GameConfig.TOWERS[id]["cost"]:
					last_message = "Not enough trust for a %s." % GameConfig.TOWERS[id]["name"]
					_refresh_ui()
					return
			select("" if selected == id else id)


func _unhandled_input(event: InputEvent) -> void:
	if not with_rig:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_5:
				if phase == Phase.NIGHT:
					pick_spell(GameConfig.SPELL_ORDER[4])
				else:
					_press_button("sell")
			KEY_1, KEY_2, KEY_3, KEY_4:
				if phase == Phase.NIGHT:
					pick_spell(GameConfig.SPELL_ORDER[event.keycode - KEY_1])
				elif phase == Phase.CARDS:
					choose_card(event.keycode - KEY_1)  # 4 does nothing here: at most 3 cards
				else:
					_press_button(GameConfig.TOWER_ORDER[event.keycode - KEY_1])
			KEY_ESCAPE:
				select("")
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				start_night()
			KEY_TAB:
				set_speed(1.0 if speed == 2.0 else 2.0)
			KEY_F5:
				if OS.is_debug_build():
					set_speed(1.0 if speed == 5.0 else 5.0)
			KEY_F6:
				if OS.is_debug_build():
					set_speed(1.0 if speed == 10.0 else 10.0)
			KEY_F7:
				if OS.is_debug_build():
					set_speed(1.0 if speed == 50.0 else 50.0)
			KEY_R:
				new_run(run_seed + 1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _mouse_hand:
		_mouse_hand.release()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _mouse_hand:
		var up := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
		if spell_sel == "boulder":
			# a Boulder armed with its sign: the wheel sets how high it is dropped from (whole cells)
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			spell_height = clampf(spell_height + up, b["min_height"], b["max_height"])
			last_message = "Boulder Drop: dropped from %d cells up (mouse wheel changes it)." % int(spell_height)
			_refresh_ui()
		else:
			_hand_height = clampf(_hand_height + up * 0.025, 0.0, 0.45)  # otherwise the wheel moves the hand up and down
	elif event is InputEventMouseButton and event.pressed and _mouse_hand:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_update_mouse_hand()
			_mouse_hand.press()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			select("")
			pick_spell(spell_sel) if spell_sel != "" else null


func _feed_grass() -> void:
	## The grass bends away from ground enemies, Guards and the hands (all cosmetic).
	if grass == null:
		return
	var pts: Array = []
	for e in enemies:
		if is_instance_valid(e) and e.alive and not e.flying and not e.underground:
			pts.append(Vector4(e.global_position.x, e.global_position.y, e.global_position.z, 0.045))
	for t in towers:
		for gd in t.guards:
			if is_instance_valid(gd):
				pts.append(Vector4(gd.global_position.x, gd.global_position.y, gd.global_position.z, 0.03))
	var hands: Array = [_mouse_hand] if _mouse_hand != null else _hands
	for h in hands:
		if is_instance_valid(h):
			pts.append(Vector4(h.global_position.x, h.global_position.y, h.global_position.z, 0.05))
	grass.set_pushers(pts)


func _process(delta: float) -> void:
	var left := delta * speed
	while left > 0.0:
		step(minf(left, MAX_TICK))
		left -= MAX_TICK
	_feed_grass()
	if not with_rig:
		return
	_update_mouse_hand()
	_update_lens()
	_update_held()
	for h in _hands:
		h.set_bubble_hot(grabbable_near(h.global_position))
	if _xr:
		if _active_hand:
			_hover(_active_hand.ray_origin(), _active_hand.ray_dir())
	elif _camera:
		var m := get_viewport().get_mouse_position()
		_hover(_camera.project_ray_origin(m), _camera.project_ray_normal(m))


# ---------------------------------------------------------------- UI (3D, so it works in the headset too)

func _build_ui() -> void:
	var ui := _child(board, "UI")
	var specs := []
	for k in GameConfig.TOWER_ORDER:
		specs.append([k, "%s\n%d trust" % [GameConfig.TOWERS[k]["name"], GameConfig.TOWERS[k]["cost"]]])
	for sid: String in GameConfig.SPELL_ORDER:
		specs.append(["spell_" + sid, GameConfig.SPELLS[sid]["name"]])
	specs.append(["sell", "Sell\ntower"])
	specs.append(["night", "Start night"])
	specs.append(["restart", "New run"])
	specs.append(["speed", "Speed x1"])
	var w := 0.14
	var gap := 0.016
	var slots := GameConfig.TOWER_ORDER.size() + 2  # the towers, Sell, then Start night (or New run, or the speed sign)
	var x0 := -(slots * w + (slots - 1) * gap) / 2.0 + w / 2.0
	for i in specs.size():
		var id: String = specs[i][0]
		# a small sign leaning back toward the player, in front of the island's south edge
		var node := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, 0.065, 0.008)
		node.mesh = bm
		var mat := ModelUtil.flat_material(Color8(0xC8, 0x8A, 0x4E))
		node.material_override = mat
		# New run (after the run) and the speed sign (during a night) take Start night's place
		var slot := slots - 1 if id == "restart" or id == "speed" or id == "night" else i
		if id.begins_with("spell_"):
			slot = GameConfig.SPELL_ORDER.find(id.substr(6))  # the spells use the tower signs' places at night
		elif id == "sell":
			slot = GameConfig.TOWER_ORDER.size()
		node.position = Vector3(x0 + slot * (w + gap), 0.0, HALF + 0.045)
		node.rotation_degrees.x = -50
		ui.add_child(node)
		var label := Label3D.new()
		label.text = specs[i][1]
		label.font_size = 48
		label.pixel_size = 0.00042
		label.outline_size = 8
		label.modulate = Color8(0x2A, 0x1E, 0x16)
		label.outline_modulate = Color8(0xFF, 0xF1, 0xDA)
		label.position = Vector3(0, 0, 0.0045)
		node.add_child(label)
		_buttons[id] = {"node": node, "mat": mat, "label": label, "hover": false, "box": AABB(-bm.size / 2.0, bm.size)}
	for i in range(3):
		# a card stands over the board, leaning back toward the player; filled in when offered
		var node := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.27, 0.01)
		node.mesh = bm
		var mat := ModelUtil.flat_material(Color8(0xE6, 0xD8, 0xBC))
		node.material_override = mat
		node.position = Vector3((i - 1) * 0.33, 0.22, 0.05)
		node.rotation_degrees.x = -35
		ui.add_child(node)
		var label := Label3D.new()
		label.font_size = 34
		label.pixel_size = 0.00045
		label.outline_size = 8
		label.width = 600.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color8(0x2A, 0x1E, 0x16)
		label.outline_modulate = Color8(0xFF, 0xF1, 0xDA)
		label.position = Vector3(0, 0, 0.0056)
		node.add_child(label)
		_buttons["card%d" % i] = {"node": node, "mat": mat, "label": label, "hover": false, "box": AABB(-bm.size / 2.0, bm.size)}
	var hg = load("res://assets/vfx/ew_vfx_rewind_hourglass_v01.glb")
	if hg:
		_hourglass = hg.instantiate()
		_hourglass.scale = Vector3.ONE * 2.0
		_hourglass.visible = false
		ui.add_child(_hourglass)
	_build_close_signs(ui)
	_build_spell_tokens(ui, x0, w, gap)
	_hud = _make_label(ui, Vector3(0, 0.24, -HALF - 0.03), 80)
	_msg = _make_label(ui, Vector3(0, 0.195, -HALF - 0.03), 56)


func _build_spell_tokens(ui: Node3D, x0: float, w: float, gap: float) -> void:
	## One small object per spell on the table in front of the signs (night only): pinch it in VR to cast.
	for i in GameConfig.SPELL_ORDER.size():
		var id: String = GameConfig.SPELL_ORDER[i]
		var t := Spells.make_token(id)
		t.position = Vector3(x0 + i * (w + gap), 0.03, HALF + 0.115)
		t.visible = false
		t.set_meta("home", t.position)
		ui.add_child(t)
		spells.tokens[id] = t


func _build_close_signs(ui: Node3D) -> void:
	## Foresight top tier: one sign inside each forest gap, "Close this path tonight". Shown only while the lens
	## is up at the top tier and no gap has been closed tonight.
	for spawn in GameConfig.SPAWNS:
		var gap: Array = GameConfig.SPAWNS[spawn]
		var centre := (NavGrid.cell_centre(gap[0]) + NavGrid.cell_centre(gap[gap.size() - 1])) / 2.0
		var inward := (-centre * Vector3(1, 0, 1)).normalized()
		var node := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.15, 0.065, 0.006)
		node.mesh = bm
		var mat := ModelUtil.flat_material(GameConfig.FORESIGHT_COLOUR.darkened(0.35))
		node.material_override = mat
		node.position = centre + inward * 3.0 * GameConfig.CELL + Vector3(0, 0.035, 0)
		node.basis = Basis.looking_at(Vector3(0, 0, HALF + 0.3) - node.position * Vector3(1, 0, 1), Vector3.UP, true)
		ui.add_child(node)
		var label := Label3D.new()
		label.text = "Close this\npath tonight"
		label.font_size = 56
		label.pixel_size = 0.0004
		label.outline_size = 8
		label.modulate = Color8(0xEA, 0xFA, 0xFF)
		label.outline_modulate = Color8(0x10, 0x2A, 0x3A)
		label.position = Vector3(0, 0, 0.0035)
		node.add_child(label)
		_buttons["close_" + spawn] = {"node": node, "mat": mat, "label": label, "hover": false, "box": AABB(-bm.size / 2.0, bm.size)}


func foresight_signs(_on: bool) -> void:
	_refresh_buttons()


func _build_lens() -> void:
	## The Crystal Lens rests on the table's right corner, past the signs (stand-in for "belt side").
	var res = load(GameConfig.LENS_SCENE)
	if res == null:
		return
	_lens = res.instantiate()
	board.add_child(_lens)
	_lens_rest = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0 + 0.35) * Basis(Vector3.UP, 0.5), Vector3(HALF - 0.08, 0.012, HALF + 0.07))
	_lens.transform = _lens_rest
	for n in ModelUtil.walk(_lens):
		if n is Marker3D and str(n.name).ends_with("grip_anchor"):
			_lens_grip = ModelUtil.xform_to(n, _lens).origin


func lens_grip_position() -> Vector3:
	return _lens.global_transform * _lens_grip if _lens else Vector3.INF


func hand_pressed(h: GameHand) -> void:
	## A pinch or grasp near the lens grip, a request prop or a spell token picks it up; anywhere else (or while a
	## tower, Sell or a spell is armed) it presses what the ray points at.
	if not placing():
		if _lens and _lens_hand == null and h.global_position.distance_to(lens_grip_position()) <= reach(GameConfig.LENS_GRAB_REACH):
			_lens_hand = h
			return
		if grab_request(request_near(h.global_position), h):
			return
		var tok := spells.token_near(h.global_position) if phase == Phase.NIGHT and _held_spell == "" else ""
		if tok != "" and spells.is_ready(tok):
			_held_spell = tok
			_held_spell_hand = h
			return
	_active_hand = h
	_press(h.ray_origin(), h.ray_dir())


func hand_released(h: GameHand) -> void:
	if _held_spell != "" and _held_spell_hand == h:
		var id := _held_spell
		var local := board.to_local(h.global_position)
		_held_spell = ""
		_held_spell_hand = null
		spells.hide_aim()
		spells.tokens[id].position = spells.tokens[id].get_meta("home")
		if absf(local.x) <= HALF and absf(local.z) <= HALF:
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			cast_spell(id, local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
		return
	if _held_req and _held_req_hand == h:
		release_request()
		return
	if h == _lens_hand:
		_lens_hand = null
		_lens.transform = _lens_rest
		set_lens(false)


func _update_lens() -> void:
	if _lens == null:
		return
	if _lens_hand:
		# the grip in the hand, the glass standing up out of the fist
		var xf := _lens_hand.global_transform * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3.ZERO)
		_lens.global_transform = xf * Transform3D(Basis.IDENTITY, -_lens_grip)
		var up := _lens.global_position.y > board.global_position.y + GameConfig.LENS_RAISE
		if up and _xr_cam:
			set_lens(true, _xr_cam.global_position, -_xr_cam.global_transform.basis.z)
		elif up:
			set_lens(true)  # desktop: every gap
		else:
			set_lens(false)
	elif not _xr:
		var held := Input.is_key_pressed(KEY_L) and phase == Phase.DAY
		_lens.transform = _lens_rest.translated(Vector3(0, 0.12, -0.03)) if held else _lens_rest
		set_lens(held)


func set_lens(up: bool, eye := Vector3.INF, look := Vector3.ZERO) -> void:
	## Looking through the lens (or not). Only during the day; gaze-aimed when an eye and look are given.
	if up and phase == Phase.DAY:
		if not foresight.showing:
			foresight.tier = foresight_tier()
			foresight.refresh()
		foresight.show_seen(eye, look)
	elif foresight.showing:
		foresight.hide_all()
	else:
		return
	_refresh_buttons()


func _make_label(parent: Node3D, pos: Vector3, size: int) -> Label3D:
	var l := Label3D.new()
	l.font_size = size
	l.pixel_size = 0.0005
	l.outline_size = 10
	l.modulate = Color8(0xFF, 0xF1, 0xDA)
	l.outline_modulate = Color8(0x2A, 0x1E, 0x16)
	l.position = pos
	l.rotation_degrees.x = -20  # tipped toward the seated player's eyes
	l.no_depth_test = true  # always readable over the forest
	l.render_priority = 10
	parent.add_child(l)
	return l


func _refresh_ui() -> void:
	_refresh_hud()
	_refresh_buttons()


func _refresh_hud() -> void:
	if _hud == null:
		return
	var phase_name: String = ["Day", "Night", "Cards", "Run over"][phase]
	var n := "Boss night" if night == GameConfig.BOSS_NIGHT else "%s %d" % [phase_name, night + 1]
	if phase == Phase.CARDS or phase == Phase.DONE:
		n = phase_name
	var t := "Loop %d   |   %s   |   Trust %d   |   Houses %d/%d" % [loop + 1, n, trust, standing_houses().size(), houses.size()]
	if phase == Phase.DAY:
		t += "   |   Foresight %d" % foresight_tier()
		if closed_spawn != "":
			t += " (%s closed)" % closed_spawn
	if phase == Phase.NIGHT:
		t += "   |   Enemies %d" % (enemies.size() + _spawn_queue.size())
		if warden:
			t += "   |   Warden phase %d" % warden.phase
	if speed > 2.0:
		t += "   |   DEBUG x%d" % int(speed)
	elif speed > 1.0:
		t += "   |   x2"
	_hud.text = t
	_msg.text = last_message


func _refresh_buttons() -> void:
	for id in _buttons:
		var b: Dictionary = _buttons[id]
		var day := phase == Phase.DAY
		var c := Color8(0xC8, 0x8A, 0x4E)
		match id:
			"night":
				b["node"].visible = day
				c = Color8(0x5E, 0x4A, 0x7A) if day else c
			"restart":
				b["node"].visible = phase == Phase.DONE
			"speed":
				b["node"].visible = phase == Phase.NIGHT
				b["label"].text = "Speed x2" if speed == 2.0 else "Speed x1"
				c = Color8(0xF0, 0xB0, 0x4A) if speed == 2.0 else c
			"spell_fire_orb", "spell_boulder", "spell_storm", "spell_rage", "spell_roots":
				var sid: String = id.substr(6)
				b["node"].visible = phase == Phase.NIGHT
				var cd: float = spells.cooldown.get(sid, 0.0)
				b["label"].text = "%s\n%s" % [GameConfig.SPELLS[sid]["name"], "ready" if cd <= 0.0 else "%d s" % ceili(cd)]
				c = Color8(0x8A, 0x84, 0x7C) if cd > 0.0 else Color8(0xC8, 0x8A, 0x4E)
				if spell_sel == sid:
					c = Color8(0xF0, 0xB0, 0x4A)
				if spells.tokens.has(sid):
					spells.tokens[sid].visible = phase == Phase.NIGHT and cd <= 0.0
			"sell":
				b["node"].visible = day
				if not day or towers.is_empty():
					c = Color8(0x8A, 0x84, 0x7C)
				elif selected == "sell":
					c = Color8(0xF0, 0xB0, 0x4A)
			"close_north", "close_east", "close_west":
				b["node"].visible = day and foresight.showing and foresight_tier() >= GameConfig.FORESIGHT_TIERS \
					and closed_spawn == "" and id.substr(6) in foresight.seen_spawns()
				c = GameConfig.FORESIGHT_COLOUR.darkened(0.35)
			"card0", "card1", "card2":
				var i := int(id.substr(4))
				b["node"].visible = phase == Phase.CARDS and i < offers.size()
				if b["node"].visible:
					var o: Dictionary = offers[i]
					var hint := "[ keep ]" if offers.size() == 1 else "[ %d ]" % (i + 1)
					b["label"].text = Cards.describe(o["id"], o["rarity"]) + "\n\n" + hint
					c = [Color8(0xE6, 0xD8, 0xBC), Color8(0xF0, 0xA4, 0x50), Color8(0xE0, 0x50, 0x3A)][o["rarity"]]
			_:
				b["node"].visible = day
				var cfg: Dictionary = GameConfig.TOWERS[id]
				b["label"].text = "%s\n%d/%d placed" % [cfg["name"], cfg["max"], cfg["max"]] if at_max(id) \
					else "%s\n%d trust" % [cfg["name"], cfg["cost"]]
				if not day or trust < GameConfig.TOWERS[id]["cost"] or at_max(id):
					c = Color8(0x8A, 0x84, 0x7C)
				elif selected == id:
					c = Color8(0xF0, 0xB0, 0x4A)
		if b["hover"]:
			c = c.lightened(0.25)
		b["mat"].albedo_color = c


# ---------------------------------------------------------------- world, light, rig

func _build_lights() -> void:
	lighting = Lighting.new()
	lighting.name = "Lighting"
	add_child(lighting)
	# metres from the eye to the board's near edge: the fog starts past the board centre and tints the forest ring
	lighting.build(0.52 if _xr else 1.12)


func _set_light(p: int) -> void:
	## Dawn eases into day at the start of a build day; dusk eases into night as the night begins.
	if lighting == null:
		return
	match p:
		Phase.DAY:
			lighting.play("dawn", "day", Lighting.DAWN_HOLD)
		Phase.NIGHT:
			lighting.play("dusk", "night", Lighting.DUSK_HOLD)
		_:
			lighting.set_mood("day")


func _build_vignette() -> void:
	## Desktop only: a soft dark edge round the screen. In the headset it would darken the real room (passthrough).
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/vignette.gdshader")
	rect.material = m
	layer.add_child(rect)


func _build_mouse_hand() -> void:
	## The desktop hand (see the header): a tip with a reach bubble, a stem down to the board and a ring where it
	## is above the board, so the height reads from the seat.
	_mouse_hand = GameHand.new()
	_mouse_hand.name = "mouse_hand"
	_mouse_hand.show_ray = false
	_mouse_hand.camera = _camera
	_mouse_hand.pressed.connect(hand_pressed)
	_mouse_hand.released.connect(hand_released)
	add_child(_mouse_hand)
	_mouse_hand.make_bubble(reach(GameConfig.REQUEST_GRAB_REACH))
	_mouse_hand.get_child(0).scale = Vector3.ONE * 1.8  # the tip (GameHand's first child) is small at table distance
	_hand_stem = MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.002, 1.0, 0.002)
	_hand_stem.mesh = sb
	_hand_stem.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF0, 0xC8), true, 0.6)
	_mouse_hand.add_child(_hand_stem)
	_hand_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.009
	tm.outer_radius = 0.012
	_hand_ring.mesh = tm
	_hand_ring.scale.y = 0.3
	_hand_ring.material_override = ModelUtil.flat_material(Color8(0xFF, 0xF0, 0xC8), true, 0.8)
	_mouse_hand.add_child(_hand_ring)


func _update_mouse_hand() -> void:
	## The mouse hand sits where the mouse ray meets a level plane _hand_height above the board.
	if _mouse_hand == null or _camera == null:
		return
	var m := get_viewport().get_mouse_position()
	var plane_y := board.global_position.y + _hand_height
	var hit: Variant = Plane(Vector3.UP, plane_y).intersects_ray(_camera.project_ray_origin(m), _camera.project_ray_normal(m))
	if hit != null:
		_mouse_hand.global_position = hit
	_mouse_hand.visible = true  # an XR controller node can hide itself when it has no tracker
	_hand_stem.scale.y = maxf(_hand_height, 0.001)
	_hand_stem.position.y = -_hand_height / 2.0
	_hand_ring.position.y = -_hand_height + 0.002
	_mouse_hand.set_bubble_hot(grabbable_near(_mouse_hand.global_position))


func _init_xr() -> bool:
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.is_initialized():
		get_viewport().use_xr = true
		print("[game] OpenXR running: hand rays + pinch")
		return true
	print("[game] OpenXR not running: desktop mode (mouse + keys)")
	return false


func _build_rig() -> void:
	if not _xr:
		_camera = Camera3D.new()
		_camera.fov = 50.0
		add_child(_camera)
		# above and behind a seated player's head, so the whole 1.2 m board and the signs fit on screen
		_camera.position = Vector3(0, 1.75, 0.25)
		_camera.rotation_degrees.x = -47.0
		_build_mouse_hand()
		_build_vignette()
		return
	var origin := XROrigin3D.new()
	add_child(origin)
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.2, 0)  # seated eye height
	origin.add_child(cam)
	_xr_cam = cam
	for hand in ["left_hand", "right_hand"]:
		var c := GameHand.new()
		c.tracker = hand
		c.pose = &"aim"
		c.name = hand
		origin.add_child(c)
		c.pressed.connect(hand_pressed)
		c.released.connect(hand_released)
		if easy_reach:
			c.make_bubble(reach(GameConfig.REQUEST_GRAB_REACH))
		_hands.append(c)
	_active_hand = _hands[1]
