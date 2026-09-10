class_name MendKit
extends Object

## Temporary NPC healer kit until a real healing spec exists.
## Values are AbilityDef.heal before SpellPower (Divine ≈ ×1.68, Nature ≈ ×0.48).
## Low threat so they do not pull.


static func recipes() -> Array:
	return [
		SpellRecipe.make("target", PackedStringArray(["divine"])),
		SpellRecipe.make("aura", PackedStringArray(["divine"])),
		SpellRecipe.make("ground_aoe", PackedStringArray(["nature"])),
		SpellRecipe.make("nova", PackedStringArray(["divine"])),
	]


static func apply_to(unit: Unit) -> void:
	if unit == null:
		return
	var spend := TalentSpend.new()
	var compiled := ChampionLoadout.compile(recipes(), spend)
	for ab in compiled:
		_amp_heal(ab)
	unit.apply_compiled_abilities(compiled)
	unit.max_mana = maxf(unit.max_mana, 560.0)
	unit.mana_regen = maxf(unit.mana_regen, 22.0)
	unit.mana = unit.max_mana
	unit.threat_mult = 0.20


static func _amp_heal(ab: AbilityDef) -> void:
	if ab == null or not ab.skill_id.is_empty():
		return
	ab.heal_allies = true
	ab.can_help_allies = true
	match ab.delivery:
		AbilityDef.Delivery.TARGET:
			ab.friendly_only = true
			ab.heal = 110.0
			ab.cooldown = 2.4
			ab.range = 16.0
			ab.mana_cost = 32.0
		AbilityDef.Delivery.AURA:
			ab.heal = 12.0
			ab.aoe_radius = maxf(ab.aoe_radius, 8.0)
			ab.mana_cost = 8.0
		AbilityDef.Delivery.GROUND_AOE:
			ab.heal = 42.0
			ab.cooldown = 12.0
			ab.range = 14.0
			ab.aoe_radius = maxf(ab.aoe_radius, 8.0)
			ab.mana_cost = 36.0
		AbilityDef.Delivery.NOVA:
			ab.heal = 85.0
			ab.cooldown = 10.0
			ab.aoe_radius = maxf(ab.aoe_radius, 8.0)
			ab.mana_cost = 48.0
		_:
			pass
