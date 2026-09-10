class_name ClassSkillDef
extends RefCounted

var id: String = ""
var talent_id: String = ""
var display_name: String = ""
var description: String = ""
var icon_id: String = ""
var mana_cost: float = 80.0
var cooldown: float = 30.0
var range: float = 12.0
var cast_time: float = 0.12
var damage: float = 0.0
var target_mode: int = AbilityDef.TargetMode.UNIT
var delivery: int = AbilityDef.Delivery.TARGET
var element: int = AbilityDef.Element.FIRE
var aoe_radius: float = 0.0
var zone_duration: float = 0.0
var tick_interval: float = 0.0
var recast_window: float = 0.0
var color: Color = Color(1.0, 0.45, 0.12)
var can_help_allies: bool = false
## Optional stamps merged with derived delivery/cast tags.
var extra_tags: PackedStringArray = PackedStringArray()
