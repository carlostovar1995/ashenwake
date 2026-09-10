class_name AllyAI
extends Node

@export var role: String = "dps" ## tank, healer, dps
var hold_center: bool = false

## Mend used to top anyone below 97% every GCD. Colossus autos are 125 into ~500 HP
## DPS, so that erased incoming before the raid felt it. Heal when HP is actually missing.
const HEAL_EMERGENCY := 0.42
const HEAL_TANK := 0.68
const HEAL_ALLY := 0.62
const HEAL_GROUND := 0.72
const HEAL_NOVA := 0.58
const HEAL_NOVA_SPREAD := 0.70
const TANK_HOLD_STICK := 0.5
const TANK_MOVE_EPS := 0.55
const TANK_NO_POINT := Vector3(INF, INF, INF)

var _think: float = 0.0
var _tank_hold_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
var _tank_hold_locked: bool = false

@onready var unit: Unit = get_parent()


func _ready() -> void:
	set_physics_process(false)
	# Enabled by Arena/GameSession when fight starts / AI on.


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled:
		return
	if unit.is_dead:
		return
	var arena := ArenaState.arena as Arena
	if arena != null and GameSession.selected_boss_id == "dawnwarden" and not arena.is_dawn_engaged():
		return
	if role == "tank":
		if _tank_play_mechanics():
			return
		_think -= delta
		if _think > 0.0:
			return
		_think = 0.18 + randf() * 0.12
		_tank()
		return
	if _try_dodge():
		return
	if _try_beam_response():
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = 0.18 + randf() * 0.12
	match role:
		"healer":
			_healer()
		_:
			_dps()


func _try_dodge() -> bool:
	for t in ArenaState.telegraphs:
		if t == null or not is_instance_valid(t):
			continue
		if t.resolved:
			continue
		if t.inner_radius > 0.05:
			if t.contains_point(unit.global_position):
				unit.controller.ai_move(t.dodge_point(unit.global_position))
				return true
			continue
		if t.ability_id == "solar_collapse":
			if role == "tank":
				continue
			if SolarCollapseFx.covers_world(unit.global_position):
				return true
			unit.controller.ai_move(_spread_solar_cover())
			return true
		if role == "tank":
			continue
		if t.requires_cover:
			if t.inbound_cover:
				if _in_radial_shadow():
					return true
				unit.controller.ai_move(_spread_inward_cover())
				return true
			if _has_pillar_cover_from(t.source):
				return true
			unit.controller.ai_move(_spread_cover_point(t.source))
			return true
		if t.contains_point(unit.global_position):
			unit.controller.ai_move(t.dodge_point(unit.global_position))
			return true
		if t.shape == Telegraph.Shape.CIRCLE:
			var d := Vector2(unit.global_position.x - t.global_position.x, unit.global_position.z - t.global_position.z).length()
			if d < t.radius + 0.8 and role != "tank":
				unit.controller.ai_move(t.dodge_point(unit.global_position))
				return true
	return false


func _try_beam_response() -> bool:
	if role == "tank":
		return false
	for beam in ArenaState.beams:
		if beam == null or not is_instance_valid(beam):
			continue
		if beam.target != unit:
			continue
		var remaining: float = beam.remaining_player_damage() if beam.has_method("remaining_player_damage") else CombatBalance.flat("dawnwarden.judgment")
		if unit.health > remaining + 25.0:
			if _has_cover_from(ArenaState.boss):
				unit.controller.ai_move(_open_soak_point())
				return true
			return false
		var hide := _full_hp_cover_point(ArenaState.boss)
		if hide != unit.global_position:
			unit.controller.ai_move(hide)
			return true
	return false


func _in_radial_shadow() -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return false
	return arena.has_radial_shadow(unit.global_position, [unit.get_rid()])


func _spread_inward_cover() -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return unit.global_position
	var spots := arena.inward_cover_spots(unit.radius)
	if spots.is_empty():
		return unit.global_position
	var hiders: Array = []
	var tank := ArenaState.tank()
	for ally in ArenaState.living_allies():
		if ally == tank:
			continue
		hiders.append(ally)
	var idx := hiders.find(unit)
	if idx < 0:
		idx = 0
	return spots[idx % spots.size()]


func _has_cover_from(threat: Unit) -> bool:
	if threat == null or not is_instance_valid(threat):
		return false
	var arena := ArenaState.arena as Arena
	if arena == null:
		return false
	return not arena.spell_has_los(threat.global_position, unit.global_position, [threat.get_rid(), unit.get_rid()])


func _has_pillar_cover_from(threat: Unit) -> bool:
	if threat == null or not is_instance_valid(threat):
		return false
	var arena := ArenaState.arena as Arena
	if arena == null:
		return false
	return arena.los_cover(threat.global_position, unit.global_position, [threat.get_rid(), unit.get_rid()]) == Arena.LosCover.PILLAR


func _spread_cover_point(threat: Unit) -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return unit.global_position
	var pillars := arena.living_pillars()
	if pillars.is_empty():
		return unit.global_position
	var hiders: Array = []
	var tank := ArenaState.tank()
	for ally in ArenaState.living_allies():
		if ally == tank:
			continue
		hiders.append(ally)
	var idx := hiders.find(unit)
	if idx < 0:
		idx = 0
	pillars.sort_custom(func(a: ArenaPillar, b: ArenaPillar) -> bool:
		return atan2(a.global_position.x, a.global_position.z) < atan2(b.global_position.x, b.global_position.z)
	)
	var origin := threat.global_position if threat else Vector3.ZERO
	return arena.cover_point_behind(pillars[idx % pillars.size()], origin, unit.radius)


func _spread_solar_cover() -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return unit.global_position
	var pillars := arena.living_pillars()
	if pillars.is_empty():
		return unit.global_position
	var hiders: Array = []
	var tank := ArenaState.tank()
	for ally in ArenaState.living_allies():
		if ally == tank:
			continue
		hiders.append(ally)
	var idx := hiders.find(unit)
	if idx < 0:
		idx = 0
	pillars.sort_custom(func(a: ArenaPillar, b: ArenaPillar) -> bool:
		return atan2(a.global_position.x, a.global_position.z) < atan2(b.global_position.x, b.global_position.z)
	)
	var dest := SolarCollapseFx.cover_point_for_pillar(pillars[idx % pillars.size()], unit.radius)
	if dest == Vector3.ZERO:
		return unit.global_position
	return dest


func _full_hp_cover_point(threat: Unit) -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return unit.global_position
	var origin := threat.global_position if threat else Vector3.ZERO
	var best := unit.global_position
	var best_d := INF
	for pillar in arena.living_pillars():
		if not pillar.is_full():
			continue
		var dest := arena.cover_point_behind(pillar, origin, unit.radius)
		var d := Vector2(unit.global_position.x - dest.x, unit.global_position.z - dest.z).length()
		if d < best_d:
			best_d = d
			best = dest
	return best


func _open_soak_point() -> Vector3:
	var flat := Vector2(unit.global_position.x, unit.global_position.z)
	if flat.length() < 8.0:
		return unit.global_position
	flat = flat.normalized() * 8.0
	return Vector3(flat.x, 0.1, flat.y)


func _tank_play_mechanics() -> bool:
	# Lethal and facing-sensitive mechanics run every physics frame so a 0.18s GCD
	# think cannot leave the tank in Solar Collapse or facing Searing Cleave through the raid.
	var boss := ArenaState.boss
	if boss == null or boss.is_dead:
		return false
	_tank_refresh_hold_dir(boss)
	var dest := _tank_survive_point(boss)
	var moving := dest != TANK_NO_POINT and unit.global_position.distance_to(dest) > TANK_MOVE_EPS
	if dest != TANK_NO_POINT:
		if moving:
			unit.controller.ai_move(dest)
		else:
			_tank_try_ironhide()
			_tank_hold_or_attack(boss, _tank_telegraph("solar_collapse") != null)
		return true
	if _tank_cleave_incoming():
		var hold := _tank_hold_point(boss)
		if unit.global_position.distance_to(hold) > 0.7:
			unit.controller.ai_move(hold)
		else:
			_tank_try_ironhide()
			_tank_hold_or_attack(boss, false)
		return true
	return false


func _tank_hold_or_attack(boss: Unit, rooted: bool) -> void:
	if unit.controller.is_busy():
		return
	if unit.in_range_of(boss, 0.5) and unit.movement.has_line_of_sight(boss):
		unit.controller.ai_attack(boss)
		return
	if rooted:
		unit.controller.ai_stop()


func _tank() -> void:
	if unit.controller.is_busy():
		return
	var boss := ArenaState.boss
	if boss == null or boss.is_dead:
		return
	if _tank_try_ironhide():
		return
	if _tank_taunt(boss):
		return
	if _tank_aura():
		return
	if _tank_sanctuary():
		return
	if _tank_pull_adds(boss):
		return
	if _tank_wall(boss):
		return
	if _tank_dump(boss):
		return
	var hold := _tank_hold_point(boss)
	if unit.global_position.distance_to(hold) > TANK_MOVE_EPS:
		unit.controller.ai_move(hold)
	else:
		unit.controller.ai_attack(boss)


func _tank_refresh_hold_dir(boss: Unit) -> void:
	if hold_center:
		_tank_hold_dir = Vector3(0.0, 0.0, 1.0)
		_tank_hold_locked = true
		return
	if _tank_cleave_incoming() and _tank_hold_locked:
		return
	var raid := _raid_centroid()
	var away := boss.global_position - raid
	away.y = 0.0
	if away.length_squared() < 0.25:
		away = Vector3(boss.global_position.x, 0.0, boss.global_position.z)
		away.y = 0.0
	if away.length_squared() < 0.25:
		away = Vector3(0.0, 0.0, 1.0)
	else:
		away = away.normalized()
	if _tank_hold_locked and _tank_hold_dir.dot(away) > TANK_HOLD_STICK:
		return
	_tank_hold_dir = away
	_tank_hold_locked = true


func _raid_centroid() -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for ally in ArenaState.living_allies():
		if ally == unit:
			continue
		sum += ally.global_position
		n += 1
	if n <= 0:
		return Vector3.ZERO
	return sum / float(n)


func _tank_hold_point(boss: Unit) -> Vector3:
	_tank_refresh_hold_dir(boss)
	if hold_center:
		return Vector3(0.0, 0.1, boss.radius + unit.radius + 0.55)
	var dest: Vector3 = boss.global_position + _tank_hold_dir * (boss.radius + unit.radius + 1.05)
	dest.y = 0.1
	var arena := ArenaState.arena as Arena
	if arena == null:
		return dest
	dest = arena.clamp_movement_point(dest, unit.radius)
	return dest


func _tank_survive_point(boss: Unit) -> Vector3:
	if _tank_telegraph("solar_collapse") != null:
		return _tank_cover_point(boss)
	var corona := _tank_telegraph("solar_corona")
	if corona != null:
		var inner := corona.inner_radius if corona.inner_radius > 0.05 else CombatBalance.flat("dawnwarden.corona.inner")
		var origin := corona.global_position
		var d := Vector2(unit.global_position.x - origin.x, unit.global_position.z - origin.z).length()
		if d > inner - 0.55 or corona.contains_point(unit.global_position):
			return _tank_corona_point(corona, boss)
	for t in ArenaState.telegraphs:
		if t == null or not is_instance_valid(t) or t.resolved:
			continue
		if t.shape == Telegraph.Shape.CONE or t.ability_id == "cone_cleave":
			continue
		if t.ability_id == "solar_collapse" or t.ability_id == "solar_corona":
			continue
		if t.contains_point(unit.global_position):
			return _tank_avoid_point(t, boss)
	return _tank_beam_sidestep(boss)


func _tank_cover_point(boss: Unit) -> Vector3:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return unit.global_position
	var threat := boss.global_position
	var best := unit.global_position
	var best_score := -INF
	for pillar in arena.living_pillars():
		var dest := SolarCollapseFx.cover_point_for_pillar(pillar, unit.radius)
		if dest == Vector3.ZERO:
			dest = arena.cover_point_behind(pillar, threat, unit.radius)
		var from_boss := dest - threat
		from_boss.y = 0.0
		var side := 0.0
		if from_boss.length_squared() > 0.01:
			side = from_boss.normalized().dot(_tank_hold_dir)
		var d := Vector2(unit.global_position.x - dest.x, unit.global_position.z - dest.z).length()
		var score := side * 8.0 - d * 0.08
		if score > best_score:
			best_score = score
			best = dest
	return best


func _tank_corona_point(corona: Telegraph, boss: Unit) -> Vector3:
	var inner := corona.inner_radius if corona.inner_radius > 0.05 else CombatBalance.flat("dawnwarden.corona.inner")
	var origin := corona.global_position
	var dest := _tank_hold_point(boss)
	var flat := Vector2(dest.x - origin.x, dest.z - origin.z)
	var max_r := maxf(inner - 0.7, inner * 0.55)
	if flat.length() > max_r:
		if flat.length_squared() < 0.01:
			flat = Vector2(_tank_hold_dir.x, _tank_hold_dir.z)
		flat = flat.normalized() * (inner * 0.62)
		dest = Vector3(origin.x + flat.x, 0.1, origin.z + flat.y)
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.clamp_movement_point(dest, unit.radius)
	return dest


func _tank_avoid_point(t: Telegraph, boss: Unit) -> Vector3:
	var dodge := t.dodge_point(unit.global_position)
	if t.shape == Telegraph.Shape.CIRCLE:
		var hold_side: Vector3 = t.global_position + _tank_hold_dir * (t.radius + 2.1)
		hold_side.y = 0.1
		if not t.contains_point(hold_side):
			dodge = hold_side
	if dodge.distance_to(boss.global_position) > boss.radius + unit.radius + 4.5:
		var toward := dodge - boss.global_position
		toward.y = 0.0
		if toward.length_squared() < 0.01:
			toward = _tank_hold_dir
		dodge = boss.global_position + toward.normalized() * (boss.radius + unit.radius + 1.2)
		dodge.y = 0.1
	var arena := ArenaState.arena as Arena
	if arena:
		return arena.clamp_movement_point(dodge, unit.radius)
	return dodge


func _tank_beam_sidestep(boss: Unit) -> Vector3:
	for beam in ArenaState.beams:
		if beam == null or not is_instance_valid(beam):
			continue
		var marked: Unit = beam.target
		if marked == null or not is_instance_valid(marked) or marked == unit:
			continue
		var src: Unit = beam.source if beam.source != null else boss
		if src == null or not is_instance_valid(src):
			continue
		var a := Vector2(src.global_position.x, src.global_position.z)
		var b := Vector2(marked.global_position.x, marked.global_position.z)
		var p := Vector2(unit.global_position.x, unit.global_position.z)
		var ab := b - a
		var ab_len_sq := ab.length_squared()
		if ab_len_sq < 0.16:
			continue
		var u := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
		var closest := a + ab * u
		if (p - closest).length() > 1.2:
			continue
		var perp := Vector2(-ab.y, ab.x)
		if perp.length_squared() < 0.01:
			continue
		perp = perp.normalized()
		var hold2 := Vector2(_tank_hold_dir.x, _tank_hold_dir.z)
		if hold2.dot(perp) < 0.0:
			perp = -perp
		var dest := Vector3(p.x + perp.x * 2.4, 0.1, p.y + perp.y * 2.4)
		var reach := boss.radius + unit.radius + 1.2
		var from_boss := dest - boss.global_position
		from_boss.y = 0.0
		if from_boss.length() > reach + 1.8:
			if from_boss.length_squared() < 0.01:
				from_boss = _tank_hold_dir
			dest = boss.global_position + from_boss.normalized() * reach
			dest.y = 0.1
		var arena := ArenaState.arena as Arena
		if arena:
			return arena.clamp_movement_point(dest, unit.radius)
		return dest
	return TANK_NO_POINT


func _tank_telegraph(ability_id: String) -> Telegraph:
	for t in ArenaState.telegraphs:
		if t == null or not is_instance_valid(t) or t.resolved:
			continue
		if t.ability_id == ability_id:
			return t
	return null


func _tank_cleave_incoming() -> bool:
	if _tank_telegraph("cone_cleave") != null:
		return true
	var brain := _boss_brain()
	if brain == null:
		return false
	return brain.ability_name == "Searing Cleave" or brain.ability_name == "Cone Cleave"


func _boss_brain() -> BossAI:
	var boss := ArenaState.boss
	if boss == null or not is_instance_valid(boss):
		return null
	for child in boss.get_children():
		if child is BossAI:
			return child as BossAI
	return null


func _tank_big_mechanic() -> bool:
	return _tank_telegraph("solar_collapse") != null or _tank_telegraph("solar_corona") != null or _tank_cleave_incoming()


func _tank_try_ironhide() -> bool:
	var idx := _slot_skill("ironhide")
	if idx < 0 or not unit.can_cast(idx) or unit.controller.is_busy():
		return false
	var hurt := unit.health <= unit.max_health * 0.55
	if not hurt and not _tank_cleave_incoming():
		return false
	unit.controller.ai_cast(idx, unit.global_position, unit)
	return true


func _tank_taunt(boss: Unit) -> bool:
	if _tank_big_mechanic():
		return false
	var idx := _slot_delivery(AbilityDef.Delivery.TARGET)
	if idx < 0 or not unit.can_cast(idx):
		return false
	var mark := _loose_mobile_add(boss)
	if mark == null:
		if ThreatTable.holds(boss, unit):
			return false
		mark = boss
	unit.controller.ai_cast(idx, mark.global_position, mark)
	return true


func _tank_aura() -> bool:
	if _tank_telegraph("solar_collapse") != null:
		return false
	var idx := _slot_delivery(AbilityDef.Delivery.AURA)
	if idx < 0 or unit.has_aura(idx) or not unit.can_cast(idx):
		return false
	unit.controller.ai_cast(idx, unit.global_position, unit)
	return true


func _tank_dump(boss: Unit) -> bool:
	if _tank_big_mechanic():
		return false
	if not ThreatTable.holds(boss, unit):
		return false
	var idx := _slot_delivery(AbilityDef.Delivery.NOVA)
	if idx < 0:
		idx = _slot_delivery(AbilityDef.Delivery.AOE_EXPLOSION)
	if idx < 0 or not unit.can_cast(idx):
		return false
	if not unit.in_range_of(boss, 2.0):
		return false
	unit.controller.ai_cast(idx, boss.global_position, boss)
	return true


func _tank_sanctuary() -> bool:
	if _tank_telegraph("solar_collapse") != null:
		return false
	var idx := _slot_skill("sanctuary")
	if idx < 0 or not unit.can_cast(idx):
		return false
	if not _raid_needs_sanctuary() and unit.health > unit.max_health * 0.70:
		return false
	unit.controller.ai_cast(idx, unit.global_position, null)
	return true


func _tank_pull_adds(boss: Unit) -> bool:
	if _tank_big_mechanic():
		return false
	var idx := _slot_wind_ground()
	if idx < 0 or not unit.can_cast(idx):
		return false
	var pack := _add_pack_point(boss)
	if pack == Vector3.ZERO:
		return false
	var ab: AbilityDef = unit.abilities[idx]
	if ab != null and unit.global_position.distance_to(pack) > ab.range - 0.4:
		return false
	unit.controller.ai_cast(idx, pack, null)
	return true


func _tank_wall(boss: Unit) -> bool:
	if _tank_big_mechanic():
		return false
	if not ThreatTable.holds(boss, unit):
		return false
	if _add_pack_point(boss) == Vector3.ZERO:
		return false
	var idx := _slot_delivery(AbilityDef.Delivery.WALL)
	if idx < 0 or not unit.can_cast(idx):
		return false
	if not unit.in_range_of(boss, 0.8):
		return false
	var away := _tank_hold_point(boss) - boss.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	var point := unit.global_position + away.normalized() * 1.4
	unit.controller.ai_cast(idx, point, null)
	return true


func _tank_stationary_add(u: Unit) -> bool:
	if u == null:
		return true
	if u.is_in_group("sun_totem"):
		return true
	return u.move_speed <= 0.15


func _loose_mobile_add(boss: Unit) -> Unit:
	for other in ArenaState.living_enemies():
		var u := other as Unit
		if u == null or u == boss or u.is_dead:
			continue
		if _tank_stationary_add(u):
			continue
		if ThreatTable.holds(u, unit):
			continue
		return u
	return null


func _add_pack_point(boss: Unit) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for other in ArenaState.living_enemies():
		var u := other as Unit
		if u == null or u == boss or u.is_dead:
			continue
		if _tank_stationary_add(u):
			continue
		sum += u.global_position
		n += 1
	if n <= 0:
		return Vector3.ZERO
	sum /= float(n)
	sum.y = 0.1
	return sum


func _raid_needs_sanctuary() -> bool:
	var hurt := 0
	for ally in ArenaState.living_allies():
		if ally.health <= ally.max_health * 0.72:
			hurt += 1
	if hurt >= 2:
		return true
	for t in ArenaState.telegraphs:
		if t == null or not is_instance_valid(t) or t.resolved:
			continue
		if t.shape == Telegraph.Shape.CIRCLE and t.radius >= 3.5:
			return true
	return false


func _slot_skill(skill_id: String) -> int:
	for i in unit.abilities.size():
		if unit.abilities[i] != null and unit.abilities[i].skill_id == skill_id:
			return i
	return -1


func _slot_delivery(delivery: int) -> int:
	for i in unit.abilities.size():
		var ab: AbilityDef = unit.abilities[i]
		if ab != null and ab.skill_id.is_empty() and ab.delivery == delivery:
			return i
	return -1


func _slot_wind_ground() -> int:
	for i in unit.abilities.size():
		var ab: AbilityDef = unit.abilities[i]
		if ab == null or not ab.skill_id.is_empty():
			continue
		if ab.delivery == AbilityDef.Delivery.GROUND_AOE and ab.has_element(AbilityDef.Element.WIND):
			return i
	return -1


func _healer() -> void:
	if unit.controller.is_busy():
		return
	if _healer_aura():
		return
	var needy := ArenaState.lowest_health_ally()
	var lowest := _ally_ratio(needy)
	if lowest < HEAL_EMERGENCY and _healer_target(needy):
		return
	if (_hurt_count(HEAL_NOVA) >= 2 or _hurt_count(HEAL_NOVA_SPREAD) >= 3) and _healer_nova():
		return
	if _hurt_count(HEAL_GROUND) >= 2 and _healer_ground():
		return
	var st := _healer_st_target()
	if st != null and _healer_target(st):
		return
	_healer_follow()


func _healer_aura() -> bool:
	var idx := _slot_delivery(AbilityDef.Delivery.AURA)
	if idx < 0 or unit.has_aura(idx) or not unit.can_cast(idx):
		return false
	unit.controller.ai_cast(idx, unit.global_position, unit)
	return true


func _healer_target(needy: Unit) -> bool:
	if needy == null or needy.is_dead:
		return false
	var idx := _slot_delivery(AbilityDef.Delivery.TARGET)
	if idx < 0:
		return false
	var ab: AbilityDef = unit.abilities[idx]
	if unit.global_position.distance_to(needy.global_position) > ab.range - 0.4:
		unit.controller.ai_move(needy.global_position)
		return true
	if not unit.can_cast(idx):
		return false
	unit.controller.ai_cast(idx, needy.global_position, needy)
	return true


func _healer_ground() -> bool:
	var idx := _slot_delivery(AbilityDef.Delivery.GROUND_AOE)
	if idx < 0 or not unit.can_cast(idx):
		return false
	var tank := ArenaState.tank()
	var dest := tank.global_position if tank != null else unit.global_position
	unit.controller.ai_cast(idx, dest, null)
	return true


func _healer_nova() -> bool:
	var idx := _slot_delivery(AbilityDef.Delivery.NOVA)
	if idx < 0 or not unit.can_cast(idx):
		return false
	unit.controller.ai_cast(idx, unit.global_position, null)
	return true


func _healer_st_target() -> Unit:
	var best: Unit = null
	var best_ratio := 1.0
	for ally in ArenaState.living_allies():
		var u := ally as Unit
		if u == null or u.is_dead:
			continue
		var ratio := _ally_ratio(u)
		var gate := HEAL_TANK if u == ArenaState.tank() else HEAL_ALLY
		if ratio >= gate:
			continue
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


func _healer_follow() -> void:
	var tank := ArenaState.tank()
	var follow: Unit = tank if tank != null else ArenaState.champion
	if follow == null or follow.is_dead:
		return
	var dest := follow.global_position
	var boss := ArenaState.boss
	if tank != null and boss != null and not boss.is_dead:
		var back := tank.global_position - boss.global_position
		back.y = 0.0
		if back.length_squared() < 0.01:
			back = Vector3(0, 0, 1)
		dest = tank.global_position + back.normalized() * 4.2
	if unit.global_position.distance_to(dest) > 1.15:
		unit.controller.ai_move(dest)


func _ally_ratio(ally: Unit) -> float:
	if ally == null or ally.is_dead:
		return 1.0
	return ally.health / maxf(ally.max_health, 1.0)


func _hurt_count(threshold: float) -> int:
	var n := 0
	for ally in ArenaState.living_allies():
		var u := ally as Unit
		if u != null and _ally_ratio(u) < threshold:
			n += 1
	return n


func _dps() -> void:
	var mark := ArenaState.boss
	if mark == null or mark.is_dead:
		return
	var dump := _dps_dump_slot(mark)
	if dump >= 0:
		unit.controller.ai_cast(dump, mark.global_position, mark)
		return
	unit.controller.ai_attack(mark)


func _dps_dump_slot(mark: Unit) -> int:
	# Default Hex/Vex bolts are weaker than the 400 DPS auto. Only spend a GCD
	# when the spell actually beats a swing.
	for i in [0, 2]:
		if i >= unit.abilities.size():
			continue
		var ab: AbilityDef = unit.abilities[i]
		if ab == null or ab.damage < unit.attack_damage * 0.85:
			continue
		if not unit.can_cast(i):
			continue
		if unit.global_position.distance_to(mark.global_position) > ab.range:
			continue
		return i
	return -1
