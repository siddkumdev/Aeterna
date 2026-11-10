extends SceneTree
## Records what the game actually outputs (the mixed audio after every bus, 3D attenuation and the Master limiter) while
## Wizard Towers fight a night. Uses Godot's Movie Maker, so the WAV is exact and not a microphone recording:
##   <godot console> --xr-mode off --path godot --write-movie C:/out/capture.avi --fixed-fps 60 -s res://tools/audio_capture.gd -- [seconds] [kind]
## Movie Maker writes capture.avi with PCM audio; extract the WAV with ffmpeg. kind: fire (Wizard, default), guard, ...

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seconds := float(args[0]) if args.size() > 0 else 25.0
	var kind := args[1] if args.size() > 1 else "fire"
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 10:
		await process_frame
	g.FAITH = 100000
	var built := 0
	for x in range(4, 20, 3):
		for y in range(4, 20, 3):
			if built < 4 and g.try_build(kind, Vector2i(x, y)):
				built += 1
	print("audio_capture: built %d %s towers" % [built, kind])
	g.night = 3
	g.start_night()
	await create_timer(seconds).timeout
	print("audio_capture: done, voices played %d" % (g.audio.played if g.audio else -1))
	quit()
