class_name UnitIllusion
extends Object


static func has_illusion(ab: AbilityDef) -> bool:
	return ab != null and (ab.has_element(AbilityDef.Element.ILLUSION) or ab.has_infusion("illusion"))


static func extra_shot_dirs(ab: AbilityDef, dir: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not has_illusion(ab):
		return out
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return out
	flat = flat.normalized()
	if ab.delivery == AbilityDef.Delivery.BOLT:
		var outer := deg_to_rad(CombatBalance.flat("illusion.bolt.angle"))
		var inner := deg_to_rad(CombatBalance.flat("illusion.bolt.inner"))
		out.append(flat.rotated(Vector3.UP, inner))
		out.append(flat.rotated(Vector3.UP, -inner))
		out.append(flat.rotated(Vector3.UP, outer))
		out.append(flat.rotated(Vector3.UP, -outer))
	elif ab.delivery == AbilityDef.Delivery.WAVE:
		out.append(flat.rotated(Vector3.UP, PI * 0.5))
		out.append(flat.rotated(Vector3.UP, -PI * 0.5))
		out.append(flat.rotated(Vector3.UP, PI))
	return out


static func ground_extras(center: Vector3, radius: float, count: int = 2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if radius <= 0.2 or count <= 0:
		return out
	var rim := radius * CombatBalance.flat("illusion.aoe.out")
	var push := CombatBalance.flat("illusion.aoe.push")
	var jitter_lo := CombatBalance.flat("illusion.aoe.jitter.min")
	var jitter_hi := CombatBalance.flat("illusion.aoe.jitter.max")
	var size_lo := CombatBalance.flat("illusion.aoe.size.min")
	var size_hi := CombatBalance.flat("illusion.aoe.size.max")
	var min_gap := deg_to_rad(CombatBalance.flat("illusion.aoe.gap"))
	var angles: Array[float] = []
	var tries := 0
	while angles.size() < count and tries < 48:
		tries += 1
		var a := randf() * TAU
		var ok := true
		for other in angles:
			if absf(angle_difference(a, other)) < min_gap:
				ok = false
				break
		if ok:
			angles.append(a)
	if angles.size() < count and not angles.is_empty():
		var extra := angles[0] + min_gap + randf() * (PI - min_gap)
		angles.append(extra)
	for a in angles:
		var dist := rim + push + randf_range(jitter_lo, jitter_hi)
		var scale := randf_range(size_lo, size_hi)
		out.append({
			"at": Vector3(center.x + cos(a) * dist, center.y, center.z + sin(a) * dist),
			"radius": radius * scale,
		})
	return out


static func nearby_enemies(around: Unit, radius: float, caster: Unit, count: int) -> Array[Unit]:
	var out: Array[Unit] = []
	if around == null or not is_instance_valid(around) or caster == null or count <= 0:
		return out
	var choices: Array[Unit] = []
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u == around or u.team == caster.team:
			continue
		if around.global_position.distance_to(u.global_position) > radius:
			continue
		choices.append(u)
	choices.shuffle()
	for i in mini(count, choices.size()):
		out.append(choices[i])
	return out


static func random_nearby_enemy(around: Unit, radius: float, caster: Unit) -> Unit:
	var found := nearby_enemies(around, radius, caster, 1)
	if found.is_empty():
		return null
	return found[0]


static func meteor_line(from: Vector3, to: Vector3, count: int = 3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var a := Vector3(from.x, 0.28, from.z)
	var b := Vector3(to.x, 0.28, to.z)
	if count == 1:
		out.append(b)
		return out
	for i in count:
		var t := float(i) / float(count - 1)
		out.append(a.lerp(b, t))
	return out


static func apply_shield_stealth(target: Unit, ab: AbilityDef, duration: float) -> void:
	if target == null or not has_illusion(ab) or ab.delivery != AbilityDef.Delivery.SHIELD:
		return
	target.apply_stealth(maxf(duration, 0.4))


static func cluster_center(units: Array) -> Vector3:
	var acc := Vector3.ZERO
	var n := 0
	for item in units:
		var u := item as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		acc += u.global_position
		n += 1
	if n <= 0:
		return Vector3.ZERO
	acc /= float(n)
	acc.y = 0.0
	return acc


static func scatter_from(u: Unit, center: Vector3, _fallback: Vector3 = Vector3.ZERO) -> void:
	if u == null or u.is_dead:
		return
	var away := Vector3(u.global_position.x - center.x, 0.0, u.global_position.z - center.z)
	if away.length_squared() < 0.010:
		return
	UnitWind.knockback(
		u,
		away,
		CombatBalance.flat("illusion.ray.push"),
		CombatBalance.flat("illusion.ray.push.time")
	)
