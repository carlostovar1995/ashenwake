class_name AutoAttack
extends Node

var winding: bool = false
var windup_left: float = 0.0
var cooldown_left: float = 0.0
var windup_target: Unit = null

@onready var unit: Unit = get_parent()


func cancel() -> void:
	winding = false
	windup_left = 0.0
	windup_target = null


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
		var cycle := maxf(0.12, unit.attack_cooldown)
		var wind := clampf(unit.attack_windup, 0.03, cycle * 0.4)
		cooldown_left = maxf(0.04, cycle - wind)
		var target := windup_target
		windup_target = null
		unit.fire_auto_attack(target)


func try_start(target: Unit) -> bool:
	if cooldown_left > 0.0 or winding:
		return false
	if target == null or target.is_dead:
		return false
	winding = true
	var cycle := maxf(0.12, unit.attack_cooldown)
	windup_left = clampf(unit.attack_windup, 0.03, cycle * 0.4)
	windup_target = target
	return true
