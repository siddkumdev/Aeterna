extends SceneTree
## Close-ups of the story's beast and Maren (desktop window):
##   <godot console> --xr-mode off --path godot -s res://tools/story_close_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_beast.png and OUT_PREFIX_maren.png in the morning light.


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "close"
	var w := StoryWorld.new()
	root.add_child(w)
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	for i in 3:
		await process_frame
	w.set_mood("morning", 0.0)
	var b: Dictionary = w.beasts[0]
	var n: Node3D = b["node"]
	n.visible = true
	n.position = Vector3(0, StoryWorld.height(0, -6), -6)
	n.rotation.y = PI * 0.75
	b["t"] = 1.0
	b["from"] = n.position
	b["to"] = n.position + Vector3(0, 0, 0.001)
	cam.position = n.position + Vector3(0.6, 1.4, 3.4)
	cam.look_at(n.position + Vector3(0, 0.95, 0))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(prefix + "_beast.png")
	n.visible = false
	var m: StoryPerson = w.people[0]
	m.place(Vector3(0, StoryWorld.height(0, -6), -6), 0.0)
	m.set_pose("idle")
	cam.position = m.position + Vector3(0.2, 1.5, 2.3)
	cam.look_at(m.position + Vector3(0, 1.15, 0))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(prefix + "_maren.png")
	# the villagers side by side
	for i in mini(4, w.people.size()):
		var p: StoryPerson = w.people[i]
		p.place(Vector3(-1.2 + i * 0.8, StoryWorld.height(-1.2 + i * 0.8, -6), -6), 0.0)
		p.set_pose("idle")
	cam.position = Vector3(0, StoryWorld.height(0, -6) + 1.3, -2.2)
	cam.look_at(Vector3(0, StoryWorld.height(0, -6) + 0.95, -6))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(prefix + "_people.png")
	for p in w.people:
		p.visible = false
	# a fir and a broadleaf on open ground
	var gy := StoryWorld.height(0, -30)
	for k in 2:
		var t := MeshInstance3D.new()
		t.mesh = w._pine(7) if k == 0 else w._oak(7)
		root.add_child(t)
		t.position = Vector3(-6 + k * 12, StoryWorld.height(-6 + k * 12, -30), -30)
	cam.fov = 55.0
	for k in 2:
		root.get_child(root.get_child_count() - 1 - k).position.z = -16.0
	cam.position = Vector3(0, gy + 5.0, -1)
	cam.look_at(Vector3(0, gy + 6.0, -16))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(prefix + "_trees.png")
	quit()
