class_name Telegraph
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")

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
var mark_damage_bonus: float = 0.0
var overheat_cast_id: int = -1
var combat_text_cast_id: int = -1
var infusion_double: int = 0
var ability_id: String = ""
var los_from_source: bool = false
var requires_cover: bool = false
var pillar_damage_ratio: float = 0.0
var linger_seconds: float = 0.0
var cover_visual: bool = false
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
	t.los_from_source = false
	t.requires_cover = true
	t.inbound_cover = true
	t.pillar_damage_ratio = 0.25
	t.linger_seconds = 6.0
	t.cover_visual = true
	t.interruptible = false
	t.vfx_scene = AbilityFx.GROUND_EXPLOSION
	t.vfx_cfg = {"scale": 4.2, "lifetime": 2.4}
	t.sfx_loop = "dawnwarden.collapse.warn"
	t.sfx_impact = "dawnwarden.collapse.impact"
	t.color = Color(1.0, 0.45, 0.08, 0.55)
	var pos := p_source.global_position if p_source else Vector3.ZERO
	_add(t, pos, Vector3.ZERO)
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
	match shape:
		Shape.CIRCLE:
			if cover_visual:
				_build_collapse_visual()
			else:
				_mat = GroundIndicator.shader_mat(color, true, Vector2(radius, radius))
				_mesh.mesh = GroundIndicator.circle_mesh()
				_mesh.material_override = _mat
				GroundIndicator.set_circle_radius(_mesh, radius)
				_mesh.position.y = 0.05
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


func _build_collapse_visual() -> void:
	_mesh.visible = false
	_fill = MeshInstance3D.new()
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.albedo_color = Color(1.0, 0.28, 0.04, 0.22)
	_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill_mat.emission_enabled = true
	_fill_mat.emission = Color(1.0, 0.22, 0.02)
	_fill_mat.emission_energy_multiplier = 1.8
	_fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill.material_override = _fill_mat
	_fill.mesh = _make_annulus_mesh(25.2, 28.0, 0.05)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill)
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
	_wall.mesh = _make_tube_mesh(26.6, 1.55)
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall)
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 25.0
	_ring_mesh.outer_radius = 27.4
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
	call_deferred("_build_pillar_shadows")
	call_deferred("_sync_wall_shadows")
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
	pm.emission_ring_radius = 26.4
	pm.emission_ring_inner_radius = 24.8
	pm.emission_ring_height = 0.6
	pm.direction = Vector3(0, 0.15, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 1.4
	pm.radial_accel_min = -28.0
	pm.radial_accel_max = -16.0
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
		mi.mesh = _shadow_mesh_for(pillar, 0.08, 1.0, true)
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
		var edge := MeshInstance3D.new()
		edge.mesh = _shadow_edge_strip(pillar, 0.11)
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
		_shadow_edge_mats.append(edge_mat)


func _sync_wall_shadows() -> void:
	if not cover_visual:
		return
	var key := ""
	var walls: Array[SpellWall] = []
	for wall in SpellWall.living_walls():
		if not wall.is_cover_solid():
			continue
		walls.append(wall)
		key += "%d:%.0f:%.0f," % [wall.get_instance_id(), wall.global_position.x * 10.0, wall.global_position.z * 10.0]
	if key == _wall_shadow_key:
		return
	_wall_shadow_key = key
	for node in _wall_shadows:
		if is_instance_valid(node):
			node.queue_free()
	_wall_shadows.clear()
	for wall in walls:
		var mi := MeshInstance3D.new()
		mi.mesh = _shadow_mesh_at(wall.global_position, wall.cover_half(), 0.08, 1.0, true)
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
		edge.mesh = _shadow_edge_at(wall.global_position, wall.cover_half(), 0.11)
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
		_wall_shadows.append(edge)


func _shadow_mesh_for(pillar: ArenaPillar, y: float, width_scale: float, fade: bool = false) -> ArrayMesh:
	return _shadow_mesh_at(pillar.global_position, pillar.half_xz(), y, width_scale, fade)


func _shadow_mesh_at(origin: Vector3, half_xz: float, y: float, width_scale: float, fade: bool = false) -> ArrayMesh:
	var p := Vector3(origin.x, 0.0, origin.z)
	var inward := Vector3(-p.x, 0.0, -p.z)
	if inward.length_squared() < 0.01:
		inward = Vector3(0, 0, -1)
	inward = inward.normalized()
	var right := Vector3(-inward.z, 0.0, inward.x)
	var half := (half_xz + 0.28) * width_scale
	var start := p + inward * (half_xz + 0.08)
	var length := 9.2
	var end := start + inward * length
	var half2 := half * 1.18
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := start - right * half + Vector3(0, y, 0)
	var b := start + right * half + Vector3(0, y, 0)
	var c := end + right * half2 + Vector3(0, y, 0)
	var d := end - right * half2 + Vector3(0, y, 0)
	if fade:
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(to_local(a))
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(to_local(b))
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(to_local(c))
		st.set_color(Color(1, 1, 1, 0.92))
		st.add_vertex(to_local(a))
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(to_local(c))
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(to_local(d))
	else:
		st.add_vertex(to_local(a))
		st.add_vertex(to_local(b))
		st.add_vertex(to_local(c))
		st.add_vertex(to_local(a))
		st.add_vertex(to_local(c))
		st.add_vertex(to_local(d))
	return st.commit()


func _shadow_edge_strip(pillar: ArenaPillar, y: float) -> ArrayMesh:
	return _shadow_edge_at(pillar.global_position, pillar.half_xz(), y)


func _shadow_edge_at(origin: Vector3, half_xz: float, y: float) -> ArrayMesh:
	var p := Vector3(origin.x, 0.0, origin.z)
	var inward := Vector3(-p.x, 0.0, -p.z)
	if inward.length_squared() < 0.01:
		inward = Vector3(0, 0, -1)
	inward = inward.normalized()
	var right := Vector3(-inward.z, 0.0, inward.x)
	var half := half_xz + 0.22
	var start := p + inward * (half_xz + 0.04)
	var end := start + inward * 0.55
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := start - right * half + Vector3(0, y, 0)
	var b := start + right * half + Vector3(0, y, 0)
	var c := end + right * half + Vector3(0, y, 0)
	var d := end - right * half + Vector3(0, y, 0)
	st.add_vertex(to_local(a))
	st.add_vertex(to_local(b))
	st.add_vertex(to_local(c))
	st.add_vertex(to_local(a))
	st.add_vertex(to_local(c))
	st.add_vertex(to_local(d))
	return st.commit()


func _make_annulus_mesh(inner: float, outer: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 48
	inner = maxf(inner, 0.2)
	outer = maxf(outer, inner + 0.15)
	for i in steps:
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		var i0 := Vector3(cos(a0) * inner, y, sin(a0) * inner)
		var i1 := Vector3(cos(a1) * inner, y, sin(a1) * inner)
		var o0 := Vector3(cos(a0) * outer, y, sin(a0) * outer)
		var o1 := Vector3(cos(a1) * outer, y, sin(a1) * outer)
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
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
			return Vector2(local.x, local.z).length() <= radius
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
			var local := to_local(from)
			var side := 1.0 if local.x >= 0.0 else -1.0
			var world_side := global_transform.basis.x * side * 3.5
			return Vector3(from.x, 0.0, from.z) + Vector3(world_side.x, 0.0, world_side.z)
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
		if inbound_cover:
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
	var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
	if _mat is ShaderMaterial:
		var sh := _mat as ShaderMaterial
		if cover_visual:
			sh.set_shader_parameter("fill_alpha", 0.03)
			sh.set_shader_parameter("outline_alpha", 0.55)
		else:
			sh.set_shader_parameter("fill_alpha", 0.16 + 0.08 * pulse)
			sh.set_shader_parameter("outline_alpha", GroundIndicator.OUTLINE_ALPHA)
			sh.set_shader_parameter("outline_width", GroundIndicator.LINE_WIDTH)
			sh.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0))
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
		_sync_wall_shadows()
	if cover_visual and _ring_mesh:
		var u := clampf(elapsed / maxf(warning_time, 0.001), 0.0, 1.0)
		var arena := ArenaState.arena as Arena
		if arena:
			arena.set_solar_flare(u, true)
		var outer := lerpf(27.5, 7.2, u * u)
		_ring_mesh.outer_radius = outer
		_ring_mesh.inner_radius = maxf(outer - 2.15, 0.6)
		if absf(outer - _last_outer) > 0.12:
			_last_outer = outer
			if _fill:
				_fill.mesh = _make_annulus_mesh(outer, 28.0, 0.05)
			if _wall:
				_wall.mesh = _make_tube_mesh(outer, 1.15 + 0.7 * u)
		if _fill_mat:
			_fill_mat.albedo_color.a = 0.18 + 0.22 * u
			_fill_mat.emission_energy_multiplier = 1.6 + 2.8 * u
		if _wall_mat:
			_wall_mat.albedo_color.a = 0.45 + 0.4 * u
			_wall_mat.emission_energy_multiplier = 5.0 + 6.0 * u
		var intensity := 0.12 + 0.78 * u
		for mat in _shadow_mats:
			if mat:
				mat.albedo_color = Color(0.02, 0.04, 0.12, intensity)
		for edge_mat in _shadow_edge_mats:
			if edge_mat:
				edge_mat.albedo_color = Color(1.0, 0.78, 0.22, 0.12 + 0.7 * u)
				edge_mat.emission = Color(1.0, 0.62, 0.12)
				edge_mat.emission_energy_multiplier = 1.4 + 6.5 * u
		if _pull:
			var pm := _pull.process_material as ParticleProcessMaterial
			if pm:
				pm.emission_ring_radius = outer
				pm.emission_ring_inner_radius = maxf(outer - 1.6, 0.5)
	if resolved:
		return
	if elapsed < warning_time:
		return
	resolved = true
	_stop_warn_loop()
	_apply_damage()
	var tw := create_tween()
	tw.tween_interval(0.18)
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


func _exit_tree() -> void:
	_stop_warn_loop()
	if not cover_visual:
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
	if vfx_scene != "":
		var vfx_at := global_position
		if cover_visual and source:
			vfx_at = source.global_position
		AbilityFx.play_at(vfx_scene, vfx_at, vfx_cfg)
		if cover_visual:
			AbilityFx.play_at(AbilityFx.FIRE_AREA, vfx_at, {"area_radius": 10.0, "scale": 1.7, "lifetime": 2.2})
			for i in 4:
				var angle := TAU * float(i) / 4.0
				var rim := Vector3(cos(angle) * 24.5, 1.0, sin(angle) * 24.5)
				AbilityFx.play_at(AbilityFx.FIRE_CAST, rim, {
					"look": -rim,
					"scale": 1.35,
					"lifetime": 1.5,
				})
	for u in ArenaState.units:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_structure:
			continue
		if source and u.team == source.team:
			continue
		if contains_point(u.global_position):
			if _blocked_by_wall(u):
				continue
			if element != AbilityDef.Element.NONE or mark_damage_bonus > 0.0 or extra_elements.size() > 0:
				u.receive_ability_hit(source, element, damage, mark_damage_bonus, extra_elements, false, true, true, overheat_cast_id, infusion_double, ability_id, combat_text_cast_id)
			else:
				u.apply_world_hit(damage, source, "hit", ability_id if not ability_id.is_empty() else "boss_hit", combat_text_cast_id)
			if slow_duration > 0.0:
				u.apply_slow(slow_percent, slow_duration)
	_damage_walls()
	if pillar_damage_ratio > 0.0:
		var arena := ArenaState.arena as Arena
		if arena:
			arena.damage_living_pillars(pillar_damage_ratio)
			_chip_cover_walls(pillar_damage_ratio)
	if linger_seconds > 0.0:
		var linger_arena := ArenaState.arena as Arena
		if linger_arena:
			linger_arena.start_lingering_dawn(linger_seconds)


func _blocked_by_wall(u: Unit) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return false
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(u.get_rid())
	var from := global_position
	if inbound_cover:
		return arena.has_radial_shadow(u.global_position, exclude)
	if source and (los_from_source or shape == Shape.CONE or shape == Shape.LINE):
		from = source.global_position
	return not arena.spell_has_los(from, u.global_position, exclude)


func _damage_walls() -> void:
	if damage <= 0.0:
		return
	if inbound_cover and pillar_damage_ratio > 0.0:
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
	if shape == Shape.CIRCLE and wall.range_to(global_position) <= radius:
		return true
	if contains_point(wall.global_position):
		return true
	for p in wall.click_world_points():
		if contains_point(p):
			return true
	return false


func _wall_in_cover(wall: SpellWall) -> bool:
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
