class_name WaveFx
extends Node3D

const _Y0 := -0.42
const _HEIGHT := 1.18
const _HALF_ANG := 1.2915


static func attach(host: Node3D, width: float, core: Color, rim: Color) -> void:
	if host == null:
		return
	var fx := new()
	host.add_child(fx)
	fx._build(maxf(width, 0.8), core, rim)


func _build(width: float, core: Color, rim: Color) -> void:
	var wall := MeshInstance3D.new()
	wall.mesh = _arc_wall(width, _HEIGHT, 0.15)
	wall.material_override = _mat(core, 0.7, 1.35)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	var edge := MeshInstance3D.new()
	edge.mesh = _arc_wall(width * 1.03, _HEIGHT + 0.08, 0.05)
	edge.material_override = _mat(rim, 0.88, 1.7)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(edge)
	var floor := MeshInstance3D.new()
	floor.mesh = _arc_floor(width, 0.22)
	floor.material_override = _mat(core, 0.2, 0.55)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor)


func _arc_wall(width: float, height: float, stroke: float) -> ArrayMesh:
	var segs := 20
	var half_w := width * 0.5
	var r := half_w / sin(_HALF_ANG)
	var z0 := r * cos(_HALF_ANG)
	var r_in := r - stroke * 0.5
	var r_out := r + stroke * 0.5
	var y1 := _Y0 + height
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := -_HALF_ANG + _HALF_ANG * 2.0 * float(i) / float(segs)
		var a1 := -_HALF_ANG + _HALF_ANG * 2.0 * float(i + 1) / float(segs)
		var i0 := _arc_point(r_in, a0, _Y0, z0)
		var i1 := _arc_point(r_in, a1, _Y0, z0)
		var o0 := _arc_point(r_out, a0, _Y0, z0)
		var o1 := _arc_point(r_out, a1, _Y0, z0)
		var i0t := _arc_point(r_in, a0, y1, z0)
		var i1t := _arc_point(r_in, a1, y1, z0)
		var o0t := _arc_point(r_out, a0, y1, z0)
		var o1t := _arc_point(r_out, a1, y1, z0)
		_quad(st, i0, o0, o1, i1)
		_quad(st, i0t, i1t, o1t, o0t)
		_quad(st, i0, i1, i1t, i0t)
		_quad(st, o0, o0t, o1t, o1)
	return st.commit()


func _arc_floor(width: float, stroke: float) -> ArrayMesh:
	var segs := 20
	var half_w := width * 0.5
	var r := half_w / sin(_HALF_ANG)
	var z0 := r * cos(_HALF_ANG)
	var r_in := r - stroke * 0.5
	var r_out := r + stroke * 0.5
	var y := _Y0 + 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var a0 := -_HALF_ANG + _HALF_ANG * 2.0 * float(i) / float(segs)
		var a1 := -_HALF_ANG + _HALF_ANG * 2.0 * float(i + 1) / float(segs)
		_quad(
			st,
			_arc_point(r_in, a0, y, z0),
			_arc_point(r_out, a0, y, z0),
			_arc_point(r_out, a1, y, z0),
			_arc_point(r_in, a1, y, z0)
		)
	return st.commit()


func _arc_point(rad: float, angle: float, y: float, z0: float) -> Vector3:
	return Vector3(rad * sin(angle), y, -(rad * cos(angle) - z0))


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


func _mat(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat
