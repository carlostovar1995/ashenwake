class_name SpellWallLayout
extends Object

## Segment keys: kind ("box", "cylinder", or "capsule"), offset (wall-space X
## along the barrier, Z along the aim), yaw, length, thickness, radius.
## Capsule lies along X (stadium from above). Negative size uses the default.


static func aim_dir(from: Vector3, point: Vector3, fallback: Vector3 = Vector3(0, 0, -1)) -> Vector3:
	var dir := Vector3(point.x - from.x, 0.0, point.z - from.z)
	if dir.length_squared() < 0.0001:
		dir = Vector3(fallback.x, 0.0, fallback.z)
	if dir.length_squared() < 0.0001:
		return Vector3(0, 0, -1)
	return dir.normalized()


static func wall_basis(dir: Vector3) -> Basis:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(0, 0, -1)
	flat = flat.normalized()
	var right := Vector3(-flat.z, 0.0, flat.x)
	return Basis(right, Vector3.UP, -flat)


static func length_of(ab: AbilityDef) -> float:
	if style_id(ab) == "ice":
		return ice_length(ab)
	if style_id(ab) == "nature":
		return nature_radius() * 2.0
	if style_id(ab) == "divine":
		return divine_radius() * 2.0
	if style_id(ab) == "protection":
		return 2.0 * protection_radius() * sin(protection_arc() * 0.5)
	if style_id(ab) == "lightning":
		return lightning_radius() * 2.0
	if style_id(ab) == "illusion":
		return illusion_width()
	var length := CombatBalance.flat("wall.length")
	if ab != null and ab.skillshot_width > 1.0:
		length = ab.skillshot_width
	if style_id(ab) == "fire":
		length *= CombatBalance.flat("wall.fire.length")
	elif style_id(ab) == "wind":
		length *= CombatBalance.flat("wall.wind.length")
	return length


static func thickness_of(ab: AbilityDef) -> float:
	if style_id(ab) == "ice":
		return ice_radius() * 2.0
	if style_id(ab) == "illusion":
		return illusion_width()
	var thick := CombatBalance.flat("wall.thickness")
	if style_id(ab) == "fire":
		thick *= CombatBalance.flat("wall.fire.thickness")
	elif style_id(ab) == "protection":
		thick = CombatBalance.flat("wall.protection.thickness")
	elif style_id(ab) == "lightning":
		thick = lightning_radius() * 2.0
	return thick


static func height_of(ab: AbilityDef) -> float:
	if style_id(ab) == "fire":
		return CombatBalance.flat("wall.fire.height")
	if style_id(ab) == "lightning":
		var h := CombatBalance.flat("wall.lightning.height")
		return h if h >= 0.4 else 1.7
	if style_id(ab) == "illusion":
		return illusion_height()
	if style_id(ab) == "nature":
		return SpellWall.HEIGHT * 0.25
	return SpellWall.HEIGHT


static func is_physical(ab: AbilityDef) -> bool:
	var style := style_id(ab)
	return style != "fire" and style != "illusion" and style != "divine" and style != "wind"


## Friendly allied wall: only the owner's enemies may lock or damage it.
## Enemy wall: only the owner's friends may lock or damage it.
## Contested: enemy to both teams.
static func allegiance(ab: AbilityDef) -> int:
	var style := style_id(ab)
	if style == "lightning" or style == "nature":
		return SpellWall.Allegiance.ALLIED
	if is_physical(ab) and not is_protection(ab):
		return SpellWall.Allegiance.CONTESTED
	return SpellWall.Allegiance.ALLIED


static func allied_shots_pass(ab: AbilityDef) -> bool:
	return style_id(ab) == "lightning"


static func is_protection(ab: AbilityDef) -> bool:
	return ab != null and ab.delivery == AbilityDef.Delivery.WALL and style_id(ab) == "protection"


static func style_id(ab: AbilityDef) -> String:
	if ab == null or ab.infusion_ids.is_empty():
		return ""
	return String(ab.infusion_ids[0])


static func lightning_radius(_ab: AbilityDef = null) -> float:
	var r := CombatBalance.flat("wall.lightning.radius")
	return r if r >= 0.12 else 0.4


static func illusion_width(_ab: AbilityDef = null) -> float:
	var w := CombatBalance.flat("wall.illusion.width")
	return w if w >= 0.4 else 1.85


static func illusion_radius(_ab: AbilityDef = null) -> float:
	return illusion_width(_ab) * 0.5


static func illusion_height(_ab: AbilityDef = null) -> float:
	var h := CombatBalance.flat("wall.illusion.height")
	return h if h >= 0.6 else 2.45


static func illusion_thickness(_ab: AbilityDef = null) -> float:
	var z := CombatBalance.flat("wall.illusion.thickness")
	return z if z >= 0.05 else 0.12


static func ice_radius(_ab: AbilityDef = null) -> float:
	return CombatBalance.flat("wall.ice.radius")


static func ice_count() -> int:
	return maxi(int(round(CombatBalance.flat("wall.ice.count"))), 1)


static func ice_length(_ab: AbilityDef = null) -> float:
	return ice_radius(_ab) * 2.0 * float(ice_count())


static func ice_medial_half(_ab: AbilityDef = null) -> float:
	return maxf(ice_length(_ab) * 0.5 - ice_radius(_ab), 0.0)


static func ice_distance_xz(local: Vector2, _ab: AbilityDef = null) -> float:
	var r := ice_radius(_ab)
	var x := clampf(local.x, -ice_medial_half(_ab), ice_medial_half(_ab))
	return maxf(0.0, Vector2(local.x - x, local.y).length() - r)


static func ice_zone_radius(_ab: AbilityDef = null) -> float:
	return SpellCatalog.aoe_explosion().aoe_radius


static func divine_radius(_ab: AbilityDef = null) -> float:
	return CombatBalance.flat("wall.divine.radius")


static func divine_height(_ab: AbilityDef = null) -> float:
	var h := CombatBalance.flat("wall.divine.height")
	return h if h >= 0.4 else 2.7


static func protection_radius(_ab: AbilityDef = null) -> float:
	var r := CombatBalance.flat("wall.protection.radius")
	return r if r >= 1.0 else 2.8


static func protection_arc(_ab: AbilityDef = null) -> float:
	return protection_step() * float(maxi(protection_count() - 1, 1))


static func protection_step() -> float:
	var deg := CombatBalance.flat("wall.protection.step")
	if deg < 1.0:
		deg = 10.0
	return deg_to_rad(deg)


static func protection_count() -> int:
	return maxi(int(round(CombatBalance.flat("wall.protection.count"))), 5)


static func protection_inward() -> float:
	return clampf(CombatBalance.pct("wall.protection.inward"), 0.0, 0.85)


static func protection_offsets(_ab: AbilityDef = null) -> Array[Vector3]:
	var n := protection_count()
	var ring := protection_radius()
	var step := protection_step()
	var start := -step * float(n - 1) * 0.5
	var pull := ring * protection_inward()
	var out: Array[Vector3] = []
	for i in n:
		var angle := start + step * float(i)
		out.append(Vector3(sin(angle) * ring, 0.0, -cos(angle) * ring + pull))
	return out


static func protection_segments(_ab: AbilityDef = null) -> Array[Dictionary]:
	var ring := protection_radius()
	var step := protection_step()
	var start := -step * float(maxi(protection_count() - 1, 1)) * 0.5
	var chord := 2.0 * ring * sin(step * 0.5) * 1.2
	var thick := maxf(CombatBalance.flat("wall.protection.thickness"), 0.5)
	var out: Array[Dictionary] = []
	var offsets := protection_offsets(_ab)
	for i in offsets.size():
		var angle := start + step * float(i)
		# Wide face toward the caster: box +Z (thickness) points at the holder.
		out.append(_segment(offsets[i], -angle, chord, thick))
	return out


static func nature_radius(_ab: AbilityDef = null) -> float:
	return CombatBalance.flat("wall.nature.radius") * 0.8


static func nature_count() -> int:
	return maxi(int(round(CombatBalance.flat("wall.nature.count"))), 3)


static func nature_segments(_ab: AbilityDef = null) -> Array[Dictionary]:
	var n := nature_count()
	var ring := nature_radius()
	var chord := 2.0 * ring * sin(PI / float(n))
	var out: Array[Dictionary] = []
	for i in n:
		var angle := TAU * float(i) / float(n)
		var offset := Vector3(sin(angle) * ring, 0.0, cos(angle) * ring)
		out.append(_segment(offset, angle, chord, -1.0))
	return out


static func ice_offsets(_ab: AbilityDef = null) -> Array[Vector3]:
	return [Vector3.ZERO]


static func segments(ab: AbilityDef) -> Array[Dictionary]:
	match style_id(ab):
		"ice":
			return [_segment(Vector3.ZERO, 0.0, ice_length(ab), ice_radius(ab) * 2.0, "capsule", ice_radius(ab))]
		"fire":
			return [_segment()]
		"nature":
			return nature_segments(ab)
		"divine":
			return []
		"protection":
			return protection_segments(ab)
		"lightning":
			return [_segment(Vector3.ZERO, 0.0, -1.0, -1.0, "cylinder", lightning_radius())]
		_:
			return [_segment()]


static func _segment(
	offset: Vector3 = Vector3.ZERO,
	yaw: float = 0.0,
	length: float = -1.0,
	thickness: float = -1.0,
	kind: String = "box",
	radius: float = -1.0
) -> Dictionary:
	return {
		"kind": kind,
		"offset": offset,
		"yaw": yaw,
		"length": length,
		"thickness": thickness,
		"radius": radius,
	}


static func contains_point(
	center: Vector3,
	dir: Vector3,
	ab: AbilityDef,
	point: Vector3,
	pad: float = 0.0
) -> bool:
	var basis := wall_basis(dir)
	if style_id(ab) == "lightning":
		var to := point - center
		to.y = 0.0
		return to.length() <= lightning_radius(ab) + pad
	if style_id(ab) == "illusion":
		var to := point - center
		to.y = 0.0
		return to.length() <= illusion_radius(ab) + pad
	if style_id(ab) == "divine":
		var to := point - center
		to.y = 0.0
		return to.length() <= divine_radius(ab) + pad
	if style_id(ab) == "nature":
		var to := point - center
		to.y = 0.0
		return to.length() <= nature_radius(ab) + pad
	if style_id(ab) == "ice":
		var zone := ice_zone_radius(ab) + pad
		for off in ice_offsets(ab):
			var world := center + basis * off
			var to := point - world
			to.y = 0.0
			if to.length() <= zone:
				return true
		return false
	var length := length_of(ab)
	var thick := thickness_of(ab)
	var right := basis.x
	var flat := -basis.z
	for raw in segments(ab):
		var seg_len := float(raw.get("length", -1.0))
		var seg_thick := float(raw.get("thickness", -1.0))
		if seg_len <= 0.0:
			seg_len = length
		if seg_thick <= 0.0:
			seg_thick = thick
		var local_off: Vector3 = raw.get("offset", Vector3.ZERO)
		var yaw := float(raw.get("yaw", 0.0))
		var world := center + basis * local_off
		var to := point - world
		to.y = 0.0
		var along := to.dot(right.rotated(Vector3.UP, yaw))
		var thru := to.dot(flat.rotated(Vector3.UP, yaw))
		if absf(along) <= seg_len * 0.5 + pad and absf(thru) <= seg_thick * 0.5 + pad:
			return true
	return false
