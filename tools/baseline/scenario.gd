extends Node
## Scripted regression scenario: five players and the boss, fixed seed, fixed
## timeline. Logs damage / healing totals, boss threat, status applications and
## casts to tools/out/scenario.json and prints a digest that must be identical
## between two runs of the same build.
##
## Run headless through tools/baseline-scenario.ps1. With --shots it renders and
## saves PNGs of fixed moments instead (tools/baseline-shots.ps1).
##
## Args after `--`: --seconds=60 --seed=1337 --boss=colossus --phase2=1 --shots

const Harness := preload("res://tools/baseline/harness.gd")
const CastDriver := preload("res://tools/baseline/cast_driver.gd")

const CHECKPOINT_SECONDS := 10.0
const PLAYER_RING := 7.5
const PLAYER_ARC_DEG := 30.0
const BOSS_HEALTH := 1.0e9
const PHASE2_AT := 0.55
## Fixed moments for --shots: label -> simulated seconds.
const SHOT_MOMENTS := {
	"01_opening": 1.0,
	"02_first_volley": 3.0,
	"03_boss_telegraph": 7.0,
	"04_overlap_build": 12.0,
	"05_midfight": 20.0,
	"06_threat_swap": 30.0,
	"07_phase2_adds": 42.0,
	"08_late_overlap": 55.0,
}

var _seconds: float = 60.0
var _seed: int = 1337
var _boss_id: String = "colossus"
var _phase2: bool = true
var _shots: bool = false

var _running: bool = false
var _finished: bool = false
var _ticks: int = 0
var _wall_start_ms: int = 0
var _drivers: Array = []
var _roster: Array[Unit] = []
var _phase2_done: bool = false

var _damage: Dictionary = {}
var _healing: Dictionary = {}
var _taken: Dictionary = {}
var _deaths: Dictionary = {}
var _status: Dictionary = {}
var _status_prev: Dictionary = {}
var _telegraphs: Dictionary = {}
var _telegraph_seen: Dictionary = {}
var _walls_seen: Dictionary = {}
var _stack_peaks: Dictionary = {}
var _checkpoints: Array[Dictionary] = []
var _pending_shots: Array[String] = []
var _shots_done: Array[String] = []


func _ready() -> void:
	var opts := Harness.args()
	_seconds = float(opts.get("seconds", _seconds))
	_seed = int(opts.get("seed", _seed))
	_boss_id = String(opts.get("boss", _boss_id))
	_phase2 = String(opts.get("phase2", "1")) != "0"
	_shots = opts.has("shots")
	seed(_seed)
	_run()


func _run() -> void:
	await Harness.boot(self, false, _boss_id)
	Harness.silence_audio()
	_setup_roster()
	for unit in ArenaState.units:
		_watch(unit)
	ArenaState.unit_registered.connect(_watch)
	_wall_start_ms = Time.get_ticks_msec()
	_running = true
	print(
		(
			"baseline-scenario: running %.0fs seed=%d boss=%s phase2=%s"
			% [_seconds, _seed, _boss_id, _phase2]
		)
	)


func _setup_roster() -> void:
	var boss := ArenaState.boss
	boss.max_health = BOSS_HEALTH
	boss.health = BOSS_HEALTH
	_roster = Harness.players()
	var half := (_roster.size() - 1) * 0.5
	for i in _roster.size():
		var unit := _roster[i]
		unit.set_ai_enabled(false)
		Harness.equip(unit, i)
		var angle := deg_to_rad((float(i) - half) * PLAYER_ARC_DEG)
		var offset := Vector3(sin(angle), 0.0, cos(angle)) * PLAYER_RING
		unit.global_position = Vector3(
			boss.global_position.x + offset.x, 0.1, boss.global_position.z + offset.z
		)
		unit.reset_physics_interpolation()
		unit.snap_facing(boss.global_position - unit.global_position)
		_drivers.append(CastDriver.new(unit))
	GameSession.select_target(boss)


func _watch(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.damaged.is_connected(_on_damaged):
		unit.damaged.connect(_on_damaged)
	if not unit.healed.is_connected(_on_healed):
		unit.healed.connect(_on_healed)
	if not unit.died.is_connected(_on_died):
		unit.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if not _running or _finished:
		return
	_ticks += 1
	var boss := ArenaState.boss
	var point := boss.global_position if boss != null and is_instance_valid(boss) else Vector3.ZERO
	for i in _drivers.size():
		var friendly := _roster[(i + 1) % _roster.size()]
		_drivers[i].tick(delta, boss, point, friendly)
	_sample_statuses()
	_sample_telegraphs()
	_sample_walls()
	if _phase2 and not _phase2_done and sim_time() >= _seconds * PHASE2_AT:
		_phase2_done = true
		boss.health = BOSS_HEALTH * 0.49
	if _ticks % int(CHECKPOINT_SECONDS * Harness.PHYSICS_HZ) == 0:
		_checkpoint()
	if sim_time() >= _seconds:
		_finished = true
		_finish()


func _process(_delta: float) -> void:
	if not _shots or not _running:
		return
	var now := sim_time()
	for label in SHOT_MOMENTS.keys():
		if (
			now >= float(SHOT_MOMENTS[label])
			and not _shots_done.has(label)
			and not _pending_shots.has(label)
		):
			_pending_shots.append(label)
			_capture(label)


func sim_time() -> float:
	return float(_ticks) / float(Harness.PHYSICS_HZ)


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var dir := Harness.out_dir().path_join("shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("%s_%s.png" % [_boss_id, label])
	var err := image.save_png(path)
	if err != OK:
		push_error("baseline-shots: could not save %s (error %d)" % [path, err])
	else:
		print("baseline-shots: saved %s (t=%.2fs, tick=%d)" % [path, sim_time(), _ticks])
	_shots_done.append(label)


func _name_of(node: Variant) -> String:
	var unit := node as Unit
	if unit == null or not is_instance_valid(unit):
		return "world"
	return unit.unit_name


func _bump(bag: Dictionary, who: String, spell: String, amount: float) -> void:
	var by_spell: Dictionary = bag.get(who, {})
	var row: Dictionary = by_spell.get(spell, {"total": 0.0, "hits": 0})
	row["total"] = float(row["total"]) + amount
	row["hits"] = int(row["hits"]) + 1
	by_spell[spell] = row
	bag[who] = by_spell


func _on_damaged(victim: Unit, amount: float, source: Variant, spell_id: String) -> void:
	_bump(_damage, _name_of(source), AbilityDef.base_from_combat_id(spell_id), amount)
	var taken: Dictionary = _taken.get(victim.unit_name, {"total": 0.0, "hits": 0})
	taken["total"] = float(taken["total"]) + amount
	taken["hits"] = int(taken["hits"]) + 1
	_taken[victim.unit_name] = taken


func _on_healed(_target: Unit, amount: float, source: Variant, spell_id: String) -> void:
	_bump(_healing, _name_of(source), AbilityDef.base_from_combat_id(spell_id), amount)


func _on_died(unit: Unit) -> void:
	_deaths[unit.unit_name] = int(_deaths.get(unit.unit_name, 0)) + 1


func _sample_statuses() -> void:
	for unit in ArenaState.units:
		if unit == null or not is_instance_valid(unit) or unit.is_dead or unit.is_structure:
			continue
		var present := {}
		for entry in unit.collect_debuffs():
			_note_status(unit, "debuff", entry, present)
		for entry in unit.collect_buffs():
			_note_status(unit, "buff", entry, present)
		_status_prev[unit.get_instance_id()] = present
		_peak(unit, "shock", unit.shock_stacks())
		_peak(unit, "chill", unit.chill_stacks())


func _note_status(unit: Unit, kind: String, entry: Dictionary, present: Dictionary) -> void:
	var id := "%s:%s" % [kind, String(entry.get("id", "?"))]
	present[id] = true
	var prev: Dictionary = _status_prev.get(unit.get_instance_id(), {})
	var by_id: Dictionary = _status.get(unit.unit_name, {})
	var row: Dictionary = by_id.get(id, {"applications": 0, "max_stacks": 0})
	if not prev.has(id):
		row["applications"] = int(row["applications"]) + 1
	row["max_stacks"] = maxi(int(row["max_stacks"]), int(entry.get("stacks", 1)))
	by_id[id] = row
	_status[unit.unit_name] = by_id


func _peak(unit: Unit, stat: String, value: int) -> void:
	var key := "%s:%s" % [unit.unit_name, stat]
	_stack_peaks[key] = maxi(int(_stack_peaks.get(key, 0)), value)


func _sample_telegraphs() -> void:
	for raw in ArenaState.telegraphs:
		var telegraph := raw as Telegraph
		if telegraph == null or not is_instance_valid(telegraph):
			continue
		var id := telegraph.get_instance_id()
		if _telegraph_seen.has(id):
			continue
		_telegraph_seen[id] = true
		var key := "%s:%s" % [Telegraph.Shape.keys()[telegraph.shape], telegraph.ability_id]
		_telegraphs[key] = int(_telegraphs.get(key, 0)) + 1


func _sample_walls() -> void:
	for node in get_tree().get_nodes_in_group("spell_walls"):
		var wall := node as SpellWall
		if wall == null or _walls_seen.has(wall.get_instance_id()):
			continue
		var owner_name := _name_of(wall.source)
		_walls_seen[wall.get_instance_id()] = owner_name


func _wall_totals() -> Dictionary:
	var out := {}
	for id in _walls_seen.keys():
		var owner_name: String = _walls_seen[id]
		out[owner_name] = int(out.get(owner_name, 0)) + 1
	return out


func _checkpoint() -> void:
	var boss := ArenaState.boss
	if boss == null or not is_instance_valid(boss):
		return
	var threat := {}
	for unit in _roster:
		threat[unit.unit_name] = snappedf(ThreatTable.threat_of(boss, unit), 0.01)
	var holder := ThreatTable.aggro_holder(boss)
	(
		_checkpoints
		. append(
			{
				"t": snappedf(sim_time(), 0.01),
				"threat": threat,
				"holder": holder.unit_name if holder != null else "",
				"boss_health": snappedf(boss.health, 1.0),
			}
		)
	)


func _round_tree(value: Variant) -> Variant:
	if value is float:
		return snappedf(value, 0.01)
	if value is Dictionary:
		var out := {}
		for key in value.keys():
			out[key] = _round_tree(value[key])
		return out
	if value is Array:
		var list := []
		for item in value:
			list.append(_round_tree(item))
		return list
	return value


func _finish() -> void:
	_checkpoint()
	var casts := {}
	var never_cast := []
	for driver in _drivers:
		casts[driver.unit.unit_name] = driver.casts
		for slot in driver.unit.abilities.size():
			var ab: AbilityDef = driver.unit.abilities[slot]
			var key := "%d:%s" % [slot, ab.id]
			if ab.implemented and not ab.id.is_empty() and not driver.casts.has(key):
				never_cast.append("%s %s" % [driver.unit.unit_name, key])
	var final_threat := {}
	var boss := ArenaState.boss
	var health := {}
	for unit in _roster:
		health[unit.unit_name] = snappedf(unit.health, 1.0)
		if boss != null and is_instance_valid(boss):
			final_threat[unit.unit_name] = snappedf(ThreatTable.threat_of(boss, unit), 0.01)
	var core := {
		"damage": _round_tree(_damage),
		"healing": _round_tree(_healing),
		"damage_taken": _round_tree(_taken),
		"deaths": _deaths,
		"statuses": _status,
		"stack_peaks": _stack_peaks,
		"telegraphs": _telegraphs,
		"walls_spawned": _wall_totals(),
		"casts": casts,
		"never_cast": never_cast,
		"threat_checkpoints": _checkpoints,
		"final_threat": final_threat,
		"final_health": health,
		"units_alive": ArenaState.units.size(),
		"outcome": ArenaState.outcome,
	}
	var digest := JSON.stringify(core, "", true).sha256_text()
	var report := {
		"meta":
		{
			"godot": Harness.godot_version(),
			"seed": _seed,
			"boss": _boss_id,
			"sim_seconds": _seconds,
			"physics_ticks": _ticks,
			"phase2_forced": _phase2,
			"wall_seconds": snappedf(float(Time.get_ticks_msec() - _wall_start_ms) / 1000.0, 0.1),
		},
		"digest": digest,
		"results": core,
	}
	# A windowed run simulates slightly differently from headless, so keep its
	# report out of the headless baseline file.
	var suffix := "_shots" if _shots else ""
	var path := Harness.write_text(
		"scenario_%s%s.json" % [_boss_id, suffix], JSON.stringify(report, "\t", true)
	)
	_print_summary(core, digest, path)
	_quit_when_shots_done()


func _print_summary(core: Dictionary, digest: String, path: String) -> void:
	var dealt := 0.0
	for who in _damage.keys():
		if who == "world":
			continue
		for spell in _damage[who].keys():
			dealt += float(_damage[who][spell]["total"])
	var applications := 0
	for who in _status.keys():
		for id in _status[who].keys():
			applications += int(_status[who][id]["applications"])
	print(
		(
			"baseline-scenario: ticks=%d damage_total=%.1f status_applications=%d never_cast=%d"
			% [_ticks, dealt, applications, core["never_cast"].size()]
		)
	)
	for entry in core["never_cast"]:
		print("baseline-scenario: NEVER CAST %s" % entry)
	print("baseline-scenario: wrote %s" % path)
	print("BASELINE_SCENARIO_DIGEST %s" % digest)


func _quit_when_shots_done() -> void:
	if _shots:
		var waited := 0
		while _shots_done.size() < SHOT_MOMENTS.size() and waited < 600:
			await get_tree().process_frame
			waited += 1
		if _shots_done.size() < SHOT_MOMENTS.size():
			push_error(
				(
					"baseline-shots: only %d of %d moments captured; raise --seconds"
					% [_shots_done.size(), SHOT_MOMENTS.size()]
				)
			)
	get_tree().quit(0)
