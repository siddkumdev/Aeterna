class_name AudioBank
extends Node
## Plays the game's generated sounds (assets/generators/make_audio.py -> res://assets/audio/, with manifest.json).
## Sounds are called by name: play("place_thunk"), play("enemy_death", world_position). Anything the manifest does not
## list, or whose file is missing, is simply silent, so the game never depends on a sound being there.
## Buses (made at runtime if the project has none): ui, sfx, ambience, music, all under Master.
## Spatial sounds use a 3D player at the given world position; the rest are 2D. Each id keeps its own cooldown from the
## manifest (so a crowd of hits does not stack into noise) and a small random pitch change ("vary").

const DIR := "res://assets/audio/"
const MAX_VOICES := 28
const BUS_DB := {"ui": -4.0, "sfx": -2.0, "ambience": -6.0, "music": -8.0}

var enabled := true
var manifest := {}
var voices := 0
var played := 0          # counted for tests
var _streams := {}       # file name -> AudioStream (loops already set)
var _last_ms := {}       # id -> last play time
var _bed_players := {}   # bed name -> AudioStreamPlayer
var _bed := ""
var _fades := {}         # player -> its running fade tween
var _rng := RandomNumberGenerator.new()


func setup() -> void:
	_rng.randomize()
	for b in BUS_DB:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			AudioServer.set_bus_volume_db(i, BUS_DB[b])
	var f := FileAccess.open(DIR + "manifest.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		manifest = data


func has(id: String) -> bool:
	return manifest.has(id)


func _stream(file: String, loop: bool) -> AudioStream:
	var key := file + ("#loop" if loop else "")
	if _streams.has(key):
		return _streams[key]
	var s: AudioStream = null
	var path := DIR + file
	if ResourceLoader.exists(path):
		s = load(path)
		if s is AudioStreamWAV and loop:
			s = s.duplicate()
			var w := s as AudioStreamWAV
			var bytes: int = 2 * (2 if w.stereo else 1)
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.data.size() / bytes)
	_streams[key] = s
	return s


func play(id: String, at := Vector3.INF) -> void:
	## One-shot. `at` = world position for a spatial sound (INF = not placed: plays flat).
	if not enabled or not manifest.has(id) or not is_inside_tree():
		return
	var m: Dictionary = manifest[id]
	if m.get("loop", false):
		return
	var now := Time.get_ticks_msec()
	var cd: float = m.get("cooldown", 0.0)
	if cd > 0.0 and now - int(_last_ms.get(id, -100000)) < int(cd * 1000.0):
		return
	if voices >= MAX_VOICES:
		return
	var files: Array = m["files"]
	var s := _stream(files[_rng.randi_range(0, files.size() - 1)]["file"], false)
	if s == null:
		return
	_last_ms[id] = now
	var vary: float = m.get("vary", 0.0)
	var pitch := 1.0 + _rng.randf_range(-vary, vary)
	var p: Node
	var placed: bool = m.get("spatial", false) and at != Vector3.INF
	if placed:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.bus = m["bus"]
		p3.pitch_scale = pitch
		p3.unit_size = 0.7
		p3.max_distance = 8.0
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = s
		p2.bus = m["bus"]
		p2.pitch_scale = pitch
		p = p2
	add_child(p)
	if placed:
		(p as AudioStreamPlayer3D).global_position = at
	voices += 1
	played += 1
	p.finished.connect(func():
		voices -= 1
		p.queue_free())
	p.play()


func set_bed(bed: String) -> void:
	## Ambient bed ("day_bed", "night_bed", "" = none): fades the old one out and the new one in.
	if bed == _bed or not enabled or not is_inside_tree():
		return
	var old := _bed
	_bed = bed
	if old != "" and _bed_players.has(old):
		_fade(_bed_players[old], -60.0, 1.2, true)
	if bed == "" or not manifest.has(bed):
		return
	var p: AudioStreamPlayer = _bed_players.get(bed)
	if p == null:
		var s := _stream(manifest[bed]["files"][0]["file"], true)
		if s == null:
			return
		p = AudioStreamPlayer.new()
		p.stream = s
		p.bus = manifest[bed]["bus"]
		add_child(p)
		_bed_players[bed] = p
	if not p.playing:
		p.volume_db = -60.0
		p.play()
	_fade(p, 0.0, 1.6, false)


func _fade(p: AudioStreamPlayer, to_db: float, seconds: float, stop_after: bool) -> void:
	if _fades.has(p) and _fades[p].is_valid():
		_fades[p].kill()  # a bed switched back mid-fade: the old fade must not keep pulling it down
	var tw := create_tween()
	_fades[p] = tw
	tw.tween_property(p, "volume_db", to_db, seconds)
	if stop_after:
		tw.tween_callback(func():
			if is_instance_valid(p) and _bed_players.get(_bed) != p:
				p.stop())
