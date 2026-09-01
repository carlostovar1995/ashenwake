class_name UnitWind
extends Object


static func has_wind(ab: AbilityDef) -> bool:
	return ab != null and ab.has_element(AbilityDef.Element.WIND)


static func knockback(u: Unit, dir: Vector3, distance: float, duration: float) -> void:
	if u == null or u.is_dead or distance <= 0.04 or duration <= 0.02:
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	u._wind_kb_from = u.global_position
	u._wind_kb_to = _stop_point(u, u.global_position, u.global_position + flat * distance)
	u._wind_kb_dur = duration
	u._wind_kb_left = duration


static func knockup(u: Unit, height: float, duration: float, fall_speed: float = 1.0) -> void:
	if u == null or u.is_dead or height <= 0.04 or duration <= 0.04:
		return
	var rise := duration * 0.5
	var fall := rise / maxf(fall_speed, 0.05)
	u._wind_air_peak = height
	u._wind_air_rise = rise
	u._wind_air_dur = rise + fall
	u._wind_air_left = u._wind_air_dur
	u._wind_ground_y = u.global_position.y


static func start_ray_push(u: Unit, caster: Unit) -> void:
	if u == null or u.is_dead or caster == null:
		return
	u._wind_ray_from = caster
	u._wind_ray_left = 0.35


static func start_carry(u: Unit, proj: Projectile) -> void:
	if u == null or u.is_dead or proj == null:
		return
	u._wind_carry = proj


static func stop_carry(u: Unit, proj: Projectile) -> void:
	if u == null:
		return
	if u._wind_carry == proj:
		u._wind_carry = null


static func pull_toward(u: Unit, center: Vector3, speed: float, delta: float) -> void:
	if u == null or u.is_dead or speed <= 0.0 or delta <= 0.0:
		return
	var to := Vector3(center.x - u.global_position.x, 0.0, center.z - u.global_position.z)
	var dist := to.length()
	if dist <= 0.12:
		return
	var step := minf(speed * delta, dist)
	var dest := _stop_point(u, u.global_position, u.global_position + to / dist * step)
	u.global_position = dest


static func tick(u: Unit, delta: float) -> bool:
	if u == null or u.is_dead:
		_clear(u)
		return false
	var moved := false
	if u._wind_air_left > 0.0:
		moved = true
		_tick_air(u, delta)
	if u._wind_kb_left > 0.0:
		moved = true
		_tick_knockback(u, delta)
	if u._wind_carry != null:
		if not is_instance_valid(u._wind_carry) or u._wind_carry._resolved:
			u._wind_carry = null
		else:
			moved = true
			_tick_carry(u, delta)
	if u._wind_ray_left > 0.0:
		u._wind_ray_left = maxf(0.0, u._wind_ray_left - delta)
		var caster := u._wind_ray_from
		if caster == null or not is_instance_valid(caster) or caster.is_dead:
			u._wind_ray_left = 0.0
			u._wind_ray_from = null
		elif u._wind_ray_left > 0.0:
			moved = true
			var away := Vector3(u.global_position.x - caster.global_position.x, 0.0, u.global_position.z - caster.global_position.z)
			if away.length_squared() < 0.0001:
				away = caster.facing_dir()
			var step := away.normalized() * CombatBalance.flat("wind.ray.drift") * delta
			u.global_position = _stop_point(u, u.global_position, u.global_position + step)
	if moved:
		u.velocity = Vector3.ZERO
		return true
	return false


static func _tick_air(u: Unit, delta: float) -> void:
	u._wind_air_left = maxf(0.0, u._wind_air_left - delta)
	var elapsed := u._wind_air_dur - u._wind_air_left
	var rise := u._wind_air_rise if u._wind_air_rise > 0.001 else u._wind_air_dur * 0.5
	var fall := maxf(u._wind_air_dur - rise, 0.001)
	var sine_t := 0.0
	if elapsed <= rise:
		sine_t = (elapsed / maxf(rise, 0.001)) * 0.5
	else:
		sine_t = 0.5 + ((elapsed - rise) / fall) * 0.5
	sine_t = clampf(sine_t, 0.0, 1.0)
	var lift := sin(sine_t * PI) * u._wind_air_peak
	var p := u.global_position
	p.y = u._wind_ground_y + lift
	if u._wind_air_left <= 0.0:
		p.y = u._wind_ground_y
		u._wind_air_peak = 0.0
		u._wind_air_rise = 0.0
	u.global_position = p


static func _tick_knockback(u: Unit, delta: float) -> void:
	u._wind_kb_left = maxf(0.0, u._wind_kb_left - delta)
	var t := 1.0 if u._wind_kb_dur <= 0.001 else 1.0 - (u._wind_kb_left / u._wind_kb_dur)
	t = clampf(t, 0.0, 1.0)
	var p := u._wind_kb_from.lerp(u._wind_kb_to, t)
	p.y = u.global_position.y
	u.global_position = p


static func _tick_carry(u: Unit, delta: float) -> void:
	if u._wind_carry == null:
		return
	var step := Vector3(u._wind_carry.direction.x, 0.0, u._wind_carry.direction.z)
	if step.length_squared() < 0.0001:
		return
	step = step.normalized() * u._wind_carry.speed * delta
	var dest := _stop_point(u, u.global_position, u.global_position + step)
	dest.y = u.global_position.y
	u.global_position = dest


static func _stop_point(u: Unit, from: Vector3, dest: Vector3) -> Vector3:
	var arena := ArenaState.arena as Arena
	var clearance := maxf(u.radius, 0.4)
	dest.y = from.y
	if arena == null:
		return dest
	dest = arena.clamp_movement_point(dest, clearance)
	if arena.movement_segment_clear(from, dest, clearance + 0.06):
		return dest
	var best := from
	for i in 10:
		var p := from.lerp(dest, float(i + 1) / 10.0)
		p = arena.clamp_movement_point(p, clearance)
		p.y = from.y
		if not arena.movement_segment_clear(from, p, clearance + 0.06):
			break
		best = p
	return best


static func _clear(u: Unit) -> void:
	if u == null:
		return
	u._wind_kb_left = 0.0
	u._wind_air_left = 0.0
	u._wind_air_rise = 0.0
	u._wind_ray_left = 0.0
	u._wind_ray_from = null
	u._wind_carry = null


static func apply_on_skillshot(u: Unit, ab: AbilityDef, proj: Projectile) -> void:
	if u == null or not has_wind(ab) or proj == null:
		return
	if ab.delivery == AbilityDef.Delivery.WAVE:
		start_carry(u, proj)
	elif ab.delivery == AbilityDef.Delivery.MISSILES:
		u.apply_slow(1.0, CombatBalance.flat("wind.missiles.snare"))
	elif ab.delivery == AbilityDef.Delivery.BOLT:
		knockback(u, proj.direction, CombatBalance.flat("wind.bolt.dist"), CombatBalance.flat("wind.bolt.time"))


static func apply_on_target(u: Unit, ab: AbilityDef, caster: Unit) -> void:
	if u == null or caster == null or not has_wind(ab):
		return
	if ab.delivery != AbilityDef.Delivery.TARGET:
		return
	var away := Vector3(u.global_position.x - caster.global_position.x, 0.0, u.global_position.z - caster.global_position.z)
	if away.length_squared() < 0.0001:
		away = caster.facing_dir()
	knockback(u, away, CombatBalance.flat("wind.bolt.dist"), CombatBalance.flat("wind.bolt.time"))


static func apply_on_burst(u: Unit, ab: AbilityDef, center: Vector3) -> void:
	if u == null or not has_wind(ab):
		return
	if ab.delivery == AbilityDef.Delivery.AOE_EXPLOSION or ab.id == "aoe_explosion":
		knockup(
			u,
			CombatBalance.flat("wind.burst.height") * 1.5,
			CombatBalance.flat("wind.burst.time"),
			CombatBalance.flat("wind.burst.fall")
		)
		return
	var away := Vector3(u.global_position.x - center.x, 0.0, u.global_position.z - center.z)
	if away.length_squared() < 0.0001:
		away = Vector3(0.0, 0.0, 1.0)
	if ab.delivery == AbilityDef.Delivery.METEOR or ab.id == "meteor":
		knockback(u, away, CombatBalance.flat("wind.meteor.dist"), CombatBalance.flat("wind.meteor.snap"))
		return
	if ab.delivery == AbilityDef.Delivery.NOVA:
		var rad := maxf(ab.aoe_radius, 0.4)
		var t := clampf(away.length() / rad, 0.0, 1.0)
		var dist := lerpf(CombatBalance.flat("wind.nova.max"), CombatBalance.flat("wind.nova.min"), t) * 1.3
		knockback(u, away, dist, CombatBalance.flat("wind.nova.snap"))


static func apply_shield_haste(target: Unit, ab: AbilityDef, duration: float) -> void:
	if target == null or not has_wind(ab) or ab.delivery != AbilityDef.Delivery.SHIELD:
		return
	target.apply_haste(CombatBalance.pct("wind.shield.haste"), maxf(duration, 0.4))


static func apply_aura_haste(target: Unit, ab: AbilityDef, hold: float) -> void:
	if target == null or not has_wind(ab):
		return
	target.apply_haste(CombatBalance.pct("wind.aura.haste"), maxf(hold, 0.2))
