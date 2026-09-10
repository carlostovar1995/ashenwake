class_name ArenaPillar
extends StaticBody3D

signal destroyed(pillar: ArenaPillar)

const VISUAL_SCENE := preload("res://assets/vfx/elemental/effects/dawnwarden/mirror_pillars.tscn")
const PIECES_SCENE := preload("res://assets/vfx/elemental/effects/dawnwarden/mirror_pillars_collision.tscn")
const RISE_ANIM := &"Mirror Pillars"
const RISE_ANIM_LEN := 5.0

## Max XZ vertex radius of unscaled mirror_pillar.glb. The old 1.538 value
## was larger than the stone, so click-move and physics hugged empty air.
const RADIUS := 1.052
const HEIGHT := 5.453873
const MAX_HP := 1200.0
const _BAR_W := 1.62
const _BAR_H := 0.10
const _DEBRIS_IMPULSE := 2.6
const _DEBRIS_POOL := 3
const _DEBRIS_STASH := Vector3(0.0, -80.0, 0.0)
const _NO_YAW := 1.0e9

static var _debris_idle: Array[Node3D] = []
static var _debris_host: Node


static func warmup_debris(parent: Node) -> void:
	if parent == null:
		return
	_debris_host = parent
	if not parent.tree_exiting.is_connected(_release_debris):
		parent.tree_exiting.connect(_release_debris)
	_prune_debris()
	while _debris_idle.size() < _DEBRIS_POOL:
		var debris := _make_debris()
		if debris == null:
			return
		_stash_debris(debris)
		_debris_idle.append(debris)


static func recycle_debris(debris: Node3D) -> void:
	if debris == null or not is_instance_valid(debris):
		return
	_stash_debris(debris)
	if not _debris_idle.has(debris):
		_debris_idle.append(debris)


static func _release_debris() -> void:
	_debris_idle.clear()
	_debris_host = null


static func _prune_debris() -> void:
	var keep: Array[Node3D] = []
	for d in _debris_idle:
		if d != null and is_instance_valid(d):
			keep.append(d)
	_debris_idle = keep


static func _make_debris() -> Node3D:
	var host := _debris_host
	if host == null or not is_instance_valid(host):
		return null
	var debris := PIECES_SCENE.instantiate() as Node3D
	if debris == null:
		return null
	debris.set_script(preload("res://scripts/arena/pillar_debris.gd"))
	host.add_child(debris)
	if debris.has_method("cache_rest"):
		debris.call("cache_rest")
	debris.set("recycle", Callable(ArenaPillar, "recycle_debris"))
	return debris


static func _stash_debris(debris: Node3D) -> void:
	if debris == null or not is_instance_valid(debris):
		return
	debris.visible = false
	debris.scale = Vector3.ONE
	debris.global_position = _DEBRIS_STASH
	debris.process_mode = Node.PROCESS_MODE_DISABLED
	debris.set_physics_process(false)


var max_health: float = MAX_HP
var health: float = MAX_HP
var living: bool = false
var ring_index: int = 1
var armed: bool = false
var planted_y: float = 0.0

var _rising: bool = false
var _shape: CollisionShape3D
var _visual: Node3D
var _pillar_vis: Node3D
var _anim: AnimationPlayer
var _shot_origin: Node3D
var _mirror_mesh: MeshInstance3D
var _feed: GPUParticles3D
var _pebbles: GPUParticles3D
var _open_with_shot: bool = false
var _bar_root: Node3D
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _bar_fill: MeshInstance3D
var _bar_fill_quad: QuadMesh


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("pillars")
	_build()
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	if not living:
		return
	if (Engine.get_physics_frames() + ring_index) % 3 != 0:
		return
	_orient_bar()


func setup(index: int, pos: Vector3, hp: float = -1.0) -> void:
	name = "ObstaclePillar%d" % index
	ring_index = index
	planted_y = 0.0
	position = Vector3(pos.x, planted_y, pos.z)
	if hp > 1.0:
		max_health = hp
	health = max_health
	bury()


func half_xz() -> float:
	return RADIUS


func is_full() -> bool:
	return living and health >= max_health - 0.5


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)


func take_damage(amount: float) -> void:
	if not living or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_refresh_visual()
	if health <= 0.0:
		_die()


func _die() -> void:
	if not living:
		return
	living = false
	armed = false
	_rising = false
	_open_with_shot = false
	stop_feed()
	_stop_pebbles()
	collision_layer = 0
	_disable_shapes()
	if _bar_root:
		_bar_root.visible = false
	_hide_intact_visual()
	_spawn_debris()
	destroyed.emit(self)


func set_armed(on: bool) -> void:
	armed = on and living


func pulse_feed() -> void:
	if _feed == null or not is_instance_valid(_feed):
		return
	_feed.one_shot = true
	_feed.explosiveness = 1.0
	_feed.restart()
	_feed.emitting = true


func stop_feed() -> void:
	if _feed:
		_feed.emitting = false


func _stop_pebbles() -> void:
	if _pebbles:
		_pebbles.emitting = false


func consume_opening_shot() -> bool:
	var ready := _open_with_shot
	_open_with_shot = false
	return ready


func is_rising() -> bool:
	return _rising


func bury() -> void:
	_kill_rise()
	_rising = false
	living = false
	armed = false
	_open_with_shot = false
	stop_feed()
	_stop_pebbles()
	position.y = planted_y
	collision_layer = 0
	_disable_shapes()
	if _bar_root:
		_bar_root.visible = false
	_show_intact_visual()
	_seek_rise(0.0)


func begin_rise(duration: float) -> void:
	_kill_rise()
	_rising = true
	living = false
	armed = false
	_open_with_shot = false
	health = max_health
	_show_intact_visual()
	if _bar_root:
		_bar_root.visible = false
	collision_layer = 0
	_disable_shapes()
	position.y = planted_y
	_play_rise(duration)


func plant() -> void:
	if not _rising:
		return
	_kill_rise()
	_rising = false
	position.y = planted_y
	if is_inside_tree():
		reset_physics_interpolation()
	## Snap to the seated pose without replaying from 0 — a rewind would
	## restart Fire shots and kill the 4.5s drop already in flight.
	if _anim != null:
		if _anim.current_animation != String(RISE_ANIM):
			_anim.play(RISE_ANIM)
		_anim.speed_scale = 1.0
		_anim.seek(RISE_ANIM_LEN, true)
		_anim.stop(true)
	if _feed:
		_feed.emitting = false
	_open_with_shot = true
	## Collision stays off until occupants are on the rim. Enabling a 5m cylinder
	## around a CharacterBody3D turns one physics frame of overlap into a launch.
	_clear_occupants()
	living = true
	health = max_health
	collision_layer = 1
	_enable_shapes()
	if _bar_root:
		_bar_root.visible = true
	set_armed(true)
	_refresh_visual()
	if is_inside_tree():
		reset_physics_interpolation()


func shot_origin() -> Vector3:
	## Combat bolts leave the seated glass, not the feed orb on the shaft cap.
	if _mirror_mesh != null and is_instance_valid(_mirror_mesh):
		return _mirror_mesh.to_global(_mirror_mesh.get_aabb().get_center())
	if _shot_origin != null and is_instance_valid(_shot_origin):
		return _shot_origin.global_position
	var mirror := _visual.get_node_or_null("Pillar/Mirror") as Node3D if _visual else null
	if mirror != null and is_instance_valid(mirror):
		return mirror.to_global(Vector3(0.0, 0.78, 0.16))
	return global_position + Vector3(0.0, 1.25, 0.0)


## Yaw the seated mesh so the mirror face (+Z) matches a flat fire direction.
## No-op during Raise Pillars — the rise clip owns Pillar.rotation.
func aim_along(dir: Vector3) -> void:
	if _rising or _pillar_vis == null:
		return
	var yaw := _face_yaw(dir)
	if yaw == _NO_YAW:
		return
	_pillar_vis.rotation.y = yaw


func turn_toward(dir: Vector3, delta: float, radians_per_sec: float) -> void:
	if _rising or _pillar_vis == null:
		return
	var yaw := _face_yaw(dir)
	if yaw == _NO_YAW:
		return
	_pillar_vis.rotation.y = rotate_toward(
		_pillar_vis.rotation.y, yaw, maxf(radians_per_sec, 0.0) * delta
	)


static func _face_yaw(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return _NO_YAW
	flat = flat.normalized()
	## Seated mirror looks along local +Z (tilted up). Align that with `dir`.
	return atan2(flat.x, flat.z)


func _kill_rise() -> void:
	if _anim != null and _anim.is_playing():
		_anim.pause()


func _play_rise(duration: float) -> void:
	if _anim == null:
		return
	_anim.speed_scale = RISE_ANIM_LEN / maxf(duration, 0.05)
	if _feed:
		_feed.emitting = false
	_anim.play(RISE_ANIM)
	_anim.seek(0.0, true)


func _seek_rise(time: float) -> void:
	if _anim == null:
		return
	_anim.speed_scale = 1.0
	_anim.play(RISE_ANIM)
	_anim.seek(clampf(time, 0.0, RISE_ANIM_LEN), true)
	_anim.pause()
	if _feed and time < 4.5:
		_feed.emitting = false
	if time <= 0.0:
		_stop_pebbles()


func _build() -> void:
	_make_collision()
	_adopt_visual()
	_build_hp_bar()


func _make_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	col.shape = cyl
	col.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	_shape = col
	add_child(col)


func _adopt_visual() -> void:
	_visual = VISUAL_SCENE.instantiate() as Node3D
	if _visual == null:
		push_error("ArenaPillar: mirror_pillars.tscn failed to instantiate")
		return
	add_child(_visual)
	_anim = _visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
	_pillar_vis = _visual.get_node_or_null("Pillar") as Node3D
	_shot_origin = _visual.get_node_or_null("Pillar/Mirror/ShotOrigin") as Node3D
	_mirror_mesh = _find_mirror_mesh()
	if _shot_origin == null:
		var mirror := _visual.get_node_or_null("Pillar/Mirror") as Node3D
		if mirror != null:
			_shot_origin = Marker3D.new()
			_shot_origin.name = "ShotOrigin"
			mirror.add_child(_shot_origin)
			_shot_origin.position = Vector3(0.0, 0.78, 0.16)
	_feed = _visual.get_node_or_null("Pillar/Fire shots") as GPUParticles3D
	_pebbles = _visual.get_node_or_null("Small Debris") as GPUParticles3D
	if _pebbles:
		_pebbles.emitting = false
	if _feed:
		_feed.one_shot = true
		_feed.explosiveness = 1.0
		_feed.emitting = false
		var pm := _feed.process_material as ParticleProcessMaterial
		if pm:
			pm.scale_min = PillarShot.SHOT_SCALE
			pm.scale_max = PillarShot.SHOT_SCALE
			pm.scale_curve = null
	var rumble := _visual.get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
	if rumble:
		## Packed-scene preview keys this at t=0. Ten ring copies would stack;
		## Arena.raise_dawnwarden_pillars plays the catalog clip once instead.
		rumble.stream = null


func _find_mirror_mesh() -> MeshInstance3D:
	if _visual == null:
		return null
	var named := _visual.get_node_or_null("Pillar/Mirror/Mirror") as MeshInstance3D
	if named != null:
		return named
	var mirror := _visual.get_node_or_null("Pillar/Mirror") as Node3D
	if mirror == null:
		return null
	for child in mirror.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _clear_occupants() -> void:
	var center := global_position
	for raw in ArenaState.units_near(center, RADIUS, false, true, true):
		var unit := raw as Unit
		if unit == null or not is_instance_valid(unit) or unit.is_dead:
			continue
		_slide_unit_off(unit)


func _slide_unit_off(unit: Unit) -> void:
	var dx := unit.global_position.x - global_position.x
	var dz := unit.global_position.z - global_position.z
	var dist := sqrt(dx * dx + dz * dz)
	var need := RADIUS + maxf(unit.radius, 0.4) + 0.16
	if dist >= need:
		return
	var dir_x := global_position.x
	var dir_z := global_position.z
	if dist > 0.001:
		dir_x = dx / dist
		dir_z = dz / dist
	elif dir_x * dir_x + dir_z * dir_z > 0.01:
		var from_center := sqrt(dir_x * dir_x + dir_z * dir_z)
		dir_x /= from_center
		dir_z /= from_center
	else:
		dir_x = 1.0
		dir_z = 0.0
	var dest := Vector3(
		global_position.x + dir_x * need,
		unit.global_position.y,
		global_position.z + dir_z * need
	)
	var arena := ArenaState.arena as Arena
	if arena:
		dest = arena.clamp_movement_point(dest, maxf(unit.radius, 0.4))
		dest.y = unit.global_position.y
	unit.global_position = dest
	unit.velocity = Vector3.ZERO
	if unit.is_inside_tree():
		unit.reset_physics_interpolation()


func _disable_shapes() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true


func _enable_shapes() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false


func _hide_intact_visual() -> void:
	if _visual:
		_visual.visible = false
	if _feed:
		_feed.emitting = false
	_stop_pebbles()


func _show_intact_visual() -> void:
	if _visual:
		_visual.visible = true


func _spawn_debris() -> void:
	var debris := _take_debris()
	if debris == null:
		push_error("ArenaPillar: pillar debris pool failed")
		return
	debris.global_position = global_position
	debris.global_basis = global_basis
	var pillar_vis := _visual.get_node_or_null("Pillar") as Node3D
	if pillar_vis != null and is_instance_valid(pillar_vis):
		debris.rotation.y = pillar_vis.global_rotation.y
	debris.scale = Vector3.ONE
	if debris.has_method("arm"):
		debris.call("arm")
	_arm_debris(debris)


static func _take_debris() -> Node3D:
	var debris: Node3D = null
	while debris == null and not _debris_idle.is_empty():
		var candidate: Node3D = _debris_idle.pop_back()
		if candidate != null and is_instance_valid(candidate):
			debris = candidate
	if debris == null:
		debris = _make_debris()
	if debris == null:
		return null
	debris.process_mode = Node.PROCESS_MODE_INHERIT
	return debris


func _arm_debris(root: Node) -> void:
	var origin := global_position + Vector3(0.0, HEIGHT * 0.4, 0.0)
	_kick_bodies(root, origin)


func _kick_bodies(n: Node, origin: Vector3) -> void:
	for child in n.get_children():
		var rb := child as RigidBody3D
		if rb == null:
			_kick_bodies(child, origin)
			continue
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.can_sleep = true
		var kick_at := rb.global_position
		for mesh_n in rb.get_children():
			if mesh_n is Node3D:
				kick_at = (mesh_n as Node3D).global_position
				break
		var away := kick_at - origin
		away.y = maxf(away.y, 0.2)
		if away.length_squared() < 0.0001:
			away = Vector3(0.0, 1.0, 0.0)
		rb.apply_central_impulse(away.normalized() * _DEBRIS_IMPULSE)
		rb.apply_torque_impulse(Vector3(
			randf_range(-0.8, 0.8),
			randf_range(-0.8, 0.8),
			randf_range(-0.8, 0.8)
		))


func _build_hp_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "PillarHpBar"
	_bar_root.top_level = true
	add_child(_bar_root)
	_bar = _make_bar_quad("HpBg", Vector2(_BAR_W + 0.10, _BAR_H + 0.05), Color(0.08, 0.07, 0.06), 0.0)
	_bar_root.add_child(_bar)
	_bar_fill_quad = QuadMesh.new()
	_bar_fill_quad.size = Vector2(_BAR_W, _BAR_H)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.name = "HpFill"
	_bar_fill.mesh = _bar_fill_quad
	_bar_fill.position.z = 0.004
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.albedo_color = Color(0.35, 0.85, 0.4)
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.emission_enabled = true
	_bar_mat.emission = Color(0.3, 0.8, 0.35)
	_bar_mat.emission_energy_multiplier = 1.2
	_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_bar_mat.no_depth_test = true
	_bar_mat.disable_receive_shadows = true
	_bar_mat.render_priority = 10
	_bar_fill.material_override = _bar_mat
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(_bar_fill)
	_orient_bar()


func _make_bar_quad(quad_name: String, size: Vector2, color: Color, z: float) -> MeshInstance3D:
	return WorldUiMesh.quad(quad_name, size, color, 8, false, z)


func _bar_world_pos() -> Vector3:
	return global_position + Vector3(0.0, HEIGHT + 0.45, 0.0)


func _orient_bar() -> void:
	if _bar_root == null or not is_instance_valid(_bar_root):
		return
	var pos := _bar_world_pos()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		_bar_root.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	var z := cam.global_position - pos
	if z.length_squared() < 0.0001:
		_bar_root.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	z = z.normalized()
	var x := cam.global_transform.basis.y.cross(z)
	if x.length_squared() < 0.0001:
		x = cam.global_transform.basis.x
	x = x.normalized()
	var y := z.cross(x).normalized()
	_bar_root.global_transform = Transform3D(Basis(x, y, z), pos)


func _refresh_visual() -> void:
	if not living:
		return
	var r := health_ratio()
	if _bar_fill and _bar_fill_quad != null:
		var w := _BAR_W * maxf(r, 0.001)
		_bar_fill_quad.size = Vector2(w, _BAR_H)
		_bar_fill.position = Vector3((w - _BAR_W) * 0.5, 0.0, 0.004)
	if _bar_mat:
		_bar_mat.albedo_color = Color(0.9, 0.28, 0.18).lerp(Color(0.35, 0.85, 0.4), r)
		_bar_mat.emission = _bar_mat.albedo_color
