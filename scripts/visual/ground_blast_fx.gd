class_name GroundBlastFx
extends Node3D

const _SHADER := preload("res://scripts/visual/ground_blast.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const SpellBaseFx := preload("res://scripts/visual/spell_base_fx.gd")

var _sheet_mat: ShaderMaterial
var _sparks: GPUParticles3D
var _radius: float = 3.6
var _primary: Color = Color(1.0, 0.72, 0.28)
var _secondary: Color = Color(1.0, 0.38, 0.08)

static var _spark_materials: Dictionary = {}
static var _spark_processes: Dictionary = {}
static var _spark_curve_texture: CurveTexture


static func play(point: Vector3, radius: float, ab: AbilityDef) -> Node3D:
	var fx := new()
	fx._radius = maxf(radius, 0.8)
	var pal := SpellBaseFx.colors(ab)
	fx._primary = pal.primary
	fx._secondary = pal.secondary
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(fx)
	fx.global_position = Vector3(point.x, 0.07, point.z)
	fx._build()
	fx._play()
	FxHeroLights.pulse(point, fx._primary, 3.2, fx._radius * 1.6, 0.28)
	return fx


func _build() -> void:
	_make_sheet()
	_sparks = _make_sparks()


func _play() -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", 0.08)
		_sheet_mat.set_shader_parameter("fade", 1.0)
	if _sparks:
		_sparks.emitting = true
	var tw := create_tween()
	tw.tween_method(_set_grow, 0.08, 1.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _sparks:
		tw.parallel().tween_callback(_stop_sparks).set_delay(0.12)
	tw.chain().tween_callback(queue_free)


func _stop_sparks() -> void:
	if _sparks:
		_sparks.emitting = false


func _set_grow(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("grow", v)


func _set_fade(v: float) -> void:
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("fade", v)


func _make_sheet() -> void:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 1.2
	mi.mesh = GroundIndicator.circle_mesh()
	mi.scale = Vector3(_radius, 1.0, _radius)
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = _SHADER
	_sheet_mat.set_shader_parameter("core_color", _primary)
	_sheet_mat.set_shader_parameter("rim_color", _secondary)
	_sheet_mat.set_shader_parameter("grow", 0.08)
	_sheet_mat.set_shader_parameter("fade", 1.0)
	mi.material_override = _sheet_mat
	add_child(mi)


func _make_sparks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 26
	p.lifetime = 0.28
	p.one_shot = true
	p.explosiveness = 0.94
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 0.04, 0.0)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.1, 0.28)
	p.draw_pass_1 = mesh
	p.material_override = _spark_material(_primary)
	p.process_material = _spark_process(_primary, _radius)
	add_child(p)
	return p


static func _spark_material(color: Color) -> ShaderMaterial:
	var tint := Color(color.r, color.g, color.b, 0.82)
	var key := tint.to_html(true)
	var cached := _spark_materials.get(key) as ShaderMaterial
	if cached != null:
		return cached
	var material := ShaderMaterial.new()
	material.shader = _WISP_SHADER
	material.set_shader_parameter("color", tint)
	_spark_materials[key] = material
	return material


static func _spark_process(color: Color, radius: float) -> ParticleProcessMaterial:
	var ring_radius := radius * 0.55
	var key := "%s|%.3f" % [color.to_html(true), ring_radius]
	var cached := _spark_processes.get(key) as ParticleProcessMaterial
	if cached != null:
		return cached
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pp.emission_ring_axis = Vector3.UP
	pp.emission_ring_radius = ring_radius
	pp.emission_ring_inner_radius = 0.08
	pp.emission_ring_height = 0.06
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 18.0
	pp.initial_velocity_min = 2.2
	pp.initial_velocity_max = 5.2
	pp.gravity = Vector3(0.0, 1.4, 0.0)
	pp.damping_min = 1.2
	pp.damping_max = 2.6
	pp.scale_min = 0.65
	pp.scale_max = 1.2
	pp.scale_curve = _spark_curve()
	pp.color = color
	_spark_processes[key] = pp
	return pp


static func _spark_curve() -> CurveTexture:
	if _spark_curve_texture != null:
		return _spark_curve_texture
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(0.18, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_spark_curve_texture = CurveTexture.new()
	_spark_curve_texture.curve = curve
	return _spark_curve_texture
