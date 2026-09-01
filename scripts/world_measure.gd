class_name WorldMeasure
extends Object

## Player-facing distance. 1.0 Godot world unit = 1.0 meter.
const METERS_PER_UNIT := 1.0


static func meters(world_units: float) -> float:
	return world_units * METERS_PER_UNIT


static func format(world_units: float) -> String:
	var m := meters(world_units)
	if m <= 0.05:
		return ""
	if is_equal_approx(m, roundf(m)):
		return "%dm" % int(roundf(m))
	return "%0.1fm" % m
