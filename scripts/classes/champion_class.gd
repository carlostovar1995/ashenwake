class_name ChampionClass
extends RefCounted

var id: String = ""
var display_name: String = ""
var champion_name: String = ""
var blurb: String = ""
var passive_name: String = ""
var passive_description: String = ""
var passive_icon: String = ""
var available: bool = false
var visual_path: String = ""
var visual_scale: float = 1.0
var body_color: Color = Color(0.35, 0.7, 1.0)
var max_health: float = 650.0
var max_mana: float = 400.0
var mana_regen: float = 10.0
var move_speed: float = 7.2
var attack_damage: float = 58.0
var attack_range: float = 6.2
var attack_cooldown: float = 0.95
var attack_windup: float = 0.06
var attack_projectile_speed: float = 22.0
var is_melee: bool = false
var ability_builder: Callable
var attack_vfx_scene: String = ""
var attack_vfx_scale: float = 0.3
var attack_vfx_yaw: float = 0.0
var attack_applies_charged: bool = false
var nameplate_debuffs: PackedStringArray = PackedStringArray()
var atonement_ratio: float = 0.0
var attack_shield: float = 0.0
var attack_shield_duration: float = 0.0
var attack_mana_restore: float = 0.0


func apply_to(unit: Unit) -> void:
	unit.unit_name = champion_name
	unit.body_color = body_color
	unit.visual_path = visual_path
	unit.visual_scale = visual_scale
	unit.max_health = max_health
	unit.max_mana = max_mana
	unit.mana_regen = mana_regen
	unit.move_speed = move_speed
	unit.attack_damage = attack_damage
	unit.attack_range = attack_range
	unit.attack_cooldown = attack_cooldown
	unit.attack_windup = attack_windup
	unit.attack_projectile_speed = attack_projectile_speed
	unit.is_melee = is_melee
	unit.attack_vfx_scene = attack_vfx_scene
	unit.attack_vfx_scale = attack_vfx_scale
	unit.attack_vfx_yaw = attack_vfx_yaw
	unit.attack_applies_charged = attack_applies_charged
	unit.atonement_ratio = atonement_ratio
	unit.attack_shield = attack_shield
	unit.attack_shield_duration = attack_shield_duration
	unit.attack_mana_restore = attack_mana_restore
	unit.abilities = build_abilities()


func build_abilities() -> Array[AbilityDef]:
	if ability_builder.is_valid():
		return ability_builder.call()
	return []


func passive_tooltip() -> String:
	if passive_name.is_empty():
		return ""
	var lines: PackedStringArray = []
	lines.append("%s    [P]" % passive_name)
	if not passive_description.is_empty():
		lines.append("")
		lines.append(passive_description)
	return "\n".join(lines)
