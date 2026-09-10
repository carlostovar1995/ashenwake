class_name UnitStatusSnapshots
extends Object

## Shared left-to-right order for nameplates, target frames, and the boss frame.
static var nameplate_debuff_order: Array[String] = [
		"frozen", "frozen_pending", "burn", "singe", "scorch", "chilled", "shocked", "afflicted",
		"seeded", "judged", "sundered", "solar_brand",
		"slow", "freeze_immune",
]


static func nameplate_debuffs(unit: Unit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit == null:
		return out
	var collected := unit.collect_debuffs()
	var by_id := {}
	for d in collected:
		by_id[String(d.get("id", ""))] = d
	var seen := {}
	for id in nameplate_debuff_order:
		if by_id.has(id):
			out.append(by_id[id])
			seen[id] = true
	for d in collected:
		var id := String(d.get("id", ""))
		if id.is_empty() or seen.has(id):
			continue
		out.append(d)
	return out
