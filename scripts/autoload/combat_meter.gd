extends Node

enum Mode { DAMAGE, HEALING }

var mode: int = Mode.DAMAGE
var _elapsed: float = 0.0
var _frozen: bool = false
var _damage: Dictionary = {}
var _healing: Dictionary = {}
var _damage_spells: Dictionary = {}
var _heal_spells: Dictionary = {}


func _ready() -> void:
	ArenaState.unit_registered.connect(_on_unit_registered)
	GameSession.session_started.connect(_on_session_started)
	ArenaState.fight_won.connect(_freeze)
	ArenaState.fight_lost.connect(_freeze)


func _process(delta: float) -> void:
	if GameSession.fight_started and not _frozen:
		_elapsed += delta


func toggle_mode() -> void:
	mode = Mode.HEALING if mode == Mode.DAMAGE else Mode.DAMAGE


func mode_title() -> String:
	return "Healing Done" if mode == Mode.HEALING else "Damage Done"


func elapsed() -> float:
	return _elapsed


func is_frozen() -> bool:
	return _frozen


func total_amount() -> float:
	var sum := 0.0
	for row in ranked_rows():
		sum += float(row["amount"])
	return sum


func overall_rate() -> float:
	return total_amount() / maxf(_elapsed, 1.0)


func ranked_rows() -> Array[Dictionary]:
	var bag: Dictionary = _healing if mode == Mode.HEALING else _damage
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	for u in _raid_members():
		seen[u] = true
		rows.append(_row_for(u, float(bag.get(u, 0.0))))
	for u in bag.keys():
		if u is Unit and is_instance_valid(u) and not seen.has(u):
			rows.append(_row_for(u, float(bag[u])))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := float(a["amount"])
		var db := float(b["amount"])
		if da == db:
			return String(a["name"]) < String(b["name"])
		return da > db
	)
	var total := 0.0
	var top := 0.0
	for row in rows:
		total += float(row["amount"])
		top = maxf(top, float(row["amount"]))
	var i := 1
	for row in rows:
		var amount := float(row["amount"])
		row["rank"] = i
		row["share"] = amount / maxf(total, 1.0)
		row["bar"] = amount / maxf(top, 1.0)
		row["rate"] = amount / maxf(_elapsed, 1.0)
		i += 1
	return rows


func format_amount(n: float) -> String:
	if n >= 1000000.0:
		return "%0.2fM" % (n / 1000000.0)
	if n >= 1000.0:
		return "%0.1fk" % (n / 1000.0)
	return str(int(round(n)))


func format_time(t: float) -> String:
	var s := maxi(int(t), 0)
	return "%d:%02d" % [int(s / 60), s % 60]


func reset_meter() -> void:
	_damage.clear()
	_healing.clear()
	_damage_spells.clear()
	_heal_spells.clear()
	_elapsed = 0.0
	_frozen = not GameSession.fight_started or ArenaState.outcome != ""
	for u in _raid_members():
		_ensure(u)


func _on_session_started() -> void:
	reset_meter()
	_frozen = false


func _freeze() -> void:
	_frozen = true


func _on_unit_registered(unit: Unit) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if not unit.damaged.is_connected(_on_damaged):
		unit.damaged.connect(_on_damaged)
	if not unit.healed.is_connected(_on_healed):
		unit.healed.connect(_on_healed)
	if unit.team == Unit.TEAM_RAID:
		_ensure(unit)


func _on_damaged(victim: Unit, amount: float, source: Node3D, spell_id: String = "") -> void:
	if not GameSession.fight_started or _frozen or amount <= 0.0:
		return
	var src := source as Unit
	if src == null or not is_instance_valid(src) or src.team != Unit.TEAM_RAID:
		return
	if victim == null or not is_instance_valid(victim) or victim.team == Unit.TEAM_RAID:
		return
	_ensure(src)
	_damage[src] = float(_damage[src]) + amount
	_add_spell(_damage_spells, src, spell_id, amount)


func _on_healed(_target: Unit, amount: float, source: Node3D = null, spell_id: String = "") -> void:
	if not GameSession.fight_started or _frozen or amount <= 0.0:
		return
	var src := source as Unit
	if src == null or not is_instance_valid(src) or src.team != Unit.TEAM_RAID:
		return
	_ensure(src)
	_healing[src] = float(_healing[src]) + amount
	_add_spell(_heal_spells, src, spell_id, amount)


func _add_spell(bag: Dictionary, src: Unit, spell_id: String, amount: float) -> void:
	var key := spell_id if not spell_id.is_empty() else "other"
	if not bag.has(src):
		bag[src] = {}
	var spells: Dictionary = bag[src]
	spells[key] = float(spells.get(key, 0.0)) + amount


func spell_breakdown(u: Unit) -> Array[Dictionary]:
	var bag: Dictionary = _heal_spells if mode == Mode.HEALING else _damage_spells
	var spells: Dictionary = bag.get(u, {})
	var rows: Array[Dictionary] = []
	var total := 0.0
	for id in spells.keys():
		total += float(spells[id])
	for id in spells.keys():
		var amount := float(spells[id])
		rows.append({
			"id": String(id),
			"name": _spell_name(u, String(id)),
			"icon": _spell_icon(String(id)),
			"amount": amount,
			"rate": amount / maxf(_elapsed, 1.0),
			"share": amount / maxf(total, 1.0),
			"color": _spell_color(String(id)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["amount"]) > float(b["amount"])
	)
	return rows


func _spell_name(u: Unit, id: String) -> String:
	if u and is_instance_valid(u):
		for ab in u.abilities:
			if ab and ab.id == id:
				return ab.display_name
	match id:
		"firebolt":
			return "Firebolt"
		"ice_blast":
			return "Freeze"
		"thunder_wave":
			return "Thunder Wave"
		"meteor":
			return "Meteor"
		"chilled_ground", "ice_tick":
			return "Chilled Ground"
		"overcharge":
			return "Overcharge"
		"burn", "fire_tick":
			return "Burn"
		"combust":
			return "Combust"
		"auto":
			return "Auto Attack"
		"q":
			return "Bolt"
		"w":
			return "Bind"
		"e":
			return "Burst"
		"r":
			return "Nova"
		"other", "hit":
			return "Other"
		_:
			return id.capitalize()


func _spell_icon(id: String) -> String:
	match id:
		"combust":
			return "combust"
		"burn", "fire_tick":
			return "burn"
		"auto":
			return "auto"
		"ice_tick":
			return "chilled_ground"
		"storm_tick", "storm":
			return "thunder_wave"
		"fire":
			return "firebolt"
		"ice":
			return "ice_blast"
		"q", "w", "e", "r":
			return id
		_:
			return id


func _spell_color(id: String) -> Color:
	match id:
		"firebolt", "meteor", "burn", "combust", "fire", "fire_tick", "e":
			return Color(1.0, 0.48, 0.14)
		"ice_blast", "chilled_ground", "ice", "ice_tick":
			return Color(0.45, 0.82, 1.0)
		"thunder_wave", "storm", "storm_tick":
			return Color(0.78, 0.86, 1.0)
		"auto":
			return Color(1.0, 0.88, 0.4)
		"overcharge":
			return Color(1.0, 0.86, 0.32)
		"w":
			return Color(0.4, 0.85, 0.5)
		_:
			return Color(0.7, 0.72, 0.78)


func _raid_members() -> Array[Unit]:
	var out: Array[Unit] = []
	if ArenaState.champion and is_instance_valid(ArenaState.champion):
		out.append(ArenaState.champion)
	for ally in ArenaState.allies:
		if ally is Unit and is_instance_valid(ally):
			out.append(ally)
	return out


func _ensure(u: Unit) -> void:
	if u == null or not is_instance_valid(u):
		return
	if not _damage.has(u):
		_damage[u] = 0.0
	if not _healing.has(u):
		_healing[u] = 0.0
	if not _damage_spells.has(u):
		_damage_spells[u] = {}
	if not _heal_spells.has(u):
		_heal_spells[u] = {}


func _row_for(u: Unit, amount: float) -> Dictionary:
	return {
		"unit": u,
		"name": u.unit_name if u else "Unknown",
		"amount": amount,
		"color": _bar_color(u),
		"is_you": u != null and u == GameSession.active_unit,
	}


func _bar_color(u: Unit) -> Color:
	if u == null or not is_instance_valid(u):
		return Color(0.42, 0.52, 0.7)
	if u.is_champion:
		return Color(0.92, 0.48, 0.14)
	var ai := u.get_node_or_null("AllyAI") as AllyAI
	if ai:
		match ai.role:
			"tank":
				return Color(0.78, 0.58, 0.22)
			"healer":
				return Color(0.22, 0.72, 0.42)
	match u.unit_name:
		"Bulwark":
			return Color(0.78, 0.58, 0.22)
		"Mend":
			return Color(0.22, 0.72, 0.42)
		"Hex":
			return Color(0.62, 0.35, 0.82)
		"Vex":
			return Color(0.28, 0.58, 0.92)
	return Color(0.45, 0.55, 0.78)
