class_name UnitWind
extends Object

## Knockback, knockup, ray push, wave-carry, and wind pull. Bosses ignore all of
## these unless Unit.allow_knock is set for that fight.


static func has_wind(ab: AbilityDef) -> bool:
	return ab != null and ab.has_element(AbilityDef.Element.WIND)


static func blocks_knock(u: Unit) -> bool:
	return u != null and u.is_boss and not u.allow_knock


static func knockback(u: Unit, dir: Vector3, distance: float, duration: float) -> void:
	if u == null or u.is_dead or distance <= 0.04 or duration <= 0.02:
		return
	if blocks_knock(u):
		return
	if SanctuaryZone.blocks_knockback(u):
		return
	if WorldrootZone.blocks_knockback(u):
		return
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	var state := _state(u)
	state.kb_from = u.global_position
	state.kb_to = _stop_point(u, u.global_position, u.global_position + flat * distance)
	state.kb_dur = duration
	state.kb_left = duration


static func knockup(u: Unit, height: float, duration: float, fall_speed: float = 1.0) -> void:
	if u == null or u.is_dead or height <= 0.04 or duration <= 0.04:
		return
	if blocks_knock(u):
		return
	var rise := duration * 0.5
	var fall := rise / maxf(fall_speed, 0.05)
	var state := _state(u)
	state.air_peak = height
	state.air_rise = rise
	state.air_dur = rise + fall
	state.air_left = state.air_dur
	state.ground_y = u.global_position.y


static func start_ray_push(u: Unit, caster: Unit) -> void:
	if u == null or u.is_dead or caster == null:
		return
	if blocks_knock(u):
		return
	var state := _state(u)
	state.ray_from = caster
	state.ray_dir = Vector3.ZERO
	state.ray_left = _ray_push_time()


static func start_ray_push_along(u: Unit, from_pos: Vector3, fallback: Vector3 = Vector3.ZERO) -> void:
	if u == null or u.is_dead:
		return
	if blocks_knock(u):
		return
	var away := Vector3(u.global_position.x - from_pos.x, 0.0, u.global_position.z - from_pos.z)
	if away.length_squared() < 0.010:
		away = Vector3(fallback.x, 0.0, fallback.z)
	if away.length_squared() < 0.010:
		return
	var state := _state(u)
	state.ray_from = null
	state.ray_dir = away.normalized()
	state.ray_left = _ray_push_time()


static func start_carry(u: Unit, proj: Projectile) -> void:
	if u == null or u.is_dead or proj == null:
		return
	if blocks_knock(u):
		return
	_state(u).carry = proj


static func stop_carry(u: Unit, proj: Projectile) -> void:
	if u == null:
		return
	var state := _state(u)
	if state.carry == proj:
		state.carry = null


static func pull_toward(u: Unit, center: Vector3, speed: float, delta: float) -> void:
	if u == null or u.is_dead or speed <= 0.0 or delta <= 0.0:
		return
	if blocks_knock(u):
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
	if blocks_knock(u):
		_clear(u)
		return false
	var state := _state(u)
	var moved := false
	if state.air_left > 0.0:
		moved = true
		_tick_air(u, state, delta)
	if state.kb_left > 0.0:
		moved = true
		_tick_knockback(u, state, delta)
	if state.carry != null:
		var carry := state.carry
		if not is_instance_valid(carry) or (carry is Projectile and (carry as Projectile)._resolved):
			state.carry = null
		else:
			moved = true
			_tick_carry(u, state, delta)
	if state.ray_left > 0.0:
		state.ray_left = maxf(0.0, state.ray_left - delta)
		var away := _ray_push_dir(u, state)
		if away.length_squared() < 0.0001:
			state.ray_left = 0.0
			state.ray_from = null
			state.ray_dir = Vector3.ZERO
		elif state.ray_left > 0.0:
			moved = true
			var step := away.normalized() * CombatBalance.flat("wind.ray.drift") * delta
			u.global_position = _stop_point(u, u.global_position, u.global_position + step)
	if moved:
		u.velocity = Vector3.ZERO
		return true
	return false


static func _tick_air(u: Unit, state: UnitWindState, delta: float) -> void:
	state.air_left = maxf(0.0, state.air_left - delta)
	var elapsed: float = state.air_dur - state.air_left
	var rise: float = state.air_rise if state.air_rise > 0.001 else state.air_dur * 0.5
	var fall: float = maxf(state.air_dur - rise, 0.001)
	var sine_t := 0.0
	if elapsed <= rise:
		sine_t = (elapsed / maxf(rise, 0.001)) * 0.5
	else:
		sine_t = 0.5 + ((elapsed - rise) / fall) * 0.5
	sine_t = clampf(sine_t, 0.0, 1.0)
	var lift: float = sin(sine_t * PI) * state.air_peak
	var p := u.global_position
	p.y = state.ground_y + lift
	if state.air_left <= 0.0:
		p.y = state.ground_y
		state.air_peak = 0.0
		state.air_rise = 0.0
	u.global_position = p


static func _tick_knockback(u: Unit, state: UnitWindState, delta: float) -> void:
	state.kb_left = maxf(0.0, state.kb_left - delta)
	var t: float = 1.0 if state.kb_dur <= 0.001 else 1.0 - (state.kb_left / state.kb_dur)
	t = clampf(t, 0.0, 1.0)
	var p: Vector3 = state.kb_from.lerp(state.kb_to, t)
	p.y = u.global_position.y
	u.global_position = p


static func _tick_carry(u: Unit, state: UnitWindState, delta: float) -> void:
	var carry := state.carry
	if carry == null or not (carry is Projectile):
		return
	var proj := carry as Projectile
	var step := Vector3(proj.direction.x, 0.0, proj.direction.z)
	if step.length_squared() < 0.0001:
		return
	step = step.normalized() * proj.speed * delta
	var dest := _stop_point(u, u.global_position, u.global_position + step)
	dest.y = u.global_position.y
	u.global_position = dest


static func _ray_push_dir(u: Unit, state: UnitWindState) -> Vector3:
	var caster: Unit = state.ray_from
	if caster != null and is_instance_valid(caster) and not caster.is_dead:
		var away := Vector3(u.global_position.x - caster.global_position.x, 0.0, u.global_position.z - caster.global_position.z)
		if away.length_squared() < 0.0001:
			away = caster.facing_dir()
		return away
	return state.ray_dir


static func _ray_push_time() -> float:
	return CombatBalance.flat("wind.ray.time")


static func _state(u: Unit) -> UnitWindState:
	return u.wind


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
	_state(u).clear()


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
