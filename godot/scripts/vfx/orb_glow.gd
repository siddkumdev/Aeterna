class_name OrbGlow
extends Node3D
## The Wizard Tower's floating power orb (asset list X26): a VFX ball, not a model. It hangs at the model's __orb_anchor and
## the shot leaves from it (Siddharth 2026-11-04). Painted in the style of moodboard #44: a ball wound from fire strands. While
## the tower aims it swells and spins faster (TowerFx sets `charge`); on the shot it collapses and fills up again (fired()).
## Magic stays black / orange / red.

var size := 0.012   # diameter, metres (the anchor's ew_size)
var charge := 0.0   # 0..1: how close the next shot is

var _t := 0.0
var _spent := 0.0   # 1 just after a shot, falling to 0
var _phase := 0.0
var _fire: MeshInstance3D
var _embers: CPUParticles3D


func setup(diameter: float) -> void:
	size = diameter
	_t = randf() * 10.0
	_fire = VfxKit.paint(self, 0, Vector2.ONE * size * 2.8, 1.0, 0.0)
	VfxKit.toon_set(_fire, "depth_bias", 0.02)
	_embers = VfxKit.trail(self, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 6, 1.0, size * 0.14)
	_embers.direction = Vector3.UP
	_embers.spread = 35.0
	_embers.initial_velocity_min = size * 0.5
	_embers.initial_velocity_max = size * 1.1
	_embers.gravity = Vector3.ZERO


func fired() -> void:
	_spent = 1.0


func _process(delta: float) -> void:
	_t += delta
	_spent = maxf(0.0, _spent - delta * 3.5)
	position.y = sin(_t * 2.1) * size * 0.2  # bob
	_phase += delta * (0.8 + 1.6 * charge)
	VfxKit.toon_set(_fire, "phase", _phase)
	VfxKit.toon_set(_fire, "size", Vector2.ONE * size * 2.8 * (1.0 + 0.18 * charge * charge - 0.5 * _spent))  # a billboard ignores node scale
	VfxKit.toon_set(_fire, "energy", 1.0 + 0.15 * charge - 0.25 * _spent)
	VfxKit.toon_set(_fire, "glow", 0.06 + 0.1 * charge)
