class_name Launcher
extends Node
## The start of the game (docs/STORY.md, scene by scene). The real island floats asleep under fireflies with the
## gilt title above it and three wooden plaques on the table: Wake, The Tale, Hands / Controllers. Wake plays the
## opening narration on parchment, then wakes the game and walks the player through the first day with small hints
## (pick up a card, set it on the grass, help someone, tap a villager, start the night).
## It owns no game rules: it only drives Game's public state (asleep, press_override) and reads it.

const GOLD := Color("F2B630")  # rarity_gold
const GLOW := Color("FFD45A")  # fire_yellow
const OUTLINE := Color("5B2920")  # wood_dark
const NARRATION := [
	"You are the god of this small island.",
	"Your Veil keeps the dark away.",
	"It is woven from the faith of the people who live here.",
	"Tonight, something is coming.",
	"Watch over them.",
]
const TALE := "You are a very small god. Your whole world is this island: a meadow, twelve people, a well and a shrine.\n\nYour Veil, woven from their faith, keeps the Dark Wood out. But Skotos, a god the world forgot, has cursed it: every nightfall, it breaks.\n\nPlace towers. Cast your spells. Help your people. And if the worst happens... you are a god. You can try again."
const HINTS := [
	"Pick up a card from the tray.",
	"Set it on the grass and let go.",
	"Someone needs help: find a red ! and lift what they need.",
	"Tap a villager to hear their thoughts.",
	"When you are ready, start the night.",
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
var _title_label: Label3D
var _t := 0.0


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
	_build_title()


func _build_title() -> void:
	var half := GameConfig.SIZE * GameConfig.CELL / 2.0
	_title = Node3D.new()
	_title.name = "Title"
	game.board.add_child(_title)
	_title_label = Label3D.new()
	_title_label.text = "AETERNA"
	_title_label.font_size = 150
	_title_label.pixel_size = 0.0011
	_title_label.modulate = GOLD
	_title_label.outline_size = 22
	_title_label.outline_modulate = OUTLINE
	_title_label.no_depth_test = true
	_title_label.render_priority = 10
	_title_label.position = Vector3(0, 0.36, -0.12)
	_title_label.rotation_degrees.x = -18
	_title.add_child(_title_label)
	var sub := Label3D.new()
	sub.name = "Sub"
	sub.text = "a tiny god, a tiny land"
	sub.font_size = 60
	sub.pixel_size = 0.0007
	sub.modulate = Color("F4E4B8")  # wall_cream
	sub.outline_size = 10
	sub.outline_modulate = OUTLINE
	sub.no_depth_test = true
	sub.render_priority = 10
	sub.position = Vector3(0, 0.27, -0.09)
	sub.rotation_degrees.x = -18
	_title.add_child(sub)
	var x := -0.2
	for spec in [["wake", "Wake"], ["tale", "The Tale"], ["hands", "Hands / Controllers"]]:
		var p := Plaque.make(spec[1])
		p.position = Vector3(x, 0.02, half + 0.1)
		p.rotation_degrees.x = -50
		_title.add_child(p)
		_plaques[spec[0]] = p
		x += 0.2
	_panel = StoryPanel.make(game.board, Vector3(0, 0.34, 0.15))
	_title.add_child(_fireflies())


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


func _process(delta: float) -> void:
	_t += delta
	if _title_label and is_instance_valid(_title_label):
		_title_label.modulate = GOLD.lerp(GLOW, 0.5 + 0.5 * sin(_t * 1.6))  # a gentle shimmer
	if _state != "playing":
		for id in _plaques:
			var p: Plaque = _plaques[id]
			var hot := false
			for h in game._hands:
				hot = hot or p.hit_point(h.global_position) or p.hit_ray(h.ray_origin(), h.ray_dir())
			if game._mouse_hand:
				hot = hot or p.hit_point(game._mouse_hand.global_position)
			if game._camera:
				var m := get_viewport().get_mouse_position()
				hot = hot or p.hit_ray(game._camera.project_ray_origin(m), game._camera.project_ray_normal(m))
			p.hot = hot
	elif game.loop == 0 and _step < HINTS.size():
		_tutorial(delta)


func _on_press(world: Vector3, origin: Vector3, dir: Vector3) -> bool:
	## Game asks us first. true = we used the press.
	if _state == "playing":
		return false
	if _state == "narrating":
		_skip = true
		return true
	for id in _plaques:
		var p: Plaque = _plaques[id]
		if p.hit_ray(origin, dir) or p.hit_point(world, 0.012):
			_press_plaque(id)
			return true
	if _state == "tale":
		_state = "title"
		_close_panel()
	return true  # nothing else can be pressed while the title is up


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
		"hands":
			prefer_controllers = not prefer_controllers
			_plaques["hands"]._label.text = "Controllers" if prefer_controllers else "Hands / Controllers"
			_show_panel("Hands and controllers both work. You chose: %s." % ("controllers" if prefer_controllers else "whatever the headset finds first"))
			_state = "tale"


func _show_panel(line: String) -> void:
	## The title steps aside while a parchment is open.
	_title_label.visible = false
	_title.find_child("Sub", true, false).visible = false
	_panel.position = Vector3(0, 0.3, 0.1)
	_panel.show_text(line)


func _close_panel() -> void:
	_panel.hide_panel()
	_title_label.visible = true
	_title.find_child("Sub", true, false).visible = true


func _wake() -> void:
	_state = "narrating"
	_skip = false
	for i in NARRATION.size():
		_panel.show_text(NARRATION[i])
		var left := 3.2
		while left > 0.0 and not _skip:
			await get_tree().process_frame
			left -= get_process_delta_time()
		if _skip:
			break
	_panel.hide_panel()
	game.snd("dawn_bell")
	_title.queue_free()
	game.asleep = false
	_state = "playing"
	game.say_at_shrine(StoryText.prayer(0, 0))
	_step = 0
	_step_time = 0.0
	_hint(HINTS[0])


func _hint(line: String) -> void:
	Bubble.say(game.board.get_node("UI"), Vector3(0, 0.17, GameConfig.SIZE * GameConfig.CELL / 2.0 + 0.1), line, 600.0)  # on the UI node: the shrine bubbles use the board


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
			var old := game.board.get_node("UI").get_node_or_null("Bubble")
			if old:
				old.queue_free()
