class_name AbilityFx
extends Object

const FIRE_PROJECTILE := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn"
const FIRE_AREA := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn"
const FIRE_CAST := "res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn"
const GROUND_EXPLOSION := "res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn"
const MAGIC_BOLT := "res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn"
const MAGIC_JAVELIN := "res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn"

const _PACK_FIRE_PROJECTILE := preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/projectile/vfx_fire_projectile_01.tscn")
const _PACK_FIRE_AREA := preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/area/vfx_fire_area_01.tscn")
const _PACK_FIRE_CAST := preload("res://assets/BinbunVFX_Vol2/ElementalMagicFX/effects/cast/vfx_fire_cast_01.tscn")
const _PACK_GROUND_EXPLOSION := preload("res://assets/BinbunVFX_Vol2/ExplosionFX/effects/ground/vfx_ground_explosion_01.tscn")
const _PACK_MAGIC_BOLT := preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn")
const _PACK_MAGIC_JAVELIN := preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn")

const _POOL_SIZE := 3
const _STASH := Vector3(0.0, -80.0, 0.0)

static var _warmed: bool = false
static var _explosion_pool: Array[Node3D] = []


static func is_warmed() -> bool:
	return _warmed


static func packed_scene(path: String) -> PackedScene:
	match path:
		FIRE_PROJECTILE:
			return _PACK_FIRE_PROJECTILE
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
	var keep: Array[Node3D] = []
	for fx in _explosion_pool:
		if is_instance_valid(fx):
			keep.append(fx)
	_explosion_pool = keep
	if _warmed and _explosion_pool.size() >= _POOL_SIZE:
		return
	_warmed = true
	for i in _POOL_SIZE - _explosion_pool.size():
		var fx := _make_instance(GROUND_EXPLOSION)
		if fx == null:
			continue
		parent.add_child(fx)
		_stash(fx)
		_explosion_pool.append(fx)
	# Compile shaders off the playable floor so dummy/nav aren't covered.
	if not _explosion_pool.is_empty():
		_play_node(_explosion_pool[0], _STASH, {"scale": 0.05, "lifetime": 0.35}, true)
	for path in [FIRE_PROJECTILE, FIRE_AREA, FIRE_CAST]:
		play_at(path, _STASH, {"scale": 0.05, "lifetime": 0.35})


static func play_at(path: String, pos: Vector3, cfg: Dictionary = {}) -> Node3D:
	if path == GROUND_EXPLOSION:
		var pooled := _acquire_explosion()
		if pooled:
			return _play_node(pooled, pos, cfg, true)
	var fx := _make_instance(path)
	if fx == null:
		return null
	_host().add_child(fx)
	return _play_node(fx, pos, cfg, false)


static func attach(path: String, host: Node3D, cfg: Dictionary = {}) -> Node3D:
	if host == null:
		return null
	var fx := _make_instance(path)
	if fx == null:
		return null
	if "one_shot" in fx:
		fx.set("one_shot", false)
	if "autoplay" in fx:
		fx.set("autoplay", true)
	host.add_child(fx)
	fx.position = Vector3.ZERO
	var yaw := float(cfg.get("yaw_offset", 0.0))
	if yaw != 0.0:
		fx.rotate_y(yaw)
	var sc: float = float(cfg.get("scale", 1.0))
	if sc != 1.0:
		fx.scale = Vector3.ONE * sc
	_tint(fx, cfg)
	return fx


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
	var lifetime := float(cfg.get("lifetime", 2.4))
	var tree := fx.get_tree()
	if tree:
		var gen := int(fx.get_meta("fx_gen", 0)) + 1
		fx.set_meta("fx_gen", gen)
		if pooled:
			fx.set_meta("fx_busy", true)
		tree.create_timer(lifetime).timeout.connect(func() -> void:
			if not is_instance_valid(fx) or int(fx.get_meta("fx_gen", 0)) != gen:
				return
			if pooled:
				_release_explosion(fx)
			else:
				fx.queue_free()
		)
	return fx


static func _acquire_explosion() -> Node3D:
	for fx in _explosion_pool:
		if is_instance_valid(fx) and not bool(fx.get_meta("fx_busy", false)):
			return fx
	var extra := _make_instance(GROUND_EXPLOSION)
	if extra == null:
		return null
	_host().add_child(extra)
	_explosion_pool.append(extra)
	return extra


static func _release_explosion(fx: Node3D) -> void:
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


static func _tint(fx: Node, cfg: Dictionary) -> void:
	if cfg.has("primary_color") and "primary_color" in fx:
		fx.primary_color = cfg["primary_color"]
	if cfg.has("secondary_color") and "secondary_color" in fx:
		fx.secondary_color = cfg["secondary_color"]
	if cfg.has("tertiary_color") and "tertiary_color" in fx:
		fx.tertiary_color = cfg["tertiary_color"]
	if cfg.has("light_color") and "light_color" in fx:
		fx.light_color = cfg["light_color"]
