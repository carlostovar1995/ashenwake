class_name JudgmentBeam
extends Node3D

const WARNING := 2.0
const DURATION := 1.8
const TICKS := 12
const PLAYER_TOTAL := 250.0

var source: Unit
var target: Unit
var elapsed: float = 0.0
var firing: bool = false
var finished: bool = false
var tick_index: int = 0

var _beam: MeshInstance3D
var _beam_mesh: BoxMesh
var _mat: StandardMaterial3D
var _tick_timer: float = 0.0
var _glow: MeshInstance3D
var _light: OmniLight3D
var _ray_sfx: int = 0
var _laser: MeshInstance3D
var _laser_mesh: BoxMesh
var _laser_mat: StandardMaterial3D
var _pip: MeshInstance3D
var _pip_mat: StandardMaterial3D


static func fire(p_source: Unit, p_target: Unit) -> JudgmentBeam:
	var beam := JudgmentBeam.new()
	beam.source = p_source
	beam.target = p_target
	var parent: Node = ArenaState.arena if ArenaState.arena else p_source.get_tree().current_scene
	parent.add_child(beam)
	ArenaState.add_beam(beam)
	return beam


func remaining_player_damage() -> float:
	if finished or target == null:
		return 0.0
	var left := TICKS - tick_index
	if not firing:
		left = TICKS
	return PLAYER_TOTAL * float(maxi(left, 0)) / float(TICKS)


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.55, 0.1, 0.55)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.42, 0.05)
	_mat.emission_energy_multiplier = 5.5
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mesh = BoxMesh.new()
	_beam_mesh.size = Vector3(0.42, 0.42, 1.0)
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.material_override = _mat
	_beam.visible = false
	add_child(_beam)
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.95, 0.55, 1.0)
	_glow = MeshInstance3D.new()
	_glow.mesh = glow_mesh
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.7, 0.15, 0.28)
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.55, 0.08)
	glow_mat.emission_energy_multiplier = 3.2
	glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow.material_override = glow_mat
	_glow.visible = false
	add_child(_glow)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.78, 0.22)
	_light.light_energy = 1.1
	_light.omni_range = 6.0
	_light.position.y = 1.2
	add_child(_light)
	_laser_mesh = BoxMesh.new()
	_laser_mesh.size = Vector3(0.05, 0.05, 1.0)
	_laser = MeshInstance3D.new()
	_laser.mesh = _laser_mesh
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.albedo_color = Color(1.0, 0.22, 0.08, 0.92)
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.emission_enabled = true
	_laser_mat.emission = Color(1.0, 0.28, 0.06)
	_laser_mat.emission_energy_multiplier = 4.5
	_laser_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_laser.material_override = _laser_mat
	_laser.position.y = 1.28
	add_child(_laser)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.13
	pip_mesh.height = 0.26
	_pip = MeshInstance3D.new()
	_pip.mesh = pip_mesh
	_pip_mat = StandardMaterial3D.new()
	_pip_mat.albedo_color = Color(1.0, 0.35, 0.08, 0.95)
	_pip_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pip_mat.emission_enabled = true
	_pip_mat.emission = Color(1.0, 0.4, 0.08)
	_pip_mat.emission_energy_multiplier = 6.0
	_pip.material_override = _pip_mat
	add_child(_pip)
	if source and is_instance_valid(source):
		AbilityFx.play_at(AbilityFx.FIRE_CAST, source.global_position + Vector3(0, 1.65, 0), {
			"scale": 1.15,
			"lifetime": WARNING + 0.2,
		})
		AudioManager.play_at("dawnwarden.ray.warn", source.global_position + Vector3(0, 1.65, 0))


func _process(_delta: float) -> void:
	if finished:
		return
	_update_visual()


func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if not firing:
		if elapsed >= WARNING:
			_begin_channel()
		return
	_tick_timer += delta
	var interval := DURATION / float(TICKS)
	while _tick_timer >= interval and tick_index < TICKS and not finished:
		_tick_timer -= interval
		_apply_tick()
		tick_index += 1
	if tick_index >= TICKS:
		_finish()


func _begin_channel() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		_finish()
		return
	if target == null or not is_instance_valid(target) or target.is_dead:
		_finish()
		return
	firing = true
	_tick_timer = 0.0
	if _laser:
		_laser.visible = false
	if _pip:
		_pip.visible = false
	_beam.visible = true
	_glow.visible = true
	var ai := _source_ai()
	if ai:
		ai.begin_ability("Judgment Ray", DURATION, Color(1.0, 0.82, 0.28), false)
	_play_fire_fx()


func _source_ai() -> BossAI:
	if source == null or not is_instance_valid(source):
		return null
	for child in source.get_children():
		if child is BossAI:
			return child
	return null


func _apply_tick() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		_finish()
		return
	if target == null or not is_instance_valid(target) or target.is_dead:
		_finish()
		return
	var arena := ArenaState.arena as Arena
	var player_tick := PLAYER_TOTAL / float(TICKS)
	if arena == null:
		target.take_damage(player_tick, source)
		return
	var hit := arena.spell_wall_hit(source.global_position, target.global_position, [source.get_rid(), target.get_rid()])
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is ArenaPillar:
			var pillar := col as ArenaPillar
			if pillar.living:
				pillar.take_damage(pillar.max_health / float(TICKS))
				if tick_index == 0 or tick_index == 5:
					AbilityFx.play_at(AbilityFx.FIRE_AREA, pillar.global_position + Vector3(0, 1.0, 0), {
						"area_radius": 1.6,
						"scale": 0.7,
						"lifetime": 0.7,
					})
				return
	target.take_damage(player_tick, source)
	if tick_index == 0:
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, target.global_position, {"scale": 0.85, "lifetime": 1.2})


func _update_visual() -> void:
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var from := source.global_position + Vector3(0, 1.35, 0)
	var to := target.global_position + Vector3(0, 1.05, 0)
	var delta := to - from
	delta.y = 0.0
	var length := maxf(delta.length(), 0.2)
	if length < 0.3:
		return
	var dir := delta.normalized()
	var mid := from + dir * (length * 0.5)
	global_position = Vector3(mid.x, 0.04, mid.z)
	var look := Vector3(mid.x + dir.x, 0.04, mid.z + dir.z)
	if Vector2(look.x - global_position.x, look.z - global_position.z).length_squared() > 0.0001:
		look_at(look, Vector3.UP)
	if firing:
		_beam_mesh.size = Vector3(0.55, 0.55, length)
		_beam.position = Vector3(0, 1.25, 0)
		if _glow:
			var gmesh := _glow.mesh as BoxMesh
			if gmesh:
				gmesh.size = Vector3(1.15, 0.7, length)
			_glow.position = Vector3(0, 1.25, 0)
		if _mat:
			_mat.albedo_color.a = 0.92
			_mat.emission_energy_multiplier = 8.5
		if _light:
			_light.light_energy = 8.0
			_light.omni_range = 10.0
		return
	var lock_u := clampf(elapsed / WARNING, 0.0, 1.0)
	var pulse := 0.55 + 0.45 * sin(elapsed * 18.0)
	var thick := lerpf(0.04, 0.09, lock_u) * (0.82 + 0.18 * pulse)
	if _laser_mesh:
		_laser_mesh.size = Vector3(thick, thick, length)
	_laser.position = Vector3(0, 1.28, 0)
	if _laser_mat:
		_laser_mat.albedo_color.a = 0.55 + 0.4 * lock_u
		_laser_mat.emission_energy_multiplier = 3.2 + 6.5 * lock_u + pulse
	if _pip:
		_pip.position = Vector3(0, 1.08, -length * 0.5)
		_pip.scale = Vector3.ONE * (0.7 + 0.55 * lock_u + 0.12 * pulse)
	if _pip_mat:
		_pip_mat.emission_energy_multiplier = 4.0 + 7.0 * lock_u
	if _light:
		_light.light_energy = 0.8 + 2.4 * lock_u
		_light.omni_range = 5.0 + 3.0 * lock_u
		_light.position = Vector3(0, 1.2, -length * 0.5)


func _play_fire_fx() -> void:
	if source == null or not is_instance_valid(source):
		return
	AbilityFx.play_at(AbilityFx.FIRE_CAST, source.global_position + Vector3(0, 1.7, 0), {
		"scale": 1.7,
		"lifetime": DURATION + 0.3,
	})
	if target and is_instance_valid(target):
		var look := target.global_position - source.global_position
		AbilityFx.play_at(AbilityFx.FIRE_PROJECTILE, source.global_position + Vector3(0, 1.4, 0), {
			"look": look,
			"scale": 1.4,
			"lifetime": DURATION,
		})
	_ray_sfx = AudioManager.attach_loop("dawnwarden.ray.loop", self)


func interrupt_cast() -> bool:
	if finished or firing:
		return false
	_finish()
	return true


func _finish() -> void:
	if finished:
		return
	finished = true
	AudioManager.stop_loop(_ray_sfx, 0.08)
	_ray_sfx = 0
	ArenaState.remove_beam(self)
	queue_free()
