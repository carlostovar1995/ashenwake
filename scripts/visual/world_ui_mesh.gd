class_name WorldUiMesh
extends RefCounted

const HOVER_FRAME_SHADER := preload("res://scripts/visual/hover_frame.gdshader")


static func unshaded_material(color: Color, priority: int, billboard: bool = false, emit: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mat.render_priority = priority
	if emit:
		mat.emission_enabled = true
		mat.emission = color
	return mat


static func quad(
	mesh_name: String,
	size: Vector2,
	color: Color,
	priority: int,
	billboard: bool = false,
	z: float = 0.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position.z = z
	mi.material_override = unshaded_material(color, priority, billboard)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi


static func hover_frame(
	frame_name: String,
	color: Color,
	border: float,
	billboard: bool,
	priority: int
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = frame_name
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(1, 1)
	mi.mesh = quad_mesh
	var mat := ShaderMaterial.new()
	mat.shader = HOVER_FRAME_SHADER
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("border", border)
	mat.set_shader_parameter("billboard", billboard)
	mat.render_priority = priority
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visible = false
	return mi


static func place_hover_frame(
	frame: MeshInstance3D,
	pos: Vector3,
	size: Vector2,
	shown: bool,
	color: Color,
	border: float
) -> void:
	if frame == null:
		return
	frame.visible = shown
	if not shown:
		return
	frame.position = pos
	frame.scale = Vector3(size.x, size.y, 1.0)
	var mat := frame.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_color", color)
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("border", border)
