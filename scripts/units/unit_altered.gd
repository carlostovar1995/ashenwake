class_name UnitAltered
extends Object

const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const _GroundAoe := preload("res://scripts/visual/ground_aoe_fx.gd")
const BUFF_TIME := 10.0
const FIRE_SPELL := 0.10
const FIRE_FIRE := 0.20
const RESIST := 0.30
const ICE_TICK := 12.6
const ICE_INTERVAL := 0.5
const ICE_RADIUS := 2.2
const ICE_PATCH_TIME := 2.6
const ICE_DROP_DIST := 1.15
const STORM_TICK := 0.25
const STORM_DAMAGE := 13.5
const STORM_RANGE := 7.0
const STORM_HOPS := 3
const SHADOW_TICK := 1.0
const SHADOW_MAX := 30
const SHADOW_HP := 0.05
const SHADOW_DAMAGE := 0.30


static func outgoing_damage_mult(u: Unit, ability_id: String, hit_kind: String) -> float:
	var m := 1.0
	if u._altered_shadow_stacks > 0 and u._altered_shadow_left > 0.05:
		m *= 1.0 + CombatBalance.pct("altered.shadow.out") * (float(u._altered_shadow_stacks) / float(SHADOW_MAX))
	if u._altered_fire_left > 0.05 and _is_spell_damage(ability_id, hit_kind):
		var fire_ab := u._ability_def(ability_id)
		if fire_ab != null and fire_ab.has_element(AbilityDef.Element.FIRE):
			m *= 1.0 + CombatBalance.pct("altered.fire.fire")
		else:
			m *= 1.0 + CombatBalance.pct("altered.fire.spell")
	return m


static func resist_cut(u: Unit, hit_kind: String, ability_id: String) -> float:
	var cut := 0.0
	if u._altered_fire_left > 0.05 and (hit_kind.begins_with("fire") or hit_kind == "burn" or AbilityDef.matches_base(ability_id, "burn")):
		cut += CombatBalance.pct("altered.resist")
	if u._altered_ice_left > 0.05 and (hit_kind.begins_with("ice") or AbilityDef.matches_base(ability_id, "chilled_ground") or AbilityDef.matches_base(ability_id, "frost_trail")):
		cut += CombatBalance.pct("altered.resist")
	if u._altered_storm_left > 0.05 and (hit_kind.begins_with("lightning") or AbilityDef.matches_base(ability_id, "shock_chain")):
		cut += CombatBalance.pct("altered.resist")
	if u._altered_shadow_left > 0.05 and not AbilityDef.matches_base(ability_id, "shadow_pact"):
		if hit_kind.begins_with("shadow") or hit_kind == "afflicted" or AbilityDef.matches_base(ability_id, "afflict"):
			cut += CombatBalance.pct("altered.resist")
	cut += _shield_resist_cut(u, hit_kind, ability_id)
	return clampf(cut, 0.0, 0.75)


static func _shield_resist_cut(u: Unit, hit_kind: String, ability_id: String) -> float:
	if u == null or u._shield_layers.is_empty():
		return 0.0
	var cut := 0.0
	var seen: Dictionary = {}
	for layer in u._shield_layers:
		var raw = layer.get("elements", PackedInt32Array())
		var els: Array = []
		if raw is PackedInt32Array:
			for el in raw:
				els.append(el)
		elif raw is Array:
			els = raw
		for item in els:
			var el := int(item)
			if seen.has(el):
				continue
			if not _element_matches_hit(el, hit_kind, ability_id):
				continue
			seen[el] = true
			cut += CombatBalance.pct("shield.resist")
	return cut


static func _element_matches_hit(el: int, hit_kind: String, ability_id: String) -> bool:
	match el:
		AbilityDef.Element.FIRE:
			return hit_kind.begins_with("fire") or hit_kind == "burn" or AbilityDef.matches_base(ability_id, "burn")
		AbilityDef.Element.ICE:
			return hit_kind.begins_with("ice") or AbilityDef.matches_base(ability_id, "chilled_ground") or AbilityDef.matches_base(ability_id, "frost_trail")
		AbilityDef.Element.STORM:
			return hit_kind.begins_with("lightning") or AbilityDef.matches_base(ability_id, "shock_chain")
		AbilityDef.Element.SHADOW:
			return not AbilityDef.matches_base(ability_id, "shadow_pact") and (hit_kind.begins_with("shadow") or hit_kind == "afflicted" or AbilityDef.matches_base(ability_id, "afflict"))
		AbilityDef.Element.NATURE:
			return hit_kind.begins_with("nature")
		AbilityDef.Element.HOLY:
			return hit_kind.begins_with("divine") or hit_kind.begins_with("holy")
		AbilityDef.Element.PROTECTION:
			return hit_kind.begins_with("protection")
		_:
			return false


static func apply_from(u: Unit, ab: AbilityDef, add_stack: bool = true) -> void:
	if u == null or u.is_dead or ab == null or not ab.altered:
		return
	var kinds := ab.altered_buff_elements()
	if kinds.is_empty():
		var kind := ab.altered_element
		if kind == AbilityDef.Element.NONE:
			kind = ab.element
		if kind != AbilityDef.Element.NONE:
			kinds.append(kind)
	for kind in kinds:
		_apply_kind(u, int(kind), add_stack)


static func _apply_kind(u: Unit, kind: int, add_stack: bool) -> void:
	match kind:
		AbilityDef.Element.FIRE:
			u._altered_fire_left = BUFF_TIME
		AbilityDef.Element.ICE:
			u._altered_ice_left = BUFF_TIME
			if u._frost_patches.is_empty():
				u._altered_ice_drop = u.global_position
				drop_frost(u)
		AbilityDef.Element.STORM:
			u._altered_storm_left = BUFF_TIME
		AbilityDef.Element.SHADOW:
			u._altered_shadow_left = BUFF_TIME
			if add_stack:
				u._altered_shadow_stacks = clampi(u._altered_shadow_stacks + 1, 1, SHADOW_MAX)
			elif u._altered_shadow_stacks < 1:
				u._altered_shadow_stacks = 1


static func apply_ally_spell(caster: Unit, target: Unit, ab: AbilityDef, include_support: bool = true, add_stack: bool = true) -> void:
	if caster == null or target == null or not is_instance_valid(target) or target.is_dead or ab == null:
		return
	if not ab.can_target_allies():
		return
	if include_support:
		var heal_amt := caster._scaled(ab.heal) if ab.heal > 0.05 else (caster._scaled(ab.damage) if ab.heal_allies else 0.0)
		if ab.heal_allies and heal_amt <= 0.05 and ab.tick_damage > 0.05:
			heal_amt = caster._scaled(ab.tick_damage)
		target.apply_support_hit(caster, heal_amt, caster._scaled(ab.shield), caster._shield_duration_for(ab), ab.applies_rejuvenation, ab.combat_id(), caster._blessing_power_for(ab), ab.extra_elements, ab.element, -1, false)
	if ab.altered:
		apply_from(target, ab, add_stack)
	if include_support and ab.shield > 0.05:
		SpellBaseFx.shield_bubble(target, ab)


static func tick(u: Unit, delta: float) -> void:
	if u._altered_fire_left > 0.0:
		u._altered_fire_left = maxf(0.0, u._altered_fire_left - delta)
	if u._altered_ice_left > 0.0:
		u._altered_ice_left = maxf(0.0, u._altered_ice_left - delta)
		if u._altered_ice_left > 0.0:
			tick_frost(u)
		else:
			clear_ice(u)
	else:
		if u._on_frost_trail or not u._frost_patches.is_empty():
			clear_ice(u)
	if u._altered_storm_left > 0.0:
		u._altered_storm_left = maxf(0.0, u._altered_storm_left - delta)
		if u._altered_storm_left > 0.0:
			u._altered_storm_acc += delta
			while u._altered_storm_acc >= STORM_TICK:
				u._altered_storm_acc -= STORM_TICK
				pulse_lightning(u)
		else:
			u._altered_storm_acc = 0.0
	if u._altered_shadow_left > 0.0:
		u._altered_shadow_left = maxf(0.0, u._altered_shadow_left - delta)
		if u._altered_shadow_left > 0.0:
			u._altered_shadow_acc += delta
			while u._altered_shadow_acc >= SHADOW_TICK and not u.is_dead:
				u._altered_shadow_acc -= SHADOW_TICK
				pulse_shadow(u)
		else:
			clear_shadow(u)


static func pulse_shadow(u: Unit) -> void:
	var ratio := float(clampi(u._altered_shadow_stacks, 1, SHADOW_MAX)) / float(SHADOW_MAX)
	var dmg := u.max_health * CombatBalance.pct("altered.shadow.hp") * ratio
	if dmg > 0.05:
		u.take_damage(dmg, u, _DamageNumber.tint_for("shadow"), "shadow_tick", "shadow_pact", false, true, -1, true)
	if u._altered_shadow_stacks < SHADOW_MAX:
		u._altered_shadow_stacks += 1


static func pulse_lightning(u: Unit) -> void:
	var first := u._chain_bounce_target(u, {u: true}, STORM_RANGE, false)
	if first == null:
		return
	var hops: Array[Unit] = [first]
	var visited: Dictionary = {u: true, first: true}
	var current := first
	for _i in STORM_HOPS - 1:
		var nxt: Unit = u._chain_bounce_target(current, visited, STORM_RANGE, false)
		if nxt == null:
			break
		visited[nxt] = true
		hops.append(nxt)
		current = nxt
	var hosts: Array = [u]
	for hop in hops:
		hosts.append(hop)
	ThunderWaveFx.spawn(hosts, 0.05)
	for i in hops.size():
		var hop := hops[i]
		var dmg := CombatBalance.scaled_hit("altered.storm.hit") * CombatBalance.chain_hop_mult(i)
		hop.take_damage(dmg, u, _DamageNumber.tint_for("lightning"), "lightning", "altered_lightning", false, false, -1, true)
		if not hop.is_dead:
			hop.apply_shock(u)


static func frost_def(u: Unit) -> AbilityDef:
	if u._frost_trail_ab == null:
		u._frost_trail_ab = AbilityDef.make("frost_trail", "Frost Trail", "", AbilityDef.TargetMode.GROUND, 0.0, 0.0, 0.0, 0.0, Color(0.45, 0.82, 1.0))
		u._frost_trail_ab.delivery = AbilityDef.Delivery.GROUND_AOE
		u._frost_trail_ab.aoe_radius = ICE_RADIUS
		u._frost_trail_ab.zone_duration = ICE_PATCH_TIME
		u._frost_trail_ab.tick_interval = ICE_INTERVAL
		u._frost_trail_ab.tick_damage = CombatBalance.scaled_hit("altered.ice.tick")
		u._frost_trail_ab.element = AbilityDef.Element.ICE
		u._frost_trail_ab.color = Color(0.45, 0.82, 1.0)
		u._frost_trail_ab.vfx_primary = Color(0.55, 0.88, 1.0)
		u._frost_trail_ab.vfx_secondary = Color(0.18, 0.45, 0.95)
	u._frost_trail_ab.tick_damage = CombatBalance.scaled_hit("altered.ice.tick")
	return u._frost_trail_ab


static func tick_frost(u: Unit) -> void:
	prune_frost(u)
	var moved := Vector2(u.global_position.x - u._altered_ice_drop.x, u.global_position.z - u._altered_ice_drop.z).length()
	if u._frost_patches.is_empty() or moved >= ICE_DROP_DIST:
		drop_frost(u)
	u._on_frost_trail = standing_on_frost(u)


static func drop_frost(u: Unit) -> void:
	var patch := _GroundAoe.spawn(u, u.global_position, frost_def(u), PackedInt32Array())
	u._frost_patches.append(patch)
	u._altered_ice_drop = u.global_position


static func standing_on_frost(u: Unit) -> bool:
	for raw in u._frost_patches:
		var z := raw as GroundAoeZone
		if z == null or not is_instance_valid(z):
			continue
		var to := u.global_position - z.global_position
		to.y = 0.0
		if to.length() <= z.radius + u.radius:
			return true
	return false


static func prune_frost(u: Unit) -> void:
	var keep: Array[Node] = []
	for raw in u._frost_patches:
		if raw != null and is_instance_valid(raw):
			keep.append(raw)
	u._frost_patches = keep


static func clear_ice(u: Unit) -> void:
	u._altered_ice_left = 0.0
	u._on_frost_trail = false
	for raw in u._frost_patches:
		if raw != null and is_instance_valid(raw):
			raw.queue_free()
	u._frost_patches.clear()


static func clear_shadow(u: Unit) -> void:
	u._altered_shadow_left = 0.0
	u._altered_shadow_stacks = 0
	u._altered_shadow_acc = 0.0


static func clear_all(u: Unit) -> void:
	u._altered_fire_left = 0.0
	u._altered_storm_left = 0.0
	u._altered_storm_acc = 0.0
	clear_ice(u)
	clear_shadow(u)


static func _is_spell_damage(ability_id: String, hit_kind: String) -> bool:
	var key := AbilityDef.base_from_combat_id(ability_id)
	if key.is_empty() or key == "auto" or key == "burn" or key == "afflict":
		return false
	if key == "shock_chain" or key == "frost_trail" or key == "shadow_pact" or key == "chilled_ground":
		return false
	if hit_kind == "burn" or hit_kind.ends_with("_tick"):
		return false
	return true
