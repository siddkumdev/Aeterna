class_name ModelUtil
extends RefCounted
## Small helpers for imported models (see tools/ew_post_import.gd for the metadata they carry).


static func walk(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(walk(c))
	return out


static func parts(model: Node) -> Dictionary:
	## "<part>" -> MeshInstance3D, from the "ew_part" metadata on moving parts.
	var out := {}
	for n in walk(model):
		if n is MeshInstance3D and n.has_meta("ew_part"):
			out[str(n.get_meta("ew_part"))] = n
	return out


static func xform_to(node: Node, root: Node) -> Transform3D:
	## Transform of node relative to root, composed by hand (global_transform is not ready before the
	## first frame in a headless run).
	var xf := Transform3D.IDENTITY
	var n := node
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func bounds(model: Node3D) -> AABB:
	## Bounds of every visible mesh, in the model's own space.
	var box := AABB()
	var first := true
	for n in walk(model):
		if n is MeshInstance3D and n.visible and n.mesh != null:
			var b: AABB = xform_to(n, model) * n.mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


static func flat_material(color: Color, unshaded := false, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, alpha)
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _has_excluded_ancestor(n: Node, root: Node, exclude_set: Dictionary) -> bool:
	var cur := n
	while cur != null and cur != root:
		if exclude_set.has(cur) or cur.has_meta("ew_part") or cur.has_meta("ew_starts_hidden"):
			return true
		if cur is Node3D and not (cur as Node3D).visible:
			return true
		cur = cur.get_parent()
	return false


static func _prune_empty_wrappers(n: Node, root: Node, exclude_set: Dictionary) -> void:
	for c in n.get_children().duplicate():
		_prune_empty_wrappers(c, root, exclude_set)
	if n == root or exclude_set.has(n) or n is Marker3D or not n.get_children().is_empty():
		return
	for m in n.get_meta_list():
		if str(m).begins_with("ew_"):
			return
	if not n.get_groups().is_empty():
		return
	if n.get_parent():
		n.get_parent().remove_child(n)
	n.free()


static func merge_static_meshes(root: Node3D, exclude_roots: Array[Node] = [], cast_shadow := GeometryInstance3D.SHADOW_CASTING_SETTING_ON, merged_name := "MergedStatic") -> MeshInstance3D:
	## Combines static MeshInstance3D surfaces under `root` by Material into one MeshInstance3D to cut draw calls.
	if root == null:
		return null
	var exclude_set := {}
	for er in exclude_roots:
		if er != null:
			exclude_set[er] = true
	var candidates: Array[MeshInstance3D] = []
	for n in walk(root):
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		if mi.skin != null or mi.skeleton != NodePath():
			continue
		if _has_excluded_ancestor(mi, root, exclude_set):
			continue
		candidates.append(mi)
	if candidates.is_empty():
		return null
	var buckets := {}  # Material (or null) -> Array[Dictionary]
	var bucket_mats: Array = []
	for mi in candidates:
		var xf := xform_to(mi, root)
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			if not buckets.has(mat):
				buckets[mat] = []
				bucket_mats.append(mat)
			(buckets[mat] as Array).append({"mesh": mi.mesh, "surface": s, "xf": xf})
	var merged_mesh := ArrayMesh.new()
	for mat in bucket_mats:
		var entries: Array = buckets[mat]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for e in entries:
			st.append_from(e["mesh"], e["surface"], e["xf"])
		st.commit(merged_mesh)
		var surf_idx := merged_mesh.get_surface_count() - 1
		if surf_idx >= 0 and mat != null:
			merged_mesh.surface_set_material(surf_idx, mat)
	if merged_mesh.get_surface_count() == 0:
		return null
	for idx in range(candidates.size() - 1, -1, -1):
		var mi := candidates[idx]
		if not is_instance_valid(mi):
			continue
		if mi.get_child_count() > 0:
			mi.mesh = null
		else:
			if mi.get_parent():
				mi.get_parent().remove_child(mi)
			mi.free()
	for c in root.get_children().duplicate():
		_prune_empty_wrappers(c, root, exclude_set)
	var out := MeshInstance3D.new()
	out.name = merged_name
	out.mesh = merged_mesh
	out.cast_shadow = cast_shadow
	root.add_child(out)
	return out
