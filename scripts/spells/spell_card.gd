class_name SpellCard
extends Object

const _BODY := Color(0.90, 0.92, 0.96)
const _GOLD := Color(1.0, 0.84, 0.38)
const _UP := Color(0.42, 0.88, 0.52)
const _DOWN := Color(1.0, 0.52, 0.48)
const _COLORS := {
	AbilityDef.Element.FIRE: Color(1.0, 0.45, 0.12),
	AbilityDef.Element.ICE: Color(0.45, 0.82, 1.0),
	AbilityDef.Element.STORM: Color(0.78, 0.68, 1.0),
	AbilityDef.Element.SHADOW: Color(0.72, 0.42, 1.0),
	AbilityDef.Element.NATURE: Color(0.38, 0.82, 0.42),
	AbilityDef.Element.HOLY: Color(0.95, 0.84, 0.38),
	AbilityDef.Element.PROTECTION: Color(0.72, 0.82, 0.98),
	AbilityDef.Element.WIND: Color(0.72, 0.92, 0.82),
	AbilityDef.Element.ILLUSION: Color(0.92, 0.55, 0.82),
}
const _NOUNS := {
	AbilityDef.Element.FIRE: "fire",
	AbilityDef.Element.ICE: "frost",
	AbilityDef.Element.STORM: "lightning",
	AbilityDef.Element.SHADOW: "shadow",
	AbilityDef.Element.NATURE: "nature",
	AbilityDef.Element.HOLY: "divine",
	AbilityDef.Element.PROTECTION: "protection",
	AbilityDef.Element.WIND: "wind",
	AbilityDef.Element.ILLUSION: "illusion",
}


static func bbcode(ab: AbilityDef, recipe: SpellRecipe = null) -> String:
	return _render(ab, recipe, true, true)


static func plain(ab: AbilityDef, recipe: SpellRecipe = null) -> String:
	return _render(ab, recipe, false, true)


static func hud(ab: AbilityDef, recipe: SpellRecipe = null) -> String:
	return _render(ab, recipe, false, false)


static func piece_tooltip(kind: String, id: String, rich: bool = false) -> String:
	match kind:
		"base":
			var recipe := SpellRecipe.make(id)
			var ab := SpellCompiler.compile(recipe, "Q")
			if ab == null:
				return ""
			var body := _render(ab, recipe, rich, false)
			return "%s\n%s" % [_paint(ab.display_name, _GOLD, rich), body]
		"infusion":
			return _infusion_piece_tooltip(id, rich)
		"augment":
			return _augment_piece_tooltip(id, rich)
	return ""


static func _infusion_piece_tooltip(id: String, rich: bool) -> String:
	var inf := SpellCatalog.get_infusion(id)
	if inf == null:
		return ""
	var tint: Color = inf.color.lightened(0.12)
	var lines := PackedStringArray([_paint(inf.display_name, _GOLD, rich)])
	var bits := _infusion_bits(inf, null)
	if not bits.is_empty():
		lines.append("")
		for bit in bits:
			lines.append(_paint(bit, tint, rich))
	if not inf.description.is_empty():
		lines.append("")
		lines.append(_paint(inf.description, tint, rich))
	return "\n".join(lines)


static func _augment_piece_tooltip(id: String, rich: bool) -> String:
	var aug := SpellCatalog.get_augment(id)
	if aug == null:
		return ""
	var lines := PackedStringArray([_paint(aug.display_name, _GOLD, rich)])
	if not aug.description.is_empty():
		lines.append("")
		lines.append(aug.description)
	var bits := _augment_bits(aug)
	if not bits.is_empty():
		lines.append("")
		for bit in bits:
			if bit == aug.description:
				continue
			lines.append(_paint(bit, _change_color(bit), rich))
	return "\n".join(lines)


static func _change_color(bit: String) -> Color:
	var plus := bit.begins_with("+")
	var minus := bit.begins_with("-") or bit.begins_with("−")
	var costish := bit.find("CD") >= 0 or bit.find("mana") >= 0 or bit.find("threat") >= 0 or bit.find("cast time") >= 0
	if costish:
		if plus:
			return _DOWN
		if minus:
			return _UP
	if plus:
		return _UP
	if minus:
		return _DOWN
	return _BODY


static func sections(ab: AbilityDef, recipe: SpellRecipe = null, rich: bool = true) -> Dictionary:
	var out := {
		"flavor": "",
		"lock": "",
		"hit": "",
		"resist": "",
		"costs": PackedStringArray(),
		"infusion_note": "",
		"infusions": PackedStringArray(),
		"augments": PackedStringArray(),
	}
	if ab == null:
		return out
	var bare := _bare_ability(ab, recipe)
	out["flavor"] = _flavor(ab, recipe)
	out["lock"] = _lock_line(ab)
	out["hit"] = ""
	out["resist"] = ""
	out["costs"] = _stat_lines(ab, bare, rich)
	var ids := recipe.infusion_ids if recipe != null else ab.infusion_ids
	if not ids.is_empty() and not SpellPower.skips_infusion_damage(ab):
		var n := 0
		for id in ids:
			if SpellCatalog.get_infusion(id) != null:
				n += 1
		if n > 0:
			out["infusion_note"] = _to_base_value(CombatBalance.pct("infusion.base") * float(n))
	out["infusions"] = _infusions(ab, recipe, rich)
	out["augments"] = _augments(recipe, rich)
	return out


static func _render(ab: AbilityDef, recipe: SpellRecipe, rich: bool, show_infusions: bool) -> String:
	var parts := sections(ab, recipe, rich)
	var lines: PackedStringArray = PackedStringArray()
	var flavor := String(parts.get("flavor", ""))
	if not flavor.is_empty():
		lines.append(flavor)
	var lock := String(parts.get("lock", ""))
	if not lock.is_empty():
		if not flavor.is_empty():
			lines.append("")
		lines.append(lock)
	var stats: PackedStringArray = parts.get("costs", PackedStringArray())
	if not stats.is_empty():
		if not flavor.is_empty() or not lock.is_empty():
			lines.append("")
		for line in stats:
			lines.append(String(line))
	if show_infusions:
		var infusions: PackedStringArray = parts.get("infusions", PackedStringArray())
		var note := String(parts.get("infusion_note", ""))
		if not infusions.is_empty() or not note.is_empty():
			lines.append("")
			lines.append(_paint("Infusions:", _GOLD, rich))
			if not note.is_empty():
				lines.append(note)
			lines.append("")
			for line in infusions:
				lines.append(String(line))
	var augments: PackedStringArray = parts.get("augments", PackedStringArray())
	if not augments.is_empty():
		lines.append("")
		lines.append(_paint("Augments:", _GOLD, rich))
		lines.append("")
		for line in augments:
			lines.append(String(line))
	return "\n".join(lines)


static func _bare_ability(ab: AbilityDef, recipe: SpellRecipe) -> AbilityDef:
	if recipe == null or recipe.base_id.is_empty():
		return null
	var hotkey := ab.hotkey if ab != null and not ab.hotkey.is_empty() else "Q"
	return SpellCompiler.compile(SpellRecipe.make(recipe.base_id), hotkey)


static func _primary_amount(ab: AbilityDef) -> int:
	if ab == null:
		return 0
	var total := 0
	for row in SpellPower.preview_slices(ab):
		if not (row is Dictionary):
			continue
		total += int(round(float(row.get("amount", 0.0))))
	return total


static func _delta_color(current: float, original: float, higher_is_better: bool) -> Color:
	if is_equal_approx(current, original):
		return _BODY
	var higher := current > original
	var better := higher if higher_is_better else not higher
	return _UP if better else _DOWN


static func _with_original(current_text: String, current_color: Color, original_text: String, rich: bool, changed: bool) -> String:
	if not changed:
		return _paint(current_text, current_color, rich)
	return "%s%s" % [_paint(current_text, current_color, rich), _paint(" (Original: %s)" % original_text, _BODY, rich)]


static func _stat_lines(ab: AbilityDef, bare: AbilityDef, rich: bool) -> PackedStringArray:
	var lines := PackedStringArray()
	for line in _power_lines(ab, bare, rich):
		lines.append(line)
	var resist := _shield_resist_line(ab, rich)
	if not resist.is_empty():
		lines.append(resist)
	var cd_now := _cd(ab)
	var cd_was := _cd(bare) if bare != null else cd_now
	var cd_color := _delta_color(_cd_seconds(ab), _cd_seconds(bare) if bare != null else _cd_seconds(ab), false)
	lines.append(_with_original("Cooldown: %s" % cd_now, cd_color, cd_was, rich, cd_now != cd_was))
	var cast_now := _cast_time_value(ab)
	if cast_now >= 0.0:
		var cast_was := _cast_time_value(bare) if bare != null else cast_now
		var cast_color := _delta_color(cast_now, cast_was, false)
		var cast_text := "Cast time: Instant" if cast_now <= 0.001 else "Cast time: %s" % _secs(cast_now)
		var cast_orig := "Instant" if cast_was <= 0.001 else _secs(cast_was)
		lines.append(_with_original(cast_text, cast_color, cast_orig, rich, not is_equal_approx(cast_now, cast_was)))
	var channel_now := _channel_value(ab)
	if channel_now > 0.05:
		var channel_was := _channel_value(bare) if bare != null else channel_now
		var channel_color := _delta_color(channel_now, channel_was, true)
		lines.append(_with_original("Channel duration: %s" % _secs(channel_now), channel_color, _secs(channel_was), rich, not is_equal_approx(channel_now, channel_was)))
	var mana_now := _mana_value(ab)
	var mana_was := _mana_value(bare) if bare != null else mana_now
	var mana_color := _delta_color(mana_now, mana_was, false)
	lines.append(_with_original("Cost: %s" % _cost_value(ab), mana_color, _cost_value(bare) if bare != null else _cost_value(ab), rich, not is_equal_approx(mana_now, mana_was)))
	var range_now := WorldMeasure.format(_range_value(ab))
	if not range_now.is_empty():
		var range_was := WorldMeasure.format(_range_value(bare)) if bare != null else range_now
		var range_color := _delta_color(_range_value(ab), _range_value(bare) if bare != null else _range_value(ab), true)
		lines.append(_with_original("Range: %s" % range_now, range_color, range_was, rich, range_now != range_was))
	var area_now := WorldMeasure.format(_area_value(ab))
	if not area_now.is_empty():
		var area_was := WorldMeasure.format(_area_value(bare)) if bare != null else area_now
		var area_color := _delta_color(_area_value(ab), _area_value(bare) if bare != null else _area_value(ab), true)
		lines.append(_with_original("Area: %s" % area_now, area_color, area_was, rich, area_now != area_was))
	return lines


static func _power_lines(ab: AbilityDef, bare: AbilityDef, rich: bool) -> PackedStringArray:
	var dmg := PackedStringArray()
	var heal := PackedStringArray()
	var shield := PackedStringArray()
	var dmg_tick := false
	var heal_tick := false
	var shield_tick := false
	var dmg_total := 0
	for row in SpellPower.preview_slices(ab):
		if not (row is Dictionary):
			continue
		var amount := int(round(float(row.get("amount", 0.0))))
		if amount <= 0:
			continue
		var verb := String(row.get("verb", "damage"))
		var painted := _paint(str(amount), _color(int(row.get("element", AbilityDef.Element.NONE))), rich)
		if verb.begins_with("healing"):
			heal.append(painted)
			if verb.find("per tick") >= 0:
				heal_tick = true
		elif verb.begins_with("shield"):
			shield.append(painted)
			if verb.find("per tick") >= 0:
				shield_tick = true
		else:
			dmg.append(painted)
			dmg_total += amount
			if verb.find("per tick") >= 0:
				dmg_tick = true
	var orig := _primary_amount(bare)
	var lines := PackedStringArray()
	var dmg_line := _labeled_power("Base damage", dmg, dmg_tick)
	if not dmg_line.is_empty():
		if orig > 0 and orig != dmg_total:
			dmg_line = "%s%s" % [dmg_line, _paint(" (Original: %d)" % orig, _BODY, rich)]
		lines.append(dmg_line)
	var heal_line := _labeled_power("Base healing", heal, heal_tick)
	if not heal_line.is_empty():
		lines.append(heal_line)
	var shield_line := _labeled_power("Shield", shield, shield_tick)
	if not shield_line.is_empty():
		lines.append(shield_line)
	return lines


static func _labeled_power(label: String, parts: PackedStringArray, per_tick: bool) -> String:
	if parts.is_empty():
		return ""
	var body := " + ".join(parts)
	if per_tick:
		return "%s: %s per tick" % [label, body]
	return "%s: %s" % [label, body]


static func _cast_time_value(ab: AbilityDef) -> float:
	if ab == null:
		return -1.0
	if ab.is_channel and ab.cast_time <= 0.001:
		return -1.0
	return maxf(ab.cast_time, 0.0)


static func _channel_value(ab: AbilityDef) -> float:
	if ab == null or not ab.is_channel:
		return 0.0
	return ab.channel_time


static func _cost_value(ab: AbilityDef) -> String:
	if ab == null:
		return "0 mana"
	var n := int(round(ab.mana_cost))
	if ab.cost_per_tick:
		return "%d mana per tick" % n
	return "%d mana" % n


static func _flavor(ab: AbilityDef, recipe: SpellRecipe) -> String:
	var base_id := ""
	if recipe != null and not recipe.base_id.is_empty():
		base_id = recipe.base_id
	elif ab != null:
		base_id = ab.id
	var base := SpellCatalog.get_base(base_id)
	if base == null:
		return ""
	return base.description


static func _lock_line(ab: AbilityDef) -> String:
	if ab == null or not ab.locks_unit_target():
		return ""
	if ab.can_target_allies() and ab.can_target_enemies():
		return "Locks allies or enemies"
	if ab.can_target_allies():
		return "Locks allies"
	if ab.can_target_enemies():
		return "Locks enemies"
	return ""


static func _range_value(ab: AbilityDef) -> float:
	if ab == null or ab.range <= 0.05:
		return 0.0
	return ab.range


static func _area_value(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	if ab.aoe_radius > 0.05:
		return ab.aoe_radius
	if ab.splash_radius > 0.05:
		return ab.splash_radius
	if ab.delivery == AbilityDef.Delivery.WAVE and ab.skillshot_width > 0.05:
		return ab.skillshot_width
	return 0.0


static func _cd_seconds(ab: AbilityDef) -> float:
	if ab == null or ab.cooldown <= 0.05:
		return 0.0
	return ab.cooldown


static func _mana_value(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	return ab.mana_cost


static func _shield_resist_line(ab: AbilityDef, rich: bool) -> String:
	if ab == null or ab.shield <= 0.05:
		return ""
	var els := SpellPower.elements_for(ab)
	if els.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for el in els:
		var noun := String(_NOUNS.get(el, ""))
		if not noun.is_empty():
			names.append(noun)
	if names.is_empty():
		return ""
	var pct := int(round(CombatBalance.pct("shield.resist") * 100.0))
	return _paint("%d%% %s resist." % [pct, " / ".join(names)], _BODY, rich)


static func _cd(ab: AbilityDef) -> String:
	if ab.cooldown <= 0.05:
		return "none"
	if is_equal_approx(ab.cooldown, roundf(ab.cooldown)):
		return "%ds" % int(round(ab.cooldown))
	return "%0.1fs" % ab.cooldown


static func _infusions(ab: AbilityDef, recipe: SpellRecipe, rich: bool) -> PackedStringArray:
	var ids := recipe.infusion_ids if recipe != null else ab.infusion_ids
	var lines: PackedStringArray = PackedStringArray()
	for id in ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf == null:
			continue
		var bits := _infusion_bits(inf, ab)
		if bits.is_empty():
			continue
		var stats := ", ".join(bits)
		if rich:
			lines.append(_paint(stats, inf.color.lightened(0.12), true))
		else:
			lines.append("%s - %s" % [inf.display_name, stats])
	if ab != null and not ab.pierces_skillshot() and SpellPower.ghosts_enemies(ab) and ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		var ghost := "passes through enemies"
		if rich:
			lines.append(_paint(ghost, _BODY, true))
		else:
			lines.append(ghost)
	return lines


static func _augments(recipe: SpellRecipe, rich: bool) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if recipe == null:
		return lines
	for id in recipe.augment_ids:
		var aug := SpellCatalog.get_augment(id)
		if aug == null:
			continue
		var bits := _augment_bits(aug)
		var body := "%s - %s" % [aug.display_name, ", ".join(bits)]
		lines.append(_paint(body, _BODY, rich))
	return lines


static func _secs(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return "%ds" % int(roundf(v))
	var hundredths: float = snappedf(v, 0.01)
	if is_equal_approx(hundredths, snappedf(v, 0.1)):
		return "%0.1fs" % v
	return "%0.2fs" % hundredths


static func _infusion_stat_bits(inf: SpellInfusion, ab: AbilityDef = null) -> PackedStringArray:
	var bits: PackedStringArray = PackedStringArray()
	var base_bits: PackedStringArray = PackedStringArray()
	if inf.offensive and not is_equal_approx(inf.damage_mult, 1.0) and (ab == null or not SpellPower.skips_infusion_damage(ab)):
		base_bits = _push_unique(base_bits, _to_base_value(inf.damage_mult - 1.0))
	if not is_equal_approx(inf.heal_mult, 1.0):
		base_bits = _push_unique(base_bits, _to_base_value(inf.heal_mult - 1.0))
	if inf.shield_from_base > 0.02:
		base_bits = _push_unique(base_bits, _to_base_value(inf.shield_from_base - 1.0))
	for bit in base_bits:
		bits.append(bit)
	if not is_equal_approx(inf.cooldown_mult, 1.0):
		bits.append("%s%% CD" % _signed_pct(inf.cooldown_mult - 1.0))
	return bits


static func _infusion_bits(inf: SpellInfusion, ab: AbilityDef = null) -> PackedStringArray:
	var bits := _infusion_stat_bits(inf, ab)
	match inf.id:
		"fire":
			bits.append("inflicts burn")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("ground fire line, not solid")
				bits.append(
					"shots through it deal +%d fire"
					% int(round(CombatBalance.flat("wall.fire.bonus")))
				)
				bits.append(
					"enemies on or through it take +%d fire per second"
					% int(round(CombatBalance.flat("wall.fire.bonus")))
				)
		"ice":
			bits.append("inflicts chilled")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("one ice capsule, shared HP")
				bits.append("ground frost around it at Burst range")
				bits.append(
					"break deals %d%% of wall HP in that range"
					% int(round(CombatBalance.flat("wall.ice.break") * 100.0))
				)
				bits.append("enemy to both teams")
		"lightning":
			bits.append("inflicts shock")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("small lightning totem")
				bits.append(
					"chains to the nearest enemy every %.1fs"
					% CombatBalance.flat("wall.lightning.tick")
				)
				bits.append("%d hops" % int(round(CombatBalance.flat("wall.lightning.hops"))))
				bits.append(
					"first hit deals %d%% of the totem's current HP"
					% int(round(CombatBalance.pct("wall.damage") * 100.0))
				)
				bits.append(
					"%d%% less each bounce"
					% int(round(CombatBalance.pct("lightning.chain.falloff") * 100.0))
				)
				bits.append("friendly allied wall")
				bits.append("friendly shots pass through")
		"wind":
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append(
					"%d%% longer"
					% int(round((CombatBalance.flat("wall.wind.length") - 1.0) * 100.0))
				)
				bits.append("no HP, units walk through")
				bits.append("catches enemy shots, then flings them back")
				bits.append("friendly shots pass through")
			elif ab != null:
				match ab.delivery:
					AbilityDef.Delivery.BOLT:
						bits.append("knockback")
					AbilityDef.Delivery.MISSILES:
						bits.append("snares")
					AbilityDef.Delivery.RAY:
						bits.append("pushes the target")
					AbilityDef.Delivery.WAVE:
						bits.append("thicker and slower")
					AbilityDef.Delivery.GROUND_AOE:
						bits.append("yanks enemies in, then vanishes")
					AbilityDef.Delivery.AOE_EXPLOSION:
						bits.append("knockup")
					AbilityDef.Delivery.METEOR:
						bits.append("knockback")
					AbilityDef.Delivery.NOVA:
						bits.append("knockback, stronger at the center")
					AbilityDef.Delivery.AURA:
						bits.append("haste on allies")
					AbilityDef.Delivery.TARGET:
						bits.append("haste on allies")
					_:
						pass
		"shadow":
			bits.append("inflicts afflict")
			bits.append("1 damage per stack each second")
			bits.append("each hit adds 1 stack")
			bits.append("200 stacks: +20% damage taken")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("%d HP" % int(round(CombatBalance.flat("wall.shadow.hp"))))
				bits.append(
					"break afflicts %d stacks on enemy NPCs in a massive range"
					% int(round(CombatBalance.flat("wall.shadow.stacks")))
				)
				bits.append("enemy to both teams")
		"nature":
			bits.append("inflicts rejuvenation")
			bits.append(
				"+%d HPS per stack, refreshes"
				% int(round(CombatBalance.flat("rejuvenation.hps")))
			)
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("ring of walls, %d HP shared" % int(round(CombatBalance.flat("wall.nature.hp"))))
				bits.append("heals and rejuvenates allies inside")
				bits.append("break heals everyone in the ring")
				bits.append("units walk over")
				bits.append(
					"enemies on a wall move at %d%% speed"
					% int(round((1.0 - CombatBalance.pct("wall.nature.slow")) * 100.0))
				)
				bits.append("friendly allied wall")
				bits.append("blocks all projectiles")
				bits.append("%ds" % int(round(CombatBalance.flat("wall.nature.time"))))
		"divine":
			bits.append("grants Holy Blessing")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("large bubble")
				bits.append(
					"allies inside take %d%% less damage"
					% int(round(CombatBalance.pct("wall.divine.dr") * 100.0))
				)
				bits.append("%ds" % int(round(CombatBalance.flat("wall.divine.time"))))
		"protection":
			bits.append("can target allies")
			if ab != null and ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("curved shield on you")
				bits.append("blocks all projectiles")
				bits.append("infinite HP")
				bits.append("channel %ds, can move" % int(round(CombatBalance.flat("wall.protection.time"))))
				bits.append(
					"recast to turn the shield (%.1fs for 180°)"
					% CombatBalance.flat("wall.protection.turn")
				)
				bits.append("you move %d%% slower" % int(round(CombatBalance.pct("wall.protection.slow") * 100.0)))
		"illusion":
			if ab != null and ab.delivery == AbilityDef.Delivery.RAY and ab.has_element(AbilityDef.Element.WIND):
				bits.append("knocks enemies away from the impact")
			if ab == null:
				pass
			elif ab.delivery == AbilityDef.Delivery.WALL:
				bits.append("cylinder portals")
				bits.append("recast to place an exit portal")
				bits.append("recast up to 3 times to move the exit")
				bits.append("first portal absorbs projectiles")
				bits.append("exit shoots them out the far side at the same angle")
				bits.append("enemy shots that exit become yours and only hit enemies")
				bits.append("shots keep damage, effects, and look")
				bits.append("lasts 8s")
				bits.append("new pair replaces the last two portals")
			else:
				match ab.delivery:
					AbilityDef.Delivery.BOLT:
						bits.append(
							"5 shots at ±%d°/±%d°, half bolt damage"
							% [
								int(round(CombatBalance.flat("illusion.bolt.inner"))),
								int(round(CombatBalance.flat("illusion.bolt.angle"))),
							]
						)
					AbilityDef.Delivery.MISSILES:
						bits.append("extra targets in Burst radius also get a volley")
					AbilityDef.Delivery.GROUND_AOE:
						bits.append("2 far fields at 80–120% size")
					AbilityDef.Delivery.AOE_EXPLOSION:
						bits.append(
							"%.1fs echoes"
							% CombatBalance.flat("illusion.burst.delay")
						)
					AbilityDef.Delivery.AURA:
						bits.append(
							"rings +%d%%"
							% int(round(CombatBalance.pct("illusion.aura.range") * 100.0))
						)
					AbilityDef.Delivery.RAY:
						bits.append("beam bounces")
					AbilityDef.Delivery.METEOR:
						bits.append(
							"%d-meteor line, %d%% smaller"
							% [
								int(round(CombatBalance.flat("illusion.meteor.count"))),
								int(round(absf(CombatBalance.pct("illusion.meteor.radius")) * 100.0)),
							]
						)
					AbilityDef.Delivery.NOVA:
						bits.append("short-range ground AOE")
					_:
						pass
	if inf.beneficial and inf.id != "protection":
		bits.append("can target allies")
	return bits


static func _augment_bits(aug: SpellAugment) -> PackedStringArray:
	var bits: PackedStringArray = PackedStringArray()
	if not is_equal_approx(aug.cooldown_mult, 1.0):
		bits.append("%s%% CD" % _signed_pct(aug.cooldown_mult - 1.0))
	if not is_equal_approx(aug.mana_mult, 1.0):
		bits.append("%s%% mana" % _signed_pct(aug.mana_mult - 1.0))
	if not is_equal_approx(aug.range_mult, 1.0):
		bits.append("%s%% range" % _signed_pct(aug.range_mult - 1.0))
	if not is_equal_approx(aug.area_mult, 1.0):
		bits.append("%s%% area" % _signed_pct(aug.area_mult - 1.0))
	if aug.id == "haste" and aug.cast_time_mult > 0.001:
		bits.append("%s%% cast speed" % _signed_pct((1.0 / aug.cast_time_mult) - 1.0))
	elif not is_equal_approx(aug.cast_time_mult, 1.0):
		bits.append("%s%% cast time" % _signed_pct(aug.cast_time_mult - 1.0))
	if aug.instant_cast:
		bits.append("no cast time")
	if aug.echo:
		bits.append("echo at %d%% damage" % int(round(aug.echo_damage_mult * 100.0)))
	if not is_equal_approx(aug.crit_chance_mult, 1.0):
		bits.append("%s%% crit chance" % _signed_pct(aug.crit_chance_mult - 1.0))
	if aug.crit_damage > 0.05:
		bits.append("crits deal %d%%" % int(round(aug.crit_damage * 100.0)))
	if aug.recast:
		bits.append("recast at %d%% damage" % int(round(aug.recast_damage_mult * 100.0)))
	if aug.move_while_casting:
		bits.append("move while casting")
	if aug.altered:
		bits.append("ally buff from an offensive infusion")
	if aug.exclusive or aug.extra_infusions > 0:
		bits.append("third infusion, exclusive")
	if not is_equal_approx(aug.threat_mult, 1.0):
		if aug.threat_mult > 1.0:
			if is_equal_approx(aug.threat_mult, roundf(aug.threat_mult)):
				bits.append("%d× threat" % int(roundf(aug.threat_mult)))
			else:
				bits.append("%0.1f× threat" % aug.threat_mult)
		else:
			bits.append("%d%% threat" % int(round(aug.threat_mult * 100.0)))
	if bits.is_empty() and not aug.description.is_empty():
		bits.append(aug.description)
	return bits


static func _to_base_value(frac: float) -> String:
	return "%s%% to base value" % _signed_pct(frac)


static func _push_unique(bits: PackedStringArray, phrase: String) -> PackedStringArray:
	for existing in bits:
		if existing == phrase:
			return bits
	bits.append(phrase)
	return bits


static func _signed_pct(frac: float) -> String:
	var n := int(round(frac * 100.0))
	if n > 0:
		return "+%d" % n
	return str(n)


static func _color(element: int) -> Color:
	return _COLORS.get(element, _BODY)


static func _paint(text: String, color: Color, rich: bool) -> String:
	if not rich:
		return text
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]
