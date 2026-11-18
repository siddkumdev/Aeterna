extends Node
## Background music that follows the time of day. Two quiet loops on the "music" bus: the day music, and the cozy-eerie
## night bed. As dusk comes the day music fades slowly away and the night bed fades in; at dawn the night bed fades
## out and the day music fades back in. The level comes from the sun's energy (as in fake_bloom.gd), so it follows the
## game's own dusk and dawn. Gains move at a limited speed, so a quick light change never makes a quick music change.
## No class_name on purpose (loaded by path): Game does `load("res://scripts/audio/music_director.gd").attach(self)`.
## Both loops are made from MIDI (assets/audio/music/*.wav): see docs/MUSIC_CREDITS.md and art/decisions.md.
## (Siddharth, 2026-11-18: day music from his draft, background level, fade away at night, fade back in after.)

const DAY_FILE := "music/day_music.wav"
const NIGHT_FILE := "music/night_music.wav"
const DAY_OUT := Vector2(0.05, 0.55)    # night level over which the day music fades out
const NIGHT_IN := Vector2(0.35, 0.95)   # ... and the night bed fades in
const SLEW := 0.12                      # gain change per second at most: a full fade takes about 8 s
const MIN_DB := -60.0

var game: Node
var audio: Node
var lighting: Object
## test hook: >= 0 replaces the lighting-derived night level
var force_level := -1.0
## true while the opening story plays its own score: both loops stay silent (the story is not the game's day or night)
var hold := false
var day_gain := 0.0
var night_gain := 0.0
var _day: AudioStreamPlayer
var _night: AudioStreamPlayer
var _started := false


static func attach(g: Node) -> Node:
	var m: Node = load("res://scripts/audio/music_director.gd").new()
	m.name = "MusicDirector"
	m.game = g
	g.add_child(m)
	return m


func _ready() -> void:
	audio = game.get("audio")
	if audio == null or not audio.enabled:
		set_process(false)
		return
	_day = _player(DAY_FILE)
	_night = _player(NIGHT_FILE)
	set_process(_day != null or _night != null)


func _player(file: String) -> AudioStreamPlayer:
	var s: AudioStream = audio._stream(file, true)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = "music"
	p.volume_db = MIN_DB
	add_child(p)
	return p


func level() -> float:
	## 0 by day, 1 at night.
	if force_level >= 0.0:
		return force_level
	if lighting == null or not is_instance_valid(lighting):
		lighting = game.get("lighting")
		if lighting == null:
			return 0.0
	var e: float = lighting.sun.light_energy
	return clampf(1.0 - e / 0.9, 0.0, 1.0)


func targets(lv: float) -> Vector2:
	## (day, night) linear gain for a night level.
	return Vector2(1.0 - smoothstep(DAY_OUT.x, DAY_OUT.y, lv), smoothstep(NIGHT_IN.x, NIGHT_IN.y, lv))


func _process(delta: float) -> void:
	if hold:
		day_gain = 0.0
		night_gain = 0.0
		_apply(_day, 0.0)
		_apply(_night, 0.0)
		return
	var t := targets(level())
	day_gain = move_toward(day_gain, t.x, SLEW * delta)
	night_gain = move_toward(night_gain, t.y, SLEW * delta)
	_apply(_day, day_gain)
	_apply(_night, night_gain)


func _apply(p: AudioStreamPlayer, gain: float) -> void:
	if p == null:
		return
	if gain <= 0.001:
		p.volume_db = MIN_DB
		if p.playing:
			p.stop()
		return
	p.volume_db = maxf(linear_to_db(gain), MIN_DB)
	if not p.playing:
		p.play()
