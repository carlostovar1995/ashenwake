class_name ClickMarker
extends Node3D

var _ring: MeshInstance3D
var _life: float = 0.0


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 0.7
	cyl.height = 0.04
	cyl.radial_segments = 24
	_ring.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.5, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = mat
	_ring.visible = false
	add_child(_ring)
	set_process(true)


func ping(pos: Vector3, color: Color) -> void:
	_ring.global_position = Vector3(pos.x, 0.08, pos.z)
	_ring.scale = Vector3.ONE
	_ring.visible = true
	_life = 0.45
	var mat := _ring.material_override as StandardMaterial3D
	if mat:
		mat.albedo_color = Color(color.r, color.g, color.b, 0.85)


func _process(delta: float) -> void:
	if _life <= 0.0:
		_ring.visible = false
		return
	_life -= delta
	var t := 1.0 - clampf(_life / 0.45, 0.0, 1.0)
	_ring.scale = Vector3.ONE * (1.0 + t * 0.8)
	var mat := _ring.material_override as StandardMaterial3D
	if mat:
		var c := mat.albedo_color
		c.a = 0.85 * (1.0 - t)
		mat.albedo_color = c
