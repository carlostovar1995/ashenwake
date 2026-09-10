class_name JudgmentBeam
extends Node3D

const WARNING := 2.0
const DURATION := 1.8
const TICKS := 12
const TICK_INTERVAL := DURATION / float(TICKS)
const _STASH := Vector3(0.0, -80.0, 0.0)
const _POOL := 2

var source: Unit
var target: Unit
var elapsed: float = 0.0
var firing: bool = false
var finished: bool = false
var tick_index: int = 0
var channel_duration: float = DURATION
var _max_ticks: int = TICKS

var _beam: MeshInstance3D
var _beam_mesh: BoxMesh
var _mat: StandardMaterial3D
var _tick_timer: float = 0.0
var _glow: MeshInstance3D
var _ray_sfx: int = 0
var _laser: MeshInstance3D
var _laser_mesh: BoxMesh
var _laser_mat: StandardMaterial3D
var _pip: MeshInstance3D
var _pip_mat: StandardMaterial3D
var _end: Vector3 = Vector3.ZERO
var _visuals_ready: bool = false

static var _idle: Array[JudgmentBeam] = []
static var _live: Array[JudgmentBeam] = []
static var _host: Node


static func fire(p_source: Unit, p_target: Unit) -> JudgmentBeam:
	var parent: Node = _host
	if parent == null or not is_instance_valid(parent):
		parent = ArenaState.arena
		if parent:
			var fx_root := parent.get_node_or_null("FxRoot")
			if fx_root:
				parent = fx_root
		if parent == null:
			parent = p_source.get_tree().current_scene if p_source else Engine.get_main_loop().root
		warmup(parent)
	var beam := _take()
	if beam == null:
		return null
	beam._launch(p_source, p_target)
	ArenaState.add_beam(beam)
	return beam


static func warmup(parent: Node) -> void:
	if parent == null:
		return
	_host = parent
	if not parent.tree_exiting.is_connected(_release):
		parent.tree_exiting.connect(_release)
	_prune()
	var have := _idle.size() + _live.size()
	while have < _POOL:
		var beam := JudgmentBeam.new()
		parent.add_child(beam)
		beam._stash()
		have += 1


static func _release() -> void:
	_idle.clear()
	_live.clear()
	_host = null


static func _take() -> JudgmentBeam:
	var beam: JudgmentBeam = null
	while beam == null and not _idle.is_empty():
		var candidate: JudgmentBeam = _idle.pop_back()
		if candidate != null and is_instance_valid(candidate):
			beam = candidate
	if beam == null and not _live.is_empty():
		var oldest: JudgmentBeam = _live[0]
		if oldest != null and is_instance_valid(oldest):
			oldest._finish()
			if not _idle.is_empty():
				beam = _idle.pop_back()
	if beam == null:
		return null
	_live.append(beam)
	return beam


static func _prune() -> void:
	var keep_idle: Array[JudgmentBeam] = []
	for b in _idle:
		if b != null and is_instance_valid(b):
			keep_idle.append(b)
	_idle = keep_idle
	var keep_live: Array[JudgmentBeam] = []
	for b in _live:
		if b != null and is_instance_valid(b):
			keep_live.append(b)
	_live = keep_live


func remaining_player_damage() -> float:
	if finished or target == null:
		return 0.0
	var left := _max_ticks - tick_index
	if not firing:
		left = _max_ticks
	return _tick_damage_for(target) * float(maxi(left, 0))


static func _player_total() -> float:
	return CombatBalance.flat("dawnwarden.judgment")


func _tick_damage_for(_victim: Unit) -> float:
	return _player_total() / float(TICKS)


func _ready() -> void:
	_build_visuals()


func _build_visuals() -> void:
	if _visuals_ready:
		return
	_visuals_ready = true
	_mat = _make_mat(Color(1.0, 0.55, 0.1, 0.55), Color(1.0, 0.42, 0.05), 5.5)
	_beam_mesh = BoxMesh.new()
	_beam_mesh.size = Vector3.ONE
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.material_override = _mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_beam.visible = false
	add_child(_beam)
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3.ONE
	_glow = MeshInstance3D.new()
	_glow.mesh = glow_mesh
	_glow.material_override = _make_mat(Color(1.0, 0.7, 0.15, 0.28), Color(1.0, 0.55, 0.08), 3.2)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_glow.visible = false
	add_child(_glow)
	_laser_mesh = BoxMesh.new()
	_laser_mesh.size = Vector3.ONE
	_laser = MeshInstance3D.new()
	_laser.mesh = _laser_mesh
	_laser_mat = _make_mat(Color(1.0, 0.22, 0.08, 0.92), Color(1.0, 0.28, 0.06), 4.5)
	_laser.material_override = _laser_mat
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_laser.position.y = 1.28
	add_child(_laser)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.13
	pip_mesh.height = 0.26
	pip_mesh.radial_segments = 10
	pip_mesh.rings = 6
	_pip = MeshInstance3D.new()
	_pip.mesh = pip_mesh
	_pip_mat = _make_mat(Color(1.0, 0.35, 0.08, 0.95), Color(1.0, 0.4, 0.08), 6.0)
	_pip.material_override = _pip_mat
	_pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pip.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_pip)


func _make_mat(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat


func _launch(p_source: Unit, p_target: Unit) -> void:
	_build_visuals()
	source = p_source
	target = p_target
	elapsed = 0.0
	firing = false
	finished = false
	tick_index = 0
	_tick_timer = 0.0
	channel_duration = DURATION
	_max_ticks = TICKS
	_end = Vector3.ZERO
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	set_physics_process(true)
	if _laser:
		_laser.visible = true
	if _pip:
		_pip.visible = true
	if _beam:
		_beam.visible = false
	if _glow:
		_glow.visible = false
	var ai := _source_ai()
	if ai != null and ai.in_phase2():
		channel_duration = DURATION * (1.0 + CombatBalance.pct("dawnwarden.p2.judgment"))
	_max_ticks = maxi(int(round(channel_duration / TICK_INTERVAL)), 1)
	FxHeroLights.bind(self, Color(1.0, 0.78, 0.22), 1.6, 6.0)
	if source and is_instance_valid(source):
		AbilityFx.play_at(AbilityFx.FIRE_CAST, source.global_position + Vector3(0, 1.65, 0), {
			"scale": 1.1,
			"lifetime": 0.85,
		})
		AudioManager.play_at("dawnwarden.ray.warn", source.global_position + Vector3(0, 1.65, 0))


func _stash() -> void:
	finished = true
	firing = false
	source = null
	target = null
	visible = false
	set_process(false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	global_position = _STASH
	if _beam:
		_beam.visible = false
	if _glow:
		_glow.visible = false
	if _laser:
		_laser.visible = false
	if _pip:
		_pip.visible = false
	FxHeroLights.unbind(self)
	var idx := _live.find(self)
	if idx >= 0:
		_live.remove_at(idx)
	if not _idle.has(self):
		_idle.append(self)


func _process(_delta: float) -> void:
	if finished:
		return
	_update_visual()


func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	_refresh_end()
	if not firing:
		if elapsed >= WARNING:
			_begin_channel()
		return
	_tick_timer += delta
	while _tick_timer >= TICK_INTERVAL and tick_index < _max_ticks and not finished:
		_tick_timer -= TICK_INTERVAL
		_apply_tick()
		tick_index += 1
	if tick_index >= _max_ticks or elapsed >= WARNING + channel_duration:
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
		ai.begin_ability("Judgment Ray", channel_duration, Color(1.0, 0.82, 0.28), false)
	_play_fire_fx()
	_apply_tick()
	tick_index += 1


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
	var hit := _soak_hit()
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is Unit:
			_hit_player(col as Unit)
			return
		if col is ArenaPillar:
			var pillar := col as ArenaPillar
			if pillar.living:
				_hit_pillar(pillar)
				if tick_index == 0 or tick_index == 5:
					AbilityFx.play_at(AbilityFx.FIRE_AREA, pillar.global_position + Vector3(0, 1.0, 0), {
						"area_radius": 1.6,
						"scale": 0.7,
						"lifetime": 0.7,
					})
				return
		if col is SpellWall:
			var wall := col as SpellWall
			if wall.blocks_shot(source):
				if wall.can_be_damaged_by(source):
					wall.take_hit(wall.max_health / float(TICKS), hit.get("position", wall.global_position), source, "hit")
					if tick_index == 0 or tick_index == 5:
						AbilityFx.play_at(AbilityFx.FIRE_AREA, wall.aim_point(source.global_position) + Vector3(0, 0.4, 0), {
							"area_radius": 1.6,
							"scale": 0.7,
							"lifetime": 0.7,
						})
				return
	_hit_player(target)


func _hit_pillar(pillar: ArenaPillar) -> void:
	if pillar == null or not pillar.living:
		return
	var rays := maxf(CombatBalance.flat("dawnwarden.judgment.pillar"), 0.25)
	var slice := pillar.max_health / (float(TICKS) * rays)
	pillar.take_damage(slice)


func _hit_player(victim: Unit) -> void:
	if victim == null or not is_instance_valid(victim) or victim.is_dead:
		return
	victim.apply_world_hit(_tick_damage_for(victim), source, "hit", "judgment", -1, true)
	victim.apply_judgment_brand(maxi(int(round(CombatBalance.flat("dawnwarden.brand.ray"))), 0))
	if tick_index == 0:
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, victim.global_position, {"scale": 0.85, "lifetime": 1.0})


func _soak_hit() -> Dictionary:
	var arena := ArenaState.arena as Arena
	if arena == null or source == null or target == null:
		return {}
	if not is_instance_valid(source) or not is_instance_valid(target):
		return {}
	return arena.beam_soak_hit(source.global_position, target.global_position, [source.get_rid()], 1.05, source)


func _refresh_end() -> void:
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var to := target.global_position + Vector3(0, 1.05, 0)
	if not firing:
		_end = to
		return
	var hit := _soak_hit()
	if hit.is_empty():
		_end = to
		return
	var at: Vector3 = hit.get("position", to)
	_end = Vector3(at.x, to.y, at.z)


func _update_visual() -> void:
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var from := source.global_position + Vector3(0, 1.35, 0)
	var to := _end if _end != Vector3.ZERO else (target.global_position + Vector3(0, 1.05, 0))
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
		_beam.scale = Vector3(0.55, 0.55, length)
		_beam.position = Vector3(0, 1.25, 0)
		if _glow:
			_glow.scale = Vector3(1.15, 0.7, length)
			_glow.position = Vector3(0, 1.25, 0)
		return
	var lock_u := clampf(elapsed / WARNING, 0.0, 1.0)
	var pulse := 0.55 + 0.45 * sin(elapsed * 18.0)
	var thick := lerpf(0.04, 0.09, lock_u) * (0.82 + 0.18 * pulse)
	if _laser:
		_laser.scale = Vector3(thick, thick, length)
		_laser.position = Vector3(0, 1.28, 0)
	if _laser_mat:
		_laser_mat.albedo_color.a = 0.55 + 0.4 * lock_u
		_laser_mat.emission_energy_multiplier = 3.2 + 6.5 * lock_u + pulse
	if _pip:
		_pip.position = Vector3(0, 1.08, -length * 0.5)
		_pip.scale = Vector3.ONE * (0.7 + 0.55 * lock_u + 0.12 * pulse)
	if _pip_mat:
		_pip_mat.emission_energy_multiplier = 4.0 + 7.0 * lock_u


func _play_fire_fx() -> void:
	if source == null or not is_instance_valid(source):
		return
	AbilityFx.play_at(AbilityFx.FIRE_CAST, source.global_position + Vector3(0, 1.7, 0), {
		"scale": 1.15,
		"lifetime": 0.85,
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
	FxHeroLights.unbind(self)
	_stash()
