class_name DummyChase
extends Node

const THINK := 0.28
const HOLD_RANGE := 1.45

var _think: float = 0.0

@onready var unit: Unit = get_parent()


func _ready() -> void:
	_think = randf() * THINK


func _physics_process(delta: float) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	if not GameSession.fight_started:
		return
	if unit.controller == null:
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK
	var t := ArenaState.champion
	if t == null or not is_instance_valid(t) or t.is_dead:
		unit.controller.ai_stop()
		return
	var dx := t.global_position.x - unit.global_position.x
	var dz := t.global_position.z - unit.global_position.z
	if dx * dx + dz * dz <= HOLD_RANGE * HOLD_RANGE:
		unit.controller.ai_stop()
		return
	unit.controller.ai_move(t.global_position)
