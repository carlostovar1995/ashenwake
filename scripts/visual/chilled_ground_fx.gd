class_name ChilledGroundZone
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const _SHADER := preload("res://scripts/visual/chilled_ground.gdshader")
const _MIST_SHADER := preload("res://scripts/visual/chilled_mist.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")

const HASTE_PERCENT := 0.30
const HASTE_REFRESH := 0.12
const DRAW_PRIORITY := 4
const MAX_OPACITY := 0.20
const FILL_ALPHA := 0.12
const FROST_OPACITY := 0.08
const RING_FILL := 0.0

static var _disc_tex: Texture2D

var source: Unit
var radius: float = 5.0
var duration: float = 8.0
var tick_interval: float = 0.25
var tick_damage: float = 6.25
var element: int = AbilityDef.Element.ICE
var extras: PackedInt32Array = PackedInt32Array()
var overheat_cast_id: int = -1
var infusion_double: int = 0
var ability_id: String = "chilled_ground"

var _elapsed: float = 0.0
var _tick_acc: float = 0.0
var _ticks: int = 0
var _max_ticks: int = 32
var _chill_granted: Dictionary = {}
var _fill_mat: StandardMaterial3D
var _ring_mat: ShaderMaterial
var _sheet_mat: ShaderMaterial
var _light: OmniLight3D
var _mist: GPUParticles3D
var _spark: GPUParticles3D
var _closing: bool = false
var _loop_sfx: int = 0


static func spawn(caster: Unit, point: Vector3, p_radius: float, p_duration: float, p_interval: float, p_damage: float, p_element: int, p_extras: PackedInt32Array, p_overheat_cast_id: int = -1, p_infusion_double: int = 0, p_ability_id: String = "chilled_ground") -> ChilledGroundZone:
	var z := ChilledGroundZone.new()
	z.source = caster
	z.radius = p_radius
	z.duration = p_duration
	z.tick_interval = maxf(p_interval, 0.05)
	z.tick_damage = p_damage
	z.element = p_element
	z.extras = p_extras
	z.overheat_cast_id = p_overheat_cast_id
	z.infusion_double = p_infusion_double
	z.ability_id = p_ability_id if not p_ability_id.is_empty() else "chilled_ground"
	z._max_ticks = maxi(int(round(p_duration / z.tick_interval)), 1)
	z.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(z)
	z.global_position = Vector3(point.x, 0.10, point.z)
	z.reset_physics_interpolation()
	z._build()
	AudioManager.play_at("chilled_ground.place", z.global_position)
	z._loop_sfx = AudioManager.attach_loop("chilled_ground.loop", z)
	return z


func _build() -> void:
	var ice := Color(0.42, 0.86, 1.0)

	var fill := MeshInstance3D.new()
	fill.mesh = GroundIndicator.circle_mesh()
	fill.scale = Vector3(radius, 1.0, radius)
	fill.extra_cull_margin = 16.0
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.albedo_texture = _circle_texture()
	_fill_mat.albedo_color = Color(1.0, 1.0, 1.0, FILL_ALPHA)
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill_mat.no_depth_test = false
	_fill_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_fill_mat.disable_receive_shadows = true
	_fill_mat.emission_enabled = true
	_fill_mat.emission = ice
	_fill_mat.emission_energy_multiplier = 1.15
	_fill_mat.render_priority = DRAW_PRIORITY
	fill.material_override = _fill_mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	fill.sorting_offset = 3.0
	add_child(fill)

	var ring := MeshInstance3D.new()
	ring.mesh = GroundIndicator.circle_mesh()
	ring.position.y = 0.012
	ring.extra_cull_margin = 16.0
	_ring_mat = GroundIndicator.shader_mat(ice, true, Vector2(radius, radius))
	_ring_mat.render_priority = DRAW_PRIORITY
	_ring_mat.set_shader_parameter("fill_alpha", RING_FILL)
	_ring_mat.set_shader_parameter("outline_alpha", MAX_OPACITY)
	ring.material_override = _ring_mat
	GroundIndicator.prepare(ring)
	GroundIndicator.set_circle_radius(ring, radius)
	ring.sorting_offset = 3.2
	add_child(ring)

	var frost := MeshInstance3D.new()
	frost.mesh = GroundIndicator.circle_mesh()
	frost.scale = Vector3(radius, 1.0, radius)
	frost.position.y = 0.02
	frost.extra_cull_margin = 16.0
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = _SHADER
	_sheet_mat.render_priority = DRAW_PRIORITY
	_sheet_mat.set_shader_parameter("fade", 1.0)
	_sheet_mat.set_shader_parameter("opacity", FROST_OPACITY)
	frost.material_override = _sheet_mat
	frost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frost.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	frost.sorting_offset = 3.4
	add_child(frost)

	_mist = _make_particles(22, 1.4, Vector2(1.15, 0.55), Color(0.82, 0.93, 1.0, 0.10), 0.35, false)
	_spark = _make_particles(16, 0.9, Vector2(0.08, 0.22), Color(0.55, 0.9, 1.0, MAX_OPACITY), 0.85, true)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.45, 0.82, 1.0)
	_light.light_energy = 1.65
	_light.omni_range = radius * 1.25
	_light.position = Vector3(0.0, 0.7, 0.0)
	add_child(_light)


static func _circle_texture() -> Texture2D:
	if _disc_tex:
		return _disc_tex
	const S := 256
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var mid := (S - 1) * 0.5
	for y in S:
		for x in S:
			var dx := (float(x) - mid) / mid
			var dy := (float(y) - mid) / mid
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var inner := 1.0 - d
			var rim := smoothstep(0.78, 0.90, d) * (1.0 - smoothstep(0.96, 1.0, d))
			var a := (0.55 + inner * 0.28 + rim * 0.4) * (1.0 - smoothstep(0.92, 1.0, d))
			var col := Color(0.38 + inner * 0.28, 0.72 + inner * 0.22, 1.0, a)
			img.set_pixel(x, y, col)
	_disc_tex = ImageTexture.create_from_image(img)
	return _disc_tex


func _physics_process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	if source == null or not is_instance_valid(source) or source.is_dead:
		_close()
		return
	_tick_acc += delta
	while _ticks < _max_ticks and (_ticks == 0 or _tick_acc >= tick_interval):
		if _ticks > 0:
			_tick_acc -= tick_interval
		_pulse()
		_ticks += 1
	_refresh_haste()
	if _elapsed >= duration:
		_close()


func _pulse() -> void:
	if source == null or not is_instance_valid(source):
		return
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == source.team:
			continue
		var to := u.global_position - global_position
		to.y = 0.0
		if to.length() > radius + u.radius:
			continue
		if not _has_los(u):
			continue
		var id := u.get_instance_id()
		var first_contact := not _chill_granted.has(id)
		if first_contact:
			_chill_granted[id] = true
		u.receive_ability_hit(source, element, tick_damage, 0.0, extras, true, first_contact, true, overheat_cast_id, infusion_double, ability_id)


func _contains(u: Unit) -> bool:
	if u == null or not is_instance_valid(u) or u.is_dead:
		return false
	var to := u.global_position - global_position
	to.y = 0.0
	return to.length() <= radius + u.radius


func _refresh_haste() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		return
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != source.team:
			continue
		if not _contains(u):
			continue
		u.apply_haste(HASTE_PERCENT, HASTE_REFRESH)


func _has_los(u: Unit) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return true
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(u.get_rid())
	return arena.spell_has_los(global_position, u.global_position, exclude)


func _close() -> void:
	if _closing:
		return
	_closing = true
	AudioManager.stop_loop(_loop_sfx, 0.4)
	_loop_sfx = 0
	if _mist:
		_mist.emitting = false
	if _spark:
		_spark.emitting = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.4)
	if _light:
		tw.tween_property(_light, "light_energy", 0.0, 0.4)
	tw.chain().tween_callback(queue_free)


func _set_fade(v: float) -> void:
	if _fill_mat:
		_fill_mat.albedo_color.a = FILL_ALPHA * v
		_fill_mat.emission_energy_multiplier = 1.15 * v
	if _ring_mat:
		_ring_mat.set_shader_parameter("fill_alpha", RING_FILL * v)
		_ring_mat.set_shader_parameter("outline_alpha", MAX_OPACITY * v)
	if _sheet_mat:
		_sheet_mat.set_shader_parameter("fade", v)


func _make_particles(amount: int, life: float, size: Vector2, color: Color, speed: float, spark: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = false
	p.explosiveness = 0.05
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.sorting_offset = 3.0
	p.position = Vector3(0.0, 0.28, 0.0)
	var mesh := QuadMesh.new()
	mesh.size = size
	p.draw_pass_1 = mesh
	var smat := ShaderMaterial.new()
	smat.shader = _WISP_SHADER if spark else _MIST_SHADER
	smat.render_priority = DRAW_PRIORITY
	smat.set_shader_parameter("color", color)
	p.material_override = smat
	var pp := ParticleProcessMaterial.new()
	if spark:
		pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_shape_scale = Vector3(radius * 0.78, 0.08, radius * 0.78)
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 18.0 if spark else 8.0
	pp.initial_velocity_min = speed * 0.25
	pp.initial_velocity_max = speed
	pp.gravity = Vector3(0.0, 0.12 if spark else -0.05, 0.0)
	pp.damping_min = 0.2
	pp.damping_max = 0.6
	pp.scale_min = 0.7
	pp.scale_max = 1.35
	pp.color = color
	p.process_material = pp
	add_child(p)
	return p
