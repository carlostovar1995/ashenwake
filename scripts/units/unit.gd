class_name Unit
extends CharacterBody3D

const _IceBlastFx := preload("res://scripts/visual/ice_blast_fx.gd")
const _ThunderWaveFx := preload("res://scripts/visual/thunder_wave_fx.gd")
const _ChilledGround := preload("res://scripts/visual/chilled_ground_fx.gd")
const _Sanctuary := preload("res://scripts/visual/sanctuary_fx.gd")
const _MeteorFx := preload("res://scripts/visual/meteor_fx.gd")
const _MarkPipShader := preload("res://scripts/visual/mark_pip.gdshader")
const _HoverFrameShader := preload("res://scripts/visual/hover_frame.gdshader")
const EnemyNameplate := preload("res://scripts/ui/enemy_nameplate.gd")
const ClassCatalog := preload("res://scripts/classes/class_catalog.gd")

signal died(unit)
signal damaged(unit, amount, source, spell_id)
signal healed(unit, amount, source, spell_id)

const TEAM_RAID := 0
const TEAM_BOSS := 1
const MARK_TIME := 5.0
const BURN_RATIO := 1.0
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
const CHARGED_AMP := 0.04
const CHARGED_MAX := 6
const CHARGED_TIME := 10.0
const CHARGED_MANA_DIV := 4.0
const CHILL_MAX := 6
const CHILL_FREEZE_AT := 6
const CHILL_SLOW_BOSS := 0.03
const CHILL_SLOW_ADD := 0.06
const OVERHEAT_CD_REFUND := 3.0
const OVERHEAT_CD_REFUND_CAP := 4
const INFUSION_DOUBLE_FIRE := 1
const INFUSION_DOUBLE_ICE := 2
const INFUSION_DOUBLE_STORM := 4
const COMBUST_RADIUS := 2.8
const SHATTER_BONUS := 45.0
const CATACLYSM_BONUS := 80.0
const WARD_TIME := 3.2
const SHIELD_MOVE_SPEED := 0.15
const FREEZE_BOSS := 3.5
const FREEZE_ADD := 5.0
const LOCAL_OUTLINE_WIDTH := 0.020
const LOCAL_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const _DodgeClockShader := preload("res://scripts/visual/dodge_clock.gdshader")

@export var unit_name: String = "Champion"
@export var team: int = TEAM_RAID
@export var is_champion: bool = false
@export var is_boss: bool = false
@export var body_color: Color = Color(0.28, 0.55, 0.95)
@export var radius: float = 0.45
@export var height: float = 1.8

@export var max_health: float = 650.0
@export var max_mana: float = 400.0
@export var mana_regen: float = 10.0
@export var move_speed: float = 7.2
@export var turn_rate: float = 9.5
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
@export var attack_vfx_scene: String = ""
@export var attack_vfx_scale: float = 0.3
@export var attack_vfx_yaw: float = 0.0
@export var attack_applies_charged: bool = false
var atonement_ratio: float = 0.0
var attack_shield: float = 0.0
var attack_shield_duration: float = 0.0
var attack_mana_restore: float = 0.0

var health: float
var mana: float
var is_dead: bool = false
var ai_enabled: bool = false

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
var _chilled_stacks: int = 0
var _burn_layers: Array[Dictionary] = []
var _burn_acc: float = 0.0
var _combust_tick: float = 0.0
var _combust_left: float = 0.0
var _combust_max: float = 0.0
var _combust_acc: float = 0.0
var _combust_hits_left: int = 0
var _combust_src: Unit
var _ward_left: float = 0.0
var _ward_time: float = 0.0
var _had_triple: bool = false
var _mark_pips: Array[Sprite3D] = []
var _mark_pip_mats: Array[ShaderMaterial] = []
static var _mark_pip_tex: Texture2D
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
var _chilled_zone: Node
var _stun_left: float = 0.0
var _stun_max: float = 0.0
var _pending_freeze: bool = false
var _pending_freeze_source: Unit
var _overcharge_sfx: int = 0
var _free_casts: int = 0
var _free_cast_max: int = 0
var _free_cast_pips: Array[Sprite3D] = []
var _atonement_amp: float = 0.0
var _ward_source: Unit
var _sanctuary_zone: Node


func _ready() -> void:
	health = max_health
	mana = max_mana
	add_to_group("units")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	_ensure_body()
	if not visual_path.is_empty():
		CharacterCatalog.attach(self, visual_path, visual_scale, visual_yaw, visual_y_offset, visual_pitch)
	if abilities.is_empty():
		_setup_default_abilities()
	while cooldown_left.size() < abilities.size():
		cooldown_left.append(0.0)
	while _cooldown_max.size() < cooldown_left.size():
		_cooldown_max.append(0.0)
	ArenaState.register_unit(self)
	set_physics_process(true)


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


func set_ai_enabled(enabled: bool) -> void:
	ai_enabled = enabled
	for child in get_children():
		if child is AllyAI or child is BossAI or child is AddAI:
			child.set_process(enabled)
			child.set_physics_process(enabled)


func _ensure_body() -> void:
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

	_bar_width = 2.08
	var overhead_hp := not _uses_feet_bars()
	_hp_bar_y = 0.0
	_bar_thick = 0.28
	if overhead_hp:
		_bar_bg = _make_bar_trough(_hp_root, "HpBg", _hp_bar_y, _bar_thick)
		_bar = _make_bar_fill(_hp_root, "Hp", _hp_bar_y, _bar_thick, _hp_fill_color())
		_shield_bar = _make_bar_fill(_hp_root, "Shield", _hp_bar_y, _bar_thick, _shield_fill_color())
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
	if team == TEAM_BOSS:
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
	_make_mark_pips()
	_make_hover_frames()
	_make_free_cast_pips()


func _physics_process(delta: float) -> void:
	var overcharge_cooldown_rate := _overcharge_cooldown_rate if _overcharge_left > 0.0 else 1.0
	if _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - delta)
		if _slow_left <= 0.0:
			_slow_percent = 0.0
			_slow_max = 0.0
	if _haste_left > 0.0:
		_haste_left = maxf(0.0, _haste_left - delta)
		if _haste_left <= 0.0:
			_haste_percent = 0.0
			_haste_max = 0.0
	if _dr_left > 0.0:
		_dr_left = maxf(0.0, _dr_left - delta)
		if _dr_left <= 0.0:
			_dr_percent = 0.0
			_dr_max = 0.0
	_tick_elemental(delta)
	if not is_dead:
		mana = max_mana if GameSession.has_infinite_mana() else minf(max_mana, mana + mana_regen * delta)
		global_cooldown_left = maxf(0.0, global_cooldown_left - delta)
		dodge_cooldown_left = maxf(0.0, dodge_cooldown_left - delta)
		if immortal:
			health = minf(max_health, health + max_health * 0.08 * delta)
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


func _uses_feet_bars() -> bool:
	return team == TEAM_RAID


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
	fill.scale = Vector3(maxf(w, 0.001), 1.0, 1.0)
	fill.position = Vector3(_bar_width * (start_ratio + w * 0.5 - 0.5), y, z)


func _update_hp_bar() -> void:
	if _hp_root:
		_hp_root.global_transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, height + 0.62, 0))
	if _feet_root:
		_face_camera(_feet_root, _feet_bar_world())
	if _bar == null and _nameplate == null:
		return
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
		_refresh_mark_pips()
		_refresh_free_cast_pips()
		return
	if _bar_bg:
		_bar_bg.visible = not is_dead
	var hp := 0.0 if is_dead else health
	var sh := 0.0 if is_dead else shield_amount()
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
	_refresh_dodge_clock()
	_refresh_name_highlight()
	_refresh_hover_frames()
	_refresh_mark_pips()
	_refresh_free_cast_pips()


func current_move_speed() -> float:
	if is_stunned():
		return 0.0
	var spd := move_speed * MOVE_SPEED_SCALE
	if _haste_left > 0.0:
		spd *= 1.0 + _haste_percent
	if _ward_left > 0.05 and _ward_time > 0.05:
		spd *= 1.0 + SHIELD_MOVE_SPEED
	if _slow_left > 0.0:
		spd *= 1.0 - _slow_percent
	return spd


func apply_slow(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_slow_percent = maxf(_slow_percent, percent) if _slow_left > 0.0 else percent
	_slow_left = maxf(_slow_left, duration)
	_slow_max = maxf(_slow_max, duration)


func apply_haste(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_haste_percent = maxf(_haste_percent, percent) if _haste_left > 0.0 else percent
	_haste_left = maxf(_haste_left, duration)
	_haste_max = maxf(_haste_max, duration)


func apply_damage_reduction(percent: float, duration: float) -> void:
	if percent <= 0.0 or duration <= 0.0:
		return
	_dr_percent = maxf(_dr_percent, percent) if _dr_left > 0.0 else percent
	_dr_left = maxf(_dr_left, duration)
	_dr_max = maxf(_dr_max, duration)


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


func in_range_of(target: Node3D, extra: float = 0.0) -> bool:
	if target == null:
		return false
	var reach := attack_range + radius + float(target.get("radius")) + extra
	return global_position.distance_to(target.global_position) <= reach


func ability_in_range(ability: AbilityDef, point: Vector3) -> bool:
	if ability.target_mode == AbilityDef.TargetMode.SKILLSHOT or ability.target_mode == AbilityDef.TargetMode.INSTANT:
		return true
	return global_position.distance_to(point) <= ability.range + 0.35


func can_cast(index: int) -> bool:
	if not can_prepare_cast(index):
		return false
	return not is_on_global_cooldown(index)


func can_prepare_cast(index: int) -> bool:
	if is_dead or is_stunned() or index < 0 or index >= abilities.size():
		return false
	if not GameSession.ignores_cooldowns() and cooldown_left[index] > 0.0:
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
			return "storm"
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
			return "Storm Infused"
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
				name = "Storm Infused"
				icon = "storm_infused"
				color = Color(0.55, 0.62, 1.0)
				desc = "Your next spell also Charges."
		out.append({
			"id": "infusion",
			"icon": icon,
			"name": name,
			"color": color,
			"time_left": 0.0,
			"duration": 0.0,
			"description": desc,
		})
	if _ward_left > 0.05 and _ward_time > 0.05:
		out.append({
			"id": "ward",
			"icon": "ward",
			"name": "Shield",
			"color": Color(0.84, 0.88, 0.96),
			"time_left": _ward_time,
			"duration": maxf(_ward_max, _ward_time),
			"description": "Absorbs incoming damage.\n15% move speed.",
		})
	if _haste_left > 0.05:
		out.append({
			"id": "frost_path",
			"icon": "chilled_ground",
			"name": "Icy Path",
			"color": Color(0.55, 0.88, 1.0),
			"time_left": 0.0,
			"duration": 0.0,
			"description": "Moving faster on the ice.",
		})
	if _dr_left > 0.05:
		out.append({
			"id": "sanctuary_dr",
			"icon": "sanctuary",
			"name": "Sanctuary",
			"color": Color(0.95, 0.84, 0.38),
			"time_left": 0.0,
			"duration": 0.0,
			"description": "Take 25% less damage.",
		})
	if not _burn_layers.is_empty():
		out.append(_burn_status_entry())
	if _combust_left > 0.05:
		out.append(_combust_status_entry())
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
	if _mark_ice > 0.05 and _chilled_stacks > 0:
		out.append({
			"id": "chilled",
			"icon": "chilled",
			"name": "Chilled",
			"color": Color(0.45, 0.82, 1.0),
			"time_left": _mark_ice,
			"duration": MARK_TIME,
			"stacks": _chilled_stacks,
			"description": "Slowed. Freeze consumes this to stun (%ss boss / %ss add)." % [str(FREEZE_BOSS), str(FREEZE_ADD)],
		})
	if _mark_storm > 0.05 and _charged_stacks > 0:
		out.append({
			"id": "charged",
			"icon": "charged",
			"name": "Charged",
			"color": Color(0.95, 0.88, 0.35),
			"time_left": _mark_storm,
			"duration": CHARGED_TIME,
			"stacks": _charged_stacks,
			"description": "Takes more Fire and Ice damage. Hits refund mana.",
		})
	return out


func collect_nameplate_debuffs() -> Array[Dictionary]:
	var kit = ClassCatalog.get_by_id(GameSession.selected_class_id)
	var want: PackedStringArray = kit.nameplate_debuffs if kit else PackedStringArray()
	if want.is_empty():
		want = PackedStringArray(["charged", "chilled", "frozen", "frozen_pending"])
	var by_id := {}
	for d in collect_debuffs():
		by_id[String(d.get("id", ""))] = d
	var out: Array[Dictionary] = []
	for id in want:
		if by_id.has(id):
			out.append(by_id[id])
	return out


func umbral_taken_bonus() -> float:
	if not is_boss:
		return 0.0
	var arena := ArenaState.arena as Arena
	if arena == null or not arena.umbral_shadow:
		return 0.0
	return arena.umbral_damage_taken_bonus(global_position)


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
		"description": "Takes more damage closer to the center.",
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
		"description": "Cannot move, attack, or cast.\nA Fire hit Shatters this for double damage and removes Frozen.",
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
		"description": "Burning for %ss. New Fire hits add another instance." % str(BURN_DURATION),
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
		"description": "Burning violently.",
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


func _consume_cast_infusion(ab: AbilityDef) -> PackedInt32Array:
	var extras := PackedInt32Array()
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
	if _overcharge_left > 0.0:
		for kind in [AbilityDef.Element.FIRE, AbilityDef.Element.ICE, AbilityDef.Element.STORM]:
			if kind != ab.element:
				extras.append(kind)
	elif _infusion != AbilityDef.Element.NONE and _infusion != ab.element:
		extras.append(_infusion)
	if ab.element != AbilityDef.Element.NONE:
		_infusion = ab.element
	_refresh_infusion_visual()
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
				color = Color(0.1, 0.28, 0.82, 0.95)
				strength = 0.6
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


func spend_cast(index: int) -> void:
	spend_mana(index)
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
	for i in abilities.size():
		if abilities[i].id == ability_id:
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
	return wall_stop_point(dest)


func wall_stop_point(to: Vector3) -> Vector3:
	var hit := _wall_ray_to(to)
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


func wall_travel_distance(dir: Vector3, max_dist: float) -> float:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return max_dist
	flat = flat.normalized()
	var dest := global_position + flat * max_dist
	var stopped := wall_stop_point(dest)
	return clampf(
		Vector2(stopped.x - global_position.x, stopped.z - global_position.z).length(),
		0.35,
		max_dist
	)


func has_wall_los(to: Vector3) -> bool:
	return _wall_ray_to(to).is_empty()


func _wall_ray_to(to: Vector3) -> Dictionary:
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.spell_wall_hit(global_position, to, [get_rid()])
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var from := Vector3(global_position.x, 1.05, global_position.z)
	var dest := Vector3(to.x, 1.05, to.z)
	if from.distance_squared_to(dest) < 0.0004:
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, dest)
	q.collision_mask = 1
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	return space.intersect_ray(q)


func take_damage(amount: float, source: Node3D = null, number_color: Color = Color(0, 0, 0, 0), hit_kind: String = "", ability_id: String = "") -> void:
	if is_dead or amount <= 0.0:
		return
	var umbral := umbral_taken_bonus()
	if umbral > 0.0:
		amount *= 1.0 + umbral
	if _dr_left > 0.0 and _dr_percent > 0.0:
		amount *= maxf(0.0, 1.0 - _dr_percent)
		if amount <= 0.0:
			return
	if _ward_left > 0.0:
		var absorbed := minf(_ward_left, amount)
		_ward_left -= absorbed
		amount -= absorbed
		if _ward_left <= 0.0:
			_clear_ward()
		if amount <= 0.0:
			return
	health = maxf(0.0, health - amount)
	if immortal:
		health = maxf(1.0, health)
	var spell := ability_id if not ability_id.is_empty() else hit_kind
	damaged.emit(self, amount, source, spell)
	_try_show_my_damage(amount, source, number_color, hit_kind)
	var src := source as Unit
	if src != null:
		src.apply_atonement(amount)
	if health <= 0.0:
		die()


func _try_show_my_heal(amount: float, source: Node3D) -> void:
	var me := GameSession.active_unit
	if me == null or source != me:
		return
	_DamageNumber.show_hit(self, amount, "heal")


func _try_show_my_damage(amount: float, source: Node3D, number_color: Color = Color(0, 0, 0, 0), hit_kind: String = "") -> void:
	var me := GameSession.active_unit
	if me == null or source != me:
		return
	var kind := hit_kind if not hit_kind.is_empty() else "hit"
	_DamageNumber.show_hit(self, amount, kind, number_color)


func _hit_number_kind(element: int, tick_hit: bool) -> String:
	if tick_hit:
		match element:
			AbilityDef.Element.FIRE:
				return "fire_tick"
			AbilityDef.Element.ICE:
				return "ice_tick"
			AbilityDef.Element.STORM:
				return "storm_tick"
			_:
				return "tick"
	match element:
		AbilityDef.Element.FIRE:
			return "fire"
		AbilityDef.Element.ICE:
			return "ice"
		AbilityDef.Element.STORM:
			return "storm"
		_:
			return "hit"


func _hit_number_tint(kind: String) -> Color:
	match kind:
		"burn":
			return Color(1.0, 0.48, 0.14)
		"combust":
			return Color(1.0, 0.28, 0.05)
		_:
			return Color(1.0, 1.0, 1.0)


func apply_heal(amount: float, source: Node3D = null, ability_id: String = "") -> void:
	if is_dead or amount <= 0.0:
		return
	var room := maxf(0.0, max_health - health)
	var hp_heal := minf(room, amount)
	if hp_heal > 0.0:
		health += hp_heal
		healed.emit(self, hp_heal, source, ability_id)
	var overflow := amount - hp_heal
	if overflow > 0.05 and ability_id == "atonement":
		var src := source as Unit
		if src != null and has_ward_from(src):
			_ward_left += overflow
	var shown := hp_heal if hp_heal > 0.05 else overflow
	if shown > 0.05:
		_try_show_my_heal(shown, source)


func set_ability_hover(enabled: bool, color: Color = Color(1.0, 0.82, 0.28, 0.92)) -> void:
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
		_name_frame = _make_hover_frame(_hp_root, "NameHoverFrame")
		if not _uses_feet_bars():
			var pri := 127 if _nameplate else 10
			_hp_frame = _make_hover_frame(_hp_root, "HpHoverFrame", true, pri)
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


func apply_shield(amount: float, duration: float = WARD_TIME, source: Node3D = null) -> void:
	if is_dead or amount <= 0.0:
		return
	_ward_left += amount
	_ward_time = maxf(_ward_time, duration)
	_ward_max = maxf(_ward_max, duration)
	if source is Unit:
		_ward_source = source as Unit


func _clear_ward() -> void:
	_ward_left = 0.0
	_ward_time = 0.0
	_ward_max = 0.0
	_ward_source = null


func has_ward_from(caster: Unit) -> bool:
	if caster == null or _ward_left <= 0.05 or _ward_time <= 0.05:
		return false
	return is_instance_valid(_ward_source) and _ward_source == caster


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


func _apply_ability_shields(ab: AbilityDef) -> void:
	if ab == null or ab.shield <= 0.0:
		return
	var dur := _shield_duration_for(ab)
	var rad := ab.aoe_radius
	if rad <= 0.05:
		apply_shield(ab.shield, dur, self)
		return
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != team:
			continue
		if u.global_position.distance_to(global_position) > rad + u.radius:
			continue
		u.apply_shield(ab.shield, dur, self)


func shield_amount() -> float:
	if _ward_time <= 0.0:
		return 0.0
	return maxf(_ward_left, 0.0)


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


func receive_ability_hit(source: Unit, element: int, damage: float, mark_bonus: float = 0.0, extra_elements: PackedInt32Array = PackedInt32Array(), tick_hit: bool = false, grant_chill: bool = true, allow_reactions: bool = true, overheat_cast_id: int = -1, infusion_double: int = 0, ability_id: String = "") -> void:
	if is_dead:
		return
	var extras: Array[int] = []
	for extra in extra_elements:
		if extra != AbilityDef.Element.NONE and extra != element and not extras.has(extra):
			extras.append(extra)
	var marks_before := elemental_mark_count()
	var had_fire := _mark_fire > 0.0
	var had_ice := _mark_ice > 0.0
	var had_storm := _mark_storm > 0.0
	var charged_on_hit := _charged_stacks if had_storm else 0
	var can_freeze := ability_id == "ice_blast"
	var was_frozen := _stun_left > 0.0
	var bonus := 0.0
	if element != AbilityDef.Element.NONE:
		if tick_hit:
			_apply_mark(element, source, false, true, infusion_double, false)
		elif allow_reactions:
			bonus += apply_elemental_hit(source, element, had_fire, had_ice, had_storm, infusion_double, can_freeze)
		else:
			# Repeat hits of the same cast still apply native status (Charged, etc.)
			# but must not Melt/Shatter marks this spell just applied.
			_apply_mark(element, source, true, true, infusion_double, can_freeze)
	for extra in extras:
		_apply_infusion_status(source, extra, true, false if tick_hit else true, infusion_double)
	var shattered := not tick_hit and was_frozen and _hit_shatters_frozen(element, extras, infusion_double)
	if shattered:
		_reaction_flash(Color(1.0, 0.72, 0.22), 1.05)
		_break_freeze()
		AudioManager.play_at("reaction.shatter", global_position + Vector3(0.0, height * 0.45, 0.0))
	var dealt := _final_spell_damage(damage, element, extras, had_storm, mark_bonus, marks_before, shattered, bonus)
	if source:
		source._refund_charge_mana(charged_on_hit, overheat_cast_id)
		source._refund_overheat_if_ice_hit(element, extra_elements, damage, tick_hit, grant_chill, overheat_cast_id)
	var kind := _hit_number_kind(element, tick_hit)
	var spell := ability_id
	if spell.is_empty():
		if tick_hit and element == AbilityDef.Element.ICE:
			spell = "chilled_ground"
		else:
			spell = kind
	take_damage(dealt, source, _hit_number_tint(kind), kind, spell)
	if is_dead:
		return
	if _hit_carries_fire(element, extras):
		var stored := dealt * (1.0 + umbral_taken_bonus())
		apply_burn(source, stored)
		if infusion_double & INFUSION_DOUBLE_FIRE:
			apply_burn(source, stored)


func apply_elemental_hit(source: Unit, kind: int, had_fire: bool = false, had_ice: bool = false, had_storm: bool = false, infusion_double: int = 0, can_freeze: bool = false) -> float:
	var extra := 0.0
	if kind == AbilityDef.Element.STORM:
		if had_ice:
			extra += SHATTER_BONUS
			_reaction_flash(Color(0.85, 0.95, 1.0), 0.7)
			AudioManager.play_at("reaction.shatter", global_position + Vector3(0.0, height * 0.45, 0.0))
	_apply_mark(kind, source, true, true, infusion_double, can_freeze)
	var triple := _mark_fire > 0.0 and _mark_ice > 0.0 and _mark_storm > 0.0
	if triple and not _had_triple:
		extra += CATACLYSM_BONUS
		_had_triple = true
		_reaction_flash(Color(1.0, 0.55, 0.2), 1.15)
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, global_position, {"scale": 0.85, "lifetime": 1.6})
		AudioManager.play_at("reaction.cataclysm", global_position)
	elif not triple:
		_had_triple = false
	return extra


func _final_spell_damage(base: float, element: int, extras: Array, had_storm: bool, mark_bonus: float, marks_before: int, shattered: bool, reaction_bonus: float) -> float:
	var amp := 1.0
	if had_storm and _hit_is_fire_or_ice(element, extras):
		amp += CHARGED_AMP * float(_charged_stacks)
	var amount := base * amp
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


func _apply_infusion_status(_source: Unit, kind: int, stack_storm: bool, stack_chill: bool = true, infusion_double: int = 0) -> void:
	if kind == AbilityDef.Element.NONE or kind == AbilityDef.Element.FIRE:
		return
	_apply_mark(kind, _source, stack_storm, stack_chill, infusion_double)


func apply_burn(source: Unit, hit_damage: float) -> void:
	var add := hit_damage * BURN_RATIO
	if add <= 0.0:
		return
	_burn_layers.append({
		"remaining": add,
		"time_left": BURN_DURATION,
		"dps": add / BURN_DURATION,
		"source": source,
	})
	_mark_fire = maxf(_mark_fire, BURN_DURATION)


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
	var dur := FREEZE_BOSS if is_boss else FREEZE_ADD
	_stun_left = dur
	_stun_max = dur
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
	_slow_left = 0.0
	_haste_left = 0.0
	_haste_percent = 0.0
	_dr_left = 0.0
	_dr_percent = 0.0
	_dr_max = 0.0
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
		target.take_damage(attack_damage, self, Color(1.0, 1.0, 1.0), "auto", "auto")
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
	spend_cast(index)
	var double_mask := _infusion_double_mask()
	var extras := _consume_cast_infusion(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	match ab.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
			var dir := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
			if dir.length_squared() < 0.001:
				dir = facing_dir()
			dir = dir.normalized()
			if ab.is_cone():
				_cone_blast(dir, ab, extras, ice_id, double_mask)
			else:
				var max_d := ab.skillshot_length if ab.skillshot_length > 0.05 else ab.range
				max_d = wall_travel_distance(dir, max_d)
				var travel := max_d
				if ab.splash_radius > 0.05:
					var to_aim := Vector2(point.x - global_position.x, point.z - global_position.z).length()
					travel = clampf(to_aim, 0.45, max_d)
				var spawn_off := clampf(minf(0.8, travel * 0.22), 0.12, maxf(travel - 0.2, 0.12))
				var remaining := maxf(travel - spawn_off, 0.15)
				var splash_vfx := AbilityFx.FIRE_AREA if ab.element == AbilityDef.Element.FIRE else AbilityFx.GROUND_EXPLOSION
				Projectile.spawn(self, global_position + dir * spawn_off + Vector3(0, 1.0, 0), {
					"direction": dir,
					"speed": ab.skillshot_speed,
					"damage": ab.damage,
					"radius": ab.skillshot_width * 0.5,
					"max_distance": remaining,
					"color": ab.color,
					"skillshot": true,
					"element": ab.element,
					"extra_elements": extras,
					"overheat_cast_id": ice_id,
					"infusion_double": double_mask,
					"vfx_scene": ab.vfx_scene,
					"vfx_scale": ab.vfx_scale,
					"vfx_primary": ab.vfx_primary,
					"vfx_secondary": ab.vfx_secondary,
					"vfx_tertiary": ab.vfx_tertiary,
					"vfx_yaw": ab.vfx_yaw,
					"splash_radius": ab.splash_radius,
					"splash_ratio": ab.splash_ratio,
					"splash_vfx": splash_vfx if ab.splash_radius > 0.0 else "",
					"splash_vfx_scale": 1.5 if ab.element == AbilityDef.Element.FIRE else 0.55,
					"ability_id": ab.id,
					"heal_allies": ab.heal_allies,
					"hit_cooldown_reduction": ab.hit_cooldown_reduction,
				})
		AbilityDef.TargetMode.UNIT:
			if target == null or target.is_dead:
				return
			if ab.chain_bounces > 0 and target.team != team:
				_chain_lightning(target, ab, extras, ice_id, double_mask)
			else:
				_play_ability_fx(ab, target.global_position + Vector3(0, 1.0, 0))
				if target.team == team:
					if ab.heal > 0.0:
						target.apply_heal(ab.heal, self, ab.id)
					if ab.shield > 0.0:
						target.apply_shield(ab.shield, _shield_duration_for(ab), self)
				else:
					target.receive_ability_hit(self, ab.element, ab.damage, 0.0, extras, false, true, true, ice_id, double_mask, ab.id)
					if ab.slow_duration > 0.0:
						target.apply_slow(ab.slow_percent, ab.slow_duration)
		AbilityDef.TargetMode.GROUND:
			if ab.zone_duration > 0.05:
				if ab.tick_shield > 0.05:
					_place_sanctuary(point, ab)
				else:
					_place_chilled_ground(point, ab, extras, ice_id, double_mask)
			elif ab.delay_time > 0.0:
				_delayed_ground(point, ab, extras, ice_id, double_mask)
			else:
				_ground_burst(point, ab, -1.0, -1.0, extras, ice_id, double_mask)
		AbilityDef.TargetMode.INSTANT:
			if ab.shield > 0.0:
				_apply_ability_shields(ab)
			if ab.grant_all_infusions or ab.buff_duration > 0.05 or ab.free_cast_charges > 0 or ab.shield > 0.0:
				_play_ability_fx(ab, global_position + Vector3(0.0, height * 0.45, 0.0))
			elif ab.damage > 0.05:
				_ground_burst(global_position, ab, -1.0, -1.0, extras, ice_id, double_mask)


func finish_channeled_ability(index: int, point: Vector3, charge: float) -> void:
	if index < 0 or index >= abilities.size():
		return
	if not _try_consume_free_cast():
		apply_cooldown(index, 1.0)
	var ab := abilities[index]
	var double_mask := _infusion_double_mask()
	var extras := _consume_cast_infusion(ab)
	var ice_id := _begin_ice_overheat_cast(ab, extras)
	var dmg := ab.scaled_damage(charge)
	var rad := ab.scaled_radius(charge)
	if ab.id == "meteor":
		var combust_mult := lerpf(1.0, 2.0, clampf(charge, 0.0, 1.0))
		_MeteorFx.drop(self, point, ab, dmg, rad, extras, ice_id, double_mask, combust_mult)
		return
	_ground_burst(point, ab, dmg, rad, extras, ice_id, double_mask)


func _chain_lightning(primary: Unit, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0) -> void:
	var chain := _build_lightning_chain(primary, ab)
	if chain.is_empty():
		return
	var pts: Array[Vector3] = []
	var first := _thunder_hit_point(primary)
	var origin := global_position + Vector3(0.0, height * 0.62, 0.0)
	origin = origin.lerp(first, 0.12)
	pts.append(origin)
	var prev: Unit = null
	for u in chain:
		var hit := _thunder_hit_point(u)
		if prev == u:
			var jitter := Vector3(_rng_jitter(), 0.35, _rng_jitter())
			hit += jitter
		pts.append(hit)
		prev = u
	_ThunderWaveFx.spawn(pts, ab.bounce_delay)
	var seen: Dictionary = {}
	for i in chain.size():
		var victim := chain[i]
		var first_on_target := not seen.has(victim)
		seen[victim] = true
		var delay := ab.bounce_delay * float(i)
		if delay <= 0.001:
			_apply_thunder_hit(victim, ab, extras, first_on_target, overheat_cast_id, infusion_double, i)
		else:
			get_tree().create_timer(delay).timeout.connect(_apply_thunder_hit.bind(victim, ab, extras, first_on_target, overheat_cast_id, infusion_double, i))


func _build_lightning_chain(primary: Unit, ab: AbilityDef) -> Array[Unit]:
	var chain: Array[Unit] = [primary]
	var visited: Dictionary = {primary: true}
	var current := primary
	for _i in ab.chain_bounces:
		var nxt := _nearest_chain_target(current, visited, ab.bounce_range)
		if nxt == null:
			nxt = current
		else:
			visited[nxt] = true
		chain.append(nxt)
		current = nxt
	return chain


func _nearest_chain_target(from: Unit, visited: Dictionary, bounce_range: float) -> Unit:
	var best: Unit = null
	var best_d := bounce_range
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == team:
			continue
		if visited.has(u):
			continue
		var d := from.global_position.distance_to(u.global_position)
		if d > best_d:
			continue
		if not from.has_wall_los(u.global_position):
			continue
		best_d = d
		best = u
	return best


func _thunder_hit_point(u: Unit) -> Vector3:
	return u.global_position + Vector3(0.0, u.height * 0.55, 0.0)


func _rng_jitter() -> float:
	return randf_range(-0.85, 0.85)


func _apply_thunder_hit(victim: Unit, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), allow_reactions: bool = true, overheat_cast_id: int = -1, infusion_double: int = 0, _hop: int = 0) -> void:
	if victim == null or not is_instance_valid(victim) or victim.is_dead:
		return
	var hit_at := victim.global_position + Vector3(0.0, victim.height * 0.55, 0.0)
	AudioManager.play_at("thunder_wave.hop", hit_at)
	if victim.is_stunned():
		AudioManager.play_at("reaction.shatter", hit_at)
	victim.receive_ability_hit(self, ab.element, ab.damage, 0.0, extras, false, true, allow_reactions, overheat_cast_id, infusion_double, ab.id)
	if ab.slow_duration > 0.0:
		victim.apply_slow(ab.slow_percent, ab.slow_duration)


func _cone_blast(dir: Vector3, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0) -> void:
	var length := ab.range if ab.range > 0.05 else ab.skillshot_length
	var half := ab.cone_angle * 0.5
	_IceBlastFx.spawn(global_position, dir, length, ab.cone_angle, cone_wall_lengths(dir, ab.cone_angle, length))
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == team:
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
		u.receive_ability_hit(self, ab.element, ab.damage, 0.0, extras, false, true, true, overheat_cast_id, infusion_double, ab.id)
		if ab.slow_duration > 0.0:
			u.apply_slow(ab.slow_percent, ab.slow_duration)
		_IceBlastFx.puff_at(u.global_position)


func _play_ability_fx(ab: AbilityDef, pos: Vector3, look: Vector3 = Vector3.ZERO) -> void:
	if ab.vfx_scene != "":
		var cfg := ab.vfx_cfg()
		if look.length_squared() > 0.0001:
			cfg["look"] = look
		if AbilityFx.play_at(ab.vfx_scene, pos, cfg):
			return
	_spawn_flash(pos, ab.color, maxf(0.6, ab.aoe_radius * 0.35))


func _place_sanctuary(point: Vector3, ab: AbilityDef) -> void:
	if is_instance_valid(_sanctuary_zone):
		_sanctuary_zone.queue_free()
	_sanctuary_zone = _Sanctuary.spawn(
		self,
		point,
		ab.aoe_radius,
		ab.zone_duration,
		ab.tick_interval,
		ab.tick_damage,
		ab.tick_shield,
		_shield_duration_for(ab),
		ab.id
	)


func _place_chilled_ground(point: Vector3, ab: AbilityDef, extras: PackedInt32Array, overheat_cast_id: int = -1, infusion_double: int = 0) -> void:
	if is_instance_valid(_chilled_zone):
		_chilled_zone.queue_free()
	_chilled_zone = _ChilledGround.spawn(
		self,
		point,
		ab.aoe_radius,
		ab.zone_duration,
		ab.tick_interval,
		ab.tick_damage,
		ab.element,
		extras,
		overheat_cast_id,
		infusion_double,
		ab.id
	)


func _delayed_ground(point: Vector3, ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0) -> void:
	var t := Telegraph.circle_slam(self, point, ab.aoe_radius, ab.delay_time, ab.damage, false)
	t.color = Color(ab.color.r, ab.color.g, ab.color.b, 0.45)
	t.vfx_scene = ab.vfx_scene
	t.vfx_cfg = ab.vfx_cfg()
	t.slow_percent = ab.slow_percent
	t.slow_duration = ab.slow_duration
	t.element = ab.element
	t.extra_elements = extras
	t.overheat_cast_id = overheat_cast_id
	t.infusion_double = infusion_double


func _ground_burst(point: Vector3, ab: AbilityDef, damage_override: float = -1.0, radius_override: float = -1.0, extras: PackedInt32Array = PackedInt32Array(), overheat_cast_id: int = -1, infusion_double: int = 0, combust_mult: float = 2.0) -> void:
	var dmg := ab.damage if damage_override < 0.0 else damage_override
	var rad := ab.aoe_radius if radius_override < 0.0 else radius_override
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
	for u in ArenaState.units:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == team:
			continue
		if u.global_position.distance_to(point) <= rad + u.radius:
			if not _burst_has_los(point, u.global_position):
				continue
			if ab.id == "meteor":
				u._combust(self, combust_mult)
			u.receive_ability_hit(self, ab.element, dmg, 0.0, extras, false, true, true, overheat_cast_id, infusion_double, ab.id)
			if ab.slow_duration > 0.0:
				u.apply_slow(ab.slow_percent, ab.slow_duration)


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
		lengths[i] = wall_travel_distance(spoke, radius)
	return lengths


func _burst_has_los(from: Vector3, to: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.spell_has_los(from, to, [get_rid()])
	return has_wall_los(to)


func _tick_elemental(delta: float) -> void:
	if _ward_time > 0.0:
		_ward_time = maxf(0.0, _ward_time - delta)
		if _ward_time <= 0.0:
			_clear_ward()
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
	_tick_burn(delta)
	_tick_combust(delta)
	_mark_ice = maxf(0.0, _mark_ice - delta)
	if _mark_ice <= 0.0:
		_chilled_stacks = 0
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
			take_damage(tick_damage, tick_source, Color(1.0, 0.48, 0.14), "burn", "burn")
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


func _clear_burn() -> void:
	_burn_layers.clear()
	_burn_acc = 0.0
	_mark_fire = 0.0


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
	var src := _combust_src
	if src != null and not is_instance_valid(src):
		src = null
	while _combust_acc >= COMBUST_TICK and _combust_hits_left > 0:
		_combust_acc -= COMBUST_TICK
		_combust_hits_left -= 1
		take_damage(_combust_tick, src, Color(1.0, 0.28, 0.05), "combust", "combust")
		if is_dead:
			_clear_combust()
			return
	if _combust_hits_left <= 0:
		_clear_combust()


func _chill_slow_amount() -> float:
	var per := CHILL_SLOW_BOSS if is_boss else CHILL_SLOW_ADD
	return minf(0.9, per * float(maxi(_chilled_stacks, 0)))


func _apply_mark(kind: int, source: Unit, stack_storm: bool = true, stack_chill: bool = true, infusion_double: int = 0, can_freeze: bool = false) -> void:
	if kind == AbilityDef.Element.FIRE:
		_mark_fire = maxf(_mark_fire, BURN_DURATION)
	elif kind == AbilityDef.Element.ICE:
		if stack_chill:
			var add := 2 if (infusion_double & INFUSION_DOUBLE_ICE) != 0 else 1
			_chilled_stacks = mini(CHILL_MAX, _chilled_stacks + add)
		elif _chilled_stacks <= 0:
			return
		_mark_ice = MARK_TIME
		apply_slow(_chill_slow_amount(), MARK_TIME)
		if can_freeze and stack_chill and _chilled_stacks >= CHILL_FREEZE_AT:
			_try_chill_freeze(source)
	elif kind == AbilityDef.Element.STORM:
		if stack_storm:
			var add := 2 if (infusion_double & INFUSION_DOUBLE_STORM) != 0 else 1
			_charged_stacks = mini(CHARGED_MAX, _charged_stacks + add)
		elif _charged_stacks <= 0:
			_charged_stacks = 1
		_mark_storm = CHARGED_TIME


func _try_chill_freeze(source: Unit = null) -> void:
	if apply_freeze(source):
		var chill_slow := _chill_slow_amount()
		_chilled_stacks = 0
		_mark_ice = 0.0
		if _slow_left > 0.0 and _slow_percent <= chill_slow + 0.03:
			_slow_left = 0.0
			_slow_percent = 0.0
			_slow_max = 0.0
		_reaction_flash(Color(0.7, 0.92, 1.0), 0.95)


func _clear_marks() -> void:
	_clear_burn()
	_clear_combust()
	_mark_ice = 0.0
	_chilled_stacks = 0
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


func _make_mark_pips() -> void:
	# Match Fire / Ice / Storm infusion tints (same as HUD infusion buffs).
	var colors := [
		Color(1.0, 0.42, 0.12),
		Color(0.45, 0.82, 1.0),
		Color(0.55, 0.62, 1.0),
	]
	var tex := _mark_pip_texture()
	for i in 3:
		var pip := Sprite3D.new()
		pip.name = "MarkPip%d" % i
		pip.texture = tex
		pip.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pip.shaded = false
		pip.double_sided = true
		pip.pixel_size = 0.0042
		pip.modulate = Color.WHITE
		pip.transparent = true
		pip.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		pip.no_depth_test = true
		pip.fixed_size = false
		var mat := ShaderMaterial.new()
		mat.shader = _MarkPipShader
		mat.set_shader_parameter("albedo_tex", tex)
		mat.set_shader_parameter("tint", colors[i])
		mat.set_shader_parameter("progress", 0.0)
		pip.material_override = mat
		pip.visible = false
		_hp_root.add_child(pip)
		_mark_pips.append(pip)
		_mark_pip_mats.append(mat)


func _refresh_mark_pips() -> void:
	if _mark_pips.size() < 3:
		return
	if _nameplate:
		for i in 3:
			_mark_pips[i].visible = false
		return
	var remain := [_mark_fire, _mark_ice, _mark_storm]
	var duration := [BURN_DURATION, MARK_TIME, CHARGED_TIME]
	var active: Array[int] = []
	for i in 3:
		if remain[i] > 0.0:
			active.append(i)
	var pip_y := 0.62 if _uses_feet_bars() else 0.86
	var spacing := 0.32
	var start := -spacing * float(active.size() - 1) * 0.5
	for i in 3:
		_mark_pips[i].visible = false
	for k in active.size():
		var idx := active[k]
		var pip := _mark_pips[idx]
		pip.visible = true
		pip.position = Vector3(start + float(k) * spacing, pip_y, 0.04)
		if idx < _mark_pip_mats.size():
			var ratio := clampf(remain[idx] / maxf(duration[idx], 0.01), 0.0, 1.0)
			_mark_pip_mats[idx].set_shader_parameter("progress", 1.0 - ratio)


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
	fx.global_position = point + Vector3(0, 0.4, 0)
	get_tree().current_scene.add_child(fx)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 1.8, 0.22)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(fx.queue_free)
