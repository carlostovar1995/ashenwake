class_name PillarBattery
extends Node

## One runner for all armed Dawnwarden pillars. Guns stay quiet while pillars
## rise. After they plant, every living pillar walks a full 360° at a fixed
## 21° step. Random start yaw and turn sign so lanes do not line up.
## Each combat bolt is preceded by a 0.5s mini-sun drop into the glass.

enum Phase {
	WARMUP,
	FIRING,
}

## 2 Hz around the barrel. Shots leave the seated mirror face.
const SHOT_INTERVAL := 0.5
const STEP := deg_to_rad(21.0)
const TURN_SPEED := STEP / SHOT_INTERVAL

var _phase: Phase = Phase.WARMUP
var _yaw: PackedFloat32Array = PackedFloat32Array()
var _turn: PackedFloat32Array = PackedFloat32Array()
var _shot_wait: PackedFloat32Array = PackedFloat32Array()
var _started: bool = false
var _active: bool = false


func activate() -> void:
	_started = true
	_active = true
	_phase = Phase.WARMUP
	_reset_guns()


func on_planted() -> void:
	if not _started:
		return
	_active = true
	_arm_living(true)
	_snap_aim()
	_open_planted_volleys()
	if _phase == Phase.WARMUP:
		_phase = Phase.FIRING


func pause() -> void:
	_active = false
	_arm_living(false)
	_stop_feeds()


func resume() -> void:
	if not _started:
		return
	_active = true
	_arm_living(true)
	_windup_volleys()


func stop() -> void:
	_started = false
	_active = false
	_arm_living(false)
	_stop_feeds()


func _physics_process(delta: float) -> void:
	if not _active or not GameSession.fight_started:
		return
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var pillars := arena.all_pillars()
	_ensure_slots(pillars.size())
	if _phase != Phase.FIRING:
		return
	for i in pillars.size():
		var pillar := pillars[i]
		if pillar == null or not is_instance_valid(pillar) or not pillar.living or not pillar.armed:
			continue
		var aim := Vector3(cos(_yaw[i]), 0.0, sin(_yaw[i]))
		pillar.turn_toward(aim, delta, TURN_SPEED)
		_shot_wait[i] -= delta
		if _shot_wait[i] > 0.0:
			continue
		_shot_wait[i] = SHOT_INTERVAL
		_fire(pillar, i)


func _reset_guns() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var n := arena.all_pillars().size()
	_yaw.clear()
	_turn.clear()
	_shot_wait.clear()
	_ensure_slots(n)


func _ensure_slots(n: int) -> void:
	while _yaw.size() < n:
		_yaw.append(randf() * TAU)
		_turn.append(-1.0 if randf() < 0.5 else 1.0)
		_shot_wait.append(SHOT_INTERVAL)


func _arm_living(on: bool) -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	for pillar in arena.all_pillars():
		if pillar == null or not is_instance_valid(pillar):
			continue
		if on and not pillar.living:
			continue
		pillar.set_armed(on and pillar.living)


func _open_planted_volleys() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var pillars := arena.all_pillars()
	_ensure_slots(pillars.size())
	for i in pillars.size():
		var pillar := pillars[i]
		if pillar == null or not is_instance_valid(pillar) or not pillar.living:
			continue
		if pillar.consume_opening_shot():
			_shot_wait[i] = 0.0


func _windup_volleys() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var pillars := arena.all_pillars()
	_ensure_slots(pillars.size())
	for i in pillars.size():
		var pillar := pillars[i]
		if pillar == null or not is_instance_valid(pillar) or not pillar.living:
			continue
		pillar.pulse_feed()
		_shot_wait[i] = SHOT_INTERVAL


func _stop_feeds() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	for pillar in arena.all_pillars():
		if pillar == null or not is_instance_valid(pillar):
			continue
		pillar.stop_feed()


func _snap_aim() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var pillars := arena.all_pillars()
	_ensure_slots(pillars.size())
	for i in pillars.size():
		var pillar := pillars[i]
		if pillar == null or not is_instance_valid(pillar) or not pillar.living:
			continue
		pillar.aim_along(Vector3(cos(_yaw[i]), 0.0, sin(_yaw[i])))


func _fire(pillar: ArenaPillar, index: int) -> void:
	var yaw := _yaw[index]
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	pillar.aim_along(dir)
	_spawn_shot(pillar, dir)
	## Next drop leaves the mini-sun now so it hits when this cadence repeats.
	pillar.pulse_feed()
	_yaw[index] = yaw + _turn[index] * STEP


func _spawn_shot(pillar: ArenaPillar, dir: Vector3) -> void:
	var origin := pillar.shot_origin() + dir * 0.25
	PillarShot.fire(origin, dir, ArenaState.boss, pillar)
