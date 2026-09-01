class_name DawnwardenAI
extends BossAI

const JudgmentBeamScript := preload("res://scripts/combat/judgment_beam.gd")
const COLLAPSE_FIRST := 16.0
const COLLAPSE_P1 := 28.0
const COLLAPSE_P2 := 20.0
const ECHO_FIRST := 22.0
const ECHO_P1 := 50.0
const ECHO_P2 := 40.0
const ECHO_CAST := 1.55
const ECHO_GROUP := "solar_echo"

var _collapse_cd: float = COLLAPSE_FIRST
var _collapsing: bool = false
var _echo_cd: float = ECHO_FIRST
var _echoing: bool = false


func _ready() -> void:
	set_physics_process(false)
	_cycle = 1.4


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled:
		return
	if unit.is_dead:
		return
	_tick_ability_display(delta)
	if not _phase2 and unit.health <= unit.max_health * 0.5:
		_enter_phase2()
	if unit.is_stunned():
		return
	if _collapsing or _echoing:
		return
	var target := _pick_target()
	if target == null:
		return
	if unit.in_range_of(target, 0.4):
		unit.controller.ai_attack(target)
	else:
		unit.controller.ai_move(target.global_position)
	_collapse_cd -= delta
	_echo_cd -= delta
	if _collapse_cd <= 0.0:
		_fire_collapse()
		return
	if _echo_cd <= 0.0 and _collapse_cd > 8.0:
		_fire_echoes()
		return
	_cycle -= delta
	if _cycle > 0.0:
		return
	_fire_ability(target)
	_cycle = [3.2, 4.0, 5.5][_index]
	_index = (_index + 1) % 3


func _pick_target() -> Unit:
	return ThreatTable.pick_target(unit)


func _random_non_tank() -> Unit:
	var tank := ArenaState.tank()
	var choices: Array[Unit] = []
	for u in ArenaState.living_allies():
		if u == tank or not u.can_be_aggroed():
			continue
		choices.append(u)
	if choices.is_empty():
		return _pick_target()
	return choices[randi() % choices.size()]


func _fire_ability(_target: Unit) -> void:
	var tank := _pick_target()
	match _index:
		0:
			if tank == null:
				return
			var forward := (tank.global_position - unit.global_position).slide(Vector3.UP)
			if forward.length_squared() < 0.001:
				forward = unit.facing_dir()
			begin_ability("Searing Cleave", 0.9, Color(1.0, 0.55, 0.12))
			var cleave := Telegraph.cone_cleave(unit, unit.global_position, forward.normalized(), 6.4, deg_to_rad(95.0), 0.9, 90.0)
			cleave.color = Color(1.0, 0.38, 0.04, 1.0)
			cleave.warn_vfx = AbilityFx.FIRE_CAST
			cleave.warn_vfx_cfg = {"scale": 2.0, "lifetime": 1.2, "look": forward.normalized()}
			cleave.vfx_scene = AbilityFx.GROUND_EXPLOSION
			cleave.vfx_cfg = {"scale": 2.2, "lifetime": 2.1, "look": forward.normalized()}
			cleave.sfx_warn = "boss.telegraph.warn"
			cleave.sfx_impact = "dawnwarden.cleave"
		1:
			var marked := _random_non_tank()
			if marked == null:
				return
			begin_ability("Sunspot", 1.2, Color(1.0, 0.72, 0.18))
			var slam := Telegraph.circle_slam(unit, marked.global_position, 3.8, 1.2, 140.0)
			slam.color = Color(1.0, 0.32, 0.04, 1.0)
			slam.warn_vfx = AbilityFx.FIRE_AREA
			slam.warn_vfx_cfg = {"area_radius": 3.8, "scale": 1.45, "lifetime": 1.45}
			slam.vfx_scene = AbilityFx.GROUND_EXPLOSION
			slam.vfx_cfg = {"scale": 2.5, "lifetime": 2.3}
			slam.sfx_warn = "boss.telegraph.warn"
			slam.sfx_impact = "dawnwarden.sunspot"
		2:
			var locked := _random_non_tank()
			if locked == null:
				return
			begin_ability("Judgment Ray", JudgmentBeamScript.WARNING, Color(1.0, 0.82, 0.28), true)
			JudgmentBeamScript.fire(unit, locked)


func _fire_collapse() -> void:
	_collapsing = true
	_collapse_cd = COLLAPSE_P2 if _phase2 else COLLAPSE_P1
	begin_ability("Solar Collapse", 4.5, Color(1.0, 0.88, 0.35), false)
	Telegraph.solar_collapse(unit, 4.5, 9999.0)
	var tree := get_tree()
	if tree:
		await tree.create_timer(4.65).timeout
	if not is_instance_valid(self):
		return
	_collapsing = false


func freeze_is_deferred() -> bool:
	return _collapsing or _echoing or super.freeze_is_deferred()


func _enter_phase2() -> void:
	_phase2 = true
	unit.attack_damage *= 1.1
	if _collapse_cd > COLLAPSE_P2:
		_collapse_cd = COLLAPSE_P2
	if _echo_cd > ECHO_P2:
		_echo_cd = ECHO_P2


func _fire_echoes() -> void:
	var arena := ArenaState.arena as Arena
	var pillars: Array[ArenaPillar] = []
	if arena:
		pillars = arena.living_pillars()
	if pillars.is_empty():
		_echo_cd = 8.0
		return
	if _living_echo_count() >= maxi(pillars.size() * 2, 4):
		_echo_cd = 5.0
		return
	_echoing = true
	_echo_cd = ECHO_P2 if _phase2 else ECHO_P1
	begin_ability("Solar Echoes", ECHO_CAST, Color(1.0, 0.42, 0.12), false)
	AbilityFx.play_at(AbilityFx.FIRE_CAST, unit.global_position + Vector3(0.0, 1.35, 0.0), {
		"scale": 2.4,
		"lifetime": 1.9,
	})
	AudioManager.play_at("fire.cast", unit.global_position + Vector3(0.0, 1.65, 0.0))
	var tree := get_tree()
	if tree:
		await tree.create_timer(ECHO_CAST).timeout
	if not is_instance_valid(self) or unit == null or not is_instance_valid(unit) or unit.is_dead:
		_echoing = false
		return
	if ArenaState.arena and ArenaState.arena.has_method("spawn_dawnwarden_echoes"):
		ArenaState.arena.spawn_dawnwarden_echoes()
	_echoing = false


func _living_echo_count() -> int:
	var n := 0
	var tree := get_tree()
	if tree == null:
		return 0
	for node in tree.get_nodes_in_group(ECHO_GROUP):
		var u := node as Unit
		if u != null and is_instance_valid(u) and not u.is_dead:
			n += 1
	return n
