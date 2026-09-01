class_name DummyShooter
extends Node

const INTERVAL := 2.2
const DAMAGE := 42.0
const SPEED := 16.0
const RANGE := 22.0
const RADIUS := 0.28

@export var fire_dir: Vector3 = Vector3(-1.0, 0.0, 0.0)

var _wait: float = 0.7

@onready var unit: Unit = get_parent()


func _physics_process(delta: float) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	if not GameSession.fight_started:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = INTERVAL
	_fire()


func _fire() -> void:
	var dir := Vector3(fire_dir.x, 0.0, fire_dir.z)
	if dir.length_squared() < 0.0001:
		dir = unit.facing_dir()
	if dir.length_squared() < 0.0001:
		dir = Vector3(-1.0, 0.0, 0.0)
	dir = dir.normalized()
	var origin := unit.global_position + dir * 0.55 + Vector3(0.0, 1.0, 0.0)
	Projectile.spawn(unit, origin, {
		"direction": dir,
		"speed": SPEED,
		"damage": DAMAGE,
		"radius": RADIUS,
		"max_distance": RANGE,
		"color": Color(1.0, 0.42, 0.16),
		"skillshot": true,
		"element": AbilityDef.Element.NONE,
		"vfx_scene": AbilityFx.MAGIC_BOLT,
		"vfx_scale": 0.7,
		"vfx_yaw": PI * 0.5,
		"vfx_primary": Color(1.0, 0.55, 0.22),
		"vfx_secondary": Color(0.85, 0.18, 0.08),
		"vfx_tertiary": Color(1.0, 0.85, 0.45),
		"ability_id": "dummy_bolt",
	})
