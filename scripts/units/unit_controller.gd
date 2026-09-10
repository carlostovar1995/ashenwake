class_name UnitController
extends Node

enum Order { IDLE, MOVE, ATTACK, ATTACK_MOVE, CAST, CHANNEL }

## Rooted casts shorter than this keep a buffered move so a 0.15s bolt does not eat a kite click. Longer lockouts like Meteor drop the memory.
const MOVE_MEMORY_CAST_LIMIT := 0.2
## Queue the next spell only in this end window; earlier recasts interrupt instead.
const CAST_QUEUE_REMAINING := 0.25
const CAST_QUEUE_PROGRESS := 0.90

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
var _channel_tick_acc: float = 0.0
var _channel_ticked: bool = false
var _halt_move: bool = false
var _pending_move: Vector3 = Vector3.ZERO
var _has_pending_move: bool = false
var _ray_dir: Vector3 = Vector3.ZERO
var _ray_want: Vector3 = Vector3.ZERO

@onready var unit: Unit = get_parent()


func _character_visual() -> Node:
	if unit == null:
		return null
	return unit.get_node_or_null("CharacterVisual")


func _play_spell_load(ab: AbilityDef, auto_release: bool = false, windup: float = 0.0) -> void:
	var vis := _character_visual()
	if vis:
		vis.play_spell_load(ab, auto_release, windup)


func _play_spell_release(ab: AbilityDef, remaining_until_fire: float = -1.0, replace: bool = false) -> void:
	var vis := _character_visual()
	if vis:
		vis.play_spell_release(ab, remaining_until_fire, replace)


func _play_channel_visual(ab: AbilityDef) -> void:
	if SpellAnimPolicy.mode_for(ab) == SpellAnimPolicy.Mode.WINDUP_HOLD:
		var vis := _character_visual()
		if vis:
			vis.hold_spell_channel_pose(ab)
		return
	_play_spell_load(ab)


func _play_spell_instant_visual(ab: AbilityDef) -> void:
	if SpellAnimPolicy.mode_for(ab) == SpellAnimPolicy.Mode.COMBINED:
		_play_spell_load(ab, false, SpellAnimPolicy.gameplay_window(ab.cast_time if ab else 0.0, _cast_time_scale))
		return
	_play_spell_release(ab, 0.0, true)


func _maybe_overlap_release(ab: AbilityDef, remaining: float) -> void:
	var vis := _character_visual()
	if vis == null or ab == null:
		return
	if remaining <= vis.release_overlap_seconds(ab):
		vis.play_spell_release(ab, remaining)


func _cancel_spell_visual() -> void:
	var vis := _character_visual()
	if vis:
		vis.cancel_spell_anim()


func cmd_move(pos: Vector3) -> void:
	_halt_move = false
	_clear_pending_move()
	if _keep_cast_and_move(pos):
		return
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
	_cancel_spell_visual()


func retarget_move(pos: Vector3) -> void:
	_halt_move = false
	if order == Order.CAST or order == Order.CHANNEL:
		if _keep_cast_and_move(pos):
			return
		if _retains_move_memory(casting_ability()):
			_pending_move = pos
			_has_pending_move = true
			return
		cmd_move(pos)
		return
	if order != Order.MOVE:
		cmd_move(pos)
		return
	move_to = pos
	unit.movement.set_target(pos, 0.45)


func cmd_attack(target: Unit) -> void:
	if target == null or target.is_dead:
		return
	_clear_pending_move()
	if is_protection_hold():
		_keep_cast_and_move(target.global_position)
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
	_cancel_spell_visual()


func cmd_attack_move(pos: Vector3) -> void:
	_clear_pending_move()
	if is_protection_hold():
		_keep_cast_and_move(pos)
		return
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
	_cancel_spell_visual()


func cmd_cast(index: int, point: Vector3, target: Unit = null) -> void:
	if is_channeling() and cast_index == index:
		if is_protection_hold():
			_reaim_protection(point)
			return
		confirm_channel()
		return
	if _can_queue_cast(index):
		_set_queued_cast(index, point, target)
		return
	_abort_cast_for_replace()
	_begin_cast(index, point, target)


func cmd_channel(index: int, point: Vector3, target: Unit = null) -> void:
	if not unit.can_prepare_cast(index):
		return
	if order != Order.CAST and not unit.can_cast(index):
		return
	var ab: AbilityDef = unit.abilities[index]
	if not _legal_unit_target(ab, target):
		return
	_clear_cast_queue()
	cast_index = index
	cast_target = target
	if ab.target_mode == AbilityDef.TargetMode.UNIT and target != null and is_instance_valid(target):
		cast_point = target.global_position
	elif ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		cast_point = unit.clamped_skillshot_point(point, ab)
	else:
		cast_point = unit.clamped_ground_point(point, ab.range)
	if ab.delivery == AbilityDef.Delivery.RAY:
		reaim_ray(point)
	_cast_elapsed = 0.0
	_channel_tick_acc = 0.0
	_channel_ticked = false
	_gcd_started = true
	_snapshot_cast_speed()
	unit.begin_channel_cast(index)
	if not _defers_channel_cooldown(ab):
		unit.trigger_global_cooldown(index)
	if not ab.cost_per_tick:
		unit.spend_mana(index)
	unit.auto_attack.cancel()
	if ab.move_while_casting:
		_halt_move = false
	else:
		unit.movement.clear_target()
		unit.snap_facing(cast_point - unit.global_position)
	order = Order.CHANNEL
	_play_channel_visual(ab)
	_stop_channel_sfx()
	if ab.id == "meteor" or ab.delivery == AbilityDef.Delivery.METEOR:
		_channel_sfx = AudioManager.play_on("fire.cast", unit)
	elif ab.element == AbilityDef.Element.FIRE:
		_channel_sfx = AudioManager.play_on("fire.cast", unit, {"from_end": _channel_duration(ab)})
	elif ab.delivery == AbilityDef.Delivery.RAY:
		_channel_sfx = AudioManager.play_on("thunder_wave.cast", unit)
	elif ab.delivery == AbilityDef.Delivery.MISSILES or ab.element == AbilityDef.Element.STORM:
		_channel_sfx = AudioManager.play_on("thunder_wave.cast", unit)


func confirm_channel() -> void:
	if not is_channeling():
		return
	var idx := cast_index
	var point := cast_point
	var charge := channel_charge()
	var ab := casting_ability()
	cast_index = -1
	_stop_channel_sfx()
	_clear_ray_steer()
	_play_spell_release(ab)
	unit.finish_channeled_ability(idx, point, charge)
	_resume_after_cast()
	_flush_cast_queue()


func cancel_channel() -> void:
	_interrupt_channel()


func cancel_cast() -> bool:
	var cancelled := false
	if is_channeling():
		_interrupt_channel()
		cancelled = true
	elif order == Order.CAST and cast_index >= 0:
		_stop_cast_sfx()
		_cancel_spell_visual()
		cast_index = -1
		cast_target = null
		_cast_elapsed = 0.0
		_gcd_started = false
		_clear_ray_steer()
		_resume_after_cast()
		cancelled = true
	if _queued_index >= 0:
		_clear_cast_queue()
		cancelled = true
	return cancelled


func _interrupt_channel() -> void:
	if not is_channeling():
		return
	var idx := cast_index
	var ab := casting_ability()
	cast_index = -1
	order = Order.IDLE
	_stop_channel_sfx()
	_clear_cast_queue()
	_clear_ray_steer()
	_cancel_spell_visual()
	var recast := unit._channel_was_recast
	unit.end_channel_cast(idx)
	if recast:
		return
	if _defers_channel_cooldown(ab):
		unit.apply_cooldown(idx, 1.0)
		unit.trigger_global_cooldown(idx)
	else:
		unit.apply_cooldown(idx, 0.25)
	_resume_after_cast()


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
	_halt_move = false
	_clear_pending_move()
	if is_channeling():
		_clear_cast_queue()
		return
	_interrupt_channel()
	_stop_cast_sfx()
	_cancel_spell_visual()
	_clear_cast_queue()
	order = Order.IDLE
	attack_target = null
	cast_index = -1
	cast_target = null
	unit.auto_attack.cancel()
	unit.movement.clear_target()


func stop_movement() -> void:
	if order == Order.CAST or order == Order.CHANNEL:
		_halt_move = true
		_clear_pending_move()
		_clear_cast_queue()
		unit.auto_attack.cancel()
		unit.movement.clear_target()
		return
	stop_now()


func _resume_after_cast() -> void:
	if unit != null and unit.movement != null and unit.movement.has_target:
		order = Order.MOVE
		move_to = unit.movement.goal
		_clear_pending_move()
		return
	if _has_pending_move and not _halt_move:
		order = Order.MOVE
		move_to = _pending_move
		unit.movement.set_target(_pending_move, 0.12)
		_clear_pending_move()
		return
	order = Order.IDLE
	_clear_pending_move()


func _stash_move() -> void:
	if _has_pending_move or _halt_move:
		return
	if unit != null and unit.movement != null and unit.movement.has_target:
		_pending_move = unit.movement.goal
		_has_pending_move = true
		return
	if order == Order.MOVE:
		_pending_move = move_to
		_has_pending_move = true


func _lockout_time(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	var t := ab.cast_time
	if ab.is_channel:
		t += ab.channel_time
	if unit != null:
		return t * unit.cast_time_scale()
	return t


func _retains_move_memory(ab: AbilityDef) -> bool:
	if ab == null or ab.move_while_casting:
		return false
	return _lockout_time(ab) < MOVE_MEMORY_CAST_LIMIT


func _apply_cast_move_memory(ab: AbilityDef) -> void:
	if ab != null and ab.move_while_casting:
		return
	if _retains_move_memory(ab):
		_stash_move()
		return
	_clear_pending_move()


func _clear_pending_move() -> void:
	_has_pending_move = false


func _keep_cast_and_move(pos: Vector3) -> bool:
	if order != Order.CAST and order != Order.CHANNEL:
		return false
	var ab := casting_ability()
	if ab == null or not ab.move_while_casting:
		return false
	_halt_move = false
	move_to = pos
	unit.movement.set_target(pos, 0.12)
	return true


func issue_move_local(pos: Vector3) -> void:
	cmd_move(pos)


func issue_move_hold(pos: Vector3) -> void:
	retarget_move(pos)


func issue_attack_local(target: Unit) -> void:
	cmd_attack(target)


func issue_attack_move_local(pos: Vector3) -> void:
	cmd_attack_move(pos)


func issue_stop_local() -> void:
	stop_movement()


func issue_cast_local(index: int, point: Vector3, target: Unit = null) -> void:
	cmd_cast(index, point, target)


func issue_dodge(dir: Vector3) -> void:
	if unit == null or not unit.try_dodge(dir):
		return
	_interrupt_channel()
	_stop_cast_sfx()
	_clear_ray_steer()
	unit.auto_attack.cancel()
	if order == Order.CAST or order == Order.CHANNEL:
		order = Order.IDLE
		cast_index = -1
		cast_target = null
		_cast_elapsed = 0.0
		_gcd_started = false
		_cancel_spell_visual()


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
			_stop_cast_sfx()
			_cancel_spell_visual()
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
	## A started windup is committed: stand, finish the clip, and fire even if
	## the target walks out. Move orders still cancel via cmd_move.
	if unit.auto_attack.winding:
		unit.movement.has_target = false
		unit.movement.tick(delta, false, to_target)
		unit.auto_attack.tick(delta)
		return
	if unit.in_range_of(attack_target) and unit.movement.has_line_of_sight(attack_target, unit.is_melee):
		unit.movement.has_target = false
		unit.movement.tick(delta, false, to_target)
		unit.auto_attack.try_start(attack_target)
		unit.auto_attack.tick(delta)
	else:
		unit.auto_attack.cancel()
		var chase := attack_target.global_position
		var drift := 0.35 if unit.is_boss else 0.5
		if unit.movement.goal.distance_squared_to(chase) > drift * drift:
			unit.movement.set_target(chase, drift)
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


func is_busy() -> bool:
	return order == Order.CAST or order == Order.CHANNEL


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
	var ab := casting_ability()
	if ab != null and unit != null:
		var extra := TalentCombat.consume_afterburn(unit, ab)
		if extra > 0.0:
			_cast_time_scale = clampf(_cast_time_scale * (1.0 - extra), 0.15, 1.0)


func _channel_duration(ab: AbilityDef) -> float:
	if SpellWallLayout.is_protection(ab):
		return maxf(ab.channel_time, 0.001)
	return maxf(ab.channel_time * _cast_time_scale, 0.001)


func is_protection_hold() -> bool:
	return is_channeling() and SpellWallLayout.is_protection(casting_ability())


func is_steering_ray() -> bool:
	var ab := casting_ability()
	if ab == null or ab.delivery != AbilityDef.Delivery.RAY:
		return false
	return order == Order.CAST or order == Order.CHANNEL


func reaim_ray(point: Vector3) -> void:
	var ab := casting_ability()
	if ab == null or ab.delivery != AbilityDef.Delivery.RAY:
		return
	var want := _ray_dir_from_point(point)
	_ray_want = want
	if _ray_dir.length_squared() < 0.0001:
		_ray_dir = want
	_refresh_ray_cast_point()


func _tick_ray_steer(_delta: float) -> void:
	var ab := casting_ability()
	if ab == null or ab.delivery != AbilityDef.Delivery.RAY:
		return
	if _ray_want.length_squared() < 0.0001:
		_ray_want = unit.facing_dir()
	_ray_dir = _ray_want
	_refresh_ray_cast_point()


func _ray_dir_from_point(point: Vector3) -> Vector3:
	var origin := Vector3(unit.global_position.x, 0.0, unit.global_position.z)
	var dest := Vector3(point.x, 0.0, point.z)
	var offset := dest - origin
	if offset.length_squared() < 0.0001:
		var face := unit.facing_dir()
		return face if face.length_squared() > 0.0001 else Vector3(0.0, 0.0, 1.0)
	offset.y = 0.0
	return offset.normalized()


func _refresh_ray_cast_point() -> void:
	var ab := casting_ability()
	if ab == null or ab.delivery != AbilityDef.Delivery.RAY:
		return
	var dir := _ray_dir if _ray_dir.length_squared() > 0.0001 else _ray_want
	if dir.length_squared() < 0.0001:
		dir = unit.facing_dir()
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	_ray_dir = dir
	cast_point = unit.ray_beam_end(ab, dir)
	unit.snap_facing(dir)


func _clear_ray_steer() -> void:
	_ray_dir = Vector3.ZERO
	_ray_want = Vector3.ZERO


func channel_time_left() -> float:
	if not is_channeling():
		return 0.0
	var ab := casting_ability()
	if ab == null:
		return 0.0
	return maxf(_channel_duration(ab) - _cast_elapsed, 0.0)


func _reaim_protection(point: Vector3) -> void:
	var ab := casting_ability()
	var aim := point
	if ab != null:
		aim = unit.clamped_ground_point(point, ab.range)
	cast_point = aim
	unit.reaim_protection_wall(aim)


func _defers_channel_cooldown(ab: AbilityDef) -> bool:
	return ab != null and ab.delivery == AbilityDef.Delivery.MISSILES


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
	if is_channeling() or (order == Order.CAST and cast_index >= 0):
		return _cast_in_queue_window()
	return unit != null and unit.is_on_global_cooldown(index)


func _cast_in_queue_window() -> bool:
	return _cast_remaining() <= CAST_QUEUE_REMAINING or cast_progress() >= CAST_QUEUE_PROGRESS


func _cast_remaining() -> float:
	var ab := casting_ability()
	if ab == null:
		return 0.0
	if order == Order.CHANNEL:
		return channel_time_left()
	var windup := ab.cast_time * _cast_time_scale
	if windup <= 0.001:
		return 0.0
	return maxf(windup - _cast_elapsed, 0.0)


func _abort_cast_for_replace() -> void:
	if is_channeling():
		_interrupt_channel()
		if unit != null:
			unit.clear_global_cooldown()
		return
	if order != Order.CAST or cast_index < 0:
		return
	_stop_cast_sfx()
	_cancel_spell_visual()
	_clear_ray_steer()
	cast_index = -1
	cast_target = null
	_cast_elapsed = 0.0
	_gcd_started = false
	if unit != null:
		unit.clear_global_cooldown()


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


func _legal_unit_target(ab: AbilityDef, target: Unit) -> bool:
	if ab == null or not ab.locks_unit_target():
		return true
	return ab.accepts_unit(unit.team, target)


func _begin_cast(index: int, point: Vector3, target: Unit) -> void:
	_clear_cast_queue()
	var ab: AbilityDef = unit.abilities[index]
	if not _legal_unit_target(ab, target):
		return
	if ab.is_toggle:
		if unit.has_aura(index):
			unit.toggle_aura(index)
			return
		if not unit.can_cast(index):
			return
		unit.toggle_aura(index, target)
		return
	if not unit.can_cast(index):
		return
	if ab.is_channel:
		var skip_windup := ab.cast_time <= 0.001 or unit.has_recast_ready(index)
		if skip_windup and not _channel_needs_approach(ab, target):
			_apply_cast_move_memory(ab)
			cmd_channel(index, point, target)
			return
	if _is_instant(ab, index) and _instant_can_fire(ab, point, target):
		_fire_instant(index, point, target, ab)
		return
	order = Order.CAST
	_apply_cast_move_memory(ab)
	cast_index = index
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		cast_point = unit.clamped_ground_point(point, ab.range)
	elif ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		cast_point = unit.clamped_skillshot_point(point, ab)
	else:
		cast_point = point
	cast_target = target
	_cast_elapsed = 0.0
	_gcd_started = false
	unit.auto_attack.cancel()
	if ab.delivery == AbilityDef.Delivery.RAY:
		reaim_ray(point)
		return
	if not ab.move_while_casting:
		var aim := cast_point
		if ab.target_mode == AbilityDef.TargetMode.UNIT and target != null and is_instance_valid(target):
			aim = target.global_position
		unit.snap_facing(aim - unit.global_position)


func _channel_needs_approach(ab: AbilityDef, target: Unit) -> bool:
	if ab == null or ab.target_mode != AbilityDef.TargetMode.UNIT:
		return false
	if target == null or not is_instance_valid(target) or target.is_dead:
		return true
	if not unit.ability_in_range(ab, target.global_position, target):
		return true
	if ab.delivery == AbilityDef.Delivery.MISSILES:
		return false
	return not unit.movement.has_line_of_sight(target)


func _is_instant(ab: AbilityDef, index: int = -1) -> bool:
	if ab == null or ab.is_channel:
		return false
	if unit != null and index >= 0 and unit.has_recast_ready(index):
		return true
	return ab.cast_time <= 0.001


func _instant_can_fire(ab: AbilityDef, point: Vector3, target: Unit) -> bool:
	if ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		return true
	if ab.target_mode == AbilityDef.TargetMode.INSTANT:
		return true
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		return true
	if ab.target_mode == AbilityDef.TargetMode.UNIT:
		if not ab.accepts_unit(unit.team, target):
			return false
		if not unit.ability_in_range(ab, target.global_position, target):
			return false
		if ab.delivery == AbilityDef.Delivery.MISSILES:
			return true
		return unit.movement.has_line_of_sight(target)
	return true


func _fire_instant(index: int, point: Vector3, target: Unit, ab: AbilityDef) -> void:
	var aim := point
	if ab.target_mode == AbilityDef.TargetMode.GROUND:
		aim = unit.clamped_ground_point(point, ab.range)
	elif ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		aim = unit.clamped_skillshot_point(point, ab)
	elif ab.target_mode == AbilityDef.TargetMode.UNIT:
		aim = target.global_position
	unit.snap_facing(aim - unit.global_position)
	unit.trigger_global_cooldown(index)
	unit.cast_ability(index, aim, target)
	_play_spell_instant_visual(ab)


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
	if ab.delivery == AbilityDef.Delivery.RAY:
		_tick_ray_steer(delta)
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
		var blocked := (
			ab.target_mode == AbilityDef.TargetMode.UNIT
			and ab.delivery != AbilityDef.Delivery.MISSILES
			and not unit.movement.has_line_of_sight(cast_target)
		)
		if too_far or blocked:
			if _halt_move:
				unit.movement.clear_target()
				unit.movement.tick(delta, false)
				return
			unit.movement.set_target(aim)
			unit.movement.tick(delta, true)
			return
	if ab.is_channel and (ab.cast_time <= 0.001 or unit.has_recast_ready(cast_index)):
		cmd_channel(cast_index, aim, cast_target)
		return
	if _is_instant(ab, cast_index):
		if not _gcd_started:
			if not unit.can_cast(cast_index):
				return
			unit.trigger_global_cooldown(cast_index)
			_gcd_started = true
			_snapshot_cast_speed()
		unit.cast_ability(cast_index, aim, cast_target)
		_play_spell_instant_visual(ab)
		cast_index = -1
		cast_target = null
		_resume_after_cast()
		if not _flush_cast_queue():
			if order == Order.MOVE:
				_tick_move(delta)
			return
		if order == Order.CAST:
			_tick_cast(delta)
		elif order == Order.CHANNEL:
			_tick_channel(delta)
		return
	if ab.move_while_casting and unit.movement.has_target:
		unit.movement.tick(delta, true)
	else:
		unit.movement.has_target = false
		if ab.delivery != AbilityDef.Delivery.RAY and to.length_squared() > 0.04:
			unit.snap_facing(to)
		unit.movement.tick(delta, false)
	if not _gcd_started:
		if not unit.can_cast(cast_index):
			return
		unit.trigger_global_cooldown(cast_index)
		_gcd_started = true
		_snapshot_cast_speed()
		_start_cast_sfx(ab)
		_play_spell_load(ab, false, ab.cast_time * _cast_time_scale)
	_cast_elapsed += delta
	var windup := ab.cast_time * _cast_time_scale
	_maybe_overlap_release(ab, windup - _cast_elapsed)
	if _cast_elapsed >= windup:
		if ab.is_channel:
			_stop_cast_sfx()
			cmd_channel(cast_index, aim, cast_target)
			return
		_play_spell_release(ab)
		unit.cast_ability(cast_index, aim, cast_target)
		cast_index = -1
		cast_target = null
		_resume_after_cast()
		if not _flush_cast_queue():
			if order == Order.MOVE:
				_tick_move(delta)
			return
		if order == Order.CAST:
			_tick_cast(delta)
		elif order == Order.CHANNEL:
			_tick_channel(delta)


func _end_cast(delta: float) -> void:
	_stop_cast_sfx()
	cast_index = -1
	cast_target = null
	_clear_ray_steer()
	_resume_after_cast()
	if _flush_cast_queue():
		if order == Order.CAST:
			_tick_cast(delta)
			return
		if order == Order.CHANNEL:
			_tick_channel(delta)
			return
	if order == Order.MOVE:
		_tick_move(delta)
	else:
		unit.movement.tick(delta, false)


func _tick_channel(delta: float) -> void:
	var ab := casting_ability()
	if ab == null:
		_stop_channel_sfx()
		cast_index = -1
		_resume_after_cast()
		if order == Order.MOVE:
			_tick_move(delta)
		else:
			unit.movement.tick(delta, false)
		return
	if ab.target_mode == AbilityDef.TargetMode.UNIT:
		if cast_target == null or not is_instance_valid(cast_target) or cast_target.is_dead:
			confirm_channel()
			return
		cast_point = cast_target.global_position
	elif ab.delivery == AbilityDef.Delivery.RAY:
		_tick_ray_steer(delta)
	var to := cast_point - unit.global_position
	to.y = 0.0
	if ab.move_while_casting and unit.movement.has_target:
		unit.movement.tick(delta, true)
	else:
		if not ab.move_while_casting:
			unit.movement.clear_target()
		if ab.delivery != AbilityDef.Delivery.RAY and to.length_squared() > 0.04:
			unit.snap_facing(to)
		unit.movement.tick(delta, false)
	if ab.delivery == AbilityDef.Delivery.MISSILES or (ab.cost_per_tick and ab.delivery == AbilityDef.Delivery.RAY):
		_tick_repeat_channel(delta, ab)
	var max_t := _channel_duration(ab)
	_cast_elapsed = minf(_cast_elapsed + delta, max_t)
	if SpellAnimPolicy.queues_release_on_channel(ab):
		_maybe_overlap_release(ab, max_t - _cast_elapsed)
	if _cast_elapsed >= max_t:
		confirm_channel()


func _tick_repeat_channel(delta: float, ab: AbilityDef) -> void:
	var interval := ab.tick_interval if ab.tick_interval > 0.05 else 0.4
	interval *= _cast_time_scale
	if not _channel_ticked:
		_channel_ticked = true
		if not unit.fire_channel_tick(cast_index, cast_target):
			confirm_channel()
		return
	_channel_tick_acc += delta
	while _channel_tick_acc >= interval:
		_channel_tick_acc -= interval
		if not unit.fire_channel_tick(cast_index, cast_target):
			confirm_channel()
			return


func _enemy_in_auto_range() -> Unit:
	var best: Unit = null
	var best_d := INF
	var origin := attack_move_to
	var reach := unit.attack_range + unit.radius + 0.15
	for u in ArenaState.units_near(unit.global_position, reach, false, true):
		if u == unit:
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
