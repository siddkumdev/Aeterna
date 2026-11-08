class_name AudioBank
extends Node
## Plays the game's generated sounds (assets/generators/make_audio.py -> res://assets/audio/, with manifest.json).
## Sounds are called by name: play("place_thunk"), play("enemy_death", world_position). Anything the manifest does not
## list, or whose file is missing, is simply silent, so the game never depends on a sound being there.
## Buses (made at runtime if the project has none): ui, sfx, ambience, music, all under Master.
## Spatial sounds use a 3D player at the given world position; the rest are 2D. Each id keeps its own cooldown from the
## manifest (so a crowd of hits does not stack into noise) and a small random pitch change ("vary").
## Combo (manifest "combo", Siddharth 2026-11-08): repeats within COMBO_GAP_MS climb the key's pentatonic scale
## (quick kills go up do-re-mi-so-la), and fall back to the root after a pause.
## Scatter (set_scatter): short ambience one-shots played every few seconds at things on the board (birds in the
## forest ring, a villager at work by a house...), from a day or a night pool, on top of the bed.

const DIR := "res://assets/audio/"
const MAX_VOICES := 28
const BUS_DB := {"ui": -3.0, "sfx": -5.0, "ambience": -15.0, "music": -10.0}  # docs/AUDIO_DIRECTION.md
const DUCK_DB := -6.0  # a story beat (manifest "duck") lowers ambience and music this much while it plays
const DUCKED := ["ambience", "music"]
const COMBO_STEPS := [0, 2, 4, 7, 9]  # semitones: the major pentatonic of the game's key (C major, make_audio.py)
const COMBO_GAP_MS := 1200

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
var _duck_until := 0  # msec: ambience and music stay lowered until then
var _duck_tw: Tween
var _combo := {}  # id -> {"n": step, "ms": last play}
var _scatter: Array = []  # [{"id", "where", "w"}]
var _scatter_point: Callable  # where -> world position (Vector3.INF = play flat)
var _scatter_gap := Vector2(3.0, 7.0)
var _scatter_left := 0.0
var scattered := 0  # counted for tests


func _add_master_limiter() -> void:
	## Many sounds at once (fireballs landing together, 3D sounds boosted close to the head) can sum past full scale, and
	## the output then hard-clips: it sounds bit-crushed (Siddharth 2026-11-08, Wizard Tower attacks). A limiter on Master
	## turns those peaks down smoothly instead. Added once.
	var m := AudioServer.get_bus_index("Master")
	for k in AudioServer.get_bus_effect_count(m):
		if AudioServer.get_bus_effect(m, k) is AudioEffectHardLimiter:
			return
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(m, lim)


func setup() -> void:
	_rng.randomize()
	for b in BUS_DB:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			AudioServer.set_bus_volume_db(i, BUS_DB[b])
	_add_master_limiter()
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


func play(id: String, at := Vector3.INF) -> bool:
	## One-shot. `at` = world position for a spatial sound (INF = not placed: plays flat). True if it played.
	if not enabled or not manifest.has(id) or not is_inside_tree():
		return false
	var m: Dictionary = manifest[id]
	if m.get("loop", false):
		return false
	var now := Time.get_ticks_msec()
	if _cooling(id, now):
		return false
	if voices >= MAX_VOICES:
		return false
	var files: Array = m["files"]
	var s := _stream(files[_rng.randi_range(0, files.size() - 1)]["file"], false)
	if s == null:
		return false
	_last_ms[id] = now
	var vary: float = m.get("vary", 0.0)
	var pitch := 1.0 + _rng.randf_range(-vary, vary)
	if m.get("combo", false):
		pitch = _combo_pitch(id, now)
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
	if m.get("duck", false):
		_duck(s.get_length() / maxf(pitch, 0.01))
	voices += 1
	played += 1
	p.finished.connect(func():
		voices -= 1
		p.queue_free())
	p.play()
	return true


func _cooling(id: String, now: int) -> bool:
	var cd: float = manifest[id].get("cooldown", 0.0) if manifest.has(id) else 0.0
	return cd > 0.0 and now - int(_last_ms.get(id, -100000)) < int(cd * 1000.0)


func _combo_pitch(id: String, now: int) -> float:
	## The next step up the scale when this id repeats quickly, else back to the root. No random detune: it stays in tune.
	var c: Dictionary = _combo.get(id, {"n": -1, "ms": -100000})
	c["n"] = mini(int(c["n"]) + 1, COMBO_STEPS.size() - 1) if now - int(c["ms"]) < COMBO_GAP_MS else 0
	c["ms"] = now
	_combo[id] = c
	return pow(2.0, COMBO_STEPS[c["n"]] / 12.0)


func combo_step(id: String) -> int:
	## The step the last play of id reached (tests).
	return int(_combo.get(id, {"n": 0})["n"])


func set_scatter(pool: Array, point: Callable, gap := Vector2(3.0, 7.0)) -> void:
	## pool: [{"id": "amb_bird", "where": "forest", "w": 5}, ...]; [] stops it. point(where) gives the world position.
	_scatter = pool
	_scatter_point = point
	_scatter_gap = gap
	_scatter_left = _rng.randf_range(gap.x * 0.5, gap.y)  # the first one comes within one gap too


func _process(delta: float) -> void:
	if _scatter.is_empty() or not enabled:
		return
	_scatter_left -= delta
	if _scatter_left > 0.0:
		return
	_scatter_left = _rng.randf_range(_scatter_gap.x, _scatter_gap.y)
	var now := Time.get_ticks_msec()
	var ready := _scatter.filter(func(e): return not _cooling(e["id"], now))  # never waste a gap on a cooling sound
	var total := 0.0
	for e in ready:
		total += float(e.get("w", 1.0))
	var pick := _rng.randf() * total
	for e in ready:
		pick -= float(e.get("w", 1.0))
		if pick <= 0.0:
			var at: Vector3 = _scatter_point.call(e["where"]) if _scatter_point.is_valid() else Vector3.INF
			if play(e["id"], at):
				scattered += 1
			return


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


func _exit_tree() -> void:
	_set_duck(0.0)  # the buses outlive this node: never leave them lowered


func _duck(seconds: float) -> void:
	## Lowers ambience and music under a story beat, and brings them back once the last beat has finished.
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	if until <= _duck_until:
		return
	_duck_until = until
	if _duck_tw and _duck_tw.is_valid():
		_duck_tw.kill()
	_duck_tw = create_tween()
	_duck_tw.tween_method(_set_duck, _duck_amount(), 1.0, 0.25)
	_duck_tw.tween_interval(maxf(0.0, seconds - 0.5))
	_duck_tw.tween_method(_set_duck, 1.0, 0.0, 0.8)


func _duck_amount() -> float:
	## How far the ducked buses are down now, 0 (normal) to 1 (fully ducked).
	var i := AudioServer.get_bus_index("ambience")
	return 0.0 if i == -1 else clampf((BUS_DB["ambience"] - AudioServer.get_bus_volume_db(i)) / -DUCK_DB, 0.0, 1.0)


func _set_duck(k: float) -> void:
	for b in DUCKED:
		var i := AudioServer.get_bus_index(b)
		if i != -1:
			AudioServer.set_bus_volume_db(i, BUS_DB[b] + DUCK_DB * k)
