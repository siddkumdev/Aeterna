extends SceneTree
## Hero frames for the store / Devpost thumbnail (desktop window needed, not --headless):
##   <godot console> --xr-mode off --resolution 1800x1200 --path godot -s res://tools/thumb_shot.gd -- OUT_PREFIX [distance factor] [aim x,y,z] [dof far m] [lift m]
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
	var centre: Vector3 = g.board.global_position if g.board else Vector3.ZERO
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	if dof_far > 0.0:
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = dof_far
		ca.dof_blur_far_transition = dof_far * 0.8
		ca.dof_blur_amount = 0.12
		cam.attributes = ca
	print("THUMBSHOT centre ", centre)
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
			var img := root.get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("%s_%s_%d.png" % [prefix, mood, a])
	print("THUMBSHOT saved ", prefix, "_*.png")
	quit()


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
