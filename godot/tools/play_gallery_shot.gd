extends SceneTree
## Gameplay shots for the Devpost gallery, close over the island (desktop window):
##   <godot console> --xr-mode off --resolution 1500x1000 --path godot -s res://tools/play_gallery_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_day_<a>.png (village with towers and quests by day) and OUT_PREFIX_night_<t>_<a>.png (a night battle).

const ANGLES := [  # camera offset from the board centre (m), look-at offset (m), fov
	[Vector3(0.34, 0.20, 0.42), Vector3(0.14, 0.04, 0.14), 40.0],
	[Vector3(-0.30, 0.18, 0.44), Vector3(-0.12, 0.04, 0.12), 40.0],
	[Vector3(0.0, 0.22, 0.40), Vector3(0.0, 0.05, 0.0), 38.0],
	[Vector3(-0.38, 0.16, -0.30), Vector3(-0.12, 0.04, -0.08), 40.0],
	[Vector3(0.40, 0.16, -0.26), Vector3(0.10, 0.04, -0.06), 40.0],
]
const HIDE_NAME := ["Bubble", "Speech", "Sign", "Hand", "Cursor", "Pointer", "Slip", "Toast", "Tray", "Clock", "Hint", "Ghost", "Compass", "Veil"]


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "play"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.faith = 3000
	g.cards = {}
	for t in [["fire", Vector2i(7, 12)], ["crossbow", Vector2i(16, 8)], ["guard", Vector2i(9, 16)], ["airship", Vector2i(15, 15)],
			["fire", Vector2i(12, 6)], ["crossbow", Vector2i(6, 7)]]:
		g.try_build(t[0], t[1])
	g.force_quests(["chimney", "bird", "lantern", "cart"])
	for i in 30:
		await process_frame
	var centre: Vector3 = g.board.global_position if g.board else Vector3.ZERO
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	g.lighting.set_mood("day", 0.0)
	if OS.get_environment("PROBE") != "":
		_probe(root, centre)
		quit()
		return
	await _shoot_all(g, cam, centre, prefix + "_day")
	# a night battle, stepped by hand
	g.set_process(true)
	g.speed = 0.0
	g.night = 2
	g.start_night()
	var t := 0.0
	for stop in [14.0, 22.0]:
		while t < stop:
			g.step(0.05)
			t += 0.05
		await _shoot_all(g, cam, centre, "%s_night_%d" % [prefix, int(stop)])
	quit()


func _shoot_all(g: Game, cam: Camera3D, centre: Vector3, base: String) -> void:
	for a in ANGLES.size():
		_hide_ui(g)
		cam.global_position = centre + ANGLES[a][0]
		cam.fov = ANGLES[a][2]
		cam.look_at(centre + ANGLES[a][1], Vector3.UP)
		for i in 10:
			_hide_ui(g)
			await process_frame
		_hide_ui(g)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%d.png" % [base, a])


func _hide_ui(g: Game) -> void:
	for n in [g._hud, g._msg, g._clock, g._toast, g._slip, g._tray, g.hud_root, g._lens, g._fast_glass, g._faith_seal,
			g._board_compass, g._grid_lines, g._ghost, g.ledger, g._hand_stem, g._hand_ring, g._mouse_hand]:
		if n is Node3D:
			n.visible = false
	_walk(root)
	for q in g.board.find_children("*", "MeshInstance3D", true, false):
		if q.mesh is QuadMesh and q.get_parent().name == "Shots" and q.global_position.y - g.board.global_position.y < 0.03:
			q.visible = false


func _walk(n: Node) -> void:
	if n is CanvasItem:
		n.visible = false
		return
	if n is Label3D or (n is Sprite3D and n.billboard != BaseMaterial3D.BILLBOARD_DISABLED):
		n.visible = false
	elif n is Node3D:
		for k in HIDE_NAME:
			if k in str(n.name):
				n.visible = false
				for d in n.find_children("*", "Node3D", true, false):
					d.visible = false
				break
	for c in n.get_children():
		_walk(c)


func _probe(n: Node, c: Vector3) -> void:
	if n is MeshInstance3D and n.is_visible_in_tree() and n.mesh and not (n.mesh is ArrayMesh):
		print(n.get_path(), " ", n.mesh.get_class(), " ", (n.global_position - c).snapped(Vector3(0.01, 0.01, 0.01)))
	for k in n.get_children():
		_probe(k, c)
