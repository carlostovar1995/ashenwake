extends Node3D

## Bolt travel body. Authored HDR gradient is left intact so bloom intensity stays.

@export var primary_color: Color = Color(0.14473142, 1.5055057, 1.5720325, 1.0)
@export var secondary_color: Color = Color(1.8247963, 0.95835364, 0.26659697, 1.0)
@export var tertiary_color: Color = Color(1.353256, 1.353256, 1.353256, 1.0)

var _sparkles: GPUParticles3D


func _ready() -> void:
	_sparkles = _find_sparkles(self)
	if _sparkles:
		_sparkles.restart()
		_sparkles.emitting = true


func _find_sparkles(node: Node) -> GPUParticles3D:
	if node is GPUParticles3D:
		return node as GPUParticles3D
	for child in node.get_children():
		var found := _find_sparkles(child)
		if found:
			return found
	return null
