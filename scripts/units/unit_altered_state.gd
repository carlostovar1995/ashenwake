class_name UnitAlteredState
extends RefCounted

## Owned altered-buff timers and frost-trail patches. UnitAltered is the only mutator.

var fire_left: float = 0.0
var ice_left: float = 0.0
var storm_left: float = 0.0
var shadow_left: float = 0.0
var shadow_stacks: int = 0
var shadow_acc: float = 0.0
var storm_acc: float = 0.0
var ice_drop: Vector3 = Vector3.ZERO
var on_frost_trail: bool = false
var frost_patches: Array[Node] = []
static var frost_trail_ab: AbilityDef


func active() -> bool:
	return fire_left > 0.05 or ice_left > 0.05 or storm_left > 0.05 or shadow_left > 0.05
