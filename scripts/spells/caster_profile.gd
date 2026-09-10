class_name CasterProfile
extends Object


static func apply_to(unit: Unit) -> void:
	if unit == null:
		return
	unit.unit_name = "Ember"
	unit.body_color = Color(0.95, 0.45, 0.18)
	unit.visual_path = CharacterCatalog.KEVDEV_DUMMY_F
	unit.visual_scale = 1.0
	unit.max_health = 500.0
	unit.max_mana = 520.0
	unit.mana_regen = 14.0
	unit.move_speed = Unit.BASE_MOVE_SPEED
	unit.attack_damage = 32.0
	unit.attack_range = 7.2
	unit.attack_cooldown = 1.05
	unit.attack_windup = 0.2
	unit.attack_projectile_speed = 28.0
	unit.is_melee = false
	unit.attack_vfx_scene = AbilityFx.MAGIC_JAVELIN
	unit.attack_vfx_scale = 0.35
	unit.attack_vfx_yaw = -PI * 0.5
	unit.attack_applies_charged = false
	unit.turn_rate = 26.0
	unit.atonement_ratio = 0.0
	unit.attack_shield = 0.0
	unit.attack_shield_duration = 0.0
	unit.attack_mana_restore = 0.0
	match RaidComp.normalize_role(GameSession.player_role):
		RaidComp.ROLE_TANK:
			unit.threat_mult = ThreatTable.TANK_MULT
		RaidComp.ROLE_HEALER:
			unit.threat_mult = 0.20
		_:
			unit.threat_mult = 1.0
	unit.abilities = ChampionLoadout.compile(GameSession.spell_loadout, GameSession.talent_spend, GameSession.skill_loadout)
	AbilityDef.stamp_loadout_slots(unit.abilities)
	var hooks := TalentHooks.from_spend(GameSession.talent_spend)
	if hooks.max_health_pct > 0.0:
		unit.max_health *= 1.0 + hooks.max_health_pct
	unit.bind_talent_hooks(hooks)
	ClassCatalog.apply_auto_to(unit, GameSession.talent_spend)
