class_name MeteorFx
extends Node3D

const FALL_TIME := 0.95
const START_HEIGHT := 20.0
const LATERAL := 11.0
const CORE_MESH_RADIUS := 0.42
const ROCK_TO_MARKER := 0.80
const _BURST_SHADER := preload("res://scripts/visual/firebolt_burst.gdshader")

var caster: Node
var ability: AbilityDef
var damage: float = 500.0
var radius: float = 2.0
var extras: PackedInt32Array = PackedInt32Array()
var overheat_cast_id: int = -1
var infusion_double: int = 0
var combust_mult: float = 2.0

var _land: Vector3
var _start: Vector3
var _rock: Node3D
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _hit: bool = false


static func drop(p_caster: Node, point: Vector3, ab: AbilityDef, p_damage: float, p_radius: float, p_extras: PackedInt32Array, p_overheat_cast_id: int = -1, p_infusion_double: int = 0, p_combust_mult: float = 2.0) -> Node3D:
	var fx := new()
	fx.caster = p_caster
	fx.ability = ab
	fx.damage = p_damage
	fx.radius = maxf(p_radius, 0.6)
	fx.extras = p_extras
	fx.overheat_cast_id = p_overheat_cast_id
	fx.infusion_double = p_infusion_double
	fx.combust_mult = p_combust_mult
	fx._land = Vector3(point.x, 0.28, point.z)
	var inbound := Vector3.FORWARD
	if p_caster and is_instance_valid(p_caster):
		inbound = fx._land - p_caster.global_position
		inbound.y = 0.0
		if inbound.length_squared() < 0.04 and p_caster.has_method("facing_dir"):
			inbound = p_caster.facing_dir()
	inbound.y = 0.0
	if inbound.length_squared() < 0.0001:
		inbound = Vector3.FORWARD
	inbound = inbound.normalized()
	fx._start = fx._land - inbound * LATERAL + Vector3(0.0, START_HEIGHT, 0.0)
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(fx)
	fx.global_position = Vector3(point.x, 0.0, point.z)
	fx._build()
	return fx


func _build() -> void:
	_make_marker()
	_rock = Node3D.new()
	add_child(_rock)
	_rock.global_position = _start
	# Core mesh radius is 0.42; keep the falling rock 20% smaller in diameter than the marker.
	var rock_scale := maxf(radius * ROCK_TO_MARKER / CORE_MESH_RADIUS, 0.55)
	_rock.scale = Vector3.ONE * rock_scale
	_orient_rock()
	var vfx := AbilityFx.attach(AbilityFx.FIRE_PROJECTILE, _rock, {
		"scale": 1.12,
		"yaw_offset": -PI * 0.5,
	})
	if vfx:
		# Fire trail sits on the smaller rock; keep the tail from stretching as far.
		vfx.scale = Vector3(0.52, 1.12, 1.12)
		if vfx.has_method("open"):
			vfx.call("open")
	var charge_vol := clampf((radius - 2.0) / 3.4, 0.0, 1.0)
	# Clip opens with ~1s of travel; start it on drop so the boom lands with the hit.
	AudioManager.play_at("meteor.impact", _land, {"volume_db": lerpf(-2.0, 3.0, charge_vol)})
	_make_core()
	_make_light()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_method(_set_flight, 0.0, 1.0, FALL_TIME)
	tw.tween_callback(_impact)


func _make_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.07
	cyl.radial_segments = 40
	_marker.mesh = cyl
	_marker.position = Vector3(0.0, 0.05, 0.0)
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(1.0, 0.42, 0.12, 0.42)
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_marker.material_override = _marker_mat
	add_child(_marker)


func _make_core() -> void:
	var core := MeshInstance3D.new()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.84
	core.mesh = sm
	core.position = Vector3(0.0, 0.0, -0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.06, 0.02)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.38, 0.08)
	mat.emission_energy_multiplier = 3.4
	mat.roughness = 0.85
	core.material_override = mat
	_rock.add_child(core)


func _make_light() -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.18)
	light.light_energy = 4.2 + radius * 1.15
	light.omni_range = radius * 3.2
	_rock.add_child(light)


func _set_flight(t: float) -> void:
	if _rock == null:
		return
	_rock.global_position = _start.lerp(_land, t)
	if t < 0.97:
		_orient_rock()


func _orient_rock() -> void:
	var to := _land - _rock.global_position
	if to.length_squared() < 0.04:
		return
	var dir := to.normalized()
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.92:
		up = Vector3.FORWARD
	_rock.look_at(_rock.global_position + dir, up)


func _process(_delta: float) -> void:
	if _hit or _marker_mat == null:
		return
	var pulse := 0.34 + 0.16 * sin(Time.get_ticks_msec() * 0.014)
	_marker_mat.albedo_color = Color(1.0, 0.42, 0.12, pulse)


func _impact() -> void:
	if _hit:
		return
	_hit = true
	if _rock:
		_rock.visible = false
	_spawn_impact_blast()
	if is_instance_valid(caster) and ability and caster.has_method("_ground_burst"):
		caster._ground_burst(_land, ability, damage, radius, extras, overheat_cast_id, infusion_double, combust_mult)
	else:
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, _land, {
			"scale": maxf(radius / 5.0, 0.35),
			"area_radius": radius,
			"lifetime": 1.8,
		})
	var tw := create_tween()
	if _marker_mat:
		tw.tween_property(_marker_mat, "albedo_color:a", 0.0, 0.18)
	else:
		tw.tween_interval(0.12)
	tw.tween_callback(queue_free)


func _spawn_impact_blast() -> void:
	var parent: Node = get_parent()
	if parent == null:
		parent = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	if parent == null:
		return
	var fx := Node3D.new()
	parent.add_child(fx)
	fx.global_position = Vector3(_land.x, 0.08, _land.z)
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = 1.5
	var mat := ShaderMaterial.new()
	mat.shader = _BURST_SHADER
	mat.set_shader_parameter("core_color", Color(1.0, 0.94, 0.48, 1.0))
	mat.set_shader_parameter("fire_color", Color(1.0, 0.38, 0.06, 1.0))
	mat.set_shader_parameter("rim_color", Color(0.72, 0.08, 0.12, 0.95))
	mat.set_shader_parameter("grow", 0.16)
	mat.set_shader_parameter("fade", 1.0)
	mi.material_override = mat
	mi.mesh = _blast_disc(radius)
	fx.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.16)
	light.light_energy = 10.0 + radius * 1.4
	light.omni_range = radius * 2.6
	light.position = Vector3(0.0, 0.55, 0.0)
	fx.add_child(light)
	var tw := fx.create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("grow", v)
	, 0.16, 1.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("fade", v)
		if is_instance_valid(light):
			light.light_energy = (10.0 + radius * 1.4) * v
	, 1.0, 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(fx.queue_free)


func _blast_disc(r: float) -> ArrayMesh:
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
