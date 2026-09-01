class_name FireboltFx
extends Node3D

const _SHADER := preload("res://scripts/visual/firebolt_burst.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const _POOL_SIZE := 10
const _BASE_RADIUS := 3.5
const _STASH := Vector3(0.0, -80.0, 0.0)

static var _pool: Array[FireboltFx] = []
static var _steal: int = 0
static var _ember_mat: ShaderMaterial
static var _flare_mat: ShaderMaterial
static var _ember_pp: ParticleProcessMaterial
static var _flare_pp: ParticleProcessMaterial

var _sheet_mat: ShaderMaterial
var _embers: GPUParticles3D
var _flares: GPUParticles3D
var _radius: float = 3.5
var _built: bool = false
var _pooled: bool = false
var _tw: Tween


static func burst(point: Vector3, radius: float) -> Node3D:
	var fx := _acquire()
	fx._radius = maxf(radius, 1.2)
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	if fx.get_parent() != parent:
		if fx.get_parent():
			fx.get_parent().remove_child(fx)
		parent.add_child(fx)
	fx.process_mode = Node.PROCESS_MODE_INHERIT
	fx.visible = true
	fx.global_position = Vector3(point.x, 0.07, point.z)
	if not fx._built:
		fx._build()
	fx.scale = Vector3.ONE * (fx._radius / _BASE_RADIUS)
	fx._play()
	FxHeroLights.pulse(point, Color(1.0, 0.55, 0.18), 4.2, fx._radius * 2.0, 0.28)
	return fx


static func _acquire() -> FireboltFx:
	for fx in _pool:
		if is_instance_valid(fx) and not bool(fx.get_meta("fx_busy", false)):
			fx.set_meta("fx_busy", true)
			return fx
	if _pool.size() < _POOL_SIZE:
		var fresh := FireboltFx.new()
		fresh._pooled = true
		fresh.set_meta("fx_busy", true)
		_pool.append(fresh)
		return fresh
	var stolen := _pool[_steal % _pool.size()]
	_steal += 1
	if is_instance_valid(stolen):
		stolen.set_meta("fx_busy", true)
		return stolen
	var fallback := FireboltFx.new()
	fallback._pooled = true
	fallback.set_meta("fx_busy", true)
	return fallback


func _build() -> void:
	_make_sheet()
	_embers = _make_particles(36, 0.22, Vector2(0.12, 0.34), Color(1.0, 0.72, 0.22, 0.95), 5.5, true)
	_flares = _make_particles(18, 0.26, Vector2(0.22, 0.62), Color(1.0, 0.38, 0.08, 0.82), 3.4, false)
	_built = true


func _play() -> void:
	if _tw:
		_tw.kill()
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", 0.0)
		_sheet_mat.set_shader_parameter("fade", 1.0)
	if _embers:
		_embers.restart()
		_embers.emitting = true
	if _flares:
		_flares.restart()
		_flares.emitting = true
	_tw = create_tween()
	_tw.set_parallel(false)
	_tw.tween_method(_set_grow, 0.18, 1.0, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(_stop_particles)
	_tw.tween_method(_set_fade, 1.0, 0.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tw.chain().tween_callback(_finish)


func _finish() -> void:
	if _pooled:
		set_meta("fx_busy", false)
		visible = false
		global_position = _STASH
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		queue_free()


func _stop_particles() -> void:
	if _embers:
		_embers.emitting = false
	if _flares:
		_flares.emitting = false


func _set_grow(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", v)


func _set_fade(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("fade", v)


func _make_sheet() -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 1.4
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = _SHADER
	_sheet_mat.set_shader_parameter("core_color", Color(1.0, 0.95, 0.52, 1.0))
	_sheet_mat.set_shader_parameter("fire_color", Color(1.0, 0.42, 0.08, 1.0))
	_sheet_mat.set_shader_parameter("rim_color", Color(0.7, 0.07, 0.16, 0.95))
	_sheet_mat.set_shader_parameter("grow", 0.0)
	_sheet_mat.set_shader_parameter("fade", 1.0)
	mi.material_override = _sheet_mat
	mi.mesh = _disc_mesh(_BASE_RADIUS)
	add_child(mi)


func _disc_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var origin := Vector3(0.0, 0.02, 0.0)
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p0 := Vector3(cos(a0) * r, 0.02, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.02, sin(a1) * r)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(origin)
		st.set_uv(Vector2(0.5 + cos(a0) * 0.5, 0.5 + sin(a0) * 0.5))
		st.add_vertex(p0)
		st.set_uv(Vector2(0.5 + cos(a1) * 0.5, 0.5 + sin(a1) * 0.5))
		st.add_vertex(p1)
	return st.commit()


func _make_particles(amount: int, life: float, size: Vector2, color: Color, speed: float, spark: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 0.12, 0.0)
	var mesh := QuadMesh.new()
	mesh.size = size
	p.draw_pass_1 = mesh
	p.material_override = _wisp_mat(color, spark)
	p.process_material = _process_for(spark, speed, color)
	add_child(p)
	return p


static func _wisp_mat(color: Color, spark: bool) -> ShaderMaterial:
	if spark:
		if _ember_mat == null:
			_ember_mat = ShaderMaterial.new()
			_ember_mat.shader = _WISP_SHADER
			_ember_mat.set_shader_parameter("color", color)
		return _ember_mat
	if _flare_mat == null:
		_flare_mat = ShaderMaterial.new()
		_flare_mat.shader = _WISP_SHADER
		_flare_mat.set_shader_parameter("color", color)
	return _flare_mat


static func _process_for(spark: bool, speed: float, color: Color) -> ParticleProcessMaterial:
	if spark:
		if _ember_pp == null:
			_ember_pp = _make_process(true, speed, color)
		return _ember_pp
	if _flare_pp == null:
		_flare_pp = _make_process(false, speed, color)
	return _flare_pp


static func _make_process(spark: bool, speed: float, color: Color) -> ParticleProcessMaterial:
	var pp := ParticleProcessMaterial.new()
	if spark:
		pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pp.emission_ring_axis = Vector3.UP
	pp.emission_ring_radius = _BASE_RADIUS * 0.22
	pp.emission_ring_inner_radius = 0.06
	pp.emission_ring_height = 0.1
	pp.emission_shape_scale = Vector3.ONE
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 72.0 if spark else 28.0
	pp.initial_velocity_min = speed * 0.45
	pp.initial_velocity_max = speed
	pp.gravity = Vector3(0.0, 1.8 if spark else 0.35, 0.0)
	pp.damping_min = 0.8
	pp.damping_max = 2.2
	pp.scale_min = 0.7
	pp.scale_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.16, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	pp.scale_curve = tex
	pp.color = color
	return pp
