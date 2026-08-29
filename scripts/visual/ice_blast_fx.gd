class_name IceBlastFx
extends Node3D

const _SHADER := preload("res://scripts/visual/ice_blast.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")

var _sheet_mat: ShaderMaterial
var _light: OmniLight3D
var _wisps: GPUParticles3D
var _mist: GPUParticles3D
var _radius: float = 8.0
var _angle: float = deg_to_rad(60.0)


static func spawn(origin: Vector3, dir: Vector3, radius: float, angle: float, spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> IceBlastFx:
	var fx := IceBlastFx.new()
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(fx)
	fx.global_position = Vector3(origin.x, 0.08, origin.z)
	var look := fx.global_position + Vector3(dir.x, 0.0, dir.z)
	if look.distance_squared_to(fx.global_position) > 0.0001:
		fx.look_at(look, Vector3.UP)
	fx.setup(radius, angle, spoke_lengths)
	fx.play()
	AudioManager.play_at("freeze.blast", fx.global_position)
	return fx


static func puff_at(pos: Vector3) -> void:
	var puff := GPUParticles3D.new()
	puff.amount = 18
	puff.lifetime = 0.5
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.preprocess = 0.02
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.18, 0.55)
	puff.draw_pass_1 = mesh
	puff.process_material = _puff_process()
	puff.material_override = _wisp_mat(Color(0.9, 0.98, 1.0, 0.54))
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(puff)
	puff.global_position = pos + Vector3(0.0, 0.15, 0.0)
	AudioManager.play_at("freeze.hit", pos)
	puff.emitting = true
	puff.get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if is_instance_valid(puff):
			puff.queue_free()
	)


func setup(radius: float, angle: float, spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> void:
	_radius = radius
	_angle = angle
	_make_sheet(spoke_lengths)
	if spoke_lengths.size() > 0:
		var clipped := radius
		for v in spoke_lengths:
			clipped = minf(clipped, float(v))
		_radius = maxf(clipped, 0.6)
	_wisps = _make_particles(34, 0.6, Vector2(0.1, 0.48), Color(0.42, 0.9, 1.0, 0.54), 2.8, 0.25)
	_mist = _make_particles(22, 0.75, Vector2(0.42, 0.55), Color(0.82, 0.95, 1.0, 0.23), 0.85, 0.2)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.88, 1.0)
	_light.light_energy = 2.15
	_light.omni_range = radius * 0.9
	_light.position = Vector3(0.0, 0.55, -radius * 0.38)
	add_child(_light)


func play() -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", 0.0)
		_sheet_mat.set_shader_parameter("fade", 1.0)
	if _wisps:
		_wisps.emitting = true
	if _mist:
		_mist.emitting = true
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_method(_set_grow, 0.0, 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.48)
	tw.tween_callback(_stop_particles)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.38)
	if _light:
		tw.parallel().tween_property(_light, "light_energy", 0.0, 0.38)
	tw.chain().tween_callback(queue_free)


func _stop_particles() -> void:
	if _wisps:
		_wisps.emitting = false
	if _mist:
		_mist.emitting = false


func _set_grow(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", v)


func _set_fade(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("fade", v)


func _make_sheet(spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 1.5
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = _SHADER
	_sheet_mat.set_shader_parameter("ice_color", Color(0.38, 0.92, 1.0, 0.9))
	_sheet_mat.set_shader_parameter("crack_color", Color(0.97, 1.0, 1.0, 1.0))
	_sheet_mat.set_shader_parameter("edge_color", Color(0.14, 0.46, 0.88, 0.95))
	_sheet_mat.set_shader_parameter("grow", 0.0)
	_sheet_mat.set_shader_parameter("fade", 1.0)
	_sheet_mat.set_shader_parameter("opacity", 0.4)
	mi.material_override = _sheet_mat
	mi.mesh = _build_cone_mesh(_radius, _angle, spoke_lengths)
	add_child(mi)


func _build_cone_mesh(radius: float, angle: float, spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 28
	if spoke_lengths.size() >= 2:
		steps = spoke_lengths.size() - 1
	var half := angle * 0.5
	var origin := Vector3(0.0, 0.02, 0.0)
	for i in steps:
		var t0 := float(i) / float(steps)
		var t1 := float(i + 1) / float(steps)
		var a0 := -half + angle * t0
		var a1 := -half + angle * t1
		var r0 := spoke_lengths[i] if i < spoke_lengths.size() else radius
		var r1 := spoke_lengths[i + 1] if i + 1 < spoke_lengths.size() else radius
		var p0 := Vector3(sin(a0) * r0, 0.02, -cos(a0) * r0)
		var p1 := Vector3(sin(a1) * r1, 0.02, -cos(a1) * r1)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(origin)
		st.set_uv(Vector2(t0, 1.0))
		st.add_vertex(p0)
		st.set_uv(Vector2(t1, 1.0))
		st.add_vertex(p1)
	return st.commit()


func _make_particles(amount: int, life: float, size: Vector2, color: Color, speed: float, explosiveness: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = false
	p.explosiveness = explosiveness
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 0.1, -_radius * 0.45)
	var mesh := QuadMesh.new()
	mesh.size = size
	p.draw_pass_1 = mesh
	p.material_override = _wisp_mat(color)
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var half := _angle * 0.5
	pp.emission_shape_scale = Vector3(sin(half) * _radius * 0.38, 0.05, _radius * 0.36)
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 12.0
	pp.initial_velocity_min = speed * 0.4
	pp.initial_velocity_max = speed
	pp.gravity = Vector3(0.0, 0.25, 0.0)
	pp.damping_min = 0.5
	pp.damping_max = 1.2
	pp.scale_min = 0.75
	pp.scale_max = 1.35
	pp.scale_curve = _fade_curve()
	pp.color = color
	p.process_material = pp
	add_child(p)
	return p


static func _fade_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


static func _wisp_mat(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _WISP_SHADER
	mat.set_shader_parameter("color", color)
	return mat


static func _puff_process() -> ParticleProcessMaterial:
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_shape_scale = Vector3(0.28, 0.12, 0.28)
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 28.0
	pp.initial_velocity_min = 1.4
	pp.initial_velocity_max = 3.4
	pp.gravity = Vector3(0.0, 0.8, 0.0)
	pp.damping_min = 1.2
	pp.damping_max = 2.4
	pp.scale_min = 0.7
	pp.scale_max = 1.4
	pp.scale_curve = _fade_curve()
	pp.color = Color(0.9, 0.98, 1.0, 0.9)
	return pp
