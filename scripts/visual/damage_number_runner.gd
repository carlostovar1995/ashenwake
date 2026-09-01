extends Node

const TICK_INTERVAL := 1.0 / 60.0

var tick: Callable
var _acc: float = 0.0


func _process(delta: float) -> void:
	if not tick.is_valid():
		return
	_acc += delta
	if _acc < TICK_INTERVAL:
		return
	var step := _acc
	_acc = fmod(_acc, TICK_INTERVAL)
	tick.call(step)
