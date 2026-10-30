class_name IslandThrust
extends Node3D
## The island's magic propulsion (asset list W02 / VFX_NOTES 2026-10-29, Siddharth): a painted fire orb in the seed's dark
## crack, a warm plume that pours DOWN under it and slow embers that fall away, with a soft halo. Not an engine flame:
## it breathes, and `pulse()` flares it (the villagers' energy channelling will call it). Magic stays black / orange / red.
## Hangs at the underside's `thrust_anchor` (ew_size = the anchor radius in metres).

var size := 0.06   # the anchor's ew_size
var level := 1.0   # 0..1, how bright (the lighting moods can set it)

var _t := 0.0
var _flare := 0.0
var _core: MeshInstance3D
var _plume: MeshInstance3D
var _halo: MeshInstance3D
var _embers: CPUParticles3D


func setup(anchor_size: float) -> void:
	size = anchor_size
	_t = randf() * 10.0
	var d := size * 2.0  # orb diameter
	_halo = VfxKit.halo(self, d * 4.0, Color(VfxKit.FIRE_ORANGE, 0.35))
	_plume = VfxKit.toon_fire(self, 1, Vector2(d * 3.2, -d * 3.4), 1.0, 1.0)  # negative height: it hangs downward, wide and short: a spill of light, not a rocket flame
	VfxKit.toon_set(_plume, "depth_bias", 0.02)
	_core = VfxKit.toon_fire(self, 0, Vector2.ONE * d * 1.5, 1.0, 1.0)
	VfxKit.toon_set(_core, "depth_bias", 0.03)
	_embers = VfxKit.trail(self, VfxKit.FIRE_YELLOW, VfxKit.FIRE_RED, 18, 2.2, d * 0.22)
	_embers.direction = Vector3.DOWN
	_embers.spread = 35.0
	_embers.initial_velocity_min = d * 0.25
	_embers.initial_velocity_max = d * 0.7
	_embers.gravity = Vector3(0, -d * 0.4, 0)


func pulse() -> void:
	_flare = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flare = maxf(0.0, _flare - delta * 1.6)
	var breath := 0.85 + 0.15 * sin(_t * 1.3)
	var lv := clampf(level * breath + _flare * 0.6, 0.0, 1.5)
	VfxKit.toon_set(_core, "energy", 0.5 + 0.7 * lv)
	VfxKit.toon_set(_plume, "energy", 0.35 + 0.75 * lv)
	VfxKit.set_halo(_halo, size * 2.0 * (3.6 + 0.7 * lv), Color(VfxKit.FIRE_ORANGE, clampf(0.18 + 0.22 * lv, 0.0, 0.7)))
	_embers.emitting = level > 0.05
