class_name AbilityFx
extends Object

const FIRE_PROJECTILE := "res://assets/vfx/elemental/effects/projectile/vfx_fire_projectile_01.tscn"
const FIREBALL := "res://assets/vfx/projectiles/fireball/fireball.tscn"
const FIRE_AREA := "res://assets/vfx/elemental/effects/area/vfx_fire_area_01.tscn"
const FIRE_CAST := "res://assets/vfx/elemental/effects/cast/vfx_fire_cast_01.tscn"
const GROUND_EXPLOSION := "res://assets/vfx/explosion/effects/ground/vfx_ground_explosion_01.tscn"
const MAGIC_BOLT := "res://assets/vfx/projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn"
const MAGIC_JAVELIN := "res://assets/vfx/projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn"

const _PACK_FIRE_PROJECTILE := preload("res://assets/vfx/elemental/effects/projectile/vfx_fire_projectile_01.tscn")
const _PACK_FIREBALL := preload("res://assets/vfx/projectiles/fireball/fireball.tscn")
const _PACK_FIRE_AREA := preload("res://assets/vfx/elemental/effects/area/vfx_fire_area_01.tscn")
const _PACK_FIRE_CAST := preload("res://assets/vfx/elemental/effects/cast/vfx_fire_cast_01.tscn")
const _PACK_GROUND_EXPLOSION := preload("res://assets/vfx/explosion/effects/ground/vfx_ground_explosion_01.tscn")
const _PACK_MAGIC_BOLT := preload("res://assets/vfx/projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn")
const _PACK_MAGIC_JAVELIN := preload("res://assets/vfx/projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn")
const _HERO_LIGHTS := preload("res://scripts/visual/fx_hero_lights.gd")

const GROUP_BODY := "fx_body"
const GROUP_PERSIST := "fx_persist"
const _POOL_SIZE := 10
const _LINGER_CAP := 24
const _LINGER_MAX := 3.0
const _LIGHT_ENERGY_MAX := 8.0
const _LIGHT_RANGE_MIN := 1.5
const _LIGHT_RANGE_MAX := 14.0
const _STASH := Vector3(0.0, -80.0, 0.0)
const _POOL_PATHS: PackedStringArray = [
	GROUND_EXPLOSION,
	FIRE_AREA,
	FIRE_CAST,
	FIRE_PROJECTILE,
	MAGIC_BOLT,
	MAGIC_JAVELIN,
]

static var _warmed: bool = false
static var _pools: Dictionary = {}
static var _steal: Dictionary = {}
static var _lingers: Array[Node3D] = []
static var _binds: Dictionary = {}


static func is_warmed() -> bool:
	return _warmed


static func packed_scene(path: String) -> PackedScene:
	match path:
		FIRE_PROJECTILE:
			return _PACK_FIRE_PROJECTILE
		FIREBALL:
			return _PACK_FIREBALL
		FIRE_AREA:
			return _PACK_FIRE_AREA
		FIRE_CAST:
			return _PACK_FIRE_CAST
		GROUND_EXPLOSION:
			return _PACK_GROUND_EXPLOSION
		MAGIC_BOLT:
			return _PACK_MAGIC_BOLT
		MAGIC_JAVELIN:
			return _PACK_MAGIC_JAVELIN
		_:
			if path.is_empty() or not ResourceLoader.exists(path):
				return null
			return load(path) as PackedScene


static func exists(path: String) -> bool:
	return packed_scene(path) != null


static func _host() -> Node:
	var arena: Node = ArenaState.arena
	if arena:
		var fx_root := arena.get_node_or_null("FxRoot")
		if fx_root:
			return fx_root
		return arena
	return Engine.get_main_loop().root


static func warmup(parent: Node) -> void:
	if parent == null:
		return
	if parent.get_node_or_null("FxHeroLights") == null:
		var hero: Node = _HERO_LIGHTS.new()
		hero.name = "FxHeroLights"
		parent.add_child(hero)
	_HERO_LIGHTS.ensure(parent)
	_prune_pools()
	_prune_lingers()
	_prune_binds()
	_warmed = true
	for path in _POOL_PATHS:
		_fill_pool(path, parent)
	for path in SpellVfxSlots.pool_paths():
		if path in _POOL_PATHS:
			continue
		_fill_pool(path, parent)
	var explosions: Array = _pools.get(GROUND_EXPLOSION, [])
	if not explosions.is_empty():
		var first := _alive(explosions[0])
		if first:
			_play_node(first, _STASH, {"scale": 0.05, "lifetime": 0.35, "hero_light": false}, true)
	for path in [FIRE_AREA, FIRE_CAST]:
		play_at(path, _STASH, {"scale": 0.05, "lifetime": 0.35, "hero_light": false})


static func play_at(path: String, pos: Vector3, cfg: Dictionary = {}) -> Node3D:
	var pooled := _acquire(path)
	if pooled:
		return _play_node(pooled, pos, cfg, true)
	var fx := _make_instance(path)
	if fx == null:
		return null
	_host().add_child(fx)
	return _play_node(fx, pos, cfg, false)


## Follow-bind travel VFX onto FxRoot. The gameplay host is not the scene parent.
## Scene OmniLights are copied into the hero-light pool; the authored nodes stay muted.
static func attach(path: String, host: Node3D, cfg: Dictionary = {}) -> Node3D:
	if host == null:
		return null
	var root := travel_root(host)
	if root == null:
		return null
	var fx := _make_instance(path)
	if fx == null:
		return null
	if "one_shot" in fx:
		fx.set("one_shot", false)
	if "autoplay" in fx:
		fx.set("autoplay", true)
	root.add_child(fx)
	fx.position = Vector3.ZERO
	var yaw := float(cfg.get("yaw_offset", 0.0))
	if yaw != 0.0:
		fx.rotate_y(yaw)
	var sc: float = float(cfg.get("scale", 1.0))
	if sc != 1.0:
		fx.scale = Vector3.ONE * sc
	_tint(fx, cfg)
	var authored := _authored_light(fx)
	_mute_omni_lights(fx)
	if bool(cfg.get("bind_light", true)):
		_bind_travel_light(host, authored, cfg, sc)
	return fx


## Travel bundle for a gameplay host. Creates the follow bind on first use.
static func travel_root(host: Node3D) -> Node3D:
	if host == null or not is_instance_valid(host):
		return null
	var rec: Variant = _binds.get(host.get_instance_id())
	if rec is Dictionary:
		var existing := _alive(rec.get("bundle"))
		if existing:
			return existing
	return _make_bind(host)


## Hide travel body and let persist emitters finish. Caller frees the gameplay host.
static func finish(host: Node3D) -> void:
	if host == null or not is_instance_valid(host):
		return
	_finish_id(host.get_instance_id())


static func _make_instance(path: String) -> Node3D:
	var packed := packed_scene(path)
	if packed == null:
		return null
	var fx := packed.instantiate() as Node3D
	if fx == null:
		return null
	if "autoplay" in fx:
		fx.set("autoplay", false)
	return fx


static func _play_node(fx: Node3D, pos: Vector3, cfg: Dictionary, pooled: bool) -> Node3D:
	fx.visible = true
	fx.process_mode = Node.PROCESS_MODE_INHERIT
	fx.scale = Vector3.ONE
	fx.rotation = Vector3.ZERO
	fx.global_position = pos
	var look: Vector3 = cfg.get("look", Vector3.ZERO)
	if look.length_squared() > 0.0001:
		var target := pos + Vector3(look.x, 0.0, look.z)
		if target.distance_squared_to(pos) > 0.0001:
			fx.look_at(target, Vector3.UP)
	var yaw := float(cfg.get("yaw_offset", 0.0))
	if yaw != 0.0:
		fx.rotate_y(yaw)
	var sc: float = float(cfg.get("scale", 1.0))
	if sc != 1.0:
		fx.scale = Vector3.ONE * sc
	_tint(fx, cfg)
	if "area_radius" in fx and cfg.has("area_radius"):
		fx.set("area_radius", float(cfg["area_radius"]))
	if "one_shot" in fx:
		fx.set("one_shot", true)
	if fx.has_method("play"):
		fx.call("play")
	elif fx.has_method("open"):
		fx.call("open")
	for child in fx.get_children():
		if child is GPUParticles3D:
			var p := child as GPUParticles3D
			p.restart()
			p.emitting = true
	var authored := _authored_light(fx)
	_mute_omni_lights(fx)
	if bool(cfg.get("hero_light", true)) and pos.y > -40.0:
		_pulse_hero_light(pos, authored, cfg, sc)
	var lifetime := float(cfg.get("lifetime", 2.4))
	var tree := fx.get_tree()
	if tree:
		var gen := int(fx.get_meta("fx_gen", 0)) + 1
		fx.set_meta("fx_gen", gen)
		if pooled:
			fx.set_meta("fx_busy", true)
		tree.create_timer(lifetime).timeout.connect(
			_on_fx_timeout.bind(fx.get_instance_id(), gen, pooled),
			CONNECT_ONE_SHOT
		)
	return fx


static func _pool_for(path: String) -> Array:
	if not _pools.has(path):
		_pools[path] = []
	return _pools[path]


static func _alive(fx: Variant) -> Node3D:
	if fx == null or not is_instance_valid(fx):
		return null
	return fx as Node3D


static func _fill_pool(path: String, parent: Node) -> void:
	var bucket: Array = _pool_for(path)
	var keep: Array = []
	for fx in bucket:
		var node := _alive(fx)
		if node == null:
			continue
		if node.get_parent() != parent:
			if node.get_parent():
				node.get_parent().remove_child(node)
			parent.add_child(node)
		keep.append(node)
	_pools[path] = keep
	for _i in _POOL_SIZE - keep.size():
		var fx := _make_instance(path)
		if fx == null:
			continue
		parent.add_child(fx)
		_stash(fx)
		keep.append(fx)
	_pools[path] = keep


static func _prune_pools() -> void:
	for path in _pools.keys():
		var keep: Array = []
		for fx in _pools[path]:
			var node := _alive(fx)
			if node:
				keep.append(node)
		_pools[path] = keep
	_prune_lingers()
	_prune_binds()


static func _acquire(path: String) -> Node3D:
	var bucket: Array = _pool_for(path)
	for fx in bucket:
		var node := _alive(fx)
		if node and not bool(node.get_meta("fx_busy", false)):
			return node
	if bucket.is_empty():
		return null
	var idx := int(_steal.get(path, 0)) % bucket.size()
	_steal[path] = idx + 1
	return _alive(bucket[idx])


static func _make_bind(host: Node3D) -> Node3D:
	var bundle := Node3D.new()
	bundle.name = "FxTravel"
	_host().add_child(bundle)
	bundle.scale = host.scale
	var remote := RemoteTransform3D.new()
	remote.name = "FxFollow"
	remote.update_position = true
	remote.update_rotation = true
	remote.update_scale = false
	host.add_child(remote)
	_binds[host.get_instance_id()] = {"bundle": bundle, "remote": remote}
	if host.is_inside_tree() and bundle.is_inside_tree():
		_snap_bundle(host, bundle)
		remote.remote_path = remote.get_path_to(bundle)
	else:
		host.tree_entered.connect(_on_host_entered.bind(host.get_instance_id()), CONNECT_ONE_SHOT)
	host.tree_exiting.connect(_on_host_exiting.bind(host.get_instance_id()), CONNECT_ONE_SHOT)
	return bundle


static func _on_host_entered(host_id: int) -> void:
	var rec: Variant = _binds.get(host_id)
	if not rec is Dictionary:
		return
	var host := _alive(instance_from_id(host_id))
	var bundle := _alive(rec.get("bundle"))
	var remote = rec.get("remote")
	if host == null or bundle == null or not is_instance_valid(remote):
		return
	_snap_bundle(host, bundle)
	(remote as RemoteTransform3D).remote_path = (remote as RemoteTransform3D).get_path_to(bundle)


static func _on_host_exiting(host_id: int) -> void:
	_finish_id(host_id)


static func _snap_bundle(host: Node3D, bundle: Node3D) -> void:
	var sc := bundle.scale
	bundle.global_transform = Transform3D(host.global_basis.orthonormalized(), host.global_position)
	bundle.scale = sc


static func _finish_id(host_id: int) -> void:
	if not _binds.has(host_id):
		return
	var rec: Dictionary = _binds[host_id]
	_binds.erase(host_id)
	var host := _alive(instance_from_id(host_id))
	var bundle := _alive(rec.get("bundle"))
	var remote = rec.get("remote")
	if host and bundle:
		_snap_bundle(host, bundle)
	if is_instance_valid(remote):
		(remote as RemoteTransform3D).remote_path = NodePath()
		remote.queue_free()
	if bundle == null:
		return
	var persist: Array[Node] = []
	_apply_finish(bundle, persist)
	if persist.is_empty():
		bundle.queue_free()
		return
	var wait := 0.05
	for emitter in persist:
		wait = maxf(wait, _emitter_wait(emitter))
	wait = minf(wait, _LINGER_MAX)
	_track_linger(bundle)
	var tree := bundle.get_tree()
	if tree == null:
		bundle.queue_free()
		return
	var wrap_gen := int(bundle.get_meta("fx_gen", 0)) + 1
	bundle.set_meta("fx_gen", wrap_gen)
	tree.create_timer(wait).timeout.connect(
		_on_linger_timeout.bind(bundle.get_instance_id(), wrap_gen),
		CONNECT_ONE_SHOT
	)


static func _apply_finish(node: Node, persist: Array[Node]) -> void:
	if node == null:
		return
	if node.is_in_group(GROUP_PERSIST):
		_stop_and_collect_persist(node, persist)
		return
	if node.is_in_group(GROUP_BODY):
		_hide_body_node(node)
		for child in node.get_children():
			if child.is_in_group(GROUP_PERSIST):
				_stop_and_collect_persist(child, persist)
		return
	if node is GPUParticles3D or node is CPUParticles3D:
		if bool(node.get_meta("fx_linger", true)):
			_stop_and_collect_persist(node, persist)
		else:
			(node as Node3D).visible = false
			_stop_emitter(node)
		return
	_hide_body_node(node)
	for child in node.get_children():
		_apply_finish(child, persist)


static func _stop_and_collect_persist(node: Node, persist: Array[Node]) -> void:
	if node is GPUParticles3D or node is CPUParticles3D:
		_stop_emitter(node)
		persist.append(node)
		return
	for child in node.get_children():
		_stop_and_collect_persist(child, persist)


static func _hide_body_node(node: Node) -> void:
	if node is AnimationPlayer:
		var anim := node as AnimationPlayer
		anim.active = false
		anim.stop()
		return
	if node is AudioStreamPlayer3D:
		(node as AudioStreamPlayer3D).stop()
		return
	if node is MeshInstance3D or node is OmniLight3D:
		(node as Node3D).visible = false


static func _stop_emitter(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	elif node is CPUParticles3D:
		(node as CPUParticles3D).emitting = false


static func _emitter_wait(node: Node) -> float:
	var life := 0.4
	var scale := 1.0
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		life = p.lifetime
		scale = p.speed_scale
	elif node is CPUParticles3D:
		var c := node as CPUParticles3D
		life = c.lifetime
		scale = c.speed_scale
	return life / maxf(scale, 0.05)


static func _prune_binds() -> void:
	var dead: Array = []
	for host_id in _binds.keys():
		var rec: Variant = _binds[host_id]
		if not rec is Dictionary:
			dead.append(host_id)
			continue
		var host := _alive(instance_from_id(int(host_id)))
		var bundle := _alive(rec.get("bundle"))
		if host == null or bundle == null:
			dead.append(host_id)
	for host_id in dead:
		_finish_id(int(host_id))


static func _track_linger(wrap: Node3D) -> void:
	_prune_lingers()
	while _lingers.size() >= _LINGER_CAP:
		var old: Node3D = _lingers[0]
		_lingers.remove_at(0)
		if is_instance_valid(old):
			old.queue_free()
	_lingers.append(wrap)


static func _prune_lingers() -> void:
	var keep: Array[Node3D] = []
	for fx in _lingers:
		var node := _alive(fx)
		if node:
			keep.append(node)
	_lingers = keep


static func _on_linger_timeout(fx_id: int, gen: int) -> void:
	var node := _alive(instance_from_id(fx_id))
	if node:
		var idx := _lingers.find(node)
		if idx >= 0:
			_lingers.remove_at(idx)
	if node == null:
		return
	if int(node.get_meta("fx_gen", 0)) != gen:
		return
	node.queue_free()


static func _on_fx_timeout(fx_id: int, gen: int, pooled: bool) -> void:
	var node := _alive(instance_from_id(fx_id))
	if node == null:
		return
	if int(node.get_meta("fx_gen", 0)) != gen:
		return
	if pooled:
		_release(node)
	else:
		node.queue_free()


static func _release(fx: Node3D) -> void:
	if not is_instance_valid(fx):
		return
	if fx.has_method("stop"):
		fx.call("stop")
	_stash(fx)


static func _stash(fx: Node3D) -> void:
	fx.set_meta("fx_busy", false)
	fx.visible = false
	fx.scale = Vector3.ONE
	fx.rotation = Vector3.ZERO
	fx.global_position = _STASH
	fx.process_mode = Node.PROCESS_MODE_DISABLED


static func _authored_light(fx: Node) -> Dictionary:
	var light := _strongest_omni(fx)
	if light == null:
		return {}
	return {
		"color": light.light_color,
		"energy": light.light_energy,
		"range": light.omni_range,
	}


static func _strongest_omni(node: Node) -> OmniLight3D:
	if node == null:
		return null
	var best: OmniLight3D = null
	if node is OmniLight3D:
		var self_light := node as OmniLight3D
		if self_light.light_energy > 0.02:
			best = self_light
	for child in node.get_children():
		var found := _strongest_omni(child)
		if found == null:
			continue
		if best == null or found.light_energy > best.light_energy:
			best = found
	return best


static func _light_color(authored: Dictionary, cfg: Dictionary) -> Color:
	var tint: Color = cfg.get("light_color", cfg.get("primary_color", Color(0, 0, 0, 0)))
	if tint.a > 0.02:
		return tint
	if authored.has("color"):
		var authored_color: Color = authored["color"]
		if authored_color.a > 0.02:
			return authored_color
	return Color(1.0, 0.55, 0.18)


static func _light_energy(authored: Dictionary, fallback: float) -> float:
	var energy := fallback
	if authored.has("energy"):
		energy = float(authored["energy"])
	return clampf(energy, 0.2, _LIGHT_ENERGY_MAX)


static func _light_range(authored: Dictionary, cfg: Dictionary, scale: float, fallback: float) -> float:
	var reach := fallback
	if authored.has("range"):
		reach = float(authored["range"])
	reach *= maxf(scale, 0.05)
	if cfg.has("area_radius") and not authored.has("range"):
		reach = maxf(float(cfg["area_radius"]) * 1.6, 3.2)
	return clampf(reach, _LIGHT_RANGE_MIN, _LIGHT_RANGE_MAX)


static func _bind_travel_light(host: Node3D, authored: Dictionary, cfg: Dictionary, scale: float) -> void:
	if authored.is_empty() or host == null:
		return
	var energy := _light_energy(authored, 1.8)
	var reach := _light_range(authored, cfg, scale, 5.0)
	_HERO_LIGHTS.bind(host, _light_color(authored, cfg), energy, reach)


static func _pulse_hero_light(pos: Vector3, authored: Dictionary, cfg: Dictionary, scale: float) -> void:
	var energy := _light_energy(authored, 3.8)
	var reach := _light_range(authored, cfg, scale, float(cfg.get("area_radius", 2.4)) * 1.6)
	if not authored.has("range"):
		reach = maxf(reach, 3.2)
	_HERO_LIGHTS.pulse(
		pos,
		_light_color(authored, cfg),
		energy,
		reach,
		minf(float(cfg.get("lifetime", 1.2)), 0.45)
	)


static func _mute_omni_lights(fx: Node) -> void:
	if fx == null or not is_instance_valid(fx):
		return
	for child in fx.get_children():
		if child is OmniLight3D:
			var light := child as OmniLight3D
			light.shadow_enabled = false
			light.light_energy = 0.0
			light.visible = false
		elif child is Node:
			_mute_omni_lights(child)


static func _tint(fx: Node, cfg: Dictionary) -> void:
	if cfg.has("primary_color") and "primary_color" in fx:
		fx.primary_color = cfg["primary_color"]
	if cfg.has("secondary_color") and "secondary_color" in fx:
		fx.secondary_color = cfg["secondary_color"]
	if cfg.has("tertiary_color") and "tertiary_color" in fx:
		fx.tertiary_color = cfg["tertiary_color"]
	if cfg.has("light_color") and "light_color" in fx:
		fx.light_color = cfg["light_color"]
