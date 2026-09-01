class_name SpellCatalog
extends Object

const HOTKEYS := ["Q", "W", "E", "R", "D", "F"]


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


static func invalidate() -> void:
	_base_list.clear()
	_base_by_id.clear()
	_infusion_list.clear()
	_infusion_by_id.clear()
	_augment_list.clear()
	_augment_by_id.clear()


static func default_loadout() -> Array:
	return [
		SpellRecipe.make("bolt", PackedStringArray(["fire"])),
		SpellRecipe.make("missiles", PackedStringArray(["lightning"])),
		SpellRecipe.make("ground_aoe", PackedStringArray(["ice"])),
		SpellRecipe.make("bolt", PackedStringArray(["ice"])),
		SpellRecipe.make("missiles", PackedStringArray(["fire"])),
		SpellRecipe.make("ground_aoe", PackedStringArray(["divine"])),
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


static func augment_skip_reason(base_id: String, augment_id: String) -> String:
	var base := get_base(base_id)
	var aug := get_augment(augment_id)
	if base == null or aug == null:
		return "Unknown piece."
	match aug.id:
		"reach":
			if base.range <= 0.05:
				return "Reach does nothing on %s (no cast range)." % base.display_name
		"widen":
			if not _base_uses_area(base):
				return "Widen does nothing on %s (no spell area)." % base.display_name
		"haste":
			if base.cast_time <= 0.05:
				return "Haste does nothing on %s (no cast time)." % base.display_name
		"snap_cast":
			if base.cast_time <= 0.05:
				return "Snap Cast does nothing on %s (already instant)." % base.display_name
		"stride":
			if base.cast_time <= 0.05 and not base.is_channel:
				return "Stride does nothing on %s (already free to move)." % base.display_name
		"overflow":
			if base.max_infusions > 0 and base.max_infusions < 2:
				return "Overflow does nothing on %s (one infusion only)." % base.display_name
		"echo":
			if base.delivery == AbilityDef.Delivery.GROUND_AOE or base.delivery == AbilityDef.Delivery.AURA or base.delivery == AbilityDef.Delivery.WALL:
				return "Echo does not recast %s." % base.display_name
		"precision", "lethality":
			if not _base_can_crit(base):
				return "%s does nothing on %s (this base cannot crit)." % [aug.display_name, base.display_name]
	return ""


static func _base_uses_area(base: SpellBase) -> bool:
	if base == null:
		return false
	match base.delivery:
		AbilityDef.Delivery.BOLT, AbilityDef.Delivery.WAVE:
			return base.splash_radius > 0.05 or base.skillshot_width > 0.05
		AbilityDef.Delivery.GROUND_AOE, AbilityDef.Delivery.AOE_EXPLOSION, AbilityDef.Delivery.AURA, AbilityDef.Delivery.METEOR, AbilityDef.Delivery.NOVA, AbilityDef.Delivery.WALL:
			return true
		_:
			return false


static func _base_can_crit(base: SpellBase) -> bool:
	if base == null:
		return false
	if base.delivery == AbilityDef.Delivery.GROUND_AOE or base.delivery == AbilityDef.Delivery.AURA:
		return false
	if base.delivery == AbilityDef.Delivery.SHIELD or (base.damage <= 0.05 and base.tick_damage <= 0.05):
		return false
	return true


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
		encore(),
		stride(),
		alteration(),
		menace(),
		subtlety(),
		overflow(),
	]
	for aug in _augment_list:
		_augment_by_id[aug.id] = aug


static func bolt() -> SpellBase:
	var b := SpellBase.new()
	b.id = "bolt"
	b.display_name = "Bolt"
	b.noun = "Bolt"
	b.icon_id = "bolt"
	b.available = true
	b.delivery = AbilityDef.Delivery.BOLT
	b.description = "Thin skillshot. Hits the first unit, then splashes 35% nearby."
	b.target_mode = AbilityDef.TargetMode.SKILLSHOT
	b.mana_cost = 18.0
	b.cooldown = 2.0
	b.range = 11.0
	b.damage = 42.0
	b.cast_time = 0.15
	b.color = Color(0.72, 0.82, 1.0)
	b.skillshot_width = 0.55
	b.skillshot_speed = 24.0
	b.skillshot_length = 11.0
	b.splash_radius = 1.2
	b.splash_ratio = 0.35
	b.vfx_scene = AbilityFx.MAGIC_BOLT
	b.vfx_scale = 0.62
	b.vfx_yaw = PI * 0.5
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
	b.description = "Toggle a ring around you. Each pulse costs mana. Several Auras can be up at once. The same infusion cannot be on two of them, except Wind and Illusion."
	b.target_mode = AbilityDef.TargetMode.INSTANT
	b.mana_cost = 8.0
	b.cooldown = 1.0
	b.range = 0.0
	b.damage = 0.0
	b.cast_time = 0.0
	b.is_toggle = true
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
	b.description = "Channel a beam on one target. Each pulse costs mana."
	b.target_mode = AbilityDef.TargetMode.UNIT
	b.mana_cost = 14.0
	b.cooldown = 8.0
	b.range = 14.0
	b.damage = 40.0
	b.cast_time = 1.5
	b.is_channel = true
	b.channel_time = 2.5
	b.tick_interval = 0.25
	b.cost_per_tick = true
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
	inf.damage_mult = 1.20
	inf.offensive = true
	inf.description = "Burns 50% of the hit over 10s.\n\nWall: ground fire line (2× length, half thickness), not solid. Projectiles that pass through it deal +8 fire. Enemies that pass through or stand on it take +8 fire per second."
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
	inf.damage_mult = 0.90
	inf.cooldown_mult = 0.90
	inf.offensive = true
	inf.description = "Chills (0.1% per damage). Freeze at 100%.\n\nWall: one ice capsule that emits Burst-range ground frost. Enemy to both teams. Breaking it deals 50% of its max HP to enemies in that range."
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
	inf.damage_mult = 1.35
	inf.cooldown_mult = 1.20
	inf.offensive = true
	inf.description = "Shocks. Hits chain to that target and nearby enemies (up to 20% at 10 stacks). Chain does not apply Shock. 20% less damage each bounce.\n\nWall: small lightning totem (200 HP). Friendly allied wall; friendly shots pass through. Chains to the nearest enemy every 1s (3 hops). First hop deals 40% of the totem's current HP. Expiring or breaking does not explode."
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
	inf.damage_mult = 1.20
	inf.cooldown_mult = 1.40
	inf.offensive = true
	inf.description = "Afflicts. Each shadow hit adds 1 stack (the afflict tick does not). 1 damage per stack each second. 200 stacks: +20% damage taken.\n\nWall: 3000 HP. Enemy to both teams. Breaking it applies 50 Afflict stacks to enemy NPCs in a massive range."
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
	inf.heal_mult = 0.80
	inf.cooldown_mult = 0.65
	inf.heal_allies = true
	inf.applies_rejuvenation = true
	inf.beneficial = true
	inf.description = "Heals. Rejuvenation: +8 HPS per stack, max 12. New applications add a stack and refresh the duration. Does not damage enemies. Skillshots and missiles pass through enemies until they hit an ally or reach max range.\n\nWall: large ring (200 HP shared, 6s). Friendly allied wall. Allies inside get a nature heal and a Rejuvenation stack. Breaking the ring blasts a strong nature heal inside. Units can walk over the walls. Enemies on a wall move at 50% speed. Projectiles cannot pass; enemy shots chip the shared HP."
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
	inf.heal_mult = 1.40
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
	inf.damage_mult = 0.70
	inf.cooldown_mult = 1.20
	inf.offensive = true
	inf.utility = true
	inf.description = "Crowd control depends on the base: knockback, pull, snare, or haste.\n\nGround AOE: 50% smaller, yanks enemies in, then vanishes. Other infusions dump once at 50%. Wave: 30% thicker and much slower. Wall: 30% longer, no HP. Units walk through it. Enemy shots hitch then fling back at their caster. Friendly shots pass through."
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
	inf.damage_mult = 0.80
	inf.heal_mult = 0.80
	inf.offensive = true
	inf.utility = true
	inf.description = "Changes how the base lands.\n\nBolt: 5 shots at ±15°/±30°, half bolt damage. Missiles: each extra target in Burst radius also gets a volley. Ground AOE: 2 far fields at 80–120% size. Burst: 0.5s echoes. Aura: rings +25%. Ray: beam bounces. Meteor: 3-meteor line, 25% smaller. Nova: short-range ground AOE. Wall: cylinder portals. Recast a second portal, then recast up to 3 times to move the exit. First absorbs projectiles; the exit shoots them out at the same angle. Enemy shots that exit become yours and only hit enemies. Lasts 8s. A new pair replaces the old portals."
	return CombatBalance.tune_infusion(inf)


static func readiness() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "readiness"
	a.display_name = "Readiness"
	a.description = ""
	a.cooldown_mult = 0.8
	return a


static func reach() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "reach"
	a.display_name = "Reach"
	a.description = ""
	a.range_mult = 1.2
	return a


static func efficiency() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "efficiency"
	a.display_name = "Efficiency"
	a.description = ""
	a.mana_mult = 0.8
	return a


static func haste() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "haste"
	a.display_name = "Haste"
	a.description = ""
	a.cast_time_mult = 1.0 / 1.2
	return a


static func echo() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "echo"
	a.display_name = "Echo"
	a.description = "A second launch follows immediately."
	a.echo = true
	a.echo_damage_mult = 0.2
	return CombatBalance.tune_augment(a)


static func widen() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "widen"
	a.display_name = "Widen"
	a.description = ""
	a.area_mult = 1.2
	return a


static func precision() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "precision"
	a.display_name = "Precision"
	a.description = "5% baseline crit chance becomes 10%."
	a.crit_chance_mult = 2.0
	a.crit_damage = 1.5
	return a


static func lethality() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "lethality"
	a.display_name = "Lethality"
	a.description = ""
	a.crit_damage = 2.5
	return a


static func snap_cast() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "snap_cast"
	a.display_name = "Snap Cast"
	a.description = ""
	a.instant_cast = true
	a.cooldown_mult = 1.25
	return a


static func encore() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "encore"
	a.display_name = "Encore"
	a.description = "Recast within 3s. On a channel, the window starts when the channel ends or is cancelled."
	a.recast = true
	a.recast_window = 3.0
	a.recast_damage_mult = 0.3
	a.cooldown_mult = 1.2
	return CombatBalance.tune_augment(a)


static func stride() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "stride"
	a.display_name = "Stride"
	a.description = ""
	a.move_while_casting = true
	return a


static func alteration() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "altered"
	a.display_name = "Alteration"
	a.altered = true
	a.description = "With an offensive infusion, this spell buffs you and can buff an ally. The buff follows the second infusion if it is offensive, otherwise the first offensive infusion."
	return a


static func menace() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "menace"
	a.display_name = "Menace"
	a.description = ""
	a.threat_mult = 4.0
	return CombatBalance.tune_augment(a)


static func subtlety() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "subtlety"
	a.display_name = "Subtlety"
	a.description = ""
	a.threat_mult = 0.5
	return CombatBalance.tune_augment(a)


static func overflow() -> SpellAugment:
	var a := SpellAugment.new()
	a.id = "overflow"
	a.display_name = "Overflow"
	a.description = "Cannot be combined with other augments."
	a.exclusive = true
	a.extra_infusions = 1
	return a
