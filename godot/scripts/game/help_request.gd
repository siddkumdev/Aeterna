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
## The old ids stay (tests and Game use them). Stand-ins to model later: the kite, the cloud and the field
## (primitives), the lamb (the bunny kid).
## Positions are board-local (this node is a child of the board at its origin).

const GOLD := Color("F2B630")  # rarity_gold
const GLOW := Color("FFD45A")  # fire_yellow
const WARM_HOLD := 3.0  # s a hand stays over the house
const WARM_REACH := 2.2  # cells from the house centre, measured flat
const LIGHTS := 3
const TASK_ID := {"chimney": "kite_in_oak", "bird": "lost_lamb", "lantern": "lost_lantern", "cart": "broken_plank",
	"rain": "rain_for_field", "warm": "sick_child", "lights": "festival_lanterns", "prayer": "answer_prayer"}
const HOW := {
	"chimney": "Pinch the kite and lift it off the roof.",
	"bird": "Pinch the lamb and lead it away along the grass.",
	"lantern": "Pinch the lantern and carry it back to its house.",
	"cart": "Pinch the cart and push it out of the rut.",
	"rain": "Pinch the cloud, carry it over the dry field, let go.",
	"warm": "Hold your open hand over the house.",
	"lights": "Touch each of the three lanterns.",
	"prayer": "Tap the one who is praying.",
}

static var shown_kinds := {}  # the ghost hand plays once per kind per session

var game  # Game
var kind := ""
var house := -1
var reward := 0
var done := false
var prop: Node3D
var held := false
var progress := 0.0  # warm: seconds held; lights: lanterns lit

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


func setup(request_kind: String, house_index: int, lantern_at := Vector3.ZERO) -> void:
	kind = request_kind
	house = house_index
	var cfg: Dictionary = GameConfig.REQUESTS[kind]
	reward = cfg["reward"]
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
	if prop:
		add_child(prop)
		prop.position = _home
		prop.rotation.y = h.rotation.y
		if kind == "lantern" or kind == "cart" or kind == "bird" or kind == "rain":
			_prop_mote = _make_mote(0.005)
			prop.add_child(_prop_mote)
			_prop_mote.position = Vector3(0, ModelUtil.bounds(prop).end.y + 0.008, 0)
	if game.life != null:
		_helper = game.life.help_wanted(house, stand)  # one of the house's own people walks over and waves
	else:
		_villager = _stand_in_villager(house)
		add_child(_villager)
		_villager.position = stand
		_villager.rotation.y = h.rotation.y
	_mote = _make_mote(0.008)
	var who := asker()
	if who:
		who.add_child(_mote)
		_mote.position = Vector3(0, 0.085, 0)
	else:
		add_child(_mote)
		_mote.position = h.position + Vector3(0, ModelUtil.bounds(h.get_child(0)).end.y + 0.02, 0)
	_say("before")
	if game.with_rig and not shown_kinds.has(kind):
		shown_kinds[kind] = true
		_show_ghost()


func asker() -> Node3D:
	return _helper if _helper else _villager


func info() -> Dictionary:
	## For the ledger's quest page.
	var who := StoryText.villager_name(_helper.voice) if _helper and _helper.voice != "" else "A villager"
	return {"kind": kind, "name": GameConfig.REQUESTS[kind]["name"], "who": who, "ask": StoryText.task(TASK_ID.get(kind, ""), "before"),
		"how": HOW.get(kind, ""), "reward": reward, "done": done}


func grabbable() -> bool:
	return prop != null and not done


func grab_point() -> Vector3:
	## World position a hand has to be near to grab the prop (far away for quests with nothing to carry).
	if prop == null:
		return Vector3(0, -1000, 0)
	return prop.global_position + Vector3(0, 0.008, 0)


func grab() -> bool:
	if done or held or prop == null:
		return false
	held = true
	_drop_ghost()
	return true


func move_to(local: Vector3) -> void:
	## While held: the prop follows the hand (board-local). The cart and the lamb stay on the ground.
	if not held:
		return
	if kind == "cart" or kind == "bird":
		local.y = 0.0
	prop.position = local


func release() -> bool:
	## Let go: true when that finished the request.
	if not held:
		return false
	held = false
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
	for m in [_mote, _prop_mote]:
		if m:
			m.visible = false
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
	var line := StoryText.task(TASK_ID.get(kind, ""), which)
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
	var q := QuadMesh.new()
	q.size = Vector2(0.016, 0.016)
	diamond.mesh = q
	diamond.rotation.z = PI / 4.0
	diamond.position.y = 0.012
	var mat := ModelUtil.flat_material(Color("EE8FA8"))  # flower_pink
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
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


func _free_beside(h: House) -> Vector3:
	## The first side of the house (back, right, left, front) with open ground: no house, tower or forest
	## within a cell of it.
	for dir in [-h.basis.z, h.basis.x, -h.basis.x, h.basis.z]:
		var p: Vector3 = h.position + dir * GameConfig.CELL * 2.3
		var c := NavGrid.local_to_cell(p)
		var clear := true
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := c + Vector2i(dx, dy)
				if n.x < 1 or n.y < 1 or n.x > GameConfig.SIZE - 2 or n.y > GameConfig.SIZE - 2 or game.nav.kind.has(n):
					clear = false
		if clear:
			return p
	return h.position - h.basis.z * GameConfig.CELL * 2.3


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
