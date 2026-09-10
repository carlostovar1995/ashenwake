class_name SanctuaryZone
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")

const GOLD := Color(0.95, 0.84, 0.38)
const ALLY_PULSE := 1.0
const DR_PERCENT := 0.25
const DR_REFRESH := 0.12
const DR_REFRESH_INTERVAL := 0.10
const DRAW_PRIORITY := 4

var source: Unit
var radius: float = 7.5
var duration: float = 8.0
var tick_interval: float = 0.5
var tick_damage: float = 8.0
var tick_shield: float = 15.0
var shield_duration: float = 3.0
var ability_id: String = "sanctuary"
var element: int = AbilityDef.Element.NONE
var extra_elements: PackedInt32Array = PackedInt32Array()
var combat_text_cast_id: int = -1
var ally_dr: float = DR_PERCENT
var caster_dr: float = DR_PERCENT
var threat_pulse: float = 0.0

static var _active: Array[SanctuaryZone] = []

var _elapsed: float = 0.0
var _tick_acc: float = 0.0
var _shield_acc: float = 0.0
var _dr_refresh_acc: float = DR_REFRESH_INTERVAL
var _ticks: int = 0
var _max_ticks: int = 16
var _allies_pulsed: bool = false
var _zone_mat: ShaderMaterial
var _closing: bool = false


static func spawn(
	caster: Unit,
	point: Vector3,
	p_radius: float,
	p_duration: float,
	p_interval: float,
	p_damage: float,
	p_shield: float,
	p_shield_duration: float,
	p_ability_id: String = "sanctuary",
	p_element: int = AbilityDef.Element.NONE,
	p_extras: PackedInt32Array = PackedInt32Array(),
	p_combat_text_cast_id: int = -1
):
	var z := new()
	z.source = caster
	z.radius = maxf(p_radius, 0.5)
	z.duration = maxf(p_duration, 0.2)
	z.tick_interval = maxf(p_interval, 0.05)
	z.tick_damage = p_damage
	z.tick_shield = p_shield
	z.shield_duration = p_shield_duration
	z.ability_id = p_ability_id if not p_ability_id.is_empty() else "sanctuary"
	z.element = p_element
	z.extra_elements = p_extras
	z.combat_text_cast_id = p_combat_text_cast_id
	z._max_ticks = maxi(int(round(z.duration / z.tick_interval)), 1)
	z.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(z)
	z.global_position = Vector3(point.x, 0.10, point.z)
	z.reset_physics_interpolation()
	z._build()
	_active.append(z)
	return z


static func blocks_knockback(u: Unit) -> bool:
	if u == null or u.is_dead:
		return false
	for zone in _active:
		if zone == null or not is_instance_valid(zone) or zone._closing:
			continue
		if zone.source == null or not is_instance_valid(zone.source):
			continue
		if u.team != zone.source.team:
			continue
		if zone._contains(u):
			return true
	return false


func _build() -> void:
	var disc := MeshInstance3D.new()
	disc.mesh = GroundIndicator.circle_mesh()
	disc.scale = Vector3(radius, 1.0, radius)
	disc.extra_cull_margin = 16.0
	_zone_mat = GroundIndicator.zone_mat(GOLD, radius)
	_zone_mat.render_priority = DRAW_PRIORITY
	disc.material_override = _zone_mat
	GroundIndicator.prepare(disc)
	add_child(disc)
	FxHeroLights.bind(self, Color(1.0, 0.88, 0.48), 1.2, radius * 1.15)


func _physics_process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	if source == null or not is_instance_valid(source) or source.is_dead:
		_close()
		return
	_tick_acc += delta
	while _ticks < _max_ticks and (_ticks == 0 or _tick_acc >= tick_interval):
		if _ticks > 0:
			_tick_acc -= tick_interval
		_pulse_enemies()
		_ticks += 1
	if not _allies_pulsed:
		_pulse_allies()
		_allies_pulsed = true
		_shield_acc = 0.0
	else:
		_shield_acc += delta
		while _shield_acc >= ALLY_PULSE:
			_shield_acc -= ALLY_PULSE
			_pulse_allies()
	_dr_refresh_acc += delta
	if _dr_refresh_acc >= DR_REFRESH_INTERVAL:
		_dr_refresh_acc = 0.0
		_refresh_dr()
	if _elapsed >= duration:
		_close()


func _pulse_enemies() -> void:
	if source == null or not is_instance_valid(source):
		return
	for u in ArenaState.units_near(global_position, radius, true, true, true):
		if u.team == source.team:
			continue
		if not _contains(u):
			continue
		if not _has_los(u):
			continue
		if tick_damage > 0.0:
			u.receive_ability_hit(source, element, tick_damage, 0.0, extra_elements, true, false, true, -1, 0, ability_id, combat_text_cast_id)
		if threat_pulse > 0.0:
			ThreatTable.add_threat(u, source, threat_pulse, ability_id)


func _pulse_allies() -> void:
	if source == null or not is_instance_valid(source) or tick_shield <= 0.0:
		return
	var dur := shield_duration if shield_duration > 0.05 else Unit.WARD_TIME
	for u in ArenaState.units_near(global_position, radius, true, true, true):
		if u.team != source.team:
			continue
		if not _contains(u):
			continue
		u.apply_shield(tick_shield, dur, source)


func _refresh_dr() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		return
	if ally_dr <= 0.0 and caster_dr <= 0.0:
		return
	var hit_caster := false
	for u in ArenaState.units_near(global_position, radius, true, true, true):
		if u.team != source.team:
			continue
		if not _contains(u):
			continue
		if u == source:
			hit_caster = true
			if caster_dr > 0.0:
				u.apply_damage_reduction(caster_dr, DR_REFRESH)
		elif ally_dr > 0.0:
			u.apply_damage_reduction(ally_dr, DR_REFRESH)
	if not hit_caster and caster_dr > 0.0:
		source.apply_damage_reduction(caster_dr, DR_REFRESH)


func _contains(u: Unit) -> bool:
	if u == null or not is_instance_valid(u) or u.is_dead:
		return false
	var to := u.global_position - global_position
	to.y = 0.0
	return to.length() <= radius + u.radius


func _has_los(u: Unit) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return true
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(u.get_rid())
	return arena.spell_has_los(global_position, u.global_position, exclude)


func _exit_tree() -> void:
	_active.erase(self)


func _close() -> void:
	if _closing:
		return
	_closing = true
	_active.erase(self)
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, 0.35)
	tw.finished.connect(queue_free)


func _set_fade(t: float) -> void:
	if _zone_mat:
		_zone_mat.set_shader_parameter("fill_alpha", GroundIndicator.ZONE_FILL_ALPHA * t)
		_zone_mat.set_shader_parameter("outline_alpha", GroundIndicator.ZONE_OUTLINE_ALPHA * t)
		_zone_mat.set_shader_parameter("emission_strength", GroundIndicator.ZONE_EMISSION * t)
