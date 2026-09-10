class_name SpellCatalog
extends Object

const HOTKEYS := ["Q", "W", "E", "R", "D", "F"]
const CRAFTED_HOTKEYS := ["Q", "W", "E", "R"]
const CRAFT_SLOTS := 4
const SKILL_SLOTS := 2
const BAR_SLOTS := 6


const _LEGACY_BASES := {
	"energy_bolt": "bolt",
	"cone_blast": "bolt",
	"chain_spark": "missiles",
	"sanctuary": "ground_aoe",
	"ward": "target",
	"shield": "target",
	"bastion": "nova",
}


const _LEGACY_INFUSIONS := {
	"frost": "ice",
	"storm": "lightning",
	"holy": "divine",
}

const _LEGACY_AUGMENTS := {
	"extra_projectiles": "echo",
	"swift_cast": "haste",
	"alteration": "altered",
	"altered": "altered",
}

const _INFUSION_TO_AUGMENT := {
	"alteration": "altered",
	"altered": "altered",
}

static var _base_list: Array[SpellBase] = []
static var _base_by_id: Dictionary = {}
static var _infusion_list: Array[SpellInfusion] = []
static var _infusion_by_id: Dictionary = {}
static var _augment_list: Array[SpellAugment] = []
static var _augment_by_id: Dictionary = {}
static var _skill_base_by_id: Dictionary = {}


static func invalidate() -> void:
	_base_list.clear()
	_base_by_id.clear()
	_infusion_list.clear()
	_infusion_by_id.clear()
	_augment_list.clear()
	_augment_by_id.clear()
	_skill_base_by_id.clear()


static func default_loadout() -> Array:
	return [
		SpellRecipe.make("bolt", PackedStringArray(["fire"])),
		SpellRecipe.make("missiles", PackedStringArray(["lightning"])),
		SpellRecipe.make("ground_aoe", PackedStringArray(["ice"])),
		SpellRecipe.make("bolt", PackedStringArray(["ice"])),
	]


static func all_bases() -> Array[SpellBase]:
	_ensure_bases()
	return _base_list


static func implemented_bases() -> Array[SpellBase]:
	var out: Array[SpellBase] = []
	for b in all_bases():
		if b.available:
			out.append(b)
	return out


static func is_base_available(id: String) -> bool:
	_ensure_bases()
	var b: SpellBase = _base_by_id.get(id, null)
	return b != null and b.available


static func migrate_base_id(id: String) -> String:
	var mapped := String(_LEGACY_BASES.get(id, id))
	if is_base_available(mapped):
		return mapped
	return "bolt"


static func all_infusions() -> Array[SpellInfusion]:
	_ensure_infusions()
	return _infusion_list


static func all_offensive_infusions() -> Array[SpellInfusion]:
	var out: Array[SpellInfusion] = []
	for inf in all_infusions():
		if inf.offensive and not inf.utility:
			out.append(inf)
	return out


static func all_utility_infusions() -> Array[SpellInfusion]:
	var out: Array[SpellInfusion] = []
	for inf in all_infusions():
		if inf.utility:
			out.append(inf)
	return out


static func all_defensive_infusions() -> Array[SpellInfusion]:
	var out: Array[SpellInfusion] = []
	for inf in all_infusions():
		if inf.beneficial:
			out.append(inf)
	return out


static func migrate_infusion_id(id: String) -> String:
	return String(_LEGACY_INFUSIONS.get(id, id))


static func infusion_becomes_augment(id: String) -> String:
	var mapped := String(_INFUSION_TO_AUGMENT.get(id, ""))
	if mapped.is_empty():
		mapped = String(_INFUSION_TO_AUGMENT.get(migrate_infusion_id(id), ""))
	return mapped


static func all_augments() -> Array[SpellAugment]:
	_ensure_augments()
	return _augment_list


static func augment_fits(base_id: String, augment_id: String) -> bool:
	return augment_skip_reason(base_id, augment_id).is_empty()


static func tags_for(base_id: String) -> PackedStringArray:
	return SpellTags.for_base(resolve_base(base_id))


static func is_craft_index(index: int) -> bool:
	return index >= 0 and index < CRAFT_SLOTS


static func is_skill_index(index: int) -> bool:
	return index >= CRAFT_SLOTS and index < BAR_SLOTS


static func is_class_skill(id: String) -> bool:
	return not id.is_empty() and ClassCatalog.get_skill(id) != null


static func resolve_base(id: String) -> SpellBase:
	if id.is_empty():
		return null
	_ensure_bases()
	var b: SpellBase = _base_by_id.get(id, null)
	if b != null:
		return b
	return skill_as_base(id)


static func skill_as_base(skill_id: String) -> SpellBase:
	if skill_id.is_empty():
		return null
	if _skill_base_by_id.has(skill_id):
		return _skill_base_by_id[skill_id]
	var skill := ClassCatalog.get_skill(skill_id)
	if skill == null:
		return null
	var ab := ClassSkillCompiler.compile(skill_id, "D")
	var b := SpellBase.new()
	b.id = skill.id
	b.display_name = skill.display_name
	b.noun = skill.display_name
	b.icon_id = ab.icon_id if not ab.icon_id.is_empty() else skill.icon_id
	b.description = skill.description if not skill.description.is_empty() else ab.description
	b.available = true
	b.max_infusions = 0
	b.delivery = ab.delivery
	b.target_mode = ab.target_mode
	b.cost_per_tick = ab.cost_per_tick
	b.is_toggle = ab.is_toggle
	b.friendly_only = ab.friendly_only
	b.mana_cost = ab.mana_cost
	b.cooldown = ab.cooldown
	b.range = ab.range
	b.damage = ab.damage
	b.heal = ab.heal
	b.shield = ab.shield
	b.shield_duration = ab.shield_duration
	b.cast_time = ab.cast_time
	b.color = ab.color
	b.skillshot_width = ab.skillshot_width
	b.skillshot_speed = ab.skillshot_speed
	b.skillshot_length = ab.skillshot_length
	b.aoe_radius = ab.aoe_radius
	b.aoe_radius_max = ab.aoe_radius_max
	b.damage_max = ab.damage_max
	b.splash_radius = ab.splash_radius
	b.splash_ratio = ab.splash_ratio
	b.cone_angle = ab.cone_angle
	b.chain_bounces = ab.chain_bounces
	b.bounce_range = ab.bounce_range
	b.bounce_delay = ab.bounce_delay
	b.is_channel = ab.is_channel
	b.channel_time = ab.channel_time
	b.zone_duration = ab.zone_duration
	b.tick_interval = ab.tick_interval
	b.tick_damage = ab.tick_damage
	b.tick_shield = ab.tick_shield
	b.gcd_exempt = ab.gcd_exempt
	b.vfx_scene = ab.vfx_scene
	b.vfx_scale = ab.vfx_scale
	b.vfx_yaw = ab.vfx_yaw
	b.vfx_primary = ab.vfx_primary
	b.vfx_secondary = ab.vfx_secondary
	b.vfx_tertiary = ab.vfx_tertiary
	b.extra_tags = skill.extra_tags.duplicate()
	_skill_base_by_id[skill_id] = b
	return b


static func augment_skip_reason(base_id: String, augment_id: String) -> String:
	_ensure_augments()
	return SpellTags.skip_reason(resolve_base(base_id), get_augment(augment_id))


static func augment_conflict_reason(recipe: SpellRecipe, augment_id: String) -> String:
	if recipe == null:
		return ""
	var aug := get_augment(augment_id)
	if aug == null or recipe.has_augment(augment_id):
		return ""
	for id in recipe.augment_ids:
		var other := get_augment(id)
		if other == null:
			continue
		if aug.exclusive_with.has(id) or other.exclusive_with.has(augment_id):
			return "Cannot be combined with %s." % other.display_name
	return ""


static func recipe_augment_skip_reason(recipe: SpellRecipe, augment_id: String) -> String:
	if recipe == null:
		return augment_skip_reason("", augment_id)
	var skip := augment_skip_reason(recipe.base_id, augment_id)
	if not skip.is_empty():
		return skip
	return augment_conflict_reason(recipe, augment_id)


static func _aura_only() -> PackedInt32Array:
	return PackedInt32Array([AbilityDef.Delivery.AURA])


static func _bolt_delivery() -> PackedInt32Array:
	return PackedInt32Array([AbilityDef.Delivery.BOLT])


static func _pct_off(mult: float) -> int:
	return int(round((1.0 - mult) * 100.0))


static func _pct_on(mult: float) -> int:
	return int(round((mult - 1.0) * 100.0))


static func migrate_augment_id(id: String) -> String:
	return String(_LEGACY_AUGMENTS.get(id, id))


static func get_base(id: String) -> SpellBase:
	_ensure_bases()
	var b: SpellBase = _base_by_id.get(id, null)
	if b:
		return b
	return _base_by_id.get("bolt", bolt())


static func get_infusion(id: String) -> SpellInfusion:
	_ensure_infusions()
	var want := migrate_infusion_id(id)
	return _infusion_by_id.get(want, null)


static func get_augment(id: String) -> SpellAugment:
	_ensure_augments()
	var want := migrate_augment_id(id)
	return _augment_by_id.get(want, null)


static func _ensure_bases() -> void:
	if not _base_list.is_empty():
		return
	_base_list = [
		bolt(),
		missiles(),
		ground_aoe(),
		aoe_explosion(),
		aura(),
		ray(),
		meteor(),
		nova(),
		wall(),
		target(),
		wave(),
	]
	for b in _base_list:
		_base_by_id[b.id] = b


static func _ensure_infusions() -> void:
	if not _infusion_list.is_empty():
		return
	_infusion_list = [fire(), ice(), lightning(), shadow(), wind(), illusion(), nature(), divine(), protection()]
	for inf in _infusion_list:
		_infusion_by_id[inf.id] = inf


static func _ensure_augments() -> void:
	if not _augment_list.is_empty():
		return
	_augment_list = [
		readiness(),
		reach(),
		efficiency(),
		haste(),
		echo(),
		widen(),
		precision(),
		lethality(),
		snap_cast(),
		alteration(),
		menace(),
		subtlety(),
		volley(),
		fan(),
		pierce(),
		focus(),
		spread(),
		lingering(),
		ritual(),
		momentum(),
		siphon(),
		cleave(),
		execute(),
		gambit(),
		heartbeat(),
		slow_burn(),
		anchor(),
		aftershock(),
		crowd(),
		stillness(),
	]
	for aug in _augment_list:
		SpellTags.bind_augment(aug)
		_augment_by_id[aug.id] = aug


static func bolt() -> SpellBase:
	var b := SpellBase.new()
	b.id = "bolt"
	b.display_name = "Bolt"
	b.noun = "Bolt"
	b.icon_id = "bolt"
	b.available = true
	b.delivery = AbilityDef.Delivery.BOLT
	b.description = "Thin skillshot. Hits the first unit."
	b.target_mode = AbilityDef.TargetMode.SKILLSHOT
	b.mana_cost = 18.0
	b.cooldown = 2.0
	b.range = 11.0
	b.damage = 42.0
	b.cast_time = 0.15
	b.color = Color(0.72, 0.82, 1.0)
	b.skillshot_width = 0.55
	b.skillshot_speed = 15.0
	b.skillshot_length = 11.0
	b.vfx_scene = AbilityFx.MAGIC_BOLT
	b.vfx_scale = 1.25
	b.vfx_yaw = 0.0
	b.vfx_primary = Color(0.82, 0.9, 1.0)
	b.vfx_secondary = Color(0.42, 0.58, 0.95)
	b.vfx_tertiary = Color(0.95, 0.98, 1.0)
	return CombatBalance.tune_base(b)


static func missiles() -> SpellBase:
	var b := SpellBase.new()
	b.id = "missiles"
	b.display_name = "Missiles"
	b.noun = "Missiles"
	b.icon_id = "missiles"
	b.available = true
	b.delivery = AbilityDef.Delivery.MISSILES
	b.description = "Channel volleys of 3 homing missiles at one target. Each volley costs mana. Missiles pass through other units and only hit the locked target. Walls still block and absorb them."
	b.target_mode = AbilityDef.TargetMode.UNIT
	b.mana_cost = 22.0
	b.cooldown = 4.0
	b.range = 16.0
	b.damage = 24.0
	b.cast_time = 0.0
	b.is_channel = true
	b.channel_time = 2.4
	b.tick_interval = 0.4
	b.cost_per_tick = true
	b.color = Color(0.75, 0.85, 1.0)
	b.skillshot_speed = 26.0
	b.vfx_scene = AbilityFx.MAGIC_JAVELIN
	b.vfx_scale = 0.38
	b.vfx_yaw = -PI * 0.5
	b.vfx_primary = Color(0.75, 0.9, 1.0)
	b.vfx_secondary = Color(0.35, 0.55, 1.0)
	b.vfx_tertiary = Color(1.0, 0.95, 0.55)
	return CombatBalance.tune_base(b)


static func ground_aoe() -> SpellBase:
	var b := SpellBase.new()
	b.id = "ground_aoe"
	b.display_name = "Ground AOE"
	b.noun = "Field"
	b.icon_id = "ground_aoe"
	b.available = true
	b.delivery = AbilityDef.Delivery.GROUND_AOE
	b.description = "Ground placed area that damages or heals over time."
	b.target_mode = AbilityDef.TargetMode.GROUND
	b.mana_cost = 28.0
	b.cooldown = 18.0
	b.range = 12.0
	b.damage = 0.0
	b.cast_time = 0.0
	b.aoe_radius = 9.36
	b.zone_duration = 6.0
	b.tick_interval = 0.5
	b.tick_damage = 14.0
	b.color = Color(0.55, 0.78, 1.0)
	b.vfx_scale = 1.1
	b.vfx_primary = Color(0.55, 0.88, 1.0)
	b.vfx_secondary = Color(0.22, 0.48, 0.95)
	b.vfx_tertiary = Color(0.85, 0.95, 1.0)
	return CombatBalance.tune_base(b)


static func aoe_explosion() -> SpellBase:
	var b := SpellBase.new()
	b.id = "aoe_explosion"
	b.display_name = "Burst"
	b.noun = "Burst"
	b.icon_id = "burst"
	b.available = true
	b.delivery = AbilityDef.Delivery.AOE_EXPLOSION
	b.description = "Place a circle, then detonate."
	b.target_mode = AbilityDef.TargetMode.GROUND
	b.mana_cost = 55.0
	b.cooldown = 10.0
	b.range = 12.0
	b.damage = 140.0
	b.cast_time = 0.85
	b.aoe_radius = 3.6
	b.color = Color(1.0, 0.5, 0.18)
	b.vfx_scene = AbilityFx.GROUND_EXPLOSION
	b.vfx_scale = 0.85
	b.vfx_primary = Color(1.0, 0.72, 0.28)
	b.vfx_secondary = Color(1.0, 0.38, 0.08)
	b.vfx_tertiary = Color(1.0, 0.92, 0.55)
	return CombatBalance.tune_base(b)


static func aura() -> SpellBase:
	var b := SpellBase.new()
	b.id = "aura"
	b.display_name = "Aura"
	b.noun = "Aura"
	b.icon_id = "aura"
	b.available = true
	b.delivery = AbilityDef.Delivery.AURA
	b.description = "Toggle a ring around you. Each pulse costs mana. Several Auras can be up at once. The same infusion cannot be on two of them, except Wind and Illusion. Does not use the GCD. Turning it off starts a 1.5s cooldown so you cannot spam it."
	b.target_mode = AbilityDef.TargetMode.INSTANT
	b.mana_cost = 8.0
	b.cooldown = 1.5
	b.range = 0.0
	b.damage = 0.0
	b.cast_time = 0.0
	b.is_toggle = true
	b.gcd_exempt = true
	b.cost_per_tick = true
	b.aoe_radius = 6.0
	b.tick_interval = 0.5
	b.tick_damage = 10.0
	b.color = Color(0.85, 0.55, 1.0)
	b.vfx_primary = Color(0.92, 0.72, 1.0)
	b.vfx_secondary = Color(0.55, 0.28, 0.95)
	b.vfx_tertiary = Color(1.0, 0.95, 0.7)
	return CombatBalance.tune_base(b)


static func ray() -> SpellBase:
	var b := SpellBase.new()
	b.id = "ray"
	b.display_name = "Ray"
	b.noun = "Ray"
	b.icon_id = "ray"
	b.available = true
	b.delivery = AbilityDef.Delivery.RAY
	b.description = "Channel a beam toward your cursor. The beam always follows your mouse and stops at max range or a wall. Hits the first unit along the beam. Each pulse costs mana."
	b.target_mode = AbilityDef.TargetMode.SKILLSHOT
	b.mana_cost = 14.0
	b.cooldown = 8.0
	b.range = 14.0
	b.damage = 40.0
	b.cast_time = 1.5
	b.is_channel = true
	b.channel_time = 2.5
	b.tick_interval = 0.25
	b.cost_per_tick = true
	b.skillshot_width = 0.99
	b.skillshot_length = 14.0
	b.color = Color(1.0, 0.82, 0.35)
	b.vfx_primary = Color(1.0, 0.92, 0.55)
	b.vfx_secondary = Color(1.0, 0.62, 0.18)
	b.vfx_tertiary = Color(1.0, 0.98, 0.82)
	return CombatBalance.tune_base(b)


static func meteor() -> SpellBase:
	var b := SpellBase.new()
	b.id = "meteor"
	b.display_name = "Meteor"
	b.noun = "Meteor"
	b.icon_id = "meteor"
	b.available = true
	b.delivery = AbilityDef.Delivery.METEOR
	b.description = "A huge rock falls on the target circle."
	b.target_mode = AbilityDef.TargetMode.GROUND
	b.mana_cost = 120.0
	b.cooldown = 30.0
	b.range = 20.0
	b.damage = 500.0
	b.cast_time = 2.2
	b.aoe_radius = 4.2
	b.color = Color(1.0, 0.35, 0.08)
	b.vfx_scene = AbilityFx.GROUND_EXPLOSION
	b.vfx_scale = 1.2
	b.vfx_primary = Color(1.0, 0.72, 0.22)
	b.vfx_secondary = Color(1.0, 0.32, 0.06)
	b.vfx_tertiary = Color(1.0, 0.92, 0.45)
	return CombatBalance.tune_base(b)


static func nova() -> SpellBase:
	var b := SpellBase.new()
	b.id = "nova"
	b.display_name = "Nova"
	b.noun = "Nova"
	b.icon_id = "nova"
	b.available = true
	b.delivery = AbilityDef.Delivery.NOVA
	b.description = "Blast around you."
	b.target_mode = AbilityDef.TargetMode.INSTANT
	b.mana_cost = 60.0
	b.cooldown = 10.0
	b.range = 0.0
	b.damage = 130.0
	b.cast_time = 0.0
	b.aoe_radius = 5.5
	b.color = Color(0.85, 0.45, 1.0)
	b.vfx_scene = AbilityFx.GROUND_EXPLOSION
	b.vfx_scale = 1.1
	b.vfx_primary = Color(0.95, 0.72, 1.0)
	b.vfx_secondary = Color(0.62, 0.28, 1.0)
	b.vfx_tertiary = Color(1.0, 0.95, 0.7)
	return CombatBalance.tune_base(b)


static func wall() -> SpellBase:
	var b := SpellBase.new()
	b.id = "wall"
	b.display_name = "Wall"
	b.noun = "Wall"
	b.icon_id = "wall"
	b.available = true
	b.delivery = AbilityDef.Delivery.WALL
	b.max_infusions = 1
	b.description = "A rectangular barrier snaps up and shoves units out of the way.\n\nOne infusion only. Overcharge does not apply. 800 HP. Takes hits from any projectile. Wall damage ignores infusion damage bonuses. Breaking it or waiting it out detonates the stored damage."
	b.target_mode = AbilityDef.TargetMode.GROUND
	b.mana_cost = 70.0
	b.cooldown = 35.0
	b.range = 10.0
	b.damage = 160.0
	b.cast_time = 0.15
	b.aoe_radius = 1.15
	b.skillshot_width = 4.8
	b.zone_duration = 8.0
	b.color = Color(0.7, 0.78, 0.88)
	b.vfx_primary = Color(0.88, 0.92, 1.0)
	b.vfx_secondary = Color(0.45, 0.58, 0.82)
	b.vfx_tertiary = Color(0.95, 0.97, 1.0)
	return CombatBalance.tune_base(b)


static func wave() -> SpellBase:
	var b := SpellBase.new()
	b.id = "wave"
	b.display_name = "Wave"
	b.noun = "Wave"
	b.icon_id = "wave"
	b.available = true
	b.delivery = AbilityDef.Delivery.WAVE
	b.description = "Thick skillshot. Travels to max range through units."
	b.target_mode = AbilityDef.TargetMode.SKILLSHOT
	b.mana_cost = 40.0
	b.cooldown = 8.0
	b.range = 12.0
	b.damage = 32.0
	b.cast_time = 0.0
	b.color = Color(0.62, 0.82, 1.0)
	b.skillshot_width = 2.6
	b.skillshot_speed = 16.0
	b.skillshot_length = 12.0
	b.vfx_scene = ""
	b.vfx_scale = 1.0
	b.vfx_primary = Color(0.72, 0.9, 1.0)
	b.vfx_secondary = Color(0.32, 0.55, 0.95)
	b.vfx_tertiary = Color(0.95, 0.98, 1.0)
	return CombatBalance.tune_base(b)


static func target() -> SpellBase:
	var b := SpellBase.new()
	b.id = "target"
	b.display_name = "Target"
	b.noun = "Target"
	b.icon_id = "target"
	b.available = true
	b.delivery = AbilityDef.Delivery.TARGET
	b.description = "Hit on one target."
	b.target_mode = AbilityDef.TargetMode.UNIT
	b.mana_cost = 40.0
	b.cooldown = 7.0
	b.range = 12.0
	b.damage = 80.0
	b.cast_time = 0.0
	b.color = Color(0.82, 0.86, 0.95)
	b.vfx_scene = AbilityFx.FIRE_CAST
	b.vfx_scale = 0.55
	b.vfx_primary = Color(0.92, 0.95, 1.0)
	b.vfx_secondary = Color(0.55, 0.68, 0.95)
	b.vfx_tertiary = Color(1.0, 0.98, 0.82)
	return CombatBalance.tune_base(b)


static func shield() -> SpellBase:
	return target()


static func fire() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "fire"
	inf.display_name = "Fire"
	inf.adjective = "Fire"
	inf.element = AbilityDef.Element.FIRE
	inf.color = Color(1.0, 0.45, 0.12)
	inf.vfx_primary = Color(1.0, 0.92, 0.42)
	inf.vfx_secondary = Color(1.0, 0.42, 0.08)
	inf.vfx_tertiary = Color(0.62, 0.08, 0.22)
	inf.vfx_layer = AbilityFx.FIRE_PROJECTILE
	inf.vfx_layer_scale = 1.0
	inf.icon_tag = "fire"
	inf.damage_mult = 1.40
	inf.cast_time_mult = 1.15
	inf.offensive = true
	inf.description = "Burns 50% of the hit over 10s. Frozen Shatter is a 3x Fire explosion (Burn from it) after enough Fire vs Shadow.\n\nWall: ground fire line (2× length, half thickness), not solid. Projectiles that pass through it deal +8 fire. Enemies that pass through or stand on it take +8 fire per second."
	return CombatBalance.tune_infusion(inf)


static func ice() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "ice"
	inf.display_name = "Ice"
	inf.adjective = "Ice"
	inf.element = AbilityDef.Element.ICE
	inf.color = Color(0.45, 0.82, 1.0)
	inf.vfx_primary = Color(0.55, 0.88, 1.0)
	inf.vfx_secondary = Color(0.18, 0.45, 0.95)
	inf.vfx_tertiary = Color(0.75, 0.95, 1.0)
	inf.vfx_layer = AbilityFx.MAGIC_BOLT
	inf.vfx_layer_scale = 0.72
	inf.icon_tag = "ice"
	inf.damage_mult = 1.75
	inf.cooldown_mult = 1.35
	inf.cast_time_mult = 1.20
	inf.offensive = true
	inf.description = "Chills. Each stack slows 1%. Freeze at 50 stacks (ice damage to freeze depends on enemy rank). Frozen: Fire or Shadow damage can Shatter (hidden break; the larger school decides Fire or Shadow Shatter).\n\nWall: one ice capsule that emits Burst-range ground frost. Enemy to both teams. Breaking it deals 50% of its max HP to enemies in that range."
	return CombatBalance.tune_infusion(inf)


static func lightning() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "lightning"
	inf.display_name = "Lightning"
	inf.adjective = "Lightning"
	inf.element = AbilityDef.Element.STORM
	inf.color = Color(0.78, 0.68, 1.0)
	inf.vfx_primary = Color(0.85, 0.78, 1.0)
	inf.vfx_secondary = Color(0.45, 0.38, 1.0)
	inf.vfx_tertiary = Color(1.0, 0.95, 0.55)
	inf.vfx_layer = AbilityFx.MAGIC_JAVELIN
	inf.vfx_layer_scale = 0.42
	inf.icon_tag = "lightning"
	inf.damage_mult = 1.20
	inf.cooldown_mult = 0.90
	inf.offensive = true
	inf.description = "Shocks. Each lightning hit adds 1 stack (2 on a crit). 100 stacks max. Hits chain to that target and nearby enemies (up to 20% at 100 stacks). Chain does not apply Shock. 20% less damage each bounce. Higher Charge copies more Burn, Chill, and Afflict to hops; copies refresh, they do not stack.\n\nWall: small lightning totem (200 HP). Friendly allied wall; friendly shots pass through. Chains to the nearest enemy every 1s (3 hops). First hop deals 40% of the totem's current HP. Expiring or breaking does not explode."
	return CombatBalance.tune_infusion(inf)


static func shadow() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "shadow"
	inf.display_name = "Shadow"
	inf.adjective = "Shadow"
	inf.element = AbilityDef.Element.SHADOW
	inf.color = Color(0.52, 0.28, 0.72)
	inf.vfx_primary = Color(0.78, 0.42, 1.0)
	inf.vfx_secondary = Color(0.28, 0.08, 0.42)
	inf.vfx_tertiary = Color(0.12, 0.04, 0.18)
	inf.vfx_layer = AbilityFx.MAGIC_BOLT
	inf.vfx_layer_scale = 0.7
	inf.icon_tag = "shadow"
	inf.cooldown_mult = 0.90
	inf.cast_time_mult = 0.85
	inf.offensive = true
	inf.description = "Afflicts. Each shadow hit adds 1 stack, 2 on a crit (the afflict tick does not). 1 damage per 4 stacks each second. 400 stacks max. Enough Shadow vs Fire on Frozen Shatters as 1x shadow/ice and spreads Afflict.\n\nWall: 3000 HP. Enemy to both teams. Breaking it applies 50 Afflict stacks to enemy NPCs in a massive range."
	return CombatBalance.tune_infusion(inf)


static func nature() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "nature"
	inf.display_name = "Nature"
	inf.adjective = "Nature"
	inf.element = AbilityDef.Element.NATURE
	inf.color = Color(0.38, 0.82, 0.42)
	inf.vfx_primary = Color(0.62, 1.0, 0.55)
	inf.vfx_secondary = Color(0.18, 0.62, 0.28)
	inf.vfx_tertiary = Color(0.85, 1.0, 0.55)
	inf.vfx_layer = AbilityFx.MAGIC_JAVELIN
	inf.vfx_layer_scale = 0.4
	inf.icon_tag = "nature"
	inf.heal_mult = 0.40
	inf.cooldown_mult = 0.65
	inf.cast_time_mult = 0.85
	inf.heal_allies = true
	inf.applies_rejuvenation = true
	inf.beneficial = true
	inf.description = "Heals. -60% to base spell power. Rejuvenation: +6 HPS per stack, max 12. New applications add a stack (2 on a crit) and refresh the duration. Does not damage enemies. Skillshots and missiles pass through enemies until they hit an ally or reach max range.\n\nWall: large ring (200 HP shared, 6s). Friendly allied wall. Allies inside get a nature heal and a Rejuvenation stack. Breaking the ring blasts a strong nature heal inside. Units can walk over the walls. Enemies on a wall move at 50% speed. Projectiles cannot pass; enemy shots chip the shared HP."
	return CombatBalance.tune_infusion(inf)


static func divine() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "divine"
	inf.display_name = "Divine"
	inf.adjective = "Divine"
	inf.element = AbilityDef.Element.HOLY
	inf.color = Color(0.95, 0.84, 0.38)
	inf.vfx_primary = Color(1.0, 0.94, 0.55)
	inf.vfx_secondary = Color(0.95, 0.72, 0.22)
	inf.vfx_tertiary = Color(0.72, 0.42, 0.08)
	inf.vfx_layer = AbilityFx.MAGIC_JAVELIN
	inf.vfx_layer_scale = 0.4
	inf.icon_tag = "divine"
	inf.heal_mult = 1.60
	inf.cooldown_mult = 1.20
	inf.cast_time_mult = 1.20
	inf.heal_allies = true
	inf.beneficial = true
	inf.description = "Heals. Holy Blessing stacks up to 10% DR from the spell's base power. Multi-hit spells add per tick. Does not damage enemies. Skillshots and missiles pass through enemies until they hit an ally or reach max range.\n\nWall: large bubble. Allies inside take 30% less damage. Lasts 7s."
	return CombatBalance.tune_infusion(inf)


static func protection() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "protection"
	inf.display_name = "Protection"
	inf.adjective = "Warding"
	inf.element = AbilityDef.Element.PROTECTION
	inf.color = Color(0.72, 0.82, 0.98)
	inf.vfx_primary = Color(0.88, 0.92, 1.0)
	inf.vfx_secondary = Color(0.48, 0.62, 0.92)
	inf.vfx_tertiary = Color(0.95, 0.97, 1.0)
	inf.vfx_layer = AbilityFx.FIRE_CAST
	inf.vfx_layer_scale = 0.45
	inf.icon_tag = "protection"
	inf.cooldown_mult = 1.50
	inf.shield_from_base = 2.00
	inf.beneficial = true
	inf.description = "Shields whoever the spell hits, including you only if it hits you. Ground AOE, Aura, and Ray apply that shield each tick. Does not damage enemies. Skillshots and missiles pass through enemies until they hit an ally or reach max range.\n\nWall: large curved shield on your side. Blocks all projectiles. Infinite HP. 4s channel, can move. Recast during the channel to turn the shield (1s for 180°). You move 50% slower while holding."
	return CombatBalance.tune_infusion(inf)


static func wind() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "wind"
	inf.display_name = "Wind"
	inf.adjective = "Wind"
	inf.element = AbilityDef.Element.WIND
	inf.color = Color(0.72, 0.92, 0.82)
	inf.vfx_primary = Color(0.85, 1.0, 0.92)
	inf.vfx_secondary = Color(0.42, 0.72, 0.62)
	inf.vfx_tertiary = Color(0.95, 1.0, 0.88)
	inf.vfx_layer = AbilityFx.MAGIC_JAVELIN
	inf.vfx_layer_scale = 0.55
	inf.icon_tag = "wind"
	inf.cooldown_mult = 1.20
	inf.offensive = true
	inf.utility = true
	inf.description = "Crowd control depends on the base: knockback, pull, snare, or haste.\n\nGround AOE: 50% smaller, yanks enemies in, then vanishes. Other infusions dump once at 50%. Wave: 30% thicker and much slower. Wall: 30% longer, no HP. Units walk through it. Enemy shots hitch then fling back at their caster. Friendly shots pass through.\n\nBosses cannot be knocked back or up unless a fight says otherwise."
	return CombatBalance.tune_infusion(inf)


static func illusion() -> SpellInfusion:
	var inf := SpellInfusion.new()
	inf.id = "illusion"
	inf.display_name = "Illusion"
	inf.adjective = "Illusory"
	inf.element = AbilityDef.Element.ILLUSION
	inf.color = Color(0.92, 0.55, 0.82)
	inf.vfx_primary = Color(1.0, 0.72, 0.92)
	inf.vfx_secondary = Color(0.62, 0.22, 0.58)
	inf.vfx_tertiary = Color(1.0, 0.88, 0.95)
	inf.vfx_layer = AbilityFx.MAGIC_BOLT
	inf.vfx_layer_scale = 0.65
	inf.icon_tag = "illusion"
	inf.damage_mult = 0.90
	inf.heal_mult = 0.90
	inf.offensive = true
	inf.utility = true
	inf.description = "Changes how the base lands.\n\nBolt: 5 shots at ±15°/±30°, half bolt damage. Missiles: each extra target in Burst radius also gets a volley. Ground AOE: 2 far fields at 80–120% size. Burst: 0.5s echoes. Aura: rings +25%. Ray: one aura pulse of the paired infusion on the first enemy hit. Meteor: 3-meteor line, 25% smaller. Nova: short-range ground AOE. Wall: cylinder portals. Recast a second portal, then confirm its shot direction. First absorbs projectiles from any angle; the exit copies them out along the aimed direction. Enemy shots that exit become yours and only hit enemies. Lasts 8s. A new pair replaces the old portals."
	return CombatBalance.tune_infusion(inf)


static func readiness() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "readiness"
	a.display_name = "Readiness"
	a.cooldown_mult = 0.8
	a.description = "Reduces this spell's cooldown by %d%%." % _pct_off(a.cooldown_mult)
	return a


static func reach() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "reach"
	a.display_name = "Reach"
	a.range_mult = 1.2
	a.needs_range = true
	a.description = "Increases this spell's range by %d%%." % _pct_on(a.range_mult)
	return a


static func efficiency() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "efficiency"
	a.display_name = "Efficiency"
	a.mana_mult = 0.8
	a.description = "Reduces the mana cost of this spell by %d%%." % _pct_off(a.mana_mult)
	return a


static func haste() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "haste"
	a.display_name = "Haste"
	a.cast_time_mult = 1.0 / 1.2
	a.needs_cast_speed = true
	a.blocked_deliveries = _bolt_delivery()
	a.exclusive_with = PackedStringArray(["snap_cast"])
	a.description = "Increases this spell's cast speed by %d%%. Channels fire ticks faster and finish sooner." % _pct_on(1.0 / a.cast_time_mult)
	return a


static func echo() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "echo"
	a.display_name = "Echo"
	a.echo = true
	a.echo_damage_mult = 0.2
	a.blocked_deliveries = PackedInt32Array([
		AbilityDef.Delivery.GROUND_AOE,
		AbilityDef.Delivery.AURA,
		AbilityDef.Delivery.WALL,
	])
	CombatBalance.tune_augment(a)
	a.description = "A second launch follows immediately, dealing %d%% damage." % int(round(a.echo_damage_mult * 100.0))
	return a


static func widen() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "widen"
	a.display_name = "Widen"
	a.area_mult = 1.2
	a.needs_area = true
	a.blocked_deliveries = _bolt_delivery()
	a.exclusive_with = PackedStringArray(["focus", "spread"])
	a.description = "Increases this spell's area by %d%%." % _pct_on(a.area_mult)
	return a


static func precision() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "precision"
	a.display_name = "Precision"
	a.crit_chance_mult = 2.0
	a.needs_crit = true
	a.description = "Doubles this spell's crit chance (5%% becomes 10%%)."
	return a


static func lethality() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "lethality"
	a.display_name = "Lethality"
	a.crit_damage = 2.5
	a.needs_crit = true
	a.description = "Critical strikes from this spell deal %d%% damage instead of 200%%." % int(round(a.crit_damage * 100.0))
	return a


static func snap_cast() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "snap_cast"
	a.display_name = "Snap Cast"
	a.instant_cast = true
	a.cooldown_mult = 1.25
	a.needs_cast_time = true
	a.blocked_deliveries = _bolt_delivery()
	a.exclusive_with = PackedStringArray(["haste", "ritual"])
	a.description = "Removes cast time. Cooldown is %d%% longer." % _pct_on(a.cooldown_mult)
	return a


static func alteration() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "altered"
	a.display_name = "Alteration"
	a.altered = true
	a.description = "With Fire, Ice, Lightning, or Shadow, this spell buffs you and can buff an ally (second infusion if it is one of those, otherwise the first). With Nature, Divine, or Protection, the spell hits enemies: Seeded (snare; Fire spends a seed for a splash; 8th seed blooms), Judged (Divine hits deal more; damage heals the lowest-HP nearby ally), or Sundered (they deal less; hitting a shield breaks a stack). Crits apply two stacks."
	return a


static func menace() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "menace"
	a.display_name = "Menace"
	a.threat_mult = 4.0
	a.exclusive_with = PackedStringArray(["subtlety"])
	CombatBalance.tune_augment(a)
	if is_equal_approx(a.threat_mult, roundf(a.threat_mult)):
		a.description = "This spell generates %d× threat." % int(roundf(a.threat_mult))
	else:
		a.description = "This spell generates %0.1f× threat." % a.threat_mult
	return a


static func subtlety() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "subtlety"
	a.display_name = "Subtlety"
	a.threat_mult = 0.5
	a.exclusive_with = PackedStringArray(["menace"])
	CombatBalance.tune_augment(a)
	a.description = "This spell generates %d%% threat." % int(round(a.threat_mult * 100.0))
	return a


static func volley() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "volley"
	a.display_name = "Volley"
	a.projectile_bonus = 2
	a.damage_mult = 0.55
	a.allowed_deliveries = PackedInt32Array([
		AbilityDef.Delivery.BOLT,
		AbilityDef.Delivery.WAVE,
	])
	CombatBalance.tune_augment(a)
	a.description = "Fires %d extra shots in a short fan. Each shot deals %d%% damage." % [
		a.projectile_bonus,
		int(round(a.damage_mult * 100.0)),
	]
	return a


static func fan() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "fan"
	a.display_name = "Fan"
	a.projectile_bonus = 2
	a.damage_mult = 0.55
	a.allowed_deliveries = PackedInt32Array([AbilityDef.Delivery.RAY])
	CombatBalance.tune_augment(a)
	a.description = "Fires %d extra beams in a short fan. Each beam deals %d%% damage." % [
		a.projectile_bonus,
		int(round(a.damage_mult * 100.0)),
	]
	return a


static func pierce() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "pierce"
	a.display_name = "Pierce"
	a.pierce = true
	a.allowed_deliveries = PackedInt32Array([
		AbilityDef.Delivery.BOLT,
		AbilityDef.Delivery.RAY,
	])
	a.description = "This beam or skillshot continues through enemies."
	return a


static func focus() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "focus"
	a.display_name = "Focus"
	a.area_mult = 0.7
	a.damage_mult = 1.25
	a.needs_area = true
	a.blocked_deliveries = PackedInt32Array([
		AbilityDef.Delivery.BOLT,
		AbilityDef.Delivery.RAY,
	])
	a.exclusive_with = PackedStringArray(["widen", "spread"])
	CombatBalance.tune_augment(a)
	a.description = "Reduces this spell's area by %d%% and increases its damage by %d%%." % [
		_pct_off(a.area_mult),
		_pct_on(a.damage_mult),
	]
	return a


static func spread() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "spread"
	a.display_name = "Spread"
	a.area_mult = 1.3
	a.damage_mult = 0.75
	a.needs_area = true
	a.allowed_deliveries = PackedInt32Array([AbilityDef.Delivery.GROUND_AOE])
	a.exclusive_with = PackedStringArray(["focus", "widen"])
	CombatBalance.tune_augment(a)
	a.description = "Increases this spell's area by %d%% and reduces its damage by %d%%." % [
		_pct_on(a.area_mult),
		_pct_off(a.damage_mult),
	]
	return a


static func lingering() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "lingering"
	a.display_name = "Lingering"
	a.duration_mult = 1.5
	a.needs_duration = true
	a.blocked_deliveries = PackedInt32Array([
		AbilityDef.Delivery.MISSILES,
		AbilityDef.Delivery.RAY,
	])
	CombatBalance.tune_augment(a)
	a.description = "Increases this spell's duration by %d%%." % _pct_on(a.duration_mult)
	return a


static func ritual() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "ritual"
	a.display_name = "Ritual"
	a.cast_time_mult = 1.6
	a.damage_mult = 1.35
	a.needs_cast_time = true
	a.blocked_deliveries = _bolt_delivery()
	a.exclusive_with = PackedStringArray(["snap_cast"])
	CombatBalance.tune_augment(a)
	a.description = "Increases cast time by %d%% and damage by %d%%." % [
		_pct_on(a.cast_time_mult),
		_pct_on(a.damage_mult),
	]
	return a


static func momentum() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "momentum"
	a.display_name = "Momentum"
	a.hit_cooldown_reduction = 0.4
	a.hit_cooldown_refund_cap = 0.25
	a.allowed_deliveries = PackedInt32Array([
		AbilityDef.Delivery.BOLT,
		AbilityDef.Delivery.WAVE,
		AbilityDef.Delivery.TARGET,
		AbilityDef.Delivery.AOE_EXPLOSION,
		AbilityDef.Delivery.METEOR,
		AbilityDef.Delivery.NOVA,
		AbilityDef.Delivery.MISSILES,
		AbilityDef.Delivery.GROUND_AOE,
		AbilityDef.Delivery.RAY,
	])
	CombatBalance.tune_augment(a)
	a.description = "Each unique enemy hit reduces this spell's remaining cooldown by %0.1fs, up to %d%% of the cooldown." % [
		a.hit_cooldown_reduction,
		int(round(a.hit_cooldown_refund_cap * 100.0)),
	]
	return a


static func siphon() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "siphon"
	a.display_name = "Siphon"
	a.lifesteal = 0.15
	a.needs_damage = true
	CombatBalance.tune_augment(a)
	a.description = "Heal for %d%% of the damage this spell deals." % int(round(a.lifesteal * 100.0))
	return a


static func cleave() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "cleave"
	a.display_name = "Cleave"
	a.cleave_ratio = 0.5
	a.cleave_radius = 1.2
	a.needs_cleave = true
	CombatBalance.tune_augment(a)
	a.description = "The primary hit splashes nearby enemies for %d%% damage, or nearby allies for %d%% of the heal and shield." % [
		int(round(a.cleave_ratio * 100.0)),
		int(round(a.cleave_ratio * 100.0)),
	]
	return a


static func execute() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "execute"
	a.display_name = "Execute"
	a.execute_health_frac = 0.3
	a.execute_damage_mult = 1.3
	a.needs_damage = true
	CombatBalance.tune_augment(a)
	a.description = "Deals %d%% more damage to enemies below %d%% health." % [
		_pct_on(a.execute_damage_mult),
		int(round(a.execute_health_frac * 100.0)),
	]
	return a


static func gambit() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "gambit"
	a.display_name = "Gambit"
	a.cooldown_mult = 0.7
	a.mana_mult = 1.4
	CombatBalance.tune_augment(a)
	a.description = "Reduces this spell's cooldown by %d%%. Mana cost is %d%% higher." % [
		_pct_off(a.cooldown_mult),
		_pct_on(a.mana_mult),
	]
	return a


static func heartbeat() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "heartbeat"
	a.display_name = "Heartbeat"
	a.tick_interval_mult = 0.6
	a.mana_mult = 1.2
	a.allowed_deliveries = _aura_only()
	a.exclusive_with = PackedStringArray(["slow_burn"])
	CombatBalance.tune_augment(a)
	a.description = "Pulses %d%% faster. Each pulse costs %d%% more mana." % [
		_pct_off(a.tick_interval_mult),
		_pct_on(a.mana_mult),
	]
	return a


static func slow_burn() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "slow_burn"
	a.display_name = "Slow Burn"
	a.tick_interval_mult = 1.5
	a.damage_mult = 1.4
	a.allowed_deliveries = _aura_only()
	a.exclusive_with = PackedStringArray(["heartbeat"])
	CombatBalance.tune_augment(a)
	a.description = "Pulses %d%% slower. Each pulse deals %d%% more damage." % [
		_pct_on(a.tick_interval_mult),
		_pct_on(a.damage_mult),
	]
	return a


static func anchor() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "anchor"
	a.display_name = "Anchor"
	a.planted = true
	a.allowed_deliveries = _aura_only()
	a.description = "The ring stays where you turned it on instead of following you."
	return a


static func aftershock() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "aftershock"
	a.display_name = "Aftershock"
	a.detonate_on_end = 1.5
	a.allowed_deliveries = _aura_only()
	CombatBalance.tune_augment(a)
	a.description = "Turning this aura off detonates it once for %d%% of a pulse." % int(round(a.detonate_on_end * 100.0))
	return a


static func crowd() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "crowd"
	a.display_name = "Crowd"
	a.crowd_bonus = 0.08
	a.crowd_bonus_cap = 0.40
	a.allowed_deliveries = _aura_only()
	CombatBalance.tune_augment(a)
	a.description = "Each extra unit in the ring increases this pulse by %d%%, up to %d%%." % [
		int(round(a.crowd_bonus * 100.0)),
		int(round(a.crowd_bonus_cap * 100.0)),
	]
	return a


static func stillness() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "stillness"
	a.display_name = "Stillness"
	a.stillness_bonus = 0.35
	a.allowed_deliveries = _aura_only()
	CombatBalance.tune_augment(a)
	a.description = "If you have not moved since the last pulse, this pulse is %d%% stronger." % int(round(a.stillness_bonus * 100.0))
	return a
