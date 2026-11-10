extends SceneTree
## A villager's thought and Maren's prayer as bubbles in the real game (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/bubble_shot.gd -- OUT_PREFIX
## Writes OUT_PREFIX_thought.png.

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "bubble_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	for i in 30:
		await process_frame
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = 38
	g._camera = null  # keep the mouse hand quiet
	var v: Villager = g.life.villagers[2]
	g.tap_villager(v)
	g.say_at_shrine(StoryText.prayer(0, 0))
	for i in 20:
		await process_frame
	var focus := g.board.to_global(Vector3(0, 0.1, 0))
	cam.global_position = g.board.to_global(Vector3(0.0, 0.5, 0.85))
	cam.look_at(focus, Vector3.UP)
	for i in 6:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s_thought.png" % prefix)
	print("BUBBLESHOT ", v.voice, ": ", StoryText.thought(v.voice, 0, 0))
	quit()
