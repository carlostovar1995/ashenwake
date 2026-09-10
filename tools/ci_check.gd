extends SceneTree

const KEY_RUNTIME_RESOURCES := [
	"res://scenes/main.tscn",
	"res://scenes/arena/arena.tscn",
	"res://scenes/arena/layouts/training.tscn",
	"res://scenes/arena/layouts/colossus.tscn",
	"res://scenes/arena/layouts/dawnwarden.tscn",
	"res://assets/models/props/collision/cover_block.tscn",
	"res://assets/models/props/collision/Pillar_collision.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/units/champion.tscn",
	"res://scenes/units/ally.tscn",
	"res://scenes/units/boss.tscn",
	"res://assets/vfx/elemental/effects/projectile/vfx_fire_projectile_01.tscn",
	"res://assets/vfx/explosion/effects/ground/vfx_ground_explosion_01.tscn",
	"res://assets/models/characters/humanoid_boss/Superhero_Male_FullBody.gltf",
	"res://assets/models/outfits/fantasy/Male_Ranger.gltf",
	"res://assets/models/outfits/fantasy/Female_Ranger.gltf",
	"res://assets/models/outfits/fantasy/Male_Peasant.gltf",
	"res://assets/models/outfits/fantasy/Female_Peasant.gltf",
	"res://assets/models/characters/kevdev/HumanCharacterDummy_F.fbx",
	"res://assets/anims/UAL1_Standard.glb",
	"res://assets/anims/UAL2_Standard.glb",
	"res://assets/anims/kevdev/HumanF@Idle01.fbx",
	"res://assets/anims/kevdev/HumanF@Walk01_Forward.fbx",
	"res://assets/anims/kevdev/HumanF@Run01_Forward.fbx",
	"res://assets/anims/kevdev/HumanF@Jump01.fbx",
	"res://assets/anims/kevdev/HumanF@Death01.fbx",
	"res://assets/anims/kevdev/HumanF@Attack1H01_R.fbx",
	"res://assets/anims/kevdev/HumanF@CastingIdle01.fbx",
	"res://assets/anims/kevdev/HumanF@CastingEnter01.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_L.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect2H01_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect2H01_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackCall1H01_L_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackCall1H01_L_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@ThrowBall01_R.fbx",
]
const CleanupGuards := preload("res://tools/cleanup_guards.gd")

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	_check_project_version()
	_check_runtime_resources()
	_check_default_loadout()
	_check_augment_matrix()
	_check_spell_tags()
	_check_class_catalog()
	_check_skill_overlays()
	_check_raid_comp()
	_check_arena_layouts()
	_check_cleanup_guards()
	if _failures > 0:
		push_error("ci_check failed with %d error(s)" % _failures)
		quit(1)
		return
	print("ci_check_ok")
	quit(0)


func _check_project_version() -> void:
	var version_file := FileAccess.open("res://VERSION", FileAccess.READ)
	if version_file == null:
		_fail("Could not open res://VERSION")
		return
	var file_version := version_file.get_as_text().strip_edges()
	if file_version.is_empty():
		_fail("VERSION is empty")
		return

	var project_config := ConfigFile.new()
	var load_error := project_config.load("res://project.godot")
	if load_error != OK:
		_fail("Could not read project.godot (error %d)" % load_error)
		return
	var project_version := String(project_config.get_value("application", "config/version", "")).strip_edges()
	if project_version != file_version:
		_fail("VERSION mismatch: VERSION=%s project.godot=%s" % [file_version, project_version])
		return
	print("Version OK: %s" % file_version)


func _check_runtime_resources() -> void:
	var failures_before := _failures
	for path in KEY_RUNTIME_RESOURCES:
		if not ResourceLoader.exists(path):
			_fail("Missing runtime resource: %s" % path)
			continue
		var resource := ResourceLoader.load(path)
		if not (resource is PackedScene):
			_fail("Runtime scene did not load as PackedScene: %s" % path)
	if _failures == failures_before:
		print("Runtime resources OK: %d scenes" % KEY_RUNTIME_RESOURCES.size())


func _check_default_loadout() -> void:
	var catalog = load("res://scripts/spells/spell_catalog.gd")
	if catalog == null:
		_fail("Could not load SpellCatalog")
		return
	var loadout: Array = catalog.default_loadout()
	if loadout.size() != catalog.CRAFT_SLOTS:
		_fail("Default loadout expected %d recipes, got %d" % [catalog.CRAFT_SLOTS, loadout.size()])
		return
	for i in loadout.size():
		var recipe = loadout[i]
		if recipe == null:
			_fail("Default loadout slot %d is empty" % i)
			return
	print("Default loadout OK: %d recipes" % loadout.size())


func _check_augment_matrix() -> void:
	var failures_before := _failures
	var catalog = load("res://scripts/spells/spell_catalog.gd")
	var recipe_script = load("res://scripts/spells/spell_recipe.gd")
	if catalog == null or recipe_script == null:
		_fail("Could not load augment catalog")
		return
	var bolt = catalog.get_base("bolt")
	if bolt == null or bolt.splash_radius > 0.05 or bolt.splash_ratio > 0.05:
		_fail("Bolt should have no splash so Pierce and Cleave can apply")
		return
	var precision = catalog.get_augment("precision")
	if precision == null or precision.crit_damage > 0.05:
		_fail("Precision should not rewrite crit damage")
		return
	if catalog.get_augment("encore") != null or catalog.get_augment("stride") != null or catalog.get_augment("overflow") != null:
		_fail("Encore, Stride, and Overflow should be removed")
		return
	var efficiency = catalog.get_augment("efficiency")
	if efficiency == null or String(efficiency.description).find("20") < 0:
		_fail("Efficiency tooltip should state the 20% mana cut")
		return
	var nature = catalog.get_infusion("nature")
	if nature == null or not is_equal_approx(nature.heal_mult, 0.40) or not is_equal_approx(nature.cooldown_mult, 0.65) or not is_equal_approx(nature.cast_time_mult, 0.85) or String(nature.description).find("60") < 0:
		_fail("Nature infusion should be -60% spell power, -35% CD, and -15% cast time")
		return
	var fire = catalog.get_infusion("fire")
	if fire == null or abs(fire.damage_mult - 1.40) > 0.001 or abs(fire.cast_time_mult - 1.15) > 0.001:
		_fail("Fire infusion should be +40% spell power and +15% cast time")
		return
	var ice = catalog.get_infusion("ice")
	if ice == null or abs(ice.damage_mult - 1.75) > 0.001 or abs(ice.cooldown_mult - 1.35) > 0.001 or abs(ice.cast_time_mult - 1.20) > 0.001:
		_fail("Ice infusion should be +75% spell power, +35% CD, and +20% cast time")
		return
	var lightning = catalog.get_infusion("lightning")
	if lightning == null or abs(lightning.damage_mult - 1.20) > 0.001 or abs(lightning.cooldown_mult - 0.90) > 0.001:
		_fail("Lightning infusion should be +20% spell power and -10% CD")
		return
	var shadow = catalog.get_infusion("shadow")
	if shadow == null or abs(shadow.damage_mult - 1.0) > 0.001 or abs(shadow.cooldown_mult - 0.90) > 0.001 or abs(shadow.cast_time_mult - 0.85) > 0.001:
		_fail("Shadow infusion should keep spell power, -10% CD, and -15% cast time")
		return
	var wind = catalog.get_infusion("wind")
	if wind == null or abs(wind.damage_mult - 1.0) > 0.001 or abs(wind.cooldown_mult - 1.20) > 0.001:
		_fail("Wind infusion should keep spell power and +20% CD")
		return
	var illusion = catalog.get_infusion("illusion")
	if illusion == null or abs(illusion.damage_mult - 0.90) > 0.001 or abs(illusion.heal_mult - 0.90) > 0.001:
		_fail("Illusion infusion should be -10% spell power")
		return
	var divine = catalog.get_infusion("divine")
	if divine == null or abs(divine.heal_mult - 1.60) > 0.001 or abs(divine.cooldown_mult - 1.20) > 0.001 or abs(divine.cast_time_mult - 1.20) > 0.001:
		_fail("Divine infusion should be +60% spell power, +20% CD, and +20% cast time")
		return
	var protection = catalog.get_infusion("protection")
	if protection == null or abs(protection.shield_from_base - 2.00) > 0.001 or abs(protection.cooldown_mult - 1.50) > 0.001:
		_fail("Protection infusion should be +100% spell power and +50% CD")
		return
	var balance = load("res://scripts/spells/combat_balance.gd")
	if balance == null or abs(balance.flat("rejuvenation.hps") - 6.0) > 0.001:
		_fail("Rejuvenation should be 6 HPS per stack")
		return
	var skipped := {
		"reach": ["aura", "nova"],
		"widen": ["bolt", "missiles", "target"],
		"haste": ["bolt", "ground_aoe", "aura", "nova", "wave", "target", "wall"],
		"snap_cast": ["bolt", "missiles", "ground_aoe", "aura", "nova", "wave", "target", "wall"],
		"ritual": ["bolt", "missiles", "ground_aoe", "aura", "nova", "wave", "target", "wall"],
		"echo": ["ground_aoe", "aura", "wall"],
		"precision": ["ground_aoe", "aura"],
		"lethality": ["ground_aoe", "aura"],
		"readiness": ["aura"],
		"gambit": ["aura"],
		"volley": ["missiles", "ground_aoe", "aoe_explosion", "aura", "ray", "meteor", "nova", "wall", "target"],
		"pierce": ["missiles", "ground_aoe", "aoe_explosion", "aura", "meteor", "nova", "wall", "wave", "target"],
		"focus": ["bolt", "missiles", "target", "ray"],
		"lingering": ["bolt", "missiles", "aoe_explosion", "aura", "meteor", "nova", "wave", "target", "ray"],
		"momentum": ["aura", "wall"],
		"cleave": ["ground_aoe", "aoe_explosion", "aura", "ray", "meteor", "nova", "wall", "wave"],
	}
	var non_aura: Array = []
	for base in catalog.all_bases():
		if String(base.id) != "aura":
			non_aura.append(String(base.id))
	for aug_id in ["heartbeat", "slow_burn", "anchor", "aftershock", "crowd", "stillness"]:
		skipped[aug_id] = non_aura
	var non_ground: Array = []
	for base in catalog.all_bases():
		if String(base.id) != "ground_aoe":
			non_ground.append(String(base.id))
	skipped["spread"] = non_ground
	var non_ray: Array = []
	for base in catalog.all_bases():
		if String(base.id) != "ray":
			non_ray.append(String(base.id))
	skipped["fan"] = non_ray
	for aug in catalog.all_augments():
		var deny: Array = skipped.get(aug.id, [])
		for base in catalog.all_bases():
			var fits: bool = catalog.augment_fits(base.id, aug.id)
			var should_skip: bool = deny.has(base.id)
			if fits and should_skip:
				_fail("%s should not fit %s" % [aug.display_name, base.display_name])
			elif not fits and not should_skip:
				_fail("%s should fit %s (%s)" % [aug.display_name, base.display_name, catalog.augment_skip_reason(base.id, aug.id)])
	var illegal = recipe_script.make("aura", PackedStringArray(), PackedStringArray(["reach", "efficiency"]))
	if illegal.has_augment("reach"):
		_fail("Recipe normalize should drop Reach from Aura")
	if not illegal.has_augment("efficiency"):
		_fail("Recipe normalize should keep Efficiency on Aura")
	var cd_lock = recipe_script.make("aura", PackedStringArray(), PackedStringArray(["readiness", "gambit", "efficiency"]))
	if cd_lock.has_augment("readiness") or cd_lock.has_augment("gambit"):
		_fail("Recipe normalize should drop cooldown augments from Aura")
	var cadence = recipe_script.make("aura", PackedStringArray(), PackedStringArray(["heartbeat", "slow_burn"]))
	if cadence.has_augment("heartbeat") or not cadence.has_augment("slow_burn"):
		_fail("Slow Burn should replace Heartbeat")
	if catalog.augment_fits("bolt", "anchor") or catalog.augment_fits("aura", "readiness"):
		_fail("Anchor is Aura-only and Readiness must not fit Aura")
	var exclusive = recipe_script.make("aoe_explosion", PackedStringArray(), PackedStringArray(["haste", "snap_cast"]))
	if exclusive.has_augment("haste") or not exclusive.has_augment("snap_cast"):
		_fail("Snap Cast should replace Haste")
	if catalog.augment_fits("bolt", "haste") or catalog.augment_fits("bolt", "widen") or catalog.augment_fits("bolt", "snap_cast") or catalog.augment_fits("bolt", "focus") or catalog.augment_fits("bolt", "ritual"):
		_fail("Bolt should not take Haste, Widen, Snap Cast, Focus, or Ritual")
	if catalog.augment_fits("missiles", "haste") == false or catalog.augment_fits("missiles", "cleave") == false or catalog.augment_fits("missiles", "momentum") == false:
		_fail("Haste, Cleave, and Momentum should fit Missiles")
	if catalog.augment_fits("missiles", "lingering"):
		_fail("Lingering should not fit Missiles")
	if catalog.augment_fits("ground_aoe", "momentum") == false or catalog.augment_fits("ground_aoe", "spread") == false:
		_fail("Momentum and Spread should fit Ground AOE")
	var spread_ex = recipe_script.make("ground_aoe", PackedStringArray(), PackedStringArray(["focus", "spread"]))
	if spread_ex.has_augment("focus") or not spread_ex.has_augment("spread"):
		_fail("Spread should replace Focus")
	var momentum = catalog.get_augment("momentum")
	if momentum == null or abs(momentum.hit_cooldown_refund_cap - 0.25) > 0.001:
		_fail("Momentum refund cap should be 25% of cooldown")
	var cleave = catalog.get_augment("cleave")
	var pierce = catalog.get_augment("pierce")
	if cleave == null or cleave.cleave_ratio <= 0.05 or pierce == null or not pierce.pierce:
		_fail("Cleave and Pierce must be defined for Bolt")
	if catalog.augment_fits("bolt", "cleave") == false or catalog.augment_fits("bolt", "pierce") == false:
		_fail("Cleave and Pierce should fit Bolt")
	if catalog.augment_fits("wave", "volley") == false:
		_fail("Volley should fit Wave")
	if catalog.augment_fits("target", "cleave") == false:
		_fail("Cleave should fit Target")
	var cleave_text := String(cleave.description).to_lower()
	if cleave_text.find("allies") < 0:
		_fail("Cleave tooltip should mention ally splash")
	if catalog.augment_fits("ray", "momentum") == false or catalog.augment_fits("ray", "pierce") == false or catalog.augment_fits("ray", "fan") == false:
		_fail("Momentum, Pierce, and Fan should fit Ray")
	if catalog.augment_fits("ray", "lingering") or catalog.augment_fits("ray", "focus") or catalog.augment_fits("bolt", "fan"):
		_fail("Ray should not take Lingering or Focus, and Fan is Ray-only")
	if catalog.augment_fits("aura", "execute") == false or catalog.augment_fits("ground_aoe", "execute") == false:
		_fail("Execute should fit Aura and Ground AOE")
	var compiler = load("res://scripts/spells/spell_compiler.gd")
	if compiler == null:
		_fail("Could not load spell compiler")
	else:
		var icy = recipe_script.make("aura", PackedStringArray(["ice"]), PackedStringArray(["efficiency", "anchor"]))
		var compiled = compiler.compile(icy, "Q")
		var aura_base = catalog.get_base("aura")
		if compiled == null or aura_base == null:
			_fail("Aura compile failed")
		elif not is_equal_approx(compiled.cooldown, aura_base.cooldown):
			_fail("Aura cooldown must stay at the toggle lockout")
		elif not compiled.gcd_exempt:
			_fail("Aura must stay off the GCD")
		elif not compiled.planted:
			_fail("Anchor should plant Aura")
		var missiles_haste = recipe_script.make("missiles", PackedStringArray(), PackedStringArray(["haste"]))
		var mh = compiler.compile(missiles_haste, "Q")
		var missiles_base = catalog.get_base("missiles")
		if mh == null or missiles_base == null:
			_fail("Missiles+Haste compile failed")
		elif mh.tick_interval >= missiles_base.tick_interval - 0.001 or mh.channel_time >= missiles_base.channel_time - 0.001:
			_fail("Haste should speed Missiles ticks and shorten the channel")
		var g_spread = recipe_script.make("ground_aoe", PackedStringArray(), PackedStringArray(["spread"]))
		var gs = compiler.compile(g_spread, "Q")
		var g_base = catalog.get_base("ground_aoe")
		if gs == null or g_base == null:
			_fail("Ground AOE+Spread compile failed")
		elif gs.aoe_radius <= g_base.aoe_radius + 0.001 or gs.tick_damage >= g_base.tick_damage - 0.001:
			_fail("Spread should grow Ground AOE and cut its damage")
		var power = load("res://scripts/spells/spell_power.gd")
		var nature_alt = recipe_script.make("bolt", PackedStringArray(["nature"]), PackedStringArray(["altered"]))
		var n_ab = compiler.compile(nature_alt, "Q")
		if n_ab == null or not n_ab.altered or n_ab.damage <= 0.05 or power.ghosts_enemies(n_ab) or String(n_ab.description).find("Seeded") < 0:
			_fail("Nature+Alteration should hit enemies and apply Seeded")
		var nature_only = recipe_script.make("bolt", PackedStringArray(["nature"]))
		var plain_n = compiler.compile(nature_only, "Q")
		if plain_n == null or plain_n.altered or plain_n.damage > 0.05 or not power.ghosts_enemies(plain_n):
			_fail("Nature without Alteration should stay a ghosting heal")
		var target_n = recipe_script.make("target", PackedStringArray(["nature"]), PackedStringArray(["altered"]))
		var t_ab = compiler.compile(target_n, "Q")
		if t_ab == null or t_ab.friendly_only or not t_ab.can_target_enemies() or not t_ab.can_target_allies():
			_fail("Nature+Alteration Target should lock allies or enemies")
		var fn_alt = recipe_script.make("bolt", PackedStringArray(["fire", "nature"]), PackedStringArray(["altered"]))
		var fn_ab = compiler.compile(fn_alt, "Q")
		var fn_buffs: PackedInt32Array = fn_ab.altered_buff_elements() if fn_ab != null else PackedInt32Array()
		if fn_ab == null or fn_buffs.size() != 1 or fn_buffs[0] != 1 or String(fn_ab.description).find("Seeded") < 0:
			_fail("Fire+Nature+Alteration should grant Altered Fire and Seeded")
		var divine_alt = recipe_script.make("bolt", PackedStringArray(["divine"]), PackedStringArray(["altered"]))
		var d_ab = compiler.compile(divine_alt, "Q")
		if d_ab == null or not d_ab.altered or d_ab.damage <= 0.05 or String(d_ab.description).find("Judged") < 0:
			_fail("Divine+Alteration should hit enemies and apply Judged")
		var prot_alt = recipe_script.make("target", PackedStringArray(["protection"]), PackedStringArray(["altered"]))
		var p_ab = compiler.compile(prot_alt, "Q")
		if p_ab == null or not p_ab.altered or p_ab.friendly_only or String(p_ab.description).find("Sundered") < 0:
			_fail("Protection+Alteration should apply Sundered and target enemies")
		var fd_alt = recipe_script.make("bolt", PackedStringArray(["fire", "divine"]), PackedStringArray(["altered"]))
		var fd_ab = compiler.compile(fd_alt, "Q")
		var fd_dmg = power.damage_elements_for(fd_ab) if fd_ab != null else PackedInt32Array()
		var fd_has_fire := false
		var fd_has_holy := false
		for el in fd_dmg:
			# 1 = Fire, 4 = Holy. Do not name AbilityDef in this script; --script parse must stay off the combat graph.
			if el == 1:
				fd_has_fire = true
			elif el == 4:
				fd_has_holy = true
		if fd_ab == null or not fd_has_fire or not fd_has_holy:
			_fail("Fire+Divine+Alteration should deal Fire and Divine damage slices")
		var ice_bolt = recipe_script.make("bolt", PackedStringArray(["ice"]))
		var ib = compiler.compile(ice_bolt, "Q")
		var bolt_base = catalog.get_base("bolt")
		if ib == null or bolt_base == null or abs(ib.cooldown - bolt_base.cooldown * 1.35) > 0.001:
			_fail("Ice Bolt cooldown should be +35% of the base")
		var fire_meteor = recipe_script.make("meteor", PackedStringArray(["fire"]))
		var fm = compiler.compile(fire_meteor, "Q")
		var meteor_base = catalog.get_base("meteor")
		if fm == null or meteor_base == null or abs(fm.cast_time - meteor_base.cast_time * 1.15) > 0.001:
			_fail("Fire Meteor cast time should be +15% of the base")
		var card = load("res://scripts/spells/spell_card.gd")
		if card != null:
			var fire_tip := String(card.piece_tooltip("infusion", "fire", false))
			if fire_tip.find("base spell power") < 0 or fire_tip.find("to base cast time") < 0 or fire_tip.find("base value") >= 0:
				_fail("Fire infusion tooltip should use base spell power and base cast time")
			var ice_tip := String(card.piece_tooltip("infusion", "ice", false))
			if ice_tip.find("to base CD") < 0:
				_fail("Ice infusion tooltip should say to base CD")
	if _failures == failures_before:
		print("Augment matrix OK")


func _check_spell_tags() -> void:
	var catalog = load("res://scripts/spells/spell_catalog.gd")
	var tags_script = load("res://scripts/spells/spell_tags.gd")
	var class_cat = load("res://scripts/talents/class_catalog.gd")
	if catalog == null or tags_script == null or class_cat == null:
		_fail("Could not load spell tag scripts")
		return
	if not is_equal_approx(tags_script.NO_CAST_THRESHOLD, 0.25):
		_fail("No-cast threshold should be 0.25s")
		return
	class_cat.ensure()
	if not catalog.tags_for("bolt").has("skillshot") or not catalog.tags_for("bolt").has("no_cast_time"):
		_fail("Bolt should be tagged skillshot and no_cast_time")
		return
	if catalog.tags_for("bolt").has("cast_time"):
		_fail("Bolt 0.15s must count as no cast time")
		return
	if not catalog.tags_for("wave").has("skillshot") or not catalog.tags_for("ray").has("skillshot"):
		_fail("Wave and Ray should be tagged skillshot")
		return
	if not catalog.tags_for("ground_aoe").has("ground_aoe") or not catalog.tags_for("ground_aoe").has("no_cast_time"):
		_fail("Ground AOE should be tagged ground_aoe and no_cast_time")
		return
	if not catalog.tags_for("wall").has("no_cast_time"):
		_fail("Wall 0.15s must count as no cast time")
		return
	if catalog.augment_fits("wall", "haste") or catalog.augment_fits("wall", "snap_cast") or catalog.augment_fits("wall", "ritual"):
		_fail("Wall should not take Haste, Snap Cast, or Ritual")
		return
	if not catalog.tags_for("aoe_explosion").has("cast_time") or not catalog.tags_for("meteor").has("cast_time"):
		_fail("Burst and Meteor should be tagged cast_time")
		return
	if not catalog.tags_for("pyre").has("cast_time") or catalog.tags_for("pyre").has("skillshot") or catalog.tags_for("pyre").has("bolt"):
		_fail("Pyre should be a 1.8s target skill, not a skillshot bolt")
		return
	if not catalog.tags_for("pyre").has("target") or not catalog.tags_for("pyre").has("unit_target"):
		_fail("Pyre should be tagged as a unit-target skill")
		return
	if catalog.augment_fits("pyre", "volley") or catalog.augment_fits("pyre", "pierce") or catalog.augment_fits("pyre", "fan"):
		_fail("Volley, Pierce, and Fan should not fit Pyre")
		return
	if catalog.augment_fits("pyre", "haste") == false or catalog.augment_fits("pyre", "snap_cast") == false:
		_fail("Haste and Snap Cast should fit Pyre's 1.8s cast")
		return
	if not catalog.tags_for("ashen_crucible").has("skillshot") or not catalog.tags_for("ashen_crucible").has("wave"):
		_fail("Ashen Crucible should be a skillshot wave")
		return
	if not catalog.tags_for("hearthguard").has("ground_aoe") or not catalog.tags_for("worldbloom").has("ground_aoe"):
		_fail("Hearthguard and Worldbloom should be tagged ground_aoe")
		return
	if not catalog.tags_for("iron_rampage").has("no_cast_time"):
		_fail("Iron Rampage should count as no cast time")
		return
	for base in catalog.all_bases():
		var tagged: PackedStringArray = catalog.tags_for(base.id)
		var cast_tags := 0
		if tagged.has("no_cast_time"):
			cast_tags += 1
		if tagged.has("cast_time"):
			cast_tags += 1
		if cast_tags != 1:
			_fail("%s should have exactly one of no_cast_time or cast_time" % base.display_name)
			return
	var spread = catalog.get_augment("spread")
	if spread == null or not spread.requires_any.has("ground_aoe"):
		_fail("Spread should require the ground_aoe tag")
		return
	var volley = catalog.get_augment("volley")
	if volley == null or not volley.requires_any.has("bolt") or not volley.requires_any.has("wave") or not volley.requires_all.has("skillshot"):
		_fail("Volley should require a skillshot bolt or wave")
		return
	var pierce = catalog.get_augment("pierce")
	if pierce == null or not pierce.requires_all.has("skillshot"):
		_fail("Pierce should require the skillshot tag")
		return
	var haste = catalog.get_augment("haste")
	if haste == null or not haste.requires_any.has("cast_time") or not haste.requires_any.has("channel") or not haste.blocked_tags.has("bolt"):
		_fail("Haste should need cast time or a channel, and block bolt")
		return
	var snap = catalog.get_augment("snap_cast")
	if snap == null or not snap.requires_all.has("cast_time"):
		_fail("Snap Cast should require the cast_time tag")
		return
	print("Spell tags OK")


func _check_class_catalog() -> void:
	var catalog = load("res://scripts/talents/class_catalog.gd")
	var validator = load("res://scripts/talents/talent_validator.gd")
	var spend_script = load("res://scripts/talents/talent_spend.gd")
	if catalog == null or validator == null or spend_script == null:
		_fail("Could not load talent catalog")
		return
	catalog.ensure()
	var specs = catalog.all_classes()
	if specs.size() != 6:
		_fail("Expected 6 specs, got %d" % specs.size())
		return
	for entry in specs:
		var class_errors: PackedStringArray = validator.validate(entry)
		if not class_errors.is_empty():
			_fail("%s catalog: %s" % [entry.id, ", ".join(class_errors)])
			return
		if entry.auto == null:
			_fail("%s missing baseline auto-attack" % entry.id)
			return
		if entry.trees.size() != 1:
			_fail("%s should have 1 choice-row tree" % entry.id)
			return
	var spend = spend_script.new()
	var kindling = catalog.def_for("kindling")
	var kindling_tree = kindling.trees[0]
	var singe_t = kindling_tree.talent_at(kindling_tree.index_of("kindling_mid_singe"))
	var scorch_t = kindling_tree.talent_at(kindling_tree.index_of("kindling_mid_scorch"))
	if singe_t == null or singe_t.type != "interaction":
		_fail("Singe should be a Furnace interaction")
		return
	if scorch_t == null or scorch_t.type != "interaction":
		_fail("Scorch should be a Furnace interaction")
		return
	var t2_cost: int = kindling_tree.unlock_cost(1)
	var ult_cost: int = kindling_tree.unlock_cost(kindling_tree.row_count() - 1)
	if ult_cost != 18:
		_fail("Furnace ultimate should unlock at 18, got %d" % ult_cost)
		return
	if not spend.can_invest("kindling_embers_emberheart"):
		_fail("Should be able to invest Emberheart")
		return
	spend.invest("kindling_embers_emberheart")
	if spend.rank_of("kindling_embers_emberheart") != 1:
		_fail("Emberheart rank should be 1")
		return
	if not spend.can_invest("kindling_detonation_hot_hands"):
		_fail("Hot Hands should stay available in the same row as Emberheart")
		return
	spend.invest("kindling_detonation_hot_hands")
	if spend.can_invest("kindling_embers_live_coals"):
		_fail("Live Coals should stay locked until %d points are in Kindling" % t2_cost)
		return
	if spend.can_invest("kindling_ult_pyre"):
		_fail("Pyre should stay locked until %d points are in Kindling" % ult_cost)
		return
	if spend.can_refund("kindling_embers_emberheart") == false:
		_fail("Should be able to refund Emberheart while the next tier is empty")
		return
	while spend.points_spent() < t2_cost:
		if not spend.invest("kindling_mid_cinder_focus"):
			_fail("Should be able to fill Cinder Focus to unlock the next tier")
			return
	if not spend.can_invest("kindling_embers_live_coals"):
		_fail("Live Coals should unlock after %d points in earlier rows" % t2_cost)
		return
	spend.invest("kindling_embers_live_coals")
	if spend.can_refund("kindling_mid_cinder_focus"):
		_fail("Cannot refund Cinder Focus if it would drop below the %d-point unlock" % t2_cost)
		return
	if spend.can_refund("kindling_embers_live_coals") == false:
		_fail("Should be able to refund Live Coals when later tiers are empty")
		return
	var tank = catalog.def_for("aegis")
	var tank_errors: PackedStringArray = validator.validate(tank)
	if not tank_errors.is_empty():
		_fail("Aegis catalog: %s" % ", ".join(tank_errors))
		return
	var tank_spend = spend_script.new()
	tank_spend.set_class_id("aegis")
	if tank_spend.class_id != "aegis":
		_fail("TalentSpend should switch to Aegis")
		return
	if not tank_spend.can_invest("aegis_plate_slab"):
		_fail("Should be able to invest Slab")
		return
	tank_spend.invest("aegis_plate_slab")
	if tank_spend.rank_of("aegis_plate_slab") != 1:
		_fail("Slab rank should be 1")
		return
	if catalog.get_skill("iron_rampage") == null or catalog.get_skill("hearthguard") == null:
		_fail("Tank spec D/F skills missing Iron Rampage or Hearthguard")
		return
	var kit = load("res://scripts/talents/bulwark_kit.gd")
	if kit == null:
		_fail("Could not load BulwarkKit")
		return
	var npc_spend = kit.spend()
	if npc_spend.points_spent() != spend_script.STARTING_POINTS:
		_fail("NPC tank kit should spend %d points, spent %d" % [spend_script.STARTING_POINTS, npc_spend.points_spent()])
		return
	if npc_spend.slot_d != "iron_rampage":
		_fail("NPC tank kit should bind Iron Rampage")
		return
	npc_spend.slot_d = ""
	npc_spend.slot_f = ""
	npc_spend.sanitize_binds()
	if npc_spend.slot_d != "iron_rampage" or not npc_spend.slot_f.is_empty():
		_fail("Unlocked ultimates should auto-bind D then F")
		return
	npc_spend.swap_binds()
	if not npc_spend.slot_d.is_empty() or npc_spend.slot_f != "iron_rampage":
		_fail("Swap should move a lone ultimate to F and leave D empty")
		return
	npc_spend.sanitize_binds()
	if not npc_spend.slot_d.is_empty() or npc_spend.slot_f != "iron_rampage":
		_fail("Sanitize should not move a swapped ultimate back to D")
		return
	if npc_spend.rank_of("aegis_ult_iron_rampage") < 1:
		_fail("NPC tank kit missing Iron Rampage talent")
		return
	if npc_spend.rank_of("aegis_auto_iron_fist") < 1:
		_fail("NPC tank kit missing Iron Fist")
		return
	var healer = catalog.def_for("wildroot")
	var healer_errors: PackedStringArray = validator.validate(healer)
	if not healer_errors.is_empty():
		_fail("Wildroot catalog: %s" % ", ".join(healer_errors))
		return
	var healer_spend = spend_script.new()
	healer_spend.set_class_id("wildroot")
	if healer_spend.class_id != "wildroot":
		_fail("TalentSpend should switch to Wildroot")
		return
	if not healer_spend.can_invest("wildroot_canopy_greenheart"):
		_fail("Should be able to invest Greenheart")
		return
	healer_spend.invest("wildroot_canopy_greenheart")
	if healer_spend.rank_of("wildroot_canopy_greenheart") != 1:
		_fail("Greenheart rank should be 1")
		return
	if catalog.get_skill("worldbloom") == null or catalog.get_skill("eye_of_tempest") == null:
		_fail("Healer spec skills missing Worldbloom or Eye of Tempest")
		return
	if catalog.get_skill("pyre") == null or catalog.get_skill("ashen_crucible") == null:
		_fail("DPS spec ultimates missing Pyre or Ashen Crucible")
		return
	var melee = spend_script.new()
	melee.set_spec_slot(0, "aegis")
	melee.set_spec_slot(1, "bastion")
	var melee_path: Array = [
		["aegis_plate_slab", 3],
		["aegis_mid_stamina", 3],
		["aegis_plate_shared_plate", 2],
		["aegis_mid_guard", 3],
		["aegis_plate_anointed", 2],
		["aegis_mid_resolve", 3],
		["aegis_auto_iron_fist", 1],
		["bastion_rampart_footing", 3],
		["bastion_mid_foundation", 3],
		["bastion_rampart_undertow", 2],
		["bastion_mid_oathbound", 3],
		["bastion_rampart_masonry", 3],
		["bastion_oath_cover", 2],
	]
	for step in melee_path:
		var talent_id: String = step[0]
		var want: int = step[1]
		while melee.rank_of(talent_id) < want:
			if not melee.invest(talent_id):
				_fail("Could not invest %s on melee uniqueness path" % talent_id)
				return
	if melee.can_invest("bastion_auto_ward_strike"):
		_fail("Ward Strike should lock while Iron Fist is invested")
		return
	if not melee.can_invest("bastion_auto_aegis_shot"):
		_fail("Aegis Shot should stay available as the non-melee auto")
		return
	if spend_script.SPEC_SLOTS != 2:
		_fail("Loadout should have 2 spec slots")
		return
	var third = spend_script.new()
	third.set_spec_slot(0, "kindling")
	third.set_spec_slot(1, "bastion")
	third.set_spec_slot(2, "tempest")
	if not String(third.spec_id_at(2)).is_empty():
		_fail("Third spec slot should be rejected")
		return
	var migrated = spend_script.from_dict({
		"spec_ids": ["kindling", "bastion", "tempest"],
		"ranks": {"tempest_mid_charge": 2, "kindling_mid_cinder_focus": 1},
	})
	if migrated.spec_ids.size() != 2:
		_fail("Saved 3-spec loadouts should clamp to 2 slots")
		return
	if migrated.spec_id_at(0) != "kindling" or migrated.spec_id_at(1) != "bastion":
		_fail("First two specs should survive the 2-slot clamp")
		return
	if migrated.rank_of("tempest_mid_charge") > 0:
		_fail("Dropped third spec should refund its ranks")
		return
	var mend = load("res://scripts/talents/mend_kit.gd")
	if mend == null:
		_fail("Could not load MendKit")
		return
	var mend_recipes: Array = mend.recipes()
	if mend_recipes.size() != 4:
		_fail("Mend kit should have 4 crafted heals")
		return
	var st = mend_recipes[0]
	if st == null or st.base_id != "target" or st.infusion_ids.is_empty() or st.infusion_ids[0] != "divine":
		_fail("Mend kit Q should be Divine Target")
		return
	print("Class catalog OK")


func _check_skill_overlays() -> void:
	var catalog = load("res://scripts/spells/spell_catalog.gd")
	var recipe_script = load("res://scripts/spells/spell_recipe.gd")
	var compiler = load("res://scripts/spells/spell_compiler.gd")
	if catalog == null or recipe_script == null or compiler == null:
		_fail("Could not load skill overlay scripts")
		return
	if catalog.BAR_SLOTS != 6 or catalog.HOTKEYS.size() != 6 or catalog.SKILL_SLOTS != 2:
		_fail("Bar should be QWER plus D/F")
		return
	if catalog.skill_as_base("pyre") == null:
		_fail("Pyre should resolve as a class-skill base")
		return
	if catalog.augment_fits("pyre", "efficiency") == false:
		_fail("Efficiency should fit Pyre")
		return
	if catalog.augment_fits("pyre", "volley") or catalog.augment_fits("pyre", "pierce"):
		_fail("Volley and Pierce should not fit Pyre (unit-target skill)")
		return
	if catalog.augment_fits("pyre", "haste") == false:
		_fail("Haste should fit Pyre (1.8s target cast)")
		return
	var overlay = recipe_script.make("pyre", PackedStringArray(["fire"]), PackedStringArray(["efficiency"]))
	if overlay.has_infusion("fire"):
		_fail("Class-skill recipes must not keep infusions")
		return
	var bare = compiler.compile_skill("pyre", null, "D")
	var buffed = compiler.compile_skill("pyre", overlay, "D")
	if buffed == null or buffed.skill_id != "pyre":
		_fail("Augmented Pyre must keep its class skill id")
		return
	if not buffed.infusion_ids.is_empty():
		_fail("Augmented class skills must not apply infusions")
		return
	if buffed.mana_cost >= bare.mana_cost - 0.05:
		_fail("Efficiency should cut Pyre mana")
		return
	var empty = recipe_script.new()
	empty.base_id = ""
	empty.augment_ids = PackedStringArray(["efficiency"])
	var empty_ab = compiler.compile_slot(empty, "D")
	if empty_ab == null or String(empty_ab.display_name) == "Bolt" or empty_ab.icon_id == "bolt":
		_fail("Empty D/F should not show Bolt")
		return
	if String(empty_ab.display_name) != "Empty":
		_fail("Empty D/F should compile as an empty ultimate slot")
		return
	print("Skill overlays OK")


func _check_raid_comp() -> void:
	var dps := RaidComp.ai_members(RaidComp.ROLE_DPS)
	if dps != PackedStringArray(["bulwark", "mend", "hex", "vex"]):
		_fail("DPS role should spawn Bulwark, Mend, Hex, Vex")
		return
	var tank := RaidComp.ai_members(RaidComp.ROLE_TANK)
	if tank.has("bulwark"):
		_fail("Tank role should not spawn Bulwark")
		return
	if not tank.has("mend") or not tank.has("rook"):
		_fail("Tank role should spawn Mend and a fill DPS")
		return
	var healer := RaidComp.ai_members(RaidComp.ROLE_HEALER)
	if healer.has("mend"):
		_fail("Healer role should not spawn Mend")
		return
	if not healer.has("bulwark") or not healer.has("rook"):
		_fail("Healer role should spawn Bulwark and a fill DPS")
		return
	for role in [RaidComp.ROLE_TANK, RaidComp.ROLE_HEALER, RaidComp.ROLE_DPS, "bogus"]:
		if RaidComp.ai_members(role).size() != 4:
			_fail("AI raid must stay 4 allies for role %s" % role)
			return
	if RaidComp.normalize_role("TANK") != RaidComp.ROLE_TANK:
		_fail("Role names should normalize")
		return
	print("Raid composition OK")


func _check_arena_layouts() -> void:
	var destinations := ArenaCatalog.destinations()
	if destinations.size() < 3:
		_fail("ArenaCatalog should list training, colossus, and dawnwarden")
		return
	var ids: PackedStringArray = PackedStringArray()
	for row in destinations:
		ids.append(String(row.get("id", "")))
		var path := String(row.get("layout", ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			_fail("ArenaCatalog layout missing for %s (%s)" % [row.get("id", ""), path])
			return
		var packed := load(path) as PackedScene
		if packed == null:
			_fail("ArenaCatalog could not load %s" % path)
			return
		var node := packed.instantiate()
		var layout := node as ArenaLayout
		if layout == null:
			node.free()
			_fail("Layout root must be ArenaLayout: %s" % path)
			return
		layout.bind_to_arena()
		if layout.nav_region == null:
			layout.free()
			_fail("Layout missing NavigationRegion3D: %s" % path)
			return
		if layout.floor_body() == null:
			layout.free()
			_fail("Layout missing Floor StaticBody3D: %s" % path)
			return
		if not layout.has_marker("PlayerSpawn"):
			layout.free()
			_fail("Layout missing PlayerSpawn marker: %s" % path)
			return
		if not layout.has_marker("BossSpawn"):
			layout.free()
			_fail("Layout missing BossSpawn marker: %s" % path)
			return
		layout.free()
	if not ids.has("training") or not ids.has("colossus") or not ids.has("dawnwarden"):
		_fail("ArenaCatalog missing a shipped destination id")
		return
	if not ArenaCatalog.is_training("training"):
		_fail("training destination should be marked training")
		return
	if ArenaCatalog.boss_id("dawnwarden") != "dawnwarden":
		_fail("dawnwarden destination should map to dawnwarden boss")
		return
	var dawn := (load("res://scenes/arena/layouts/dawnwarden.tscn") as PackedScene).instantiate() as ArenaLayout
	dawn.bind_to_arena()
	if dawn.use_stock_decor:
		dawn.free()
		_fail("Dawnwarden layout should not spawn stock decor")
		return
	if dawn.pillar_anchors().size() != 10:
		var count := dawn.pillar_anchors().size()
		dawn.free()
		_fail("Dawnwarden layout should expose 10 PillarSpawn markers, got %d" % count)
		return
	if dawn.has_marker("TrainingPlayer"):
		dawn.free()
		_fail("Dawnwarden layout should not include training spawn markers")
		return
	dawn.free()
	var colossus := (load("res://scenes/arena/layouts/colossus.tscn") as PackedScene).instantiate() as ArenaLayout
	if colossus.has_marker("TrainingPlayer"):
		colossus.free()
		_fail("Colossus layout should not include training spawn markers")
		return
	colossus.free()
	var training := (load("res://scenes/arena/layouts/training.tscn") as PackedScene).instantiate() as ArenaLayout
	if not training.has_marker("TrainingPlayer"):
		training.free()
		_fail("Training layout should include TrainingPlayer")
		return
	training.free()
	for row in destinations:
		var layout_path := String(row.get("layout", ""))
		var src := FileAccess.get_file_as_string(layout_path)
		if src.contains("plaza.tscn"):
			_fail("Layout must not instance plaza.tscn: %s" % layout_path)
			return
		for other in destinations:
			var other_path := String(other.get("layout", ""))
			if other_path == layout_path:
				continue
			var other_file := other_path.get_file()
			if src.contains(other_file):
				_fail("Layout %s must not instance %s" % [layout_path, other_file])
				return
	print("Arena layouts OK")


func _check_cleanup_guards() -> void:
	var errors: PackedStringArray = CleanupGuards.run()
	for message in errors:
		_fail(message)
	if errors.is_empty():
		print("Cleanup guards OK")


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
