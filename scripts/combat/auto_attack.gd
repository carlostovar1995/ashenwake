class_name AutoAttack
extends Node

## League-style swing: windup is cancellable by a new move/cast order.
## Leaving range after the swing has started does not cancel — the clip
## finishes and the hit still fires. Attack delay starts after fire.

var winding: bool = false
var windup_left: float = 0.0
var cooldown_left: float = 0.0
var windup_target: Unit = null
var _played_windup: float = 0.0
var _played_cycle: float = 0.0

@onready var unit: Unit = get_parent()


func cancel() -> void:
	var was := winding
	winding = false
	windup_left = 0.0
	windup_target = null
	_played_windup = 0.0
	_played_cycle = 0.0
	if was:
		var vis := _visual()
		if vis:
			vis.cancel_auto_anim()


func tick(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if not winding:
		return
	if windup_target == null or not is_instance_valid(windup_target) or windup_target.is_dead:
		cancel()
		return
	windup_left -= delta
	if windup_left <= 0.0:
		winding = false
		cooldown_left = AutoAnimPolicy.fire_cooldown(_played_cycle, _played_windup)
		var target := windup_target
		windup_target = null
		var vis := _visual()
		if vis:
			vis.finish_auto_windup()
		unit.fire_auto_attack(target)


func try_start(target: Unit) -> bool:
	if cooldown_left > 0.0 or winding:
		return false
	if target == null or target.is_dead:
		return false
	winding = true
	_played_cycle = AutoAnimPolicy.attack_cycle(unit.attack_cooldown)
	_played_windup = AutoAnimPolicy.windup_window(unit.attack_windup, unit.attack_cooldown)
	windup_left = _played_windup
	windup_target = target
	var vis := _visual()
	if vis:
		vis.play_auto_windup(_played_windup)
	return true


func _visual() -> CharacterVisual:
	if unit == null:
		return null
	return unit.get_node_or_null("CharacterVisual") as CharacterVisual
