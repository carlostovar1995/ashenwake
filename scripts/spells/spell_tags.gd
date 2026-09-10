class_name SpellTags
extends Object

## Windups at or below this still count as no cast time for augment matching.
## Bolt and Wall sit at 0.15s; they should not take Snap Cast, Ritual, or Haste.
const NO_CAST_THRESHOLD := 0.25

const NO_CAST_TIME := "no_cast_time"
const CAST_TIME := "cast_time"
const CHANNEL := "channel"
const TOGGLE := "toggle"

const SKILLSHOT := "skillshot"
const GROUND := "ground"
const UNIT_TARGET := "unit_target"
const TARGET := "target"
const INSTANT := "instant"

const BOLT := "bolt"
const WAVE := "wave"
const RAY := "ray"
const MISSILES := "missiles"
const GROUND_AOE := "ground_aoe"
const BURST := "burst"
const AURA := "aura"
const METEOR := "meteor"
const NOVA := "nova"
const WALL := "wall"
const SHIELD := "shield"

const PROJECTILE := "projectile"
const HOMING := "homing"
const BEAM := "beam"

const RANGED := "ranged"
const AREA := "area"
const DURATION := "duration"
const CRIT := "crit"
const DAMAGE := "damage"
const SINGLE_TARGET := "single_target"

const _LABELS := {
	NO_CAST_TIME: "No cast time",
	CAST_TIME: "Cast time",
	CHANNEL: "Channel",
	TOGGLE: "Toggle",
	SKILLSHOT: "Skillshot",
	GROUND: "Ground",
	UNIT_TARGET: "Unit target",
	TARGET: "Target",
	INSTANT: "Instant",
	BOLT: "Bolt",
	WAVE: "Wave",
	RAY: "Ray",
	MISSILES: "Missiles",
	GROUND_AOE: "Ground AoE",
	BURST: "Burst",
	AURA: "Aura",
	METEOR: "Meteor",
	NOVA: "Nova",
	WALL: "Wall",
	SHIELD: "Shield",
	PROJECTILE: "Projectile",
	HOMING: "Homing",
	BEAM: "Beam",
	RANGED: "Ranged",
	AREA: "Area",
	DURATION: "Duration",
	CRIT: "Crit",
	DAMAGE: "Damage",
	SINGLE_TARGET: "Single-target",
}

const _ORDER: PackedStringArray = [
	SKILLSHOT, GROUND, UNIT_TARGET, TARGET, INSTANT,
	BOLT, WAVE, RAY, MISSILES, GROUND_AOE, BURST, AURA, METEOR, NOVA, WALL, SHIELD,
	PROJECTILE, HOMING, BEAM,
	NO_CAST_TIME, CAST_TIME, CHANNEL, TOGGLE,
	RANGED, AREA, DURATION, CRIT, DAMAGE, SINGLE_TARGET,
]


static func label(tag: String) -> String:
	return String(_LABELS.get(tag, tag.replace("_", " ").capitalize()))


static func display_line(tags: PackedStringArray) -> String:
	if tags.is_empty():
		return ""
	var names: PackedStringArray = PackedStringArray()
	for tag in tags:
		names.append(label(tag))
	return "Tags: " + ", ".join(names)


static func requirement_line(aug: SpellAugment) -> String:
	if aug == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	if not aug.requires_all.is_empty():
		parts.append("Needs " + _join_labels(aug.requires_all))
	if not aug.requires_any.is_empty():
		parts.append("Needs any of " + _join_labels(aug.requires_any))
	if not aug.blocked_tags.is_empty():
		parts.append("Not for " + _join_labels(aug.blocked_tags))
	return ". ".join(parts)


static func for_base(base: SpellBase) -> PackedStringArray:
	if base == null:
		return PackedStringArray()
	var found: Dictionary = {}
	var shape := delivery_tag(base.delivery)
	# Unit-lock bolts/waves/rays are targeted hits, not aimed skillshots.
	if base.target_mode == AbilityDef.TargetMode.UNIT and _is_skillshot_delivery(base.delivery):
		shape = TARGET
	_mark(found, shape)
	match base.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
			_mark(found, SKILLSHOT)
		AbilityDef.TargetMode.UNIT:
			_mark(found, UNIT_TARGET)
		AbilityDef.TargetMode.GROUND:
			_mark(found, GROUND)
		AbilityDef.TargetMode.INSTANT:
			_mark(found, INSTANT)
	if base.cast_time <= NO_CAST_THRESHOLD:
		_mark(found, NO_CAST_TIME)
	else:
		_mark(found, CAST_TIME)
	if base.is_channel:
		_mark(found, CHANNEL)
	if base.is_toggle:
		_mark(found, TOGGLE)
	if base.delivery == AbilityDef.Delivery.MISSILES:
		_mark(found, PROJECTILE)
		_mark(found, HOMING)
	elif base.delivery == AbilityDef.Delivery.BOLT and base.target_mode == AbilityDef.TargetMode.SKILLSHOT:
		_mark(found, PROJECTILE)
	if base.delivery == AbilityDef.Delivery.RAY:
		_mark(found, BEAM)
	if base.range > 0.05:
		_mark(found, RANGED)
	if has_area(base):
		_mark(found, AREA)
	if has_duration(base):
		_mark(found, DURATION)
	if can_crit(base):
		_mark(found, CRIT)
	if base.damage > 0.05 or base.tick_damage > 0.05:
		_mark(found, DAMAGE)
	if can_cleave(base):
		_mark(found, SINGLE_TARGET)
	for extra in base.extra_tags:
		_mark(found, extra)
	return _ordered(found)


static func has(base: SpellBase, tag: String) -> bool:
	return for_base(base).has(tag)


static func delivery_tag(delivery: int) -> String:
	match delivery:
		AbilityDef.Delivery.BOLT:
			return BOLT
		AbilityDef.Delivery.WAVE:
			return WAVE
		AbilityDef.Delivery.RAY:
			return RAY
		AbilityDef.Delivery.MISSILES:
			return MISSILES
		AbilityDef.Delivery.GROUND_AOE:
			return GROUND_AOE
		AbilityDef.Delivery.AOE_EXPLOSION:
			return BURST
		AbilityDef.Delivery.AURA:
			return AURA
		AbilityDef.Delivery.METEOR:
			return METEOR
		AbilityDef.Delivery.NOVA:
			return NOVA
		AbilityDef.Delivery.WALL:
			return WALL
		AbilityDef.Delivery.SHIELD:
			return SHIELD
		AbilityDef.Delivery.TARGET:
			return TARGET
	return ""


static func bind_augment(aug: SpellAugment) -> void:
	if aug == null:
		return
	# Derive fit tags from the existing needs_* / delivery flags so new augments
	# can also set requires_all / requires_any / blocked_tags directly.
	if aug.needs_range:
		aug.requires_all = _with(aug.requires_all, RANGED)
	if aug.needs_area:
		aug.requires_all = _with(aug.requires_all, AREA)
	if aug.needs_cast_time:
		aug.requires_all = _with(aug.requires_all, CAST_TIME)
	if aug.needs_crit:
		aug.requires_all = _with(aug.requires_all, CRIT)
	if aug.needs_damage:
		aug.requires_all = _with(aug.requires_all, DAMAGE)
	if aug.needs_duration:
		aug.requires_all = _with(aug.requires_all, DURATION)
	if aug.needs_cleave:
		aug.requires_all = _with(aug.requires_all, SINGLE_TARGET)
	if aug.needs_cast_speed:
		aug.requires_any = _with(aug.requires_any, CAST_TIME)
		aug.requires_any = _with(aug.requires_any, CHANNEL)
	if _allowed_are_skillshots(aug):
		aug.requires_all = _with(aug.requires_all, SKILLSHOT)
	for delivery in aug.allowed_deliveries:
		aug.requires_any = _with(aug.requires_any, delivery_tag(delivery))
	for delivery in aug.blocked_deliveries:
		aug.blocked_tags = _with(aug.blocked_tags, delivery_tag(delivery))
	if _changes_cooldown(aug):
		aug.blocked_tags = _with(aug.blocked_tags, TOGGLE)
	if aug.needs_cast_time or aug.needs_cast_speed:
		aug.tags = _with(aug.tags, CAST_TIME)
	if aug.needs_cast_speed:
		aug.tags = _with(aug.tags, CHANNEL)
	if aug.needs_area:
		aug.tags = _with(aug.tags, AREA)
	if aug.needs_range:
		aug.tags = _with(aug.tags, RANGED)
	if aug.needs_duration:
		aug.tags = _with(aug.tags, DURATION)
	if not aug.allowed_deliveries.is_empty():
		for delivery in aug.allowed_deliveries:
			aug.tags = _with(aug.tags, delivery_tag(delivery))


static func skip_reason(base: SpellBase, aug: SpellAugment) -> String:
	if base == null or aug == null:
		return "Unknown piece."
	var tags := for_base(base)
	for tag in aug.requires_all:
		if not tags.has(tag):
			return _missing_reason(base, aug, tag)
	if not aug.requires_any.is_empty():
		var hit := false
		for tag in aug.requires_any:
			if tags.has(tag):
				hit = true
				break
		if not hit:
			if aug.needs_cast_speed:
				return "%s does nothing on %s (no cast or channel to speed up)." % [aug.display_name, base.display_name]
			return "%s does not apply to %s." % [aug.display_name, base.display_name]
	for tag in aug.blocked_tags:
		if tags.has(tag):
			if tag == TOGGLE:
				return "%s cannot change %s cooldown (toggle lockout only)." % [aug.display_name, base.display_name]
			if aug.echo:
				return "Echo does not recast %s." % base.display_name
			return "%s does not apply to %s." % [aug.display_name, base.display_name]
	if aug.pierce and tags.has(WAVE):
		return "Pierce does nothing on %s (already passes through units)." % base.display_name
	return ""


static func has_area(base: SpellBase) -> bool:
	if base == null:
		return false
	match base.delivery:
		AbilityDef.Delivery.BOLT, AbilityDef.Delivery.WAVE, AbilityDef.Delivery.RAY:
			return base.splash_radius > 0.05 or base.skillshot_width > 0.05
		AbilityDef.Delivery.GROUND_AOE, AbilityDef.Delivery.AOE_EXPLOSION, AbilityDef.Delivery.AURA, AbilityDef.Delivery.METEOR, AbilityDef.Delivery.NOVA, AbilityDef.Delivery.WALL:
			return true
	return false


static func can_crit(base: SpellBase) -> bool:
	if base == null:
		return false
	if base.delivery == AbilityDef.Delivery.GROUND_AOE or base.delivery == AbilityDef.Delivery.AURA:
		return false
	if base.delivery == AbilityDef.Delivery.SHIELD or (base.damage <= 0.05 and base.tick_damage <= 0.05):
		return false
	return true


static func has_duration(base: SpellBase) -> bool:
	if base == null:
		return false
	return base.is_channel or base.zone_duration > 0.05


static func can_cleave(base: SpellBase) -> bool:
	if base == null:
		return false
	return (
		base.delivery == AbilityDef.Delivery.BOLT
		or base.delivery == AbilityDef.Delivery.TARGET
		or base.delivery == AbilityDef.Delivery.MISSILES
	)


static func _missing_reason(base: SpellBase, aug: SpellAugment, tag: String) -> String:
	match tag:
		RANGED:
			return "%s does nothing on %s (no cast range)." % [aug.display_name, base.display_name]
		AREA:
			return "%s does nothing on %s (no spell area)." % [aug.display_name, base.display_name]
		CAST_TIME:
			if aug.instant_cast:
				return "%s does nothing on %s (already instant)." % [aug.display_name, base.display_name]
			return "%s does nothing on %s (no cast time)." % [aug.display_name, base.display_name]
		CRIT:
			return "%s does nothing on %s (this base cannot crit)." % [aug.display_name, base.display_name]
		DAMAGE:
			return "%s does nothing on %s (no damage)." % [aug.display_name, base.display_name]
		DURATION:
			return "%s does nothing on %s (no duration to extend)." % [aug.display_name, base.display_name]
		SINGLE_TARGET:
			return "%s does nothing on %s (needs a single-target hit)." % [aug.display_name, base.display_name]
		SKILLSHOT:
			return "%s does not apply to %s (not a skillshot)." % [aug.display_name, base.display_name]
	return "%s does not apply to %s." % [aug.display_name, base.display_name]


static func _changes_cooldown(aug: SpellAugment) -> bool:
	if aug == null:
		return false
	return not is_equal_approx(aug.cooldown_mult, 1.0) or aug.hit_cooldown_reduction > 0.05


static func _is_skillshot_delivery(delivery: int) -> bool:
	return (
		delivery == AbilityDef.Delivery.BOLT
		or delivery == AbilityDef.Delivery.WAVE
		or delivery == AbilityDef.Delivery.RAY
	)


static func _allowed_are_skillshots(aug: SpellAugment) -> bool:
	if aug == null or aug.allowed_deliveries.is_empty():
		return false
	for delivery in aug.allowed_deliveries:
		if not _is_skillshot_delivery(delivery):
			return false
	return true


static func _mark(found: Dictionary, tag: String) -> void:
	if not tag.is_empty():
		found[tag] = true


static func _with(tags: PackedStringArray, tag: String) -> PackedStringArray:
	if tag.is_empty() or tags.has(tag):
		return tags
	var out := tags.duplicate()
	out.append(tag)
	return out


static func _ordered(found: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for tag in _ORDER:
		if found.has(tag):
			out.append(tag)
			found.erase(tag)
	var leftovers: Array = found.keys()
	leftovers.sort()
	for tag in leftovers:
		out.append(String(tag))
	return out


static func _join_labels(tags: PackedStringArray) -> String:
	var names: PackedStringArray = PackedStringArray()
	for tag in tags:
		names.append(label(tag))
	return ", ".join(names)
