extends Node

var tick: Callable


func _process(delta: float) -> void:
	if tick.is_valid():
		tick.call(delta)
