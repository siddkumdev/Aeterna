extends SceneTree
## Quick check of the live story world (desktop): --xr-mode off --path godot -s res://tools/story_live_shot.gd -- OUT_PREFIX
## Writes _skotos (curse, looking at him with a headset-like 90 degree view), _village (morning), _beasts (night).

var _w: StoryWorld
var _cam: Camera3D


func _shot(path: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("wrote ", path)


func _initialize() -> void:
	var prefix := OS.get_cmdline_user_args()[0]
	if OS.get_environment("STORY_TIER") != "":
		StoryWorld.force_tier = int(OS.get_environment("STORY_TIER"))  # 1 = low Quest, 2 = Quest 3 (PerfTier enum)
	_w = StoryWorld.new()
	root.add_child(_w)
	if StoryWorld.force_tier >= 0:
		_w.apply_perf_tier(StoryWorld.force_tier)  # as OpeningStage does after _ready (materials exist now)
	var we := WorldEnvironment.new()
	we.environment = _w.env
	root.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = 90.0
	_cam.far = 160.0
	root.add_child(_cam)
	_cam.current = true
	await process_frame
	_w.set_mood("curse", 0.0)
	_w.skotos.visible = true
	_w.skotos.position.y = StoryWorld.height(StoryWorld.SKOTOS_AT.x, StoryWorld.SKOTOS_AT.z) - 3.0
	_w.skotos_eyes.light_energy = 4.0
	_cam.position = Vector3(0, 1.6, 0)
	_cam.look_at(Vector3(StoryWorld.SKOTOS_AT.x, 12.0, StoryWorld.SKOTOS_AT.z))
	await _shot(prefix + "_skotos.png")
	_w.skotos.visible = false
	_w.set_mood("morning", 0.0)
	_cam.look_at(Vector3(0, 1.0, -20))
	await _shot(prefix + "_village.png")
	_w.set_mood("curse", 0.0)
	_w.release_beasts()
	for b in _w.beasts:
		b["delay"] = 0.0
	for i in 400:
		await process_frame
	var n: Node3D = _w.beasts[0]["node"]
	_cam.position = n.position + Vector3(4, 2.5, 6)
	_cam.look_at(n.position + Vector3(0, 1.2, 0))
	await _shot(prefix + "_beasts.png")
	quit()
