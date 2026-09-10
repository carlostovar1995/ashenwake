class_name ClassCatalog
extends Object

static var _classes: Dictionary = {}
static var _skills: Dictionary = {}
static var _ready: bool = false


static func invalidate() -> void:
	_ready = false
	_classes.clear()
	_skills.clear()


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	_register(_kindling())
	_register(_cinderfrost())
	_register(_aegis())
	_register(_bastion())
	_register(_wildroot())
	_register(_tempest())
	for class_def in _classes.values():
		var errors := TalentValidator.validate(class_def)
		if not errors.is_empty():
			push_error("ClassCatalog: %s failed validation: %s" % [class_def.id, ", ".join(errors)])


static func def_for(class_id: String) -> ClassDef:
	ensure()
	if class_id.is_empty():
		return _classes.get(default_class_id(), null)
	return _classes.get(class_id, null)


static func default_class_id() -> String:
	return "kindling"


static func apply_auto_to(unit: Unit, spend: TalentSpend) -> void:
	if unit == null:
		return
	unit.bind_class_auto(ClassAutoAttack.from_spend(spend))
	if spend != null and spend.rank_of("aegis_auto_iron_fist") > 0:
		var hooks := unit.talent_hooks()
		if hooks != null:
			hooks.lunge = true


static func all_classes() -> Array[ClassDef]:
	ensure()
	var out: Array[ClassDef] = []
	for class_def in _classes.values():
		if class_def is ClassDef:
			out.append(class_def)
	out.sort_custom(func(a: ClassDef, b: ClassDef) -> bool:
		return a.display_name < b.display_name
	)
	return out


static func get_skill(skill_id: String) -> ClassSkillDef:
	ensure()
	return _skills.get(skill_id, null)


static func talent(class_id: String, talent_id: String) -> TalentDef:
	var class_def := def_for(class_id)
	if class_def == null:
		return null
	return class_def.talent(talent_id)


static func find_talent(talent_id: String) -> TalentDef:
	ensure()
	if talent_id.is_empty():
		return null
	for class_def in _classes.values():
		if class_def is ClassDef:
			var def: TalentDef = class_def.talent(talent_id)
			if def != null:
				return def
	return null


static func spec_for_talent(talent_id: String) -> ClassDef:
	ensure()
	for class_def in _classes.values():
		if class_def is ClassDef and class_def.talent(talent_id) != null:
			return class_def
	return null


static func _register(class_def: ClassDef) -> void:
	_classes[class_def.id] = class_def
	for talent in class_def.all_skills():
		if talent.skill_id.is_empty():
			continue
		_skills[talent.skill_id] = _skill_for(talent)


static func _skill_for(talent: TalentDef) -> ClassSkillDef:
	var skill := ClassSkillDef.new()
	skill.id = talent.skill_id
	skill.talent_id = talent.id
	skill.display_name = talent.display_name
	skill.description = talent.line_for_rank(1)
	skill.icon_id = talent.skill_id
	skill.color = Color(1.0, 0.45, 0.12)
	match talent.skill_id:
		"pyre":
			skill.mana_cost = 90.0
			skill.cooldown = 36.0
			skill.cast_time = 1.8
			skill.damage = 400.0
			skill.range = 14.0
			skill.target_mode = AbilityDef.TargetMode.UNIT
			skill.delivery = AbilityDef.Delivery.TARGET
			skill.icon_id = "bolt"
			skill.aoe_radius = 2.8
		"ashen_crucible":
			skill.mana_cost = 80.0
			skill.cooldown = 32.0
			skill.range = 10.0
			skill.recast_window = 6.0
			skill.target_mode = AbilityDef.TargetMode.SKILLSHOT
			skill.delivery = AbilityDef.Delivery.WAVE
			skill.color = Color(0.55, 0.28, 0.18)
			skill.icon_id = "wave"
			skill.aoe_radius = 10.0
		"iron_rampage":
			skill.mana_cost = 50.0
			skill.cooldown = 22.0
			skill.range = 0.0
			skill.target_mode = AbilityDef.TargetMode.INSTANT
			skill.delivery = AbilityDef.Delivery.NOVA
			skill.color = Color(0.72, 0.42, 0.32)
			skill.icon_id = "nova"
			skill.element = AbilityDef.Element.PROTECTION
		"hearthguard":
			skill.mana_cost = 60.0
			skill.cooldown = 22.0
			skill.range = 12.0
			skill.aoe_radius = 4.5
			skill.zone_duration = 5.0
			skill.tick_interval = 1.0
			skill.target_mode = AbilityDef.TargetMode.GROUND
			skill.delivery = AbilityDef.Delivery.GROUND_AOE
			skill.color = Color(0.92, 0.84, 0.42)
			skill.icon_id = "ground_aoe"
			skill.element = AbilityDef.Element.HOLY
			skill.can_help_allies = true
		"worldbloom":
			skill.mana_cost = 60.0
			skill.cooldown = 36.0
			skill.range = 12.0
			skill.aoe_radius = 7.0
			skill.zone_duration = 6.0
			skill.tick_interval = 1.0
			skill.recast_window = 6.0
			skill.target_mode = AbilityDef.TargetMode.GROUND
			skill.delivery = AbilityDef.Delivery.GROUND_AOE
			skill.color = Color(0.22, 0.55, 0.28)
			skill.icon_id = "ground_aoe"
			skill.element = AbilityDef.Element.NATURE
			skill.can_help_allies = true
		"eye_of_tempest":
			skill.mana_cost = 60.0
			skill.cooldown = 34.0
			skill.range = 10.0
			skill.aoe_radius = 6.0
			skill.zone_duration = 8.0
			skill.recast_window = 8.0
			skill.target_mode = AbilityDef.TargetMode.INSTANT
			skill.delivery = AbilityDef.Delivery.NOVA
			skill.color = Color(0.78, 0.68, 1.0)
			skill.icon_id = "lightning"
			skill.element = AbilityDef.Element.STORM
		_:
			pass
	return skill


static func _t(
	p_id: String,
	p_name: String,
	p_max: int,
	p_type: String,
	p_lines: PackedStringArray,
	p_hook: String,
	p_skill: String = ""
) -> TalentDef:
	return TalentDef.make(p_id, p_name, p_max, p_type, p_lines, p_hook, p_skill)


static func _auto(p_id: String, p_name: String, p_line: String, p_melee: bool = false) -> TalentDef:
	var t := _t(p_id, p_name, 1, TalentDef.TYPE_AUTO, PackedStringArray([p_line]), "auto")
	t.melee_auto = p_melee
	return t


static func _p(lines: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for line in lines:
		out.append(String(line))
	return out


static func _spec(p_id: String, p_name: String, p_role: String, p_tree: TalentTreeDef) -> ClassDef:
	var class_def := ClassDef.new()
	class_def.id = p_id
	class_def.display_name = p_name
	class_def.role = p_role
	class_def.auto = ClassAutoAttack.baseline()
	class_def.trees = [p_tree]
	return class_def


static func _kindling() -> ClassDef:
	return _spec("kindling", "Furnace", "dps", TalentTreeDef.make_choice(
		"kindling", "Furnace", "bank Burn vs crits into Pyre", "Embers", "Detonation",
		[
			[
				_t("kindling_embers_emberheart", "Emberheart", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% Burn damage", "2: +8%", "3: +12%"]), "burn"),
				_t("kindling_mid_cinder_focus", "Cinder Focus", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% fire damage", "2: +7%", "3: +10%"]), "fire"),
				_t("kindling_detonation_hot_hands", "Hot Hands", 3, TalentDef.TYPE_PASSIVE, _p(["1: Fire spells +2% crit chance", "2: +4%", "3: +6%"]), "fire"),
			],
			[
				_t("kindling_embers_live_coals", "Live Coals", 2, TalentDef.TYPE_INTERACTION, _p(["1: Dying enemies with Burn explode for 20% of remaining Burn in 3.6m", "2: 30%"]), "burn / burst"),
				_t("kindling_mid_burnbrand", "Burnbrand", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% damage to Burned enemies", "2: +6%", "3: +9%"]), "burn"),
				_t("kindling_mid_singe", "Singe", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Fire hits (not ticks or autos) apply Singe 6s, cap 3. At 3 stacks, your next Burst / Nova / Meteor / Pyre consumes it for 18 fire in 2.2m",
					"2: consume 28; Fire Bolt, Missiles, and Ray can also consume",
					"3: consume 36; copies 20% remaining Burn to neighbors in 2.8m (does not hop again)",
				]), "fire / burn"),
				_t("kindling_detonation_critical_mass", "Critical Mass", 2, TalentDef.TYPE_INTERACTION, _p(["1: Fire crits splash 12% of the crit in 1.6m", "2: 20%"]), "fire"),
			],
			[
				_t("kindling_embers_cinder_spark", "Cinder Spark", 2, TalentDef.TYPE_INTERACTION, _p(["1: Applying Burn to a target that already has Burn deals 6% of the new layer instantly", "2: 10%"]), "burn"),
				_t("kindling_detonation_flashover", "Flashover", 2, TalentDef.TYPE_INTERACTION, _p(["1: Fire crits store an extra 15% of the hit as Burn", "2: 25%"]), "fire / burn"),
			],
			[
				_auto("kindling_auto_cinder_shot", "Cinder Shot", "1: Fire. Store Burn. If the target has Burn, copy 25% of remaining Burn, split among enemies in 2.8m"),
				_auto("kindling_auto_hot_streak_shot", "Hot Streak Shot", "1: Fire. Store Burn. Autos +8% crit. Auto crits splash 15% of the crit in 1.6m"),
			],
			[
				_t("kindling_embers_searing_marks", "Searing Marks", 3, TalentDef.TYPE_INTERACTION, _p(["1: Fire hits refresh Burn layers by 0.5s", "2: by 1.0s, and Ground AOE / Aura / Wall ticks also refresh", "3: by 1.5s"]), "fire / burn"),
				_t("kindling_mid_pyromania", "Pyromania", 3, TalentDef.TYPE_PASSIVE, _p(["1: Fire crit damage +5% (200% → 205%)", "2: +10%", "3: +15%"]), "fire"),
				_t("kindling_mid_scorch", "Scorch", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Fire Ground AOE / Aura / Wall ticks apply Scorched 5s (12% snare). Fire hits vs Scorched store +8% extra of the hit as Burn",
					"2: 18% snare, +12% extra store",
					"3: 24% snare, +16% extra store. Pyre vs Scorched: leftover splash 40% → 55% (consumes Scorched)",
				]), "fire / burn / ground_aoe"),
				_t("kindling_detonation_glass_furnace", "Glass Furnace", 3, TalentDef.TYPE_PASSIVE, _p(["1: Fire crit damage 215% (from 200%)", "2: 230%", "3: 245%"]), "fire"),
			],
			[
				_t("kindling_embers_kindling", "Kindling", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Burn stores +8% of the hit (50% becomes 58%)",
					"2: +16% (50% becomes 66%)",
					"3: +25% (50% becomes 75%); Fire Bolt, Missiles, and Ray vs Burned store an extra 25%; Heating 6s after Pyre: fire hits store 100%",
				]), "burn / fire"),
				_t("kindling_mid_ember_core", "Ember Core", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% Burn damage", "2: +8%", "3: +12%"]), "burn"),
				_t("kindling_detonation_afterburn", "Afterburn", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: After a fire crit, next fire spell is 16% faster to cast for 4s",
					"2: 32% faster",
					"3: 40% faster and Hot Streak: 2 fire crits within 8s make your next Pyre instant",
				]), "fire"),
			],
		],
		_t("kindling_ult_pyre", "Pyre", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: 1.8s unit-target, 36s CD, 90 mana. Consume remaining Burn: 150% as fire plus a 400 fire hit that always crits if any Burn was consumed. Nearby take 40% leftover Burn in 2.8m. Fire crits reduce remaining CD by 0.5s"]), "fire / burn", "pyre")
	))


static func _cinderfrost() -> ClassDef:
	return _spec("cinderfrost", "Crucible", "dps", TalentTreeDef.make_choice(
		"cinderfrost", "Crucible", "fuse Frostfire vs paint Afflict", "Frostfire", "Cinder",
		[
			[
				_t("cinderfrost_frostfire_alloy", "Alloy", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% damage on crafted spells with both Fire and Ice", "2: +6%", "3: +8%"]), "fire / ice"),
				_t("cinderfrost_mid_duality", "Duality", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% fire damage", "2: +7%", "3: +10%"]), "fire"),
				_t("cinderfrost_cinder_cinderfeed", "Cinderfeed", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% fire and shadow damage to Afflicted", "2: +7%", "3: +10%"]), "fire / shadow / afflicted"),
			],
			[
				_t("cinderfrost_frostfire_kiln", "Kiln", 2, TalentDef.TYPE_INTERACTION, _p(["1: Frostfire crafts apply Frostfire 6s, Burn as a fire hit would, and 1 Chill stack", "2: 2 Chill stacks. Ticks: 1 Chill and Burn equal to 10% of the tick"]), "fire / ice / burn / chilled"),
				_t("cinderfrost_cinder_wick", "Wick", 2, TalentDef.TYPE_INTERACTION, _p(["1: Heal for 5% of Burn damage you deal", "2: 8%"]), "burn"),
			],
			[
				_t("cinderfrost_frostfire_quench", "Quench", 2, TalentDef.TYPE_INTERACTION, _p(["1: The first Frostfire apply on a target deals a steam burst equal to 12% of remaining Burn", "2: 20%. Burn is not consumed"]), "burn / frostfire"),
				_t("cinderfrost_mid_frostbite", "Frostbite", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% damage to Chilled enemies", "2: +6%", "3: +9%"]), "chilled"),
				_t("cinderfrost_mid_soot", "Soot", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% damage to Afflicted", "2: +6%", "3: +9%"]), "afflicted"),
				_t("cinderfrost_cinder_pitch_skin", "Pitch Skin", 2, TalentDef.TYPE_INTERACTION, _p(["1: 12% DR vs fire and shadow while a nearby enemy has Afflict (8m)", "2: 20%"]), "afflicted / fire / shadow"),
			],
			[
				_auto("cinderfrost_auto_kiln_shot", "Kiln Shot", "1: Fire. Store Burn. Autos vs Frostfire apply 1 Chill"),
				_t("cinderfrost_mid_branding", "Branding", 3, TalentDef.TYPE_PASSIVE, _p(["1: Autos +4 damage", "2: +8", "3: +12"]), "auto"),
				_auto("cinderfrost_auto_soot_shot", "Soot Shot", "1: Fire. Apply 1 Afflict. Autos vs Afflicted +10%"),
			],
			[
				_t("cinderfrost_frostfire_fumarole", "Fumarole", 3, TalentDef.TYPE_INTERACTION, _p(["1: Enemies with Frostfire take +5% from you", "2: +10%; on death a 1s steam patch (12 fire + 12 ice per 0.5s, 1.6m)", "3: +15%; 2s steam patch"]), "frostfire"),
				_t("cinderfrost_mid_steam", "Steam", 3, TalentDef.TYPE_PASSIVE, _p(["1: +2% ice damage", "2: +4%", "3: +6%"]), "ice"),
			],
			[
				_t("cinderfrost_frostfire_glaze", "Glaze", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Frostfire duration 6s → 7s",
					"2: 8s. Frostfire crafts apply 3 Chill (from 2)",
					"3: Fire-only hits vs Frostfire refresh it 2s and apply 1 Chill; Ice-only hits vs Frostfire refresh it 2s and apply Burn equal to 15% of the hit",
				]), "fire / ice / frostfire"),
				_t("cinderfrost_mid_ash", "Ash", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% fire and shadow damage", "2: +6%", "3: +9%"]), "fire / shadow"),
				_t("cinderfrost_cinder_sootbrand", "Sootbrand", 3, TalentDef.TYPE_INTERACTION, _p(["1: Fire hits apply 1 Afflict stack, including aura, Ground AOE, and wall ticks", "2: 2 stacks", "3: 3 stacks"]), "fire / afflicted"),
				_t("cinderfrost_cinder_wraithfire", "Wraithfire", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Replaces dodge with a 6m blink; landing nova 25 fire+shadow in 2.2m",
					"2: 8m blink, nova 40, fire spells cost 8% less",
					"3: 10m blink, nova 70 in 2.8m, apply 6 Afflict, fire spells cost 15% less. Dodge cooldown still applies. Not a D/F skill",
				]), "fire / shadow / afflicted"),
			],
		],
		_t("cinderfrost_ult_ashen_crucible", "Ashen Crucible", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: Aimed dash, max 10m, 32s CD. First dash absorbs Afflict. 6s fuse window. Recast: release as Burn and detonate Frostfire in 10m for 30 fire + 30 ice + 1s root"]), "fire / ice / frostfire / burn / afflicted", "ashen_crucible")
	))


static func _aegis() -> ClassDef:
	return _spec("aegis", "Ironclad", "tank", TalentTreeDef.make_choice(
		"aegis", "Ironclad", "live through hits vs keep aggro", "Plate", "Grudge",
		[
			[
				_t("aegis_plate_slab", "Slab", 3, TalentDef.TYPE_PASSIVE, _p(["1: +15% max health (500 → 575)", "2: +28% (500 → 640)", "3: +40% (500 → 700)"]), "none"),
				_t("aegis_mid_stamina", "Stamina", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% max health", "2: +7%", "3: +10%"]), "none"),
				_t("aegis_grudge_spite", "Spite", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% damage and 5% DR", "2: +7% damage and 8% DR", "3: +10% damage and 12% DR"]), "none"),
			],
			[
				_t("aegis_plate_shared_plate", "Shared Plate", 2, TalentDef.TYPE_INTERACTION, _p(["1: Protection shield on an ally also gives you 50 shield for 6s (once per cast)", "2: 80 shield"]), "protection / shield"),
				_t("aegis_grudge_goad", "Goad", 2, TalentDef.TYPE_INTERACTION, _p(["1: Crafted Target on an enemy taunts 2s", "2: 3s. After Goad: +20% move for 2s"]), "target / threat"),
			],
			[
				_t("aegis_plate_anointed", "Anointed", 2, TalentDef.TYPE_INTERACTION, _p(["1: While Holy Blessing: each hit generates 25 threat on that attacker", "2: 40 threat, and divine-heal 40, 1s ICD"]), "divine / threat"),
				_t("aegis_mid_guard", "Guard", 3, TalentDef.TYPE_PASSIVE, _p(["1: +2% damage reduction", "2: +4%", "3: +6%"]), "none"),
				_t("aegis_mid_resolve", "Resolve", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% damage", "2: +6%", "3: +9%"]), "none"),
				_t("aegis_grudge_marked_prey", "Marked Prey", 3, TalentDef.TYPE_PASSIVE, _p(["1: Enemies you hold aggro on take +4% damage from you only", "2: +7%", "3: +10%"]), "threat"),
			],
			[
				_auto("aegis_auto_iron_fist", "Iron Fist", "1: Melee 180 physical, 2.4m, 0.85s. +24 extra threat. 10 raid mana per hit. Dodge 8m, CD 3.6s", true),
				_t("aegis_mid_heavy_hands", "Heavy Hands", 3, TalentDef.TYPE_PASSIVE, _p(["1: Autos +6 extra threat", "2: +12", "3: +18"]), "auto"),
				_auto("aegis_auto_goading_shot", "Goading Shot", "1: Stay ranged. Autos +40 threat and 8 raid mana"),
			],
			[
				_t("aegis_plate_second_skin", "Second Skin", 3, TalentDef.TYPE_INTERACTION, _p(["1: Shield absorb Protection-heals 50. 1s ICD", "2: 90", "3: 90, and +20% shield amount"]), "protection / shield"),
				_t("aegis_mid_plating", "Plating", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% shield amount", "2: +8%", "3: +12%"]), "shield"),
				_t("aegis_grudge_claim", "Claim", 3, TalentDef.TYPE_INTERACTION, _p(["1: Damaging crafts +12% threat", "2: +20%", "3: +35%"]), "threat"),
			],
			[
				_t("aegis_plate_brace", "Brace", 3, TalentDef.TYPE_INTERACTION, _p(["1: While shielded, 10% DR", "2: 16% DR", "3: 22% DR. Also divine-heal 40 every 1s while shielded"]), "shield / divine"),
				_t("aegis_mid_grit", "Grit", 3, TalentDef.TYPE_PASSIVE, _p(["1: +2% DR while shielded", "2: +4%", "3: +6%"]), "shield"),
				_t("aegis_grudge_ire", "Ire", 3, TalentDef.TYPE_INTERACTION, _p(["1: Shield = 15% of threat that hit generated, 6s, cap 80", "2: 25%, cap 120", "3: Also Nova and Burst generate 2.5× threat"]), "threat / shield"),
			],
		],
		_t("aegis_ult_iron_rampage", "Iron Rampage", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: Instant self, 7s, 22s CD. 40% DR, +20% damage, +40% threat from damaging crafts, +10% move. Each hit taken grants 60 shield for 6s"]), "threat / shield", "iron_rampage")
	))


static func _bastion() -> ClassDef:
	return _spec("bastion", "Holdfast", "tank", TalentTreeDef.make_choice(
		"bastion", "Holdfast", "hold space vs peel allies", "Rampart", "Oath",
		[
			[
				_t("bastion_rampart_footing", "Footing", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% Ground AOE damage, healing, and shielding", "2: +7%", "3: +10%"]), "ground_aoe"),
				_t("bastion_mid_foundation", "Foundation", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% Ground AOE damage, healing, and shielding", "2: +7%", "3: +10%"]), "ground_aoe"),
				_t("bastion_oath_vow", "Vow", 3, TalentDef.TYPE_PASSIVE, _p(["1: +6% shield amount on allies. +4% healing dealt and received", "2: +12% / +8%", "3: +18% / +12%"]), "shield"),
			],
			[
				_t("bastion_rampart_undertow", "Undertow", 2, TalentDef.TYPE_INTERACTION, _p(["1: Wind Ground AOE: 2 charges", "2: 20% faster recharge. Each pull: 50 threat per yanked enemy"]), "wind / ground_aoe / threat"),
				_t("bastion_oath_halo", "Halo", 2, TalentDef.TYPE_INTERACTION, _p(["1: Divine Blessing at 125% rate. Cap 15% DR (from 10%), 8s", "2: 150% rate, cap 20%"]), "divine"),
			],
			[
				_t("bastion_rampart_masonry", "Masonry", 3, TalentDef.TYPE_PASSIVE, _p(["1: +10% wall HP and 8% wall CDR", "2: +20% HP and 14% CDR", "3: +30% HP and 20% CDR (35s → 28s)"]), "wall"),
				_t("bastion_mid_oathbound", "Oathbound", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% healing received", "2: +6%", "3: +9%"]), "none"),
				_t("bastion_mid_bastion", "Keep", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% wall HP", "2: +8%", "3: +12%"]), "wall"),
				_t("bastion_oath_cover", "Cover", 2, TalentDef.TYPE_INTERACTION, _p(["1: Ally Protection shields last +1.5s (6s → 7.5s)", "2: +3s (6s → 9s)"]), "protection / shield"),
			],
			[
				_auto("bastion_auto_ward_strike", "Ward Strike", "1: Melee 140 physical, 2.4m. +16 extra threat. Nearest ally 20 shield for 4s", true),
				_auto("bastion_auto_aegis_shot", "Aegis Shot", "1: Stay ranged. Autos grant you 25 shield for 4s"),
			],
			[
				_t("bastion_rampart_palisade", "Palisade", 3, TalentDef.TYPE_INTERACTION, _p(["1: Wall length +12%", "2: +20%", "3: +35% length and walls last +1.5s"]), "wall"),
				_t("bastion_mid_ward", "Ward", 3, TalentDef.TYPE_PASSIVE, _p(["1: Autos grant you 8 shield for 4s", "2: 16", "3: 24"]), "auto"),
				_t("bastion_mid_barricade", "Barricade", 3, TalentDef.TYPE_PASSIVE, _p(["1: +2% damage reduction", "2: +4%", "3: +6%"]), "none"),
				_t("bastion_oath_redirect", "Redirect", 3, TalentDef.TYPE_INTERACTION, _p(["1: 6% of threat from damage allies deal within 8m is moved to you", "2: 12%", "3: 18%"]), "threat"),
			],
			[
				_t("bastion_rampart_battlement", "Battlement", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Normal mobs taunt onto the wall until it dies or expires",
					"2: +2.5m leash. Protection Wall channel 5s, 35% slow",
					"3: Heal 35% of damage the wall absorbs as that wall's infusion",
				]), "wall / threat"),
				_t("bastion_mid_aegis_wall", "Aegis Wall", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% shield amount on allies", "2: +8%", "3: +12%"]), "shield"),
				_t("bastion_oath_bodyguard", "Bodyguard", 3, TalentDef.TYPE_INTERACTION, _p(["1: Allies within 6m take 8% less", "2: 15%", "3: 25% of prevented damage becomes a 6s shield on you"]), "shield"),
			],
		],
		_t("bastion_ult_hearthguard", "Hearthguard", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: Ground 4.5m, 5s, 22s CD. Pulse 60 shield and 24 threat every 1s. You: 30% DR. Lowest-HP ally: 30% of their damage redirects to you for 4s and they gain 200 extra shield"]), "ground_aoe / shield / threat", "hearthguard")
	))


static func _wildroot() -> ClassDef:
	return _spec("wildroot", "Lifegrove", "healer", TalentTreeDef.make_choice(
		"wildroot", "Lifegrove", "stack Rejuv vs plant the ring", "Canopy", "Grove",
		[
			[
				_t("wildroot_canopy_greenheart", "Greenheart", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% nature healing", "2: +7%", "3: +10%"]), "nature"),
				_t("wildroot_mid_vitality", "Vitality", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% nature healing", "2: +7%", "3: +10%"]), "nature"),
				_t("wildroot_grove_loam", "Loam", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% healing from nature Ground AOE, Aura, and Wall", "2: +7%", "3: +10%"]), "ground_aoe / aura / wall / nature"),
			],
			[
				_t("wildroot_canopy_deep_roots", "Deep Roots", 2, TalentDef.TYPE_INTERACTION, _p(["1: Nature Bolt and Ray apply 2 Rejuvenation stacks instead of 1", "2: also Nature Target"]), "bolt / ray / rejuvenation"),
				_t("wildroot_grove_thicket", "Thicket", 2, TalentDef.TYPE_INTERACTION, _p(["1: Nature Ground AOE lasts 7s (from 6)", "2: 8s and radius +15%"]), "ground_aoe / nature"),
			],
			[
				_t("wildroot_canopy_evergreen", "Evergreen", 3, TalentDef.TYPE_PASSIVE, _p(["1: Rejuvenation HPS +4% (6 → 6.2 per stack)", "2: +7%", "3: +10% (6 → 6.6)"]), "rejuvenation"),
				_t("wildroot_mid_bloom", "Bloom", 3, TalentDef.TYPE_PASSIVE, _p(["1: Rejuvenation HPS +4%", "2: +7%", "3: +10%"]), "rejuvenation"),
				_t("wildroot_mid_canopy", "Canopy", 3, TalentDef.TYPE_PASSIVE, _p(["1: +2% healing dealt", "2: +4%", "3: +6%"]), "none"),
				_t("wildroot_grove_ringward", "Ringward", 2, TalentDef.TYPE_INTERACTION, _p(["1: Allies inside your nature Wall ring take 5% less damage and +5% healing received", "2: 8% / +8%"]), "wall / nature"),
			],
			[
				_auto("wildroot_auto_bloom_touch", "Bloom Touch", "1: Ally click 14 nature + 1 Rejuvenation. Enemy click baseline 32"),
				_t("wildroot_mid_dew", "Dew", 3, TalentDef.TYPE_PASSIVE, _p(["1: Ally autos heal +4", "2: +8", "3: +12"]), "auto"),
				_auto("wildroot_auto_grove_pulse", "Grove Pulse", "1: Enemy click pulses 25% of the hit as nature heal to the lowest ally in 8.5m"),
			],
			[
				_t("wildroot_canopy_photosynthesis", "Photosynthesis", 3, TalentDef.TYPE_INTERACTION, _p(["1: Applying Rejuv to an ally who already has it also heals 8 instantly", "2: 14", "3: 18"]), "rejuvenation"),
				_t("wildroot_mid_thorns", "Thorns", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% healing from nature Ground AOE, Aura, and Wall", "2: +8%", "3: +12%"]), "ground_aoe / nature"),
				_t("wildroot_grove_bramble", "Bramble", 3, TalentDef.TYPE_INTERACTION, _p(["1: Enemies on nature wall segments take 8 nature per second", "2: 12 per second", "3: 20 per second and rooted 0.3s every 2s"]), "wall / nature"),
			],
			[
				_t("wildroot_canopy_lifebloom", "Lifebloom", 3, TalentDef.TYPE_INTERACTION, _p([
					"1: Nature Target on an ally applies Lifebloom: 14 HPS, 8s, one ally",
					"2: 24 HPS. When Lifebloom expires or is consumed, bloom for 60",
					"3: Bloom 90. Allies at 12 Rejuv take +12% from your nature crafts",
				]), "target / nature / rejuvenation"),
				_t("wildroot_mid_groveheart", "Groveheart", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% nature healing", "2: +8%", "3: +12%"]), "nature"),
				_t("wildroot_grove_germinate", "Germinate", 3, TalentDef.TYPE_INTERACTION, _p(["1: First heal from each nature Ground AOE grants a 40 shield for 4s", "2: 70 shield and 1 Rejuv stack", "3: 2 Rejuv stacks"]), "ground_aoe / shield / rejuvenation"),
			],
		],
		_t("wildroot_ult_worldbloom", "Worldbloom", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: Ground 7m, 6s, 36s CD. Rooted. Pulse 40 nature + 1 Rejuv every 1s. Recast or expire: consume Rejuv inside, heal 22 per stack. Lifebloom bloom 90 + 15% DR 3s. Nature Wall CD resets. Then 3s Drought"]), "ground_aoe / nature / rejuvenation", "worldbloom")
	))


static func _tempest() -> ClassDef:
	return _spec("tempest", "Stormpulse", "healer / dps", TalentTreeDef.make_choice(
		"tempest", "Stormpulse", "damage that heals vs full lightning", "Stormbloom", "Thunderhead",
		[
			[
				_t("tempest_stormbloom_galvanic_grove", "Galvanic Grove", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% lightning damage on crafts that also have Nature. +4% healing from the nature atonement pulse", "2: +6% / +7%", "3: +8% / +10%"]), "lightning / nature"),
				_t("tempest_mid_charge", "Charge", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% lightning damage", "2: +7%", "3: +10%"]), "lightning"),
				_t("tempest_thunderhead_high_voltage", "High Voltage", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% lightning damage. +3% lightning damage to enemies with 50+ Shock", "2: +7% / +6%", "3: +10% / +8%"]), "lightning / shocked"),
			],
			[
				_t("tempest_stormbloom_stormbond", "Stormbond", 2, TalentDef.TYPE_INTERACTION, _p(["1: A nature heal on an ally applies Stormbond 8s, max 2 allies", "2: Pulse heals Stormbonded only (split)"]), "nature / rejuvenation"),
				_t("tempest_thunderhead_arc", "Arc", 2, TalentDef.TYPE_INTERACTION, _p(["1: Shock chain hops 4 (from 3)", "2: bounce range 7 → 9m"]), "lightning / shocked"),
			],
			[
				_t("tempest_stormbloom_feedback", "Feedback", 2, TalentDef.TYPE_INTERACTION, _p(["1: Shock chain hops also trigger the nature pulse at 50% strength", "2: full strength"]), "shocked / lightning / nature"),
				_t("tempest_mid_pulse", "Pulse", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% healing from the nature atonement pulse", "2: +6%", "3: +10%"]), "nature"),
				_t("tempest_mid_static_field", "Static Field", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% lightning damage to enemies with 50+ Shock", "2: +6%", "3: +9%"]), "shocked"),
				_t("tempest_thunderhead_static", "Static", 2, TalentDef.TYPE_INTERACTION, _p(["1: Enemies that die with 50+ Shock explode for 30 lightning in Burst radius", "2: 45 lightning"]), "shocked / burst"),
			],
			[
				_auto("tempest_auto_storm_touch", "Storm Touch", "1: Lightning vs enemies (1 Shock). Allies: 14 nature + 1 Rejuvenation"),
				_auto("tempest_auto_high_volt_shot", "High Volt Shot", "1: Lightning vs enemies (1 Shock). +8% lightning on autos. No ally heal"),
			],
			[
				_t("tempest_stormbloom_seedstorm", "Seedstorm", 3, TalentDef.TYPE_INTERACTION, _p(["1: Lightning+Nature enemy hits apply 1 Seeded stack without Alteration", "2: 2 stacks", "3: 3 stacks"]), "lightning / nature / altered"),
				_t("tempest_mid_spark", "Spark", 3, TalentDef.TYPE_PASSIVE, _p(["1: Autos +4 damage", "2: +8", "3: +12"]), "auto"),
				_t("tempest_mid_conduit", "Conduit", 3, TalentDef.TYPE_PASSIVE, _p(["1: +4% lightning damage", "2: +8%", "3: +12%"]), "lightning"),
				_t("tempest_thunderhead_charge_coil", "Charge Coil", 3, TalentDef.TYPE_INTERACTION, _p(["1: Lightning hits apply 2 Shock (from 1)", "2: 3 Shock", "3: 4 Shock"]), "lightning / shocked"),
			],
			[
				_t("tempest_stormbloom_atonement", "Atonement", 3, TalentDef.TYPE_INTERACTION, _p(["1: Nature pulse 25% → 35% of dealt", "2: 45%", "3: 55% and pulse range 8.5 → 12m"]), "nature / lightning"),
				_t("tempest_mid_stormheart", "Stormheart", 3, TalentDef.TYPE_PASSIVE, _p(["1: +3% lightning and nature", "2: +6%", "3: +9%"]), "lightning / nature"),
				_t("tempest_thunderhead_totem_surge", "Totem Surge", 3, TalentDef.TYPE_INTERACTION, _p(["1: Lightning Wall first hop 40% → 50%", "2: 70%", "3: 70% and each totem tick applies 2 Shock"]), "wall / lightning / shocked"),
			],
		],
		_t("tempest_ult_eye_of_tempest", "Eye of Tempest", 1, TalentDef.TYPE_ULTIMATE, PackedStringArray(["1: Instant self, 8s, 34s CD. Storm cloud 6m. Enemies inside: +1 Shock and 16 lightning every 0.5s. Lightning crafts from inside count as Nature for a 40% pulse, 0 bounce falloff, +1 hop. Recast detach; recast jump 10m. Stormbond cap 2 → 3"]), "lightning / nature / shocked", "eye_of_tempest")
	))
