class_name ClassAutoAttack
extends RefCounted

## Right-click. Baseline is generic ranged. Spec auto-row riders stack on top.

var summary: String = ""
var element: int = AbilityDef.Element.NONE
var extra_elements: PackedInt32Array = PackedInt32Array()
var applies_charged: bool = false
var extra_threat: float = 0.0
var raid_mana: float = 0.0
var melee: bool = false
var attack_damage: float = 32.0
var attack_range: float = 7.2
var attack_cooldown: float = 1.05
var attack_windup: float = 0.2
var spread_burn_radius: float = 0.0
var spread_burn_ratio: float = 0.0
var projectile_color: Color = Color(0.78, 0.76, 0.72)
var vfx_scene: String = ""
var ally_heal: float = 0.0
var ally_rejuvenation: bool = false
var ally_color: Color = Color(0.45, 0.85, 0.42)
var auto_crit: float = 0.0
var auto_crit_splash: float = 0.0
var afflict_hit: int = 0
var afflict_amp: float = 0.0
var chill_on_frostfire: bool = false
var ally_shield: float = 0.0
var self_shield: float = 0.0
var grove_pulse: float = 0.0
var lightning_pct: float = 0.0
var dodge_distance: float = 0.0
var dodge_cooldown: float = 0.0


static func baseline() -> ClassAutoAttack:
	var aa := ClassAutoAttack.new()
	aa.summary = "Ranged. 32 hit, 7.2m, 1.05s. No element, no rider."
	aa.vfx_scene = AbilityFx.MAGIC_JAVELIN
	return aa


static func from_spend(spend: TalentSpend) -> ClassAutoAttack:
	var aa := baseline()
	if spend == null:
		return aa
	_apply_kindling(aa, spend)
	_apply_cinderfrost(aa, spend)
	_apply_aegis(aa, spend)
	_apply_bastion(aa, spend)
	_apply_wildroot(aa, spend)
	_apply_tempest(aa, spend)
	var hooks := TalentHooks.from_spend(spend)
	aa.attack_damage += hooks.auto_damage_bonus
	aa.extra_threat += hooks.auto_threat_bonus
	aa.self_shield += hooks.auto_self_shield_bonus
	aa.ally_heal += hooks.ally_heal_bonus
	_set_element(aa)
	aa.summary = _summary(aa)
	return aa


static func fire_mage() -> ClassAutoAttack:
	return from_spend(null)


static func bulwark() -> ClassAutoAttack:
	var aa := baseline()
	aa.melee = true
	aa.attack_damage = 180.0
	aa.attack_range = 2.4
	aa.attack_cooldown = 0.85
	aa.attack_windup = 0.22
	aa.extra_threat = 24.0
	aa.raid_mana = 10.0
	aa.vfx_scene = ""
	aa.summary = "Melee. 180 physical. +24 extra threat. Each hit restores 10 mana to every living raid member."
	return aa


static func storm_druid() -> ClassAutoAttack:
	var aa := baseline()
	aa.element = AbilityDef.Element.STORM
	aa.projectile_color = Color(0.42, 0.78, 1.0)
	aa.vfx_scene = AbilityFx.MAGIC_JAVELIN
	aa.ally_heal = 14.0
	aa.ally_rejuvenation = true
	aa.summary = "Lightning vs enemies (1 Shock). Allies: 14 nature heal + 1 Rejuvenation."
	return aa


static func _apply_kindling(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("kindling_auto_cinder_shot") > 0:
		aa.element = AbilityDef.Element.FIRE
		aa.spread_burn_radius = 2.8
		aa.spread_burn_ratio = 0.25
		aa.projectile_color = Color(1.0, 0.42, 0.1)
		aa.vfx_scene = AbilityFx.FIRE_PROJECTILE
	if spend.rank_of("kindling_auto_hot_streak_shot") > 0:
		aa.element = AbilityDef.Element.FIRE
		aa.auto_crit = 0.08
		aa.auto_crit_splash = 0.15
		aa.projectile_color = Color(1.0, 0.42, 0.1)
		aa.vfx_scene = AbilityFx.FIRE_PROJECTILE


static func _apply_cinderfrost(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("cinderfrost_auto_kiln_shot") > 0:
		aa.element = AbilityDef.Element.FIRE
		aa.chill_on_frostfire = true
		aa.projectile_color = Color(1.0, 0.55, 0.35)
		aa.vfx_scene = AbilityFx.FIRE_PROJECTILE
	if spend.rank_of("cinderfrost_auto_soot_shot") > 0:
		aa.element = AbilityDef.Element.FIRE
		aa.afflict_hit = 1
		aa.afflict_amp = 0.10
		aa.projectile_color = Color(0.55, 0.18, 0.12)
		aa.vfx_scene = AbilityFx.FIRE_PROJECTILE


static func _apply_aegis(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("aegis_auto_iron_fist") > 0:
		_melee(aa, 180.0, 24.0, 10.0)
		aa.dodge_distance = 8.0
		aa.dodge_cooldown = 3.6
	if spend.rank_of("aegis_auto_goading_shot") > 0:
		aa.extra_threat += 40.0
		aa.raid_mana += 8.0


static func _apply_bastion(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("bastion_auto_ward_strike") > 0:
		_melee(aa, 140.0, 16.0, 0.0)
		aa.ally_shield = 20.0
	if spend.rank_of("bastion_auto_aegis_shot") > 0:
		aa.self_shield = 25.0


static func _apply_wildroot(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("wildroot_auto_bloom_touch") > 0:
		aa.ally_heal = 14.0
		aa.ally_rejuvenation = true
		aa.ally_color = Color(0.42, 0.88, 0.48)
	if spend.rank_of("wildroot_auto_grove_pulse") > 0:
		aa.grove_pulse = 0.25


static func _apply_tempest(aa: ClassAutoAttack, spend: TalentSpend) -> void:
	if spend.rank_of("tempest_auto_storm_touch") > 0:
		aa.element = AbilityDef.Element.STORM
		aa.projectile_color = Color(0.42, 0.78, 1.0)
		aa.vfx_scene = AbilityFx.MAGIC_JAVELIN
		aa.ally_heal = 14.0
		aa.ally_rejuvenation = true
		aa.ally_color = Color(0.42, 0.88, 0.48)
	if spend.rank_of("tempest_auto_high_volt_shot") > 0:
		aa.element = AbilityDef.Element.STORM
		aa.lightning_pct = 0.08
		aa.projectile_color = Color(0.42, 0.78, 1.0)
		aa.vfx_scene = AbilityFx.MAGIC_JAVELIN


static func _melee(aa: ClassAutoAttack, damage: float, threat: float, mana: float) -> void:
	aa.melee = true
	aa.attack_damage = damage
	aa.attack_range = 2.4
	aa.attack_cooldown = 0.85
	aa.attack_windup = 0.22
	aa.extra_threat += threat
	aa.raid_mana += mana
	aa.vfx_scene = ""


static func _set_element(aa: ClassAutoAttack) -> void:
	if aa.element == AbilityDef.Element.FIRE:
		return
	if aa.element == AbilityDef.Element.STORM:
		return
	if aa.melee:
		aa.element = AbilityDef.Element.NONE


static func _summary(aa: ClassAutoAttack) -> String:
	if aa.melee:
		return "Melee. %.0f hit. Stacked spec auto riders apply." % aa.attack_damage
	if aa.element == AbilityDef.Element.FIRE:
		return "Fire ranged auto with stacked spec riders."
	if aa.element == AbilityDef.Element.STORM:
		return "Lightning ranged auto with stacked spec riders."
	return baseline().summary
