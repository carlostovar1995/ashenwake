class_name SpellInfusion
extends RefCounted

var id: String = ""
var display_name: String = ""
var adjective: String = ""
var element: AbilityDef.Element = AbilityDef.Element.NONE
var color: Color = Color.WHITE
var vfx_primary: Color = Color.WHITE
var vfx_secondary: Color = Color.WHITE
var vfx_tertiary: Color = Color.WHITE
var vfx_layer: String = ""
var vfx_layer_scale: float = 0.7
var icon_tag: String = ""
var description: String = ""
var damage_mult: float = 1.0
var heal_mult: float = 1.0
var cooldown_mult: float = 1.0
var shield_from_base: float = 0.0
var heal_allies: bool = false
var applies_rejuvenation: bool = false
var holy_pulse_ratio: float = 0.0
var beneficial: bool = false
var offensive: bool = false
var utility: bool = false
