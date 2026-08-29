class_name UnitController
extends Node

enum Order { IDLE, MOVE, ATTACK, ATTACK_MOVE, CAST, CHANNEL }

var order: Order = Order.IDLE
var move_to: Vector3 = Vector3.ZERO
var attack_target: Unit = null
var attack_move_to: Vector3 = Vector3.ZERO
var cast_index: int = -1
var cast_point: Vector3 = Vector3.ZERO
var cast_target: Unit = null
var _cast_elapsed: float = 0.0
var _cast_time_scale: float = 1.0
var _gcd_started: bool = false
var _queued_index: int = -1
var _queued_point: Vector3 = Vector3.ZERO
var _queued_target: Unit = null
var _channel_sfx: int = 0
var _cast_sfx: int = 0

@onready var unit: Unit = get_parent()


func cmd_move(pos: Vector3) -> void:
	_interrupt_channel()
	_stop_cast_sfx()
	_clear_cast_queue()
	order = Order.MOVE
	move_to = pos
	attack_target = null
	cast_index = -1
	cast_target = null
	unit.auto_attack.cancel()
	unit.movement.set_target(pos, 0.12)


func retarget_move(pos: Vector3) -> void:
	if order != Order.MOVE:
		cmd_move(pos)
		return
	move_to = pos
	unit.movement.set_target(pos, 0.45)


func cmd_attack(target: Unit) -> void:
	if target == null or target.is_dead:
		return
	_interrupt_channel()
	_stop_cast_sfx()
	_clear_cast_queue()
	order = Order.ATTACK
	cast_index = -1
	cast_target = null
	if attack_target != target:
		unit.auto_attack.cancel()
	attack_target = target


func cmd_attack_move(pos: Vector3) -> void:
	_interrupt_channel()
	_stop_cast_sfx()
	_clear_cast_queue()
	order = Order.ATTACK_MOVE
	attack_move_to = pos
	attack_target = null
	cast_index = -1
	cast_target = null
	unit.auto_attack.cancel()
	unit.movement.set_target(pos, 0.12)


func cmd_cast(index: int, point: Vector3, target: Unit = null) -> void:
	if is_channeling() and cast_index == index:
		confirm_channel()
		return
	if _can_queue_cast(index):
		_set_queued_cast(index, point, target)
		return
	_interrupt_channel()
	_begin_cast(index, point, target)


func cmd_channel(index: int, point: Vector3) -> void:
	if not unit.can_cast(index):
		return
	_clear_cast_queue()
	var ab: AbilityDef = unit.abilities[index]
	cast_point = unit.clamped_ground_point(point, ab.range)
	cast_index = index
	cast_target = null
	_cast_elapsed = 0.0
	_gcd_started = true
	_snapshot_cast_speed()
	unit.trigger_global_cooldown(index)
	unit.spend_mana(index)
	unit.auto_attack.cancel()
	unit.movement.clear_target()
	order = Order.CHANNEL
	_stop_channel_sfx()
	if ab.id == "meteor":
		_channel_sfx = AudioManager.play_on("fire.cast", unit)
	elif ab.element == AbilityDef.Element.FIRE:
		_channel_sfx = AudioManager.play_on("fire.cast", unit, {"from_end": _channel_duration(ab)})


func confirm_channel() -> void:
	if not is_channeling():
		return
	var idx := cast_index
	var point := cast_point
	var charge := channel_charge()
	cast_index = -1
	order = Order.IDLE
	_stop_channel_sfx()
	unit.finish_channeled_ability(idx, point, charge)
	_flush_cast_queue()


func cancel_channel() -> void:
	_interrupt_channel()


func _interrupt_channel() -> void:
	if not is_channeling():
		return
	var idx := cast_index
	cast_index = -1
	order = Order.IDLE
	_stop_channel_sfx()
	_clear_cast_queue()
	unit.apply_cooldown(idx, 0.25)


func _stop_channel_sfx() -> void:
	AudioManager.stop_loop(_channel_sfx, 0.12)
	_channel_sfx = 0


func _start_cast_sfx(ab: AbilityDef) -> void:
	_stop_cast_sfx()
	if ab == null:
		return
	var duration := maxf(ab.cast_time * _cast_time_scale, 0.001)
	if ab.element == AbilityDef.Element.FIRE:
		_cast_sfx = AudioManager.play_on("fire.cast", unit, {"from_end": duration})
		return
	if ab.id == "thunder_wave" or ab.element == AbilityDef.Element.STORM:
		_cast_sfx = AudioManager.play_on("thunder_wave.cast", unit, {"from_end": duration})
		return
	AudioManager.play_at("%s.cast" % ab.id, unit.global_position + Vector3(0.0, 1.1, 0.0))


func _stop_cast_sfx() -> void:
	AudioManager.stop_loop(_cast_sfx, 0.08)
	_cast_sfx = 0


func stop_now() -> void:
	if is_channeling():
		_clear_cast_queue()
		return
	_interrupt_channel()
	_stop_cast_sfx()
	_clear_cast_queue()
	order = Order.IDLE
	attack_target = null
	cast_index = -1
	cast_target = null
	unit.auto_attack.cancel()
	unit.movement.clear_target()


func issue_move_local(pos: Vector3) -> void:
	cmd_move(pos)


func issue_move_hold(pos: Vector3) -> void:
	retarget_move(pos)


func issue_attack_local(target: Unit) -> void:
	cmd_attack(target)


func issue_attack_move_local(pos: Vector3) -> void:
	cmd_attack_move(pos)


func issue_stop_local() -> void:
	stop_now()


func issue_cast_local(index: int, point: Vector3, target: Unit = null) -> void:
	cmd_cast(index, point, target)


func issue_dodge(dir: Vector3) -> void:
	if unit == null or not unit.try_dodge(dir):
		return
	_interrupt_channel()
	_stop_cast_sfx()
	unit.auto_attack.cancel()
	if order == Order.CAST or order == Order.CHANNEL:
		order = Order.IDLE
		cast_index = -1
		cast_target = null
		_cast_elapsed = 0.0
		_gcd_started = false


func ai_move(pos: Vector3) -> void:
	cmd_move(pos)


func ai_attack(target: Unit) -> void:
	cmd_attack(target)


func ai_cast(index: int, point: Vector3, target: Unit = null) -> void:
	cmd_cast(index, point, target)


func ai_stop() -> void:
	stop_now()


func tick(delta: float) -> void:
	if unit.is_dead:
		_clear_cast_queue()
		return
	if unit.is_stunned():
		if order == Order.CAST or order == Order.CHANNEL:
			_interrupt_channel()
			_clear_cast_queue()
			order = Order.IDLE
			cast_index = -1
			cast_target = null
		unit.auto_attack.cancel()
		unit.movement.tick(delta, false)
		return
	if unit.is_dodging():
		unit.movement.tick(delta, false)
		if not unit.is_dodging() and _queued_index >= 0:
			_flush_cast_queue()
		return
	if order == Order.IDLE and _queued_index >= 0 and _flush_cast_queue():
		if order == Order.CAST:
			_tick_cast(delta)
		elif order == Order.CHANNEL:
			_tick_channel(delta)
		return
	match order:
		Order.IDLE:
			unit.movement.tick(delta, false)
		Order.MOVE:
			_tick_move(delta)
		Order.ATTACK:
			_tick_attack(delta)
		Order.ATTACK_MOVE:
			_tick_attack_move(delta)
		Order.CAST:
			_tick_cast(delta)
		Order.CHANNEL:
			_tick_channel(delta)


func _tick_move(delta: float) -> void:
	if unit.movement.arrived():
		order = Order.IDLE
		unit.movement.clear_target()
		unit.movement.tick(delta, false)
		return
	unit.movement.tick(delta, true)


func _tick_attack(delta: float) -> void:
	if attack_target == null or not is_instance_valid(attack_target) or attack_target.is_dead:
		order = Order.IDLE
		unit.movement.tick(delta, false)
		return
	var to_target := attack_target.global_position - unit.global_position
	to_target.y = 0.0
	if unit.in_range_of(attack_target) and unit.movement.has_line_of_sight(attack_target):
		unit.movement.has_target = false
		unit.movement.tick(delta, false, to_target)
		unit.auto_attack.try_start(attack_target)
		unit.auto_attack.tick(delta)
	else:
		unit.auto_attack.cancel()
		var chase := attack_target.global_position
		if unit.movement.goal.distance_squared_to(chase) > 0.25:
			unit.movement.set_target(chase)
		unit.movement.tick(delta, true)
		unit.auto_attack.tick(delta)


func _tick_attack_move(delta: float) -> void:
	var nearby := _enemy_in_auto_range()
	if nearby:
		attack_target = nearby
		_tick_attack(delta)
		if order == Order.IDLE:
			order = Order.ATTACK_MOVE
			unit.movement.set_target(attack_move_to)
		return
	attack_target = null
	if unit.movement.arrived():
		order = Order.IDLE
		unit.movement.clear_target()
		unit.movement.tick(delta, false)
		return
	unit.movement.set_target(attack_move_to)
	unit.movement.tick(delta, true)
	unit.auto_attack.tick(delta)


func is_casting() -> bool:
	if order == Order.CHANNEL and cast_index >= 0:
		return true
	return order == Order.CAST and cast_index >= 0 and _cast_elapsed > 0.0


func is_channeling() -> bool:
	return order == Order.CHANNEL and cast_index >= 0


func channel_charge() -> float:
	var ab := casting_ability()
	if ab == null:
		return 0.0
	return clampf(_cast_elapsed / _channel_duration(ab), 0.0, 1.0)


func _snapshot_cast_speed() -> void:
	_cast_time_scale = unit.cast_time_scale() if unit != null else 1.0


func _channel_duration(ab: AbilityDef) -> float:
	return maxf(ab.channel_time * _cast_time_scale, 0.001)


func cast_progress() -> float:
	var ab := casting_ability()
	if ab == null:
		return 0.0
	if order == Order.CHANNEL:
		return channel_charge()
	if ab.cast_time <= 0.001:
		return 1.0
	return clampf(_cast_elapsed / maxf(ab.cast_time * _cast_time_scale, 0.001), 0.0, 1.0)


func casting_ability() -> AbilityDef:
	if unit == null or cast_index < 0 or cast_index >= unit.abilities.size():
		return null
	return unit.abilities[cast_index]


func _can_queue_cast(index: int = -1) -> bool:
	if unit != null and unit.is_dodging():
		return true
	if is_channeling() or (order == Order.CAST and cast_index >= 0 and _cast_elapsed > 0.0):
		return true
	return unit != null and unit.is_on_global_cooldown(index)


func _set_queued_cast(index: int, point: Vector3, target: Unit) -> void:
	if unit == null or index < 0 or index >= unit.abilities.size():
		return
	_queued_index = index
	_queued_point = point
	_queued_target = target


func _clear_cast_queue() -> void:
	_queued_index = -1
	_queued_point = Vector3.ZERO
	_queued_target = null


func clear_cast_queue() -> void:
	_clear_cast_queue()


func _begin_cast(index: int, point: Vector3, target: Unit) -> void:
	_clear_cast_queue()
	if not unit.can_cast(index):
		return
	var ab: AbilityDef = unit.abilities[index]
	if ab.is_channel:
		cmd_channel(index, point)
		return
	if _is_instant(ab) and _instant_can_fire(ab, point, target):
		_fire_instant(index, point, target, ab)
		return
	order = Order.CAST
	cast_index = index
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		cast_point = unit.clamped_ground_point(point, ab.range)
	else:
		cast_point = point
	cast_target = target
	_cast_elapsed = 0.0
	_gcd_started = false
	unit.auto_attack.cancel()


func _is_instant(ab: AbilityDef) -> bool:
	return ab != null and not ab.is_channel and ab.cast_time <= 0.001


func _instant_can_fire(ab: AbilityDef, point: Vector3, target: Unit) -> bool:
	if ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		return true
	if ab.target_mode == AbilityDef.TargetMode.INSTANT:
		return true
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		return true
	if ab.target_mode == AbilityDef.TargetMode.UNIT:
		if target == null or not is_instance_valid(target) or target.is_dead:
			return false
		if ab.is_ally_support() and target.team != unit.team:
			return false
		if not ab.is_ally_support() and target.team == unit.team:
			return false
		if not unit.ability_in_range(ab, target.global_position):
			return false
		return unit.movement.has_line_of_sight(target)
	return true


func _fire_instant(index: int, point: Vector3, target: Unit, ab: AbilityDef) -> void:
	var aim := point
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		aim = unit.clamped_ground_point(point, ab.range)
	elif ab.target_mode == AbilityDef.TargetMode.UNIT:
		aim = target.global_position
	unit.trigger_global_cooldown(index)
	unit.cast_ability(index, aim, target)


func _flush_cast_queue() -> bool:
	var index := _queued_index
	var point := _queued_point
	var target := _queued_target
	if index < 0:
		return false
	if not unit.can_cast(index):
		if unit.is_on_global_cooldown(index) and unit.can_prepare_cast(index):
			return false
		_clear_cast_queue()
		return false
	_clear_cast_queue()
	_begin_cast(index, point, target)
	return order == Order.CAST or order == Order.CHANNEL


func _tick_cast(delta: float) -> void:
	if cast_index < 0 or cast_index >= unit.abilities.size():
		_end_cast(delta)
		return
	if _cast_elapsed <= 0.0 and not unit.can_prepare_cast(cast_index):
		_end_cast(delta)
		return
	var ab: AbilityDef = unit.abilities[cast_index]
	var aim := cast_point
	if ab.target_mode == AbilityDef.TargetMode.UNIT:
		if cast_target == null or not is_instance_valid(cast_target) or cast_target.is_dead:
			_end_cast(delta)
			return
		aim = cast_target.global_position
	var to := aim - unit.global_position
	to.y = 0.0
	# Skill shots (and instants) fire from the caster toward the click, even if the
	# cursor is past max range. Targeted and ground AoE still walk into range first.
	if ab.target_mode == AbilityDef.TargetMode.UNIT or ab.target_mode == AbilityDef.TargetMode.GROUND:
		var need_range := ab.range
		if ab.target_mode == AbilityDef.TargetMode.UNIT and cast_target:
			need_range += unit.radius + cast_target.radius
		var too_far := unit.global_position.distance_to(aim) > need_range
		var blocked := ab.target_mode == AbilityDef.TargetMode.UNIT and not unit.movement.has_line_of_sight(cast_target)
		if too_far or blocked:
			unit.movement.set_target(aim)
			unit.movement.tick(delta, true)
			return
	if _is_instant(ab):
		if not _gcd_started:
			if not unit.can_cast(cast_index):
				return
			unit.trigger_global_cooldown(cast_index)
			_gcd_started = true
			_snapshot_cast_speed()
		unit.cast_ability(cast_index, aim, cast_target)
		cast_index = -1
		cast_target = null
		order = Order.IDLE
		if not _flush_cast_queue():
			return
		if order == Order.CAST:
			_tick_cast(delta)
		elif order == Order.CHANNEL:
			_tick_channel(delta)
		return
	unit.movement.has_target = false
	unit.movement.tick(delta, false, to)
	if not unit.is_facing(to, 0.22) and to.length_squared() > 0.04:
		return
	if not _gcd_started:
		if not unit.can_cast(cast_index):
			return
		unit.trigger_global_cooldown(cast_index)
		_gcd_started = true
		_snapshot_cast_speed()
		_start_cast_sfx(ab)
	_cast_elapsed += delta
	if _cast_elapsed >= ab.cast_time * _cast_time_scale:
		unit.cast_ability(cast_index, aim, cast_target)
		cast_index = -1
		cast_target = null
		order = Order.IDLE
		if not _flush_cast_queue():
			return
		if order == Order.CAST:
			_tick_cast(delta)
		elif order == Order.CHANNEL:
			_tick_channel(delta)


func _end_cast(delta: float) -> void:
	_stop_cast_sfx()
	cast_index = -1
	cast_target = null
	order = Order.IDLE
	if _flush_cast_queue():
		if order == Order.CAST:
			_tick_cast(delta)
			return
		if order == Order.CHANNEL:
			_tick_channel(delta)
			return
	unit.movement.tick(delta, false)


func _tick_channel(delta: float) -> void:
	var ab := casting_ability()
	if ab == null:
		_stop_channel_sfx()
		order = Order.IDLE
		cast_index = -1
		unit.movement.tick(delta, false)
		return
	var to := cast_point - unit.global_position
	to.y = 0.0
	unit.movement.has_target = false
	unit.movement.tick(delta, false, to)
	var max_t := _channel_duration(ab)
	_cast_elapsed = minf(_cast_elapsed + delta, max_t)
	if _cast_elapsed >= max_t:
		confirm_channel()


func _enemy_in_auto_range() -> Unit:
	var best: Unit = null
	var best_d := INF
	var origin := attack_move_to
	for u in ArenaState.units:
		if u == null or u == unit or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == unit.team:
			continue
		if not unit.in_range_of(u, 0.15):
			continue
		var d := origin.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best
