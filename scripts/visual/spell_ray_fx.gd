class_name SpellRay
extends Node3D

## Particle beam is authored along local +Z. Parent look_at uses -Z, so the
## visual is yawed 180°. Lifetime follows the channel; cylinder Z scale
## follows current aim length. The VFX-maker AnimationPlayer is not played.

const _BEAM_SCENE := preload("res://assets/vfx/beams/spell_ray_beam.tscn")
const _WIDTH_REF := 1.0
const _MESH_Z := 1.2
const _DEFAULT_DURATION := 2.5

var source: Unit
var target: Unit
var color: Color = Color(1.0, 0.82, 0.35)
var steered: bool = false
var beam_width: float = 0.192
var steer_yaw: float = 0.0
var reach: float = 14.0
var duration: float = _DEFAULT_DURATION

var _visual: Node3D
var _cylinders: Array[GPUParticles3D] = []
var _muzzle: GPUParticles3D
var _sparks: GPUParticles3D
var _particles: Array[GPUParticles3D] = []


static func attach(caster: Unit, victim: Unit, tint: Color, life: float = _DEFAULT_DURATION, ab: AbilityDef = null) -> SpellRay:
	return _make(caster, victim, tint, false, life, ab)


static func attach_aimed(caster: Unit, tint: Color, life: float = _DEFAULT_DURATION, ab: AbilityDef = null) -> SpellRay:
	return _make(caster, null, tint, true, life, ab)


static func _make(caster: Unit, victim: Unit, tint: Color, follow_aim: bool, life: float, ab: AbilityDef = null) -> SpellRay:
	var ray := SpellRay.new()
	ray.source = caster
	ray.target = victim
	ray.color = tint
	ray.steered = follow_aim
	ray.duration = maxf(life, 0.05)
	if ab != null and ab.range > 0.05:
		ray.reach = ab.range
	var parent: Node = ArenaState.arena if ArenaState.arena else caster.get_tree().current_scene
	parent.add_child(ray)
	ray._build()
	ray._place()
	if ab:
		SpellVfx.attach_persist(ray, ab)
	return ray


func _build() -> void:
	_visual = _BEAM_SCENE.instantiate() as Node3D
	if _visual == null:
		push_warning("SpellRay: spell_ray_beam.tscn did not instantiate")
		return
	add_child(_visual)
	_visual.rotation.y = PI
	_collect(_visual)
	_configure_particles()
	FxHeroLights.bind(self, color, 2.0, 5.5)


func _collect(node: Node) -> void:
	if node is AnimationPlayer:
		(node as AnimationPlayer).active = false
		return
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		p.local_coords = true
		_particles.append(p)
		match p.name:
			"MainEnergyCylinder", "LittleEnergyCylinder":
				_cylinders.append(p)
			"SplashEnergy":
				_muzzle = p
			"Particles":
				_sparks = p
	for child in node.get_children():
		_collect(child)


func _configure_particles() -> void:
	var life := maxf(duration, 0.05)
	for p in _particles:
		p.lifetime = life
		_tint_process(p)
		p.restart()
		p.emitting = true


func _tint_process(p: GPUParticles3D) -> void:
	var src := p.process_material
	if not (src is ParticleProcessMaterial):
		return
	var pm := (src as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
	var energy := maxf(maxf(pm.color.r, pm.color.g), pm.color.b)
	energy = maxf(energy, 1.0)
	pm.color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	p.process_material = pm


func _process(_delta: float) -> void:
	_place()


func _place() -> void:
	if source == null or not is_instance_valid(source):
		queue_free()
		return
	var from := source.global_position + Vector3(0.0, source.height * 0.62, 0.0)
	var to := from
	if steered:
		var origin := Vector3(source.global_position.x, 0.0, source.global_position.z)
		var dir := source.facing_dir()
		if source.controller != null:
			var aim: Vector3 = source.controller.cast_point
			var offset := Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
			if offset.length_squared() > 0.0001:
				dir = offset.normalized()
		if dir.length_squared() < 0.0001:
			dir = Vector3(0.0, 0.0, 1.0)
		if absf(steer_yaw) > 0.0001:
			dir = dir.rotated(Vector3.UP, steer_yaw)
		var dest := source.wall_stop_point(origin + dir * reach, true)
		to = Vector3(dest.x, from.y, dest.z)
	elif target != null and is_instance_valid(target):
		to = target.global_position + Vector3(0.0, target.height * 0.55, 0.0)
	else:
		queue_free()
		return
	var delta := to - from
	var length := delta.length()
	if length < 0.08:
		visible = false
		return
	visible = true
	global_position = from
	look_at(to, Vector3.UP)
	if _visual == null:
		return
	var xy := beam_width / _WIDTH_REF
	var z := length / _MESH_Z
	for p in _cylinders:
		p.scale = Vector3(xy, xy, z)
	if _muzzle != null:
		_muzzle.scale = Vector3(xy, xy, 1.0)
	if _sparks != null:
		_sparks.scale = Vector3(xy, xy, 1.0)
