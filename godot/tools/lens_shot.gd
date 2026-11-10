extends SceneTree
## The look-through lens (desktop window, not --headless):
##   <godot console> --xr-mode off --path godot -s res://tools/lens_shot.gd -- OUT_PREFIX
## Builds the headset's lens window by hand (the desktop game does not make it): the Foresight overlay goes on
## render layer 2, the main camera does not draw that layer, the lens window does. Writes OUT_PREFIX_lens.png (the
## lens held up in front of the camera, island and overlay seen through the glass) and prints LENSSHOT lines.

func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "lens_shot"
	var g: Game = load("res://scripts/game/game.gd").new()
	g.with_rig = true
	root.add_child(g)
	for i in 20:
		await process_frame
	g._camera = null
	g.set_process(false)  # the desktop game would put the lens back on the table every frame
	g.foresight.overlay_layers = LensView.OVERLAY_LAYER
	g.foresight.tier = 3
	g.foresight.refresh()
	g.foresight.show_seen()
	var cam := Camera3D.new()
	cam.cull_mask = 0xFFFFF & ~LensView.OVERLAY_LAYER
	root.add_child(cam)
	cam.current = true
	cam.fov = 50
	cam.global_position = g.board.to_global(Vector3(0.0, 0.62, 0.78))
	var target := g.board.to_global(Vector3(0, 0.0, 0.1))
	if not g.foresight._views.is_empty():
		target = g.board.to_global(g.foresight._views[0]["at"])  # a forest gap with a drawing, so the overlay shows
	print("LENSSHOT views: ", g.foresight._views.size(), " target ", g.board.to_local(target))
	cam.look_at(target, Vector3.UP)
	var lens: Node3D = g._lens
	# the lens held up between the eye and the island, glass toward the eye
	var hold := cam.global_position + (target - cam.global_position).normalized() * 0.32
	var lb := Basis.looking_at(cam.global_position - hold, Vector3.UP, true) * Basis.from_scale(Vector3.ONE * GameConfig.LENS_SCALE)
	lens.global_transform = Transform3D(lb, hold - lb * g._lens_centre)  # the middle of the glass sits at `hold`
	var lv := LensView.new()
	g.add_child(lv)
	lv.setup(lens, g._lens_centre, Vector2(0.066, 0.098))
	lv.set_active(true)
	for i in 8:
		lv.aim(cam.global_position, lens.global_transform * g._lens_centre)
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s_lens.png" % prefix)
	var plain := cam.cull_mask & LensView.OVERLAY_LAYER
	print("LENSSHOT main camera sees overlay layer: ", plain != 0, "  lens camera sees it: ", lv._cam.cull_mask & LensView.OVERLAY_LAYER != 0)
	quit()
