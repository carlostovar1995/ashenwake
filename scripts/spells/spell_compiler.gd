class_name SpellCompiler
extends Object

const _COMPOUNDS := {
	"fire|ice": "Frostfire",
	"ice|fire": "Frostfire",
	"fire|lightning": "Stormfire",
	"lightning|fire": "Stormfire",
	"ice|lightning": "Stormfrost",
	"lightning|ice": "Stormfrost",
	"fire|shadow": "Shadowflame",
	"shadow|fire": "Shadowflame",
	"ice|shadow": "Shadeice",
	"shadow|ice": "Shadeice",
	"lightning|shadow": "Voidstorm",
	"shadow|lightning": "Voidstorm",
	"fire|nature": "Wildfire",
	"nature|fire": "Wildfire",
	"ice|nature": "Winterbloom",
	"nature|ice": "Winterbloom",
	"lightning|nature": "Tempestbloom",
	"nature|lightning": "Tempestbloom",
	"shadow|nature": "Blightbloom",
	"nature|shadow": "Blightbloom",
	"fire|divine": "Holyfire",
	"divine|fire": "Holyfire",
	"ice|divine": "Holyfrost",
	"divine|ice": "Holyfrost",
	"lightning|divine": "Holystorm",
	"divine|lightning": "Holystorm",
	"shadow|divine": "Twilight",
	"divine|shadow": "Twilight",
	"nature|divine": "Sanctuary",
	"divine|nature": "Sanctuary",
	"fire|protection": "Warding Fire",
	"protection|fire": "Warding Fire",
	"ice|protection": "Warding Ice",
	"protection|ice": "Warding Ice",
	"lightning|protection": "Warding Storm",
	"protection|lightning": "Warding Storm",
	"shadow|protection": "Warding Shade",
	"protection|shadow": "Warding Shade",
	"nature|protection": "Warding Bloom",
	"protection|nature": "Warding Bloom",
	"divine|protection": "Aegis",
	"protection|divine": "Aegis",
}


static func compile_loadout(loadout: Array) -> Array[AbilityDef]:
	return ChampionLoadout.compile(loadout, null)


static func compile(recipe: SpellRecipe, hotkey: String = "Q") -> AbilityDef:
	if recipe == null:
		recipe = SpellRecipe.make("bolt")
	else:
		# Compilation normalizes a private working copy; previews must not mutate
		# the recipe currently being edited or persisted by GameSession.
		var source := recipe
		recipe = SpellRecipe.new()
		recipe.base_id = source.base_id
		recipe.infusion_ids = source.infusion_ids.duplicate()
		recipe.augment_ids = source.augment_ids.duplicate()
	recipe.base_id = SpellCatalog.migrate_base_id(recipe.base_id)
	var augs := PackedStringArray()
	for raw in recipe.augment_ids:
		var aug_id := SpellCatalog.migrate_augment_id(String(raw).strip_edges())
		if aug_id.is_empty() or SpellCatalog.get_augment(aug_id) == null or augs.has(aug_id):
			continue
		augs.append(aug_id)
	recipe.augment_ids = augs
	recipe.normalize()
	recipe.infusion_ids = _migrated_infusions(recipe.infusion_ids, recipe.infusion_cap())
	var base := SpellCatalog.get_base(recipe.base_id)
	var infusions: Array[SpellInfusion] = []
	for id in recipe.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf:
			infusions.append(inf)
	var augments: Array[SpellAugment] = []
	for id in recipe.augment_ids:
		if not SpellCatalog.augment_fits(recipe.base_id, id):
			continue
		var aug := SpellCatalog.get_augment(id)
		if aug:
			augments.append(aug)
	var ab := AbilityDef.make(base.id, _display_name(base, infusions), hotkey, base.target_mode, base.mana_cost, base.cooldown, base.range, base.damage, base.color)
	_copy_base(ab, base)
	_apply_craft_layers(ab, base, infusions, augments)
	ab.display_name = _display_name(base, infusions)
	ab.description = _description(base, infusions, augments, ab)
	ab.icon_id = _icon_id(base, infusions)
	ab.icon_infusion_tag = _icon_infusion_tag(infusions)
	# Toggle cooldown is anti-spam lockout after turning off, not a spell CD.
	if base.is_toggle:
		ab.cooldown = base.cooldown
		ab.gcd_exempt = true
	return ab


static func compile_slot(recipe: SpellRecipe, hotkey: String = "Q") -> AbilityDef:
	if recipe != null and SpellCatalog.is_class_skill(recipe.base_id):
		return compile_skill(recipe.base_id, recipe, hotkey)
	if recipe == null or recipe.base_id.is_empty():
		return ClassSkillCompiler.empty_slot(hotkey)
	return compile(recipe, hotkey)


static func compile_skill(skill_id: String, overlay: SpellRecipe, hotkey: String = "D") -> AbilityDef:
	var ab := ClassSkillCompiler.compile(skill_id, hotkey)
	if skill_id.is_empty():
		return ab
	var base := SpellCatalog.skill_as_base(skill_id)
	if base == null:
		return ab
	var recipe := SpellRecipe.new()
	recipe.base_id = skill_id
	if overlay != null:
		recipe.augment_ids = overlay.augment_ids.duplicate()
	var augs := PackedStringArray()
	for raw in recipe.augment_ids:
		var aug_id := SpellCatalog.migrate_augment_id(String(raw).strip_edges())
		if aug_id.is_empty() or SpellCatalog.get_augment(aug_id) == null or augs.has(aug_id):
			continue
		augs.append(aug_id)
	recipe.augment_ids = augs
	recipe.infusion_ids = PackedStringArray()
	recipe.normalize()
	var empty_infusions: Array[SpellInfusion] = []
	var augments: Array[SpellAugment] = []
	for id in recipe.augment_ids:
		if not SpellCatalog.augment_fits(skill_id, id):
			continue
		var aug := SpellCatalog.get_augment(id)
		if aug:
			augments.append(aug)
	if augments.is_empty():
		return ab
	var keep_skill := ab.skill_id
	var keep_help := ab.can_help_allies
	var keep_friendly := ab.friendly_only
	var keep_heal := ab.heal_allies
	var keep_gcd := ab.gcd_exempt
	var keep_name := ab.display_name
	var keep_icon := ab.icon_id
	_apply_augments(ab, augments)
	_apply_duration_augments(ab, augments)
	ab.skill_id = keep_skill
	ab.can_help_allies = keep_help
	ab.friendly_only = keep_friendly
	ab.heal_allies = keep_heal
	ab.gcd_exempt = keep_gcd
	ab.display_name = keep_name
	ab.icon_id = keep_icon
	ab.icon_infusion_tag = ""
	ab.description = _description(base, empty_infusions, augments, ab)
	return ab


static func _apply_craft_layers(ab: AbilityDef, base: SpellBase, infusions: Array[SpellInfusion], augments: Array[SpellAugment]) -> void:
	_apply_infusions(ab, base, infusions, _keep_support_alter_damage(infusions, augments))
	_apply_augments(ab, augments)
	_apply_wind_ground_aoe(ab, infusions)
	_apply_wind_wave(ab)
	_apply_illusion(ab)
	if ab.delivery == AbilityDef.Delivery.WALL and (ab.has_element(AbilityDef.Element.NATURE) or ab.has_infusion("nature")):
		ab.zone_duration = CombatBalance.flat("wall.nature.time")
	if ab.delivery == AbilityDef.Delivery.WALL and (ab.has_element(AbilityDef.Element.HOLY) or ab.has_infusion("divine")):
		ab.zone_duration = CombatBalance.flat("wall.divine.time")
	_apply_protection_wall(ab)
	_apply_duration_augments(ab, augments)
	_apply_ally_flags(ab, infusions, augments)


static func preview_name(recipe: SpellRecipe) -> String:
	if recipe == null:
		return "Empty"
	var base := SpellCatalog.get_base(recipe.base_id)
	var infusions: Array[SpellInfusion] = []
	for id in recipe.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf:
			infusions.append(inf)
	return _display_name(base, infusions)


static func _copy_base(ab: AbilityDef, base: SpellBase) -> void:
	ab.heal = base.heal
	ab.shield = base.shield
	ab.shield_duration = base.shield_duration
	ab.cast_time = base.cast_time
	ab.skillshot_width = base.skillshot_width
	ab.skillshot_speed = base.skillshot_speed
	ab.skillshot_length = base.skillshot_length
	ab.aoe_radius = base.aoe_radius
	ab.aoe_radius_max = base.aoe_radius_max
	ab.damage_max = base.damage_max
	ab.splash_radius = base.splash_radius
	ab.splash_ratio = base.splash_ratio
	ab.cone_angle = base.cone_angle
	ab.chain_bounces = base.chain_bounces
	ab.bounce_range = base.bounce_range
	ab.bounce_delay = base.bounce_delay
	ab.is_channel = base.is_channel
	ab.channel_time = base.channel_time
	ab.zone_duration = base.zone_duration
	ab.tick_interval = base.tick_interval
	ab.tick_damage = base.tick_damage
	ab.tick_shield = base.tick_shield
	ab.gcd_exempt = base.gcd_exempt
	ab.vfx_scene = base.vfx_scene
	ab.vfx_scale = base.vfx_scale
	ab.vfx_yaw = base.vfx_yaw
	ab.vfx_primary = base.vfx_primary
	ab.vfx_secondary = base.vfx_secondary
	ab.vfx_tertiary = base.vfx_tertiary
	ab.delivery = base.delivery
	ab.cost_per_tick = base.cost_per_tick
	ab.is_toggle = base.is_toggle
	ab.friendly_only = base.friendly_only
	ab.can_help_allies = false
	ab.altered = false
	ab.altered_element = AbilityDef.Element.NONE
	ab.move_while_casting = false
	ab.infusion_ids = PackedStringArray()
	ab.implemented = base.available
	ab.can_freeze = false
	ab.projectile_count = 1
	ab.pierce = false
	ab.lifesteal = 0.0
	ab.execute_health_frac = 0.0
	ab.execute_damage_mult = 1.0
	ab.hit_cooldown_reduction = 0.0
	ab.hit_cooldown_refund_cap = 0.0
	ab.planted = false
	ab.detonate_on_end = 0.0
	ab.crowd_bonus = 0.0
	ab.crowd_bonus_cap = 0.0
	ab.stillness_bonus = 0.0
	ab.base_power = maxf(base.damage, maxf(base.tick_damage, base.heal))
	ab.crit_chance = 0.05
	ab.crit_damage = 2.0
	ab.echo = false
	ab.recast_window = 0.0


static func _migrated_infusions(ids: PackedStringArray, cap: int = SpellRecipe.DEFAULT_INFUSIONS) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	var limit := clampi(cap, 0, SpellRecipe.MAX_INFUSIONS)
	for raw in ids:
		var id := SpellCatalog.migrate_infusion_id(String(raw).strip_edges())
		if not SpellCatalog.infusion_becomes_augment(id).is_empty():
			continue
		if id.is_empty() or seen.has(id) or SpellCatalog.get_infusion(id) == null:
			continue
		if out.size() >= limit:
			continue
		seen[id] = true
		out.append(id)
	return out


static func _value_basis(base: SpellBase) -> float:
	if base.damage > 0.05:
		return base.damage
	if base.tick_damage > 0.05:
		return base.tick_damage
	return maxf(base.heal, 0.0)


static func _is_altered_augment(aug: SpellAugment) -> bool:
	return aug != null and (aug.altered or aug.id == "altered" or aug.id == "alteration")


static func _is_support_alter_element(el: int) -> bool:
	return el == AbilityDef.Element.NATURE or el == AbilityDef.Element.HOLY or el == AbilityDef.Element.PROTECTION


static func _keep_support_alter_damage(infusions: Array[SpellInfusion], augments: Array[SpellAugment]) -> bool:
	var has_altered := false
	for aug in augments:
		if _is_altered_augment(aug):
			has_altered = true
			break
	if not has_altered:
		return false
	for inf in infusions:
		if inf != null and _is_support_alter_element(inf.element):
			return true
	return false


static func _apply_infusions(ab: AbilityDef, base: SpellBase, infusions: Array[SpellInfusion], keep_damage: bool = false) -> void:
	var extras := PackedInt32Array()
	var pulse := 0.0
	var cooldown_mult := 1.0
	var cast_time_mult := 1.0
	var has_protection := false
	ab.split_elements = PackedInt32Array()
	ab.split_damage_inc = PackedFloat32Array()
	ab.split_heal_inc = PackedFloat32Array()
	ab.split_shield_inc = PackedFloat32Array()
	ab.split_flat = PackedFloat32Array()
	var has_base_shield := base.shield > 0.05
	for i in infusions.size():
		var inf: SpellInfusion = infusions[i]
		cooldown_mult *= inf.cooldown_mult
		cast_time_mult *= inf.cast_time_mult
		if inf.shield_from_base > 0.02:
			has_protection = true
		ab.split_elements.append(inf.element)
		ab.split_damage_inc.append(0.0 if inf.beneficial else inf.damage_mult - 1.0)
		ab.split_heal_inc.append(inf.heal_mult - 1.0)
		ab.split_shield_inc.append(_shield_inc(inf, has_base_shield))
		ab.split_flat.append(0.0)
		if i == 0:
			ab.element = inf.element
			ab.color = inf.color
			ab.vfx_primary = inf.vfx_primary
			ab.vfx_secondary = inf.vfx_secondary
			ab.vfx_tertiary = inf.vfx_tertiary
		else:
			extras.append(inf.element)
			ab.color = ab.color.lerp(inf.color, 0.45)
			ab.vfx_primary = ab.vfx_primary.lerp(inf.vfx_primary, 0.5)
			ab.vfx_secondary = ab.vfx_secondary.lerp(inf.vfx_secondary, 0.5)
			ab.vfx_tertiary = ab.vfx_tertiary.lerp(inf.vfx_tertiary, 0.5)
		ab.infusion_ids.append(inf.id)
		if inf.heal_allies:
			ab.heal_allies = true
		if inf.applies_rejuvenation:
			ab.applies_rejuvenation = true
		pulse = maxf(pulse, inf.holy_pulse_ratio)
	if ab.heal <= 0.05 and ab.heal_allies:
		var heal_from := ab.damage if ab.damage > 0.05 else ab.tick_damage
		if heal_from > 0.05:
			ab.heal = heal_from
	var any_offensive := false
	for inf in infusions:
		if inf.offensive:
			any_offensive = true
			break
	if not any_offensive and not infusions.is_empty() and not keep_damage:
		ab.damage = 0.0
		ab.tick_damage = 0.0
	if not base.is_toggle:
		ab.cooldown *= cooldown_mult
	ab.cast_time *= cast_time_mult
	if has_protection:
		if ab.shield <= 0.05:
			ab.shield = _value_basis(base)
		if ab.shield_duration <= 0.05:
			ab.shield_duration = 6.0
	ab.extra_elements = extras
	SpellVfxSlots.apply(ab, base, infusions)
	ab.holy_pulse_ratio = pulse
	if ab.can_freeze:
		var has_frost := ab.element == AbilityDef.Element.ICE
		for extra in extras:
			if extra == AbilityDef.Element.ICE:
				has_frost = true
		ab.can_freeze = has_frost


static func _apply_wind_ground_aoe(ab: AbilityDef, infusions: Array[SpellInfusion]) -> void:
	if ab == null or ab.delivery != AbilityDef.Delivery.GROUND_AOE:
		return
	if not ab.has_element(AbilityDef.Element.WIND):
		return
	var radius_keep := CombatBalance.flat("wind.ground.radius")
	ab.aoe_radius *= radius_keep
	ab.aoe_radius_max *= radius_keep
	var ticks := 1.0
	if ab.zone_duration > 0.05 and ab.tick_interval > 0.05:
		ticks = maxf(1.0, ab.zone_duration / ab.tick_interval)
	var other := false
	for inf in infusions:
		if inf != null and inf.id != "wind":
			other = true
			break
	if other:
		var keep := CombatBalance.pct("wind.ground.dump")
		if ab.tick_damage > 0.05:
			ab.tick_damage *= ticks * keep
		if ab.heal > 0.05:
			ab.heal *= ticks * keep
		if ab.shield > 0.05:
			ab.shield *= ticks * keep
		if ab.base_power > 0.05:
			ab.base_power *= ticks * keep
	ab.zone_duration = CombatBalance.flat("wind.ground.time")


static func _apply_wind_wave(ab: AbilityDef) -> void:
	if ab == null or ab.delivery != AbilityDef.Delivery.WAVE:
		return
	if not ab.has_element(AbilityDef.Element.WIND):
		return
	ab.skillshot_speed *= CombatBalance.flat("wind.wave.speed")
	ab.skillshot_width *= CombatBalance.flat("wind.wave.width")
	ab.vfx_scale *= CombatBalance.flat("wind.wave.width")


static func _apply_illusion(ab: AbilityDef) -> void:
	if ab == null or not (ab.has_element(AbilityDef.Element.ILLUSION) or ab.has_infusion("illusion")):
		return
	if ab.delivery == AbilityDef.Delivery.BOLT:
		ab.damage *= 1.0 + CombatBalance.pct("illusion.bolt.damage")
	if ab.delivery == AbilityDef.Delivery.AURA:
		ab.aoe_radius *= 1.0 + CombatBalance.pct("illusion.aura.range")
		ab.aoe_radius_max *= 1.0 + CombatBalance.pct("illusion.aura.range")
		ab.inner_radius = ab.aoe_radius * CombatBalance.pct("illusion.aura.inner")
		ab.inner_radius *= 1.0 + CombatBalance.pct("illusion.aura.inner.push")
	if ab.delivery == AbilityDef.Delivery.METEOR:
		ab.aoe_radius *= 1.0 + CombatBalance.pct("illusion.meteor.radius")
		ab.aoe_radius_max *= 1.0 + CombatBalance.pct("illusion.meteor.radius")
	if ab.delivery == AbilityDef.Delivery.NOVA:
		ab.target_mode = AbilityDef.TargetMode.GROUND
		ab.range = CombatBalance.flat("illusion.nova.range")
	if ab.delivery == AbilityDef.Delivery.WALL:
		ab.recast_window = maxf(ab.recast_window, CombatBalance.flat("wall.illusion.recast"))
		ab.recast_damage_mult = 1.0
		ab.zone_duration = CombatBalance.flat("wall.illusion.time")


static func _apply_protection_wall(ab: AbilityDef) -> void:
	if ab == null or ab.delivery != AbilityDef.Delivery.WALL:
		return
	if not (ab.has_element(AbilityDef.Element.PROTECTION) or ab.has_infusion("protection")):
		return
	ab.is_channel = true
	var held := CombatBalance.flat("wall.protection.time")
	ab.channel_time = held if held > 0.2 else 4.0
	ab.move_while_casting = true
	ab.cast_time = 0.0
	ab.zone_duration = ab.channel_time


static func _shield_inc(inf: SpellInfusion, has_base_shield: bool) -> float:
	if inf.shield_from_base > 0.02:
		return inf.shield_from_base - 1.0
	if not has_base_shield:
		return 0.0
	if inf.offensive:
		return inf.damage_mult - 1.0
	return inf.heal_mult - 1.0


static func _apply_augments(ab: AbilityDef, augments: Array[SpellAugment]) -> void:
	var crit_dmg := ab.crit_damage
	var has_lethality := false
	var area_mult := 1.0
	var cleave_ratio := 0.0
	var cleave_radius := 0.0
	for aug in augments:
		ab.cast_time *= aug.cast_time_mult
		if ab.is_channel and aug.cast_time_mult < 0.999:
			if ab.tick_interval > 0.05:
				ab.tick_interval *= aug.cast_time_mult
			if ab.channel_time > 0.05:
				ab.channel_time *= aug.cast_time_mult
		ab.cooldown *= aug.cooldown_mult
		ab.mana_cost *= aug.mana_mult
		ab.range *= aug.range_mult
		ab.skillshot_length *= aug.range_mult
		area_mult *= aug.area_mult
		if not is_equal_approx(aug.damage_mult, 1.0):
			ab.damage *= aug.damage_mult
			ab.damage_max *= aug.damage_mult
			ab.tick_damage *= aug.damage_mult
		if aug.projectile_bonus > 0:
			ab.projectile_count = maxi(ab.projectile_count, 1) + aug.projectile_bonus
		if aug.pierce:
			ab.pierce = true
		if aug.lifesteal > 0.05:
			ab.lifesteal = maxf(ab.lifesteal, aug.lifesteal)
		if aug.execute_health_frac > 0.05:
			ab.execute_health_frac = aug.execute_health_frac
			ab.execute_damage_mult = aug.execute_damage_mult
		if aug.cleave_ratio > 0.05:
			cleave_ratio = maxf(cleave_ratio, aug.cleave_ratio)
			cleave_radius = maxf(cleave_radius, aug.cleave_radius)
		if aug.hit_cooldown_reduction > 0.05:
			ab.hit_cooldown_reduction = maxf(ab.hit_cooldown_reduction, aug.hit_cooldown_reduction)
			ab.hit_cooldown_refund_cap = maxf(ab.hit_cooldown_refund_cap, aug.hit_cooldown_refund_cap)
		if not is_equal_approx(aug.tick_interval_mult, 1.0):
			ab.tick_interval *= aug.tick_interval_mult
		if aug.planted:
			ab.planted = true
		if aug.detonate_on_end > 0.05:
			ab.detonate_on_end = maxf(ab.detonate_on_end, aug.detonate_on_end)
		if aug.crowd_bonus > 0.05:
			ab.crowd_bonus = maxf(ab.crowd_bonus, aug.crowd_bonus)
			ab.crowd_bonus_cap = maxf(ab.crowd_bonus_cap, aug.crowd_bonus_cap)
		if aug.stillness_bonus > 0.05:
			ab.stillness_bonus = maxf(ab.stillness_bonus, aug.stillness_bonus)
		if aug.instant_cast:
			ab.cast_time = 0.0
		if aug.echo:
			ab.echo = true
			ab.echo_damage_mult = aug.echo_damage_mult
		ab.crit_chance *= aug.crit_chance_mult
		if aug.id == "lethality":
			has_lethality = true
			crit_dmg = aug.crit_damage
		elif aug.crit_damage > 0.0 and not has_lethality:
			crit_dmg = aug.crit_damage
		if not is_equal_approx(aug.threat_mult, 1.0):
			ab.threat_mult *= aug.threat_mult
	if not is_equal_approx(area_mult, 1.0):
		ab.aoe_radius *= area_mult
		ab.aoe_radius_max *= area_mult
		ab.splash_radius *= area_mult
		ab.skillshot_width *= area_mult
		ab.cone_angle *= area_mult
	if cleave_ratio > 0.05 and ab.splash_radius <= 0.05:
		ab.splash_radius = (cleave_radius if cleave_radius > 0.05 else 1.2) * area_mult
		ab.splash_ratio = cleave_ratio
	elif cleave_ratio > 0.05:
		ab.splash_ratio = maxf(ab.splash_ratio, cleave_ratio)
	if ab.delivery == AbilityDef.Delivery.WALL and (ab.has_element(AbilityDef.Element.ILLUSION) or ab.has_infusion("illusion")):
		ab.recast_window = maxf(ab.recast_window, CombatBalance.flat("wall.illusion.recast"))
		ab.recast_damage_mult = 1.0
		ab.zone_duration = CombatBalance.flat("wall.illusion.time")
	_apply_protection_wall(ab)
	ab.crit_damage = crit_dmg


static func _apply_duration_augments(ab: AbilityDef, augments: Array[SpellAugment]) -> void:
	var duration_mult := 1.0
	for aug in augments:
		duration_mult *= aug.duration_mult
	if is_equal_approx(duration_mult, 1.0):
		return
	ab.zone_duration *= duration_mult
	ab.channel_time *= duration_mult


static func _apply_ally_flags(ab: AbilityDef, infusions: Array[SpellInfusion], augments: Array[SpellAugment]) -> void:
	var beneficial := false
	var offensive := false
	var has_altered := false
	var first_offensive := AbilityDef.Element.NONE
	var second_infusion := AbilityDef.Element.NONE
	for i in infusions.size():
		var inf: SpellInfusion = infusions[i]
		if inf.beneficial:
			beneficial = true
		if inf.offensive:
			offensive = true
			if first_offensive == AbilityDef.Element.NONE:
				first_offensive = inf.element
		if i == 1:
			second_infusion = inf.element
	for aug in augments:
		if aug.altered or aug.id == "altered" or aug.id == "alteration":
			has_altered = true
	var support_kit := false
	for inf in infusions:
		if inf != null and _is_support_alter_element(inf.element):
			support_kit = true
			break
	ab.altered = has_altered and (offensive or support_kit)
	if ab.altered:
		if infusions.size() >= 2 and infusions[1].offensive:
			ab.altered_element = second_infusion
		else:
			ab.altered_element = first_offensive
	else:
		ab.altered_element = AbilityDef.Element.NONE
	ab.can_help_allies = beneficial or ab.altered
	# Unit-lock recipes only. Skillshots still fire toward enemies and ghost when support-only.
	# Offensive-only: enemies. Support-only: allies. Mixed, or offensive + Alteration: both.
	if ab.target_mode == AbilityDef.TargetMode.UNIT and beneficial and not offensive and not ab.altered:
		ab.friendly_only = true


static func _display_name(base: SpellBase, infusions: Array[SpellInfusion]) -> String:
	if infusions.is_empty():
		return base.display_name
	if infusions.size() == 1:
		return "%s %s" % [infusions[0].adjective, base.noun]
	var key := "%s|%s" % [infusions[0].id, infusions[1].id]
	var head := String(_COMPOUNDS.get(key, ""))
	if head.is_empty():
		head = "%s %s" % [infusions[0].adjective, infusions[1].adjective]
	if infusions.size() >= 3:
		return "%s %s %s" % [head, infusions[2].adjective, base.noun]
	return "%s %s" % [head, base.noun]


static func _icon_id(base: SpellBase, _infusions: Array[SpellInfusion]) -> String:
	return base.icon_id


static func _icon_infusion_tag(infusions: Array[SpellInfusion]) -> String:
	if infusions.is_empty():
		return ""
	var present: Dictionary = {}
	for infusion in infusions:
		if infusion != null and not infusion.icon_tag.is_empty():
			present[infusion.icon_tag] = true
	var ordered := PackedStringArray()
	# Pair art is unordered; recipes with more than two infusions keep the first
	# two elements in this same canonical order until extra-infusion art exists.
	for tag in ["fire", "ice", "lightning", "shadow", "wind", "illusion", "nature", "divine", "protection"]:
		if present.has(tag):
			ordered.append(tag)
		if ordered.size() == 2:
			break
	return "_".join(ordered)


static func _description(base: SpellBase, infusions: Array[SpellInfusion], augments: Array[SpellAugment], ab: AbilityDef = null) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if not base.description.is_empty():
		lines.append(base.description)
	for inf in infusions:
		if not inf.description.is_empty():
			lines.append(inf.description)
	for aug in augments:
		if not aug.description.is_empty():
			lines.append(aug.description)
	if ab != null:
		if ab.locks_unit_target():
			if ab.can_target_allies() and ab.can_target_enemies():
				lines.append("Can be cast on a teammate or an enemy.")
			elif ab.can_target_allies():
				lines.append("Can be cast on a teammate.")
			elif ab.can_target_enemies():
				lines.append("Can be cast on an enemy.")
		if ab.delivery == AbilityDef.Delivery.MISSILES:
			lines.append("Homing. Passes through other units. Blocked by walls.")
		elif SpellPower.ghosts_enemies(ab) and not ab.pierces_skillshot() and ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
			lines.append("Passes through enemies and impacts the first ally, or travels to max range.")
		elif not SpellPower.ghosts_enemies(ab) and not ab.pierces_skillshot() and ab.can_target_allies() and ab.target_mode == AbilityDef.TargetMode.SKILLSHOT:
			lines.append("Impacts the first enemy or ally hit.")
		if ab.altered:
			var names := PackedStringArray()
			for kind in ab.altered_buff_elements():
				match int(kind):
					AbilityDef.Element.FIRE:
						names.append("Fire")
					AbilityDef.Element.ICE:
						names.append("Ice")
					AbilityDef.Element.STORM:
						names.append("Lightning")
					AbilityDef.Element.SHADOW:
						names.append("Shadow")
			var buff := _join_and(names)
			if not buff.is_empty():
				lines.append("Alteration buffs you and an ally with %s." % buff)
			_append_support_alter_lines(lines, ab)
	return "\n".join(lines)


static func _append_support_alter_lines(lines: PackedStringArray, ab: AbilityDef) -> void:
	if ab.has_element(AbilityDef.Element.NATURE):
		var snare := int(round(CombatBalance.pct("altered.nature.snare") * 100.0))
		var splash := int(round(CombatBalance.flat("altered.nature.splash")))
		var bloom := int(round(CombatBalance.flat("altered.nature.bloom")))
		var cap := int(round(CombatBalance.flat("altered.nature.max")))
		lines.append("Seeded: %d%% snare per seed. Fire spends one seed for a %d nature splash. The %dth seed blooms for %d nature on that target. Expiring does nothing." % [snare, splash, cap, bloom])
	if ab.has_element(AbilityDef.Element.HOLY):
		var taken := int(round(CombatBalance.pct("altered.divine.taken") * 100.0))
		var div := int(round(CombatBalance.flat("altered.divine.mend_div")))
		lines.append("Judged: Divine hits deal +%d%% per stack. Damage on them heals the lowest-HP nearby ally (hit / %d × stacks)." % [taken, div])
	if ab.has_element(AbilityDef.Element.PROTECTION):
		var out := int(round(CombatBalance.pct("altered.protection.out") * 100.0))
		var brk := int(round(CombatBalance.pct("altered.protection.break") * 100.0))
		lines.append("Sundered: deals %d%% less damage per stack. Hitting a shield breaks a stack and returns %d%% of the absorbed hit." % [out, brk])


static func _join_and(parts: PackedStringArray) -> String:
	if parts.is_empty():
		return ""
	if parts.size() == 1:
		return parts[0]
	if parts.size() == 2:
		return "%s and %s" % [parts[0], parts[1]]
	return "%s, and %s" % [", ".join(parts.slice(0, parts.size() - 1)), parts[parts.size() - 1]]
