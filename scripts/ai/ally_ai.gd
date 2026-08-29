class_name AllyAI
extends Node

@export var role: String = "dps" ## tank, healer, dps
var hold_center: bool = false

var _think: float = 0.0

@onready var unit: Unit = get_parent()


func _ready() -> void:
	set_physics_process(false)
	# Enabled by Arena/GameSession when fight starts / AI on.


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled:
		return
	if unit.is_dead:
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
		"tank":
			_tank()
		"healer":
			_healer()
		_:
			_dps()


func _try_dodge() -> bool:
	if role == "tank":
		return false
	for t in ArenaState.telegraphs:
		if t == null or not is_instance_valid(t):
			continue
		if t.resolved:
			continue
		if t.requires_cover:
			if t.inbound_cover:
				if _in_radial_shadow():
					return true
				unit.controller.ai_move(_spread_inward_cover())
				return true
			if _has_cover_from(t.source):
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
		var remaining: float = beam.remaining_player_damage() if beam.has_method("remaining_player_damage") else 250.0
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
	return arena.cover_point_inward(pillars[idx % pillars.size()], unit.radius)


func _has_cover_from(threat: Unit) -> bool:
	if threat == null or not is_instance_valid(threat):
		return false
	var arena := ArenaState.arena as Arena
	if arena == null:
		return false
	return not arena.spell_has_los(threat.global_position, unit.global_position, [threat.get_rid(), unit.get_rid()])


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


func _tank() -> void:
	var boss := ArenaState.boss
	if boss == null or boss.is_dead:
		return
	var hold: Vector3
	if hold_center:
		hold = Vector3(0.0, 0.1, boss.radius + unit.radius + 0.55)
	else:
		var hold_dir := Vector3(0, 0, 1)
		if ArenaState.champion and not ArenaState.champion.is_dead:
			hold_dir = ArenaState.champion.global_position - boss.global_position
			hold_dir.y = 0.0
		if hold_dir.length_squared() < 0.01:
			hold_dir = Vector3(0, 0, 1)
		hold = boss.global_position + hold_dir.normalized() * (boss.radius + unit.radius + 1.05)
	var dist := unit.global_position.distance_to(hold)
	if dist > 0.55:
		unit.controller.ai_move(hold)
	else:
		unit.controller.ai_attack(boss)


func _healer() -> void:
	var needy := ArenaState.lowest_health_ally()
	if needy and needy.health / needy.max_health < 0.82 and unit.can_cast(1):
		unit.controller.ai_cast(1, needy.global_position, needy)
		return
	_dps()


func _dps() -> void:
	var boss := ArenaState.boss
	if boss == null or boss.is_dead:
		return
	if unit.can_cast(0) and unit.global_position.distance_to(boss.global_position) <= unit.abilities[0].range:
		unit.controller.ai_cast(0, boss.global_position, null)
		return
	if unit.can_cast(2) and unit.global_position.distance_to(boss.global_position) <= unit.abilities[2].range:
		unit.controller.ai_cast(2, boss.global_position, null)
		return
	unit.controller.ai_attack(boss)
