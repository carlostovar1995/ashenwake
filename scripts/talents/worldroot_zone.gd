class_name WorldrootZone
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const GROVE_GREEN := Color(0.32, 0.78, 0.38)

static var _active: Array[WorldrootZone] = []

var source: Unit
var radius: float = 7.0
var duration: float = 6.0
var heal: float = 52.0
var combat_text_cast_id: int = -1
var _elapsed: float = 0.0
var _tick_acc: float = 0.0
var _closing: bool = false
var _zone_mat: ShaderMaterial


static func spawn(caster: Unit, point: Vector3, ab: AbilityDef, text_id: int) -> WorldrootZone:
	close_for(caster)
	var z := WorldrootZone.new()
	z.source = caster
	z.radius = ab.aoe_radius if ab.aoe_radius > 0.05 else CombatBalance.flat("skill.worldroot.radius")
	z.duration = ab.zone_duration if ab.zone_duration > 0.05 else CombatBalance.flat("skill.worldroot.time")
	z.heal = CombatBalance.flat("skill.worldroot.heal")
	z.combat_text_cast_id = text_id
	z.name = "WorldrootZone"
	var parent: Node = ArenaState.arena if ArenaState.arena else Engine.get_main_loop().root
	parent.add_child(z)
	z.global_position = Vector3(point.x, 0.10, point.z)
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


static func blocks_knockback(u: Unit) -> bool:
	if u == null:
		return false
	var hooks := u.talent_hooks()
	return hooks != null and hooks.rooted_left > 0.05


func _build() -> void:
	var disc := MeshInstance3D.new()
	disc.mesh = GroundIndicator.circle_mesh()
	disc.scale = Vector3(radius, 1.0, radius)
	disc.extra_cull_margin = 16.0
	_zone_mat = GroundIndicator.zone_mat(GROVE_GREEN, radius)
	disc.material_override = _zone_mat
	GroundIndicator.prepare(disc)
	add_child(disc)


func _physics_process(delta: float) -> void:
	if _closing:
		return
	if source == null or not is_instance_valid(source) or source.is_dead:
		_close()
		return
	_elapsed += delta
	_tick_acc += delta
	if _elapsed < duration and (_tick_acc >= 1.0 or _elapsed <= delta + 0.001):
		if _tick_acc >= 1.0:
			_tick_acc -= 1.0
		_pulse()
	if _elapsed >= duration:
		_close()


func _pulse() -> void:
	if source == null or not is_instance_valid(source):
		return
	for other in ArenaState.units_near(global_position, radius, false, true):
		var u := other as Unit
		if u == null or u.is_dead or u.team != source.team:
			continue
		var to: Vector3 = u.global_position - global_position
		to.y = 0.0
		if to.length() > radius + u.radius:
			continue
		u.apply_support_hit(source, heal, 0.0, 0.0, true, "worldroot", 0.0, PackedInt32Array(), AbilityDef.Element.NATURE, combat_text_cast_id, true)


func _close() -> void:
	if _closing:
		return
	_closing = true
	_active.erase(self)
	if source != null and is_instance_valid(source):
		var hooks := source.talent_hooks()
		if hooks != null:
			hooks.rooted_left = 0.0
			hooks.worldroot_zone_id = 0
	queue_free()


func _exit_tree() -> void:
	_active.erase(self)
