extends SceneTree
## Prints the Crystal Lens model's nodes, sizes and anchors (headless ok):
##   <godot console> --headless --xr-mode off --path godot -s res://tools/lens_inspect.gd

func _initialize() -> void:
	var res := load(GameConfig.LENS_SCENE)
	var n: Node3D = res.instantiate()
	root.add_child(n)
	await process_frame
	for c in ModelUtil.walk(n):
		if c is Node3D:
			var line := "%s  %s  pos=%s" % [c.get_class(), c.name, (c as Node3D).position]
			if c is MeshInstance3D:
				line += "  aabb=%s" % (c as MeshInstance3D).get_aabb()
			print("LENS ", line)
	quit()
