class_name TalentCombat
extends Object

const LIVE_COALS_RADIUS := 3.6
const CRITICAL_MASS_RADIUS := 1.6
const SINGE_RADIUS := 2.2
const SINGE_DURATION := 6.0
const SINGE_CAP := 3
const SCORCH_DURATION := 5.0
const PITCH_SKIN_RANGE := 8.0
const STEAM_TICK := 12.0
## Passive DR from Plate/Grudge/Oath adds together. CDs (Ironhide, Rampage, Sanctuary) stay on the unit DR buff.
const TAKEN_CUT_CAP := 0.50
const SECOND_SKIN_ICD := 1.0
const ANOINTED_ICD := 1.0


static func hit_mult(source: Unit, victim: Unit, element: int, extras, tick_hit: bool, ability_id: String) -> float:
	if source == null or victim == null:
		return 1.0
	var hooks := source.talent_hooks()
	if hooks == null:
		return 1.0
	var mult := 1.0
	if hooks.spite_damage > 0.0:
		mult *= 1.0 + hooks.spite_damage
	if hooks.rampage_left > 0.0:
		mult *= 1.25
	if hooks.marked_prey > 0.0 and ThreatTable.aggro_holder(victim) == source:
		mult *= 1.0 + hooks.marked_prey
	if not tick_hit and _carries_fire(element, extras) and victim.has_burn() and hooks.hotter_coals > 0.0:
		mult *= 1.0 + hooks.hotter_coals
	if victim.has_burn() and victim.has_chill() and hooks.fumarole_amp > 0.0:
		mult *= 1.0 + hooks.fumarole_amp
	if _carries_storm(element, extras):
		if hooks.lightning_damage_pct > 0.0:
			mult *= 1.0 + hooks.lightning_damage_pct
		if hooks.galvanic_grove > 0.0 and _carries_nature(element, extras):
			mult *= 1.0 + hooks.galvanic_grove
		if hooks.conduction > 0.0 and victim.shock_stacks() >= 50:
			mult *= 1.0 + hooks.conduction
	if hooks.fire_damage_pct > 0.0 and _carries_fire(element, extras):
		mult *= 1.0 + hooks.fire_damage_pct
	if hooks.ice_damage_pct > 0.0 and _carries_ice(element, extras):
		mult *= 1.0 + hooks.ice_damage_pct
	if hooks.shadow_damage_pct > 0.0 and _carries_shadow(element, extras):
		mult *= 1.0 + hooks.shadow_damage_pct
	if hooks.burned_damage_pct > 0.0 and victim.has_burn():
		mult *= 1.0 + hooks.burned_damage_pct
	if hooks.chilled_damage_pct > 0.0 and victim.has_chill():
		mult *= 1.0 + hooks.chilled_damage_pct
	if hooks.afflicted_damage_pct > 0.0 and victim.afflict_stacks() > 0:
		mult *= 1.0 + hooks.afflicted_damage_pct
	return mult


static func taken_cut(victim: Unit, hit_kind: String) -> float:
	if victim == null:
		return 0.0
	var cut := 0.0
	var hooks := victim.talent_hooks()
	if hooks != null:
		if hooks.pitch_skin > 0.0 and _pitch_skin_hit(hit_kind) and _nearby_afflicted_enemy(victim):
			cut += hooks.pitch_skin
		if hooks.spite_dr > 0.0:
			cut += hooks.spite_dr
		if hooks.passive_dr > 0.0:
			cut += hooks.passive_dr
		if hooks.brace_dr > 0.0 and victim.shield_amount() > 0.05:
			cut += hooks.brace_dr
		if hooks.shielded_dr > 0.0 and victim.shield_amount() > 0.05:
			cut += hooks.shielded_dr
	var guard := _nearby_bodyguard(victim)
	if guard > 0.0:
		cut += guard
	var ring := ringward_cut(victim)
	if ring > 0.0:
		cut += ring
	return minf(cut, TAKEN_CUT_CAP)


static func _pitch_skin_hit(hit_kind: String) -> bool:
	return hit_kind == "fire" or hit_kind == "shadow" or hit_kind.begins_with("fire") or hit_kind.begins_with("shadow")


static func on_ability_hit(
	source: Unit,
	victim: Unit,
	ab: AbilityDef,
	element: int,
	extras,
	dealt: float,
	tick_hit: bool,
	crit: bool,
	ability_id: String
) -> void:
	if source == null or victim == null or dealt <= 0.05:
		return
	var hooks := source.talent_hooks()
	if hooks == null:
		return
	var fire := _carries_fire(element, extras)
	var ice := _carries_ice(element, extras)
	if fire and hooks.sootbrand_stacks > 0:
		victim.apply_afflict_stacks(source, hooks.sootbrand_stacks)
	if fire and not tick_hit:
		if hooks.searing_refresh > 0.0:
			victim.refresh_burn(hooks.searing_refresh)
		if crit:
			if hooks.flashover_burn > 0.0:
				victim.apply_burn(source, dealt * hooks.flashover_burn)
			if hooks.critical_mass > 0.0:
				_splash(source, victim, dealt * hooks.critical_mass, CRITICAL_MASS_RADIUS, AbilityDef.Element.FIRE, "critical_mass")
			if hooks.afterburn > 0.0:
				hooks.afterburn_left = 4.0
			if hooks.pyroblast_slot >= 0:
				source.reduce_ability_cooldown(hooks.pyroblast_slot, CombatBalance.flat("skill.pyroblast.cdr"))
	if fire:
		_on_furnace_mark_hit(source, victim, hooks, ability_id, tick_hit)
	if victim.has_burn() and victim.has_chill() and hooks.obsidian_shell > 0.0:
		source.apply_shield(dealt * hooks.obsidian_shell, 3.0, source)
	_on_bulwark_hit(source, victim, ab, dealt, tick_hit, ability_id)
	_on_storm_druid_hit(source, victim, element, extras, dealt, tick_hit)
	if tick_hit and hooks.kiln_rank > 0:
		var base := AbilityDef.base_from_combat_id(ability_id)
		var kiln_ok := base == "ground_aoe" or base == "aura" or base == "wall"
		if kiln_ok and fire:
			victim.apply_chill_stacks(hooks.kiln_rank, source)
		if kiln_ok and ice:
			victim.apply_burn(source, dealt * (0.10 if hooks.kiln_rank == 1 else 0.20))


static func burn_store_ratio(source: Unit, victim: Unit = null) -> float:
	var ratio := CombatBalance.pct("burn.ratio")
	if source == null:
		return ratio
	var hooks := source.talent_hooks()
	if hooks == null:
		return ratio
	ratio += hooks.burn_store_bonus
	if victim != null and hooks.scorch_store > 0.0 and victim.has_scorch_from(source):
		ratio += hooks.scorch_store
	return ratio


static func _on_furnace_mark_hit(source: Unit, victim: Unit, hooks: TalentHooks, ability_id: String, tick_hit: bool) -> void:
	if source == null or victim == null or hooks == null:
		return
	if ability_id == "singe" or ability_id == "critical_mass" or ability_id == "live_coals" or ability_id == "cinder_spark":
		return
	if tick_hit and hooks.scorch_snare > 0.0:
		var zone := AbilityDef.base_from_combat_id(ability_id)
		if zone == "ground_aoe" or zone == "aura" or zone == "wall":
			victim.apply_scorch(source, SCORCH_DURATION, hooks.scorch_snare)
	if tick_hit or ability_id == "auto":
		return
	if hooks.singe_rank <= 0:
		return
	if victim.singe_stacks() >= SINGE_CAP and _singe_can_consume(hooks.singe_rank, ability_id):
		_detonate_singe(source, victim, hooks)
		return
	victim.apply_singe(source, SINGE_DURATION, SINGE_CAP)


static func _singe_can_consume(rank: int, ability_id: String) -> bool:
	var base := AbilityDef.base_from_combat_id(ability_id)
	if base == "burst" or base == "nova" or base == "meteor" or base == "pyre":
		return true
	if rank >= 2 and (base == "bolt" or base == "missiles" or base == "ray"):
		return true
	return false


static func _detonate_singe(source: Unit, victim: Unit, hooks: TalentHooks) -> void:
	if victim.consume_singe() < SINGE_CAP:
		return
	var dmg := 18.0
	if hooks.singe_rank >= 3:
		dmg = 36.0
	elif hooks.singe_rank >= 2:
		dmg = 28.0
	if hooks.singe_rank >= 3 and victim.has_burn():
		var leftover := victim.spreadable_burn_remaining()
		var slice := leftover * 0.20
		if slice > 0.05:
			_spread_auto_burn(source, victim, slice, 2.8)
	_splash(source, victim, dmg, SINGE_RADIUS, AbilityDef.Element.FIRE, "singe")
	victim.take_damage(dmg, source, _DamageNumber.tint_for("fire"), "fire", "singe", false, true, -1, true)


static func consume_singe_on_pyre(source: Unit, victim: Unit) -> void:
	if source == null or victim == null:
		return
	var hooks := source.talent_hooks()
	if hooks == null or hooks.singe_rank <= 0:
		return
	if victim.singe_stacks() < SINGE_CAP:
		return
	_detonate_singe(source, victim, hooks)


static func pyre_splash_ratio(source: Unit, victim: Unit) -> float:
	var ratio := 0.40
	if source == null or victim == null:
		return ratio
	var hooks := source.talent_hooks()
	if hooks == null or hooks.scorch_pyre_splash <= 0.0:
		return ratio
	if not victim.has_scorch_from(source):
		return ratio
	victim.clear_scorch()
	return ratio + hooks.scorch_pyre_splash


static func on_auto_attack(source: Unit, victim: Unit) -> void:
	if source == null or victim == null or victim.is_dead:
		return
	var aa := source.class_auto()
	if aa == null:
		return
	if aa.extra_threat > 0.05 and victim.team != source.team:
		ThreatTable.add_threat(victim, source, aa.extra_threat, "auto")
	if aa.raid_mana > 0.05:
		_restore_raid_mana(source, aa.raid_mana)
	if aa.afflict_hit > 0 and victim.team != source.team:
		victim.apply_afflict_stacks(source, aa.afflict_hit)
	if aa.chill_on_frostfire and victim.team != source.team and (victim.has_chill() or victim.has_burn()):
		victim.apply_chill_stacks(1, source)
	if aa.self_shield > 0.05:
		source.apply_shield(aa.self_shield, 4.0, source)
	if aa.ally_shield > 0.05:
		_shield_nearest_ally(source, aa.ally_shield, 4.0)
	if aa.grove_pulse > 0.0:
		_grove_pulse(source, source.attack_damage * aa.grove_pulse)
	if aa.lightning_pct > 0.0 and victim.team != source.team:
		victim.take_damage(
			source.attack_damage * aa.lightning_pct,
			source,
			_DamageNumber.tint_for("lightning"),
			"lightning",
			"auto"
		)
	if aa.afflict_amp > 0.0 and victim.team != source.team and victim.afflict_stacks() > 0:
		victim.take_damage(
			source.attack_damage * aa.afflict_amp,
			source,
			_DamageNumber.tint_for("shadow"),
			"shadow",
			"auto"
		)
	if aa.spread_burn_ratio <= 0.0 or aa.spread_burn_radius <= 0.05:
		return
	if not victim.has_burn():
		return
	var leftover := victim.spreadable_burn_remaining()
	var slice := leftover * aa.spread_burn_ratio
	if slice <= 0.05:
		return
	_spread_auto_burn(source, victim, slice, aa.spread_burn_radius)


static func _restore_raid_mana(source: Unit, amount: float) -> void:
	if source == null or amount <= 0.05:
		return
	for ally in ArenaState.living_team(source.team):
		var u := ally as Unit
		if u == null or u.is_dead:
			continue
		u.restore_mana(amount)


static func _shield_nearest_ally(source: Unit, amount: float, duration: float) -> void:
	var best: Unit = null
	var best_d := 8.5
	for ally in ArenaState.living_team(source.team):
		var u := ally as Unit
		if u == null or u == source or u.is_dead:
			continue
		var d := source.global_position.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	if best != null:
		best.apply_shield(amount, duration, source)


static func _grove_pulse(source: Unit, amount: float) -> void:
	if amount <= 0.05:
		return
	var best: Unit = null
	var best_hp := 2.0
	for ally in ArenaState.living_team(source.team):
		var u := ally as Unit
		if u == null or u == source or u.is_dead or u.max_health <= 0.05:
			continue
		if source.global_position.distance_to(u.global_position) > 8.5:
			continue
		var ratio := u.health / u.max_health
		if ratio < best_hp:
			best_hp = ratio
			best = u
	if best != null:
		best.apply_heal(amount, source, "auto")


static func _spread_auto_burn(source: Unit, origin: Unit, amount: float, radius: float) -> void:
	var neighbors: Array[Unit] = []
	for other in ArenaState.units_near(origin.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u == origin or u.is_dead or u.team == source.team:
			continue
		neighbors.append(u)
	if neighbors.is_empty():
		return
	var slice := amount / float(neighbors.size())
	if slice <= 0.05:
		return
	for u in neighbors:
		u.apply_spread_burn(source, slice, Unit.BURN_DURATION, origin)


static func on_apply_burn(source: Unit, victim: Unit, had_burn: bool, layer_amount: float) -> void:
	if source == null or victim == null or layer_amount <= 0.05:
		return
	var hooks := source.talent_hooks()
	if hooks == null:
		return
	if had_burn and hooks.cinder_spark_ratio > 0.0:
		victim.take_damage(
			layer_amount * hooks.cinder_spark_ratio,
			source,
			_DamageNumber.tint_for("fire"),
			"fire",
			"cinder_spark",
			false,
			false,
			-1,
			true
		)


static func modify_burn_tick(source: Unit, victim: Unit, amount: float) -> float:
	if source == null or amount <= 0.0:
		return amount
	var hooks := source.talent_hooks()
	if hooks == null:
		return amount
	if hooks.emberheart > 0.0:
		amount *= 1.0 + hooks.emberheart
	if hooks.cinderfeed > 0.0 and victim != null and victim.afflict_stacks() > 0:
		amount *= 1.0 + hooks.cinderfeed
	if hooks.wick > 0.0:
		source.apply_heal(amount * hooks.wick, source, "wick")
	return amount


static func on_death(victim: Unit) -> void:
	if victim == null:
		return
	_on_storm_druid_death(victim)
	if not victim.has_burn():
		return
	var leftover := victim.burn_remaining()
	if leftover <= 0.05:
		return
	var killer := _burn_source(victim)
	if killer == null:
		return
	var hooks := killer.talent_hooks()
	if hooks == null:
		return
	if hooks.live_coals_ratio > 0.0:
		_splash(killer, victim, leftover * hooks.live_coals_ratio, LIVE_COALS_RADIUS, AbilityDef.Element.FIRE, "live_coals")
	if hooks.fumarole_time > 0.0 and victim.has_chill():
		_steam_patch(killer, victim.global_position, hooks.fumarole_time)


static func chill_effectiveness(source: Unit, victim: Unit, base_effectiveness: float) -> float:
	if source == null or victim == null:
		return base_effectiveness
	var hooks := source.talent_hooks()
	if hooks != null and hooks.glaze and victim.has_burn():
		return base_effectiveness * 2.0
	return base_effectiveness


static func on_chill_applied(source: Unit, victim: Unit, stacks_before: int) -> void:
	if source == null or victim == null or stacks_before > 0:
		return
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.quench or not victim.has_burn():
		return
	var burst := victim.burn_remaining() * 0.20
	if burst <= 0.05:
		return
	victim.take_damage(burst, source, _DamageNumber.tint_for("fire"), "fire", "quench", false, false, -1, true)


static func always_crit(source: Unit, victim: Unit, ab: AbilityDef) -> bool:
	if ab == null or source == null or victim == null:
		return false
	if (ab.skill_id == "pyroblast" or ab.skill_id == "pyre") and victim.has_burn():
		return true
	return false


static func consume_afterburn(source: Unit, ab: AbilityDef) -> float:
	if source == null or ab == null:
		return 0.0
	var hooks := source.talent_hooks()
	if hooks == null or hooks.afterburn_left <= 0.0 or hooks.afterburn <= 0.0:
		return 0.0
	if not ab.has_element(AbilityDef.Element.FIRE):
		return 0.0
	hooks.afterburn_left = 0.0
	return hooks.afterburn


static func wraithfire_distance(source: Unit) -> float:
	if source == null:
		return 0.0
	var hooks := source.talent_hooks()
	if hooks == null or hooks.wraithfire_rank <= 0:
		return 0.0
	if hooks.wraithfire_rank >= 3:
		return 10.0
	if hooks.wraithfire_rank >= 2:
		return 8.0
	return 6.0


static func wraithfire_nova(source: Unit) -> void:
	if source == null:
		return
	var hooks := source.talent_hooks()
	if hooks == null or hooks.wraithfire_rank <= 0:
		return
	var dmg := 25.0
	var radius := 2.2
	if hooks.wraithfire_rank >= 3:
		dmg = 70.0
		radius = 2.8
	elif hooks.wraithfire_rank >= 2:
		dmg = 40.0
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, source.global_position, {"scale": 0.55, "lifetime": 0.9})
	for other in ArenaState.units_near(source.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u.team == source.team or u.is_dead:
			continue
		u.receive_ability_hit(
			source,
			AbilityDef.Element.FIRE,
			dmg,
			0.0,
			PackedInt32Array([AbilityDef.Element.SHADOW]),
			false,
			true,
			true,
			-1,
			0,
			"wraithfire",
			-1,
			false
		)


static func tick_afterburn(hooks: TalentHooks, delta: float) -> void:
	if hooks == null:
		return
	hooks.afterburn_left = maxf(0.0, hooks.afterburn_left - delta)


static func tick(unit: Unit, delta: float) -> void:
	if unit == null:
		return
	var hooks := unit.talent_hooks()
	tick_afterburn(hooks, delta)
	if hooks == null:
		return
	hooks.ironhide_left = maxf(0.0, hooks.ironhide_left - delta)
	hooks.second_skin_icd = maxf(0.0, hooks.second_skin_icd - delta)
	hooks.anointed_icd = maxf(0.0, hooks.anointed_icd - delta)
	hooks.rampage_left = maxf(0.0, hooks.rampage_left - delta)
	hooks.intercede_left = maxf(0.0, hooks.intercede_left - delta)
	hooks.sanctuary_left = maxf(0.0, hooks.sanctuary_left - delta)
	hooks.drought_left = maxf(0.0, hooks.drought_left - delta)
	if hooks.drought_left <= 0.05:
		hooks.drought_rejuv_only = false
	var had_bloom := hooks.tempest_bloom_left > 0.05
	hooks.tempest_bloom_left = maxf(0.0, hooks.tempest_bloom_left - delta)
	if had_bloom and hooks.tempest_bloom_left <= 0.05:
		hooks.stormbond_cap = 2
		hooks.drought_left = 2.0
		hooks.drought_rejuv_only = true
	hooks.rooted_left = maxf(0.0, hooks.rooted_left - delta)
	hooks.eye_storm_left = maxf(0.0, hooks.eye_storm_left - delta)
	_prune_stormbond(hooks)
	if hooks.intercede_left <= 0.0:
		hooks.intercede_target_id = 0
	if hooks.brace_heal > 0.05 and unit.shield_amount() > 0.05:
		hooks.brace_heal_acc += delta
		while hooks.brace_heal_acc >= 1.0:
			hooks.brace_heal_acc -= 1.0
			apply_channel_heal(unit, unit, hooks.brace_heal, AbilityDef.Element.HOLY, "brace", true, true)
	else:
		hooks.brace_heal_acc = 0.0
	_tick_undertow(unit, hooks, delta)


static func dodge_is_blink(source: Unit) -> bool:
	return wraithfire_distance(source) > 0.05


static func dodge_distance(source: Unit, base_dist: float) -> float:
	var wraith := wraithfire_distance(source)
	if wraith > 0.05:
		return wraith
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.lunge:
		return 8.0
	return base_dist


static func dodge_cooldown(source: Unit, base_cd: float) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.lunge:
		return 3.6
	return base_cd


static func protection_hold_slow(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.pavise:
		return 0.35
	return CombatBalance.pct("wall.protection.slow")


static func blessing_cap(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.halo_cap > 0.05:
		return hooks.halo_cap
	return Unit.BLESSING_MAX


static func blessing_rate(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.halo:
		return 1.50
	return 1.0


static func shield_out_mult(source: Unit, target: Unit) -> float:
	if source == null:
		return 1.0
	var hooks := source.talent_hooks()
	if hooks == null:
		return 1.0
	var mult := 1.0 + hooks.shield_pct
	if target != null and target != source:
		mult *= 1.0 + hooks.vow_ally_shield
	return mult


static func shield_duration_bonus(source: Unit, target: Unit, ab: AbilityDef) -> float:
	if source == null or target == null or source == target:
		return 0.0
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.cover or ab == null:
		return 0.0
	if not ab.has_element(AbilityDef.Element.PROTECTION):
		return 0.0
	return hooks.cover_extra if hooks.cover_extra > 0.05 else 2.0


static func heal_out_mult(source: Unit, ability_id: String = "") -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return 1.0
	var mult := 1.0 + hooks.mercy_dealt + hooks.heal_dealt_pct
	if hooks.nature_heal_pct > 0.0 and _heal_is_nature(source, ability_id):
		mult *= 1.0 + hooks.nature_heal_pct
	if hooks.pulse_heal_pct > 0.0 and AbilityDef.base_from_combat_id(ability_id) == "nature":
		mult *= 1.0 + hooks.pulse_heal_pct
	return mult


static func heal_taken_mult(target: Unit) -> float:
	var hooks := target.talent_hooks() if target else null
	var mult := 1.0
	if hooks != null:
		mult *= 1.0 + hooks.mercy_taken
	mult *= 1.0 + heartwood_taken(target)
	return mult


static func apply_channel_heal(target: Unit, source: Unit, amount: float, element: int, ability_id: String, periodic: bool = false, apply_blessing: bool = false) -> void:
	if target == null or source == null or amount <= 0.05:
		return
	var blessing := amount if apply_blessing and element == AbilityDef.Element.HOLY else 0.0
	target.apply_support_hit(
		source,
		amount,
		0.0,
		0.0,
		false,
		ability_id,
		blessing,
		PackedInt32Array(),
		element,
		-1,
		periodic
	)


static func allows_undertow_cast(source: Unit, ab: AbilityDef) -> bool:
	if source == null or ab == null:
		return false
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.undertow or hooks.undertow_charges <= 0:
		return false
	return ab.delivery == AbilityDef.Delivery.GROUND_AOE and ab.has_element(AbilityDef.Element.WIND)


static func undertow_empty(source: Unit, ab: AbilityDef) -> bool:
	if source == null or ab == null:
		return false
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.undertow:
		return false
	if ab.delivery != AbilityDef.Delivery.GROUND_AOE or not ab.has_element(AbilityDef.Element.WIND):
		return false
	return hooks.undertow_charges <= 0


static func consume_undertow_charge(source: Unit, ab: AbilityDef) -> bool:
	if not allows_undertow_cast(source, ab):
		return false
	var hooks := source.talent_hooks()
	hooks.undertow_charges = maxi(hooks.undertow_charges - 1, 0)
	if hooks.undertow_recharge_left <= 0.05:
		hooks.undertow_recharge_left = hooks.undertow_recharge
	return true


static func on_wind_pull(source: Unit, victim: Unit) -> void:
	if source == null or victim == null or victim.team == source.team:
		return
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.undertow:
		return
	ThreatTable.add_threat(victim, source, 50.0, "undertow")


static func on_taken_hit(victim: Unit, source: Unit, absorbed: float, hp_hit: float) -> void:
	if victim == null:
		return
	var hooks := victim.talent_hooks()
	if hooks == null:
		return
	if absorbed > 0.05 and hooks.second_skin_heal > 0.05 and hooks.second_skin_icd <= 0.0:
		apply_channel_heal(victim, victim, hooks.second_skin_heal, AbilityDef.Element.PROTECTION, "second_skin")
		hooks.second_skin_icd = SECOND_SKIN_ICD
	if hooks.ironhide_left > 0.05 and hp_hit + absorbed > 0.05:
		victim.apply_shield(CombatBalance.flat("skill.ironhide.shield"), 6.0, victim)
	if source == null or source.team == victim.team:
		return
	if hooks.anointed and victim.holy_blessing_dr() > 0.001:
		if hooks.anointed_icd <= 0.0:
			apply_channel_heal(victim, victim, hooks.anointed_heal, AbilityDef.Element.HOLY, "anointed")
			hooks.anointed_icd = ANOINTED_ICD
		ThreatTable.add_threat(source, victim, hooks.anointed_threat, "anointed")
	_redirect_intercede(victim, source, hp_hit + absorbed)


static func on_shield_applied(caster: Unit, target: Unit, ab: AbilityDef, combat_text_cast_id: int = -1) -> void:
	if caster == null or target == null or ab == null:
		return
	if caster == target:
		return
	var hooks := caster.talent_hooks()
	if hooks == null or not hooks.shared_plate:
		return
	if not ab.has_element(AbilityDef.Element.PROTECTION):
		return
	if combat_text_cast_id >= 0:
		if hooks.shared_plate_cast_id == combat_text_cast_id:
			return
		hooks.shared_plate_cast_id = combat_text_cast_id
	else:
		var now := Time.get_ticks_msec()
		if now - hooks.shared_plate_msec < 250:
			return
		hooks.shared_plate_msec = now
	caster.apply_shield(hooks.shared_plate_shield if hooks.shared_plate_shield > 0.05 else 24.0, 6.0, caster)


static func on_wall_spawned(wall: SpellWall) -> void:
	if wall == null or wall.source == null:
		return
	var hooks := wall.source.talent_hooks()
	if hooks == null:
		return
	if hooks.wall_hp_pct > 0.0:
		wall.max_health *= 1.0 + hooks.wall_hp_pct
		wall.health = wall.max_health
	if hooks.palisade_duration > 0.0:
		wall.duration += hooks.palisade_duration
	if hooks.pavise and SpellWallLayout.style_id(wall.ability) == "protection":
		wall.duration = CombatBalance.flat("wall.protection.time") + 1.0


static func on_wall_hit(wall: SpellWall, amount: float) -> void:
	if wall == null or amount <= 0.05 or wall.source == null:
		return
	var hooks := wall.source.talent_hooks()
	if hooks == null or hooks.mortar <= 0.0:
		return
	apply_channel_heal(wall.source, wall.source, amount * hooks.mortar, _wall_heal_element(wall), "mortar")


static func _wall_heal_element(wall: SpellWall) -> int:
	if wall == null or wall.ability == null:
		return AbilityDef.Element.PROTECTION
	var ab: AbilityDef = wall.ability
	if ab.has_element(AbilityDef.Element.HOLY):
		return AbilityDef.Element.HOLY
	if ab.has_element(AbilityDef.Element.NATURE):
		return AbilityDef.Element.NATURE
	if ab.has_element(AbilityDef.Element.PROTECTION):
		return AbilityDef.Element.PROTECTION
	if ab.element != AbilityDef.Element.NONE:
		return ab.element
	return AbilityDef.Element.PROTECTION


static func tick_wall(wall: SpellWall, delta: float) -> void:
	if wall == null or not wall.living or wall.source == null:
		return
	var hooks := wall.source.talent_hooks()
	if hooks == null:
		return
	if hooks.battlement_rank > 0:
		var radius := 1.2
		if hooks.battlement_rank >= 2:
			radius += 2.5
		var proxy := wall.target_proxy()
		if proxy != null:
			for other in ArenaState.units_near(wall.global_position, radius + SpellWallLayout.length_of(wall.ability) * 0.5, false, true, true):
				var u := other as Unit
				if u == null or u.is_dead or u.team == wall.source.team:
					continue
				if EnemyRank.from_unit(u) != EnemyRank.Rank.NORMAL:
					continue
				ThreatTable.taunt(u, proxy, 1.25)
	_tick_bramble(wall, hooks, delta)


static func threat_dealt_mult(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return 1.0
	var mult := 1.0
	if hooks.rampage_left > 0.0:
		mult *= 1.50
	return mult


static func redirect_slice(source: Unit) -> float:
	if source == null or source.team != Unit.TEAM_RAID:
		return 0.0
	var best := 0.0
	for ally in ArenaState.living_team(source.team):
		var u := ally as Unit
		if u == null or u == source or u.is_dead:
			continue
		var hooks := u.talent_hooks()
		if hooks == null or hooks.redirect <= 0.0:
			continue
		if u.global_position.distance_to(source.global_position) > 8.0:
			continue
		best = maxf(best, hooks.redirect)
	return best


static func redirect_tank(source: Unit) -> Unit:
	if source == null:
		return null
	for ally in ArenaState.living_team(source.team):
		var u := ally as Unit
		if u == null or u == source or u.is_dead:
			continue
		var hooks := u.talent_hooks()
		if hooks == null or hooks.redirect <= 0.0:
			continue
		if u.global_position.distance_to(source.global_position) > 8.0:
			continue
		return u
	return null


static func _carries_fire(element: int, extras) -> bool:
	if element == AbilityDef.Element.FIRE:
		return true
	for extra in extras:
		if int(extra) == AbilityDef.Element.FIRE:
			return true
	return false


static func _carries_ice(element: int, extras) -> bool:
	if element == AbilityDef.Element.ICE:
		return true
	for extra in extras:
		if int(extra) == AbilityDef.Element.ICE:
			return true
	return false


static func _carries_shadow(element: int, extras) -> bool:
	if element == AbilityDef.Element.SHADOW:
		return true
	for extra in extras:
		if int(extra) == AbilityDef.Element.SHADOW:
			return true
	return false


static func _splash(source: Unit, origin: Unit, amount: float, radius: float, element: int, ability_id: String) -> void:
	if amount <= 0.05:
		return
	for other in ArenaState.units_near(origin.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u == origin or u.is_dead or u.team == source.team:
			continue
		u.receive_ability_hit(source, element, amount, 0.0, PackedInt32Array(), true, false, false, -1, 0, ability_id, -1, true)


static func _nearby_afflicted_enemy(victim: Unit) -> bool:
	for other in ArenaState.units_near(victim.global_position, PITCH_SKIN_RANGE, false, true, true):
		var u := other as Unit
		if u == null or u.team == victim.team or u.is_dead:
			continue
		if u.afflict_stacks() > 0:
			return true
	return false


static func _nearby_bodyguard(victim: Unit) -> float:
	if victim == null or victim.team != Unit.TEAM_RAID:
		return 0.0
	var best := 0.0
	for ally in ArenaState.living_team(victim.team):
		var u := ally as Unit
		if u == null or u == victim or u.is_dead:
			continue
		var hooks := u.talent_hooks()
		if hooks == null or hooks.bodyguard_dr <= 0.0:
			continue
		if u.global_position.distance_to(victim.global_position) > 6.0:
			continue
		if hooks.bodyguard_dr > best:
			best = hooks.bodyguard_dr
	return best


static func on_bodyguard_prevented(victim: Unit, prevented: float) -> void:
	if victim == null or prevented <= 0.05:
		return
	for ally in ArenaState.living_team(victim.team):
		var u := ally as Unit
		if u == null or u == victim or u.is_dead:
			continue
		var hooks := u.talent_hooks()
		if hooks == null or hooks.bodyguard_convert <= 0.0:
			continue
		if u.global_position.distance_to(victim.global_position) > 6.0:
			continue
		u.apply_shield(prevented * hooks.bodyguard_convert, 6.0, u)
		return


static func on_lightning_hop(source: Unit, victim: Unit) -> void:
	_on_bulwark_hit(source, victim, null, 1.0, false, "shock_chain")
	_on_feedback_hop(source, victim)


static func _on_bulwark_hit(source: Unit, victim: Unit, ab: AbilityDef, dealt: float, tick_hit: bool, ability_id: String) -> void:
	var hooks := source.talent_hooks() if source else null
	if hooks == null or victim == null or victim.team == source.team:
		return
	if hooks.live_wire and victim.has_shock() and not tick_hit and ability_id != "shock_chain":
		ThreatTable.add_threat(victim, source, 40.0, ability_id)
	if hooks.live_wire and ability_id == "shock_chain":
		ThreatTable.add_threat(victim, source, 18.0, "shock_chain")
	if hooks.goad and ab != null and ab.delivery == AbilityDef.Delivery.TARGET and ab.skill_id.is_empty():
		ThreatTable.taunt(victim, source, 3.0)
		if hooks.lunge:
			source.apply_haste(0.20, 2.0)
	if hooks.ire and dealt > 0.05 and not tick_hit:
		var threat := dealt * maxf(ab.threat_mult if ab != null else 1.0, 1.0) * threat_dealt_mult(source)
		var ratio := hooks.ire_ratio if hooks.ire_ratio > 0.05 else 0.18
		var cap := hooks.ire_cap if hooks.ire_cap > 0.05 else 40.0
		source.apply_shield(minf(cap, threat * ratio), 6.0, source)


static func _tick_undertow(unit: Unit, hooks: TalentHooks, delta: float) -> void:
	if hooks == null or not hooks.undertow:
		return
	if hooks.undertow_charges >= hooks.undertow_charge_max:
		hooks.undertow_recharge_left = 0.0
		return
	if hooks.undertow_recharge_left <= 0.05:
		hooks.undertow_recharge_left = hooks.undertow_recharge
	hooks.undertow_recharge_left = maxf(0.0, hooks.undertow_recharge_left - delta)
	if hooks.undertow_recharge_left > 0.05:
		return
	hooks.undertow_charges = mini(hooks.undertow_charge_max, hooks.undertow_charges + 1)
	if hooks.undertow_charges < hooks.undertow_charge_max:
		hooks.undertow_recharge_left = hooks.undertow_recharge


static func _redirect_intercede(victim: Unit, attacker: Unit, amount: float) -> void:
	if victim == null or amount <= 0.05:
		return
	for ally in ArenaState.living_team(victim.team):
		var u := ally as Unit
		if u == null or u == victim or u.is_dead:
			continue
		var hooks := u.talent_hooks()
		if hooks == null or hooks.intercede_left <= 0.05:
			continue
		if hooks.intercede_target_id != victim.get_instance_id():
			continue
		var share := hooks.intercede_share if hooks.intercede_share > 0.05 else 0.30
		var bounced := amount * share
		if bounced > 0.05:
			u.take_damage(bounced, attacker, Color(0.78, 0.86, 1.0), "hit", "intercede", false, true)
		return


static func _carries_storm(element: int, extras) -> bool:
	if element == AbilityDef.Element.STORM:
		return true
	for extra in extras:
		if int(extra) == AbilityDef.Element.STORM:
			return true
	return false


static func _carries_nature(element: int, extras) -> bool:
	if element == AbilityDef.Element.NATURE:
		return true
	for extra in extras:
		if int(extra) == AbilityDef.Element.NATURE:
			return true
	return false


static func _heal_is_nature(source: Unit, ability_id: String) -> bool:
	var base := AbilityDef.base_from_combat_id(ability_id)
	if base == "rejuvenation" or base == "nature" or base == "flourish" or base == "worldroot" or base == "lifebloom" or base == "photosynthesis":
		return true
	if source == null or ability_id.is_empty():
		return false
	var ab := source._ability_def(ability_id)
	return ab != null and ab.has_element(AbilityDef.Element.NATURE)


static func nature_target_heal_mult(source: Unit, target: Unit, ability_id: String) -> float:
	if source == null or target == null:
		return 1.0
	var hooks := source.talent_hooks()
	if hooks == null or hooks.overgrowth <= 0.0:
		return 1.0
	if target.rejuv_stacks() < Unit.REJUV_STACK_MAX:
		return 1.0
	if not _heal_is_nature(source, ability_id):
		return 1.0
	return 1.0 + hooks.overgrowth


static func pulse_ratio(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.tempest_bloom_left > 0.05:
		return 0.50
	var base := CombatBalance.pct("rejuvenation.pulse")
	if hooks == null:
		return base
	return base + hooks.pulse_ratio_bonus


static func pulse_range(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return 8.5
	return hooks.pulse_range


static func tempest_bloom_pulses(source: Unit, element: int, extras) -> bool:
	var hooks := source.talent_hooks() if source else null
	if hooks == null or hooks.tempest_bloom_left <= 0.05:
		return false
	return _carries_storm(element, extras)


static func blocks_rejuvenation(source: Unit) -> bool:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return false
	if hooks.eye_storm_left > 0.05:
		return true
	if hooks.drought_left > 0.05 and not hooks.drought_rejuv_only:
		return true
	return false


static func drought_blocks_rejuv_apply(source: Unit, ability_id: String = "") -> bool:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return false
	var base := AbilityDef.base_from_combat_id(ability_id)
	if base == "germinate" or base == "worldroot" or base == "nature":
		return false
	if hooks.eye_storm_left > 0.05:
		return true
	return hooks.drought_left > 0.05


static func rejuvenation_stacks_to_apply(source: Unit, ability_id: String) -> int:
	var n := 1
	var hooks := source.talent_hooks() if source else null
	if hooks == null or not hooks.deep_roots:
		return n
	var base := AbilityDef.base_from_combat_id(ability_id)
	if base == "bolt" or base == "ray":
		return 2
	return n


static func on_rejuvenation_applied(source: Unit, target: Unit, had_stacks: int, _ability_id: String) -> void:
	if source == null or target == null:
		return
	var hooks := source.talent_hooks()
	if hooks == null:
		return
	if had_stacks > 0 and hooks.photosynthesis_heal > 0.05:
		target.apply_heal(hooks.photosynthesis_heal, source, "photosynthesis")


static func on_nature_support(source: Unit, target: Unit, ability_id: String, combat_text_cast_id: int) -> void:
	if source == null or target == null or target.team != source.team:
		return
	var hooks := source.talent_hooks()
	if hooks == null:
		return
	var ab := source._ability_def(ability_id)
	if hooks.lifebloom_hps > 0.05 and ab != null and ab.delivery == AbilityDef.Delivery.TARGET and ab.has_element(AbilityDef.Element.NATURE):
		target.apply_lifebloom(source, hooks.lifebloom_hps, 8.0, hooks.lifebloom_bloom)
		hooks.lifebloom_target_id = target.get_instance_id()
	if hooks.stormbond:
		_bind_stormbond(source, target)
	if hooks.germinate_shield > 0.05 and ab != null and ab.delivery == AbilityDef.Delivery.GROUND_AOE and ab.has_element(AbilityDef.Element.NATURE):
		var key := "%d:%d" % [combat_text_cast_id, target.get_instance_id()]
		if not hooks.germinate_seen.has(key):
			hooks.germinate_seen[key] = true
			target.apply_shield(hooks.germinate_shield, 4.0, source)
			if hooks.germinate_rejuv > 0:
				for _i in hooks.germinate_rejuv:
					target.apply_rejuvenation(source, 1, "germinate")
	if hooks.tempest_bloom_left > 0.05:
		_shock_nearest(source, 3, 12.0)


static func pulse_allies(source: Unit, dealt: float) -> Array[Unit]:
	var out: Array[Unit] = []
	if source == null:
		return out
	var hooks := source.talent_hooks()
	var reach := pulse_range(source)
	if hooks != null and hooks.stormbond:
		_prune_stormbond(hooks)
		for id in hooks.stormbond_ids:
			var found = instance_from_id(id)
			if found is Unit and is_instance_valid(found) and not (found as Unit).is_dead:
				out.append(found as Unit)
		if not out.is_empty():
			return out
	var lowest: Unit = null
	var lowest_hp := INF
	for other in ArenaState.units_near(source.global_position, reach, false, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team != source.team:
			continue
		out.append(u)
		if u.health < lowest_hp:
			lowest = u
			lowest_hp = u.health
	if hooks != null and hooks.stormbond and out.is_empty() == false and lowest != null:
		_bind_stormbond(source, lowest)
		return [lowest] as Array[Unit]
	if hooks != null and hooks.stormbond and lowest != null:
		_bind_stormbond(source, lowest)
		return [lowest] as Array[Unit]
	return out


static func _bind_stormbond(source: Unit, target: Unit) -> void:
	var hooks := source.talent_hooks()
	if hooks == null or target == null:
		return
	var id := target.get_instance_id()
	if hooks.stormbond_ids.has(id):
		target.apply_stormbond(source, 8.0)
		return
	while hooks.stormbond_ids.size() >= maxi(hooks.stormbond_cap, 1):
		var old_id: int = hooks.stormbond_ids[0]
		hooks.stormbond_ids.remove_at(0)
		var old = instance_from_id(old_id)
		if old is Unit and is_instance_valid(old):
			(old as Unit).clear_stormbond_from(source)
	hooks.stormbond_ids.append(id)
	target.apply_stormbond(source, 8.0)


static func _prune_stormbond(hooks: TalentHooks) -> void:
	if hooks == null:
		return
	var keep: Array[int] = []
	for id in hooks.stormbond_ids:
		var found = instance_from_id(id)
		if found is Unit and is_instance_valid(found) and (found as Unit).has_stormbond():
			keep.append(id)
	hooks.stormbond_ids = keep


static func _shock_nearest(source: Unit, stacks: int, reach: float) -> void:
	var best: Unit = null
	var best_d := reach
	for other in ArenaState.units_near(source.global_position, reach, false, true, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team == source.team:
			continue
		var d := source.global_position.distance_to(u.global_position)
		if d < best_d:
			best = u
			best_d = d
	if best != null:
		best.apply_shock(source, stacks)


static func _on_storm_druid_hit(source: Unit, victim: Unit, element: int, extras, dealt: float, tick_hit: bool) -> void:
	if source == null or victim == null or victim.team == source.team:
		return
	var hooks := source.talent_hooks()
	if hooks == null:
		return
	if hooks.seedstorm_stacks > 0 and _carries_storm(element, extras) and _carries_nature(element, extras):
		UnitEnemyAlter.apply_seeded_stacks(victim, source, hooks.seedstorm_stacks, tick_hit)


static func _on_feedback_hop(source: Unit, victim: Unit) -> void:
	if source == null or victim == null:
		return
	var hooks := source.talent_hooks()
	if hooks == null or not hooks.feedback:
		return
	source._pulse_rejuvenation(maxf(victim.shock_stacks(), 1.0))


static func _on_storm_druid_death(victim: Unit) -> void:
	if victim == null or victim.shock_stacks() < 50:
		return
	var killer := victim.shock_source()
	if killer == null:
		return
	var hooks := killer.talent_hooks()
	if hooks == null or not hooks.static_explode:
		return
	_splash(killer, victim, 45.0, 3.6, AbilityDef.Element.STORM, "static")


static func shock_stacks_on_hit(source: Unit, ability_id: String, tick_hit: bool) -> int:
	if AbilityDef.matches_base(ability_id, "shock_chain"):
		return 0
	var n := 1
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.charge_coil > 0 and not tick_hit:
		n = hooks.charge_coil
	return n


static func shock_chain_hops(source: Unit) -> int:
	var hops := Unit.SHOCK_CHAIN_HOPS
	var hooks := source.talent_hooks() if source else null
	if hooks != null:
		hops += hooks.arc_hops
	if StormCloudZone.contains_caster(source):
		hops += 1
	return hops


static func shock_chain_range(source: Unit) -> float:
	var reach := Unit.SHOCK_CHAIN_RANGE
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.arc_range > 0.0:
		reach += hooks.arc_range
	return reach


static func chain_hop_mult_for(source: Unit, hop: int) -> float:
	if StormCloudZone.contains_caster(source):
		return 1.0
	return CombatBalance.chain_hop_mult(hop)


static func totem_first_hop_pct(source: Unit) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks != null and hooks.totem_hop_pct > 0.05:
		return hooks.totem_hop_pct
	var ratio := CombatBalance.pct("wall.damage")
	if ratio < 0.01:
		return 0.40
	return ratio


static func totem_shock_stacks(source: Unit) -> int:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return 0
	return hooks.totem_shock


static func nature_zone_heal_mult(source: Unit, from_wall: bool) -> float:
	var hooks := source.talent_hooks() if source else null
	if hooks == null:
		return 1.0
	if from_wall and hooks.loam > 0.0:
		return 1.0 + hooks.loam
	return 1.0


static func ringward_cut(victim: Unit) -> float:
	if victim == null:
		return 0.0
	for wall in SpellWall.living_walls():
		if wall == null or wall.source == null:
			continue
		var hooks := wall.source.talent_hooks()
		if hooks == null or not hooks.ringward:
			continue
		if SpellWallLayout.style_id(wall.ability) != "nature":
			continue
		if _ally_in_nature_ring(wall, victim):
			return 0.08
	return 0.0


static func heartwood_taken(target: Unit) -> float:
	if target == null:
		return 0.0
	for wall in SpellWall.living_walls():
		if wall == null or wall.source == null:
			continue
		var hooks := wall.source.talent_hooks()
		if hooks == null or hooks.heartwood <= 0.0:
			continue
		if SpellWallLayout.style_id(wall.ability) != "nature":
			continue
		if _ally_in_nature_ring(wall, target):
			return hooks.heartwood
	return 0.0


static func _ally_in_nature_ring(wall: SpellWall, u: Unit) -> bool:
	if wall == null or u == null or u.team != wall.source.team:
		return false
	var rad := SpellWallLayout.nature_radius(wall.ability)
	var to := u.global_position - wall.global_position
	to.y = 0.0
	return to.length() <= rad + u.radius


static func _tick_bramble(wall: SpellWall, hooks: TalentHooks, delta: float) -> void:
	if hooks.bramble_dps <= 0.05:
		return
	if SpellWallLayout.style_id(wall.ability) != "nature":
		return
	wall.bramble_acc += delta
	var pulse := false
	if wall.bramble_acc >= 1.0:
		wall.bramble_acc -= 1.0
		pulse = true
	wall.bramble_root_acc += delta
	var do_root := hooks.bramble_root and wall.bramble_root_acc >= 2.0
	if do_root:
		wall.bramble_root_acc -= 2.0
	if not pulse and not do_root:
		return
	for other in ArenaState.units_near(wall.global_position, SpellWallLayout.query_radius(wall.ability), false, true, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team == wall.source.team:
			continue
		if not wall.unit_on_hedge(u):
			continue
		if pulse:
			u.take_damage(hooks.bramble_dps, wall.source, _DamageNumber.tint_for("nature"), "nature", "bramble", false, true, -1, true)
		if do_root:
			u.apply_rooted(0.3)


static func _burn_source(victim: Unit) -> Unit:
	return victim.burn_source()


static func _steam_patch(caster: Unit, point: Vector3, duration: float) -> void:
	var ab := AbilityDef.make("fumarole_steam", "Steam", "Q", AbilityDef.TargetMode.GROUND, 0.0, 0.0, 0.0, STEAM_TICK, Color(0.85, 0.78, 0.72))
	ab.delivery = AbilityDef.Delivery.GROUND_AOE
	ab.element = AbilityDef.Element.FIRE
	ab.extra_elements = PackedInt32Array([AbilityDef.Element.ICE])
	ab.aoe_radius = 2.2
	ab.zone_duration = duration
	ab.tick_interval = 0.5
	ab.tick_damage = STEAM_TICK
	ab.implemented = true
	GroundAoeZone.spawn(caster, point, ab, ab.extra_elements, ab.aoe_radius, -1)


const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
