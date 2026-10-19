extends SceneTree
## Headless: load each house, move every part to its "<part>_broken" marker (as the game will), print the
## combined bounds so they can be compared with the Blender broken preview.
##   <godot console> --headless --xr-mode off --path godot -s res://tools/pose_check.gd


func _initialize() -> void:
	for f in ["cottage", "cabin", "townhouse"]:
		var scene: Node3D = load("res://assets/village/ew_village_%s_v03.glb" % f).instantiate()
		get_root().add_child(scene)
		var parts := {}
		for n in _all(scene):
			if n is MeshInstance3D and n.has_meta("ew_part"):
				parts[str(n.get_meta("ew_part"))] = n
		for n in _all(scene):
			if n is Marker3D and n.is_in_group("ew_pose") and String(n.name).ends_with("_broken"):
				var p: Node3D = parts[str(n.get_meta("ew_pose_of"))]
				p.transform = n.transform
		if parts.has("windows") and str(parts["windows"].get_meta("ew_broken", "")) == "off":
			parts["windows"].visible = false
		var aabb := AABB()
		var first := true
		for n in _all(scene):
			if n is MeshInstance3D and n.visible:
				var box: AABB = _xform_to(n, scene) * n.mesh.get_aabb()
				aabb = box if first else aabb.merge(box)
				first = false
		print("%s broken: x %.4f..%.4f  y(blender) %.4f..%.4f  top %.4f" % [f, aabb.position.x, aabb.end.x, -aabb.end.z, -aabb.position.z, aabb.end.y])
		scene.queue_free()
	quit()


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _xform_to(node: Node, root: Node) -> Transform3D:
	# global_transform is not ready before the first frame in a headless run; compose it by hand
	var xf := Transform3D.IDENTITY
	var n := node
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
