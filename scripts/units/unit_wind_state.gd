class_name UnitWindState
extends RefCounted

## Owned knockback / knockup / carry motion. UnitWind is the only mutator.

var kb_left: float = 0.0
var kb_dur: float = 0.0
var kb_from: Vector3 = Vector3.ZERO
var kb_to: Vector3 = Vector3.ZERO
var air_left: float = 0.0
var air_dur: float = 0.0
var air_rise: float = 0.0
var air_peak: float = 0.0
var ground_y: float = 0.0
var ray_left: float = 0.0
var ray_from: Unit
var ray_dir: Vector3 = Vector3.ZERO
var carry: Area3D


func clear() -> void:
	kb_left = 0.0
	air_left = 0.0
	air_rise = 0.0
	ray_left = 0.0
	ray_from = null
	ray_dir = Vector3.ZERO
	carry = null


func displacing() -> bool:
	return air_left > 0.0 or kb_left > 0.0 or carry != null or ray_left > 0.0
