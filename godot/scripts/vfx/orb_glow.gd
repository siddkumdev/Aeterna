class_name OrbGlow
extends Node3D
## The Wizard Tower's floating power orb (asset list X26): a VFX ball, not a model. It hangs at the model's
## __orb_anchor, bobs, pulses and gives off slow embers. Siddharth 2026-10-27: the orb is the power source. It dims
## while the wizard's staff charges (TowerFx sets `level`) and flares back to full when the shot is released
## (flare()). Magic stays black / orange / red.

var size := 0.012  # diameter, metres (the anchor's ew_size)
var level := 1.0   # 0..1: how full the orb is

var _t := 0.0
var _flare := 0.0
var _fire: MeshInstance3D  # the painted swirling orb (fx_toon_fire, mode 0)
var _embers: CPUParticles3D


func setup(diameter: float) -> void:
	size = diameter
	_t = randf() * 10.0
	_fire = VfxKit.toon_fire(self, 0, Vector2.ONE * size * 2.0, 1.0, 1.0)
	_embers = VfxKit.trail(self, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 7, 0.9, size * 0.2)
	_embers.direction = Vector3.UP
	_embers.spread = 25.0
	_embers.initial_velocity_min = size * 0.4
	_embers.initial_velocity_max = size * 0.9
	_embers.gravity = Vector3.ZERO


func flare() -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta * 3.0)
	var lv := clampf(level + _flare * 0.5, 0.0, 1.0)
	position.y = sin(_t * 2.1) * size * 0.2  # bob
	scale = Vector3.ONE * (1.0 + _flare * 0.35)
	VfxKit.toon_set(_fire, "energy", 0.3 + 0.9 * lv)
	_embers.emitting = lv > 0.3
