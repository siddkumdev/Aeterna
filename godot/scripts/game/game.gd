class_name Game
extends Node3D
## The game loop (spec 6 + 15). Day = spend faith on towers and help villagers (requests, done by hand);
## Night = enemies walk from the forest gaps to the houses; Dawn = income (+5 per standing house, +10 x night
## for clearing it) and +10 HP for each house (damage carries over). A loop is 5 nights + a boss night
## (the 3-phase Warden). Beating the boss offers 3 ability cards (keep 1); losing a night offers 1
## Common card. Either way the hourglass turns: the next loop starts, harder, with faith, towers and damage
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
signal tower_placed(kind: String, at: Vector3)

enum Phase { DAY, NIGHT, CARDS, DONE }

# Table height; the 1.2 m board's near edge sits 0.25 m in front of a seated player
const SELL_RING_Y := 0.024  # just above the grass tufts: it stays depth-tested, so the tower hides its back half
const TRAY_SUBTITLE_WIDTH := 620.0  # px: two short centred lines instead of a view-wide nightfall sentence
const TOAST_POS := Vector3(0, 0.165, -0.028)  # clear above the tilted tray cards from both seated and elevated angles
const TOAST_LINE_STEP := 0.024  # m per wrapped line when anchored at bottom
const TOAST_STACK_GAP := 0.018  # m extra clear space between stacked toasts
const TOAST_STACK_STEP := TOAST_LINE_STEP + TOAST_STACK_GAP  # minimum vertical step between 1-line toasts
const TOAST_CHARS_PER_LINE := 24.0
const TOAST_STACK_MAX := 3
const TOAST_HOLD := 3.2
const BOARD_POS := Vector3(0, 0.75, -0.85)
const SPELL_SOUNDS := {"fire_orb": "orb_launch", "boulder": "boulder_fall", "storm": "storm_cloud", "rage": "rage_cast", "roots": "ward_cast"}
const RARITY_SOUNDS := ["rarity_common", "rarity_rare", "rarity_legendary"]
const HALF := GameConfig.SIZE * GameConfig.CELL / 2.0
const MAX_TICK := 0.05  # fast speeds run several small steps a frame, so nothing skips past a target
const XR_FOVEATION_LEVEL := 0  # off: level 1 and 2 both broke the view on the Quest (the user, 2026-11-17 and 2026-11-18); do not turn on

## false = no camera, hands or input (headless tests build the game without them)
var with_rig := true
## the villagers and forest watchers (always with the rig; the tests can ask for them without one)
var with_life := false
var life: VillageLife
var island_workers: IslandWorkers  # the villagers on the planks under the island (with the rig only)
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
var kill_sparks: KillSparks  # a spark flies from each kill to the nearest house (looks only; with the rig only)
var faith := GameConfig.START_FAITH
var night := 0  # 0-based, within the loop; fall_night() is the last (unwinnable) night
var loop := 0  # 0-based; loops are endless (no cap), see GameConfig.loop_nights
var loop_nights := GameConfig.FIRST_LOOP_NIGHTS  # nights in this loop, rolled when it starts (Siddharth 2026-11-17)
var carried_total := 0  # Faith carried over at every rewind so far this run (the ledger shows it; gates ending B)
var _carry_in := 0  # what the last rewind carries into the loop being started
var last_carry := 0  # the carry of the latest rewind (message / ledger)
var cards := {}  # ability cards held: id -> rarity (0 Common, 1 Rare, 2 Legendary); kept through the loop
var offers: Array[Dictionary] = []  # cards on the table during Phase.CARDS
var ending_choice := false  # Phase.CARDS holds the two endings (let_go / remember), not ability cards
var loop_won := false  # how the current loop ended (beat the boss, or lost a night)
var phase := Phase.DAY
var night_time := 0.0
var selected := ""  # tower kind being placed, "" = none
var speed := 1.0  # 1 or 2 for the player (2026-10-22, Siddharth); 5 and 10 are debug only
var last_message := "":
	set(v):
		last_message = v
		_msg_serial += 1
var _msg_serial := 0

var foresight: Foresight
var spells: Spells
var spell_sel := ""  # the spell armed with a sign or key, waiting for a click on the board
var spell_height := GameConfig.SPELLS["boulder"]["default_height"]  # the Boulder's drop height (cells) for mouse casts
var _held_spell := ""  # VR: the spell token in a hand
var _held_spell_hand: GameHand
var requests: Array[HelpRequest] = []
var _requests_root: Node3D
var _perf_log_t := 0.0
var _palm_log_t := 0.0
var _fast_pending := {}  # hand -> seconds it has held a pinch on the tray hourglass
var _clock: Label3D  # the big countdown over the island
var _rim_pending := {}  # hand -> seconds it has held a pinch on the rim; the island only moves after GameConfig.RIM_HOLD (the user: it moved by itself)
var _rim_hands: Array = []  # the hands pinching the table rim (move, turn, resize the island)
var _rim_start := Transform3D.IDENTITY  # the board when the current grip began
var _rim_p0: Array[Vector3] = []  # where each gripping hand was then
var _rim_handles: Array[MeshInstance3D] = []  # visible edge handles for Lazy-Susan board movement
var settle_ms := 2500  # (tests set 0)
var _settle_until := 0  # msec: right after the board and tray are placed, grabbing the tray or rim and zooming are ignored, so a stray pinch cannot drag them away (the user, 2026-11-18)
var _board_placed := false  # seated XR auto-centering done once per wake / start
var ledger: Ledger  # the stat screens (scripts/ui/ledger.gd): left palm up in the headset, L on the desktop
var _ledger_latched := false  # opened by a button or key: stays until closed the same way
var _palm_time := 0.0  # how long the left palm has been turned up
var _palm_close_time := 0.0  # how long a tracking blink / low palm angle has persisted while open
var _palm: XRController3D  # the left hand's grip pose: its +X is the palm's normal (fallback when no joints)
var _left_hand_tracker: XRHandTracker
var _left_tracker_hooked := false
var _xr_origin: XROrigin3D
static var ask_for_quests := true  # a quest waits for the player to tap its asker (the user, 2026-11-18); the self-test turns it off for the old request checks
var quest_cap := 99  # the tutorial holds the day's quests back (it posts its own) until it is over
var quest_plan: Array = []  # today's quests not posted yet: [{"kind", "house"}]
var _quest_deck: Array = []  # the kinds still to come round before the deck is reshuffled
var _quest_rng := RandomNumberGenerator.new()
var _held_req: HelpRequest  # the request prop being moved
var _held_req_hand: GameHand  # the hand holding it, or null for the mouse
var closed_spawn := ""  # Foresight tier 3 rewrite: the gap closed for the coming night

var press_override := Callable()  # the title screen takes presses first: func(world_pos, ray_origin, ray_dir) -> bool (true = used)
var asleep := false:  # the title screen shows the island asleep: no cards, signs or HUD, no pressing
	set(v):
		asleep = v
		var ui := board.get_node_or_null("UI") if board else null
		if ui:
			ui.visible = not v
		if _tray:
			_tray.visible = not v
		if v:
			_tray_hand = null
		if _lens:
			_lens.visible = not v  # the lens lies on the table only once the game is awake
var veil: VeilDome  # the warm dome over the island: cracks at dusk, shatters in the night, knits at dawn (with the rig only)
var haze: HazeDome  # the dim warm haze over the passthrough room (with the rig only)
var _doom_started := false  # night 5 of loops 1-4: the Warden's horn has sounded
var _doom_timer := 0.0
var _ui_placed := false  # the tray has been put beside the player for this session
var _ui_rig: Node3D  # headset: the cards, buttons and messages float here, in front of you (follows your head)
var _ui_yaw := 0.0
var _tray_placed := false  # the tray has been put at its start pose (once per app start; the player's spot is kept after that)
var _tray_hand: GameHand  # the hand moving the tray
var _tray_off := Vector3.ZERO  # tray origin minus the hand's touch point when it was grabbed
var _tray_start := Transform3D.IDENTITY
var _tray_hand_yaw0 := 0.0  # the holding hand's yaw at the grab: turning the hand turns the tray (like the island)
var _zoom_hands: Array[GameHand] = []  # both hands pinched close together in empty air, then spread: the table comes closer
var _zoom_d0 := 0.0
var _board_home := Vector3.ZERO  # where the table was placed (wake / recenter): closing both hands in a zoom returns it here
var _board_home_set := false
var _zoom_start := Transform3D.IDENTITY
var _zoom_head := Vector3.ZERO  # eye at zoom start: the push/pull direction stays fixed while the head moves
var _zoom_d := 0.0  # smoothed hand spread
var _free_pinch: Array[GameHand] = []  # hands whose current pinch landed on nothing in particular
var _tray: CardTray  # the physical cards (with the rig only): towers by day, spells at night, ability offers after a loop
var _tray_key := ""  # what the tray shows now, so it is rebuilt only when that changes
var _held_card: Card3D  # the tower card in a hand (or on the mouse hand)
var _held_card_hand: GameHand
var _held_spell_cards := {}  # GameHand -> Card3D; one independent spell card per hand
var _lens: Node3D  # the Crystal Lens model (spec 13)
var _lens_rest := Transform3D.IDENTITY  # where it lies when nobody holds it (board-local)
var _lens_grip := Vector3.ZERO  # the grip anchor in the lens model's own space
var _lens_centre := Vector3.ZERO  # the middle of the glass, in the lens model's own space
var _lens_view: LensView  # the window on the glass (headset only)
var _lens_hand: GameHand  # the hand holding it, or null
var _xr_cam: XRCamera3D
var easy_reach := false  # desktop and simulator: grab distances x GameConfig.EASY_REACH and the reach bubbles show
var _mouse_hand: GameHand  # desktop only
var _mouse_rim := false  # desktop: the left button is down on a rim handle, the table turns with the mouse
var _mouse_rim_x0 := 0.0
var _mouse_rim_yaw0 := 0.0
const MOUSE_RIM_RAD_PER_PX := 0.006  # table yaw per pixel of horizontal mouse drag (Siddharth 2026-11-16: smooth drag, no 25 degree jump)
var _hand_height := 0.03  # m above the board: set with the mouse wheel
var _hand_stem: MeshInstance3D
var _hand_ring: MeshInstance3D
var _patches: Array = []  # burning ground (Hot Coals Legendary): {"pos", "r", "dps", "left"}
var _held_tonight := false  # Sturdy Homes Legendary: one house held at 1 HP per night
var _hourglass: Node3D
var _rewind_tween: Tween  # the hourglass animation of the latest rewind (killed by new_run)
var _rewind_serial := 0  # bumped by new_run so a pending rewind-words timer from the old run does nothing
var day_time := 0.0  # seconds of this day gone (the day ends by itself at GameConfig.DAY_LENGTH)
var day_fast := false  # the tray hourglass, by day: the day runs GameConfig.DAY_FAST times as fast
var day_clock := true  # the day only runs out in a played game (with the rig, awake)
var _sun: MeshInstance3D  # travels its arc over the island through the day
var _dusk_warned := false
var _fast_glass: Node3D  # the small hourglass on the tray: pinch = fast
var _fast_label: Label3D
var _faith_seal: Node3D  # the wax seal at the tray's corner, with the faith on it
var _faith_label: Label3D
var _board_compass: Node3D  # carved scale / recenter compass on the tray's left wing
var _compass_label: Label3D
var _compass_scale := -1.0
var _compass_pending := {}  # hand -> seconds held on the compass (tap cycles scale, hold recenters)
var _toast: Label3D  # newest short message line above the tray
var _toast_stack: Array[Label3D] = []  # older still-visible toasts stacked above _toast
var _toast_last := ""
const QuestSlipScript := preload("res://scripts/ui/quest_slip.gd")
var _slip: QuestSlipScript  # the pinned quest slip on the tray's front lip (active quest, next step, progress)
var _slip_t := 0.0
const HUD_GAP := 0.08  # m (board scale 1) between the table's far edge and the day clock / tutorial text
const DAY_CLOCK_POS := Vector3(0, 0.42, 0)  # local to the HUD root (see update_hud_root)
var hud_root: Node3D  # day clock + tutorial text: follows the table's position, never its turn (Siddharth 2026-11-16)
const LEDGER_INWARD_SHIFT := 0.14
const SELL_TOWER_HINT := "Pinch and hold a tower to return it for faith."
const TUTORIAL_SHADE_REWARD := 15
var tutorial_hold := false  # the tutorial is teaching by day: the day clock stands still until it is over (the user, 2026-11-18)
var tutorial_spotlight := ""  # "", "cards", "rim", "board", "lens", "tray", "zoom", "ledger", "hourglass", "spells"
var run_serial := 0
var _sell_hint_shown := false
var quit_requested := false
var _hud_toast_serial := 0
var _grass_pushers: Array = []  # pre-allocated per-frame grass pusher buffer
var _crush := {}  # selling by hand: {"tower", "hand", "t", "at"} while a built tower is pinched and held
var warden: Warden  # the boss's phases, while the Warden is alive (null otherwise)
var _spawn_queue: Array = []  # [{"t": s, "cell": Vector2i, "kind": String}], sorted by time
var _rng := RandomNumberGenerator.new()  # seeded per night: cluster sizes, gap cells, walking offsets
var _towers_root: Node3D
var _enemies_root: Node3D
var _grid_lines: MeshInstance3D
var _ghost: Node3D
var _ghost_plate: MeshInstance3D
var _ghost_models := {}
var _ghost_mat: StandardMaterial3D
var _sell_mat: StandardMaterial3D  # the solid red on the tower about to be sold
var _sell_ring: MeshInstance3D  # the bright ring round it
var _sell_target: Tower
var _ghost_ring: MeshInstance3D
var _hover_cell := Vector2i(-1, -1)
var _hover_board_cell := Vector2i(-1, -1)  # the single cell under the pointer (for selling)
var _buttons := {}  # id -> {"node", "mat", "label", "box": AABB (board-local)}
var _hud: Label3D
var _msg: Label3D
var lighting: Lighting  # the four moods, tonemap, bloom and fog (scripts/vfx/lighting.gd)
var _camera: Camera3D
var _hands: Array[GameHand] = []
var recorder: InputRecorder  # VR runs only: head + hands + buttons to user://rec (GameConfig.RECORD_INPUT)
var _active_hand: GameHand
var _xr := false
var log_sounds := false  # tests: record every sound asked for (headless has no audio rig)
var sound_log: Array = []
var audio: AudioBank  # sounds; only made with the rig (headless tests stay silent)
var music: Node  # MusicDirector (scripts/audio/music_director.gd): background loops that follow dusk and dawn


func _ready() -> void:
	UiFonts.install()
	if with_rig:
		_xr = _init_xr()
		easy_reach = not _xr or OS.get_environment("AETERNA_EASY_REACH") == "1"
	_build_lights()
	board = Node3D.new()
	board.name = "Board"
	board.position = BOARD_POS
	add_child(board)
	WorldBuilder.build_island(board)
	var under := WorldBuilder.build_underside(board)
	if with_rig:
		island_workers = IslandWorkers.new()
		island_workers.name = "IslandWorkers"
		board.add_child(island_workers)
		island_workers.setup(under)
	WorldBuilder.build_forest(board, 7)
	_rim_handles = WorldBuilder.build_rim_handles(board)
	_grid_lines = WorldBuilder.build_grid_lines(board)
	_towers_root = _child(board, "Towers")
	_enemies_root = _child(board, "Enemies")
	shots_root = _child(board, "Shots")
	if with_rig:
		kill_sparks = KillSparks.new()
		kill_sparks.game = self
		shots_root.add_child(kill_sparks)
	_build_houses()
	var dressing := VillageDresser.build(board, 11)
	decor_cells = dressing["decor"]
	_path_tiles = dressing["tiles"]
	_prop_points = dressing["props"]
	_setup_shrine(dressing["shrine"])
	load("res://scripts/vfx/fake_bloom.gd").attach(self)  # Quest tiers only: cheap halos instead of the bloom (builds itself when PerfTier is not DESKTOP)
	_build_ghost()
	spells = Spells.new()
	spells.name = "Spells"
	spells.game = self
	board.add_child(spells)
	foresight = Foresight.new()
	foresight.name = "Foresight"
	foresight.game = self
	if with_rig and _xr:
		foresight.overlay_layers = LensView.OVERLAY_LAYER  # drawn only through the lens window
	board.add_child(foresight)
	_requests_root = _child(board, "Requests")
	_build_ui()
	_build_lens()
	if with_rig:
		audio = AudioBank.new()
		audio.name = "Audio"
		add_child(audio)
		audio.setup()
		music = load("res://scripts/audio/music_director.gd").attach(self)  # day music, fades out at dusk for the night bed, back in at dawn
		_build_rig()
		if _xr:
			_mount_ui_rig()
		haze = HazeDome.new()
		haze.name = "Haze"
		add_child(haze)
		haze.set_active(lighting.enable_passthrough())  # false on the desktop and in the simulator: nothing changes there
		if _xr or PerfTier.forced():
			PerfTier.apply(get_viewport(), lighting.env, lighting.sun, XRServer.find_interface("OpenXR"))
		veil = VeilDome.new()
		veil.name = "Veil"
		board.add_child(veil)
	if with_rig or with_life:
		life = VillageLife.new()
		life.name = "VillageLife"
		board.add_child(life)
		life.setup(self, dressing["landmarks"])
	new_run(run_seed)


func _child(parent: Node, n: String) -> Node3D:
	var c := Node3D.new()
	c.name = n
	parent.add_child(c)
	return c


# ---------------------------------------------------------------- run, phases

func new_run(rng_seed: int) -> void:
	run_serial += 1
	run_seed = rng_seed
	_quest_deck.clear()  # a new run deals its quests from a fresh deck
	loop = 0
	carried_total = 0
	_carry_in = 0
	last_carry = 0
	_cutscene = false
	_cutscene_glass_wait = false
	_stop_cutscene_score(0.0)
	_kill_statue_tweens()
	cutscene_count = 0
	_dawn_pending = ""
	if is_instance_valid(_cutscene_skotos):
		_cutscene_skotos.queue_free()
	_cutscene_skotos = null
	cards = {}
	offers = []
	ending_choice = false  # a restart during the ending offer must not turn the next card offer into an ending
	speed = 1.0
	_rewind_serial += 1  # the last run's pending rewind words are stale
	if _rewind_tween and _rewind_tween.is_valid():
		_rewind_tween.kill()  # no old hourglass animation in the new run
	if _hourglass:
		_hourglass.visible = false
	_toast_last = ""
	_hud_toast_serial = _msg_serial
	_sell_hint_shown = false
	quit_requested = false
	_set_toast_alpha(_toast, 0.0)
	if _toast:
		_toast.text = ""
		_toast.set_meta("left", 0.0)
	for l in _toast_stack:
		l.text = ""
		l.set_meta("left", 0.0)
		_set_toast_alpha(l, 0.0)
	_start_loop("Day 1. Build before the sun sets.")


func _start_loop(message: String, prayer_delay := 0.0) -> void:
	## Everything the time loop resets (spec 15): night counter, faith, towers, village damage.
	set_tutorial_spotlight("")
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
	var dark := 0
	for h in houses:
		h.max_hp = GameConfig.HOUSE_HP * (1.0 + (Cards.value("sturdy_homes", sturdy) / 100.0 if sturdy >= 0 else 0.0))
		if with_rig and h.is_shuttered and is_inside_tree():
			dark += 1
			var i := houses.find(h)
			get_tree().create_timer(0.5 + 0.45 * (houses.size() - 1 - i)).timeout.connect(func():  # the rewind: windows light again, last house first
				if is_instance_valid(h):
					h.repair())
		else:
			h.repair()
	var pockets := card("deep_pockets")
	faith = GameConfig.START_FAITH + (int(Cards.value("deep_pockets", pockets)) if pockets >= 0 else 0) + _carry_in
	_carry_in = 0
	loop_nights = GameConfig.loop_nights(run_seed, loop)  # rolled once, at the start of each loop
	night = 0
	closed_spawn = ""
	_helped = 0
	_set_phase(Phase.DAY, message)
	_update_shrine()
	select("")  # a new run starts with nothing picked: no sell ring left on the empty ground
	if with_rig:
		if prayer_delay > 0.0 and is_inside_tree():  # after a rewind: once the hourglass is gone, never over it
			var serial := _rewind_serial
			get_tree().create_timer(prayer_delay).timeout.connect(func():
				if serial == _rewind_serial:
					say_at_shrine(StoryText.prayer(loop, 0)))
		else:
			say_at_shrine(StoryText.prayer(loop, 0))  # Maren's first prayer of the loop


func card(id: String) -> int:
	## Rarity of a held card, or -1 when it is not held.
	return cards.get(id, -1)


func snd(id: String, at := Vector3.INF) -> void:
	## Plays a sound by name (see AudioBank); does nothing without the rig.
	if log_sounds:
		sound_log.append(id)
	if audio:
		audio.play(id, at)


func snd_loop(id: String, follow: Node3D) -> Node:
	## A looping sound on a node (the Storm Cloud's rain); returns a handle for snd_loop_stop (null without the rig).
	if log_sounds:
		sound_log.append(id + ":start")
	if audio:
		return audio.loop_start(id, follow)
	return null


func snd_loop_stop(id: String, handle: Node) -> void:
	if log_sounds:
		sound_log.append(id + ":stop")
	if audio and handle != null:
		audio.loop_stop(handle)


# Ambience one-shots (AudioBank.set_scatter; no beds since 2026-11-08): day = birds and leaves in the forest ring, a villager
# at work by a house; night = sparser and a little tense: an owl, a creak, something moving in the undergrowth.
const SCATTER_DAY := [
	{"id": "amb_bird", "where": "forest", "w": 5}, {"id": "amb_leaves", "where": "forest", "w": 2},
	{"id": "amb_work", "where": "village", "w": 2},
]
const SCATTER_NIGHT := [
	{"id": "amb_owl", "where": "forest", "w": 1}, {"id": "amb_creak", "where": "forest", "w": 2},
	{"id": "amb_rustle", "where": "forest", "w": 2},
]


func _phase_sound(_was: int, p: int) -> void:
	if audio == null:
		return
	if p == Phase.NIGHT:
		audio.set_scatter(SCATTER_NIGHT, ambience_point, Vector2(4.0, 9.0))
	else:
		audio.set_scatter(SCATTER_DAY, ambience_point, Vector2(2.5, 6.0))
	# No background beds (Siddharth 2026-11-08: he did not like the day and night beds); the scattered one-shots above
	# carry the time of day. The bed files stay in the bank in case they come back.
	audio.set_bed("")
	# No sound at the change of time either (Siddharth 2026-11-08: replace the bells with "Nothing"): dawn_bell and
	# night_fall stay built but are not played; the light change and the UI carry it.


func ambience_point(where: String) -> Vector3:
	## A world position for an ambience one-shot: a random cell of the forest ring (the board's edge), or a standing house.
	if where == "village":
		var up: Array = houses.filter(func(h): return not h.is_shuttered)
		if not up.is_empty():
			var h: Node3D = up[randi() % up.size()]
			return h.global_position + Vector3(0, GameConfig.CELL, 0)
	var n := GameConfig.SIZE
	var i := randi() % n
	var cells := [Vector2i(i, 0), Vector2i(i, n - 1), Vector2i(0, i), Vector2i(n - 1, i)]
	var cell: Vector2i = cells[randi() % 4]
	return board.to_global(NavGrid.cell_centre(cell) + Vector3(0, GameConfig.CELL * 1.5, 0))


func _set_phase(p: int, message: String) -> void:
	var was := phase
	phase = p
	last_message = message
	day_fast = false
	crush_cancel()
	if p == Phase.DAY:
		day_time = 0.0
		_dusk_warned = false
	if p != Phase.NIGHT and speed > 1.0 and speed <= GameConfig.NIGHT_FAST:
		speed = 1.0  # the hourglass is let go when the night ends (debug speeds stay)
	if p != Phase.DAY:
		select("")
	if p != Phase.NIGHT and spells:
		spell_sel = ""
		spells.hide_aim()
	if foresight and foresight.showing:
		set_lens(false)  # the lens only reads the coming night; it goes blank when the day ends
	if _requests_root and p == Phase.DAY:
		_plan_quests()
	elif _requests_root:
		_clear_requests()
	_set_light(p)
	_veil_for(was, p)
	_refresh_ui()
	_phase_sound(was, p)
	phase_changed.emit(p)


func _veil_for(was: int, p: int) -> void:
	## Dusk: a purple crack runs over the Veil, then it shatters. Dawn: it knits back. Rewind or a new run: whole again.
	if veil == null:
		return
	if p == Phase.NIGHT and was != Phase.NIGHT:
		veil.crack(1.6, veil_crack_amount())
		get_tree().create_timer(1.8).timeout.connect(func():
			if is_instance_valid(veil) and phase == Phase.NIGHT:
				veil.shatter())
	elif p == Phase.DAY and was == Phase.NIGHT:
		veil.knit()
		veil.crack_amount = veil_crack_amount()  # the day before a later night already shows a little more crack
	elif p != Phase.NIGHT:
		veil.snap(1.0, veil_crack_amount())


func fall_night() -> int:
	## 0-based index of this loop's last night: the Warden's fall (3rd night in loop 1, 1-8 later, weighted).
	return loop_nights - 1


func is_doomed_night() -> bool:
	## The fall night can never be won, in any loop (see GameConfig.DOOM_AT and docs/STORY.md).
	return night == fall_night()


func veil_crack_amount(n := -1) -> float:
	## Warning sign: the Veil's crack grows a little every night of the loop, never reaches its maximum and does not
	## depend on the fall night (so it cannot give the fall away). Stand-in curve, Siddharth 2026-11-17.
	var i := night if n < 0 else n
	return minf(0.75, 0.1 * i + 0.05)


func _doom_step(delta: float) -> void:
	if not is_doomed_night() or night_time < GameConfig.DOOM_AT:
		return
	if not _doom_started:
		_doom_started = true
		_doom_timer = 0.0
		last_message = "The Warden's horn sounds. The Veil breaks."
		snd("boss_roar")
		_refresh_ui()
		_skotos_says(StoryText.warden("night5", loop))
	_doom_timer += delta
	if _doom_timer >= GameConfig.DOOM_STEP:
		_doom_timer = 0.0
		for h in houses:
			if not h.is_shuttered:
				h.force_dark()  # a house goes dark whatever holds it; the third one ends the night (_on_house_shuttered)
				break


func start_night() -> bool:
	if phase != Phase.DAY:
		return false
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.get_meta("tutorial_shade", false):
			enemies.erase(e)
			e.queue_free()
	night_time = 0.0
	_doom_started = false
	_doom_timer = 0.0
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
	if night == fall_night():
		_set_phase(Phase.NIGHT, "Night %d. The Warden comes." % (night + 1))
		snd("boss_roar")
		_skotos_says(StoryText.warden("night5", loop))
	else:
		_set_phase(Phase.NIGHT, "Night %d. They come from the forest." % (night + 1))
		snd("boss_roar")  # Skotos's horn sounds at EVERY dusk (Siddharth 2026-11-17: a fall-only horn would give it away)
		if night == 0:
			_skotos_says(StoryText.warden("dusk_day1", loop))  # the curse, spoken at the first dusk of each loop
	return true


func night_plan() -> Array[Dictionary]:
	## The coming night's groups (WavePlan), with a Foresight rewrite applied (a closed spawn's groups come
	## from the next edge instead) and, on the boss night, the boss as its own group. What Foresight reveals.
	var plan := WavePlan.groups_for(night, run_seed, loop)
	if maxi(night, mini(loop * 2, GameConfig.ELITE_FROM_NIGHT)) >= GameConfig.ELITE_FROM_NIGHT and night < fall_night():  # later loops: elites even in a short loop
		var es: Array = GameConfig.SPAWNS.keys()
		plan.append({"time": GameConfig.ELITE_DELAY, "spawn": es[(run_seed + loop + night) % es.size()],
			"enemies": [GameConfig.ELITES[(run_seed + loop * 2 + night) % GameConfig.ELITES.size()]]})
	if night == fall_night():
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
	## Where a Tunneler heading for `house` from `p` comes up: 1.9-2.8 cells from the house centre so ground
	## defenses get a fair window; falls back to the adjacent doorstep cells if every outer cell is blocked.
	var h_pt := house_point(house)
	var hc := houses[house].cell
	var outer: Array = []
	for x in range(hc.x - 3, hc.x + GameConfig.TOWER_SIZE.x + 3):
		for y in range(hc.y - 3, hc.y + GameConfig.TOWER_SIZE.y + 3):
			var c := Vector2i(x, y)
			if not nav.astar.is_in_boundsv(c) or nav.astar.is_point_solid(c) or nav.kind.has(c):
				continue
			var cc := NavGrid.cell_centre(c)
			var d_house := Vector2(cc.x - h_pt.x, cc.z - h_pt.z).length() / GameConfig.CELL
			if d_house >= 1.9 and d_house <= 2.8:
				outer.append({"cell": c, "dist": Vector2(cc.x - p.x, cc.z - p.z).length()})
	outer.sort_custom(func(a, b): return a["dist"] < b["dist"])
	for item in outer:
		var c: Vector2i = item["cell"]
		if not nav.route(c, [house]).is_empty():
			return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in nav.goals_of(house):
		var d := Vector2(NavGrid.cell_centre(c).x - p.x, NavGrid.cell_centre(c).z - p.z).length()
		if d < best_d:
			best_d = d
			best = c
	return best


func _plan_quests() -> void:
	## The day's quests (the user, 2026-11-11): at most REQUESTS_PER_DAY, dealt from a shuffled deck of every kind so
	## they cycle, on different standing houses. They are posted one by one as the day goes on (post_next_quest).
	_clear_requests()
	quest_plan.clear()
	_quest_rng.seed = run_seed * 53 + loop * 11 + night
	var where: Array = standing_houses()
	_shuffle(where, _quest_rng)
	var today: Array[String] = []
	if loop == 0 and night == 0:
		today.append("prayer")  # the very first quest is the smallest: Maren's prayer, answered with a tap
		if _quest_deck.is_empty():  # fill the deck first, so the prayer is out of this cycle and nothing repeats in it
			_quest_deck = GameConfig.REQUESTS.keys()
			_shuffle(_quest_deck, _quest_rng)
		_quest_deck.erase("prayer")
	var guard := 0
	while today.size() < GameConfig.REQUESTS_PER_DAY and guard < 64:
		guard += 1
		if _quest_deck.is_empty():
			_quest_deck = GameConfig.REQUESTS.keys()
			_shuffle(_quest_deck, _quest_rng)
		var k: String = _quest_deck.pop_front()
		if today.has(k):
			_quest_deck.append(k)
		else:
			today.append(k)
	for i in mini(today.size(), where.size()):
		quest_plan.append({"kind": today[i], "house": where[i]})


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t


func post_next_quest() -> HelpRequest:
	## Posts the next planned quest of the day (null when there is none left, or it is not day).
	if phase != Phase.DAY or quest_plan.is_empty() or _requests_root == null:
		return null
	var q: Dictionary = quest_plan.pop_front()
	return _post_quest(q["kind"], q["house"])


func post_all_quests() -> void:
	while post_next_quest() != null:
		pass


func force_quests(kinds: Array) -> void:
	## Tests and shot tools: today's quests are exactly these kinds, posted now.
	_clear_requests()
	quest_plan.clear()
	var where: Array = standing_houses()
	for i in mini(kinds.size(), where.size()):
		_post_quest(kinds[i], where[i])


func _post_quest(kind: String, house: int) -> HelpRequest:
	var r := HelpRequest.new()
	r.game = self
	_requests_root.add_child(r)
	r.setup(kind, house, _lantern_spot(house, _quest_rng) if kind == "lantern" else Vector3.ZERO)
	requests.append(r)
	_refresh_clearings()
	if with_rig and not asleep and (_slip == null or _tray == null or not _tray.visible or phase != Phase.DAY or requests.size() > 1):
		# the first open quest appears on the slip, so it gets no toast too (one message at a time)
		if r.accepted:
			last_message = "New quest: %s" % GameConfig.REQUESTS[kind]["name"]
			_refresh_ui()
		elif requests.size() == 1:  # one line for the whole batch: it says how a quest starts
			last_message = "Villagers are waving: tap one to hear what they need."
			_refresh_ui()
	return r


func quests_posted_by(day_seconds: float) -> int:
	## How many of the day's quests should be out after this much of the day.
	var n := 0
	for f: float in GameConfig.QUEST_TIMES:
		if day_seconds >= f * GameConfig.DAY_LENGTH:
			n += 1
	return n


func _tick_quests(delta: float) -> void:
	## Posts the day's quests as their times come, and runs the ones done without carrying anything:
	## a hand held over a house (warm), a fingertip on a lantern (lights).
	if phase != Phase.DAY or asleep:
		return
	while requests.size() < mini(quests_posted_by(day_time), quest_cap) and not quest_plan.is_empty():
		post_next_quest()
	var points: Array[Vector3] = []
	for h in _hands:
		if not h.is_lost():
			points.append(h.touch_point())  # the drawn fingers in the headset (the node's position otherwise)
	if _mouse_hand:
		points.append(_mouse_hand.global_position)
	var active := active_request()
	for r in requests:
		if r.done:
			continue
		r.tick(delta, r == active)
		if r.kind == "warm":
			if r.warm_step(delta, points.any(func(p): return r.hand_over_house(p))):
				_pay_quest(r)
		elif r.kind == "lights":
			for p in points:
				if r.touch(p, reach(GameConfig.TOUCH_REACH)):
					_pay_quest(r)
					break


func _pay_quest(r: HelpRequest) -> void:
	snd("help_done")
	snd("trust_chime")
	var paid := r.payout()
	faith += paid
	_helped += 1
	_update_shrine()
	if with_rig:
		_faith_sparkle(houses[r.house].global_position + Vector3(0, 0.1, 0))
	last_message = "%s: +%d faith" % [GameConfig.REQUESTS[r.kind]["name"], paid]
	_update_ghost()
	_refresh_ui()


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


func _refresh_clearings() -> void:
	## The grass is cleared round the new quests' scenery and loose items (cosmetic).
	if grass == null:
		return
	var pts: Array[Vector3] = []
	for r in requests:
		if is_instance_valid(r) and not r.is_queued_for_deletion():
			pts.append_array(r.clear_points())
	grass.set_clearings(pts, HelpRequest.CLEAR_RADIUS)


func _clear_requests() -> void:
	_held_req = null
	_held_req_hand = null
	for r in requests:
		r.queue_free()
	requests.clear()
	_refresh_clearings()
	for h in houses:
		h.chimney_blocked = false
	if life:
		life.clear_claims()


func reach(metres: float) -> float:
	## A grab distance, doubled where easy reach is on.
	return metres * (GameConfig.EASY_REACH if easy_reach else 1.0)


func card_reach() -> float:
	## How far a pinch may be from a tray card: wider in the real headset, where the tray floats with your head.
	return GameConfig.XR_CARD_REACH if _xr and not easy_reach else reach(GameConfig.TOUCH_REACH * 1.6)


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
		var d := r.grab_dist(world)
		if not r.done and d <= best_d:
			best_d = d
			best = r
	return best


func grab_request(r: HelpRequest, hand: GameHand = null) -> bool:
	if _cutscene or phase != Phase.DAY or r == null or _held_req != null or not r.grab(hand.global_position if hand else Vector3.INF):
		return false
	_held_req = r
	_held_req_hand = hand
	select("")
	snd("grab")
	return true


func release_request() -> bool:
	## Let go of the held prop; pays the reward when that finished the request.
	if _held_req == null:
		return false
	var r := _held_req
	_held_req = null
	_held_req_hand = null
	if not r.release():
		snd("release")
		return false
	_pay_quest(r)
	return true


func _faith_sparkle(at: Vector3) -> void:
	## Faith earned: a little rise of gold (X08).
	VfxKit.burst(shots_root, at, VfxKit.FIRE_YELLOW, VfxKit.FIRE_ORANGE, 10, 0.05, 0.8, 0.006, 0.06)


func _update_held() -> void:
	for h in _hands:
		if is_instance_valid(h) and h.visual:
			h.visual.holding_card = (_held_card != null and _held_card_hand == h) or _held_spell_cards.has(h) or (_held_spell != "" and _held_spell_hand == h)
	if _held_card and _held_card_hand:
		# The tower card rides in the hand, face toward the eyes, and shows its ghost and range ring on the board.
		var hp := _held_card_hand.touch_point()  # the drawn fingers, so the ghost sits under the pinch
		_held_card.global_position = hp + Vector3(0, 0.05, 0.02)  # a little above the fingers, so the ghost under it stays visible
		_held_card.face_toward(_eye())
		var local := board.to_local(hp)
		var next_cell := Vector2i(-1, -1)
		if absf(local.x) <= HALF and absf(local.z) <= HALF:
			next_cell = NavGrid.local_to_cell(local - Vector3(GameConfig.CELL / 2.0, 0, GameConfig.CELL / 2.0)) \
				.clamp(Vector2i.ZERO, Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))
		if next_cell != _hover_cell:
			_hover_cell = next_cell
			_update_ghost()
	if not _held_spell_cards.is_empty():
		spells.hide_aim()  # clear a stale ring when both held spells move off the board
	for hand: GameHand in _held_spell_cards:
		var card: Card3D = _held_spell_cards[hand]
		if not is_instance_valid(hand) or not is_instance_valid(card):
			continue
		var hp := hand.touch_point()
		card.global_position = hp + Vector3(0, 0.05, 0.02)
		card.face_toward(_eye())
		var local := board.to_local(hp)
		if absf(local.x) <= HALF and absf(local.z) <= HALF:
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			spells.show_aim(card.data["id"], local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
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
		snd("invalid")
		last_message = "%s is still cooling down (%d s)." % [GameConfig.SPELLS[id]["name"], ceili(spells.cooldown[id])]
		_refresh_ui()
		return false
	var ok := spells.cast(id, pos, spell_height if height < 0.0 else height)
	if ok:
		snd(SPELL_SOUNDS.get(id, ""), board.to_global(pos))
		last_message = "%s!" % GameConfig.SPELLS[id]["name"]
	_refresh_ui()
	return ok


func pick_spell(id: String) -> void:
	## Arms a spell (or puts it down again); only at night.
	if phase != Phase.NIGHT or not GameConfig.SPELLS.has(id):
		return
	spell_sel = "" if spell_sel == id else id
	snd("spell_pick")
	if spell_sel == "":
		spells.hide_aim()
	_refresh_ui()


func _end_night() -> void:
	## The night was cleared: every enemy spawned and defeated with fewer than 3 houses shuttered.
	var standing := standing_houses().size()
	var mult := 1.0 + GameConfig.LOOP_FAITH_STEP * loop
	var income := roundi(float(standing * GameConfig.DAWN_FAITH_PER_HOUSE + GameConfig.NIGHT_CLEAR_FAITH_PER_NIGHT * (night + 1)) * mult)
	if card("deep_pockets") == 2 and standing == houses.size():
		income += 5  # Deep Pockets Legendary: no house shuttered tonight
	faith += income
	for h in houses:
		if with_rig and not h.is_shuttered:
			_faith_sparkle(h.global_position + Vector3(0, 0.1, 0))  # the dawn income, house by house
		h.heal(GameConfig.DAWN_REPAIR)  # damage carries over (Siddharth 2026-10-23)
	for t in towers:
		if t.cfg["kind"] == "spawner":
			t.refill()  # stand-in: the Guards are all back, at full health, by morning
	_clear_night()
	if night == fall_night():
		_end_loop(false)  # the fall is never won (Siddharth 2026-11-17); only reachable if the Warden were gone
		return
	night += 1
	closed_spawn = ""
	var next := "The fall night next." if night == fall_night() else "Day %d." % (night + 1)
	var dawn := "Dawn. %d houses stood: +%d faith. %s" % [standing, income, next]
	if ending_available():
		_offer_ending(dawn)  # from loop 3 on the statue offers an ending each dawn; the player may keep looping
		return
	_begin_day(dawn)


func _begin_day(message: String) -> void:
	_set_phase(Phase.DAY, message)
	if with_rig:
		say_at_shrine(StoryText.prayer(loop, night))  # Maren's dawn prayer for this day


func ending_available() -> bool:
	## The ending choice is offered from loop 3 on (0-based loop 2), at every dawn.
	return loop >= GameConfig.ENDING_FROM_LOOP


func ending_b_open() -> bool:
	## "Remember them" needs the Faith carried across loops to reach the stand-in total; "Let go" is always open.
	return carried_total >= GameConfig.ENDING_B_CARRIED


func _offer_ending(dawn_message: String) -> void:
	ending_choice = true
	_dawn_pending = dawn_message
	offers = [{"id": "let_go", "rarity": 0}]
	if ending_b_open():
		offers.append({"id": "remember", "rarity": 0})
	offers.append({"id": "keep_looping", "rarity": 0})
	_set_phase(Phase.CARDS, "Dawn. The statue waits: choose an ending, or keep looping.")
	if lighting:  # hold the dawn light while the choice waits, so the dawn plays once (Keep looping carries it on to day)
		lighting.stop_sequence()
		lighting.set_mood("dawn")


func villagers_alive() -> int:
	## Nobody dies in the village; the fall only darkens the houses, so every villager counts (houses when no village).
	return life.villagers.size() if life != null else houses.size()


func carry_amount() -> int:
	## Faith the coming rewind carries into the next loop (stand-in numbers, GameConfig): a share of the Faith held at
	## the fall, a bonus per villager alive and one per kindness task done this loop.
	return roundi(faith * GameConfig.CARRY_FAITH_SHARE) + GameConfig.CARRY_PER_VILLAGER * villagers_alive() 		+ GameConfig.CARRY_PER_KINDNESS * _helped


func _end_loop(_won := false) -> void:
	## The loop is over (the fall, or a lost night): the Warden is never beaten, loops are endless. Fall night: 3 cards,
	## keep 1. A night lost earlier: 1 Common card.
	loop_won = false
	var boss_p2 := warden != null and warden.phase >= 2
	_clear_night()
	_rng.seed = run_seed * 977 + loop
	var earned_full_draft := night >= fall_night() or boss_p2
	offers = Cards.offers(cards, 3 if earned_full_draft else 1, _rng, not earned_full_draft, loop)
	if offers.is_empty():
		_begin_rewind()
		return
	var head := ("Night %d falls. Choose 1 of 3 cards to carry back." % (night + 1) if earned_full_draft else "Night %d lost. The hourglass gives you a card." % (night + 1))
	_set_phase(Phase.CARDS, head)


func choose_card(i: int) -> bool:
	if _cutscene or phase != Phase.CARDS or i < 0 or i >= offers.size():
		return false
	var o: Dictionary = offers[i]
	if ending_choice:
		if o["id"] == "keep_looping":
			ending_choice = false
			offers = []
			_begin_day(_dawn_pending)
			return true
		return _finish_story(o["id"])
	cards[o["id"]] = o["rarity"]  # a duplicate is only offered at a higher rarity, so this upgrades it
	snd(RARITY_SOUNDS[clampi(int(o["rarity"]), 0, 2)])
	offers = []
	_begin_rewind()
	return true


const ENDINGS := {
	"let_go": "You let go. The Veil is yours no longer: it is theirs, and it holds. You fade into a small carved statue on the shrine. In the morning the villagers leave honeycakes at your feet, and Wren whispers: \"Thank you, little god.\" In the trees, Skotos weeps, because someone gave everything for love.",
	"remember": "You show Skotos every prayer you ever heard. They remember being worshipped. They remember being loved. The curse cracks. The Dark Wood blooms, and two small gods keep watch over one garden.",
}


func _finish_story(id: String) -> bool:
	## The ending the player chose. The run is over; a new run starts from the sign (or R).
	ending_choice = false
	offers = []
	snd("dawn_bell")
	_set_phase(Phase.DONE, ENDINGS.get(id, "The end."))
	if with_rig:
		say_at_shrine("Thank you, little god." if id == "let_go" else "I remember.")
	return true


## The first rewind (end of loop 1 only) is a short cutscene on the table first. DRAFT lines live in
## godot/data/thoughts.json under "cutscene" (Claude, Siddharth to approve). Times in seconds from its start.
const CUTSCENE_T := {"skotos1": 1.2, "dark": 4.6}  # the rest follows from how many houses are still lit
const FALL_CAPTION := preload("res://scripts/ui/fall_caption.gd")  # no class_name: it needs no editor import
const CUTSCENE_HOUSE_GAP := 1.5  # s between one house going dark and the next
const GLASS_RISE := 0.8  # the rewind hourglass: rises, flips, the sand runs (seconds), then its burst
const GLASS_FLIP := 0.9
const GLASS_SAND := 1.3
const CUTSCENE_GLASS := GLASS_RISE + GLASS_FLIP + GLASS_SAND + 0.3  # the day returns only once it has turned
const CUTSCENE_SKOTOS_SCALE := 1.65  # the display Skotos on top of Enemy.BOSS_SCALE (0.65): 0.31 m x 1.65 = 0.52 m, about four houses tall, whole figure in frame
const CUTSCENE_SKOTOS_TURN := 0.0  # yaw so he faces the player
var _cutscene := false  # the player cannot act while it plays
var _cutscene_glass_wait := false  # the story is told: the rewind waits for the player to hold the tray hourglass (the user, 2026-11-18)
const CUTSCENE_SCORE_FROM := 97.0  # story_music.ogg: the ominous stretch, beasts and the lights going out (97-126 s); looped while we wait
const CUTSCENE_SCORE_LEN := 28.0
var _score_player: AudioStreamPlayer
var _score_own_hold := false  # this cutscene set music.hold (the story's own score may hold it too: never release that one)
var _score_tween: Tween
var cutscene_count := 0  # how many times it has played this run (only ever the end of loop 1)
var _cutscene_skotos: Enemy
var _statue_tweens: Array[Tween] = []
var _dawn_pending := ""  # the dawn message waiting while the ending choice is on the tray


func is_cutscene() -> bool:
	return _cutscene


func _begin_rewind() -> void:
	## After the fall: the end of loop 1 plays the explanation first, every later loop goes straight to the rewind.
	if loop != 0:
		_rewind()
		return
	cutscene_count += 1
	if not (with_rig and is_inside_tree() and board != null):
		_rewind()  # no table to play it on (headless checks): it still counts, and still ends in the rewind
		return
	if ledger and ledger.open:  # a book latched open would stay over the whole scene
		ledger.set_open(false)
	_ledger_latched = false
	_cutscene = true
	last_message = "The village falls dark."
	_start_cutscene_score()
	if lighting:  # still the fall night, darker and colder than any night: held until the glass turns
		lighting.stop_sequence()
		lighting.set_mood("fallen", 1.5)
	for old in get_tree().get_nodes_in_group(Bubble.ACTIVE_GROUP):  # no villager line left hanging over the scene
		old.queue_free()
	if veil:
		veil.shatter(0.8)  # the Veil has fallen anyway: its grid is gone for the scene
	_refresh_ui()
	var serial := _rewind_serial
	var at := func(t: float, f: Callable):
		get_tree().create_timer(t).timeout.connect(func():
			if serial == _rewind_serial and _cutscene:
				f.call())
	var lit := houses.filter(func(h): return is_instance_valid(h) and not h.is_shuttered)
	var t_dark: float = CUTSCENE_T["dark"]
	var t_maren: float = t_dark + maxi(lit.size(), 1) * CUTSCENE_HOUSE_GAP + 1.0
	var t_s2: float = t_maren + 3.8
	var t_n0: float = t_s2 + 5.6
	var t_end: float = t_n0 + 3.4 * StoryText.cutscene_narration().size()
	at.call(0.3, func(): _cutscene_show_skotos())
	at.call(CUTSCENE_T["skotos1"], func(): _cutscene_line("Skotos", StoryText.cutscene("skotos_1"), SKOTOS.darkened(0.2), 3.2))
	for k in lit.size():  # the houses go dark one by one, a flicker and then out
		at.call(t_dark + k * CUTSCENE_HOUSE_GAP, func():
			if is_instance_valid(lit[k]) and not lit[k].is_shuttered:
				snd("shutter_close", lit[k].global_position)
				lit[k].snuff())
	at.call(t_dark + lit.size() * CUTSCENE_HOUSE_GAP - 0.4, func(): _cutscene_dim_statue())  # the statue's glow goes last
	at.call(t_maren, func(): _cutscene_line("Maren", StoryText.cutscene("maren"), Color("7A4A1E"), 3.2))  # still praying
	at.call(t_s2, func(): _cutscene_line("Skotos", StoryText.cutscene("skotos_2"), SKOTOS.darkened(0.2), 5.0))
	var lines := StoryText.cutscene_narration()
	for k in lines.size():
		at.call(t_n0 + 3.4 * k, func(): _cutscene_line("", lines[k], Color.BLACK, 3.0))  # parchment narration
	at.call(t_end, func():  # the story is told: the hourglass on the tray waits for the player's hand
		_cutscene_glass_wait = true
		_cutscene_prompt_glass(serial))


func _cutscene_prompt_glass(serial: int) -> void:
	## Until the player holds the tray hourglass the dark stays: the line is repeated, the glass pulses (see _tick_tray_bits).
	if serial != _rewind_serial or not _cutscene or not _cutscene_glass_wait:
		return
	_cutscene_line("", "Hold the hourglass on your tray to turn back time.", Color.BLACK, 6.5)
	get_tree().create_timer(7.0).timeout.connect(_cutscene_prompt_glass.bind(serial))


func _cutscene_turn_glass() -> void:
	## The player's hand turned it: the hourglass rises and turns in the dark, the day comes only when it has turned.
	if not _cutscene_glass_wait:
		return
	_cutscene_glass_wait = false
	var serial := _rewind_serial
	_play_hourglass()
	get_tree().create_timer(CUTSCENE_GLASS).timeout.connect(func():
		if serial == _rewind_serial:
			_cutscene = false
			if is_instance_valid(_cutscene_skotos):
				_cutscene_skotos.queue_free()
			_cutscene_skotos = null
			_stop_cutscene_score(1.5)
			_rewind(true))


func _start_cutscene_score() -> void:
	## The loss cutscene plays the story score's ominous stretch (97-126 s of story_music.ogg) instead of the day / night loops,
	## looped with a short dip while it waits for the hourglass (the user, 2026-11-18).
	if audio == null or not (audio is AudioBank):
		return
	var st: AudioStream = (audio as AudioBank)._stream("music/story_music.ogg", false)
	if st == null:
		return
	_stop_cutscene_score(0.0)
	if music != null:
		music.hold = true
		_score_own_hold = true
	_score_player = AudioStreamPlayer.new()
	_score_player.stream = st
	_score_player.bus = "music"
	_score_player.volume_db = -40.0
	add_child(_score_player)
	_score_player.play(CUTSCENE_SCORE_FROM)
	var pl := _score_player
	_score_tween = create_tween().set_loops()
	_score_tween.tween_property(pl, "volume_db", 0.0, 1.5)
	_score_tween.tween_interval(CUTSCENE_SCORE_LEN - 3.0)
	_score_tween.tween_property(pl, "volume_db", -40.0, 1.0)
	_score_tween.tween_callback(func(): pl.seek(CUTSCENE_SCORE_FROM))


func _stop_cutscene_score(fade: float) -> void:
	if _score_tween and _score_tween.is_valid():
		_score_tween.kill()
	_score_tween = null
	if music != null and _score_own_hold:
		music.hold = false
		_score_own_hold = false
	if _score_player != null and is_instance_valid(_score_player):
		var pl := _score_player
		_score_player = null
		if fade <= 0.0:
			pl.queue_free()
		else:
			var tw := pl.create_tween()
			tw.tween_property(pl, "volume_db", -60.0, fade)
			tw.tween_callback(pl.queue_free)


func _cutscene_show_skotos() -> void:
	## The Warden's own model, for show only (not in the enemy list, never fights): a god-sized figure at the board's
	## back edge in clear view, facing the player. A new boss model is coming; its size is CUTSCENE_SKOTOS_SCALE.
	if is_instance_valid(_cutscene_skotos):
		_cutscene_skotos.queue_free()
	var e := Enemy.new()
	e.game = self
	e.setup("boss", night, loop, _rng)
	_enemies_root.add_child(e)
	var gap: Array = GameConfig.SPAWNS[GameConfig.SPAWNS.keys()[0]]
	e.spawn_at(gap[gap.size() / 2])
	e.position = Vector3(0.0, 0.0, -0.32)
	e.scale = Vector3.ONE * CUTSCENE_SKOTOS_SCALE
	e.rotation.y = CUTSCENE_SKOTOS_TURN
	var glow := OmniLight3D.new()  # a purple light on him, so he reads in the dark (the only glow besides fire and embers)
	glow.light_color = SKOTOS
	glow.light_energy = 1.2
	glow.omni_range = 0.5
	glow.position = Vector3(0, 0.12, 0.05)
	e.add_child(glow)
	_cutscene_skotos = e


func _cutscene_line(speaker: String, line: String, name_colour: Color, seconds: float) -> void:
	if line == "" or board == null:
		return
	FALL_CAPTION.say(board, speaker, line, name_colour, seconds)
	last_message = ("%s: %s" % [speaker, line]) if speaker != "" else line
	_refresh_ui()


func _cutscene_dim_statue() -> void:
	## The statue's glow dims last: its candle light and flame sink to a faint ember.
	_kill_statue_tweens()
	if _shrine_light:
		_statue_tweens.append(create_tween())
		_statue_tweens[-1].tween_property(_shrine_light, "light_energy", 0.03, 1.0)
	if _shrine_flame:
		_statue_tweens.append(create_tween())
		_statue_tweens[-1].tween_property(_shrine_flame, "scale", Vector3.ONE * 0.25, 1.0)


func _kill_statue_tweens() -> void:
	for tw in _statue_tweens:
		if tw and tw.is_valid():
			tw.kill()
	_statue_tweens.clear()


func _rewind(glass_played := false) -> void:
	last_carry = carry_amount()  # Faith carried over: a share of what is held at the fall, per villager, per kindness
	carried_total += last_carry
	_carry_in = last_carry
	loop += 1
	if not glass_played:
		_play_hourglass()
	var kept := ", ".join(cards.keys().map(func(k): return "%s (%s)" % [Cards.POOL[k]["name"], Cards.RARITY_NAMES[cards[k]]]))
	_start_loop("The hourglass turns. Loop %d: enemies are tougher. +%d faith carried. Cards kept: %s" % [loop + 1, last_carry, kept if kept != "" else "none"], 5.4 if glass_played else 4.8)
	if with_rig and is_inside_tree():
		_toast_last = last_message  # the gilded words say it; no small line as well
		var serial := _rewind_serial
		get_tree().create_timer(1.0 if glass_played else 3.4).timeout.connect(func():  # once the hourglass has turned (already, after the cutscene)
			if serial == _rewind_serial:  # not if a new run started meanwhile
				show_rewind_words())


func show_rewind_words() -> TitleCard:
	## After the hourglass (the user, 2026-11-11): gilded words over the island, naming the loop.
	return TitleCard.show_over(board, Vector3(0, 0.36, 0.05), "TIME HAS BEEN REWOUND", "Loop %s" % LedgerPage.roman(loop + 1))


func _play_hourglass() -> void:
	## STAND-IN for the rewind effect (VFX come later): the hourglass model rises over the board, turns, hides.
	snd("rewind_whoosh")  # as the glass rises (not when the card is picked: the first rewind plays a cutscene between)
	if _hourglass == null or not is_inside_tree():
		return
	_hourglass.visible = true
	_hourglass.position = Vector3(0, 0.17, 0)  # rises from the statue (its __rewind_anchor)
	_hourglass.rotation = Vector3.ZERO
	var top: Node3D = _hourglass.find_child("*__sand_top", true, false)
	var bottom: Node3D = _hourglass.find_child("*__sand_bottom", true, false)
	if top:
		top.scale.y = 1.0
	if bottom:
		bottom.scale.y = 0.12
	var gold := Color("FFD45A")  # fire_yellow
	var amber := Color("F6A45D")  # lantern_glow
	VfxKit.burst(shots_root, _hourglass.global_position, gold, amber, 36, 0.12, 1.1, 0.006, 0.02)  # embers rise as it wakes
	if _rewind_tween and _rewind_tween.is_valid():
		_rewind_tween.kill()
	var tw := create_tween()
	_rewind_tween = tw  # new_run kills it
	tw.tween_property(_hourglass, "position:y", 0.3, GLASS_RISE).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_hourglass, "rotation:z", PI, GLASS_FLIP).set_trans(Tween.TRANS_BACK)
	if top and bottom:  # once flipped, the sand runs upward: the "top" bulb (now below) empties into the other
		tw.tween_property(top, "scale:y", 0.08, GLASS_SAND)
		tw.parallel().tween_property(bottom, "scale:y", 1.0, GLASS_SAND)
	tw.tween_callback(func():
		VfxKit.burst(shots_root, _hourglass.global_position, gold, amber, 48, 0.16, 1.4, 0.007, 0.05)  # a warm burst as the day returns
		var flash := OmniLight3D.new()  # a warm white flash over the island, gone in a moment
		flash.light_color = Color("FFF1B8")
		flash.omni_range = 1.6
		flash.light_energy = 0.0
		flash.position = Vector3(0, 0.4, 0)
		board.add_child(flash)
		var ft := flash.create_tween()
		ft.tween_property(flash, "light_energy", 6.0, 0.15)
		ft.tween_property(flash, "light_energy", 0.0, 0.7)
		ft.tween_callback(flash.queue_free))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): _hourglass.visible = false)


func _clear_night() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	if warden != null:
		warden.cleanup()  # the Grove's roots, lash line and stuns (phase 4, loop 2+)
	warden = null
	for t in towers:
		if is_instance_valid(t):
			t.reset_kick()
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
	for cd: Card3D in _held_spell_cards.values():
		if is_instance_valid(cd):
			cd.release_to_home(0.0)
	_held_spell_cards.clear()


func standing_houses() -> Array[int]:
	var out: Array[int] = []
	for h in houses:
		if not h.is_shuttered:
			out.append(h.index)
	return out


func set_speed(s: float) -> void:
	speed = s
	_refresh_ui()


func toggle_fast() -> void:
	## The tray hourglass (the user, 2026-11-11). By day it hurries the day on; at night it reads "2x" and runs
	## GameConfig.NIGHT_FAST (4) times as fast.
	if phase == Phase.DAY and tutorial_spotlight in ["cards", "rim", "board", "lens", "tray", "zoom", "ledger"]:
		return
	if phase == Phase.DAY:
		day_fast = not day_fast
	elif phase == Phase.NIGHT:
		set_speed(1.0 if speed > 1.0 else GameConfig.NIGHT_FAST)
	snd("pinch")
	_refresh_ui()


func is_fast() -> bool:
	return day_fast if phase == Phase.DAY else (phase == Phase.NIGHT and speed > 1.0)


func day_left() -> float:
	return maxf(0.0, GameConfig.DAY_LENGTH - day_time)


func _tick_day(delta: float) -> void:
	## The day runs out by itself (the user, 2026-11-11: "day ends at 3 min"). The sun crosses the island, the
	## light warms toward dusk near the end, and the night begins.
	var running := phase == Phase.DAY and day_clock and not asleep and not tutorial_hold
	if _sun:
		_sun.visible = phase == Phase.DAY and day_clock and not asleep
	if not running:
		return
	day_time += delta * (GameConfig.DAY_FAST if day_fast else 1.0)
	var f := clampf(day_time / GameConfig.DAY_LENGTH, 0.0, 1.0)
	if _sun:
		var a := lerpf(0.14, 0.97, f) * PI  # rises in the east (+X), sets in the west
		_sun.position = Vector3(cos(a) * 0.78, 0.06 + sin(a) * 0.42, -0.3)
		var low := clampf((f - 0.75) / 0.25, 0.0, 1.0)
		(_sun.material_override as StandardMaterial3D).albedo_color = Color("FFD45A").lerp(Color("E8452C"), low)  # fire_yellow -> fire_red
	if not _dusk_warned and day_left() <= GameConfig.DAY_DUSK_WARN:
		_dusk_warned = true
		if lighting:
			lighting.set_mood("dusk", minf(GameConfig.DAY_DUSK_WARN, 8.0))
		last_message = "Dusk is coming."
		_refresh_ui()
	if day_time >= GameConfig.DAY_LENGTH:
		start_night()


func crush_start(t: Tower, hand: GameHand, at: Vector3) -> bool:
	## Selling (the user, 2026-11-11: "crush to embers"): pinch a built tower and hold. Day only.
	if phase != Phase.DAY or t == null or not towers.has(t):
		return false
	_crush = {"tower": t, "hand": hand, "t": 0.0, "at": at}
	last_message = "Hold to return the %s: +%d faith." % [GameConfig.TOWERS[t.kind]["name"], sell_value(t)]
	_refresh_ui()
	return true


func crush_cancel() -> void:
	if _crush.is_empty():
		return
	var t: Tower = _crush["tower"]
	if is_instance_valid(t):
		t.scale = Vector3.ONE
		t.tint(null)
	_crush = {}


func crush_step(delta: float) -> bool:
	## true when the hold finished and the tower was sold.
	if _crush.is_empty():
		return false
	var t: Tower = _crush["tower"]
	var hand: GameHand = _crush["hand"]
	if not is_instance_valid(t) or phase != Phase.DAY or (hand and hand.touch_point().distance_to(_crush["at"]) > 0.05):
		crush_cancel()
		return false
	_crush["t"] += delta
	var f := clampf(_crush["t"] / GameConfig.CRUSH_HOLD, 0.0, 1.0)
	t.scale = Vector3(1.0 + f * 0.08, 1.0 - f * 0.45, 1.0 + f * 0.08)  # pressed down under the hand
	if _sell_mat == null:
		_make_sell_mat()
	t.tint(_sell_mat if f > 0.15 else null)
	if f < 1.0:
		return false
	var at := t.global_position + Vector3(0, 0.04, 0)
	_crush = {}
	t.scale = Vector3.ONE
	sell(t)
	VfxKit.burst(shots_root, at, VfxKit.FIRE_YELLOW, VfxKit.FIRE_ORANGE, 26, 0.09, 1.1, 0.006, 0.07)
	_faith_sparkle(board.global_position + Vector3(0, 0.12, 0))  # the faith arrives at the centre
	return true


func step(delta: float) -> void:
	## One game tick. Night waves drive combat; during the day, only active tutorial skirmishes step.
	if phase == Phase.DAY:
		if not enemies.is_empty():
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.has_meta("tutorial_shade") and (towers.is_empty() or e.attacking):
					e.alive = false
					enemies.erase(e)
					e.queue_free()
		var guards_active := towers.any(func(t): return t.cfg["kind"] == "spawner" and t.guards.any(func(gd): return gd.state != "idle"))
		if enemies.is_empty() and shots.is_empty() and not guards_active:
			return
		for e in enemies.duplicate():
			if is_instance_valid(e):
				e.step(delta)
		for t in towers:
			t.step(delta)
		for s in shots.duplicate():
			if is_instance_valid(s) and not s.done:
				s.step(delta)
		shots = shots.filter(func(s): return is_instance_valid(s) and not s.done)
		return
	if phase != Phase.NIGHT:
		return
	night_time += delta
	while not _spawn_queue.is_empty() and _spawn_queue[0]["t"] <= night_time:
		var ev: Dictionary = _spawn_queue.pop_front()
		var born := _spawn(ev["cell"], ev["kind"])
		if ev["kind"] == "boss":
			warden = Warden.new(self, born)
	for e in enemies.duplicate():
		if phase != Phase.NIGHT:
			return  # an enemy just ended the night: the rest (freed only at frame end) must not act this tick
		if is_instance_valid(e):
			e.step(delta)
	if phase != Phase.NIGHT:
		return
	if warden:
		warden.step(delta)
	_doom_step(delta)
	if phase != Phase.NIGHT:
		return  # the third house going dark ends the night
	for t in towers:
		t.step(delta)
	spells.step(delta)
	if _tray:
		_refresh_card_availability()  # cooldown cards return to full colour on the first tick they become ready
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
	if _spawn_queue.is_empty() and (enemies.is_empty() or stuck) and not (is_doomed_night() and warden != null):  # the doomed night ends only by the fall
		_end_night()
	else:
		_refresh_hud()


func _spawn(cell: Vector2i, kind: String, at := Vector3.INF) -> Enemy:
	var e := Enemy.new()
	e.game = self
	e.setup(kind, night, loop, _rng)
	_enemies_root.add_child(e)
	e.spawn_at(cell, at)
	snd("wisp_screech" if kind == "wisp" else "enemy_spawn", e.global_position)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	return e


func spawn_tutorial_shade(t: Tower) -> Enemy:
	## Spawns one slow, harmless daytime shade on open grass beside the first built tower for an instant combat payoff.
	if t == null or not is_instance_valid(t):
		return null
	var kind := "wisp" if t.kind == "airship" else "grunt"
	var side := 1.0 if t.position.x >= 0.0 else -1.0
	var base_dir := Vector3(side * 0.35, 0.0, 0.94).normalized()
	var chosen_cell := t.cell
	var chosen_pos := Vector3.ZERO
	var found := false
	for dist_cells: float in [2.8, 3.2, 2.4]:
		if found:
			break
		for ang_deg: float in [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0, 180.0]:
			var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(ang_deg))
			var p: Vector3 = t.position + dir * (dist_cells * GameConfig.CELL)
			p.x = clampf(p.x, -HALF + GameConfig.CELL * 3.5, HALF - GameConfig.CELL * 3.5)
			p.z = clampf(p.z, -HALF + GameConfig.CELL * 3.5, HALF - GameConfig.CELL * 3.5)
			var c := NavGrid.local_to_cell(p).clamp(Vector2i(3, 3), Vector2i(GameConfig.SIZE - 4, GameConfig.SIZE - 4))
			var standing := standing_houses()
			if kind == "wisp":
				var far_enough := true
				for hi in standing:
					var hpos := house_point(hi)
					if Vector2(p.x - hpos.x, p.z - hpos.z).length() < GameConfig.CELL * 2.0:
						far_enough = false
						break
				if not far_enough:
					continue
				chosen_cell = c
				chosen_pos = Vector3(p.x, 0.0, p.z)
				found = true
				break
			var clear := not nav.astar.is_point_solid(c) and not nav.kind.has(c)
			if clear:
				for nb in [c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)]:
					if nav.kind.get(nb, "") in ["house", "tower", "decor"]:
						clear = false
						break
			if clear and (nav.route(c, standing).get("path", []) as Array).size() >= 3:
				chosen_cell = c
				chosen_pos = Vector3(p.x, 0.0, p.z)
				found = true
				break
	if not found:
		for ang_deg: float in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]:
			var dir: Vector3 = base_dir.rotated(Vector3.UP, deg_to_rad(ang_deg))
			var p: Vector3 = t.position + dir * (2.6 * GameConfig.CELL)
			p.x = clampf(p.x, -HALF + GameConfig.CELL * 2.5, HALF - GameConfig.CELL * 2.5)
			p.z = clampf(p.z, -HALF + GameConfig.CELL * 2.5, HALF - GameConfig.CELL * 2.5)
			var c := NavGrid.local_to_cell(p).clamp(Vector2i(2, 2), Vector2i(GameConfig.SIZE - 3, GameConfig.SIZE - 3))
			if kind == "wisp" or (not nav.astar.is_point_solid(c) and not nav.route(c, standing_houses()).is_empty()):
				chosen_cell = c
				chosen_pos = Vector3(p.x, 0.0, p.z)
				found = true
				break
	if not found:
		chosen_pos = Vector3(clampf(t.position.x + base_dir.x * 2.5 * GameConfig.CELL, -HALF + 0.12, HALF - 0.12), 0.0, clampf(t.position.z + base_dir.z * 2.5 * GameConfig.CELL, -HALF + 0.12, HALF - 0.12))
		chosen_cell = NavGrid.local_to_cell(chosen_pos).clamp(Vector2i(1, 1), Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))
	var e := _spawn(chosen_cell, kind, chosen_pos)
	e.stats = e.stats.duplicate()
	e.stats["dps"] = 0.0
	e.hp = 8.0
	e.slow(0.35, 30.0)
	e.set_meta("tutorial_shade", true)
	e.died.connect(func(dead: Enemy):
		if is_instance_valid(self):
			faith += TUTORIAL_SHADE_REWARD
			var pos := dead.global_position if is_instance_valid(dead) else t.global_position
			snd("trust_chime", pos)
			if with_rig:
				_faith_sparkle(pos + Vector3(0, 0.06, 0))
			last_message = "First shade felled! +%d faith" % TUTORIAL_SHADE_REWARD
			_refresh_ui())
	return e


func add_patch(pos: Vector3, radius: float, dps: float, seconds: float) -> void:
	_patches.append({"pos": pos, "r": radius, "dps": dps, "left": seconds})


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	snd("boss_roar" if e.is_boss else "enemy_death", e.global_position)
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


func _on_house_shuttered(h: House) -> void:
	snd("shutter_close", h.global_position)
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


static func with_indefinite_article(noun: String) -> String:
	## Tower names currently begin with ordinary vowel/consonant sounds (Airship, Guard, Longbow, Wizard).
	var first := noun.strip_edges().left(1).to_lower()
	return "%s %s" % ["an" if first in ["a", "e", "i", "o", "u"] else "a", noun]


func tower_at(cell: Vector2i) -> Tower:
	for t in towers:
		if NavGrid.footprint(t.cell, GameConfig.TOWER_SIZE).has(cell):
			return t
	return null


func sell_value(t: Tower) -> int:
	var cost: int = GameConfig.TOWERS[t.kind]["cost"]
	return cost if t.built_night == night else int(cost * GameConfig.SELL_LATER)


func sell(t: Tower) -> bool:
	## Day only: the tower goes, its cells open up again, and faith comes back (sell_value).
	if phase != Phase.DAY or t == null or not towers.has(t):
		return false
	var back := sell_value(t)
	faith += back
	nav.remove_tower(t.cell, GameConfig.TOWER_SIZE)
	grass.refresh(nav)
	towers.erase(t)
	VfxKit.build_pop(shots_root, t.global_position)
	snd("sell", t.global_position)
	t.queue_free()
	last_message = "%s sold: +%d faith." % [GameConfig.TOWERS[t.kind]["name"], back]
	if foresight.showing:
		foresight.refresh()
	_update_ghost()
	_refresh_ui()
	return true


func can_build(kind: String, cell: Vector2i) -> bool:
	return phase == Phase.DAY and faith >= GameConfig.TOWERS[kind]["cost"] and not at_max(kind) \
		and nav.can_build(cell, GameConfig.TOWER_SIZE, standing_houses())


func at_max(kind: String) -> bool:
	## Spec 7: some kinds have a board limit (at most 2 Airships).
	return towers.filter(func(t): return t.kind == kind).size() >= GameConfig.TOWERS[kind].get("max", 999)


func try_build(kind: String, cell: Vector2i) -> bool:
	if not can_build(kind, cell):
		return false
	faith -= GameConfig.TOWERS[kind]["cost"]
	nav.add_tower(cell, GameConfig.TOWER_SIZE)
	grass.refresh(nav)
	var t := Tower.new()
	t.game = self
	_towers_root.add_child(t)
	t.setup(kind, cell)
	t.built_night = night
	towers.append(t)
	VfxKit.build_pop(shots_root, t.global_position)
	snd("build_pop", t.global_position)
	snd("place_thunk", t.global_position)
	var voice: String = t.voice()
	if audio and voice != "":  # the crew calls out once the tower has landed
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(t):
				snd("bark_%s_ready" % voice, t.global_position))
	if with_rig:
		t.settle()
	tower_placed.emit(kind, t.global_position)
	for r in requests:
		r.dodge(NavGrid.footprint(cell, GameConfig.TOWER_SIZE))
	last_message = "%s built. %d faith left." % [GameConfig.TOWERS[kind]["name"], faith]
	if faith < GameConfig.TOWERS[kind]["cost"] or at_max(kind):
		select("")
	if foresight.showing:
		foresight.refresh()  # a new tower can change the routes the lens draws
	_update_ghost()
	_refresh_ui()
	if not _sell_hint_shown:
		_sell_hint_shown = true
		_show_toast(SELL_TOWER_HINT)
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
		h.fx = with_rig
		h.shuttered.connect(_on_house_shuttered)
		h.hold_check = _hold_check
		h.on_hit = func(): snd("house_hit", h.global_position)
		houses.append(h)


func _build_ghost() -> void:
	_ghost = _child(board, "Ghost")
	_ghost_plate = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(GameConfig.CELL * 2 - 0.004, 0.002, GameConfig.CELL * 2 - 0.004)
	_ghost_plate.mesh = pm
	_ghost_mat = ModelUtil.flat_material(Color.GREEN, true, 0.4)  # the see-through tint on the ghost model
	_ghost_plate.position.y = 0.001
	_ghost_plate.material_override = ModelUtil.flat_material(Color.GREEN, true, 0.45)
	_ghost.add_child(_ghost_plate)
	_sell_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.outer_radius = GameConfig.CELL * 1.62  # round the 2 x 2 footprint's corners, hugging the tower
	ring.inner_radius = GameConfig.CELL * 1.48
	ring.rings = 32
	ring.ring_segments = 6
	_sell_ring.mesh = ring
	_sell_ring.scale = Vector3(1, 0.5, 1)
	_sell_ring.position.y = SELL_RING_Y
	var ring_mat := ModelUtil.flat_material(Color(1.0, 0.22, 0.14), true)
	_sell_ring.material_override = ring_mat
	_sell_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sell_ring.visible = false
	_ghost.add_child(_sell_ring)
	for k in GameConfig.TOWER_ORDER:
		var m: Node3D = load(GameConfig.TOWERS[k]["scene"]).instantiate()
		m.visible = false
		m.scale = Vector3.ONE * 1.04  # a hair bigger, so it never z-fights a tower it hovers over
		_ghost.add_child(m)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = _ghost_mat
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


func _tint_sell_target() -> void:
	var hot: Tower = tower_at(_hover_board_cell) if selected == "sell" else null
	if hot == _sell_target:
		return
	if is_instance_valid(_sell_target):
		_sell_target.tint(null)
	_sell_target = hot
	if hot:
		if _sell_mat == null:
			_make_sell_mat()
		hot.tint(_sell_mat)


func _make_sell_mat() -> void:
	_sell_mat = ModelUtil.flat_material(Color(1.0, 0.3, 0.24))  # solid red (Siddharth 2026-11-04): over the palette's own colours, so a tower's parts stay readable
	_sell_mat.albedo_texture = load("res://assets/palette/palette_atlas.png")
	_sell_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sell_mat.emission_enabled = true
	_sell_mat.emission = Color(0.42, 0.04, 0.03)  # lifts the black hat and the dark parts into red too


func _update_ghost() -> void:
	_tint_sell_target()
	if selected == "sell":
		# the tower under the pointer turns solid red (_tint_sell_target) inside a bright ring, with the refund in the message line
		var t := tower_at(_hover_board_cell)
		_ghost.visible = t != null
		_ghost_plate.visible = false
		_sell_ring.visible = true
		if t:
			_ghost.position = NavGrid.footprint_centre(t.cell, GameConfig.TOWER_SIZE)
			var when := "built today: full cost" if t.built_night == night else "half cost after a night"
			_msg.text = "Sell %s: +%d faith (%s)" % [GameConfig.TOWERS[t.kind]["name"], sell_value(t), when]
		elif _msg:
			_msg.text = "Pick a tower to sell. Full cost back on the day it was built, half after that."
		return
	_ghost_plate.visible = true
	_sell_ring.visible = false
	var show := selected != "" and _hover_cell.x >= 0
	_ghost.visible = show
	if not show:
		return
	_ghost.position = NavGrid.footprint_centre(_hover_cell, GameConfig.TOWER_SIZE)
	var ok := can_build(selected, _hover_cell)
	(_ghost_plate.material_override as StandardMaterial3D).albedo_color = Color(0.3, 0.9, 0.35, 0.45) if ok else Color(0.95, 0.25, 0.2, 0.45)
	_ghost_mat.albedo_color = Color(0.3, 0.9, 0.35, 0.4) if ok else Color(0.95, 0.25, 0.2, 0.4)


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
	var btn_changed := false
	for id in _buttons:
		var hovered: bool = (id == over)
		if _buttons[id]["hover"] != hovered:
			_buttons[id]["hover"] = hovered
			btn_changed = true
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
	if btn_changed:
		_refresh_buttons()


func villager_at(origin: Vector3, dir: Vector3, reach_m := 0.025) -> Villager:
	## The visible villager nearest the ray (within reach_m of its chest), or null.
	if life == null:
		return null
	var best: Villager = null
	var best_d := reach_m
	for v in life.villagers:
		if not v.visible:
			continue
		var chest := v.global_position + Vector3(0, 0.035, 0)
		var d := Geometry3D.get_closest_point_to_segment_uncapped(chest, origin, origin + dir * 2.0).distance_to(chest)
		if d < best_d:
			best_d = d
			best = v
	return best


func _find_prayer_asker(origin: Vector3, dir := Vector3.ZERO, radius := 0.025) -> Node3D:
	for r in requests:
		if not r.done and (r.kind == "prayer" or not r.accepted):  # a waving asker that is no listed villager (a stand-in) is tapped here
			var who := r.asker()
			if who == null or not who.is_visible_in_tree():
				continue
			var chest := who.global_position + Vector3(0, 0.035, 0)
			var d := chest.distance_to(origin) if dir == Vector3.ZERO \
				else Geometry3D.get_closest_point_to_segment_uncapped(chest, origin, origin + dir * 2.0).distance_to(chest)
			if d < radius:
				return who
	return null


func tap_villager(v: Node) -> String:
	## Tap a villager: a bubble with their next thought for this loop; they turn to look at you.
	if v == null or _cutscene:
		return ""
	for r in requests:
		if is_instance_valid(r) and not r.accepted and not r.done and r.asker() == v:  # a waving villager: ask what is wrong
			r.accept()
			if v is Villager:
				(v as Villager).taps += 1
			return r.ask_line
	for r in requests:
		if r.answer(v):  # the one who prays was heard
			if v is Villager:
				(v as Villager).taps += 1
			_pay_quest(r)
			return r.after_line
	if not (v is Villager):
		return ""
	var vil := v as Villager
	if vil.voice == "":
		return ""
	var line := StoryText.thought(vil.voice, loop, vil.taps)
	vil.taps += 1
	if line == "":
		return ""
	vil.said = line
	snd("villager_blip", vil.global_position)
	Bubble.say(vil, Vector3(0, 0.1, 0), "%s: %s" % [StoryText.villager_name(vil.voice), line] if vil.taps == 1 else line)
	if vil.state == "stay" or vil.state == "go":
		vil.put(vil.position, "idle", 2.5, board.to_local(_eye()))  # stops and looks at you while it speaks
	return line


const SKOTOS := Color("9C3EB0")  # palette crystal_purple: the Warden's colour


var shrine: Node3D  # the god's shrine at the centre of the island
var _shrine_cracks: Node3D
var _shrine_light: OmniLight3D
var _shrine_flame: MeshInstance3D
var _cakes: Array[MeshInstance3D] = []
var _helped := 0  # kindnesses done in this loop: a honeycake appears at the shrine for each (up to 6)


func _setup_shrine(node: Node3D) -> void:
	## The candle flame, a warm light that follows your faith, and the cracks (one more shows each loop).
	shrine = node
	if shrine == null:
		return
	_shrine_cracks = shrine.find_child("*__cracks", true, false)
	var candle: Node3D = shrine.find_child("*__candle_anchor", true, false)
	if candle:
		_shrine_flame = MeshInstance3D.new()  # a flame is Godot's job, never glowing geometry in the model
		var fm := SphereMesh.new()
		fm.radius = 0.0034
		fm.height = 0.0110
		_shrine_flame.mesh = fm
		_shrine_flame.material_override = ModelUtil.flat_material(Color("FFD45A"), true)  # fire_yellow
		candle.add_child(_shrine_flame)
		_shrine_light = OmniLight3D.new()
		_shrine_light.light_color = Color("F6A45D")  # lantern_glow
		_shrine_light.omni_range = 0.12  # the ember is in the statue's hands, close to its robe
		_shrine_light.light_energy = 0.2
		candle.add_child(_shrine_light)
	_update_shrine()


func _update_shrine() -> void:
	## Cracks from loop 2 on; honeycakes for each kindness this loop; the light follows your faith.
	if shrine == null:
		return
	if _shrine_cracks:
		_shrine_cracks.visible = loop >= 1
	if _shrine_light:
		_shrine_light.light_energy = 0.15 + clampf(float(faith) / 400.0, 0.0, 1.0) * 0.35
	if _shrine_flame:
		_shrine_flame.scale = Vector3.ONE  # the cutscene had dimmed it
	var want := mini(_helped, 6)
	var bowl: Node3D = shrine.find_child("*__offering_anchor", true, false)
	if bowl == null:
		return
	while _cakes.size() < want:
		var m := MeshInstance3D.new()
		var cm := SphereMesh.new()
		cm.radius = 0.0034
		cm.height = 0.0045
		m.mesh = cm
		m.material_override = ModelUtil.flat_material(Color("C87428"))  # roof_orange: a honeycake
		var k := _cakes.size()
		m.position = Vector3(0.0045 * cos(k * 2.1), 0.0012 + 0.0026 * (k / 3), 0.0045 * sin(k * 2.1))
		bowl.add_child(m)
		_cakes.append(m)
	while _cakes.size() > want:
		_cakes.pop_back().queue_free()


func _skotos_says(line: String) -> void:
	## Skotos speaks: purple, in the message line and over the island (with the rig only).
	if line == "" or not with_rig:
		return
	last_message = "Skotos: " + line
	_refresh_ui()
	say_at_shrine(line, SKOTOS.darkened(0.25))
	if _msg:
		_msg.modulate = SKOTOS.lightened(0.25)
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(_msg):
				_msg.modulate = Color.WHITE)


func say_at_shrine(line: String, colour := Bubble.INK, seconds := 6.0) -> void:
	## A line from the shrine (Maren's dawn prayer, Skotos's words). TODO: the shrine model's __candle_anchor.
	if board and line != "":
		Bubble.say(board, Vector3(0, 0.13, 0), line, seconds, colour)


func _press(origin: Vector3, dir: Vector3) -> void:
	if _cutscene:
		if _cutscene_glass_wait and _fast_glass != null and _fast_glass.is_visible_in_tree() 				and Plane(Vector3.UP, _fast_glass.global_position.y).intersects_ray(origin, dir) != null:
			var hit = Plane(Vector3.UP, _fast_glass.global_position.y).intersects_ray(origin, dir)
			if (hit as Vector3).distance_to(_fast_glass.global_position) <= reach(GameConfig.TOUCH_REACH * 2.0):
				_cutscene_turn_glass()  # the pointer (desktop, or a controller ray) on the glass turns it at once
		return
	if press_override.is_valid() and press_override.call(origin, origin, dir):
		return
	if asleep:
		return
	if ledger and ledger.open:
		if ledger.quit_hit_ray(origin, dir):
			quit_game()
			return
		var ql0 := ledger.quest_hit_ray(origin, dir)
		if _point_request(ql0):
			return
		var side := ledger.page_hit_ray(origin, dir)
		if side != 0:
			ledger.turn(side)  # the right page turns forward, the left back; the press is used up either way
			return
	var b := _button_at(origin, dir)
	if b != "":
		_press_button(b)
		return
	if _slip != null and _slip.hit_ray(origin, dir) and not _card_on_ray(origin, dir) and point_active_quest():
		return
	if not placing():
		var vt := villager_at(origin, dir)
		if vt:
			tap_villager(vt)
			return
		var pq := _find_prayer_asker(origin, dir, 0.025)
		if pq:
			tap_villager(pq)
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
		if _tray and phase == Phase.DAY:
			crush_start(tower_at(_board_cell_at(origin, dir)), null, Vector3.ZERO)  # desktop: hold the mouse on a tower
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
		elif faith < GameConfig.TOWERS[selected]["cost"]:
			last_message = "Not enough faith."
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
		"fast":
			if tutorial_spotlight in ["cards", "rim", "board", "lens", "tray", "zoom", "ledger"]:
				_show_toast("Finish the current tutorial step first.")
				return
			if _xr:
				_show_toast("Hold the hourglass to hurry the day")  # a stray touch never speeds time (the user, 2026-11-11)
			else:
				toggle_fast()
		"compass":
			cycle_board_scale()
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
				if faith < GameConfig.TOWERS[id]["cost"]:
					last_message = "Not enough faith for %s." % with_indefinite_article(GameConfig.TOWERS[id]["name"])
					_refresh_ui()
					return
			select("" if selected == id else id)


func _unhandled_input(event: InputEvent) -> void:
	if not with_rig:
		return
	if _cutscene and not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R) 			and not (_cutscene_glass_wait and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return  # the cutscene locks the input; only the restart key (and, once the story is told, a click on the hourglass) gets through
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
				toggle_fast()
			KEY_L:
				toggle_ledger()
			KEY_COMMA:
				if ledger and ledger.open:
					ledger.turn(-1)
			KEY_PERIOD:
				if ledger and ledger.open:
					ledger.turn(1)
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
			KEY_G:  # compare the two ways of walking (Siddharth is choosing, 2026-11-03)
				CharacterRig.step_legs = not CharacterRig.step_legs
				last_message = "Walking: %s (G switches)." % ("stepping legs" if CharacterRig.step_legs else "hopping")
				_refresh_ui()
	elif event is InputEventMouseMotion and _mouse_rim:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			mouse_rim_drag(event.position.x)
		else:
			_mouse_rim = false  # the button came up where we did not see it
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
	_grass_pushers.clear()
	for e in enemies:
		if _grass_pushers.size() >= GrassField.MAX_PUSH:
			break
		if is_instance_valid(e) and e.alive and not e.flying and not e.underground:
			_grass_pushers.append(Vector4(e.global_position.x, e.global_position.y, e.global_position.z, 0.045))
	for t in towers:
		if _grass_pushers.size() >= GrassField.MAX_PUSH:
			break
		for gd in t.guards:
			if _grass_pushers.size() >= GrassField.MAX_PUSH:
				break
			if is_instance_valid(gd):
				_grass_pushers.append(Vector4(gd.global_position.x, gd.global_position.y, gd.global_position.z, 0.03))
	if _mouse_hand != null:
		if _grass_pushers.size() < GrassField.MAX_PUSH and is_instance_valid(_mouse_hand) and not _mouse_hand.is_lost():
			_grass_pushers.append(Vector4(_mouse_hand.global_position.x, _mouse_hand.global_position.y, _mouse_hand.global_position.z, 0.05))
	else:
		for h in _hands:
			if _grass_pushers.size() >= GrassField.MAX_PUSH:
				break
			if is_instance_valid(h) and not h.is_lost():
				_grass_pushers.append(Vector4(h.global_position.x, h.global_position.y, h.global_position.z, 0.05))
	if life and _grass_pushers.size() < GrassField.MAX_PUSH:
		life.append_pushers(_grass_pushers, GrassField.MAX_PUSH)
	grass.set_pushers(_grass_pushers)


func _process(delta: float) -> void:
	var left := delta * speed
	while left > 0.0:
		step(minf(left, MAX_TICK))
		left -= MAX_TICK
	_feed_grass()
	if not with_rig:
		return
	_tick_day(delta)
	_tick_quests(delta)
	_tick_rim(delta)
	update_hud_root()
	if _xr and not asleep:
		if not OpeningStage.sweeping:  # the story's measuring pass needs steady quality settings
			PerfTier.govern(delta, get_viewport(), lighting.sun, XRServer.find_interface("OpenXR"))
	if _xr and (GameConfig.VERBOSE_XR_LOG or OS.is_stdout_verbose()):
		_perf_log_t -= delta
		if _perf_log_t <= 0.0:
			_perf_log_t = 5.0
			print("[perf] fps=%d tier=%s step=%d" % [Engine.get_frames_per_second(), PerfTier.name_of(PerfTier.tier), PerfTier.step])
	if _xr and ledger:
		var palm := palm_pose()
		ledger_from_palm(delta, palm[0], palm[1], palm[2], _eye())
	elif ledger and ledger.open:
		_place_ledger_in_front()
	crush_step(delta)
	_tick_tray_bits(delta)
	_update_mouse_hand()
	_update_lens()
	_update_ui_rig(delta)
	_update_tray()
	_tick_lens_window()
	_update_held()
	for h in _hands:
		h.set_bubble_hot(not h.is_lost() and grabbable_near(h.global_position))
		if h.bubble:
			h.bubble.visible = not h.is_lost()
	if _held_card or not _held_spell_cards.is_empty():
		pass  # a card in hand decides the cell (_update_held); the pointer must not overwrite it
	elif _xr:
		if _active_hand:
			if _active_hand.is_lost():
				_hover(Vector3(0, 1000, 0), Vector3.UP)  # a hand that left tracking points at nothing
			else:
				_hover(_active_hand.ray_origin(), _active_hand.ray_dir())
	elif _camera:
		var m := get_viewport().get_mouse_position()
		_hover(_camera.project_ray_origin(m), _camera.project_ray_normal(m))


# ---------------------------------------------------------------- UI (3D, so it works in the headset too)

func _build_ui() -> void:
	var ui := _child(board, "UI")
	var specs := []
	for k in GameConfig.TOWER_ORDER:
		specs.append([k, "%s\n%d faith" % [GameConfig.TOWERS[k]["name"], GameConfig.TOWERS[k]["cost"]]])
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
	var hg = load("res://assets/vfx/ew_vfx_rewind_hourglass_v02.glb")
	if hg:
		_hourglass = hg.instantiate()
		_hourglass.scale = Vector3.ONE * 2.0
		_hourglass.visible = false
		board.add_child(_hourglass)  # on the board, not the UI: the intro plays it while the UI is hidden
	_build_close_signs(ui)
	_build_spell_tokens(ui, x0, w, gap)
	if with_rig:
		_tray = CardTray.new()
		_tray.name = "CardTray"
		add_child(_tray)  # on its own, not on the board: moving, turning or resizing the island leaves it where it is
		_tray.visible = not asleep
	_hud = _make_label(ui, Vector3(0, 0.24, -HALF - 0.03), 80)
	_msg = _make_label(ui, Vector3(0, 0.195, -HALF - 0.03), 56)
	if _tray:
		_hud.visible = false  # 2026-11-11 (the user): no text wall. Faith is on the seal, the day is the sun, the rest is in the ledger
		_msg.visible = false
		_build_tray_bits()
		ledger = Ledger.new()
		ledger.name = "Ledger"
		ledger.game = self
		add_child(ledger)


func ledger_data() -> Dictionary:
	## Everything the ledger's pages show. Read-only.
	var folk := []
	if life:
		for v in life.villagers:
			if v.voice != "":
				folk.append({"name": StoryText.villager_name(v.voice), "role": StoryText.villager_role(v.voice), "said": v.said})
	var left := int(ceil(day_left()))
	return {
		"loop": loop, "night": night, "days": loop_nights, "faith": faith, "carried": carried_total,
		"houses": standing_houses().size(), "houses_total": houses.size(), "foresight": foresight_tier(),
		"time_left": "%d:%02d" % [left / 60, left % 60] if phase == Phase.DAY else "night",
		"gifts": cards.keys().map(func(k): return "%s (%s)" % [Cards.POOL[k]["name"], Cards.RARITY_NAMES[cards[k]]]),
		"villagers": folk,
		"towers": GameConfig.TOWER_ORDER.map(func(id): return CardData.tower(id)),
		"spells": GameConfig.SPELL_ORDER.map(func(id): return CardData.spell(id)),
		"quests": requests.map(func(r): return r.info()),
		"quests_to_come": quest_plan.size(),
	}


func toggle_ledger() -> void:
	## A button or a key: opens it in front of you and keeps it there until pressed again.
	if ledger == null or asleep or _cutscene:
		return
	_ledger_latched = not ledger.open
	if _ledger_latched:
		_place_ledger_in_front()
	ledger.set_open(_ledger_latched)


func _place_ledger_in_front() -> void:
	var cam: Camera3D = _xr_cam if _xr_cam else _camera
	if cam == null:
		return
	var at := cam.global_transform * Vector3(0, -0.02 if _xr_cam else 0.0, -0.5)
	_face_ledger(at, cam.global_position)


func _face_ledger(at: Vector3, eye: Vector3) -> void:
	ledger.global_position = at
	if at.distance_to(eye) > 0.01:
		ledger.global_basis = Basis.looking_at(at - eye, Vector3.UP).scaled(Vector3.ONE * ledger.scale.x)  # its face (+Z) toward the eye


func _on_xr_tracker_removed(tracker_name: StringName, _type: int = 0) -> void:
	if tracker_name == &"/user/hand_tracker/left":
		_left_hand_tracker = null


func quit_game() -> void:
	## Triggered by the Quit Game seal on the final page of the Ledger.
	quit_requested = true
	last_message = "Closing Aeterna..."
	if get_tree() and DisplayServer.get_name() != "headless":
		get_tree().quit()


func _get_left_hand_tracker() -> XRHandTracker:
	if not _left_tracker_hooked:
		_left_tracker_hooked = true
		var cb := Callable(self, "_on_xr_tracker_removed")
		if not XRServer.tracker_removed.is_connected(cb):
			XRServer.tracker_removed.connect(cb)
	if _left_hand_tracker == null or not is_instance_valid(_left_hand_tracker):
		_left_hand_tracker = XRServer.get_tracker(&"/user/hand_tracker/left") as XRHandTracker
	return _left_hand_tracker


func palm_pose() -> Array:
	## [found, position, normal out of the palm] of the left hand, in world space.
	if _xr_origin:
		var tr := _get_left_hand_tracker()
		if tr and tr.has_tracking_data:
			# The palm's normal from where the fingers actually are, so it does not depend on a joint-axis convention:
			# (wrist -> middle knuckle) x (index knuckle -> little knuckle) points out of the LEFT palm.
			var o := _xr_origin.global_transform
			var wrist: Vector3 = o * tr.get_hand_joint_transform(1).origin
			var mid: Vector3 = o * tr.get_hand_joint_transform(12).origin
			var idx: Vector3 = o * tr.get_hand_joint_transform(7).origin
			var lit: Vector3 = o * tr.get_hand_joint_transform(22).origin
			var n := (lit - idx).cross(mid - wrist)  # measured on the Quest 3 (log 2026-11-11 15:50: a palm held up read -0.99 with the opposite order)
			if n.length() > 0.0001:
				return [true, o * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM).origin, n.normalized()]
	return [false, Vector3.ZERO, Vector3.ZERO]  # only the LEFT HAND's tracked palm counts: no controller or right-hand fallback (the user, 2026-11-11)


func ledger_from_palm(delta: float, found: bool, at: Vector3, normal: Vector3, eye: Vector3) -> void:
	## Palm turned up for a moment: the ledger unfolds over it and stays where it opened. Turned away: it folds shut after a brief debounce.
	if ledger == null or _ledger_latched:
		return
	var raw_up := normal.dot(Vector3.UP) if found else -1.0
	var d := at.distance_to(eye)
	if GameConfig.VERBOSE_XR_LOG or OS.is_stdout_verbose():
		_palm_log_t -= delta
		if found and _palm_log_t <= 0.0:
			_palm_log_t = 2.0
			print("[ledger] left palm seen: up=%.2f dist=%.2f below_eye=%.2f open=%s" % [raw_up, d, eye.y - at.y, ledger.open])  # for the headset log
	var in_reach := found and d >= GameConfig.PALM_REACH.x and d <= GameConfig.PALM_REACH.y and at.y <= eye.y - GameConfig.PALM_BELOW_EYE
	var up := raw_up if in_reach else -1.0  # a hand resting in the lap, behind you or up by your face is not the gesture
	var busy := asleep or (_hands.size() > 0 and ((_held_card and _held_card_hand == _hands[0]) or _held_spell_cards.has(_hands[0])))
	if busy:
		up = -1.0
	if not ledger.open:
		_palm_close_time = 0.0
		_palm_time = _palm_time + delta if up > GameConfig.PALM_UP_OPEN else 0.0
		if _palm_time >= GameConfig.PALM_UP_HOLD:
			var inward := Vector3.FORWARD
			if is_instance_valid(board):
				var flat := Vector3(board.global_position.x - at.x, 0.0, board.global_position.z - at.z)
				if flat.length() > 0.001:
					inward = flat.normalized()
			var open_pos := at + Vector3(0, 0.17, 0) + inward * LEDGER_INWARD_SHIFT
			_face_ledger(open_pos, eye)  # it appears once, over the palm and shifted inward toward the board
			ledger.set_open(true)
			if GameConfig.VERBOSE_XR_LOG or OS.is_stdout_verbose():
				print("[ledger] opened by the left palm, up=%.2f dist=%.2f" % [up, d])
	elif busy or (found and in_reach and raw_up <= -0.5):
		_palm_time = 0.0
		_palm_close_time = 0.0
		ledger.set_open(false)
	elif up < GameConfig.PALM_UP_CLOSE:
		_palm_close_time += delta
		if _palm_close_time >= GameConfig.PALM_CLOSE_HOLD:
			_palm_time = 0.0
			_palm_close_time = 0.0
			ledger.set_open(false)
	else:
		_palm_close_time = 0.0


func _build_tray_bits() -> void:
	## What stands on the tray beside the cards: the faith seal (left), the small hourglass (right) and the one
	## fading message line above. And the sun that carries the day over the island.
	_faith_seal = Node3D.new()
	_faith_seal.name = "FaithSeal"
	_tray.add_child(_faith_seal)
	var wax := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.021
	cyl.bottom_radius = 0.023
	cyl.height = 0.006
	cyl.radial_segments = 20
	wax.mesh = cyl
	wax.material_override = ModelUtil.flat_material(Color("E8452C"))  # fire_red wax
	_faith_seal.add_child(wax)
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.0215
	tor.outer_radius = 0.0245
	tor.rings = 24
	tor.ring_segments = 6
	ring.mesh = tor
	ring.material_override = ModelUtil.flat_material(Color("F2B630"))  # rarity_gold rim
	ring.position.y = 0.002
	_faith_seal.add_child(ring)
	_faith_label = Label3D.new()
	_faith_label.font_size = 64
	_faith_label.pixel_size = 0.00036
	_faith_label.outline_size = 10
	_faith_label.modulate = Color("FFD45A")
	_faith_label.outline_modulate = Color("5B2920")
	_faith_label.rotation_degrees.x = -90
	_faith_label.position.y = 0.0045
	_faith_seal.add_child(_faith_label)
	_faith_seal.rotation_degrees.x = 40  # tipped up toward the eyes
	var hold := MeshInstance3D.new()  # the pressable spot (ray) around the small hourglass
	hold.name = "FastGlass"
	_tray.add_child(hold)
	_fast_glass = hold
	var hg = load("res://assets/vfx/ew_vfx_rewind_hourglass_v02.glb")
	if hg:
		var m: Node3D = hg.instantiate()
		m.name = "Model"
		m.scale = Vector3.ONE * 0.34
		hold.add_child(m)
	_fast_label = Label3D.new()
	_fast_label.font_size = 56
	_fast_label.pixel_size = 0.00036
	_fast_label.outline_size = 10
	_fast_label.modulate = Color("FFD45A")
	_fast_label.outline_modulate = Color("5B2920")
	_fast_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_fast_label.position = Vector3(0, 0.06, 0)
	hold.add_child(_fast_label)
	var box := Vector3(0.045, 0.06, 0.045)
	_buttons["fast"] = {"node": hold, "mat": StandardMaterial3D.new(), "label": _fast_label, "hover": false, "box": AABB(Vector3(-box.x / 2.0, 0, -box.z / 2.0), box)}
	var compass := Node3D.new()
	compass.name = "BoardCompass"
	_tray.add_child(compass)
	_board_compass = compass
	var disc := MeshInstance3D.new()
	var dcyl := CylinderMesh.new()
	dcyl.top_radius = 0.021
	dcyl.bottom_radius = 0.023
	dcyl.height = 0.008
	dcyl.radial_segments = 20
	disc.mesh = dcyl
	var cmat := ModelUtil.flat_material(Color8(0x5B, 0x29, 0x20))
	disc.material_override = cmat
	compass.add_child(disc)
	var dring := MeshInstance3D.new()
	var dtor := TorusMesh.new()
	dtor.inner_radius = 0.0205
	dtor.outer_radius = 0.0235
	dtor.rings = 24
	dtor.ring_segments = 6
	dring.mesh = dtor
	dring.material_override = ModelUtil.flat_material(Color("F2B630"))
	dring.position.y = 0.0025
	compass.add_child(dring)
	_compass_label = Label3D.new()
	_compass_label.font_size = 46
	_compass_label.pixel_size = 0.00029
	_compass_label.outline_size = 8
	_compass_label.modulate = Color("FFD45A")
	_compass_label.outline_modulate = Color("5B2920")
	_compass_label.rotation_degrees.x = -90
	_compass_label.position.y = 0.0055
	compass.add_child(_compass_label)
	compass.rotation_degrees.x = 40
	var cbox := Vector3(0.05, 0.03, 0.05)
	_buttons["compass"] = {"node": compass, "mat": cmat, "label": _compass_label, "hover": false, "box": AABB(Vector3(-cbox.x / 2.0, -0.015, -cbox.z / 2.0), cbox)}
	_update_compass_label()
	_toast = _make_toast_label("Toast", TOAST_POS)
	_toast_stack.clear()
	for i in range(TOAST_STACK_MAX - 1):
		var stacked := _make_toast_label("ToastStack%d" % (i + 1), TOAST_POS + Vector3(0, TOAST_STACK_STEP * (i + 1), 0))
		_toast_stack.append(stacked)
	_slip = QuestSlipScript.new()
	_slip.name = "QuestSlip"
	_tray.add_child(_slip)
	_slip.position = Vector3(0, 0.001, 0.056)  # its top edge on the tray's front lip
	_slip.visible = false
	_sun = MeshInstance3D.new()
	_sun.name = "Sun"
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	_sun.mesh = sm
	_sun.material_override = ModelUtil.flat_material(Color("FFD45A"), true)
	_sun.visible = false
	board.add_child(_sun)


func update_hud_root() -> void:
	## The day clock and tutorial text stay just behind the table's far edge (seen from the player), at the table's
	## scale, and keep facing the seated player: they follow the board's position and scale but not its rotation.
	if board == null:
		return
	if hud_root == null:
		hud_root = Node3D.new()
		hud_root.name = "HudRoot"
		add_child(hud_root)
	var s := board.global_transform.basis.get_scale().x
	var c := board.global_position
	var eye := _eye()
	var away := Vector3(c.x - eye.x, 0.0, c.z - eye.z)
	away = Vector3(0, 0, -1) if away.length() < 0.05 else away.normalized()
	var ax := board.global_transform.basis.x
	var az := board.global_transform.basis.z
	ax = Vector3(ax.x, 0, ax.z).normalized()
	az = Vector3(az.x, 0, az.z).normalized()
	var ext := HALF * (absf(away.dot(ax)) + absf(away.dot(az)))  # how far the (turned) square reaches along "away"
	hud_root.global_position = c + away * (ext + HUD_GAP) * s
	hud_root.scale = Vector3.ONE * s


func _tick_clock() -> void:
	## The countdown (the user: "there's no obvious countdown"): a big gilded m:ss over the island all day, red in the last 20 s.
	if _clock == null:
		_clock = Label3D.new()
		_clock.name = "DayClock"
		_clock.font_size = 220
		_clock.pixel_size = 0.00045
		_clock.outline_size = 24
		_clock.outline_modulate = Color("5B2920")
		_clock.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_clock.no_depth_test = true
		_clock.render_priority = 12
		_clock.position = DAY_CLOCK_POS
		update_hud_root()
		hud_root.add_child(_clock)
	update_hud_root()
	_clock.visible = phase == Phase.DAY and not asleep
	if _clock.visible:
		var left := int(ceil(day_left()))
		_clock.text = "%d:%02d" % [left / 60, left % 60] if not tutorial_hold else "Take your time"
		_clock.modulate = Color("E8452C") if left <= int(GameConfig.DAY_DUSK_WARN) else Color("FFD45A")


func _make_toast_label(node_name: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.font_size = 44
	l.pixel_size = 0.00036
	l.width = TRAY_SUBTITLE_WIDTH
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.outline_size = 8
	l.modulate = Color("FFF3D6")
	l.outline_modulate = Color("2A1E16")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = pos
	_tray.add_child(l)
	_set_toast_alpha(l, 0.0)
	return l


func _set_toast_alpha(l: Label3D, a: float) -> void:
	if l == null:
		return
	l.modulate.a = a
	l.outline_modulate.a = a
	l.visible = a > 0.005 and l.text != ""


func _layout_toast_stack() -> void:
	if _toast == null:
		return
	_toast.position = TOAST_POS
	var y := TOAST_POS.y
	var prev := _toast
	for l in _toast_stack:
		var lines := maxi(1, ceili(float(prev.text.length()) / TOAST_CHARS_PER_LINE))
		y += TOAST_LINE_STEP * lines + TOAST_STACK_GAP
		l.position = Vector3(TOAST_POS.x, y, TOAST_POS.z)
		prev = l


func _tick_toast_label(l: Label3D, delta: float) -> void:
	if l == null or not l.visible:
		return
	var left: float = maxf(0.0, l.get_meta("left", 0.0) - delta)
	l.set_meta("left", left)
	if left <= 0.0:
		l.text = ""
		_set_toast_alpha(l, 0.0)
		if l == _toast:
			_toast_last = ""
		return
	_set_toast_alpha(l, clampf(left / 0.6, 0.0, 1.0))


func active_request() -> HelpRequest:
	## The quest the slip shows: the open one the player last engaged, else the oldest open one.
	var best: HelpRequest = null
	for r in requests:
		if r.done or not is_instance_valid(r):
			continue
		if best == null or (r.accepted and not best.accepted) or (r.accepted == best.accepted and r.engaged_seq > best.engaged_seq):
			best = r
	return best


func slip_data() -> Dictionary:
	## What the slip shows now; {} when no quest is open.
	var a := active_request()
	if a == null:
		return {}
	var others := 0
	for r in requests:
		if r != a and not r.done and is_instance_valid(r):
			others += 1
	return {"name": GameConfig.REQUESTS[a.kind]["name"], "step": a.step_line(), "where": a.where_text(),
		"ticks": a.ticks_total(), "ticks_done": a.ticks_done(), "others": others}


func update_slip() -> void:
	## Shows or hides the slip (by day, with an open quest) and redraws it when its quest changed.
	if _slip == null:
		return
	var d := slip_data() if phase == Phase.DAY and not asleep else {}
	_slip.visible = not d.is_empty() and _tray != null and _tray.visible
	if not d.is_empty():
		_slip.set_data(d)


func _point_request(i: int) -> bool:
	## A ledger poke on entry i: that quest's house glows. false for a bad index or a finished quest.
	if i < 0 or i >= requests.size() or not is_instance_valid(requests[i]) or requests[i].done:
		return false
	requests[i].point_the_way()
	_show_toast("Look for the glowing house.")
	return true


func _card_on_ray(origin: Vector3, dir: Vector3) -> bool:
	## A tray card lies on the pointer ray (its press belongs to the card, not the slip).
	if _tray == null:
		return false
	for c in _tray.cards:
		if is_instance_valid(c) and not c.lifted:
			var q := Geometry3D.get_closest_point_to_segment_uncapped(c.global_position, origin, origin + dir * 2.0)
			if q.distance_to(c.global_position) <= Card3D.H / 2.0:
				return true
	return false


func _slip_takes(tp: Vector3) -> bool:
	## A fingertip belongs to the slip only when it is on the slip and no tray card is within reach (the card wins).
	if _slip == null or not _slip.hit_point(tp, reach(0.02)):
		return false
	return _tray == null or _tray.card_near(tp, card_reach()) == null


func point_active_quest() -> bool:
	## The slip was touched: the asker's house glows for a few seconds.
	var a := active_request()
	if a == null:
		return false
	a.point_the_way()
	if with_rig:
		snd("pinch")
	_show_toast("Look for the glowing house.")
	return true


func _tick_slip(delta: float) -> void:
	_slip_t += delta
	if _slip_t >= 0.25:
		_slip_t = 0.0
		update_slip()


func _tick_tray_bits(delta: float) -> void:
	_tick_clock()
	if _tray != null and _tray.visible:
		var pts: Array = []
		for hh in _hands:
			if is_instance_valid(hh) and not hh.is_lost():
				pts.append(hh.touch_point())
		_tray.light_handles(pts, reach(GameConfig.TRAY_HANDLE_GRAB + 0.02), _tray_hand != null)
	_tick_slip(delta)
	if _compass_label and board and not is_equal_approx(_compass_scale, board.scale.x):
		_update_compass_label()
	if _fast_glass:
		if tutorial_spotlight == "hourglass" or _cutscene_glass_wait:
			_fast_glass.scale = Vector3.ONE * (1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.007))
		elif _fast_glass.scale != Vector3.ONE:
			_fast_glass.scale = Vector3.ONE
		var m := _fast_glass.get_node_or_null("Model")
		if m:
			m.rotation.z = fmod(m.rotation.z + delta * 5.0, TAU) if is_fast() else lerp_angle(m.rotation.z, 0.0, minf(1.0, delta * 6.0))
	_tick_toast_label(_toast, delta)
	for l in _toast_stack:
		_tick_toast_label(l, delta)
	if _tray:
		var card_pulse := 0.85 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
		var highlight_cards := tutorial_spotlight in ["cards", "spells"]
		for c in _tray.cards:
			if c._body and c._body.material_override is StandardMaterial3D:
				var bm := c._body.material_override as StandardMaterial3D
				if highlight_cards and c.glow:
					bm.emission_enabled = true
					bm.emission = Color("FFD45A")
					bm.emission_energy_multiplier = card_pulse
					c._body.scale = Vector3(1.10, 1.08, 0.92)
				elif bm.emission_enabled:
					bm.emission_enabled = false
					c._body.scale = Vector3.ONE


func _show_toast(line: String) -> void:
	if _toast == null or line == "" or asleep or line == _toast_last:
		return
	_toast_last = line
	for dst in _toast_stack:
		dst.text = ""
		dst.set_meta("left", 0.0)
		_set_toast_alpha(dst, 0.0)
	_toast.text = line
	_toast.position = TOAST_POS
	_toast.set_meta("left", TOAST_HOLD)
	_set_toast_alpha(_toast, 1.0)


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


func _tray_lens_rest(half_w: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -1.08) * Basis(Vector3.UP, 0.45), Vector3(half_w + 0.145, 0.012, 0.022))


func _build_lens() -> void:
	## The Crystal Lens rests on the tray's right wing when the tray is active, or the table corner in headless tests.
	var res = load(GameConfig.LENS_SCENE)
	if res == null:
		return
	_lens = res.instantiate()
	var dock_parent: Node3D = _tray if _tray != null else board
	dock_parent.add_child(_lens)
	if _tray != null:
		var half_w := GameConfig.TOWER_ORDER.size() * CardTray.CARD_SPACING / 2.0
		_lens_rest = _tray_lens_rest(half_w)
	else:
		_lens_rest = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0 + 0.35) * Basis(Vector3.UP, 0.5), Vector3(HALF - 0.1, 0.012, HALF + 0.09))
	_lens.transform = _lens_rest
	for n in ModelUtil.walk(_lens):
		if n is Marker3D and str(n.name).ends_with("grip_anchor"):
			_lens_grip = ModelUtil.xform_to(n, _lens).origin
		elif n is Marker3D and str(n.name).ends_with("lens_anchor"):
			_lens_centre = ModelUtil.xform_to(n, _lens).origin
	if with_rig and _xr:
		# the window on the glass (see LensView): only in the headset, where the Foresight overlay is hidden from the main eyes
		_lens_view = LensView.new()
		_lens_view.name = "LensView"
		add_child(_lens_view)
		_lens_view.setup(_lens, _lens_centre, Vector2(0.066, 0.098))


func lens_grip_position() -> Vector3:
	return _lens.global_transform * _lens_grip if _lens else Vector3.INF


func hand_pressed(h: GameHand) -> void:
	if _cutscene:
		# the first-rewind cutscene: nothing can be pressed, grabbed, poked or turned until the glass turns; once the story
		# is told, only the tray hourglass answers (held for FAST_HOLD, see _tick_rim)
		if _cutscene_glass_wait and h == _mouse_hand:
			_press(h.ray_origin(), h.ray_dir())
		elif _cutscene_glass_wait and _fast_glass != null and _fast_glass.is_visible_in_tree() 				and _on_tray_hourglass(h.touch_point()):
			_fast_pending[h] = 0.0
			snd("pinch")
		return
	## A pinch or grasp near the lens grip, a request prop or a spell token picks it up; anywhere else (or while a
	## tower, Sell or a spell is armed) it presses what the ray points at.
	if press_override.is_valid() and press_override.call(h.touch_point(), h.ray_origin(), h.ray_dir()):
		return
	if asleep:
		return
	var tp := h.target_point()  # small targets follow the visible pinch; dragging still follows the preferred aim pose
	if ledger and ledger.open:
		if ledger.quit_hit_point(tp, 0.05):
			quit_game()
			return
		var qp := ledger.quest_hit_point(tp, 0.05)
		if _point_request(qp):
			return
		var side := ledger.page_hit_point(tp, 0.05)
		if side != 0:
			ledger.turn(side)
			return
		if ledger.near_open_book(tp, 0.08):
			return  # a tap on the spine or during turn cooldown must not fall through to a ray press on the other page
	if _slip_takes(tp) and point_active_quest():
		return
	var glass_d := tp.distance_to(_fast_glass.global_position + Vector3(0, 0.03, 0)) if _fast_glass != null and _fast_glass.is_visible_in_tree() else INF
	var compass_d := tp.distance_to(_board_compass.global_position) if _board_compass != null and _board_compass.is_visible_in_tree() else INF
	var lens_d := _lens_grab_distance(h)
	if _tray and _held_card == null:
		var cd := _tray.card_near(tp, card_reach())
		# The tray's own wood (outside a card's face) takes the whole tray: a pinch within TRAY_GRAB_PAD of the base
		# grabs it unless the point is on a card's face (within half a card's height of its centre), where the card keeps priority.
		if h != _mouse_hand and _tray_hand == null and _held_spell_cards.is_empty() and _tray.visible \
				and (_tray.body_distance(tp) <= reach(GameConfig.TRAY_GRAB_PAD) or _tray.handle_distance(tp) <= reach(GameConfig.TRAY_HANDLE_GRAB)) \
				and (cd == null or cd.global_position.distance_to(tp) > Card3D.H / 2.0) \
				and not _on_tray_hourglass(tp) and not _on_tray_compass(tp) and not _on_tray_lens(h):
			_tray_grab(h)
			return
		var card_d := cd.global_position.distance_to(tp) if cd else INF
		if cd and not (_on_tray_hourglass(tp) and glass_d < card_d) \
				and not (_on_tray_compass(tp) and compass_d < card_d) \
				and not (not placing() and _on_tray_lens(h) and lens_d < card_d) \
				and _grab_card(cd, h):
			_hand_log(h, "target card:%s" % cd.data.get("id", "unknown"))
			return
	if not placing():
		if _on_tray_lens(h) and not (_on_tray_hourglass(tp) and glass_d <= lens_d) \
				and not (_on_tray_compass(tp) and compass_d <= lens_d):
			_lens_hand = h
			return
		if grab_request(request_near(tp), h):
			return
		var tok := spells.token_near(h.global_position) if phase == Phase.NIGHT and _held_spell == "" else ""
		if tok != "" and spells.is_ready(tok):
			_held_spell = tok
			_held_spell_hand = h
			return
	if _on_tray_hourglass(tp):
		if tutorial_spotlight in ["cards", "rim", "board", "lens", "tray", "zoom", "ledger"]:
			_show_toast("Finish the current tutorial step first.")
			return
		if h == _mouse_hand:
			toggle_fast()
		else:
			_fast_pending[h] = 0.0  # held for GameConfig.FAST_HOLD, then it hurries the day (see _tick_rim)
			_show_toast("Hold to hurry the day")
		return
	if _on_tray_compass(tp):
		if h == _mouse_hand:
			cycle_board_scale()
		else:
			_compass_pending[h] = 0.0
			_show_toast("Tap to resize · Hold to recenter")
		return
	if life and not placing():
		var nearest_v: Villager = null
		var nearest_d := reach(GameConfig.TOUCH_REACH)
		for v in life.villagers:  # a pinch right at the nearest villager (arm's reach, no ray needed)
			if not v.visible:
				continue
			var d := tp.distance_to(v.global_position + Vector3(0, 0.035, 0))
			if requests.any(func(r): return is_instance_valid(r) and not r.accepted and not r.done and r.asker() == v):
				d -= 0.02  # in a crowd the waving asker wins the tap
			if d < nearest_d:
				nearest_d = d
				nearest_v = v
		if nearest_v:
			_hand_log(h, "target villager:%s" % nearest_v.name)
			tap_villager(nearest_v)
			return
	if not placing():
		var pq := _find_prayer_asker(tp, Vector3.ZERO, reach(GameConfig.TOUCH_REACH))
		if pq:
			_hand_log(h, "target prayer:%s" % pq.name)
			tap_villager(pq)
			return
	if not placing() and phase == Phase.DAY and h != _mouse_hand:
		for t in towers:  # a pinch right on a built tower, held: it is crushed back into faith
			var d := tp - t.global_position
			if Vector2(d.x, d.z).length() <= GameConfig.CELL * 1.1 and d.y > -0.01 and d.y <= 0.16:
				crush_start(t, h, tp)  # crush_step measures the drift from this same touch point
				return
	if not placing() and on_rim(tp) and Time.get_ticks_msec() >= _settle_until:
		if h == _mouse_hand:
			mouse_rim_begin(get_viewport().get_mouse_position().x)  # a plain click without a drag turns nothing
			snd("grab")
		elif GameConfig.RIM_HOLD <= 0.0:
			_rim_hands.append(h)
			_rim_anchor()
			snd("grab")
		else:
			_rim_pending[h] = 0.0
			snd("pinch")
		return
	if h != _mouse_hand and not placing():
		for o in _free_pinch:
			if Time.get_ticks_msec() >= _settle_until and is_instance_valid(o) and o != h and not o.is_lost() and o.is_pressing() and o.touch_point().distance_to(h.touch_point()) <= GameConfig.ZOOM_START_GAP:
				_zoom_hands = [o, h]
				_zoom_d0 = o.touch_point().distance_to(h.touch_point())
				_zoom_start = board.global_transform
				_zoom_head = _eye()
				_zoom_d = _zoom_d0
				_free_pinch.clear()
				_show_toast("Zoom: spread your hands to bring the island closer, bring them together to send it back.")
				_active_hand = null  # the first hand now belongs to the zoom, not to a ray drag
				snd("grab")
				return
		if _board_cell_at(h.ray_origin(), h.ray_dir()).x < 0:
			_free_pinch.append(h)  # only a pinch aimed off the island can become a zoom, so it never also builds or casts
	_active_hand = h
	snd("pinch")
	_press(h.ray_origin(), h.ray_dir())


func _hand_log(h: GameHand, event: String) -> void:
	if GameConfig.VERBOSE_XR_LOG or OS.is_stdout_verbose():
		print("[hand] %s %s" % [h.name, event])


func _grab_card(cd: Card3D, h: GameHand) -> bool:
	## Returns true when the pinch was used on this card (even if it could not be taken, so it never also presses
	## something behind it).
	var id: String = cd.data.get("id", "")
	match cd.data.get("kind", ""):
		"tower":
			if phase != Phase.DAY:
				return true
			if faith < GameConfig.TOWERS[id]["cost"] or at_max(id):
				snd("invalid")
				last_message = "Not enough faith for %s." % with_indefinite_article(GameConfig.TOWERS[id]["name"]) if faith < GameConfig.TOWERS[id]["cost"] \
					else "You already have the most %s towers the island holds." % GameConfig.TOWERS[id]["name"]
				_refresh_ui()
				return true
			select(id)
		"spell":
			if phase != Phase.NIGHT:
				return true
			if _held_spell_cards.has(h):
				return true  # this hand already holds its one spell
			if not spells.is_ready(id):
				snd("invalid")
				last_message = "%s is still cooling down (%d s)." % [GameConfig.SPELLS[id]["name"], ceili(spells.cooldown[id])]
				_refresh_ui()
				return true
		_:
			# an ability offer: picking it up is choosing it
			choose_card(_tray.cards.find(cd))
			return true
	snd("pinch")
	if cd.data.get("kind", "") == "spell":
		_held_spell_cards[h] = cd
	else:
		_held_card = cd
		_held_card_hand = h
	cd.lift(_eye())
	return true


func _eye() -> Vector3:
	var cam: Camera3D = _xr_cam if _xr and _xr_cam else _camera
	return cam.global_position if cam else Vector3(0, 1.4, 0.6)


func on_rim(world: Vector3) -> bool:
	## Is this point on the table's rim: just outside the island's edge, near its height?
	var l := board.to_local(world)
	var m := maxf(absf(l.x), absf(l.z))
	return m >= HALF - 0.01 and m <= HALF + GameConfig.RIM_WIDTH and l.y >= -0.12 and l.y <= 0.08


func _rim_anchor() -> void:
	_rim_start = board.global_transform
	_rim_p0.clear()
	for h in _rim_hands:
		_rim_p0.append(h.touch_point())  # the same point on_rim tested and _tick_rim follows


static func rim_transform(start: Transform3D, p0: Array[Vector3], p: Array[Vector3], yaw := 0.0) -> Transform3D:
	## The board after a rim grip. One hand: Lazy-Susan spin around the board's centre from sweeping tangentially in XZ
	## (`yaw`, radians) plus translation when pulled/pushed. Two hands: midpoint, turn and resize within GameConfig.BOARD_SCALE.
	if p.size() == 1:
		return Transform3D(Basis(Vector3.UP, yaw), p[0]) * Transform3D(Basis.IDENTITY, -p0[0]) * start
	var a0 := p0[1] - p0[0]
	var a := p[1] - p[0]
	var d0 := Vector2(a0.x, a0.z)
	var d := Vector2(a.x, a.z)
	var turn := 0.0 if d0.length() < 0.01 or d.length() < 0.01 else -d0.angle_to(d)
	var s0 := start.basis.get_scale().x
	var k := clampf(s0 * (a.length() / maxf(a0.length(), 0.01)), GameConfig.BOARD_SCALE.x, GameConfig.BOARD_SCALE.y) / s0
	var mid0 := (p0[0] + p0[1]) / 2.0
	var mid := (p[0] + p[1]) / 2.0
	return Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * k), mid) * Transform3D(Basis.IDENTITY, -mid0) * start


static func rim_one_hand_yaw(center: Vector3, p0: Vector3, p: Vector3) -> float:
	## Tangential Lazy-Susan spin around the board's centre from sweeping the gripped rim handle in XZ.
	var v0 := Vector2(p0.x - center.x, p0.z - center.z)
	var v1 := Vector2(p.x - center.x, p.z - center.z)
	return 0.0 if v0.length() < 0.05 or v1.length() < 0.05 else -v0.angle_to(v1)


static func seated_board_transform(head_pos: Vector3, head_forward: Vector3) -> Transform3D:
	## Initial seated placement: centred directly in front of the player at eye_y - SEATED_BOARD_DROP and 0.8x scale.
	var f := Vector3(head_forward.x, 0.0, head_forward.z)
	f = f.normalized() if f.length() > 0.05 else Vector3(0.0, 0.0, -1.0)
	var yaw := atan2(-f.x, -f.z)
	var y := clampf(head_pos.y - GameConfig.SEATED_BOARD_DROP, GameConfig.BOARD_MIN_Y, GameConfig.BOARD_MAX_Y)
	var pos := Vector3(head_pos.x + f.x * GameConfig.SEATED_BOARD_DIST, y, head_pos.z + f.z * GameConfig.SEATED_BOARD_DIST)
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * GameConfig.SEATED_BOARD_SCALE), pos)


static func board_clamp(board_xf: Transform3D, head_pos: Vector3) -> Transform3D:
	## Keeps the board inside comfortable seated height and arm reach relative to the headset.
	var out := board_xf
	var max_y := maxf(GameConfig.BOARD_MIN_Y, minf(GameConfig.BOARD_MAX_Y, head_pos.y - 0.18))
	out.origin.y = clampf(out.origin.y, GameConfig.BOARD_MIN_Y, max_y)
	var flat := Vector2(out.origin.x - head_pos.x, out.origin.z - head_pos.z)
	var d := flat.length()
	if d < 0.001:
		flat = Vector2(0.0, -GameConfig.BOARD_MIN_DIST)
	elif d < GameConfig.BOARD_MIN_DIST:
		flat = flat / d * GameConfig.BOARD_MIN_DIST
	elif d > GameConfig.BOARD_MAX_DIST:
		flat = flat / d * GameConfig.BOARD_MAX_DIST
	out.origin.x = head_pos.x + flat.x
	out.origin.z = head_pos.z + flat.y
	return out


func mouse_rim_begin(x: float) -> void:
	_mouse_rim = true
	_mouse_rim_x0 = x
	_mouse_rim_yaw0 = board.rotation.y


func mouse_rim_drag(x: float) -> void:
	## Desktop: while the button is held on a rim handle the table's yaw follows the mouse horizontally.
	if not _mouse_rim:
		return
	board.rotation.y = _mouse_rim_yaw0 + (x - _mouse_rim_x0) * MOUSE_RIM_RAD_PER_PX
	_update_compass_label()


func _tick_rim(delta := 0.0) -> void:
	for h in _fast_pending.keys():
		if not is_instance_valid(h) or _fast_glass == null or h.touch_point().distance_to(_fast_glass.global_position + Vector3(0, 0.03, 0)) > reach(GameConfig.TOUCH_REACH * 2.0):
			_fast_pending.erase(h)  # let go or slid away
			continue
		_fast_pending[h] += delta
		if _fast_pending[h] >= GameConfig.FAST_HOLD:
			_fast_pending.erase(h)
			if _cutscene_glass_wait:
				_cutscene_turn_glass()
			else:
				toggle_fast()
	for h in _compass_pending.keys():
		if not is_instance_valid(h) or not _on_tray_compass(h.target_point()):
			_compass_pending.erase(h)
			continue
		_compass_pending[h] += delta
		if _compass_pending[h] >= GameConfig.COMPASS_RESET_HOLD:
			_compass_pending.erase(h)
			recenter_seated_board()
	for h in _rim_pending.keys():
		if not is_instance_valid(h):
			_rim_pending.erase(h)
			continue
		_rim_pending[h] += delta
		if _rim_pending[h] >= GameConfig.RIM_HOLD and on_rim(h.touch_point()):
			_rim_pending.erase(h)
			_rim_hands.append(h)
			_rim_anchor()
			snd("grab")
		elif _rim_pending[h] >= GameConfig.RIM_HOLD:
			_rim_pending.erase(h)  # slid off the rim while holding: nothing happens
	if not _rim_handles.is_empty():
		var grabbed := not _rim_hands.is_empty()
		var hovered := false
		if not grabbed and with_rig and not asleep and not placing():
			for h in _hands:
				if is_instance_valid(h) and not h.is_lost() and h != _mouse_hand and on_rim(h.target_point()):
					hovered = true
					break
		var rmat := _rim_handles[0].material_override as StandardMaterial3D
		if rmat:
			var rim_pulse := 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
			rmat.emission_energy_multiplier = 0.75 if grabbed else (0.42 if hovered else (rim_pulse if tutorial_spotlight == "rim" else 0.18))
	if _zoom_hands.size() == 2 and is_instance_valid(_zoom_hands[0]) and is_instance_valid(_zoom_hands[1]):
		if not _zoom_hands[0].is_lost() and not _zoom_hands[1].is_lost():  # a hand the tracker lost holds the island still
			var raw := _zoom_hands[0].touch_point().distance_to(_zoom_hands[1].touch_point())
			raw = _zoom_d0 + signf(raw - _zoom_d0) * maxf(absf(raw - _zoom_d0) - GameConfig.ZOOM_DEADZONE, 0.0)
			_zoom_d = lerpf(_zoom_d, raw, 1.0 - exp(-GameConfig.ZOOM_SMOOTH * get_process_delta_time()))
			var zx := zoom_board_transform(_zoom_start, _zoom_head, _zoom_d0, _zoom_d, _board_home if _board_home_set else Vector3.INF)
			board.global_transform = board_clamp(zx, _eye()) if _xr else zx
	if _rim_hands.is_empty():
		return
	var p: Array[Vector3] = []
	for h in _rim_hands.slice(0, 2):
		p.append(h.touch_point())
	var p0: Array[Vector3] = _rim_p0.slice(0, 2)
	var one_yaw := rim_one_hand_yaw(_rim_start.origin, p0[0], p[0]) if p.size() == 1 else 0.0
	var xf := rim_transform(_rim_start, p0, p, one_yaw)
	board.global_transform = board_clamp(xf, _eye()) if _xr else xf
	_update_compass_label()


func hand_released(h: GameHand, cancelled := false) -> void:
	_free_pinch.erase(h)
	## cancelled: the hand lost tracking mid-pinch (GameHand.cancelled). Nothing is built, cast, delivered or moved.
	if h == _mouse_hand and _mouse_rim:
		_mouse_rim = false
		snd("release")
		return
	if _fast_pending.has(h):
		_fast_pending.erase(h)
		return
	if _compass_pending.has(h):
		_compass_pending.erase(h)
		if not cancelled:
			cycle_board_scale()
		return
	if _zoom_hands.has(h):
		_zoom_hands.clear()  # the table stays where the zoom left it, also when tracking was lost
		snd("release")
		return
	if _rim_pending.has(h):
		_rim_pending.erase(h)
		return
	if _tray_hand == h:
		# tracking lost mid-move (sykeriin, 2026-11-17: hand loss "isn't handled well"): the tray stays where it was, no snap back
		_tray_hand = null
		snd("release")
		return
	if _rim_hands.has(h):
		_rim_hands.erase(h)  # tracking lost mid-move: the island stays where it was, no snap back (sykeriin, 2026-11-17)
		_rim_anchor()
		_update_compass_label()
		snd("release")
		return
	if not _crush.is_empty() and (_crush["hand"] == h or (_crush["hand"] == null and h == _mouse_hand)):
		crush_cancel()
	if _held_spell_cards.has(h):
		var cd: Card3D = _held_spell_cards[h]
		var id: String = cd.data.get("id", "")
		var local := board.to_local(h.touch_point())
		_held_spell_cards.erase(h)
		spells.hide_aim()
		if cancelled:
			cd.release_to_home()
			_hand_log(h, "release card:%s cancelled" % id)
			return
		if absf(local.x) <= HALF and absf(local.z) <= HALF:
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			var cast := cast_spell(id, local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
			_hand_log(h, "release card:%s %s" % [id, "cast" if cast else "rejected"])
		else:
			_hand_log(h, "release card:%s off-board" % id)
		cd.release_to_home()
		return
	if _held_card and _held_card_hand == h:
		var cd := _held_card
		var id: String = cd.data.get("id", "")
		var local := board.to_local(h.touch_point())  # the same point _update_held drew the ghost at
		_held_card = null
		_held_card_hand = null
		spells.hide_aim()
		if cancelled:
			if cd.data.get("kind", "") == "tower":
				select("")
			cd.release_to_home()
			_hand_log(h, "release card:%s cancelled" % id)
			return
		if cd.data.get("kind", "") == "tower":
			var cell := Vector2i(-1, -1)
			var built := false
			if absf(local.x) <= HALF and absf(local.z) <= HALF:
				cell = NavGrid.local_to_cell(local - Vector3(GameConfig.CELL / 2.0, 0, GameConfig.CELL / 2.0)) \
					.clamp(Vector2i.ZERO, Vector2i(GameConfig.SIZE - 2, GameConfig.SIZE - 2))
			if cell.x >= 0:
				built = try_build(id, cell)
			_hand_log(h, "release card:%s %s cell:%s" % [id, "built" if built else "rejected", str(cell)])
			select("")  # built or not, this card is done: no armed tower and no grid left behind
		elif absf(local.x) <= HALF and absf(local.z) <= HALF:
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			var cast := cast_spell(id, local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
			_hand_log(h, "release card:%s %s" % [id, "cast" if cast else "rejected"])
		else:
			_hand_log(h, "release card:%s off-board" % id)
		cd.release_to_home()
		return
	if _held_spell != "" and _held_spell_hand == h:
		var id := _held_spell
		var local := board.to_local(h.global_position)
		_held_spell = ""
		_held_spell_hand = null
		spells.hide_aim()
		spells.tokens[id].position = spells.tokens[id].get_meta("home")
		if not cancelled and absf(local.x) <= HALF and absf(local.z) <= HALF:
			var b: Dictionary = GameConfig.SPELLS["boulder"]
			cast_spell(id, local, clampf(local.y / GameConfig.CELL, b["min_height"], b["max_height"]))
		return
	if _held_req and _held_req_hand == h:
		if cancelled:
			_held_req.put_back()  # back home and no longer held, so the release below cannot finish it
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
		var sc := Basis.from_scale(Vector3.ONE * GameConfig.LENS_SCALE)
		var hold_at := _lens_hand.global_position
		var basis_held := Basis.IDENTITY
		if _xr_cam:
			# like a hand mirror: upright, the glass turned toward your eyes (the model's front is +Z)
			var to_eye := _xr_cam.global_position - hold_at
			to_eye.y = 0.0
			if to_eye.length() < 0.001:
				to_eye = Vector3.BACK
			var turn := Basis.looking_at(-to_eye.normalized(), Vector3.UP)  # -Z toward the far side, so +Z faces you
			var tilt := Basis(Vector3.RIGHT, -0.25)  # leaned back a little, so you look into it
			basis_held = turn * tilt
		else:
			basis_held = _lens_hand.global_transform.basis * Basis(Vector3.RIGHT, -PI / 2.0)
		_lens.global_transform = Transform3D(basis_held * sc, hold_at - basis_held * sc * _lens_grip)
		var up := hold_at.y > board.global_position.y + GameConfig.LENS_RAISE
		if up and _xr_cam and _lens_view:
			set_lens(true)  # every gap: the lens window crops to what you look at through the glass
		elif up and _xr_cam:
			set_lens(true, _xr_cam.global_position, -_xr_cam.global_transform.basis.z)
		elif up:
			set_lens(true)  # desktop: every gap
		else:
			set_lens(false)
	elif not _xr and Input.is_key_pressed(KEY_L) and phase == Phase.DAY:
		_lens.transform = _lens_rest.translated(Vector3(0, 0.12, -0.03)).scaled_local(Vector3.ONE * GameConfig.LENS_SCALE)
		set_lens(true)
	else:
		var lens_pulse := 1.0 + 0.09 * sin(Time.get_ticks_msec() * 0.007) if tutorial_spotlight == "lens" else 1.0
		_lens.transform = _lens_rest.scaled_local(Vector3.ONE * lens_pulse) if lens_pulse != 1.0 else _lens_rest
		if not _xr:
			set_lens(false)


func _mount_ui_rig() -> void:
	## 2026-11-10 (the user): the UI on the table was painful to reach. In the headset the buttons and the
	## messages float about 40 cm in front of you, a little below eye level, and turn with you when you look far away.
	_ui_rig = Node3D.new()
	_ui_rig.name = "UiRig"
	add_child(_ui_rig)
	var spots := {"sell": Vector3(-0.17, -0.40, -0.40), "night": Vector3(0.17, -0.40, -0.40),
		"restart": Vector3(0.17, -0.40, -0.40), "speed": Vector3(0.17, -0.40, -0.40)}
	for id in spots:
		if _buttons.has(id):
			var n: Node3D = _buttons[id]["node"]
			n.get_parent().remove_child(n)
			_ui_rig.add_child(n)
			n.position = spots[id]
			n.rotation_degrees = Vector3(-35, 0, 0)
	for l in [_hud, _msg]:
		if l:
			l.get_parent().remove_child(l)
			_ui_rig.add_child(l)
	if _hud:
		_hud.position = Vector3(0, 0.02, -0.62)
	if _msg:
		_msg.position = Vector3(0, -0.04, -0.62)


func _update_ui_rig(_delta: float) -> void:
	## 2026-11-11 (the user: "it should just be still, beside me"): the tray is placed ONCE, beside you, when the game
	## wakes, and then stays where it is. It is hidden on the title screen. Walk round the island and it stays put.
	if _ui_rig == null or _xr_cam == null:
		return
	if asleep:
		_ui_rig.visible = false
		_ui_placed = false
		return
	if not _ui_placed:
		var f := -_xr_cam.global_transform.basis.z
		_ui_rig.rotation.y = atan2(-f.x, -f.z)
		_ui_rig.global_position = _xr_cam.global_position
		_ui_rig.visible = true
		_ui_placed = true


static func tray_start_transform(board_xf: Transform3D, head: Vector3) -> Transform3D:
	## The tray's first pose (Siddharth 2026-11-12, seated play): along the board edge nearest the headset, TRAY_OUT
	## beyond it, TRAY_DROP under the board's top, facing out toward the player and tipped up TRAY_TILT_DEG.
	var half := HALF * board_xf.basis.get_scale().x
	var to_head := head - board_xf.origin
	to_head.y = 0.0
	to_head = to_head.normalized() if to_head.length() > 0.001 else Vector3(0, 0, 1)
	var n := Vector3(0, 0, 1)
	var best := -2.0
	for a in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var w: Vector3 = board_xf.basis * a
		w.y = 0.0
		w = w.normalized()
		if w.dot(to_head) > best:
			best = w.dot(to_head)
			n = w
	var right := (-n).cross(Vector3.UP)  # the player's right as they face the board
	var pos := board_xf.origin + n * (half + GameConfig.TRAY_OUT) + right * GameConfig.TRAY_SIDE * board_xf.basis.get_scale().x
	pos.y = board_xf.origin.y + GameConfig.TRAY_DROP
	var face := head - pos  # beside the near edge it turns toward the eyes, not straight out from the board
	face.y = 0.0
	var yaw := atan2(face.x, face.z) if face.length() > 0.05 else atan2(n.x, n.z)
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(GameConfig.TRAY_TILT_DEG)), pos)


static func flat_yaw(b: Basis) -> float:
	## Heading of a hand on the floor plane (its pointing axis, or its side axis when pointing straight up/down): no gimbal flip.
	var f := -b.z
	if Vector2(f.x, f.z).length() < 0.3:
		f = b.x.rotated(Vector3.UP, PI / 2.0)
	return atan2(-f.x, -f.z)


static func tray_turned_transform(start: Transform3D, pos: Vector3, turn: float) -> Transform3D:
	## The tray while a hand holds it by a handle (sykeriin, 2026-11-17: "same as the island"): it follows the hand and
	## turns by as much as the hand has turned since the grab, keeping its tilt; it stays put when let go.
	return Transform3D(Basis(Vector3.UP, start.basis.get_euler().y + turn) * Basis(Vector3.RIGHT, deg_to_rad(GameConfig.TRAY_TILT_DEG)), pos)


static func zoom_board_transform(start: Transform3D, head: Vector3, d0: float, d: float, home := Vector3.INF) -> Transform3D:
	## Two-hand zoom (sykeriin, 2026-11-17): spreading the hands brings the table closer, bringing them together pushes
	## it away; same size, same turn. ZOOM_GAIN metres of table travel per metre of change in hand spacing.
	var flat := Vector3(head.x - start.origin.x, 0.0, head.z - start.origin.z)
	if flat.length() < 0.001:
		return start
	var out := start
	var dir := flat.normalized()
	if home != Vector3.INF and d < d0:
		# Closing the hands (the user, 2026-11-18): the table glides back to where it was placed, however far the hands were
		# when the pinch began; hands (nearly) together = home. It never goes past home.
		var pulled := maxf((start.origin - home).dot(dir), 0.0)  # how far toward the head the table has been brought
		var t := clampf((d0 - d) / maxf(d0 - GameConfig.ZOOM_HOME_GAP, 0.04), 0.0, 1.0)
		out.origin -= dir * pulled * t
		return out
	out.origin += dir * (d - d0) * GameConfig.ZOOM_GAIN
	return out


static func tray_held_transform(start: Transform3D, touch: Vector3, off: Vector3, head: Vector3, from_yaw := NAN, weight := 1.0) -> Transform3D:
	## The tray while a hand holds it: it follows the touch point, keeps its tilt and yaws (eased, `weight` of the way
	## per call, no snap) to face the headset.
	var pos := touch + off
	var d := head - pos
	d.y = 0.0
	var yaw := atan2(d.x, d.z) if d.length() > 0.05 else start.basis.get_euler().y
	if not is_nan(from_yaw):
		yaw = lerp_angle(from_yaw, yaw, weight)
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(GameConfig.TRAY_TILT_DEG)), pos)


static func tray_clamp(pos: Vector3, board_xf: Transform3D) -> Vector3:
	## Technical safety: the tray stays between TRAY_MIN_Y and TRAY_MAX_Y, within TRAY_MAX_DIST of the board's middle,
	## and never ends up inside the island's body (it is pushed out of the nearest edge).
	var p := pos
	p.y = clampf(p.y, GameConfig.TRAY_MIN_Y, GameConfig.TRAY_MAX_Y)
	var flat := Vector3(p.x - board_xf.origin.x, 0.0, p.z - board_xf.origin.z)
	if flat.length() > GameConfig.TRAY_MAX_DIST:
		flat = flat.normalized() * GameConfig.TRAY_MAX_DIST
		p.x = board_xf.origin.x + flat.x
		p.z = board_xf.origin.z + flat.z
	var l := board_xf.affine_inverse() * p
	var lim := HALF + 0.06
	if maxf(absf(l.x), absf(l.z)) < lim and l.y > -0.25 and l.y < 0.22:  # may hover above the island (the start pose is over its near edge), never sink into it
		if absf(l.x) > absf(l.z):
			l.x = signf(l.x) * lim if l.x != 0.0 else lim
		else:
			l.z = signf(l.z) * lim if l.z != 0.0 else lim
		p = board_xf * l
	return p


func _head_valid() -> bool:
	## In the headset the first frames can report the head at the origin; the tray waits for a real pose.
	if _xr and _xr_cam:
		return _xr_cam.global_position.y > 0.3
	return true


func place_seated_board() -> void:
	if not _xr or _xr_cam == null or not _head_valid():
		return
	board.global_transform = seated_board_transform(_eye(), -_xr_cam.global_transform.basis.z)
	_board_placed = true
	_board_home = board.global_position
	_board_home_set = true
	_settle_until = Time.get_ticks_msec() + settle_ms
	_update_compass_label()


func _update_tray() -> void:
	## Placed once, when the game first wakes after app start; after that it stays where the player left it, through
	## new runs, loops, rewinds, day and night, and whatever happens to the island.
	if _tray == null or asleep:
		return
	if _xr and not _board_placed:
		if not _head_valid():
			return
		place_seated_board()
	if not _tray_placed:
		if not _head_valid():
			return  # retry every frame until the headset reports a real pose
		_tray.global_transform = tray_start_transform(board.global_transform, _eye())
		_tray_placed = true
		_settle_until = Time.get_ticks_msec() + settle_ms
	if _tray_hand != null:
		if not is_instance_valid(_tray_hand):
			_tray_hand = null
		else:
			# the tray follows the hand and eases round to face the headset (the wrist's turn was noisy and sent it the wrong way;
			# the user, 2026-11-18)
			var t := tray_held_transform(_tray_start, _tray_hand.touch_point(), _tray_off, _eye(), _tray.global_transform.basis.get_euler().y,
				1.0 - exp(-GameConfig.TRAY_YAW_EASE * get_process_delta_time()))
			t.origin = tray_clamp(t.origin, board.global_transform)
			_tray.global_transform = t


func _on_tray_hourglass(tp: Vector3) -> bool:
	return _fast_glass != null and _fast_glass.is_visible_in_tree() and tp.distance_to(_fast_glass.global_position + Vector3(0, 0.03, 0)) <= reach(GameConfig.TOUCH_REACH * 1.4)


func _on_tray_compass(tp: Vector3) -> bool:
	return _board_compass != null and _board_compass.is_visible_in_tree() and tp.distance_to(_board_compass.global_position) <= reach(GameConfig.TOUCH_REACH * 1.4)


func _lens_grab_distance(h: GameHand) -> float:
	if _lens == null or _lens_hand != null:
		return INF
	var grip := lens_grip_position()
	return minf(h.global_position.distance_to(grip), h.target_point().distance_to(grip))


func _on_tray_lens(h: GameHand) -> bool:
	return _lens_grab_distance(h) <= reach(GameConfig.LENS_GRAB_REACH)


func _update_compass_label() -> void:
	if _compass_label and board:
		_compass_scale = board.scale.x
		_compass_label.text = "%d%%" % roundi(_compass_scale * 100.0)


func cycle_board_scale() -> void:
	var steps := GameConfig.BOARD_SCALE_STEPS
	var cur := board.scale.x
	var idx := 0
	var best := INF
	for i in steps.size():
		var diff := absf(steps[i] - cur)
		if diff < best:
			best = diff
			idx = i
	var next_s: float = steps[(idx + 1) % steps.size()]
	var rot := board.global_basis.orthonormalized()
	board.global_basis = rot.scaled(Vector3.ONE * next_s)
	if _xr:
		board.global_transform = board_clamp(board.global_transform, _eye())
	if not _rim_hands.is_empty():
		_rim_anchor()
	_update_compass_label()
	_show_toast("Board %d%%" % roundi(next_s * 100.0))
	snd("pinch")


func recenter_seated_board() -> void:
	_rim_hands.clear()
	_rim_p0.clear()
	_rim_pending.clear()
	_zoom_hands.clear()
	_tray_hand = null
	var fwd := -_xr_cam.global_transform.basis.z if _xr_cam else Vector3(0.0, 0.0, -1.0)
	board.global_transform = seated_board_transform(_eye(), fwd)
	_board_placed = true
	_board_home = board.global_position
	_board_home_set = true
	if _tray:
		_tray.global_transform = tray_start_transform(board.global_transform, _eye())
		_tray_placed = true
	_update_compass_label()
	_show_toast("Board recentered")
	snd("grab")


func _tray_grab(h: GameHand) -> void:
	if Time.get_ticks_msec() < _settle_until:
		return
	_tray_hand = h
	_tray_start = _tray.global_transform
	_tray_off = _tray.global_position - h.touch_point()
	_tray_hand_yaw0 = flat_yaw(h.global_transform.basis)
	snd("grab")




func _tick_lens_window() -> void:
	## The glass shows the future only while the lens is up and it is day; the window camera follows your eye.
	if _lens_view == null or _xr_cam == null:
		return
	var on := foresight.showing and phase == Phase.DAY
	_lens_view.set_active(on)
	if on:
		_lens_view.aim(_xr_cam.global_position, _lens.global_transform * _lens_centre)


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
	var n := "Fall night" if night == fall_night() else "%s %d" % [phase_name, night + 1]
	if phase == Phase.CARDS or phase == Phase.DONE:
		n = phase_name
	var t := "Loop %d   |   %s   |   Faith %d   |   Houses %d/%d" % [loop + 1, n, faith, standing_houses().size(), houses.size()]
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
	if _faith_label:
		_faith_label.text = str(faith)
	if _fast_label:
		_fast_label.text = "2x" if is_fast() else ""
	if _msg_serial != _hud_toast_serial and not asleep:
		_hud_toast_serial = _msg_serial
		_show_toast(last_message)
	if _shrine_light and not _cutscene:  # the cutscene dims the statue's light itself
		_shrine_light.light_energy = 0.15 + clampf(float(faith) / 400.0, 0.0, 1.0) * 0.35


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
			"fast":
				pass
			"compass":
				c = Color8(0x5B, 0x29, 0x20)
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
					b["label"].text = (CardData.ending(o["id"])["text"] if ending_choice else Cards.describe(o["id"], o["rarity"])) + "\n\n" + hint
					c = [Color8(0xE6, 0xD8, 0xBC), Color8(0xF0, 0xA4, 0x50), Color8(0xE0, 0x50, 0x3A)][o["rarity"]]
			_:
				b["node"].visible = day
				var cfg: Dictionary = GameConfig.TOWERS[id]
				b["label"].text = "%s\n%d/%d placed" % [cfg["name"], cfg["max"], cfg["max"]] if at_max(id) \
					else "%s\n%d faith" % [cfg["name"], cfg["cost"]]
				if not day or faith < GameConfig.TOWERS[id]["cost"] or at_max(id):
					c = Color8(0x8A, 0x84, 0x7C)
				elif selected == id:
					c = Color8(0xF0, 0xB0, 0x4A)
		if _tray and (GameConfig.TOWER_ORDER.has(id) or id.begins_with("spell_") or id.begins_with("card")):
			b["node"].visible = false  # the physical cards take these signs' place
		if _tray and id in ["sell", "night", "speed"]:
			b["node"].visible = false  # 2026-11-11: no slabs. Selling is a held pinch, the day ends by itself, speed is the tray hourglass
		if id == "fast":
			b["node"].visible = phase == Phase.DAY or phase == Phase.NIGHT
		elif id == "compass":
			b["node"].visible = true
		if b["hover"]:
			c = c.lightened(0.25)
		b["mat"].albedo_color = c
	if _tray:
		for sid in spells.tokens:
			spells.tokens[sid].visible = false  # a spell is a card now, not a token on the table
		_refresh_tray()


func _place_tray_bits(n_cards: int) -> void:
	var half_w := n_cards * CardTray.CARD_SPACING / 2.0  # the cards; the tray runs CardTray.ENDS further each side
	if _faith_seal:
		_faith_seal.position = Vector3(-half_w - 0.050, 0.012, 0.01)
	if _board_compass:
		_board_compass.position = Vector3(-half_w - 0.118, 0.008, 0.0)
	if _fast_glass:
		_fast_glass.position = Vector3(half_w + 0.048, 0.0, -0.005)
	if _lens and _lens.get_parent() == _tray:
		_lens_rest = _tray_lens_rest(half_w)
		if _lens_hand == null:
			_lens.transform = _lens_rest


func _refresh_tray() -> void:
	## Tower cards by day, spell cards at night, the ability offers after a loop. The tray is rebuilt only when what
	## it shows changes; otherwise each card just lights or dims (can you use it now?).
	var key := ""
	match phase:
		Phase.DAY:
			key = "day"
		Phase.NIGHT:
			key = "night"
		Phase.CARDS:
			key = "offers%d_%s" % [loop, str(offers)]
	if key != _tray_key:
		_tray_key = key
		var list: Array[Dictionary] = []
		match phase:
			Phase.DAY:
				for id: String in GameConfig.TOWER_ORDER:
					list.append(CardData.tower(id))
			Phase.NIGHT:
				for id: String in GameConfig.SPELL_ORDER:
					list.append(CardData.spell(id))
			Phase.CARDS:
				for o in offers:
					list.append(CardData.ending(o["id"]) if ending_choice else CardData.ability(o["id"], o["rarity"]))
		if _held_card:  # the phase changed under a held card: put it down cleanly
			spells.hide_aim()
			if phase != Phase.DAY:
				select("")
		_held_card = null
		_held_card_hand = null
		_held_spell_cards.clear()
		_tray.set_cards(list)
		_place_tray_bits(list.size())
	_refresh_card_availability()


func set_tutorial_spotlight(mode: String) -> void:
	## Highlights only the active tutorial affordance on the tray or board; "" restores normal state.
	tutorial_spotlight = mode
	if _fast_glass and mode != "hourglass":
		_fast_glass.scale = Vector3.ONE
	if _tray:
		_refresh_card_availability()


func _refresh_card_availability() -> void:
	## Cheap state-only update used every night tick; does not rebuild card data or allocate tray lists.
	if tutorial_spotlight in ["rim", "board", "lens", "tray", "zoom", "ledger", "hourglass"]:
		for c in _tray.cards:
			c.set_glow(false)
		return
	for c in _tray.cards:
		var id: String = c.data.get("id", "")
		match c.data.get("kind", ""):
			"tower":
				c.set_glow(faith >= GameConfig.TOWERS[id]["cost"] and not at_max(id))
			"spell":
				c.set_glow(spells.is_ready(id))
			_:
				c.set_glow(true)


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
			lighting.stop_sequence()  # a night that ends within the dusk must not fall back into night light
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


static func configure_xr_viewport(vp: Viewport, xr: Object = null) -> void:
	## Enable XR rendering and explicit OpenXR foveated VRS on the active viewport.
	if vp:
		vp.use_xr = true
		# Foveation fully off (the user, 2026-11-17): no VRS map and runtime level 0.
		vp.vrs_mode = Viewport.VRS_DISABLED
	if xr != null and "foveation_level" in xr:  # the Quest renders the edges of each eye cheaper (the user: it lags a lot)
		xr.set("foveation_level", XR_FOVEATION_LEVEL)
		xr.set("foveation_dynamic", false)


func _init_xr() -> bool:
	var xr := XRServer.find_interface("OpenXR")
	if GameConfig.FORCE_XR and (xr == null or not xr.is_initialized()):
		print("[game] XR rig forced without OpenXR (replay)")
		return true
	if xr and xr.is_initialized():
		configure_xr_viewport(get_viewport(), xr)
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
		if OS.get_environment("AETERNA_WATCH") == "1" and ResourceLoader.exists("res://scripts/game/watch_link.gd"):
			var watch_script := load("res://scripts/game/watch_link.gd") as Script
			if watch_script:
				var watch: Node = watch_script.new()  # the Galaxy Watch drives the mouse hand (scripts/game/watch_link.gd)
				watch.name = "watch_link"
				add_child(watch)
		return
	var origin := XROrigin3D.new()
	add_child(origin)
	_xr_origin = origin
	_palm = XRController3D.new()
	_palm.tracker = "left_hand"
	_palm.pose = &"grip"
	_palm.name = "left_palm"
	origin.add_child(_palm)
	_palm.button_pressed.connect(func(action: String):
		if action == "by_button" or action == "menu_button":
			toggle_ledger())
	var cam := XRCamera3D.new()
	cam.position = Vector3(0, 1.2, 0)  # seated eye height
	cam.near = 0.06
	cam.far = 30.0
	cam.cull_mask = 0xFFFFF & ~LensView.OVERLAY_LAYER  # Foresight's drawings are for the lens window only
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
		c.cancelled.connect(hand_released.bind(true))  # tracking lost mid-pinch: drop everything back, play nothing
		if easy_reach:
			c.make_bubble(reach(GameConfig.REQUEST_GRAB_REACH))
		_hands.append(c)
	_active_hand = _hands[1]
	if GameConfig.RECORD_INPUT:
		recorder = InputRecorder.new()
		recorder.name = "InputRecorder"
		add_child(recorder)
		phase_changed.connect(func(ph: int): recorder.mark("phase", {"phase": ph}))
		tower_placed.connect(func(kind: String, at: Vector3): recorder.mark("tower", {"kind": kind, "at": [at.x, at.y, at.z]}))
