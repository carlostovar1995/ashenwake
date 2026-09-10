class_name StatusReactions
extends Object

## Effect-on-effect riders. These fire from statuses on the target, not from
## dual-infusion recipes. Transfer scales with the origin's Charge ratio
## (stacks / cap). Spread copies replace the previous snapshot and cannot
## ride a later chain. DoT ticks must not call shock-chain copy.
## Shatter pulses use ability ids that begin with "shatter" so they cannot
## refill a Frozen neighbor's hidden shell.


static func on_shock_chain(origin: Unit, hops: Array[Unit], source: Unit) -> void:
	if origin == null or not is_instance_valid(origin) or hops.size() < 2:
		return
	if source == null or not is_instance_valid(source):
		return
	var charge := origin.shock_charge_ratio()
	if charge <= 0.0:
		return
	var remaining := origin.spreadable_burn_remaining()
	var chill := origin.spreadable_chill_stacks()
	var afflict := origin.spreadable_afflict_stacks()
	if remaining <= 0.05 and chill <= 0 and afflict <= 0:
		return
	var burn_ratio := CombatBalance.pct("flashover.ratio") * charge
	var burn_time := CombatBalance.flat("flashover.time")
	var chill_frac := CombatBalance.pct("conductive.chill.frac") * charge
	var chill_cap := maxi(int(round(CombatBalance.flat("conductive.chill.cap"))), 1)
	var afflict_frac := CombatBalance.pct("voidarc.afflict.frac") * charge
	var afflict_cap := maxi(int(round(CombatBalance.flat("voidarc.afflict.cap"))), 1)
	for i in range(1, hops.size()):
		var hop := hops[i]
		if hop == null or not is_instance_valid(hop) or hop.is_dead:
			continue
		var hop_mult := CombatBalance.chain_hop_mult(i - 1)
		if remaining > 0.05 and burn_ratio > 0.0 and burn_time > 0.05:
			var slice := remaining * burn_ratio * hop_mult
			if slice > 0.05:
				hop.apply_spread_burn(source, slice, burn_time, origin)
		if chill > 0 and chill_frac > 0.0:
			var chill_copy := mini(int(floor(float(chill) * chill_frac * hop_mult)), chill_cap)
			if chill_copy > 0:
				hop.apply_spread_chill(chill_copy)
		if afflict > 0 and afflict_frac > 0.0:
			var afflict_hop := mini(int(floor(float(afflict) * afflict_frac * hop_mult)), afflict_cap)
			if afflict_hop > 0:
				hop.apply_spread_afflict(source, afflict_hop)


static func on_shatter_break(
	origin: Unit,
	source: Unit,
	fire_wins: bool,
	fire_contrib: float,
	shadow_contrib: float,
	combat_text_cast_id: int
) -> void:
	if origin == null or not is_instance_valid(origin):
		return
	if source == null or not is_instance_valid(source):
		return
	if fire_wins:
		_pulse_fire_shatter(origin, source, fire_contrib, combat_text_cast_id)
	else:
		_pulse_shadow_shatter(origin, source, shadow_contrib, combat_text_cast_id)


static func _pulse_fire_shatter(origin: Unit, source: Unit, fire_contrib: float, combat_text_cast_id: int) -> void:
	var explosion := fire_contrib * CombatBalance.flat("shatter.mult")
	if explosion <= 0.05:
		return
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, origin.global_position, {
		"scale": 0.55,
		"lifetime": 1.1,
		"primary_color": Color(1.0, 0.92, 0.42),
		"secondary_color": Color(1.0, 0.42, 0.08),
		"tertiary_color": Color(0.62, 0.08, 0.22),
	})
	if not origin.is_dead:
		origin.receive_ability_hit(
			source,
			AbilityDef.Element.FIRE,
			explosion,
			0.0,
			PackedInt32Array(),
			true,
			false,
			false,
			-1,
			0,
			"shatter_fire",
			combat_text_cast_id,
			true
		)
	var splash := explosion * CombatBalance.pct("shatter.frostburst")
	_pulse_shatter_neighbors(
		origin,
		source,
		AbilityDef.Element.FIRE,
		splash,
		"shatter_fire_burst",
		combat_text_cast_id,
		0
	)


static func _pulse_shadow_shatter(origin: Unit, source: Unit, shadow_contrib: float, combat_text_cast_id: int) -> void:
	var explosion := shadow_contrib * CombatBalance.flat("shatter.shadow.mult")
	if explosion <= 0.05:
		return
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, origin.global_position, {
		"scale": 0.55,
		"lifetime": 1.1,
		"primary_color": Color(0.78, 0.42, 1.0),
		"secondary_color": Color(0.28, 0.08, 0.42),
		"tertiary_color": Color(0.55, 0.88, 1.0),
	})
	var afflict_copy := _shatter_afflict_copy(origin)
	if not origin.is_dead:
		origin.receive_ability_hit(
			source,
			AbilityDef.Element.SHADOW,
			explosion,
			0.0,
			PackedInt32Array(),
			true,
			false,
			false,
			-1,
			0,
			"shatter_shadow",
			combat_text_cast_id,
			true
		)
	var splash := explosion * CombatBalance.pct("shatter.frostburst")
	_pulse_shatter_neighbors(
		origin,
		source,
		AbilityDef.Element.ICE,
		splash,
		"shatter_frostburst",
		combat_text_cast_id,
		afflict_copy
	)


static func _shatter_afflict_copy(origin: Unit) -> int:
	var stacks: int = origin.afflict_display_stacks()
	if stacks <= 0:
		return 0
	var frac := CombatBalance.pct("shatter.afflict.frac")
	var cap := maxi(int(round(CombatBalance.flat("shatter.afflict.cap"))), 1)
	return mini(int(floor(float(stacks) * frac)), cap)


static func _pulse_shatter_neighbors(
	origin: Unit,
	source: Unit,
	element: int,
	raw: float,
	ability_id: String,
	combat_text_cast_id: int,
	afflict_copy: int
) -> void:
	if raw <= 0.05 and afflict_copy <= 0:
		return
	var radius := CombatBalance.flat("shatter.frostburst.radius")
	for other in ArenaState.units_near(origin.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u == origin or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == source.team:
			continue
		if raw > 0.05:
			u.receive_ability_hit(
				source,
				element,
				raw,
				0.0,
				PackedInt32Array(),
				true,
				false,
				false,
				-1,
				0,
				ability_id,
				combat_text_cast_id,
				true
			)
		if afflict_copy > 0:
			u.apply_afflict_stacks(source, afflict_copy)
