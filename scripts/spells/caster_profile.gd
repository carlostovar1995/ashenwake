class_name CasterProfile
extends Object


static func apply_to(unit: Unit) -> void:
	if unit == null:
		return
	unit.unit_name = "Ember"
	unit.body_color = Color(0.95, 0.45, 0.18)
	unit.visual_path = CharacterCatalog.FEMALE_PEASANT
	unit.visual_scale = 1.0
	unit.max_health = 480.0
	unit.max_mana = 520.0
	unit.mana_regen = 14.0
	unit.move_speed = 6.6
	unit.attack_damage = 32.0
	unit.attack_range = 7.2
	unit.attack_cooldown = 1.05
	unit.attack_windup = 0.05
	unit.attack_projectile_speed = 28.0
	unit.is_melee = false
	unit.attack_vfx_scene = AbilityFx.MAGIC_JAVELIN
	unit.attack_vfx_scale = 0.35
	unit.attack_vfx_yaw = -PI * 0.5
	unit.attack_applies_charged = true
	unit.turn_rate = 26.0
	unit.atonement_ratio = 0.0
	unit.attack_shield = 0.0
	unit.attack_shield_duration = 0.0
	unit.attack_mana_restore = 0.0
	unit.abilities = SpellCompiler.compile_loadout(GameSession.spell_loadout)
	AbilityDef.stamp_loadout_slots(unit.abilities)
