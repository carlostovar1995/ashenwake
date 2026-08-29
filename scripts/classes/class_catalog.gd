class_name ClassCatalog
extends Object


static func all() -> Array[ChampionClass]:
	return [elemental(), healer(), arcane(), dark()]


static func get_by_id(class_id: String) -> ChampionClass:
	for c in all():
		if c.id == class_id:
			return c
	return elemental()


static func elemental() -> ChampionClass:
	var c := ChampionClass.new()
	c.id = "elemental"
	c.display_name = "Elemental"
	c.champion_name = "Ember"
	c.blurb = "Mix fire, ice, and storm."
	c.passive_name = "Attenuate"
	c.passive_icon = "attenuate"
	c.passive_description = "Your last spell infuses the next with Fire, Ice, or Storm.\nSame element hits harder. Autos apply Charged."
	c.available = true
	c.visual_path = CharacterCatalog.FEMALE_PEASANT
	c.visual_scale = 1.0
	c.body_color = Color(0.95, 0.45, 0.18)
	c.max_health = 480.0
	c.max_mana = 520.0
	c.mana_regen = 14.0
	c.move_speed = 6.6
	c.attack_damage = 32.0
	c.attack_range = 7.2
	c.attack_cooldown = 1.05
	c.attack_windup = 0.05
	c.attack_projectile_speed = 28.0
	c.is_melee = false
	c.attack_vfx_scene = AbilityFx.MAGIC_JAVELIN
	c.attack_vfx_scale = 0.35
	c.attack_vfx_yaw = -PI * 0.5
	c.attack_applies_charged = true
	c.nameplate_debuffs = PackedStringArray(["charged", "chilled", "frozen", "frozen_pending"])
	c.ability_builder = _elemental_abilities
	return c


static func healer() -> ChampionClass:
	var c := ChampionClass.new()
	c.id = "healer"
	c.display_name = "Healer"
	c.champion_name = "Haven"
	c.blurb = "Shield allies. Damage heals them."
	c.passive_name = "Atonement"
	c.passive_icon = "atonement"
	c.passive_description = "35% of damage you deal heals each ally who still has your shield.\nOverhealing tops that same shield.\nAutos can shield allies and restore 10 mana."
	c.available = true
	c.visual_path = CharacterCatalog.FEMALE_RANGER
	c.visual_scale = 1.0
	c.body_color = Color(0.92, 0.82, 0.42)
	c.max_health = 500.0
	c.max_mana = 560.0
	c.mana_regen = 16.0
	c.move_speed = 6.7
	c.attack_damage = 30.0
	c.attack_range = 7.0
	c.attack_cooldown = 1.0
	c.attack_windup = 0.05
	c.attack_projectile_speed = 26.0
	c.is_melee = false
	c.attack_vfx_scene = AbilityFx.MAGIC_JAVELIN
	c.attack_vfx_scale = 0.35
	c.attack_vfx_yaw = -PI * 0.5
	c.atonement_ratio = 0.35
	c.attack_shield = 25.0
	c.attack_shield_duration = 10.0
	c.attack_mana_restore = 10.0
	c.ability_builder = _healer_abilities
	return c


static func arcane() -> ChampionClass:
	var c := ChampionClass.new()
	c.id = "arcane"
	c.display_name = "Arcane"
	c.champion_name = "Spark"
	c.blurb = "Coming soon — blink kit."
	c.available = false
	c.visual_path = CharacterCatalog.MALE_RANGER
	c.body_color = Color(0.45, 0.7, 1.0)
	return c


static func dark() -> ChampionClass:
	var c := ChampionClass.new()
	c.id = "dark"
	c.display_name = "Dark"
	c.champion_name = "Hex"
	c.blurb = "Coming soon — void kit."
	c.available = false
	c.visual_path = CharacterCatalog.MALE_RANGER
	c.body_color = Color(0.55, 0.22, 0.7)
	return c


static func _elemental_abilities() -> Array[AbilityDef]:
	var q := AbilityDef.make("firebolt", "Firebolt", "Q", AbilityDef.TargetMode.SKILLSHOT, 35, 0.0, 12.0, 70, Color(1.0, 0.45, 0.12))
	q.skillshot_width = 1.3125
	q.skillshot_speed = 20.0
	q.skillshot_length = 12.0
	q.cast_time = 1.2
	q.splash_radius = 3.51
	q.splash_ratio = 0.8
	q.vfx_scene = AbilityFx.FIRE_PROJECTILE
	q.vfx_scale = 1.6625
	q.vfx_yaw = PI * 0.5
	q.vfx_primary = Color(1.0, 0.92, 0.42)
	q.vfx_secondary = Color(1.0, 0.42, 0.08)
	q.vfx_tertiary = Color(0.62, 0.08, 0.22)
	q.element = AbilityDef.Element.FIRE
	q.icon_id = "firebolt"
	q.description = "Hurl a bolt that explodes. Applies Burn (10s).\nDeals extra damage to Frozen targets."

	var w := AbilityDef.make("ice_blast", "Freeze", "W", AbilityDef.TargetMode.SKILLSHOT, 55, 12.0, 10.0, 50, Color(0.45, 0.8, 1.0))
	w.skillshot_length = 10.0
	w.cast_time = 0.0
	w.gcd_exempt = true
	w.cone_angle = deg_to_rad(60.0)
	w.vfx_scene = ""
	w.vfx_scale = 1.05
	w.vfx_primary = Color(0.55, 0.88, 1.0)
	w.vfx_secondary = Color(0.18, 0.45, 0.95)
	w.vfx_tertiary = Color(0.75, 0.95, 1.0)
	w.element = AbilityDef.Element.ICE
	w.icon_id = "ice_blast"
	w.description = "Frost cone. Applies Chilled.\nFully Chilled enemies Freeze (3.5s boss / 5s add), interrupting most boss spells."

	var e := AbilityDef.make("thunder_wave", "Thunder Wave", "E", AbilityDef.TargetMode.UNIT, 80, 12.0, 14.0, 150, Color(0.75, 0.85, 1.0))
	e.cast_time = 1.5
	e.chain_bounces = 4
	e.bounce_range = 6.0
	e.bounce_delay = 0.25
	e.vfx_scene = ""
	e.vfx_scale = 0.9
	e.vfx_primary = Color(0.75, 0.9, 1.0)
	e.vfx_secondary = Color(0.35, 0.55, 1.0)
	e.vfx_tertiary = Color(1.0, 0.95, 0.55)
	e.element = AbilityDef.Element.STORM
	e.icon_id = "thunder_wave"
	e.description = "Lightning hits instantly when the cast finishes, then jumps every 0.25s. Applies Charged on each hit.\nShatters Frozen targets."

	var r := AbilityDef.make("meteor", "Meteor", "R", AbilityDef.TargetMode.GROUND, 120, 30.0, 20.0, 500, Color(1.0, 0.35, 0.08))
	r.aoe_radius = 2.0
	r.aoe_radius_max = 5.4
	r.damage_max = 1000.0
	r.is_channel = true
	r.channel_time = 3.0
	r.cast_time = 0.0
	r.vfx_scene = AbilityFx.GROUND_EXPLOSION
	r.vfx_scale = 1.2
	r.element = AbilityDef.Element.FIRE
	r.icon_id = "meteor"
	r.description = "Mark a spot, then channel. Hold longer for a bigger blast.\nPress R again to drop it early. Moving cancels.\nConsumes Burn to Combust."

	var d := AbilityDef.make("chilled_ground", "Chilled Ground", "D", AbilityDef.TargetMode.GROUND, 70, 30.0, 12.0, 25, Color(0.4, 0.78, 1.0))
	d.aoe_radius = 7.8
	d.cast_time = 0.0
	d.gcd_exempt = true
	d.zone_duration = 8.0
	d.tick_interval = 0.25
	d.tick_damage = 6.25
	d.vfx_scene = ""
	d.vfx_scale = 1.35
	d.vfx_primary = Color(0.55, 0.88, 1.0)
	d.vfx_secondary = Color(0.18, 0.45, 0.95)
	d.vfx_tertiary = Color(0.75, 0.95, 1.0)
	d.element = AbilityDef.Element.ICE
	d.icon_id = "chilled_ground"
	d.description = "Leave ice that Chills enemies and speeds allies.\nDoes not Freeze."

	var f := AbilityDef.make("overcharge", "Overcharge", "F", AbilityDef.TargetMode.INSTANT, 0, 120.0, 0.0, 0, Color(0.95, 0.85, 0.4))
	f.cast_time = 0.0
	f.buff_duration = 10.0
	f.cast_speed_bonus = 0.5
	f.mana_cost_reduction = 0.6
	f.cooldown_recovery_rate = 2.0
	f.grant_all_infusions = true
	f.icon_id = "overcharge"
	f.vfx_scene = AbilityFx.FIRE_CAST
	f.vfx_scale = 1.2
	f.vfx_primary = Color(1.0, 0.92, 0.45)
	f.vfx_secondary = Color(0.55, 0.85, 1.0)
	f.vfx_tertiary = Color(1.0, 0.45, 0.15)
	f.description = "Every spell is Fire, Ice, and Storm for a short time.\nCasts faster. Costs less. Ability cooldowns recover at 2× speed."
	return [q, w, e, r, d, f]


static func _healer_abilities() -> Array[AbilityDef]:
	var gold := Color(0.95, 0.84, 0.38)
	var q := AbilityDef.make("radiant_bolt", "Radiant Bolt", "Q", AbilityDef.TargetMode.SKILLSHOT, 30, 3.0, 12.0, 75, gold)
	q.skillshot_width = 0.85
	q.skillshot_speed = 24.0
	q.skillshot_length = 12.0
	q.cast_time = 0.25
	q.heal_allies = true
	q.hit_cooldown_reduction = 1.0
	q.vfx_scene = AbilityFx.MAGIC_JAVELIN
	q.vfx_scale = 0.45
	q.vfx_yaw = -PI * 0.5
	q.vfx_primary = Color(1.0, 0.94, 0.55)
	q.vfx_secondary = Color(0.95, 0.72, 0.22)
	q.vfx_tertiary = Color(0.72, 0.42, 0.08)
	q.icon_id = "radiant_bolt"
	q.description = "Line of light. Heals allies or damages the first target hit.\nLanding a hit reduces all spell cooldowns by 1s."

	var w := AbilityDef.make("ward", "Ward", "W", AbilityDef.TargetMode.UNIT, 40, 5.0, 12.0, 0, Color(0.88, 0.9, 0.98))
	w.cast_time = 0.0
	w.gcd_exempt = true
	w.shield = 200.0
	w.shield_duration = 10.0
	w.vfx_scene = AbilityFx.FIRE_CAST
	w.vfx_scale = 0.85
	w.vfx_primary = Color(0.92, 0.95, 1.0)
	w.vfx_secondary = Color(0.7, 0.78, 0.95)
	w.vfx_tertiary = Color(1.0, 0.88, 0.45)
	w.icon_id = "ward_cast"
	w.description = "Shield an ally (or yourself if you click empty ground).\nAtonement heals them while the absorb lasts."

	var e := AbilityDef.make("judgment", "Judgment", "E", AbilityDef.TargetMode.UNIT, 70, 10.0, 14.0, 180, gold)
	e.cast_time = 1.3
	e.vfx_scene = AbilityFx.FIRE_CAST
	e.vfx_scale = 1.05
	e.vfx_primary = Color(1.0, 0.92, 0.4)
	e.vfx_secondary = Color(0.95, 0.7, 0.18)
	e.vfx_tertiary = Color(1.0, 0.98, 0.75)
	e.icon_id = "judgment"
	e.description = "Strike one enemy with a burst of light.\nStrong Atonement healing."

	var r := AbilityDef.make("bastion", "Bastion", "R", AbilityDef.TargetMode.INSTANT, 100, 40.0, 14.0, 0, Color(0.95, 0.88, 0.55))
	r.cast_time = 0.0
	r.shield = 100.0
	r.shield_duration = 8.0
	r.aoe_radius = 14.0
	r.vfx_scene = AbilityFx.FIRE_CAST
	r.vfx_scale = 1.35
	r.vfx_primary = Color(1.0, 0.94, 0.55)
	r.vfx_secondary = Color(0.85, 0.78, 0.4)
	r.vfx_tertiary = Color(1.0, 0.98, 0.8)
	r.icon_id = "bastion"
	r.description = "Shield you and nearby allies.\nOpen an Atonement window."

	var d := AbilityDef.make("sanctuary", "Sanctuary", "D", AbilityDef.TargetMode.GROUND, 60, 25.0, 12.0, 0, gold)
	d.aoe_radius = 7.5
	d.cast_time = 0.0
	d.gcd_exempt = true
	d.zone_duration = 8.0
	d.tick_interval = 0.5
	d.tick_damage = 8.0
	d.tick_shield = 15.0
	d.shield_duration = 3.0
	d.vfx_scale = 1.2
	d.vfx_primary = Color(1.0, 0.9, 0.4)
	d.vfx_secondary = Color(0.95, 0.72, 0.2)
	d.icon_id = "sanctuary"
	d.description = "Consecrate the ground. Damages enemies.\nAllies inside take 25% less damage and gain a small rolling shield."

	var f := AbilityDef.make("radiance", "Radiance", "F", AbilityDef.TargetMode.INSTANT, 0, 60.0, 0.0, 0, Color(1.0, 0.92, 0.5))
	f.cast_time = 0.0
	f.free_cast_charges = 2
	f.icon_id = "radiance"
	f.vfx_scene = AbilityFx.FIRE_CAST
	f.vfx_scale = 1.25
	f.vfx_primary = Color(1.0, 0.96, 0.6)
	f.vfx_secondary = Color(1.0, 0.84, 0.32)
	f.vfx_tertiary = Color(1.0, 0.98, 0.85)
	f.description = "Your next two spells have no cooldown."
	return [q, w, e, r, d, f]
