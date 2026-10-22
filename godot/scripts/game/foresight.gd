class_name Foresight
extends Node3D
## What the Crystal Lens shows (spec 13): the coming night, drawn at the forest edge in crystal blue, during
## the day only. Its tier is the loop number (1-5):
##   1  blurry silhouettes (about half as many as are coming, so the size reads but not the count) and an
##      arrow at the gap each group comes from
##   2  every enemy as its own silhouette, plus type names and counts (stand-in for icons)
##   3  path ribbons: the route each walking group takes and the straight line of its flyers, plus a ring
##      where each Tunneler will come up
##   4  when each group leaves the forest
##   5  rewrite: a sign at each gap closes it for the night (once per night); its groups use the next edge
## The Fog variant never shows. Gaze-aimed: only groups whose gap is near where the head looks are drawn
## (desktop: all of them). `reveal()` is the same information as data, for the headless tests.

var game  # Game
var tier := 1
var showing := false

var _views: Array = []  # [{"spawn", "node": Node3D, "at": Vector3 board-local}]
var _mat: StandardMaterial3D
var _mat_soft: StandardMaterial3D


func _ready() -> void:
	_mat = ModelUtil.flat_material(GameConfig.FORESIGHT_COLOUR, true, 0.55)
	_mat_soft = ModelUtil.flat_material(GameConfig.FORESIGHT_COLOUR, true, 0.3)
	visible = false


static func reveal(at_tier: int, plan: Array, g) -> Array[Dictionary]:
	## One entry per group with anything to show:
	## {"spawn", "silhouettes": [{"flying", "boss"}], "types": {kind: count} (tier 2+),
	##  "paths": [Array[Vector3] board-local] (tier 3+), "surface": [Vector2i] (tier 3+), "time": s (tier 4+)}
	var out: Array[Dictionary] = []
	for grp in plan:
		var shown: Array = grp["enemies"].filter(func(k): return not GameConfig.ENEMIES[k].get("hidden", false))
		if shown.is_empty():
			continue
		var e := {"spawn": grp["spawn"], "silhouettes": []}
		var n := shown.size() if at_tier >= 2 else ceili(shown.size() / 2.0)
		for i in range(n):
			var k: String = shown[i * shown.size() / n]
			e["silhouettes"].append({"flying": GameConfig.ENEMIES[k].get("flying", false), "boss": GameConfig.ENEMIES[k].get("boss", false)})
		if at_tier >= 2:
			var types := {}
			for k in shown:
				types[k] = types.get(k, 0) + 1
			e["types"] = types
		if at_tier >= 3:
			var gap: Array = GameConfig.SPAWNS[grp["spawn"]]
			var mid: Vector2i = gap[gap.size() / 2]
			var from := NavGrid.cell_centre(mid)
			e["paths"] = []
			e["surface"] = []
			if shown.any(func(k): return not GameConfig.ENEMIES[k].get("flying", false) and not GameConfig.ENEMIES[k].get("burrows", false)):
				var r: Dictionary = g.nav.route(mid, g.standing_houses())
				if not r.is_empty():
					e["paths"].append(r["path"].map(func(c): return NavGrid.cell_centre(c)))
			var h: int = g.nearest_house_to(from)
			if h >= 0:
				if shown.any(func(k): return GameConfig.ENEMIES[k].get("flying", false)):
					var up := Vector3(0, GameConfig.ENEMIES["wisp"]["fly_height"] * GameConfig.CELL, 0)
					e["paths"].append([from + Vector3(0, 1.5 * GameConfig.CELL, 0), g.house_point(h) + up])
				if shown.has("tunneler"):
					e["surface"].append(g.surface_cell(h, from))
		if at_tier >= 4:
			e["time"] = grp["time"]
		out.append(e)
	return out


func refresh() -> void:
	## Rebuilds the drawing from the coming night's plan (routes change when towers are built).
	for v in _views:
		v["node"].queue_free()
	_views.clear()
	var merged := {}  # one view per gap: groups from the same edge are drawn together
	for e in reveal(tier, game.night_plan(), game):
		if not merged.has(e["spawn"]):
			merged[e["spawn"]] = []
		merged[e["spawn"]].append(e)
	for spawn in merged:
		_views.append(_draw(spawn, merged[spawn]))
	game.foresight_signs(tier >= GameConfig.FORESIGHT_TIERS and game.closed_spawn == "")


func show_seen(eye := Vector3.INF, look := Vector3.ZERO) -> void:
	## Shows the groups whose gap is within the gaze angle of `look` from `eye` (world space); all when no
	## gaze is given (desktop).
	showing = true
	visible = true
	for v in _views:
		var on := true
		if eye != Vector3.INF:
			var to: Vector3 = to_global(v["at"]) - eye
			on = rad_to_deg(to.angle_to(look)) <= GameConfig.LENS_GAZE_DEG
		v["node"].visible = on


func hide_all() -> void:
	showing = false
	visible = false


func seen_spawns() -> Array:
	return _views.filter(func(v): return visible and v["node"].visible).map(func(v): return v["spawn"])


func _draw(spawn: String, entries: Array) -> Dictionary:
	var gap: Array = GameConfig.SPAWNS[spawn]
	var centre := Vector3.ZERO
	for c in gap:
		centre += NavGrid.cell_centre(c)
	centre /= gap.size()
	var inward := (-centre * Vector3(1, 0, 1)).normalized()
	var across := inward.cross(Vector3.UP)
	var node := Node3D.new()
	add_child(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(spawn)
	# silhouettes stand just inside the tree line, spread across the gap
	var all: Array = []
	for e in entries:
		all.append_array(e["silhouettes"])
	for i in all.size():
		var s: Dictionary = all[i]
		var m := MeshInstance3D.new()
		var size := 2.5 if s["boss"] else 1.0
		if s["flying"]:
			var sm := SphereMesh.new()
			sm.radius = 0.012
			sm.height = 0.024
			m.mesh = sm
		else:
			var cm := CapsuleMesh.new()
			cm.radius = 0.012 * size
			cm.height = 0.045 * size
			m.mesh = cm
		m.material_override = _mat_soft if tier < 2 else _mat
		var row := i / 6
		var along := (i % 6 - 2.5) / 6.0 * gap.size() * GameConfig.CELL + rng.randf_range(-0.004, 0.004)
		m.position = centre - inward * (0.6 + row * 0.8) * GameConfig.CELL + across * along
		m.position.y = 4.0 * GameConfig.CELL if s["flying"] else 0.0225 * size
		if tier < 2:
			m.scale = Vector3.ONE * rng.randf_range(1.1, 1.5)  # blurry: bigger and fainter
		node.add_child(m)
	# arrow on the board pointing in from the gap (the direction of the group)
	var arrow := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.022
	am.height = 0.05
	arrow.mesh = am
	arrow.material_override = _mat
	arrow.position = centre + inward * 2.0 * GameConfig.CELL + Vector3(0, 0.006, 0)
	# the cone's tip (+Y) points inward, lying flat and squashed to a thin plate (its local Z is vertical)
	arrow.basis = Basis(across, inward, across.cross(inward) * 0.2)
	node.add_child(arrow)
	# words: type counts (tier 2), departure times (tier 4)
	var lines: Array[String] = []
	for e in entries:
		var parts: Array[String] = []
		for k in e.get("types", {}):
			parts.append("%s x%d" % [GameConfig.ENEMIES[k]["name"], e["types"][k]])
		var line := ", ".join(parts)
		if e.has("time"):
			line = "%s  @ %d s" % [line, int(e["time"])]
		if line != "":
			lines.append(line)
	if not lines.is_empty():
		var l := Label3D.new()
		l.text = "\n".join(lines)
		l.font_size = 60
		l.pixel_size = 0.0005
		l.outline_size = 10
		l.modulate = Color8(0xD8, 0xF6, 0xFF)
		l.outline_modulate = Color8(0x10, 0x2A, 0x3A)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 9
		l.position = centre + inward * 1.0 * GameConfig.CELL + Vector3(0, 0.14, 0)  # above the tree line
		node.add_child(l)
	# ribbons and Tunneler rings
	for e in entries:
		for p in e.get("paths", []):
			node.add_child(_ribbon(p))
		for c in e.get("surface", []):
			node.add_child(_ring(NavGrid.cell_centre(c)))
	return {"spawn": spawn, "node": node, "at": centre}


func _ribbon(points: Array) -> MeshInstance3D:
	## A flat strip a fifth of a cell wide along the points (a thin line is lost at table distance).
	var half := GameConfig.CELL * 0.1
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in points.size():
		var a: Vector3 = points[maxi(i - 1, 0)]
		var b: Vector3 = points[mini(i + 1, points.size() - 1)]
		var d := (b - a) * Vector3(1, 0, 1)
		var side := d.normalized().cross(Vector3.UP) * half if d.length() > 0.0 else Vector3.ZERO
		var p: Vector3 = points[i] + Vector3(0, 0.004, 0)
		im.surface_add_vertex(p + side)  # this order faces up (the underside is culled)
		im.surface_add_vertex(p - side)
	im.surface_end()
	var m := MeshInstance3D.new()
	m.mesh = im
	m.material_override = _mat
	return m


func _ring(at: Vector3) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = GameConfig.CELL * 0.45
	tm.outer_radius = GameConfig.CELL * 0.7
	var m := MeshInstance3D.new()
	m.mesh = tm
	m.position = at + Vector3(0, 0.004, 0)
	m.scale.y = 0.3
	m.material_override = _mat
	return m
