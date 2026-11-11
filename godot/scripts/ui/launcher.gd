class_name Launcher
extends Node
## The start of the game (docs/STORY.md, scene by scene). The real island floats asleep under fireflies with the
## gilt title above it and three wooden plaques on the table: Wake, The Tale, Hands / Controllers. Wake plays the
## opening narration on parchment, then wakes the game and walks the player through the first day with small hints
## (pick up a card, set it on the grass, help someone, tap a villager, start the night).
## It owns no game rules: it only drives Game's public state (asleep, press_override) and reads it.

const AUTO_START := 6.0  # s of title before the story begins on its own
const GOLD := Color("F2B630")  # rarity_gold
const GLOW := Color("FFD45A")  # fire_yellow
const OUTLINE := Color("5B2920")  # wood_dark
const TALE := "You are a very small god. Your whole world is this island: a meadow, twelve people, a well and a shrine.\n\nYour Veil, woven from their faith, keeps the Dark Wood out. But Skotos, a god the world forgot, has cursed it: every nightfall, it breaks.\n\nPlace towers. Cast your spells. Help your people. And if the worst happens... you are a god. You can try again."
const HINTS := [
	"Pick up a card from the tray.",
	"Set it on the grass and let go.",
	"Someone is praying. Find the gold mote and tap them.",
	"Tap a villager to hear their thoughts.",
	"Night falls on its own. Hold the hourglass to hurry the day.",
]

static var prefer_controllers := false  # placeholder for the Hands / Controllers plaque

var game: Game
var _title: Node3D
var _plaques := {}  # id -> Plaque
var _panel: StoryPanel
var _state := "title"  # title / tale / narrating / playing
var _skip := false
var _step := 0
var _step_time := 0.0
var _card: TitleCard
var _t := 0.0
var _hint_root: Node3D
var _hint_card: TitleCard
var _auto_at := -1.0  # when the story starts by itself (the title shows a few seconds first)
var _xr_rig: Node3D  # headset: the plaques float in front of you (placed once), not on the island's front edge


func _ready() -> void:
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
	var tale := Plaque.make("The Tale")
	tale.position = Vector3(0.3, 0.03, half + 0.1)
	tale.rotation_degrees.x = -50
	tale.scale = Vector3.ONE * 0.8
	_title.add_child(tale)
	_plaques["tale"] = tale
	if game._xr:
		_xr_rig = Node3D.new()
		_xr_rig.name = "TitleRig"
		_xr_rig.visible = false  # shown when the headset's pose is known (_place_xr_rig)
		game.add_child(_xr_rig)
		for id in ["wake", "tale"]:
			var pl: Node3D = _plaques[id]
			pl.get_parent().remove_child(pl)
			_xr_rig.add_child(pl)
			pl.rotation_degrees = Vector3(-30, 0, 0)
		(_plaques["wake"] as Node3D).position = Vector3(-0.07, 0, 0)
		(_plaques["wake"] as Node3D).scale = Vector3.ONE * 1.5
		(_plaques["tale"] as Node3D).position = Vector3(0.20, -0.03, 0.02)
		(_plaques["tale"] as Node3D).scale = Vector3.ONE * 0.85
	_panel = StoryPanel.make(game.board, Vector3(0, 0.34, 0.15))
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


func _process(delta: float) -> void:
	_t += delta
	if _auto_at >= 0.0 and _state == "title":  # the whole story starts by itself; a press on Wake just starts it sooner
		_auto_at -= delta
		if _auto_at < 0.0:
			_press_plaque("wake")
	elif _state != "title":
		_auto_at = -1.0
	if _state != "playing":
		_place_xr_rig()
	if _state != "playing":
		for id in _plaques:
			var p: Plaque = _plaques[id]
			if not is_instance_valid(p):
				continue
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
	elif game.loop == 0 and _step < HINTS.size():
		_tutorial(delta)


func _on_press(world: Vector3, origin: Vector3, dir: Vector3) -> bool:
	## Game asks us first. true = we used the press.
	if _state == "playing":
		return false
	if _state == "narrating":
		_skip = true
		return true
	var touched := ""  # a fingertip on a plaque beats the ray; the nearest plaque wins when the pads overlap
	var best := INF
	for id in _plaques:
		var p: Plaque = _plaques[id]
		if p.hit_point(world, _touch_pad()) and p.global_position.distance_to(world) < best:
			best = p.global_position.distance_to(world)
			touched = id
	if touched == "":
		for id in _plaques:
			if (_plaques[id] as Plaque).hit_ray(origin, dir):
				touched = id
				break
	if touched != "":
		_press_plaque(touched)
		return true
	if _state == "tale":
		_state = "title"
		_close_panel()
	return true  # nothing else can be pressed while the title is up


func _touch_pad() -> float:
	## How far outside a plaque a press still counts: wider in the real headset (GameConfig.XR_PLAQUE_PAD).
	return GameConfig.XR_PLAQUE_PAD if game._xr and not game.easy_reach else 0.012


func _press_plaque(id: String) -> void:
	game.snd("menu_open")
	match id:
		"wake":
			_wake()
		"tale":
			if _state == "tale":
				_state = "title"
				_close_panel()
			else:
				_state = "tale"
				_show_panel(TALE)


func _show_panel(line: String) -> void:
	## The title steps aside while a parchment is open.
	if is_instance_valid(_card):
		_card.visible = false
	_panel.position = Vector3(0, 0.3, 0.1)
	_panel.show_text(line)


func _close_panel() -> void:
	_panel.hide_panel()
	if is_instance_valid(_card):
		_card.visible = true


func _wake() -> void:
	## The opening, played on the island itself (the user, 2026-11-10: "explain the story piece by piece in an
	## in-game rendered animation"). Each beat is a line of gilded words and something that happens to the real
	## island: dawn, the people waking, their faith rising into the Veil, the dusk, Skotos's crack, the Veil
	## shattering, the hourglass turning time back, dawn again. Any press skips it.
	_state = "narrating"
	_skip = false
	_panel.hide_panel()
	_title.visible = false
	if _xr_rig:
		_xr_rig.queue_free()
		_xr_rig = null
	var v: VeilDome = game.veil
	# The opening is a puppet theatre of its own in front of you (scripts/ui/opening_stage.gd), not the island acted out.
	game.board.visible = false
	if v:
		v.snap(0.0, 0.0)
	var stage := OpeningStage.new()
	stage.game = game
	stage.name = "OpeningStage"
	game.add_child(stage)
	var cam: Camera3D = game._xr_cam if game._xr_cam else get_viewport().get_camera_3d()
	stage.place(cam, game.board.global_position + Vector3(0, 0.5, 1.0))
	await stage.play()
	_skip = stage._skipped
	stage.queue_free()
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
	game.asleep = false
	_state = "playing"
	TitleCard.show_over(game.board, Vector3(0, 0.36, -0.1), "THE FIRST DAWN", "Watch over them.")
	game.say_at_shrine(StoryText.prayer(0, 0))
	_step = 0
	_step_time = 0.0
	_hint(HINTS[0])


func _hint(line: String) -> void:
	## The tutorial, in the world and big, from the moment the story ends (the user, 2026-11-11: "the tutorial needs to be
	## there when the game starts, not only in the ledger"). One gilded line over the island, its own parent so the story's
	## title cards never replace it.
	if _hint_root == null or not is_instance_valid(_hint_root):
		_hint_root = Node3D.new()
		_hint_root.name = "HintRoot"
		game.board.add_child(_hint_root)
	_hint_card = TitleCard.show_over(_hint_root, Vector3(0, 0.27, 0.15), line, "%d of %d" % [mini(_step + 1, HINTS.size()), HINTS.size()], -1.0, 54)


func _end_hints() -> void:
	if _hint_card and is_instance_valid(_hint_card):
		_hint_card.dismiss()
	_hint_card = null


func _tutorial(delta: float) -> void:
	## The first day, one small hint at a time. Each moves on when the player does the thing (or after a while).
	_step_time += delta
	var done := false
	match _step:
		0:
			done = game._held_card != null
		1:
			done = not game.towers.is_empty()
		2:
			done = game._helped > 0 or _step_time > 70.0
		3:
			done = game.life != null and game.life.villagers.any(func(v): return v.taps > 0) or _step_time > 40.0
		4:
			done = game.phase != Game.Phase.DAY
	if done:
		_step += 1
		_step_time = 0.0
		if _step < HINTS.size():
			_hint(HINTS[_step])
		else:
			_end_hints()
