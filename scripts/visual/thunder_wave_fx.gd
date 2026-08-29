class_name ThunderWaveFx
extends Node3D

const _SHADER := preload("res://scripts/visual/lightning_bolt.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const _CORE := Color(0.95, 0.98, 1.0, 1.0)
const _BLUE := Color(0.28, 0.62, 1.0, 0.95)
const _PURPLE := Color(0.55, 0.28, 1.0, 0.72)

var _points: Array[Vector3] = []
var _shown: int = 1
var _fade: float = 1.0
var _acc: float = 0.0
var _bounce_delay: float = 0.08
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _mesh: MeshInstance3D


static func spawn(points: Array[Vector3], bounce_delay: float = 0.08) -> ThunderWaveFx:
	var fx := ThunderWaveFx.new()
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(fx)
	fx._points = points
	fx._bounce_delay = maxf(bounce_delay, 0.01)
	fx._play()
	return fx


func _play() -> void:
	_rng.randomize()
	_mat = ShaderMaterial.new()
	_mat.shader = _SHADER
	_mat.set_shader_parameter("fade", 1.0)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _mat
	add_child(_mesh)
	if _points.size() >= 2:
		_burst(_points[0], 0.55)
		_burst(_points[1], 1.0)
	_rebuild()
	var hops := maxi(_points.size() - 2, 0)
	var tw := create_tween()
	for i in hops:
		var idx := i + 2
		tw.tween_interval(_bounce_delay)
		tw.tween_callback(_reveal.bind(idx))
	tw.tween_interval(0.32)
	tw.tween_method(_set_fade, 1.0, 0.0, 0.22)
	tw.tween_callback(queue_free)


func _reveal(upto: int) -> void:
	_shown = upto
	if upto < _points.size():
		_burst(_points[upto], 1.0)
	_rebuild()


func _set_fade(v: float) -> void:
	_fade = v
	if _mat:
		_mat.set_shader_parameter("fade", v)


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.04:
		_acc = 0.0
		_rebuild()


func _rebuild() -> void:
	if _points.size() < 2 or _mesh == null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := mini(_shown, _points.size() - 1)
	for i in last:
		var a := _points[i]
		var b := _points[i + 1]
		if a.distance_squared_to(b) < 0.0004:
			continue
		var jag := _jagged(a, b)
		_cross_ribbon(st, jag, 0.34, _PURPLE)
		_cross_ribbon(st, jag, 0.14, _BLUE)
		_cross_ribbon(st, jag, 0.045, _CORE)
		_forks(st, jag)
	_mesh.mesh = st.commit()


func _jagged(a: Vector3, b: Vector3) -> PackedVector3Array:
	var dist := a.distance_to(b)
	var n := clampi(int(dist / 0.7) + 4, 5, 14)
	var dir := b - a
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var pts := PackedVector3Array()
	pts.append(a)
	var mag := 0.22 + dist * 0.035
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := a.lerp(b, t)
		var sign := 1.0 if i % 2 == 0 else -1.0
		p += side * sign * mag * _rng.randf_range(0.35, 1.0)
		p += Vector3.UP * _rng.randf_range(-mag * 0.35, mag * 0.55)
		pts.append(p)
	pts.append(b)
	return pts


func _forks(st: SurfaceTool, jag: PackedVector3Array) -> void:
	if jag.size() < 4:
		return
	var forks := clampi(int(jag.size() / 4), 1, 3)
	for _i in forks:
		var idx := _rng.randi_range(1, jag.size() - 2)
		var origin := jag[idx]
		var prev := jag[idx - 1]
		var tan := origin - prev
		if tan.length_squared() < 0.0001:
			continue
		tan = tan.normalized()
		var side := tan.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var tip := origin + side * _rng.randf_range(-0.9, 0.9) + tan * _rng.randf_range(0.25, 0.7) + Vector3.UP * _rng.randf_range(0.05, 0.45)
		var branch := PackedVector3Array()
		branch.append(origin)
		branch.append(origin.lerp(tip, 0.45) + side * _rng.randf_range(-0.15, 0.15))
		branch.append(tip)
		_cross_ribbon(st, branch, 0.09, _BLUE)
		_cross_ribbon(st, branch, 0.03, _CORE)


func _cross_ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, color: Color) -> void:
	if pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_pos := cam.global_position if cam else Vector3(0.0, 18.0, 8.0)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := b - a
		if dir.length_squared() < 0.00001:
			continue
		dir = dir.normalized()
		var to_cam := cam_pos - (a + b) * 0.5
		var side := dir.cross(to_cam)
		if side.length_squared() < 0.0001:
			side = dir.cross(Vector3.UP)
		side = side.normalized() * width
		var u0 := float(i) / float(pts.size() - 1)
		var u1 := float(i + 1) / float(pts.size() - 1)
		_quad(st, a - side, a + side, b + side, b - side, u0, u1, color)
		var up := Vector3.UP * width * 0.7
		_quad(st, a - up, a + up, b + up, b - up, u0, u1, color)


func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, u0: float, u1: float, color: Color) -> void:
	st.set_color(color)
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(p0)
	st.set_color(color)
	st.set_uv(Vector2(u0, 1.0))
	st.add_vertex(p1)
	st.set_color(color)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(p2)
	st.set_color(color)
	st.set_uv(Vector2(u1, 1.0))
	st.add_vertex(p2)
	st.set_color(color)
	st.set_uv(Vector2(u1, 0.0))
	st.add_vertex(p3)
	st.set_color(color)
	st.set_uv(Vector2(u0, 0.0))
	st.add_vertex(p0)


func _burst(pos: Vector3, strength: float) -> void:
	var ball := MeshInstance3D.new()
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sph := SphereMesh.new()
	sph.radius = 0.42 * strength
	sph.height = 0.84 * strength
	ball.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.55, 0.32, 1.0, 0.7 * strength)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ball.material_override = mat
	ball.position = pos
	ball.scale = Vector3.ONE * 0.45
	add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.4, 1.0)
	light.light_energy = 3.8 * strength
	light.omni_range = 3.4 * strength
	light.position = pos
	add_child(light)
	_sparks(pos, strength)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.42)
	tw.tween_property(light, "light_energy", 0.0, 0.42)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(ball):
			ball.queue_free()
		if is_instance_valid(light):
			light.queue_free()
	)


func _sparks(pos: Vector3, strength: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = int(14.0 * strength)
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.28)
	p.draw_pass_1 = mesh
	var smat := ShaderMaterial.new()
	smat.shader = _WISP_SHADER
	smat.set_shader_parameter("color", Color(0.85, 0.9, 1.0, 0.95))
	p.material_override = smat
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_shape_scale = Vector3(0.18, 0.18, 0.18)
	pp.direction = Vector3(0.0, 1.0, 0.0)
	pp.spread = 80.0
	pp.initial_velocity_min = 1.6
	pp.initial_velocity_max = 4.2
	pp.gravity = Vector3(0.0, 0.4, 0.0)
	pp.scale_min = 0.55
	pp.scale_max = 1.25
	p.process_material = pp
	p.position = pos
	add_child(p)
	p.emitting = true
	p.get_tree().create_timer(0.55).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.queue_free()
	)
