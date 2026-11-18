extends SceneTree
## Hero frames for the store / Devpost thumbnail (desktop window needed, not --headless):
##   <godot console> --xr-mode off --resolution 1800x1200 --path godot -s res://tools/thumb_shot.gd -- OUT_PREFIX [distance factor] [aim x,y,z] [dof far m] [lift m]
## Env THUMB_SIZE=2560x1440 renders off-screen at that size (bigger than the screen allows).
## Builds a game with a few towers, hides every UI piece (tray, slip, bubbles, clock, labels, desktop buttons) and
## shoots the island from a few low three-quarter angles in the dusk and day moods, on a transparent background: OUT_PREFIX_<mood>_<angle>.png.

const MOODS := ["dusk", "day"]
# camera offsets from the board centre (metres) and field of view
const ANGLES := [
	[Vector3(-1.10, 0.62, 1.15), 34.0],
	[Vector3(-1.25, 0.48, 1.05), 32.0],
	[Vector3(1.15, 0.55, 1.15), 34.0],
]
const HIDE_NAME := ["Slip", "Toast", "Tray", "Clock", "Hint", "Label", "Ghost", "Compass"]
var _vp: Viewport  # what gets saved: the window, or the off-screen SubViewport when THUMB_SIZE is set
const FREE_NAME := ["Bubble", "Hand", "mouse_hand", "Cursor", "Pointer"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := args[0] if args.size() > 0 else "thumb"
	var dist := float(args[1]) if args.size() > 1 else 1.0  # camera distance factor: 1.38 whole island (icon), 1.0 village, 0.8 close
	var aim := Vector3.ZERO  # look-at offset from the board centre, "x,y,z" in metres
	if args.size() > 2:
		var p := args[2].split(",")
		aim = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var dof_far := float(args[3]) if args.size() > 3 else 0.0  # > 0: blur beyond this distance (miniature look)
	var lift := float(args[4]) if args.size() > 4 else 0.0  # tilt the view up by aiming this much higher (camera stays): room for a title
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.faith = 2000
	g.cards = {}
	for t in [["fire", Vector2i(6, 12)], ["airship", Vector2i(16, 14)], ["guard", Vector2i(9, 17)], ["crossbow", Vector2i(16, 8)], ["fire", Vector2i(14, 18)]]:
		g.try_build(t[0], t[1])
	g.set_process(false)
	for i in 10:
		await process_frame
	_hide_ui(g)
	root.transparent_bg = true
	_vp = root
	var centre: Vector3 = g.board.global_position if g.board else Vector3.ZERO
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var sz := OS.get_environment("THUMB_SIZE")  # "2560x1440": render off-screen at this size (the desktop window is clamped to the screen)
	if sz != "":
		var p := sz.split("x")
		var sv := SubViewport.new()
		sv.size = Vector2i(int(p[0]), int(p[1]))
		sv.transparent_bg = true
		sv.world_3d = root.find_world_3d()
		sv.msaa_3d = root.msaa_3d
		sv.screen_space_aa = root.screen_space_aa
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var c2 := Camera3D.new()
		sv.add_child(c2)
		c2.make_current()
		cam = c2
		_vp = sv
	if dof_far > 0.0:
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = dof_far
		ca.dof_blur_far_transition = dof_far * 0.8
		ca.dof_blur_amount = 0.12
		cam.attributes = ca
	print("THUMBSHOT centre ", centre)
	if OS.get_environment("THUMB_GROUP") != "":
		await _group(g, cam, prefix)
		quit()
		return
	if OS.get_environment("THUMB_PORTRAIT") != "":
		await _portraits(g, cam, prefix)
		quit()
		return
	for mood in MOODS:
		g.lighting.set_mood(mood, 0.0)
		for i in 20:
			await process_frame
		_no_fog(root)  # fog writes alpha on a transparent background and washes the island out
		for a in ANGLES.size():
			_hide_ui(g)
			cam.global_position = centre + aim + ANGLES[a][0] * dist
			cam.fov = ANGLES[a][1]
			cam.look_at(centre + aim + Vector3(0, lift, 0), Vector3.UP)
			for i in 8:
				await process_frame
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s_%s_%d.png" % [prefix, mood, a])
	print("THUMBSHOT saved ", prefix, "_*.png")
	quit()


# Character portraits (env THUMB_PORTRAIT=1, optional THUMB_ONLY=<index>, THUMB_YAW=<deg>, THUMB_DIST=<x height>):
# one eye-level frame per villager, close in front of its face, the village blurred behind: PREFIX_<mood>_v<i>.png
func _portraits(g: Game, cam: Camera3D, prefix: String) -> void:
	var only := int(OS.get_environment("THUMB_ONLY")) if OS.get_environment("THUMB_ONLY") != "" else -1
	var yaw := float(OS.get_environment("THUMB_YAW")) if OS.get_environment("THUMB_YAW") != "" else 25.0
	var k := float(OS.get_environment("THUMB_DIST")) if OS.get_environment("THUMB_DIST") != "" else 2.6
	var vs: Array = g.life.villagers if g.life else []
	print("THUMBSHOT villagers ", vs.size())
	for mood in MOODS:
		g.lighting.set_mood(mood, 0.0)
		for i in 20:
			await process_frame
		_no_fog(root)
		for i in vs.size():
			if only >= 0 and i != only:
				continue
			var v: Node3D = vs[i]
			if not v.visible:
				continue
			_hide_ui(g)
			var box := _aabb(v, v.global_transform)
			var h: float = max(box.size.y, 0.02)
			var base: Vector3 = v.global_position
			var fwd: Vector3 = (v.rig.global_basis.z if v.rig else v.global_basis.z)
			fwd.y = 0.0
			fwd = fwd.normalized().rotated(Vector3.UP, deg_to_rad(yaw))
			var eye := base + Vector3(0, h * 0.62, 0)
			cam.fov = 34.0
			cam.global_position = eye + fwd * h * k + Vector3(0, h * 0.75, 0)
			cam.look_at(eye - Vector3(0, h * 0.05, 0), Vector3.UP)
			var ca := CameraAttributesPractical.new()
			ca.dof_blur_far_enabled = true
			ca.dof_blur_far_distance = h * k * 1.5
			ca.dof_blur_far_transition = h * k * 1.5
			ca.dof_blur_amount = 0.25
			cam.attributes = ca
			for f in 8:
				await process_frame
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s_%s_v%d.png" % [prefix, mood, i])
			print("THUMBSHOT v", i, " ", v.key, " ", v.job, " h=", h)


# Group portrait (env THUMB_GROUP=1): a few real villagers staged on the open square in front of the statue,
# facing the camera and waving, shot at their eye level with the village blurred behind: PREFIX_<mood>_g<n>.png
const GROUP := [["cat_girl", -0.075, 0.115, "wave"], ["dancer_butterfly", -0.025, 0.135, "cheer"],
	["farmer_horse", 0.03, 0.13, "wave"], ["bee_kid", 0.075, 0.11, "cheer"], ["kid_bunny", -0.05, 0.075, "wave"],
	["elder_ram", 0.055, 0.07, "talk"]]


func _group(g: Game, cam: Camera3D, prefix: String) -> void:
	var statue := _find(root, "statue")
	var sp: Vector3 = statue.global_position if statue else Vector3(0, 0.837, -0.831)
	print("THUMBSHOT statue ", statue.name if statue else "none", " ", sp)
	if g.life:
		g.life.set_process(false)
	var vs: Array = g.life.villagers if g.life else []
	var ground := sp.y
	var hs := []
	for v in vs:
		hs.append(v.global_position.y)
	hs.sort()
	if hs.size() > 0:
		ground = hs[hs.size() / 2]
	var camd := float(OS.get_environment("THUMB_DIST")) if OS.get_environment("THUMB_DIST") != "" else 0.22
	var yaw := deg_to_rad(float(OS.get_environment("THUMB_YAW")) if OS.get_environment("THUMB_YAW") != "" else 0.0)
	var gs := float(OS.get_environment("THUMB_SPREAD")) if OS.get_environment("THUMB_SPREAD") != "" else 0.7
	var cam_pos := sp + Vector3(0.012, 0, camd).rotated(Vector3.UP, yaw)
	cam_pos.y = ground + float(OS.get_environment("THUMB_CAMY")) if OS.get_environment("THUMB_CAMY") != "" else ground + 0.06
	for v in vs:
		for e in GROUP:
			if v.key == e[0]:
				var gp: Vector3 = sp + Vector3(e[1] * gs, 0, e[2] * gs).rotated(Vector3.UP, yaw)
				gp.y = ground
				v.state = "stay"
				v.visible = true
				v.scale = Vector3.ONE
				v.global_position = gp
				var d: Vector3 = cam_pos - gp
				v.rotation.y = atan2(d.x, d.z) - v.get_parent().global_rotation.y
				v.rig.anim = e[3]
				v.rig.gait = 0.0
	if OS.get_environment("THUMB_CAT") != "":  # the village cat, sitting in the front row facing the camera
		var cat: Node3D = load("res://assets/village/ew_village_cat_v02.glb").instantiate()
		g.add_child(cat)
		var cp: Vector3 = sp + Vector3(float(OS.get_environment("THUMB_CATX")) if OS.get_environment("THUMB_CATX") != "" else -0.03, 0, float(OS.get_environment("THUMB_CATZ")) if OS.get_environment("THUMB_CATZ") != "" else 0.17).rotated(Vector3.UP, yaw)
		cp.y = ground
		cat.global_position = cp
		var cd: Vector3 = cam_pos - cp
		cat.rotation.y = atan2(cd.x, cd.z)
		var cs := float(OS.get_environment("THUMB_CATSCALE")) if OS.get_environment("THUMB_CATSCALE") != "" else 1.0
		cat.scale = Vector3.ONE * cs
		print("THUMBSHOT cat bounds ", ModelUtil.bounds(cat))
	for mood in MOODS:
		g.lighting.set_mood(mood, 0.0)
		for i in 20:
			await process_frame
		_no_fog(root)
		_hide_ui(g)
		cam.fov = float(OS.get_environment("THUMB_FOV")) if OS.get_environment("THUMB_FOV") != "" else 30.0
		cam.global_position = cam_pos
		var look: Vector3 = sp + Vector3(0, 0, 0.05).rotated(Vector3.UP, yaw)
		look.y = ground + (float(OS.get_environment("THUMB_LOOKY")) if OS.get_environment("THUMB_LOOKY") != "" else 0.04)
		cam.look_at(look, Vector3.UP)
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = camd
		ca.dof_blur_far_transition = 0.4
		ca.dof_blur_amount = 0.18
		cam.attributes = ca
		for t in 3:  # three moments of the wave loop
			for f in 9:
				await process_frame
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s_%s_g%d.png" % [prefix, mood, t])
	print("THUMBSHOT group saved")


func _find(n: Node, part: String) -> Node3D:
	if n is Node3D and part in str(n.name).to_lower():
		return n
	for c in n.get_children():
		var r := _find(c, part)
		if r:
			return r
	return null


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for ch in n.get_children():
		var t := xf * (ch as Node3D).transform if ch is Node3D else xf
		var b := AABB()
		if ch is VisualInstance3D and (ch as VisualInstance3D).visible:
			b = Transform3D(t.basis, t.origin - xf.origin) * (ch as VisualInstance3D).get_aabb()
			b.position += xf.origin - xf.origin
		var cb := _aabb(ch, t)
		if cb.size != Vector3.ZERO:
			b = cb if b.size == Vector3.ZERO else b.merge(cb)
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


func _hide_ui(g: Game) -> void:
	for n in [g._hud, g._msg, g._clock, g._toast, g._slip, g._tray, g.hud_root, g._lens, g._fast_glass, g._faith_seal,
			g._board_compass, g._grid_lines, g._ghost, g.ledger, g._hand_stem, g._hand_ring, g._sun, g.veil]:
		if n is Node3D:
			n.visible = false
	_walk(root)


func _walk(n: Node) -> void:
	if n is CanvasItem:
		n.visible = false
		return
	if n is Label3D:
		n.visible = false
	elif n is Node3D:
		for k in FREE_NAME:
			if k in str(n.name):
				n.get_parent().remove_child(n)
				n.queue_free()
				return
		for k in HIDE_NAME:
			if k in str(n.name):
				n.visible = false
				break
	for c in n.get_children():
		_walk(c)



func _no_fog(n: Node) -> void:
	if n is WorldEnvironment and n.environment:
		n.environment.fog_enabled = false
		n.environment.volumetric_fog_enabled = false
	if n is Camera3D and n.environment:
		n.environment.fog_enabled = false
	for c in n.get_children():
		_no_fog(c)
