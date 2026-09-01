class_name GroundAoeZone
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const DRAW_PRIORITY := 3
const QUERY_RADIUS_PAD := 3.0
const MAX_PULSES_PER_PHYSICS_FRAME := 1

static var _pulse_queue: Array[int] = []
static var _pulse_queued: Dictionary = {}
static var _pulse_budget_frame: int = -1
static var _pulse_budget_used: int = 0
static var _scheduler_arena_id: int = 0

var source: Unit
var radius: float = 9.36
var duration: float = 6.0
var tick_interval: float = 0.5
var tick_damage: float = 14.0
var element: int = AbilityDef.Element.NONE
var extra_elements: PackedInt32Array = PackedInt32Array()
var ability_id: String = "ground_aoe"
var combat_text_cast_id: int = -1
var color: Color = Color(0.55, 0.78, 1.0)
var _core: Color = Color(0.55, 0.78, 1.0)
var _rim: Color = Color(0.22, 0.48, 0.95)
var heal: float = 0.0
var heal_allies: bool = false
var applies_rejuvenation: bool = false
var shield: float = 0.0
var shield_duration: float = 0.0
var blessing_power: float = 0.0

var _elapsed: float = 0.0
var _tick_acc: float = 0.0
var _ticks: int = 0
var _max_ticks: int = 12
var _pending_pulses: int = 0
var _zone_mat: ShaderMaterial
var _closing: bool = false
var _fade: float = 1.0
var _pulse_tw: Tween
var wind_pull: bool = false
var vacuum_hit: bool = false


static func spawn(
	caster: Unit,
	point: Vector3,
	ab: AbilityDef,
	extras: PackedInt32Array,
	radius_override: float = -1.0,
	text_cast_id: int = -1
) -> GroundAoeZone:
	var z := GroundAoeZone.new()
	z.source = caster
	z.radius = maxf(radius_override if radius_override > 0.05 else ab.aoe_radius, 0.6)
	z.duration = maxf(ab.zone_duration, 0.2)
	z.tick_interval = maxf(ab.tick_interval, 0.05)
	z.tick_damage = caster._scaled(ab.tick_damage)
	z.element = ab.element
	z.extra_elements = extras
	z.ability_id = AbilityDef.combat_id_of(ab, "ground_aoe")
	if z.ability_id.is_empty():
		z.ability_id = "ground_aoe"
	z.combat_text_cast_id = text_cast_id
	var pal := SpellBaseFx.palette(ab)
	z.color = pal.core
	z._core = pal.core
	z._rim = pal.rim
	z.heal = caster._scaled(ab.heal)
	z.heal_allies = ab.heal_allies
	z.applies_rejuvenation = ab.applies_rejuvenation
	z.shield = caster._scaled(ab.shield)
	z.shield_duration = ab.shield_duration if ab.shield_duration > 0.05 else Unit.PROTECTION_SHIELD_TIME
	if ab.element == AbilityDef.Element.HOLY:
		z.blessing_power = ab.base_power
	else:
		for extra in extras:
			if extra == AbilityDef.Element.HOLY:
				z.blessing_power = ab.base_power
				break
	z.wind_pull = ab.has_element(AbilityDef.Element.WIND)
	if z.wind_pull:
		z.vacuum_hit = ab.element != AbilityDef.Element.WIND or extras.size() > 0
	z._max_ticks = maxi(int(round(z.duration / z.tick_interval)), 1)
	z.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(z)
	z.global_position = Vector3(point.x, 0.10, point.z)
	z.reset_physics_interpolation()
	z._build()
	return z


func _build() -> void:
	var disc := MeshInstance3D.new()
	disc.mesh = GroundIndicator.circle_mesh()
	disc.scale = Vector3(radius, 1.0, radius)
	disc.extra_cull_margin = 16.0
	_zone_mat = GroundIndicator.zone_mat(_core, radius)
	GroundIndicator.set_rim(_zone_mat, _rim)
	_zone_mat.render_priority = DRAW_PRIORITY
	disc.material_override = _zone_mat
	GroundIndicator.prepare(disc)
	add_child(disc)
	FxHeroLights.bind(self, _core.lerp(_rim, 0.35), 1.1, radius * 1.1)


func _physics_process(delta: float) -> void:
	_drain_pulse_queue()
	if _closing:
		return
	_elapsed += delta
	if source == null or not is_instance_valid(source) or source.is_dead:
		_close()
		return
	_tick_acc += delta
	if wind_pull:
		_pull_enemies(delta)
	while _ticks < _max_ticks and (_ticks == 0 or _tick_acc >= tick_interval):
		if _ticks > 0:
			_tick_acc -= tick_interval
		_enqueue_pulse(self, true)
		_ticks += 1
	_drain_pulse_queue()
	if _elapsed >= duration and _pending_pulses <= 0:
		_close()


static func _ensure_pulse_scheduler() -> void:
	var arena_id := ArenaState.arena.get_instance_id() if ArenaState.arena != null and is_instance_valid(ArenaState.arena) else 0
	if arena_id == _scheduler_arena_id:
		return
	_scheduler_arena_id = arena_id
	_pulse_queue.clear()
	_pulse_queued.clear()
	_pulse_budget_frame = -1
	_pulse_budget_used = 0


static func _enqueue_pulse(zone: GroundAoeZone, add_pending: bool) -> void:
	_ensure_pulse_scheduler()
	if zone == null or not is_instance_valid(zone):
		return
	if add_pending:
		zone._pending_pulses += 1
	var id: int = zone.get_instance_id()
	if _pulse_queued.has(id):
		return
	_pulse_queued[id] = true
	_pulse_queue.append(id)


static func _drain_pulse_queue() -> void:
	_ensure_pulse_scheduler()
	var frame := Engine.get_physics_frames()
	if frame != _pulse_budget_frame:
		_pulse_budget_frame = frame
		_pulse_budget_used = 0
	while _pulse_budget_used < MAX_PULSES_PER_PHYSICS_FRAME and not _pulse_queue.is_empty():
		var id: int = int(_pulse_queue.pop_front())
		_pulse_queued.erase(id)
		var found = instance_from_id(id)
		if found == null or not is_instance_valid(found):
			continue
		var zone := found as GroundAoeZone
		if zone == null or zone.is_queued_for_deletion():
			continue
		_pulse_budget_used += 1
		zone._run_queued_pulse()
		if is_instance_valid(zone) and not zone._closing and zone._pending_pulses > 0:
			_enqueue_pulse(zone, false)


func _run_queued_pulse() -> void:
	if _pending_pulses <= 0 or _closing:
		return
	_pending_pulses -= 1
	if source == null or not is_instance_valid(source) or source.is_dead:
		_pending_pulses = 0
		_close()
		return
	_pulse_enemies()
	_pulse_allies()
	_pulse_zone()
	if _elapsed >= duration and _pending_pulses <= 0:
		_close()


func _pulse_enemies() -> void:
	if source == null or not is_instance_valid(source) or tick_damage <= 0.0:
		return
	for u in ArenaState.units_near(global_position, radius + QUERY_RADIUS_PAD):
		if u.team == source.team:
			continue
		if u.hit_distance_to(global_position) > radius:
			continue
		u.receive_ability_hit(source, element, tick_damage, 0.0, extra_elements, not vacuum_hit, true, true, -1, 0, ability_id, combat_text_cast_id, true)
	SpellWall.apply_radius_hit(source, global_position, radius, tick_damage, "hit", Color(0, 0, 0, 0), combat_text_cast_id)


func _pull_enemies(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var speed := CombatBalance.flat("wind.ground.pull")
	for u in ArenaState.units_near(global_position, radius + QUERY_RADIUS_PAD):
		if u.team == source.team:
			continue
		var to := u.global_position - global_position
		to.y = 0.0
		if to.length() > radius + u.radius:
			continue
		UnitWind.pull_toward(u, global_position, speed, delta)


func _pulse_allies() -> void:
	if source == null or not is_instance_valid(source):
		return
	var ab := source._ability_def(ability_id)
	var altered := ab != null and ab.altered
	if not heal_allies and not applies_rejuvenation and shield <= 0.05 and not altered:
		return
	var heal_amt := heal if heal > 0.05 else 0.0
	for u in ArenaState.units_near(global_position, radius + QUERY_RADIUS_PAD):
		if u.team != source.team:
			continue
		var to := u.global_position - global_position
		to.y = 0.0
		if to.length() > radius + u.radius:
			continue
		_buff_ally(u, ab, altered, heal_amt)


func _buff_ally(u: Unit, ab: AbilityDef, altered: bool, heal_amt: float) -> void:
	if u == null or not is_instance_valid(u) or u.is_dead:
		return
	if heal_allies or applies_rejuvenation or shield > 0.05:
		u.apply_support_hit(
			source,
			heal_amt,
			shield,
			shield_duration,
			applies_rejuvenation,
			ability_id,
			blessing_power,
			extra_elements,
			element,
			combat_text_cast_id,
			true
		)
	if altered:
		u.apply_altered_from(ab, false)


func _close() -> void:
	if _closing:
		return
	_closing = true
	if _pulse_tw != null and is_instance_valid(_pulse_tw):
		_pulse_tw.kill()
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, 0.10 if wind_pull else 0.3)
	tw.finished.connect(queue_free)


func _pulse_zone() -> void:
	if _zone_mat == null or _closing:
		return
	if _pulse_tw != null and is_instance_valid(_pulse_tw):
		_pulse_tw.kill()
	_pulse_tw = create_tween()
	_pulse_tw.tween_method(_set_pulse, 0.0, 1.0, 0.08)
	_pulse_tw.tween_method(_set_pulse, 1.0, 0.0, 0.2)


func _set_pulse(t: float) -> void:
	_apply_zone_look(_fade, t)


func _set_fade(t: float) -> void:
	_fade = t
	_apply_zone_look(t, 0.0)


func _apply_zone_look(fade: float, pulse: float) -> void:
	if _zone_mat:
		_zone_mat.set_shader_parameter("fill_alpha", GroundIndicator.ZONE_FILL_ALPHA * fade * (1.0 + pulse * 0.7))
		_zone_mat.set_shader_parameter("outline_alpha", GroundIndicator.ZONE_OUTLINE_ALPHA * fade * (1.0 + pulse * 0.45))
		_zone_mat.set_shader_parameter("emission_strength", GroundIndicator.ZONE_EMISSION * fade * (1.0 + pulse * 0.4))
