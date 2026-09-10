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
	var power := 1.0 + pct(inf.id + ".power")
	match inf.id:
		"fire", "ice", "lightning", "shadow", "wind":
			inf.damage_mult = power
		"illusion":
			inf.damage_mult = power
			inf.heal_mult = power
		"nature", "divine":
			inf.heal_mult = power
		"protection":
			inf.shield_from_base = power
	inf.cooldown_mult = 1.0 + pct(inf.id + ".cooldown")
	inf.cast_time_mult = 1.0 + pct(inf.id + ".cast")
	return inf


static func tune_augment(aug: SpellAugment) -> SpellAugment:
	ensure()
	if aug == null:
		return aug
	match aug.id:
		"echo":
			aug.echo_damage_mult = pct("echo.damage")
		"menace":
			aug.threat_mult = flat("menace.threat")
		"subtlety":
			aug.threat_mult = flat("subtlety.threat")
		"volley":
			aug.damage_mult = pct("volley.damage")
			aug.projectile_bonus = int(round(flat("volley.extra")))
		"fan":
			aug.damage_mult = pct("fan.damage")
			aug.projectile_bonus = int(round(flat("fan.extra")))
		"focus":
			aug.area_mult = 1.0 + pct("focus.area")
			aug.damage_mult = 1.0 + pct("focus.damage")
		"spread":
			aug.area_mult = 1.0 + pct("spread.area")
			aug.damage_mult = 1.0 + pct("spread.damage")
		"lingering":
			aug.duration_mult = 1.0 + pct("lingering.duration")
		"ritual":
			aug.cast_time_mult = 1.0 + pct("ritual.cast")
			aug.damage_mult = 1.0 + pct("ritual.damage")
		"momentum":
			aug.hit_cooldown_reduction = flat("momentum.refund")
			aug.hit_cooldown_refund_cap = pct("momentum.cap")
		"siphon":
			aug.lifesteal = pct("siphon.heal")
		"cleave":
			aug.cleave_ratio = pct("cleave.ratio")
			aug.cleave_radius = flat("cleave.radius")
		"execute":
			aug.execute_health_frac = pct("execute.health")
			aug.execute_damage_mult = 1.0 + pct("execute.damage")
		"gambit":
			aug.cooldown_mult = 1.0 + pct("gambit.cooldown")
			aug.mana_mult = 1.0 + pct("gambit.mana")
		"heartbeat":
			aug.tick_interval_mult = 1.0 + pct("heartbeat.interval")
			aug.mana_mult = 1.0 + pct("heartbeat.mana")
		"slow_burn":
			aug.tick_interval_mult = 1.0 + pct("slow_burn.interval")
			aug.damage_mult = 1.0 + pct("slow_burn.damage")
		"aftershock":
			aug.detonate_on_end = 1.0 + pct("aftershock.pulse")
		"crowd":
			aug.crowd_bonus = pct("crowd.each")
			aug.crowd_bonus_cap = pct("crowd.cap")
		"stillness":
			aug.stillness_bonus = pct("stillness.bonus")
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
	var result := cfg.load(SAVE_PATH)
	if result != OK:
		if result != ERR_FILE_NOT_FOUND:
			push_warning("CombatBalance: could not load overrides (%s)" % error_string(result))
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
	var result := cfg.save(SAVE_PATH)
	if result != OK:
		push_warning("CombatBalance: could not save overrides (%s)" % error_string(result))


static func _default_rows() -> Array[Dictionary]:
	return [
		_flat("bolt.hit", "Spell bases", "Bolt hit", 42.0, 0.0, 2000.0, 1.0),
		_flat("missiles.hit", "Spell bases", "Missiles hit", 24.0, 0.0, 2000.0, 1.0),
		_flat("missiles.volley", "Spell bases", "Missile volley", 3.0, 2.0, 6.0, 1.0),
		_flat("missiles.arc.width", "Spell bases", "Missile bloom spacing", 0.85, 0.12, 1.8, 0.05),
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
		_flat("altered.ice.tick", "Effect bases", "Altered Ice trail tick", 12.6, 0.0, 500.0, 0.1),
		_flat("altered.storm.hit", "Effect bases", "Altered Lightning pulse", 13.5, 0.0, 500.0, 0.1),
		_flat("altered.support.time", "Alteration", "Support alter duration", 10.0, 1.0, 30.0, 0.25),
		_flat("altered.nature.max", "Alteration", "Seeded max stacks", 8.0, 1.0, 20.0, 1.0),
		_flat("altered.nature.splash", "Effect bases", "Seeded Fire splash", 18.0, 0.0, 500.0, 0.1),
		_flat("altered.nature.splash_radius", "Alteration", "Seeded Fire splash radius", 2.2, 0.4, 8.0, 0.05),
		_flat("altered.nature.bloom", "Effect bases", "Seeded 8-stack bloom", 90.0, 0.0, 2000.0, 1.0),
		_flat("altered.divine.max", "Alteration", "Judged max stacks", 5.0, 1.0, 20.0, 1.0),
		_flat("altered.divine.mend_div", "Alteration", "Judged mend hit divisor", 24.0, 1.0, 100.0, 1.0),
		_flat("altered.divine.range", "Alteration", "Judged mend range", 7.0, 1.0, 20.0, 0.25),
		_flat("altered.protection.max", "Alteration", "Sundered max stacks", 5.0, 1.0, 20.0, 1.0),
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
		_pct("altered.ice.tick.pct", "Effect extra %", "Altered Ice trail", 0.0),
		_pct("altered.storm.hit.pct", "Effect extra %", "Altered Lightning pulse", 0.0),
		_pct("altered.nature.splash.pct", "Effect extra %", "Seeded Fire splash", 0.0),
		_pct("altered.nature.bloom.pct", "Effect extra %", "Seeded 8-stack bloom", 0.0),
		_pct("fire.power", "Infusion %", "Fire spell power", 0.40),
		_pct("fire.cooldown", "Infusion %", "Fire cooldown", 0.00),
		_pct("fire.cast", "Infusion %", "Fire cast time", 0.15),
		_pct("ice.power", "Infusion %", "Ice spell power", 0.75),
		_pct("ice.cooldown", "Infusion %", "Ice cooldown", 0.35),
		_pct("ice.cast", "Infusion %", "Ice cast time", 0.20),
		_pct("lightning.power", "Infusion %", "Lightning spell power", 0.20),
		_pct("lightning.cooldown", "Infusion %", "Lightning cooldown", -0.10),
		_pct("lightning.cast", "Infusion %", "Lightning cast time", 0.00),
		_pct("shadow.power", "Infusion %", "Shadow spell power", 0.00),
		_pct("shadow.cooldown", "Infusion %", "Shadow cooldown", -0.10),
		_pct("shadow.cast", "Infusion %", "Shadow cast time", -0.15),
		_pct("wind.power", "Infusion %", "Wind spell power", 0.00),
		_pct("wind.cooldown", "Infusion %", "Wind cooldown", 0.20),
		_pct("wind.cast", "Infusion %", "Wind cast time", 0.00),
		_flat("wind.bolt.dist", "Wind CC", "Bolt knockback", 1.35, 0.0, 8.0, 0.05),
		_flat("wind.bolt.time", "Wind CC", "Bolt knock time", 0.16, 0.05, 1.0, 0.01),
		_flat("wind.missiles.snare", "Wind CC", "Missile snare", 0.30, 0.05, 2.0, 0.01),
		_flat("wind.ray.drift", "Wind CC", "Ray push speed", 0.40, 0.0, 3.0, 0.05),
		_flat("wind.ray.time", "Wind CC", "Ray push time", 0.35, 0.05, 1.5, 0.01),
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
		_pct("illusion.power", "Infusion %", "Illusion spell power", -0.10),
		_pct("illusion.cooldown", "Infusion %", "Illusion cooldown", 0.00),
		_pct("illusion.cast", "Infusion %", "Illusion cast time", 0.00),
		_flat("illusion.bolt.angle", "Illusion", "Bolt outer angle", 30.0, 5.0, 90.0, 1.0),
		_flat("illusion.bolt.inner", "Illusion", "Bolt inner angle", 15.0, 5.0, 90.0, 1.0),
		_pct("illusion.bolt.damage", "Illusion", "Bolt base keep", -0.50),
		_flat("illusion.missiles.radius", "Illusion", "Missile search radius", 3.6, 1.0, 20.0, 0.1),
		_flat("illusion.missiles.count", "Illusion", "Extra missile targets", 2.0, 1.0, 6.0, 1.0),
		_flat("illusion.ray.pulse", "Illusion", "Ray aura pulse radius", 6.0, 2.0, 16.0, 0.25),
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
		_pct("nature.power", "Infusion %", "Nature spell power", -0.60),
		_pct("nature.cooldown", "Infusion %", "Nature cooldown", -0.35),
		_pct("nature.cast", "Infusion %", "Nature cast time", -0.15),
		_pct("divine.power", "Infusion %", "Divine spell power", 0.60),
		_pct("divine.cooldown", "Infusion %", "Divine cooldown", 0.20),
		_pct("divine.cast", "Infusion %", "Divine cast time", 0.20),
		_pct("protection.power", "Infusion %", "Protection spell power", 1.00),
		_pct("protection.cooldown", "Infusion %", "Protection cooldown", 0.50),
		_pct("protection.cast", "Infusion %", "Protection cast time", 0.00),
		_pct("shield.resist", "Effect %", "Shield elemental resist", 0.30),
		_pct("burn.ratio", "Effect % of hit", "Burn", 0.50),
		_flat("chill.stacks.max", "Effect bases", "Chill stacks to freeze", 50.0, 1.0, 50.0, 1.0),
		_pct("chill.slow.per_stack", "Effect %", "Chill slow per stack", 0.01),
		_flat("chill.ice.normal", "Effect bases", "Ice damage per Chill stack (normal)", 6.0, 1.0, 200.0, 1.0),
		_flat("chill.ice.rare", "Effect bases", "Ice damage per Chill stack (rare)", 20.0, 1.0, 200.0, 1.0),
		_flat("chill.ice.elite", "Effect bases", "Ice damage per Chill stack (elite)", 40.0, 1.0, 200.0, 1.0),
		_flat("freeze.immune.normal", "Effect bases", "Freeze DR (normal)", 2.5, 0.0, 30.0, 0.25),
		_flat("freeze.immune.rare", "Effect bases", "Freeze DR (rare)", 6.0, 0.0, 30.0, 0.25),
		_flat("freeze.immune.elite", "Effect bases", "Freeze DR (elite)", 12.0, 0.0, 30.0, 0.25),
		_flat("shatter.mult", "Effect bases", "Shatter Fire explosion multiplier", 3.0, 1.0, 5.0, 0.25),
		_flat("shatter.shadow.mult", "Effect bases", "Shatter Shadow explosion multiplier", 1.0, 1.0, 5.0, 0.25),
		_flat("shatter.shell.normal", "Effect bases", "Shatter shell (normal)", 90.0, 1.0, 4000.0, 1.0),
		_flat("shatter.shell.rare", "Effect bases", "Shatter shell (rare)", 300.0, 1.0, 4000.0, 1.0),
		_flat("shatter.shell.elite", "Effect bases", "Shatter shell (elite)", 600.0, 1.0, 4000.0, 1.0),
		_pct("shatter.frostburst", "Effect % of hit", "Shatter frostburst", 0.40),
		_flat("shatter.frostburst.radius", "Effect bases", "Shatter frostburst radius", 3.6, 0.5, 12.0, 0.1),
		_pct("shatter.afflict.frac", "Effect %", "Shatter Afflict spread fraction", 0.25),
		_flat("shatter.afflict.cap", "Effect bases", "Shatter Afflict spread cap", 100.0, 1.0, 400.0, 1.0),
		_flat("skill.combustion.mana", "Class skills", "Combustion mana", 80.0, 0.0, 400.0, 5.0),
		_flat("skill.combustion.cd", "Class skills", "Combustion cooldown", 30.0, 5.0, 120.0, 1.0),
		_flat("skill.combustion.radius", "Class skills", "Combustion splash radius", 2.8, 0.5, 12.0, 0.1),
		_pct("skill.combustion.consume", "Class skills", "Combustion leftover as hit", 2.00),
		_pct("skill.combustion.splash", "Class skills", "Combustion splash of leftover", 0.50),
		_flat("skill.pyroblast.mana", "Class skills", "Pyroblast mana", 90.0, 0.0, 400.0, 5.0),
		_flat("skill.pyroblast.cd", "Class skills", "Pyroblast cooldown", 40.0, 5.0, 120.0, 1.0),
		_flat("skill.pyroblast.cast", "Class skills", "Pyroblast cast time", 2.2, 0.2, 6.0, 0.05),
		_flat("skill.pyroblast.damage", "Class skills", "Pyroblast damage", 500.0, 50.0, 4000.0, 10.0),
		_flat("skill.pyroblast.cdr", "Class skills", "Pyroblast CDR per fire crit", 0.5, 0.0, 4.0, 0.05),
		_flat("skill.crucible.mana", "Class skills", "Crucible mana", 85.0, 0.0, 400.0, 5.0),
		_flat("skill.crucible.cd", "Class skills", "Crucible cooldown", 45.0, 5.0, 120.0, 1.0),
		_flat("skill.crucible.time", "Class skills", "Crucible duration", 4.0, 1.0, 12.0, 0.25),
		_flat("skill.crucible.radius", "Class skills", "Crucible radius", 3.6, 1.0, 12.0, 0.1),
		_flat("skill.crucible.tick", "Class skills", "Crucible tick interval", 0.5, 0.2, 2.0, 0.05),
		_flat("skill.ashen.mana", "Class skills", "Ashen Wake mana", 70.0, 0.0, 400.0, 5.0),
		_flat("skill.ashen.cd", "Class skills", "Ashen Wake cooldown", 20.0, 4.0, 80.0, 1.0),
		_flat("skill.ashen.recast", "Class skills", "Ashen Wake recast window", 4.0, 1.0, 8.0, 0.25),
		_flat("skill.ashen.width", "Class skills", "Ashen Wake path width", 2.6, 0.8, 6.0, 0.1),
		_pct("skill.ashen.convert", "Class skills", "Ashen Wake Afflict convert", 0.50),
		_flat("skill.ashen.afflict_to_burn", "Class skills", "Burn DPS per converted Afflict stack", 1.0, 0.0, 10.0, 0.25),
		_flat("skill.ashen.afflict", "Class skills", "Ashen Wake Afflict stacks", 20.0, 1.0, 80.0, 1.0),
		_flat("skill.ironhide.mana", "Class skills", "Ironhide mana", 40.0, 0.0, 400.0, 5.0),
		_flat("skill.ironhide.cd", "Class skills", "Ironhide cooldown", 24.0, 5.0, 120.0, 1.0),
		_flat("skill.ironhide.time", "Class skills", "Ironhide duration", 6.0, 1.0, 16.0, 0.25),
		_pct("skill.ironhide.dr", "Class skills", "Ironhide DR", 0.50),
		_flat("skill.ironhide.shield", "Class skills", "Ironhide shield per hit", 80.0, 0.0, 400.0, 1.0),
		_flat("skill.rampage.mana", "Class skills", "Rampage mana", 50.0, 0.0, 400.0, 5.0),
		_flat("skill.rampage.cd", "Class skills", "Rampage cooldown", 20.0, 5.0, 120.0, 1.0),
		_flat("skill.rampage.time", "Class skills", "Rampage duration", 8.0, 1.0, 16.0, 0.25),
		_pct("skill.rampage.dr", "Class skills", "Rampage DR", 0.30),
		_flat("skill.sanctuary.mana", "Class skills", "Sanctuary mana", 60.0, 0.0, 400.0, 5.0),
		_flat("skill.sanctuary.cd", "Class skills", "Sanctuary cooldown", 22.0, 5.0, 120.0, 1.0),
		_flat("skill.sanctuary.radius", "Class skills", "Sanctuary radius", 4.5, 1.0, 12.0, 0.1),
		_flat("skill.sanctuary.time", "Class skills", "Sanctuary duration", 6.0, 1.0, 16.0, 0.25),
		_flat("skill.sanctuary.shield", "Class skills", "Sanctuary shield pulse", 70.0, 0.0, 400.0, 1.0),
		_flat("skill.sanctuary.threat", "Class skills", "Sanctuary threat pulse", 28.0, 0.0, 400.0, 1.0),
		_pct("skill.sanctuary.dr", "Class skills", "Sanctuary self DR", 0.30),
		_flat("skill.intercede.mana", "Class skills", "Intercede mana", 45.0, 0.0, 400.0, 5.0),
		_flat("skill.intercede.cd", "Class skills", "Intercede cooldown", 20.0, 5.0, 120.0, 1.0),
		_flat("skill.intercede.shield", "Class skills", "Intercede shield", 350.0, 0.0, 2000.0, 5.0),
		_flat("skill.flourish.mana", "Class skills", "Flourish mana", 50.0, 0.0, 400.0, 5.0),
		_flat("skill.flourish.cd", "Class skills", "Flourish cooldown", 28.0, 5.0, 120.0, 1.0),
		_flat("skill.flourish.radius", "Class skills", "Flourish radius", 12.0, 4.0, 20.0, 0.25),
		_flat("skill.flourish.heal", "Class skills", "Flourish heal per Rejuv stack", 26.0, 1.0, 200.0, 1.0),
		_flat("skill.flourish.bloom", "Class skills", "Flourish Lifebloom bloom", 120.0, 0.0, 800.0, 5.0),
		_flat("skill.flourish.drought", "Class skills", "Flourish Drought duration", 4.0, 1.0, 12.0, 0.25),
		_flat("skill.worldroot.mana", "Class skills", "Worldroot mana", 60.0, 0.0, 400.0, 5.0),
		_flat("skill.worldroot.cd", "Class skills", "Worldroot cooldown", 40.0, 8.0, 120.0, 1.0),
		_flat("skill.worldroot.radius", "Class skills", "Worldroot radius", 7.0, 2.0, 16.0, 0.1),
		_flat("skill.worldroot.time", "Class skills", "Worldroot duration", 6.0, 2.0, 16.0, 0.25),
		_flat("skill.worldroot.heal", "Class skills", "Worldroot heal pulse", 52.0, 0.0, 400.0, 1.0),
		_flat("skill.tempest_bloom.mana", "Class skills", "Tempest Bloom mana", 55.0, 0.0, 400.0, 5.0),
		_flat("skill.tempest_bloom.cd", "Class skills", "Tempest Bloom cooldown", 32.0, 8.0, 120.0, 1.0),
		_flat("skill.tempest_bloom.time", "Class skills", "Tempest Bloom duration", 8.0, 2.0, 16.0, 0.25),
		_flat("skill.eye_storm.mana", "Class skills", "Eye of the Storm mana", 60.0, 0.0, 400.0, 5.0),
		_flat("skill.eye_storm.cd", "Class skills", "Eye of the Storm cooldown", 36.0, 8.0, 120.0, 1.0),
		_flat("skill.eye_storm.time", "Class skills", "Eye of the Storm duration", 8.0, 2.0, 16.0, 0.25),
		_flat("skill.eye_storm.radius", "Class skills", "Eye of the Storm radius", 6.0, 2.0, 14.0, 0.1),
		_flat("skill.eye_storm.jump", "Class skills", "Eye of the Storm jump range", 10.0, 4.0, 20.0, 0.25),
		_flat("skill.eye_storm.tick", "Class skills", "Eye of the Storm tick damage", 18.0, 0.0, 200.0, 1.0),
		_flat("talent.wraithfire.range.1", "Class talents", "Wraithfire blink rank 1", 8.0, 2.0, 16.0, 0.25),
		_flat("talent.wraithfire.range.2", "Class talents", "Wraithfire blink rank 2", 10.0, 2.0, 16.0, 0.25),
		_flat("afflict.stacks.max", "Effect bases", "Afflict stack cap", 400.0, 1.0, 400.0, 1.0),
		_flat("afflict.per", "Effect bases", "Afflict stacks per 1 tick damage", 4.0, 1.0, 20.0, 1.0),
		_flat("afflict.tick", "Effect bases", "Afflict damage per 4 stacks", 1.0, 0.0, 50.0, 0.25),
		_flat("shock.stacks.max", "Effect bases", "Shock stack cap", 100.0, 1.0, 100.0, 1.0),
		_pct("shock.chain", "Effect % of hit", "Shock chain at 100 stacks", 0.20),
		_pct("lightning.chain.falloff", "Effect %", "Chain lightning bounce falloff", 0.20),
		_pct("flashover.ratio", "Effect % of remaining", "Flashover Burn on chain hops", 0.20),
		_flat("flashover.time", "Effect bases", "Flashover Burn duration", 4.0, 1.0, 10.0, 0.25),
		_pct("conductive.chill.frac", "Effect %", "Conductive Frost Chill fraction", 0.20),
		_flat("conductive.chill.cap", "Effect bases", "Conductive Frost Chill cap per hop", 8.0, 1.0, 50.0, 1.0),
		_pct("voidarc.afflict.frac", "Effect %", "Void Arc Afflict fraction", 0.05),
		_flat("voidarc.afflict.cap", "Effect bases", "Void Arc Afflict cap per hop", 20.0, 1.0, 100.0, 1.0),
		_pct("afflict.taken", "Effect %", "Afflict taken amp at cap (off)", 0.0),
		_pct("rejuvenation.pulse", "Effect % of hit", "Nature atonement pulse", 0.25),
		_flat("rejuvenation.hps", "Effect bases", "Rejuvenation HPS per stack", 6.0, 0.0, 200.0, 0.5),
		_pct("echo.damage", "Augment %", "Echo leftover damage", 0.20),
		_flat("menace.threat", "Augment", "Menace threat", 4.0, 1.0, 10.0, 0.25),
		_flat("subtlety.threat", "Augment", "Subtlety threat", 0.5, 0.0, 1.0, 0.05),
		_pct("volley.damage", "Augment %", "Volley bolt damage", 0.55),
		_flat("volley.extra", "Augment", "Volley extra bolts", 2.0, 1.0, 4.0, 1.0),
		_pct("fan.damage", "Augment %", "Fan beam damage", 0.55),
		_flat("fan.extra", "Augment", "Fan extra beams", 2.0, 1.0, 4.0, 1.0),
		_flat("fan.angle", "Augment", "Fan beam spacing", 12.0, 4.0, 30.0, 1.0),
		_pct("focus.area", "Augment %", "Focus area", -0.30),
		_pct("focus.damage", "Augment %", "Focus damage", 0.25),
		_pct("spread.area", "Augment %", "Spread area", 0.30),
		_pct("spread.damage", "Augment %", "Spread damage", -0.25),
		_pct("lingering.duration", "Augment %", "Lingering duration", 0.50),
		_pct("ritual.cast", "Augment %", "Ritual cast time", 0.60),
		_pct("ritual.damage", "Augment %", "Ritual damage", 0.35),
		_flat("momentum.refund", "Augment", "Momentum per-enemy refund", 0.4, 0.05, 2.0, 0.05),
		_pct("momentum.cap", "Augment %", "Momentum refund cap of cooldown", 0.25),
		_pct("siphon.heal", "Augment %", "Siphon heal from damage", 0.15),
		_pct("cleave.ratio", "Augment %", "Cleave splash damage", 0.50),
		_flat("cleave.radius", "Augment", "Cleave splash radius", 1.2, 0.4, 4.0, 0.05),
		_pct("execute.health", "Augment %", "Execute health threshold", 0.30),
		_pct("execute.damage", "Augment %", "Execute bonus damage", 0.30),
		_pct("gambit.cooldown", "Augment %", "Gambit cooldown", -0.30),
		_pct("gambit.mana", "Augment %", "Gambit mana", 0.40),
		_pct("heartbeat.interval", "Augment %", "Heartbeat pulse interval", -0.40),
		_pct("heartbeat.mana", "Augment %", "Heartbeat pulse mana", 0.20),
		_pct("slow_burn.interval", "Augment %", "Slow Burn pulse interval", 0.50),
		_pct("slow_burn.damage", "Augment %", "Slow Burn pulse damage", 0.40),
		_pct("aftershock.pulse", "Augment %", "Aftershock extra pulse", 0.50),
		_pct("crowd.each", "Augment %", "Crowd bonus per extra unit", 0.08),
		_pct("crowd.cap", "Augment %", "Crowd bonus cap", 0.40),
		_pct("stillness.bonus", "Augment %", "Stillness standing bonus", 0.35),
		_pct("altered.fire.spell", "Alteration %", "Altered Fire other spells", 0.10),
		_pct("altered.fire.fire", "Alteration %", "Altered Fire on fire spells", 0.20),
		_pct("altered.resist", "Alteration %", "Altered elemental resist", 0.30),
		_pct("altered.shadow.out", "Alteration %", "Shadow Pact outgoing at 30", 0.30),
		_pct("altered.shadow.hp", "Alteration %", "Shadow Pact HP drain at 30", 0.05),
		_pct("altered.nature.snare", "Alteration %", "Seeded snare per stack", 0.05),
		_pct("altered.divine.taken", "Alteration %", "Judged divine taken per stack", 0.08),
		_pct("altered.protection.out", "Alteration %", "Sundered outgoing cut per stack", 0.05),
		_pct("altered.protection.break", "Alteration %", "Sundered shield break return", 0.40),
		# 8–12 min 4-player band. Parse before touching these: TTK under 8:00 → check
		# infinite mana / tank AA uptime first. TTK over 12:00 → check OOM (Ray+Missiles)
		# before raising HP. One HP, one incoming table, one 12:00 clock. No role-count branches.
		# NPC Bulwark / Hex / Vex swing this auto DPS. Player class autos stay on the class.
		_flat("raid.npc.dps", "Raid AI", "NPC tank and DPS auto DPS", 400.0, 50.0, 2000.0, 10.0),
		_flat("fight.enrage.time", "Bosses", "Fight clock enrage (s)", 720.0, 60.0, 2400.0, 15.0),
		_flat("colossus.hp", "Bosses", "Colossus health", 330000.0, 1000.0, 2000000.0, 1000.0),
		# Tank lives from Plate/Grudge (DR, shields, self-heals), not a huge HP pool.
		# 180 auto so 500 HP melts in ~4s unhealed. Slab 700 plus Brace+Spite (~34% while
		# shielded) holds autos; slam 240 forces a heal or Ironhide. Cleave/breath stay raid.
		_flat("colossus.auto", "Bosses", "Colossus auto", 180.0, 0.0, 500.0, 1.0),
		_flat("colossus.cleave", "Bosses", "Colossus cleave", 160.0, 0.0, 2000.0, 1.0),
		_flat("colossus.slam", "Bosses", "Colossus slam", 240.0, 0.0, 2000.0, 1.0),
		_flat("colossus.breath", "Bosses", "Colossus breath", 190.0, 0.0, 2000.0, 1.0),
		_pct("colossus.p2.auto", "Bosses", "Colossus P2 auto", 0.15),
		_flat("colossus.p2.speed", "Bosses", "Colossus P2 move add", 1.1, 0.0, 8.0, 0.05),
		_flat("colossus.p2.rate", "Bosses", "Colossus P2 ability rate", 0.7, 0.2, 1.5, 0.05),
		_flat("colossus.shard.hp", "Bosses", "Colossus Shard health", 1200.0, 1.0, 20000.0, 10.0),
		_flat("colossus.shard.damage", "Bosses", "Colossus Shard auto", 22.0, 0.0, 400.0, 1.0),
		_flat("dawnwarden.hp", "Bosses", "Dawnwarden health", 150000.0, 1000.0, 2000000.0, 1000.0),
		_flat("dawnwarden.auto", "Bosses", "Dawnwarden auto", 200.0, 0.0, 800.0, 1.0),
		_flat("dawnwarden.auto.range", "Bosses", "Dawnwarden auto range", 3.5, 2.0, 16.0, 0.1),
		_flat("dawnwarden.speed", "Bosses", "Dawnwarden move speed", 11.0, 3.0, 18.0, 0.1),
		_flat("dawnwarden.cleave", "Bosses", "Dawnwarden cleave", 155.0, 0.0, 2000.0, 1.0),
		_flat("dawnwarden.cleave.radius", "Bosses", "Dawnwarden cleave radius", 16.0, 4.0, 32.0, 0.1),
		_flat("dawnwarden.cleave.angle", "Bosses", "Dawnwarden cleave angle (deg)", 160.0, 60.0, 180.0, 1.0),
		_flat("dawnwarden.cleave.warn", "Bosses", "Dawnwarden cleave warn (s)", 0.40, 0.15, 2.0, 0.05),
		_flat("dawnwarden.sunspot", "Bosses", "Dawnwarden Sunspot", 200.0, 0.0, 2000.0, 1.0),
		_flat("dawnwarden.sunspot.radius", "Bosses", "Dawnwarden Sunspot radius", 3.8, 1.0, 16.0, 0.1),
		_flat("dawnwarden.judgment", "Bosses", "Dawnwarden Judgment total", 125.0, 0.0, 4000.0, 5.0),
		_pct("dawnwarden.judgment.brand", "Bosses", "Judgment Brand per stack", 0.005),
		_flat("dawnwarden.judgment.pillar", "Bosses", "Judgment rays to kill a pillar", 2.0, 0.25, 8.0, 0.25),
		_pct("dawnwarden.p2.sunspot", "Bosses", "Dawnwarden P2 Sunspot size", 0.50),
		_pct("dawnwarden.p2.judgment", "Bosses", "Dawnwarden P2 Judgment length", 1.0),
		_flat("dawnwarden.collapse.damage", "Bosses", "Solar Collapse damage", 100.0, 0.0, 99999.0, 1.0),
		_flat("dawnwarden.collapse.cast", "Bosses", "Solar Collapse cast (s)", 4.5, 1.0, 12.0, 0.05),
		_flat("dawnwarden.corona.damage", "Bosses", "Solar Corona damage", 100.0, 0.0, 99999.0, 1.0),
		_flat("dawnwarden.corona.cast", "Bosses", "Solar Corona cast (s)", 4.0, 1.0, 12.0, 0.05),
		_flat("dawnwarden.corona.inner", "Bosses", "Solar Corona safe radius", 7.2, 2.0, 20.0, 0.1),
		_flat("dawnwarden.seq.slam", "Bosses", "Dawnwarden wait before slam (s)", 15.0, 2.0, 60.0, 0.5),
		_flat("dawnwarden.seq.ray", "Bosses", "Dawnwarden wait before ray (s)", 15.0, 2.0, 60.0, 0.5),
		_flat("dawnwarden.seq.nova", "Bosses", "Dawnwarden wait before corona (s)", 10.0, 2.0, 60.0, 0.5),
		_flat("dawnwarden.brand.cleave", "Bosses", "Cleave Judgment stacks", 2.0, 0.0, 40.0, 1.0),
		_flat("dawnwarden.brand.sunspot", "Bosses", "Sunspot Judgment stacks", 10.0, 0.0, 80.0, 1.0),
		_flat("dawnwarden.brand.ray", "Bosses", "Judgment Ray stacks per tick", 4.0, 0.0, 40.0, 1.0),
		_flat("dawnwarden.brand.corona", "Bosses", "Corona Judgment stacks", 50.0, 0.0, 200.0, 1.0),
		_flat("dawnwarden.brand.collapse", "Bosses", "Collapse Judgment stacks", 50.0, 0.0, 200.0, 1.0),
		_flat("dawnwarden.pillar.shot", "Bosses", "Pillar shot damage", 12.0, 0.0, 400.0, 1.0),
		_flat("dawnwarden.pillar.shot.speed", "Bosses", "Pillar shot speed", 16.0, 4.0, 48.0, 0.5),
		_flat("dawnwarden.pillar.shot.range", "Bosses", "Pillar shot leak range", 64.0, 8.0, 80.0, 0.5),
		_flat("dawnwarden.pillar.sprinkle", "Bosses", "Pillar shot interval (s)", 0.5, 0.08, 2.0, 0.02),
		_flat("dawnwarden.pillar.player", "Bosses", "Pillar player-aim interval (s)", 0.667, 0.15, 2.0, 0.02),
		_flat("dawnwarden.pillar.mode", "Bosses", "Pillar gun mode length (s)", 10.0, 2.0, 40.0, 0.25),
		_flat("dawnwarden.pillar.warmup", "Bosses", "Pillar rise (s)", 5.0, 1.0, 20.0, 0.25),
		_flat("dawnwarden.pillar.spin", "Bosses", "Pillar pattern sweep (rad/s)", 2.2, 0.2, 8.0, 0.1),
		_flat("dawnwarden.totem.hp", "Bosses", "Sun Totem health", 1000.0, 1.0, 40000.0, 10.0),
		_flat("dawnwarden.totem.damage", "Bosses", "Sun Totem bolt", 18.0, 0.0, 400.0, 1.0),
		_flat("dawnwarden.totem.interval", "Bosses", "Sun Totem fire (s)", 0.16, 0.05, 2.2, 0.01),
		_flat("dawnwarden.totem.speed", "Bosses", "Sun Totem bolt speed", 22.0, 6.0, 48.0, 0.5),
		_flat("dawnwarden.totem.range", "Bosses", "Sun Totem bolt range", 28.0, 8.0, 48.0, 0.5),
		_flat("dawnwarden.totem.radius", "Bosses", "Sun Totem bolt radius", 0.26, 0.1, 0.8, 0.01),
		_flat("dawnwarden.totem.swap", "Bosses", "Sun Totem aim swap (s)", 1.6, 0.4, 8.0, 0.05),
		_flat("dawnwarden.totem.first", "Bosses", "Sun Totem first (s)", 14.0, 2.0, 120.0, 1.0),
		_flat("dawnwarden.totem.p1", "Bosses", "Sun Totem P1 (s)", 24.0, 6.0, 180.0, 1.0),
		_flat("dawnwarden.totem.p2", "Bosses", "Sun Totem P2 (s)", 18.0, 6.0, 180.0, 1.0),
		_flat("dawnwarden.totem.cast", "Bosses", "Sun Totem cast (s)", 0.85, 0.2, 4.0, 0.05),
		_flat("dawnwarden.totem.cap", "Bosses", "Sun Totem live cap", 1.0, 1.0, 16.0, 1.0),
		_flat("dawnwarden.totem.p2.cap", "Bosses", "Sun Totem P2 live cap", 2.0, 1.0, 16.0, 1.0),
		_flat("dawnwarden.totem.execute", "Bosses", "Execute extra totems", 4.0, 0.0, 12.0, 1.0),
		_pct("dawnwarden.execute.hp", "Bosses", "Execute HP", 0.15),
		_flat("dawnwarden.pillar.hp", "Bosses", "Pillar health", 1200.0, 1.0, 40000.0, 10.0),
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
