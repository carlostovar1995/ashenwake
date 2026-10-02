extends RefCounted
## Shared bootstrap for the regression-baseline scenes (scenario, perf, shots).
## Boots the real main scene, pins every piece of saved player state that could
## change the fight, and gives each caster a fixed loadout.

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT_DIR := "res://tools/out"
const PHYSICS_HZ := 60
const PLAYER_HEALTH := 1.0e6

## One row per player: four crafted recipes ("base:infusion+infusion:augment+augment")
## and the D / F class skills. Together the five rows cover every spell base,
## every infusion, and a spread of class skills.
const LOADOUTS := [
	{
		"name": "Ember",
		"recipes":
		["bolt:fire", "missiles:lightning:volley", "ground_aoe:ice:lingering", "meteor:fire"],
		"skills": ["pyre", "ashen_crucible"],
	},
	{
		"name": "Bulwark",
		"recipes": ["wall:protection", "nova:shadow:widen", "aoe_explosion:fire", "bolt:wind"],
		"perf_recipes": ["wall:fire", "nova:shadow:widen", "aoe_explosion:fire", "bolt:wind"],
		"skills": ["iron_rampage", "hearthguard"],
	},
	{
		"name": "Mend",
		"recipes": ["target:nature", "aura:divine", "ground_aoe:nature", "wave:ice"],
		"skills": ["worldbloom", "eye_of_tempest"],
	},
	{
		"name": "Hex",
		"recipes": ["ray:lightning", "bolt:shadow:pierce", "missiles:illusion", "meteor:shadow"],
		"skills": ["ashen_crucible", "pyre"],
	},
	{
		"name": "Vex",
		"recipes": ["wave:wind", "nova:divine", "aoe_explosion:ice", "target:protection"],
		"skills": ["eye_of_tempest", "worldbloom"],
	},
]


static func args() -> Dictionary:
	var out := {}
	for raw in OS.get_cmdline_user_args():
		var text := String(raw).trim_prefix("--")
		var eq := text.find("=")
		if eq >= 0:
			out[text.substr(0, eq)] = text.substr(eq + 1)
		else:
			out[text] = "true"
	return out


static func out_dir() -> String:
	var path := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(path)
	return path


static func write_text(file_name: String, text: String) -> String:
	var path := out_dir().path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("baseline: cannot write %s" % path)
		return path
	file.store_string(text)
	file.close()
	return path


## Boots main.tscn under `host` and returns once the match has spawned.
## training = single champion + dummies; otherwise 5 players + the chosen boss.
static func boot(host: Node, training: bool, boss_id: String = "colossus") -> Node:
	var tree := host.get_tree()
	_pin_session(training, boss_id)
	var main := (load(MAIN_SCENE) as PackedScene).instantiate()
	host.add_child(main)
	for i in 40:
		await tree.process_frame
	GameSession.request_match(training)
	for i in 900:
		await tree.process_frame
		if _match_ready(training):
			break
	if not _match_ready(training):
		push_error("baseline: match did not spawn (training=%s boss=%s)" % [training, boss_id])
	# Let spawn-time deferred work (visual attach, nav bake follow-ups) settle.
	for i in 30:
		await tree.process_frame
	return main


static func _match_ready(training: bool) -> bool:
	if not GameSession.fight_started or ArenaState.champion == null:
		return false
	if training:
		return true
	return ArenaState.boss != null and ArenaState.allies.size() == 4


## Overrides whatever the local user has saved so runs compare across machines.
static func _pin_session(training: bool, boss_id: String) -> void:
	GameSession.talent_spend = TalentSpend.new()
	GameSession.spell_loadout = SpellCatalog.default_loadout()
	GameSession.skill_loadout = []
	GameSession.player_role = RaidComp.ROLE_DPS
	GameSession.selected_boss_id = boss_id
	GameSession.spawn_ai_raid = true
	GameSession.training_mode = training
	GameSession.ignore_cooldowns = true
	GameSession.infinite_mana = true
	GameSession.dev_test_mode = false
	GameSession.smart_cast = false
	GameSession.show_damage_numbers = true


## One-shot SFX draw their pitch from the global RNG only when a pooled player is
## free, and "free" depends on real playback time. That makes the crit and arc
## rolls drift between otherwise identical runs, so deterministic runs drop the
## pool. Owned cast loops are unaffected.
static func silence_audio() -> void:
	var pool: Array = AudioManager._pool
	for player in pool:
		if is_instance_valid(player):
			player.queue_free()
	pool.clear()


static func players() -> Array[Unit]:
	var out: Array[Unit] = []
	if ArenaState.champion != null:
		out.append(ArenaState.champion)
	for ally in ArenaState.allies:
		out.append(ally)
	return out


static func recipe_from(spec: String) -> SpellRecipe:
	var parts := spec.split(":")
	var infusions := (
		PackedStringArray(parts[1].split("+")) if parts.size() > 1 else PackedStringArray()
	)
	var augments := (
		PackedStringArray(parts[2].split("+")) if parts.size() > 2 else PackedStringArray()
	)
	return SpellRecipe.make(parts[0], infusions, augments)


static func abilities_for(row: int, perf: bool = false) -> Array[AbilityDef]:
	var def: Dictionary = LOADOUTS[row % LOADOUTS.size()]
	var out: Array[AbilityDef] = []
	var recipes: Array = def.get("perf_recipes", def["recipes"]) if perf else def["recipes"]
	for i in recipes.size():
		var ab := SpellCompiler.compile(
			recipe_from(String(recipes[i])), SpellCatalog.CRAFTED_HOTKEYS[i]
		)
		out.append(ab)
	var skills: Array = def["skills"]
	for i in skills.size():
		var hotkey := "D" if i == 0 else "F"
		var skill_id := String(skills[i])
		if ClassCatalog.get_skill(skill_id) == null:
			push_warning("baseline: unknown class skill '%s'" % skill_id)
			out.append(ClassSkillCompiler.empty_slot(hotkey))
		else:
			out.append(ClassSkillCompiler.compile(skill_id, hotkey))
	return out


## Applies the fixed loadout to a unit and keeps it alive for the whole run.
static func equip(unit: Unit, row: int, perf: bool = false) -> void:
	unit.apply_compiled_abilities(abilities_for(row, perf))
	unit.max_health = PLAYER_HEALTH
	unit.health = PLAYER_HEALTH
	unit.max_mana = 100000.0
	unit.mana = unit.max_mana


static func godot_version() -> String:
	var info := Engine.get_version_info()
	return "%s.%s.%s-%s" % [info.major, info.minor, info.patch, info.status]
