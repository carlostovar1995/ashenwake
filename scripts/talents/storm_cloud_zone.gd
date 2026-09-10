class_name StormCloudZone
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const STORM_VIOLET := Color(0.62, 0.55, 1.0)

static var _active: Array[StormCloudZone] = []

var source: Unit
var radius: float = 6.0
var duration: float = 8.0
var tick_damage: float = 18.0
var attached: bool = true
var _elapsed: float = 0.0
var _tick_acc: float = 0.0
var _closing: bool = false
var _zone_mat: ShaderMaterial


static func spawn(caster: Unit, ab: AbilityDef) -> StormCloudZone:
	close_for(caster)
	var z := StormCloudZone.new()
	z.source = caster
	z.radius = ab.aoe_radius if ab.aoe_radius > 0.05 else CombatBalance.flat("skill.eye_storm.radius")
	z.duration = ab.zone_duration if ab.zone_duration > 0.05 else CombatBalance.flat("skill.eye_storm.time")
	z.tick_damage = CombatBalance.flat("skill.eye_storm.tick")
	z.name = "StormCloudZone"
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(z)
	z.global_position = Vector3(caster.global_position.x, 0.12, caster.global_position.z)
	z.reset_physics_interpolation()
	z._build()
	_active.append(z)
	return z


static func close_for(caster: Unit) -> void:
	for zone in _active.duplicate():
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.source == caster:
			zone._close()


static func for_caster(caster: Unit) -> StormCloudZone:
	for zone in _active:
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.source == caster:
			return zone
	return null


static func contains_caster(caster: Unit) -> bool:
	if caster == null:
		return false
	for zone in _active:
		if zone == null or not is_instance_valid(zone):
			continue
		if zone.source != caster:
			continue
		if zone.attached:
			return true
		var to: Vector3 = caster.global_position - zone.global_position
		to.y = 0.0
		return to.length() <= zone.radius + caster.radius
	return false


func remaining() -> float:
	return maxf(0.0, duration - _elapsed)


func detach() -> void:
	attached = false
	if source != null and is_instance_valid(source):
		global_position = Vector3(source.global_position.x, 0.12, source.global_position.z)


func _build() -> void:
	var disc := MeshInstance3D.new()
	disc.mesh = GroundIndicator.circle_mesh()
	disc.scale = Vector3(radius, 1.0, radius)
	disc.extra_cull_margin = 16.0
	_zone_mat = GroundIndicator.zone_mat(STORM_VIOLET, radius)
	disc.material_override = _zone_mat
	GroundIndicator.prepare(disc)
	add_child(disc)


func _physics_process(delta: float) -> void:
	if _closing:
		return
	if source == null or not is_instance_valid(source) or source.is_dead:
		_close()
		return
	if attached:
		global_position = Vector3(source.global_position.x, 0.12, source.global_position.z)
	_elapsed += delta
	_tick_acc += delta
	while _tick_acc >= 0.5:
		_tick_acc -= 0.5
		_pulse()
	if _elapsed >= duration:
		_close()


func _pulse() -> void:
	if source == null or not is_instance_valid(source):
		return
	for other in ArenaState.units_near(global_position, radius, false, true, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team == source.team:
			continue
		var to: Vector3 = u.global_position - global_position
		to.y = 0.0
		if to.length() > radius + u.radius:
			continue
		u.apply_shock(source)
		u.take_damage(tick_damage, source, _DamageNumber.tint_for("lightning"), "lightning", "eye_of_the_storm", false, true, -1, true)


func _close() -> void:
	if _closing:
		return
	_closing = true
	_active.erase(self)
	if source != null and is_instance_valid(source):
		var hooks := source.talent_hooks()
		if hooks != null:
			hooks.eye_storm_left = 0.0
			hooks.storm_cloud_id = 0
			hooks.storm_cloud_detached = false
			hooks.storm_cloud_jumped = false
	queue_free()


func _exit_tree() -> void:
	_active.erase(self)
