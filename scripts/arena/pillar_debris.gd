class_name PillarDebris
extends Node3D

## Shatter chunks rest, then shrink away. Recycle via `recycle` so this
## script does not parse-depend on ArenaPillar.
const GROUND_HOLD := 3
const SHRINK_TIME := 1.4
const SETTLE_SPEED := 0.7
const FORCE_SETTLE := 1.6

var recycle: Callable
var _spawned: float = 0.0
var _rest: Array[Transform3D] = []
var _bodies: Array[RigidBody3D] = []
var _settled: PackedByteArray = PackedByteArray()
var _grounded: PackedFloat32Array = PackedFloat32Array()
var _shrinking: bool = false
var _shrink_t: float = 0.0


func cache_rest() -> void:
	_bodies.clear()
	_rest.clear()
	_collect_bodies(self)


func _collect_bodies(n: Node) -> void:
	for child in n.get_children():
		var rb := child as RigidBody3D
		if rb == null:
			_collect_bodies(child)
			continue
		_bodies.append(rb)
		_rest.append(rb.transform)
		rb.can_sleep = true
		rb.continuous_cd = false
		rb.contact_monitor = false
		rb.linear_damp = 1.15
		rb.angular_damp = 1.35
		rb.gravity_scale = 1.55
		rb.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		for mesh_n in rb.get_children():
			if mesh_n is GeometryInstance3D:
				var gi := mesh_n as GeometryInstance3D
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func arm() -> void:
	_spawned = 0.0
	_shrinking = false
	_shrink_t = 0.0
	_settled.resize(_bodies.size())
	_grounded.resize(_bodies.size())
	scale = Vector3.ONE
	for i in _bodies.size():
		_settled[i] = 0
		_grounded[i] = 0.0
		var rb := _bodies[i]
		if rb == null or not is_instance_valid(rb):
			continue
		rb.transform = _rest[i]
		rb.scale = Vector3.ONE
		rb.freeze = false
		rb.sleeping = false
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.visible = true
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _shrinking:
		_tick_shrink(delta)
		return
	_spawned += delta
	var live := 0
	var ready := 0
	for i in _bodies.size():
		var rb := _bodies[i]
		if rb == null or not is_instance_valid(rb):
			continue
		live += 1
		if _settled[i] == 1:
			ready += 1
			continue
		var settled := _is_settled(rb) or _spawned >= FORCE_SETTLE
		if settled:
			_grounded[i] = _grounded[i] + delta
			if _grounded[i] >= GROUND_HOLD:
				_settled[i] = 1
				rb.freeze = true
				rb.sleeping = true
				rb.linear_velocity = Vector3.ZERO
				rb.angular_velocity = Vector3.ZERO
				rb.collision_mask = 0
				ready += 1
		else:
			_grounded[i] = 0.0
	if live == 0 or ready >= live:
		_shrinking = true
		_shrink_t = 0.0


func _is_settled(rb: RigidBody3D) -> bool:
	if rb.sleeping:
		return true
	var vel := rb.linear_velocity
	return vel.length() < SETTLE_SPEED and absf(vel.y) < 0.4


func _tick_shrink(delta: float) -> void:
	_shrink_t += delta
	var u := clampf(_shrink_t / SHRINK_TIME, 0.0, 1.0)
	var s := Vector3.ONE * (1.0 - u)
	for rb in _bodies:
		if rb == null or not is_instance_valid(rb):
			continue
		rb.scale = s
	if u < 1.0:
		return
	set_physics_process(false)
	if recycle.is_valid():
		recycle.call(self)
		return
	queue_free()
