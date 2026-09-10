class_name ClassSkillCompiler
extends Object


static func compile(skill_id: String, hotkey: String) -> AbilityDef:
	if skill_id.is_empty():
		return empty_slot(hotkey)
	var skill := ClassCatalog.get_skill(skill_id)
	if skill == null:
		return empty_slot(hotkey)
	var ab := AbilityDef.make(
		skill.id,
		skill.display_name,
		hotkey,
		skill.target_mode,
		skill.mana_cost,
		skill.cooldown,
		skill.range,
		skill.damage,
		skill.color
	)
	ab.skill_id = skill.id
	ab.cast_time = skill.cast_time
	ab.delivery = skill.delivery
	ab.element = skill.element
	ab.aoe_radius = skill.aoe_radius
	ab.zone_duration = skill.zone_duration
	ab.tick_interval = skill.tick_interval
	ab.recast_window = skill.recast_window
	ab.description = skill.description
	ab.icon_id = skill.icon_id if not skill.icon_id.is_empty() else skill.id
	ab.implemented = true
	ab.can_help_allies = skill.can_help_allies
	ab.vfx_primary = skill.color
	ab.vfx_secondary = Color(1.0, 0.28, 0.08)
	ab.vfx_tertiary = Color(1.0, 0.82, 0.35)
	match skill.id:
		"pyre":
			ab.vfx_scene = AbilityFx.FIRE_PROJECTILE
			ab.skillshot_speed = 22.0
			ab.skillshot_length = 16.0
			ab.aoe_radius = skill.aoe_radius
		"ashen_crucible":
			ab.skillshot_width = CombatBalance.flat("skill.ashen.width")
			ab.skillshot_length = ab.range
			ab.skillshot_speed = 0.0
			ab.recast_damage_mult = 1.0
			ab.vfx_scene = AbilityFx.FIRE_CAST
			ab.recast_window = skill.recast_window
		"iron_rampage":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
		"hearthguard":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.tick_shield = 60.0
			ab.shield_duration = 6.0
			ab.can_help_allies = true
		"worldbloom":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.heal = 40.0
			ab.heal_allies = true
			ab.applies_rejuvenation = true
			ab.can_help_allies = true
			ab.recast_window = skill.recast_window
			ab.recast_damage_mult = 1.0
		"eye_of_tempest":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
			ab.recast_window = skill.recast_window
			ab.recast_damage_mult = 1.0
		"pyroblast":
			ab.vfx_scene = AbilityFx.FIRE_PROJECTILE
			ab.skillshot_speed = 22.0
			ab.skillshot_length = 16.0
		"crucible":
			ab.tick_damage = 40.0
			ab.vfx_scene = AbilityFx.FIRE_AREA
		"ashen_wake":
			ab.skillshot_width = CombatBalance.flat("skill.ashen.width")
			ab.skillshot_length = ab.range
			ab.skillshot_speed = 0.0
			ab.recast_damage_mult = 1.0
			ab.vfx_scene = AbilityFx.FIRE_CAST
		"combustion":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
		"ironhide":
			ab.vfx_scene = AbilityFx.FIRE_CAST
			ab.gcd_exempt = true
		"rampage":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
		"sanctuary":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.tick_shield = CombatBalance.flat("skill.sanctuary.shield")
			ab.shield_duration = 6.0
		"intercede":
			ab.vfx_scene = AbilityFx.FIRE_CAST
			ab.shield = CombatBalance.flat("skill.intercede.shield")
			ab.shield_duration = 6.0
			ab.can_help_allies = true
		"flourish":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
			ab.can_help_allies = true
			ab.heal_allies = true
			ab.aoe_radius = skill.aoe_radius
		"worldroot":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.heal = CombatBalance.flat("skill.worldroot.heal")
			ab.heal_allies = true
			ab.applies_rejuvenation = true
			ab.can_help_allies = true
			ab.recast_window = skill.recast_window
			ab.recast_damage_mult = 1.0
		"tempest_bloom":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
		"eye_of_the_storm":
			ab.vfx_scene = AbilityFx.GROUND_EXPLOSION
			ab.gcd_exempt = true
			ab.recast_window = skill.recast_window
			ab.recast_damage_mult = 1.0
		_:
			pass
	return ab


static func empty_slot(hotkey: String) -> AbilityDef:
	var ab := AbilityDef.make("", "Empty", hotkey, AbilityDef.TargetMode.INSTANT, 0.0, 0.0, 0.0, 0.0, Color(0.28, 0.28, 0.30))
	ab.implemented = false
	ab.description = "No ultimate bound. Unlock one on the Talents tab; it fills D then F. Swap them on the Spellbook."
	ab.icon_id = ""
	ab.skill_id = ""
	return ab
