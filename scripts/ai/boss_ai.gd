class_name BossAI
extends Node

var _cycle: float = 1.2
var _index: int = 0
var _phase2: bool = false
var _adds_spawned: bool = false
var ability_name: String = ""
var ability_duration: float = 0.0
var ability_elapsed: float = 0.0
var ability_color: Color = Color(1.0, 0.72, 0.22)
var ability_interruptible: bool = true

@onready var unit: Unit = get_parent()


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled:
		return
	if unit.is_dead:
		return
	_tick_ability_display(delta)
	if not _phase2 and unit.health <= unit.max_health * 0.5:
		_enter_phase2()
	if unit.is_stunned():
		return
	var target := _pick_target()
	if target == null:
		return
	var to := target.global_position - unit.global_position
	to.y = 0.0
	if unit.in_range_of(target, 0.4):
		unit.controller.ai_attack(target)
	else:
		unit.controller.ai_move(target.global_position)
	_cycle -= delta
	if _cycle > 0.0:
		return
	_fire_ability(target)
	var rate := 0.7 if _phase2 else 1.0
	_cycle = [3.4, 5.2, 4.6][_index] * rate
	_index = (_index + 1) % 3


func _pick_target() -> Unit:
	return ThreatTable.pick_target(unit)


func _fire_ability(target: Unit) -> void:
	var forward := (target.global_position - unit.global_position).slide(Vector3.UP)
	if forward.length_squared() < 0.001:
		forward = unit.facing_dir()
	forward = forward.normalized()
	match _index:
		0:
			begin_ability("Cone Cleave", 0.85, Color(1.0, 0.55, 0.12))
			var cleave := Telegraph.cone_cleave(unit, unit.global_position, forward, 6.2, deg_to_rad(95.0), 0.85, 95.0)
			cleave.sfx_warn = "boss.telegraph.warn"
			cleave.sfx_impact = "colossus.cleave"
		1:
			begin_ability("Circle Slam", 1.35, Color(1.0, 0.4, 0.15))
			var slam_at := target.global_position
			var slam := Telegraph.circle_slam(unit, slam_at, 4.1, 1.35, 150.0)
			slam.sfx_warn = "boss.telegraph.warn"
			slam.sfx_impact = "colossus.slam"
		2:
			begin_ability("Line Breath", 1.05, Color(1.0, 0.25, 0.35))
			var breath := Telegraph.line_breath(unit, unit.global_position, forward, 18.0, 2.3, 1.05, 130.0)
			breath.sfx_warn = "boss.telegraph.warn"
			breath.sfx_impact = "colossus.breath"


func begin_ability(label: String, duration: float, color: Color = Color(1.0, 0.72, 0.22), kickable: bool = true) -> void:
	ability_name = label
	ability_duration = maxf(duration, 0.05)
	ability_elapsed = 0.0
	ability_color = color
	ability_interruptible = kickable


func is_showing_ability() -> bool:
	return ability_duration > 0.0 and ability_elapsed < ability_duration


func freeze_is_deferred() -> bool:
	return is_showing_ability() and not ability_interruptible


func remaining_ability_time() -> float:
	if not is_showing_ability():
		return 0.0
	return maxf(0.0, ability_duration - ability_elapsed)


func interrupt_current_cast() -> bool:
	if not is_showing_ability() or not ability_interruptible:
		return false
	var kicked := ArenaState.interrupt_casts_from(unit)
	_clear_ability_display()
	return kicked


func _clear_ability_display() -> void:
	ability_name = ""
	ability_duration = 0.0
	ability_elapsed = 0.0
	ability_interruptible = true


func ability_progress() -> float:
	if ability_duration <= 0.0:
		return 0.0
	return clampf(ability_elapsed / ability_duration, 0.0, 1.0)


func _tick_ability_display(delta: float) -> void:
	if ability_duration <= 0.0:
		return
	ability_elapsed += delta
	if ability_elapsed >= ability_duration:
		_clear_ability_display()


func _enter_phase2() -> void:
	_phase2 = true
	unit.move_speed += 1.1
	unit.attack_damage *= 1.15
	ArenaState.start_shrink()
	if not _adds_spawned:
		_adds_spawned = true
		if ArenaState.arena and ArenaState.arena.has_method("spawn_add"):
			ArenaState.arena.spawn_add(Vector3(-5, 0, -3))
			ArenaState.arena.spawn_add(Vector3(5, 0, -3))
