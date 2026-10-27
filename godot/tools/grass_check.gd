extends SceneTree
## Needs a window. Checks the grass moves: (1) the image changes between two moments (wind), (2) a pusher bends the
## grass near it (the image changes there) and a pusher held high above it does nothing.
func _initialize() -> void:
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 5:
		await process_frame
	g.set_process(false)
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	var c: Vector3 = g.board.global_position + Vector3(0.3, 0, 0.3)  # open meadow, south-east of the village
	cam.global_position = c + Vector3(0, 0.16, 0.12)
	cam.look_at(c, Vector3.UP)
	cam.fov = 35
	g.grass.set_pushers([])
	var a := await _shot()
	for i in 60:
		await process_frame
	var b := await _shot()
	print("GRASS wind: changed pixels = ", _diff(a, b))
	g.grass.set_pushers([Vector4(c.x, c.y, c.z, 0.05)])
	var p := await _shot()
	g.grass.set_pushers([Vector4(c.x, c.y + 0.2, c.z, 0.05)])
	var hi := await _shot()
	g.grass.set_pushers([])
	var none := await _shot()
	print("GRASS pusher on the ground vs none: changed pixels = ", _diff(p, none))
	print("GRASS pusher 20 cm up vs none: changed pixels = ", _diff(hi, none))
	quit()

func _shot() -> Image:
	for i in 3:
		await process_frame
	return root.get_viewport().get_texture().get_image()

func _diff(a: Image, b: Image) -> int:
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			if absf(pa.r - pb.r) + absf(pa.g - pb.g) + absf(pa.b - pb.b) > 0.08:
				n += 1
	return n
