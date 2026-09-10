extends Node

signal fight_won
signal fight_lost
signal unit_registered(unit)

const UNIT_GRID_CELL := 4.0

var units: Array = []
var allies: Array = []
var enemies: Array = []
var _structures: Array[Unit] = []
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
var _fight_elapsed: float = 0.0
var _unit_grid: Dictionary = {}
var _unit_grid_frame: int = -1
var _unit_grid_max_radius: float = 0.0


func reset() -> void:
	units.clear()
	allies.clear()
	enemies.clear()
	_structures.clear()
	champion = null
	boss = null
	arena = null
	outcome = ""
	telegraphs.clear()
	beams.clear()
	_unit_grid.clear()
	_unit_grid_frame = -1
	_unit_grid_max_radius = 0.0
	shrink_active = false
	safe_radius = 26.0
	_fight_elapsed = 0.0


func register_arena(p_arena: Node3D) -> void:
	arena = p_arena


func register_unit(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if units.has(unit):
		return
	units.append(unit)
	if unit.is_structure:
		_structures.append(unit)
	else:
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
	_unit_grid_frame = -1
	unit_registered.emit(unit)


func unregister_unit(unit: Unit) -> void:
	if unit == null:
		return
	units.erase(unit)
	allies.erase(unit)
	enemies.erase(unit)
	_structures.erase(unit)
	if champion == unit:
		champion = null
	if boss == unit:
		boss = null
	if unit.died.is_connected(_on_unit_died):
		unit.died.disconnect(_on_unit_died)
	_unit_grid_frame = -1


func units_near(
	point: Vector3,
	radius: float,
	include_structures: bool = false,
	include_unit_radius: bool = false,
	flat_distance: bool = false
) -> Array[Unit]:
	_refresh_unit_grid()
	var result: Array[Unit] = []
	var reach := maxf(radius, 0.0)
	var search_reach := reach + (_unit_grid_max_radius if include_unit_radius else 0.0)
	var cell := _grid_cell(point)
	var cells := maxi(int(ceil(search_reach / UNIT_GRID_CELL)), 0)
	for x in range(cell.x - cells, cell.x + cells + 1):
		for z in range(cell.y - cells, cell.y + cells + 1):
			var bucket: Array = _unit_grid.get(Vector2i(x, z), [])
			for raw in bucket:
				if raw == null or not is_instance_valid(raw):
					continue
				var unit := raw as Unit
				if unit == null or unit.is_dead or unit.is_structure:
					continue
				var offset := unit.global_position - point
				if flat_distance:
					offset.y = 0.0
				var unit_reach := reach + (maxf(unit.radius, 0.0) if include_unit_radius else 0.0)
				if offset.length_squared() <= unit_reach * unit_reach:
					result.append(unit)
	if include_structures:
		for unit in _structures:
			if unit == null or not is_instance_valid(unit) or unit.is_dead:
				continue
			var offset := unit.global_position - point
			if flat_distance:
				offset.y = 0.0
			var unit_reach := reach + (maxf(unit.radius, 0.0) if include_unit_radius else 0.0)
			if offset.length_squared() <= unit_reach * unit_reach:
				result.append(unit)
			elif include_unit_radius and unit.hit_distance_to(point) <= reach:
				# Wall proxies can be long relative to their center/radius.
				result.append(unit)
	return result


func _grid_cell(point: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(point.x / UNIT_GRID_CELL)),
		int(floor(point.z / UNIT_GRID_CELL))
	)


func _refresh_unit_grid() -> void:
	var frame := Engine.get_physics_frames()
	if _unit_grid_frame == frame:
		return
	_unit_grid_frame = frame
	_unit_grid.clear()
	_unit_grid_max_radius = 0.0
	for raw in units:
		if raw == null or not is_instance_valid(raw):
			continue
		var unit := raw as Unit
		if unit == null or unit.is_dead or unit.is_structure:
			continue
		_unit_grid_max_radius = maxf(_unit_grid_max_radius, maxf(unit.radius, 0.0))
		var cell := _grid_cell(unit.global_position)
		var bucket: Array = _unit_grid.get(cell, [])
		bucket.append(unit)
		_unit_grid[cell] = bucket


func living_allies() -> Array:
	var result: Array = []
	_append_living(result, champion)
	for u in allies:
		_append_living(result, u)
	return result


func living_enemies() -> Array:
	var result: Array = []
	for u in enemies:
		_append_living(result, u)
	return result


func living_team(team: int) -> Array:
	return living_allies() if team == 0 else living_enemies()


func structures() -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in _structures:
		if unit == null or not is_instance_valid(unit) or unit.is_dead:
			continue
		result.append(unit)
	return result


func _append_living(result: Array, unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_dead or unit.is_structure:
		return
	if result.has(unit):
		return
	result.append(unit)


func nearest_enemy(from: Vector3, team: int) -> Unit:
	var best: Unit = null
	var best_d := INF
	var pool: Array = living_enemies() if team == 0 else living_allies()
	for u in pool:
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.has_method("can_be_aggroed") and not u.can_be_aggroed():
			continue
		if u.team == team:
			continue
		var d := from.distance_to(u.global_position)
		if d < best_d:
			best_d = d
			best = u
	return best


func tank() -> Unit:
	if GameSession.player_is_tank():
		if champion != null and is_instance_valid(champion) and not champion.is_dead:
			return champion
		return null
	for ally in allies:
		if ally == null or not is_instance_valid(ally) or ally.is_dead:
			continue
		var ai := ally.get_node_or_null("AllyAI") as AllyAI
		if ai and ai.role == "tank":
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


func remove_telegraph(t: Node) -> void:
	telegraphs.erase(t)


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
	if not GameSession.training_mode:
		_fight_elapsed += delta
		# Same 12:00 shrink for every group. Not HP%, not a role-count tax.
		if not shrink_active and _fight_elapsed >= CombatBalance.flat("fight.enrage.time"):
			start_shrink()
	if not shrink_active:
		return
	safe_radius = maxf(shrink_min, safe_radius - shrink_speed * delta)
	var center := Vector3.ZERO
	if arena:
		center = arena.global_position
	for u in living_allies():
		var d := Vector2(u.global_position.x - center.x, u.global_position.z - center.z).length()
		if d > safe_radius:
			u.apply_world_hit(shrink_dps * delta, boss, "hit", "arena_shrink", -1, true)
