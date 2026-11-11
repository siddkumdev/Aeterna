class_name BossVfx
extends Node3D
## The Warden's effects (the user, 2026-11-11: "make crazy vfx for the boss"). Lives on the boss Enemy; one set per form
## (a summons, b crystal bloom, c unravelling rage, d final stand), built on the model's anchors (halo_anchor, eye_anchor,
## bloom_anchor, sigil_anchor, ribbon_anchor_1..3, crystal_anchor_1..3). Palette: Warden purple, gold, ember; never blue.
## Logged in docs/VFX_NOTES.md. Everything is capped: a handful of CPU emitters, no per-frame allocation.

const PURPLE := Color("8A5BC7")
const DEEP := Color("3B1F5C")
const GOLD := Color("FFD45A")
const EMBER := Color("F6A45D")
const RED := Color("E8452C")
const MAROON := Color("7A2318")

var boss: Enemy
var form := -1

var _halo: MeshInstance3D
var _eye: MeshInstance3D
var _live: Array[Node] = []
var _t := 0.0
var _pulse_t := 0.0


func setup(b: Enemy) -> void:
	boss = b
	boss.add_child(self)
	enter_form(0)


func enter_form(i: int, announce := false) -> void:
	form = i
	for n in _live:
		if is_instance_valid(n):
			n.queue_free()
	_live.clear()
	_halo = null
	_eye = null
	var rig: CharacterRig = boss._rig
	if rig == null or rig.model == null:
		return
	var halo_at := rig.marker("halo_anchor")
	if halo_at:
		_halo = VfxKit.halo(halo_at, 0.10, Color(GOLD, 0.16))
		_live.append(_halo)
	var eye_at := rig.marker("eye_anchor")
	if eye_at:
		_eye = VfxKit.halo(eye_at, 0.03, Color(PURPLE, 0.8))
		_live.append(_eye)
	match form:
		0:  # a: embers drift off the broken ring, a gold wisp at each relic
			_stream("halo_anchor", EMBER, RED, 14, 1.2, 0.006, Vector3(0, 0.012, 0))
			_stream("sigil_anchor", GOLD, EMBER, 8, 0.8, 0.004, Vector3(0, 0.006, 0))
		1:  # b: the bloom opens: petals fall round it, pollen glows, the crystals shed light
			_stream("bloom_anchor", MAROON, DEEP, 22, 2.0, 0.007, Vector3(0, -0.012, 0), false)
			_stream("bloom_anchor", GOLD, PURPLE, 16, 1.6, 0.004, Vector3(0, 0.010, 0))
			for k in 3:
				_stream("crystal_anchor_%d" % (k + 1), PURPLE, DEEP, 8, 0.8, 0.005, Vector3(0, 0.008, 0))
		2:  # c: it unravels: ribbons of red and purple pour off the hem, the halo burns
			for k in 3:
				_stream("ribbon_anchor_%d" % (k + 1), RED, MAROON, 26, 1.4, 0.007, Vector3(0, 0.004, 0))
			_stream("halo_anchor", RED, EMBER, 24, 1.0, 0.008, Vector3(0, 0.014, 0))
			_stream("eye_anchor", RED, EMBER, 10, 0.6, 0.004, Vector3(0, 0.008, 0))
		3:  # d: the final stand: spores rise, the corona flares, gold motes spiral up
			_stream("bloom_anchor", PURPLE, DEEP, 30, 2.2, 0.006, Vector3(0, 0.016, 0))
			_stream("halo_anchor", GOLD, EMBER, 30, 1.2, 0.007, Vector3(0, 0.012, 0))
			_stream("sigil_anchor", GOLD, RED, 12, 1.0, 0.005, Vector3(0, 0.010, 0))
			for k in 3:
				_stream("ribbon_anchor_%d" % (k + 1), PURPLE, MAROON, 14, 1.4, 0.006, Vector3(0, 0.010, 0))
	if announce:
		transition()


func _stream(anchor: String, a: Color, b: Color, rate: int, life: float, size: float, gravity: Vector3, additive := true) -> void:
	var at := boss._rig.marker(anchor)
	if at == null:
		return
	var p := VfxKit.trail(at, a, b, rate, life, size)
	p.gravity = gravity
	p.spread = 90.0
	p.initial_velocity_max = 0.02
	if not additive:
		p.material_override = VfxKit.material("disc", true, false)
	_live.append(p)


func transition() -> void:
	## The change of form: a flash, three shockwave rings and a burst of petals and embers.
	var at := boss.global_position + Vector3(0, 0.05, 0)
	var root := boss.get_parent()
	if root == null or not boss.is_inside_tree():
		return
	VfxKit.flash(root, at, Color(GOLD, 0.6), 0.16, 0.35)
	for k in 3:
		get_tree().create_timer(0.12 * k).timeout.connect(func():
			if is_instance_valid(boss) and boss.is_inside_tree():
				VfxKit.ring(root, boss.global_position, Color(PURPLE if k % 2 == 0 else GOLD, 0.9), 0.16 + 0.05 * k, 0.7))
	VfxKit.burst(root, at, GOLD, PURPLE, 36, 0.10, 0.9, 0.009, 0.0)
	VfxKit.burst(root, at, RED, EMBER, 24, 0.07, 0.7, 0.007, -0.05)
	VfxKit.paint_ring(root, at, 0.34, 0.6, true)


func hit_pulse() -> void:
	## A short brightening of the halo and eye (called when the boss takes a hit).
	_pulse_t = 0.18


func _process(delta: float) -> void:
	_t += delta
	_pulse_t = maxf(0.0, _pulse_t - delta)
	var k := 1.0 + 0.9 * _pulse_t / 0.18
	if _halo and is_instance_valid(_halo):
		var rage := 1.0 if form >= 2 else 0.0
		var col := GOLD.lerp(RED, rage * (0.5 + 0.5 * sin(_t * 3.0)))
		VfxKit.set_halo(_halo, (0.10 + 0.02 * sin(_t * 2.0) + 0.015 * form) * k, Color(col, 0.15 + 0.05 * sin(_t * 1.7)))
	if _eye and is_instance_valid(_eye):
		var flick := 0.6 + 0.4 * sin(_t * 9.0) * sin(_t * 3.3)
		VfxKit.set_halo(_eye, 0.02 * k, Color(PURPLE if form < 2 else RED, 0.3 + 0.4 * flick))
