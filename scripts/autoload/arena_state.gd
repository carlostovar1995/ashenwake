extends Node

signal fight_won
signal fight_lost
signal unit_registered(unit)
signal telegraph_spawned(telegraph)
signal telegraph_cleared(telegraph)

var units: Array = []
var allies: Array = []
var enemies: Array = []
var champion: Unit = null
var boss: Unit = null
var arena: Node3D = null

var outcome: String = "" ## "", "win", "lose"
var telegraphs: Array = []
var beams: Array = []

var shrink_active: bool = false
var safe_radius: float = 26.0
var arena_radius: float = 28.0
var shrink_speed: float = 1.15
var shrink_min: float = 10.0
var shrink_dps: float = 18.0


func reset() -> void:
	units.clear()
	allies.clear()
	enemies.clear()
	champion = null
	boss = null
	arena = null
	outcome = ""
	telegraphs.clear()
	beams.clear()
	shrink_active = false
	safe_radius = 26.0


func register_arena(p_arena: Node3D) -> void:
	arena = p_arena


func register_unit(unit: Unit) -> void:
	if units.has(unit):
		return
	units.append(unit)
	if unit.is_boss:
		boss = unit
		enemies.append(unit)
	elif unit.team == 0:
		if unit.is_champion:
			champion = unit
		else:
			allies.append(unit)
	else:
		enemies.append(unit)
	if not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)
	unit_registered.emit(unit)


func living_allies() -> Array:
	var result: Array = []
	for u in units:
		if u and is_instance_valid(u) and u.team == 0 and not u.is_dead:
			result.append(u)
	return result


func living_enemies() -> Array:
	var result: Array = []
	for u in units:
		if u and is_instance_valid(u) and u.team != 0 and not u.is_dead:
			result.append(u)
	return result


func nearest_enemy(from: Vector3, team: int) -> Unit:
	var best: Unit = null
	var best_d := INF
	for u in units:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == team:
			continue
		var d := from.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func tank() -> Unit:
	for ally in allies:
		if ally == null or not is_instance_valid(ally) or ally.is_dead:
			continue
		var ai := ally.get_node_or_null("AllyAI") as AllyAI
		if ai and ai.role == "tank":
			return ally
		if ally.immortal:
			return ally
	return null


func lowest_health_ally(except: Unit = null) -> Unit:
	var best: Unit = null
	var best_ratio := 2.0
	for u in living_allies():
		if u == except:
			continue
		var ratio: float = u.health / maxf(u.max_health, 1.0)
		if ratio < best_ratio:
			best_ratio = ratio
			best = u
	return best


func add_telegraph(t: Node) -> void:
	telegraphs.append(t)
	telegraph_spawned.emit(t)


func remove_telegraph(t: Node) -> void:
	telegraphs.erase(t)
	telegraph_cleared.emit(t)


func add_beam(beam: Node) -> void:
	beams.append(beam)


func remove_beam(beam: Node) -> void:
	beams.erase(beam)


func interrupt_casts_from(source: Unit) -> bool:
	if source == null:
		return false
	var did := false
	for t in telegraphs.duplicate():
		if t is Telegraph and (t as Telegraph).source == source:
			if (t as Telegraph).interrupt_cast():
				did = true
	for b in beams.duplicate():
		if b != null and is_instance_valid(b) and b.get("source") == source and b.has_method("interrupt_cast"):
			if bool(b.call("interrupt_cast")):
				did = true
	return did


func start_shrink() -> void:
	shrink_active = true


func _on_unit_died(unit: Unit) -> void:
	if outcome != "":
		return
	if unit == champion:
		outcome = "lose"
		fight_lost.emit()
		return
	if unit == boss and not GameSession.training_mode:
		outcome = "win"
		fight_won.emit()


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started:
		return
	if not shrink_active:
		return
	safe_radius = maxf(shrink_min, safe_radius - shrink_speed * delta)
	var center := Vector3.ZERO
	if arena:
		center = arena.global_position
	for u in living_allies():
		var d := Vector2(u.global_position.x - center.x, u.global_position.z - center.z).length()
		if d > safe_radius:
			u.take_damage(shrink_dps * delta, boss)
