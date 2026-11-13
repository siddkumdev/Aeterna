class_name OpeningStage
extends Node3D
## The opening (the user, 2026-11-11: "like an actual opening scene, a full experience, not acted out in the village";
## "make it like a puppet show"): a paper-cutout puppet theatre that appears in front of you before the island does.
## Six chapters of about 20 s: the island and the Veil, Skotos the forgotten god, the curse, the fall, the hourglass,
## your turn. Every puppet is a flat cut-out built in code from palette colours (no outside art), with a soft paper
## shadow, sliding on rods in layers that parallax as you move your head. Gilded captions under each scene. Words are
## in docs/STORY.md ("The opening"). Skip: hold a pinch (or the mouse), or press Space / Esc.
## Palette only: Warden purple for Skotos, gold and ember for the Veil, never blue.

signal finished

const W := 1.1  # m, the stage's width
const H := 0.66  # m
const CHAPTER_TIME := 20.0
const SKIP_HOLD := 0.8  # s of a held pinch that skips it
const INK := Color("111C30")
const NIGHT := Color("1B1226")
const DEEP := Color("3B1F5C")
const PURPLE := Color("8A5BC7")
const MAROON := Color("7A2318")
const OAK := Color("5B2920")
const GOLD := Color("E8B83A")
const GLOW := Color("FFD45A")
const EMBER := Color("F6A45D")
const RED := Color("E8452C")
const CREAM := Color("F4E4B8")
const WALL := Color("EAD9A8")
const ROOF := Color("D9673A")
const GRASS := Color("6FA04F")
const GRASS_D := Color("4F7F3A")
const ROCK := Color("7A5A3C")
const PINE := Color("2F5D3A")
const PINE_D := Color("1E3F2B")

const CHAPTERS := [
	{"name": "I.  THE ISLAND", "lines": [
		["Beyond the edge of the map,", "a very small island floats."],
		["Twelve people live on it,", "and one small god who watches over them."],
		["Their faith weaves the Veil:", "a warm dome of light that keeps the dark away."]]},
	{"name": "II.  THE FORGOTTEN", "lines": [
		["In the Dark Wood around it,", "another god once ruled."],
		["His name was Skotos.", "His temples rotted. His people forgot him."],
		["And a god who is forgotten", "goes hungry."]]},
	{"name": "III.  THE CURSE", "lines": [
		["So Skotos laid a curse upon your island:", ""],
		["\"At every nightfall,", "your Veil will fail.\""],
		["\"Let us see how long they believe", "in a god who cannot keep the dark out.\""]]},
	{"name": "IV.  THE FALL", "lines": [
		["Five days to build. Five nights to hold.", ""],
		["The dark grows stronger each night.", ""],
		["And on the fifth night,", "the village always falls."]]},
	{"name": "V.  THE HOURGLASS", "lines": [
		["But you are a god.", ""],
		["You turn the hourglass,", "and time runs back."],
		["The village wakes again.", "Only you remember."]]},
	{"name": "VI.  YOUR TURN", "lines": [
		["Each day, build before the sun sets.", ""],
		["Help your people. Their faith is your light.", ""],
		["Watch over them.", ""]]},
]

var game
var _content: Node3D  # the current chapter's puppets
var _head_root: Node3D  # the chapter name, above the stage
var _cap_root: Node3D  # the captions, below it
var _hint_root: Node3D
var _frame: Node3D
var _chapter := -1
var _t := 0.0
var _tick := Callable()
var _skip_t := 0.0
var _skipped := false
var _started := false
var _fade: MeshInstance3D
var _lines_shown := 0
var _movers: Array = []  # [node, base position, phase, amplitude]


# ------------------------------------------------------------------ shapes
static func ellipse(cx: float, cy: float, rx: float, ry: float, n := 20) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return p


static func rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func tri(a: Vector2, b: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b, c])


static func arc_band(cx: float, cy: float, r: float, w: float, a0: float, a1: float, n := 28) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		p.append(Vector2(cx + cos(a) * (r + w / 2.0), cy + sin(a) * (r + w / 2.0)))
	for i in range(n, -1, -1):
		var a := lerpf(a0, a1, float(i) / n)
		p.append(Vector2(cx + cos(a) * (r - w / 2.0), cy + sin(a) * (r - w / 2.0)))
	return p


static func ridge(x0: float, x1: float, base: float, amp: float, freq: float, ph: float, bottom: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		p.append(Vector2(x, base + sin(x * freq + ph) * amp + sin(x * freq * 2.3 + ph * 1.7) * amp * 0.4))
	p.append(Vector2(x1, bottom))
	p.append(Vector2(x0, bottom))
	return p


func poly(parent: Node3D, pts: PackedVector2Array, col: Color, z := 0.0, shadow := true) -> MeshInstance3D:
	## One flat paper piece: the polygon, with a soft dark shadow cut behind it.
	var idx := Geometry2D.triangulate_polygon(pts)
	var mi := MeshInstance3D.new()
	var verts := PackedVector3Array()
	for p in pts:
		verts.append(Vector3(p.x, p.y, 0))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	if not idx.is_empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if col.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.z = z
	parent.add_child(mi)
	if shadow and col.a >= 0.99:
		var sh := mi.duplicate() as MeshInstance3D
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color(0, 0, 0, 0.35)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sh.material_override = sm
		sh.position = Vector3(0.007, -0.009, -0.004)
		mi.add_child(sh)
	return mi


func group(parent: Node3D, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = at
	parent.add_child(g)
	return g


# ------------------------------------------------------------------ puppets
func sky(top: Color, bottom: Color, z := -0.02) -> void:
	var n := 8
	for i in n:
		var y0 := lerpf(H / 2.0, -H / 2.0, float(i) / n)
		var y1 := lerpf(H / 2.0, -H / 2.0, float(i + 1) / n)
		poly(_content, rect(-W / 2.0 - 0.02, y1 - 0.002, W / 2.0 + 0.02, y0), top.lerp(bottom, float(i) / (n - 1)), z, false)


func stars(count: int, seed_: int, col := CREAM, z := -0.015) -> Node3D:
	var g := group(_content, Vector3(0, 0, z))
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	for i in count:
		var c := Vector2(r.randf_range(-W / 2.0, W / 2.0), r.randf_range(-0.05, H / 2.0))
		var s := r.randf_range(0.004, 0.011)
		var star := poly(g, PackedVector2Array([c + Vector2(0, s * 2), c + Vector2(s * 0.5, s * 0.5), c + Vector2(s * 2, 0), c + Vector2(s * 0.5, -s * 0.5), c + Vector2(0, -s * 2),
			c + Vector2(-s * 0.5, -s * 0.5), c + Vector2(-s * 2, 0), c + Vector2(-s * 0.5, s * 0.5)]), col, 0.0, false)
		_movers.append([star, star.position, r.randf() * TAU, 0.0])
	return g


func pine(parent: Node3D, x: float, y: float, h: float, col: Color, z := 0.0) -> void:
	var w := h * 0.42
	poly(parent, rect(x - w * 0.07, y, x + w * 0.07, y + h * 0.2), OAK, z, false)
	for k in 3:
		var by := y + h * (0.15 + k * 0.26)
		var ww := w * (1.0 - k * 0.28)
		poly(parent, tri(Vector2(x - ww, by), Vector2(x + ww, by), Vector2(x, by + h * 0.4)), col, z + 0.001 * k)


func house(parent: Node3D, x: float, y: float, s: float, wall := WALL, roof := ROOF, lit := true, z := 0.0) -> Node3D:
	var g := group(parent, Vector3(x, y, z))
	poly(g, rect(-s * 0.5, 0, s * 0.5, s * 0.55), wall)
	poly(g, tri(Vector2(-s * 0.62, s * 0.52), Vector2(s * 0.62, s * 0.52), Vector2(0, s * 1.05)), roof, 0.001)
	poly(g, rect(-s * 0.12, s * 0.14, s * 0.12, s * 0.4), GLOW if lit else Color("3A2A22"), 0.002, false)
	poly(g, rect(s * 0.28, s * 0.62, s * 0.38, s * 0.9), Color("8A8A86"), 0.0005, false)
	return g


func villager(parent: Node3D, x: float, y: float, col: Color, s := 1.0) -> Node3D:
	var g := group(parent, Vector3(x, y, 0))
	poly(g, PackedVector2Array([Vector2(-0.010, 0), Vector2(0.010, 0), Vector2(0.006, 0.028), Vector2(-0.006, 0.028)]).duplicate(), col, 0.0, false)
	poly(g, ellipse(0, 0.036, 0.008, 0.008, 10), Color("F2C9A0"), 0.001, false)
	g.scale = Vector3.ONE * s
	return g


func sun(parent: Node3D, x: float, y: float, r: float, col := GLOW) -> Node3D:
	var g := group(parent, Vector3(x, y, 0))
	for k in 12:
		var a := TAU * k / 12
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		poly(g, tri(d * r * 1.05 + n * r * 0.13, d * r * 1.05 - n * r * 0.13, d * r * 1.55), EMBER, 0.0, false)
	poly(g, ellipse(0, 0, r, r, 24), col, 0.001, false)
	return g


func island(parent: Node3D, x: float, y: float, s: float, lit := true) -> Node3D:
	## A floating island: grass top, hanging rock, little houses, trees, a well.
	var g := group(parent, Vector3(x, y, 0))
	poly(g, PackedVector2Array([Vector2(-0.20 * s, 0), Vector2(0.20 * s, 0), Vector2(0.14 * s, -0.06 * s), Vector2(0.07 * s, -0.12 * s), Vector2(0.02 * s, -0.17 * s), Vector2(-0.03 * s, -0.11 * s),
		Vector2(-0.10 * s, -0.07 * s)]), ROCK, 0.0)
	poly(g, rect(-0.20 * s, -0.012 * s, 0.20 * s, 0.0), Color("5E4228"), 0.001, false)
	poly(g, ellipse(0, 0.012 * s, 0.205 * s, 0.045 * s, 28), GRASS, 0.002)
	poly(g, ellipse(0, 0.016 * s, 0.19 * s, 0.032 * s, 28), GRASS_D, 0.003, false)
	house(g, -0.09 * s, 0.020 * s, 0.07 * s, WALL, ROOF, lit, 0.004)
	house(g, 0.03 * s, 0.014 * s, 0.06 * s, WALL, Color("3E8F86"), lit, 0.004)
	house(g, 0.12 * s, 0.024 * s, 0.05 * s, WALL, ROOF, lit, 0.004)
	pine(g, -0.16 * s, 0.026 * s, 0.07 * s, PINE, 0.005)
	pine(g, 0.17 * s, 0.03 * s, 0.06 * s, PINE_D, 0.005)
	return g


func veil(parent: Node3D, cx: float, cy: float, r: float, a := 0.5) -> MeshInstance3D:
	## The Veil: a warm gold dome over the island, two bands.
	var v := poly(parent, arc_band(cx, cy, r, 0.012, 0.0, PI), Color(GLOW, a), 0.02, false)
	poly(v, arc_band(cx, cy, r * 0.96, 0.022, 0.0, PI), Color(EMBER, a * 0.4), 0.0, false)
	return v


func skotos(parent: Node3D, x: float, y: float, s: float) -> Node3D:
	## Skotos: tall, hooded in dark, a bone mask, a crown of spikes and an eclipse halo behind the head (the Warden's purples and gold).
	var g := group(parent, Vector3(x, y, 0))
	var halo := group(g, Vector3(0, 0.34 * s, -0.01))
	for k in 18:
		var a := TAU * k / 18
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var L := 0.075 * s if k % 2 == 0 else 0.048 * s
		poly(halo, tri(d * 0.085 * s + n * 0.008 * s, d * 0.085 * s - n * 0.008 * s, d * (0.085 * s + L)), GOLD if k % 3 else PURPLE, 0.0, false)
	poly(halo, ellipse(0, 0, 0.085 * s, 0.085 * s, 28), INK, 0.001, false)
	poly(halo, arc_band(0, 0, 0.09 * s, 0.008 * s, 0.0, TAU, 36), GOLD, 0.002, false)
	poly(g, PackedVector2Array([Vector2(-0.07 * s, 0), Vector2(0.07 * s, 0), Vector2(0.045 * s, 0.26 * s), Vector2(0.03 * s, 0.30 * s), Vector2(-0.03 * s, 0.30 * s), Vector2(-0.045 * s, 0.26 * s)]), DEEP, 0.003)
	poly(g, rect(-0.06 * s, 0.10 * s, 0.06 * s, 0.112 * s), GOLD, 0.004, false)
	poly(g, ellipse(0, 0.335 * s, 0.032 * s, 0.040 * s, 16), CREAM, 0.005)
	poly(g, rect(-0.016 * s, 0.338 * s, -0.006 * s, 0.346 * s), INK, 0.006, false)
	poly(g, rect(0.006 * s, 0.338 * s, 0.016 * s, 0.346 * s), INK, 0.006, false)
	for k in 7:
		var cx := lerpf(-0.03, 0.03, k / 6.0) * s
		var h := (0.040 if k % 2 == 0 else 0.026) * s
		poly(g, tri(Vector2(cx - 0.006 * s, 0.368 * s), Vector2(cx + 0.006 * s, 0.368 * s), Vector2(cx, 0.368 * s + h)), GOLD, 0.005, false)
	for sx in [-1, 1]:  # long arms spread wide
		poly(g, PackedVector2Array([Vector2(sx * 0.05 * s, 0.24 * s), Vector2(sx * 0.14 * s, 0.30 * s), Vector2(sx * 0.15 * s, 0.285 * s), Vector2(sx * 0.055 * s, 0.215 * s)]), DEEP, 0.002)
	return g


func hourglass(parent: Node3D, x: float, y: float, s: float) -> Node3D:
	var g := group(parent, Vector3(x, y, 0))
	poly(g, tri(Vector2(-0.07 * s, 0.14 * s), Vector2(0.07 * s, 0.14 * s), Vector2(0, 0.0)), Color(CREAM, 0.55), 0.0, false)
	poly(g, tri(Vector2(-0.07 * s, -0.14 * s), Vector2(0.07 * s, -0.14 * s), Vector2(0, 0.0)), Color(CREAM, 0.55), 0.0, false)
	poly(g, rect(-0.09 * s, 0.14 * s, 0.09 * s, 0.16 * s), GOLD, 0.002)
	poly(g, rect(-0.09 * s, -0.16 * s, 0.09 * s, -0.14 * s), GOLD, 0.002)
	for sx in [-1, 1]:
		poly(g, rect(sx * 0.085 * s - 0.004 * s, -0.14 * s, sx * 0.085 * s + 0.004 * s, 0.14 * s), GOLD, 0.002, false)
	var top := poly(g, tri(Vector2(-0.05 * s, 0.12 * s), Vector2(0.05 * s, 0.12 * s), Vector2(0, 0.02 * s)), GLOW, 0.001, false)
	var bottom := poly(g, tri(Vector2(-0.065 * s, -0.135 * s), Vector2(0.065 * s, -0.135 * s), Vector2(0, -0.04 * s)), GLOW, 0.001, false)
	top.name = "SandTop"
	bottom.name = "SandBottom"
	return g


# ------------------------------------------------------------------ the theatre
func _build_frame() -> void:
	_frame = Node3D.new()
	_frame.name = "Frame"
	add_child(_frame)
	poly(_frame, rect(-W / 2.0 - 0.30, -H / 2.0 - 0.30, W / 2.0 + 0.30, -H / 2.0 - 0.002), Color(0.02, 0.01, 0.03), 0.06, false)  # the dark below
	poly(_frame, rect(-W / 2.0 - 0.30, H / 2.0 + 0.002, W / 2.0 + 0.30, H / 2.0 + 0.30), Color(0.02, 0.01, 0.03), 0.06, false)
	for sx in [-1, 1]:  # curtains
		var curtain := poly(_frame, PackedVector2Array([Vector2(sx * (W / 2.0 + 0.30), H / 2.0 + 0.30), Vector2(sx * (W / 2.0 - 0.07), H / 2.0 + 0.30), Vector2(sx * (W / 2.0 - 0.02), 0.0),
			Vector2(sx * (W / 2.0 - 0.09), -H / 2.0 - 0.30), Vector2(sx * (W / 2.0 + 0.30), -H / 2.0 - 0.30)]), MAROON, 0.07)
		for k in 5:  # folds
			var fx: float = sx * (W / 2.0 + 0.02 + k * 0.05)
			poly(curtain, rect(fx - 0.004, -H / 2.0, fx + 0.004, H / 2.0), Color(0.35, 0.1, 0.08), 0.001, false)
	poly(_frame, PackedVector2Array([Vector2(-W / 2.0 - 0.02, H / 2.0), Vector2(W / 2.0 + 0.02, H / 2.0), Vector2(W / 2.0 + 0.02, H / 2.0 - 0.05), Vector2(0, H / 2.0 - 0.09), Vector2(-W / 2.0 - 0.02, H / 2.0 - 0.05)]), OAK, 0.065)
	poly(_frame, rect(-W / 2.0 - 0.02, H / 2.0 - 0.008, W / 2.0 + 0.02, H / 2.0), GOLD, 0.066, false)
	poly(_frame, rect(-W / 2.0 - 0.02, -H / 2.0, W / 2.0 + 0.02, -H / 2.0 + 0.012), GOLD, 0.066, false)
	for k in 9:  # footlights
		poly(_frame, ellipse(lerpf(-W / 2.0 + 0.06, W / 2.0 - 0.06, k / 8.0), -H / 2.0 + 0.022, 0.011, 0.011, 10), GLOW, 0.067, false)


func _ready() -> void:
	_build_frame()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	_head_root = Node3D.new()
	_head_root.position = Vector3(0, H / 2.0 + 0.075, 0.07)
	add_child(_head_root)
	_cap_root = Node3D.new()
	_cap_root.position = Vector3(0, -H / 2.0 - 0.14, 0.12)
	add_child(_cap_root)
	_hint_root = Node3D.new()
	_hint_root.position = Vector3(0, -H / 2.0 - 0.32, 0.12)
	_hint_root.scale = Vector3.ONE * 0.72
	add_child(_hint_root)
	_fade = poly(self, rect(-W / 2.0 - 0.3, -H / 2.0 - 0.3, W / 2.0 + 0.3, H / 2.0 + 0.3), Color(0, 0, 0, 1), 0.09, false)
	(_fade.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	visible = false


func place(cam: Camera3D, fallback: Vector3) -> void:
	## In front of you, a metre away, turned to face you. In the headset it stays level with your eyes.
	var at := fallback
	var f := Vector3(0, 0, 1)
	if cam:
		f = -cam.global_transform.basis.z
		if game and game._xr:
			f.y = 0.0
		f = f.normalized()
		at = cam.global_position + f * 1.0 + Vector3(0, -0.04 if game and game._xr else 0.0, 0)
	global_position = at
	rotation.y = atan2(-f.x, -f.z)  # +Z (the stage's face) points back at you
	visible = true


func play() -> void:
	## Runs the whole opening; returns when it ends or is skipped.
	_started = true
	var tw := create_tween()
	tw.tween_property(_fade.material_override, "albedo_color:a", 0.0, 1.2)
	_hint_line("Hold a pinch to skip")
	for ch in CHAPTERS.size():
		if _skipped:
			break
		_start_chapter(ch)
		while _t < CHAPTER_TIME and not _skipped:
			await get_tree().process_frame
	var out := create_tween()
	out.tween_property(_fade.material_override, "albedo_color:a", 1.0, 0.8)
	await out.finished
	finished.emit()


func _hint_line(s: String) -> void:
	TitleCard.show_over(_hint_root, Vector3.ZERO, s, "", 4.0, 30)


func _start_chapter(i: int) -> void:
	_chapter = i
	_t = 0.0
	_lines_shown = 0
	_movers.clear()
	if _content:
		_content.queue_free()
	_content = Node3D.new()
	_content.name = "Content"
	add_child(_content)
	_tick = Callable()
	call("_ch%d" % (i + 1))
	TitleCard.show_over(_head_root, Vector3.ZERO, CHAPTERS[i]["name"], "", -1.0, 44)
	if game:
		match i:
			0: game.snd("dawn_bell")
			1: game.snd("forest_rumble")
			2: game.snd("boss_roar")
			3: game.snd("night_fall")
			4: game.snd("heal_chime")
			5: game.snd("dawn_bell")


func _process(delta: float) -> void:
	if not _started:
		return
	_t += delta
	_follow_head(delta)
	_step_skip(delta)
	var lines: Array = CHAPTERS[clampi(_chapter, 0, CHAPTERS.size() - 1)]["lines"]
	if _chapter >= 0 and _lines_shown < lines.size() and _t >= 1.0 + _lines_shown * 6.2:
		TitleCard.show_over(_cap_root, Vector3.ZERO, lines[_lines_shown][0], lines[_lines_shown][1], 5.6, 46)
		_lines_shown += 1
	for m in _movers:
		if is_instance_valid(m[0]):
			(m[0] as Node3D).scale = Vector3.ONE * (0.8 + 0.4 * sin(_t * 2.0 + float(m[2])))
	if _tick.is_valid():
		_tick.call(_t)


func _step_skip(delta: float) -> void:
	var held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ESCAPE)
	if game:
		for h in game._hands:
			if is_instance_valid(h) and h.is_pressing():
				held = true
	if Input.is_key_pressed(KEY_ESCAPE):
		_skip_t = SKIP_HOLD
	_skip_t = _skip_t + delta if held else 0.0
	if _skip_t >= SKIP_HOLD:
		_skipped = true


func _follow_head(delta: float) -> void:
	if not visible or game == null or not game._xr or game._xr_cam == null:
		return
	var cam: Camera3D = game._xr_cam
	var f := -cam.global_transform.basis.z
	f.y = 0.0
	if f.length() < 0.05:
		return
	f = f.normalized()
	var flat := Vector3(global_position.x - cam.global_position.x, 0.0, global_position.z - cam.global_position.z)
	var dist := flat.length()
	if dist < 0.05:
		return
	var d := flat / dist
	if f.angle_to(d) > 0.38:
		var yaw := lerp_angle(atan2(d.x, d.z), atan2(f.x, f.z), minf(1.0, delta * 2.5))
		var dir := Vector3(sin(yaw), 0.0, cos(yaw))
		global_position = Vector3(cam.global_position.x, cam.global_position.y - 0.04, cam.global_position.z) + dir * dist
		rotation.y = atan2(-dir.x, -dir.z)


# ------------------------------------------------------------------ the six chapters (each builds its puppets and sets a per-frame tick)
func _ch1() -> void:
	sky(Color("F6C98A"), Color("F2A65C"))
	var s := sun(_content, 0.30, 0.16, 0.05)
	poly(_content, ridge(-W / 2.0, W / 2.0, -0.25, 0.04, 6.0, 0.4, -H / 2.0), Color("C77D4A"), 0.0)
	poly(_content, ridge(-W / 2.0, W / 2.0, -0.31, 0.03, 7.0, 2.0, -H / 2.0), Color("9A5A3A"), 0.01)
	var isl := island(_content, 0.0, -0.04, 1.9)
	var vil: Array = []
	for i in 6:
		vil.append(villager(isl, -0.15 + i * 0.06, 0.035, [CREAM, RED, GLOW, EMBER, PURPLE, GRASS][i], 1.2))
	var v := veil(_content, 0.0, -0.04, 0.45, 0.0)
	var motes := group(_content, Vector3.ZERO)
	for i in 14:
		var m := poly(motes, ellipse(0, 0, 0.006, 0.006, 8), GLOW, 0.03, false)
		_movers.append([m, Vector3.ZERO, i * 0.7, 0.0])
	_tick = func(t: float):
		isl.position.y = -0.04 + sin(t * 1.2) * 0.012
		s.rotation.z = t * 0.2
		s.position.y = 0.16 + minf(t * 0.004, 0.03)
		for i in vil.size():
			vil[i].position.y = 0.035 + absf(sin(t * 3.0 + i)) * 0.006
		for i in motes.get_child_count():  # faith rises from the people into the sky, then the Veil knits
			var k := fposmod(t * 0.18 + i / 14.0, 1.0)
			var from := Vector2(-0.15 + (i % 7) * 0.05, -0.01)
			(motes.get_child(i) as Node3D).position = Vector3(from.x * (1.0 - k) + 0.0, from.y + k * 0.34 * (1.0 - 0.3 * k), 0.03)
		(v.material_override as StandardMaterial3D).albedo_color.a = clampf((t - 9.0) / 4.0, 0.0, 0.55)
		v.scale = Vector3.ONE * lerpf(0.6, 1.0, clampf((t - 9.0) / 4.0, 0.0, 1.0))
		v.position = Vector3(0, -0.04 * (1.0 - v.scale.x), 0.02)


func _ch2() -> void:
	sky(Color("1A0F26"), Color("3B1F5C"))
	stars(26, 7)
	var moon := poly(_content, ellipse(-0.35, 0.2, 0.05, 0.05, 24), CREAM, -0.01, false)
	poly(moon, ellipse(0.02, 0.01, 0.045, 0.045, 24), Color("2A1740"), 0.001, false)
	var wood := group(_content, Vector3.ZERO)
	for i in 14:
		pine(wood, -0.6 + i * 0.09, -0.34 + (i % 3) * 0.01, 0.2 + (i % 4) * 0.05, Color("0B0814") if i % 2 else Color("120C1E"), 0.0 + (i % 3) * 0.002)
	var temple := group(_content, Vector3(-0.30, -0.30, 0.01))  # a rotting temple: broken pillars, a cracked roof
	for k in 4:
		poly(temple, rect(-0.09 + k * 0.06, 0, -0.07 + k * 0.06, 0.09 - (k % 2) * 0.04), Color("2B2438"))
	poly(temple, tri(Vector2(-0.12, 0.09), Vector2(0.12, 0.09), Vector2(-0.01, 0.15)), Color("2B2438"), 0.001)
	var sk := skotos(_content, 0.16, -0.33, 1.25)
	var faith := group(_content, Vector3.ZERO)
	for i in 10:
		poly(faith, ellipse(0, 0, 0.005, 0.005, 8), GLOW, 0.03, false)
	var far := island(_content, 0.45, 0.02, 0.5)
	_tick = func(t: float):
		sk.position.y = -0.33 + sin(t * 0.9) * 0.008
		var a := clampf(t / 5.0, 0.0, 1.0)  # he appears, then thins: a god who is forgotten goes hungry
		sk.scale = Vector3.ONE * lerpf(1.0, 0.86, clampf((t - 12.0) / 7.0, 0.0, 1.0))
		for i in faith.get_child_count():  # the people's faith drifts away from him toward the little island
			var k := fposmod(t * 0.1 + i / 10.0, 1.0)
			(faith.get_child(i) as Node3D).position = Vector3(lerpf(-0.45 + (i % 5) * 0.09, 0.45, k), lerpf(-0.30, 0.04, k) + sin(k * PI) * 0.1, 0.03)
		far.position.y = 0.02 + sin(t * 1.3) * 0.01
		sk.visible = a > 0.05


func _ch3() -> void:
	sky(Color("2A1330"), Color("5A2A3A"))
	stars(18, 11)
	var isl := island(_content, 0.0, -0.26, 1.4)
	var v := veil(_content, 0.0, -0.26, 0.34, 0.6)
	var sk := skotos(_content, 0.0, -0.17, 0.8)
	var cracks := group(_content, Vector3(0, 0, 0.03))
	var zig := PackedVector2Array([Vector2(0.0, 0.17), Vector2(-0.03, 0.12), Vector2(0.02, 0.08), Vector2(-0.04, 0.03), Vector2(0.01, -0.02), Vector2(-0.02, -0.06)])
	for i in zig.size() - 1:
		var a := zig[i]
		var b := zig[i + 1]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x) * 0.004
		poly(cracks, PackedVector2Array([a + n, b + n, b - n, a - n]), PURPLE, 0.0, false)
	cracks.visible = false
	var shards := group(_content, Vector3.ZERO)
	for i in 10:
		poly(shards, tri(Vector2(-0.01, 0), Vector2(0.01, 0), Vector2(0, 0.025)), GLOW if i % 2 else EMBER, 0.03, false)
	shards.visible = false
	var night := poly(_content, rect(-W / 2.0, -H / 2.0, W / 2.0, H / 2.0), Color(0.05, 0.0, 0.08, 0.0), 0.04, false)
	_tick = func(t: float):
		sk.position = Vector3(0, -0.17 + sin(t) * 0.01, 0)
		sk.scale = Vector3.ONE * (1.0 + 0.15 * clampf(t / 10.0, 0.0, 1.0))
		isl.position.y = -0.26 + sin(t * 1.2) * 0.008
		cracks.visible = t > 8.0
		cracks.scale = Vector3.ONE * (1.0 + maxf(t - 8.0, 0.0) * 0.05)
		v.visible = t < 14.0
		(night.material_override as StandardMaterial3D).albedo_color.a = clampf((t - 14.0) / 5.0, 0.0, 0.5)
		shards.visible = t > 14.0
		for i in shards.get_child_count():  # the Veil breaks into falling embers
			var k := clampf((t - 14.0 - i * 0.12) / 4.0, 0.0, 1.0)
			var a := PI * (0.1 + 0.8 * i / 9.0)
			(shards.get_child(i) as Node3D).position = Vector3(cos(a) * 0.34, -0.26 + sin(a) * 0.34 - k * 0.3, 0.03)
			(shards.get_child(i) as Node3D).rotation.z = k * 6.0 * (1 if i % 2 else -1)


func _ch4() -> void:
	sky(Color("F6C98A"), Color("F2A65C"))
	var isl := island(_content, 0.0, -0.10, 2.0)
	var suns := group(_content, Vector3(0, 0.22, 0))
	var days := []
	for i in 5:  # five days along the top: the sun for each, the fifth one a black sun
		var d := group(suns, Vector3(-0.32 + i * 0.16, 0, 0.0))
		poly(d, ellipse(0, 0, 0.028, 0.028, 18), GLOW if i < 4 else INK, 0.0, false)
		poly(d, arc_band(0, 0, 0.034, 0.005, 0.0, TAU, 24), GOLD if i < 4 else PURPLE, 0.001, false)
		d.scale = Vector3.ZERO
		days.append(d)
	var dark := poly(_content, rect(-W / 2.0, -H / 2.0, W / 2.0, H / 2.0), Color(0.05, 0.0, 0.08, 0.0), 0.03, false)
	var creep := group(_content, Vector3.ZERO)
	for i in 16:  # dark shapes creep in from the edges, low
		var r := RandomNumberGenerator.new()
		r.seed = i * 31
		var x := (-0.55 if i % 2 == 0 else 0.55)
		var m := poly(creep, PackedVector2Array([Vector2(-0.02, 0), Vector2(0.02, 0), Vector2(0.015, 0.05), Vector2(0.0, 0.07), Vector2(-0.015, 0.05)]), Color("0B0814"), 0.035)
		m.position = Vector3(x, -0.20 + r.randf_range(-0.06, 0.04), 0.035)
		m.set_meta("x0", x)
		m.set_meta("i", i)
	_tick = func(t: float):
		isl.position.y = -0.10 + sin(t * 1.2) * 0.01
		for i in days.size():
			days[i].scale = Vector3.ONE * clampf((t - 1.0 - i * 2.6) / 0.8, 0.0, 1.0)
		var night_k := clampf((t - 12.0) / 6.0, 0.0, 1.0)
		(dark.material_override as StandardMaterial3D).albedo_color.a = night_k * 0.55
		for m in creep.get_children():
			var i: int = m.get_meta("i")
			var x0: float = m.get_meta("x0")
			var k := clampf((t - 9.0 - i * 0.2) / 8.0, 0.0, 1.0)
			m.position.x = lerpf(x0, 0.0 + (i % 5 - 2) * 0.06, k)


func _ch5() -> void:
	sky(Color("1A0F26"), Color("3B1F5C"))
	stars(20, 5)
	var hg := hourglass(_content, 0.0, 0.0, 1.9)
	var isl := island(_content, 0.0, -0.25, 0.9)
	var rings := group(_content, Vector3(0, 0, -0.01))
	for r in [0.3, 0.38]:
		poly(rings, arc_band(0, 0, r, 0.006, 0.0, TAU, 40), GLOW if r < 0.35 else EMBER, 0.0, false)
	var ticks := []
	for k in 12:
		var a := TAU * k / 12
		var m := poly(rings, rect(-0.004, 0.31, 0.004, 0.345), GOLD, 0.001, false)
		m.rotation.z = a
		ticks.append(m)
	var hand := poly(_content, PackedVector2Array([Vector2(-0.006, 0), Vector2(0.006, 0), Vector2(0.003, 0.26), Vector2(-0.003, 0.26)]), GLOW, 0.02, false)
	var motes := group(_content, Vector3.ZERO)
	for i in 14:
		poly(motes, ellipse(0, 0, 0.005, 0.005, 8), GLOW, 0.03, false)
	_tick = func(t: float):
		hg.rotation.z = lerpf(0.0, PI, clampf((t - 5.0) / 4.0, 0.0, 1.0))  # it turns over
		var k := clampf((t - 9.0) / 9.0, 0.0, 1.0)  # the sand runs back up
		var top := hg.get_node("SandTop") as MeshInstance3D
		var bottom := hg.get_node("SandBottom") as MeshInstance3D
		top.scale = Vector3.ONE * (0.15 + 0.85 * (1.0 - k) if t > 5.0 else 1.0)
		bottom.scale = Vector3.ONE * (0.15 + 0.85 * k)
		hand.rotation.z = -t * 0.9 if t > 9.0 else 0.0  # the clock hand sweeps backward
		rings.rotation.z = -t * 0.12
		isl.position.y = -0.25 + sin(t * 1.3) * 0.008
		for i in motes.get_child_count():
			var kk := fposmod(t * 0.2 + i / 14.0, 1.0)
			var a := TAU * i / 14 + t * 0.4
			(motes.get_child(i) as Node3D).position = Vector3(cos(a) * (0.08 + kk * 0.3), sin(a) * (0.08 + kk * 0.3), 0.03)


func _ch6() -> void:
	sky(Color("F6D9A0"), Color("F2A65C"))
	sun(_content, 0.0, 0.05, 0.12)
	poly(_content, ridge(-W / 2.0, W / 2.0, -0.24, 0.04, 5.0, 1.0, -H / 2.0), Color("C77D4A"), 0.0)
	var isl := island(_content, 0.0, -0.12, 2.6)
	var v := veil(_content, 0.0, -0.12, 0.58, 0.5)
	var stat := group(_content, Vector3(0, -0.12, 0.05))
	poly(stat, PackedVector2Array([Vector2(-0.012, 0.018), Vector2(0.012, 0.018), Vector2(0.008, 0.06), Vector2(-0.008, 0.06)]), Color("D9A63A"), 0.0)
	poly(stat, ellipse(0, 0.068, 0.008, 0.009, 10), Color("7A2318"), 0.001, false)
	var embers := group(_content, Vector3.ZERO)
	for i in 12:
		poly(embers, ellipse(0, 0, 0.005, 0.005, 8), GLOW, 0.04, false)
	_tick = func(t: float):
		isl.position.y = -0.12 + sin(t * 1.2) * 0.01
		stat.position.y = -0.12 + sin(t * 1.2) * 0.01 + 0.02
		(v.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.15 * sin(t * 1.5)
		for i in embers.get_child_count():
			var k := fposmod(t * 0.15 + i / 12.0, 1.0)
			(embers.get_child(i) as Node3D).position = Vector3(-0.3 + (i % 6) * 0.12, -0.2 + k * 0.5, 0.04)
