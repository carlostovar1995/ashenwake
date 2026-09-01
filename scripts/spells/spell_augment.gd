class_name SpellAugment
extends RefCounted

var id: String = ""
var display_name: String = ""
var description: String = ""
var cast_time_mult: float = 1.0
var cooldown_mult: float = 1.0
var mana_mult: float = 1.0
var range_mult: float = 1.0
var area_mult: float = 1.0
var instant_cast: bool = false
var echo: bool = false
var echo_damage_mult: float = 0.2
var crit_chance_mult: float = 1.0
var crit_damage: float = 0.0
var recast: bool = false
var recast_window: float = 3.0
var recast_damage_mult: float = 0.2
var altered: bool = false
var move_while_casting: bool = false
var exclusive: bool = false
var extra_infusions: int = 0
var threat_mult: float = 1.0
