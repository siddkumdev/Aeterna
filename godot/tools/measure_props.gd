extends SceneTree
## Prints the footprint (in cells) and height of every cosmetic village/world prop, newest version of each.
func _initialize() -> void:
	var names := {}
	for dir in ["res://assets/village/", "res://assets/world/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".glb"):
				var base := f.substr(0, f.rfind("_v"))
				if base.contains("tower") or base.contains("forest") or base.contains("tree") or base.contains("island"):
					continue
				if not names.has(base) or f > names[base][1]:
					names[base] = [dir, f]
	var keys := names.keys()
	keys.sort()
	for k in keys:
		var n: Node3D = load(names[k][0] + names[k][1]).instantiate()
		root.add_child(n)
		var box := AABB()
		var first := true
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%-42s %.1f x %.1f cells, %.1f tall  centre(%.1f,%.1f)" % [names[k][1], box.size.x / 0.05, box.size.z / 0.05, box.size.y / 0.05, (box.position.x + box.size.x / 2) / 0.05, (box.position.z + box.size.z / 2) / 0.05])
		n.queue_free()
	quit()
