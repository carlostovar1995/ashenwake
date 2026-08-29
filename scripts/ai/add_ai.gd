class_name AddAI
extends Node

var _think: float = 0.0

@onready var unit: Unit = get_parent()


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or unit.is_dead:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.2
	var t := ArenaState.tank()
	if t == null or t.is_dead:
		t = ArenaState.nearest_enemy(unit.global_position, unit.team) as Unit
	if t:
		unit.controller.ai_attack(t)
