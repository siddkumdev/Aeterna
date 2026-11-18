extends SceneTree
## Close character shots for the Devpost gallery, in the story world (desktop window):
##   <godot console> --xr-mode off --resolution 1500x1000 --path godot -s res://tools/gallery_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_solo_<i>.png (each villager alone, morning or dusk), _pray.png, _pair.png, _beast_dusk.png.


func _snap(path: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "gal"
	var w := StoryWorld.new()
	root.add_child(w)
	var cam := Camera3D.new()
	cam.fov = 38.0
	root.add_child(cam)
	cam.current = true
	for i in 3:
		await process_frame
	var at := Vector3(0, StoryWorld.height(0, -6), -6)
	for p in w.people:
		p.visible = false
	# each villager alone, alternating morning and dusk, slightly off to one side
	for i in w.people.size():
		var p: StoryPerson = w.people[i]
		p.visible = true
		p.place(at, 0.25 if i % 2 == 0 else -0.25)
		p.set_pose("idle")
		w.set_mood("morning", 0.0)
		var side := 0.45 if i % 2 == 0 else -0.45
		cam.position = at + Vector3(side, 1.25, 2.9)
		cam.look_at(at + Vector3(0, 0.8, 0))
		await _snap("%s_solo_%d.png" % [prefix, i])
		p.visible = false
	# three of them praying in the morning
	w.set_mood("morning", 0.0)
	for i in 3:
		var p: StoryPerson = w.people[i + 1]
		var x := -0.7 + i * 0.7
		p.visible = true
		p.place(Vector3(x, StoryWorld.height(x, -6), -6), 0.0)
		p.set_pose("pray")
	cam.position = at + Vector3(0.3, 1.1, 3.6)
	cam.look_at(at + Vector3(0, 0.7, 0))
	await _snap(prefix + "_pray.png")
	for p in w.people:
		p.visible = false
	# two side by side in the morning
	w.set_mood("morning", 0.0)
	for i in 2:
		var p: StoryPerson = w.people[i + 4]
		var x := -0.35 + i * 0.7
		p.visible = true
		p.place(Vector3(x, StoryWorld.height(x, -6), -6), 0.3 - i * 0.6)
		p.set_pose("idle")
	cam.position = at + Vector3(0, 1.25, 3.2)
	cam.look_at(at + Vector3(0, 0.75, 0))
	await _snap(prefix + "_pair.png")
	for p in w.people:
		p.visible = false
	# the beast at dusk, low angle
	var b: Dictionary = w.beasts[0]
	var n: Node3D = b["node"]
	n.visible = true
	n.position = at
	n.rotation.y = PI * 0.8
	b["t"] = 1.0
	b["from"] = n.position
	b["to"] = n.position + Vector3(0, 0, 0.001)
	w.set_mood("dusk", 0.0)
	cam.position = at + Vector3(-0.8, 0.6, 2.6)
	cam.look_at(at + Vector3(0, 1.2, 0))
	await _snap(prefix + "_beast_dusk.png")
	quit()
