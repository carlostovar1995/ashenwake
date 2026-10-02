extends Node
## Worst-case overlap perf run. Training arena, 60 chase dummies piled on the
## champion, and five scripted casters (the champion plus four helpers) cycling
## every spell base with no cooldowns, so ground AoEs, lightning, walls,
## projectiles, HUD and damage numbers are all live at once.
##
## Needs a real renderer: draw calls and GPU time read 0 under --headless.
## Run through tools/baseline-perf.ps1. Writes tools/out/perf.json.
##
## Args after `--`: --seconds=30 --warmup=6 --dummies=60 --seed=1337

const Harness := preload("res://tools/baseline/harness.gd")
const CastDriver := preload("res://tools/baseline/cast_driver.gd")

const COUNT_INTERVAL := 0.25
## The engine updates TIME_PROCESS / TIME_PHYSICS_PROCESS about once a second and
## holds the worst frame of that second, so they are sampled at that rate.
const SCRIPT_MONITOR_INTERVAL := 1.0
const AIM_RADIUS := 3.5
const AIM_POINTS := 8
const AIM_STEP_TICKS := 30
const HELPER_RING := 2.4
const HITCH_MS := 100.0
const MAX_HITCHES := 12
const FRAME_BUDGET_MS := 1000.0 / 60.0
const MONITOR_PREFIX := "ashenwake/"

var _seconds: float = 30.0
var _warmup: float = 6.0
var _dummies: int = 60
var _seed: int = 1337

var _ready_to_run: bool = false
var _phase: String = "warmup"
var _phase_start_us: int = 0
var _last_frame_us: int = 0
var _ticks: int = 0
var _drivers: Array = []
var _casters: Array[Unit] = []
var _counts: Dictionary = {}
var _count_clock: float = 0.0
var _script_clock: float = 0.0
var _viewport_rid: RID

var _frame_ms := PackedFloat64Array()
var _process_ms := PackedFloat64Array()
var _physics_ms := PackedFloat64Array()
var _render_cpu_ms := PackedFloat64Array()
var _render_gpu_ms := PackedFloat64Array()
var _draw_calls := PackedFloat64Array()
var _primitives := PackedFloat64Array()
var _render_objects := PackedFloat64Array()
var _count_series: Dictionary = {}
var _hitches: Array[Dictionary] = []
var _walls_seen: Dictionary = {}
var _walls_peak: int = 0


func _ready() -> void:
	var opts := Harness.args()
	_seconds = float(opts.get("seconds", _seconds))
	_warmup = float(opts.get("warmup", _warmup))
	_dummies = int(opts.get("dummies", _dummies))
	_seed = int(opts.get("seed", _seed))
	seed(_seed)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_register_monitors()
	_run()


func _run() -> void:
	await Harness.boot(self, true)
	_spawn_dummies()
	for i in 60:
		await get_tree().process_frame
	_harden_dummies()
	_spawn_helpers()
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	_phase_start_us = Time.get_ticks_usec()
	_last_frame_us = _phase_start_us
	_ready_to_run = true
	print(
		(
			"baseline-perf: warmup %.0fs then measuring %.0fs (%d chase dummies, %d casters)"
			% [_warmup, _seconds, _dummies, _casters.size()]
		)
	)


func _spawn_dummies() -> void:
	var arena := ArenaState.arena
	arena._chase_spawns_left = _dummies


## Chase dummies despawn on death; keep all of them alive so the count is fixed.
func _harden_dummies() -> void:
	for enemy in ArenaState.enemies:
		enemy.immortal = true
		enemy.max_health = 1.0e9
		enemy.health = 1.0e9


func _spawn_helpers() -> void:
	var arena := ArenaState.arena
	var champion := ArenaState.champion
	Harness.equip(champion, 0, true)
	_casters.append(champion)
	var names := ["Bulwark", "Mend", "Hex", "Vex"]
	for i in names.size():
		var angle := TAU * float(i) / float(names.size())
		var pos := champion.global_position + Vector3(cos(angle), 0.0, sin(angle)) * HELPER_RING
		var stats := {"max_health": 1.0e6, "max_mana": 1.0e5, "radius": 0.45}
		var helper: Unit = arena._spawn_ally(names[i], "dps", Color(0.7, 0.7, 0.9), pos, stats)
		helper.set_ai_enabled(false)
		Harness.equip(helper, i + 1, true)
		_casters.append(helper)
	for caster in _casters:
		_drivers.append(CastDriver.new(caster))


func _physics_process(delta: float) -> void:
	if not _ready_to_run:
		return
	_ticks += 1
	_track_walls()
	var champion := ArenaState.champion
	var centre := champion.global_position
	var enemies := ArenaState.enemies
	for i in _drivers.size():
		var step := (_ticks / AIM_STEP_TICKS + i * 3) % AIM_POINTS
		var angle := TAU * float(step) / float(AIM_POINTS)
		var point := centre + Vector3(cos(angle), 0.0, sin(angle)) * AIM_RADIUS
		var hostile: Unit = null
		if not enemies.is_empty():
			hostile = enemies[(_ticks / AIM_STEP_TICKS * 5 + i * 11) % enemies.size()]
		_drivers[i].tick(delta, hostile, point, _casters[(i + 1) % _casters.size()])


## Walls can live and die between count samples, so count spawns every tick.
func _track_walls() -> void:
	var live := get_tree().get_nodes_in_group("spell_walls")
	_walls_peak = maxi(_walls_peak, live.size())
	for wall in live:
		_walls_seen[wall.get_instance_id()] = true


func _process(delta: float) -> void:
	if not _ready_to_run:
		return
	var now_us := Time.get_ticks_usec()
	var frame_ms := float(now_us - _last_frame_us) / 1000.0
	_last_frame_us = now_us
	_count_clock += delta
	_script_clock += delta
	if _script_clock >= SCRIPT_MONITOR_INTERVAL:
		_script_clock = 0.0
		if _phase == "measure":
			_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if _count_clock >= COUNT_INTERVAL:
		_count_clock = 0.0
		_refresh_counts()
		if _phase == "measure":
			_record_counts()
	var elapsed := float(now_us - _phase_start_us) / 1000000.0
	if _phase == "warmup":
		if elapsed >= _warmup:
			_phase = "measure"
			_phase_start_us = now_us
			print("baseline-perf: measuring")
		return
	_frame_ms.append(frame_ms)
	if frame_ms > HITCH_MS and _hitches.size() < MAX_HITCHES:
		_hitches.append({"at_s": _r(elapsed), "ms": _r(frame_ms)})
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_render_objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	_render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid))
	_render_gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid))
	if elapsed >= _seconds:
		_ready_to_run = false
		_finish()


# --- live counts, exposed as custom Performance monitors ---------------------


func _register_monitors() -> void:
	for key in [
		"particle_systems", "particle_budget", "projectiles", "spell_walls", "telegraphs", "units"
	]:
		_counts[key] = 0
		Performance.add_custom_monitor(MONITOR_PREFIX + key, _read_count.bind(key))


func _read_count(key: String) -> int:
	return int(_counts.get(key, 0))


## Walks the tree four times a second; the monitors return the cached result.
func _refresh_counts() -> void:
	var systems := 0
	var budget := 0
	var projectiles := 0
	var walls := 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is GPUParticles3D:
			var gpu := node as GPUParticles3D
			if gpu.emitting and gpu.is_visible_in_tree():
				systems += 1
				budget += gpu.amount
		elif node is CPUParticles3D:
			var cpu := node as CPUParticles3D
			if cpu.emitting and cpu.is_visible_in_tree():
				systems += 1
				budget += cpu.amount
		elif node is Projectile:
			projectiles += 1
		elif node is SpellWall:
			walls += 1
		for child in node.get_children():
			stack.append(child)
	_counts["particle_systems"] = systems
	_counts["particle_budget"] = budget
	_counts["projectiles"] = projectiles
	_counts["spell_walls"] = walls
	_counts["telegraphs"] = ArenaState.telegraphs.size()
	_counts["units"] = ArenaState.units.size()


func _record_counts() -> void:
	for key in _counts.keys():
		_push_series(key, float(Performance.get_custom_monitor(MONITOR_PREFIX + key)))
	_push_series("objects", Performance.get_monitor(Performance.OBJECT_COUNT))
	_push_series("nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_push_series("orphan_nodes", Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_push_series("resources", Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	_push_series("static_memory_mb", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_push_series(
		"video_memory_mb", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	)


func _push_series(key: String, value: float) -> void:
	var series: PackedFloat64Array = _count_series.get(key, PackedFloat64Array())
	series.append(value)
	_count_series[key] = series


# --- report ------------------------------------------------------------------


func _stats(series: PackedFloat64Array) -> Dictionary:
	if series.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted := series.duplicate()
	sorted.sort()
	var total := 0.0
	for value in series:
		total += value
	return {
		"mean": _r(total / float(series.size())),
		"p50": _r(sorted[int(float(sorted.size() - 1) * 0.50)]),
		"p95": _r(sorted[int(float(sorted.size() - 1) * 0.95)]),
		"p99": _r(sorted[int(float(sorted.size() - 1) * 0.99)]),
		"max": _r(sorted[sorted.size() - 1]),
	}


func _r(value: float) -> float:
	return snappedf(value, 0.001)


func _count_summary(series: PackedFloat64Array) -> Dictionary:
	if series.is_empty():
		return {"first": 0.0, "last": 0.0, "mean": 0.0, "max": 0.0}
	var total := 0.0
	var peak := series[0]
	for value in series:
		total += value
		peak = maxf(peak, value)
	return {
		"first": _r(series[0]),
		"last": _r(series[series.size() - 1]),
		"mean": _r(total / float(series.size())),
		"max": _r(peak),
		"slope_per_s": _r(_slope(series)),
	}


## Least-squares trend per second over the evenly spaced count samples.
func _slope(series: PackedFloat64Array) -> float:
	var n := series.size()
	if n < 2:
		return 0.0
	var mean_x := float(n - 1) * 0.5
	var mean_y := 0.0
	for value in series:
		mean_y += value
	mean_y /= float(n)
	var num := 0.0
	var den := 0.0
	for i in n:
		num += (float(i) - mean_x) * (series[i] - mean_y)
		den += (float(i) - mean_x) * (float(i) - mean_x)
	return (num / maxf(den, 0.000001)) / COUNT_INTERVAL


func _cast_totals() -> Dictionary:
	var out := {}
	for driver in _drivers:
		out[driver.unit.unit_name] = driver.casts
	return out


func _finish() -> void:
	var over_budget := 0
	var over_double := 0
	for ms in _frame_ms:
		if ms > FRAME_BUDGET_MS:
			over_budget += 1
		if ms > FRAME_BUDGET_MS * 2.0:
			over_double += 1
	var frame := _stats(_frame_ms)
	var counts := {}
	for key in _count_series.keys():
		counts[key] = _count_summary(_count_series[key])
	var report := {
		"meta":
		{
			"godot": Harness.godot_version(),
			"seed": _seed,
			"measure_seconds": _seconds,
			"warmup_seconds": _warmup,
			"frames_measured": _frame_ms.size(),
			"chase_dummies_requested": _dummies,
			"casters": _casters.size(),
			"window":
			"%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
			"renderer":
			String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")),
			"adapter": RenderingServer.get_video_adapter_name(),
			"vsync": "disabled",
			"os": OS.get_name(),
		},
		"frame_ms": frame,
		"avg_fps": _r(1000.0 / maxf(float(frame["mean"]), 0.001)),
		"frames_over_16_7ms": over_budget,
		"frames_over_33_3ms": over_double,
		"script_process_ms_worst_per_second": _stats(_process_ms),
		"script_physics_ms_worst_per_second": _stats(_physics_ms),
		"render_cpu_ms": _stats(_render_cpu_ms),
		"render_gpu_ms": _stats(_render_gpu_ms),
		"draw_calls": _stats(_draw_calls),
		"primitives": _stats(_primitives),
		"render_objects": _stats(_render_objects),
		"hitches_over_100ms": _hitches,
		"casts": _cast_totals(),
		"walls_spawned_total": _walls_seen.size(),
		"walls_live_peak": _walls_peak,
		"live_counts": counts,
	}
	var path := Harness.write_text("perf.json", JSON.stringify(report, "\t", true))
	print(
		(
			"baseline-perf: frame ms mean=%.2f p95=%.2f p99=%.2f max=%.2f (%.0f fps)"
			% [frame["mean"], frame["p95"], frame["p99"], frame["max"], report["avg_fps"]]
		)
	)
	print(
		(
			"baseline-perf: draw calls mean=%.0f max=%.0f"
			% [report["draw_calls"]["mean"], report["draw_calls"]["max"]]
		)
	)
	print(
		(
			"baseline-perf: particles max=%.0f projectiles max=%.0f walls max=%.0f objects %.0f->%.0f"
			% [
				counts["particle_systems"]["max"],
				counts["projectiles"]["max"],
				counts["spell_walls"]["max"],
				counts["objects"]["first"],
				counts["objects"]["last"]
			]
		)
	)
	print("baseline-perf: wrote %s" % path)
	get_tree().quit(0)
