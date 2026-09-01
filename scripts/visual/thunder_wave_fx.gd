class_name ThunderWaveFx
extends Node3D

## Pooled chain bolts. Jagged 3-layer ribbons stay. NPC endpoints are
## snapshotted; only a local-player origin follows, at a low geometry rate.

const _SHADER := preload("res://scripts/visual/lightning_bolt.gdshader")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const _CORE := Color(0.94, 0.99, 1.0, 1.0)
const _BLUE := Color(0.62, 0.88, 1.0, 0.92)
const _GLOW := Color(0.45, 0.82, 1.0, 0.42)
const _POOL_SIZE := 16
const _SPAWNS_PER_SECOND := 40.0
const _SPAWN_BURST := 8.0
const _FOLLOW_INTERVAL := 0.10
const _MOVE_EPSILON_SQ := 0.0004
const _STASH := Vector3(0.0, -80.0, 0.0)

static var _pool: Array[ThunderWaveFx] = []
static var _steal: int = 0
static var _spark_mat: ShaderMaterial
static var _spark_pp: ParticleProcessMaterial
static var _spark_mesh: QuadMesh
static var _spawn_tokens: float = _SPAWN_BURST
static var _last_spawn_usec: int = 0

var _points: Array[Vector3] = []
var _hosts: Array = []
var _fallbacks: Array[Vector3] = []
var _shown: int = 1
var _bounce_delay: float = 0.08
var _shape_seed: int = 0
var _rng := RandomNumberGenerator.new()
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _array_mesh: ArrayMesh
var _sparks: GPUParticles3D
var _tw: Tween
var _built: bool = false
var _pooled: bool = false
var _cam_pos: Vector3 = Vector3(0.0, 18.0, 8.0)
var _follow_acc: float = 0.0
var _has_player_origin: bool = false


static func spawn(chain: Array, bounce_delay: float = 0.08, guaranteed: bool = false) -> ThunderWaveFx:
	if chain.size() < 2:
		return null
	if not guaranteed and not _take_spawn_token():
		return null
	var fx := _acquire()
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	if fx.get_parent() != parent:
		if fx.get_parent():
			fx.get_parent().remove_child(fx)
		parent.add_child(fx)
	fx.process_mode = Node.PROCESS_MODE_INHERIT
	fx.visible = true
	fx.global_position = Vector3.ZERO
	fx._bind_chain(chain)
	fx._bounce_delay = maxf(bounce_delay, 0.01)
	if not fx._built:
		fx._build()
	fx._play()
	return fx


static func _take_spawn_token() -> bool:
	var now := Time.get_ticks_usec()
	if _last_spawn_usec <= 0:
		_last_spawn_usec = now
	var elapsed := maxf(float(now - _last_spawn_usec) / 1000000.0, 0.0)
	_last_spawn_usec = now
	_spawn_tokens = minf(_SPAWN_BURST, _spawn_tokens + elapsed * _SPAWNS_PER_SECOND)
	if _spawn_tokens < 1.0:
		return false
	_spawn_tokens -= 1.0
	return true


static func warmup(parent: Node) -> void:
	if parent == null:
		return
	_ensure_shared()
	var keep: Array[ThunderWaveFx] = []
	for item in _pool:
		var fx := _alive(item)
		if fx == null:
			continue
		if fx.get_parent() != parent:
			if fx.get_parent():
				fx.get_parent().remove_child(fx)
			parent.add_child(fx)
		fx._pooled = true
		fx._stash()
		keep.append(fx)
	_pool = keep
	while _pool.size() < _POOL_SIZE:
		var fx := ThunderWaveFx.new()
		fx._pooled = true
		fx.set_meta("fx_busy", false)
		parent.add_child(fx)
		fx._build()
		fx._stash()
		_pool.append(fx)


static func _alive(value: Variant) -> ThunderWaveFx:
	if value == null or not is_instance_valid(value):
		return null
	var fx := value as ThunderWaveFx
	if fx == null or fx.is_queued_for_deletion():
		return null
	return fx


static func _prune_pool() -> void:
	var keep: Array[ThunderWaveFx] = []
	for item in _pool:
		var fx := _alive(item)
		if fx != null:
			keep.append(fx)
	_pool = keep


static func _acquire() -> ThunderWaveFx:
	_prune_pool()
	for item in _pool:
		var fx := _alive(item)
		if fx != null and not bool(fx.get_meta("fx_busy", false)):
			fx.set_meta("fx_busy", true)
			return fx
	if _pool.size() < _POOL_SIZE:
		var fresh := ThunderWaveFx.new()
		fresh._pooled = true
		fresh.set_meta("fx_busy", true)
		_pool.append(fresh)
		return fresh
	var stolen := _pool[_steal % _pool.size()]
	_steal += 1
	stolen.set_meta("fx_busy", true)
	return stolen


static func _ensure_shared() -> void:
	if _spark_mat == null:
		_spark_mat = ShaderMaterial.new()
		_spark_mat.shader = _WISP_SHADER
	_spark_mat.set_shader_parameter("color", Color(0.72, 0.93, 1.0, 0.92))
	if _spark_mesh == null:
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2(0.08, 0.28)
	if _spark_pp == null:
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
		_spark_pp = pp


func _build() -> void:
	_ensure_shared()
	_mat = ShaderMaterial.new()
	_mat.shader = _SHADER
	_mat.set_shader_parameter("fade", 1.0)
	_mesh = MeshInstance3D.new()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.material_override = _mat
	_array_mesh = ArrayMesh.new()
	_mesh.mesh = _array_mesh
	add_child(_mesh)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 14
	_sparks.lifetime = 0.18
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.emitting = false
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparks.draw_pass_1 = _spark_mesh
	_sparks.material_override = _spark_mat
	_sparks.process_material = _spark_pp
	add_child(_sparks)
	_built = true


func _bind_chain(chain: Array) -> void:
	_hosts.clear()
	_points.clear()
	_fallbacks.clear()
	for item in chain:
		if typeof(item) == TYPE_OBJECT and not is_instance_valid(item):
			continue
		var host: Variant = null
		var pos := Vector3.ZERO
		if item is Unit:
			pos = _anchor_point(item)
		elif item is Node3D:
			pos = _anchor_point(item)
		elif item is Vector3:
			pos = item
		else:
			continue
		if _points.is_empty() and typeof(item) == TYPE_OBJECT and item == GameSession.active_unit:
			host = item
		_hosts.append(host)
		_points.append(pos)
		_fallbacks.append(pos)
	_has_player_origin = not _hosts.is_empty() and _hosts[0] != null
	_follow_acc = 0.0


func _anchor_point(host: Variant) -> Vector3:
	if host is Unit and is_instance_valid(host):
		return host.global_position + Vector3(0.0, host.height * 0.55, 0.0)
	if host is Node3D and is_instance_valid(host):
		return host.global_position + Vector3(0.0, 0.55, 0.0)
	return Vector3.ZERO


func _sync_points() -> bool:
	var changed := false
	var n := mini(_hosts.size(), _points.size())
	for i in n:
		var host: Variant = _hosts[i]
		if host != null and is_instance_valid(host):
			var pos := _anchor_point(host)
			if _points[i].distance_squared_to(pos) > _MOVE_EPSILON_SQ:
				_points[i] = pos
				changed = true
			_fallbacks[i] = pos
		elif host != null and i < _fallbacks.size():
			_hosts[i] = null
			_points[i] = _fallbacks[i]
	return changed


func _play() -> void:
	if _tw:
		_tw.kill()
		_tw = null
	_rng.randomize()
	_shape_seed = _rng.randi()
	_shown = 1
	_follow_acc = 0.0
	if _mat:
		_mat.set_shader_parameter("fade", 1.0)
	_sync_points()
	_cache_cam()
	if _points.size() >= 2:
		_spark_at(_points[0])
		FxHeroLights.pulse(_points[0], Color(0.55, 0.86, 1.0), 3.4, 3.6, 0.18)
	_rebuild()
	set_process(_has_player_origin)
	var hops := maxi(_points.size() - 2, 0)
	_tw = create_tween()
	for i in hops:
		var idx := i + 2
		_tw.tween_interval(_bounce_delay)
		_tw.tween_callback(_reveal.bind(idx))
	_tw.tween_interval(0.05)
	_tw.tween_method(_set_fade, 1.0, 0.0, 0.08)
	_tw.tween_callback(_finish)


func _process(delta: float) -> void:
	if not _has_player_origin or _points.size() < 2:
		return
	_follow_acc += delta
	if _follow_acc < _FOLLOW_INTERVAL:
		return
	_follow_acc = fmod(_follow_acc, _FOLLOW_INTERVAL)
	if _sync_points():
		_rebuild()


func _reveal(upto: int) -> void:
	_shown = upto
	_sync_points()
	if upto < _points.size():
		_spark_at(_points[upto])
	_rebuild()


func _set_fade(v: float) -> void:
	if _mat:
		_mat.set_shader_parameter("fade", v)


func _finish() -> void:
	if _pooled:
		_stash()
	else:
		queue_free()


func _stash() -> void:
	if _tw:
		_tw.kill()
		_tw = null
	set_meta("fx_busy", false)
	set_process(false)
	visible = false
	if _sparks:
		_sparks.emitting = false
	if _mesh:
		if _array_mesh:
			_array_mesh.clear_surfaces()
		_mesh.mesh = _array_mesh
	_hosts.clear()
	_points.clear()
	_fallbacks.clear()
	_has_player_origin = false
	_follow_acc = 0.0
	global_position = _STASH
	process_mode = Node.PROCESS_MODE_DISABLED


func _cache_cam() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	_cam_pos = cam.global_position if cam else Vector3(0.0, 18.0, 8.0)


func _spark_at(pos: Vector3) -> void:
	if _sparks == null:
		return
	_sparks.global_position = pos
	_sparks.restart()
	_sparks.emitting = true


func _rebuild() -> void:
	if _points.size() < 2 or _mesh == null or _array_mesh == null:
		return
	_rng.seed = _shape_seed
	_cache_cam()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := mini(_shown, _points.size() - 1)
	for i in last:
		var a := _points[i]
		var b := _points[i + 1]
		if a.distance_squared_to(b) < 0.0004:
			continue
		var jag := _jagged(a, b)
		_cross_ribbon(st, jag, 0.09, _GLOW)
		_cross_ribbon(st, jag, 0.038, _BLUE)
		_cross_ribbon(st, jag, 0.014, _CORE)
		_forks(st, jag)
	_array_mesh.clear_surfaces()
	st.commit(_array_mesh)
	_mesh.mesh = _array_mesh


func _jagged(a: Vector3, b: Vector3) -> PackedVector3Array:
	var dist := a.distance_to(b)
	var n := clampi(int(dist / 0.45) + 5, 7, 14)
	var dir := b - a
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var pts := PackedVector3Array()
	pts.append(a)
	var mag := 0.05 + dist * 0.012
	for i in range(1, n):
		var t := float(i) / float(n)
		var p := a.lerp(b, t)
		var kick := 0.0
		if _rng.randf() > 0.28:
			kick = _rng.randf_range(-1.0, 1.0) * mag
			if _rng.randf() < 0.16:
				kick *= _rng.randf_range(1.8, 2.6)
		p += side * kick
		p += Vector3.UP * kick * _rng.randf_range(-0.35, 0.45)
		pts.append(p)
	pts.append(b)
	return pts


func _forks(st: SurfaceTool, jag: PackedVector3Array) -> void:
	if jag.size() < 4:
		return
	var forks := 1 if jag.size() < 7 else 2
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
		var tip := origin + side * _rng.randf_range(-0.35, 0.35) + tan * _rng.randf_range(0.18, 0.42) + Vector3.UP * _rng.randf_range(0.02, 0.22)
		var branch := PackedVector3Array()
		branch.append(origin)
		branch.append(origin.lerp(tip, 0.45) + side * _rng.randf_range(-0.06, 0.06))
		branch.append(tip)
		_cross_ribbon(st, branch, 0.028, _BLUE)
		_cross_ribbon(st, branch, 0.01, _CORE)


func _cross_ribbon(st: SurfaceTool, pts: PackedVector3Array, width: float, color: Color) -> void:
	if pts.size() < 2:
		return
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := b - a
		if dir.length_squared() < 0.00001:
			continue
		dir = dir.normalized()
		var to_cam := _cam_pos - (a + b) * 0.5
		var side := dir.cross(to_cam)
		if side.length_squared() < 0.0001:
			side = dir.cross(Vector3.UP)
		side = side.normalized() * width
		var u0 := float(i) / float(pts.size() - 1)
		var u1 := float(i + 1) / float(pts.size() - 1)
		_quad(st, a - side, a + side, b + side, b - side, u0, u1, color)


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
