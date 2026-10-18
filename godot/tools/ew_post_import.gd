@tool
extends EditorScenePostImport
## Runs on every Endless Watch .glb import (tools/sync_to_godot.py sets it in each .import file).
## 1. Swaps the glTF materials for the two shared materials (one palette atlas for the whole game):
##    "ew_palette" -> res://assets/palette/ew_palette.tres, "ew_palette_glow" -> ew_palette_glow.tres.
## 2. Turns every "__<name>_anchor" empty into a Marker3D in the group "ew_vfx_anchor", with the effect
##    size (meters, from the glTF extra "ew_size") as metadata "ew_size". VFX code finds them by group.
## 3. Tags moving parts (meshes named "..__<part>") with metadata "ew_part" = "<part>".

const PALETTE_PATH := "res://assets/palette/ew_palette.tres"
const GLOW_PATH := "res://assets/palette/ew_palette_glow.tres"

var palette: Material
var glow: Material


func _post_import(scene: Node) -> Object:
	palette = load(PALETTE_PATH)
	glow = load(GLOW_PATH)
	if palette == null or glow == null:
		push_error("ew_post_import: shared materials missing (%s, %s)" % [PALETTE_PATH, GLOW_PATH])
		return scene
	_walk(scene, scene)
	return scene


func _walk(node: Node, root: Node) -> void:
	for child in node.get_children():
		_walk(child, root)
	if node is MeshInstance3D:
		_swap_materials(node)
	var n := String(node.name)
	if node == root or not n.contains("__"):
		return
	var short := n.get_slice("__", 1)
	if short.contains("_anchor") and not (node is MeshInstance3D):
		_make_anchor(node, root)
	elif node is MeshInstance3D:
		node.set_meta("ew_part", short)


func _swap_materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var old := mesh.surface_get_material(i)
		var mname := old.resource_name if old else ""
		if mname.begins_with("ew_palette_glow"):
			mesh.surface_set_material(i, glow)
		else:
			if not mname.begins_with("ew_palette"):
				push_warning("ew_post_import: %s surface %d has material '%s', using ew_palette" % [mi.name, i, mname])
			mesh.surface_set_material(i, palette)
		mi.set_surface_override_material(i, null)


func _make_anchor(node: Node, root: Node) -> void:
	var size := 0.0
	if node.has_meta("extras"):
		size = float(node.get_meta("extras").get("ew_size", 0.0))
	elif node.has_meta("ew_size"):
		size = float(node.get_meta("ew_size"))
	var m := Marker3D.new()
	m.name = node.name
	m.transform = node.transform
	m.gizmo_extents = maxf(size, 0.005)
	m.set_meta("ew_size", size)
	var parent := node.get_parent()
	var idx := node.get_index()
	parent.remove_child(node)
	parent.add_child(m)
	parent.move_child(m, idx)
	m.owner = root
	m.add_to_group("ew_vfx_anchor", true)
	node.free()
