class_name SpellAura
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const SpellBaseFx := preload("res://scripts/visual/spell_base_fx.gd")
const DRAW_PRIORITY := 2

var source: Unit
var ability: AbilityDef
var extras: PackedInt32Array = PackedInt32Array()
var overheat_cast_id: int = -1
var combat_text_cast_id: int = -1
var infusion_double: int = 0
var slot_index: int = -1
var radius: float = 6.0
var inner_radius: float = 0.0
var tick_interval: float = 0.5
var tick_damage: float = 10.0
var color: Color = Color(0.85, 0.55, 1.0)
var _core: Color = Color(0.85, 0.55, 1.0)
var _rim: Color = Color(0.92, 0.72, 1.0)

var _tick_acc: float = 0.0


static func attach(caster: Unit, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, text_cast_id: int = -1, slot_index: int = -1) -> SpellAura:
	var z := SpellAura.new()
	z.source = caster
	z.ability = ab
	z.extras = extras
	z.overheat_cast_id = ice_id
	z.combat_text_cast_id = text_cast_id
	z.infusion_double = double_mask
	z.slot_index = slot_index
	z.radius = maxf(ab.aoe_radius, 1.2)
	z.inner_radius = _resolve_inner(ab, z.radius)
	z.tick_interval = maxf(ab.tick_interval, 0.15)
	z.tick_damage = caster._scaled(ab.tick_damage if ab.tick_damage > 0.05 else ab.damage)
	var pal := SpellBaseFx.palette(ab)
	z.color = pal.core
	z._core = pal.core
	z._rim = pal.rim
	caster.add_child(z)
	z.position = Vector3(0.0, 0.08 + maxf(float(slot_index), 0.0) * 0.012, 0.0)
	z._build()
	z._pulse()
	return z


static func _resolve_inner(ab: AbilityDef, radius: float) -> float:
	if ab == null:
		return 0.0
	if ab.inner_radius > 0.05:
		return ab.inner_radius
	if not (ab.has_infusion("illusion") or ab.has_element(AbilityDef.Element.ILLUSION)):
		return 0.0
	var inner := radius * CombatBalance.pct("illusion.aura.inner")
	return inner * (1.0 + CombatBalance.pct("illusion.aura.inner.push"))


func _build() -> void:
	var hint := MeshInstance3D.new()
	hint.mesh = GroundIndicator.circle_mesh()
	hint.scale = Vector3(radius, 1.0, radius)
	var hollow := inner_radius > 0.05
	var fill := GroundIndicator.AURA_RING_FILL if hollow else GroundIndicator.AURA_HINT_FILL
	var hint_mat := GroundIndicator.zone_mat(
		_core,
		radius,
		fill,
		GroundIndicator.AURA_HINT_OUTLINE
	)
	GroundIndicator.set_rim(hint_mat, _rim)
	GroundIndicator.set_inner_hole(hint_mat, inner_radius, radius)
	hint_mat.render_priority = DRAW_PRIORITY + maxi(slot_index, 0)
	hint.material_override = hint_mat
	GroundIndicator.prepare(hint)
	add_child(hint)


func _physics_process(delta: float) -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		queue_free()
		return
	_tick_acc += delta
	if _tick_acc >= tick_interval:
		_tick_acc -= tick_interval
		_pulse()


func _pulse() -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	if not GameSession.has_infinite_mana() and source.mana < source.mana_cost_for(slot_index):
		queue_free()
		return
	if ability.cost_per_tick:
		source.spend_mana(slot_index)
	SpellBaseFx.wave(self, radius, _core, minf(tick_interval * 1.05, 0.62), _rim, inner_radius)
	_buff_ally(source)
	var origin := source.global_position
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u == source:
			continue
		var dist := u.global_position.distance_to(origin)
		if dist > radius + u.radius:
			continue
		if inner_radius > 0.05 and dist < inner_radius:
			continue
		if u.team == source.team:
			_buff_ally(u)
			continue
		if tick_damage > 0.05:
			u.receive_ability_hit(source, ability.element, tick_damage, 0.0, extras, true, true, true, overheat_cast_id, infusion_double, _combat_ability_id(), combat_text_cast_id)


func _combat_ability_id() -> String:
	if ability == null:
		return ""
	return ability.combat_id(slot_index)


func _buff_ally(u: Unit) -> void:
	if u == null or not is_instance_valid(u) or u.is_dead or ability == null:
		return
	if ability.heal_allies or ability.shield > 0.05 or ability.applies_rejuvenation:
		var heal_amt: float = source._scaled(ability.heal) if ability.heal > 0.05 else (tick_damage if ability.heal_allies else 0.0)
		var shield_amt: float = source._scaled(ability.shield) if ability.shield > 0.05 else 0.0
		u.apply_support_hit(source, heal_amt, shield_amt, source._shield_duration_for(ability), ability.applies_rejuvenation, _combat_ability_id(), source._blessing_power_for(ability), extras, ability.element, combat_text_cast_id, true)
	if ability.altered:
		u.apply_altered_from(ability, false)
	UnitWind.apply_aura_haste(u, ability, tick_interval + 0.25)
