class_name DawnwardenAI
extends BossAI

const JudgmentBeamScript := preload("res://scripts/combat/judgment_beam.gd")
const COLLAPSE_FIRST := 16.0
const COLLAPSE_P1 := 28.0
const COLLAPSE_P2 := 20.0

var _collapse_cd: float = COLLAPSE_FIRST
var _collapsing: bool = false


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
	if _collapsing:
		return
	var target := _pick_target()
	if target == null:
		return
	if unit.in_range_of(target, 0.4):
		unit.controller.ai_attack(target)
	else:
		unit.controller.ai_move(target.global_position)
	_collapse_cd -= delta
	if _collapse_cd <= 0.0:
		_fire_collapse()
		return
	_cycle -= delta
	if _cycle > 0.0:
		return
	_fire_ability(target)
	_cycle = [3.2, 4.0, 5.5][_index]
	_index = (_index + 1) % 3


func _pick_target() -> Unit:
	var tank := ArenaState.tank()
	if tank:
		return tank
	if ArenaState.champion and not ArenaState.champion.is_dead:
		return ArenaState.champion
	return ArenaState.nearest_enemy(unit.global_position, unit.team) as Unit


func _random_non_tank() -> Unit:
	var tank := ArenaState.tank()
	var choices: Array[Unit] = []
	for u in ArenaState.living_allies():
		if u == tank:
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
	return _collapsing or super.freeze_is_deferred()


func _enter_phase2() -> void:
	_phase2 = true
	unit.attack_damage *= 1.1
	if _collapse_cd > COLLAPSE_P2:
		_collapse_cd = COLLAPSE_P2
