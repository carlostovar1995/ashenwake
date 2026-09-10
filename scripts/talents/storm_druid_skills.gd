class_name StormDruidSkills
extends Object


static func try_deliver(caster: Unit, ab: AbilityDef, point: Vector3, _target: Unit, slot: int, combat_text_cast_id: int, recast: bool) -> bool:
	if caster == null or ab == null:
		return false
	match ab.skill_id:
		"flourish":
			_flourish(caster)
			return true
		"worldroot":
			_worldroot(caster, ab, point, slot, combat_text_cast_id, recast)
			return true
		"worldbloom":
			_worldbloom(caster, ab, point, slot, combat_text_cast_id, recast)
			return true
		"tempest_bloom":
			_tempest_bloom(caster)
			return true
		"eye_of_the_storm":
			_eye_of_the_storm(caster, ab, slot, recast)
			return true
		"eye_of_tempest":
			_eye_of_tempest(caster, ab, slot, recast)
			return true
		_:
			return false


static func _flourish(caster: Unit) -> void:
	var radius := CombatBalance.flat("skill.flourish.radius")
	var per := CombatBalance.flat("skill.flourish.heal")
	var bloom := CombatBalance.flat("skill.flourish.bloom")
	for other in ArenaState.units_near(caster.global_position, radius, false, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team != caster.team:
			continue
		var stacks := u.consume_rejuvenation()
		if stacks > 0:
			u.apply_heal(per * float(stacks), caster, "flourish")
		if u.has_lifebloom_from(caster):
			u.consume_lifebloom(bloom, false)
			u.apply_damage_reduction(0.15, 3.0)
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.drought_left = CombatBalance.flat("skill.flourish.drought")
		hooks.drought_rejuv_only = false
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, caster.global_position, {"scale": 0.85, "lifetime": 1.0})


static func _worldroot(caster: Unit, ab: AbilityDef, point: Vector3, slot: int, combat_text_cast_id: int, recast: bool) -> void:
	var hooks := caster.talent_hooks()
	if recast:
		WorldrootZone.close_for(caster)
		if hooks != null:
			hooks.rooted_left = 0.0
		return
	_reset_nature_wall_cd(caster)
	var duration := ab.zone_duration if ab.zone_duration > 0.05 else CombatBalance.flat("skill.worldroot.time")
	if hooks != null:
		hooks.rooted_left = duration
	caster.apply_slow(0.70, duration)
	var zone := WorldrootZone.spawn(caster, point, ab, combat_text_cast_id)
	if hooks != null and zone != null:
		hooks.worldroot_zone_id = zone.get_instance_id()
	if slot >= 0:
		caster.arm_skill_recast(slot, duration)


static func _worldbloom(caster: Unit, ab: AbilityDef, point: Vector3, slot: int, combat_text_cast_id: int, recast: bool) -> void:
	if recast:
		_worldbloom_consume(caster, point)
		_worldroot(caster, ab, point, slot, combat_text_cast_id, true)
		var hooks := caster.talent_hooks()
		if hooks != null:
			hooks.drought_left = 3.0
			hooks.drought_rejuv_only = false
		return
	ab.heal = 40.0
	_worldroot(caster, ab, point, slot, combat_text_cast_id, false)


static func _worldbloom_consume(caster: Unit, point: Vector3) -> void:
	for other in ArenaState.units_near(point, 7.0, false, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team != caster.team:
			continue
		var stacks := u.consume_rejuvenation()
		if stacks > 0:
			u.apply_heal(22.0 * float(stacks), caster, "worldbloom")
		if u.has_lifebloom_from(caster):
			u.consume_lifebloom(90.0, false)
			u.apply_damage_reduction(0.15, 3.0)


static func _tempest_bloom(caster: Unit) -> void:
	var hooks := caster.talent_hooks()
	if hooks == null:
		return
	hooks.tempest_bloom_left = CombatBalance.flat("skill.tempest_bloom.time")
	hooks.stormbond_cap = 4
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, caster.global_position, {"scale": 0.7, "lifetime": 0.9})


static func _eye_of_the_storm(caster: Unit, ab: AbilityDef, slot: int, recast: bool) -> void:
	var hooks := caster.talent_hooks()
	if hooks == null:
		return
	if recast:
		var cloud := StormCloudZone.for_caster(caster)
		if cloud == null:
			return
		if not hooks.storm_cloud_detached:
			cloud.detach()
			hooks.storm_cloud_detached = true
			caster.arm_skill_recast(slot, maxf(cloud.remaining(), 0.2))
			return
		if not hooks.storm_cloud_jumped:
			_jump_to_cloud(caster, cloud, ab)
			hooks.storm_cloud_jumped = true
		return
	var duration := ab.zone_duration if ab.zone_duration > 0.05 else CombatBalance.flat("skill.eye_storm.time")
	hooks.eye_storm_left = duration
	hooks.storm_cloud_detached = false
	hooks.storm_cloud_jumped = false
	var cloud := StormCloudZone.spawn(caster, ab)
	if cloud != null:
		hooks.storm_cloud_id = cloud.get_instance_id()
	if slot >= 0:
		caster.arm_skill_recast(slot, duration)
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, caster.global_position, {"scale": 0.75, "lifetime": 0.9})


static func _eye_of_tempest(caster: Unit, ab: AbilityDef, slot: int, recast: bool) -> void:
	var hooks := caster.talent_hooks()
	if hooks != null and not recast:
		hooks.tempest_bloom_left = 8.0
		hooks.stormbond_cap = 3
		hooks.pulse_ratio_bonus = 0.15
	_eye_of_the_storm(caster, ab, slot, recast)


static func _jump_to_cloud(caster: Unit, cloud: StormCloudZone, ab: AbilityDef) -> void:
	if caster.movement == null or cloud == null:
		return
	var max_range := ab.range if ab.range > 0.05 else CombatBalance.flat("skill.eye_storm.jump")
	var to: Vector3 = cloud.global_position - caster.global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.2:
		return
	if dist > max_range:
		return
	caster.movement.blink_to(to / dist, dist)


static func _reset_nature_wall_cd(caster: Unit) -> void:
	if caster == null:
		return
	for i in caster.abilities.size():
		var ab: AbilityDef = caster.abilities[i]
		if ab == null or ab.delivery != AbilityDef.Delivery.WALL:
			continue
		if not ab.has_element(AbilityDef.Element.NATURE):
			continue
		if i < caster.cooldown_left.size():
			caster.cooldown_left[i] = 0.0
