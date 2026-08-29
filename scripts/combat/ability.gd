class_name AbilityDef
extends Resource

enum TargetMode { SKILLSHOT, UNIT, GROUND, INSTANT }
enum Element { NONE, FIRE, ICE, STORM }

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
	return (heal > 0.05 or shield > 0.05) and damage <= 0.05


func can_self_cast() -> bool:
	if target_mode != TargetMode.UNIT:
		return false
	return heal > 0.05 or shield > 0.05


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
	var lines: PackedStringArray = []
	lines.append("%s    [%s]" % [display_name, hotkey])
	var bits: PackedStringArray = []
	if mana_cost > 0.05:
		bits.append("Mana %d" % int(mana_cost))
	if cooldown <= 0.05:
		bits.append("No CD")
	else:
		bits.append("CD %s s" % _num(cooldown))
	if range > 0.05:
		bits.append("Range %s" % _num(range))
	if gcd_exempt:
		bits.append("Off GCD")
	if heal > 0.05:
		bits.append("Heal %d" % int(round(heal)))
	if shield > 0.05:
		bits.append("Shield %d" % int(round(shield)))
	if cast_time > 0.05:
		bits.append("Cast %s s" % _num(cast_time))
	elif is_channel:
		bits.append("Channel %s s" % _num(channel_time))
	else:
		bits.append("Instant")
	if not bits.is_empty():
		lines.append("   ·   ".join(bits))
	if not description.is_empty():
		lines.append("")
		lines.append(description)
	return "\n".join(lines)


func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%0.1f" % v
