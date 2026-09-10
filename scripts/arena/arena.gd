class_name Arena
extends Node3D

const CHAMPION_SCENE := preload("res://scenes/units/champion.tscn")
const ALLY_SCENE := preload("res://scenes/units/ally.tscn")
const BOSS_SCENE := preload("res://scenes/units/boss.tscn")
const DAWNWARDEN_AI := preload("res://scripts/ai/dawnwarden_ai.gd")
const DUMMY_CHASE := preload("res://scripts/ai/dummy_chase.gd")
const BULWARK_KIT := preload("res://scripts/talents/bulwark_kit.gd")
const MEND_KIT := preload("res://scripts/talents/mend_kit.gd")
const PILLAR_BATTERY := preload("res://scripts/arena/pillar_battery.gd")
const PILLAR_SHOT := preload("res://scripts/combat/pillar_shot.gd")
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const CHASE_PAD_POS := Vector3(-22.0, 0.08, 1.5)

## First LoS blocker from a caster to a point.
enum LosCover {
	OPEN,
	PILLAR,
	WALL,
}
const CHASE_PAD_RADIUS := 2.2
const CHASE_PAD_CD := 15.0
const CHASE_PACK_COUNT := 60
const CHASE_DUMMY_SPEED := Unit.BASE_MOVE_SPEED
## Outside the physics capsule+cylinder contact so wrap waypoints are not
## inside the slide, which used to reverse the click path every repath.
const _PATH_RING_PAD := 0.28
const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")

@onready var layout_host: Node3D = $LayoutHost
@onready var units_root: Node3D = $Units
@onready var shrink_ring: MeshInstance3D = $ShrinkRing

var nav_region: NavigationRegion3D
var _layout: ArenaLayout
var _mounted_destination_id: String = ""
var _baked: bool = false
var _spawned: bool = false
var _pending_match: bool = false
var _mounting_match: bool = false
var _pillars: Array[ArenaPillar] = []
var _pillar_battery: PillarBattery
var _blockers_frame: int = -1
var _blockers_cache: Array[Dictionary] = []
var _dawn_engaged: bool = false
var _pillar_ring_radius: float = 17.0
var _solar_flare: float = 0.0
var _flare_applied: float = -1.0
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
	_mount_layout(GameSession.selected_destination_id)
	_setup_shrink_ring()
	await get_tree().physics_frame
	await get_tree().physics_frame
	rebake_navigation()
	await get_tree().physics_frame
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
	if _mounting_match:
		return
	_mounting_match = true
	await _ensure_match_layout()
	if GameSession.training_mode:
		_spawn_training()
	else:
		_spawn_raid()
		_enable_ai()
	_spawned = true
	_mounting_match = false
	GameSession.begin_fight()


func _ensure_match_layout() -> void:
	var id := _match_layout_id()
	if _mounted_destination_id == id and nav_region != null:
		return
	_mount_layout(id)
	await get_tree().physics_frame
	rebake_navigation()


func _match_layout_id() -> String:
	if GameSession.training_mode:
		return ArenaCatalog.ID_TRAINING
	var from_boss := ArenaCatalog.destination_for_boss(GameSession.selected_boss_id)
	if not from_boss.is_empty():
		return from_boss
	var dest := GameSession.selected_destination_id.strip_edges()
	if dest.is_empty():
		return ArenaCatalog.ID_COLOSSUS
	return dest


func _mount_layout(destination_id: String) -> void:
	var id := destination_id.strip_edges()
	if id.is_empty():
		id = ArenaCatalog.ID_TRAINING
	if layout_host == null:
		layout_host = get_node_or_null("LayoutHost") as Node3D
		if layout_host == null:
			layout_host = Node3D.new()
			layout_host.name = "LayoutHost"
			add_child(layout_host)
	if _layout != null and is_instance_valid(_layout):
		layout_host.remove_child(_layout)
		_layout.free()
	_layout = null
	nav_region = null
	_mounted_destination_id = ""
	var packed := ArenaCatalog.load_layout(id)
	if packed == null:
		return
	var node := packed.instantiate()
	_layout = node as ArenaLayout
	if _layout == null:
		push_error("Arena: layout root must be ArenaLayout (%s)" % packed.resource_path)
		node.free()
		return
	layout_host.add_child(_layout)
	_layout.bind_to_arena()
	nav_region = _layout.nav_region
	_mounted_destination_id = id
	ArenaState.arena_radius = _layout.arena_radius
	ArenaState.safe_radius = maxf(1.0, _layout.arena_radius - 2.0)
	_refresh_stock_decor()


func _refresh_stock_decor() -> void:
	var existing := get_node_or_null("Decor")
	if existing:
		remove_child(existing)
		existing.free()
	if _layout == null or not _layout.use_stock_decor:
		return
	var decor := ArenaDecor.new()
	decor.name = "Decor"
	add_child(decor)
	decor.decorate(self)


func _setup_shrink_ring() -> void:
	if shrink_ring == null:
		shrink_ring = MeshInstance3D.new()
		shrink_ring.name = "ShrinkRing"
		add_child(shrink_ring)
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.4, ArenaState.arena_radius - 2.5)
	torus.outer_radius = ArenaState.arena_radius
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
	return champ


func _spawn_training() -> void:
	_spawn_player(_layout_player_spawn(true))
	_spawn_training_dummy("Aguirre", _layout_training_dummy(), true)
	var pack := _layout_training_pack()
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(-0.85, -0.15))
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(0.7, 0.85))
	_spawn_training_dummy("Aguirre", pack + _aoe_dummy_offset(0.75, -0.95))
	_spawn_training_dummy("Ally Aguirre", _layout_training_ally(), false, true)
	_spawn_training_shooter(_layout_training_shooter(), _layout_training_shooter_dir())
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
	_chase_pad.position = _layout_chase_pad()
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
	var pad := _chase_pad.global_position
	var dx := champ.global_position.x - pad.x
	var dz := champ.global_position.z - pad.z
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
	var n := mini(_chase_spawns_left, 3)
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
	_spawn_player(_layout_player_spawn(false))
	if GameSession.spawn_ai_raid:
		_spawn_ai_raid()
	if GameSession.selected_boss_id == "dawnwarden":
		_prepare_dawnwarden_layout()
		_spawn_dawnwarden()
	else:
		_spawn_colossus()


func _spawn_ai_raid() -> void:
	var role := GameSession.player_role
	for member_id in RaidComp.ai_members(role):
		_spawn_raid_member(member_id, role)


func _spawn_raid_member(member_id: String, player_role: String) -> void:
	var pos := _layout_raid_spawn(member_id, player_role)
	match member_id:
		RaidComp.MEMBER_BULWARK:
			var tank := _spawn_ally("Bulwark", "tank", Color(0.38, 0.52, 0.78), pos, {
				"max_health": 500.0,
				"move_speed": Unit.BASE_MOVE_SPEED,
				"attack_range": 2.4,
				"attack_damage": 180.0,
				"is_melee": true,
				"attack_cooldown": 0.85,
				"max_mana": 480.0,
				"mana_regen": 16.0,
				"radius": 0.55,
				"height": 2.05,
				"visual_path": CharacterCatalog.MALE_PEASANT,
				"visual_scale": 1.18,
			})
			BULWARK_KIT.apply_to(tank)
			_tune_npc_damage(tank)
		RaidComp.MEMBER_MEND:
			var healer := _spawn_ally("Mend", "healer", Color(0.35, 0.82, 0.5), pos, {
				"max_health": 520.0,
				"move_speed": Unit.BASE_MOVE_SPEED,
				"attack_range": 6.5,
				"attack_damage": 28.0,
				"max_mana": 560.0,
				"mana_regen": 22.0,
				"visual_path": CharacterCatalog.FEMALE_PEASANT,
			})
			MEND_KIT.apply_to(healer)
		RaidComp.MEMBER_HEX:
			var hex := _spawn_ally("Hex", "dps", Color(0.85, 0.45, 0.2), pos, {
				"max_health": 560.0,
				"move_speed": Unit.BASE_MOVE_SPEED,
				"attack_range": 6.4,
				"attack_damage": 52.0,
				"attack_cooldown": 0.95,
				"visual_path": CharacterCatalog.MALE_RANGER,
			})
			_tune_npc_damage(hex)
		RaidComp.MEMBER_VEX:
			var vex := _spawn_ally("Vex", "dps", Color(0.7, 0.4, 0.95), pos, {
				"max_health": 540.0,
				"move_speed": Unit.BASE_MOVE_SPEED,
				"attack_range": 6.6,
				"attack_damage": 54.0,
				"attack_cooldown": 0.95,
				"visual_path": CharacterCatalog.FEMALE_RANGER,
			})
			_tune_npc_damage(vex)
		RaidComp.MEMBER_ROOK:
			var rook := _spawn_ally("Rook", "dps", Color(0.45, 0.68, 0.82), pos, {
				"max_health": 550.0,
				"move_speed": Unit.BASE_MOVE_SPEED,
				"attack_range": 6.5,
				"attack_damage": 53.0,
				"attack_cooldown": 0.95,
				"visual_path": CharacterCatalog.MALE_RANGER,
			})
			_tune_npc_damage(rook)


func _spawn_colossus() -> void:
	var boss: Unit = BOSS_SCENE.instantiate()
	boss.unit_name = "Colossus"
	boss.is_boss = true
	boss.team = Unit.TEAM_BOSS
	boss.body_color = Color(0.62, 0.12, 0.14)
	boss.radius = 1.35
	boss.height = 4.2
	boss.max_health = CombatBalance.flat("colossus.hp")
	boss.max_mana = 0.0
	boss.mana_regen = 0.0
	boss.move_speed = Unit.BASE_MOVE_SPEED
	boss.turn_rate = 5.5
	boss.attack_damage = CombatBalance.flat("colossus.auto")
	boss.attack_range = 3.6
	boss.attack_windup = 0.35
	boss.attack_cooldown = 1.35
	boss.is_melee = true
	boss.visual_path = CharacterCatalog.BOSS_BODY
	boss.visual_scale = 2.35
	units_root.add_child(boss)
	boss._attach_visual()
	boss.global_position = _layout_boss_spawn()
	var face := _layout_player_spawn(false)
	face.y = boss.global_position.y
	if Vector2(boss.global_position.x - face.x, boss.global_position.z - face.z).length_squared() > 0.01:
		boss.look_at(face, Vector3.UP)
	boss.reset_physics_interpolation()


func _spawn_dawnwarden() -> void:
	var boss: Unit = BOSS_SCENE.instantiate()
	boss.unit_name = "Dawnwarden"
	boss.is_boss = true
	boss.team = Unit.TEAM_BOSS
	boss.body_color = Color(0.78, 0.16, 0.08)
	boss.radius = 1.4
	boss.height = 4.4
	boss.max_health = CombatBalance.flat("dawnwarden.hp")
	boss.max_mana = 0.0
	boss.mana_regen = 0.0
	boss.move_speed = CombatBalance.flat("dawnwarden.speed")
	boss.turn_rate = 9.0
	boss.attack_damage = CombatBalance.flat("dawnwarden.auto")
	boss.attack_range = CombatBalance.flat("dawnwarden.auto.range")
	boss.attack_windup = 0.35
	boss.attack_cooldown = 1.4
	boss.is_melee = true
	boss.visual_path = CharacterCatalog.KEVDEV_DUMMY_F
	boss.visual_scale = boss.height / 1.8
	units_root.add_child(boss)
	boss._attach_visual()
	_tint_dawnwarden(boss)
	boss.global_position = _layout_boss_spawn()
	var face := _layout_player_spawn(false)
	face.y = boss.global_position.y
	if Vector2(boss.global_position.x - face.x, boss.global_position.z - face.z).length_squared() > 0.01:
		boss.look_at(face, Vector3.UP)
	boss.reset_physics_interpolation()
	var old_ai := boss.get_node_or_null("BossAI")
	if old_ai:
		boss.remove_child(old_ai)
		old_ai.free()
	var ai := DAWNWARDEN_AI.new()
	ai.name = "DawnwardenAI"
	boss.add_child(ai)


func _prepare_dawnwarden_layout() -> void:
	_dawn_engaged = false
	var decor := get_node_or_null("Decor") as Node3D
	if decor:
		decor.visible = false
	_spawn_dawnwarden_pillars()
	if _pillar_battery == null:
		_pillar_battery = PILLAR_BATTERY.new()
		_pillar_battery.name = "PillarBattery"
		add_child(_pillar_battery)
	_warmup_dawnwarden_fx()
	_capture_idle_lights()
	rebake_navigation()


func _warmup_dawnwarden_fx() -> void:
	var fx_root: Node = get_node_or_null("FxRoot")
	if fx_root == null:
		fx_root = self
	SolarWashFx.warmup(fx_root)
	SolarCollapseFx.warmup(fx_root)
	GroundIndicator.warmup(fx_root)
	JudgmentBeam.warmup(fx_root)
	PILLAR_SHOT.warmup(fx_root)
	ArenaPillar.warmup_debris(fx_root)


func _spawn_dawnwarden_pillars() -> void:
	_pillars.clear()
	if nav_region == null:
		return
	var anchors := _layout_pillar_anchors()
	var ring := 17.0
	for i in anchors.size():
		var pos: Vector3 = anchors[i]
		ring = maxf(ring, Vector2(pos.x, pos.z).length())
		var pillar := ArenaPillar.new()
		nav_region.add_child(pillar)
		pillar.setup(i + 1, pos, CombatBalance.flat("dawnwarden.pillar.hp"))
		pillar.destroyed.connect(_on_pillar_destroyed)
		_pillars.append(pillar)
	_pillar_ring_radius = ring


func living_pillars() -> Array[ArenaPillar]:
	var result: Array[ArenaPillar] = []
	for p in _pillars:
		if p and is_instance_valid(p) and p.living:
			result.append(p)
	return result


func all_pillars() -> Array[ArenaPillar]:
	return _pillars


func pillar_ring_radius() -> float:
	return _pillar_ring_radius


func is_dawn_engaged() -> bool:
	return _dawn_engaged


func engage_dawnwarden() -> void:
	if _dawn_engaged:
		return
	_dawn_engaged = true


func raise_dawnwarden_pillars(destroyed_only: bool) -> void:
	var dur := CombatBalance.flat("dawnwarden.pillar.warmup")
	var rising := false
	for pillar in _pillars:
		if pillar == null or not is_instance_valid(pillar):
			continue
		if destroyed_only and pillar.living:
			continue
		pillar.begin_rise(dur)
		rising = true
	if rising:
		## One rumble for the whole ring. The packed scene also keys this clip
		## at animation start; ArenaPillar mutes those copies so ten do not stack.
		AudioManager.play_at("dawnwarden.pillar.rise", Vector3.ZERO)
	if not destroyed_only and _pillar_battery:
		_pillar_battery.activate()


func plant_dawnwarden_pillars() -> void:
	for pillar in _pillars:
		if pillar == null or not is_instance_valid(pillar):
			continue
		if pillar.is_rising():
			pillar.plant()
	if _pillar_battery:
		_pillar_battery.on_planted()
	rebake_navigation()


func pause_dawnwarden_pillars() -> void:
	if _pillar_battery:
		_pillar_battery.pause()


func resume_dawnwarden_pillars() -> void:
	if _pillar_battery:
		_pillar_battery.resume()


func double_raid_judgment() -> void:
	for ally in ArenaState.living_allies():
		var u := ally as Unit
		if u != null and is_instance_valid(u):
			u.double_judgment_brand()


func _capture_idle_lights() -> void:
	var sun := _sun_light()
	if sun:
		_idle_sun_energy = sun.light_energy
		_idle_sun_color = sun.light_color
	var fill := _fill_light()
	if fill:
		_idle_fill_energy = fill.light_energy
		_idle_fill_color = fill.light_color
	var world := _world_env()
	if world and world.environment:
		_idle_ambient = world.environment.ambient_light_energy
		_idle_fog = world.environment.fog_density


func cover_point_behind(pillar: ArenaPillar, threat: Vector3, unit_radius: float) -> Vector3:
	if pillar == null:
		return threat
	var away := pillar.global_position - threat
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	var dest: Vector3 = pillar.global_position + away.normalized() * (pillar.half_xz() + unit_radius + 1.05)
	dest.y = 0.1
	return clamp_movement_point(dest, unit_radius + 0.08)


func set_solar_flare(progress: float, from_cast: bool = false) -> void:
	if from_cast and _flare_tween:
		_flare_tween.kill()
	_solar_flare = clampf(progress, 0.0, 1.0)
	var u := _solar_flare
	if from_cast and absf(u - _flare_applied) < 0.025 and u > 0.02 and u < 0.98:
		return
	_flare_applied = u
	var sun := _sun_light()
	if sun:
		sun.light_energy = lerpf(_idle_sun_energy, 2.0, u)
		sun.light_color = _idle_sun_color.lerp(Color(1.0, 0.72, 0.28), u)
	var fill := _fill_light()
	if fill:
		fill.light_energy = lerpf(_idle_fill_energy, 1.6, u)
		fill.light_color = _idle_fill_color.lerp(Color(1.0, 0.55, 0.12), u)
		fill.omni_range = lerpf(36.0, 42.0, u)
	var world := _world_env()
	if world and world.environment:
		world.environment.ambient_light_energy = lerpf(_idle_ambient, 0.72, u)
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
	return clamp_movement_point(dest, unit_radius + 0.08)


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
	return clamp_movement_point(dest, unit_radius + 0.08)


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
	var ai := ally.get_node("AllyAI") as AllyAI
	if ai:
		ai.role = role
	if role == "tank":
		ally.threat_mult = ThreatTable.TANK_MULT
	ally.set_ai_enabled(false)
	return ally


func _tune_npc_damage(unit: Unit) -> void:
	if unit == null:
		return
	var dps := CombatBalance.flat("raid.npc.dps")
	var swing := maxf(unit.attack_cooldown, 0.2)
	unit.attack_damage = dps * swing


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
	add.max_health = CombatBalance.flat("colossus.shard.hp")
	add.max_mana = 0.0
	add.move_speed = Unit.BASE_MOVE_SPEED
	add.attack_range = 2.0
	add.attack_damage = CombatBalance.flat("colossus.shard.damage")
	add.attack_cooldown = 1.1
	add.is_melee = true
	add.visual_path = CharacterCatalog.MALE_PEASANT
	add.visual_scale = 0.82
	add.abilities.clear()
	units_root.add_child(add)
	add._attach_visual()
	add.global_position = pos
	add.reset_physics_interpolation()
	var old_ai := add.get_node_or_null("AllyAI")
	if old_ai:
		old_ai.queue_free()
	var ai := AddAI.new()
	ai.name = "AddAI"
	add.add_child(ai)
	add.set_ai_enabled(true)


func _tint_dawnwarden(boss: Unit) -> void:
	var vis := boss.get_node_or_null("CharacterVisual") as CharacterVisual
	if vis == null:
		return
	vis.recolor(Color(0.92, 0.28, 0.10), 1.35)
	vis.set_infusion_tint(Color(1.0, 0.35, 0.08), 0.48)


func plan_movement_path(
	from: Vector3,
	requested: Vector3,
	clearance: float,
	wrap_io: Array = []
) -> PackedVector3Array:
	# Routes around map Obstacle* cover and living solid spell walls so click-move
	# and LoS approaches walk around barriers instead of into them.
	var original_start := Vector3(from.x, from.y, from.z)
	var blockers := _movement_blockers()
	var start := _valid_movement_point(original_start, clearance + 0.04, blockers)
	var finish := _valid_movement_point(requested, clearance, blockers)
	if _movement_segment_clear(original_start, finish, blockers, clearance + 0.04, null, true):
		if wrap_io.size() > 0:
			wrap_io[0] = 0.0
		return PackedVector3Array([finish])
	var prefer := float(wrap_io[0]) if wrap_io.size() > 0 else 0.0
	var chosen: Array = [prefer]
	var bypass := _try_circle_bypass(original_start, finish, blockers, clearance, prefer, 0, chosen, false)
	if bypass.size() > 0:
		if wrap_io.size() > 0:
			wrap_io[0] = float(chosen[0])
		return bypass
	var nodes: Array[Vector3] = [original_start, finish]
	var corner_margin := clearance + 0.18
	for blocker in blockers:
		if not _blocker_affects_path(blocker, original_start, finish, clearance):
			continue
		_append_blocker_waypoints(nodes, blocker, original_start, finish, original_start.y, corner_margin, blockers, clearance)

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
			if not _movement_segment_clear(
				nodes[current], nodes[other], blockers, clearance + 0.04, null, true
			):
				continue
			var candidate := distances[current] + _flat_distance(nodes[current], nodes[other])
			if candidate < distances[other]:
				distances[other] = candidate
				previous[other] = current

	if previous[1] < 0:
		var retry_chosen: Array = [prefer]
		var retry := _try_circle_bypass(
			original_start, finish, blockers, clearance + 0.1, prefer, 0, retry_chosen, false
		)
		if retry.size() > 0:
			if wrap_io.size() > 0:
				wrap_io[0] = float(retry_chosen[0])
			return retry
		var forced_chosen: Array = [prefer]
		var forced := _try_circle_bypass(
			original_start, finish, blockers, clearance, prefer, 0, forced_chosen, true
		)
		if forced.size() > 0:
			if wrap_io.size() > 0:
				wrap_io[0] = float(forced_chosen[0])
			return forced
		if wrap_io.size() > 0:
			wrap_io[0] = prefer
		return PackedVector3Array([finish])
	var reverse_path: Array[Vector3] = []
	var cursor := 1
	while cursor > 0:
		reverse_path.append(nodes[cursor])
		cursor = previous[cursor]
	reverse_path.reverse()
	## Do not walk to a radially pushed start first — that is "run away from the pillar".
	if reverse_path.size() > 0 and _flat_distance(reverse_path[0], start) < 0.12:
		reverse_path.remove_at(0)
	if reverse_path.is_empty():
		reverse_path.append(finish)
	if wrap_io.size() > 0:
		wrap_io[0] = prefer
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


func los_cover(from: Vector3, to: Vector3, extra_exclude: Array[RID] = [], ray_y: float = 1.05) -> LosCover:
	var hit := spell_wall_hit(from, to, extra_exclude, ray_y)
	if hit.is_empty():
		return LosCover.OPEN
	var col: Variant = hit.get("collider")
	if col is SpellWall:
		var wall := col as SpellWall
		if wall.is_cover_solid():
			return LosCover.WALL
		return LosCover.OPEN
	if col is ArenaPillar:
		var pillar := col as ArenaPillar
		if pillar.living:
			return LosCover.PILLAR
		return LosCover.OPEN
	return LosCover.PILLAR


func beam_soak_hit(from: Vector3, to: Vector3, extra_exclude: Array[RID] = [], ray_y: float = 1.05, shot_source: Unit = null) -> Dictionary:
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
	var mask := SpellWall.shot_block_mask() | 2
	for _i in 8:
		var q := PhysicsRayQueryParameters3D.create(a, b)
		q.collision_mask = mask
		q.exclude = exclude
		q.collide_with_areas = false
		q.collide_with_bodies = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var col = hit.get("collider")
		if _is_floor_collider(col):
			return {}
		if col is Unit:
			var u := col as Unit
			if u.team == Unit.TEAM_RAID and not u.is_dead:
				return hit
			exclude.append(u.get_rid())
			continue
		if col is ArenaPillar:
			if (col as ArenaPillar).living:
				return hit
			exclude.append((col as ArenaPillar).get_rid())
			continue
		if col is SpellWall:
			var wall := col as SpellWall
			if wall.blocks_shot(shot_source):
				return hit
			exclude.append(wall.get_rid())
			continue
		return hit
	return {}


func _is_floor_collider(obj: Object) -> bool:
	return obj is Node and String((obj as Node).name) == "Floor"


func _movement_blockers() -> Array[Dictionary]:
	# Map Obstacle* bodies plus living solid spell walls (ice, stone, lightning).
	# Fire/wind/illusion/divine/nature do not block walking; protection follows the caster.
	var frame := Engine.get_physics_frames()
	if frame == _blockers_frame:
		return _blockers_cache
	_blockers_frame = frame
	var blockers: Array[Dictionary] = []
	if nav_region != null:
		for child in nav_region.get_children():
			if child is SpellWall:
				continue
			if not child is StaticBody3D or not String(child.name).begins_with("Obstacle"):
				continue
			var body := child as StaticBody3D
			if body.collision_layer == 0:
				continue
			if child is ArenaPillar and not (child as ArenaPillar).living:
				continue
			_collect_box_blockers(body, blockers)
	for wall in SpellWall.living_walls():
		wall.append_movement_blockers(blockers)
	_blockers_cache = blockers
	return _blockers_cache


func _blocker_affects_path(blocker: Dictionary, from: Vector3, to: Vector3, clearance: float) -> bool:
	var xform := blocker["xform"] as Node3D
	if xform == null or not is_instance_valid(xform):
		return false
	var circle := float(blocker.get("circle", 0.0))
	var half: Vector3 = blocker["half"]
	var reach := clearance + 10.0
	if circle > 0.0:
		reach += circle
	else:
		reach += maxf(half.x, half.z)
	return _xz_dist_to_segment(xform.global_position, from, to) <= reach


func _xz_dist_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var abx := b.x - a.x
	var abz := b.z - a.z
	var len_sq := abx * abx + abz * abz
	var t := 0.0
	if len_sq > 0.0001:
		t = clampf(((point.x - a.x) * abx + (point.z - a.z) * abz) / len_sq, 0.0, 1.0)
	var dx := point.x - (a.x + abx * t)
	var dz := point.z - (a.z + abz * t)
	return sqrt(dx * dx + dz * dz)


func _append_blocker_waypoints(
	nodes: Array[Vector3],
	blocker: Dictionary,
	start: Vector3,
	finish: Vector3,
	height_y: float,
	corner_margin: float,
	blockers: Array[Dictionary],
	clearance: float
) -> void:
	var xform := blocker["xform"] as Node3D
	if xform == null or not is_instance_valid(xform):
		return
	var circle := float(blocker.get("circle", 0.0))
	if circle > 0.0:
		_append_circle_waypoints(nodes, blocker, start, finish, height_y, blockers, clearance)
		return
	var half: Vector3 = blocker["half"]
	var locals: Array[Vector3] = []
	var hx := half.x + corner_margin
	var hz := half.z + corner_margin
	locals.append(Vector3(-hx, 0.0, -hz))
	locals.append(Vector3(hx, 0.0, -hz))
	locals.append(Vector3(hx, 0.0, hz))
	locals.append(Vector3(-hx, 0.0, hz))
	if hx >= 1.35:
		locals.append(Vector3(0.0, 0.0, -hz))
		locals.append(Vector3(0.0, 0.0, hz))
	if hz >= 1.35:
		locals.append(Vector3(-hx, 0.0, 0.0))
		locals.append(Vector3(hx, 0.0, 0.0))
	for local_pt in locals:
		var corner := xform.to_global(local_pt)
		corner.y = height_y
		nodes.append(_valid_movement_point(corner, clearance, blockers))


func _try_circle_bypass(
	from: Vector3,
	finish: Vector3,
	blockers: Array[Dictionary],
	clearance: float,
	prefer_sign: float,
	depth: int,
	chosen_sign: Array,
	force: bool,
	ignore: Node3D = null
) -> PackedVector3Array:
	if depth > 3:
		return PackedVector3Array()
	var hit: Dictionary = {}
	var hit_d := INF
	for blocker in blockers:
		var circle := float(blocker.get("circle", 0.0))
		if circle <= 0.0:
			continue
		var xform := blocker["xform"] as Node3D
		if xform == null or not is_instance_valid(xform):
			continue
		if ignore != null and xform == ignore:
			continue
		var c := xform.global_position
		var a := Vector2(from.x - c.x, from.z - c.z)
		var b := Vector2(finish.x - c.x, finish.z - c.z)
		if not _segment_enters_circle(a, b, circle + clearance + 0.04, true):
			continue
		var d := _xz_dist_to_segment(c, from, finish)
		if d < hit_d:
			hit_d = d
			hit = blocker
	if hit.is_empty():
		return PackedVector3Array()
	var skip := hit["xform"] as Node3D
	var center := skip.global_position
	var short_sign := _shorter_wrap_sign(from, finish, center)
	var first := short_sign
	if absf(prefer_sign) > 0.5:
		first = signf(prefer_sign)
	var try_signs: Array[float] = [first, -first]
	var r_ring := float(hit.get("circle", 0.0)) + clearance + _PATH_RING_PAD
	for s in try_signs:
		var entry := _circle_touch_angle(from, center, r_ring, s)
		var exit_ang := _circle_touch_angle(finish, center, r_ring, -s)
		var span := _signed_arc_span(entry, exit_ang, s)
		## First click always takes the minor arc. The scenic TAU wrap was
		## what happened when the short side's chords failed a self-hit test.
		if not force and span > PI + 0.12 and (absf(prefer_sign) < 0.5 or signf(prefer_sign) != signf(s)):
			continue
		var wrap := _wrap_one_circle(from, finish, hit, clearance, blockers, s)
		if wrap.is_empty():
			continue
		if force or _path_from_clear(from, wrap, blockers, clearance, skip):
			if chosen_sign.size() > 0:
				chosen_sign[0] = s
			return wrap
		var body := _wrap_body_without_finish(wrap, finish)
		if body.is_empty() or not _path_from_clear(from, body, blockers, clearance, skip):
			continue
		var rest_chosen: Array = [0.0]
		var rest := _try_circle_bypass(
			body[body.size() - 1],
			finish,
			blockers,
			clearance,
			0.0,
			depth + 1,
			rest_chosen,
			force,
			skip
		)
		if rest.is_empty():
			continue
		if chosen_sign.size() > 0:
			chosen_sign[0] = s
		return _concat_paths(body, rest)
	return PackedVector3Array()


func _shorter_wrap_sign(from: Vector3, finish: Vector3, center: Vector3) -> float:
	var a0 := atan2(from.z - center.z, from.x - center.x)
	var a1 := atan2(finish.z - center.z, finish.x - center.x)
	var cw := _signed_arc_span(a0, a1, -1.0)
	var ccw := _signed_arc_span(a0, a1, 1.0)
	if cw <= ccw:
		return -1.0
	return 1.0


func _wrap_body_without_finish(wrap: PackedVector3Array, finish: Vector3) -> PackedVector3Array:
	var body := PackedVector3Array()
	for p in wrap:
		if _flat_distance(p, finish) < 0.15:
			continue
		body.append(p)
	return body


func _concat_paths(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in a:
		out.append(p)
	for p in b:
		if out.size() == 0 or _flat_distance(out[out.size() - 1], p) > 0.08:
			out.append(p)
	return out


func _wrap_one_circle(
	from: Vector3,
	finish: Vector3,
	blocker: Dictionary,
	clearance: float,
	blockers: Array[Dictionary],
	sign: float
) -> PackedVector3Array:
	var xform := blocker["xform"] as Node3D
	var circle := float(blocker.get("circle", 0.0))
	var r_ring := circle + clearance + _PATH_RING_PAD
	var center := xform.global_position
	var height_y := from.y
	var entry := _circle_touch_angle(from, center, r_ring, sign)
	var exit_ang := _circle_touch_angle(finish, center, r_ring, -sign)
	var span := _signed_arc_span(entry, exit_ang, sign)
	var steps := maxi(1, int(ceil(span / 0.22)))
	var pts: Array[Vector3] = []
	for i in range(0, steps + 1):
		var ang := entry + sign * span * float(i) / float(steps)
		var pt := Vector3(center.x + cos(ang) * r_ring, height_y, center.z + sin(ang) * r_ring)
		pt = _valid_movement_point(pt, clearance, blockers, xform)
		var is_exit := i == steps
		if not is_exit and _flat_distance(from, pt) < 0.2:
			continue
		if pts.size() > 0 and _flat_distance(pts[pts.size() - 1], pt) < 0.1:
			if is_exit:
				pts[pts.size() - 1] = pt
			continue
		pts.append(pt)
	if _flat_distance(from, finish) > 0.05:
		if pts.is_empty() or _flat_distance(pts[pts.size() - 1], finish) > 0.12:
			pts.append(finish)
	var packed := PackedVector3Array()
	for p in pts:
		packed.append(p)
	return packed


func _circle_touch_angle(origin: Vector3, center: Vector3, radius: float, side: float) -> float:
	var dx := origin.x - center.x
	var dz := origin.z - center.z
	var dist := sqrt(dx * dx + dz * dz)
	var base := atan2(dz, dx)
	## Already inside/on the ring: stay on this radial. Stepping ±0.20 rad
	## here was the first hop *backward* whenever wrap side flipped.
	if dist <= radius + 0.05:
		return base
	var spread := acos(clampf(radius / dist, -1.0, 1.0))
	return base + side * spread


func _signed_arc_span(from_ang: float, to_ang: float, sign: float) -> float:
	var raw := to_ang - from_ang
	if sign >= 0.0:
		return wrapf(raw, 0.0, TAU)
	return wrapf(-raw, 0.0, TAU)


func _path_from_clear(
	from: Vector3,
	pts: PackedVector3Array,
	blockers: Array[Dictionary],
	clearance: float,
	skip: Node3D = null
) -> bool:
	var prev := from
	for p in pts:
		if not _movement_segment_clear(prev, p, blockers, clearance + 0.04, skip):
			return false
		prev = p
	return true


func _append_circle_waypoints(
	nodes: Array[Vector3],
	blocker: Dictionary,
	start: Vector3,
	finish: Vector3,
	height_y: float,
	blockers: Array[Dictionary],
	clearance: float
) -> void:
	var xform := blocker["xform"] as Node3D
	var circle := float(blocker.get("circle", 0.0))
	var r_ring := circle + clearance + _PATH_RING_PAD
	var center := xform.global_position
	var angs: Array[float] = []
	var a0 := atan2(start.z - center.z, start.x - center.x)
	var a1 := atan2(finish.z - center.z, finish.x - center.x)
	## Sample both wraps from a step off the start radial. A vertex *at* the
	## start angle is behind the unit and becomes Dijkstra's first hop away.
	_append_arc_angles(angs, a0, a1, 1.0)
	_append_arc_angles(angs, a0, a1, -1.0)
	_append_circle_tangents(angs, start, center, r_ring)
	_append_circle_tangents(angs, finish, center, r_ring)
	for ang in angs:
		var pt := Vector3(center.x + cos(ang) * r_ring, height_y, center.z + sin(ang) * r_ring)
		nodes.append(_valid_movement_point(pt, clearance, blockers, xform))


func _append_arc_angles(angs: Array[float], from_ang: float, to_ang: float, sign: float) -> void:
	var span := _signed_arc_span(from_ang, to_ang, sign)
	if span < 0.05:
		return
	var steps := maxi(2, int(ceil(span / 0.26)))
	for i in range(1, steps + 1):
		angs.append(from_ang + sign * span * float(i) / float(steps))


func _append_circle_tangents(angs: Array[float], origin: Vector3, center: Vector3, radius: float) -> void:
	var dx := origin.x - center.x
	var dz := origin.z - center.z
	var dist := sqrt(dx * dx + dz * dz)
	if dist <= radius + 0.02:
		return
	var base := atan2(dz, dx)
	var spread := acos(clampf(radius / dist, -1.0, 1.0))
	angs.append(base + spread)
	angs.append(base - spread)


func _collect_box_blockers(node: Node, blockers: Array[Dictionary]) -> void:
	if node is CollisionShape3D:
		var shape_node := node as CollisionShape3D
		if not shape_node.disabled:
			if shape_node.shape is BoxShape3D:
				var box := shape_node.shape as BoxShape3D
				blockers.append({"xform": shape_node, "half": box.size * 0.5})
			elif shape_node.shape is CylinderShape3D:
				var cyl := shape_node.shape as CylinderShape3D
				blockers.append({
					"xform": shape_node,
					"half": Vector3(cyl.radius, cyl.height * 0.5, cyl.radius),
					"circle": cyl.radius,
				})
	for child in node.get_children():
		_collect_box_blockers(child, blockers)


func clamp_movement_point(requested: Vector3, clearance: float) -> Vector3:
	return _valid_movement_point(requested, clearance, _movement_blockers())


func _valid_movement_point(
	requested: Vector3,
	clearance: float,
	blockers: Array[Dictionary],
	skip: Node3D = null
) -> Vector3:
	var point := Vector3(requested.x, requested.y, requested.z)
	var max_radius := maxf(1.0, ArenaState.arena_radius - clearance - 0.4)
	var flat := Vector2(point.x, point.z)
	if flat.length() > max_radius:
		flat = flat.normalized() * max_radius
		point.x = flat.x
		point.z = flat.y
	for blocker in blockers:
		var xform := blocker["xform"] as Node3D
		if xform == null or not is_instance_valid(xform):
			continue
		if skip != null and xform == skip:
			continue
		var half: Vector3 = blocker["half"]
		var local := xform.to_local(point)
		var circle := float(blocker.get("circle", 0.0))
		if circle > 0.0:
			var radial := Vector2(local.x, local.z)
			var limit := circle + clearance + _PATH_RING_PAD
			if radial.length() < limit:
				if radial.length_squared() < 0.0000001:
					radial = Vector2(1.0, 0.0)
				radial = radial.normalized() * limit
				local.x = radial.x
				local.z = radial.y
				point = xform.to_global(local)
				point.y = requested.y
			continue
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
	clearance: float,
	skip: Node3D = null,
	strict_inside: bool = false
) -> bool:
	for blocker in blockers:
		var xform := blocker["xform"] as Node3D
		if xform == null or not is_instance_valid(xform):
			continue
		if skip != null and xform == skip:
			continue
		var half: Vector3 = blocker["half"]
		var a := xform.to_local(from)
		var b := xform.to_local(to)
		var circle := float(blocker.get("circle", 0.0))
		if circle > 0.0:
			if _segment_enters_circle(
				Vector2(a.x, a.z), Vector2(b.x, b.z), circle + clearance, strict_inside
			):
				return false
			continue
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


func _segment_enters_circle(
	a: Vector2,
	b: Vector2,
	radius: float,
	strict_inside: bool = false
) -> bool:
	var delta := b - a
	var a_len := a.length()
	var b_len := b.length()
	if not strict_inside and a_len < radius:
		## Follow-time only: allow walking out of the keep-out. Planning uses
		## strict closest-approach so a hug does not count as a clear shortcut.
		return delta.dot(a) < -0.0001 or b_len < radius
	var len_sq := delta.length_squared()
	var t := 0.0
	if len_sq > 0.0001:
		t = clampf(-a.dot(delta) / len_sq, 0.0, 1.0)
	if not strict_inside and t <= 0.0001:
		return false
	return (a + delta * t).length() < radius


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _sun_light() -> DirectionalLight3D:
	if _layout:
		return _layout.sun_light()
	return get_node_or_null("DirectionalLight3D") as DirectionalLight3D


func _fill_light() -> OmniLight3D:
	if _layout:
		return _layout.fill_light()
	return get_node_or_null("FillLight") as OmniLight3D


func _world_env() -> WorldEnvironment:
	if _layout:
		return _layout.world_environment()
	return get_node_or_null("WorldEnvironment") as WorldEnvironment


func _layout_player_spawn(training: bool) -> Vector3:
	if _layout:
		return _layout.player_spawn(training)
	return ArenaLayout.DEFAULT_TRAINING_PLAYER if training else ArenaLayout.DEFAULT_PLAYER


func _layout_boss_spawn() -> Vector3:
	if _layout:
		return _layout.boss_spawn()
	return ArenaLayout.DEFAULT_BOSS


func _layout_training_dummy() -> Vector3:
	if _layout:
		return _layout.training_dummy_spawn()
	return ArenaLayout.DEFAULT_TRAINING_DUMMY


func _layout_training_pack() -> Vector3:
	if _layout:
		return _layout.training_pack_spawn()
	return ArenaLayout.DEFAULT_TRAINING_PACK


func _layout_training_ally() -> Vector3:
	if _layout:
		return _layout.training_ally_spawn()
	return ArenaLayout.DEFAULT_TRAINING_ALLY


func _layout_training_shooter() -> Vector3:
	if _layout:
		return _layout.training_shooter_spawn()
	return ArenaLayout.DEFAULT_TRAINING_SHOOTER


func _layout_training_shooter_dir() -> Vector3:
	if _layout:
		return _layout.training_shooter_dir()
	return ArenaLayout.DEFAULT_TRAINING_SHOOTER_DIR


func _layout_chase_pad() -> Vector3:
	if _layout:
		return _layout.chase_pad_position()
	return CHASE_PAD_POS


func _layout_raid_spawn(member_id: String, player_role: String) -> Vector3:
	if _layout:
		return _layout.raid_member_spawn(member_id, player_role)
	return RaidComp.member_position(member_id, player_role)


func _layout_pillar_anchors() -> Array[Vector3]:
	var anchors: Array[Vector3] = []
	if _layout:
		anchors = _layout.pillar_anchors()
	if not anchors.is_empty():
		return anchors
	for i in 10:
		var angle := TAU * float(i) / 10.0
		anchors.append(Vector3(cos(angle) * 17.0, 0.0, sin(angle) * 17.0))
	return anchors
