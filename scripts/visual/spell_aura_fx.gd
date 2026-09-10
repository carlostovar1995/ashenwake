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
var hit_element: int = -1
var _core: Color = Color(0.85, 0.55, 1.0)
var _rim: Color = Color(0.92, 0.72, 1.0)
var _world_pulse: bool = false

var _tick_acc: float = 0.0
var _last_source_pos: Vector3 = Vector3.ZERO
var _has_source_pos: bool = false
var _releasing: bool = false


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
	var lift := 0.08 + maxf(float(slot_index), 0.0) * 0.012
	if ab.planted:
		var host := caster.get_parent()
		if host != null:
			host.add_child(z)
			z.global_position = caster.global_position + Vector3(0.0, lift, 0.0)
		else:
			caster.add_child(z)
			z.position = Vector3(0.0, lift, 0.0)
	else:
		caster.add_child(z)
		z.position = Vector3(0.0, lift, 0.0)
	z._build()
	SpellVfx.attach_persist(z, ab)
	z._pulse()
	return z


static func burst_at(
	caster: Unit,
	at: Vector3,
	ab: AbilityDef,
	extras: PackedInt32Array,
	ice_id: int,
	double_mask: int,
	text_cast_id: int,
	damage: float,
	radius: float,
	element: int
) -> void:
	if caster == null or not is_instance_valid(caster) or ab == null:
		return
	var z := SpellAura.new()
	z.source = caster
	z.ability = ab
	z.extras = extras
	z.overheat_cast_id = ice_id
	z.combat_text_cast_id = text_cast_id
	z.infusion_double = double_mask
	z.radius = maxf(radius, 1.2)
	z.inner_radius = 0.0
	z.tick_interval = 0.45
	z.tick_damage = damage
	z.hit_element = element
	z._world_pulse = true
	var pal := SpellBaseFx.palette(ab)
	z.color = pal.core
	z._core = pal.core
	z._rim = pal.rim
	var parent: Node = ArenaState.arena if ArenaState.arena else caster.get_tree().current_scene
	if parent == null:
		return
	parent.add_child(z)
	z.global_position = Vector3(at.x, 0.08, at.z)
	z._build()
	z._pulse(1.0, false)
	z._releasing = true
	z.get_tree().create_timer(0.55).timeout.connect(z.queue_free)


static func _resolve_inner(ab: AbilityDef, radius: float) -> float:
	if ab == null:
		return 0.0
	if ab.inner_radius > 0.05:
		return ab.inner_radius
	if not (ab.has_infusion("illusion") or ab.has_element(AbilityDef.Element.ILLUSION)):
		return 0.0
	var inner := radius * CombatBalance.pct("illusion.aura.inner")
	return inner * (1.0 + CombatBalance.pct("illusion.aura.inner.push"))


func release(detonate: bool) -> void:
	if _releasing:
		return
	_releasing = true
	if detonate and ability != null and ability.detonate_on_end > 0.05:
		_pulse(ability.detonate_on_end, false)
	queue_free()


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
	if _releasing:
		return
	if source == null or not is_instance_valid(source) or source.is_dead:
		queue_free()
		return
	_tick_acc += delta
	if _tick_acc >= tick_interval:
		_tick_acc -= tick_interval
		_pulse()


func _pulse(power_mult: float = 1.0, spend: bool = true) -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	if spend:
		if not GameSession.has_infinite_mana() and source.mana < source.mana_cost_for(slot_index):
			queue_free()
			return
		if ability.cost_per_tick:
			source.spend_mana(slot_index)
	var origin := global_position
	var pulse_mult := power_mult * _stillness_mult() * _crowd_mult_at(origin)
	var pulse_damage := tick_damage * pulse_mult
	SpellBaseFx.wave(self, radius, _core, minf(tick_interval * 1.05, 0.62), _rim, inner_radius)
	if _source_receives_self_buff(origin):
		_buff_ally(source, pulse_mult)
	for u in ArenaState.units_near(origin, radius, true, true):
		if u == source:
			continue
		if not _in_ring(u, origin):
			continue
		if u.team == source.team:
			_buff_ally(u, pulse_mult)
			continue
		if pulse_damage > 0.05:
			u.receive_ability_hit(source, _hit_element(), pulse_damage, 0.0, extras, true, true, true, overheat_cast_id, infusion_double, _combat_ability_id(), combat_text_cast_id)


func _stillness_mult() -> float:
	if ability == null or ability.stillness_bonus <= 0.05:
		_stamp_source_pos()
		return 1.0
	var standing := not _has_source_pos or source.global_position.distance_to(_last_source_pos) <= 0.2
	_stamp_source_pos()
	return 1.0 + ability.stillness_bonus if standing else 1.0


func _stamp_source_pos() -> void:
	if source == null or not is_instance_valid(source):
		return
	_last_source_pos = source.global_position
	_has_source_pos = true


func _crowd_mult_at(origin: Vector3) -> float:
	if ability == null or ability.crowd_bonus <= 0.05:
		return 1.0
	var others := 0
	for u in ArenaState.units_near(origin, radius, true, true):
		if u == null or u == source or not _in_ring(u, origin):
			continue
		others += 1
	var extra := maxi(others - 1, 0)
	return 1.0 + minf(float(extra) * ability.crowd_bonus, ability.crowd_bonus_cap)


func _in_ring(u: Unit, origin: Vector3) -> bool:
	if u == null or not is_instance_valid(u):
		return false
	var dist := u.global_position.distance_to(origin)
	if dist > radius + u.radius:
		return false
	if inner_radius > 0.05 and dist < inner_radius:
		return false
	return true


func _hit_element() -> int:
	if hit_element >= 0:
		return hit_element
	if ability == null:
		return AbilityDef.Element.NONE
	return ability.element


func _source_receives_self_buff(origin: Vector3) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if _world_pulse or (ability != null and ability.planted):
		return source.global_position.distance_to(origin) <= radius + source.radius
	return true


func _combat_ability_id() -> String:
	if ability == null:
		return ""
	return ability.combat_id(slot_index)


func _buff_ally(u: Unit, pulse_mult: float = 1.0) -> void:
	if u == null or not is_instance_valid(u) or u.is_dead or ability == null:
		return
	if ability.heal_allies or ability.shield > 0.05 or ability.applies_rejuvenation:
		var heal_amt: float = 0.0
		if ability.heal > 0.05:
			heal_amt = source._scaled(ability.heal) * pulse_mult
		elif ability.heal_allies:
			heal_amt = tick_damage * pulse_mult
		var shield_amt: float = source._scaled(ability.shield) if ability.shield > 0.05 else 0.0
		u.apply_support_hit(source, heal_amt, shield_amt, source._shield_duration_for(ability), ability.applies_rejuvenation, _combat_ability_id(), source._blessing_power_for(ability), extras, ability.element, combat_text_cast_id, true)
	if ability.altered:
		u.apply_altered_from(ability, false)
	UnitWind.apply_aura_haste(u, ability, tick_interval + 0.25)
