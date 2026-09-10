extends Node

## Per-enemy threat tables. Damage writes to that mob; healing splits across engaged enemies.

const DAMAGE_COEFF := 1.0
const HEAL_COEFF := 0.5
const MELEE_SNAP := 1.10
const RANGE_SNAP := 1.30
const TANK_MULT := 1.0
const SEED_THREAT := 120.0
const CLOSE_RATIO := 0.80

var lock_boss_to_tank: bool = false

var _tables: Dictionary = {}
var _aggro: Dictionary = {}
var _taunts: Dictionary = {}
var _spells: Dictionary = {}


func _ready() -> void:
	ArenaState.unit_registered.connect(_on_unit_registered)
	GameSession.session_started.connect(_on_session_started)
	ArenaState.fight_won.connect(_on_fight_over)
	ArenaState.fight_lost.connect(_on_fight_over)


func reset() -> void:
	_tables.clear()
	_aggro.clear()
	_taunts.clear()
	_spells.clear()


func threat_of(enemy: Unit, unit: Unit) -> float:
	if enemy == null or unit == null:
		return 0.0
	var table: Dictionary = _tables.get(enemy, {})
	return float(table.get(unit, 0.0))


func holds(enemy: Unit, unit: Unit) -> bool:
	return unit != null and aggro_holder(enemy) == unit


func rival_threat(enemy: Unit, unit: Unit) -> float:
	if enemy == null or unit == null:
		return 0.0
	var table: Dictionary = _tables.get(enemy, {})
	var best := 0.0
	for key in table.keys():
		var other := key as Unit
		if other == null or other == unit or not is_instance_valid(other):
			continue
		best = maxf(best, float(table[other]))
	return best


func aggro_holder(enemy: Unit) -> Unit:
	if enemy == null or not is_instance_valid(enemy):
		return null
	var held = _aggro.get(enemy)
	if held is Unit and is_instance_valid(held) and (held as Unit).can_be_aggroed():
		return held
	return null


func pick_target(mob: Unit) -> Unit:
	if mob == null or not is_instance_valid(mob) or mob.is_dead:
		return null
	var taunted := _taunt_holder(mob)
	if taunted != null:
		_aggro[mob] = taunted
		return taunted
	return _snap_target(mob)


func _taunt_holder(mob: Unit) -> Unit:
	if not _taunts.has(mob):
		return null
	var row: Dictionary = _taunts[mob]
	var until := float(row.get("until", 0.0))
	if Time.get_ticks_msec() * 0.001 >= until:
		_taunts.erase(mob)
		return null
	var holder = row.get("holder")
	if holder is Unit and is_instance_valid(holder) and (holder as Unit).can_be_aggroed():
		return holder as Unit
	_taunts.erase(mob)
	return null


func drop_unit(unit: Unit) -> void:
	if unit == null:
		return
	for enemy in _tables.keys():
		var table: Dictionary = _tables[enemy]
		table.erase(unit)
		_erase_spell_src(enemy, unit)
		if _aggro.get(enemy) == unit:
			_aggro.erase(enemy)
		if _taunts.get(enemy) is Dictionary and (_taunts[enemy] as Dictionary).get("holder") == unit:
			_taunts.erase(enemy)


func ranked_rows(enemy: Unit) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if enemy == null or not is_instance_valid(enemy):
		return rows
	var table: Dictionary = _tables.get(enemy, {})
	var you := GameSession.active_unit as Unit
	var holder := aggro_holder(enemy)
	var top := 0.0
	for key in table.keys():
		if not (key is Unit) or not is_instance_valid(key):
			continue
		top = maxf(top, float(table[key]))
	var entries: Array[Dictionary] = []
	for key in table.keys():
		var u := key as Unit
		if u == null or not is_instance_valid(u):
			continue
		var amount := float(table[u])
		if amount <= 0.0 and u != you:
			continue
		entries.append({
			"unit": u,
			"name": u.unit_name,
			"amount": amount,
			"share": amount / maxf(top, 1.0),
			"is_you": u == you,
			"is_aggro": u == holder,
			"color": _bar_color(u, u == holder),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a["amount"])
		var db := float(b["amount"])
		if is_equal_approx(da, db):
			return String(a["name"]) < String(b["name"])
		return da > db
	)
	var i := 1
	for row in entries:
		row["rank"] = i
		rows.append(row)
		i += 1
	return rows


func spell_breakdown(enemy: Unit, src: Unit) -> Array[Dictionary]:
	if enemy == null or src == null or not is_instance_valid(enemy) or not is_instance_valid(src):
		return []
	var by_src: Dictionary = _spells.get(enemy, {})
	var spells: Dictionary = by_src.get(src, {})
	return CombatMeter.rows_from_spells(src, spells, CombatMeter.elapsed())


func player_view(enemy: Unit) -> Dictionary:
	var you := GameSession.active_unit as Unit
	var empty := {
		"rank": 0,
		"amount": 0.0,
		"top": 0.0,
		"ratio": 0.0,
		"status": "none",
		"color": Color(0.62, 0.10, 0.10),
		"aggro_name": "",
		"locked": false,
		"label": "",
	}
	if enemy == null or not is_instance_valid(enemy) or you == null:
		return empty
	var rows := ranked_rows(enemy)
	var holder := aggro_holder(enemy)
	empty["aggro_name"] = holder.unit_name if holder else ""
	empty["locked"] = false
	if rows.is_empty():
		return empty
	var top := float(rows[0]["amount"])
	empty["top"] = top
	var mine := 0.0
	var rank := 0
	for row in rows:
		if row.get("unit") == you:
			mine = float(row["amount"])
			rank = int(row["rank"])
			break
	empty["amount"] = mine
	empty["rank"] = rank
	empty["ratio"] = mine / maxf(top, 1.0)
	var status := _status_for(enemy, you, holder, mine, threat_of(enemy, holder) if holder else top)
	empty["status"] = status
	empty["color"] = _status_color(status)
	empty["label"] = _status_label(status, rank, empty["ratio"], empty["locked"])
	return empty


func _on_session_started() -> void:
	reset()
	_seed_engaged()


func _on_fight_over() -> void:
	pass


func _on_unit_registered(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.damaged.is_connected(_on_damaged):
		unit.damaged.connect(_on_damaged)
	if not unit.healed.is_connected(_on_healed):
		unit.healed.connect(_on_healed)
	if not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)
	if GameSession.fight_started and unit.team != Unit.TEAM_RAID and not unit.is_dead:
		_seed_enemy(unit)


func _on_unit_died(unit: Unit) -> void:
	if unit == null:
		return
	if unit.team != Unit.TEAM_RAID:
		_tables.erase(unit)
		_aggro.erase(unit)
		_spells.erase(unit)
		_taunts.erase(unit)
		return
	drop_unit(unit)


func _on_damaged(victim: Unit, amount: float, source: Node3D, spell_id: String = "") -> void:
	if not GameSession.fight_started or amount <= 0.0:
		return
	var src := source as Unit
	if src == null or not is_instance_valid(src) or src.team != Unit.TEAM_RAID:
		return
	if victim == null or not is_instance_valid(victim) or victim.team == Unit.TEAM_RAID:
		return
	if not src.can_be_aggroed():
		return
	_add_to(victim, src, amount * DAMAGE_COEFF * _source_mult(src, spell_id) * TalentCombat.threat_dealt_mult(src), spell_id)
	_apply_redirect(victim, src, amount * DAMAGE_COEFF * _source_mult(src, spell_id), spell_id)


func _on_healed(_target: Unit, amount: float, source: Node3D = null, spell_id: String = "") -> void:
	if not GameSession.fight_started or amount <= 0.0:
		return
	var src := source as Unit
	if src == null or not is_instance_valid(src) or src.team != Unit.TEAM_RAID:
		return
	if not src.can_be_aggroed():
		return
	var enemies := _engaged_enemies()
	if enemies.is_empty():
		return
	var total := amount * HEAL_COEFF * _source_mult(src, spell_id)
	var share := total / float(enemies.size())
	for enemy in enemies:
		_add_to(enemy, src, share, spell_id)


func _source_mult(src: Unit, spell_id: String) -> float:
	return maxf(0.0, src.threat_mult) * src.ability_threat_mult(spell_id)


func _apply_redirect(enemy: Unit, src: Unit, generated: float, spell_id: String = "") -> void:
	var slice := TalentCombat.redirect_slice(src)
	if slice <= 0.0 or generated <= 0.0:
		return
	var tank := TalentCombat.redirect_tank(src)
	if tank == null:
		return
	var moved := generated * slice
	var table: Dictionary = _tables.get(enemy, {})
	var current := float(table.get(src, 0.0))
	if current > 0.0:
		table[src] = maxf(0.0, current - moved)
	_add_spell_threat(enemy, src, spell_id, -moved)
	_add_to(enemy, tank, moved, "redirect")


func add_threat(enemy: Unit, src: Unit, amount: float, spell_id: String = "") -> void:
	_add_to(enemy, src, amount, spell_id)


func taunt(enemy: Unit, src: Unit, duration: float) -> void:
	if enemy == null or src == null or duration <= 0.0:
		return
	if not src.can_be_aggroed():
		return
	_taunts[enemy] = {
		"holder": src,
		"until": Time.get_ticks_msec() * 0.001 + duration,
	}
	_add_to(enemy, src, 80.0, "taunt")
	_aggro[enemy] = src


func _add_to(enemy: Unit, src: Unit, amount: float, spell_id: String = "") -> void:
	if enemy == null or src == null or amount <= 0.0:
		return
	if not _tables.has(enemy):
		_tables[enemy] = {}
	var table: Dictionary = _tables[enemy]
	table[src] = float(table.get(src, 0.0)) + amount
	_add_spell_threat(enemy, src, spell_id, amount)
	if not _aggro.has(enemy):
		_aggro[enemy] = src


func _seed_engaged() -> void:
	for enemy in ArenaState.living_enemies():
		_seed_enemy(enemy)


func _seed_enemy(enemy: Unit) -> void:
	var tank := ArenaState.tank()
	if tank == null or not tank.can_be_aggroed():
		return
	_add_to(enemy, tank, SEED_THREAT, "seed")
	_aggro[enemy] = tank


func set_initial_target(enemy: Unit, holder: Unit) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
		return
	if holder == null or not is_instance_valid(holder) or not holder.can_be_aggroed():
		return
	_tables[enemy] = {holder: SEED_THREAT}
	_spells[enemy] = {holder: {"seed": SEED_THREAT}}
	_aggro[enemy] = holder


func _engaged_enemies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in ArenaState.living_enemies():
		if u is Unit:
			out.append(u)
	return out


func _snap_target(mob: Unit) -> Unit:
	_prune(mob)
	var table: Dictionary = _tables.get(mob, {})
	var current := aggro_holder(mob)
	var best: Unit = null
	var best_amt := -1.0
	for key in table.keys():
		var u := key as Unit
		if u == null or not is_instance_valid(u) or not u.can_be_aggroed():
			continue
		var amt := float(table[u])
		if amt > best_amt:
			best_amt = amt
			best = u
	if best == null:
		best = ArenaState.nearest_enemy(mob.global_position, mob.team) as Unit
		if best:
			_aggro[mob] = best
		else:
			_aggro.erase(mob)
		return best
	if current == null or not current.can_be_aggroed():
		_aggro[mob] = best
		return best
	if best == current:
		_aggro[mob] = current
		return current
	var need := MELEE_SNAP if mob.in_range_of(best) else RANGE_SNAP
	if best_amt >= threat_of(mob, current) * need:
		_aggro[mob] = best
		return best
	_aggro[mob] = current
	return current


func _status_for(enemy: Unit, you: Unit, holder: Unit, mine: float, holder_amt: float) -> String:
	if you == holder and you != null and you.can_be_aggroed():
		return "aggro"
	if mine <= 0.05:
		return "none"
	var need := MELEE_SNAP if enemy.in_range_of(you) else RANGE_SNAP
	var line := maxf(holder_amt, 1.0) * need
	if mine >= line:
		return "pull"
	if mine >= line * CLOSE_RATIO:
		return "close"
	return "safe"


func _status_color(status: String) -> Color:
	match status:
		"aggro":
			return Color(0.92, 0.16, 0.12)
		"pull":
			return Color(0.95, 0.55, 0.10)
		"close":
			return Color(0.95, 0.78, 0.14)
		"safe":
			return Color(0.18, 0.62, 0.28)
		_:
			return Color(0.62, 0.10, 0.10)


func _status_label(status: String, rank: int, ratio: float, locked: bool) -> String:
	var pct := int(round(ratio * 100.0))
	var lock := "  lock" if locked else ""
	match status:
		"aggro":
			return "Aggro%s" % lock
		"none":
			return ""
		_:
			if rank <= 0:
				return ""
			return "%s  %d%%%s" % [_ordinal(rank), pct, lock]


func _ordinal(n: int) -> String:
	if n == 1:
		return "1st"
	if n == 2:
		return "2nd"
	if n == 3:
		return "3rd"
	return "%dth" % n


func _bar_color(u: Unit, is_holder: bool) -> Color:
	if is_holder:
		return Color(0.92, 0.22, 0.16)
	if u != null and u.is_champion:
		return Color(0.92, 0.48, 0.14)
	var ai := u.get_node_or_null("AllyAI") as AllyAI if u else null
	if ai:
		match ai.role:
			"tank":
				return Color(0.78, 0.58, 0.22)
			"healer":
				return Color(0.22, 0.72, 0.42)
	return Color(0.45, 0.55, 0.78)


func _prune(enemy: Unit) -> void:
	if not _tables.has(enemy):
		return
	var table: Dictionary = _tables[enemy]
	for key in table.keys():
		if not (key is Unit) or not is_instance_valid(key) or (key as Unit).is_dead:
			table.erase(key)
			_erase_spell_src(enemy, key)


func _add_spell_threat(enemy: Unit, src: Unit, spell_id: String, amount: float) -> void:
	if enemy == null or src == null or is_zero_approx(amount):
		return
	var key := spell_id if not spell_id.is_empty() else "other"
	if not _spells.has(enemy):
		_spells[enemy] = {}
	var by_src: Dictionary = _spells[enemy]
	if not by_src.has(src):
		by_src[src] = {}
	var bag: Dictionary = by_src[src]
	var next := float(bag.get(key, 0.0)) + amount
	if next <= 0.02:
		bag.erase(key)
	else:
		bag[key] = next
	if bag.is_empty():
		by_src.erase(src)
	if by_src.is_empty():
		_spells.erase(enemy)


func _erase_spell_src(enemy: Variant, src: Variant) -> void:
	if not _spells.has(enemy):
		return
	var by_src: Dictionary = _spells[enemy]
	by_src.erase(src)
	if by_src.is_empty():
		_spells.erase(enemy)
