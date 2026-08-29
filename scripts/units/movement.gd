class_name UnitMovement
extends Node

const WAYPOINT_REACH := 0.32

var current_speed: float = 0.0
var has_target: bool = false
var arrive_epsilon: float = 0.4
var goal: Vector3 = Vector3.ZERO
var _requested_goal: Vector3 = Vector3.ZERO
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _dashing: bool = false
var _dash_left: float = 0.0
var _dash_duration: float = 0.0
var _dash_from: Vector3 = Vector3.ZERO
var _dash_to: Vector3 = Vector3.ZERO

@onready var unit: Unit = get_parent()
@onready var agent: NavigationAgent3D = unit.get_node("NavigationAgent3D")


func _ready() -> void:
	# Kept for scene compatibility; player movement uses the deterministic arena
	# planner because the runtime NavigationServer map is empty after baking.
	agent.avoidance_enabled = false


func bind_map(_map: RID) -> void:
	pass


func set_target(pos: Vector3, min_move: float = 0.2) -> void:
	var requested := Vector3(pos.x, unit.global_position.y, pos.z)
	if has_target and _xz_dist_sq(requested, _requested_goal) < min_move * min_move:
		return
	_requested_goal = requested
	var arena := ArenaState.arena as Arena
	if arena:
		_path = arena.plan_movement_path(unit.global_position, requested, maxf(unit.radius, 0.4))
	else:
		_path = PackedVector3Array([requested])
	if _path.is_empty():
		_path = PackedVector3Array([requested])
	_path_index = 0
	goal = _path[_path.size() - 1]
	has_target = true


func clear_target() -> void:
	has_target = false
	goal = unit.global_position
	_requested_goal = goal
	_path.clear()
	_path_index = 0


func is_dodging() -> bool:
	return _dashing


func start_dodge(dir: Vector3, distance: float, duration: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = unit.facing_dir()
	flat = flat.normalized()
	var dest := unit.global_position + flat * maxf(distance, 0.4)
	dest.y = unit.global_position.y
	var arena := ArenaState.arena as Arena
	if arena:
		dest = _dodge_stop_point(unit.global_position, dest, maxf(unit.radius, 0.4))
	_dashing = true
	_dash_duration = maxf(duration, 0.08)
	_dash_left = _dash_duration
	_dash_from = unit.global_position
	_dash_to = dest
	var look := dest - unit.global_position
	look.y = 0.0
	if look.length_squared() > 0.0001:
		unit.rotation.y = Basis.looking_at(look.normalized(), Vector3.UP).get_euler().y
	current_speed = look.length() / _dash_duration


func stop_dodge() -> void:
	_dashing = false
	_dash_left = 0.0
	current_speed = 0.0


func _dodge_stop_point(from: Vector3, dest: Vector3, clearance: float) -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return dest
	dest = arena.clamp_movement_point(dest, clearance)
	if arena.movement_segment_clear(from, dest, clearance + 0.06):
		return dest
	var best := from
	for i in 10:
		var p := from.lerp(dest, float(i + 1) / 10.0)
		p = arena.clamp_movement_point(p, clearance)
		if not arena.movement_segment_clear(from, p, clearance + 0.06):
			break
		best = p
	return best


func arrived() -> bool:
	if not has_target:
		return true
	return _xz_dist_sq(goal, unit.global_position) <= arrive_epsilon * arrive_epsilon


func is_traveling() -> bool:
	return has_target and not arrived()


func has_line_of_sight(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var space := unit.get_world_3d().direct_space_state
	if space == null:
		return true
	var from := unit.global_position + Vector3(0.0, 1.0, 0.0)
	var to := target.global_position + Vector3(0.0, 1.0, 0.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var skip: Array[RID] = [unit.get_rid()]
	if target is CollisionObject3D:
		skip.append((target as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return true
	var collider: Object = hit.get("collider")
	if collider == target:
		return true
	if collider is Node and (target.is_ancestor_of(collider) or collider.is_ancestor_of(target)):
		return true
	return false


func tick(delta: float, want_move: bool, face_override: Vector3 = Vector3.ZERO) -> void:
	if _dashing:
		_tick_dodge(delta)
		return
	var desired := Vector3.ZERO
	if want_move and has_target and not arrived():
		_advance_path()
		if _path_index < _path.size():
			var waypoint := _path[_path_index]
			desired = Vector3(
				waypoint.x - unit.global_position.x,
				0.0,
				waypoint.z - unit.global_position.z
			)
			if desired.length_squared() > 0.0001:
				desired = desired.normalized()
	elif face_override.length_squared() > 0.0001:
		desired = Vector3(face_override.x, 0.0, face_override.z)
		if desired.length_squared() > 0.0001:
			desired = desired.normalized()

	if desired.length_squared() > 0.0001:
		var look := Basis.looking_at(desired, Vector3.UP)
		var target_yaw: float = look.get_euler().y
		unit.rotation.y = lerp_angle(unit.rotation.y, target_yaw, 1.0 - exp(-unit.turn_rate * delta))
		if absf(angle_difference(unit.rotation.y, target_yaw)) < 0.04:
			unit.rotation.y = target_yaw

	var moving := want_move and has_target and not arrived() and desired.length_squared() > 0.0001
	if moving:
		current_speed = move_toward(current_speed, unit.current_move_speed(), unit.acceleration * delta)
	else:
		current_speed = move_toward(current_speed, 0.0, unit.deceleration * delta)

	var travel := desired if moving else unit.facing_dir()
	unit.velocity.x = travel.x * current_speed
	unit.velocity.z = travel.z * current_speed
	if unit.is_on_floor():
		unit.velocity.y = 0.0
	else:
		unit.velocity.y -= 24.0 * delta
	unit.move_and_slide()


func _tick_dodge(delta: float) -> void:
	if unit.is_stunned() or unit.is_dead:
		stop_dodge()
		unit.velocity.x = 0.0
		unit.velocity.z = 0.0
		if unit.is_on_floor():
			unit.velocity.y = 0.0
		else:
			unit.velocity.y -= 24.0 * delta
		unit.move_and_slide()
		return
	_dash_left = maxf(0.0, _dash_left - delta)
	var t := 1.0 if _dash_duration <= 0.001 else 1.0 - (_dash_left / _dash_duration)
	t = clampf(t, 0.0, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	var next := _dash_from.lerp(_dash_to, eased)
	var delta_pos := next - unit.global_position
	delta_pos.y = 0.0
	current_speed = delta_pos.length() / maxf(delta, 0.0001)
	unit.velocity.x = delta_pos.x / maxf(delta, 0.0001)
	unit.velocity.z = delta_pos.z / maxf(delta, 0.0001)
	if unit.is_on_floor():
		unit.velocity.y = 0.0
	else:
		unit.velocity.y -= 24.0 * delta
	unit.move_and_slide()
	if _dash_left <= 0.0:
		_dashing = false
		current_speed = 0.0


func _advance_path() -> void:
	while _path_index < _path.size() - 1:
		var waypoint := _path[_path_index]
		if _xz_dist_sq(waypoint, unit.global_position) > WAYPOINT_REACH * WAYPOINT_REACH:
			break
		_path_index += 1
	var arena := ArenaState.arena as Arena
	while arena and _path_index < _path.size() - 1:
		var later := _path[_path_index + 1]
		if not arena.movement_segment_clear(
			unit.global_position,
			later,
			maxf(unit.radius, 0.4) + 0.06
		):
			break
		_path_index += 1


func _xz_dist_sq(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return dx * dx + dz * dz
