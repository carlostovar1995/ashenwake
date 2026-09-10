class_name SolarCollapseFx
extends Node3D

const PACKED := preload("res://assets/vfx/elemental/effects/dawnwarden/solar_collapse_spell.tscn")
## Clip name is authored with this spelling in the VFX scene.
## Edit charge, blast scale, explode rim, aura hide, and fade on that clip.
const ANIM_NAME := &"Solar Collpase Animation"
const _STASH := Vector3(0.0, -80.0, 0.0)
const _LIGHT_ENERGY_MAX := 5.5
const _LIGHT_RANGE_MAX := 11.0
## Default SphereMesh radius is 0.5, so scale 80 ≈ 40m. Author the blast on
## Meshes:scale; this only stops a 500x key from filling the GPU.
const _MESH_SCALE_MAX := 80.0
const _SHADOW_Y := 0.06
const _SHADOW_LEN_MIN := 4.5
const _SHADOW_LEN_MAX := 13.0
const _SHADOW_ALPHA_MIN := 0.06
const _SHADOW_ALPHA_MAX := 0.78
const _SHADOW_HZ := 15.0
## Shadow.png is a white trapezoid, wide at texture top. Godot decals map
## v = 0 to local +Z. Opaque stamp is the visible black ground blob.
const _STAMP_V0 := 0.07
const _STAMP_V1 := 0.88
const _STAMP_HW0 := 0.33
const _STAMP_HW1 := 0.11

var _follow: Node3D
var _elapsed: float = 0.0
var _materials: Array[ShaderMaterial] = []
var _lights: Array[OmniLight3D] = []
var _playing: bool = false
var _meshes: Node3D
var _player: AnimationPlayer
var _pillar_shadows: Node3D
var _shadow_decals: Array[Decal] = []
var _shadows: Array[MeshInstance3D] = []
var _shadow_wait: float = 0.0

static var _pooled: SolarCollapseFx
static var _live: SolarCollapseFx
static var _host: Node
static var _shadow_mesh: ArrayMesh
static var _shadow_mat: StandardMaterial3D


static func warmup(parent: Node) -> void:
	if parent == null:
		return
	_host = parent
	if not parent.tree_exiting.is_connected(_release):
		parent.tree_exiting.connect(_release)
	if _pooled != null and is_instance_valid(_pooled):
		return
	if _live != null and is_instance_valid(_live):
		return
	var fx := PACKED.instantiate() as SolarCollapseFx
	if fx == null:
		return
	parent.add_child(fx)
	_pooled = fx
	fx._ensure_shadows()


static func _release() -> void:
	_pooled = null
	_live = null
	_host = null


static func spawn(follow: Node3D) -> SolarCollapseFx:
	var parent: Node = _host
	if parent == null or not is_instance_valid(parent):
		parent = ArenaState.arena
		if parent:
			var fx_root := parent.get_node_or_null("FxRoot")
			if fx_root:
				parent = fx_root
	if parent == null:
		parent = Engine.get_main_loop().root
	var fx := _pooled if _pooled != null and is_instance_valid(_pooled) else null
	if fx == null and _live != null and is_instance_valid(_live):
		fx = _live
	if fx == null:
		warmup(parent)
		fx = _pooled
	if fx == null or not is_instance_valid(fx):
		return null
	_pooled = null
	_live = fx
	fx.setup(follow)
	fx._play()
	return fx


func setup(follow: Node3D) -> void:
	_follow = follow


static func covers_world(pos: Vector3) -> bool:
	var fx := _fx()
	if fx == null:
		return false
	return fx._covers_world(pos)


static func cover_point_for_pillar(pillar: ArenaPillar, unit_radius: float) -> Vector3:
	var fx := _fx()
	if fx == null or pillar == null or not is_instance_valid(pillar) or not pillar.living:
		return Vector3.ZERO
	return fx._cover_point_for_pillar(pillar, unit_radius)


static func _fx() -> SolarCollapseFx:
	if _live != null and is_instance_valid(_live):
		return _live
	if _pooled != null and is_instance_valid(_pooled):
		return _pooled
	return null


func _ready() -> void:
	_meshes = get_node_or_null("Meshes") as Node3D
	_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	_pillar_shadows = get_node_or_null("Pillar Shadows") as Node3D
	_collect_decals()
	_collect_fx(self)
	_detach_lights()
	if _player and not _player.animation_finished.is_connected(_on_anim_finished):
		_player.animation_finished.connect(_on_anim_finished)
	if _playing:
		return
	_run_compile()


func _run_compile() -> void:
	visible = true
	global_position = _STASH
	_hide_shadows()
	_sync_decal_visibility()
	if _meshes:
		_meshes.scale = Vector3.ONE
		_meshes.position = Vector3(0.0, 2.2, -2.8)
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		light.light_energy = 0.2
		light.omni_range = 4.0
		light.shadow_enabled = false
		light.visible = true
	set_process(false)
	_hide_shadows()
	var tree := get_tree()
	if tree:
		await tree.process_frame
		await tree.process_frame
	if _playing:
		return
	_stash()
	_pooled = self


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_snap_to_follow()
	_clamp_drawn()
	_sync_decal_visibility()
	if _pillar_shadows == null:
		_maybe_update_shadows(delta, false)
	if _player != null and _player.has_animation(ANIM_NAME):
		var clip := _player.get_animation(ANIM_NAME)
		if clip != null and _elapsed > clip.length + 0.4:
			_on_anim_finished(ANIM_NAME)


func _on_anim_finished(anim_name: StringName) -> void:
	if not _playing or anim_name != ANIM_NAME:
		return
	_stash()
	_live = null
	_pooled = self


func _play() -> void:
	_elapsed = 0.0
	_playing = true
	_shadow_wait = 0.0
	_set_fx_params(1.0, 0.0)
	visible = true
	set_process(true)
	_snap_to_follow()
	_sync_decal_visibility()
	if _player:
		_player.stop()
		_player.play(ANIM_NAME)
	if _pillar_shadows == null:
		_update_shadows()


func _stash() -> void:
	_playing = false
	_follow = null
	_elapsed = 0.0
	visible = false
	set_process(false)
	_hide_shadows()
	_sync_decal_visibility()
	global_position = _STASH
	_set_fx_params(1.0, 0.0)
	if _meshes:
		_meshes.scale = Vector3(0.1, 0.1, 0.1)
		_meshes.position = Vector3(0.0, 2.2, -2.8)
	var aura := get_node_or_null("Meshes/Solar Collapse Aura") as MeshInstance3D
	if aura:
		aura.visible = true
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		light.light_energy = 0.05
		light.omni_range = 2.0
		light.shadow_enabled = false
		light.visible = false
	if _player:
		_player.stop()
		_player.seek(0.0, true)


func _snap_to_follow() -> void:
	if _follow == null or not is_instance_valid(_follow):
		_pin_pillar_shadows()
		return
	# Root stays unscaled at the boss feet so Meshes position/scale keys stay in meters.
	global_position = _follow.global_position
	# Pin before rotating so the 10 ground decals never inherit a look_at basis.
	# look_at on a bad forward prints invert det==0 for every child instance.
	_pin_pillar_shadows()
	var forward := Vector3.FORWARD
	if _follow is Unit:
		forward = (_follow as Unit).facing_dir()
	else:
		forward = -_follow.global_transform.basis.z
	forward.y = 0.0
	if not forward.is_finite() or forward.length_squared() < 0.0001:
		return
	var b := Basis.looking_at(forward.normalized(), Vector3.UP)
	if not b.x.is_finite() or not b.y.is_finite() or not b.z.is_finite():
		return
	global_transform = Transform3D(b, global_position)
	_pin_pillar_shadows()


func _pin_pillar_shadows() -> void:
	if _pillar_shadows == null or not is_instance_valid(_pillar_shadows):
		return
	# Authored in arena space. Keep them there while the sun root faces the boss.
	_pillar_shadows.top_level = true
	var origin := Vector3.ZERO
	var arena := ArenaState.arena as Node3D
	if arena != null:
		origin = arena.global_position
	_pillar_shadows.global_position = origin
	_pillar_shadows.global_rotation = Vector3.ZERO


func _collect_decals() -> void:
	_shadow_decals.clear()
	if _pillar_shadows == null:
		return
	for child in _pillar_shadows.get_children():
		if child is Decal:
			_shadow_decals.append(child as Decal)


func _sync_decal_visibility() -> void:
	if _shadow_decals.is_empty():
		_collect_decals()
	if _pillar_shadows != null and is_instance_valid(_pillar_shadows):
		_pillar_shadows.visible = _playing
	var pillars: Array[ArenaPillar] = []
	var arena := ArenaState.arena as Arena
	if arena:
		pillars = arena.all_pillars()
	for decal in _shadow_decals:
		if decal == null or not is_instance_valid(decal):
			continue
		var pillar := _pillar_for_decal(decal, pillars)
		decal.visible = _playing and pillar != null and pillar.living


func _covers_world(pos: Vector3) -> bool:
	if _shadow_decals.is_empty():
		_collect_decals()
	var pillars: Array[ArenaPillar] = []
	var arena := ArenaState.arena as Arena
	if arena:
		pillars = arena.all_pillars()
	for decal in _shadow_decals:
		if decal == null or not is_instance_valid(decal):
			continue
		var pillar := _pillar_for_decal(decal, pillars)
		if pillar == null or not pillar.living:
			continue
		if _point_in_stamp(decal, pos):
			return true
	return false


func _cover_point_for_pillar(pillar: ArenaPillar, unit_radius: float) -> Vector3:
	if _shadow_decals.is_empty():
		_collect_decals()
	var decal := _decal_for_pillar(pillar)
	if decal == null:
		return Vector3.ZERO
	var xf := _stamp_xform(decal)
	var s := decal.size
	if s.z < 0.001:
		return Vector3.ZERO
	var local_p := _to_stamp_local(xf, pillar.global_position)
	var dist := pillar.half_xz() + unit_radius + 0.95
	var local := Vector3(0.0, 0.0, local_p.z - dist)
	var v := -local.z / s.z + 0.5
	v = clampf(v, 0.18, 0.55)
	local.z = -(v - 0.5) * s.z
	var dest := xf * local
	dest.y = 0.1
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.clamp_movement_point(dest, unit_radius + 0.08)
	return dest


func _pillar_for_decal(decal: Decal, pillars: Array[ArenaPillar]) -> ArenaPillar:
	if decal == null or pillars.is_empty():
		return null
	var o := _stamp_xform(decal).origin
	var best: ArenaPillar = null
	var best_d := INF
	for pillar in pillars:
		if pillar == null or not is_instance_valid(pillar):
			continue
		var d := Vector2(o.x - pillar.global_position.x, o.z - pillar.global_position.z).length_squared()
		if d < best_d:
			best_d = d
			best = pillar
	return best


func _decal_for_pillar(pillar: ArenaPillar) -> Decal:
	if pillar == null:
		return null
	var p := Vector2(pillar.global_position.x, pillar.global_position.z)
	var best: Decal = null
	var best_d := INF
	for decal in _shadow_decals:
		if decal == null or not is_instance_valid(decal):
			continue
		var o := _stamp_xform(decal).origin
		var d := Vector2(o.x - p.x, o.z - p.y).length_squared()
		if d < best_d:
			best_d = d
			best = decal
	return best


func _stamp_xform(decal: Decal) -> Transform3D:
	# Authored in arena space. Use local pose so cover still matches if the
	# FX root is stashed or the boss look_at has not pinned the parent yet.
	var origin := Vector3.ZERO
	var arena := ArenaState.arena as Node3D
	if arena:
		origin = arena.global_position
	var xf := decal.transform
	xf.origin = origin + xf.origin
	return xf


func _to_stamp_local(xf: Transform3D, world: Vector3) -> Vector3:
	# Authored decal poses are rotation+translation. Transpose avoids
	# Transform3D.affine_inverse(), which ERROR-spams when det is 0.
	var rel := world - xf.origin
	var b := xf.basis
	return Vector3(b.x.dot(rel), b.y.dot(rel), b.z.dot(rel))


func _point_in_stamp(decal: Decal, world: Vector3) -> bool:
	var xf := _stamp_xform(decal)
	var local := _to_stamp_local(xf, world)
	var s := decal.size
	if s.x < 0.001 or s.z < 0.001:
		return false
	var u := local.x / s.x + 0.5
	var v := -local.z / s.z + 0.5
	if v < _STAMP_V0 or v > _STAMP_V1:
		return false
	var t := (v - _STAMP_V0) / (_STAMP_V1 - _STAMP_V0)
	var hw := lerpf(_STAMP_HW0, _STAMP_HW1, t)
	return absf(u - 0.5) <= hw


func _clamp_drawn() -> void:
	if _meshes:
		var s := _meshes.scale
		var mx := maxf(s.x, 0.05)
		var my := maxf(s.y, 0.05)
		var mz := maxf(s.z, 0.05)
		mx = minf(mx, _MESH_SCALE_MAX)
		my = minf(my, _MESH_SCALE_MAX)
		mz = minf(mz, _MESH_SCALE_MAX)
		if mx != s.x or my != s.y or mz != s.z:
			_meshes.scale = Vector3(mx, my, mz)
	var sun := _sun_xz()
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		light.top_level = true
		light.global_position = sun
		light.global_basis = Basis.IDENTITY
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.light_volumetric_fog_energy = 0.0
		light.omni_range = minf(light.omni_range, _LIGHT_RANGE_MAX)
		light.light_energy = minf(light.light_energy, _LIGHT_ENERGY_MAX)
		light.visible = _playing


func _collect_fx(n: Node) -> void:
	if n is GeometryInstance3D:
		var gi := n as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var mat := gi.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("fade_alpha", 1.0)
			mat.set_shader_parameter("explode", 0.0)
			_materials.append(mat)
	elif n is OmniLight3D:
		var light := n as OmniLight3D
		light.shadow_enabled = false
		light.light_specular = 0.0
		light.light_volumetric_fog_energy = 0.0
		_lights.append(light)
	for child in n.get_children():
		_collect_fx(child)


func _detach_lights() -> void:
	for light in _lights:
		if light == null or not is_instance_valid(light):
			continue
		light.top_level = true
		light.shadow_enabled = false


func _set_fx_params(alpha: float, explode: float) -> void:
	for mat in _materials:
		if mat == null:
			continue
		mat.set_shader_parameter("fade_alpha", alpha)
		mat.set_shader_parameter("explode", explode)


static func _ensure_shadow_res() -> void:
	if _shadow_mesh != null and _shadow_mat != null:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(-0.5, 0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, -1.0))
	st.add_vertex(Vector3(0.5, 0.0, 0.0))
	st.add_vertex(Vector3(0.5, 0.0, 0.0))
	st.add_vertex(Vector3(0.0, 0.0, -1.0))
	st.add_vertex(Vector3(-0.5, 0.0, 0.0))
	_shadow_mesh = st.commit()
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_color = Color(0.03, 0.04, 0.08, _SHADOW_ALPHA_MIN)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow_mat.disable_receive_shadows = true


func _ensure_shadows() -> void:
	_ensure_shadow_res()
	var parent: Node = _host if _host != null and is_instance_valid(_host) else get_parent()
	if parent == null:
		return
	var n := 10
	var arena := ArenaState.arena as Arena
	if arena:
		n = maxi(arena.all_pillars().size(), 1)
	while _shadows.size() < n:
		var mi := MeshInstance3D.new()
		mi.mesh = _shadow_mesh
		mi.material_override = _shadow_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		mi.visible = false
		parent.add_child(mi)
		_shadows.append(mi)


func _hide_shadows() -> void:
	for mi in _shadows:
		if mi != null and is_instance_valid(mi):
			mi.visible = false


func _sun_xz() -> Vector3:
	if _meshes != null and is_instance_valid(_meshes):
		return _meshes.global_position
	for light in _lights:
		if light != null and is_instance_valid(light):
			return light.global_position
	return global_position


func _sun_energy_u() -> float:
	var energy := 0.0
	for light in _lights:
		if light != null and is_instance_valid(light):
			energy = maxf(energy, light.light_energy)
	return clampf(energy / _LIGHT_ENERGY_MAX, 0.0, 1.0)


func _maybe_update_shadows(delta: float, force: bool) -> void:
	_shadow_wait -= delta
	if not force and _shadow_wait > 0.0:
		return
	_shadow_wait = 1.0 / _SHADOW_HZ
	_update_shadows()


func _update_shadows() -> void:
	_ensure_shadows()
	var arena := ArenaState.arena as Arena
	if arena == null:
		_hide_shadows()
		return
	var u := _sun_energy_u()
	if _shadow_mat:
		_shadow_mat.albedo_color = Color(0.03, 0.04, 0.08, lerpf(_SHADOW_ALPHA_MIN, _SHADOW_ALPHA_MAX, u))
	var sun := _sun_xz()
	var length := lerpf(_SHADOW_LEN_MIN, _SHADOW_LEN_MAX, u)
	var pillars := arena.all_pillars()
	for i in _shadows.size():
		var mi := _shadows[i]
		if mi == null or not is_instance_valid(mi):
			continue
		var pillar := pillars[i] if i < pillars.size() else null
		if pillar == null or not is_instance_valid(pillar) or not pillar.living:
			mi.visible = false
			continue
		var away := Vector3(pillar.global_position.x - sun.x, 0.0, pillar.global_position.z - sun.z)
		if not away.is_finite() or away.length_squared() < 0.04:
			mi.visible = false
			continue
		away = away.normalized()
		var half := pillar.half_xz()
		var start := Vector3(pillar.global_position.x, _SHADOW_Y, pillar.global_position.z) + away * half
		mi.visible = true
		mi.scale = Vector3.ONE
		mi.global_position = start
		var look := start + away
		if Vector2(look.x - start.x, look.z - start.z).length_squared() > 0.0001:
			mi.look_at(Vector3(look.x, start.y, look.z), Vector3.UP)
		mi.scale = Vector3(half * 2.0, 1.0, length)
