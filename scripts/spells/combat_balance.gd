class_name CombatBalance
extends Object

const SAVE_PATH := "user://combat_balance.cfg"

static var _values: Dictionary = {}
static var _rows: Array[Dictionary] = []
static var _ready: bool = false


static func ensure() -> void:
	if _ready:
		return
	_ready = true
	_rows = _default_rows()
	for row in _rows:
		var id := String(row["id"])
		if not _values.has(id):
			_values[id] = float(row["default"])
	_load()


static func rows_of(kind: String) -> Array[Dictionary]:
	ensure()
	_rows = _default_rows()
	for row in _rows:
		var id := String(row["id"])
		if not _values.has(id):
			_values[id] = float(row["default"])
	var out: Array[Dictionary] = []
	for row in _rows:
		if String(row.get("kind", "")) == kind:
			out.append(row)
	return out


static func get_value(id: String) -> float:
	ensure()
	if _values.has(id):
		return float(_values[id])
	return _default_for(id)


static func set_value(id: String, amount: float) -> void:
	ensure()
	var row := _row(id)
	var lo := float(row.get("lo", 0.0))
	var hi := float(row.get("hi", 2000.0))
	_values[id] = clampf(amount, lo, hi)
	_save()
	_notify()


static func reset_kind(kind: String) -> void:
	ensure()
	for row in rows_of(kind):
		_values[String(row["id"])] = float(row["default"])
	_save()
	_notify()


static func flat(id: String) -> float:
	return get_value(id)


static func pct(id: String) -> float:
	return get_value(id)


static func scaled_hit(id: String) -> float:
	return get_value(id) * (1.0 + get_value(id + ".pct"))


static func wall_hit_damage(hp: float = -1.0) -> float:
	var pool := hp if hp > 0.05 else flat("wall.lightning.hp")
	var ratio := pct("wall.damage")
	if ratio < 0.01:
		ratio = 0.40
	return pool * ratio


static func chain_hop_mult(hop: int) -> float:
	var cut := pct("lightning.chain.falloff")
	if cut <= 0.0:
		return 1.0
	return pow(maxf(0.0, 1.0 - cut), float(maxi(hop, 0)))


static func tune_base(b: SpellBase) -> SpellBase:
	ensure()
	if b == null:
		return b
	match b.id:
		"bolt", "missiles", "aoe_explosion", "ray", "meteor", "nova", "wall", "wave", "target":
			b.damage = scaled_hit(b.id + ".hit")
		"ground_aoe", "aura":
			b.tick_damage = scaled_hit(b.id + ".tick")
	return b


static func tune_infusion(inf: SpellInfusion) -> SpellInfusion:
	ensure()
	if inf == null:
		return inf
	match inf.id:
		"fire", "ice", "lightning", "shadow", "wind":
			inf.damage_mult = 1.0 + pct(inf.id + ".damage")
		"illusion":
			inf.damage_mult = 1.0 + pct("illusion.value")
			inf.heal_mult = 1.0 + pct("illusion.value")
		"nature":
			inf.heal_mult = 1.0 + pct("nature.heal")
		"divine":
			inf.heal_mult = 1.0 + pct("divine.heal")
		"protection":
			inf.shield_from_base = pct("protection.shield")
	return inf


static func tune_augment(aug: SpellAugment) -> SpellAugment:
	ensure()
	if aug == null:
		return aug
	match aug.id:
		"echo":
			aug.echo_damage_mult = pct("echo.damage")
		"encore":
			aug.recast_damage_mult = pct("encore.damage")
		"menace":
			aug.threat_mult = flat("menace.threat")
		"subtlety":
			aug.threat_mult = flat("subtlety.threat")
	return aug


static func _notify() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var gs := (loop as SceneTree).root.get_node_or_null("GameSession")
	if gs:
		gs.call("notify_balance_changed")


static func _default_for(id: String) -> float:
	var row := _row(id)
	return float(row.get("default", 0.0))


static func _row(id: String) -> Dictionary:
	for row in _rows:
		if String(row.get("id", "")) == id:
			return row
	return {}


static func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for row in _rows:
		var id := String(row["id"])
		if cfg.has_section_key("values", id):
			_values[id] = clampf(float(cfg.get_value("values", id, row["default"])), float(row["lo"]), float(row["hi"]))


static func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for row in _rows:
		var id := String(row["id"])
		cfg.set_value("values", id, get_value(id))
	cfg.save(SAVE_PATH)


static func _default_rows() -> Array[Dictionary]:
	return [
		_flat("bolt.hit", "Spell bases", "Bolt hit", 42.0, 0.0, 2000.0, 1.0),
		_flat("missiles.hit", "Spell bases", "Missiles hit", 24.0, 0.0, 2000.0, 1.0),
		_flat("missiles.volley", "Spell bases", "Missile volley", 3.0, 2.0, 6.0, 1.0),
		_flat("missiles.arc.width", "Spell bases", "Missile bloom width", 0.78, 0.15, 1.8, 0.05),
		_flat("missiles.arc.min", "Spell bases", "Missile bloom min", 2.6, 0.4, 8.0, 0.1),
		_flat("ground_aoe.tick", "Spell bases", "Ground AOE tick", 14.0, 0.0, 2000.0, 1.0),
		_flat("aoe_explosion.hit", "Spell bases", "Burst hit", 140.0, 0.0, 4000.0, 1.0),
		_flat("aura.tick", "Spell bases", "Aura tick", 10.0, 0.0, 2000.0, 1.0),
		_flat("ray.hit", "Spell bases", "Ray pulse", 40.0, 0.0, 2000.0, 1.0),
		_flat("meteor.hit", "Spell bases", "Meteor hit", 500.0, 0.0, 8000.0, 1.0),
		_flat("nova.hit", "Spell bases", "Nova hit", 130.0, 0.0, 4000.0, 1.0),
		_flat("wall.hit", "Spell bases", "Wall blast", 160.0, 0.0, 4000.0, 1.0),
		_flat("wall.hp", "Spell bases", "Wall health", 800.0, 1.0, 20000.0, 10.0),
		_pct("wall.damage", "Wall infusions", "Lightning wall hit from HP", 0.40),
		_flat("wall.length", "Spell bases", "Wall length", 4.8, 1.0, 16.0, 0.1),
		_flat("wall.thickness", "Spell bases", "Wall thickness", 0.55, 0.2, 3.0, 0.05),
		_flat("wall.grow", "Spell bases", "Wall grow time", 0.14, 0.04, 0.6, 0.01),
		_flat("wall.fire.length", "Wall infusions", "Fire wall length", 2.0, 1.0, 4.0, 0.05),
		_flat("wall.fire.thickness", "Wall infusions", "Fire wall thickness", 0.50, 0.2, 1.0, 0.05),
		_flat("wall.fire.height", "Wall infusions", "Fire wall height", 0.18, 0.06, 1.2, 0.02),
		_flat("wall.fire.bonus", "Wall infusions", "Fire wall shot bonus", 8.0, 0.0, 400.0, 1.0),
		_flat("wall.ice.radius", "Wall infusions", "Ice capsule radius", 0.55, 0.15, 2.0, 0.05),
		_flat("wall.ice.count", "Wall infusions", "Ice capsule length", 3.0, 1.0, 6.0, 1.0),
		_flat("wall.ice.break", "Wall infusions", "Ice wall break HP", 0.50, 0.05, 2.0, 0.05),
		_flat("wall.lightning.hp", "Wall infusions", "Lightning totem health", 200.0, 1.0, 20000.0, 10.0),
		_flat("wall.lightning.radius", "Wall infusions", "Lightning totem radius", 0.4, 0.15, 1.5, 0.05),
		_flat("wall.lightning.height", "Wall infusions", "Lightning totem height", 1.7, 0.6, 3.5, 0.05),
		_flat("wall.lightning.tick", "Wall infusions", "Lightning totem interval", 1.0, 0.2, 4.0, 0.05),
		_flat("wall.lightning.range", "Wall infusions", "Lightning totem range", 8.0, 2.0, 20.0, 0.25),
		_flat("wall.lightning.hops", "Wall infusions", "Lightning totem hops", 3.0, 0.0, 8.0, 1.0),
		_flat("wall.lightning.bounce", "Wall infusions", "Lightning totem bounce", 7.0, 2.0, 16.0, 0.25),
		_flat("wall.shadow.hp", "Wall infusions", "Shadow wall health", 3000.0, 1.0, 20000.0, 10.0),
		_flat("wall.shadow.stacks", "Wall infusions", "Shadow wall afflict", 50.0, 1.0, 100.0, 1.0),
		_flat("wall.shadow.range", "Wall infusions", "Shadow wall break range", 28.0, 4.0, 64.0, 0.5),
		_flat("wall.wind.length", "Wall infusions", "Wind wall length", 1.30, 1.0, 3.0, 0.05),
		_flat("wall.wind.bounce", "Wall infusions", "Wind wall bounce time", 0.12, 0.04, 0.6, 0.01),
		_flat("wall.illusion.recast", "Wall infusions", "Illusion wall recast", 8.0, 1.0, 16.0, 0.25),
		_flat("wall.illusion.time", "Wall infusions", "Illusion wall time", 8.0, 1.0, 20.0, 0.25),
		_flat("wall.illusion.moves", "Wall infusions", "Illusion exit moves", 3.0, 0.0, 8.0, 1.0),
		_flat("wall.illusion.width", "Wall infusions", "Illusion portal width", 1.85, 0.6, 6.0, 0.05),
		_flat("wall.illusion.height", "Wall infusions", "Illusion portal height", 2.45, 0.8, 6.0, 0.05),
		_flat("wall.illusion.thickness", "Wall infusions", "Illusion portal thickness", 0.12, 0.06, 0.6, 0.01),
		_flat("wall.nature.radius", "Wall infusions", "Nature wall radius", 6.5, 2.0, 16.0, 0.1),
		_flat("wall.nature.count", "Wall infusions", "Nature wall count", 12.0, 6.0, 24.0, 1.0),
		_flat("wall.nature.hp", "Wall infusions", "Nature wall shared HP", 200.0, 1.0, 4000.0, 10.0),
		_flat("wall.nature.tick", "Wall infusions", "Nature wall heal", 16.0, 0.0, 400.0, 1.0),
		_flat("wall.nature.blast", "Wall infusions", "Nature wall break heal", 90.0, 0.0, 2000.0, 1.0),
		_flat("wall.nature.time", "Wall infusions", "Nature wall time", 6.0, 1.0, 20.0, 0.25),
		_pct("wall.nature.slow", "Wall infusions", "Nature wall enemy slow", 0.50),
		_flat("wall.divine.radius", "Wall infusions", "Divine wall radius", 7.5, 2.0, 16.0, 0.1),
		_flat("wall.divine.height", "Wall infusions", "Divine wall height", 2.7, 0.8, 8.0, 0.05),
		_flat("wall.divine.time", "Wall infusions", "Divine wall time", 7.0, 1.0, 20.0, 0.25),
		_pct("wall.divine.dr", "Wall infusions", "Divine wall DR", 0.30),
		_flat("wall.protection.radius", "Wall infusions", "Protection wall radius", 2.8, 1.5, 12.0, 0.1),
		_pct("wall.protection.inward", "Wall infusions", "Protection wall inward", 0.40),
		_flat("wall.protection.arc", "Wall infusions", "Protection wall arc", 70.0, 40.0, 220.0, 5.0),
		_flat("wall.protection.step", "Wall infusions", "Protection wall step", 10.0, 5.0, 30.0, 1.0),
		_flat("wall.protection.count", "Wall infusions", "Protection wall pieces", 8.0, 3.0, 16.0, 1.0),
		_flat("wall.protection.thickness", "Wall infusions", "Protection wall thickness", 0.5, 0.2, 2.0, 0.05),
		_flat("wall.protection.time", "Wall infusions", "Protection wall channel", 4.0, 1.0, 20.0, 0.25),
		_flat("wall.protection.turn", "Wall infusions", "Protection recast turn (180°)", 1.0, 0.1, 2.0, 0.05),
		_pct("wall.protection.slow", "Wall infusions", "Protection hold slow", 0.50),
		_flat("wave.hit", "Spell bases", "Wave hit", 32.0, 0.0, 2000.0, 1.0),
		_flat("target.hit", "Spell bases", "Target hit", 80.0, 0.0, 2000.0, 1.0),
		_flat("shatter", "Effect bases", "Shatter bonus", 45.0, 0.0, 2000.0, 1.0),
		_flat("cataclysm", "Effect bases", "Cataclysm bonus", 80.0, 0.0, 2000.0, 1.0),
		_flat("altered.ice.tick", "Effect bases", "Altered Ice trail tick", 12.6, 0.0, 500.0, 0.1),
		_flat("altered.storm.hit", "Effect bases", "Altered Lightning pulse", 13.5, 0.0, 500.0, 0.1),
		_pct("bolt.hit.pct", "Spell extra %", "Bolt", 0.0),
		_pct("missiles.hit.pct", "Spell extra %", "Missiles", 0.0),
		_pct("ground_aoe.tick.pct", "Spell extra %", "Ground AOE", 0.0),
		_pct("aoe_explosion.hit.pct", "Spell extra %", "Burst", 0.0),
		_pct("aura.tick.pct", "Spell extra %", "Aura", 0.0),
		_pct("ray.hit.pct", "Spell extra %", "Ray", 0.0),
		_pct("meteor.hit.pct", "Spell extra %", "Meteor", 0.0),
		_pct("nova.hit.pct", "Spell extra %", "Nova", 0.0),
		_pct("wall.hit.pct", "Spell extra %", "Wall", 0.0),
		_pct("wave.hit.pct", "Spell extra %", "Wave", 0.0),
		_pct("target.hit.pct", "Spell extra %", "Target", 0.0),
		_pct("shatter.pct", "Effect extra %", "Shatter", 0.0),
		_pct("cataclysm.pct", "Effect extra %", "Cataclysm", 0.0),
		_pct("altered.ice.tick.pct", "Effect extra %", "Altered Ice trail", 0.0),
		_pct("altered.storm.hit.pct", "Effect extra %", "Altered Lightning pulse", 0.0),
		_pct("infusion.base", "Infusion %", "Per infusion base value", 0.20),
		_pct("fire.damage", "Infusion %", "Fire damage", 0.20),
		_pct("ice.damage", "Infusion %", "Ice damage", -0.10),
		_pct("lightning.damage", "Infusion %", "Lightning damage", 0.35),
		_pct("shadow.damage", "Infusion %", "Shadow damage", 0.20),
		_pct("wind.damage", "Infusion %", "Wind damage", -0.30),
		_flat("wind.bolt.dist", "Wind CC", "Bolt knockback", 1.35, 0.0, 8.0, 0.05),
		_flat("wind.bolt.time", "Wind CC", "Bolt knock time", 0.16, 0.05, 1.0, 0.01),
		_flat("wind.missiles.snare", "Wind CC", "Missile snare", 0.30, 0.05, 2.0, 0.01),
		_flat("wind.ray.drift", "Wind CC", "Ray push speed", 0.40, 0.0, 3.0, 0.05),
		_flat("wind.wave.speed", "Wind CC", "Wave speed keep", 0.45, 0.2, 1.0, 0.05),
		_flat("wind.wave.width", "Wind CC", "Wave width", 1.30, 1.0, 2.0, 0.05),
		_flat("wind.ground.time", "Wind CC", "Ground AOE lifetime", 0.22, 0.05, 1.5, 0.01),
		_flat("wind.ground.radius", "Wind CC", "Ground AOE radius keep", 0.50, 0.3, 1.0, 0.05),
		_pct("wind.ground.dump", "Wind CC", "Other infusion dump", 0.50),
		_flat("wind.ground.pull", "Wind CC", "Ground AOE pull speed", 40.0, 0.0, 80.0, 1.0),
		_flat("wind.burst.height", "Wind CC", "Burst knockup height", 1.35, 0.2, 6.0, 0.05),
		_flat("wind.burst.time", "Wind CC", "Burst knockup time", 0.55, 0.1, 2.0, 0.01),
		_flat("wind.burst.fall", "Wind CC", "Burst fall speed", 0.50, 0.15, 1.0, 0.05),
		_flat("wind.meteor.dist", "Wind CC", "Meteor knockback", 4.5, 0.5, 12.0, 0.1),
		_flat("wind.meteor.snap", "Wind CC", "Meteor knock time", 0.09, 0.04, 0.4, 0.01),
		_flat("wind.nova.max", "Wind CC", "Nova knock at center", 3.0, 0.4, 10.0, 0.1),
		_flat("wind.nova.min", "Wind CC", "Nova knock at edge", 0.6, 0.0, 6.0, 0.05),
		_flat("wind.nova.snap", "Wind CC", "Nova knock time", 0.08, 0.04, 0.4, 0.01),
		_pct("wind.aura.haste", "Wind CC", "Aura ally haste", 0.10),
		_pct("wind.shield.haste", "Wind CC", "Shield haste", 0.20),
		_pct("illusion.value", "Infusion %", "Illusion value", -0.20),
		_flat("illusion.bolt.angle", "Illusion", "Bolt outer angle", 30.0, 5.0, 90.0, 1.0),
		_flat("illusion.bolt.inner", "Illusion", "Bolt inner angle", 15.0, 5.0, 90.0, 1.0),
		_pct("illusion.bolt.damage", "Illusion", "Bolt base keep", -0.50),
		_flat("illusion.missiles.radius", "Illusion", "Missile search radius", 3.6, 1.0, 20.0, 0.1),
		_flat("illusion.missiles.count", "Illusion", "Extra missile targets", 2.0, 1.0, 6.0, 1.0),
		_flat("illusion.ray.range", "Illusion", "Ray bounce range", 12.0, 4.0, 30.0, 0.5),
		_flat("illusion.ray.hops", "Illusion", "Ray extra hops", 2.0, 1.0, 6.0, 1.0),
		_flat("illusion.ray.push", "Illusion", "Ray knock from impact", 2.2, 0.0, 8.0, 0.05),
		_flat("illusion.ray.push.time", "Illusion", "Ray knock time", 0.18, 0.04, 0.6, 0.01),
		_flat("illusion.aoe.gap", "Illusion", "Extra zone min angle", 35.0, 15.0, 180.0, 1.0),
		_flat("illusion.aoe.out", "Illusion", "Extra zone rim scale", 1.18, 1.0, 2.0, 0.01),
		_flat("illusion.aoe.push", "Illusion", "Extra zone push", 2.0, 0.0, 12.0, 0.25),
		_flat("illusion.aoe.jitter.min", "Illusion", "Extra zone extra min", 1.0, 0.0, 8.0, 0.25),
		_flat("illusion.aoe.jitter.max", "Illusion", "Extra zone extra max", 4.0, 0.5, 12.0, 0.25),
		_flat("illusion.aoe.size.min", "Illusion", "Extra zone size min", 0.80, 0.3, 1.5, 0.05),
		_flat("illusion.aoe.size.max", "Illusion", "Extra zone size max", 1.20, 0.5, 2.0, 0.05),
		_flat("illusion.burst.delay", "Illusion", "Burst echo delay", 0.50, 0.08, 1.2, 0.02),
		_flat("illusion.burst.radius", "Illusion", "Burst echo radius keep", 0.70, 0.3, 1.0, 0.05),
		_flat("illusion.nova.range", "Illusion", "Nova cast range", 6.0, 2.0, 16.0, 0.25),
		_pct("illusion.aura.range", "Illusion", "Aura range", 0.25),
		_pct("illusion.aura.inner", "Illusion", "Aura inner dead zone", 0.28),
		_pct("illusion.aura.inner.push", "Illusion", "Aura inner push", 0.25),
		_pct("illusion.meteor.damage", "Illusion", "Meteor damage", -0.20),
		_pct("illusion.meteor.radius", "Illusion", "Meteor radius", -0.25),
		_flat("illusion.meteor.count", "Illusion", "Meteor line count", 3.0, 2.0, 8.0, 1.0),
		_flat("illusion.meteor.delay", "Illusion", "Meteor line delay", 0.25, 0.05, 1.0, 0.01),
		_pct("nature.heal", "Infusion %", "Nature heal", -0.20),
		_pct("divine.heal", "Infusion %", "Divine heal", 0.40),
		_pct("protection.shield", "Infusion %", "Protection shield", 2.00),
		_pct("shield.resist", "Effect %", "Shield elemental resist", 0.30),
		_pct("burn.ratio", "Effect % of hit", "Burn", 0.50),
		_flat("afflict.tick", "Effect bases", "Afflict damage per stack", 1.0, 0.0, 50.0, 0.25),
		_pct("shock.chain", "Effect % of hit", "Shock chain at 10 stacks", 0.20),
		_pct("lightning.chain.falloff", "Effect %", "Chain lightning bounce falloff", 0.20),
		_pct("afflict.taken", "Effect %", "Afflict taken amp at 200", 0.20),
		_pct("rejuvenation.pulse", "Effect % of hit", "Nature atonement pulse", 0.25),
		_flat("rejuvenation.hps", "Effect bases", "Rejuvenation HPS per stack", 8.0, 0.0, 200.0, 0.5),
		_pct("echo.damage", "Augment %", "Echo leftover damage", 0.20),
		_pct("encore.damage", "Augment %", "Encore recast damage", 0.30),
		_flat("menace.threat", "Augment", "Menace threat", 4.0, 1.0, 10.0, 0.25),
		_flat("subtlety.threat", "Augment", "Subtlety threat", 0.5, 0.0, 1.0, 0.05),
		_pct("altered.fire.spell", "Alteration %", "Altered Fire other spells", 0.10),
		_pct("altered.fire.fire", "Alteration %", "Altered Fire on fire spells", 0.20),
		_pct("altered.resist", "Alteration %", "Altered elemental resist", 0.30),
		_pct("altered.shadow.out", "Alteration %", "Shadow Pact outgoing at 30", 0.30),
		_pct("altered.shadow.hp", "Alteration %", "Shadow Pact HP drain at 30", 0.05),
	]


static func _flat(id: String, group: String, label: String, amount: float, lo: float, hi: float, step: float) -> Dictionary:
	return {"id": id, "kind": "flat", "group": group, "label": label, "default": amount, "lo": lo, "hi": hi, "step": step}


static func _pct(id: String, group: String, label: String, amount: float) -> Dictionary:
	return {"id": id, "kind": "pct", "group": group, "label": label, "default": amount, "lo": -0.90, "hi": 4.00, "step": 0.01}


static func _pretty_mult(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return "%0.1f" % v


static func _pretty_fraction(v: float) -> String:
	if is_equal_approx(v, 0.5):
		return "half"
	if v <= 0.001:
		return "no"
	return "%d%%" % int(round(v * 100.0))
