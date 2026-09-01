class_name Arena
extends Node3D

const CHAMPION_SCENE := preload("res://scenes/units/champion.tscn")
const ALLY_SCENE := preload("res://scenes/units/ally.tscn")
const BOSS_SCENE := preload("res://scenes/units/boss.tscn")
const DAWNWARDEN_AI := preload("res://scripts/ai/dawnwarden_ai.gd")
const DUMMY_CHASE := preload("res://scripts/ai/dummy_chase.gd")
const UMBRAL_SHADER := preload("res://scripts/visual/umbral_shadow.gdshader")
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const TEX_FLOOR := preload("res://assets/textures/arena/floor_plaza.png")
const TEX_RIM := preload("res://assets/textures/arena/wall_brick.png")
const TEX_BLOCK := preload("res://assets/textures/arena/metal_plates.png")
const UMBRAL_MAX_AMP := 0.5
const UMBRAL_INNER := 5.6
const UMBRAL_OUTER := 26.0
const CHASE_PAD_POS := Vector3(-22.0, 0.08, 1.5)
const CHASE_PAD_RADIUS := 2.2
const CHASE_PAD_CD := 15.0
const CHASE_PACK_COUNT := 60
const CHASE_DUMMY_SPEED := 2.8
const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var units_root: Node3D = $Units
@onready var shrink_ring: MeshInstance3D = $ShrinkRing

var _baked: bool = false
var _spawned: bool = false
var _pending_match: bool = false
var _pillars: Array[ArenaPillar] = []
var _center_well: MeshInstance3D
var _linger_ring: MeshInstance3D
var _linger_left: float = 0.0
var _linger_inner: float = 15.4
var _linger_dps: float = 36.0
var umbral_shadow: bool = false
var _umbral_floor: MeshInstance3D
var _umbral_mat: ShaderMaterial
var _solar_flare: float = 0.0
var _flare_tween: Tween
var _idle_sun_energy: float = 0.78
var _idle_sun_color: Color = Color(0.72, 0.78, 1.0)
var _idle_fill_energy: float = 0.32
var _idle_fill_color: Color = Color(0.45, 0.6, 1.0)
var _idle_ambient: float = 0.36
var _idle_fog: float = 0.01
var _chase_pad: MeshInstance3D
var _chase_pad_mat: ShaderMaterial
var _chase_pad_cd: float = 0.0
var _chase_spawns_left: int = 0


func _ready() -> void:
	ArenaState.reset()
	ArenaState.register_arena(self)
	if not GameSession.match_requested.is_connected(_on_match_requested):
		GameSession.match_requested.connect(_on_match_requested)
	_apply_surface_textures()
	_setup_shrink_ring()
	await get_tree().physics_frame
	await get_tree().physics_frame
	rebake_navigation()
	await get_tree().physics_frame
	var decor := ArenaDecor.new()
	decor.name = "Decor"
	add_child(decor)
	decor.decorate(self)
	var fx_root := Node3D.new()
	fx_root.name = "FxRoot"
	add_child(fx_root)
	AbilityFx.warmup(fx_root)
	ThunderWaveFx.warmup(fx_root)
	_DamageNumber.warmup(get_tree())
	_baked = true
	if _pending_match:
		_on_match_requested()


func _on_match_requested() -> void:
	if not _baked:
		_pending_match = true
		return
	if _spawned:
		GameSession.begin_fight()
		return
	if GameSession.training_mode:
		_spawn_training()
	else:
		_spawn_raid()
		_enable_ai()
	_spawned = true
	GameSession.begin_fight()


func _triplanar_mat(tex: Texture2D, scale: float, roughness: float, tint: Color = Color.WHITE, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _apply_surface_textures() -> void:
	var floor_mesh := get_node_or_null("NavigationRegion3D/Floor/MeshInstance3D") as MeshInstance3D
	if floor_mesh:
		floor_mesh.material_override = _triplanar_mat(TEX_FLOOR, 0.14, 0.92, Color(0.92, 0.9, 0.88))
	var edge := get_node_or_null("NavigationRegion3D/Edge") as MeshInstance3D
	if edge:
		edge.material_override = _triplanar_mat(TEX_RIM, 0.16, 0.88, Color(0.78, 0.7, 0.62))
	for i in range(1, 4):
		var obs := get_node_or_null("NavigationRegion3D/Obstacle%d/MeshInstance3D" % i) as MeshInstance3D
		if obs:
			obs.material_override = _triplanar_mat(TEX_BLOCK, 0.32, 0.48, Color(0.78, 0.82, 0.9), 0.22)


func _setup_shrink_ring() -> void:
	if shrink_ring == null:
		shrink_ring = MeshInstance3D.new()
		shrink_ring.name = "ShrinkRing"
		add_child(shrink_ring)
	var torus := TorusMesh.new()
	torus.inner_radius = 25.5
	torus.outer_radius = 28.0
	torus.rings = 24
	torus.ring_segments = 48
	shrink_ring.mesh = torus
	shrink_ring.rotation_degrees.x = 90.0
	shrink_ring.position.y = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.12, 0.1, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.15, 0.1)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shrink_ring.material_override = mat
	shrink_ring.visible = false


func rebake_navigation() -> void:
	if nav_region == null:
		return
	nav_region.bake_navigation_mesh(false)
	var map := nav_region.get_navigation_map()
	var mesh := nav_region.navigation_mesh
	if mesh:
		NavigationServer3D.map_set_cell_size(map, mesh.cell_size)
		NavigationServer3D.map_set_cell_height(map, mesh.cell_height)
	NavigationServer3D.map_force_update(map)


func _process(delta: float) -> void:
	if _linger_left > 0.0:
		_tick_linger(delta)
	_tick_chase_pad(delta)
	if not ArenaState.shrink_active:
		return
	shrink_ring.visible = true
	var torus := shrink_ring.mesh as TorusMesh
	if torus:
		torus.inner_radius = maxf(0.4, ArenaState.safe_radius)
		torus.outer_radius = ArenaState.arena_radius


func _spawn_player(pos: Vector3) -> Unit:
	GameSession.ensure_loadout()
	var champ: Unit = CHAMPION_SCENE.instantiate()
	champ.is_champion = true
	CasterProfile.apply_to(champ)
	units_root.add_child(champ)
	champ._attach_visual()
	champ.global_position = pos
	champ.reset_physics_interpolation()
	_bind_nav(champ)
	return champ


func _spawn_training() -> void:
	_spawn_player(Vector3(0, 0.1, 8.0))
	_spawn_training_dummy("Aguirre", Vector3(0, 0.1, 0), true)
	var pack := Vector3(8.8, 0.1, 1.2)
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(-0.85, -0.15))
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(0.7, 0.85))
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(0.75, -0.95))
	_spawn_training_dummy("Ally Aguirre", Vector3(-5.4, 0.1, 6.2), false, true)
	_spawn_training_shooter(Vector3(6.8, 0.1, 13.5), Vector3(-1.0, 0.0, 0.0))
	_setup_chase_pad()


func _spawn_training_shooter(pos: Vector3, dir: Vector3) -> Unit:
	var dummy := _spawn_training_dummy("Aguirre", pos)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.0001:
		flat = flat.normalized()
		var look := dummy.global_position + flat * 4.0
		dummy.look_at(Vector3(look.x, dummy.global_position.y, look.z), Vector3.UP)
		dummy.arm_home_reset()
	var brain := DummyShooter.new()
	brain.name = "DummyShooter"
	brain.fire_dir = flat if flat.length_squared() > 0.0001 else Vector3(-1.0, 0.0, 0.0)
	dummy.add_child(brain)
	return dummy


func _aoe_dummy_offset(x: float, z: float) -> Vector3:
	var flat := Vector2(x, z)
	var dist := flat.length()
	if dist < 0.001:
		return Vector3(x, 0.0, z)
	flat = flat.normalized() * (dist + 1.0)
	return Vector3(flat.x, 0.0, flat.y)


func _spawn_training_dummy(p_name: String, pos: Vector3, as_boss: bool = false, friendly: bool = false) -> Unit:
	var dummy: Unit = ALLY_SCENE.instantiate()
	dummy.unit_name = p_name
	dummy.team = Unit.TEAM_RAID if friendly else Unit.TEAM_BOSS
	dummy.is_boss = as_boss and not friendly
	dummy.immortal = true
	dummy.heal_practice = friendly
	dummy.body_color = Color(0.32, 0.62, 0.42) if friendly else Color(0.55, 0.42, 0.28)
	dummy.radius = 0.55
	dummy.height = 2.0
	dummy.max_health = 800.0 if friendly else 50000.0
	dummy.max_mana = 0.0
	dummy.mana_regen = 0.0
	dummy.move_speed = 0.0
	dummy.attack_damage = 0.0
	dummy.attack_range = 0.5
	dummy.is_melee = true
	dummy.visual_path = CharacterCatalog.TRAINING_DUMMY
	dummy.visual_scale = 1.2
	dummy.abilities.clear()
	units_root.add_child(dummy)
	dummy._attach_visual()
	dummy.global_position = pos
	var face := Vector3(0.0, pos.y, 0.0) if friendly else Vector3(0.0, pos.y, 8.0)
	if Vector2(pos.x - face.x, pos.z - face.z).length_squared() > 0.01:
		dummy.look_at(face, Vector3.UP)
	dummy.reset_physics_interpolation()
	_bind_nav(dummy)
	var dummy_agent := dummy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if dummy_agent:
		dummy_agent.avoidance_enabled = false
		dummy_agent.target_position = dummy.global_position
	dummy.abilities.clear()
	dummy.cooldown_left.clear()
	var ai := dummy.get_node_or_null("AllyAI")
	if ai:
		ai.queue_free()
	dummy.set_ai_enabled(false)
	if friendly:
		dummy.health = 1.0
	dummy.arm_home_reset()
	return dummy


func _setup_chase_pad() -> void:
	if _chase_pad != null and is_instance_valid(_chase_pad):
		return
	_chase_pad = MeshInstance3D.new()
	_chase_pad.name = "ChasePad"
	_chase_pad.mesh = GroundIndicator.circle_mesh()
	_chase_pad.position = CHASE_PAD_POS
	_chase_pad_mat = GroundIndicator.zone_mat(_chase_pad_ready_color(), CHASE_PAD_RADIUS, 0.22, 0.92)
	_chase_pad_mat.set_shader_parameter("emission_strength", 0.95)
	_chase_pad.material_override = _chase_pad_mat
	GroundIndicator.prepare(_chase_pad)
	GroundIndicator.set_circle_radius(_chase_pad, CHASE_PAD_RADIUS)
	add_child(_chase_pad)
	_chase_pad_cd = 0.0
	_refresh_chase_pad_look()


func _tick_chase_pad(delta: float) -> void:
	if _chase_pad == null or not is_instance_valid(_chase_pad):
		return
	if _chase_spawns_left > 0:
		_flush_chase_spawns()
	if _chase_pad_cd > 0.0:
		_chase_pad_cd = maxf(0.0, _chase_pad_cd - delta)
		_refresh_chase_pad_look()
	if _chase_pad_cd > 0.0 or not GameSession.fight_started:
		return
	var champ := ArenaState.champion
	if champ == null or not is_instance_valid(champ) or champ.is_dead:
		return
	var reach := CHASE_PAD_RADIUS + champ.radius
	var dx := champ.global_position.x - CHASE_PAD_POS.x
	var dz := champ.global_position.z - CHASE_PAD_POS.z
	if dx * dx + dz * dz > reach * reach:
		return
	_chase_pad_cd = CHASE_PAD_CD
	_refresh_chase_pad_look()
	_chase_spawns_left = CHASE_PACK_COUNT
	_flush_chase_spawns()


func _chase_pad_ready_color() -> Color:
	return Color(0.95, 0.68, 0.18)


func _chase_pad_cool_color() -> Color:
	return Color(0.34, 0.3, 0.24)


func _refresh_chase_pad_look() -> void:
	if _chase_pad_mat == null:
		return
	var ready := _chase_pad_cd <= 0.0
	var col := _chase_pad_ready_color() if ready else _chase_pad_cool_color()
	_chase_pad_mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 1.0))
	_chase_pad_mat.set_shader_parameter("rim_color", Color(col.r, col.g, col.b, 1.0))
	_chase_pad_mat.set_shader_parameter("fill_alpha", 0.22 if ready else 0.08)
	_chase_pad_mat.set_shader_parameter("outline_alpha", 0.92 if ready else 0.35)
	_chase_pad_mat.set_shader_parameter("emission_strength", 0.95 if ready else 0.22)


func _flush_chase_spawns() -> void:
	var n := mini(_chase_spawns_left, 6)
	var start := CHASE_PACK_COUNT - _chase_spawns_left
	for i in n:
		_spawn_chase_dummy(_chase_dummy_pos(start + i))
	_chase_spawns_left -= n


func _chase_dummy_pos(index: int) -> Vector3:
	var ring := index / 10
	var slot := index % 10
	var radius := 3.1 + float(ring) * 1.55
	var ang := TAU * float(slot) / 10.0 + float(ring) * 0.21
	return Vector3(cos(ang) * radius, 0.1, sin(ang) * radius)


func _spawn_chase_dummy(pos: Vector3) -> Unit:
	var dummy: Unit = ALLY_SCENE.instantiate()
	dummy.unit_name = "Dummy"
	dummy.team = Unit.TEAM_BOSS
	dummy.body_color = Color(0.55, 0.42, 0.28)
	dummy.radius = 0.42
	dummy.height = 1.7
	dummy.max_health = 1000.0
	dummy.max_mana = 0.0
	dummy.mana_regen = 0.0
	dummy.move_speed = CHASE_DUMMY_SPEED
	dummy.attack_damage = 0.0
	dummy.attack_range = 0.5
	dummy.is_melee = true
	dummy.despawn_on_death = true
	dummy.visual_path = CharacterCatalog.TRAINING_DUMMY
	dummy.visual_scale = 1.05
	dummy.abilities.clear()
	units_root.add_child(dummy)
	dummy._attach_visual()
	dummy.global_position = pos
	dummy.reset_physics_interpolation()
	_bind_nav(dummy)
	var dummy_agent := dummy.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if dummy_agent:
		dummy_agent.avoidance_enabled = false
		dummy_agent.radius = 0.3
		dummy_agent.path_desired_distance = 0.4
		dummy_agent.target_desired_distance = 0.45
	dummy.abilities.clear()
	dummy.cooldown_left.clear()
	var old_ai := dummy.get_node_or_null("AllyAI")
	if old_ai:
		old_ai.queue_free()
	var brain := DUMMY_CHASE.new()
	brain.name = "DummyChase"
	dummy.add_child(brain)
	dummy.set_ai_enabled(false)
	return dummy


func _spawn_raid() -> void:
	_spawn_player(Vector3(0, 0.1, 16.5))

	var tank := _spawn_ally("Bulwark", "tank", Color(0.38, 0.52, 0.78), Vector3(-4.2, 0.1, 15.2), {
		"max_health": 3200.0,
		"move_speed": 6.5,
		"attack_range": 2.4,
		"attack_damage": 48.0,
		"is_melee": true,
		"max_mana": 250.0,
		"radius": 0.55,
		"height": 2.05,
		"immortal": true,
		"visual_path": CharacterCatalog.MALE_PEASANT,
		"visual_scale": 1.18,
	})
	_spawn_ally("Mend", "healer", Color(0.35, 0.82, 0.5), Vector3(4.2, 0.1, 15.2), {
		"max_health": 520.0,
		"move_speed": 7.0,
		"attack_range": 6.5,
		"attack_damage": 28.0,
		"max_mana": 480.0,
		"mana_regen": 16.0,
		"visual_path": CharacterCatalog.FEMALE_PEASANT,
	})
	_spawn_ally("Hex", "dps", Color(0.85, 0.45, 0.2), Vector3(-7.2, 0.1, 13.6), {
		"max_health": 560.0,
		"move_speed": 7.3,
		"attack_range": 6.4,
		"attack_damage": 52.0,
		"visual_path": CharacterCatalog.MALE_RANGER,
	})
	_spawn_ally("Vex", "dps", Color(0.7, 0.4, 0.95), Vector3(7.2, 0.1, 13.6), {
		"max_health": 540.0,
		"move_speed": 7.4,
		"attack_range": 6.6,
		"attack_damage": 54.0,
		"visual_path": CharacterCatalog.FEMALE_RANGER,
	})

	if GameSession.selected_boss_id == "dawnwarden":
		var tank_ai := tank.get_node_or_null("AllyAI") as AllyAI
		if tank_ai:
			tank_ai.hold_center = true
		_prepare_dawnwarden_layout()
		_spawn_dawnwarden()
	else:
		_spawn_colossus()


func _spawn_colossus() -> void:
	var boss: Unit = BOSS_SCENE.instantiate()
	boss.unit_name = "Colossus"
	boss.is_boss = true
	boss.team = Unit.TEAM_BOSS
	boss.body_color = Color(0.62, 0.12, 0.14)
	boss.radius = 1.35
	boss.height = 4.2
	boss.max_health = 100000.0
	boss.max_mana = 0.0
	boss.mana_regen = 0.0
	boss.move_speed = 4.4
	boss.turn_rate = 5.5
	boss.attack_damage = 78.0
	boss.attack_range = 3.6
	boss.attack_windup = 0.35
	boss.attack_cooldown = 1.35
	boss.is_melee = true
	boss.visual_path = CharacterCatalog.BOSS_BODY
	boss.visual_scale = 2.35
	units_root.add_child(boss)
	boss._attach_visual()
	boss.global_position = Vector3(0, 0.1, 0)
	boss.look_at(Vector3(0, 0.1, 16), Vector3.UP)
	boss.reset_physics_interpolation()
	_bind_nav(boss)


func _spawn_dawnwarden() -> void:
	var boss: Unit = BOSS_SCENE.instantiate()
	boss.unit_name = "Dawnwarden"
	boss.is_boss = true
	boss.team = Unit.TEAM_BOSS
	boss.body_color = Color(0.92, 0.78, 0.32)
	boss.radius = 1.4
	boss.height = 4.4
	boss.max_health = 100000.0
	boss.max_mana = 0.0
	boss.mana_regen = 0.0
	boss.move_speed = 4.2
	boss.turn_rate = 5.2
	boss.attack_damage = 72.0
	boss.attack_range = 3.5
	boss.attack_windup = 0.35
	boss.attack_cooldown = 1.4
	boss.is_melee = true
	boss.visual_path = CharacterCatalog.LIGHT_ENTITY
	boss.visual_scale = 2.1
	boss.visual_yaw = 0.0
	boss.visual_pitch = -PI * 0.5
	boss.visual_y_offset = 2.03
	units_root.add_child(boss)
	boss._attach_visual()
	boss.global_position = Vector3(0, 0.1, 0)
	boss.look_at(Vector3(0, 0.1, 16), Vector3.UP)
	boss.reset_physics_interpolation()
	_bind_nav(boss)
	var old_ai := boss.get_node_or_null("BossAI")
	if old_ai:
		boss.remove_child(old_ai)
		old_ai.free()
	var ai := DAWNWARDEN_AI.new()
	ai.name = "DawnwardenAI"
	boss.add_child(ai)


func _prepare_dawnwarden_layout() -> void:
	var decor := get_node_or_null("Decor") as Node3D
	if decor:
		decor.visible = false
	_set_stock_obstacles_enabled(false)
	_spawn_dawnwarden_pillars()
	_spawn_center_well()
	_setup_linger_ring()
	_setup_umbral_shadow()
	rebake_navigation()


func _set_stock_obstacles_enabled(enabled: bool) -> void:
	for child in nav_region.get_children():
		if child is ArenaPillar:
			continue
		if not child is StaticBody3D or not String(child.name).begins_with("Obstacle"):
			continue
		var body := child as StaticBody3D
		body.visible = enabled
		body.collision_layer = 1 if enabled else 0
		var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape:
			shape.disabled = not enabled


func _spawn_dawnwarden_pillars() -> void:
	_pillars.clear()
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var pos := Vector3(cos(angle) * 17.0, 0.0, sin(angle) * 17.0)
		var pillar := ArenaPillar.new()
		nav_region.add_child(pillar)
		pillar.setup(i + 1, pos)
		pillar.destroyed.connect(_on_pillar_destroyed)
		_pillars.append(pillar)


func _spawn_center_well() -> void:
	if _center_well:
		return
	var torus := TorusMesh.new()
	torus.inner_radius = UMBRAL_INNER - 0.12
	torus.outer_radius = UMBRAL_INNER + 0.22
	torus.rings = 8
	torus.ring_segments = 48
	_center_well = MeshInstance3D.new()
	_center_well.name = "CenterWell"
	_center_well.mesh = torus
	_center_well.rotation_degrees.x = 90.0
	_center_well.position.y = 0.07
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.38, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.28)
	mat.emission_energy_multiplier = 0.7
	_center_well.material_override = mat
	add_child(_center_well)


func _setup_linger_ring() -> void:
	if _linger_ring:
		return
	_linger_ring = MeshInstance3D.new()
	_linger_ring.name = "LingerRing"
	_linger_ring.mesh = _annulus_mesh(_linger_inner, 27.6, 0.08)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.38, 0.06, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.32, 0.04)
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_linger_ring.material_override = mat
	_linger_ring.visible = false
	_linger_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_linger_ring)


func living_pillars() -> Array[ArenaPillar]:
	var result: Array[ArenaPillar] = []
	for p in _pillars:
		if p and is_instance_valid(p) and p.living:
			result.append(p)
	return result


func cover_point_behind(pillar: ArenaPillar, threat: Vector3, unit_radius: float) -> Vector3:
	if pillar == null:
		return threat
	var away := pillar.global_position - threat
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	var dest: Vector3 = pillar.global_position + away.normalized() * (pillar.half_xz() + unit_radius + 1.05)
	dest.y = 0.1
	return _valid_movement_point(dest, unit_radius + 0.08)


func umbral_intensity_at(pos: Vector3) -> float:
	if not umbral_shadow:
		return 0.0
	var r := Vector2(pos.x, pos.z).length()
	if r >= UMBRAL_OUTER:
		return 0.0
	return pow(1.0 - r / UMBRAL_OUTER, 1.35)


func umbral_damage_taken_bonus(pos: Vector3) -> float:
	return UMBRAL_MAX_AMP * umbral_intensity_at(pos)


func _annulus_mesh(inner: float, outer: float, y: float) -> ArrayMesh:
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


func _setup_umbral_shadow() -> void:
	umbral_shadow = true
	if _umbral_floor:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(UMBRAL_OUTER * 2.0, UMBRAL_OUTER * 2.0)
	plane.orientation = PlaneMesh.FACE_Y
	_umbral_mat = ShaderMaterial.new()
	_umbral_mat.shader = UMBRAL_SHADER
	_umbral_mat.render_priority = 0
	_umbral_mat.set_shader_parameter("darkness", 1.0)
	_umbral_mat.set_shader_parameter("falloff", 1.35)
	_umbral_floor = MeshInstance3D.new()
	_umbral_floor.name = "UmbralShadow"
	_umbral_floor.mesh = plane
	_umbral_floor.position.y = 0.035
	_umbral_floor.material_override = _umbral_mat
	_umbral_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_umbral_floor.sorting_offset = -12.0
	add_child(_umbral_floor)
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_energy = 0.78
		sun.light_color = Color(0.72, 0.78, 1.0)
		_idle_sun_energy = sun.light_energy
		_idle_sun_color = sun.light_color
	var fill := get_node_or_null("FillLight") as OmniLight3D
	if fill:
		fill.light_energy = 0.32
		fill.light_color = Color(0.45, 0.6, 1.0)
		fill.omni_range = 36.0
		_idle_fill_energy = fill.light_energy
		_idle_fill_color = fill.light_color
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		world.environment.ambient_light_energy = 0.36
		world.environment.fog_density = 0.01
		_idle_ambient = world.environment.ambient_light_energy
		_idle_fog = world.environment.fog_density


func set_solar_flare(progress: float, from_cast: bool = false) -> void:
	if from_cast and _flare_tween:
		_flare_tween.kill()
	_solar_flare = clampf(progress, 0.0, 1.0)
	var u := _solar_flare
	if _umbral_mat:
		_umbral_mat.set_shader_parameter("darkness", 1.0 - u * 0.92)
	var sun := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun:
		sun.light_energy = lerpf(_idle_sun_energy, 4.2, u)
		sun.light_color = _idle_sun_color.lerp(Color(1.0, 0.72, 0.28), u)
	var fill := get_node_or_null("FillLight") as OmniLight3D
	if fill:
		fill.light_energy = lerpf(_idle_fill_energy, 3.4, u)
		fill.light_color = _idle_fill_color.lerp(Color(1.0, 0.55, 0.12), u)
		fill.omni_range = lerpf(36.0, 52.0, u)
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		world.environment.ambient_light_energy = lerpf(_idle_ambient, 1.35, u)
		world.environment.ambient_light_color = Color(0.42, 0.48, 0.58).lerp(Color(1.0, 0.62, 0.22), u)
		world.environment.fog_density = lerpf(_idle_fog, 0.0015, u)


func end_solar_flare() -> void:
	if _flare_tween:
		_flare_tween.kill()
	if _solar_flare <= 0.02:
		set_solar_flare(0.0)
		return
	_flare_tween = create_tween()
	_flare_tween.tween_method(set_solar_flare, _solar_flare, 0.0, 1.15)


func cover_point_inward(pillar: ArenaPillar, unit_radius: float) -> Vector3:
	if pillar == null:
		return Vector3.ZERO
	var inward := Vector3(-pillar.global_position.x, 0.0, -pillar.global_position.z)
	if inward.length_squared() < 0.01:
		inward = Vector3(0, 0, -1)
	var dest: Vector3 = pillar.global_position + inward.normalized() * (pillar.half_xz() + unit_radius + 1.1)
	dest.y = 0.1
	return _valid_movement_point(dest, unit_radius + 0.08)


func has_radial_shadow(pos: Vector3, extra_exclude: Array[RID] = []) -> bool:
	var flat := Vector2(pos.x, pos.z)
	if flat.length() < 1.2:
		return false
	var outward := Vector3(flat.x, 0.0, flat.y).normalized()
	var from := outward * (ArenaState.arena_radius - 0.35)
	from.y = pos.y
	if not spell_has_los(from, pos, extra_exclude):
		return true
	return SpellWall.cover_occludes(from, pos, extra_exclude)


func cover_point_inward_at(origin: Vector3, half: float, unit_radius: float) -> Vector3:
	var inward := Vector3(-origin.x, 0.0, -origin.z)
	if inward.length_squared() < 0.01:
		inward = Vector3(0, 0, -1)
	var dest: Vector3 = origin + inward.normalized() * (half + unit_radius + 1.1)
	dest.y = 0.1
	return _valid_movement_point(dest, unit_radius + 0.08)


func inward_cover_spots(unit_radius: float) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for pillar in living_pillars():
		spots.append(cover_point_inward(pillar, unit_radius))
	for wall in SpellWall.living_walls():
		if not wall.is_cover_solid():
			continue
		spots.append(cover_point_inward_at(wall.global_position, wall.cover_half(), unit_radius))
	return spots


func damage_living_pillars(ratio: float) -> void:
	for p in living_pillars():
		p.take_damage(p.max_health * ratio)


func start_lingering_dawn(duration: float = 6.0) -> void:
	_linger_left = duration
	if _linger_ring:
		_linger_ring.visible = true


func _tick_linger(delta: float) -> void:
	_linger_left = maxf(0.0, _linger_left - delta)
	if _linger_ring:
		_linger_ring.visible = _linger_left > 0.0
		var pulse := 0.28 + 0.1 * sin(Time.get_ticks_msec() * 0.01)
		var mat := _linger_ring.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = pulse
			mat.emission_energy_multiplier = 2.2 + pulse * 2.0
	if _linger_left <= 0.0:
		return
	if not GameSession.fight_started:
		return
	for u in ArenaState.living_allies():
		var d := Vector2(u.global_position.x, u.global_position.z).length()
		if d > _linger_inner:
			u.apply_world_hit(_linger_dps * delta, ArenaState.boss, "fire", "dawn_linger", -1, true)


func _on_pillar_destroyed(_pillar: ArenaPillar) -> void:
	rebake_navigation()


func _spawn_ally(p_name: String, role: String, color: Color, pos: Vector3, stats: Dictionary) -> Unit:
	var ally: Unit = ALLY_SCENE.instantiate()
	ally.unit_name = p_name
	ally.body_color = color
	for key in stats.keys():
		ally.set(key, stats[key])
	units_root.add_child(ally)
	ally._attach_visual()
	ally.global_position = pos
	ally.reset_physics_interpolation()
	_bind_nav(ally)
	var ai := ally.get_node("AllyAI") as AllyAI
	if ai:
		ai.role = role
	if role == "tank":
		ally.threat_mult = ThreatTable.TANK_MULT
	ally.set_ai_enabled(false)
	return ally


func _enable_ai() -> void:
	for u in ArenaState.allies:
		if u:
			u.set_ai_enabled(true)
	if ArenaState.boss:
		ArenaState.boss.set_ai_enabled(true)
	if ArenaState.champion:
		ArenaState.champion.set_ai_enabled(false)


func spawn_add(pos: Vector3) -> void:
	var add: Unit = ALLY_SCENE.instantiate()
	add.unit_name = "Shard"
	add.team = Unit.TEAM_BOSS
	add.show_nameplate = true
	add.body_color = Color(0.55, 0.18, 0.22)
	add.radius = 0.38
	add.height = 1.4
	add.max_health = 280.0
	add.max_mana = 0.0
	add.move_speed = 6.6
	add.attack_range = 2.0
	add.attack_damage = 22.0
	add.attack_cooldown = 1.1
	add.is_melee = true
	add.visual_path = CharacterCatalog.MALE_PEASANT
	add.visual_scale = 0.82
	add.abilities.clear()
	units_root.add_child(add)
	add._attach_visual()
	add.global_position = pos
	add.reset_physics_interpolation()
	_bind_nav(add)
	var old_ai := add.get_node_or_null("AllyAI")
	if old_ai:
		old_ai.queue_free()
	var ai := AddAI.new()
	ai.name = "AddAI"
	add.add_child(ai)
	add.set_ai_enabled(true)


func spawn_dawnwarden_echoes() -> void:
	for pillar in living_pillars():
		_spawn_echoes_at_pillar(pillar)


func spawn_dawnwarden_echo(pos: Vector3, melee: bool) -> Unit:
	var add: Unit = ALLY_SCENE.instantiate()
	add.unit_name = "Echo"
	add.team = Unit.TEAM_BOSS
	add.show_nameplate = false
	add.body_color = Color(0.42, 0.05, 0.04) if melee else Color(1.0, 0.48, 0.08)
	add.radius = 0.32
	add.height = 1.08
	add.max_health = 200.0
	add.max_mana = 0.0
	add.mana_regen = 0.0
	add.move_speed = 6.2 if melee else 5.4
	add.turn_rate = 10.0
	add.attack_windup = 0.22 if melee else 0.28
	if melee:
		add.attack_range = 1.85
		add.attack_damage = 16.0
		add.attack_cooldown = 1.15
		add.is_melee = true
	else:
		add.attack_range = 8.2
		add.attack_damage = 22.0
		add.attack_cooldown = 2.05
		add.attack_projectile_speed = 16.0
		add.is_melee = false
		add.attack_vfx_scene = AbilityFx.FIRE_PROJECTILE
		add.attack_vfx_scale = 0.42
	add.visual_path = CharacterCatalog.LIGHT_ENTITY
	add.visual_scale = 0.50
	add.visual_yaw = 0.0
	add.visual_pitch = -PI * 0.5
	add.visual_y_offset = 0.48
	add.despawn_on_death = true
	add.abilities.clear()
	var nav := add.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if nav:
		nav.radius = 0.28
		nav.path_desired_distance = 0.32
		nav.target_desired_distance = 0.28
	units_root.add_child(add)
	add.add_to_group("solar_echo")
	add._attach_visual()
	add.global_position = pos
	add.reset_physics_interpolation()
	_bind_nav(add)
	_tint_echo(add, melee)
	var old_ai := add.get_node_or_null("AllyAI")
	if old_ai:
		old_ai.queue_free()
	var ai := AddAI.new()
	ai.name = "AddAI"
	add.add_child(ai)
	add.set_ai_enabled(true)
	var nearest := ArenaState.nearest_enemy(add.global_position, add.team)
	if nearest:
		ThreatTable.set_initial_target(add, nearest)
	return add


func _spawn_echoes_at_pillar(pillar: ArenaPillar) -> void:
	if pillar == null or not is_instance_valid(pillar) or not pillar.living:
		return
	var spots := _echo_spots_at_pillar(pillar)
	for i in spots.size():
		spawn_dawnwarden_echo(spots[i], (i % 2) == 0)


func _echo_spots_at_pillar(pillar: ArenaPillar) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var origin := Vector3(pillar.global_position.x, 0.1, pillar.global_position.z)
	var facing := Vector3(origin.x, 0.0, origin.z)
	if facing.length_squared() < 0.01:
		facing = Vector3(0.0, 0.0, 1.0)
	else:
		facing = facing.normalized()
	var ring := pillar.half_xz() + 0.95
	var spin := atan2(facing.z, facing.x)
	for i in 4:
		var angle := spin + TAU * float(i) / 4.0
		var pos := origin + Vector3(cos(angle), 0.0, sin(angle)) * ring
		out.append(clamp_movement_point(pos, 0.45))
	return out


func _tint_echo(add: Unit, melee: bool) -> void:
	var vis := add.get_node_or_null("CharacterVisual") as CharacterVisual
	var color := Color(0.48, 0.05, 0.04) if melee else Color(1.0, 0.46, 0.08)
	if vis:
		vis.recolor(color, 1.15 if melee else 2.15)
		vis.set_infusion_tint(color, 0.78 if melee else 0.64)


func _bind_nav(u: Unit) -> void:
	if u == null or u.movement == null:
		return
	u.movement.bind_map(nav_region.get_navigation_map())


func plan_movement_path(from: Vector3, requested: Vector3, clearance: float) -> PackedVector3Array:
	var original_start := Vector3(from.x, from.y, from.z)
	var start := _valid_movement_point(original_start, clearance + 0.04)
	var finish := _valid_movement_point(requested, clearance)
	var start_adjusted := _flat_distance(start, original_start) > 0.01
	var blockers := _movement_blockers()
	var nodes: Array[Vector3] = [start, finish]
	var corner_margin := clearance + 0.18
	for blocker in blockers:
		var xform := blocker["xform"] as Node3D
		if xform == null or not is_instance_valid(xform):
			continue
		var half: Vector3 = blocker["half"]
		for local_corner in [
			Vector3(-half.x - corner_margin, 0.0, -half.z - corner_margin),
			Vector3(half.x + corner_margin, 0.0, -half.z - corner_margin),
			Vector3(half.x + corner_margin, 0.0, half.z + corner_margin),
			Vector3(-half.x - corner_margin, 0.0, half.z + corner_margin),
		]:
			var corner := xform.to_global(local_corner)
			corner.y = start.y
			nodes.append(corner)

	var count := nodes.size()
	var distances: Array[float] = []
	var previous: Array[int] = []
	var visited: Array[bool] = []
	for i in count:
		distances.append(INF)
		previous.append(-1)
		visited.append(false)
	distances[0] = 0.0

	for step in count:
		var current := -1
		var best := INF
		for i in count:
			if not visited[i] and distances[i] < best:
				best = distances[i]
				current = i
		if current < 0 or current == 1:
			break
		visited[current] = true
		for other in count:
			if other == current or visited[other]:
				continue
			if not _movement_segment_clear(nodes[current], nodes[other], blockers, clearance + 0.08):
				continue
			var candidate := distances[current] + _flat_distance(nodes[current], nodes[other])
			if candidate < distances[other]:
				distances[other] = candidate
				previous[other] = current

	if previous[1] < 0:
		if start_adjusted:
			return PackedVector3Array([start, finish])
		return PackedVector3Array([finish])
	var reverse_path: Array[Vector3] = []
	var cursor := 1
	while cursor > 0:
		reverse_path.append(nodes[cursor])
		cursor = previous[cursor]
	reverse_path.reverse()
	if start_adjusted:
		reverse_path.push_front(start)
	return PackedVector3Array(reverse_path)


func movement_segment_clear(from: Vector3, to: Vector3, clearance: float) -> bool:
	return _movement_segment_clear(from, to, _movement_blockers(), clearance)


func spell_wall_hit(
	from: Vector3,
	to: Vector3,
	extra_exclude: Array[RID] = [],
	ray_y: float = 1.05,
	include_spell_walls: bool = true
) -> Dictionary:
	if include_spell_walls:
		var shield := SpellWall.protection_hit(from, to, 0.12)
		if shield != null:
			var n := shield.emit_dir()
			return {
				"collider": shield,
				"position": from.lerp(to, 0.5),
				"normal": n,
			}
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var a := Vector3(from.x, ray_y, from.z)
	var b := Vector3(to.x, ray_y, to.z)
	if a.distance_squared_to(b) < 0.0004:
		return {}
	var exclude: Array[RID] = []
	for rid in extra_exclude:
		exclude.append(rid)
	if not include_spell_walls:
		_exclude_spell_walls(exclude)
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collision_mask = SpellWall.shot_block_mask()
	q.exclude = exclude
	q.collide_with_areas = false
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	if _is_floor_collider(hit.get("collider")):
		return {}
	return hit


func _exclude_spell_walls(exclude: Array[RID]) -> void:
	var tree := get_tree()
	if tree == null:
		return
	_append_living_walls(tree, "spell_walls", exclude)
	_append_living_walls(tree, "spell_protection_walls", exclude)


func _append_living_walls(tree: SceneTree, group: String, exclude: Array[RID]) -> void:
	for node in tree.get_nodes_in_group(group):
		if node == null or not is_instance_valid(node):
			continue
		if not (node is SpellWall):
			continue
		exclude.append((node as SpellWall).get_rid())


func spell_has_los(from: Vector3, to: Vector3, extra_exclude: Array[RID] = [], ray_y: float = 1.05) -> bool:
	return spell_wall_hit(from, to, extra_exclude, ray_y).is_empty()


func _is_floor_collider(obj: Object) -> bool:
	return obj is Node and String((obj as Node).name) == "Floor"


func _movement_blockers() -> Array[Dictionary]:
	var blockers: Array[Dictionary] = []
	for child in nav_region.get_children():
		if not child is StaticBody3D or not String(child.name).begins_with("Obstacle"):
			continue
		var body := child as StaticBody3D
		if body.collision_layer == 0:
			continue
		if child is ArenaPillar and not (child as ArenaPillar).living:
			continue
		_collect_box_blockers(body, blockers)
	return blockers


func _collect_box_blockers(node: Node, blockers: Array[Dictionary]) -> void:
	if node is CollisionShape3D:
		var shape_node := node as CollisionShape3D
		if not shape_node.disabled:
			if shape_node.shape is BoxShape3D:
				var box := shape_node.shape as BoxShape3D
				blockers.append({"xform": shape_node, "half": box.size * 0.5})
			elif shape_node.shape is CylinderShape3D:
				var cyl := shape_node.shape as CylinderShape3D
				blockers.append({"xform": shape_node, "half": Vector3(cyl.radius, cyl.height * 0.5, cyl.radius)})
	for child in node.get_children():
		_collect_box_blockers(child, blockers)


func clamp_movement_point(requested: Vector3, clearance: float) -> Vector3:
	return _valid_movement_point(requested, clearance)


func _valid_movement_point(requested: Vector3, clearance: float) -> Vector3:
	var point := Vector3(requested.x, requested.y, requested.z)
	var max_radius := maxf(1.0, ArenaState.arena_radius - clearance - 0.4)
	var flat := Vector2(point.x, point.z)
	if flat.length() > max_radius:
		flat = flat.normalized() * max_radius
		point.x = flat.x
		point.z = flat.y
	for blocker in _movement_blockers():
		var xform := blocker["xform"] as Node3D
		var half: Vector3 = blocker["half"]
		var local := xform.to_local(point)
		var hx := half.x + clearance + 0.12
		var hz := half.z + clearance + 0.12
		if absf(local.x) >= hx or absf(local.z) >= hz:
			continue
		var push_x := hx - absf(local.x)
		var push_z := hz - absf(local.z)
		if push_x < push_z:
			local.x = hx * (1.0 if local.x >= 0.0 else -1.0)
		else:
			local.z = hz * (1.0 if local.z >= 0.0 else -1.0)
		point = xform.to_global(local)
		point.y = requested.y
	return point


func _movement_segment_clear(
	from: Vector3,
	to: Vector3,
	blockers: Array[Dictionary],
	clearance: float
) -> bool:
	for blocker in blockers:
		var xform := blocker["xform"] as Node3D
		var half: Vector3 = blocker["half"]
		var a := xform.to_local(from)
		var b := xform.to_local(to)
		if _segment_enters_rect(
			Vector2(a.x, a.z),
			Vector2(b.x, b.z),
			Vector2(half.x + clearance, half.z + clearance)
		):
			return false
	return true


func _segment_enters_rect(a: Vector2, b: Vector2, half: Vector2) -> bool:
	var delta := b - a
	var enter := 0.0
	var exit := 1.0
	for axis in 2:
		var origin := a[axis]
		var direction := delta[axis]
		var extent := half[axis]
		if absf(direction) < 0.00001:
			if absf(origin) < extent:
				continue
			return false
		var t1 := (-extent - origin) / direction
		var t2 := (extent - origin) / direction
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		enter = maxf(enter, t1)
		exit = minf(exit, t2)
		if enter > exit:
			return false
	return enter < 0.9999 and exit > 0.0001


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
