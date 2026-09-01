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
const _HoverFrameShader := preload("res://scripts/visual/hover_frame.gdshader")
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
const MOVE_SPEED_SCALE := 0.7
const DODGE_DISTANCE := 6.0 * MOVE_SPEED_SCALE
const DODGE_DURATION := 0.4
const DODGE_COOLDOWN := 4.5
const COMBUST_DURATION := 2.0
const COMBUST_TICKS := 32
const COMBUST_TICK := COMBUST_DURATION / float(COMBUST_TICKS)
const COMBUST_DIVISOR := 16.0
const SHOCK_MAX := 10
const SHOCK_TIME := 10.0
const SHOCK_CHAIN_RATIO := 0.20
const SHOCK_CHAIN_RANGE := 7.0
const SHOCK_CHAIN_HOPS := 3
const SHOCK_CHAIN_BATCH_WINDOW := 0.08
const MAX_SHOCK_BATCHES_PER_PHYSICS_FRAME := 12
const CHARGED_MANA_DIV := 4.0
const AFFLICT_DURATION := 10.0
const AFFLICT_TICK := 1.0
const AFFLICT_STACK_MAX := 200
const AFFLICT_TAKEN_AMP := 0.20
const REJUV_DURATION := 6.0
const REJUV_TICK := 1.0
const REJUV_STACK_MAX := 12
const PROTECTION_SHIELD_TIME := 6.0
const CHILL_PER_DAMAGE := 0.001
const CHILL_FREEZE_AT := 1.0
const BLESSING_MAX := 0.10
const BLESSING_REF := 200.0
const BLESSING_TIME := 8.0
const OVERHEAT_CD_REFUND := 3.0
const OVERHEAT_CD_REFUND_CAP := 4
const INFUSION_DOUBLE_FIRE := 1
const INFUSION_DOUBLE_ICE := 2
const INFUSION_DOUBLE_STORM := 4
const COMBUST_RADIUS := 2.8
const SHATTER_BONUS := 45.0
const CATACLYSM_BONUS := 80.0
const WARD_TIME := 6.0
const SHIELD_MOVE_SPEED := 0.15
const FREEZE_TIME := 5.0
const FREEZE_IMMUNE_TIME := 10.0
const FREEZE_BOSS := 5.0
const FREEZE_ADD := 5.0
const ALTERED_BUFF_TIME := 10.0
const ALTERED_FIRE_SPELL := 0.10
const ALTERED_FIRE_FIRE := 0.20
const ALTERED_RESIST := 0.30
const ALTERED_ICE_SPEED := 0.30
const ALTERED_ICE_TICK := 12.6
const ALTERED_ICE_INTERVAL := 0.5
const ALTERED_ICE_RADIUS := 2.2
const ALTERED_ICE_PATCH_TIME := 2.6
const ALTERED_ICE_DROP_DIST := 1.15
const ALTERED_STORM_TICK := 0.25
const ALTERED_STORM_DAMAGE := 13.5
const ALTERED_STORM_RANGE := 7.0
const ALTERED_STORM_HOPS := 3
const ALTERED_SHADOW_TICK := 1.0
const ALTERED_SHADOW_MAX := 30
const ALTERED_SHADOW_HP := 0.05
const ALTERED_SHADOW_DAMAGE := 0.30
const LOCAL_OUTLINE_WIDTH := 0.020
const LOCAL_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const _DodgeClockShader := preload("res://scripts/visual/dodge_clock.gdshader")

@export var unit_name: String = "Champion"
@export var team: int = TEAM_RAID
@export var is_champion: bool = false
@export var is_boss: bool = false
@export var show_nameplate: bool = false
@export var body_color: Color = Color(0.28, 0.55, 0.95)
@export var radius: float = 0.45
@export var height: float = 1.8

@export var max_health: float = 650.0
@export var max_mana: float = 400.0
@export var mana_regen: float = 10.0
@export var move_speed: float = 7.2
@export var turn_rate: float = 20.0
@export var acceleration: float = 42.0
@export var deceleration: float = 55.0

@export var attack_damage: float = 58.0
@export var attack_range: float = 6.2
@export var attack_windup: float = 0.06
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
var _chill_left: float = 0.0
var _freeze_immune_left: float = 0.0
var _afflict_stacks: int = 0
var _afflict_left: float = 0.0
var _afflict_acc: float = 0.0
var _afflict_src: Unit
var _blessing_dr: float = 0.0
var _blessing_left: float = 0.0
var _blessing_max: float = 0.0
var _burn_layers: Array[Dictionary] = []
var _burn_acc: float = 0.0
var _rejuv_stacks: int = 0
var _rejuv_left: float = 0.0
var _rejuv_acc: float = 0.0
var _rejuv_src: Unit
var _shield_layers: Array[Dictionary] = []
var _cast_power: float = 1.0
var _recast_index: int = -1
var _recast_left: float = 0.0
var _illusion_wall_slot: int = -1
var _echoing: bool = false
var _illusion_echoing: bool = false
var _illusion_invis_left: float = 0.0
var _illusion_invis_max: float = 0.0
var _channel_was_recast: bool = false
var _channel_combat_text_cast_id: int = -1
var _combust_tick: float = 0.0
var _combust_left: float = 0.0
var _combust_max: float = 0.0
var _combust_acc: float = 0.0
var _combust_hits_left: int = 0
var _combust_src: Unit
var _ward_left: float = 0.0
var _ward_time: float = 0.0
var _had_triple: bool = false
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
var _charge_mana_open: Dictionary = {}
var _slow_max: float = 0.0
var _ward_max: float = 0.0
var _floor_zones: Dictionary = {}
var _floor_extras: Dictionary = {}
var _stun_left: float = 0.0
var _stun_max: float = 0.0
var _wind_kb_left: float = 0.0
var _wind_kb_dur: float = 0.0
var _wind_kb_from: Vector3 = Vector3.ZERO
var _wind_kb_to: Vector3 = Vector3.ZERO
var _wind_air_left: float = 0.0
var _wind_air_dur: float = 0.0
var _wind_air_rise: float = 0.0
var _wind_air_peak: float = 0.0
var _wind_ground_y: float = 0.0
var _wind_ray_left: float = 0.0
var _wind_ray_from: Unit
var _wind_carry: Area3D
var _pending_freeze: bool = false
var _pending_freeze_source: Unit
var _overcharge_sfx: int = 0
var _free_casts: int = 0
var _free_cast_max: int = 0
var _free_cast_pips: Array[Sprite3D] = []
var _atonement_amp: float = 0.0
var _ward_source: Unit
var _altered_fire_left: float = 0.0
var _altered_ice_left: float = 0.0
var _altered_storm_left: float = 0.0
var _altered_shadow_left: float = 0.0
var _altered_shadow_stacks: int = 0
var _altered_shadow_acc: float = 0.0
var _altered_storm_acc: float = 0.0
var _altered_ice_drop: Vector3 = Vector3.ZERO
var _on_frost_trail: bool = false
var _frost_patches: Array[Node] = []
var _nature_hedge_left: float = 0.0
static var _frost_trail_ab: AbilityDef
var _auras: Dictionary = {}
var _spell_ray: Node
var _illusion_rays: Array = []
var _illusion_missile_extras: Array[Unit] = []
var _spell_wall: Node


func _ready() -> void:
	health = 1.0 if heal_practice else max_health
	mana = max_mana
	add_to_group("units")
	collision_layer = 0 if is_structure else 2
	collision_mask = 0 if is_structure else 1
	floor_snap_length = 0.4
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
	_clear_illusion_rays()


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
		if _freeze_immune_left <= 0.0 and _chill_percent >= CHILL_FREEZE_AT:
			_try_chill_freeze()
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		if _stun_left <= 0.0:
			_stun_max = 0.0
	if _pending_freeze:
		flush_pending_freeze()
	_tick_burn(delta)
	_tick_combust(delta)
	_tick_afflict(delta)
	_mark_ice = maxf(0.0, _mark_ice - delta)
	_chill_left = maxf(0.0, _chill_left - delta)
	if _chill_left <= 0.0:
		_chill_percent = 0.0
	_mark_storm = maxf(0.0, _mark_storm - delta)
	if _mark_storm <= 0.0:
		_charged_stacks = 0
	if not (_mark_fire > 0.0 and _mark_ice > 0.0 and _mark_storm > 0.0):
		_had_triple = false


func _physics_process(delta: float) -> void:
	if is_structure:
		_tick_structure(delta)
		return
	var overcharge_cooldown_rate := _overcharge_cooldown_rate if _overcharge_left > 0.0 else 1.0
	if _recast_left > 0.0:
		_recast_left = maxf(0.0, _recast_left - delta)
		if _recast_left <= 0.0:
			_clear_recast()
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


func _feet_bar_world() -> Vector3:
	var toward := Vector3(0.0, 0.0, 1.0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		toward = cam.global_position - global_position
		toward.y = 0.0
		if toward.length_squared() < 0.0001:
			toward = Vector3(0.0, 0.0, 1.0)
		else:
			toward = toward.normalized()
	return global_position + toward * (radius + 0.32) + Vector3(0.0, 0.22, 0.0)


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


func _bar_material(color: Color, priority: int, billboard: bool = true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mat.render_priority = priority
	return mat


func _make_bar_mesh(parent: Node3D, mesh_name: String, size: Vector2, y: float, color: Color, priority: int, billboard: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = Vector3(0, y, 0)
	mi.material_override = _bar_material(color, priority, billboard)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
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
	if _hp_root:
		_face_camera(_hp_root, global_position + Vector3(0, height + 0.62, 0))
	if _feet_root:
		_face_camera(_feet_root, _feet_bar_world())
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
	var spd := move_speed * MOVE_SPEED_SCALE
	if _haste_left > 0.0:
		spd *= 1.0 + _haste_percent
	if shield_amount() > 0.05:
		spd *= 1.0 + SHIELD_MOVE_SPEED
	if _chill_percent > 0.0:
		spd *= 1.0 - clampf(_chill_percent, 0.0, 1.0)
	if _slow_left > 0.0:
		spd *= 1.0 - _slow_percent
	if _nature_hedge_left > 0.0:
		spd *= 1.0 - clampf(CombatBalance.pct("wall.nature.slow"), 0.0, 0.9)
	if is_protection_hold():
		spd *= 1.0 - clampf(CombatBalance.pct("wall.protection.slow"), 0.0, 0.9)
	if _on_frost_trail:
		spd *= 1.0 + ALTERED_ICE_SPEED
	return spd


func apply_slow(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_slow_percent = maxf(_slow_percent, percent) if _slow_left > 0.0 else percent
	_slow_left = maxf(_slow_left, duration)
	_slow_max = maxf(_slow_max, duration)


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
	if not GameSession.ignores_cooldowns() and cooldown_left[index] > 0.0 and not has_recast_ready(index):
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
	return true


func try_dodge(dir: Vector3) -> bool:
	if not can_dodge() or movement == null:
		return false
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.04:
		flat = facing_dir()
	dodge_cooldown_left = DODGE_COOLDOWN
	movement.start_dodge(flat, DODGE_DISTANCE, DODGE_DURATION)
	var vis := get_node_or_null("CharacterVisual")
	if vis and vis.has_method("play_dodge"):
		vis.call("play_dodge", DODGE_DURATION)
	return true


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
	if _combust_left > 0.05:
		out.append(_combust_status_entry())
	if _rejuv_stacks > 0:
		out.append(_rejuv_status_entry())
	if _recast_left > 0.05 and _recast_index >= 0 and _recast_index < abilities.size():
		var recast_ab := abilities[_recast_index]
		var portal := recast_ab.delivery == AbilityDef.Delivery.WALL and SpellWallLayout.style_id(recast_ab) == "illusion"
		var portal_moves := _SpellWall.outlet_moves_left(self) if portal else 0
		var portal_text := "Recast to place the exit portal."
		if portal and portal_moves > 0:
			portal_text = "Recast to move the exit portal (%d left)." % portal_moves
		out.append({
			"id": "encore",
			"icon": "encore",
			"name": "Portal" if portal else "Encore",
			"color": Color(0.95, 0.62, 0.88) if portal else Color(0.95, 0.82, 0.45),
			"time_left": _recast_left,
			"duration": maxf(recast_ab.recast_window, _recast_left),
			"badge": ("%d" % portal_moves) if portal and portal_moves > 0 else "",
			"description": (
				portal_text
				if portal
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
	if _altered_fire_left > 0.05:
		out.append({
			"id": "altered_fire",
			"icon": "altered_fire",
			"name": "Altered Fire",
			"color": Color(1.0, 0.45, 0.12),
			"time_left": _altered_fire_left,
			"duration": ALTERED_BUFF_TIME,
			"description": "Spells deal +10% damage (+20% if fire-infused). 30% fire resistance.",
		})
	if _altered_ice_left > 0.05:
		out.append({
			"id": "altered_ice",
			"icon": "altered_ice",
			"name": "Altered Ice",
			"color": Color(0.45, 0.82, 1.0),
			"time_left": _altered_ice_left,
			"duration": ALTERED_BUFF_TIME,
			"description": "Leaves a frost trail. +30% move speed on it. 30% ice resistance.",
		})
	if _altered_storm_left > 0.05:
		out.append({
			"id": "altered_lightning",
			"icon": "altered_lightning",
			"name": "Altered Lightning",
			"color": Color(0.78, 0.68, 1.0),
			"time_left": _altered_storm_left,
			"duration": ALTERED_BUFF_TIME,
			"description": "Chains lightning every 0.25s. 20% less damage each bounce. 30% lightning resistance.",
		})
	if _altered_shadow_left > 0.05:
		out.append({
			"id": "altered_shadow",
			"icon": "altered_shadow",
			"name": "Shadow Pact",
			"color": Color(0.62, 0.28, 0.82),
			"time_left": _altered_shadow_left,
			"duration": ALTERED_BUFF_TIME,
			"stacks": _altered_shadow_stacks,
			"badge": str(_altered_shadow_stacks),
			"description": "Pact DoT (%d/%d). +%d%% damage dealt. 30%% shadow resist (not vs the pact)." % [
				_altered_shadow_stacks,
				ALTERED_SHADOW_MAX,
				int(round(ALTERED_SHADOW_DAMAGE * 100.0 * float(_altered_shadow_stacks) / float(ALTERED_SHADOW_MAX))),
			],
		})
	return out


func collect_debuffs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var umbral := _umbral_status_entry()
	if not umbral.is_empty():
		out.append(umbral)
	if _stun_left > 0.05:
		out.append(_frozen_status_entry())
	elif _pending_freeze:
		out.append(_pending_freeze_status_entry())
	if not _burn_layers.is_empty():
		out.append(_burn_status_entry())
	if _combust_left > 0.05:
		out.append(_combust_status_entry())
	if _freeze_immune_left > 0.05 and _stun_left <= 0.05:
		out.append({
			"id": "freeze_immune",
			"icon": "freeze_immune",
			"name": "Freeze Immune",
			"color": Color(0.62, 0.78, 0.88),
			"time_left": _freeze_immune_left,
			"duration": FREEZE_IMMUNE_TIME,
			"description": "Cannot be frozen. Chill can still stack.",
		})
	if _chill_percent > 0.001:
		out.append({
			"id": "chilled",
			"icon": "chilled",
			"name": "Chilled",
			"color": Color(0.45, 0.82, 1.0),
			"time_left": _chill_left,
			"duration": MARK_TIME,
			"badge": "%d%%" % int(round(_chill_percent * 100.0)),
			"description": "Slowed by %d%%. Lasts %ss without ice. Freeze at 100%% for %ss." % [int(round(_chill_percent * 100.0)), str(MARK_TIME), str(FREEZE_TIME)],
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
			"description": "Hits chain lightning to this target and nearby enemies (%d%% of the hit). 20%% less each bounce. Chain does not apply Shock." % int(round(_shock_chain_ratio() * 100.0)),
		})
	if _afflict_stacks > 0:
		out.append(_afflict_status_entry())
	if is_protection_hold():
		var slow := CombatBalance.pct("wall.protection.slow")
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
	# Shared left-to-right order for nameplates, target frames, and the boss frame.
	var want := PackedStringArray([
		"frozen", "frozen_pending", "burn", "chilled", "shocked", "afflicted",
		"combust", "slow", "freeze_immune", "umbral",
	])
	var by_id := {}
	for d in collect_debuffs():
		by_id[String(d.get("id", ""))] = d
	var out: Array[Dictionary] = []
	var seen := {}
	for id in want:
		if by_id.has(id):
			out.append(by_id[id])
			seen[id] = true
	for d in collect_debuffs():
		var id := String(d.get("id", ""))
		if id.is_empty() or seen.has(id):
			continue
		out.append(d)
	return out


func umbral_taken_bonus() -> float:
	if not is_boss:
		return 0.0
	var arena := ArenaState.arena as Arena
	if arena == null or not arena.umbral_shadow:
		return 0.0
	return arena.umbral_damage_taken_bonus(global_position)


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


func _umbral_status_entry() -> Dictionary:
	var bonus := umbral_taken_bonus()
	if bonus < 0.015:
		return {}
	var pct := int(round(bonus * 100.0))
	return {
		"id": "umbral",
		"icon": "umbral",
		"name": "Umbral",
		"color": Color(0.38, 0.48, 0.92),
		"badge": "%d%%" % pct,
		"description": "Takes more damage closer to the center of the shadow.",
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
		"description": "Cannot move, attack, or cast for %ss.\nA Fire hit Shatters this for double damage." % str(FREEZE_TIME),
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
		"description": "Stores 50%% of Fire hits as damage over %ss." % str(BURN_DURATION),
	}


func _combust_status_entry() -> Dictionary:
	return {
		"id": "combust",
		"icon": "combust",
		"name": "Combust",
		"color": Color(1.0, 0.28, 0.05),
		"time_left": _combust_left,
		"duration": maxf(_combust_max, _combust_left),
		"badge": _burn_tick_badge(_combust_tick),
		"description": "A violent Burn from Meteor or Burst.",
	}


func _afflict_status_entry() -> Dictionary:
	var amp := _afflict_stacks >= AFFLICT_STACK_MAX
	return {
		"id": "afflicted",
		"icon": "afflicted",
		"name": "Afflicted",
		"color": Color(0.62, 0.32, 0.82),
		"time_left": _afflict_left,
		"duration": AFFLICT_DURATION,
		"stacks": _afflict_stacks,
		"badge": "%d" % _afflict_stacks,
		"description": "1 damage per stack each second (%d/%d). Shadow hits add 1 stack.%s" % [
			_afflict_stacks,
			AFFLICT_STACK_MAX,
			" Takes 20% more damage." if amp else "",
		],
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
		"description": "+%d HPS per stack (%d/%d). New nature heals add a stack and refresh the duration." % [
			int(round(hps)),
			_rejuv_stacks,
			REJUV_STACK_MAX,
		],
	}


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
		"combust":
			_clear_combust()
			return true
		"afflicted":
			_clear_afflict()
			return true
		"rejuvenation":
			_clear_rejuv()
			return true
		"encore":
			_clear_recast()
			return true
		"holy_blessing":
			_blessing_dr = 0.0
			_blessing_left = 0.0
			_blessing_max = 0.0
			return true
		"altered_fire":
			_altered_fire_left = 0.0
			return true
		"altered_ice":
			_clear_altered_ice()
			return true
		"altered_lightning":
			_altered_storm_left = 0.0
			_altered_storm_acc = 0.0
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


func _arm_illusion_portal_recast(window: float) -> void:
	if _illusion_wall_slot < 0 or _illusion_wall_slot >= abilities.size():
		return
	_arm_recast(_illusion_wall_slot, window)


func _clear_recast() -> void:
	_recast_index = -1
	_recast_left = 0.0


func has_aura(index: int = -1) -> bool:
	_prune_auras()
	if index < 0:
		return not _auras.is_empty()
	return _auras.has(index)


func toggle_aura(index: int, target: Unit = null) -> void:
	if index < 0 or index >= abilities.size():
		return
	if has_aura(index):
		stop_aura(index)
		apply_cooldown(index, 1.0)
		return
	var ab := abilities[index]
	if _aura_infusion_blocked(ab):
		return
	if not can_prepare_cast(index):
		return
	_cast_power = 1.0
	if not _try_consume_free_cast():
		apply_cooldown(index, 1.0)
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


func stop_aura(index: int = -1) -> void:
	_prune_auras()
	if index < 0:
		for slot in _auras.keys():
			var node = _auras[slot]
			if is_instance_valid(node):
				node.queue_free()
		_auras.clear()
		return
	if not _auras.has(index):
		return
	var node = _auras[index]
	_auras.erase(index)
	if is_instance_valid(node):
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
	if is_instance_valid(_spell_ray):
		_spell_ray.queue_free()
	_spell_ray = null
	_clear_illusion_rays()
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


func roll_ability_crit(ab: AbilityDef) -> bool:
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


func take_damage(amount: float, source = null, number_color: Color = Color(0, 0, 0, 0), hit_kind: String = "", ability_id: String = "", crit: bool = false, ignore_resist: bool = false, combat_text_cast_id: int = -1, combat_text_periodic: bool = false, combat_text_split: Dictionary = {}) -> void:
	if not is_instance_valid(source):
		source = null
	if is_structure and host_wall != null and is_instance_valid(host_wall):
		if _afflict_stacks >= AFFLICT_STACK_MAX:
			amount *= 1.0 + CombatBalance.pct("afflict.taken")
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
	var umbral := umbral_taken_bonus()
	if umbral > 0.0:
		amount *= 1.0 + umbral
	if _afflict_stacks >= AFFLICT_STACK_MAX:
		amount *= 1.0 + CombatBalance.pct("afflict.taken")
	if _dr_left > 0.0 and _dr_percent > 0.0:
		amount *= maxf(0.0, 1.0 - _dr_percent)
		if amount <= 0.0:
			return
	if _blessing_left > 0.0 and _blessing_dr > 0.0:
		amount *= maxf(0.0, 1.0 - _blessing_dr)
		if amount <= 0.0:
			return
	if shield_amount() > 0.0:
		amount = _absorb_shield(amount)
		if amount <= 0.0:
			return
	health = maxf(0.0, health - amount)
	if immortal:
		health = maxf(1.0, health)
	var spell := ability_id if not ability_id.is_empty() else hit_kind
	damaged.emit(self, amount, source, spell)
	_present_damage_text(amount, source, number_color, hit_kind, crit, spell, combat_text_cast_id, combat_text_periodic, combat_text_split)
	if src != null:
		src.apply_atonement(amount)
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
	var mi := MeshInstance3D.new()
	mi.name = frame_name
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _HoverFrameShader
	mat.set_shader_parameter("outline_color", _hover_color)
	mat.set_shader_parameter("border", 0.02)
	mat.set_shader_parameter("billboard", camera_billboard)
	mat.render_priority = overlay_priority
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.visible = false
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
	if frame == null:
		return
	frame.visible = shown
	if not shown:
		return
	frame.position = pos
	frame.scale = Vector3(size.x, size.y, 1.0)
	var mat := frame.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_color", color)
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("border", border)


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
	if DODGE_COOLDOWN > 0.04:
		ratio = clampf(dodge_cooldown_left / DODGE_COOLDOWN, 0.0, 1.0)
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
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != team:
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
	var dur := _shield_duration_for(ab)
	target.apply_shield(_shield_grant_amount(ab), dur, self, SpellPower.elements_for(ab))
	UnitWind.apply_shield_haste(target, ab, dur)


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
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != team:
			continue
		if u.global_position.distance_to(global_position) > rad + u.radius:
			continue
		apply_spell_shield(u, ab)


func shield_amount() -> float:
	var total := 0.0
	for layer in _shield_layers:
		total += float(layer.get("remaining", 0.0))
	return maxf(0.0, total)


func health_bar_span() -> float:
	return maxf(max_health, health + shield_amount())


func elemental_mark_count() -> int:
	var n := 0
	if _mark_fire > 0.0:
		n += 1
	if _mark_ice > 0.0:
		n += 1
	if _mark_storm > 0.0:
		n += 1
	return n


func receive_ability_hit(source = null, element: int = AbilityDef.Element.NONE, damage: float = 0.0, mark_bonus: float = 0.0, extra_elements: PackedInt32Array = PackedInt32Array(), tick_hit: bool = false, grant_chill: bool = true, allow_reactions: bool = true, overheat_cast_id: int = -1, infusion_double: int = 0, ability_id: String = "", combat_text_cast_id: int = -1, combat_text_periodic: bool = false) -> void:
	if not is_instance_valid(source):
		source = null
	if is_dead:
		return
	var ab := _spell_for_incoming_hit(source, ability_id, element, extra_elements)
	if ab != null and not SpellPower.deals_enemy_damage(ab):
		return
	var extras: Array[int] = []
	for extra in extra_elements:
		if extra != AbilityDef.Element.NONE and extra != element and not extras.has(extra):
			extras.append(extra)
	var marks_before := elemental_mark_count()
	var had_fire := _mark_fire > 0.0
	var had_ice := _mark_ice > 0.0
	var had_storm := _mark_storm > 0.0
	var can_freeze := true
	var was_frozen := _stun_left > 0.0
	var bonus := 0.0
	if _element_applies_mark(element):
		if tick_hit:
			_apply_mark(element, source, false, grant_chill, infusion_double, false)
		elif allow_reactions:
			bonus += apply_elemental_hit(source, element, had_fire, had_ice, had_storm, infusion_double, can_freeze)
		else:
			_apply_mark(element, source, true, grant_chill, infusion_double, can_freeze)
	for extra in extras:
		_apply_infusion_status(source, extra, true, false if tick_hit else grant_chill, infusion_double, can_freeze)
	var shattered := not tick_hit and was_frozen and _hit_shatters_frozen(element, extras, infusion_double)
	if shattered:
		_reaction_flash(Color(1.0, 0.72, 0.22), 1.05)
		_break_freeze()
		AudioManager.play_at("reaction.shatter", global_position + Vector3(0.0, height * 0.45, 0.0))
	var crit := false
	if source and not tick_hit and not AbilityDef.matches_base(ability_id, "shock_chain"):
		crit = source.roll_ability_crit(ab)
	var powered := SpellPower.packet(damage, ab, extra_elements, self, false, ability_id, crit, element)
	var dealt := _final_spell_damage(powered, element, extras, had_storm, mark_bonus, marks_before, shattered, bonus)
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
	if source and not tick_hit and _hit_carries_element(element, extras, AbilityDef.Element.NATURE):
		source._pulse_rejuvenation(dealt)
	if is_dead:
		return
	if _hit_carries_fire(element, extras):
		apply_burn(source, dealt)
		if infusion_double & INFUSION_DOUBLE_FIRE:
			apply_burn(source, dealt)
	if _hit_carries_element(element, extras, AbilityDef.Element.ICE) and grant_chill:
		apply_chill(dealt, source)
	if _hit_carries_element(element, extras, AbilityDef.Element.STORM):
		apply_shock(source)
	if _hit_carries_element(element, extras, AbilityDef.Element.SHADOW):
		apply_afflict(source)
	if source != null and dealt > 0.05:
		_try_shock_chain(source, dealt)


func apply_elemental_hit(source: Unit, kind: int, had_fire: bool = false, had_ice: bool = false, had_storm: bool = false, infusion_double: int = 0, can_freeze: bool = false) -> float:
	if not _element_applies_mark(kind):
		return 0.0
	var extra := 0.0
	if kind == AbilityDef.Element.STORM:
		if had_ice:
			extra += CombatBalance.scaled_hit("shatter")
			_reaction_flash(Color(0.85, 0.95, 1.0), 0.7)
			AudioManager.play_at("reaction.shatter", global_position + Vector3(0.0, height * 0.45, 0.0))
	_apply_mark(kind, source, true, true, infusion_double, can_freeze)
	var triple := _mark_fire > 0.0 and _mark_ice > 0.0 and _mark_storm > 0.0
	if triple and not _had_triple:
		extra += CombatBalance.scaled_hit("cataclysm")
		_had_triple = true
		_reaction_flash(Color(1.0, 0.55, 0.2), 1.15)
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, global_position, {"scale": 0.85, "lifetime": 1.6})
		AudioManager.play_at("reaction.cataclysm", global_position)
	elif not triple:
		_had_triple = false
	return extra


func _final_spell_damage(base: float, element: int, extras: Array, _had_storm: bool, mark_bonus: float, marks_before: int, shattered: bool, reaction_bonus: float) -> float:
	var amount := base
	if mark_bonus > 0.0:
		amount *= 1.0 + mark_bonus * float(marks_before)
	if shattered:
		amount *= 2.0
	return amount + reaction_bonus


func _hit_is_fire_or_ice(element: int, extras: Array) -> bool:
	if element == AbilityDef.Element.FIRE or element == AbilityDef.Element.ICE:
		return true
	for extra in extras:
		if extra == AbilityDef.Element.FIRE or extra == AbilityDef.Element.ICE:
			return true
	return false


func _hit_carries_fire(element: int, extras: Array) -> bool:
	if element == AbilityDef.Element.FIRE:
		return true
	for extra in extras:
		if extra == AbilityDef.Element.FIRE:
			return true
	return false


func _break_freeze() -> void:
	if _stun_left <= 0.0:
		return
	_stun_left = 0.0
	_stun_max = 0.0
	_refresh_freeze_visual()


func _hit_shatters_frozen(element: int, extras: Array, infusion_double: int) -> bool:
	if element == AbilityDef.Element.FIRE:
		return true
	if (infusion_double & INFUSION_DOUBLE_FIRE) != 0:
		return true
	for extra in extras:
		if extra == AbilityDef.Element.FIRE:
			return true
	return false


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


func _pulse_rejuvenation(dealt: float) -> void:
	if is_dead or dealt <= 0.0:
		return
	var amt := dealt * CombatBalance.pct("rejuvenation.pulse")
	if amt < 1.0:
		return
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != team:
			continue
		if u.global_position.distance_to(global_position) > 8.5 + u.radius:
			continue
		u.apply_heal(amt, self, "nature")
		u.apply_rejuvenation(self)


func apply_burn(source: Unit, hit_damage: float) -> void:
	var add := hit_damage * CombatBalance.pct("burn.ratio")
	if add <= 0.0:
		return
	_burn_layers.append({
		"remaining": add,
		"time_left": BURN_DURATION,
		"dps": add / BURN_DURATION,
		"source": source,
	})
	_mark_fire = maxf(_mark_fire, BURN_DURATION)


func apply_afflict(source: Unit) -> void:
	apply_afflict_stacks(source, 1)


func apply_afflict_stacks(source: Unit, stacks: int) -> void:
	if is_dead or stacks <= 0:
		return
	_afflict_stacks = mini(AFFLICT_STACK_MAX, _afflict_stacks + stacks)
	_afflict_left = AFFLICT_DURATION
	if source != null and is_instance_valid(source):
		_afflict_src = source


func apply_rejuvenation(source: Unit) -> void:
	if is_dead:
		return
	_rejuv_stacks = mini(REJUV_STACK_MAX, _rejuv_stacks + 1)
	_rejuv_left = REJUV_DURATION
	if source != null and is_instance_valid(source):
		_rejuv_src = source


func apply_holy_blessing(base_power: float) -> void:
	if is_dead or base_power <= 0.0:
		return
	var add := (base_power / BLESSING_REF) * BLESSING_MAX
	if add <= 0.0:
		return
	if _blessing_left <= 0.05:
		_blessing_dr = 0.0
	_blessing_dr = minf(BLESSING_MAX, _blessing_dr + add)
	_blessing_left = maxf(_blessing_left, BLESSING_TIME)
	_blessing_max = maxf(_blessing_max, BLESSING_TIME)


func apply_chill(ability_damage: float, source: Unit = null) -> void:
	if ability_damage <= 0.0:
		return
	_chill_percent = minf(1.0, _chill_percent + ability_damage * CHILL_PER_DAMAGE)
	_chill_left = MARK_TIME
	_mark_ice = MARK_TIME
	_try_chill_freeze(source)


func apply_shock(_source: Unit = null) -> void:
	_charged_stacks = mini(SHOCK_MAX, _charged_stacks + 1)
	_mark_storm = SHOCK_TIME


func _shock_chain_ratio() -> float:
	if _charged_stacks <= 0:
		return 0.0
	return CombatBalance.pct("shock.chain") * (float(_charged_stacks) / float(SHOCK_MAX))


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
	if frame != _shock_batch_frame:
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
	for _i in SHOCK_CHAIN_HOPS:
		var nxt := source._chain_bounce_target(current, visited, SHOCK_CHAIN_RANGE, false)
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
		var dmg := bounce * CombatBalance.chain_hop_mult(i)
		if dmg < 1.0:
			continue
		u.take_damage(dmg, source, _DamageNumber.tint_for("lightning"), "lightning", "shock_chain", false, false, -1, true)


func outgoing_damage_mult(ability_id: String, hit_kind: String) -> float:
	return UnitAltered.outgoing_damage_mult(self, ability_id, hit_kind)


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
	_wind_kb_left = 0.0
	_wind_air_left = 0.0
	_wind_air_rise = 0.0
	_wind_ray_left = 0.0
	_wind_ray_from = null
	_wind_carry = null
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
	if heal_amount > 0.05:
		var crit := source.roll_ability_crit(ab) if source and not combat_text_periodic else false
		var healed := SpellPower.packet(heal_amount, ab, extras, null, true, ability_id, crit, primary)
		split = _DamageNumber.split_for_heal(ab, extras, ability_id, crit, primary, heal_amount, healed)
		var kind := _DamageNumber.kind_for_element(primary, combat_text_periodic) if primary != AbilityDef.Element.NONE else "heal"
		apply_heal(healed, source, ability_id, split, combat_text_cast_id, combat_text_periodic, crit, kind)
		if blessing_power > 0.05:
			apply_holy_blessing(blessing_power)
	if rejuvenate:
		apply_rejuvenation(source)
	if shield_amount > 0.05:
		var dur := shield_duration if shield_duration > 0.05 else PROTECTION_SHIELD_TIME
		var amt := SpellPower.packet(shield_amount, ab, extras, null, true, ability_id, false, primary, "shield")
		apply_shield(amt, dur, source, SpellPower.elements_for(ab, extras, primary), combat_text_cast_id)
		UnitWind.apply_shield_haste(self, ab, dur)


func remaining_burn() -> float:
	var total := 0.0
	for layer in _burn_layers:
		total += float(layer.get("remaining", 0.0))
	return maxf(0.0, total)


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
	_chill_percent = 0.0
	_chill_left = 0.0
	_freeze_immune_left = maxf(_freeze_immune_left, FREEZE_IMMUNE_TIME)
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


func consume_elemental_marks() -> float:
	var n := elemental_mark_count()
	_clear_marks()
	if n <= 0:
		return 35.0
	if n == 1:
		return 75.0
	if n == 2:
		return 170.0
	return 300.0


func die() -> void:
	if is_dead:
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
	_chill_percent = 0.0
	_chill_left = 0.0
	_freeze_immune_left = 0.0
	_blessing_dr = 0.0
	_blessing_left = 0.0
	_blessing_max = 0.0
	_clear_recast()
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
		target.take_damage(attack_damage, self, _DamageNumber.tint_for("physical"), "physical", "auto")
		AudioManager.play_at("melee.hit", target.global_position + Vector3(0.0, 1.0, 0.0))
		if attack_applies_charged:
			target._apply_mark(AbilityDef.Element.STORM, self)
		return
	var origin := auto_attack_origin()
	Projectile.spawn(self, origin, {
		"homing": target,
		"speed": attack_projectile_speed,
		"damage": attack_damage,
		"radius": 0.14,
		"max_distance": 24.0,
		"color": Color(1.0, 0.5, 0.12),
		"skillshot": false,
		"vfx_scene": attack_vfx_scene,
		"vfx_scale": attack_vfx_scale,
		"vfx_yaw": attack_vfx_yaw,
		"grant_charged": attack_applies_charged,
		"ability_id": "auto",
	})


func can_attack_ally() -> bool:
	return attack_shield > 0.05


func _restore_auto_mana() -> void:
	if attack_mana_restore > 0.05:
		restore_mana(attack_mana_restore)


func _fire_ally_auto(target: Unit) -> void:
	if not can_attack_ally() or target == null or target.is_dead:
		return
	var dur := attack_shield_duration if attack_shield_duration > 0.05 else WARD_TIME
	if is_melee:
		target.apply_shield(attack_shield, dur, self)
		AudioManager.play_at("auto.hit", target.global_position + Vector3(0.0, 1.0, 0.0))
		return
	var origin := auto_attack_origin()
	Projectile.spawn(self, origin, {
		"homing": target,
		"speed": attack_projectile_speed,
		"damage": 0.0,
		"shield": attack_shield,
		"shield_duration": dur,
		"radius": 0.14,
		"max_distance": 24.0,
		"color": Color(0.95, 0.88, 0.45),
		"skillshot": false,
		"vfx_scene": attack_vfx_scene,
		"vfx_scale": attack_vfx_scale,
		"vfx_yaw": attack_vfx_yaw,
		"vfx_primary": Color(1.0, 0.94, 0.55),
		"vfx_secondary": Color(0.95, 0.78, 0.28),
		"vfx_tertiary": Color(1.0, 0.98, 0.8),
		"ability_id": "auto",
	})


func cast_ability(index: int, point: Vector3, target: Unit = null) -> void:
	if not can_prepare_cast(index):
		return
	var ab := abilities[index]
	var recast := has_recast_ready(index)
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
	var ally := target if target != null and is_instance_valid(target) and not target.is_dead and target.team == team and ab.can_target_allies() else null
	if ally != null and not ab.pierces_skillshot() and ab.target_mode == AbilityDef.TargetMode.UNIT:
		_play_ability_fx(ab, ally.global_position + Vector3(0, 1.0, 0))
		_apply_ally_and_self(ally, ab)
		return
	if ally != null and ally == self and ab.target_mode == AbilityDef.TargetMode.SKILLSHOT and not ab.pierces_skillshot():
		_apply_ally_and_self(ally, ab)
		return
	match ab.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
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
				else:
					target.receive_ability_hit(self, ab.element, _scaled(ab.damage), 0.0, extras, false, true, true, ice_id, double_mask, ab.combat_id(), combat_text_cast_id)
					if ab.slow_duration > 0.0:
						target.apply_slow(ab.slow_percent, ab.slow_duration)
					UnitWind.apply_on_target(target, ab, self)
		AbilityDef.TargetMode.GROUND:
			if ab.delivery == AbilityDef.Delivery.METEOR:
				_drop_meteors(point, ab, _scaled(ab.damage), ab.aoe_radius, extras, ice_id, double_mask, 1.0, combat_text_cast_id)
			elif ab.delivery == AbilityDef.Delivery.WALL:
				_place_spell_wall(point, ab, extras, ice_id, double_mask, combat_text_cast_id, slot)
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
				_ground_burst(point, ab, -1.0, -1.0, extras, ice_id, double_mask, 2.0, combat_text_cast_id)
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
				_ground_burst(global_position, ab, -1.0, -1.0, extras, ice_id, double_mask, 2.0, combat_text_cast_id)
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
	if recast:
		_clear_recast()
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
		var combust_mult := lerpf(1.0, 2.0, clampf(charge, 0.0, 1.0))
		_drop_meteors(point, ab, dmg, rad, extras, ice_id, double_mask, combust_mult, combat_text_cast_id)
		end_channel_cast(index)
		return
	_ground_burst(point, ab, dmg, rad, extras, ice_id, double_mask, 2.0, combat_text_cast_id)
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


func _chain_bounce_target(from: Unit, visited: Dictionary, bounce_range: float, check_los: bool = true) -> Unit:
	if from == null or not is_instance_valid(from):
		return null
	var range_sq := bounce_range * bounce_range
	var origin := from.global_position
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
	if victim.is_stunned():
		AudioManager.play_at("reaction.shatter", hit_at)
	var raw := damage_override if damage_override >= 0.0 else _scaled(ab.damage)
	raw *= CombatBalance.chain_hop_mult(hop)
	victim.receive_ability_hit(self, ab.element, raw, 0.0, extras, false, true, allow_reactions, overheat_cast_id, infusion_double, ab.combat_id(), combat_text_cast_id, combat_text_periodic or hop > 0)
	if ab.slow_duration > 0.0:
		victim.apply_slow(ab.slow_percent, ab.slow_duration)


func _spawn_skillshot_fan(dir: Vector3, point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	var count := maxi(ab.projectile_count, 1)
	var spread := deg_to_rad(8.0)
	var start := -spread * 0.5 * float(count - 1)
	for i in count:
		var shot_dir := dir.rotated(Vector3.UP, start + spread * float(i))
		_spawn_skillshot(shot_dir, point, ab, extras, ice_id, double_mask, combat_text_cast_id)
	for extra_dir in UnitIllusion.extra_shot_dirs(ab, dir):
		_spawn_skillshot(extra_dir, point, ab, extras, ice_id, double_mask, combat_text_cast_id)


func _spawn_skillshot(dir: Vector3, point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1) -> void:
	var max_d := ab.skillshot_length if ab.skillshot_length > 0.05 else ab.range
	max_d = wall_travel_distance(dir, max_d, false)
	var travel := max_d
	if ab.splash_radius > 0.05:
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
		"vfx_scene": ab.vfx_scene,
		"vfx_scale": ab.vfx_scale,
		"vfx_primary": ab.vfx_primary,
		"vfx_secondary": ab.vfx_secondary,
		"vfx_tertiary": ab.vfx_tertiary,
		"vfx_yaw": ab.vfx_yaw,
		"vfx_layers": ab.vfx_layers,
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
		"hit_cooldown_reduction": ab.hit_cooldown_reduction,
		"holy_pulse_ratio": ab.holy_pulse_ratio,
		"pierce": ab.delivery == AbilityDef.Delivery.WAVE,
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
		"vfx_scene": ab.vfx_scene,
		"vfx_scale": ab.vfx_scale,
		"vfx_primary": ab.vfx_primary,
		"vfx_secondary": ab.vfx_secondary,
		"vfx_tertiary": ab.vfx_tertiary,
		"vfx_yaw": ab.vfx_yaw,
		"vfx_layers": ab.vfx_layers,
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
	var length := ab.range if ab.range > 0.05 else ab.skillshot_length
	var half := ab.cone_angle * 0.5
	_IceBlastFx.spawn(global_position, dir, length, ab.cone_angle, cone_wall_lengths(dir, ab.cone_angle, length))
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_structure:
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
	var played := false
	if ab.vfx_scene != "":
		var cfg := ab.vfx_cfg()
		if look.length_squared() > 0.0001:
			cfg["look"] = look
		if AbilityFx.play_at(ab.vfx_scene, pos, cfg):
			played = true
	SpellVfx.play_impact(pos, {"vfx_layers": ab.vfx_layers})
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
	SpellVfx.play_impact(Vector3(point.x, 0.35, point.z), {"vfx_layers": ab.vfx_layers})


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


func _place_spell_wall(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, combat_text_cast_id: int = -1, slot: int = -1) -> void:
	if SpellWallLayout.style_id(ab) == "illusion":
		if slot >= 0:
			_illusion_wall_slot = slot
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


func _fire_ray_tick(index: int, ab: AbilityDef, target: Unit) -> bool:
	if not ab.accepts_unit(team, target):
		return false
	spend_mana(index)
	if _spell_ray == null or not is_instance_valid(_spell_ray):
		_spell_ray = _SpellRay.attach(self, target, ab.vfx_primary if ab.vfx_primary.a > 0.02 else ab.color)
	elif _spell_ray.get("target") != null:
		_spell_ray.set("target", target)
	var extras := _cast_extras(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	var dmg := _scaled(ab.damage if ab.damage > 0.05 else ab.tick_damage)
	if target.team == team:
		_apply_ally_spell(target, ab, true, false)
		if target != self:
			apply_altered_from(ab, false)
	else:
		target.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, ice_id, _infusion_double_mask(), ab.combat_id(), _channel_combat_text_cast_id)
		if UnitWind.has_wind(ab) and not UnitIllusion.has_illusion(ab):
			UnitWind.start_ray_push(target, self)
		_illusion_ray_bounces(target, ab, extras, ice_id, dmg, _channel_combat_text_cast_id)
	if ab.echo and not _channel_was_recast:
		var target_id := target.get_instance_id() if target != null and is_instance_valid(target) else 0
		var tw := create_tween()
		tw.tween_interval(0.1)
		tw.tween_callback(_finish_ray_echo.bind(target_id, ab, extras, ice_id, _channel_combat_text_cast_id))
	return true


func _finish_ray_echo(target_id: int, echo_ab: AbilityDef, echo_extras: PackedInt32Array, echo_ice: int, echo_combat_text_cast_id: int) -> void:
	if is_dead or echo_ab == null:
		return
	var echo_target := instance_from_id(target_id) as Unit if target_id != 0 else null
	if echo_target == null or not is_instance_valid(echo_target) or echo_target.is_dead:
		return
	var saved := _cast_power
	_cast_power = echo_ab.echo_damage_mult
	var echo_dmg := _scaled(echo_ab.damage if echo_ab.damage > 0.05 else echo_ab.tick_damage)
	if echo_target.team == team:
		_apply_ally_spell(echo_target, echo_ab, true, false)
		if echo_target != self:
			apply_altered_from(echo_ab, false)
	else:
		echo_target.receive_ability_hit(self, echo_ab.element, echo_dmg, 0.0, echo_extras, false, true, true, echo_ice, _infusion_double_mask(), echo_ab.combat_id(), echo_combat_text_cast_id)
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
		out.append(0.55)
		return out
	for i in count:
		out.append(lerpf(1.15, -0.28, float(i) / float(count - 1)))
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
	var arc_min := CombatBalance.flat("missiles.arc.min")
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
		var yaw := side * 0.95
		var launch := toward.rotated(Vector3.UP, yaw)
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
			"vfx_scene": ab.vfx_scene,
			"vfx_scale": ab.vfx_scale,
			"vfx_primary": ab.vfx_primary,
			"vfx_secondary": ab.vfx_secondary,
			"vfx_tertiary": ab.vfx_tertiary,
			"vfx_yaw": ab.vfx_yaw,
			"vfx_layers": ab.vfx_layers,
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
			"arc_min": arc_min,
		})


func fire_channel_tick(index: int, target: Unit) -> bool:
	if index < 0 or index >= abilities.size():
		return false
	var ab := abilities[index]
	if target == null or not is_instance_valid(target) or target.is_dead:
		return false
	if not ab.accepts_unit(team, target):
		return false
	if not GameSession.has_infinite_mana() and mana < mana_cost_for(index):
		return false
	if ab.delivery == AbilityDef.Delivery.RAY:
		return _fire_ray_tick(index, ab, target)
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


func _ground_burst(point: Vector3, ab: AbilityDef, damage_override: float = -1.0, radius_override: float = -1.0, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combust_mult: float = 2.0, combat_text_cast_id: int = -1) -> void:
	var dmg := _scaled(ab.damage) if damage_override < 0.0 else damage_override
	var rad := ab.aoe_radius if radius_override < 0.0 else radius_override
	var is_burst := ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION or ab.id == "aoe_explosion"
	var is_nova := ab.delivery == AbilityDef.Delivery.NOVA
	if is_burst:
		_GroundBlast.play(point, rad, ab)
	elif not is_nova:
		if ab.vfx_scene != "":
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
	for u in ArenaState.units:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_structure:
			continue
		if u.hit_distance_to(point) > rad:
			continue
		if not _burst_has_los(point, u.global_position):
			continue
		if u.team == team:
			_apply_area_ally(u, ab)
			continue
		if ab.id == "meteor":
			u._combust(self, combust_mult)
		u.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, overheat_cast_id, infusion_double, ab.combat_id(), combat_text_cast_id)
		if ab.slow_duration > 0.0:
			u.apply_slow(ab.slow_percent, ab.slow_duration)
		UnitWind.apply_on_burst(u, ab, point)
	SpellWall.apply_radius_hit(self, point, rad, dmg, "hit", Color(0, 0, 0, 0), combat_text_cast_id, true)


func _drop_meteors(point: Vector3, ab: AbilityDef, dmg: float, rad: float, extras: PackedInt32Array, ice_id: int, double_mask: int, combust_mult: float, combat_text_cast_id: int = -1) -> void:
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
			_drop_one_meteor(at, ab, dmg * keep, rad, extras, ice_id, double_mask, combust_mult, combat_text_cast_id)
		else:
			get_tree().create_timer(wait).timeout.connect(_drop_one_meteor.bind(at, ab, dmg * keep, rad, extras, ice_id, double_mask, combust_mult, combat_text_cast_id))


func _drop_one_meteor(point: Vector3, ab: AbilityDef, dmg: float, rad: float, extras: PackedInt32Array, ice_id: int, double_mask: int, combust_mult: float, combat_text_cast_id: int = -1) -> void:
	if is_dead:
		return
	_MeteorFx.drop(self, point, ab, dmg, rad, extras, ice_id, double_mask, combust_mult, combat_text_cast_id)


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
	_ground_burst(point, ab, damage_override, echo_rad, extras, ice_id, double_mask, 2.0, combat_text_cast_id)
	_illusion_echoing = false


func _illusion_ray_bounces(primary: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, dmg: float, combat_text_cast_id: int = -1) -> void:
	if not UnitIllusion.has_illusion(ab) or primary == null:
		_clear_illusion_rays()
		return
	var hops := maxi(int(round(CombatBalance.flat("illusion.ray.hops"))), 1)
	var bounce_range := CombatBalance.flat("illusion.ray.range")
	var visited: Dictionary = {primary: true}
	var current := primary
	var chain: Array[Unit] = []
	for _i in hops:
		var nxt := _chain_bounce_target(current, visited, bounce_range)
		if nxt == null:
			break
		visited[nxt] = true
		chain.append(nxt)
		current = nxt
	_sync_illusion_rays(primary, chain, ab)
	var origin := Vector3.ZERO
	if UnitWind.has_wind(ab):
		var pack: Array = [primary]
		for hop in chain:
			pack.append(hop)
		origin = UnitIllusion.cluster_center(pack)
		UnitIllusion.scatter_from(primary, origin)
	if chain.is_empty():
		return
	var double_mask := _infusion_double_mask()
	var fallback := facing_dir()
	for i in chain.size():
		var hop := chain[i]
		var delay := ab.bounce_delay * float(i + 1)
		if delay <= 0.001:
			_apply_illusion_ray_hop(hop, ab, extras, ice_id, double_mask, dmg, origin, fallback, combat_text_cast_id)
		else:
			get_tree().create_timer(delay).timeout.connect(_apply_illusion_ray_hop.bind(hop, ab, extras, ice_id, double_mask, dmg, origin, fallback, combat_text_cast_id))


func _sync_illusion_rays(primary: Unit, chain: Array[Unit], ab: AbilityDef) -> void:
	var tint: Color = ab.vfx_primary if ab.vfx_primary.a > 0.02 else ab.color
	while _illusion_rays.size() > chain.size():
		var old = _illusion_rays.pop_back()
		if old != null and is_instance_valid(old):
			old.queue_free()
	var prev := primary
	for i in chain.size():
		var hop := chain[i]
		if i < _illusion_rays.size() and _illusion_rays[i] != null and is_instance_valid(_illusion_rays[i]):
			var ray = _illusion_rays[i]
			ray.source = prev
			ray.target = hop
		else:
			if i < _illusion_rays.size():
				_illusion_rays[i] = _SpellRay.attach(prev, hop, tint)
			else:
				_illusion_rays.append(_SpellRay.attach(prev, hop, tint))
		prev = hop


func _clear_illusion_rays() -> void:
	for ray in _illusion_rays:
		if ray != null and is_instance_valid(ray):
			ray.queue_free()
	_illusion_rays.clear()


func _apply_illusion_ray_hop(hop: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, dmg: float, origin: Vector3 = Vector3.ZERO, fallback: Vector3 = Vector3.ZERO, combat_text_cast_id: int = -1) -> void:
	if hop == null or not is_instance_valid(hop) or hop.is_dead:
		return
	hop.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, ice_id, double_mask, ab.combat_id(), combat_text_cast_id)
	if UnitWind.has_wind(ab):
		UnitIllusion.scatter_from(hop, origin, fallback)


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
		if _freeze_immune_left <= 0.0 and _chill_percent >= CHILL_FREEZE_AT:
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
			_refresh_freeze_visual()
	if _pending_freeze:
		flush_pending_freeze()
	if is_dead:
		return
	_tick_altered(delta)
	_tick_burn(delta)
	_tick_combust(delta)
	_tick_afflict(delta)
	_tick_rejuv(delta)
	_mark_ice = maxf(0.0, _mark_ice - delta)
	_chill_left = maxf(0.0, _chill_left - delta)
	if _chill_left <= 0.0:
		_chill_percent = 0.0
	_mark_storm = maxf(0.0, _mark_storm - delta)
	if _mark_storm <= 0.0:
		_charged_stacks = 0
	if not (_mark_fire > 0.0 and _mark_ice > 0.0 and _mark_storm > 0.0):
		_had_triple = false


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


func _clear_rejuv() -> void:
	_rejuv_stacks = 0
	_rejuv_left = 0.0
	_rejuv_acc = 0.0
	_rejuv_src = null


func _rejuv_hps() -> float:
	return CombatBalance.flat("rejuvenation.hps")


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


func _tick_afflict(delta: float) -> void:
	if _afflict_stacks <= 0:
		_afflict_acc = 0.0
		return
	_afflict_left = maxf(0.0, _afflict_left - delta)
	_afflict_acc += delta
	var per_stack := CombatBalance.flat("afflict.tick")
	while _afflict_acc >= AFFLICT_TICK and _afflict_stacks > 0 and not is_dead:
		_afflict_acc -= AFFLICT_TICK
		var amount := per_stack * float(_afflict_stacks) * AFFLICT_TICK
		if amount > 0.02:
			var src: Unit = _afflict_src if _afflict_src != null and is_instance_valid(_afflict_src) else null
			take_damage(amount, src, _DamageNumber.tint_for("afflicted"), "afflicted", "afflicted", false, false, -1, true)
	if _afflict_left <= 0.02 or _afflict_stacks <= 0:
		_clear_afflict()


func _clear_combust() -> void:
	_combust_tick = 0.0
	_combust_left = 0.0
	_combust_max = 0.0
	_combust_acc = 0.0
	_combust_hits_left = 0
	_combust_src = null


func _tick_combust(delta: float) -> void:
	if _combust_hits_left <= 0 or _combust_tick <= 0.0:
		return
	_combust_acc += delta
	_combust_left = maxf(0.0, float(_combust_hits_left) * COMBUST_TICK - _combust_acc)
	var src = _combust_src
	if not is_instance_valid(src):
		src = null
		_combust_src = null
	while _combust_acc >= COMBUST_TICK and _combust_hits_left > 0:
		_combust_acc -= COMBUST_TICK
		_combust_hits_left -= 1
		take_damage(_combust_tick, src, _DamageNumber.tint_for("combust"), "combust", "combust", false, false, -1, true)
		if is_dead:
			_clear_combust()
			return
	if _combust_hits_left <= 0:
		_clear_combust()


func _apply_mark(kind: int, _source: Unit, _stack_storm: bool = true, _stack_chill: bool = true, _infusion_double: int = 0, _can_freeze: bool = false) -> void:
	if kind == AbilityDef.Element.FIRE:
		_mark_fire = maxf(_mark_fire, BURN_DURATION)
	elif kind == AbilityDef.Element.ICE:
		_mark_ice = MARK_TIME
	elif kind == AbilityDef.Element.STORM:
		_mark_storm = SHOCK_TIME


func _try_chill_freeze(source: Unit = null) -> void:
	if _chill_percent < CHILL_FREEZE_AT:
		return
	if apply_freeze(source):
		_reaction_flash(Color(0.7, 0.92, 1.0), 0.95)


func _clear_marks() -> void:
	_clear_burn()
	_clear_combust()
	_clear_afflict()
	_clear_rejuv()
	_mark_ice = 0.0
	_chill_percent = 0.0
	_chill_left = 0.0
	_mark_storm = 0.0
	_charged_stacks = 0
	_had_triple = false


func _combust(source: Unit, mult: float = 2.0) -> void:
	var leftover := remaining_burn()
	if leftover <= 0.0:
		return
	_clear_burn()
	var tick := leftover * maxf(mult, 0.0) / COMBUST_DIVISOR
	if tick <= 0.02:
		return
	_combust_tick = tick
	_combust_left = COMBUST_DURATION
	_combust_max = COMBUST_DURATION
	_combust_acc = 0.0
	_combust_hits_left = COMBUST_TICKS
	_combust_src = source
	_reaction_flash(Color(1.0, 0.45, 0.12), 1.0)
	AbilityFx.play_at(AbilityFx.FIRE_CAST, global_position + Vector3(0.0, height * 0.2, 0.0), {
		"scale": 0.9,
		"lifetime": 0.9,
		"primary_color": Color(1.0, 0.45, 0.12),
		"secondary_color": Color(1.0, 0.22, 0.05),
	})
	AudioManager.play_at("reaction.combust", global_position + Vector3(0.0, height * 0.2, 0.0))


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
