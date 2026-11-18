extends SceneTree
## Meta XR Simulator run (needs the simulator runtime): powershell -File godotxr_sim_shot.ps1 OUT_PREFIX. NOTE: in XR the root viewport image comes back white (no eye image), so the saved PNGs are blank; the useful output is the [xrshot] log lines (XR up, tier, fps, HUD nodes). Grab the mirror window from the desktop for pictures.
## Builds the Game in XR mode (the real Quest path: PerfTier, XR viewport, hands, HUD), waits, saves the viewport a few
## times and the XR facts, then quits.


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "xr_sim"
	var xr := XRServer.find_interface("OpenXR")
	print("[xrshot] interface=", xr, " initialized=", xr != null and xr.is_initialized())
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for s in 6:
		await create_timer(2.0).timeout
		var img := root.get_viewport().get_texture().get_image()
		img.save_png("%s_%d.png" % [prefix, s])
		print("[xrshot] frame %d size=%s fps=%d tier=%s" % [s, str(img.get_size()), Engine.get_frames_per_second(), PerfTier.name_of(PerfTier.tier)])
		if s == 1:
			g.faith = 3000
			g.try_build("crossbow", Vector2i(3, 9))
	print("[xrshot] xr=", g._xr, " cam=", g._xr_cam, " hud_root=", g.hud_root, " tray=", g.get("tray"), " ledger=", g.get("ledger"))
	quit()
