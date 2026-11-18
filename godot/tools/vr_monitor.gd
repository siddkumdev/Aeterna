extends Node
## Watches a scripted VR run (vr_play.gd) like a tester sitting next to the player and writes a timed event log
## (2026-11-18 stress test, for the teammate). Times are VIDEO time (frames drawn / FPS), so a line can be found in the
## Movie Maker recording. It logs:
##   SND   every sound that starts: stream, bus, volume, distance from the head (3D), how many play at once
##   MSG   every change of the game's message line, PHASE every phase change
##   TEXT  two visible text labels overlapping on screen (text over text)
##   NEAR  a visible mesh closer than NEAR_EYE to the head (it would clip into the face)
##   UI    the Continue plaque shown but off screen for more than OFF_SCREEN_S
##   BOT   the bot's own notes (its actions and checks), copied with the video time

const FPS := 30.0
const NEAR_EYE := 0.07  # m
const OFF_SCREEN_S := 4.0
const OVERLAP_MIN := 0.25  # share of the smaller label's screen box

var g: Node
var l: Node
var bot: Node
var out_path := ""
var lines: PackedStringArray = []
var _players: Array[Node] = []
var _meshes: Array[Node] = []
var _labels: Array[Node] = []
var _was_playing := {}
var _last_pos := {}
var _last_msg := ""
var _last_phase := -1
var _bot_seen := 0
var _overlaps := {}
var _near := {}
var _cont_off := 0.0
var _scan_t := 0.0
var max_concurrent := 0


func setup(game: Node, launcher: Node, b: Node, path: String) -> void:
	g = game
	l = launcher
	bot = b
	out_path = path
	get_tree().node_added.connect(_track)
	for n in get_tree().root.find_children("*", "", true, false):
		_track(n)


func vt() -> float:
	return Engine.get_frames_drawn() / FPS


func log_line(kind: String, s: String) -> void:
	var t := vt()
	lines.append("%8.2f  %-5s %s" % [t, kind, s])


func flush() -> void:
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\nMAX_CONCURRENT_SOUNDS %d\n" % max_concurrent)
		f.close()


func _track(n: Node) -> void:
	if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
		_players.append(n)
	elif n is Label3D:
		_labels.append(n)
	elif n is MeshInstance3D:
		_meshes.append(n)


func _cam() -> Camera3D:
	return get_viewport().get_camera_3d()


func _process(delta: float) -> void:
	if g == null or not is_instance_valid(g):
		return
	_sounds()
	_bot_notes()
	var msg := str(g.last_message)
	if msg != _last_msg:
		_last_msg = msg
		log_line("MSG", msg.replace("\n", " / "))
	if int(g.phase) != _last_phase:
		_last_phase = int(g.phase)
		log_line("PHASE", "%d night=%d loop=%d" % [_last_phase, int(g.night), int(g.loop)])
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.5
		_texts()
		_near_face()
		_continue_check(0.5)


func _sounds() -> void:
	var now := 0
	var eye: Vector3 = bot.eye_world() if bot else Vector3.ZERO
	var keep: Array[Node] = []
	for p in _players:
		if not is_instance_valid(p):
			continue
		keep.append(p)
		var playing: bool = p.playing
		var pos: float = p.get_playback_position() if playing else 0.0
		var id := p.get_instance_id()
		var restarted: bool = playing and _was_playing.get(id, false) and pos + 0.05 < float(_last_pos.get(id, 0.0))
		if playing and (not _was_playing.get(id, false) or restarted):
			var path := "?"
			if p.stream != null:
				path = p.stream.resource_path.get_file() if p.stream.resource_path != "" else p.stream.get_class()
			var extra := ""
			if p is AudioStreamPlayer3D:
				extra = " dist=%.2f" % (p as Node3D).global_position.distance_to(eye)
			log_line("SND", "%s bus=%s vol=%.1f%s" % [path, p.bus, p.volume_db, extra])
		_was_playing[id] = playing
		_last_pos[id] = pos
		if playing:
			now += 1
	_players = keep
	max_concurrent = maxi(max_concurrent, now)


func _bot_notes() -> void:
	if bot == null:
		return
	var bl: PackedStringArray = bot.log_lines
	while _bot_seen < bl.size():
		log_line("BOT", bl[_bot_seen])
		_bot_seen += 1


func _screen_rect(lb: Label3D, cam: Camera3D) -> Rect2:
	var box: AABB = lb.get_aabb()
	var xf := lb.global_transform
	var r := Rect2()
	var first := true
	for i in 8:
		var w := xf * box.get_endpoint(i)
		if cam.is_position_behind(w):
			return Rect2()
		var s := cam.unproject_position(w)
		if first:
			r = Rect2(s, Vector2.ZERO)
			first = false
		else:
			r = r.expand(s)
	return r


func _texts() -> void:
	var cam := _cam()
	if cam == null:
		return
	var vis: Array = []
	var keep: Array[Node] = []
	var vp := get_viewport().get_visible_rect()
	for lb in _labels:
		if not is_instance_valid(lb):
			continue
		keep.append(lb)
		var l3 := lb as Label3D
		if not l3.is_visible_in_tree() or l3.text.strip_edges() == "" or l3.modulate.a < 0.1:
			continue
		var r := _screen_rect(l3, cam)
		if r.size.x < 4.0 or r.size.y < 4.0 or not r.intersects(vp):
			continue
		vis.append([l3, r])
	_labels = keep
	for i in vis.size():
		for j in range(i + 1, vis.size()):
			var a: Rect2 = vis[i][1]
			var b: Rect2 = vis[j][1]
			if not a.intersects(b):
				continue
			var inter := a.intersection(b)
			var share := inter.get_area() / maxf(1.0, minf(a.get_area(), b.get_area()))
			if share < OVERLAP_MIN:
				continue
			var la: Label3D = vis[i][0]
			var lb2: Label3D = vis[j][0]
			if la.is_ancestor_of(lb2) or lb2.is_ancestor_of(la) or la.get_parent() == lb2.get_parent() and share < 0.6:
				continue  # parts of one sign (a name over its line) are laid out together on purpose
			var key := "%d_%d" % [la.get_instance_id(), lb2.get_instance_id()]
			var t := vt()
			if t - float(_overlaps.get(key, -100.0)) > 15.0:
				log_line("TEXT", "%d%% overlap: [%s] over [%s]" % [int(share * 100.0), la.text.left(40).replace("\n", " "), lb2.text.left(40).replace("\n", " ")])
			_overlaps[key] = t


func _near_face() -> void:
	if bot == null:
		return
	var eye: Vector3 = bot.eye_world()
	var keep: Array[Node] = []
	for m in _meshes:
		if not is_instance_valid(m):
			continue
		keep.append(m)
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		if box.size.length() > 3.0:
			continue  # the sky, the ground, the dome: big shells around the player on purpose
		var closest := Vector3(clampf(eye.x, box.position.x, box.end.x), clampf(eye.y, box.position.y, box.end.y), clampf(eye.z, box.position.z, box.end.z))
		if closest.distance_to(eye) < NEAR_EYE:
			var t := vt()
			var id := mi.get_instance_id()
			if t - float(_near.get(id, -100.0)) > 20.0:
				log_line("NEAR", "%s (%s) %.3f m from the eye" % [mi.name, str(mi.get_path()).right(70), closest.distance_to(eye)])
			_near[id] = t
	_meshes = keep


func _continue_check(dt: float) -> void:
	if l == null or not is_instance_valid(l):
		return
	var c = l.get("_cont")
	if c == null or not is_instance_valid(c) or not (c as Node3D).is_visible_in_tree():
		_cont_off = 0.0
		return
	var cam := _cam()
	var p: Vector3 = (c as Node3D).global_position
	var on := cam != null and not cam.is_position_behind(p) and get_viewport().get_visible_rect().has_point(cam.unproject_position(p))
	_cont_off = 0.0 if on else _cont_off + dt
	if _cont_off >= OFF_SCREEN_S and _cont_off < OFF_SCREEN_S + dt:
		log_line("UI", "the Continue plaque has been off screen for %.0f s" % OFF_SCREEN_S)
