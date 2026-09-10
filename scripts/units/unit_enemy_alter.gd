class_name UnitEnemyAlter
extends Object

const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const PROC_SEED_SPLASH := "seed_splash"
const PROC_SEED_BLOOM := "seed_bloom"
const PROC_JUDGE_MEND := "judge_mend"
const PROC_SUNDER_BREAK := "sunder_break"


static func is_proc(ability_id: String) -> bool:
	var key := AbilityDef.base_from_combat_id(ability_id)
	return key == PROC_SEED_SPLASH or key == PROC_SEED_BLOOM or key == PROC_JUDGE_MEND or key == PROC_SUNDER_BREAK


static func buff_time() -> float:
	return CombatBalance.flat("altered.support.time")


static func seed_max() -> int:
	return maxi(int(round(CombatBalance.flat("altered.nature.max"))), 1)


static func judged_max() -> int:
	return maxi(int(round(CombatBalance.flat("altered.divine.max"))), 1)


static func sunder_max() -> int:
	return maxi(int(round(CombatBalance.flat("altered.protection.max"))), 1)


static func snare_cut(u: Unit) -> float:
	if u == null or u._seed_stacks <= 0 or u._seed_left <= 0.05:
		return 0.0
	return clampf(CombatBalance.pct("altered.nature.snare") * float(u._seed_stacks), 0.0, 0.9)


static func outgoing_mult(u: Unit) -> float:
	if u == null or u._sunder_stacks <= 0 or u._sunder_left <= 0.05:
		return 1.0
	return maxf(0.0, 1.0 - CombatBalance.pct("altered.protection.out") * float(u._sunder_stacks))


static func taken_mult(u: Unit, element: int) -> float:
	if u == null or element != AbilityDef.Element.HOLY:
		return 1.0
	if u._judged_stacks <= 0 or u._judged_left <= 0.05:
		return 1.0
	return 1.0 + CombatBalance.pct("altered.divine.taken") * float(u._judged_stacks)


static func on_ability_hit(target: Unit, source: Unit, ab: AbilityDef, element: int, extras: Array, tick_hit: bool, crit: bool = false) -> void:
	if target == null or target.is_dead or target.is_structure:
		return
	if source != null and target.team == source.team:
		return
	if _hit_carries(element, extras, AbilityDef.Element.FIRE) and not tick_hit:
		_fire_consume(target, source)
	if ab == null or not ab.altered:
		return
	var n := Unit.crit_status_stacks(1, crit)
	if _hit_carries(element, extras, AbilityDef.Element.NATURE):
		for _i in n:
			_apply_seeded(target, source, tick_hit)
	if _hit_carries(element, extras, AbilityDef.Element.HOLY):
		for _i in n:
			_apply_judged(target, tick_hit)
	if _hit_carries(element, extras, AbilityDef.Element.PROTECTION):
		for _i in n:
			_apply_sundered(target, tick_hit)


static func on_taken_hit(victim: Unit, source: Unit, landed: float, absorbed: float, ability_id: String) -> void:
	if victim == null or victim.is_dead:
		return
	if landed > 0.05 and not AbilityDef.matches_base(ability_id, PROC_JUDGE_MEND):
		_mend(victim, source, landed)
	if absorbed > 0.05 and source != null and not AbilityDef.matches_base(ability_id, PROC_SUNDER_BREAK):
		_sunder_break(source, victim, absorbed)


static func tick(u: Unit, delta: float) -> void:
	if u == null:
		return
	if u._seed_left > 0.0:
		u._seed_left = maxf(0.0, u._seed_left - delta)
		if u._seed_left <= 0.0:
			clear_seeded(u)
	if u._judged_left > 0.0:
		u._judged_left = maxf(0.0, u._judged_left - delta)
		if u._judged_left <= 0.0:
			clear_judged(u)
	if u._sunder_left > 0.0:
		u._sunder_left = maxf(0.0, u._sunder_left - delta)
		if u._sunder_left <= 0.0:
			clear_sundered(u)


static func clear_all(u: Unit) -> void:
	clear_seeded(u)
	clear_judged(u)
	clear_sundered(u)


static func apply_seeded_stacks(target: Unit, source: Unit, stacks: int, tick_hit: bool) -> void:
	if target == null or stacks <= 0:
		return
	for _i in stacks:
		_apply_seeded(target, source, tick_hit)


static func clear_seeded(u: Unit) -> void:
	u._seed_stacks = 0
	u._seed_left = 0.0
	u._seed_src = null


static func clear_judged(u: Unit) -> void:
	u._judged_stacks = 0
	u._judged_left = 0.0


static func clear_sundered(u: Unit) -> void:
	u._sunder_stacks = 0
	u._sunder_left = 0.0


static func _apply_seeded(target: Unit, source: Unit, tick_hit: bool) -> void:
	var dur := buff_time()
	if tick_hit:
		if target._seed_stacks > 0:
			target._seed_left = dur
		return
	var cap := seed_max()
	if target._seed_stacks + 1 >= cap:
		_bloom(target, source)
		return
	target._seed_stacks = mini(target._seed_stacks + 1, cap)
	target._seed_left = dur
	if source != null and is_instance_valid(source):
		target._seed_src = source


static func _apply_judged(target: Unit, tick_hit: bool) -> void:
	var dur := buff_time()
	if tick_hit:
		if target._judged_stacks > 0:
			target._judged_left = dur
		return
	target._judged_stacks = mini(target._judged_stacks + 1, judged_max())
	target._judged_left = dur


static func _apply_sundered(target: Unit, tick_hit: bool) -> void:
	var dur := buff_time()
	if tick_hit:
		if target._sunder_stacks > 0:
			target._sunder_left = dur
		return
	target._sunder_stacks = mini(target._sunder_stacks + 1, sunder_max())
	target._sunder_left = dur


static func _fire_consume(target: Unit, source: Unit) -> void:
	if target._seed_stacks <= 0 or target._seed_left <= 0.05:
		return
	var owner := target._seed_src if target._seed_src != null and is_instance_valid(target._seed_src) else source
	target._seed_stacks -= 1
	if target._seed_stacks <= 0:
		clear_seeded(target)
	if owner == null:
		return
	var dmg := CombatBalance.scaled_hit("altered.nature.splash")
	var radius := CombatBalance.flat("altered.nature.splash_radius")
	for raw in ArenaState.units_near(target.global_position, radius, false, true, true):
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == owner.team:
			continue
		u.take_damage(dmg, owner, _DamageNumber.tint_for("nature"), "nature", PROC_SEED_SPLASH, false, false, -1, false)


static func _bloom(target: Unit, source: Unit) -> void:
	var owner := target._seed_src if target._seed_src != null and is_instance_valid(target._seed_src) else source
	clear_seeded(target)
	if owner == null or target.is_dead:
		return
	var dmg := CombatBalance.scaled_hit("altered.nature.bloom")
	target.take_damage(dmg, owner, _DamageNumber.tint_for("nature"), "nature", PROC_SEED_BLOOM, false, false, -1, false)
	if is_instance_valid(owner) and not owner.is_dead:
		owner._pulse_rejuvenation(dmg)


static func _mend(victim: Unit, source: Unit, landed: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	if victim._judged_stacks <= 0 or victim._judged_left <= 0.05:
		return
	var div := maxf(CombatBalance.flat("altered.divine.mend_div"), 0.01)
	var amt := (landed / div) * float(victim._judged_stacks)
	if amt <= 0.05:
		return
	var ally := _lowest_hp_ally_near(victim, source.team, CombatBalance.flat("altered.divine.range"))
	if ally == null:
		return
	ally.apply_heal(amt, source, PROC_JUDGE_MEND, {}, -1, false, false, "divine")


static func _sunder_break(attacker: Unit, shielded: Unit, absorbed: float) -> void:
	if attacker._sunder_stacks <= 0 or attacker._sunder_left <= 0.05:
		return
	attacker._sunder_stacks -= 1
	if attacker._sunder_stacks <= 0:
		clear_sundered(attacker)
	var dmg := absorbed * CombatBalance.pct("altered.protection.break")
	if dmg <= 0.05:
		return
	attacker.take_damage(dmg, shielded, _DamageNumber.tint_for("protection"), "protection", PROC_SUNDER_BREAK, false, false, -1, false)


static func _lowest_hp_ally_near(from: Unit, team: int, radius: float) -> Unit:
	var best: Unit = null
	var best_ratio := 2.0
	for raw in ArenaState.units_near(from.global_position, radius, false, true, true):
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u.is_structure:
			continue
		if u.team != team:
			continue
		var ratio := u.health / maxf(u.max_health, 1.0)
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


static func _hit_carries(element: int, extras: Array, want: int) -> bool:
	if element == want:
		return true
	for extra in extras:
		if int(extra) == want:
			return true
	return false
