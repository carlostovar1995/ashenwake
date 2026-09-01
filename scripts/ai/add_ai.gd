class_name AddAI
extends Node

var _think: float = 0.0

@onready var unit: Unit = get_parent()


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled or unit.is_dead:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.2
	var t := ThreatTable.pick_target(unit)
	if t == null:
		return
	if unit.in_range_of(t, 0.4):
		unit.controller.ai_attack(t)
	else:
		unit.controller.ai_move(t.global_position)
