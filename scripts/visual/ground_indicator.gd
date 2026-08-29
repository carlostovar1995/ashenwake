class_name GroundIndicator
extends RefCounted

const SHADER := preload("res://scripts/visual/ground_indicator.gdshader")
const FILL_ALPHA := 0.18
const OUTLINE_ALPHA := 0.95
const RIBBON := 0.13
const LINE_WIDTH := RIBBON * 2.0


static func outline_width() -> float:
	return GameSession.spell_hover_width


static func shader_mat(color: Color, circle: bool, size: Vector2 = Vector2.ONE) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = 8
	mat.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("fill_alpha", FILL_ALPHA)
	mat.set_shader_parameter("outline_alpha", OUTLINE_ALPHA)
	mat.set_shader_parameter("outline_width", outline_width())
	mat.set_shader_parameter("shape_mode", 0 if circle else 1)
	mat.set_shader_parameter("quad_size", size)
	return mat


static func fill_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, FILL_ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 0.85
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	mat.render_priority = 7
	return mat


static func line_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, OUTLINE_ALPHA)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.35
	mat.disable_receive_shadows = true
	mat.render_priority = 8
	return mat


static func circle_mesh() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(2, 2)
	p.orientation = PlaneMesh.FACE_Y
	return p


static func rect_mesh() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(1, 1)
	p.orientation = PlaneMesh.FACE_Y
	return p


static func prepare(mi: MeshInstance3D) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED


static func set_circle_radius(mi: MeshInstance3D, radius: float) -> void:
	if mi == null:
		return
	var r := maxf(radius, 0.05)
	mi.scale = Vector3(r, 1.0, r)
	var sh := mi.material_override as ShaderMaterial
	if sh:
		sh.set_shader_parameter("quad_size", Vector2(r, r))
		sh.set_shader_parameter("outline_width", outline_width())
		sh.set_shader_parameter("outline_alpha", OUTLINE_ALPHA)


static func even_radii(radius: float, steps: int = 20) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(steps + 1)
	for i in steps + 1:
		out[i] = radius
	return out


static func cone_fill_mesh(angle: float, lengths: PackedFloat32Array, y: float = 0.03) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(lengths.size() - 1, 1)
	var half := angle * 0.5
	var origin := Vector3(0.0, y, 0.0)
	for i in steps:
		var a0 := -half + angle * float(i) / float(steps)
		var a1 := -half + angle * float(i + 1) / float(steps)
		var r0 := lengths[i] if i < lengths.size() else 1.0
		var r1 := lengths[i + 1] if i + 1 < lengths.size() else r0
		st.add_vertex(origin)
		st.add_vertex(Vector3(sin(a0) * r0, y, -cos(a0) * r0))
		st.add_vertex(Vector3(sin(a1) * r1, y, -cos(a1) * r1))
	return st.commit()


static func cone_outline_mesh(angle: float, lengths: PackedFloat32Array, y: float = 0.045, half_w: float = -1.0) -> ArrayMesh:
	if half_w < 0.0:
		half_w = outline_width() * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if lengths.is_empty():
		return st.commit()
	var last := maxi(lengths.size() - 1, 1)
	var half := angle * 0.5
	var origin := Vector3(0.0, y, 0.0)
	var rim: PackedVector3Array = PackedVector3Array()
	for i in lengths.size():
		var a := -half + angle * float(i) / float(last)
		var r := lengths[i]
		rim.append(Vector3(sin(a) * r, y, -cos(a) * r))
	_ribbon(st, origin, rim[0], half_w)
	_ribbon(st, origin, rim[rim.size() - 1], half_w)
	for i in rim.size() - 1:
		_ribbon(st, rim[i], rim[i + 1], half_w)
	return st.commit()


static func tint_shader(mat: Material, color: Color) -> void:
	var sh := mat as ShaderMaterial
	if sh:
		sh.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
		sh.set_shader_parameter("outline_width", outline_width())
		sh.set_shader_parameter("outline_alpha", OUTLINE_ALPHA)


static func tint_standard(mat: Material, color: Color, alpha: float) -> void:
	var sm := mat as StandardMaterial3D
	if sm:
		sm.albedo_color = Color(color.r, color.g, color.b, alpha)
		if sm.emission_enabled:
			sm.emission = Color(color.r, color.g, color.b)


static func _ribbon(st: SurfaceTool, a: Vector3, b: Vector3, half_w: float) -> void:
	var dir := b - a
	dir.y = 0.0
	if dir.length_squared() < 0.00001:
		return
	dir = dir.normalized()
	var n := Vector3(-dir.z, 0.0, dir.x) * half_w
	var a0 := a - n
	var a1 := a + n
	var b0 := b - n
	var b1 := b + n
	st.add_vertex(a0)
	st.add_vertex(b0)
	st.add_vertex(b1)
	st.add_vertex(a0)
	st.add_vertex(b1)
	st.add_vertex(a1)
