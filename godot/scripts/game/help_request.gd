class_name HelpRequest
extends Node3D
## One quest: a villager asks the god for a small kindness, done by hand during the day for faith (spec 18;
## docs/STORY.md section 13). 2026-11-11 (the user): "let them be quests", at most four a day, posted one by one,
## no "!" markers. The asker has a small gold mote over their head; the quest and how to do it are in the ledger.
##   chimney  (Wren's kite) the kite is caught on the roof: grab it and pull it down (move it 1.5 cells from the roof)
##   bird     (the lost lamb) a lamb is lost beside the house: lead it 2 cells along the ground; it trots home
##   lantern  (the lost lantern) a lantern lies out on the grass: carry it back and let go within 1.5 cells of the
##            house's lantern hook; it stands by the door
##   cart     (the stuck cart) a handcart is stuck in a rut next to the house: push it 2 cells clear
##   rain     (rain for the field) a small cloud hangs over the house: carry it over the dry field and let go
##   warm     (the sick child) hold a hand over the house for WARM_HOLD seconds
##   lights   (the festival lanterns) touch each of the three unlit lanterns by the door
##   prayer   (answer a prayer) the asker kneels by the statue: tap them
## 2026-11-16 (the user): eight more kinds, all pinch-and-carry (NEW_KINDS; items are _items, prop is the one in hand):
##   laundry  (shirt, sock, towel on the grass) release each within 1 cell of the clothesline to hang it
##   well     carry the bucket to the well, release within 1.5 cells
##   apples   pinch the tree and wiggle it (1 cell of side movement in all) and 3 apples drop; carry each to the
##            basket, release within 1 cell
##   cat      the cat sits on the roof: release her on the ground within 2 cells of the door
##   weeds    4 weeds in the garden bed: lift each 1 cell and let go to pull it
##   bell     pinch the bell rope, pull it 1 cell down and let go: the bell rings; 3 rings
##   firewood 3 logs by the woodpile: release each within 1.5 cells of the door
##   letter   a letter flutters in a small loop until pinched; release it within 1 cell of the postbox
## A dropped item that is not in place stays on the grass and can be picked up again (the cat goes back on the roof,
## a weed back in the bed). Stand-ins to model later: the clothesline (two posts and a line).
## The old ids stay (tests and Game use them). Stand-ins to model later: the kite, the cloud and the field
## (primitives), the lamb (the bunny kid).
## Positions are board-local (this node is a child of the board at its origin).

const GOLD := Color("F2B630")  # rarity_gold
const GLOW := Color("FFD45A")  # fire_yellow
const WARM_HOLD := 3.0  # s a hand stays over the house
const WARM_REACH := 2.2  # cells from the house centre, measured flat
const LIGHTS := 3
const NEW_KINDS := ["laundry", "well", "apples", "cat", "weeds", "bell", "firewood", "letter"]
const APPLES := 3
const WEEDS := 4
const RINGS := 3
const LOGS := 3
const CLEAR_RADIUS := 0.045  # m of grass cleared round quest scenery
const SMALL_ITEM := 0.06  # m: items whose bounds are smaller than this get a thinner quest outline
static var _thin_mats := {}
const WIGGLE_NEED := 1.0  # cells of side movement while holding the apple tree
const TASK_ID := {"chimney": "kite_in_oak", "bird": "lost_lamb", "lantern": "lost_lantern", "cart": "broken_plank",
	"rain": "rain_for_field", "warm": "sick_child", "lights": "festival_lanterns", "prayer": "answer_prayer",
	"laundry": "laundry_line", "well": "well_bucket", "apples": "apple_basket", "cat": "sleepy_cat",
	"weeds": "weed_garden", "bell": "supper_bell", "firewood": "firewood_house", "letter": "lost_letter"}
const HOW := {
	"chimney": "Pinch the kite and lift it off the roof.",
	"bird": "Pinch the lamb and lead it away along the grass.",
	"lantern": "Pinch the lantern and carry it back to its house.",
	"cart": "Pinch the cart and push it out of the rut.",
	"rain": "Pinch the cloud, carry it over the dry field, let go.",
	"warm": "Hold your open hand over the house.",
	"lights": "Touch each of the three lanterns.",
	"prayer": "Tap the one who is praying.",
	"laundry": "Pinch each garment and hang it on the clothesline.",
	"well": "Pinch the bucket, carry it to the well, let go.",
	"apples": "Pinch the tree and wiggle it, then carry each apple to the basket.",
	"cat": "Pinch the cat and set her down by the door.",
	"weeds": "Pinch each weed and pull it up out of the bed.",
	"bell": "Pinch the bell rope and pull it down, three times.",
	"firewood": "Pinch each log and carry it to the door.",
	"letter": "Catch the letter and carry it to the postbox.",
}

static var shown_kinds := {}  # the ghost hand plays once per kind per session

var game  # Game
var kind := ""
var house := -1
var reward := 0
var done := false
var prop: Node3D
var held := false
var progress := 0.0  # warm: seconds held; lights: lanterns lit; NEW_KINDS: items placed (bell: rings)
var ask_line := ""  # the words picked when it was posted (kept, so the ledger and the bubble agree)
var after_line := ""

var _home := Vector3.ZERO  # where the prop started
var _goal := Vector3.ZERO  # lantern: where it is returned to; rain: the middle of the dry field
var _mote: Node3D  # the gold mote over the asker
var _prop_mote: Node3D  # a smaller one on a loose prop, so it can be found even behind a tall tower
var _villager: Node3D
var _helper: Villager
var _field: MeshInstance3D
var _lamps: Array[Node3D] = []
var _lit: Array[bool] = []
var _ghost: Node3D
var _outlined: Array[MeshInstance3D] = []
static var _outline_mat: ShaderMaterial
# NEW_KINDS state
var _items: Array[Node3D] = []  # what can be pinched; prop is the one in hand (or the next one)
var _placed: Array[bool] = []
var _homes: Array[Vector3] = []
var _extras: Array[Node3D] = []  # quest scenery: the clothesline, well, basket, garden bed, postbox, woodpile...
var _yaw := Basis.IDENTITY  # the house's facing
var _off := Vector3.ZERO  # the item's offset from the hand while carried
var _line_a := Vector3.ZERO  # laundry: the two ends of the clothesline
var _line_b := Vector3.ZERO
var _tree: Node3D  # apples
var _shaken := false
var _wiggle := 0.0  # cells of side movement so far
var _wiggle_last := Vector3.ZERO
var _wiggle_from := Vector3.ZERO
var _apple_dir := Vector3.RIGHT  # apples: from the tree towards the basket
var _rope: MeshInstance3D  # bell
var _bell: Node3D
var _rope_home := Vector3.ZERO
var _ref_y := 0.0  # bell: the hand height when the rope was pinched
var _pull := 0.0
var _flutter_c := Vector3.ZERO  # letter
var _flutter: Tween
var _tw := {}  # node -> a falling or returning tween, killed when the item is pinched again


func setup(request_kind: String, house_index: int, lantern_at := Vector3.ZERO) -> void:
	kind = request_kind
	house = house_index
	var cfg: Dictionary = GameConfig.REQUESTS[kind]
	reward = cfg["reward"]
	ask_line = StoryText.task(TASK_ID.get(kind, ""), "before")
	after_line = StoryText.task(TASK_ID.get(kind, ""), "after")
	var h: House = game.houses[house]
	var stand := _beside_door(h, 1.2) + h.basis.x * GameConfig.CELL * 0.8
	var socket := _anchor(h, "rubble_anchor")
	match kind:
		"chimney":
			prop = _make_kite()
			_home = socket
		"bird":
			prop = load(cfg["scene"]).instantiate()
			prop.scale = Vector3.ONE * 0.8  # the lamb: the bunny kid as a stand-in
			_home = _free_beside(h)
		"lantern":
			prop = load(cfg["scene"]).instantiate()
			_home = lantern_at
			var hook := _anchor(h, "lantern_anchor")
			_goal = Vector3(hook.x, 0.0, hook.z)
		"cart":
			prop = load(cfg["scene"]).instantiate()
			_home = _free_beside(h)
		"rain":
			prop = _make_cloud()
			_home = h.position + Vector3(0, ModelUtil.bounds(h.get_child(0)).end.y + 0.03, 0)
			_goal = _free_beside(h)
			_field = _make_field()
			add_child(_field)
			_field.position = _goal + Vector3(0, 0.0015, 0)
		"lights":
			for i in LIGHTS:
				var lamp: Node3D = load(cfg["scene"]).instantiate()
				add_child(lamp)
				lamp.position = _beside_door(h, 1.7) + h.basis.x * GameConfig.CELL * (i - 1) * 1.1
				lamp.position.y = 0.0
				_dim(lamp, true)
				_lamps.append(lamp)
				_lit.append(false)
		"prayer":
			stand = Vector3(0, 0, GameConfig.CELL * 1.7).rotated(Vector3.UP, house * 1.05)  # kneels by the statue
		"laundry", "well", "apples", "cat", "weeds", "bell", "firewood", "letter":
			_setup_new(h, socket, stand)
	if prop and not NEW_KINDS.has(kind):
		add_child(prop)
		prop.position = _home
		prop.rotation.y = h.rotation.y
		if kind == "lantern" or kind == "cart" or kind == "bird" or kind == "rain":
			_prop_mote = _make_mote(0.005)
			prop.add_child(_prop_mote)
			_prop_mote.position = Vector3(0, ModelUtil.bounds(prop).end.y + 0.008, 0)
	if game.life != null:
		_helper = game.life.help_wanted(house, stand)  # one of the house's own people walks over and waves
	if _helper == null:
		_villager = _stand_in_villager(house)
		add_child(_villager)
		_villager.position = stand
		_villager.rotation.y = h.rotation.y
	elif not _helper.visible or _helper.state == "inside" or _helper.state == "wait_out" or _helper.state == "enter":
		_helper.put(stand, "wave", 3.0, problem_point())
	_mote = _make_mote(0.008)
	var who := asker()
	if who:
		who.add_child(_mote)
		_mote.position = Vector3(0, 0.085, 0)
	else:
		add_child(_mote)
		_mote.position = h.position + Vector3(0, ModelUtil.bounds(h.get_child(0)).end.y + 0.02, 0)
	_say("before")
	if _helper:  # it acts the request out: hops, waves both arms, turns to the problem and points, every couple of seconds
		_helper.ask_face = problem_point()
		if _helper.state == "stay" and _helper.rig and _helper.rig.anim == "wave":
			_helper.wave_on(Vector3.INF)
	_start_outline()
	if game.with_rig and not shown_kinds.has(kind):
		shown_kinds[kind] = true
		_show_ghost()


func asker() -> Node3D:
	return _helper if _helper else _villager


func problem_point() -> Vector3:
	## Board-local spot the asker turns to and points at: the thing that needs doing.
	match kind:
		"warm":
			return game.houses[house].position
		"lights":
			return _lamps[0].position if not _lamps.is_empty() else game.houses[house].position
		"prayer":
			return Vector3.ZERO  # the statue
		_:
			return prop.position if prop else game.houses[house].position


func focus_point() -> Vector3:
	## World spot to point the player at (the tutorial ring): the quest's item, the asker for a prayer.
	var who := asker()
	if kind == "prayer" and who:
		return who.global_position
	return game.board.to_global(problem_point())


func engage() -> void:
	## The player took the request on (grabbed, held a hand over it, lit a lantern): the asker stops acting it out.
	if _helper:
		_helper.stop_asking()


func _start_outline() -> void:
	## A warm pulsing outline on the quest's item (shader quest_outline: one extra pass per mesh) until it is done.
	if not game.with_rig:
		return
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/quest_outline.gdshader")
	var roots: Array[Node] = []
	match kind:
		"warm":
			roots.append(game.houses[house].get_child(0))
		"lights":
			roots.append_array(_lamps)
		"prayer":
			if asker():
				roots.append(asker())
		_:
			if NEW_KINDS.has(kind):
				for i in _items.size():
					if not _placed[i]:
						roots.append(_items[i])
			elif prop:
				roots.append(prop)
	for r in roots:
		_outline_one(r)


func _outline_mat_for(root: Node3D) -> ShaderMaterial:
	## The new kinds' tiny items (apples, weeds, the letter, the cat) get a thinner outline, so it traces the prop
	## instead of covering it; everything else keeps the one shared width.
	if not NEW_KINDS.has(kind):
		return _outline_mat
	var size := ModelUtil.bounds(root).size.length()
	if size >= SMALL_ITEM:
		return _outline_mat
	var width := 0.008 * clampf(size / SMALL_ITEM, 0.35, 1.0)
	var key := roundi(width * 100000.0)
	if not _thin_mats.has(key):
		var m := _outline_mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("width", width)
		_thin_mats[key] = m
	return _thin_mats[key]


func _outline_one(root: Node) -> void:
	if not game.with_rig:
		return
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/quest_outline.gdshader")
	var mat := _outline_mat_for(root) if root is Node3D else _outline_mat
	for n in ModelUtil.walk(root):
		if n is MeshInstance3D and not (_mote and _mote.is_ancestor_of(n)) and not (_prop_mote and _prop_mote.is_ancestor_of(n)):
			var ov: Material = n.material_overlay
			if ov is StandardMaterial3D:
				ov.next_pass = mat  # an unlit lantern keeps its dark look; the outline is drawn after it
			else:
				n.material_overlay = mat
			_outlined.append(n)


func _drop_outline(n: MeshInstance3D) -> void:
	var ov: Material = n.material_overlay
	if ov is StandardMaterial3D:
		ov.next_pass = null
	else:
		n.material_overlay = null


func _unoutline(root: Node) -> void:
	## One item is in place: its outline goes, the others keep theirs.
	for n in ModelUtil.walk(root):
		if n is MeshInstance3D and _outlined.has(n):
			_drop_outline(n)
			_outlined.erase(n)


func _exit_tree() -> void:
	_stop_outline()


func _stop_outline() -> void:
	for m in _outlined:
		if is_instance_valid(m):
			_drop_outline(m)
	_outlined.clear()


func payout() -> int:
	## Faith reward scaled by the current loop, matching what completion pays.
	return roundi(float(reward) * (1.0 + GameConfig.LOOP_FAITH_STEP * (game.loop if game != null else 0)))


func info() -> Dictionary:
	## For the ledger's quest page.
	var who := StoryText.villager_name(_helper.voice) if _helper and _helper.voice != "" else "A villager"
	return {"kind": kind, "name": GameConfig.REQUESTS[kind]["name"], "who": who, "ask": ask_line,
		"how": HOW.get(kind, ""), "reward": payout(), "done": done}


func grabbable() -> bool:
	return prop != null and not done


func grab_point() -> Vector3:
	## World position a hand has to be near to grab the prop (far away for quests with nothing to carry).
	if prop == null:
		return Vector3(0, -1000, 0)
	if NEW_KINDS.has(kind):
		var i := _first_open()
		return _item_grab_point(i) if i >= 0 else Vector3(0, -1000, 0)
	return prop.global_position + Vector3(0, 0.008, 0)


func grab_dist(world: Vector3) -> float:
	## Distance from a hand to the nearest thing a pinch here would take (INF when nothing is left to pinch).
	if not NEW_KINDS.has(kind):
		return grab_point().distance_to(world)
	var best := INF
	for i in _items.size():
		if not _placed[i]:
			best = minf(best, _item_grab_point(i).distance_to(world))
	return best


func grab(world := Vector3.INF) -> bool:
	## world = where the hand is (the item pinched is the nearest to it); unknown, the first one left.
	if done or held or prop == null:
		return false
	if NEW_KINDS.has(kind) and not _grab_new(world):
		return false
	held = true
	_drop_ghost()
	engage()
	return true


func move_to(local: Vector3) -> void:
	## While held: the prop follows the hand (board-local). The cart and the lamb stay on the ground.
	if not held:
		return
	if NEW_KINDS.has(kind):
		_move_new(local)
		return
	if kind == "cart" or kind == "bird":
		local.y = 0.0
	prop.position = local


func put_back() -> void:
	## The hand holding the prop lost tracking: the prop goes home, nothing is finished.
	if held:
		prop.position = _home
		held = false
		if NEW_KINDS.has(kind):
			_reset_hold()


func release() -> bool:
	## Let go: true when that finished the request.
	if not held:
		return false
	held = false
	if NEW_KINDS.has(kind):
		return _release_new()
	var moved := prop.position - _home
	var flat := Vector2(moved.x, moved.z).length()
	match kind:
		"chimney":
			if moved.length() >= 1.5 * GameConfig.CELL:
				_finish()
				_toss(prop)
				return true
		"bird":
			if flat >= 2.0 * GameConfig.CELL:
				_finish()
				_trot_home(prop)
				return true
		"lantern":
			var to_goal := prop.position - _goal
			if Vector2(to_goal.x, to_goal.z).length() <= 1.5 * GameConfig.CELL:
				prop.position = _goal
				_finish()
				return true
			prop.position.y = 0.0  # dropped on the grass, can be picked up again
			return false
		"cart":
			if flat >= 2.0 * GameConfig.CELL:
				var parts := ModelUtil.parts(prop)
				if parts.has("rut"):
					parts["rut"].visible = false
				_finish()
				return true
		"rain":
			var over := prop.position - _goal
			if Vector2(over.x, over.z).length() <= 1.5 * GameConfig.CELL:
				_rain()
				_finish()
				_toss(prop)
				return true
	prop.position = _home
	return false


func warm_step(delta: float, hand_over: bool) -> bool:
	## warm: a hand over the house fills the hold; taking it away lets it drain. true when that finished it.
	if kind != "warm" or done:
		return false
	progress = clampf(progress + (delta if hand_over else -delta * 1.5), 0.0, WARM_HOLD)
	if _mote:
		_mote.scale = Vector3.ONE * (1.0 + 2.0 * progress / WARM_HOLD)
	if hand_over:
		_drop_ghost()
		engage()
	if progress < WARM_HOLD:
		return false
	_finish()
	return true


func touch(world: Vector3, reach: float) -> bool:
	## lights: a fingertip at an unlit lantern lights it. true when the last one was lit.
	if kind != "lights" or done:
		return false
	for i in _lamps.size():
		if not _lit[i] and world.distance_to(_lamps[i].global_position + Vector3(0, 0.012, 0)) <= reach:
			_lit[i] = true
			progress += 1.0
			_dim(_lamps[i], false)
			_drop_ghost()
			engage()
			if game.with_rig:
				VfxKit.burst(game.shots_root, _lamps[i].global_position + Vector3(0, 0.015, 0), GLOW, Color("F6A45D"), 8, 0.03, 0.6, 0.004, 0.03)
				game.snd("pinch")
	if _lit.has(false):
		return false
	_finish()
	return true


func answer(v: Node) -> bool:
	## prayer: the one who prays was tapped.
	if kind != "prayer" or done or (v != null and v != asker()):
		return false
	_finish()
	return true


func hand_over_house(world: Vector3) -> bool:
	var d: Vector3 = game.board.to_local(world) - game.houses[house].position
	return Vector2(d.x, d.z).length() <= WARM_REACH * GameConfig.CELL and d.y >= 0.0 and d.y <= 0.3


func dodge(footprint: Array[Vector2i]) -> void:
	## A tower was just built: a lantern, cart or lamb on or right beside its cells (a tall tower hides what is
	## next to it from the seat) is carried to the nearest open ground. Not while someone is holding it.
	if NEW_KINDS.has(kind):
		_dodge_new(footprint)
		return
	if done or held or (kind != "lantern" and kind != "cart" and kind != "bird"):
		return
	var c := NavGrid.local_to_cell(prop.position)
	for f in footprint:
		if absi(f.x - c.x) <= 1 and absi(f.y - c.y) <= 1:
			var spot: Vector3 = game.open_ground_near(prop.position)
			var shift := spot - prop.position
			prop.position = spot
			_home += Vector3(shift.x, 0, shift.z)
			return  # a lantern's goal is the house's hook, which never moves


func _finish() -> void:
	done = true
	_drop_ghost()
	_stop_outline()
	for m in [_mote, _prop_mote]:
		if m:
			m.visible = false
	if _flutter:
		_flutter.kill()
	_say("after")
	if _helper:
		_helper.thank()
	if _villager and _villager.is_inside_tree():
		var tw := _villager.create_tween()  # a happy hop
		tw.tween_property(_villager, "position:y", 0.02, 0.15).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_villager, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)


func _toss(n: Node3D) -> void:
	if not n.is_inside_tree():
		n.visible = false
		return
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE * 0.001, 0.4)
	tw.tween_callback(func(): n.visible = false)


func _trot_home(n: Node3D) -> void:
	## The lamb trots to the door and is gone.
	if not n.is_inside_tree():
		n.visible = false
		return
	var door := _beside_door(game.houses[house], 1.0)
	var tw := n.create_tween()
	tw.tween_property(n, "position", Vector3(door.x, 0.0, door.z), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): n.visible = false)


func _rain() -> void:
	## The field drinks: it turns green, with a short fall of drops (pale, never blue: blue is Foresight's).
	if _field:
		(_field.material_override as StandardMaterial3D).albedo_color = Color("88BE45")  # grass
	if game.with_rig and is_inside_tree():
		VfxKit.burst(game.shots_root, to_global(_goal + Vector3(0, 0.05, 0)), Color("F4E4B8"), Color("88BE45"), 30, 0.05, 0.9, 0.003, -0.25)


func _say(which: String) -> void:
	## "before" when posted, "after" when done: a parchment bubble over the villager who asked (with the rig only).
	if not game.with_rig or not is_inside_tree() or game.asleep:
		return  # the title screen shows the island asleep: the words wait until the game wakes
	var line := ask_line if which == "before" else after_line
	if line == "":
		return
	var who := asker()
	if who and who.is_inside_tree():
		Bubble.say(who, Vector3(0, 0.1, 0), line, 6.0)


func _show_ghost() -> void:
	## The first time a kind of quest appears, a golden ghost hand plays the gesture over it.
	if not is_inside_tree():
		return
	match kind:
		"chimney":
			_ghost = GhostHand.carry(self, _home, _home + Vector3(0, 0.1, 0.03))
		"bird", "cart":
			_ghost = GhostHand.carry(self, _home + Vector3(0, 0.02, 0), _home + Vector3(0, 0.02, 0) + game.houses[house].basis.x * GameConfig.CELL * 2.5)
		"lantern":
			_ghost = GhostHand.carry(self, _home + Vector3(0, 0.02, 0), _goal + Vector3(0, 0.03, 0))
		"rain":
			_ghost = GhostHand.carry(self, _home, _goal + Vector3(0, 0.07, 0))
		"warm":
			_ghost = GhostHand.hover(self, game.houses[house].position + Vector3(0, ModelUtil.bounds(game.houses[house].get_child(0)).end.y + 0.05, 0))
		"lights":
			_ghost = GhostHand.tap(self, _lamps[0].position + Vector3(0, 0.02, 0))
		"prayer":
			var who := asker()
			if who:
				_ghost = GhostHand.tap(self, who.position + Vector3(0, 0.05, 0))
		"laundry":  # the nearest existing ghost: carry one garment to the line
			_ghost = GhostHand.carry(self, _homes[0] + Vector3(0, 0.02, 0), _line_a.lerp(_line_b, 0.3))
		"well", "cat", "firewood", "letter":
			_ghost = GhostHand.carry(self, _homes[0] + Vector3(0, 0.02, 0), _goal + Vector3(0, 0.03, 0))
		"apples":  # a wiggle across the tree
			var at := _tree.position + Vector3(0, 0.03, 0)
			_ghost = GhostHand.carry(self, at - _apple_dir * GameConfig.CELL * 0.5, at + _apple_dir * GameConfig.CELL * 0.5)
		"weeds":
			_ghost = GhostHand.carry(self, _homes[0] + Vector3(0, 0.02, 0), _homes[0] + Vector3(0, 0.1, 0))
		"bell":
			var rp := to_local(_rope_center())
			_ghost = GhostHand.carry(self, rp, rp - Vector3(0, GameConfig.CELL * 1.5, 0))


func _drop_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _make_mote(radius: float) -> Node3D:
	## The quest marker: a small gold mote, bobbing. Not a "!".
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	m.mesh = s
	m.material_override = ModelUtil.flat_material(GLOW, true)
	n.add_child(m)
	if is_inside_tree():
		var tw := m.create_tween().set_loops()
		tw.tween_property(m, "position:y", 0.006, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(m, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	return n


func _dim(lamp: Node3D, dark: bool) -> void:
	## An unlit lantern is dark; lit, it gets its glow and a small light.
	for n in ModelUtil.walk(lamp):
		if n is MeshInstance3D:
			(n as MeshInstance3D).transparency = 0.0
			(n as MeshInstance3D).material_overlay = ModelUtil.flat_material(Color(0.05, 0.04, 0.04, 0.6)) if dark else null
	if not dark:
		var glow := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.004
		s.height = 0.008
		glow.mesh = s
		glow.material_override = ModelUtil.flat_material(GLOW, true)
		glow.position.y = 0.014
		lamp.add_child(glow)


static func _make_kite() -> Node3D:
	## STAND-IN (to model later): a pink diamond kite with a red tail, from primitives, palette colours only.
	var k := Node3D.new()
	var diamond := MeshInstance3D.new()
	var q := BoxMesh.new()  # a thin closed slab (a quad would be open: the quest outline hull needs a closed mesh)
	q.size = Vector3(0.016, 0.016, 0.0012)
	diamond.mesh = q
	diamond.rotation.z = PI / 4.0
	diamond.position.y = 0.012
	var mat := ModelUtil.flat_material(Color("EE8FA8"))  # flower_pink
	diamond.material_override = mat
	k.add_child(diamond)
	for i in 3:
		var bow := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.004, 0.003, 0.001)
		bow.mesh = bm
		bow.position = Vector3(0.002 * i, 0.0045 - i * 0.004, 0)
		bow.material_override = ModelUtil.flat_material(Color("E8452C"))  # fire_red
		k.add_child(bow)
	return k


static func _make_cloud() -> Node3D:
	## STAND-IN (to model later): a small cream cloud of three puffs.
	var c := Node3D.new()
	for spec in [[Vector3(0, 0.008, 0), 0.011], [Vector3(-0.011, 0.005, 0.002), 0.008], [Vector3(0.012, 0.005, -0.002), 0.0085]]:
		var puff := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = spec[1]
		s.height = spec[1] * 2.0
		s.radial_segments = 10
		s.rings = 5
		puff.mesh = s
		puff.position = spec[0]
		puff.material_override = ModelUtil.flat_material(Color("F4E4B8"))  # wall_cream
		c.add_child(puff)
	return c


static func _make_field() -> MeshInstance3D:
	## STAND-IN (to model later): a dry patch of field, 2 x 2 cells.
	var f := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(GameConfig.CELL * 2.0, GameConfig.CELL * 2.0)
	f.mesh = p
	f.material_override = ModelUtil.flat_material(Color("A98A72"))  # dirt_light
	return f


func _anchor(h: House, suffix: String) -> Vector3:
	## A house anchor in board space (the house is a child of the board's "Houses" node at the origin).
	var model: Node3D = h.get_child(0)
	for n in ModelUtil.walk(model):
		if n is Marker3D and str(n.name).ends_with(suffix):
			return h.transform * ModelUtil.xform_to(n, model).origin
	return h.position


func _free_beside(h: House, not_front := false, stand := Vector3.INF) -> Vector3:
	## The first side of the house (back, right, left, front) with open ground: no house, tower or forest
	## within a cell of it. not_front leaves out the door side (where the villagers and the door are).
	for dir in [-h.basis.z, h.basis.x, -h.basis.x, h.basis.z]:
		if not_front and dir == h.basis.z:
			continue
		var p: Vector3 = h.position + dir * GameConfig.CELL * 2.3
		if _clear3(p) and not (not_front and _crowded(p, stand)):
			return p
	return h.position - h.basis.z * GameConfig.CELL * 2.3


func _crowded(p: Vector3, stand: Vector3) -> bool:
	## Scenery spot p is within 3 cells of where the asker stands, or on another quest's scenery or items.
	if stand.is_finite() and _flat(p, stand) < 3.0 * GameConfig.CELL:
		return true
	for r in game.requests:
		if r == self:
			continue
		var pts: Array[Vector3] = []
		for n in r._extras:
			pts.append(n.position)
		for n in r._items:
			pts.append(n.position)
		if r.prop:
			pts.append(r.prop.position)
		for q in pts:
			if _flat(p, q) < 0.14:
				return true
	return false


func _clear3(p: Vector3) -> bool:
	## No house, tower or forest on the 3 x 3 cells round p, and inside the board's edge.
	var c := NavGrid.local_to_cell(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x < 1 or n.y < 1 or n.x > GameConfig.SIZE - 2 or n.y > GameConfig.SIZE - 2 or game.nav.kind.has(n):
				return false
	return true


func _beside_door(h: House, cells: float) -> Vector3:
	## The doors face the village centre (+Z of the model).
	return h.position + h.basis.z * GameConfig.CELL * cells


static func _stand_in_villager(i: int) -> Node3D:
	## STAND-IN until Durva's villagers: a small capsule body in a warm cloth colour and a round head.
	var cloth: Array[Color] = [Color("B04F31"), Color("2F8F8A"), Color("E09B4E"), Color("9A6538"), Color("6479E0"), Color("C6924C")]
	var v := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.007
	cm.height = 0.024
	body.mesh = cm
	body.position.y = 0.012
	body.material_override = ModelUtil.flat_material(cloth[i % cloth.size()])
	v.add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0075
	sm.height = 0.015
	head.mesh = sm
	head.position.y = 0.03
	head.material_override = ModelUtil.flat_material(Color("F2C9A0"))
	v.add_child(head)
	return v


# ---- NEW_KINDS (2026-11-16) ----

static func _model(n: String) -> Node3D:
	return load("res://assets/village/ew_village_%s.glb" % n).instantiate()


static func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = ModelUtil.flat_material(color)
	return m


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	## Flat distance from p to the segment a-b.
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var t := clampf(Vector2(p.x - a.x, p.z - a.z).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return Vector2(p.x - a.x - ab.x * t, p.z - a.z - ab.y * t).length()


func _extra(n: Node3D, pos: Vector3) -> Node3D:
	## Quest scenery: it goes with the request (it is a child of it).
	add_child(n)
	n.position = pos
	n.basis = _yaw
	_extras.append(n)
	return n


func _patch(pos: Vector3, radius: float) -> void:
	## A patch of trodden ground under a piece of quest scenery, so its foot is not lost in the grass.
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.0012
	c.radial_segments = 14
	m.mesh = c
	m.material_override = ModelUtil.flat_material(Color("A98A72"))  # dirt_light
	add_child(m)
	m.position = Vector3(pos.x, 0.0015, pos.z)


func clear_points() -> Array[Vector3]:
	## Board-local spots where the grass is cleared (radius CLEAR_RADIUS) so the scenery and loose items read.
	var out: Array[Vector3] = []
	if not NEW_KINDS.has(kind):
		return out
	for n in _extras:
		out.append(n.position)
	if kind == "laundry":
		out.append(_line_a.lerp(_line_b, 0.5))
		for i in _items.size():
			out.append(_homes[i])
	elif kind == "letter":
		out.append(_flutter_c)
	elif kind != "cat" and kind != "bell":
		for i in _items.size():
			if not _placed[i]:
				out.append(_homes[i])
	return out


func _register(n: Node3D) -> void:
	## An item that can be pinched. Its grab height is kept as metadata.
	n.set_meta("gp_y", clampf(ModelUtil.bounds(n).get_center().y, 0.006, 0.03))
	_items.append(n)
	_placed.append(false)
	_homes.append(n.position)


func _loose_item(name: String, pos: Vector3) -> Node3D:
	var n := _model(name)
	add_child(n)
	n.basis = _yaw
	n.position = Vector3(pos.x, 0.0, pos.z)
	_register(n)
	return n


func _spot(cands: Array, avoid: Vector3, min_cells: float) -> Vector3:
	## The first candidate on open ground at least min_cells from avoid (else the last).
	var p := Vector3.ZERO
	for c in cands:
		p = c
		var ok: bool = not game.nav.kind.has(NavGrid.local_to_cell(p))
		if ok and avoid.is_finite() and _flat(p, avoid) < min_cells * GameConfig.CELL:
			ok = false
		if ok:
			return p
	return p


func _setup_new(h: House, socket: Vector3, stand: Vector3) -> void:
	var C := GameConfig.CELL
	_yaw = Basis(Vector3.UP, h.rotation.y)
	var ax: Vector3 = h.basis.x
	var az: Vector3 = h.basis.z
	match kind:
		"laundry":
			## STAND-IN (to model later): two wooden posts and a thin cream line, 2.6 cells long.
			var p := _free_beside(h, true, stand)
			_goal = p
			var line_y := 0.045
			_line_a = p - ax * 0.065 + Vector3(0, line_y, 0)
			_line_b = p + ax * 0.065 + Vector3(0, line_y, 0)
			for e in [_line_a, _line_b]:
				_patch(Vector3(e.x, 0, e.z), 0.015)
				_extra(_box(Vector3(0.003, line_y + 0.004, 0.003), Color("9A6538")), Vector3(e.x, (line_y + 0.004) * 0.5, e.z))  # wood_mid
			_extra(_box(Vector3(0.13, 0.0012, 0.0012), Color("F4E4B8")), p + Vector3(0, line_y, 0))  # wall_cream
			var names := ["laundry_shirt_v01", "laundry_sock_v01", "laundry_towel_v01"]
			var lay := [-0.045, 0.0, 0.04]
			var slot := [-0.034, 0.006, 0.036]
			for i in 3:
				var g := _loose_item(names[i], p + ax * float(lay[i]) + az * 0.045)
				var zmax: float = ModelUtil.bounds(g).end.z
				g.set_meta("hang", p + ax * float(slot[i]) + Vector3(0, line_y - zmax, 0))  # hung by its top edge
		"well":
			var p := _free_beside(h, true, stand)
			_patch(p, 0.032)
			_extra(_model("well_v02"), Vector3(p.x, 0, p.z))
			_goal = Vector3(p.x, 0, p.z)
			var cands := []
			for sgn in [-0.9, 0.9]:
				cands.append(_beside_door(h, 1.35) + ax * C * sgn)
			var b := _loose_item("bucket_v02", _spot(cands, _goal, 2.2))
			_mote_on(b)
		"apples":
			var p := _free_beside(h, true, stand)
			p = Vector3(p.x, 0, p.z)
			_tree = _extra(_model("apple_tree_v01"), p)
			_register(_tree)
			var cands := []
			for d in [ax, -ax, az, -az]:
				if _clear3(p + d * C * 2.0):
					cands.append(d)
			_apple_dir = cands[0] if not cands.is_empty() else ax
			_goal = p + _apple_dir * 0.1
			_patch(_goal, 0.03)
			_extra(_model("basket_v02"), _goal).scale = Vector3.ONE * 1.6  # bigger, so it reads among the grass
		"cat":
			var c := _model("cat_v01")
			add_child(c)
			c.basis = _yaw
			if socket.is_equal_approx(h.position):  # no rubble_anchor on this house: the top of the roof, like the cloud
				socket = h.position + Vector3(0, ModelUtil.bounds(h.get_child(0)).end.y, 0)
			c.position = socket
			_register(c)
			_goal = _beside_door(h, 1.0)
			_goal.y = 0.0
			_mote_on(c)
			if game.with_rig:
				_cat_idle(c)
		"weeds":
			var p := _free_beside(h, true, stand)
			p = Vector3(p.x, 0, p.z)
			_extra(_model("garden_v01"), p)
			for i in WEEDS:
				var o := ax * (0.021 if i % 2 == 0 else -0.021) + az * (0.021 if i < 2 else -0.021)
				_loose_item("garden_weed_v01", p + o)
		"bell":
			_bell = _model("house_bell_v01")
			add_child(_bell)
			_bell.basis = _yaw
			var wall_z: float = ModelUtil.bounds(h.get_child(0)).end.z
			_bell.position = h.position + az * (wall_z - 0.001) + ax * C * 0.8 + Vector3(0, 0.012, 0)
			var parts := ModelUtil.parts(_bell)
			_rope = parts.get("rope")
			if _rope == null:  # a model without the rope part: an empty stand-in at the bell's foot
				_rope = MeshInstance3D.new()
				_bell.add_child(_rope)
			_rope_home = _rope.position
			_register(_bell)
			_homes[0] = _bell.position
		"firewood":
			var p := _free_beside(h, true, stand)
			p = Vector3(p.x, 0, p.z)
			_patch(p + az * 0.02, 0.04)
			_extra(_model("firewood_v01"), p)
			_goal = _beside_door(h, 1.1)
			_goal.y = 0.0
			for i in LOGS:
				_loose_item("firewood_log_v01", p + ax * (i - 1) * 0.024 + az * 0.046)
		"letter":
			var p := _free_beside(h, true, stand)
			p = Vector3(p.x, 0, p.z)
			_patch(p, 0.03)
			_extra(_model("postbox_v01"), p)
			_goal = p
			var cands := []
			for d in [ax, -ax, az, -az]:
				cands.append(p + d * C * 2.0)
			_flutter_c = _spot(cands, Vector3.INF, 0.0)
			var l := _loose_item("letter_v01", _flutter_pos(0.0))
			_homes[0] = Vector3(_flutter_c.x + 0.02, 0, _flutter_c.z)
			_mote_on(l)
			if game.with_rig:
				_flutter = l.create_tween().set_loops()
				_flutter.tween_method(_flutter_step, 0.0, TAU, 7.0)
	_select(_first_open())


func _mote_on(n: Node3D) -> void:
	_prop_mote = _make_mote(0.005)
	n.add_child(_prop_mote)
	_prop_mote.position = Vector3(0, ModelUtil.bounds(n).end.y + 0.008, 0)


func _select(i: int) -> void:
	## prop is the item in hand, or the next one left.
	if i < 0 or i >= _items.size():
		return
	prop = _items[i]
	_home = _homes[i]


func _first_open() -> int:
	for i in _items.size():
		if not _placed[i]:
			return i
	return -1


func _item_grab_point(i: int) -> Vector3:
	if kind == "bell":
		return _rope_center()
	return _items[i].global_position + Vector3(0, float(_items[i].get_meta("gp_y", 0.008)), 0)


func _rope_center() -> Vector3:
	if _rope.mesh == null:
		return _rope.global_position + Vector3(0, 0.02, 0)
	return _rope.global_transform * _rope.mesh.get_aabb().get_center()


func _grab_new(world: Vector3) -> bool:
	## Pick the item nearest the hand (the first left when the hand is unknown) and note where the hand is.
	var best := -1
	var best_d := INF
	for i in _items.size():
		if _placed[i]:
			continue
		var d := _item_grab_point(i).distance_to(world) if world.is_finite() else float(i)
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	_select(best)
	_kill_tw(prop)
	if kind == "bell":
		_kill_tw(_rope)
	var hand: Vector3 = game.board.to_local(world) if world.is_finite() else Vector3.INF
	_off = (prop.position - hand) if hand.is_finite() else Vector3.ZERO
	if kind == "apples" and prop == _tree:
		_wiggle_last = hand if hand.is_finite() else prop.position + Vector3(0, 0.02, 0)
		_wiggle_from = _wiggle_last
	if kind == "bell":
		_ref_y = hand.y if hand.is_finite() else game.board.to_local(_rope_center()).y
	if kind == "letter" and _flutter:
		_flutter.kill()
		_flutter = null
	return true


func _move_new(local: Vector3) -> void:
	match kind:
		"apples":
			if prop == _tree:
				_wiggle_tree(local)
				return
		"bell":
			_pull = maxf(0.0, _ref_y - local.y)
			_rope.position = _rope_home - Vector3(0, minf(_pull, GameConfig.CELL * 1.5), 0)
			return
	prop.position = local + _off
	prop.position.y = maxf(prop.position.y, 0.0)


func _wiggle_tree(local: Vector3) -> void:
	## The tree stays rooted; it leans with the hand. A cell of side movement in all shakes the apples down.
	_wiggle += Vector2(local.x - _wiggle_last.x, local.z - _wiggle_last.z).length() / GameConfig.CELL
	_wiggle_last = local
	var d := local - _wiggle_from
	_tree.basis = _yaw * Basis(Vector3.BACK, clampf(-d.x * 2.4, -0.2, 0.2)) * Basis(Vector3.RIGHT, clampf(d.z * 2.4, -0.2, 0.2))
	if not _shaken and _wiggle >= WIGGLE_NEED:
		_drop_apples()


func _drop_apples() -> void:
	_shaken = true
	_unoutline(_tree)
	_items.clear()
	_placed.clear()
	_homes.clear()
	var side := _apple_dir.cross(Vector3.UP)
	for i in APPLES:
		var a := _model("apple_v01")
		add_child(a)
		a.basis = _yaw
		var spot := _tree.position - _apple_dir * 0.04 + side * (i - 1) * 0.026
		a.position = Vector3(spot.x, 0.0, spot.z)
		_register(a)
		_outline_one(a)
		if game.with_rig and is_inside_tree():
			a.position.y = 0.07 + 0.01 * i
			var tw := a.create_tween()
			tw.tween_property(a, "position:y", 0.0, 0.35 + 0.08 * i).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			_tw[a] = tw
		if game.with_rig and i == 0:
			game.snd("grab")


func _dodge_new(footprint: Array[Vector2i]) -> void:
	## A tower was just built on or right beside a loose item of the new kinds: it is carried to open ground,
	## and its home with it. The cat, the bell and the weeds (in their bed) stay put.
	if done or held or kind == "cat" or kind == "bell" or kind == "weeds":
		return
	for i in _items.size():
		if _placed[i] or _items[i] == _tree:
			continue
		var c := NavGrid.local_to_cell(_items[i].position)
		for f in footprint:
			if absi(f.x - c.x) <= 1 and absi(f.y - c.y) <= 1:
				var spot: Vector3 = game.open_ground_near(_items[i].position)
				var shift := Vector3(spot.x - _items[i].position.x, 0, spot.z - _items[i].position.z)
				_items[i].position += shift
				_homes[i] += shift
				if kind == "letter":
					_flutter_c += shift
				break
	var cur := _items.find(prop)
	if cur >= 0:
		_home = _homes[cur]


func _kill_tw(n: Node) -> void:
	## A pinch stops the item's fall or return, so the tween cannot pull it out of the hand.
	if _tw.has(n):
		if _tw[n] is Tween:
			(_tw[n] as Tween).kill()
		_tw.erase(n)


func _flutter_pos(t: float) -> Vector3:
	## The letter's small loop: about one cell across, low in the air.
	return _flutter_c + Vector3(cos(t) * 0.02, 0.024 + 0.005 * sin(t * 2.0), sin(t) * 0.014)


func _flutter_step(t: float) -> void:
	if prop == null or held:
		return
	var l := _items[0]
	l.position = _flutter_pos(t)
	l.basis = _yaw * Basis(Vector3.UP, t + sin(t * 1.5) * 0.6) * Basis(Vector3.BACK, sin(t * 2.0) * 0.25)


func _cat_idle(c: Node3D) -> void:
	## A gentle idle: the tail sways, the head turns now and then.
	var parts := ModelUtil.parts(c)
	if parts.has("tail"):
		var tw: Tween = parts["tail"].create_tween().set_loops()
		tw.tween_property(parts["tail"], "rotation:y", 0.4, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(parts["tail"], "rotation:y", -0.4, 1.1).set_trans(Tween.TRANS_SINE)
	if parts.has("head"):
		var th: Tween = parts["head"].create_tween().set_loops()
		th.tween_interval(1.6)
		th.tween_property(parts["head"], "rotation:y", 0.5, 0.5).set_trans(Tween.TRANS_SINE)
		th.tween_interval(1.2)
		th.tween_property(parts["head"], "rotation:y", -0.3, 0.7).set_trans(Tween.TRANS_SINE)
		th.tween_interval(0.8)
		th.tween_property(parts["head"], "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func _reset_hold() -> void:
	## A hold ended without finishing anything: the tree straightens, the rope comes back up.
	if _tree:
		_tree.basis = _yaw
	if kind == "bell":
		_rope.position = _rope_home
		_pull = 0.0


func _drop_here() -> void:
	## Not in place: it lies on the grass where it was let go, and can be pinched again.
	prop.position.y = 0.0
	var i := _items.find(prop)
	if i >= 0:
		_homes[i] = prop.position
	_home = prop.position


func _complete(i: int) -> bool:
	## Item i is in place. true when that was the last one (the request is finished).
	_placed[i] = true
	progress += 1.0
	_unoutline(_items[i])
	if _first_open() >= 0:
		_select(_first_open())
		if game.with_rig:
			game.snd("pinch")
		return false
	_finish()
	return true


func _release_new() -> bool:
	var C := GameConfig.CELL
	var i := _items.find(prop)
	match kind:
		"laundry":
			if _seg_dist(prop.position, _line_a, _line_b) <= C:
				prop.basis = _yaw * Basis(Vector3.RIGHT, -PI / 2.0)
				prop.position = prop.get_meta("hang")
				return _complete(i)
			_drop_here()
		"well":
			if _flat(prop.position, _goal) <= 1.5 * C:
				prop.position = _goal
				_toss(prop)  # lowered into the well
				return _complete(i)
			_drop_here()
		"apples":
			if prop == _tree:
				_reset_hold()
				_select(_first_open())  # the apples, if they fell
				return false
			if _flat(prop.position, _goal) <= C:
				var k := int(progress)
				prop.position = _goal + Vector3((k - 1) * 0.004, 0.006 + 0.005 * k, 0.0)
				return _complete(i)
			_drop_here()
		"cat":
			if _flat(prop.position, _goal) <= 2.0 * C and prop.position.y <= 0.04:
				prop.position = Vector3(prop.position.x, 0.0, prop.position.z)
				return _complete(i)
			prop.position = _home  # back on the roof
		"weeds":
			if prop.position.y - _home.y >= C:
				_toss(prop)  # pulled
				return _complete(i)
			prop.position = _home  # still rooted
		"firewood":
			if _flat(prop.position, _goal) <= 1.5 * C:
				_toss(prop)  # carried in
				return _complete(i)
			_drop_here()
		"letter":
			if _flat(prop.position, _goal) <= C:
				prop.position = _goal
				_toss(prop)  # posted
				return _complete(i)
			_drop_here()
		"bell":
			var pulled := _pull >= C
			_pull = 0.0
			_ring_back()
			if pulled:
				progress += 1.0
				_ring()
				if progress >= RINGS:
					_finish()
					return true
	return false


func _ring_back() -> void:
	if game.with_rig and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(_rope, "position", _rope_home, 0.25).set_trans(Tween.TRANS_SINE)
		_tw[_rope] = tw
	else:
		_rope.position = _rope_home


func _ring() -> void:
	## The bell swings, damped, and the village bell sounds.
	game.snd("village_bell")
	var bell: Node3D = ModelUtil.parts(_bell).get("bell")
	if bell and game.with_rig and is_inside_tree():
		var tw := bell.create_tween()
		for a in [0.5, -0.4, 0.28, -0.16, 0.0]:
			tw.tween_property(bell, "rotation:z", a, 0.22).set_trans(Tween.TRANS_SINE)
