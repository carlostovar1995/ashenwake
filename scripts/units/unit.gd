class_name Unit
extends CharacterBody3D

const _IceBlastFx := preload("res://scripts/visual/ice_blast_fx.gd")
const _ThunderWaveFx := preload("res://scripts/visual/thunder_wave_fx.gd")
const _ChilledGround := preload("res://scripts/visual/chilled_ground_fx.gd")
const _Sanctuary := preload("res://scripts/visual/sanctuary_fx.gd")
const _MeteorFx := preload("res://scripts/visual/meteor_fx.gd")
const _GroundAoe := preload("res://scripts/visual/ground_aoe_fx.gd")
const _SpellAura := preload("res://scripts/visual/spell_aura_fx.gd")
const _SpellRay := preload("res://scripts/visual/spell_ray_fx.gd")
const _SpellWall := preload("res://scripts/combat/spell_wall.gd")
const _SpellBaseFx := preload("res://scripts/visual/spell_base_fx.gd")
const _GroundBlast := preload("res://scripts/visual/ground_blast_fx.gd")
const EnemyNameplate := preload("res://scripts/ui/enemy_nameplate.gd")

signal died(unit)
signal damaged(unit, amount, source, spell_id)
signal healed(unit, amount, source, spell_id)

const TEAM_RAID := 0
const TEAM_BOSS := 1
const TEAM_CONTESTED := 2
const MARK_TIME := 5.0
const BURN_RATIO := 0.5
const BURN_DURATION := 10.0
const BURN_TICK := 1.0
const GLOBAL_COOLDOWN := 0.5
const BASE_MOVE_SPEED := 5.5
const DODGE_DISTANCE := 6.0
const DODGE_DURATION := 0.4
const DODGE_COOLDOWN := 4.5
const SHOCK_MAX := 100
const SHOCK_TIME := 10.0
const SHOCK_CHAIN_RATIO := 0.20
const SHOCK_CHAIN_RANGE := 7.0
const SHOCK_CHAIN_HOPS := 3
const SHOCK_CHAIN_BATCH_WINDOW := 0.08
const MAX_SHOCK_BATCHES_PER_PHYSICS_FRAME := 12
const CHARGED_MANA_DIV := 4.0
const AFFLICT_DURATION := 10.0
const AFFLICT_TICK := 1.0
const REJUV_DURATION := 6.0
const REJUV_TICK := 1.0
const REJUV_STACK_MAX := 12
const PROTECTION_SHIELD_TIME := 6.0
const BLESSING_MAX := 0.10
const BLESSING_REF := 200.0
const BLESSING_TIME := 8.0
const OVERHEAT_CD_REFUND := 3.0
const OVERHEAT_CD_REFUND_CAP := 4
const INFUSION_DOUBLE_FIRE := 1
const INFUSION_DOUBLE_ICE := 2
const INFUSION_DOUBLE_STORM := 4
const SHATTER_BONUS := 45.0
const CATACLYSM_BONUS := 80.0
const WARD_TIME := 6.0
const SHIELD_MOVE_SPEED := 0.15
const FREEZE_TIME := 5.0
const FREEZE_BOSS := 5.0
const FREEZE_ADD := 5.0
const LOCAL_OUTLINE_WIDTH := 0.020
const LOCAL_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const _DodgeClockShader := preload("res://scripts/visual/dodge_clock.gdshader")

@export var unit_name: String = "Champion"
@export var team: int = TEAM_RAID
@export var is_champion: bool = false
@export var is_boss: bool = false
## Bosses ignore knockback and knockup unless a fight sets this.
@export var allow_knock: bool = false
@export var enemy_rank: int = EnemyRank.Rank.NORMAL
@export var show_nameplate: bool = false
@export var body_color: Color = Color(0.28, 0.55, 0.95)
@export var radius: float = 0.45
@export var height: float = 1.8

@export var max_health: float = 650.0
@export var max_mana: float = 400.0
@export var mana_regen: float = 10.0
@export var move_speed: float = BASE_MOVE_SPEED
@export var turn_rate: float = 20.0
@export var acceleration: float = 42.0
@export var deceleration: float = 55.0

@export var attack_damage: float = 58.0
@export var attack_range: float = 6.2
@export var attack_windup: float = 0.18
@export var attack_cooldown: float = 0.95
@export var attack_projectile_speed: float = 22.0
@export var is_melee: bool = false
@export var visual_path: String = ""
@export var visual_scale: float = 1.0
@export var visual_yaw: float = PI
@export var visual_pitch: float = 0.0
@export var visual_y_offset: float = 0.0
@export var immortal: bool = false
@export var despawn_on_death: bool = false
@export var heal_practice: bool = false
@export var attack_vfx_scene: String = ""
@export var attack_vfx_scale: float = 0.3
@export var attack_vfx_yaw: float = 0.0
@export var attack_applies_charged: bool = false
var atonement_ratio: float = 0.0
var threat_mult: float = 1.0
var attack_shield: float = 0.0
var attack_shield_duration: float = 0.0
var attack_mana_restore: float = 0.0

const HEAL_PRACTICE_RESET := 3.0
const DUMMY_HOME_WAIT := 10.0
const DUMMY_HOME_SLACK := 0.45

var health: float
var mana: float
var is_dead: bool = false
var _heal_practice_reset: float = 0.0
var _home_reset: bool = false
var _home_pos: Vector3 = Vector3.ZERO
var _home_yaw: float = 0.0
var _home_away: float = 0.0
var _home_return_left: float = 0.0
var _home_return_dur: float = 0.0
var _home_return_from: Vector3 = Vector3.ZERO
var ai_enabled: bool = false
var is_structure: bool = false
var host_wall: SpellWall = null

var abilities: Array[AbilityDef] = []
var cooldown_left: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _cooldown_max: Array[float] = [0.0, 0.0, 0.0, 0.0]
var global_cooldown_left: float = 0.0
var _gcd_from_exempt: bool = false
var _gcd_max: float = 0.0
var dodge_cooldown_left: float = 0.0

@onready var controller: UnitController = $Controller
@onready var movement: UnitMovement = $Movement
@onready var auto_attack: AutoAttack = $AutoAttack

var _mesh: MeshInstance3D
var _face: MeshInstance3D
var _hp_root: Node3D
var _feet_root: Node3D
var _bar: MeshInstance3D
var _bar_bg: MeshInstance3D
var _shield_bar: MeshInstance3D
var _mp_bar: MeshInstance3D
var _mp_bg: MeshInstance3D
var _label: Label3D
var _nameplate: Node3D
var _hp_ui_sig: int = 0
var _hp_ui_acc: float = 0.12
var _bar_width: float = 1.9
var _hp_bar_y: float = 0.0
var _mp_bar_y: float = 0.0
var _slow_left: float = 0.0
var _slow_percent: float = 0.0
var _haste_left: float = 0.0
var _haste_percent: float = 0.0
var _haste_max: float = 0.0
var _dr_left: float = 0.0
var _dr_percent: float = 0.0
var _dr_max: float = 0.0
var _mark_fire: float = 0.0
var _mark_ice: float = 0.0
var _mark_storm: float = 0.0
var _charged_stacks: int = 0
var _pending_shock_chains: Dictionary = {}
var _shock_chain_flush_scheduled: bool = false
var _shock_chain_batch_left: float = 0.0
var _shock_chain_flush_queued: bool = false
var _chill_percent: float = 0.0
var _chill_stacks: int = 0
var _chill_progress: float = 0.0
var _chill_left: float = 0.0
var _spread_chill: int = 0
var _spread_chill_left: float = 0.0
var _freeze_immune_left: float = 0.0
var _afflict_stacks: int = 0
var _afflict_left: float = 0.0
var _afflict_acc: float = 0.0
var _afflict_src: Unit
var _spread_afflict: int = 0
var _spread_afflict_left: float = 0.0
var _seed_stacks: int = 0
var _seed_left: float = 0.0
var _seed_src: Unit
var _judged_stacks: int = 0
var _judged_left: float = 0.0
var _sunder_stacks: int = 0
var _sunder_left: float = 0.0
var _judgment_brand: int = 0
var _singe_stacks: int = 0
var _singe_left: float = 0.0
var _singe_src: Unit
var _scorch_left: float = 0.0
var _scorch_snare: float = 0.0
var _scorch_src: Unit
var _ashen_absorbed: int = 0
var _blessing_dr: float = 0.0
var _blessing_left: float = 0.0
var _blessing_max: float = 0.0
var _burn_layers: Array[Dictionary] = []
var _burn_acc: float = 0.0
var _rejuv_stacks: int = 0
var _rejuv_left: float = 0.0
var _rejuv_acc: float = 0.0
var _rejuv_src: Unit
var _lifebloom_left: float = 0.0
var _lifebloom_max: float = 0.0
var _lifebloom_hps: float = 0.0
var _lifebloom_acc: float = 0.0
var _lifebloom_bloom: float = 0.0
var _lifebloom_src: Unit
var _stormbond_left: float = 0.0
var _stormbond_src: Unit
var _shock_src: Unit
var _shield_layers: Array[Dictionary] = []
var _cast_power: float = 1.0
var _recast_index: int = -1
var _recast_left: float = 0.0
var _illusion_exit_dir: Vector3 = Vector3.ZERO
var _echoing: bool = false
var _illusion_echoing: bool = false
var _illusion_invis_left: float = 0.0
var _illusion_invis_max: float = 0.0
var _channel_was_recast: bool = false
var _channel_combat_text_cast_id: int = -1
var _ward_left: float = 0.0
var _ward_time: float = 0.0
static var _mark_pip_tex: Texture2D
static var _shock_batch_queue: Array[int] = []
static var _shock_batch_queued: Dictionary = {}
static var _shock_batch_frame: int = -1
static var _shock_batches_used: int = 0
static var _shock_scheduler_arena_id: int = 0
var _ability_hover: bool = false
var _hover_mat: ShaderMaterial
var _hover_color: Color = Color(1.0, 0.82, 0.28, 0.92)
var _name_frame: MeshInstance3D
var _hp_frame: MeshInstance3D
var _mp_frame: MeshInstance3D
var _combo_border: MeshInstance3D
var _dodge_clock: MeshInstance3D
var _dodge_clock_mat: ShaderMaterial
var _bar_thick: float = 0.18
var _infusion: int = AbilityDef.Element.NONE
var _overcharge_left: float = 0.0
var _overcharge_max: float = 0.0
var _overcharge_mana_cut: float = 0.0
var _overcharge_cast_bonus: float = 0.0
var _overcharge_cooldown_rate: float = 1.0
var _overheat_cast_seq: int = 0
var _overheat_refund_left: Dictionary = {}
var _momentum_spent: Dictionary = {}
var _charge_mana_open: Dictionary = {}
var _slow_max: float = 0.0
var _ward_max: float = 0.0
var _floor_zones: Dictionary = {}
var _floor_extras: Dictionary = {}
var _stun_left: float = 0.0
var _stun_max: float = 0.0
var _shatter_fire_contrib: float = 0.0
var _shatter_shadow_contrib: float = 0.0
var wind: UnitWindState = UnitWindState.new()
var _pending_freeze: bool = false
var _pending_freeze_source: Unit
var _overcharge_sfx: int = 0
var _free_casts: int = 0
var _free_cast_max: int = 0
var _free_cast_pips: Array[Sprite3D] = []
var _atonement_amp: float = 0.0
var _ward_source: Unit
var altered: UnitAlteredState = UnitAlteredState.new()
var _talent_hooks: TalentHooks
var _class_auto: ClassAutoAttack
var _skill_recast: bool = false
var _wraithfire_pending: bool = false
var _nature_hedge_left: float = 0.0
var _auras: Dictionary = {}
var _spell_rays: Array = []
var _illusion_ray_pulsed: bool = false
var _illusion_missile_extras: Array[Unit] = []
var _spell_wall: Node


func _ready() -> void:
	if is_boss and enemy_rank == EnemyRank.Rank.NORMAL:
		enemy_rank = EnemyRank.Rank.ELITE
	health = 1.0 if heal_practice else max_health
	mana = max_mana
	add_to_group("units")
	collision_layer = 0 if is_structure else 2
	collision_mask = 0 if is_structure else 1
	floor_snap_length = 0.4
	## Rising pillars are StaticBody3Ds. Inheriting their interpolated motion
	## launches anyone who overlaps the volume for one physics frame.
	platform_on_leave = PLATFORM_ON_LEAVE_DO_NOTHING
	_ensure_body()
	call_deferred("_attach_visual")
	if abilities.is_empty() and not is_structure:
		_setup_default_abilities()
	while cooldown_left.size() < abilities.size():
		cooldown_left.append(0.0)
	while _cooldown_max.size() < cooldown_left.size():
		_cooldown_max.append(0.0)
	ArenaState.register_unit(self)
	set_physics_process(true)


func _exit_tree() -> void:
	ArenaState.unregister_unit(self)


func apply_compiled_abilities(next: Array[AbilityDef]) -> void:
	stop_aura()
	abilities = next
	AbilityDef.stamp_loadout_slots(abilities)
	while cooldown_left.size() < abilities.size():
		cooldown_left.append(0.0)
	while _cooldown_max.size() < cooldown_left.size():
		_cooldown_max.append(0.0)
	_illusion_missile_extras.clear()
	_clear_spell_ray()
	bind_talent_hooks(_talent_hooks)


func bind_talent_hooks(hooks: TalentHooks) -> void:
	_talent_hooks = hooks
	if _talent_hooks == null:
		return
	for i in abilities.size():
		var ab: AbilityDef = abilities[i]
		if ab != null and (ab.skill_id == "pyroblast" or ab.skill_id == "pyre"):
			_talent_hooks.pyroblast_slot = i


func talent_hooks() -> TalentHooks:
	return _talent_hooks


func bind_class_auto(aa: ClassAutoAttack) -> void:
	_class_auto = aa
	if aa == null:
		return
	is_melee = aa.melee
	attack_damage = aa.attack_damage
	attack_range = aa.attack_range
	attack_cooldown = aa.attack_cooldown
	attack_windup = aa.attack_windup
	attack_applies_charged = aa.applies_charged
	attack_vfx_scene = aa.vfx_scene


func class_auto() -> ClassAutoAttack:
	return _class_auto


func _attach_visual() -> void:
	if visual_path.is_empty():
		return
	var existing := get_node_or_null("CharacterVisual")
	if existing != null and not (existing is CharacterVisual):
		existing.free()
	CharacterCatalog.attach(self, visual_path, visual_scale, visual_yaw, visual_y_offset, visual_pitch)


func _setup_default_abilities() -> void:
	var q := AbilityDef.make("q", "Bolt", "Q", AbilityDef.TargetMode.SKILLSHOT, 55, 5.5, 11.0, 85, Color(0.35, 0.75, 1.0))
	q.skillshot_width = 0.85
	q.skillshot_speed = 20.0
	q.skillshot_length = 12.0
	var w := AbilityDef.make("w", "Bind", "W", AbilityDef.TargetMode.UNIT, 50, 7.5, 8.5, 90, Color(0.55, 0.95, 0.55))
	w.heal = 95.0
	var e := AbilityDef.make("e", "Burst", "E", AbilityDef.TargetMode.GROUND, 70, 9.0, 9.5, 110, Color(0.95, 0.55, 0.2))
	e.aoe_radius = 2.6
	var r := AbilityDef.make("r", "Nova", "R", AbilityDef.TargetMode.SKILLSHOT, 100, 38.0, 16.0, 240, Color(0.85, 0.35, 1.0))
	r.skillshot_width = 1.35
	r.skillshot_speed = 16.5
	r.skillshot_length = 18.0
	r.cast_time = 0.28
	abilities = [q, w, e, r]
	AbilityDef.stamp_loadout_slots(abilities)


func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	for child in get_children():
		if child is AllyAI or child is BossAI or child is AddAI:
			child.set_process(enabled)
			child.set_physics_process(enabled)


func _ensure_body() -> void:
	if is_structure:
		_ensure_structure_body()
		return
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	col.shape = capsule
	col.position = Vector3(0, height * 0.5, 0)

	_mesh = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "MeshInstance3D"
		add_child(_mesh)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_mesh.mesh = mesh
	_mesh.position = Vector3(0, height * 0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.roughness = 0.45
	mat.metallic = 0.08
	_mesh.material_override = mat

	_face = get_node_or_null("FacingMarker") as MeshInstance3D
	if _face == null:
		_face = MeshInstance3D.new()
		_face.name = "FacingMarker"
		add_child(_face)
	var box := BoxMesh.new()
	box.size = Vector3(radius * 0.7, radius * 0.45, radius * 1.15)
	_face.mesh = box
	_face.position = Vector3(0, height * 0.55, -radius * 0.85)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = body_color.lightened(0.35)
	_face.material_override = face_mat

	_hp_root = Node3D.new()
	_hp_root.name = "HpAnchor"
	_hp_root.top_level = true
	# Anchors are posed in _process from the interpolated unit origin. Engine
	# interpolation on these top_level nodes would trail the rendered mesh.
	_hp_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_hp_root)

	var use_plate := _wants_enemy_nameplate()
	_bar_width = 2.08
	var overhead_hp := not _uses_feet_bars()
	_hp_bar_y = 0.0
	_bar_thick = 0.28
	if team == TEAM_BOSS and not use_plate:
		_bar_width = 0.92
		_bar_thick = 0.18
	if overhead_hp:
		_bar_bg = _make_bar_trough(_hp_root, "HpBg", _hp_bar_y, _bar_thick, false)
		_bar = _make_bar_fill(_hp_root, "Hp", _hp_bar_y, _bar_thick, _hp_fill_color(), false)
		_shield_bar = _make_bar_fill(_hp_root, "Shield", _hp_bar_y, _bar_thick, _shield_fill_color(), false)
	else:
		_feet_root = Node3D.new()
		_feet_root.name = "FeetAnchor"
		_feet_root.top_level = true
		_feet_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_feet_root)
		var trough_h := _bar_fill_h() + _bar_pad() * 2.0
		var stack := trough_h + _bar_gap() if max_mana > 1.0 else 0.0
		_hp_bar_y = stack * 0.5
		_mp_bar_y = -stack * 0.5
		_bar_bg = _make_bar_trough(_feet_root, "HpBg", _hp_bar_y, _bar_thick, false)
		_bar = _make_bar_fill(_feet_root, "Hp", _hp_bar_y, _bar_thick, _hp_fill_color(), false)
		_shield_bar = _make_bar_fill(_feet_root, "Shield", _hp_bar_y, _bar_thick, _shield_fill_color(), false)
		if max_mana > 1.0:
			_mp_bg = _make_bar_trough(_feet_root, "MpBg", _mp_bar_y, _bar_thick, false)
			_mp_bar = _make_bar_fill(_feet_root, "Mp", _mp_bar_y, _bar_thick, Color(0.22, 0.48, 0.95), false)
		_combo_border = _make_outline_frame(_feet_root, "ComboBorder", false)
		_make_dodge_clock()

	_label = Label3D.new()
	_label.name = "NameTag"
	_label.text = unit_name
	_label.font_size = 44
	_label.pixel_size = 0.013
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 9
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.position = Vector3(0, 0.28 if overhead_hp else 0.10, 0)
	_hp_root.add_child(_label)
	if use_plate:
		_nameplate = EnemyNameplate.new()
		_nameplate.name = "Nameplate"
		_hp_root.add_child(_nameplate)
		if _bar:
			_bar.visible = false
		if _bar_bg:
			_bar_bg.visible = false
		if _shield_bar:
			_shield_bar.visible = false
		_label.visible = false
	elif team == TEAM_BOSS:
		_label.visible = false
	_make_hover_frames()
	_make_free_cast_pips()


func _ensure_structure_body() -> void:
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col == null:
		col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		add_child(col)
	var capsule := CapsuleShape3D.new()
	capsule.radius = maxf(radius, 0.2)
	capsule.height = maxf(height, 0.8)
	col.shape = capsule
	col.position = Vector3(0, height * 0.5, 0)
	col.disabled = true


func _tick_structure(delta: float) -> void:
	if host_wall == null or not is_instance_valid(host_wall) or not host_wall.living:
		if not is_dead:
			is_dead = true
			health = 0.0
			died.emit(self)
			_DamageNumber.clear_for(self)
		return
	health = host_wall.health
	max_health = host_wall.max_health
	if is_dead:
		return
	if _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - delta)
		if _slow_left <= 0.0:
			_slow_percent = 0.0
			_slow_max = 0.0
	if _freeze_immune_left > 0.0:
		_freeze_immune_left = maxf(0.0, _freeze_immune_left - delta)
		if _freeze_immune_left <= 0.0 and _chill_stacks >= EnemyRank.stack_max():
			_try_chill_freeze()
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		if _stun_left <= 0.0:
			_stun_max = 0.0
			_reset_shatter_shell()
	if _pending_freeze:
		flush_pending_freeze()
	_tick_burn(delta)
	_tick_afflict(delta)
	_tick_spread_copies(delta)
	_mark_ice = maxf(0.0, _mark_ice - delta)
	_chill_left = maxf(0.0, _chill_left - delta)
	if _chill_left <= 0.0:
		_clear_chill_stacks()
	_mark_storm = maxf(0.0, _mark_storm - delta)
	if _mark_storm <= 0.0:
		_charged_stacks = 0


func _physics_process(delta: float) -> void:
	if is_structure:
		_tick_structure(delta)
		return
	var overcharge_cooldown_rate := _overcharge_cooldown_rate if _overcharge_left > 0.0 else 1.0
	if _recast_left > 0.0:
		_recast_left = maxf(0.0, _recast_left - delta)
		if _recast_left <= 0.0:
			_expire_recast()
	if _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - delta)
		if _slow_left <= 0.0:
			_slow_percent = 0.0
			_slow_max = 0.0
	if _nature_hedge_left > 0.0:
		_nature_hedge_left = maxf(0.0, _nature_hedge_left - delta)
	if _haste_left > 0.0:
		_haste_left = maxf(0.0, _haste_left - delta)
		if _haste_left <= 0.0:
			_haste_percent = 0.0
			_haste_max = 0.0
	if _illusion_invis_left > 0.0:
		_illusion_invis_left = maxf(0.0, _illusion_invis_left - delta)
		if _illusion_invis_left <= 0.0:
			_illusion_invis_max = 0.0
			_refresh_stealth_visual()
	if _dr_left > 0.0:
		_dr_left = maxf(0.0, _dr_left - delta)
		if _dr_left <= 0.0:
			_dr_percent = 0.0
			_dr_max = 0.0
	_tick_elemental(delta)
	_tick_shock_chain_batch(delta)
	if not is_dead:
		mana = max_mana if GameSession.has_infinite_mana() else minf(max_mana, mana + mana_regen * delta)
		global_cooldown_left = maxf(0.0, global_cooldown_left - delta)
		dodge_cooldown_left = maxf(0.0, dodge_cooldown_left - delta)
		if immortal and not heal_practice:
			health = minf(max_health, health + max_health * 0.08 * delta)
		_tick_heal_practice(delta)
		for i in cooldown_left.size():
			if GameSession.ignores_cooldowns():
				cooldown_left[i] = 0.0
			else:
				var recovery_rate := overcharge_cooldown_rate
				if i < abilities.size() and abilities[i].grant_all_infusions:
					recovery_rate = 1.0
				cooldown_left[i] = maxf(0.0, cooldown_left[i] - delta * recovery_rate)
		if controller:
			controller.tick(delta)
		if is_stunned():
			velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO
		move_and_slide()
	_tick_dummy_home(delta)
	_update_hp_bar()


func _process(_delta: float) -> void:
	if _hp_root == null and _feet_root == null:
		set_process(false)
		return
	_sync_world_ui_anchors()


func hp_anchor_world() -> Vector3:
	if _hp_root:
		return _hp_root.global_position
	return global_position + Vector3(0, height + 0.62, 0)


func hp_bar_half_width() -> float:
	return _bar_width * 0.5


func uses_feet_resource_bars() -> bool:
	return _uses_feet_bars()


func feet_anchor_world() -> Vector3:
	if _feet_root:
		return _feet_root.global_position
	return _feet_bar_world()


func _visual_origin() -> Vector3:
	if is_inside_tree():
		return get_global_transform_interpolated().origin
	return global_position


func _feet_bar_world() -> Vector3:
	return _feet_bar_at(_visual_origin())


func _feet_bar_at(origin: Vector3) -> Vector3:
	var toward := Vector3(0.0, 0.0, 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		toward = cam.global_position - origin
		toward.y = 0.0
		if toward.length_squared() < 0.0001:
			toward = Vector3(0.0, 0.0, 1.0)
		else:
			toward = toward.normalized()
	return origin + toward * (radius + 0.32) + Vector3(0.0, 0.22, 0.0)


func _sync_world_ui_anchors() -> void:
	if _hp_root == null and _feet_root == null:
		return
	var origin := _visual_origin()
	if _hp_root:
		_face_camera(_hp_root, origin + Vector3(0, height + 0.62, 0))
	if _feet_root:
		_face_camera(_feet_root, _feet_bar_at(origin))


func nameplate_click_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	var hw := _bar_width * 0.5 + 0.12
	if _nameplate and _hp_root:
		var sz: Vector2 = _nameplate.world_size() if _nameplate.has_method("world_size") else Vector2(_bar_width + 0.2, 0.48)
		var mid := Vector3.ZERO
		if _nameplate.has_method("world_offset"):
			mid = _nameplate.world_offset()
		var o := _hp_root.global_position + mid
		var hx := sz.x * 0.5 + 0.04
		var hy := sz.y * 0.5 + 0.04
		out.append(o + Vector3(-hx, -hy, 0.0))
		out.append(o + Vector3(hx, -hy, 0.0))
		out.append(o + Vector3(-hx, hy, 0.0))
		out.append(o + Vector3(hx, hy, 0.0))
		return out
	if _hp_root:
		var o := _hp_root.global_position
		var top := 0.72 if _uses_feet_bars() else 0.98
		var bot := -0.14 if _uses_feet_bars() else -0.24
		out.append(o + Vector3(-hw, bot, 0.0))
		out.append(o + Vector3(hw, bot, 0.0))
		out.append(o + Vector3(-hw, top, 0.0))
		out.append(o + Vector3(hw, top, 0.0))
		if _label and _label.visible:
			var name_w := maxf(hw, 0.10 * float(maxi(unit_name.length(), 1)) + 0.16)
			var name_h := 0.30
			var n := o + _label.position
			out.append(n + Vector3(-name_w, -name_h, 0.0))
			out.append(n + Vector3(name_w, -name_h, 0.0))
			out.append(n + Vector3(-name_w, name_h, 0.0))
			out.append(n + Vector3(name_w, name_h, 0.0))
	if _feet_root:
		var xf := _feet_root.global_transform
		var trough_h := _bar_fill_h() + _bar_pad() * 2.0
		var top := _hp_bar_y + trough_h * 0.5 + 0.04
		var bot := (_mp_bar_y if _mp_bar else _hp_bar_y) - trough_h * 0.5 - 0.04
		out.append(xf * Vector3(-hw, bot, 0.0))
		out.append(xf * Vector3(hw, bot, 0.0))
		out.append(xf * Vector3(-hw, top, 0.0))
		out.append(xf * Vector3(hw, top, 0.0))
	return out


func opposite_team() -> int:
	return TEAM_BOSS if team == TEAM_RAID else TEAM_RAID


func is_hostile_to(other: Unit) -> bool:
	if other == null or not is_instance_valid(other):
		return false
	if team == TEAM_CONTESTED or other.team == TEAM_CONTESTED:
		return true
	return team != other.team


func _uses_feet_bars() -> bool:
	return team == TEAM_RAID


func _wants_enemy_nameplate() -> bool:
	return team == TEAM_BOSS and (is_boss or show_nameplate)


func _hp_fill_color() -> Color:
	return Color(0.25, 0.85, 0.35) if team == TEAM_RAID else Color(0.9, 0.2, 0.22)


func _shield_fill_color() -> Color:
	return Color(0.86, 0.90, 0.96)


func _bar_fill_h() -> float:
	return _bar_thick * 0.45


func _bar_pad() -> float:
	return 0.024


func _bar_gap() -> float:
	return 0.030


func _bar_trough_size() -> Vector2:
	return Vector2(_bar_width + _bar_pad() * 2.0, _bar_fill_h() + _bar_pad() * 2.0)


func _face_camera(node: Node3D, pos: Vector3) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		node.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	var z := cam.global_position - pos
	if z.length_squared() < 0.0001:
		node.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	z = z.normalized()
	var x := cam.global_transform.basis.y.cross(z)
	if x.length_squared() < 0.0001:
		x = cam.global_transform.basis.x
	x = x.normalized()
	var y := z.cross(x).normalized()
	node.global_transform = Transform3D(Basis(x, y, z), pos)


func _make_bar_mesh(parent: Node3D, mesh_name: String, size: Vector2, y: float, color: Color, priority: int, billboard: bool = true) -> MeshInstance3D:
	var mi := WorldUiMesh.quad(mesh_name, size, color, priority, billboard)
	mi.position = Vector3(0, y, 0)
	parent.add_child(mi)
	return mi


func _make_bar_trough(parent: Node3D, prefix: String, y: float, thick: float, billboard: bool = true) -> MeshInstance3D:
	return _make_bar_mesh(
		parent,
		prefix,
		Vector2(_bar_width + _bar_pad() * 2.0, thick * 0.45 + _bar_pad() * 2.0),
		y,
		Color(0.04, 0.04, 0.05),
		8,
		billboard
	)


func _make_bar_fill(parent: Node3D, prefix: String, y: float, thick: float, fill_color: Color, billboard: bool = true) -> MeshInstance3D:
	return _make_bar_mesh(
		parent,
		prefix + "Bar",
		Vector2(_bar_width, thick * 0.45),
		y,
		fill_color,
		9,
		billboard
	)


func _apply_bar_ratio(fill: MeshInstance3D, ratio: float, y: float) -> void:
	_apply_bar_segment(fill, 0.0, ratio, y, 0.0)


func _apply_bar_segment(fill: MeshInstance3D, start_ratio: float, width_ratio: float, y: float, z: float = 0.0) -> void:
	if fill == null:
		return
	var w := clampf(width_ratio, 0.0, 1.0)
	var width := _bar_width * maxf(w, 0.001)
	var mesh := fill.mesh as QuadMesh
	if mesh:
		mesh.size = Vector2(width, mesh.size.y)
	fill.scale = Vector3.ONE
	var left := -_bar_width * 0.5 + _bar_width * start_ratio
	fill.position = Vector3(left + width * 0.5, y, z)


func _update_hp_bar() -> void:
	if _bar == null and _nameplate == null:
		return
	_refresh_dodge_clock()
	_hp_ui_acc += get_physics_process_delta_time()
	var hp := 0.0 if is_dead else health
	var sh := 0.0 if is_dead else shield_amount()
	var mp := 0.0 if is_dead else mana
	var sig := int(hp * 10.0) ^ (int(sh * 10.0) << 10) ^ (int(mp) << 20)
	if is_dead:
		sig ^= 1
	if _ability_hover:
		sig ^= 2
	var force := _hp_ui_acc >= 0.12
	if not force and sig == _hp_ui_sig:
		return
	_hp_ui_sig = sig
	_hp_ui_acc = 0.0
	if _nameplate:
		_nameplate.visible = not is_dead
		if _nameplate.has_method("refresh"):
			_nameplate.refresh(self)
		if _bar:
			_bar.visible = false
		if _bar_bg:
			_bar_bg.visible = false
		if _shield_bar:
			_shield_bar.visible = false
		if _label:
			_label.visible = false
		_refresh_combo_border()
		_refresh_name_highlight()
		_refresh_hover_frames()
		_refresh_free_cast_pips()
		return
	if _bar_bg:
		_bar_bg.visible = not is_dead
	if _bar:
		_bar.visible = not is_dead
	var span := maxf(max_health, hp + sh)
	var hp_ratio := clampf(hp / span, 0.0, 1.0)
	var sh_ratio := clampf(sh / span, 0.0, 1.0)
	_apply_bar_segment(_bar, 0.0, hp_ratio, _hp_bar_y, 0.0)
	var bar_mat := _bar.material_override as StandardMaterial3D
	if bar_mat:
		_tint_bar_material(bar_mat, _hp_fill_color())
	if _shield_bar:
		_shield_bar.visible = not is_dead and sh_ratio > 0.008
		if _shield_bar.visible:
			_apply_bar_segment(_shield_bar, hp_ratio, sh_ratio, _hp_bar_y, 0.02)
			var sh_mat := _shield_bar.material_override as StandardMaterial3D
			if sh_mat:
				_tint_bar_material(sh_mat, _shield_fill_color())
	if _mp_bar:
		var mp_ratio := 0.0 if is_dead else clampf(mana / maxf(max_mana, 1.0), 0.0, 1.0)
		_apply_bar_ratio(_mp_bar, mp_ratio, _mp_bar_y)
		_mp_bar.visible = not is_dead and max_mana > 1.0
		if _mp_bg:
			_mp_bg.visible = _mp_bar.visible
		var mp_mat := _mp_bar.material_override as StandardMaterial3D
		if mp_mat:
			_tint_bar_material(mp_mat, Color(0.22, 0.48, 0.95))
	_refresh_combo_border()
	_refresh_name_highlight()
	_refresh_hover_frames()
	_refresh_free_cast_pips()


func current_move_speed() -> float:
	if is_stunned():
		return 0.0
	var spd := move_speed
	if _haste_left > 0.0:
		spd *= 1.0 + _haste_percent
	if shield_amount() > 0.05:
		spd *= 1.0 + SHIELD_MOVE_SPEED
	if _chill_stacks > 0 or _spread_chill > 0:
		spd *= 1.0 - clampf(float(_effective_chill_stacks()) * EnemyRank.slow_per_stack(), 0.0, 0.9)
	if _slow_left > 0.0:
		spd *= 1.0 - _slow_percent
	if _nature_hedge_left > 0.0:
		spd *= 1.0 - clampf(CombatBalance.pct("wall.nature.slow"), 0.0, 0.9)
	var seed_cut := UnitEnemyAlter.snare_cut(self)
	if seed_cut > 0.0:
		spd *= 1.0 - seed_cut
	if is_protection_hold():
		spd *= 1.0 - clampf(TalentCombat.protection_hold_slow(self), 0.0, 0.9)
	if altered.on_frost_trail:
		spd *= 1.0 + UnitAltered.ICE_SPEED
	return spd


func apply_slow(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_slow_percent = maxf(_slow_percent, percent) if _slow_left > 0.0 else percent
	_slow_left = maxf(_slow_left, duration)
	_slow_max = maxf(_slow_max, duration)


func apply_rooted(duration: float) -> void:
	if duration <= 0.05:
		return
	if _talent_hooks == null:
		_talent_hooks = TalentHooks.new()
	_talent_hooks.rooted_left = maxf(_talent_hooks.rooted_left, duration)
	apply_slow(0.70, duration)


func refresh_nature_hedge_slow() -> void:
	_nature_hedge_left = 0.15


func tick_wind_displace(delta: float) -> bool:
	return UnitWind.tick(self, delta)


func apply_haste(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_haste_percent = maxf(_haste_percent, percent) if _haste_left > 0.0 else percent
	_haste_left = maxf(_haste_left, duration)
	_haste_max = maxf(_haste_max, duration)


func apply_stealth(duration: float) -> void:
	if is_dead or duration <= 0.0:
		return
	_illusion_invis_left = maxf(_illusion_invis_left, duration)
	_illusion_invis_max = maxf(_illusion_invis_max, duration)
	ThreatTable.drop_unit(self)
	_refresh_stealth_visual()


func is_stealthed() -> bool:
	return _illusion_invis_left > 0.0


func can_be_aggroed() -> bool:
	return not is_structure and not is_dead and _illusion_invis_left <= 0.0


func ability_threat_mult(ability_id: String) -> float:
	if ability_id.is_empty():
		return 1.0
	var ab := _ability_def(ability_id)
	if ab == null:
		return 1.0
	return maxf(0.0, ab.threat_mult)


func _refresh_stealth_visual() -> void:
	var vis := get_node_or_null("CharacterVisual")
	if vis == null:
		return
	if vis.has_method("set_stealthed"):
		vis.call("set_stealthed", is_stealthed())
	else:
		_fade_model_meshes(vis, 0.80 if is_stealthed() else 0.0)


func _fade_model_meshes(n: Node, fade: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = fade
	for c in n.get_children():
		_fade_model_meshes(c, fade)


func apply_damage_reduction(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_dr_percent = maxf(_dr_percent, percent) if _dr_left > 0.0 else percent
	_dr_left = maxf(_dr_left, duration)
	_dr_max = maxf(_dr_max, duration)


func is_protection_hold() -> bool:
	return controller != null and controller.is_protection_hold()


func facing_dir() -> Vector3:
	var d := -global_transform.basis.z
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return d.normalized()


func angle_to_dir(dir: Vector3) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return 0.0
	return facing_dir().signed_angle_to(flat.normalized(), Vector3.UP)


func is_facing(dir: Vector3, threshold: float = 0.28) -> bool:
	return absf(angle_to_dir(dir)) <= threshold


func snap_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	rotation.y = Basis.looking_at(flat.normalized(), Vector3.UP).get_euler().y


func in_range_of(target: Node3D, extra: float = 0.0) -> bool:
	if target == null:
		return false
	if target is Unit:
		var u := target as Unit
		if u.is_structure and u.host_wall != null and is_instance_valid(u.host_wall):
			return u.host_wall.range_to(global_position) <= attack_range + radius + extra
		return global_position.distance_to(u.global_position) <= attack_range + radius + u.radius + extra
	var reach := attack_range + radius + float(target.get("radius")) + extra
	return global_position.distance_to(target.global_position) <= reach


func ability_in_range(ability: AbilityDef, point: Vector3, target: Unit = null) -> bool:
	if ability.target_mode == AbilityDef.TargetMode.SKILLSHOT or ability.target_mode == AbilityDef.TargetMode.INSTANT:
		return true
	if target != null and target.is_structure and target.host_wall != null and is_instance_valid(target.host_wall):
		return target.host_wall.range_to(global_position) <= ability.range + 0.35
	return global_position.distance_to(point) <= ability.range + 0.35


func hit_distance_to(point: Vector3) -> float:
	if is_structure and host_wall != null and is_instance_valid(host_wall):
		return host_wall.range_to(point)
	return global_position.distance_to(point) - radius


func can_cast(index: int) -> bool:
	if not can_prepare_cast(index):
		return false
	return not is_on_global_cooldown(index)


func can_prepare_cast(index: int) -> bool:
	if is_dead or is_stunned() or index < 0 or index >= abilities.size():
		return false
	if has_aura(index):
		return true
	if not abilities[index].implemented:
		return false
	if _aura_infusion_blocked(abilities[index]):
		return false
	if TalentCombat.undertow_empty(self, abilities[index]):
		return false
	if not GameSession.ignores_cooldowns() and cooldown_left[index] > 0.0 and not has_recast_ready(index):
		if not TalentCombat.allows_undertow_cast(self, abilities[index]):
			return false
	if GameSession.has_infinite_mana():
		return true
	return mana >= mana_cost_for(index)


func is_on_global_cooldown(index: int) -> bool:
	if global_cooldown_left <= 0.0:
		return false
	if index < 0 or index >= abilities.size():
		return false
	# Off-GCD spells can still weave during a normal GCD. Once an off-GCD spell
	# starts the GCD, every slot is locked — including other gcd_exempt spells.
	if abilities[index].gcd_exempt and not _gcd_from_exempt:
		return false
	return true


func trigger_global_cooldown(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	_gcd_max = gcd_duration()
	global_cooldown_left = _gcd_max
	_gcd_from_exempt = abilities[index].gcd_exempt


func clear_global_cooldown() -> void:
	global_cooldown_left = 0.0
	_gcd_from_exempt = false


func gcd_duration() -> float:
	return maxf(GLOBAL_COOLDOWN * cast_time_scale(), 0.05)


func gcd_clock_duration() -> float:
	if global_cooldown_left <= 0.0:
		return gcd_duration()
	return maxf(_gcd_max, global_cooldown_left)


func gcd_display_left(index: int) -> float:
	return global_cooldown_left if is_on_global_cooldown(index) else 0.0


func is_dodging() -> bool:
	return movement != null and movement.is_dodging()


func can_dodge() -> bool:
	if is_dead or is_stunned() or dodge_cooldown_left > 0.0:
		return false
	if is_dodging():
		return false
	var hooks := talent_hooks()
	if hooks != null and hooks.rooted_left > 0.05:
		return false
	return true


func try_dodge(dir: Vector3) -> bool:
	if not can_dodge() or movement == null:
		return false
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.04:
		flat = facing_dir()
	var dist := TalentCombat.dodge_distance(self, DODGE_DISTANCE)
	dodge_cooldown_left = TalentCombat.dodge_cooldown(self, DODGE_COOLDOWN)
	# Default for every class is a 0.4s roll. Only a talent that replaces dodge
	# (currently Wraithfire) may blink. Lunge still rolls; Worldroot blocks dodge.
	if TalentCombat.dodge_is_blink(self):
		_wraithfire_pending = true
		movement.blink_to(flat, dist)
		return true
	_wraithfire_pending = false
	movement.start_dodge(flat, dist, DODGE_DURATION)
	var vis := get_node_or_null("CharacterVisual") as CharacterVisual
	if vis != null:
		vis.play_dodge(DODGE_DURATION)
	return true


func on_dodge_landed() -> void:
	if not _wraithfire_pending:
		return
	_wraithfire_pending = false
	TalentCombat.wraithfire_nova(self)


func mana_cost_for(index: int) -> float:
	if index < 0 or index >= abilities.size():
		return 0.0
	var cost := abilities[index].mana_cost
	if _overcharge_left > 0.0:
		cost *= maxf(0.0, 1.0 - _overcharge_mana_cut)
	return cost


func cast_time_scale() -> float:
	var bonus := _cast_speed_bonus()
	if bonus <= 0.0:
		return 1.0
	return clampf(1.0 - bonus, 0.15, 1.0)


func _cast_speed_bonus() -> float:
	if _overcharge_left > 0.0:
		return maxf(_overcharge_cast_bonus, 0.0)
	return 0.0


func infusion_icon_tag() -> String:
	if _overcharge_left > 0.05:
		return "overcharge"
	match _infusion:
		AbilityDef.Element.FIRE:
			return "fire"
		AbilityDef.Element.ICE:
			return "ice"
		AbilityDef.Element.STORM:
			return "lightning"
		AbilityDef.Element.SHADOW:
			return "shadow"
		AbilityDef.Element.NATURE:
			return "nature"
		AbilityDef.Element.HOLY:
			return "divine"
		AbilityDef.Element.PROTECTION:
			return "protection"
		AbilityDef.Element.WIND:
			return "wind"
		AbilityDef.Element.ILLUSION:
			return "illusion"
		_:
			return ""


func infusion_label() -> String:
	if _overcharge_left > 0.0:
		return "Overcharge"
	match _infusion:
		AbilityDef.Element.FIRE:
			return "Fire Infused"
		AbilityDef.Element.ICE:
			return "Ice Infused"
		AbilityDef.Element.STORM:
			return "Lightning Infused"
		AbilityDef.Element.SHADOW:
			return "Shadow Infused"
		AbilityDef.Element.NATURE:
			return "Nature Infused"
		AbilityDef.Element.HOLY:
			return "Divine Infused"
		AbilityDef.Element.PROTECTION:
			return "Protection Infused"
		AbilityDef.Element.WIND:
			return "Wind Infused"
		AbilityDef.Element.ILLUSION:
			return "Illusion Infused"
		_:
			return ""


func collect_buffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _stun_left > 0.05:
		out.append(_frozen_status_entry())
	if _free_casts > 0:
		var n := _free_casts
		out.append({
			"id": "radiance",
			"icon": "radiance",
			"name": "Radiance",
			"color": Color(1.0, 0.9, 0.45),
			"time_left": 0.0,
			"duration": 0.0,
			"stacks": n,
			"description": "Your next %d spell%s have no cooldown." % [n, "" if n == 1 else "s"],
		})
	if _overcharge_left > 0.05:
		out.append({
			"id": "overcharge",
			"icon": "overcharge",
			"name": "Overcharge",
			"color": Color(0.95, 0.78, 0.28),
			"time_left": _overcharge_left,
			"duration": maxf(_overcharge_max, _overcharge_left),
			"description": "Casts faster. Spells cost less. Ability cooldowns recover at 2× speed.\nEvery spell is Fire, Ice, and Storm.",
		})
	elif _infusion != AbilityDef.Element.NONE:
		var name := "Infused"
		var icon := "infused"
		var color := Color.WHITE
		var desc := "Your next spell carries an extra element."
		match _infusion:
			AbilityDef.Element.FIRE:
				name = "Fire Infused"
				icon = "fire_infused"
				color = Color(1.0, 0.42, 0.12)
				desc = "Your next spell also Burns (%ss)." % str(BURN_DURATION)
			AbilityDef.Element.ICE:
				name = "Ice Infused"
				icon = "ice_infused"
				color = Color(0.45, 0.82, 1.0)
				desc = "Your next spell also Chills."
			AbilityDef.Element.STORM:
				name = "Lightning Infused"
				icon = "storm_infused"
				color = Color(0.78, 0.68, 1.0)
				desc = "Your next spell also Shocks."
			AbilityDef.Element.SHADOW:
				name = "Shadow Infused"
				icon = "shadow"
				color = Color(0.52, 0.28, 0.72)
				desc = "Your next spell also Afflicts."
			AbilityDef.Element.NATURE:
				name = "Nature Infused"
				icon = "nature"
				color = Color(0.38, 0.82, 0.42)
				desc = "Your next spell also Rejuvenates."
			AbilityDef.Element.HOLY:
				name = "Divine Infused"
				icon = "divine"
				color = Color(0.95, 0.84, 0.38)
				desc = "Your next spell also heals allies."
			AbilityDef.Element.PROTECTION:
				name = "Protection Infused"
				icon = "protection"
				color = Color(0.72, 0.82, 0.98)
				desc = "Your next spell also Shields."
			AbilityDef.Element.WIND:
				name = "Wind Infused"
				icon = "wind"
				color = Color(0.72, 0.92, 0.82)
				desc = "Your next spell also carries Wind."
			AbilityDef.Element.ILLUSION:
				name = "Illusion Infused"
				icon = "illusion"
				color = Color(0.92, 0.55, 0.82)
				desc = "Your next spell also carries Illusion."
		out.append({
			"id": "infusion",
			"icon": icon,
			"name": name,
			"color": color,
			"time_left": 0.0,
			"duration": 0.0,
			"description": desc,
		})
	if shield_amount() > 0.05:
		out.append({
			"id": "ward",
			"icon": "ward",
			"name": "Shield",
			"color": Color(0.84, 0.88, 0.96),
			"time_left": _shield_time_left(),
			"duration": PROTECTION_SHIELD_TIME,
			"badge": str(int(round(shield_amount()))),
			"description": _shield_status_text(),
		})
	if _illusion_invis_left > 0.05:
		out.append({
			"id": "invisibility",
			"icon": "illusion",
			"name": "Invisibility",
			"color": Color(0.92, 0.55, 0.82),
			"time_left": _illusion_invis_left,
			"duration": maxf(_illusion_invis_max, _illusion_invis_left),
			"description": "Invisible. Threat is wiped. Mobs will not target you.",
		})
	if _haste_left > 0.05:
		out.append({
			"id": "frost_path",
			"icon": "chilled_ground",
			"name": "Icy Path",
			"color": Color(0.55, 0.88, 1.0),
			"time_left": _haste_left,
			"duration": maxf(_haste_max, _haste_left),
			"badge": "%d%%" % int(round(_haste_percent * 100.0)),
			"description": "Move faster on the ice.",
		})
	if _dr_left > 0.05:
		out.append({
			"id": "sanctuary_dr",
			"icon": "sanctuary",
			"name": "Sanctuary",
			"color": Color(0.95, 0.84, 0.38),
			"time_left": _dr_left,
			"duration": maxf(_dr_max, _dr_left),
			"badge": "%d%%" % int(round(_dr_percent * 100.0)),
			"description": "Take %d%% less damage." % int(round(_dr_percent * 100.0)),
		})
	if _slow_left > 0.05:
		out.append(_slow_status_entry())
	if not _burn_layers.is_empty():
		out.append(_burn_status_entry())
	if _rejuv_stacks > 0:
		out.append(_rejuv_status_entry())
	if _lifebloom_left > 0.05:
		out.append(_lifebloom_status_entry())
	if _stormbond_left > 0.05:
		out.append(_stormbond_status_entry())
	_append_storm_druid_buffs(out)
	if _recast_left > 0.05 and _recast_index >= 0 and _recast_index < abilities.size():
		var recast_ab := abilities[_recast_index]
		var portal := recast_ab.delivery == AbilityDef.Delivery.WALL and SpellWallLayout.style_id(recast_ab) == "illusion"
		out.append({
			"id": "recast",
			"icon": "recast",
			"name": "Portal" if portal else "Recast",
			"color": Color(0.95, 0.62, 0.88) if portal else Color(0.95, 0.82, 0.45),
			"time_left": _recast_left,
			"duration": maxf(recast_ab.recast_window, _recast_left),
			"badge": ("%d" % _ashen_absorbed) if recast_ab.skill_id == "ashen_wake" and _ashen_absorbed > 0 else "",
			"description": (
				"Recast to place the exit portal, then aim its direction."
				if portal
				else "Recast: dash again and release absorbed Afflict as Burn on units you pass through (400 stacks/target)."
				if recast_ab.skill_id == "ashen_wake"
				else "Recast %s instantly at %d%% damage." % [recast_ab.display_name, int(round(recast_ab.recast_damage_mult * 100.0))]
			),
		})
	_prune_auras()
	var aura_slots: Array = _auras.keys()
	aura_slots.sort()
	for slot in aura_slots:
		var idx := int(slot)
		if idx < 0 or idx >= abilities.size():
			continue
		var aura_ab: AbilityDef = abilities[idx]
		out.append({
			"id": "aura_%d" % idx,
			"icon": aura_ab.icon_id if not aura_ab.icon_id.is_empty() else "aura",
			"name": aura_ab.display_name,
			"color": aura_ab.color,
			"time_left": 0.0,
			"duration": 0.0,
			"description": "Aura is active. Click to dismiss, or recast the slot to turn it off.",
		})
	if _blessing_left > 0.05:
		out.append({
			"id": "holy_blessing",
			"icon": "holy_blessing",
			"name": "Holy Blessing",
			"color": Color(1.0, 0.86, 0.38),
			"time_left": _blessing_left,
			"duration": maxf(_blessing_max, _blessing_left),
			"badge": "%d%%" % int(round(_blessing_dr * 100.0)),
			"description": "Take %d%% less damage." % int(round(_blessing_dr * 100.0)),
		})
	if altered.fire_left > 0.05:
		out.append({
			"id": "altered_fire",
			"icon": "altered_fire",
			"name": "Altered Fire",
			"color": Color(1.0, 0.45, 0.12),
			"time_left": altered.fire_left,
			"duration": UnitAltered.BUFF_TIME,
			"description": "Spells deal +10% damage (+20% if fire-infused). 30% fire resistance.",
		})
	if altered.ice_left > 0.05:
		out.append({
			"id": "altered_ice",
			"icon": "altered_ice",
			"name": "Altered Ice",
			"color": Color(0.45, 0.82, 1.0),
			"time_left": altered.ice_left,
			"duration": UnitAltered.BUFF_TIME,
			"description": "Leaves a frost trail. +30% move speed on it. 30% ice resistance.",
		})
	if altered.storm_left > 0.05:
		out.append({
			"id": "altered_lightning",
			"icon": "altered_lightning",
			"name": "Altered Lightning",
			"color": Color(0.78, 0.68, 1.0),
			"time_left": altered.storm_left,
			"duration": UnitAltered.BUFF_TIME,
			"description": "Chains lightning every 0.25s. 20% less damage each bounce. 30% lightning resistance.",
		})
	if altered.shadow_left > 0.05:
		out.append({
			"id": "altered_shadow",
			"icon": "altered_shadow",
			"name": "Shadow Pact",
			"color": Color(0.62, 0.28, 0.82),
			"time_left": altered.shadow_left,
			"duration": UnitAltered.BUFF_TIME,
			"stacks": altered.shadow_stacks,
			"badge": str(altered.shadow_stacks),
			"description": "Pact DoT (%d/%d). +%d%% damage dealt. 30%% shadow resist (not vs the pact)." % [
				altered.shadow_stacks,
				UnitAltered.SHADOW_MAX,
				int(round(UnitAltered.SHADOW_DAMAGE * 100.0 * float(altered.shadow_stacks) / float(UnitAltered.SHADOW_MAX))),
			],
		})
	return out


func collect_debuffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _stun_left > 0.05:
		out.append(_frozen_status_entry())
	elif _pending_freeze:
		out.append(_pending_freeze_status_entry())
	if not _burn_layers.is_empty():
		out.append(_burn_status_entry())
	if _freeze_immune_left > 0.05 and _stun_left <= 0.05:
		out.append({
			"id": "freeze_immune",
			"icon": "freeze_immune",
			"name": "Freeze Immune",
			"color": Color(0.62, 0.78, 0.88),
			"time_left": _freeze_immune_left,
			"duration": EnemyRank.freeze_immune_time(combat_rank()),
			"description": "Cannot be frozen. Chill can still stack.",
		})
	if _chill_stacks > 0 or _spread_chill > 0:
		var shown := _effective_chill_stacks()
		var slow_pct := int(round(float(shown) * EnemyRank.slow_per_stack() * 100.0))
		out.append({
			"id": "chilled",
			"icon": "chilled",
			"name": "Chilled",
			"color": Color(0.45, 0.82, 1.0),
			"time_left": maxf(_chill_left, _spread_chill_left),
			"duration": MARK_TIME,
			"stacks": shown,
			"badge": str(shown),
			"description": "Slowed by %d%% (%d/%d). Lasts %ss without ice. Freeze at %d stacks for %ss (ice Chill only). Shock chains copy Chill scaled by Charge; the copy refreshes, it does not stack." % [
				slow_pct,
				shown,
				EnemyRank.stack_max(),
				str(MARK_TIME),
				EnemyRank.stack_max(),
				str(FREEZE_TIME),
			],
		})
	if _charged_stacks > 0:
		out.append({
			"id": "shocked",
			"icon": "shocked",
			"name": "Shocked",
			"color": Color(0.85, 0.72, 1.0),
			"time_left": _mark_storm,
			"duration": SHOCK_TIME,
			"stacks": _charged_stacks,
			"badge": "%d/%d" % [_charged_stacks, shock_stack_max()],
			"description": "Charge %d/%d. Lightning hits add 1 stack (2 on a crit). Hits chain lightning (%d%% of the hit now, 20%% at 100 Charge). 20%% less each bounce. Chain does not apply Shock. Higher Charge copies more Burn, Chill, and Afflict to hops. Copies refresh; they do not stack." % [
				_charged_stacks,
				shock_stack_max(),
				int(round(_shock_chain_ratio() * 100.0)),
			],
		})
	if _afflict_stacks > 0 or _spread_afflict > 0:
		out.append(_afflict_status_entry())
	if _seed_stacks > 0 and _seed_left > 0.05:
		out.append(_seeded_status_entry())
	if _judged_stacks > 0 and _judged_left > 0.05:
		out.append(_judged_status_entry())
	if _sunder_stacks > 0 and _sunder_left > 0.05:
		out.append(_sundered_status_entry())
	if _judgment_brand > 0:
		out.append(_solar_brand_status_entry())
	if _singe_stacks > 0 and _singe_left > 0.05:
		out.append(_singe_status_entry())
	if _scorch_left > 0.05:
		out.append(_scorch_status_entry())
	if is_protection_hold():
		var slow := TalentCombat.protection_hold_slow(self)
		var left := controller.channel_time_left() if controller != null else 0.0
		var hold := 4.0
		if controller != null:
			var hold_ab := controller.casting_ability()
			if hold_ab != null:
				hold = maxf(hold_ab.channel_time, left)
		out.append({
			"id": "protection_hold",
			"icon": "protection",
			"name": "Holding",
			"color": Color(0.78, 0.86, 1.0),
			"time_left": left,
			"duration": hold,
			"badge": "%d%%" % int(round(slow * 100.0)),
			"description": "Movement speed reduced by %d%% while the shield is up." % int(round(slow * 100.0)),
		})
	if _slow_left > 0.05:
		out.append(_slow_status_entry())
	return out


func collect_nameplate_debuffs() -> Array[Dictionary]:
	return UnitStatusSnapshots.nameplate_debuffs(self)


func _slow_status_entry() -> Dictionary:
	return {
		"id": "slow",
		"icon": "slow",
		"name": "Slowed",
		"color": Color(0.62, 0.84, 1.0),
		"time_left": _slow_left,
		"duration": maxf(_slow_max, _slow_left),
		"badge": "%d%%" % int(round(_slow_percent * 100.0)),
		"description": "Movement speed reduced by %d%%." % int(round(_slow_percent * 100.0)),
	}


func _solar_brand_status_entry() -> Dictionary:
	var extra := float(_judgment_brand) * CombatBalance.pct("dawnwarden.judgment.brand") * 100.0
	return {
		"id": "solar_brand",
		"icon": "solar_brand",
		"name": "Solar Brand",
		"color": Color(1.0, 0.55, 0.12),
		"stacks": _judgment_brand,
		"badge": str(_judgment_brand),
		"description": "Takes +%.1f%% damage (0.5%% per stack, no cap). Lasts the whole fight." % extra,
	}


func _singe_status_entry() -> Dictionary:
	return {
		"id": "singe",
		"icon": "singe",
		"name": "Singe",
		"color": Color(1.0, 0.55, 0.16),
		"time_left": _singe_left,
		"duration": TalentCombat.SINGE_DURATION,
		"stacks": _singe_stacks,
		"badge": "%d/%d" % [_singe_stacks, TalentCombat.SINGE_CAP],
		"description": "Fire mark %d/%d. At 3 stacks, Burst / Nova / Meteor / Pyre detonates it (Bolt / Missiles / Ray too at Singe 2+)." % [
			_singe_stacks,
			TalentCombat.SINGE_CAP,
		],
	}


func _scorch_status_entry() -> Dictionary:
	var snare := int(round(_scorch_snare * 100.0))
	return {
		"id": "scorch",
		"icon": "scorch",
		"name": "Scorched",
		"color": Color(0.92, 0.38, 0.08),
		"time_left": _scorch_left,
		"duration": TalentCombat.SCORCH_DURATION,
		"badge": "%d%%" % snare,
		"description": "Slowed %d%%. Fire hits store extra Burn. Lasts %ss." % [snare, str(TalentCombat.SCORCH_DURATION)],
	}


func _frozen_status_entry() -> Dictionary:
	var dur := maxf(_stun_max, _stun_left)
	return {
		"id": "frozen",
		"icon": "frozen",
		"name": "Frozen",
		"color": Color(0.62, 0.9, 1.0),
		"time_left": _stun_left,
		"duration": dur,
		"description": "Cannot move, attack, or cast for %ss.\nFire or Shadow damage can Shatter. The larger contributor decides a Fire Shatter or a Shadow Shatter." % str(FREEZE_TIME),
	}


func _pending_freeze_status_entry() -> Dictionary:
	var left := 0.8
	var brain := boss_brain()
	if brain:
		left = maxf(brain.remaining_ability_time(), 0.15)
	return {
		"id": "frozen_pending",
		"icon": "frozen",
		"name": "Freeze Primed",
		"color": Color(0.72, 0.92, 1.0),
		"time_left": left,
		"duration": maxf(left, 0.5),
		"description": "Will Freeze when this cast ends.",
	}


func _burn_status_entry() -> Dictionary:
	var tick := _burn_tick_damage()
	return {
		"id": "burn",
		"icon": "burn",
		"name": "Burn",
		"color": Color(1.0, 0.38, 0.08),
		"time_left": _burn_time_left(),
		"duration": BURN_DURATION,
		"badge": _burn_tick_badge(tick),
		"description": "Stores 50%% of Fire hits as damage over %ss. Shock chains copy remaining Fire Burn scaled by Charge (short tick, not the full layer). The copy refreshes; it does not stack, and it cannot chain again." % str(BURN_DURATION),
	}


func _afflict_status_entry() -> Dictionary:
	return {
		"id": "afflicted",
		"icon": "afflicted",
		"name": "Afflicted",
		"color": Color(0.62, 0.32, 0.82),
		"time_left": maxf(_afflict_left, _spread_afflict_left),
		"duration": AFFLICT_DURATION,
		"stacks": _afflict_display_stacks(),
		"badge": "%d" % _afflict_display_stacks(),
		"description": "1 damage per 4 stacks each second (%d/%d). Shadow hits add 1 stack (2 on a crit). Shock chains copy Afflict scaled by Charge; the copy refreshes, it does not stack. A Shadow Shatter copies a slice of stacks to nearby enemies." % [
			_afflict_display_stacks(),
			afflict_stack_max(),
		],
	}


func _seeded_status_entry() -> Dictionary:
	var snare := int(round(UnitEnemyAlter.snare_cut(self) * 100.0))
	var cap := UnitEnemyAlter.seed_max()
	return {
		"id": "seeded",
		"icon": "seeded",
		"name": "Seeded",
		"color": Color(0.42, 0.88, 0.42),
		"time_left": _seed_left,
		"duration": UnitEnemyAlter.buff_time(),
		"stacks": _seed_stacks,
		"badge": "%d/%d" % [_seed_stacks, cap],
		"description": "Slowed %d%%. Fire spends one seed for a splash. At %d seeds, the next Nature hit blooms." % [snare, cap],
	}


func _judged_status_entry() -> Dictionary:
	var taken := int(round(CombatBalance.pct("altered.divine.taken") * 100.0 * float(_judged_stacks)))
	var div := int(round(CombatBalance.flat("altered.divine.mend_div")))
	return {
		"id": "judged",
		"icon": "judged",
		"name": "Judged",
		"color": Color(1.0, 0.86, 0.38),
		"time_left": _judged_left,
		"duration": UnitEnemyAlter.buff_time(),
		"stacks": _judged_stacks,
		"badge": str(_judged_stacks),
		"description": "Divine hits deal +%d%%. Damage heals the lowest-HP nearby ally (hit / %d × stacks)." % [taken, div],
	}


func _sundered_status_entry() -> Dictionary:
	var cut := int(round(CombatBalance.pct("altered.protection.out") * 100.0 * float(_sunder_stacks)))
	var brk := int(round(CombatBalance.pct("altered.protection.break") * 100.0))
	return {
		"id": "sundered",
		"icon": "sundered",
		"name": "Sundered",
		"color": Color(0.78, 0.86, 1.0),
		"time_left": _sunder_left,
		"duration": UnitEnemyAlter.buff_time(),
		"stacks": _sunder_stacks,
		"badge": str(_sunder_stacks),
		"description": "Deals %d%% less damage. Hitting a shield breaks a stack and returns %d%% of the absorbed hit." % [cut, brk],
	}


func _rejuv_status_entry() -> Dictionary:
	var hps := _rejuv_hps()
	return {
		"id": "rejuvenation",
		"icon": "rejuvenation",
		"name": "Rejuvenation",
		"color": Color(0.42, 0.88, 0.48),
		"time_left": _rejuv_left,
		"duration": REJUV_DURATION,
		"stacks": _rejuv_stacks,
		"badge": "%d" % _rejuv_stacks,
		"description": "+%d HPS per stack (%d/%d). New nature heals add a stack (2 on a crit) and refresh the duration." % [
			int(round(hps)),
			_rejuv_stacks,
			REJUV_STACK_MAX,
		],
	}


func _lifebloom_status_entry() -> Dictionary:
	return {
		"id": "lifebloom",
		"icon": "lifebloom",
		"name": "Lifebloom",
		"color": Color(0.55, 1.0, 0.42),
		"time_left": _lifebloom_left,
		"duration": maxf(_lifebloom_max, _lifebloom_left),
		"badge": str(int(round(_lifebloom_hps))),
		"description": "+%d HPS. Blooms when it expires or is consumed." % int(round(_lifebloom_hps)),
	}


func _stormbond_status_entry() -> Dictionary:
	return {
		"id": "stormbond",
		"icon": "stormbond",
		"name": "Stormbond",
		"color": Color(0.55, 0.78, 1.0),
		"time_left": _stormbond_left,
		"duration": 8.0,
		"description": "Receives this caster's nature atonement pulse.",
	}


func _append_storm_druid_buffs(out: Array[Dictionary]) -> void:
	var hooks := talent_hooks()
	if hooks == null:
		return
	if hooks.drought_left > 0.05:
		out.append({
			"id": "drought",
			"icon": "drought",
			"name": "Drought",
			"color": Color(0.55, 0.42, 0.18),
			"time_left": hooks.drought_left,
			"duration": 4.0,
			"description": "Your nature crafts do not apply Rejuvenation." if not hooks.drought_rejuv_only else "Rejuvenation applications are suppressed.",
		})
	if hooks.rooted_left > 0.05:
		out.append({
			"id": "rooted",
			"icon": "rooted",
			"name": "Rooted",
			"color": Color(0.28, 0.48, 0.22),
			"time_left": hooks.rooted_left,
			"duration": 6.0,
			"description": "Cannot dodge. 70% slow. Knockback immune.",
		})
	if hooks.tempest_bloom_left > 0.05:
		out.append({
			"id": "tempest_bloom",
			"icon": "lightning",
			"name": "Tempest Bloom",
			"color": Color(0.55, 0.72, 0.95),
			"time_left": hooks.tempest_bloom_left,
			"duration": 8.0,
			"description": "Lightning heals. Nature crafts shock.",
		})
	if hooks.eye_storm_left > 0.05:
		out.append({
			"id": "storm_cloud",
			"icon": "lightning",
			"name": "Eye of the Storm",
			"color": Color(0.78, 0.68, 1.0),
			"time_left": hooks.eye_storm_left,
			"duration": 8.0,
			"description": "Storm cloud. Cannot apply Rejuvenation.",
		})


func _burn_tick_badge(tick: float) -> String:
	if tick <= 0.04:
		return ""
	if tick >= 9.5:
		return str(int(round(tick)))
	var tenths := snappedf(tick, 0.1)
	if is_equal_approx(tenths, round(tenths)):
		return str(int(round(tenths)))
	return "%0.1f" % tenths


func dismiss_buff(id: String) -> bool:
	if id == "aura":
		stop_aura()
		return true
	if id.begins_with("aura_"):
		stop_aura(id.substr(5).to_int())
		return true
	match id:
		"overcharge", "overcharged", "overheat":
			_overcharge_left = 0.0
			_overcharge_max = 0.0
			_overcharge_mana_cut = 0.0
			_overcharge_cast_bonus = 0.0
			_overcharge_cooldown_rate = 1.0
			_stop_overcharge_sfx(true)
			_refresh_infusion_visual()
			return true
		"radiance":
			_clear_radiance()
			return true
		"infusion":
			_infusion = AbilityDef.Element.NONE
			_refresh_infusion_visual()
			return true
		"ward":
			_clear_ward()
			return true
		"invisibility":
			_illusion_invis_left = 0.0
			_illusion_invis_max = 0.0
			ThreatTable.drop_unit(self)
			_refresh_stealth_visual()
			return true
		"slow":
			_slow_left = 0.0
			_slow_percent = 0.0
			_slow_max = 0.0
			return true
		"frost_path":
			_haste_left = 0.0
			_haste_percent = 0.0
			_haste_max = 0.0
			return true
		"sanctuary_dr":
			_dr_left = 0.0
			_dr_percent = 0.0
			_dr_max = 0.0
			return true
		"burn":
			_clear_burn()
			return true
		"afflicted":
			_clear_afflict()
			return true
		"seeded":
			UnitEnemyAlter.clear_seeded(self)
			return true
		"judged":
			UnitEnemyAlter.clear_judged(self)
			return true
		"sundered":
			UnitEnemyAlter.clear_sundered(self)
			return true
		"singe":
			_clear_singe()
			return true
		"scorch":
			clear_scorch()
			return true
		"rejuvenation":
			_clear_rejuv()
			return true
		"lifebloom":
			clear_lifebloom(false)
			return true
		"stormbond":
			_stormbond_left = 0.0
			_stormbond_src = null
			return true
		"encore", "recast":
			_expire_recast()
			return true
		"holy_blessing":
			_blessing_dr = 0.0
			_blessing_left = 0.0
			_blessing_max = 0.0
			return true
		"altered_fire":
			altered.fire_left = 0.0
			return true
		"altered_ice":
			_clear_altered_ice()
			return true
		"altered_lightning":
			altered.storm_left = 0.0
			altered.storm_acc = 0.0
			return true
		"altered_shadow":
			_clear_altered_shadow()
			return true
		"freeze_immune":
			_freeze_immune_left = 0.0
			return true
	return false


func _stop_overcharge_sfx(play_end: bool = false) -> void:
	AudioManager.stop_loop(_overcharge_sfx, 0.0)
	_overcharge_sfx = 0
	if play_end:
		AudioManager.play_at("overcharge.end", global_position + Vector3(0.0, height * 0.45, 0.0))


func free_cast_charges() -> int:
	return _free_casts


func free_cast_charge_max() -> int:
	return _free_cast_max


func _apply_radiance(ab: AbilityDef) -> void:
	if ab == null:
		return
	var n := ab.free_cast_charges
	if n <= 0:
		return
	_free_casts = n
	_free_cast_max = n
	_refresh_infusion_visual()
	_refresh_free_cast_pips()


func _clear_radiance() -> void:
	_free_casts = 0
	_free_cast_max = 0
	_atonement_amp = 0.0
	_refresh_infusion_visual()
	_refresh_free_cast_pips()


func _try_consume_free_cast() -> bool:
	if _free_casts <= 0:
		return false
	_free_casts -= 1
	if _free_casts <= 0:
		_free_cast_max = 0
		_refresh_infusion_visual()
	_refresh_free_cast_pips()
	return true


func _cast_extras(ab: AbilityDef) -> PackedInt32Array:
	var extras := PackedInt32Array()
	if ab == null:
		return extras
	if ab.free_cast_charges > 0:
		_apply_radiance(ab)
		return extras
	if ab.grant_all_infusions:
		_overcharge_left = maxf(_overcharge_left, ab.buff_duration)
		_overcharge_max = maxf(_overcharge_max, ab.buff_duration)
		_overcharge_mana_cut = maxf(_overcharge_mana_cut, ab.mana_cost_reduction)
		_overcharge_cast_bonus = maxf(_overcharge_cast_bonus, ab.cast_speed_bonus)
		_overcharge_cooldown_rate = maxf(_overcharge_cooldown_rate, ab.cooldown_recovery_rate)
		_refresh_infusion_visual()
		AudioManager.play_at("overcharge.activate", global_position + Vector3(0.0, height * 0.45, 0.0))
		AudioManager.stop_loop(_overcharge_sfx, 0.0)
		_overcharge_sfx = AudioManager.play_on("overcharge.loop", self)
		return extras
	for extra in ab.extra_elements:
		if extra == AbilityDef.Element.NONE or extra == ab.element:
			continue
		var seen := false
		for existing in extras:
			if existing == extra:
				seen = true
				break
		if not seen:
			extras.append(extra)
	return extras


func _refresh_infusion_visual() -> void:
	if _stun_left > 0.0:
		_refresh_freeze_visual()
		return
	var color := Color(0, 0, 0, 0)
	var strength := 0.0
	if _free_casts > 0:
		color = Color(0.98, 0.9, 0.42, 0.95)
		strength = 0.48
	elif _overcharge_left > 0.0:
		color = Color(0.95, 0.82, 0.35, 0.95)
		strength = 0.52
	else:
		match _infusion:
			AbilityDef.Element.FIRE:
				color = Color(1.0, 0.22, 0.05, 0.95)
				strength = 0.58
			AbilityDef.Element.ICE:
				color = Color(0.5, 0.88, 1.0, 0.95)
				strength = 0.55
			AbilityDef.Element.STORM:
				color = Color(0.55, 0.32, 0.95, 0.95)
				strength = 0.6
			AbilityDef.Element.SHADOW:
				color = Color(0.42, 0.16, 0.62, 0.95)
				strength = 0.58
			AbilityDef.Element.NATURE:
				color = Color(0.28, 0.78, 0.36, 0.95)
				strength = 0.52
			AbilityDef.Element.HOLY:
				color = Color(0.95, 0.84, 0.38, 0.95)
				strength = 0.5
			AbilityDef.Element.PROTECTION:
				color = Color(0.72, 0.82, 0.98, 0.95)
				strength = 0.5
	var vis := get_node_or_null("CharacterVisual")
	if vis and vis.has_method("set_infusion_tint"):
		vis.call("set_infusion_tint", color, strength)
	_tint_capsule_infusion(color, strength)


func _tint_capsule_infusion(color: Color, strength: float) -> void:
	if _mesh == null:
		return
	var mat := _mesh.material_override as StandardMaterial3D
	if mat == null:
		return
	if strength > 0.02:
		mat.albedo_color = body_color.lerp(color, clampf(strength * 0.85, 0.0, 0.8))
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.85 * strength
	else:
		mat.albedo_color = body_color
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0


func _refresh_freeze_visual() -> void:
	var vis := get_node_or_null("CharacterVisual")
	if _stun_left > 0.0:
		var color := Color(0.62, 0.9, 1.0, 1.0)
		if vis and vis.has_method("set_freeze_tint"):
			vis.call("set_freeze_tint", true, color)
		_tint_capsule_infusion(color, 0.88)
		return
	if vis and vis.has_method("set_freeze_tint"):
		vis.call("set_freeze_tint", false)
	_refresh_infusion_visual()


func has_recast_ready(index: int) -> bool:
	return recast_slot() == index


func has_recast_prompt(index: int) -> bool:
	if has_recast_ready(index) or has_aura(index):
		return true
	return is_protection_hold() and controller != null and controller.cast_index == index


func recast_slot() -> int:
	if _recast_index < 0 or _recast_left <= 0.05:
		return -1
	return _recast_index


func recast_time_left(index: int) -> float:
	return _recast_left if has_recast_ready(index) else 0.0


func recast_window_duration(index: int) -> float:
	if not has_recast_ready(index) or index < 0 or index >= abilities.size():
		return 0.0
	return maxf(abilities[index].recast_window, _recast_left)


func _arm_recast(index: int, window: float) -> void:
	_recast_index = index
	_recast_left = maxf(window, 0.05)


func set_illusion_exit_dir(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = facing_dir()
	if flat.length_squared() < 0.0001:
		_illusion_exit_dir = Vector3(0, 0, -1)
	else:
		_illusion_exit_dir = flat.normalized()


func take_illusion_exit_dir() -> Vector3:
	var dir := _illusion_exit_dir
	_illusion_exit_dir = Vector3.ZERO
	return dir


func _clear_recast() -> void:
	_recast_index = -1
	_recast_left = 0.0


func _expire_recast() -> void:
	_clear_recast()
	clear_ashen_absorbed()


func has_aura(index: int = -1) -> bool:
	_prune_auras()
	if index < 0:
		return not _auras.is_empty()
	return _auras.has(index)


func toggle_aura(index: int, target: Unit = null) -> void:
	if index < 0 or index >= abilities.size():
		return
	if has_aura(index):
		stop_aura(index, true)
		apply_cooldown(index)
		return
	var ab := abilities[index]
	if _aura_infusion_blocked(ab):
		return
	if not can_prepare_cast(index):
		return
	_cast_power = 1.0
	_try_consume_free_cast()
	var extras := _cast_extras(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	var combat_text_cast_id := _DamageNumber.begin_cast()
	var aura: SpellAura = _SpellAura.attach(self, ab, extras, ice_id, _infusion_double_mask(), combat_text_cast_id, index)
	_auras[index] = aura
	aura.tree_exited.connect(func() -> void:
		if _auras.get(index) == aura:
			_auras.erase(index)
	)
	var help := target if target != null and is_instance_valid(target) and not target.is_dead and target.team == team and ab.can_target_allies() else null
	_apply_ally_and_self(help, ab, false)


func stop_aura(index: int = -1, detonate: bool = false) -> void:
	_prune_auras()
	if index < 0:
		for slot in _auras.keys():
			_release_aura_node(_auras[slot], false)
		_auras.clear()
		return
	if not _auras.has(index):
		return
	var node = _auras[index]
	_auras.erase(index)
	_release_aura_node(node, detonate)


func _release_aura_node(node, detonate: bool) -> void:
	if not is_instance_valid(node):
		return
	if node is SpellAura:
		(node as SpellAura).release(detonate)
	else:
		node.queue_free()


func _prune_auras() -> void:
	var stale: Array = []
	for slot in _auras.keys():
		var node = _auras[slot]
		if node == null or not is_instance_valid(node):
			stale.append(slot)
	for slot in stale:
		_auras.erase(slot)


func _aura_lock_ids(ab: AbilityDef) -> PackedStringArray:
	var out := PackedStringArray()
	if ab == null:
		return out
	for id in ab.infusion_ids:
		if id.is_empty() or out.has(id):
			continue
		out.append(id)
	return out


func _aura_infusion_blocked(ab: AbilityDef) -> bool:
	if ab == null or ab.delivery != AbilityDef.Delivery.AURA:
		return false
	var want := _aura_lock_ids(ab)
	if want.is_empty():
		return false
	_prune_auras()
	for slot in _auras.keys():
		var idx := int(slot)
		if idx < 0 or idx >= abilities.size():
			continue
		var other: AbilityDef = abilities[idx]
		for id in _aura_lock_ids(other):
			if want.has(id):
				return true
	return false


func _clear_spell_ray() -> void:
	for ray in _spell_rays:
		if is_instance_valid(ray):
			ray.queue_free()
	_spell_rays.clear()
	_illusion_missile_extras.clear()


func _scaled(amount: float) -> float:
	return amount * maxf(_cast_power, 0.0)


func _ability_def(ability_id: String) -> AbilityDef:
	var idx := _ability_index_by_id(ability_id)
	if idx < 0:
		return null
	return abilities[idx]


func ability_for_combat_id(ability_id: String) -> AbilityDef:
	return _ability_def(ability_id)


func _spell_for_incoming_hit(source: Unit, ability_id: String, primary: int, extras: PackedInt32Array) -> AbilityDef:
	if source == null:
		return null
	if ability_id.is_empty() and source.team != TEAM_RAID:
		return null
	return source._ability_def_for_hit(ability_id, primary, extras)


func _ability_def_for_hit(ability_id: String, primary: int, extras: PackedInt32Array) -> AbilityDef:
	var slot := AbilityDef.slot_from_combat_id(ability_id)
	if slot >= 0 and slot < abilities.size() and abilities[slot] != null:
		return abilities[slot]
	var lookup_id := AbilityDef.base_from_combat_id(ability_id)
	var first: AbilityDef = null
	for ab in abilities:
		if ab == null:
			continue
		if not lookup_id.is_empty() and ab.id != lookup_id:
			continue
		if first == null:
			first = ab
		if SpellPower.matches_hit(ab, extras, primary):
			return ab
	if first != null:
		return first
	return _ability_def(ability_id)


func roll_spell_crit(ability_id: String) -> bool:
	return roll_ability_crit(_ability_def(ability_id))


func roll_ability_crit(ab: AbilityDef, victim: Unit = null) -> bool:
	if TalentCombat.always_crit(self, victim, ab):
		return true
	if ab == null or ab.crit_chance <= 0.0:
		return false
	return randf() < ab.crit_chance


func spell_crit_mult(ability_id: String) -> float:
	var ab := _ability_def(ability_id)
	if ab == null:
		return 2.0
	return maxf(ab.crit_damage, 1.0)


func spend_cast(index: int) -> void:
	spend_mana(index)
	if has_recast_ready(index):
		return
	var ab: AbilityDef = abilities[index] if index >= 0 and index < abilities.size() else null
	if ab != null and ab.free_cast_charges > 0:
		apply_cooldown(index, 1.0)
		return
	if _try_consume_free_cast():
		return
	apply_cooldown(index, 1.0)


func spend_mana(index: int) -> void:
	var cost := mana_cost_for(index)
	if not GameSession.has_infinite_mana():
		mana = maxf(0.0, mana - cost)
	else:
		mana = max_mana


func restore_mana(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	mana = minf(max_mana, mana + amount)


func apply_cooldown(index: int, factor: float = 1.0) -> void:
	if index < 0 or index >= cooldown_left.size():
		return
	while _cooldown_max.size() < cooldown_left.size():
		_cooldown_max.append(0.0)
	if GameSession.ignores_cooldowns():
		cooldown_left[index] = 0.0
		_cooldown_max[index] = 0.0
		return
	var dur := abilities[index].cooldown * factor
	if TalentCombat.consume_undertow_charge(self, abilities[index]):
		dur = 0.0
	cooldown_left[index] = dur
	_cooldown_max[index] = dur


func cooldown_duration(index: int) -> float:
	if index >= 0 and index < _cooldown_max.size() and _cooldown_max[index] > 0.04:
		return _cooldown_max[index]
	if index >= 0 and index < abilities.size():
		return abilities[index].cooldown
	return 0.0


func reduce_all_cooldowns(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	for i in cooldown_left.size():
		cooldown_left[i] = maxf(0.0, cooldown_left[i] - amount)


func reduce_ability_cooldown(index: int, amount: float) -> void:
	if amount <= 0.0 or is_dead or index < 0 or index >= cooldown_left.size():
		return
	cooldown_left[index] = maxf(0.0, cooldown_left[index] - amount)


func apply_momentum_cooldown_refund(ab: AbilityDef, combat_text_cast_id: int, victim: Unit) -> void:
	# One refund per unique victim per combat-text cast, including zone ticks.
	# Total refund is capped at a fraction of compiled cooldown so cleave/pierce/volley cannot dump the whole CD.
	if ab == null or ab.hit_cooldown_reduction <= 0.05 or is_dead:
		return
	if victim == null or not is_instance_valid(victim):
		return
	var key := combat_text_cast_id if combat_text_cast_id >= 0 else -ab.loadout_slot
	var rec: Dictionary = _momentum_spent.get(key, {"refunded": 0.0, "mobs": {}})
	var cap := ab.cooldown * ab.hit_cooldown_refund_cap
	if cap <= 0.05:
		return
	var refunded := float(rec.get("refunded", 0.0))
	var left := cap - refunded
	if left <= 0.05:
		return
	var mobs: Dictionary = rec.get("mobs", {})
	var vid := victim.get_instance_id()
	if mobs.has(vid):
		return
	mobs[vid] = true
	var amount := minf(ab.hit_cooldown_reduction, left)
	rec["mobs"] = mobs
	rec["refunded"] = refunded + amount
	var was_new := not _momentum_spent.has(key)
	_momentum_spent[key] = rec
	if was_new and _momentum_spent.size() > 24:
		var drop: Array = []
		for k in _momentum_spent.keys():
			if drop.size() >= 8:
				break
			drop.append(k)
		for k in drop:
			if k == key:
				continue
			_momentum_spent.erase(k)
	var idx := ab.loadout_slot
	if idx < 0:
		idx = _ability_index_by_id(ab.combat_id())
	reduce_ability_cooldown(idx, amount)


func reduce_overheat_cooldown(amount: float = OVERHEAT_CD_REFUND) -> void:
	if amount <= 0.0 or is_dead:
		return
	var idx := _ability_index_by_id("overcharge")
	if idx < 0:
		idx = _ability_index_by_id("overheat")
	if idx < 0:
		idx = _ability_index_by_id("overcharged")
	if idx < 0 or idx >= cooldown_left.size():
		return
	if cooldown_left[idx] <= 0.0:
		return
	cooldown_left[idx] = maxf(0.0, cooldown_left[idx] - amount)


func _refund_overheat_if_ice_hit(element: int, extras: PackedInt32Array, damage: float, tick_hit: bool, grant_chill: bool, overheat_cast_id: int) -> void:
	if damage <= 0.0 or overheat_cast_id < 0:
		return
	if tick_hit and not grant_chill:
		return
	if not _overheat_refund_left.has(overheat_cast_id):
		return
	var n := int(_overheat_refund_left[overheat_cast_id])
	if n <= 0:
		return
	var ice := element == AbilityDef.Element.ICE
	if not ice:
		for extra in extras:
			if extra == AbilityDef.Element.ICE:
				ice = true
				break
	if not ice:
		return
	_overheat_refund_left[overheat_cast_id] = n - 1
	reduce_overheat_cooldown()


func _begin_ice_overheat_cast(ab: AbilityDef, extras: PackedInt32Array) -> int:
	if ab == null or ab.grant_all_infusions or ab.free_cast_charges > 0:
		return -1
	_overheat_cast_seq += 1
	var id := _overheat_cast_seq
	_charge_mana_open[id] = ab.mana_cost
	var ice := ab.element == AbilityDef.Element.ICE
	if not ice:
		for extra in extras:
			if extra == AbilityDef.Element.ICE:
				ice = true
				break
	if ice:
		_overheat_refund_left[id] = OVERHEAT_CD_REFUND_CAP
	_prune_cast_tracking()
	return id


func _prune_cast_tracking() -> void:
	if _overheat_refund_left.size() <= 24 and _charge_mana_open.size() <= 24:
		return
	var keep_from := _overheat_cast_seq - 16
	for bag in [_overheat_refund_left, _charge_mana_open]:
		var drop: Array = []
		for k in bag.keys():
			if int(k) < keep_from:
				drop.append(k)
		for k in drop:
			bag.erase(k)


func _refund_charge_mana(stacks: int, cast_id: int) -> void:
	if cast_id < 0 or stacks <= 0:
		return
	if not _charge_mana_open.has(cast_id):
		return
	var base := float(_charge_mana_open[cast_id])
	_charge_mana_open.erase(cast_id)
	restore_mana(base * (float(stacks) / CHARGED_MANA_DIV))


func _infusion_double_mask() -> int:
	if _overcharge_left > 0.0:
		return INFUSION_DOUBLE_FIRE | INFUSION_DOUBLE_ICE | INFUSION_DOUBLE_STORM
	match _infusion:
		AbilityDef.Element.FIRE:
			return INFUSION_DOUBLE_FIRE
		AbilityDef.Element.ICE:
			return INFUSION_DOUBLE_ICE
		AbilityDef.Element.STORM:
			return INFUSION_DOUBLE_STORM
		_:
			return 0


func _ability_index_by_id(ability_id: String) -> int:
	if ability_id.is_empty():
		return -1
	var slot := AbilityDef.slot_from_combat_id(ability_id)
	if slot >= 0:
		return slot if slot < abilities.size() else -1
	for i in abilities.size():
		if abilities[i] != null and abilities[i].id == ability_id:
			return i
	return -1


func clamped_ground_point(point: Vector3, max_range: float) -> Vector3:
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	var dest := Vector3(point.x, 0.0, point.z)
	var d := dest - origin
	var reach := max_range if max_range > 0.0 else d.length()
	if d.length_squared() < 0.0001:
		return origin + facing_dir() * minf(0.6, reach)
	if d.length() > reach:
		dest = origin + d.normalized() * reach
	return wall_stop_point(dest, false)


func clamped_skillshot_point(point: Vector3, ab: AbilityDef) -> Vector3:
	var reach := ab.skillshot_reach() if ab != null else 12.0
	return clamped_ground_point(point, reach)


func wall_stop_point(to: Vector3, include_spell_walls: bool = true) -> Vector3:
	var hit := _wall_ray_to(to, include_spell_walls)
	if hit.is_empty():
		return Vector3(to.x, 0.0, to.z)
	var p: Vector3 = hit.position
	var n: Vector3 = hit.get("normal", Vector3.ZERO)
	n.y = 0.0
	if n.length_squared() < 0.0001:
		n = Vector3(global_position.x - p.x, 0.0, global_position.z - p.z)
	if n.length_squared() > 0.0001:
		n = n.normalized()
		p += n * 0.14
	return Vector3(p.x, 0.0, p.z)


func wall_travel_distance(dir: Vector3, max_dist: float, include_spell_walls: bool = true) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return max_dist
	flat = flat.normalized()
	var dest := global_position + flat * max_dist
	var stopped := wall_stop_point(dest, include_spell_walls)
	return clampf(
		Vector2(stopped.x - global_position.x, stopped.z - global_position.z).length(),
		0.35,
		max_dist
	)


func has_wall_los(to: Vector3) -> bool:
	return _wall_ray_to(to).is_empty()


func _wall_ray_to(to: Vector3, include_spell_walls: bool = true) -> Dictionary:
	var arena := ArenaState.arena as Arena
	if arena:
		var exclude: Array[RID] = [get_rid()]
		SpellWall.append_pass_excludes(exclude, self)
		return arena.spell_wall_hit(global_position, to, exclude, 1.05, include_spell_walls)
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var from := Vector3(global_position.x, 1.05, global_position.z)
	var dest := Vector3(to.x, 1.05, to.z)
	if from.distance_squared_to(dest) < 0.0004:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, dest)
	q.collision_mask = SpellWall.shot_block_mask()
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	if not include_spell_walls and hit.get("collider") is SpellWall:
		return {}
	return hit


func _dev_test_unkillable() -> bool:
	return GameSession.dev_test_mode and team == TEAM_RAID and not is_structure


func take_damage(amount: float, source = null, number_color: Color = Color(0, 0, 0, 0), hit_kind: String = "", ability_id: String = "", crit: bool = false, ignore_resist: bool = false, combat_text_cast_id: int = -1, combat_text_periodic: bool = false, combat_text_split: Dictionary = {}) -> void:
	if not is_instance_valid(source):
		source = null
	if is_structure and host_wall != null and is_instance_valid(host_wall):
		host_wall.take_hit(amount, global_position, source as Unit, hit_kind, number_color, crit, combat_text_cast_id, combat_text_split)
		if host_wall == null or not is_instance_valid(host_wall) or not host_wall.living:
			if not is_dead:
				is_dead = true
				health = 0.0
		else:
			health = host_wall.health
			max_health = host_wall.max_health
		return
	if is_dead or amount <= 0.0:
		return
	var src := source as Unit
	if src != null:
		amount *= src.outgoing_damage_mult(ability_id, hit_kind)
	if not ignore_resist:
		amount *= maxf(0.0, 1.0 - _resist_cut(hit_kind, ability_id))
		if amount <= 0.0:
			return
	if team == TEAM_RAID and _judgment_brand > 0:
		amount *= judgment_brand_taken_mult()
	if _dr_left > 0.0 and _dr_percent > 0.0:
		amount *= maxf(0.0, 1.0 - _dr_percent)
		if amount <= 0.0:
			return
	var talent_cut := TalentCombat.taken_cut(self, hit_kind)
	var before_cut := amount
	if talent_cut > 0.0:
		amount *= maxf(0.0, 1.0 - talent_cut)
		if amount <= 0.0:
			TalentCombat.on_bodyguard_prevented(self, before_cut)
			return
		TalentCombat.on_bodyguard_prevented(self, before_cut - amount)
	if _blessing_left > 0.0 and _blessing_dr > 0.0:
		amount *= maxf(0.0, 1.0 - _blessing_dr)
		if amount <= 0.0:
			if ability_id != "intercede":
				TalentCombat.on_taken_hit(self, src, 0.0, 0.0)
			return
	var absorbed := 0.0
	if shield_amount() > 0.0:
		var before_sh := amount
		amount = _absorb_shield(amount)
		absorbed = before_sh - amount
		if amount <= 0.0:
			if ability_id != "intercede":
				TalentCombat.on_taken_hit(self, src, absorbed, 0.0)
				UnitEnemyAlter.on_taken_hit(self, src, absorbed, absorbed, ability_id)
			return
	health = maxf(0.0, health - amount)
	if immortal or _dev_test_unkillable():
		health = maxf(1.0, health)
	if ability_id != "intercede":
		TalentCombat.on_taken_hit(self, src, absorbed, amount)
		UnitEnemyAlter.on_taken_hit(self, src, amount + absorbed, absorbed, ability_id)
	var spell := ability_id if not ability_id.is_empty() else hit_kind
	damaged.emit(self, amount, source, spell)
	_present_damage_text(amount, source, number_color, hit_kind, crit, spell, combat_text_cast_id, combat_text_periodic, combat_text_split)
	if src != null:
		src.apply_atonement(amount)
	if _stun_left > 0.05:
		_chew_shatter_from_dot(src, amount, hit_kind, combat_text_cast_id)
	if health <= 0.0:
		die()


func apply_world_hit(amount: float, source = null, kind: String = "hit", ability_id: String = "", combat_text_cast_id: int = -1, combat_text_periodic: bool = false) -> void:
	if not is_instance_valid(source):
		source = null
	var hit_kind := kind if not kind.is_empty() else "hit"
	var spell := ability_id if not ability_id.is_empty() else hit_kind
	var tint := _DamageNumber.tint_for(hit_kind)
	var split := _DamageNumber.split_for_amount(hit_kind, amount, tint) if GameSession.show_damage_numbers else {}
	take_damage(amount, source, tint, hit_kind, spell, false, false, combat_text_cast_id, combat_text_periodic, split)


func _should_show_combat_text(source: Node3D) -> bool:
	var me := GameSession.active_unit
	if me != null and source == me:
		return true
	return team == TEAM_RAID


func _present_damage_text(amount: float, source: Node3D, number_color: Color, hit_kind: String, crit: bool, ability_id: String, combat_text_cast_id: int, combat_text_periodic: bool, combat_text_split: Dictionary) -> void:
	if not GameSession.show_damage_numbers or amount <= 0.0 or not _should_show_combat_text(source):
		return
	var kind := hit_kind if not hit_kind.is_empty() else "hit"
	var split_input := combat_text_split
	if split_input.is_empty():
		split_input = _DamageNumber.split_for_amount(kind, amount, number_color)
	var shown_split := _DamageNumber.scaled_split(split_input, amount)
	var periodic_key := _combat_text_periodic_key(source, ability_id, kind, combat_text_cast_id) if combat_text_periodic else ""
	_DamageNumber.show_hit(self, amount, kind, number_color, crit, combat_text_cast_id, periodic_key, shown_split)


func _try_show_my_heal(amount: float, source: Node3D, ability_id: String = "", combat_text_split: Dictionary = {}, combat_text_cast_id: int = -1, combat_text_periodic: bool = false, crit: bool = false, heal_kind: String = "") -> void:
	if amount <= 0.0 or not _should_show_combat_text(source):
		return
	var is_hot := AbilityDef.matches_base(ability_id, "rejuvenation")
	var kind := "rejuvenation" if is_hot else (heal_kind if not heal_kind.is_empty() else "heal")
	var periodic := combat_text_periodic or is_hot
	var periodic_key := _combat_text_periodic_key(source, ability_id, kind, combat_text_cast_id) if periodic else ""
	_DamageNumber.show_hit(self, amount, kind, Color(0, 0, 0, 0), crit, combat_text_cast_id, periodic_key, combat_text_split, true)


func _try_show_my_shield(amount: float, source: Node3D, combat_text_cast_id: int = -1) -> void:
	if amount <= 0.0 or not _should_show_combat_text(source):
		return
	var periodic_key := "shield:%s" % _combat_text_periodic_key(source, "shield", "shield", combat_text_cast_id)
	_DamageNumber.show_hit(self, amount, "shield", Color(0, 0, 0, 0), false, combat_text_cast_id, periodic_key, {}, true)


func _try_show_my_damage(amount: float, source: Node3D, number_color: Color = Color(0, 0, 0, 0), hit_kind: String = "", crit: bool = false, ability_id: String = "", combat_text_cast_id: int = -1, combat_text_periodic: bool = false, combat_text_split: Dictionary = {}) -> void:
	_present_damage_text(amount, source, number_color, hit_kind, crit, ability_id, combat_text_cast_id, combat_text_periodic, combat_text_split)


func _combat_text_periodic_key(source: Node3D, ability_id: String, kind: String, combat_text_cast_id: int) -> String:
	if combat_text_cast_id >= 0:
		return "cast:%d" % combat_text_cast_id
	var source_id := source.get_instance_id() if source != null and is_instance_valid(source) else 0
	var effect_id := ability_id if not ability_id.is_empty() else kind
	return "effect:%d:%s" % [source_id, effect_id]


func _hit_number_kind(element: int, tick_hit: bool) -> String:
	if tick_hit:
		match element:
			AbilityDef.Element.FIRE:
				return "fire_tick"
			AbilityDef.Element.ICE:
				return "ice_tick"
			AbilityDef.Element.STORM:
				return "lightning_tick"
			AbilityDef.Element.SHADOW:
				return "shadow_tick"
			AbilityDef.Element.NATURE:
				return "nature_tick"
			AbilityDef.Element.HOLY:
				return "divine_tick"
			AbilityDef.Element.PROTECTION:
				return "protection_tick"
			AbilityDef.Element.WIND:
				return "wind_tick"
			AbilityDef.Element.ILLUSION:
				return "illusion_tick"
			_:
				return "tick"
	match element:
		AbilityDef.Element.FIRE:
			return "fire"
		AbilityDef.Element.ICE:
			return "ice"
		AbilityDef.Element.STORM:
			return "lightning"
		AbilityDef.Element.SHADOW:
			return "shadow"
		AbilityDef.Element.NATURE:
			return "nature"
		AbilityDef.Element.HOLY:
			return "divine"
		AbilityDef.Element.PROTECTION:
			return "protection"
		AbilityDef.Element.WIND:
			return "wind"
		AbilityDef.Element.ILLUSION:
			return "illusion"
		_:
			return "physical"


func _hit_number_tint(kind: String) -> Color:
	return _DamageNumber.tint_for(kind)


func apply_heal(amount: float, source: Node3D = null, ability_id: String = "", combat_text_split: Dictionary = {}, combat_text_cast_id: int = -1, combat_text_periodic: bool = false, crit: bool = false, heal_kind: String = "") -> void:
	if is_dead or amount <= 0.0:
		return
	var src_unit := source as Unit
	amount *= TalentCombat.heal_out_mult(src_unit, ability_id)
	amount *= TalentCombat.heal_taken_mult(self)
	amount *= TalentCombat.nature_target_heal_mult(src_unit, self, ability_id)
	var room := maxf(0.0, max_health - health)
	var hp_heal := minf(room, amount)
	if hp_heal > 0.0:
		health += hp_heal
		healed.emit(self, hp_heal, source, ability_id)
		if heal_practice:
			_heal_practice_reset = HEAL_PRACTICE_RESET
	var overflow := amount - hp_heal
	if overflow > 0.05 and AbilityDef.matches_base(ability_id, "atonement"):
		var src := source as Unit
		if src != null and has_ward_from(src):
			apply_shield(overflow, PROTECTION_SHIELD_TIME, src)
	var shown := hp_heal if hp_heal > 0.05 else overflow
	if shown > 0.05:
		var shown_split := _DamageNumber.scaled_split(combat_text_split, shown)
		_try_show_my_heal(shown, source, ability_id, shown_split, combat_text_cast_id, combat_text_periodic, crit, heal_kind)


func set_ability_hover(enabled: bool, color: Color = Color(1.0, 0.82, 0.28, 0.92)) -> void:
	if is_structure:
		if is_dead:
			enabled = false
		if host_wall != null and is_instance_valid(host_wall):
			host_wall.set_targeted(enabled, color)
		return
	if is_dead:
		enabled = false
	_ability_hover = enabled
	_hover_color = color
	_refresh_character_outline()
	_refresh_name_highlight()
	_refresh_hover_frames()
	if _bar:
		var bar_mat := _bar.material_override as StandardMaterial3D
		if bar_mat:
			_tint_bar_material(bar_mat, _hp_fill_color())
	if _mp_bar:
		var mp_mat := _mp_bar.material_override as StandardMaterial3D
		if mp_mat:
			_tint_bar_material(mp_mat, Color(0.22, 0.48, 0.95))


func _refresh_character_outline() -> void:
	var local := _is_local_player() and not is_dead
	var shown := _ability_hover or local
	var color := LOCAL_OUTLINE_COLOR if local else _hover_color
	var width := LOCAL_OUTLINE_WIDTH if local else _hover_width()
	var vis := get_node_or_null("CharacterVisual")
	if vis and vis.has_method("set_hover_outline"):
		vis.call("set_hover_outline", shown, color, width)
	elif _mesh:
		if shown:
			if _hover_mat == null:
				_hover_mat = ShaderMaterial.new()
				_hover_mat.shader = load("res://scripts/visual/hover_outline.gdshader")
			_hover_mat.set_shader_parameter("outline_color", color)
			_hover_mat.set_shader_parameter("width", width)
			_mesh.material_overlay = _hover_mat
		elif _mesh.material_overlay == _hover_mat:
			_mesh.material_overlay = null


func _is_local_player() -> bool:
	return GameSession.active_unit == self


func _refresh_name_highlight() -> void:
	if _label == null:
		return
	if _nameplate:
		_label.visible = false
		return
	_label.visible = not _is_local_player()
	_label.modulate = Color.WHITE
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.outline_size = 8


func _tint_bar_material(mat: StandardMaterial3D, base: Color) -> void:
	mat.albedo_color = base
	mat.emission_enabled = false


func _make_hover_frame(parent: Node3D, frame_name: String, camera_billboard: bool = true, overlay_priority: int = 10) -> MeshInstance3D:
	return _make_outline_frame(parent, frame_name, camera_billboard, overlay_priority)


func _make_outline_frame(parent: Node3D, frame_name: String, camera_billboard: bool = true, overlay_priority: int = 10) -> MeshInstance3D:
	var mi := WorldUiMesh.hover_frame(frame_name, _hover_color, 0.02, camera_billboard, overlay_priority)
	parent.add_child(mi)
	return mi


func _make_hover_frames() -> void:
	if _hp_root:
		_name_frame = _make_hover_frame(_hp_root, "NameHoverFrame", false)
		if not _uses_feet_bars():
			var pri := 127 if _nameplate else 10
			_hp_frame = _make_hover_frame(_hp_root, "HpHoverFrame", false, pri)
	if _feet_root:
		_hp_frame = _make_hover_frame(_feet_root, "HpHoverFrame", false)
		if _mp_bar:
			_mp_frame = _make_hover_frame(_feet_root, "MpHoverFrame", false)


func _place_hover_frame(frame: MeshInstance3D, pos: Vector3, size: Vector2, shown: bool) -> void:
	_place_outline_frame(frame, pos, size, shown, _hover_color, 0.02)


func _place_outline_frame(frame: MeshInstance3D, pos: Vector3, size: Vector2, shown: bool, color: Color, border: float) -> void:
	WorldUiMesh.place_hover_frame(frame, pos, size, shown, color, border)


func _make_dodge_clock() -> void:
	if _feet_root == null or not is_champion:
		return
	var trough_h := _bar_fill_h() + _bar_pad() * 2.0
	var bars_h := trough_h
	if max_mana > 1.0:
		bars_h = trough_h * 2.0 + _bar_gap()
	var diameter := maxf(bars_h, 0.22)
	var x := -(_bar_trough_size().x * 0.5 + 0.06 + diameter * 0.5)
	_dodge_clock = MeshInstance3D.new()
	_dodge_clock.name = "DodgeClock"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(diameter, diameter)
	_dodge_clock.mesh = mesh
	_dodge_clock.position = Vector3(x, 0.0, 0.03)
	_dodge_clock_mat = ShaderMaterial.new()
	_dodge_clock_mat.shader = _DodgeClockShader
	_dodge_clock_mat.render_priority = 10
	_dodge_clock_mat.set_shader_parameter("progress", 0.0)
	_dodge_clock.material_override = _dodge_clock_mat
	_dodge_clock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dodge_clock.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_feet_root.add_child(_dodge_clock)


func _refresh_dodge_clock() -> void:
	if _dodge_clock == null:
		return
	_dodge_clock.visible = not is_dead
	if _dodge_clock_mat == null:
		return
	var ratio := 0.0
	var cd := TalentCombat.dodge_cooldown(self, DODGE_COOLDOWN)
	if cd > 0.04:
		ratio = clampf(dodge_cooldown_left / cd, 0.0, 1.0)
	_dodge_clock_mat.set_shader_parameter("progress", ratio)


func _make_free_cast_pips() -> void:
	var parent := _feet_root if _feet_root else _hp_root
	if parent == null:
		return
	var tex := _mark_pip_texture()
	for i in 2:
		var pip := Sprite3D.new()
		pip.name = "FreeCastPip%d" % i
		pip.texture = tex
		pip.billboard = BaseMaterial3D.BILLBOARD_DISABLED if _feet_root else BaseMaterial3D.BILLBOARD_ENABLED
		pip.shaded = false
		pip.double_sided = true
		pip.pixel_size = 0.0028
		pip.modulate = Color(1.0, 0.88, 0.35)
		pip.transparent = true
		pip.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		pip.no_depth_test = true
		pip.fixed_size = false
		pip.visible = false
		parent.add_child(pip)
		_free_cast_pips.append(pip)


func _refresh_free_cast_pips() -> void:
	if _free_cast_pips.size() < 2:
		return
	var shown := not is_dead and not _nameplate and _free_cast_max > 0
	var trough_h := _bar_fill_h() + _bar_pad() * 2.0
	var y := _hp_bar_y - trough_h * 0.5 - 0.048
	var spacing := 0.10
	var start := -spacing * 0.5
	for i in 2:
		var pip := _free_cast_pips[i]
		pip.visible = shown
		if not shown:
			continue
		pip.position = Vector3(start + float(i) * spacing, y, 0.05)
		if i < _free_casts:
			pip.modulate = Color(1.15, 0.95, 0.42, 1.0)
		else:
			pip.modulate = Color(0.22, 0.18, 0.08, 0.55)


func _refresh_combo_border() -> void:
	if _combo_border == null:
		return
	var shown := not is_dead
	var trough := _bar_trough_size()
	var half := trough.y * 0.5
	var top := _hp_bar_y + half
	var bot := _hp_bar_y - half
	if _mp_bar and _mp_bar.visible:
		bot = _mp_bar_y - half
	var h := top - bot + 0.02
	var y := (top + bot) * 0.5
	_place_outline_frame(
		_combo_border,
		Vector3(0.0, y, 0.04),
		Vector2(trough.x + 0.02, h),
		shown,
		Color(0.84, 0.70, 0.34, 0.95),
		0.010
	)


func _refresh_hover_frames() -> void:
	var shown := _ability_hover and not is_dead
	if _nameplate:
		var sz: Vector2 = _nameplate.world_size() if _nameplate.has_method("world_size") else Vector2(_bar_width + 0.16, 0.5)
		var mid := Vector3.ZERO
		if _nameplate.has_method("world_offset"):
			mid = _nameplate.world_offset()
		_place_hover_frame(_name_frame, Vector3.ZERO, Vector2.ZERO, false)
		_place_outline_frame(
			_hp_frame,
			mid + Vector3(0, 0, 0.06),
			sz + Vector2(0.10, 0.10),
			shown,
			_hover_color,
			0.045
		)
		_place_hover_frame(_mp_frame, Vector3.ZERO, Vector2.ZERO, false)
		return
	var name_w := maxf(_bar_width + 0.12, 0.11 * float(maxi(unit_name.length(), 1)) + 0.32)
	var name_pos := _label.position if _label else Vector3(0, 0.16, 0.04)
	var show_name := shown and _label != null and _label.visible
	_place_hover_frame(_name_frame, name_pos + Vector3(0, 0, 0.04), Vector2(name_w, 0.52), show_name)
	var trough := _bar_trough_size()
	_place_hover_frame(_hp_frame, Vector3(0, _hp_bar_y, 0.05), trough + Vector2(0.04, 0.04), shown)
	var show_mp := shown and _mp_bar != null and _mp_bar.visible
	_place_hover_frame(_mp_frame, Vector3(0, _mp_bar_y, 0.05), trough + Vector2(0.04, 0.04), show_mp)


func _hover_width() -> float:
	return GameSession.unit_hover_width


func refresh_hover_outline() -> void:
	_refresh_character_outline()


func apply_ward(amount: float, duration: float = WARD_TIME) -> void:
	apply_shield(amount, duration)


func apply_shield(amount: float, duration: float = WARD_TIME, source: Node3D = null, elements: PackedInt32Array = PackedInt32Array(), combat_text_cast_id: int = -1) -> void:
	if is_dead or amount <= 0.0:
		return
	var dur := duration if duration > 0.05 else PROTECTION_SHIELD_TIME
	_shield_layers.append({
		"remaining": amount,
		"time_left": dur,
		"dps": amount / dur,
		"source": source,
		"elements": elements,
	})
	_ward_left = shield_amount()
	_ward_time = _shield_time_left()
	_ward_max = maxf(_ward_max, dur)
	if source is Unit:
		_ward_source = source as Unit
	_try_show_my_shield(amount, source, combat_text_cast_id)


func _clear_ward() -> void:
	_shield_layers.clear()
	_ward_left = 0.0
	_ward_time = 0.0
	_ward_max = 0.0
	_ward_source = null


func has_ward_from(caster: Unit) -> bool:
	if caster == null:
		return false
	for layer in _shield_layers:
		var src = layer.get("source")
		if src is Unit and is_instance_valid(src) and src == caster:
			return true
	return false


func _shield_time_left() -> float:
	return _dot_time_left(_shield_layers)


func _absorb_shield(amount: float) -> float:
	var need := amount
	var keep: Array[Dictionary] = []
	for layer in _shield_layers:
		if need <= 0.0:
			keep.append(layer)
			continue
		var take := minf(float(layer.get("remaining", 0.0)), need)
		layer["remaining"] = maxf(0.0, float(layer.get("remaining", 0.0)) - take)
		need -= take
		if float(layer.get("remaining", 0.0)) > 0.02 and float(layer.get("time_left", 0.0)) > 0.02:
			keep.append(layer)
	_shield_layers = keep
	_ward_left = shield_amount()
	if _shield_layers.is_empty():
		_clear_ward()
	return maxf(0.0, need)


func _tick_shield(delta: float) -> void:
	if _shield_layers.is_empty():
		return
	var keep: Array[Dictionary] = []
	for layer in _shield_layers:
		var remain := maxf(0.0, float(layer.get("remaining", 0.0)) - float(layer.get("dps", 0.0)) * delta)
		var time_left := maxf(0.0, float(layer.get("time_left", 0.0)) - delta)
		layer["remaining"] = remain
		layer["time_left"] = time_left
		if remain > 0.02 and time_left > 0.02:
			keep.append(layer)
	_shield_layers = keep
	_ward_left = shield_amount()
	_ward_time = _shield_time_left()
	if _shield_layers.is_empty():
		_clear_ward()


func apply_atonement(dealt: float) -> void:
	if is_dead or dealt <= 0.0 or atonement_ratio <= 0.0:
		return
	var heal_amt := dealt * atonement_ratio * (1.0 + _atonement_amp)
	if heal_amt <= 0.05:
		return
	var teammates: Array = ArenaState.living_team(team)
	for other in teammates:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if not u.has_ward_from(self):
			continue
		u.apply_heal(heal_amt, self, "atonement")


func _shield_duration_for(ab: AbilityDef) -> float:
	if ab != null and ab.shield_duration > 0.05:
		return ab.shield_duration
	return WARD_TIME


func _shield_grant_amount(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	return _scaled(SpellPower.preview_shield(ab))


func apply_spell_shield(target: Unit, ab: AbilityDef) -> void:
	if target == null or ab == null or ab.shield <= 0.05:
		return
	var dur := _shield_duration_for(ab) + TalentCombat.shield_duration_bonus(self, target, ab)
	var amt := _shield_grant_amount(ab) * TalentCombat.shield_out_mult(self, target)
	target.apply_shield(amt, dur, self, SpellPower.elements_for(ab))
	UnitWind.apply_shield_haste(target, ab, dur)
	TalentCombat.on_shield_applied(self, target, ab)


func _shield_status_text() -> String:
	var resist := _shield_resist_names()
	var wear := "Layers wear off over %ss." % str(PROTECTION_SHIELD_TIME)
	if resist.is_empty():
		return "Absorbs incoming damage. %s" % wear
	return "Absorbs incoming damage. %d%% %s resist. %s" % [
		int(round(CombatBalance.pct("shield.resist") * 100.0)),
		" / ".join(resist),
		wear,
	]


func _shield_resist_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for layer in _shield_layers:
		var els: PackedInt32Array = PackedInt32Array()
		var raw = layer.get("elements", PackedInt32Array())
		if raw is PackedInt32Array:
			els = raw
		elif raw is Array:
			for item in raw:
				els.append(int(item))
		for el in els:
			if seen.has(el):
				continue
			seen[el] = true
			var noun := _element_noun(el)
			if not noun.is_empty():
				names.append(noun)
	return names


func _element_noun(el: int) -> String:
	match el:
		AbilityDef.Element.FIRE:
			return "fire"
		AbilityDef.Element.ICE:
			return "frost"
		AbilityDef.Element.STORM:
			return "lightning"
		AbilityDef.Element.SHADOW:
			return "shadow"
		AbilityDef.Element.NATURE:
			return "nature"
		AbilityDef.Element.HOLY:
			return "divine"
		AbilityDef.Element.PROTECTION:
			return "protection"
		_:
			return ""


func _apply_ability_shields(ab: AbilityDef) -> void:
	if ab == null or ab.shield <= 0.0:
		return
	var rad := ab.aoe_radius
	if rad <= 0.05:
		apply_spell_shield(self, ab)
		return
	for other in ArenaState.units_near(global_position, rad, false, true):
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != team:
			continue
		apply_spell_shield(u, ab)


func shield_amount() -> float:
	var total := 0.0
	for layer in _shield_layers:
		total += float(layer.get("remaining", 0.0))
	return maxf(0.0, total)


func health_bar_span() -> float:
	return maxf(max_health, health + shield_amount())


func receive_ability_hit(source = null, element: int = AbilityDef.Element.NONE, damage: float = 0.0, _mark_bonus: float = 0.0, extra_elements: PackedInt32Array = PackedInt32Array(), tick_hit: bool = false, grant_chill: bool = true, _allow_reactions: bool = true, overheat_cast_id: int = -1, infusion_double: int = 0, ability_id: String = "", combat_text_cast_id: int = -1, combat_text_periodic: bool = false) -> void:
	if not is_instance_valid(source):
		source = null
	if is_dead:
		return
	var ab := _spell_for_incoming_hit(source, ability_id, element, extra_elements)
	if ab != null and not SpellPower.deals_enemy_damage(ab):
		return
	if source != null:
		damage *= TalentCombat.hit_mult(source, self, element, extra_elements, tick_hit, ability_id)
	if ab != null and ab.execute_health_frac > 0.05 and max_health > 0.05 and health / max_health <= ab.execute_health_frac:
		damage *= ab.execute_damage_mult
	var extras: Array[int] = []
	for extra in extra_elements:
		if extra != AbilityDef.Element.NONE and extra != element and not extras.has(extra):
			extras.append(extra)
	var was_frozen := _stun_left > 0.0
	if _element_applies_mark(element):
		_apply_mark(element, source, false if tick_hit else true, grant_chill, infusion_double, not tick_hit)
	for extra in extras:
		_apply_infusion_status(source, extra, true, false if tick_hit else grant_chill, infusion_double, not tick_hit)
	var crit := false
	if source and not tick_hit and not AbilityDef.matches_base(ability_id, "shock_chain"):
		crit = source.roll_ability_crit(ab, self)
	var powered := SpellPower.packet(damage, ab, extra_elements, self, false, ability_id, crit, element)
	var dealt := powered
	if source:
		source._refund_overheat_if_ice_hit(element, extra_elements, damage, tick_hit, grant_chill, overheat_cast_id)
	var kind := _hit_number_kind(element, tick_hit)
	var spell := ability_id
	if spell.is_empty():
		if tick_hit and element == AbilityDef.Element.ICE:
			spell = "chilled_ground"
		else:
			spell = kind
	var split := (
		_DamageNumber.split_for_hit(ab, extra_elements, self, ability_id, crit, element, tick_hit, damage, dealt)
		if GameSession.show_damage_numbers
		else {}
	)
	take_damage(dealt, source, _hit_number_tint(kind), kind, spell, crit, true, combat_text_cast_id, combat_text_periodic or tick_hit, split)
	if was_frozen:
		_chew_shatter_from_hit(source, dealt, element, extras, infusion_double, ability_id, combat_text_cast_id)
	if source and dealt > 0.05:
		source.apply_momentum_cooldown_refund(ab, combat_text_cast_id, self)
		if ab != null and ab.lifesteal > 0.05:
			source.apply_heal(dealt * ab.lifesteal, source, ability_id)
	if source and not tick_hit:
		var pulse := _hit_carries_element(element, extras, AbilityDef.Element.NATURE) or TalentCombat.tempest_bloom_pulses(source, element, extras)
		if pulse:
			source._pulse_rejuvenation(dealt, crit_status_stacks(1, crit))
	if is_dead:
		return
	if _hit_carries_fire(element, extras):
		apply_burn(source, dealt)
		if infusion_double & INFUSION_DOUBLE_FIRE:
			apply_burn(source, dealt)
	if _hit_carries_element(element, extras, AbilityDef.Element.ICE) and grant_chill:
		apply_chill(dealt, source)
	if _hit_carries_element(element, extras, AbilityDef.Element.STORM):
		var shock_n := TalentCombat.shock_stacks_on_hit(source, ability_id, tick_hit)
		if shock_n > 0:
			apply_shock(source, crit_status_stacks(shock_n, crit))
	if _hit_carries_element(element, extras, AbilityDef.Element.SHADOW) and not _is_shatter_pulse(ability_id):
		apply_afflict_stacks(source, crit_status_stacks(1, crit))
	UnitEnemyAlter.on_ability_hit(self, source, ab, element, extras, tick_hit, crit)
	if source != null and dealt > 0.05 and not _is_shatter_pulse(ability_id):
		_try_shock_chain(source, dealt)
	if source != null:
		TalentCombat.on_ability_hit(source, self, ab, element, extras, dealt, tick_hit, crit, ability_id)


func _hit_carries_fire(element: int, extras: Array) -> bool:
	return _hit_carries_element(element, extras, AbilityDef.Element.FIRE)


func _break_freeze() -> void:
	_reset_shatter_shell()
	_stun_left = 0.0
	_stun_max = 0.0
	_refresh_freeze_visual()


func _reset_shatter_shell() -> void:
	_shatter_fire_contrib = 0.0
	_shatter_shadow_contrib = 0.0


func _is_shatter_pulse(ability_id: String) -> bool:
	return ability_id.begins_with("shatter")


func _chew_shatter_from_dot(source: Unit, amount: float, hit_kind: String, combat_text_cast_id: int) -> void:
	if amount <= 0.05:
		return
	if hit_kind == "burn":
		_chew_shatter_shell(source, amount, 0.0, AbilityDef.Element.FIRE, combat_text_cast_id)
	elif hit_kind == "afflicted":
		_chew_shatter_shell(source, 0.0, amount, AbilityDef.Element.SHADOW, combat_text_cast_id)


func _chew_shatter_from_hit(
	source: Unit,
	dealt: float,
	element: int,
	extras: Array,
	infusion_double: int,
	ability_id: String,
	combat_text_cast_id: int
) -> void:
	if dealt <= 0.05 or _is_shatter_pulse(ability_id):
		return
	var fire_hit := _hit_carries_fire(element, extras) or (infusion_double & INFUSION_DOUBLE_FIRE) != 0
	var shadow_hit := _hit_carries_element(element, extras, AbilityDef.Element.SHADOW)
	if not fire_hit and not shadow_hit:
		return
	var fire_amt := 0.0
	var shadow_amt := 0.0
	if fire_hit and shadow_hit:
		fire_amt = dealt * 0.5
		shadow_amt = dealt * 0.5
	elif fire_hit:
		fire_amt = dealt
	else:
		shadow_amt = dealt
	_chew_shatter_shell(source, fire_amt, shadow_amt, element, combat_text_cast_id)


func _chew_shatter_shell(
	source: Unit,
	fire_amt: float,
	shadow_amt: float,
	primary_element: int,
	combat_text_cast_id: int
) -> void:
	if fire_amt <= 0.0 and shadow_amt <= 0.0:
		return
	_shatter_fire_contrib += maxf(fire_amt, 0.0)
	_shatter_shadow_contrib += maxf(shadow_amt, 0.0)
	var shell := EnemyRank.shatter_shell(combat_rank())
	if _shatter_fire_contrib + _shatter_shadow_contrib < shell:
		return
	var fire_c := _shatter_fire_contrib
	var shadow_c := _shatter_shadow_contrib
	var fire_wins := fire_c > shadow_c
	if fire_c == shadow_c:
		fire_wins = primary_element != AbilityDef.Element.SHADOW
	_break_freeze()
	if fire_wins:
		_reaction_flash(Color(1.0, 0.72, 0.22), 1.05)
	else:
		_reaction_flash(Color(0.62, 0.32, 0.82), 1.05)
	AudioManager.play_at("reaction.shatter", global_position + Vector3(0.0, height * 0.45, 0.0))
	if source != null and is_instance_valid(source):
		StatusReactions.on_shatter_break(self, source, fire_wins, fire_c, shadow_c, combat_text_cast_id)


func _element_applies_mark(kind: int) -> bool:
	return kind == AbilityDef.Element.FIRE or kind == AbilityDef.Element.ICE or kind == AbilityDef.Element.STORM


func _apply_infusion_status(_source: Unit, kind: int, stack_storm: bool, stack_chill: bool = true, infusion_double: int = 0, can_freeze: bool = false) -> void:
	if not _element_applies_mark(kind) or kind == AbilityDef.Element.FIRE:
		return
	_apply_mark(kind, _source, stack_storm, stack_chill, infusion_double, can_freeze)


func _hit_carries_element(element: int, extras: Array, want: int) -> bool:
	if element == want:
		return true
	for extra in extras:
		if extra == want:
			return true
	return false


func _pulse_rejuvenation(dealt: float, stacks: int = 1) -> void:
	if is_dead or dealt <= 0.0:
		return
	var amt := dealt * TalentCombat.pulse_ratio(self)
	if amt < 1.0:
		return
	var allies := TalentCombat.pulse_allies(self, dealt)
	if allies.is_empty():
		return
	var share := amt / float(allies.size())
	var rejuv_n := maxi(stacks, 1)
	for u in allies:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		u.apply_heal(share, self, "nature")
		u.apply_rejuvenation(self, rejuv_n, "nature")


func apply_burn(source: Unit, hit_damage: float) -> void:
	var had_burn := not _burn_layers.is_empty()
	var add := hit_damage * TalentCombat.burn_store_ratio(source, self)
	if add <= 0.0:
		return
	_burn_layers.append({
		"remaining": add,
		"time_left": BURN_DURATION,
		"dps": add / BURN_DURATION,
		"source": source,
	})
	_mark_fire = maxf(_mark_fire, BURN_DURATION)
	TalentCombat.on_apply_burn(source, self, had_burn, add)


func apply_spread_burn(source: Unit, amount: float, duration: float, origin: Unit = null) -> void:
	if is_dead or amount <= 0.02 or duration <= 0.05:
		return
	var origin_id := origin.get_instance_id() if origin != null and is_instance_valid(origin) else 0
	var layer := {
		"remaining": amount,
		"time_left": duration,
		"dps": amount / duration,
		"source": source,
		"spread": true,
		"spread_from": origin_id,
	}
	for i in _burn_layers.size():
		var existing: Dictionary = _burn_layers[i]
		if bool(existing.get("spread", false)) and int(existing.get("spread_from", 0)) == origin_id:
			_burn_layers[i] = layer
			_mark_fire = maxf(_mark_fire, duration)
			return
	_burn_layers.append(layer)
	_mark_fire = maxf(_mark_fire, duration)


## Discrete stacks from a spell hit. Burn and Chill convert from damage, so crit already scales them.
static func crit_status_stacks(stacks: int, crit: bool) -> int:
	if stacks <= 0:
		return 0
	return stacks * 2 if crit else stacks


func apply_afflict(source: Unit) -> void:
	apply_afflict_stacks(source, 1)


func apply_afflict_stacks(source: Unit, stacks: int) -> void:
	if is_dead or stacks <= 0:
		return
	_afflict_stacks = mini(afflict_stack_max(), _afflict_stacks + stacks)
	_afflict_left = AFFLICT_DURATION
	if source != null and is_instance_valid(source):
		_afflict_src = source


func apply_rejuvenation(source: Unit, stacks: int = 1, ability_id: String = "") -> void:
	if is_dead or stacks <= 0:
		return
	if TalentCombat.drought_blocks_rejuv_apply(source, ability_id):
		return
	var had := _rejuv_stacks
	_rejuv_stacks = mini(REJUV_STACK_MAX, _rejuv_stacks + stacks)
	_rejuv_left = REJUV_DURATION
	if source != null and is_instance_valid(source):
		_rejuv_src = source
	TalentCombat.on_rejuvenation_applied(source, self, had, ability_id)


func rejuv_stacks() -> int:
	return _rejuv_stacks


func consume_rejuvenation() -> int:
	var n := _rejuv_stacks
	_clear_rejuv()
	return n


func apply_lifebloom(source: Unit, hps: float, duration: float, bloom: float) -> void:
	if is_dead or hps <= 0.05:
		return
	if source != null:
		var hooks := source.talent_hooks()
		if hooks != null and hooks.lifebloom_target_id != 0 and hooks.lifebloom_target_id != get_instance_id():
			var old = instance_from_id(hooks.lifebloom_target_id)
			if old is Unit and is_instance_valid(old) and old != self:
				(old as Unit).clear_lifebloom(false)
	_lifebloom_hps = hps
	_lifebloom_left = duration
	_lifebloom_max = duration
	_lifebloom_bloom = bloom
	_lifebloom_acc = 0.0
	_lifebloom_src = source


func has_lifebloom_from(source: Unit) -> bool:
	if _lifebloom_left <= 0.05:
		return false
	return source != null and _lifebloom_src == source


func consume_lifebloom(bloom_override: float = -1.0, trigger_expire_bloom: bool = true) -> void:
	var src := _lifebloom_src
	var bloom := bloom_override if bloom_override > 0.05 else ( _lifebloom_bloom if trigger_expire_bloom else 0.0 )
	clear_lifebloom(false)
	if bloom > 0.05 and src != null and is_instance_valid(src):
		apply_heal(bloom, src, "lifebloom")


func clear_lifebloom(trigger_expire_bloom: bool = true) -> void:
	var src := _lifebloom_src
	if trigger_expire_bloom and _lifebloom_bloom > 0.05 and src != null and is_instance_valid(src):
		apply_heal(_lifebloom_bloom, src, "lifebloom")
	_lifebloom_left = 0.0
	_lifebloom_max = 0.0
	_lifebloom_hps = 0.0
	_lifebloom_acc = 0.0
	_lifebloom_bloom = 0.0
	_lifebloom_src = null
	if src != null and is_instance_valid(src):
		var hooks := src.talent_hooks()
		if hooks != null and hooks.lifebloom_target_id == get_instance_id():
			hooks.lifebloom_target_id = 0


func apply_stormbond(source: Unit, duration: float) -> void:
	if is_dead:
		return
	_stormbond_left = duration
	_stormbond_src = source


func has_stormbond() -> bool:
	return _stormbond_left > 0.05


func clear_stormbond_from(source: Unit) -> void:
	if source != null and _stormbond_src == source:
		_stormbond_left = 0.0
		_stormbond_src = null


func shock_stacks() -> int:
	return _charged_stacks


func shock_source() -> Unit:
	return _shock_src if _shock_src != null and is_instance_valid(_shock_src) else null


func arm_skill_recast(index: int, window: float) -> void:
	_arm_recast(index, window)


func apply_holy_blessing(base_power: float, source: Unit = null) -> void:
	if is_dead or base_power <= 0.0:
		return
	var cap := TalentCombat.blessing_cap(source)
	var add := (base_power / BLESSING_REF) * cap * TalentCombat.blessing_rate(source)
	if add <= 0.0:
		return
	if _blessing_left <= 0.05:
		_blessing_dr = 0.0
	_blessing_dr = minf(cap, _blessing_dr + add)
	_blessing_left = maxf(_blessing_left, BLESSING_TIME)
	_blessing_max = maxf(_blessing_max, BLESSING_TIME)


func combat_rank() -> int:
	return EnemyRank.from_unit(self)


func chill_stacks() -> int:
	return _chill_stacks


func spreadable_chill_stacks() -> int:
	return _chill_stacks


func _effective_chill_stacks() -> int:
	return _chill_stacks + _spread_chill


func has_chill() -> bool:
	return _chill_stacks > 0 or _spread_chill > 0


func has_shock() -> bool:
	return _mark_storm > 0.0


func shock_stack_max() -> int:
	var cap := int(round(CombatBalance.flat("shock.stacks.max")))
	if cap <= 0:
		return SHOCK_MAX
	return cap


func shock_charge_ratio() -> float:
	if _charged_stacks <= 0:
		return 0.0
	return float(_charged_stacks) / float(shock_stack_max())


func holy_blessing_dr() -> float:
	return _blessing_dr if _blessing_left > 0.05 else 0.0


func has_burn() -> bool:
	return not _burn_layers.is_empty()


func burn_remaining() -> float:
	var total := 0.0
	for layer in _burn_layers:
		total += float(layer.get("remaining", 0.0))
	return total


func spreadable_burn_remaining() -> float:
	var total := 0.0
	for layer in _burn_layers:
		if bool(layer.get("spread", false)):
			continue
		total += float(layer.get("remaining", 0.0))
	return total


func consume_burn() -> float:
	var total := burn_remaining()
	_clear_burn()
	return total


func burn_source() -> Unit:
	for layer in _burn_layers:
		var layer_src = layer.get("source")
		if layer_src is Unit and is_instance_valid(layer_src):
			return layer_src as Unit
	return null


func apply_singe(source: Unit, duration: float, cap: int) -> void:
	if is_dead or duration <= 0.05 or cap <= 0:
		return
	_singe_src = source
	_singe_left = duration
	_singe_stacks = mini(_singe_stacks + 1, cap)


func singe_stacks() -> int:
	if _singe_left <= 0.05:
		return 0
	return _singe_stacks


func consume_singe() -> int:
	var n := singe_stacks()
	_clear_singe()
	return n


func apply_scorch(source: Unit, duration: float, snare: float) -> void:
	if is_dead or duration <= 0.05:
		return
	_scorch_src = source
	_scorch_left = duration
	_scorch_snare = maxf(_scorch_snare, snare)
	if snare > 0.0:
		apply_slow(snare, duration)


func has_scorch_from(source: Unit) -> bool:
	if _scorch_left <= 0.05 or source == null:
		return false
	return _scorch_src == source


func clear_scorch() -> void:
	_scorch_left = 0.0
	_scorch_snare = 0.0
	_scorch_src = null


func _clear_singe() -> void:
	_singe_stacks = 0
	_singe_left = 0.0
	_singe_src = null


func refresh_burn(seconds: float) -> void:
	if seconds <= 0.0 or _burn_layers.is_empty():
		return
	for layer in _burn_layers:
		layer["time_left"] = float(layer.get("time_left", 0.0)) + seconds


func afflict_stacks() -> int:
	return _afflict_stacks


func spreadable_afflict_stacks() -> int:
	return _afflict_stacks


func afflict_display_stacks() -> int:
	return _afflict_display_stacks()


func _afflict_display_stacks() -> int:
	return _afflict_stacks + _spread_afflict


func afflict_stack_max() -> int:
	return maxi(int(round(CombatBalance.flat("afflict.stacks.max"))), 1)


func apply_judgment_brand(stacks: int = 1) -> void:
	if team != TEAM_RAID or is_dead or stacks <= 0:
		return
	_judgment_brand += stacks


func double_judgment_brand() -> void:
	if team != TEAM_RAID or is_dead or _judgment_brand <= 0:
		return
	_judgment_brand *= 2


func judgment_brand_stacks() -> int:
	return _judgment_brand


func judgment_brand_taken_mult() -> float:
	if _judgment_brand <= 0:
		return 1.0
	return 1.0 + float(_judgment_brand) * CombatBalance.pct("dawnwarden.judgment.brand")


func afflict_tick_damage() -> float:
	var per := maxf(CombatBalance.flat("afflict.per"), 1.0)
	return CombatBalance.flat("afflict.tick") * float(_afflict_display_stacks()) / per


func afflict_remaining_value() -> float:
	return afflict_tick_damage() * _afflict_left


func consume_afflict() -> float:
	var total := afflict_remaining_value()
	_clear_afflict()
	return total


func consume_afflict_stacks() -> int:
	var stacks := _afflict_stacks
	if stacks <= 0:
		return 0
	_clear_afflict()
	return stacks


func absorb_ashen_afflict(stacks: int) -> void:
	if stacks <= 0:
		return
	_ashen_absorbed += stacks


func ashen_absorbed_afflict() -> int:
	return _ashen_absorbed


func clear_ashen_absorbed() -> void:
	_ashen_absorbed = 0


func apply_burn_from_afflict_stacks(source: Unit, stacks: int) -> int:
	if is_dead:
		return 0
	var take := clampi(stacks, 0, afflict_stack_max())
	if take <= 0:
		return 0
	var dps := float(take) * CombatBalance.flat("skill.ashen.afflict_to_burn")
	if dps > 0.02:
		_add_burn_dps(source, dps)
	return take


func convert_afflict_to_burn(source: Unit, fraction: float) -> int:
	if is_dead or _afflict_stacks <= 0 or fraction <= 0.0:
		return 0
	var take := clampi(int(round(float(_afflict_stacks) * fraction)), 0, _afflict_stacks)
	if take <= 0:
		return 0
	_afflict_stacks -= take
	if _afflict_stacks <= 0:
		_clear_afflict()
	var dps := float(take) * CombatBalance.flat("skill.ashen.afflict_to_burn")
	if dps > 0.02:
		_add_burn_dps(source, dps)
	return take


func _add_burn_dps(source: Unit, dps: float) -> void:
	if dps <= 0.0:
		return
	_burn_layers.append({
		"remaining": dps * BURN_DURATION,
		"time_left": BURN_DURATION,
		"dps": dps,
		"source": source,
	})
	_mark_fire = maxf(_mark_fire, BURN_DURATION)


func apply_chill(ability_damage: float, source: Unit = null, effectiveness: float = 1.0) -> void:
	if ability_damage <= 0.0:
		return
	var stacks_before := _chill_stacks
	effectiveness = TalentCombat.chill_effectiveness(source, self, effectiveness)
	var per := maxf(EnemyRank.ice_per_stack(combat_rank()), 0.01)
	_chill_progress += ability_damage * maxf(effectiveness, 0.0)
	var cap := EnemyRank.stack_max()
	while _chill_progress >= per and _chill_stacks < cap:
		_chill_stacks += 1
		_chill_progress -= per
	_chill_percent = float(_chill_stacks) / float(maxi(cap, 1))
	_chill_left = MARK_TIME
	_mark_ice = MARK_TIME
	TalentCombat.on_chill_applied(source, self, stacks_before)
	_try_chill_freeze(source)


func apply_chill_stacks(stacks: int, source: Unit = null) -> void:
	if stacks <= 0:
		return
	var stacks_before := _chill_stacks
	var cap := EnemyRank.stack_max()
	_chill_stacks = mini(cap, _chill_stacks + stacks)
	_chill_percent = float(_chill_stacks) / float(maxi(cap, 1))
	_chill_left = MARK_TIME
	_mark_ice = MARK_TIME
	TalentCombat.on_chill_applied(source, self, stacks_before)
	_try_chill_freeze(source)


func apply_spread_chill(stacks: int) -> void:
	if is_dead or stacks <= 0:
		return
	_spread_chill = stacks
	_spread_chill_left = MARK_TIME


func apply_spread_afflict(source: Unit, stacks: int) -> void:
	if is_dead or stacks <= 0:
		return
	_spread_afflict = mini(afflict_stack_max(), stacks)
	_spread_afflict_left = AFFLICT_DURATION
	if source != null and is_instance_valid(source) and _afflict_src == null:
		_afflict_src = source


func apply_shock(_source: Unit = null, stacks: int = 1) -> void:
	var n := maxi(stacks, 1)
	_charged_stacks = mini(shock_stack_max(), _charged_stacks + n)
	_mark_storm = SHOCK_TIME
	if _source != null and is_instance_valid(_source):
		_shock_src = _source


func _shock_chain_ratio() -> float:
	if _charged_stacks <= 0:
		return 0.0
	return CombatBalance.pct("shock.chain") * shock_charge_ratio()


func _try_shock_chain(source: Unit, hit_damage: float) -> void:
	if source == null or hit_damage <= 0.05 or _charged_stacks <= 0:
		return
	var ratio := _shock_chain_ratio()
	if ratio <= 0.0:
		return
	var bounce := hit_damage * ratio
	if bounce < 1.0:
		return
	var source_id := source.get_instance_id()
	var pending: Dictionary = _pending_shock_chains.get(source_id, {})
	pending["source_id"] = source_id
	pending["bounce"] = float(pending.get("bounce", 0.0)) + bounce
	_pending_shock_chains[source_id] = pending
	if not _shock_chain_flush_scheduled:
		_shock_chain_flush_scheduled = true
		_shock_chain_batch_left = SHOCK_CHAIN_BATCH_WINDOW


func _tick_shock_chain_batch(delta: float) -> void:
	_drain_shock_chain_batches()
	if not _shock_chain_flush_scheduled:
		return
	if is_dead:
		_pending_shock_chains.clear()
		_shock_chain_flush_scheduled = false
		_shock_chain_batch_left = 0.0
		return
	if _shock_chain_flush_queued:
		return
	_shock_chain_batch_left -= delta
	if _shock_chain_batch_left <= 0.0:
		_enqueue_shock_chain_batch(self)
		_drain_shock_chain_batches()


static func _ensure_shock_scheduler() -> void:
	var arena_id := ArenaState.arena.get_instance_id() if ArenaState.arena != null and is_instance_valid(ArenaState.arena) else 0
	if arena_id == _shock_scheduler_arena_id:
		return
	_shock_scheduler_arena_id = arena_id
	_shock_batch_queue.clear()
	_shock_batch_queued.clear()
	_shock_batch_frame = -1
	_shock_batches_used = 0


static func _enqueue_shock_chain_batch(unit: Unit) -> void:
	_ensure_shock_scheduler()
	if unit == null or not is_instance_valid(unit):
		return
	var id: int = unit.get_instance_id()
	if _shock_batch_queued.has(id):
		return
	unit._shock_chain_flush_queued = true
	_shock_batch_queued[id] = true
	_shock_batch_queue.append(id)


static func _drain_shock_chain_batches() -> void:
	_ensure_shock_scheduler()
	var frame := Engine.get_physics_frames()
	if frame == _shock_batch_frame:
		return
	_shock_batch_frame = frame
	_shock_batches_used = 0
	while _shock_batches_used < MAX_SHOCK_BATCHES_PER_PHYSICS_FRAME and not _shock_batch_queue.is_empty():
		var id: int = int(_shock_batch_queue.pop_front())
		_shock_batch_queued.erase(id)
		var found = instance_from_id(id)
		if found == null or not is_instance_valid(found):
			continue
		var unit := found as Unit
		if unit == null or unit.is_queued_for_deletion():
			continue
		unit._shock_chain_flush_queued = false
		_shock_batches_used += 1
		unit._flush_pending_shock_chains()


func _flush_pending_shock_chains() -> void:
	_shock_chain_flush_queued = false
	_shock_chain_flush_scheduled = false
	_shock_chain_batch_left = 0.0
	if _pending_shock_chains.is_empty():
		return
	var pending := _pending_shock_chains.values()
	_pending_shock_chains.clear()
	if is_dead:
		return
	for entry_any in pending:
		var entry: Dictionary = entry_any
		var source_id := int(entry.get("source_id", 0))
		var found = instance_from_id(source_id) if source_id != 0 else null
		if found == null or not is_instance_valid(found):
			continue
		var source := found as Unit
		if source == null:
			continue
		_resolve_shock_chain(source, float(entry.get("bounce", 0.0)))


func _resolve_shock_chain(source: Unit, bounce: float) -> void:
	if source == null or not is_instance_valid(source) or bounce < 1.0:
		return
	var hops: Array[Unit] = [self]
	var visited: Dictionary = {self: true}
	var current := self
	var hop_count := TalentCombat.shock_chain_hops(source)
	var bounce_range := TalentCombat.shock_chain_range(source)
	for _i in hop_count:
		var nxt := source._chain_bounce_target(current, visited, bounce_range, false)
		if nxt == null:
			break
		visited[nxt] = true
		hops.append(nxt)
		current = nxt
	if hops.size() >= 2:
		_ThunderWaveFx.spawn(hops, 0.05)
	for i in hops.size():
		var u := hops[i]
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		var dmg := bounce * TalentCombat.chain_hop_mult_for(source, i)
		if dmg < 1.0:
			continue
		u.take_damage(dmg, source, _DamageNumber.tint_for("lightning"), "lightning", "shock_chain", false, false, -1, true)
		TalentCombat.on_lightning_hop(source, u)
	StatusReactions.on_shock_chain(self, hops, source)


func outgoing_damage_mult(ability_id: String, hit_kind: String) -> float:
	return UnitAltered.outgoing_damage_mult(self, ability_id, hit_kind) * UnitEnemyAlter.outgoing_mult(self)


func element_taken_mult(element: int) -> float:
	return UnitEnemyAlter.taken_mult(self, element)


func _resist_cut(hit_kind: String, ability_id: String) -> float:
	return UnitAltered.resist_cut(self, hit_kind, ability_id)


func element_resist(element: int, ability_id: String = "") -> float:
	return _resist_cut(_hit_number_kind(element, false), ability_id)


func apply_altered_from(ab: AbilityDef, add_stack: bool = true) -> void:
	UnitAltered.apply_from(self, ab, add_stack)


func _apply_area_ally(target: Unit, ab: AbilityDef) -> void:
	if target == null or ab == null:
		return
	if ab.altered or ab.heal_allies or ab.shield > 0.05 or ab.applies_rejuvenation:
		_apply_ally_spell(target, ab)


func _apply_ally_and_self(target: Unit, ab: AbilityDef, include_support: bool = true) -> void:
	if target != null and target != self:
		_apply_ally_spell(target, ab, include_support)
		_apply_ally_spell(self, ab, false)
	else:
		_apply_ally_spell(self, ab, include_support)
	var cloak := target if target != null else self
	UnitIllusion.apply_shield_stealth(cloak, ab, _shield_duration_for(ab))


func _apply_ally_spell(target: Unit, ab: AbilityDef, include_support: bool = true, add_stack: bool = true) -> void:
	UnitAltered.apply_ally_spell(self, target, ab, include_support, add_stack)


func _tick_altered(delta: float) -> void:
	UnitAltered.tick(self, delta)


func _clear_altered_ice() -> void:
	UnitAltered.clear_ice(self)


func _clear_altered_shadow() -> void:
	UnitAltered.clear_shadow(self)


func _clear_altered_effects() -> void:
	UnitAltered.clear_all(self)


func _blessing_power_for(ab: AbilityDef) -> float:
	if ab == null or ab.base_power <= 0.05:
		return 0.0
	if ab.element == AbilityDef.Element.HOLY:
		return ab.base_power
	for extra in ab.extra_elements:
		if extra == AbilityDef.Element.HOLY:
			return ab.base_power
	return 0.0


func _tick_heal_practice(delta: float) -> void:
	if not heal_practice or is_dead:
		return
	if _heal_practice_reset <= 0.0:
		return
	_heal_practice_reset = maxf(0.0, _heal_practice_reset - delta)
	if _heal_practice_reset <= 0.0:
		health = 1.0


func arm_home_reset() -> void:
	_home_reset = true
	_home_pos = global_position
	_home_yaw = rotation.y
	_home_away = 0.0
	_home_return_left = 0.0


func _tick_dummy_home(delta: float) -> void:
	if not _home_reset or is_dead:
		return
	if _home_return_left > 0.0:
		_home_return_left = maxf(0.0, _home_return_left - delta)
		var t := 1.0 if _home_return_dur <= 0.001 else 1.0 - (_home_return_left / _home_return_dur)
		t = clampf(t * t * (3.0 - 2.0 * t), 0.0, 1.0)
		var p := _home_return_from.lerp(_home_pos, t)
		p.y = _home_pos.y
		global_position = p
		rotation.y = lerp_angle(rotation.y, _home_yaw, 1.0 - exp(-12.0 * delta))
		velocity = Vector3.ZERO
		if _home_return_left <= 0.0:
			global_position = _home_pos
			rotation.y = _home_yaw
			_home_away = 0.0
			reset_physics_interpolation()
		return
	var dx := global_position.x - _home_pos.x
	var dz := global_position.z - _home_pos.z
	if dx * dx + dz * dz <= DUMMY_HOME_SLACK * DUMMY_HOME_SLACK:
		_home_away = 0.0
		return
	_home_away += delta
	if _home_away < DUMMY_HOME_WAIT:
		return
	wind.clear()
	_home_return_from = global_position
	var dist := Vector2(dx, dz).length()
	_home_return_dur = clampf(dist / 10.0, 0.25, 0.7)
	_home_return_left = _home_return_dur
	_home_away = 0.0


func apply_support_hit(source: Unit, heal_amount: float, shield_amount: float, shield_duration: float, rejuvenate: bool, ability_id: String = "", blessing_power: float = 0.0, extra_elements: PackedInt32Array = PackedInt32Array(), element: int = AbilityDef.Element.NONE, combat_text_cast_id: int = -1, combat_text_periodic: bool = false) -> void:
	if is_dead:
		return
	var extras := extra_elements
	var primary := element
	var ab := source._ability_def_for_hit(ability_id, primary, extras) if source else null
	if ab != null:
		if extras.is_empty():
			extras = ab.extra_elements
		if primary == AbilityDef.Element.NONE:
			primary = ab.element
	var split := {}
	var crit := false
	if heal_amount > 0.05:
		crit = source.roll_ability_crit(ab) if source and not combat_text_periodic else false
		var healed := SpellPower.packet(heal_amount, ab, extras, null, true, ability_id, crit, primary)
		split = _DamageNumber.split_for_heal(ab, extras, ability_id, crit, primary, heal_amount, healed)
		var kind := _DamageNumber.kind_for_element(primary, combat_text_periodic) if primary != AbilityDef.Element.NONE else "heal"
		apply_heal(healed, source, ability_id, split, combat_text_cast_id, combat_text_periodic, crit, kind)
		if blessing_power > 0.05:
			apply_holy_blessing(blessing_power, source)
	if rejuvenate:
		var rejuv_n := TalentCombat.rejuvenation_stacks_to_apply(source, ability_id)
		apply_rejuvenation(source, crit_status_stacks(rejuv_n, crit), ability_id)
		TalentCombat.on_nature_support(source, self, ability_id, combat_text_cast_id)
	if shield_amount > 0.05:
		var dur := shield_duration if shield_duration > 0.05 else PROTECTION_SHIELD_TIME
		dur += TalentCombat.shield_duration_bonus(source, self, ab)
		var amt := SpellPower.packet(shield_amount, ab, extras, null, true, ability_id, false, primary, "shield")
		amt *= TalentCombat.shield_out_mult(source, self)
		apply_shield(amt, dur, source, SpellPower.elements_for(ab, extras, primary), combat_text_cast_id)
		UnitWind.apply_shield_haste(self, ab, dur)
		TalentCombat.on_shield_applied(source, self, ab, combat_text_cast_id)


func _burn_tick_damage() -> float:
	var total := 0.0
	for layer in _burn_layers:
		total += float(layer.get("dps", 0.0)) * BURN_TICK
	return total


func _burn_time_left() -> float:
	var t := 0.0
	for layer in _burn_layers:
		t = maxf(t, float(layer.get("time_left", 0.0)))
	return t


func is_stunned() -> bool:
	return _stun_left > 0.0


func boss_brain() -> BossAI:
	for child in get_children():
		if child is BossAI:
			return child
	return null


func apply_freeze(source: Unit = null) -> bool:
	if _pending_freeze:
		return false
	if _freeze_immune_left > 0.05:
		return false
	if is_boss and _freeze_should_defer():
		_pending_freeze = true
		_pending_freeze_source = source
		return true
	_commit_freeze(source)
	return true


func _freeze_should_defer() -> bool:
	var brain := boss_brain()
	return brain != null and brain.freeze_is_deferred()


func _commit_freeze(source: Unit = null) -> void:
	var dur := FREEZE_TIME
	_stun_left = dur
	_stun_max = dur
	_clear_chill_stacks()
	_reset_shatter_shell()
	_freeze_immune_left = maxf(_freeze_immune_left, EnemyRank.freeze_immune_time(combat_rank()))
	_pending_freeze = false
	_pending_freeze_source = null
	if controller:
		controller.stop_now()
	if movement:
		movement.stop_dodge()
	velocity = Vector3.ZERO
	_refresh_freeze_visual()
	AudioManager.play_at("freeze.lock", global_position + Vector3(0.0, height * 0.45, 0.0))
	if is_boss:
		var brain := boss_brain()
		if brain and brain.interrupt_current_cast():
			_DamageNumber.show_banner(self, "Interrupted!", Color(0.62, 0.92, 1.0))


func flush_pending_freeze() -> void:
	if not _pending_freeze:
		return
	if _freeze_should_defer():
		return
	var src := _pending_freeze_source
	_pending_freeze = false
	_pending_freeze_source = null
	_commit_freeze(src)


func die() -> void:
	if is_dead:
		return
	if _dev_test_unkillable():
		health = maxf(1.0, health)
		return
	if is_structure:
		is_dead = true
		health = 0.0
		var wall := host_wall
		host_wall = null
		if wall != null and is_instance_valid(wall) and wall.living:
			wall.detonate(true)
		died.emit(self)
		_DamageNumber.clear_for(self)
		return
	is_dead = true
	health = 0.0
	TalentCombat.on_death(self)
	set_ability_hover(false)
	_clear_marks()
	_stun_left = 0.0
	_stun_max = 0.0
	_pending_freeze = false
	_pending_freeze_source = null
	_infusion = AbilityDef.Element.NONE
	_overcharge_left = 0.0
	_overcharge_max = 0.0
	_overcharge_cooldown_rate = 1.0
	_stop_overcharge_sfx()
	_clear_radiance()
	_refresh_freeze_visual()
	_clear_ward()
	_clear_chill_stacks()
	_freeze_immune_left = 0.0
	_blessing_dr = 0.0
	_blessing_left = 0.0
	_blessing_max = 0.0
	_expire_recast()
	_illusion_exit_dir = Vector3.ZERO
	_echoing = false
	_illusion_echoing = false
	_illusion_invis_left = 0.0
	_illusion_invis_max = 0.0
	_refresh_stealth_visual()
	_cast_power = 1.0
	_channel_was_recast = false
	_channel_combat_text_cast_id = -1
	stop_aura()
	_clear_spell_ray()
	_SpellWall.detonate_owned_by(self)
	if is_instance_valid(_spell_wall):
		if _spell_wall.has_method("detonate"):
			_spell_wall.call("detonate")
		else:
			_spell_wall.queue_free()
		_spell_wall = null
	_slow_left = 0.0
	_nature_hedge_left = 0.0
	_haste_left = 0.0
	_haste_percent = 0.0
	_dr_left = 0.0
	_dr_percent = 0.0
	_dr_max = 0.0
	_clear_altered_effects()
	controller.stop_now()
	if movement:
		movement.stop_dodge()
	collision_layer = 0
	if _mesh:
		var mat := _mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = mat.albedo_color.darkened(0.55)
		_mesh.scale = Vector3(1.0, 0.35, 1.0)
		_mesh.position.y = 0.2
	died.emit(self)
	_DamageNumber.clear_for(self)
	if despawn_on_death:
		_begin_despawn()


func _begin_despawn() -> void:
	collision_layer = 0
	collision_mask = 0
	if _hp_root:
		_hp_root.visible = false
	if _feet_root:
		_feet_root.visible = false
	if _mesh:
		_mesh.visible = false
	if _face:
		_face.visible = false
	var vis := get_node_or_null("CharacterVisual") as Node3D
	if vis:
		var tw := create_tween()
		tw.tween_property(vis, "scale", vis.scale * 0.08, 0.18)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func auto_attack_origin() -> Vector3:
	var vis := get_node_or_null("CharacterVisual")
	if vis and vis.has_method("muzzle_point"):
		var from: Vector3 = vis.call("muzzle_point")
		if from.length_squared() > 0.0001:
			return from
	return global_position + Vector3(0.0, height * 0.72, 0.0) + facing_dir() * 0.12


func fire_auto_attack(target: Unit) -> void:
	if target == null or target.is_dead:
		return
	if target.team == team:
		if not can_attack_ally():
			return
		_restore_auto_mana()
		_fire_ally_auto(target)
		return
	_restore_auto_mana()
	if is_melee:
		_deliver_auto_hit(target)
		AudioManager.play_at("melee.hit", target.global_position + Vector3(0.0, 1.0, 0.0))
		return
	var origin := auto_attack_origin()
	Projectile.spawn(self, origin, _auto_projectile_cfg(target))


func _deliver_auto_hit(target: Unit) -> void:
	var aa := class_auto()
	if aa != null and aa.element != AbilityDef.Element.NONE:
		target.receive_ability_hit(self, aa.element, attack_damage, 0.0, aa.extra_elements, false, true, true, -1, 0, "auto")
	else:
		target.take_damage(attack_damage, self, _DamageNumber.tint_for("physical"), "physical", "auto")
		if attack_applies_charged:
			target._apply_mark(AbilityDef.Element.STORM, self)
	TalentCombat.on_auto_attack(self, target)


func _auto_projectile_cfg(target: Unit) -> Dictionary:
	var aa := class_auto()
	var color := Color(1.0, 0.5, 0.12)
	var element := AbilityDef.Element.NONE
	var extras := PackedInt32Array()
	var charged := attack_applies_charged
	var scene := attack_vfx_scene
	if aa != null:
		color = aa.projectile_color
		element = aa.element
		extras = aa.extra_elements
		charged = aa.applies_charged
		if not aa.vfx_scene.is_empty():
			scene = aa.vfx_scene
	return {
		"homing": target,
		"speed": attack_projectile_speed,
		"damage": attack_damage,
		"radius": 0.14,
		"max_distance": 24.0,
		"color": color,
		"element": element,
		"extra_elements": extras,
		"skillshot": false,
		"vfx_scene": scene,
		"vfx_scale": attack_vfx_scale,
		"vfx_yaw": attack_vfx_yaw,
		"grant_charged": charged,
		"ability_id": "auto",
	}


func can_attack_ally() -> bool:
	if attack_shield > 0.05:
		return true
	var aa := class_auto()
	return aa != null and aa.ally_heal > 0.05


func _restore_auto_mana() -> void:
	if attack_mana_restore > 0.05:
		restore_mana(attack_mana_restore)


func _fire_ally_auto(target: Unit) -> void:
	if not can_attack_ally() or target == null or target.is_dead:
		return
	var aa := class_auto()
	var heal := aa.ally_heal if aa != null else 0.0
	var rejuv := aa != null and aa.ally_rejuvenation
	var dur := attack_shield_duration if attack_shield_duration > 0.05 else WARD_TIME
	var color := aa.ally_color if aa != null and heal > 0.05 else Color(0.95, 0.88, 0.45)
	var scene := attack_vfx_scene
	if aa != null and not aa.vfx_scene.is_empty():
		scene = aa.vfx_scene
	if is_melee:
		if heal > 0.05 or rejuv:
			target.apply_support_hit(self, heal, attack_shield, dur, rejuv, "auto", 0.0, PackedInt32Array(), AbilityDef.Element.NATURE)
		elif attack_shield > 0.05:
			target.apply_shield(attack_shield, dur, self)
		AudioManager.play_at("auto.hit", target.global_position + Vector3(0.0, 1.0, 0.0))
		return
	var origin := auto_attack_origin()
	Projectile.spawn(self, origin, {
		"homing": target,
		"speed": attack_projectile_speed,
		"damage": 0.0,
		"heal": heal,
		"heal_allies": heal > 0.05,
		"applies_rejuvenation": rejuv,
		"element": AbilityDef.Element.NATURE if heal > 0.05 or rejuv else AbilityDef.Element.NONE,
		"shield": attack_shield,
		"shield_duration": dur,
		"radius": 0.14,
		"max_distance": 24.0,
		"color": color,
		"skillshot": false,
		"vfx_scene": scene,
		"vfx_scale": attack_vfx_scale,
		"vfx_yaw": attack_vfx_yaw,
		"vfx_primary": color,
		"vfx_secondary": color.darkened(0.18),
		"vfx_tertiary": color.lightened(0.2),
		"ability_id": "auto",
	})


func cast_ability(index: int, point: Vector3, target: Unit = null) -> void:
	if not can_prepare_cast(index):
		return
	var ab := abilities[index]
	var recast := has_recast_ready(index)
	_skill_recast = recast
	_cast_power = ab.recast_damage_mult if recast else 1.0
	spend_cast(index)
	if recast:
		_clear_recast()
	var wall_cast := ab.delivery == AbilityDef.Delivery.WALL
	var double_mask := 0 if wall_cast else _infusion_double_mask()
	var extras := _cast_extras(ab)
	var ice_id := -1 if wall_cast else _begin_ice_overheat_cast(ab, extras)
	var combat_text_cast_id := _DamageNumber.begin_cast()
	_deliver_ability(ab, point, target, extras, ice_id, double_mask, index, combat_text_cast_id)
	_skill_recast = false
	if not recast and not _echoing and ab.recast_window > 0.05:
		_arm_recast(index, ab.recast_window)
	if not recast and not _echoing and ab.echo and ab.delivery != AbilityDef.Delivery.GROUND_AOE and ab.delivery != AbilityDef.Delivery.AURA and ab.delivery != AbilityDef.Delivery.WALL:
		_queue_echo(index, point, target, ab, extras, ice_id, double_mask, combat_text_cast_id)
	_cast_power = 1.0


func _queue_echo(index: int, point: Vector3, target: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int) -> void:
	_echoing = true
	if not is_inside_tree():
		_echoing = false
		return
	var target_id := target.get_instance_id() if target != null and is_instance_valid(target) else 0
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_callback(_finish_queued_echo.bind(index, point, target_id, ab, extras, ice_id, double_mask, combat_text_cast_id))


func _finish_queued_echo(index: int, point: Vector3, target_id: int, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int) -> void:
	_echoing = false
	if is_dead or ab == null or index < 0 or index >= abilities.size():
		return
	var echo_target: Unit = null
	if target_id != 0:
		var found = instance_from_id(target_id)
		if is_instance_valid(found):
			echo_target = found as Unit
	_cast_power = ab.echo_damage_mult
	_deliver_ability(ab, point, echo_target, extras, ice_id, double_mask, index, combat_text_cast_id)
	_cast_power = 1.0


func _deliver_ability(ab: AbilityDef, point: Vector3, target: Unit, extras: PackedInt32Array, ice_id: int, double_mask: int, slot: int = -1, combat_text_cast_id: int = -1) -> void:
	if ClassSkillRuntime.try_deliver(self, ab, point, target, slot, combat_text_cast_id, _skill_recast):
		return
	var ally := target if target != null and is_instance_valid(target) and not target.is_dead and target.team == team and ab.can_target_allies() else null
	if ally != null and not ab.pierces_skillshot() and ab.target_mode == AbilityDef.TargetMode.UNIT:
		_play_ability_fx(ab, ally.global_position + Vector3(0, 1.0, 0))
		_apply_ally_and_self(ally, ab)
		_apply_cleave_ally_splash(ally, ab)
		return
	if ally != null and ally == self and ab.target_mode == AbilityDef.TargetMode.SKILLSHOT and not ab.pierces_skillshot():
		_apply_ally_and_self(ally, ab)
		_apply_cleave_ally_splash(ally, ab)
		return
	match ab.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
			if ab.delivery == AbilityDef.Delivery.RAY:
				return
			var dir := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
			if dir.length_squared() < 0.001:
				dir = facing_dir()
			dir = dir.normalized()
			if ab.is_cone():
				_cone_blast(dir, ab, extras, ice_id, double_mask, combat_text_cast_id)
			else:
				_spawn_skillshot_fan(dir, point, ab, extras, ice_id, double_mask, combat_text_cast_id)
		AbilityDef.TargetMode.UNIT:
			if target == null or target.is_dead:
				return
			if not ab.accepts_unit(team, target):
				return
			if ab.chain_bounces > 0 and target.team != team:
				_chain_lightning(target, ab, extras, ice_id, double_mask, combat_text_cast_id)
			else:
				_play_ability_fx(ab, target.global_position + Vector3(0, 1.0, 0))
				if target.team == team:
					_apply_ally_and_self(target, ab)
					_apply_cleave_ally_splash(target, ab)
				else:
					target.receive_ability_hit(self, ab.element, _scaled(ab.damage), 0.0, extras, false, true, true, ice_id, double_mask, ab.combat_id(), combat_text_cast_id)
					if ab.slow_duration > 0.0:
						target.apply_slow(ab.slow_percent, ab.slow_duration)
					UnitWind.apply_on_target(target, ab, self)
					_apply_cleave_splash(target, ab, extras, ice_id, double_mask, combat_text_cast_id)
		AbilityDef.TargetMode.GROUND:
			if ab.delivery == AbilityDef.Delivery.METEOR:
				_drop_meteors(point, ab, _scaled(ab.damage), ab.aoe_radius, extras, ice_id, double_mask, combat_text_cast_id)
			elif ab.delivery == AbilityDef.Delivery.WALL:
				_place_spell_wall(point, ab, extras, ice_id, double_mask, combat_text_cast_id)
			elif ab.delivery == AbilityDef.Delivery.GROUND_AOE or (ab.zone_duration > 0.05 and ab.tick_shield <= 0.05 and ab.tick_damage > 0.05):
				_place_ground_aoe(point, ab, extras, slot, combat_text_cast_id)
			elif ab.zone_duration > 0.05:
				if ab.tick_shield > 0.05:
					_place_sanctuary(point, ab, slot, combat_text_cast_id)
				else:
					_place_chilled_ground(point, ab, extras, ice_id, double_mask, slot, combat_text_cast_id)
			elif ab.delay_time > 0.0:
				_delayed_ground(point, ab, extras, ice_id, double_mask, combat_text_cast_id)
			else:
				if ab.delivery == AbilityDef.Delivery.NOVA:
					_SpellBaseFx.nova(point, ab.aoe_radius, ab)
				_ground_burst(point, ab, -1.0, -1.0, extras, ice_id, double_mask, combat_text_cast_id)
				_queue_illusion_area_echoes(point, ab, extras, ice_id, double_mask, -1.0, -1.0, combat_text_cast_id)
			if ab.delivery == AbilityDef.Delivery.GROUND_AOE or ab.zone_duration > 0.05:
				_apply_ally_and_self(ally, ab, false)
			elif ally != null and ally != self:
				_apply_ally_spell(ally, ab, false)
		AbilityDef.TargetMode.INSTANT:
			if ab.shield > 0.0:
				_apply_ability_shields(ab)
				_SpellBaseFx.shield_bubble(self, ab)
			if ab.damage > 0.05 or ab.delivery == AbilityDef.Delivery.NOVA:
				if ab.delivery == AbilityDef.Delivery.NOVA:
					_SpellBaseFx.nova(global_position, ab.aoe_radius, ab)
				_ground_burst(global_position, ab, -1.0, -1.0, extras, ice_id, double_mask, combat_text_cast_id)
				_queue_illusion_area_echoes(global_position, ab, extras, ice_id, double_mask, -1.0, -1.0, combat_text_cast_id)
			elif ab.grant_all_infusions or ab.buff_duration > 0.05 or ab.free_cast_charges > 0 or ab.shield > 0.0:
				_play_ability_fx(ab, global_position + Vector3(0.0, height * 0.45, 0.0))
			if ab.damage > 0.05 or ab.delivery == AbilityDef.Delivery.NOVA:
				if ally != null and ally != self:
					_apply_ally_spell(ally, ab, false)
			else:
				_apply_ally_and_self(ally, ab, false)


func begin_channel_cast(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	var ab := abilities[index]
	var recast := has_recast_ready(index)
	_cast_power = ab.recast_damage_mult if recast else 1.0
	_channel_was_recast = recast
	_channel_combat_text_cast_id = _DamageNumber.begin_cast()
	_illusion_missile_extras.clear()
	_illusion_ray_pulsed = false
	if recast:
		_clear_recast()
	if ab.delivery == AbilityDef.Delivery.RAY:
		_ensure_spell_rays(ab)
	if SpellWallLayout.is_protection(ab):
		var aim := global_position + facing_dir()
		if controller != null:
			aim = controller.cast_point
		var dir := SpellWallLayout.aim_dir(global_position, aim, facing_dir())
		if dir.length_squared() > 0.0001:
			rotation.y = Basis.looking_at(dir, Vector3.UP).get_euler().y
			_place_spell_wall(aim, ab, _cast_extras(ab), -1, 0, _channel_combat_text_cast_id)


func reaim_protection_wall(aim: Vector3) -> void:
	var dir := SpellWallLayout.aim_dir(global_position, aim, facing_dir())
	var wall := _live_spell_wall()
	if wall == null or not wall.living:
		return
	wall.aim_protection(dir)


func end_channel_cast(index: int = -1) -> void:
	if index >= 0 and index < abilities.size() and not _channel_was_recast:
		var ab := abilities[index]
		if ab != null and ab.recast_window > 0.05:
			_arm_recast(index, ab.recast_window)
	_channel_was_recast = false
	_cast_power = 1.0
	_channel_combat_text_cast_id = -1
	_clear_spell_ray()
	_clear_protection_wall()


func finish_channeled_ability(index: int, point: Vector3, charge: float) -> void:
	if index < 0 or index >= abilities.size():
		return
	var ab := abilities[index]
	var skip_cd := _channel_was_recast
	if not skip_cd and not _try_consume_free_cast():
		apply_cooldown(index, 1.0)
	if ab.delivery == AbilityDef.Delivery.WALL:
		end_channel_cast(index)
		return
	if ab.delivery == AbilityDef.Delivery.MISSILES:
		trigger_global_cooldown(index)
	var double_mask := _infusion_double_mask()
	var extras := _cast_extras(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	var combat_text_cast_id := _channel_combat_text_cast_id
	var dmg := _scaled(ab.scaled_damage(charge))
	var rad := ab.scaled_radius(charge)
	if ab.delivery == AbilityDef.Delivery.MISSILES or ab.cost_per_tick:
		end_channel_cast(index)
		return
	if ab.id == "meteor" or ab.delivery == AbilityDef.Delivery.METEOR:
		_drop_meteors(point, ab, dmg, rad, extras, ice_id, double_mask, combat_text_cast_id)
		end_channel_cast(index)
		return
	_ground_burst(point, ab, dmg, rad, extras, ice_id, double_mask, combat_text_cast_id)
	_queue_illusion_area_echoes(point, ab, extras, ice_id, double_mask, dmg, rad, combat_text_cast_id)
	end_channel_cast(index)


func _chain_lightning(primary: Unit, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combat_text_cast_id: int = -1, combat_text_periodic: bool = false) -> void:
	chain_lightning_at(
		global_position + Vector3(0.0, height * 0.62, 0.0),
		primary,
		ab,
		extras,
		overheat_cast_id,
		infusion_double,
		ab.chain_bounces,
		ab.bounce_range,
		combat_text_cast_id,
		combat_text_periodic
	)


func chain_lightning_at(
	origin: Vector3,
	primary: Unit,
	ab: AbilityDef,
	extras: PackedInt32Array = PackedInt32Array(),
	overheat_cast_id: int = -1,
	infusion_double: int = 0,
	extra_hops: int = -1,
	bounce_range: float = -1.0,
	combat_text_cast_id: int = -1,
	combat_text_periodic: bool = false,
	damage_override: float = -1.0,
	from_node: Node3D = null
) -> void:
	if ab == null or primary == null or not is_instance_valid(primary) or primary.is_dead:
		return
	var hops := extra_hops if extra_hops >= 0 else ab.chain_bounces
	if StormCloudZone.contains_caster(self):
		hops += 1
	var reach := bounce_range if bounce_range > 0.0 else ab.bounce_range
	var chain := _build_lightning_chain(primary, hops, reach)
	if chain.is_empty():
		return
	var hosts: Array = []
	if from_node != null and is_instance_valid(from_node):
		hosts.append(from_node)
	else:
		hosts.append(self)
	for u in chain:
		hosts.append(u)
	_ThunderWaveFx.spawn(hosts, ab.bounce_delay, true)
	var seen: Dictionary = {}
	for i in chain.size():
		var victim := chain[i]
		var first_on_target := not seen.has(victim)
		seen[victim] = true
		var delay := ab.bounce_delay * float(i)
		if delay <= 0.001:
			_apply_thunder_hit(victim, ab, extras, first_on_target, overheat_cast_id, infusion_double, i, combat_text_cast_id, combat_text_periodic, damage_override)
		else:
			get_tree().create_timer(delay).timeout.connect(_apply_thunder_hit.bind(victim, ab, extras, first_on_target, overheat_cast_id, infusion_double, i, combat_text_cast_id, combat_text_periodic, damage_override))


func _build_lightning_chain(primary: Unit, hops: int, bounce_range: float) -> Array[Unit]:
	var chain: Array[Unit] = [primary]
	var visited: Dictionary = {primary: true}
	var current := primary
	for _i in hops:
		var nxt := _chain_bounce_target(current, visited, bounce_range)
		if nxt == null:
			break
		visited[nxt] = true
		chain.append(nxt)
		current = nxt
	return chain


func _chain_bounce_target(from: Unit, visited: Dictionary, bounce_range: float, check_los: bool = true, closest: bool = false) -> Unit:
	if from == null or not is_instance_valid(from):
		return null
	var range_sq := bounce_range * bounce_range
	var origin := from.global_position
	if closest:
		var best: Unit = null
		var best_d := INF
		for u in ArenaState.units_near(origin, bounce_range):
			if u.team == team:
				continue
			if visited.has(u):
				continue
			var d := origin.distance_squared_to(u.global_position)
			if d > range_sq or d >= best_d:
				continue
			if check_los and not from.has_wall_los(u.global_position):
				continue
			best_d = d
			best = u
		return best
	var nearby: Array[Unit] = []
	for u in ArenaState.units_near(origin, bounce_range):
		if u.team == team:
			continue
		if visited.has(u):
			continue
		if origin.distance_squared_to(u.global_position) > range_sq:
			continue
		nearby.append(u)
	if nearby.is_empty():
		return null
	if not check_los:
		return nearby[randi() % nearby.size()]
	var tries := mini(nearby.size(), 4)
	for _i in tries:
		var idx := randi() % nearby.size()
		var pick := nearby[idx]
		nearby.remove_at(idx)
		if from.has_wall_los(pick.global_position):
			return pick
	return null


func _thunder_hit_point(u: Unit) -> Vector3:
	return u.global_position + Vector3(0.0, u.height * 0.55, 0.0)


func _rng_jitter() -> float:
	return randf_range(-0.85, 0.85)


func _apply_thunder_hit(victim: Unit, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), allow_reactions: bool = true, overheat_cast_id: int = -1, infusion_double: int = 0, hop: int = 0, combat_text_cast_id: int = -1, combat_text_periodic: bool = false, damage_override: float = -1.0) -> void:
	if victim == null or not is_instance_valid(victim) or victim.is_dead:
		return
	var hit_at := victim.global_position + Vector3(0.0, victim.height * 0.55, 0.0)
	AudioManager.play_at("thunder_wave.hop", hit_at)
	var raw := damage_override if damage_override >= 0.0 else _scaled(ab.damage)
	raw *= TalentCombat.chain_hop_mult_for(self, hop)
	victim.receive_ability_hit(self, ab.element, raw, 0.0, extras, false, true, allow_reactions, overheat_cast_id, infusion_double, ab.combat_id(), combat_text_cast_id, combat_text_periodic or hop > 0)
	if ab.slow_duration > 0.0:
		victim.apply_slow(ab.slow_percent, ab.slow_duration)


func _spawn_skillshot_fan(dir: Vector3, point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	var count := maxi(ab.projectile_count, 1)
	# Wave is already wide; bolt's 8° fan would stack into one blob.
	var spread := deg_to_rad(18.0) if ab.delivery == AbilityDef.Delivery.WAVE else deg_to_rad(8.0)
	var start := -spread * 0.5 * float(count - 1)
	for i in count:
		var shot_dir := dir.rotated(Vector3.UP, start + spread * float(i))
		_spawn_skillshot(shot_dir, point, ab, extras, ice_id, double_mask, combat_text_cast_id)
	for extra_dir in UnitIllusion.extra_shot_dirs(ab, dir):
		_spawn_skillshot(extra_dir, point, ab, extras, ice_id, double_mask, combat_text_cast_id)


func _apply_cleave_splash(primary: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int) -> void:
	if ab == null or primary == null or not is_instance_valid(primary):
		return
	if ab.splash_radius <= 0.05 or ab.splash_ratio <= 0.05:
		return
	if primary.team == team:
		_apply_cleave_ally_splash(primary, ab)
		return
	var splash_dmg := _scaled(ab.damage) * ab.splash_ratio
	if splash_dmg <= 0.05:
		return
	var origin := primary.global_position
	for u in ArenaState.units_near(origin, ab.splash_radius, false, true, true):
		if u == null or u == primary or u.team == team or u.is_dead:
			continue
		u.receive_ability_hit(self, ab.element, splash_dmg, 0.0, extras, false, true, true, ice_id, double_mask, ab.combat_id(), combat_text_cast_id)
	SpellWall.apply_radius_hit(self, origin, ab.splash_radius, splash_dmg, "hit", Color(0, 0, 0, 0), combat_text_cast_id, true)


func _apply_cleave_ally_splash(primary: Unit, ab: AbilityDef) -> void:
	if ab == null or primary == null or not is_instance_valid(primary):
		return
	if ab.splash_radius <= 0.05 or ab.splash_ratio <= 0.05:
		return
	if not ab.can_target_allies():
		return
	var origin := primary.global_position
	for u in ArenaState.units_near(origin, ab.splash_radius, false, true, true):
		if u == null or u == primary or u.team != team or u.is_dead:
			continue
		_apply_cleave_ally_hit(u, ab)


func _apply_cleave_ally_hit(target: Unit, ab: AbilityDef) -> void:
	var ratio := ab.splash_ratio
	var heal_amt := _scaled(ab.heal) if ab.heal > 0.05 else (_scaled(ab.damage) if ab.heal_allies else 0.0)
	if ab.heal_allies and heal_amt <= 0.05 and ab.tick_damage > 0.05:
		heal_amt = _scaled(ab.tick_damage)
	heal_amt *= ratio
	var shield_amt := _scaled(ab.shield) * ratio
	if heal_amt > 0.05 or shield_amt > 0.05 or ab.applies_rejuvenation:
		target.apply_support_hit(
			self,
			heal_amt,
			shield_amt,
			_shield_duration_for(ab),
			ab.applies_rejuvenation,
			ab.combat_id(),
			_blessing_power_for(ab),
			ab.extra_elements,
			ab.element
		)
	if ab.altered:
		target.apply_altered_from(ab)
	if shield_amt > 0.05:
		UnitIllusion.apply_shield_stealth(target, ab, _shield_duration_for(ab))


func _spawn_skillshot(dir: Vector3, point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	var max_d := ab.skillshot_reach()
	max_d = wall_travel_distance(dir, max_d, false)
	var travel := max_d
	if ab.splash_radius > 0.05 and not ab.pierces_skillshot():
		var to_aim := Vector2(point.x - global_position.x, point.z - global_position.z).length()
		travel = clampf(to_aim, 0.45, max_d)
	var spawn_off := clampf(minf(0.8, travel * 0.22), 0.12, maxf(travel - 0.2, 0.12))
	var remaining := maxf(travel - spawn_off, 0.15)
	var splash_vfx := AbilityFx.FIRE_AREA if ab.element == AbilityDef.Element.FIRE else AbilityFx.GROUND_EXPLOSION
	var lift := 0.55 if ab.delivery == AbilityDef.Delivery.WAVE else 1.0
	Projectile.spawn(self, global_position + dir * spawn_off + Vector3(0, lift, 0), {
		"direction": dir,
		"speed": ab.skillshot_speed,
		"damage": _scaled(ab.damage),
		"radius": ab.skillshot_width * 0.5,
		"max_distance": remaining,
		"color": ab.color,
		"skillshot": true,
		"element": ab.element,
		"extra_elements": extras,
		"overheat_cast_id": ice_id,
		"combat_text_cast_id": combat_text_cast_id,
		"infusion_double": double_mask,
		"vfx_scene": ab.travel_vfx_path(),
		"vfx_body_aura": ab.vfx_body_aura,
		"vfx_scale": ab.vfx_scale,
		"vfx_primary": ab.vfx_primary,
		"vfx_secondary": ab.vfx_secondary,
		"vfx_tertiary": ab.vfx_tertiary,
		"vfx_yaw": ab.vfx_yaw,
		"vfx_persist": ab.vfx_persist,
		"vfx_impact": ab.vfx_impact,
		"splash_radius": ab.splash_radius,
		"splash_ratio": ab.splash_ratio,
		"splash_vfx": splash_vfx if ab.splash_radius > 0.0 else "",
		"splash_vfx_scale": 1.5 if ab.element == AbilityDef.Element.FIRE else 0.55,
		"ability_id": ab.combat_id(),
		"ghost_enemies": SpellPower.ghosts_enemies(ab),
		"heal_allies": ab.heal_allies,
		"heal": _scaled(ab.heal),
		"shield": _scaled(ab.shield),
		"shield_duration": _shield_duration_for(ab),
		"applies_rejuvenation": ab.applies_rejuvenation,
		"blessing_power": _blessing_power_for(ab),
		"hit_cooldown_reduction": 0.0,
		"holy_pulse_ratio": ab.holy_pulse_ratio,
		"pierce": ab.pierces_skillshot(),
	})


func _spawn_ally_delivery(target: Unit, ab: AbilityDef) -> void:
	if target == null or target.is_dead:
		return
	var extras := _cast_extras(ab)
	var origin := global_position + Vector3(0.0, height * 0.62, 0.0)
	var dir := (target.global_position - global_position).slide(Vector3.UP)
	if dir.length_squared() < 0.001:
		dir = facing_dir()
	Projectile.spawn(self, origin, {
		"homing": target,
		"direction": dir.normalized(),
		"speed": ab.skillshot_speed if ab.skillshot_speed > 0.05 else 24.0,
		"damage": _scaled(ab.damage),
		"radius": 0.18,
		"max_distance": maxf(ab.range, 12.0) + 4.0,
		"color": ab.color,
		"skillshot": false,
		"element": ab.element,
		"extra_elements": extras,
		"vfx_scene": ab.travel_vfx_path(),
		"vfx_body_aura": ab.vfx_body_aura,
		"vfx_scale": ab.vfx_scale,
		"vfx_primary": ab.vfx_primary,
		"vfx_secondary": ab.vfx_secondary,
		"vfx_tertiary": ab.vfx_tertiary,
		"vfx_yaw": ab.vfx_yaw,
		"vfx_persist": ab.vfx_persist,
		"vfx_impact": ab.vfx_impact,
		"ability_id": ab.combat_id(),
		"ghost_enemies": SpellPower.ghosts_enemies(ab),
		"heal_allies": ab.heal_allies or ab.altered,
		"heal": _scaled(ab.heal),
		"shield": _scaled(ab.shield),
		"shield_duration": _shield_duration_for(ab),
		"applies_rejuvenation": ab.applies_rejuvenation,
		"blessing_power": _blessing_power_for(ab),
		"ally_cast": true,
	})


func _cone_blast(dir: Vector3, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combat_text_cast_id: int = -1) -> void:
	var length := ab.skillshot_reach()
	var half := ab.cone_angle * 0.5
	_IceBlastFx.spawn(global_position, dir, length, ab.cone_angle, cone_wall_lengths(dir, ab.cone_angle, length))
	for other in ArenaState.units_near(global_position, length, false, true, true):
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		var to := u.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > length + u.radius:
			continue
		if dist > 0.04:
			var ang := absf(dir.signed_angle_to(to.normalized(), Vector3.UP))
			var extra := atan2(u.radius, maxf(dist, 0.01))
			if ang > half + extra:
				continue
		if not has_wall_los(u.global_position):
			continue
		if u.team == team:
			_apply_area_ally(u, ab)
			continue
		u.receive_ability_hit(self, ab.element, _scaled(ab.damage), 0.0, extras, false, true, true, overheat_cast_id, infusion_double, ab.combat_id(), combat_text_cast_id)
		if ab.slow_duration > 0.0:
			u.apply_slow(ab.slow_percent, ab.slow_duration)
	SpellWall.apply_cone_hit(self, global_position, dir, length, half, _scaled(ab.damage), "hit", Color(0, 0, 0, 0), combat_text_cast_id)


func _play_ability_fx(ab: AbilityDef, pos: Vector3, look: Vector3 = Vector3.ZERO) -> void:
	var played := SpellVfx.play_point(ab, pos, look)
	_SpellBaseFx.cast_pop(pos, ab)
	if played:
		return
	_spawn_flash(pos, ab.color, maxf(0.6, ab.aoe_radius * 0.35))


func _place_sanctuary(point: Vector3, ab: AbilityDef, slot: int = -1, combat_text_cast_id: int = -1) -> void:
	_replace_floor_zone(slot, _Sanctuary.spawn(
		self,
		point,
		ab.aoe_radius,
		ab.zone_duration,
		ab.tick_interval,
		_scaled(ab.tick_damage),
		_scaled(ab.tick_shield),
		_shield_duration_for(ab),
		ab.combat_id(),
		ab.element,
		ab.extra_elements,
		combat_text_cast_id
	))
	SpellVfx.play_ability_impact(ab, Vector3(point.x, 0.35, point.z))


func _clear_protection_wall() -> void:
	var wall := _live_spell_wall()
	if wall == null:
		return
	if SpellWallLayout.style_id(wall.ability) != "protection":
		return
	if wall.has_method("detonate"):
		wall.detonate(false)
	elif is_instance_valid(wall):
		wall.queue_free()
	_spell_wall = null


func _live_spell_wall() -> SpellWall:
	if not is_instance_valid(_spell_wall):
		_spell_wall = null
		return null
	return _spell_wall as SpellWall


func _place_spell_wall(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1, _slot: int = -1) -> void:
	if SpellWallLayout.style_id(ab) == "illusion":
		_SpellWall.spawn(self, point, ab, extras, ice_id, double_mask, combat_text_cast_id)
		return
	var old := _live_spell_wall()
	if old != null:
		if old.has_method("detonate"):
			old.detonate()
		elif is_instance_valid(old):
			old.queue_free()
	_spell_wall = _SpellWall.spawn(self, point, ab, extras, ice_id, double_mask, combat_text_cast_id)


func _place_ground_aoe(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, slot: int = -1, combat_text_cast_id: int = -1) -> void:
	_replace_floor_zone(slot, _GroundAoe.spawn(self, point, ab, extras, -1.0, combat_text_cast_id))
	if UnitIllusion.has_illusion(ab):
		for extra in UnitIllusion.ground_extras(point, ab.aoe_radius, 2):
			_register_floor_extra(slot, _GroundAoe.spawn(self, extra.at, ab, extras, extra.radius, combat_text_cast_id))


func _ensure_spell_rays(ab: AbilityDef) -> void:
	var tint: Color = ab.vfx_primary if ab.vfx_primary.a > 0.02 else ab.color
	var width := 0.192
	if ab.skillshot_width > 0.05:
		width = ab.skillshot_width * (0.16 / 0.55)
	var count := maxi(ab.projectile_count, 1)
	var yaws := _ray_fan_yaws(count)
	var life := maxf(ab.channel_time * cast_time_scale(), 0.05)
	var reach := ab.range if ab.range > 0.05 else 14.0
	while _spell_rays.size() > count:
		var extra = _spell_rays.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	for i in count:
		var ray: SpellRay = null
		if i < _spell_rays.size() and is_instance_valid(_spell_rays[i]) and _spell_rays[i] is SpellRay:
			ray = _spell_rays[i] as SpellRay
		else:
			ray = _SpellRay.attach_aimed(self, tint, life, ab)
			if i < _spell_rays.size():
				var old = _spell_rays[i]
				if is_instance_valid(old):
					old.queue_free()
				_spell_rays[i] = ray
			else:
				_spell_rays.append(ray)
		ray.beam_width = width
		ray.steer_yaw = yaws[i] if i < yaws.size() else 0.0
		ray.reach = reach


func _ray_fan_yaws(count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := maxi(count, 1)
	if n <= 1:
		out.append(0.0)
		return out
	var spread := deg_to_rad(CombatBalance.flat("fan.angle"))
	var start := -spread * 0.5 * float(n - 1)
	for i in n:
		out.append(start + spread * float(i))
	return out


func ray_beam_end(ab: AbilityDef, dir: Vector3) -> Vector3:
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = facing_dir()
	if flat.length_squared() < 0.0001:
		flat = Vector3(0.0, 0.0, 1.0)
	flat = flat.normalized()
	var reach := ab.range if ab.range > 0.05 else 14.0
	return wall_stop_point(origin + flat * reach, true)


func _ray_beam_hits(ab: AbilityDef, u: Unit) -> bool:
	if u == null or u == self or not is_instance_valid(u) or u.is_dead:
		return false
	if u.team == team:
		return ab.can_target_allies()
	if SpellPower.ghosts_enemies(ab):
		return false
	return ab.can_target_enemies()


func _dist_to_xz_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len_sq := ab.length_squared()
	var t := 0.0 if len_sq < 0.0001 else clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return Vector2(p.x, p.z).distance_to(Vector2(a.x, a.z) + ab * t)


func _ray_beam_targets(ab: AbilityDef, aim: Vector3) -> Array[Unit]:
	var found: Array[Unit] = []
	var start := Vector3(global_position.x, 0.0, global_position.z)
	var end := Vector3(aim.x, 0.0, aim.z)
	var delta := end - start
	var length := delta.length()
	if length < 0.08:
		return found
	var dir := delta / length
	var half_w := ab.skillshot_width * 0.5 if ab.skillshot_width > 0.05 else 0.28
	var query_center := start.lerp(end, 0.5)
	var query_radius := length * 0.5 + half_w
	var ranked: Array[Dictionary] = []
	for u in ArenaState.units_near(query_center, query_radius, true, true, true):
		if not _ray_beam_hits(ab, u):
			continue
		if _dist_to_xz_segment(u.global_position, start, end) > half_w + u.radius:
			continue
		var along := Vector3(u.global_position.x - start.x, 0.0, u.global_position.z - start.z).dot(dir)
		if along < -u.radius or along > length + u.radius:
			continue
		ranked.append({"unit": u, "along": along})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.along) < float(b.along))
	var pierce := ab.pierces_skillshot()
	for row in ranked:
		found.append(row.unit as Unit)
		if not pierce:
			break
	return found


func _fire_ray_tick(index: int, ab: AbilityDef, _locked: Unit) -> bool:
	spend_mana(index)
	_ensure_spell_rays(ab)
	var extras := _cast_extras(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	_apply_ray_beam_hits(ab, extras, ice_id, _channel_combat_text_cast_id, true)
	if ab.echo and not _channel_was_recast:
		var tw := create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(_finish_ray_echo.bind(ab, extras, ice_id, _channel_combat_text_cast_id))
	return true


func _apply_ray_beam_hits(ab: AbilityDef, extras: PackedInt32Array, ice_id: int, combat_text_cast_id: int, allow_pulse: bool) -> void:
	var dmg := _scaled(ab.damage if ab.damage > 0.05 else ab.tick_damage)
	var origin := Vector3(global_position.x, 0.0, global_position.z)
	var aim := controller.cast_point if controller != null else origin + facing_dir() * (ab.range if ab.range > 0.05 else 14.0)
	var center := Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
	if center.length_squared() < 0.0001:
		center = facing_dir()
	if center.length_squared() < 0.0001:
		center = Vector3(0.0, 0.0, 1.0)
	center = center.normalized()
	var yaws := _ray_fan_yaws(maxi(ab.projectile_count, 1))
	var seen: Dictionary = {}
	var pulse_host: Unit = null
	for yaw in yaws:
		var dir := center.rotated(Vector3.UP, yaw)
		var dest := ray_beam_end(ab, dir)
		for target in _ray_beam_targets(ab, dest):
			var id := target.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			_hit_ray_target(target, ab, extras, ice_id, dmg, combat_text_cast_id)
			if pulse_host == null and target.team != team:
				pulse_host = target
	if allow_pulse:
		_try_illusion_ray_pulse(pulse_host, ab, extras, ice_id, dmg, combat_text_cast_id)


func _hit_ray_target(target: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, dmg: float, combat_text_cast_id: int) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	if target.team == team:
		_apply_ally_spell(target, ab, true, false)
		if target != self:
			apply_altered_from(ab, false)
		return
	target.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, ice_id, _infusion_double_mask(), ab.combat_id(), combat_text_cast_id)
	if UnitWind.has_wind(ab):
		UnitWind.start_ray_push(target, self)


func _try_illusion_ray_pulse(host: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, dmg: float, combat_text_cast_id: int) -> void:
	if _illusion_ray_pulsed or not UnitIllusion.has_illusion(ab):
		return
	if host == null or not is_instance_valid(host) or host.is_dead or host.team == team:
		return
	_illusion_ray_pulsed = true
	var pulse_el := _illusion_ray_pulse_element(ab)
	var pulse_extras := PackedInt32Array()
	for extra in extras:
		if extra == AbilityDef.Element.ILLUSION or extra == pulse_el:
			continue
		pulse_extras.append(extra)
	_SpellAura.burst_at(
		self,
		host.global_position,
		ab,
		pulse_extras,
		ice_id,
		_infusion_double_mask(),
		combat_text_cast_id,
		dmg,
		CombatBalance.flat("illusion.ray.pulse"),
		pulse_el
	)


func _illusion_ray_pulse_element(ab: AbilityDef) -> int:
	if ab == null:
		return AbilityDef.Element.ILLUSION
	if ab.element != AbilityDef.Element.ILLUSION:
		return ab.element
	for extra in ab.extra_elements:
		if extra != AbilityDef.Element.NONE and extra != AbilityDef.Element.ILLUSION:
			return extra
	return AbilityDef.Element.ILLUSION


func _finish_ray_echo(echo_ab: AbilityDef, echo_extras: PackedInt32Array, echo_ice: int, echo_combat_text_cast_id: int) -> void:
	if is_dead or echo_ab == null:
		return
	var saved := _cast_power
	_cast_power = echo_ab.echo_damage_mult
	_apply_ray_beam_hits(echo_ab, echo_extras, echo_ice, echo_combat_text_cast_id, false)
	_cast_power = saved


func _fire_illusion_missiles(around: Unit, origin: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, combat_text_cast_id: int = -1) -> void:
	if not UnitIllusion.has_illusion(ab):
		_illusion_missile_extras.clear()
		return
	if around != null and around.team == team:
		return
	if _illusion_missile_extras.is_empty():
		var n := maxi(int(round(CombatBalance.flat("illusion.missiles.count"))), 1)
		_illusion_missile_extras = UnitIllusion.nearby_enemies(around, CombatBalance.flat("illusion.missiles.radius"), self, n)
	var live: Array[Unit] = []
	for extra in _illusion_missile_extras:
		if extra == null or not is_instance_valid(extra) or extra.is_dead:
			continue
		live.append(extra)
		_fire_missile_set(extra, origin, ab, extras, ice_id, false, true, combat_text_cast_id)
	_illusion_missile_extras = live


func _missile_bloom_sides(count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 1:
		out.append(0.78)
		return out
	for i in count:
		out.append(lerpf(-1.0, 1.0, float(i) / float(count - 1)))
	if count == 3:
		out[1] = -0.22
	return out


func _missile_bloom_lifts(count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if count <= 1:
		out.append(0.28)
		return out
	for i in count:
		out.append(lerpf(0.52, -0.14, float(i) / float(count - 1)))
	return out


func _fire_missile_set(target: Unit, origin: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, ally_cast: bool, extra_target: bool = false, combat_text_cast_id: int = -1) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	if not extra_target and not ab.accepts_unit(team, target):
		return
	var n := maxi(int(round(CombatBalance.flat("missiles.volley"))), 1)
	var share := 1.0 / float(n)
	var sides := _missile_bloom_sides(n)
	var lifts := _missile_bloom_lifts(n)
	var width := CombatBalance.flat("missiles.arc.width")
	var toward := (target.global_position - global_position).slide(Vector3.UP)
	if toward.length_squared() < 0.001:
		toward = facing_dir()
	toward = toward.normalized()
	var speed := ab.skillshot_speed if ab.skillshot_speed > 0.05 else 26.0
	var dmg := _scaled(ab.damage) * share
	var heal_amt := 0.0 if extra_target else _scaled(ab.heal) * share
	var shield_amt := 0.0 if extra_target else _scaled(ab.shield) * share
	var travel := maxf(ab.range, 16.0) * 2.4 + 8.0
	if travel <= 0.05:
		travel = 16.0
	for i in n:
		var side := sides[i] if i < sides.size() else 0.0
		var yaw := side * 0.28
		var launch := toward.rotated(Vector3.UP, yaw)
		var splash_r := 0.0
		var splash_ratio := 0.0
		if i == 0 and ab.splash_radius > 0.05 and ab.splash_ratio > 0.05:
			splash_r = ab.splash_radius
			splash_ratio = ab.splash_ratio / share
		Projectile.spawn(self, origin, {
			"homing": target,
			"direction": launch,
			"speed": speed,
			"damage": dmg,
			"radius": 0.16,
			"max_distance": travel,
			"color": ab.color,
			"skillshot": false,
			"element": ab.element,
			"extra_elements": extras,
			"overheat_cast_id": ice_id,
			"combat_text_cast_id": combat_text_cast_id,
			"splash_radius": splash_r,
			"splash_ratio": splash_ratio,
			"vfx_scene": ab.travel_vfx_path(),
			"vfx_body_aura": ab.vfx_body_aura,
			"vfx_scale": ab.vfx_scale,
			"vfx_primary": ab.vfx_primary,
			"vfx_secondary": ab.vfx_secondary,
			"vfx_tertiary": ab.vfx_tertiary,
			"vfx_yaw": ab.vfx_yaw,
			"vfx_persist": ab.vfx_persist,
			"vfx_impact": ab.vfx_impact,
			"ability_id": ab.combat_id(),
			"ghost_enemies": SpellPower.ghosts_enemies(ab),
			"heal_allies": false if extra_target else (ab.heal_allies or ab.altered),
			"heal": heal_amt,
			"shield": shield_amt,
			"shield_duration": 0.0 if extra_target else _shield_duration_for(ab),
			"applies_rejuvenation": false if extra_target else ab.applies_rejuvenation,
			"blessing_power": 0.0 if extra_target else _blessing_power_for(ab),
			"ally_cast": ally_cast and not extra_target,
			"arc_side": side,
			"arc_width": width * randf_range(0.92, 1.08),
			"arc_lift": lifts[i] if i < lifts.size() else 0.0,
		})


func fire_channel_tick(index: int, target: Unit) -> bool:
	if index < 0 or index >= abilities.size():
		return false
	var ab := abilities[index]
	if not GameSession.has_infinite_mana() and mana < mana_cost_for(index):
		return false
	if ab.delivery == AbilityDef.Delivery.RAY:
		return _fire_ray_tick(index, ab, target)
	if target == null or not is_instance_valid(target) or target.is_dead:
		return false
	if not ab.accepts_unit(team, target):
		return false
	spend_mana(index)
	var extras := _cast_extras(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	var origin := global_position + Vector3(0.0, height * 0.62, 0.0)
	_fire_missile_set(target, origin, ab, extras, ice_id, target.team == team, false, _channel_combat_text_cast_id)
	_fire_illusion_missiles(target, origin, ab, extras, ice_id, _channel_combat_text_cast_id)
	if ab.echo and not _channel_was_recast:
		var target_id := target.get_instance_id() if target != null and is_instance_valid(target) else 0
		var tw := create_tween()
		tw.tween_interval(0.12)
		tw.tween_callback(_finish_missile_echo.bind(target_id, origin, ab, extras, ice_id, _channel_combat_text_cast_id))
	return true


func _finish_missile_echo(target_id: int, echo_origin: Vector3, echo_ab: AbilityDef, echo_extras: PackedInt32Array, echo_ice: int, echo_combat_text_cast_id: int) -> void:
	if is_dead or echo_ab == null:
		return
	var echo_target := instance_from_id(target_id) as Unit if target_id != 0 else null
	if echo_target == null or not is_instance_valid(echo_target) or echo_target.is_dead:
		return
	var saved := _cast_power
	_cast_power = echo_ab.echo_damage_mult
	_fire_missile_set(echo_target, echo_origin, echo_ab, echo_extras, echo_ice, echo_target.team == team, false, echo_combat_text_cast_id)
	_fire_illusion_missiles(echo_target, echo_origin, echo_ab, echo_extras, echo_ice, echo_combat_text_cast_id)
	_cast_power = saved


func _replace_floor_zone(slot: int, zone: Node) -> void:
	_clear_floor_extras(slot)
	if slot < 0:
		return
	if _floor_zones.has(slot):
		var old = _floor_zones[slot]
		_floor_zones.erase(slot)
		if is_instance_valid(old):
			old.queue_free()
	if zone != null and is_instance_valid(zone):
		_floor_zones[slot] = zone


func _register_floor_extra(slot: int, zone: Node) -> void:
	if zone == null or not is_instance_valid(zone):
		return
	if slot < 0:
		return
	if not _floor_extras.has(slot):
		_floor_extras[slot] = []
	(_floor_extras[slot] as Array).append(zone)


func _clear_floor_extras(slot: int) -> void:
	if slot < 0 or not _floor_extras.has(slot):
		return
	var extras: Array = _floor_extras[slot]
	_floor_extras.erase(slot)
	for extra in extras:
		if extra != null and is_instance_valid(extra):
			extra.queue_free()


func _place_chilled_ground(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, overheat_cast_id: int = -1, infusion_double: int = 0, slot: int = -1, combat_text_cast_id: int = -1) -> void:
	_replace_floor_zone(slot, _ChilledGround.spawn(
		self,
		point,
		ab.aoe_radius,
		ab.zone_duration,
		ab.tick_interval,
		_scaled(ab.tick_damage),
		ab.element,
		extras,
		overheat_cast_id,
		infusion_double,
		ab.combat_id(),
		combat_text_cast_id
	))


func _delayed_ground(point: Vector3, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combat_text_cast_id: int = -1) -> void:
	var t := Telegraph.circle_slam(self, point, ab.aoe_radius, ab.delay_time, _scaled(ab.damage), false)
	t.color = Color(ab.color.r, ab.color.g, ab.color.b, 0.45)
	t.vfx_scene = ab.vfx_scene
	t.vfx_cfg = ab.vfx_cfg()
	t.slow_percent = ab.slow_percent
	t.slow_duration = ab.slow_duration
	t.element = ab.element
	t.extra_elements = extras
	t.overheat_cast_id = overheat_cast_id
	t.infusion_double = infusion_double
	t.ability_id = ab.combat_id()
	t.combat_text_cast_id = combat_text_cast_id


func _ground_burst(point: Vector3, ab: AbilityDef, damage_override: float = -1.0, radius_override: float = -1.0, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combat_text_cast_id: int = -1) -> void:
	var dmg := _scaled(ab.damage) if damage_override < 0.0 else damage_override
	var rad := ab.aoe_radius if radius_override < 0.0 else radius_override
	var is_burst := ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION or ab.id == "aoe_explosion"
	var is_nova := ab.delivery == AbilityDef.Delivery.NOVA
	if is_burst:
		if not SpellVfx.play_ability_impact(ab, point):
			_GroundBlast.play(point, rad, ab)
	elif not is_nova:
		if SpellVfx.play_ability_impact(ab, point):
			pass
		elif ab.vfx_scene != "":
			var cfg := ab.vfx_cfg()
			cfg["area_radius"] = rad
			if ab.id == "meteor":
				# Ground-explosion shockwave mesh is radius 5 at scale 1; match the AoE marker.
				cfg["scale"] = maxf(rad / 5.0, 0.35)
			else:
				cfg["scale"] = ab.vfx_scale * clampf(rad / maxf(ab.aoe_radius, 0.5), 0.7, 1.6)
			if not AbilityFx.play_at(ab.vfx_scene, point, cfg):
				_spawn_flash(point, ab.color, maxf(0.6, rad * 0.35))
		else:
			_spawn_flash(point, ab.color, maxf(0.6, rad * 0.35))
		_SpellBaseFx.burst(point, rad, ab)
	for u in ArenaState.units_near(point, rad, false, true):
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if not _burst_has_los(point, u.global_position):
			continue
		if u.team == team:
			_apply_area_ally(u, ab)
			continue
		u.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, overheat_cast_id, infusion_double, ab.combat_id(), combat_text_cast_id)
		if ab.slow_duration > 0.0:
			u.apply_slow(ab.slow_percent, ab.slow_duration)
		UnitWind.apply_on_burst(u, ab, point)
	SpellWall.apply_radius_hit(self, point, rad, dmg, "hit", Color(0, 0, 0, 0), combat_text_cast_id, true)


func _drop_meteors(point: Vector3, ab: AbilityDef, dmg: float, rad: float, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	var keep := 1.0
	var spots: Array[Vector3] = [point]
	var step := 0.0
	if UnitIllusion.has_illusion(ab):
		keep = 1.0 + CombatBalance.pct("illusion.meteor.damage")
		var n := maxi(int(round(CombatBalance.flat("illusion.meteor.count"))), 1)
		spots = UnitIllusion.meteor_line(global_position, point, n)
		step = CombatBalance.flat("illusion.meteor.delay")
	for i in spots.size():
		var at: Vector3 = spots[i]
		var wait := step * float(i)
		if wait <= 0.001:
			_drop_one_meteor(at, ab, dmg * keep, rad, extras, ice_id, double_mask, combat_text_cast_id)
		else:
			get_tree().create_timer(wait).timeout.connect(_drop_one_meteor.bind(at, ab, dmg * keep, rad, extras, ice_id, double_mask, combat_text_cast_id))


func _drop_one_meteor(point: Vector3, ab: AbilityDef, dmg: float, rad: float, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	if is_dead:
		return
	_MeteorFx.drop(self, point, ab, dmg, rad, extras, ice_id, double_mask, combat_text_cast_id)


func _queue_illusion_area_echoes(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, damage_override: float = -1.0, radius_override: float = -1.0, combat_text_cast_id: int = -1) -> void:
	if _illusion_echoing or not UnitIllusion.has_illusion(ab):
		return
	var is_burst := ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION or ab.id == "aoe_explosion"
	if not is_burst:
		return
	if not is_inside_tree():
		return
	var base_rad := ab.aoe_radius if radius_override < 0.0 else radius_override
	var delay := CombatBalance.flat("illusion.burst.delay")
	var keep := CombatBalance.flat("illusion.burst.radius")
	for i in 2:
		var wait := delay * float(i + 1)
		var tw := create_tween()
		tw.tween_interval(wait)
		tw.tween_callback(_finish_illusion_area_echo.bind(point, ab, extras, ice_id, double_mask, damage_override, base_rad * keep, combat_text_cast_id))


func _finish_illusion_area_echo(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, damage_override: float, echo_rad: float, combat_text_cast_id: int) -> void:
	if is_dead or ab == null:
		return
	_illusion_echoing = true
	_ground_burst(point, ab, damage_override, echo_rad, extras, ice_id, double_mask, combat_text_cast_id)
	_illusion_echoing = false


func cone_wall_lengths(dir: Vector3, angle: float, radius: float, steps: int = 28) -> PackedFloat32Array:
	var lengths := PackedFloat32Array()
	lengths.resize(steps + 1)
	var half := angle * 0.5
	var right := Vector3.UP.cross(dir)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	for i in steps + 1:
		var a := -half + angle * float(i) / float(steps)
		var spoke := (dir * cos(a) + right * sin(a)).normalized()
		lengths[i] = wall_travel_distance(spoke, radius, false)
	return lengths


func _burst_has_los(from: Vector3, to: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.spell_has_los(from, to, [get_rid()])
	return has_wall_los(to)


func _tick_elemental(delta: float) -> void:
	_tick_shield(delta)
	if _blessing_left > 0.0:
		_blessing_left = maxf(0.0, _blessing_left - delta)
		if _blessing_left <= 0.0:
			_blessing_dr = 0.0
			_blessing_max = 0.0
	if _freeze_immune_left > 0.0:
		_freeze_immune_left = maxf(0.0, _freeze_immune_left - delta)
		if _freeze_immune_left <= 0.0 and _chill_stacks >= EnemyRank.stack_max():
			_try_chill_freeze()
	if _overcharge_left > 0.0:
		_overcharge_left = maxf(0.0, _overcharge_left - delta)
		if _overcharge_left <= 0.0:
			_overcharge_mana_cut = 0.0
			_overcharge_cast_bonus = 0.0
			_overcharge_cooldown_rate = 1.0
			_overcharge_max = 0.0
			_stop_overcharge_sfx(true)
			_refresh_infusion_visual()
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		if _stun_left <= 0.0:
			_stun_max = 0.0
			_reset_shatter_shell()
			_refresh_freeze_visual()
	if _pending_freeze:
		flush_pending_freeze()
	if is_dead:
		return
	_tick_altered(delta)
	UnitEnemyAlter.tick(self, delta)
	TalentCombat.tick(self, delta)
	_tick_furnace_marks(delta)
	_tick_burn(delta)
	_tick_afflict(delta)
	_tick_rejuv(delta)
	_tick_lifebloom(delta)
	_tick_stormbond(delta)
	_tick_spread_copies(delta)
	_mark_ice = maxf(0.0, _mark_ice - delta)
	_chill_left = maxf(0.0, _chill_left - delta)
	if _chill_left <= 0.0:
		_clear_chill_stacks()
	_mark_storm = maxf(0.0, _mark_storm - delta)
	if _mark_storm <= 0.0:
		_charged_stacks = 0


func _tick_furnace_marks(delta: float) -> void:
	if _singe_left > 0.0:
		_singe_left = maxf(0.0, _singe_left - delta)
		if _singe_left <= 0.0:
			_clear_singe()
	if _scorch_left > 0.0:
		_scorch_left = maxf(0.0, _scorch_left - delta)
		if _scorch_left <= 0.0:
			clear_scorch()


func _tick_burn(delta: float) -> void:
	if _burn_layers.is_empty():
		_burn_acc = 0.0
		return
	_burn_acc += delta
	while _burn_acc >= BURN_TICK and not _burn_layers.is_empty() and not is_dead:
		_burn_acc -= BURN_TICK
		var tick_damage := 0.0
		var tick_source: Unit = null
		for layer in _burn_layers:
			var slice := minf(float(layer.get("dps", 0.0)) * BURN_TICK, float(layer.get("remaining", 0.0)))
			layer["remaining"] = maxf(0.0, float(layer.get("remaining", 0.0)) - slice)
			tick_damage += slice
			var layer_src = layer.get("source")
			if layer_src is Unit and is_instance_valid(layer_src):
				tick_source = layer_src
		if tick_damage > 0.02:
			if tick_source != null:
				tick_damage = TalentCombat.modify_burn_tick(tick_source, self, tick_damage)
			take_damage(tick_damage, tick_source, _DamageNumber.tint_for("burn"), "burn", "burn", false, false, -1, true)
	var keep: Array[Dictionary] = []
	for layer in _burn_layers:
		var time_left := maxf(0.0, float(layer.get("time_left", 0.0)) - delta)
		layer["time_left"] = time_left
		if time_left > 0.02 and float(layer.get("remaining", 0.0)) > 0.02:
			keep.append(layer)
	_burn_layers = keep
	if _burn_layers.is_empty():
		_clear_burn()
	else:
		_mark_fire = _burn_time_left()


func _dot_tick_damage(layers: Array, tick: float) -> float:
	var total := 0.0
	for layer in layers:
		total += float(layer.get("dps", 0.0)) * tick
	return total


func _dot_time_left(layers: Array) -> float:
	var t := 0.0
	for layer in layers:
		t = maxf(t, float(layer.get("time_left", 0.0)))
	return t


func _tick_dot_layers(layers: Array, acc: float, tick: float, delta: float) -> Dictionary:
	var next_acc := acc + delta
	var tick_damage := 0.0
	var tick_source: Unit = null
	while next_acc >= tick and not layers.is_empty() and not is_dead:
		next_acc -= tick
		for layer in layers:
			var slice := minf(float(layer.get("dps", 0.0)) * tick, float(layer.get("remaining", 0.0)))
			layer["remaining"] = maxf(0.0, float(layer.get("remaining", 0.0)) - slice)
			tick_damage += slice
			var layer_src = layer.get("source")
			if layer_src is Unit and is_instance_valid(layer_src):
				tick_source = layer_src
	var keep: Array[Dictionary] = []
	for layer in layers:
		var time_left := maxf(0.0, float(layer.get("time_left", 0.0)) - delta)
		layer["time_left"] = time_left
		if time_left > 0.02 and float(layer.get("remaining", 0.0)) > 0.02:
			keep.append(layer)
	return {"acc": next_acc, "amount": tick_damage, "source": tick_source, "layers": keep}


func _clear_burn() -> void:
	_burn_layers.clear()
	_burn_acc = 0.0
	_mark_fire = 0.0


func _clear_afflict() -> void:
	_afflict_stacks = 0
	_afflict_left = 0.0
	_afflict_acc = 0.0
	_afflict_src = null
	_spread_afflict = 0
	_spread_afflict_left = 0.0


func _tick_spread_copies(delta: float) -> void:
	_spread_chill_left = maxf(0.0, _spread_chill_left - delta)
	if _spread_chill_left <= 0.02:
		_spread_chill = 0
	_spread_afflict_left = maxf(0.0, _spread_afflict_left - delta)
	if _spread_afflict_left <= 0.02:
		_spread_afflict = 0


func _clear_rejuv() -> void:
	_rejuv_stacks = 0
	_rejuv_left = 0.0
	_rejuv_acc = 0.0
	_rejuv_src = null


func _rejuv_hps() -> float:
	var hps := CombatBalance.flat("rejuvenation.hps")
	var src := _rejuv_src if _rejuv_src != null and is_instance_valid(_rejuv_src) else null
	if src != null:
		var hooks := src.talent_hooks()
		if hooks != null and hooks.evergreen > 0.0:
			hps *= 1.0 + hooks.evergreen
	return hps


func _tick_rejuv(delta: float) -> void:
	if _rejuv_stacks <= 0:
		_rejuv_acc = 0.0
		return
	_rejuv_left = maxf(0.0, _rejuv_left - delta)
	_rejuv_acc += delta
	var hps := _rejuv_hps()
	while _rejuv_acc >= REJUV_TICK and _rejuv_stacks > 0 and not is_dead:
		_rejuv_acc -= REJUV_TICK
		var amount := hps * float(_rejuv_stacks) * REJUV_TICK
		if amount > 0.02:
			var src: Unit = _rejuv_src if _rejuv_src != null and is_instance_valid(_rejuv_src) else null
			var split := _DamageNumber.split_for_amount("nature", amount)
			apply_heal(amount, src, "rejuvenation", split, -1, true, false, "rejuvenation")
	if _rejuv_left <= 0.02 or _rejuv_stacks <= 0:
		_clear_rejuv()


func _tick_lifebloom(delta: float) -> void:
	if _lifebloom_left <= 0.05:
		_lifebloom_acc = 0.0
		return
	_lifebloom_left = maxf(0.0, _lifebloom_left - delta)
	_lifebloom_acc += delta
	while _lifebloom_acc >= 1.0 and _lifebloom_left > 0.0 and not is_dead:
		_lifebloom_acc -= 1.0
		var src: Unit = _lifebloom_src if _lifebloom_src != null and is_instance_valid(_lifebloom_src) else null
		if _lifebloom_hps > 0.02:
			apply_heal(_lifebloom_hps, src, "lifebloom")
	if _lifebloom_left <= 0.02:
		clear_lifebloom(true)


func _tick_stormbond(delta: float) -> void:
	if _stormbond_left <= 0.05:
		return
	_stormbond_left = maxf(0.0, _stormbond_left - delta)
	if _stormbond_left <= 0.02:
		_stormbond_src = null


func _tick_afflict(delta: float) -> void:
	if _afflict_stacks <= 0 and _spread_afflict <= 0:
		_afflict_acc = 0.0
		return
	if _afflict_stacks > 0:
		_afflict_left = maxf(0.0, _afflict_left - delta)
	_afflict_acc += delta
	while _afflict_acc >= AFFLICT_TICK and (_afflict_stacks > 0 or _spread_afflict > 0) and not is_dead:
		_afflict_acc -= AFFLICT_TICK
		var amount := afflict_tick_damage() * AFFLICT_TICK
		if amount > 0.02:
			var src: Unit = _afflict_src if _afflict_src != null and is_instance_valid(_afflict_src) else null
			take_damage(amount, src, _DamageNumber.tint_for("afflicted"), "afflicted", "afflicted", false, false, -1, true)
	if _afflict_stacks > 0 and _afflict_left <= 0.02:
		_afflict_stacks = 0
		_afflict_left = 0.0
		if _spread_afflict <= 0:
			_afflict_acc = 0.0
			_afflict_src = null


func _apply_mark(kind: int, _source: Unit, _stack_storm: bool = true, _stack_chill: bool = true, _infusion_double: int = 0, _can_freeze: bool = false) -> void:
	if kind == AbilityDef.Element.FIRE:
		_mark_fire = maxf(_mark_fire, BURN_DURATION)
	elif kind == AbilityDef.Element.ICE:
		_mark_ice = MARK_TIME
	elif kind == AbilityDef.Element.STORM:
		_mark_storm = SHOCK_TIME


func _try_chill_freeze(source: Unit = null) -> void:
	if _chill_stacks < EnemyRank.stack_max():
		return
	if apply_freeze(source):
		_reaction_flash(Color(0.7, 0.92, 1.0), 0.95)


func _clear_chill_stacks() -> void:
	_chill_stacks = 0
	_chill_progress = 0.0
	_chill_percent = 0.0
	_chill_left = 0.0


func _clear_marks() -> void:
	_clear_burn()
	_clear_afflict()
	_clear_rejuv()
	_clear_singe()
	clear_scorch()
	UnitEnemyAlter.clear_all(self)
	_mark_ice = 0.0
	_clear_chill_stacks()
	_spread_chill = 0
	_spread_chill_left = 0.0
	_mark_storm = 0.0
	_charged_stacks = 0


func _reaction_flash(color: Color, size: float) -> void:
	_spawn_flash(global_position + Vector3(0, height * 0.45, 0), color, size)


func _mark_pip_texture() -> Texture2D:
	if _mark_pip_tex:
		return _mark_pip_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := 31.5
	var cy := 31.5
	for y in 64:
		for x in 64:
			var d := Vector2(float(x) - cx, float(y) - cy).length()
			if d > 31.0:
				continue
			var a := clampf(31.0 - d, 0.0, 1.0)
			var col := Color(1.0, 1.0, 1.0, a)
			if d > 26.5:
				col = Color(0.08, 0.08, 0.1, a)
			img.set_pixel(x, y, col)
	_mark_pip_tex = ImageTexture.create_from_image(img)
	return _mark_pip_tex


func _spawn_flash(point: Vector3, color: Color, size: float = 0.6) -> void:
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	fx.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	fx.material_override = mat
	var tree := get_tree()
	if tree == null or not is_inside_tree():
		fx.free()
		return
	var host := tree.current_scene
	if host == null:
		host = tree.root
	host.add_child(fx)
	fx.global_position = point + Vector3(0, 0.4, 0)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 1.8, 0.22)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(fx.queue_free)
