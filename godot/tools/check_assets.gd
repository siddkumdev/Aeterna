extends SceneTree
## Headless check of every imported Endless Watch model in res://assets/<category>/.
##   Godot_v4.7.2-stable_win64_console.exe --headless --path godot -s res://tools/check_assets.gd
## Optional user args after "--": only check files whose name contains one of them.
## Per model: loads, origin on the ground, size in cells, triangles vs budget, every surface uses one
## of the two shared materials, moving parts, VFX anchors (with ew_size). Exit code 1 on any FAIL.

const CELL := 0.05
const PALETTE_PATH := "res://assets/palette/ew_palette.tres"
const GLOW_PATH := "res://assets/palette/ew_palette_glow.tres"
# Starting budgets from CLAUDE.md (tune on a real Quest).
const BUDGET := {"defense": 2000, "village": 2000, "enemy": 2000, "world": 800, "portal": 2000, "vr": 2000,
		"foresight": 800, "ui": 800, "vfx": 800}
const SKIP_DIRS := ["palette", "_old"]

var fails := 0


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	var checked := 0
	for cat in DirAccess.get_directories_at("res://assets"):
		if cat in SKIP_DIRS:
			continue
		for f in DirAccess.get_files_at("res://assets/" + cat):
			if not f.ends_with(".glb"):
				continue
			if not only.is_empty() and not Array(only).any(func(o): return f.contains(o)):
				continue
			_check(cat, "res://assets/%s/%s" % [cat, f])
			checked += 1
	print("\n%d model(s) checked, %d FAIL" % [checked, fails])
	quit(1 if fails > 0 or checked == 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("   FAIL  ", msg)


func _check(cat: String, path: String) -> void:
	print("\n", path)
	var res = load(path)
	if res == null:
		_fail("does not load")
		return
	var scene: Node3D = res.instantiate()
	var tris := 0
	var aabb := AABB()
	var first := true
	var bad_mats := {}
	var parts: Array[String] = []
	var anchors: Array[String] = []
	var poses: Array[String] = []
	var pose_parts: Array[String] = []
	for node in _all(scene):
		var xf := _xform_to(node, scene)
		if node is MeshInstance3D and node.mesh:
			var mesh: Mesh = node.mesh
			for i in mesh.get_surface_count():
				var arr := mesh.surface_get_arrays(i)
				var idx = arr[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx else arr[Mesh.ARRAY_VERTEX].size()) / 3
				var mat: Material = node.get_active_material(i)
				var mp: String = mat.resource_path if mat else "<none>"
				if mp != PALETTE_PATH and mp != GLOW_PATH:
					bad_mats[mp] = true
			var box: AABB = xf * mesh.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
			if node.has_meta("ew_part"):
				parts.append(str(node.get_meta("ew_part")))
		if node is Marker3D and node.is_in_group("ew_pose"):
			poses.append(String(node.name).get_slice("__", 1))
			pose_parts.append(str(node.get_meta("ew_pose_of", "")))
		elif node is Marker3D and node.is_in_group("ew_vfx_anchor"):
			var s := float(node.get_meta("ew_size", 0.0))
			anchors.append("%s (%.4f m)" % [String(node.name).get_slice("__", 1), s])
			if s <= 0.0:
				_fail("anchor %s has no ew_size" % node.name)
		elif String(node.name).contains("_anchor") and not (node is MeshInstance3D):
			_fail("anchor %s was not converted (import script not applied?)" % node.name)
	scene.free()
	if first:
		_fail("no meshes")
		return
	var budget: int = BUDGET.get(cat, 2000)
	if path.contains("ew_world_island"):
		budget = 4000  # lush grass (Siddharth 2026-10-20), same override as tools/validate_asset.py
	print("   size      %.1f x %.1f cells footprint, %.1f cells tall (%.3f x %.3f x %.3f m)"
			% [aabb.size.x / CELL, aabb.size.z / CELL, aabb.size.y / CELL, aabb.size.x, aabb.size.z, aabb.size.y])
	print("   tris      %d / %d" % [tris, budget])
	print("   parts     %s" % (", ".join(parts) if parts else "none (static)"))
	print("   anchors   %s" % (", ".join(anchors) if anchors else "none"))
	if poses:
		print("   poses     %s" % ", ".join(poses))
	for pp in pose_parts:
		if not pp in parts:
			_fail("pose marker for part '%s', but no such part" % pp)
	if absf(aabb.position.y) > 0.002:
		_fail("origin not on the ground: lowest point at y = %.4f m" % aabb.position.y)
	if absf(aabb.get_center().x) > 0.01 or absf(aabb.get_center().z) > 0.01:
		print("   note      footprint centre is off the origin by (%.3f, %.3f) m" % [aabb.get_center().x, aabb.get_center().z])
	if tris > budget:
		_fail("over budget: %d > %d triangles" % [tris, budget])
	if not bad_mats.is_empty():
		_fail("surfaces not using the shared materials: %s" % ", ".join(bad_mats.keys()))
	if aabb.size.y < 0.005 or aabb.size.y > 1.0:
		_fail("height %.3f m looks wrong (upside down or wrong scale?)" % aabb.size.y)


func _all(n: Node) -> Array[Node]:
	var out: Array[Node] = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _xform_to(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n := node
	while n != root and n is Node3D:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
