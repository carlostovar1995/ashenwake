class_name AbilityDef
extends Resource

enum TargetMode { SKILLSHOT, UNIT, GROUND, INSTANT }
enum Element { NONE, FIRE, ICE, STORM, HOLY, SHADOW, NATURE, PROTECTION, WIND, ILLUSION }
enum Delivery {
	BOLT,
	MISSILES,
	GROUND_AOE,
	AOE_EXPLOSION,
	AURA,
	RAY,
	METEOR,
	NOVA,
	WALL,
	SHIELD,
	TARGET,
	WAVE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var hotkey: String = "Q"
@export var mana_cost: float = 50.0
@export var cooldown: float = 6.0
@export var range: float = 10.0
@export var target_mode: TargetMode = TargetMode.SKILLSHOT
@export var skillshot_width: float = 0.9
@export var skillshot_speed: float = 18.0
@export var skillshot_length: float = 12.0
@export var aoe_radius: float = 2.5
@export var inner_radius: float = 0.0
@export var damage: float = 80.0
@export var heal: float = 0.0
@export var cast_time: float = 0.12
@export var color: Color = Color(0.4, 0.8, 1.0)
@export var slow_percent: float = 0.0
@export var slow_duration: float = 0.0
@export var delay_time: float = 0.0
@export var vfx_scene: String = ""
@export var vfx_scale: float = 1.0
@export var vfx_primary: Color = Color(0, 0, 0, 0)
@export var vfx_secondary: Color = Color(0, 0, 0, 0)
@export var vfx_tertiary: Color = Color(0, 0, 0, 0)
@export var vfx_yaw: float = 0.0
@export var element: Element = Element.NONE
@export var shield: float = 0.0
@export var description: String = ""
@export var icon_id: String = ""
@export var cone_angle: float = 0.0
@export var splash_radius: float = 0.0
@export var splash_ratio: float = 0.0
@export var chain_bounces: int = 0
@export var bounce_range: float = 6.0
@export var bounce_delay: float = 0.08
@export var is_channel: bool = false
@export var channel_time: float = 0.0
@export var damage_max: float = 0.0
@export var aoe_radius_max: float = 0.0
@export var zone_duration: float = 0.0
@export var tick_interval: float = 0.0
@export var tick_damage: float = 0.0
@export var buff_duration: float = 0.0
@export var cast_speed_bonus: float = 0.0
@export var mana_cost_reduction: float = 0.0
@export var cooldown_recovery_rate: float = 1.0
@export var grant_all_infusions: bool = false
@export var mark_damage_bonus: float = 0.0
@export var consume_marks: bool = false
@export var gcd_exempt: bool = false
@export var shield_duration: float = 0.0
@export var atonement_amp: float = 0.0
@export var tick_shield: float = 0.0
@export var free_cast_charges: int = 0
@export var heal_allies: bool = false
@export var hit_cooldown_reduction: float = 0.0
@export var projectile_count: int = 1
@export var extra_elements: PackedInt32Array = PackedInt32Array()
@export var split_elements: PackedInt32Array = PackedInt32Array()
@export var split_damage_inc: PackedFloat32Array = PackedFloat32Array()
@export var split_heal_inc: PackedFloat32Array = PackedFloat32Array()
@export var split_shield_inc: PackedFloat32Array = PackedFloat32Array()
@export var split_flat: PackedFloat32Array = PackedFloat32Array()
@export var vfx_layers: Array = []
@export var can_freeze: bool = false
@export var holy_pulse_ratio: float = 0.0
@export var applies_rejuvenation: bool = false
@export var base_power: float = 0.0
@export var echo: bool = false
@export var echo_damage_mult: float = 0.2
@export var crit_chance: float = 0.05
@export var crit_damage: float = 2.0
@export var recast_window: float = 0.0
@export var recast_damage_mult: float = 0.2
@export var icon_infusion_tag: String = ""
@export var delivery: Delivery = Delivery.BOLT
@export var cost_per_tick: bool = false
@export var is_toggle: bool = false
@export var friendly_only: bool = false
@export var can_help_allies: bool = false
@export var altered: bool = false
@export var altered_element: int = Element.NONE
@export var move_while_casting: bool = false
@export var infusion_ids: PackedStringArray = PackedStringArray()
@export var implemented: bool = true
@export var threat_mult: float = 1.0
@export var loadout_slot: int = -1


func combat_id(slot: int = -1) -> String:
	var idx := slot if slot >= 0 else loadout_slot
	if idx < 0 or id.is_empty():
		return id
	return "%s#%d" % [id, idx]


static func combat_id_of(ab: AbilityDef, fallback: String = "") -> String:
	if ab == null:
		return fallback
	return ab.combat_id()


static func matches_base(ability_id: String, base: String) -> bool:
	return base_from_combat_id(ability_id) == base


static func stamp_loadout_slots(next: Array) -> void:
	for i in next.size():
		var ab = next[i]
		if ab is AbilityDef:
			(ab as AbilityDef).loadout_slot = i


static func slot_from_combat_id(ability_id: String) -> int:
	var hash_at := ability_id.rfind("#")
	if hash_at < 0:
		return -1
	var tail := ability_id.substr(hash_at + 1)
	if not tail.is_valid_int():
		return -1
	return tail.to_int()


static func base_from_combat_id(ability_id: String) -> String:
	var hash_at := ability_id.rfind("#")
	if hash_at < 0:
		return ability_id
	return ability_id.substr(0, hash_at)


static func make(
	p_id: String,
	p_name: String,
	p_hotkey: String,
	p_mode: TargetMode,
	p_mana: float,
	p_cd: float,
	p_range: float,
	p_damage: float,
	p_color: Color
) -> AbilityDef:
	var a := AbilityDef.new()
	a.id = p_id
	a.display_name = p_name
	a.hotkey = p_hotkey
	a.target_mode = p_mode
	a.mana_cost = p_mana
	a.cooldown = p_cd
	a.range = p_range
	a.damage = p_damage
	a.color = p_color
	return a


func is_cone() -> bool:
	return cone_angle > 0.01


func is_ally_support() -> bool:
	if friendly_only:
		return true
	return (heal > 0.05 or shield > 0.05) and damage <= 0.05


func locks_unit_target() -> bool:
	return target_mode == TargetMode.UNIT


func can_target_allies() -> bool:
	return friendly_only or can_help_allies or altered


func can_target_enemies() -> bool:
	return not friendly_only


func accepts_unit(caster_team: int, target: Unit) -> bool:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return false
	if target.team == caster_team:
		return can_target_allies()
	return can_target_enemies()


func can_self_cast() -> bool:
	return can_target_allies()


func altered_buff_elements() -> PackedInt32Array:
	var out := PackedInt32Array()
	if not altered:
		return out
	for kind in [Element.FIRE, Element.ICE, Element.STORM, Element.SHADOW]:
		if has_element(kind) or altered_element == kind:
			out.append(kind)
	return out


func allows_self_click() -> bool:
	if not locks_unit_target() or not can_self_cast():
		return false
	return delivery == Delivery.TARGET or id == "target"


func ticks_shield() -> bool:
	return delivery == Delivery.GROUND_AOE or delivery == Delivery.AURA or delivery == Delivery.RAY


func pierces_skillshot() -> bool:
	return delivery == Delivery.WAVE


func has_infusion(infusion_id: String) -> bool:
	return infusion_ids.has(infusion_id)


func has_element(kind: int) -> bool:
	if element == kind:
		return true
	for extra in extra_elements:
		if extra == kind:
			return true
	for split in split_elements:
		if split == kind:
			return true
	return false


func scaled_damage(charge: float) -> float:
	if damage_max <= damage:
		return damage
	return lerpf(damage, damage_max, clampf(charge, 0.0, 1.0))


func scaled_radius(charge: float) -> float:
	if aoe_radius_max <= aoe_radius:
		return aoe_radius
	return lerpf(aoe_radius, aoe_radius_max, clampf(charge, 0.0, 1.0))


func vfx_cfg() -> Dictionary:
	var cfg := {
		"scale": vfx_scale,
		"area_radius": aoe_radius,
		"lifetime": maxf(1.2, delay_time + 1.6),
		"yaw_offset": vfx_yaw,
	}
	if vfx_primary.a > 0.0:
		cfg["primary_color"] = vfx_primary
	if vfx_secondary.a > 0.0:
		cfg["secondary_color"] = vfx_secondary
	if vfx_tertiary.a > 0.0:
		cfg["tertiary_color"] = vfx_tertiary
	return cfg


func tooltip() -> String:
	var recipe: SpellRecipe = null
	if GameSession.spell_loadout.size() == 6:
		var idx := SpellCatalog.HOTKEYS.find(hotkey)
		if idx >= 0 and GameSession.spell_loadout[idx] is SpellRecipe:
			recipe = GameSession.spell_loadout[idx]
	return "%s    [%s]\n%s" % [display_name, hotkey, SpellCard.hud(self, recipe)]


func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%0.1f" % v
