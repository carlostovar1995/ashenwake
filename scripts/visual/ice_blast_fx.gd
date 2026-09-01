class_name IceBlastFx
extends Node3D

const _SHADER := preload("res://scripts/visual/ice_blast.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const _CRYSTAL_SHADER := preload("res://scripts/visual/ice_crystal.gdshader")
const _HeroLights := preload("res://scripts/visual/fx_hero_lights.gd")

var _sheet_mat: ShaderMaterial
var _crystal_mat: ShaderMaterial
var _glow_mat: StandardMaterial3D
var _wisps: GPUParticles3D
var _mist: GPUParticles3D
var _shards: GPUParticles3D
var _crystals: Array[Node3D] = []
var _crystal_scales: PackedFloat32Array = PackedFloat32Array()
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
	AudioManager.play_at("freeze.hit", pos)


static func _free_if_valid(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func setup(radius: float, angle: float, spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> void:
	_radius = radius
	_angle = angle
	_make_sheet(spoke_lengths)
	if spoke_lengths.size() > 0:
		var clipped := radius
		for v in spoke_lengths:
			clipped = minf(clipped, float(v))
		_radius = maxf(clipped, 0.6)
	_make_crystals()
	_wisps = _make_particles(40, 0.55, Vector2(0.08, 0.42), Color(0.55, 0.95, 1.0, 0.7), 3.4, 0.85)
	_mist = _make_particles(18, 0.7, Vector2(0.36, 0.48), Color(0.2, 0.95, 0.7, 0.22), 0.7, 0.35)
	_shards = _make_particles(48, 0.5, Vector2(0.09, 0.09), Color(0.75, 0.98, 1.0, 0.95), 2.8, 0.95)
	_HeroLights.pulse(global_position + Vector3(0.0, 0.7, 0.0), Color(0.55, 0.92, 1.0), 4.4, radius * 0.95, 0.55)


func play() -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", 0.0)
		_sheet_mat.set_shader_parameter("fade", 1.0)
	if _crystal_mat:
		_crystal_mat.set_shader_parameter("fade", 1.0)
	_set_crystal_grow(0.0)
	if _wisps:
		_wisps.emitting = true
	if _mist:
		_mist.emitting = true
	if _shards:
		_shards.emitting = true
	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_method(_set_grow, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_crystal_grow, 0.0, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.52)
	tw.tween_callback(_stop_particles)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.36)
	tw.chain().tween_callback(queue_free)


func _stop_particles() -> void:
	if _wisps:
		_wisps.emitting = false
	if _mist:
		_mist.emitting = false
	if _shards:
		_shards.emitting = false


func _set_grow(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", v)


func _set_fade(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("fade", v)
	if _crystal_mat:
		_crystal_mat.set_shader_parameter("fade", v)
	if _glow_mat:
		_glow_mat.albedo_color.a = 0.42 * v
		_glow_mat.emission_energy_multiplier = 2.8 * v


func _set_crystal_grow(v: float) -> void:
	for i in _crystals.size():
		var n := _crystals[i]
		if n == null or not is_instance_valid(n):
			continue
		var s := _crystal_scales[i] if i < _crystal_scales.size() else 1.0
		n.scale = Vector3(s * (0.35 + v * 0.65), s * v, s * (0.35 + v * 0.65))


func _make_sheet(spoke_lengths: PackedFloat32Array = PackedFloat32Array()) -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 1.5
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = _SHADER
	_sheet_mat.set_shader_parameter("ice_color", Color(0.55, 0.95, 1.0, 0.92))
	_sheet_mat.set_shader_parameter("crack_color", Color(1.0, 1.0, 1.0, 1.0))
	_sheet_mat.set_shader_parameter("edge_color", Color(0.12, 0.55, 0.88, 0.95))
	_sheet_mat.set_shader_parameter("grow", 0.0)
	_sheet_mat.set_shader_parameter("fade", 1.0)
	_sheet_mat.set_shader_parameter("opacity", 0.14)
	mi.material_override = _sheet_mat
	mi.mesh = _build_cone_mesh(_radius, _angle, spoke_lengths)
	add_child(mi)


func _make_crystals() -> void:
	_crystal_mat = ShaderMaterial.new()
	_crystal_mat.shader = _CRYSTAL_SHADER
	_crystal_mat.set_shader_parameter("ice_color", Color(0.52, 0.94, 1.0, 0.82))
	_crystal_mat.set_shader_parameter("core_color", Color(0.95, 1.0, 1.0, 1.0))
	_crystal_mat.set_shader_parameter("base_glow", Color(0.18, 0.96, 0.62, 1.0))
	_crystal_mat.set_shader_parameter("fade", 1.0)
	var meshes: Array[ArrayMesh] = [_spike_mesh(0), _spike_mesh(1), _spike_mesh(2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var half := _angle * 0.5
	for i in 42:
		var dist_t := pow(rng.randf(), 0.68)
		var dist := lerpf(0.45, 1.85, dist_t)
		var yaw := rng.randf_range(-half * 0.55, half * 0.55)
		yaw *= 0.3 + 0.7 * absf(yaw) / maxf(half, 0.001)
		var n := MeshInstance3D.new()
		n.mesh = meshes[i % meshes.size()]
		n.material_override = _crystal_mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.position = Vector3(sin(yaw) * dist, 0.0, -cos(yaw) * dist)
		n.rotation = Vector3(
			deg_to_rad(rng.randf_range(16.0, 34.0)),
			yaw + rng.randf_range(-0.12, 0.12),
			rng.randf_range(-0.18, 0.18)
		)
		var s := lerpf(2.15, 0.85, dist_t) * rng.randf_range(0.7, 1.15)
		if i < 8:
			s *= 1.12
		n.scale = Vector3.ZERO
		_crystals.append(n)
		_crystal_scales.append(s)
		add_child(n)
	_make_base_glow()


func _make_base_glow() -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 1.8)
	mi.mesh = q
	mi.rotation.x = -PI * 0.5
	mi.position = Vector3(0.0, 0.03, -1.05)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.albedo_color = Color(0.12, 0.95, 0.58, 0.28)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.2, 1.0, 0.62)
	_glow_mat.emission_energy_multiplier = 2.8
	mi.material_override = _glow_mat
	add_child(mi)


func _spike_mesh(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0.03, 1.85, 0.07)
	var base: Array[Vector3] = [
		Vector3(-0.17, 0.0, -0.09),
		Vector3(-0.04, 0.0, -0.19),
		Vector3(0.15, 0.0, -0.11),
		Vector3(0.18, 0.0, 0.07),
		Vector3(0.01, 0.0, 0.17),
		Vector3(-0.15, 0.0, 0.09),
	]
	if variant == 1:
		tip = Vector3(-0.05, 2.15, 0.1)
		base = [
			Vector3(-0.12, 0.0, -0.14),
			Vector3(0.06, 0.0, -0.16),
			Vector3(0.2, 0.0, -0.02),
			Vector3(0.1, 0.0, 0.14),
			Vector3(-0.1, 0.0, 0.12),
			Vector3(-0.2, 0.0, -0.02),
		]
	elif variant == 2:
		tip = Vector3(0.08, 1.55, 0.02)
		base = [
			Vector3(-0.22, 0.0, -0.06),
			Vector3(0.0, 0.0, -0.16),
			Vector3(0.2, 0.0, -0.08),
			Vector3(0.16, 0.0, 0.1),
			Vector3(-0.06, 0.0, 0.14),
			Vector3(-0.18, 0.0, 0.04),
		]
	for i in base.size():
		var a: Vector3 = base[i]
		var b: Vector3 = base[(i + 1) % base.size()]
		st.set_uv(Vector2(0.5, 1.0))
		st.add_vertex(tip)
		st.set_uv(Vector2(float(i) / float(base.size()), 0.0))
		st.add_vertex(a)
		st.set_uv(Vector2(float(i + 1) / float(base.size()), 0.0))
		st.add_vertex(b)
	var mid := Vector3.ZERO
	for p in base:
		mid += p
	mid /= float(base.size())
	for i in base.size():
		var a: Vector3 = base[i]
		var b: Vector3 = base[(i + 1) % base.size()]
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(mid)
		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(b)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


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
	p.position = Vector3(0.0, 0.18, -minf(_radius * 0.22, 1.4))
	var mesh := QuadMesh.new()
	mesh.size = size
	p.draw_pass_1 = mesh
	p.material_override = _wisp_mat(color)
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	var half := _angle * 0.5
	pp.emission_shape_scale = Vector3(sin(half) * minf(_radius * 0.22, 1.1), 0.12, minf(_radius * 0.2, 1.0))
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
