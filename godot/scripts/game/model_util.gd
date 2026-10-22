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
