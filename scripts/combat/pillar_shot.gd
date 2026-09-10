class_name PillarShot
extends Area3D

## Pooled solar bolt from an armed Dawnwarden pillar. Visual is the same
## GPUParticles + HDR billboard sphere as the authored Fire shots feed.
## Steal-oldest when the pool is full — never grow unbounded.

const _SHOT_MAT := preload("res://assets/vfx/mirror_fire_shot_mat.tres")
const _POOL := 48
const _STASH := Vector3(0.0, -80.0, 0.0)
const _SHOT_COLOR := Color(1.5720325, 0.9315799, 0.28894123, 1.0)
## Same visual scale as the pillar Fire shots GPUParticles (default SphereMesh).
const SHOT_SCALE := 0.35

static var _mesh: SphereMesh
static var _shape: SphereShape3D
static var _proc: ParticleProcessMaterial
static var _idle: Array[PillarShot] = []
static var _live: Array[PillarShot] = []
static var _host: Node
static var _warmed: bool = false


static func warmup(host: Node) -> void:
	_host = host
	if host != null and not host.tree_exiting.is_connected(_release):
		host.tree_exiting.connect(_release)
	_rebuild_pool()


static func _release() -> void:
	_free_pool()
	_host = null


static func _free_pool() -> void:
	for shot in _idle:
		if shot != null and is_instance_valid(shot):
			shot.queue_free()
	for shot in _live:
		if shot != null and is_instance_valid(shot):
			shot.queue_free()
	_idle.clear()
	_live.clear()
	_warmed = false


static func _rebuild_pool() -> void:
	_free_pool()
	if _host == null or not is_instance_valid(_host):
		return
	_mesh = SphereMesh.new()
	_shape = SphereShape3D.new()
	_shape.radius = 0.22
	_proc = ParticleProcessMaterial.new()
	_proc.gravity = Vector3.ZERO
	_proc.scale_min = SHOT_SCALE
	_proc.scale_max = SHOT_SCALE
	_proc.color = _SHOT_COLOR
	_warmed = true
	for _i in _POOL:
		_idle.append(_make())


static func fire(origin: Vector3, direction: Vector3, source: Unit, ignore: CollisionObject3D = null) -> void:
	if _host == null or not is_instance_valid(_host):
		return
	if direction.length_squared() < 0.0001:
		return
	var shot := _take()
	if shot == null:
		return
	shot._launch(origin, direction.normalized(), source, ignore)


static func _make() -> PillarShot:
	var shot := PillarShot.new()
	shot.monitoring = false
	shot.monitorable = false
	shot.collision_layer = 4
	shot.collision_mask = SpellWall.shot_block_mask() | 2
	var col := CollisionShape3D.new()
	col.shape = _shape
	shot.add_child(col)
	var fx := GPUParticles3D.new()
	fx.amount = 1
	fx.lifetime = 16.0
	fx.one_shot = false
	fx.explosiveness = 0.0
	fx.local_coords = true
	fx.emitting = false
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.material_override = _SHOT_MAT
	fx.draw_pass_1 = _mesh
	fx.process_material = _proc
	fx.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	shot.add_child(fx)
	shot._fx = fx
	shot.body_entered.connect(shot._on_body)
	_host.add_child(shot)
	shot.global_position = _STASH
	shot.set_physics_process(false)
	return shot


static func _take() -> PillarShot:
	var shot: PillarShot = null
	while shot == null and not _idle.is_empty():
		var candidate: PillarShot = _idle.pop_back() as PillarShot
		if candidate != null and is_instance_valid(candidate):
			shot = candidate
	if shot == null and not _live.is_empty():
		var oldest: PillarShot = _live[0]
		if oldest != null and is_instance_valid(oldest):
			oldest._sleep(false)
			shot = oldest
	if shot == null or not is_instance_valid(shot):
		return null
	_live.append(shot)
	return shot


var source: Unit
var direction: Vector3 = Vector3.FORWARD
var traveled: float = 0.0
var speed: float = 18.0
var max_distance: float = 28.0
var damage: float = 12.0
var brand_stacks: int = 1
var _armed: bool = false
var _sleep_seq: int = 0
var _fx: GPUParticles3D
var _ignore: CollisionObject3D


func _launch(origin: Vector3, dir: Vector3, src: Unit, ignore: CollisionObject3D) -> void:
	_sleep_seq += 1
	source = src
	_ignore = ignore
	direction = dir
	traveled = 0.0
	speed = CombatBalance.flat("dawnwarden.pillar.shot.speed")
	## Cross the floor. The rim check is the real despawn; this is a leak cap.
	var rim := ArenaState.arena_radius
	max_distance = maxf(CombatBalance.flat("dawnwarden.pillar.shot.range"), rim * 2.0 + 4.0)
	damage = CombatBalance.flat("dawnwarden.pillar.shot")
	brand_stacks = 1
	_armed = true
	visible = true
	monitoring = true
	global_position = origin
	if _fx != null:
		_fx.restart()
		_fx.emitting = true
	if dir.length_squared() > 0.0001 and absf(dir.dot(Vector3.UP)) < 0.98:
		look_at(origin + dir, Vector3.UP)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _armed:
		return
	var step := direction * speed * delta
	global_position += step
	traveled += step.length()
	var rim := ArenaState.arena_radius
	if rim > 0.5:
		var dx := global_position.x
		var dz := global_position.z
		if dx * dx + dz * dz >= rim * rim:
			_sleep()
			return
	if traveled >= max_distance:
		_sleep()


func _on_body(body: Node) -> void:
	if not _armed:
		return
	if body == _ignore:
		return
	if body is Unit:
		var victim := body as Unit
		if victim.team != Unit.TEAM_RAID or victim.is_dead:
			return
		if source != null and is_instance_valid(source) and victim == source:
			return
		victim.apply_world_hit(damage, source, "hit", "pillar_shot", -1, true)
		if brand_stacks > 0:
			victim.apply_judgment_brand(brand_stacks)
		_sleep()
		return
	if body is SpellWall:
		var wall := body as SpellWall
		if source != null and not wall.blocks_shot(source):
			return
		_sleep()
		return
	if body is StaticBody3D and String(body.name) != "Floor":
		_sleep()


func _sleep(return_to_pool: bool = true) -> void:
	if not _armed:
		return
	_armed = false
	_sleep_seq += 1
	var seq := _sleep_seq
	set_physics_process(false)
	visible = false
	source = null
	_ignore = null
	if _fx != null:
		_fx.emitting = false
	var idx := _live.find(self)
	if idx >= 0:
		_live.remove_at(idx)
	if return_to_pool and not _idle.has(self):
		_idle.append(self)
	call_deferred("_park", seq)


func _park(seq: int) -> void:
	if seq != _sleep_seq or _armed:
		return
	monitoring = false
	global_position = _STASH
