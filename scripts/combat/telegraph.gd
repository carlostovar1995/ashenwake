class_name Telegraph
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const _SolarCollapseFx := preload("res://scripts/visual/solar_collapse_fx.gd")
const _FIRE_SHELL := preload("res://assets/vfx/elemental/effects/dawnwarden/solar_fire_shell.gdshader")
const _FIRE_TEX := preload("res://assets/vfx/elemental/effects/dawnwarden/fire_body.png")
const _VISUAL_HZ := 20.0

static var _cover_wedge: ArrayMesh
static var _cover_wedge_edge: ArrayMesh
static var _corona_torus: TorusMesh
static var _corona_ring_mat: StandardMaterial3D
static var _corona_heat_mesh: SphereMesh
static var _corona_heat_mat: ShaderMaterial

enum Shape { CIRCLE, CONE, LINE }

var shape: Shape = Shape.CIRCLE
var radius: float = 4.0
var length: float = 12.0
var width: float = 2.0
var cone_angle: float = deg_to_rad(80.0)
var warning_time: float = 1.0
var damage: float = 100.0
var source: Unit
var elapsed: float = 0.0
var resolved: bool = false
var color: Color = Color(1.0, 0.35, 0.15, 0.55)
var hostile: bool = true
var vfx_scene: String = ""
var vfx_cfg: Dictionary = {}
var slow_percent: float = 0.0
var slow_duration: float = 0.0
var element: int = 0
var extra_elements: PackedInt32Array = PackedInt32Array()
var overheat_cast_id: int = -1
var combat_text_cast_id: int = -1
var infusion_double: int = 0
var ability_id: String = ""
var los_from_source: bool = false
var requires_cover: bool = false
var pillar_damage_ratio: float = 0.0
var inner_radius: float = 0.0
var cover_visual: bool = false
var judgment_stacks: int = 0
var pillar_flat_damage: float = 0.0
var inbound_cover: bool = false
var warn_vfx: String = ""
var warn_vfx_cfg: Dictionary = {}
var interruptible: bool = true
var sfx_warn: String = ""
var sfx_impact: String = ""
var sfx_loop: String = ""
var _sfx_loop_token: int = 0

var _mesh: MeshInstance3D
var _mat: Material
var _ring: MeshInstance3D
var _ring_mesh: TorusMesh
var _shadows: Array[MeshInstance3D] = []
var _shadow_mats: Array[StandardMaterial3D] = []
var _shadow_edges: Array[MeshInstance3D] = []
var _shadow_pillars: Array[ArenaPillar] = []
var _pull: GPUParticles3D
var _boss_light: OmniLight3D
var _warn_played: bool = false
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _wall: MeshInstance3D
var _wall_mat: StandardMaterial3D
var _rim_lights: Array[OmniLight3D] = []
var _last_outer: float = -1.0
var _shadow_edge_mats: Array[StandardMaterial3D] = []
var _wall_shadows: Array[MeshInstance3D] = []
var _wall_shadow_key: String = ""
var _outline: MeshInstance3D
var _outline_mat: StandardMaterial3D
var _heat: MeshInstance3D
var _visual_wait: float = 0.0


static func circle_slam(p_source: Unit, pos: Vector3, p_radius: float, p_time: float, p_damage: float, p_hostile: bool = true) -> Telegraph:
	var t := Telegraph.new()
	t.shape = Shape.CIRCLE
	t.source = p_source
	t.radius = p_radius
	t.warning_time = p_time
	t.damage = p_damage
	t.hostile = p_hostile
	t.ability_id = "circle_slam"
	t.color = Color(1.0, 0.4, 0.15, 0.5)
	_add(t, pos, Vector3.ZERO)
	return t


static func cone_cleave(p_source: Unit, origin: Vector3, forward: Vector3, p_radius: float, p_angle: float, p_time: float, p_damage: float) -> Telegraph:
	var t := Telegraph.new()
	t.shape = Shape.CONE
	t.source = p_source
	t.radius = p_radius
	t.cone_angle = p_angle
	t.warning_time = p_time
	t.damage = p_damage
	t.ability_id = "cone_cleave"
	t.color = Color(1.0, 0.55, 0.12, 0.5)
	_add(t, origin, forward)
	return t


static func line_breath(p_source: Unit, origin: Vector3, forward: Vector3, p_length: float, p_width: float, p_time: float, p_damage: float) -> Telegraph:
	var t := Telegraph.new()
	t.shape = Shape.LINE
	t.source = p_source
	t.length = p_length
	t.width = p_width
	t.warning_time = p_time
	t.damage = p_damage
	t.ability_id = "line_breath"
	t.color = Color(1.0, 0.25, 0.35, 0.5)
	_add(t, origin, forward)
	return t


static func solar_collapse(p_source: Unit, p_time: float, p_damage: float) -> Telegraph:
	var t := Telegraph.new()
	t.shape = Shape.CIRCLE
	t.source = p_source
	t.radius = 32.0
	t.warning_time = p_time
	t.damage = p_damage
	t.ability_id = "solar_collapse"
	t.requires_cover = true
	t.interruptible = false
	t.sfx_loop = "dawnwarden.collapse.warn"
	t.sfx_impact = "dawnwarden.collapse.impact"
	t.color = Color(1.0, 0.45, 0.08, 0.55)
	var pos := p_source.global_position if p_source else Vector3.ZERO
	_add(t, pos, Vector3.ZERO)
	return t


static func solar_corona(p_source: Unit, p_time: float, p_damage: float) -> Telegraph:
	var t := Telegraph.new()
	t.shape = Shape.CIRCLE
	t.source = p_source
	t.radius = maxf(ArenaState.arena_radius, 28.0)
	t.inner_radius = CombatBalance.flat("dawnwarden.corona.inner")
	t.warning_time = p_time
	t.damage = p_damage
	t.ability_id = "solar_corona"
	t.interruptible = false
	t.sfx_loop = "dawnwarden.collapse.warn"
	t.sfx_impact = "dawnwarden.collapse.impact"
	t.warn_vfx = AbilityFx.FIRE_CAST
	t.warn_vfx_cfg = {"scale": 1.15, "lifetime": 0.85}
	t.color = Color(1.0, 0.28, 0.06, 0.62)
	_add(t, Vector3.ZERO, Vector3.ZERO)
	return t


static func _add(t: Telegraph, pos: Vector3, forward: Vector3) -> void:
	var parent: Node = ArenaState.arena if ArenaState.arena else t.source.get_tree().current_scene
	parent.add_child(t)
	t.global_position = Vector3(pos.x, 0.04, pos.z)
	if forward.length_squared() > 0.0001:
		forward.y = 0.0
		t.look_at(t.global_position + forward.normalized(), Vector3.UP)
	if t.hostile:
		ArenaState.add_telegraph(t)


func _ready() -> void:
	_build_visual()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	GroundIndicator.prepare(_mesh)
	add_child(_mesh)
	if ability_id == "solar_collapse":
		_mesh.visible = false
		return
	match shape:
		Shape.CIRCLE:
			if cover_visual:
				_mat = GroundIndicator.shader_mat(color, true, Vector2(2.0, 2.0))
				_mesh.mesh = GroundIndicator.circle_mesh()
				_mesh.material_override = _mat
				GroundIndicator.set_circle_radius(_mesh, 2.0)
				_mesh.position.y = 0.05
				_build_collapse_visual()
			else:
				_mat = GroundIndicator.shader_mat(color, true, Vector2(radius, radius))
				_mesh.mesh = GroundIndicator.circle_mesh()
				_mesh.material_override = _mat
				GroundIndicator.set_circle_radius(_mesh, radius)
				_mesh.position.y = 0.05
				if inner_radius > 0.05:
					GroundIndicator.set_inner_hole(_mat, inner_radius, radius)
					_build_corona_visual()
		Shape.LINE:
			_mat = GroundIndicator.shader_mat(color, false, Vector2(width, length))
			_mesh.mesh = GroundIndicator.rect_mesh()
			_mesh.material_override = _mat
			_mesh.scale = Vector3(width, 1.0, length)
			_mesh.position = Vector3(0, 0.05, -length * 0.5)
		Shape.CONE:
			_mat = GroundIndicator.fill_mat(color)
			_mesh.mesh = GroundIndicator.cone_fill_mesh(cone_angle, GroundIndicator.even_radii(radius, 16))
			_mesh.material_override = _mat
			_outline_mat = GroundIndicator.line_mat(color)
			_outline = MeshInstance3D.new()
			_outline.mesh = GroundIndicator.cone_outline_mesh(cone_angle, GroundIndicator.even_radii(radius, 16))
			_outline.material_override = _outline_mat
			GroundIndicator.prepare(_outline)
			add_child(_outline)


func _build_corona_visual() -> void:
	var hole := maxf(inner_radius, 0.8)
	_fill = MeshInstance3D.new()
	GroundIndicator.prepare(_fill)
	var safe_mat := GroundIndicator.shader_mat(Color(1.0, 0.86, 0.32, 1.0), true, Vector2(hole, hole))
	_fill.mesh = GroundIndicator.circle_mesh()
	_fill.material_override = safe_mat
	GroundIndicator.set_circle_radius(_fill, hole)
	safe_mat.set_shader_parameter("fill_alpha", 0.07)
	safe_mat.set_shader_parameter("outline_alpha", 0.95)
	safe_mat.set_shader_parameter("emission_strength", 1.35)
	_fill.position.y = 0.06
	add_child(_fill)
	_ensure_corona_res()
	_corona_torus.inner_radius = maxf(hole - 0.18, 0.4)
	_corona_torus.outer_radius = hole + 0.16
	_ring = MeshInstance3D.new()
	_ring.mesh = _corona_torus
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.18
	_ring.material_override = _corona_ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_ring.scale = Vector3.ONE
	_corona_ring_mat.emission_energy_multiplier = 5.5
	add_child(_ring)
	_heat = MeshInstance3D.new()
	_heat.mesh = _corona_heat_mesh
	_heat.material_override = _corona_heat_mat
	_heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_heat.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_heat.top_level = true
	add_child(_heat)
	FxHeroLights.bind(self, Color(1.0, 0.45, 0.12), 1.6, 7.0)


static func _ensure_corona_res() -> void:
	if _corona_torus == null:
		_corona_torus = TorusMesh.new()
		_corona_torus.rings = 6
		_corona_torus.ring_segments = 24
	if _corona_ring_mat == null:
		_corona_ring_mat = StandardMaterial3D.new()
		_corona_ring_mat.albedo_color = Color(1.0, 0.84, 0.28, 0.92)
		_corona_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_corona_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_corona_ring_mat.emission_enabled = true
		_corona_ring_mat.emission = Color(1.0, 0.72, 0.18)
		_corona_ring_mat.emission_energy_multiplier = 5.5
		_corona_ring_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_corona_ring_mat.disable_receive_shadows = true
	if _corona_heat_mesh == null:
		_corona_heat_mesh = SphereMesh.new()
		_corona_heat_mesh.radius = 1.15
		_corona_heat_mesh.height = 2.3
		_corona_heat_mesh.radial_segments = 12
		_corona_heat_mesh.rings = 8
	if _corona_heat_mat == null:
		_corona_heat_mat = ShaderMaterial.new()
		_corona_heat_mat.shader = _FIRE_SHELL
		_corona_heat_mat.set_shader_parameter("fade_alpha", 1.0)
		_corona_heat_mat.set_shader_parameter("fire_tex", _FIRE_TEX)


func _build_collapse_visual() -> void:
	_ensure_cover_wedges()
	_wall = MeshInstance3D.new()
	_wall_mat = StandardMaterial3D.new()
	_wall_mat.albedo_color = Color(1.0, 0.48, 0.08, 0.72)
	_wall_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_mat.emission_enabled = true
	_wall_mat.emission = Color(1.0, 0.42, 0.05)
	_wall_mat.emission_energy_multiplier = 6.5
	_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall.material_override = _wall_mat
	_wall.mesh = _make_tube_mesh(1.0, 1.0)
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.72
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 12
	_ring_mesh.ring_segments = 64
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	_ring.rotation_degrees.x = 90.0
	_ring.position.y = 0.22
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.82, 0.28, 0.95)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.7, 0.15)
	ring_mat.emission_energy_multiplier = 7.5
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring.material_override = ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_build_pull_particles()
	_build_pillar_shadows()
	_sync_wall_shadows()
	call_deferred("_spawn_rim_heat")
	FxHeroLights.bind(self, Color(1.0, 0.55, 0.15), 2.4, 16.0)


func _build_pull_particles() -> void:
	_pull = GPUParticles3D.new()
	_pull.amount = 48
	_pull.lifetime = 1.4
	_pull.preprocess = 0.25
	_pull.visibility_aabb = AABB(Vector3(-32, -2, -32), Vector3(64, 10, 64))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.4
	pm.emission_ring_inner_radius = 0.4
	pm.emission_ring_height = 0.6
	pm.direction = Vector3(0, 0.2, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 2.4
	pm.initial_velocity_max = 5.5
	pm.radial_accel_min = 10.0
	pm.radial_accel_max = 18.0
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.35
	pm.scale_max = 0.7
	pm.color = Color(1.0, 0.55, 0.12, 1.0)
	_pull.process_material = pm
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(1.0, 0.62, 0.14)
	ball_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_mat.emission_enabled = true
	ball_mat.emission = Color(1.0, 0.5, 0.08)
	ball_mat.emission_energy_multiplier = 5.0
	ball.material = ball_mat
	_pull.draw_pass_1 = ball
	_pull.position.y = 0.55
	_pull.emitting = true
	add_child(_pull)


func _build_pillar_shadows() -> void:
	if not _shadows.is_empty():
		return
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	for pillar in arena.living_pillars():
		var mi := MeshInstance3D.new()
		mi.mesh = _cover_wedge
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.02, 0.04, 0.12, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_shadows.append(mi)
		_shadow_mats.append(mat)
		_shadow_pillars.append(pillar)
		var edge := MeshInstance3D.new()
		edge.mesh = _cover_wedge_edge
		var edge_mat := StandardMaterial3D.new()
		edge_mat.albedo_color = Color(1.0, 0.78, 0.28, 0.08)
		edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		edge_mat.emission_enabled = true
		edge_mat.emission = Color(1.0, 0.62, 0.12)
		edge_mat.emission_energy_multiplier = 1.2
		edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		edge.material_override = edge_mat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(edge)
		_shadow_edges.append(edge)
		_shadow_edge_mats.append(edge_mat)
	_orient_pillar_shadows()


func _sync_wall_shadows() -> void:
	if not cover_visual:
		return
	var key := ""
	var walls: Array[SpellWall] = []
	for wall in SpellWall.living_walls():
		if not wall.is_cover_solid():
			continue
		walls.append(wall)
		key += "%d," % wall.get_instance_id()
	if key != _wall_shadow_key:
		_wall_shadow_key = key
		for node in _wall_shadows:
			if is_instance_valid(node):
				node.queue_free()
		_wall_shadows.clear()
		for wall in walls:
			var mi := MeshInstance3D.new()
			mi.mesh = _cover_wedge
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.02, 0.04, 0.12, 1.0)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.vertex_color_use_as_albedo = true
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_wall_shadows.append(mi)
			var edge := MeshInstance3D.new()
			edge.mesh = _cover_wedge_edge
			var edge_mat := StandardMaterial3D.new()
			edge_mat.albedo_color = Color(1.0, 0.78, 0.28, 0.22)
			edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			edge_mat.emission_enabled = true
			edge_mat.emission = Color(1.0, 0.62, 0.12)
			edge_mat.emission_energy_multiplier = 1.2
			edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			edge.material_override = edge_mat
			edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(edge)
			_wall_shadows.append(edge)
	_orient_wall_shadows(walls)


func _light_origin() -> Vector3:
	if source != null and is_instance_valid(source):
		return source.global_position
	return global_position


func _orient_cover_wedge(mi: MeshInstance3D, origin: Vector3, half_xz: float, length: float, y: float) -> void:
	if mi == null:
		return
	var light := _light_origin()
	var p := Vector3(origin.x, y, origin.z)
	var away := Vector3(p.x - light.x, 0.0, p.z - light.z)
	if away.length_squared() < 0.04:
		away = Vector3(0.0, 0.0, 1.0)
	else:
		away = away.normalized()
	var start := p + away * (half_xz + 0.08)
	mi.scale = Vector3.ONE
	mi.global_position = start
	var look := start + away
	if Vector2(look.x - start.x, look.z - start.z).length_squared() > 0.0001:
		mi.look_at(Vector3(look.x, start.y, look.z), Vector3.UP)
	mi.scale = Vector3(half_xz * 2.2 + 0.55, 1.0, length)


func _orient_pillar_shadows() -> void:
	for i in _shadows.size():
		var pillar := _shadow_pillars[i] if i < _shadow_pillars.size() else null
		var living := pillar != null and is_instance_valid(pillar) and pillar.living
		var fill := _shadows[i]
		var edge := _shadow_edges[i] if i < _shadow_edges.size() else null
		if fill:
			fill.visible = living
		if edge:
			edge.visible = living
		if not living:
			continue
		_orient_cover_wedge(fill, pillar.global_position, pillar.half_xz(), 9.2, 0.08)
		if edge:
			_orient_cover_wedge(edge, pillar.global_position, pillar.half_xz(), 0.55, 0.11)


func _orient_wall_shadows(walls: Array[SpellWall]) -> void:
	var wi := 0
	for wall in walls:
		if wi + 1 >= _wall_shadows.size():
			break
		_orient_cover_wedge(_wall_shadows[wi], wall.global_position, wall.cover_half(), 9.2, 0.08)
		_orient_cover_wedge(_wall_shadows[wi + 1], wall.global_position, wall.cover_half(), 0.55, 0.11)
		wi += 2


static func _ensure_cover_wedges() -> void:
	if _cover_wedge != null and _cover_wedge_edge != null:
		return
	_cover_wedge = _unit_wedge_mesh(1.0, 1.18, true)
	_cover_wedge_edge = _unit_wedge_mesh(1.0, 1.0, false)


static func _unit_wedge_mesh(end_scale: float, taper: float, fade: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := 0.5
	var a := Vector3(-half, 0.0, 0.0)
	var b := Vector3(half, 0.0, 0.0)
	var c := Vector3(half * taper, 0.0, -end_scale)
	var d := Vector3(-half * taper, 0.0, -end_scale)
	if fade:
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(a)
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(b)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(c)
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(a)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(c)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(d)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(d)
	return st.commit()


func _make_tube_mesh(radius: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 40
	var y0 := 0.04
	var y1 := height
	radius = maxf(radius, 0.4)
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var p0 := Vector3(cos(a0) * radius, y0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, y0, sin(a1) * radius)
		var p2 := Vector3(cos(a1) * radius, y1, sin(a1) * radius)
		var p3 := Vector3(cos(a0) * radius, y1, sin(a0) * radius)
		st.add_vertex(p0)
		st.add_vertex(p1)
		st.add_vertex(p2)
		st.add_vertex(p0)
		st.add_vertex(p2)
		st.add_vertex(p3)
	return st.commit()


func _build_rim_lights() -> void:
	for i in 4:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.58, 0.14)
		light.light_energy = 0.5
		light.omni_range = 14.0
		var angle := TAU * float(i) / 4.0 + 0.4
		light.position = Vector3(cos(angle) * 25.4, 3.0, sin(angle) * 25.4)
		add_child(light)
		_rim_lights.append(light)


func _spawn_rim_heat() -> void:
	if source:
		AbilityFx.play_at(AbilityFx.FIRE_CAST, source.global_position + Vector3(0, 1.6, 0), {
			"scale": 1.9,
			"lifetime": warning_time + 0.35,
		})


func contains_point(world: Vector3) -> bool:
	var local := to_local(world)
	local.y = 0.0
	match shape:
		Shape.CIRCLE:
			var d := Vector2(local.x, local.z).length()
			if inner_radius > 0.05:
				return d >= inner_radius and d <= radius
			return d <= radius
		Shape.LINE:
			return absf(local.x) <= width * 0.5 and local.z <= 0.0 and local.z >= -length
		Shape.CONE:
			var d := Vector2(local.x, local.z).length()
			if d > radius:
				return false
			var a := absf(atan2(local.x, -local.z))
			return a <= cone_angle * 0.5
	return false


func dodge_point(from: Vector3) -> Vector3:
	if requires_cover:
		return cover_dodge_point(from)
	match shape:
		Shape.CIRCLE:
			if inner_radius > 0.05:
				var to_from := from - global_position
				to_from.y = 0.0
				var d := to_from.length()
				if d <= inner_radius - 0.35:
					return from
				if d < 0.05:
					return global_position
				return global_position + to_from.normalized() * (inner_radius * 0.55)
			var away := from - global_position
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.RIGHT
			return global_position + away.normalized() * (radius + 2.2)
		Shape.LINE:
			var local := to_local(from)
			var side := 1.0 if local.x >= 0.0 else -1.0
			var world_side := global_transform.basis.x * side * (width * 0.5 + 2.0)
			return Vector3(from.x, 0.0, from.z) + Vector3(world_side.x, 0.0, world_side.z)
		Shape.CONE:
			# Frontal cones are escaped by moving behind the caster, not a short sidestep.
			var back := global_transform.basis.z
			back.y = 0.0
			if back.length_squared() < 0.01:
				back = Vector3(0.0, 0.0, 1.0)
			var dist := 3.2
			if source != null and is_instance_valid(source):
				dist = source.radius + 2.4
			return global_position + back.normalized() * dist
	return from


func cover_dodge_point(from: Vector3) -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return from
	var threat: Vector3 = global_position
	if source != null:
		threat = source.global_position
	var best := from
	var best_d := INF
	for pillar in arena.living_pillars():
		var dest: Vector3
		if ability_id == "solar_collapse":
			dest = _SolarCollapseFx.cover_point_for_pillar(pillar, 0.45)
			if dest == Vector3.ZERO:
				dest = arena.cover_point_behind(pillar, threat, 0.45)
		elif inbound_cover:
			dest = arena.cover_point_inward(pillar, 0.45)
		else:
			dest = arena.cover_point_behind(pillar, threat, 0.45)
		var d := Vector2(from.x - dest.x, from.z - dest.z).length()
		if d < best_d:
			best_d = d
			best = dest
	if inbound_cover:
		for wall in SpellWall.living_walls():
			if not wall.is_cover_solid():
				continue
			var wall_dest := arena.cover_point_inward_at(wall.global_position, wall.cover_half(), 0.45)
			var wall_d := Vector2(from.x - wall_dest.x, from.z - wall_dest.z).length()
			if wall_d < best_d:
				best_d = wall_d
				best = wall_dest
	return best


func _play_warn_sfx() -> void:
	if sfx_warn != "":
		AudioManager.play_at(sfx_warn, global_position + Vector3(0.0, 0.9, 0.0))
	if sfx_loop != "":
		_sfx_loop_token = AudioManager.attach_loop(sfx_loop, self)


func _stop_warn_loop() -> void:
	AudioManager.stop_loop(_sfx_loop_token, 0.08)
	_sfx_loop_token = 0


func _play_warn_vfx() -> void:
	if ability_id == "solar_collapse":
		_SolarCollapseFx.spawn(source)
		return
	if warn_vfx == "":
		return
	var look := Vector3.ZERO
	if shape == Shape.CONE or shape == Shape.LINE:
		look = -global_transform.basis.z
	var cfg := warn_vfx_cfg.duplicate()
	if look.length_squared() > 0.0001 and not cfg.has("look"):
		cfg["look"] = look
	AbilityFx.play_at(warn_vfx, global_position + Vector3(0, 0.9, 0), cfg)


func _process(delta: float) -> void:
	if not _warn_played:
		_warn_played = true
		_play_warn_vfx()
		_play_warn_sfx()
	elapsed += delta
	if _heat != null and is_instance_valid(_heat) and source != null and is_instance_valid(source):
		_heat.global_position = source.global_position + Vector3(0.0, 1.75, 0.0)
	if ability_id == "solar_collapse":
		_visual_wait -= delta
		if _visual_wait <= 0.0:
			_visual_wait = 1.0 / _VISUAL_HZ
			var collapse_u := clampf(elapsed / maxf(warning_time, 0.001), 0.0, 1.0)
			var collapse_arena := ArenaState.arena as Arena
			if collapse_arena:
				collapse_arena.set_solar_flare(collapse_u, true)
	else:
		_visual_wait -= delta
		if _visual_wait <= 0.0:
			_visual_wait = 1.0 / _VISUAL_HZ
			var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
			if _mat is ShaderMaterial:
				var sh := _mat as ShaderMaterial
				if cover_visual:
					sh.set_shader_parameter("fill_alpha", 0.14 + 0.12 * pulse)
					sh.set_shader_parameter("outline_alpha", 0.92)
					sh.set_shader_parameter("outline_width", GroundIndicator.LINE_WIDTH)
					sh.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
				else:
					sh.set_shader_parameter("fill_alpha", 0.16 + 0.08 * pulse)
					sh.set_shader_parameter("outline_alpha", GroundIndicator.OUTLINE_ALPHA)
					sh.set_shader_parameter("outline_width", GroundIndicator.LINE_WIDTH)
					sh.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
					if inner_radius > 0.05:
						GroundIndicator.set_inner_hole(sh, inner_radius, radius)
						sh.set_shader_parameter("fill_alpha", 0.22 + 0.10 * pulse)
			elif _mat is StandardMaterial3D:
				var sm := _mat as StandardMaterial3D
				var c := color
				c.a = 0.16 + 0.08 * pulse if elapsed < warning_time else 0.22
				sm.albedo_color = c
			if _outline_mat:
				var oc := color
				oc.a = GroundIndicator.OUTLINE_ALPHA
				_outline_mat.albedo_color = oc
	if cover_visual:
		if source != null and is_instance_valid(source):
			global_position = Vector3(source.global_position.x, 0.04, source.global_position.z)
		_sync_wall_shadows()
		_orient_pillar_shadows()
		var u := clampf(elapsed / maxf(warning_time, 0.001), 0.0, 1.0)
		var arena := ArenaState.arena as Arena
		if arena:
			arena.set_solar_flare(u, true)
		var outer := lerpf(2.2, maxf(radius, 28.0), u * u)
		GroundIndicator.set_circle_radius(_mesh, outer)
		if _ring:
			_ring.scale = Vector3(outer, 1.0, outer)
		if _wall:
			var wall_h := 1.15 + 0.7 * u
			_wall.scale = Vector3(outer, wall_h, outer)
		if _wall_mat:
			_wall_mat.albedo_color.a = 0.45 + 0.4 * u
			_wall_mat.emission_energy_multiplier = 5.0 + 6.0 * u
		var intensity := 0.5 + 0.45 * u
		for mat in _shadow_mats:
			if mat:
				mat.albedo_color = Color(0.02, 0.04, 0.12, intensity)
		for edge_mat in _shadow_edge_mats:
			if edge_mat:
				edge_mat.albedo_color = Color(1.0, 0.78, 0.22, 0.45 + 0.5 * u)
				edge_mat.emission = Color(1.0, 0.62, 0.12)
				edge_mat.emission_energy_multiplier = 1.4 + 6.5 * u
		if _pull:
			var pm := _pull.process_material as ParticleProcessMaterial
			if pm:
				pm.emission_ring_radius = maxf(outer * 0.22, 1.2)
				pm.emission_ring_inner_radius = 0.35
	if resolved:
		return
	if elapsed < warning_time:
		return
	resolved = true
	_stop_warn_loop()
	_apply_damage()
	_pulse_corona_impact()
	var linger := 0.38 if inner_radius > 0.05 else 0.18
	var tw := create_tween()
	tw.tween_interval(linger)
	tw.tween_callback(func() -> void:
		if hostile:
			ArenaState.remove_telegraph(self)
		queue_free()
	)


func interrupt_cast() -> bool:
	if resolved or not interruptible:
		return false
	resolved = true
	_stop_warn_loop()
	color = Color(0.55, 0.88, 1.0, 1.0)
	if _mat is ShaderMaterial:
		GroundIndicator.tint_shader(_mat, color)
	elif _mat is StandardMaterial3D:
		GroundIndicator.tint_standard(_mat, color, GroundIndicator.FILL_ALPHA)
	if _outline_mat:
		GroundIndicator.tint_standard(_outline_mat, color, GroundIndicator.OUTLINE_ALPHA)
	var fade := create_tween()
	fade.tween_interval(0.12)
	fade.tween_callback(func() -> void:
		if hostile:
			ArenaState.remove_telegraph(self)
		queue_free()
	)
	return true


func _pulse_corona_impact() -> void:
	if inner_radius <= 0.05:
		return
	if _heat != null and is_instance_valid(_heat):
		_heat.visible = false
	if _ring != null and is_instance_valid(_ring):
		var pop := create_tween()
		pop.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
		pop.tween_property(_ring, "scale", Vector3(1.28, 1.0, 1.28), 0.28)
	if _corona_ring_mat:
		_corona_ring_mat.emission_energy_multiplier = 8.5
	SolarWashFx.play(0.12, 0.35)


func _exit_tree() -> void:
	_stop_warn_loop()
	if not cover_visual and ability_id != "solar_collapse":
		return
	var arena := ArenaState.arena as Arena
	if arena:
		arena.end_solar_flare()


func _apply_damage() -> void:
	if sfx_impact != "":
		var at := global_position
		if cover_visual and source:
			at = source.global_position
		AudioManager.play_at(sfx_impact, at)
	if ability_id == "solar_collapse":
		SolarWashFx.play(0.1, 0.4)
	if vfx_scene != "":
		var vfx_at := global_position
		if cover_visual and source:
			vfx_at = source.global_position
		AbilityFx.play_at(vfx_scene, vfx_at, vfx_cfg)
	for u in ArenaState.units_near(global_position, _unit_query_radius(), false, true, true):
		if source and u.team == source.team:
			continue
		if contains_point(u.global_position):
			if _blocked_by_wall(u):
				continue
			if element != AbilityDef.Element.NONE or extra_elements.size() > 0:
				u.receive_ability_hit(source, element, damage, 0.0, extra_elements, false, true, true, overheat_cast_id, infusion_double, ability_id, combat_text_cast_id)
			else:
				u.apply_world_hit(damage, source, "hit", ability_id if not ability_id.is_empty() else "boss_hit", combat_text_cast_id)
			if judgment_stacks > 0:
				u.apply_judgment_brand(judgment_stacks)
			if slow_duration > 0.0:
				u.apply_slow(slow_percent, slow_duration)
	_damage_walls()
	if pillar_flat_damage > 0.0 or pillar_damage_ratio > 0.0:
		_damage_pillars()


func _unit_query_radius() -> float:
	match shape:
		Shape.LINE:
			return sqrt(length * length + width * width * 0.25)
		Shape.CONE:
			return radius
		_:
			return radius


func _damage_pillars() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	for pillar in arena.living_pillars():
		if not contains_point(pillar.global_position):
			continue
		var amount := pillar_flat_damage
		if amount <= 0.0 and pillar_damage_ratio > 0.0:
			amount = pillar.max_health * pillar_damage_ratio
		if amount > 0.0:
			pillar.take_damage(amount)
	if pillar_damage_ratio > 0.0:
		_chip_cover_walls(pillar_damage_ratio)


func _blocked_by_wall(u: Unit) -> bool:
	if inner_radius > 0.05:
		return false
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return false
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(u.get_rid())
	var from := global_position
	if ability_id == "solar_collapse":
		if _SolarCollapseFx.covers_world(u.global_position):
			return true
		if source:
			from = source.global_position
		return SpellWall.cover_occludes(from, u.global_position, exclude)
	if inbound_cover:
		return arena.has_radial_shadow(u.global_position, exclude)
	if source and (los_from_source or shape == Shape.CONE or shape == Shape.LINE):
		from = source.global_position
	return not arena.spell_has_los(from, u.global_position, exclude)


func _damage_walls() -> void:
	if damage <= 0.0:
		return
	if requires_cover and pillar_damage_ratio > 0.0:
		return
	for wall in SpellWall.living_walls():
		if not wall.can_be_damaged_by(source):
			continue
		if not _overlaps_wall(wall):
			continue
		if _wall_in_cover(wall):
			continue
		wall.take_hit(damage, wall.aim_point(global_position), source, "hit", Color(0, 0, 0, 0), false, combat_text_cast_id)


func _chip_cover_walls(ratio: float) -> void:
	if ratio <= 0.0 and damage <= 0.0:
		return
	for wall in SpellWall.living_walls():
		if not wall.is_cover_solid():
			continue
		if not wall.can_be_damaged_by(source):
			continue
		if _wall_in_cover(wall):
			continue
		var amount := damage if damage > 0.0 else wall.max_health * ratio
		wall.take_hit(amount, wall.aim_point(global_position), source, "hit", Color(0, 0, 0, 0), false, combat_text_cast_id)


func _overlaps_wall(wall: SpellWall) -> bool:
	if wall == null:
		return false
	if shape == Shape.CIRCLE:
		if inner_radius > 0.05:
			if contains_point(wall.global_position):
				return true
			for p in wall.click_world_points():
				if contains_point(p):
					return true
			return false
		if wall.range_to(global_position) <= radius:
			return true
	if contains_point(wall.global_position):
		return true
	for p in wall.click_world_points():
		if contains_point(p):
			return true
	return false


func _wall_in_cover(wall: SpellWall) -> bool:
	if inner_radius > 0.05:
		return false
	var arena := ArenaState.arena as Arena
	if arena == null or wall == null:
		return false
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(wall.get_rid())
	if inbound_cover:
		return arena.has_radial_shadow(wall.global_position, exclude)
	if source and (los_from_source or shape == Shape.CONE or shape == Shape.LINE):
		return not arena.spell_has_los(source.global_position, wall.aim_point(source.global_position), exclude)
	return false
