class_name SpellRay
extends Node3D

var source: Unit
var target: Unit
var color: Color = Color(1.0, 0.82, 0.35)

var _beam: MeshInstance3D
var _mesh: BoxMesh
var _mat: StandardMaterial3D
var _glow: MeshInstance3D


static func attach(caster: Unit, victim: Unit, tint: Color) -> SpellRay:
	var ray := SpellRay.new()
	ray.source = caster
	ray.target = victim
	ray.color = tint
	var parent: Node = ArenaState.arena if ArenaState.arena else caster.get_tree().current_scene
	parent.add_child(ray)
	ray._build()
	ray._place()
	return ray


func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.72)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 4.2
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = BoxMesh.new()
	_mesh.size = Vector3(0.16, 0.16, 1.0)
	_beam = MeshInstance3D.new()
	_beam.mesh = _mesh
	_beam.material_override = _mat
	add_child(_beam)
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.38, 0.38, 1.0)
	_glow = MeshInstance3D.new()
	_glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.22)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled = true
	glow_mat.emission = color
	glow_mat.emission_energy_multiplier = 2.4
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow.material_override = glow_mat
	add_child(_glow)
	FxHeroLights.bind(self, color, 2.0, 5.5)


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if source == null or not is_instance_valid(source) or target == null or not is_instance_valid(target):
		queue_free()
		return
	var from := source.global_position + Vector3(0.0, source.height * 0.62, 0.0)
	var to := target.global_position + Vector3(0.0, target.height * 0.55, 0.0)
	var delta := to - from
	var length := delta.length()
	if length < 0.08:
		visible = false
		return
	visible = true
	global_position = from
	look_at(to, Vector3.UP)
	_mesh.size = Vector3(0.16, 0.16, length)
	_beam.position = Vector3(0.0, 0.0, -length * 0.5)
	_glow.position = _beam.position
	(_glow.mesh as BoxMesh).size = Vector3(0.38, 0.38, length)
