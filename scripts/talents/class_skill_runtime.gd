class_name ClassSkillRuntime
extends Object


static func try_deliver(caster: Unit, ab: AbilityDef, point: Vector3, target: Unit, _slot: int, combat_text_cast_id: int, recast: bool) -> bool:
	if caster == null or ab == null or ab.skill_id.is_empty():
		return false
	match ab.skill_id:
		"combustion":
			_combustion(caster, ab, target, combat_text_cast_id)
			return true
		"pyre":
			_pyre(caster, ab, target, combat_text_cast_id)
			return true
		"crucible":
			_crucible(caster, ab, point, combat_text_cast_id)
			return true
		"ashen_wake":
			_ashen_wake(caster, ab, point, combat_text_cast_id, recast)
			return true
		"ashen_crucible":
			_ashen_crucible(caster, ab, point, combat_text_cast_id, recast)
			return true
		"ironhide":
			_ironhide(caster)
			return true
		"rampage":
			_rampage(caster)
			return true
		"iron_rampage":
			_iron_rampage(caster)
			return true
		"sanctuary":
			_sanctuary(caster, ab, point, combat_text_cast_id)
			return true
		"hearthguard":
			_hearthguard(caster, ab, point, combat_text_cast_id)
			return true
		"intercede":
			_intercede(caster, ab, target)
			return true
		_:
			return StormDruidSkills.try_deliver(caster, ab, point, target, _slot, combat_text_cast_id, recast)


static func _pyre(caster: Unit, ab: AbilityDef, target: Unit, combat_text_cast_id: int) -> void:
	if target == null or target.is_dead or target.team == caster.team:
		return
	var leftover := target.consume_burn()
	var consumed := leftover > 0.05
	var hit := leftover * 1.5
	if consumed:
		hit += 400.0
	else:
		hit = 400.0
	target.take_damage(hit, caster, _DamageNumber.tint_for("fire"), "fire", "pyre", consumed, true, combat_text_cast_id, false)
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, target.global_position, {"scale": 0.75, "lifetime": 1.1})
	TalentCombat.consume_singe_on_pyre(caster, target)
	if leftover <= 0.05:
		return
	var splash := leftover * TalentCombat.pyre_splash_ratio(caster, target)
	var radius := ab.aoe_radius if ab.aoe_radius > 0.05 else 2.8
	for other in ArenaState.units_near(target.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u == target or u.is_dead or u.team == caster.team:
			continue
		u.take_damage(splash, caster, _DamageNumber.tint_for("fire"), "fire", "pyre", false, true, combat_text_cast_id, true)


static func _ashen_crucible(caster: Unit, ab: AbilityDef, point: Vector3, combat_text_cast_id: int, recast: bool) -> void:
	_ashen_wake(caster, ab, point, combat_text_cast_id, recast)
	var hooks := caster.talent_hooks()
	if recast:
		var origin := caster.global_position
		for other in ArenaState.units_near(origin, 10.0, false, true, true):
			var u := other as Unit
			if u == null or u.is_dead or u.team == caster.team:
				continue
			u.take_damage(30.0, caster, _DamageNumber.tint_for("fire"), "fire", "ashen_crucible", false, true, combat_text_cast_id, true)
			u.take_damage(30.0, caster, _DamageNumber.tint_for("ice"), "ice", "ashen_crucible", false, true, combat_text_cast_id, true)
			u.apply_rooted(1.0)
		if hooks != null:
			hooks.kiln_rank = maxi(hooks.kiln_rank, 2)
		return
	if hooks != null:
		hooks.kiln_rank = maxi(hooks.kiln_rank, 2)


static func _iron_rampage(caster: Unit) -> void:
	var dur := 7.0
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.ironhide_left = dur
		hooks.rampage_left = dur
		hooks.claim_threat = maxf(hooks.claim_threat, 0.40)
	caster.apply_damage_reduction(0.40, dur)
	caster.apply_haste(0.10, dur)
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, caster.global_position, {"scale": 0.7, "lifetime": 0.9})


static func _hearthguard(caster: Unit, ab: AbilityDef, point: Vector3, combat_text_cast_id: int) -> void:
	ab.zone_duration = 5.0
	_sanctuary(caster, ab, point, combat_text_cast_id)
	var lowest: Unit = null
	var lowest_hp := 999999.0
	for other in ArenaState.units_near(point, 4.5, false, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team != caster.team or u == caster:
			continue
		if u.health < lowest_hp:
			lowest_hp = u.health
			lowest = u
	if lowest == null:
		return
	lowest.apply_shield(200.0, 6.0, caster)
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.intercede_left = 4.0
		hooks.intercede_target_id = lowest.get_instance_id()
		hooks.intercede_share = 0.30


static func _combustion(caster: Unit, ab: AbilityDef, target: Unit, combat_text_cast_id: int) -> void:
	if target == null or target.is_dead or target.team == caster.team:
		return
	var leftover := target.consume_burn()
	if leftover <= 0.05:
		return
	var hit := leftover * CombatBalance.pct("skill.combustion.consume")
	target.take_damage(hit, caster, _DamageNumber.tint_for("fire"), "fire", "combustion", false, true, combat_text_cast_id, false)
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, target.global_position, {"scale": 0.7, "lifetime": 1.2})
	var splash := leftover * CombatBalance.pct("skill.combustion.splash")
	var radius := ab.aoe_radius if ab.aoe_radius > 0.05 else CombatBalance.flat("skill.combustion.radius")
	for other in ArenaState.units_near(target.global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u == target or u.is_dead or u.team == caster.team:
			continue
		u.take_damage(splash, caster, _DamageNumber.tint_for("fire"), "fire", "combustion", false, true, combat_text_cast_id, true)


static func _crucible(caster: Unit, ab: AbilityDef, point: Vector3, combat_text_cast_id: int) -> void:
	var zone := CrucibleZone.new()
	zone.setup(caster, point, ab, combat_text_cast_id)
	var parent: Node = ArenaState.arena if ArenaState.arena else caster.get_tree().root
	parent.add_child(zone)


static func _ashen_wake(caster: Unit, ab: AbilityDef, point: Vector3, combat_text_cast_id: int, recast: bool) -> void:
	var origin := caster.global_position
	var to := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	var max_range := ab.skillshot_reach()
	var dist := to.length()
	var dir: Vector3
	if dist < 0.4:
		dir = caster.facing_dir()
		dist = 0.4
	else:
		dir = to / dist
		dist = minf(dist, max_range)
	var dest := origin + dir * dist
	if caster.movement != null:
		dest = caster.movement.start_dodge(dir, dist, clampf(dist / 28.0, 0.12, 0.36))
	var half_w := ab.skillshot_width * 0.5 if ab.skillshot_width > 0.05 else 1.3
	if recast:
		var payload := caster.ashen_absorbed_afflict()
		for u in _units_along_dash(caster, origin, dest, half_w):
			u.apply_burn_from_afflict_stacks(caster, payload)
		caster.clear_ashen_absorbed()
	else:
		caster.clear_ashen_absorbed()
		for u in _units_along_dash(caster, origin, dest, half_w):
			var stacks := u.consume_afflict_stacks()
			if stacks <= 0:
				continue
			caster.absorb_ashen_afflict(stacks)
			u.take_damage(
				float(stacks),
				caster,
				_DamageNumber.tint_for("shadow"),
				"shadow",
				"ashen_wake",
				false,
				true,
				combat_text_cast_id,
				false
			)
	AbilityFx.play_at(
		AbilityFx.FIRE_CAST if recast else AbilityFx.GROUND_EXPLOSION,
		dest + Vector3(0, 0.4, 0),
		{"scale": 0.55 if recast else 0.7, "lifetime": 0.7}
	)


static func _units_along_dash(caster: Unit, origin: Vector3, dest: Vector3, half_w: float) -> Array[Unit]:
	var out: Array[Unit] = []
	var span := dest - origin
	span.y = 0.0
	var length := span.length()
	var center := origin.lerp(dest, 0.5)
	var query_r := length * 0.5 + half_w
	for other in ArenaState.units_near(center, query_r, false, true, true):
		var u := other as Unit
		if u == null or u == caster or u.is_dead or u.team == caster.team:
			continue
		if _dist_to_xz_segment(u.global_position, origin, dest) <= half_w + u.radius:
			out.append(u)
	return out


static func _dist_to_xz_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len_sq := ab.length_squared()
	var t := 0.0 if len_sq < 0.0001 else clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return Vector2(p.x, p.z).distance_to(Vector2(a.x, a.z) + ab * t)


static func _ironhide(caster: Unit) -> void:
	var dur := CombatBalance.flat("skill.ironhide.time")
	var dr := CombatBalance.pct("skill.ironhide.dr")
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.ironhide_left = dur
	caster.apply_damage_reduction(dr, dur)
	AbilityFx.play_at(AbilityFx.FIRE_CAST, caster.global_position + Vector3(0, 1.0, 0), {"scale": 0.7, "lifetime": 0.8})


static func _rampage(caster: Unit) -> void:
	var dur := CombatBalance.flat("skill.rampage.time")
	var dr := CombatBalance.pct("skill.rampage.dr")
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.rampage_left = dur
	caster.apply_damage_reduction(dr, dur)
	caster.apply_haste(0.15, dur)
	AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, caster.global_position, {"scale": 0.65, "lifetime": 0.9})


static func _sanctuary(caster: Unit, ab: AbilityDef, point: Vector3, combat_text_cast_id: int) -> void:
	var dur := ab.zone_duration if ab != null and ab.zone_duration > 0.05 else CombatBalance.flat("skill.sanctuary.time")
	var hooks := caster.talent_hooks()
	if hooks != null:
		hooks.sanctuary_left = dur
	caster.apply_damage_reduction(CombatBalance.pct("skill.sanctuary.dr"), dur)
	var zone: SanctuaryZone = SanctuaryZone.spawn(
		caster,
		point,
		ab.aoe_radius if ab.aoe_radius > 0.05 else 4.5,
		dur,
		1.0,
		0.0,
		CombatBalance.flat("skill.sanctuary.shield"),
		6.0,
		"sanctuary",
		AbilityDef.Element.HOLY,
		PackedInt32Array(),
		combat_text_cast_id
	)
	if zone != null:
		zone.ally_dr = 0.0
		zone.caster_dr = 0.0
		zone.threat_pulse = CombatBalance.flat("skill.sanctuary.threat")


static func _intercede(caster: Unit, ab: AbilityDef, target: Unit) -> void:
	var shield := CombatBalance.flat("skill.intercede.shield")
	caster.apply_shield(shield, 6.0, caster)
	if target == null or target == caster or target.team != caster.team:
		return
	var hooks := caster.talent_hooks()
	if hooks == null:
		return
	hooks.intercede_left = 4.0
	hooks.intercede_target_id = target.get_instance_id()


const _DamageNumber := preload("res://scripts/visual/damage_number.gd")


class CrucibleZone:
	extends Node3D

	var source: Unit
	var radius: float = 3.6
	var duration: float = 4.0
	var tick_interval: float = 0.5
	var combat_text_cast_id: int = -1
	var _elapsed: float = 0.0
	var _tick_acc: float = 0.0
	var _fire_next: bool = true
	var _tick_damage: float = 28.0


	func setup(caster: Unit, point: Vector3, ab: AbilityDef, text_id: int) -> void:
		source = caster
		radius = ab.aoe_radius
		duration = ab.zone_duration
		tick_interval = maxf(ab.tick_interval, 0.2)
		combat_text_cast_id = text_id
		_tick_damage = maxf(ab.tick_damage, 28.0)
		name = "CrucibleZone"
		position = Vector3(point.x, 0.05, point.z)


	func _ready() -> void:
		set_physics_process(true)
		AbilityFx.play_at(AbilityFx.FIRE_AREA, global_position, {"scale": 0.7, "lifetime": duration})


	func _physics_process(delta: float) -> void:
		if source == null or not is_instance_valid(source) or source.is_dead:
			queue_free()
			return
		_elapsed += delta
		_tick_acc += delta
		while _tick_acc >= tick_interval:
			_tick_acc -= tick_interval
			_pulse()
		if _elapsed >= duration:
			_finish()
			queue_free()


	func _pulse() -> void:
		var element := AbilityDef.Element.FIRE if _fire_next else AbilityDef.Element.ICE
		_fire_next = not _fire_next
		for other in ArenaState.units_near(global_position, radius, false, true, true):
			var u := other as Unit
			if u == null or u.is_dead or u.team == source.team:
				continue
			u.receive_ability_hit(
				source,
				element,
				_tick_damage,
				0.0,
				PackedInt32Array(),
				true,
				true,
				true,
				-1,
				0,
				"crucible",
				combat_text_cast_id,
				true
			)


	func _finish() -> void:
		for other in ArenaState.units_near(global_position, radius, false, true, true):
			var u := other as Unit
			if u == null or u.is_dead or u.team == source.team:
				continue
			if not (u.has_burn() and u.has_chill()):
				continue
			u.take_damage(_tick_damage * 2.0, source, Color(0.85, 0.78, 0.72), "fire", "crucible", false, true, combat_text_cast_id, false)
			u.apply_slow(1.0, 1.5)
