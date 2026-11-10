extends SceneTree
## Headless check of the passthrough helpers (no headset here, so passthrough must stay off and nothing may change):
##   <godot console> --headless --xr-mode off --path godot -s res://tools/haze_check.gd

func _initialize() -> void:
	var fails := 0
	var g: Game = load("res://scripts/game/game.gd").new()
	root.add_child(g)
	for i in 3:
		await process_frame
	var bg_before := g.lighting.env.background_color
	var on: bool = g.lighting.enable_passthrough()
	fails += _check("enable_passthrough() is false without OpenXR", not on)
	fails += _check("background colour untouched on desktop", g.lighting.env.background_color == bg_before)
	fails += _check("viewport stays opaque on desktop", not root.transparent_bg)
	var haze := HazeDome.new()
	g.add_child(haze)
	await process_frame
	fails += _check("haze starts hidden", not haze.visible)
	haze.set_active(true)
	await process_frame
	fails += _check("haze shows when activated", haze.visible)
	haze.set_active(false)
	fails += _check("haze hides again", not haze.visible)
	var veil := VeilDome.new()
	g.add_child(veil)
	await process_frame
	veil.snap(0.0, 0.0)
	fails += _check("veil dome hidden at knit 0", not veil.get_node("dome").visible)
	veil.snap(1.0, 0.0)
	fails += _check("veil dome shown at knit 1", veil.get_node("dome").visible)
	print("haze_check: %d failure(s)" % fails)
	quit(1 if fails > 0 else 0)


func _check(label: String, ok: bool) -> int:
	print("%s  %s" % ["PASS" if ok else "FAIL", label])
	return 0 if ok else 1
