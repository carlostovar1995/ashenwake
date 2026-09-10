class_name DawnwardenAI
extends BossAI

const JudgmentBeamScript := preload("res://scripts/combat/judgment_beam.gd")

enum Seq {
	WAIT_SLAM,
	WAIT_RAY,
	WAIT_NOVA,
}

var _engaged: bool = false
var _casting: bool = false
var _pillar_cast: bool = false
var _seq: Seq = Seq.WAIT_SLAM
var _seq_left: float = 0.0
var _execute: bool = false


func _ready() -> void:
	set_physics_process(false)
	_cycle = 1.4
	if unit != null and not unit.damaged.is_connected(_on_boss_damaged):
		unit.damaged.connect(_on_boss_damaged)


func _physics_process(delta: float) -> void:
	if not GameSession.fight_started or not unit.ai_enabled:
		return
	if unit.is_dead:
		return
	_tick_ability_display(delta)
	if not _engaged:
		_try_pull()
		return
	if not _phase2 and unit.health <= unit.max_health * 0.5:
		_enter_phase2()
	if not _execute and unit.health <= unit.max_health * CombatBalance.pct("dawnwarden.execute.hp"):
		_enter_execute()
	if unit.is_stunned():
		return
	if _casting:
		return
	_seq_left -= delta
	if _seq_left > 0.0:
		_chase()
		return
	_run_sequence()


func freeze_is_deferred() -> bool:
	return _casting or _pillar_cast or super.freeze_is_deferred()


func _try_pull() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var ring := arena.pillar_ring_radius()
	for ally in ArenaState.living_allies():
		var u := ally as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		var d := Vector2(u.global_position.x - unit.global_position.x, u.global_position.z - unit.global_position.z).length()
		if d <= ring:
			_engage()
			return


func _on_boss_damaged(_victim: Unit, _amount: float, source: Node3D, _spell_id: String = "") -> void:
	if _engaged:
		return
	var src := source as Unit
	if src == null or not is_instance_valid(src) or src.team != Unit.TEAM_RAID:
		return
	_engage()


func _engage() -> void:
	if _engaged:
		return
	_engaged = true
	var arena := ArenaState.arena as Arena
	if arena:
		arena.engage_dawnwarden()
	_raise_pillars(false)


func _raise_pillars(destroyed_only: bool) -> void:
	if _pillar_cast:
		return
	_pillar_cast = true
	_casting = true
	_root_cast()
	var dur := CombatBalance.flat("dawnwarden.pillar.warmup")
	begin_ability("Raise Pillars", dur, Color(1.0, 0.78, 0.28), false)
	var arena := ArenaState.arena as Arena
	if arena:
		arena.raise_dawnwarden_pillars(destroyed_only)
	var tree := get_tree()
	if tree:
		await tree.create_timer(dur).timeout
	if not is_instance_valid(self):
		return
	if arena:
		arena.plant_dawnwarden_pillars()
	_pillar_cast = false
	_casting = false
	_seq = Seq.WAIT_SLAM
	_seq_left = CombatBalance.flat("dawnwarden.seq.slam")
	if destroyed_only:
		_resume_pillars()


func _release_cast() -> bool:
	if _pillar_cast:
		return false
	_casting = false
	return true


func _run_sequence() -> void:
	match _seq:
		Seq.WAIT_SLAM:
			_fire_slam_and_sunspot()
		Seq.WAIT_RAY:
			_fire_dual_ray()
		Seq.WAIT_NOVA:
			_fire_corona()
		_:
			_seq = Seq.WAIT_SLAM
			_seq_left = CombatBalance.flat("dawnwarden.seq.slam")


func _chase() -> void:
	var target := _pick_target()
	if target == null:
		return
	unit.controller.ai_attack(target)


func _pick_target() -> Unit:
	return ThreatTable.pick_target(unit)


func _non_tank_raid() -> Array[Unit]:
	var skip := ThreatTable.aggro_holder(unit)
	if skip == null:
		skip = ArenaState.tank()
	var choices: Array[Unit] = []
	for u in ArenaState.living_allies():
		if u == skip or not u.can_be_aggroed():
			continue
		choices.append(u)
	return choices


func _aggro_target() -> Unit:
	var holder := ThreatTable.aggro_holder(unit)
	if holder != null:
		return holder
	return _pick_target()


func _cleave_damage() -> float:
	var amount := CombatBalance.flat("dawnwarden.cleave")
	if _phase2:
		amount *= 2.0
	return amount


func _cleave_brand() -> int:
	var stacks := maxi(int(round(CombatBalance.flat("dawnwarden.brand.cleave"))), 0)
	if _phase2:
		stacks *= 2
	return stacks


func _sunspot_radius() -> float:
	var r := CombatBalance.flat("dawnwarden.sunspot.radius")
	if _phase2:
		r *= 1.0 + CombatBalance.pct("dawnwarden.p2.sunspot")
	return r


func _fire_slam_and_sunspot() -> void:
	_casting = true
	var warn := CombatBalance.flat("dawnwarden.cleave.warn")
	var spot_warn := 1.2
	begin_ability("Searing Cleave", maxf(warn, spot_warn), Color(1.0, 0.55, 0.12), false)
	var tank := _aggro_target()
	if tank != null:
		var toward := (tank.global_position - unit.global_position).slide(Vector3.UP)
		if toward.length_squared() < 0.001:
			toward = unit.facing_dir()
		else:
			toward = toward.normalized()
		unit.snap_facing(toward)
		var radius := CombatBalance.flat("dawnwarden.cleave.radius")
		var angle := deg_to_rad(CombatBalance.flat("dawnwarden.cleave.angle"))
		var forward := unit.facing_dir()
		var cleave := Telegraph.cone_cleave(unit, unit.global_position, forward, radius, angle, warn, _cleave_damage())
		cleave.color = Color(1.0, 0.38, 0.04, 1.0)
		cleave.judgment_stacks = _cleave_brand()
		cleave.pillar_flat_damage = _cleave_damage()
		cleave.warn_vfx = AbilityFx.FIRE_CAST
		cleave.warn_vfx_cfg = {"scale": 1.15, "lifetime": 0.85, "look": forward}
		cleave.vfx_scene = AbilityFx.GROUND_EXPLOSION
		cleave.vfx_cfg = {"scale": 1.2, "lifetime": 1.1, "look": forward}
		cleave.sfx_warn = "boss.telegraph.warn"
		cleave.sfx_impact = "dawnwarden.cleave"
	var marked := _non_tank_raid()
	var spot_r := _sunspot_radius()
	var spot_dmg := CombatBalance.flat("dawnwarden.sunspot")
	var brand := maxi(int(round(CombatBalance.flat("dawnwarden.brand.sunspot"))), 0)
	for victim in marked:
		if victim == null or not is_instance_valid(victim) or victim.is_dead:
			continue
		var slam := Telegraph.circle_slam(unit, victim.global_position, spot_r, spot_warn, spot_dmg)
		slam.ability_id = "sunspot"
		slam.color = Color(1.0, 0.32, 0.04, 1.0)
		slam.judgment_stacks = brand
		slam.pillar_flat_damage = spot_dmg
		slam.vfx_scene = AbilityFx.GROUND_EXPLOSION
		slam.vfx_cfg = {"scale": 1.1, "lifetime": 1.1}
		slam.sfx_warn = "boss.telegraph.warn"
		slam.sfx_impact = "dawnwarden.sunspot"
	var tree := get_tree()
	if tree:
		await tree.create_timer(maxf(warn, spot_warn) + 0.05).timeout
	if not is_instance_valid(self):
		return
	if not _release_cast():
		return
	_seq = Seq.WAIT_RAY
	_seq_left = CombatBalance.flat("dawnwarden.seq.ray")


func _fire_dual_ray() -> void:
	_casting = true
	_root_cast()
	var picks := _ray_targets()
	var channel := JudgmentBeamScript.DURATION
	if _phase2:
		channel *= 1.0 + CombatBalance.pct("dawnwarden.p2.judgment")
	begin_ability("Judgment Ray", JudgmentBeamScript.WARNING + channel, Color(1.0, 0.82, 0.28), true)
	for locked in picks:
		JudgmentBeamScript.fire(unit, locked)
	var tree := get_tree()
	if tree:
		await tree.create_timer(JudgmentBeamScript.WARNING + channel + 0.1).timeout
	if not is_instance_valid(self):
		return
	if not _release_cast():
		return
	_seq = Seq.WAIT_NOVA
	_seq_left = CombatBalance.flat("dawnwarden.seq.nova")


func _ray_targets() -> Array[Unit]:
	if GameSession.dev_test_mode:
		var you := GameSession.active_unit as Unit
		if you != null and is_instance_valid(you) and not you.is_dead and you.team == Unit.TEAM_RAID:
			return [you, you]
	var pool := _non_tank_raid()
	if pool.size() < 2:
		var tank := _aggro_target()
		if tank != null and not pool.has(tank):
			pool.append(tank)
	var picks: Array[Unit] = []
	while picks.size() < 2 and not pool.is_empty():
		var idx := randi() % pool.size()
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks


func _fire_corona() -> void:
	_casting = true
	_pause_pillars()
	_go_to_center()
	var cast := CombatBalance.flat("dawnwarden.corona.cast")
	begin_ability("Solar Corona", cast, Color(1.0, 0.42, 0.08), false)
	var corona := Telegraph.solar_corona(unit, cast, CombatBalance.flat("dawnwarden.corona.damage"))
	corona.judgment_stacks = maxi(int(round(CombatBalance.flat("dawnwarden.brand.corona"))), 0)
	corona.pillar_flat_damage = CombatBalance.flat("dawnwarden.corona.damage")
	var tree := get_tree()
	if tree:
		await tree.create_timer(cast + 0.05).timeout
	if not is_instance_valid(self) or unit == null or not is_instance_valid(unit) or unit.is_dead:
		_resume_pillars()
		_release_cast()
		return
	if _pillar_cast:
		return
	_fire_collapse()


func _fire_collapse() -> void:
	_root_cast()
	var cast := CombatBalance.flat("dawnwarden.collapse.cast")
	begin_ability("Solar Collapse", cast, Color(1.0, 0.88, 0.35), false)
	var collapse := Telegraph.solar_collapse(unit, cast, CombatBalance.flat("dawnwarden.collapse.damage"))
	collapse.judgment_stacks = maxi(int(round(CombatBalance.flat("dawnwarden.brand.collapse"))), 0)
	collapse.pillar_flat_damage = CombatBalance.flat("dawnwarden.collapse.damage")
	var tree := get_tree()
	if tree:
		await tree.create_timer(cast + 0.05).timeout
	if not is_instance_valid(self):
		return
	_resume_pillars()
	if not _release_cast():
		return
	_seq = Seq.WAIT_SLAM
	_seq_left = CombatBalance.flat("dawnwarden.seq.slam")


func _root_cast() -> void:
	if unit == null or not is_instance_valid(unit) or unit.controller == null:
		return
	unit.controller.ai_stop()


func _go_to_center() -> void:
	if unit == null or not is_instance_valid(unit) or unit.controller == null:
		return
	var dest := Vector3.ZERO
	var arena := ArenaState.arena as Arena
	if arena != null:
		dest = arena.global_position
	dest.y = unit.global_position.y
	var dx := unit.global_position.x - dest.x
	var dz := unit.global_position.z - dest.z
	if dx * dx + dz * dz <= 0.55 * 0.55:
		unit.controller.ai_stop()
		return
	unit.controller.ai_move(dest)


func _pause_pillars() -> void:
	var arena := ArenaState.arena as Arena
	if arena:
		arena.pause_dawnwarden_pillars()


func _resume_pillars() -> void:
	var arena := ArenaState.arena as Arena
	if arena:
		arena.resume_dawnwarden_pillars()


func _enter_phase2() -> void:
	_phase2 = true


func _enter_execute() -> void:
	_execute = true
	var arena := ArenaState.arena as Arena
	if arena:
		arena.double_raid_judgment()
	_raise_pillars(true)
