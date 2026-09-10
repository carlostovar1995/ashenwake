extends Node

signal session_started
signal unit_assigned(unit)
signal loadout_changed
signal talents_changed

const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const LOADOUT_PATH := "user://spell_loadout.json"
const LOADOUT_VERSION := 3

var fight_started: bool = false
var active_unit: Unit = null
var spell_loadout: Array = []
var skill_loadout: Array = []
var spell_profiles: Dictionary = {}
var skill_profiles: Dictionary = {}
var active_profile: String = ""
var talent_spend: TalentSpend = TalentSpend.new()
var selected_boss_id: String = "colossus"
var selected_destination_id: String = "training"
var training_mode: bool = true
var spawn_ai_raid: bool = true
## Lobby checkbox. Raid HP floors at 1; Dawnwarden Judgment Rays lock onto you.
var dev_test_mode: bool = false
var player_role: String = RaidComp.ROLE_DPS
var ignore_cooldowns: bool = true
var infinite_mana: bool = true
var selected_target: Unit = null
var smart_cast: bool = false
var show_damage_numbers: bool = true
var unit_hover_width: float = 0.050
var spell_hover_width: float = 0.10

signal match_requested
signal balance_changed


func notify_balance_changed() -> void:
	SpellCatalog.invalidate()
	ClassCatalog.invalidate()
	_apply_loadout_to_unit()
	balance_changed.emit()


func ignores_cooldowns() -> bool:
	return training_mode and ignore_cooldowns


func has_infinite_mana() -> bool:
	return training_mode and infinite_mana


func _ready() -> void:
	_ensure_input_map()
	ClassCatalog.ensure()
	if not talent_spend.changed.is_connected(_on_talents_changed):
		talent_spend.changed.connect(_on_talents_changed)
	var had_save := FileAccess.file_exists(LOADOUT_PATH)
	_load_persisted_loadout()
	ensure_loadout()
	if had_save:
		persist_loadout()


func ensure_loadout() -> void:
	if spell_loadout.size() != SpellCatalog.CRAFT_SLOTS:
		spell_loadout = SpellCatalog.default_loadout()
	else:
		for i in SpellCatalog.CRAFT_SLOTS:
			var item = spell_loadout[i]
			if not (item is SpellRecipe):
				spell_loadout = SpellCatalog.default_loadout()
				break
			var recipe: SpellRecipe = item
			recipe.base_id = SpellCatalog.migrate_base_id(recipe.base_id)
			var migrated := PackedStringArray()
			var augs := PackedStringArray()
			for inf_id in recipe.infusion_ids:
				var next_id := SpellCatalog.migrate_infusion_id(inf_id)
				var as_aug := SpellCatalog.infusion_becomes_augment(inf_id)
				if as_aug.is_empty():
					as_aug = SpellCatalog.infusion_becomes_augment(next_id)
				if not as_aug.is_empty():
					if not augs.has(as_aug) and augs.size() < SpellRecipe.MAX_AUGMENTS:
						augs.append(as_aug)
					continue
				if not next_id.is_empty() and SpellCatalog.get_infusion(next_id) != null and not migrated.has(next_id):
					migrated.append(next_id)
			recipe.infusion_ids = migrated
			for aug_id in recipe.augment_ids:
				var next_aug := SpellCatalog.migrate_augment_id(aug_id)
				if not next_aug.is_empty() and SpellCatalog.get_augment(next_aug) != null and not augs.has(next_aug):
					augs.append(next_aug)
			recipe.augment_ids = augs
			recipe.normalize()
	_ensure_skill_loadout()


func set_slot_recipe(index: int, recipe: SpellRecipe) -> void:
	ensure_loadout()
	if recipe == null:
		return
	if SpellCatalog.is_craft_index(index):
		spell_loadout[index] = recipe
	elif SpellCatalog.is_skill_index(index):
		_store_skill_recipe(index - SpellCatalog.CRAFT_SLOTS, recipe)
	else:
		return
	_apply_loadout_to_unit()
	persist_loadout()
	loadout_changed.emit()


func skill_recipe(index: int) -> SpellRecipe:
	ensure_loadout()
	if index < 0 or index >= skill_loadout.size():
		return null
	var item = skill_loadout[index]
	return item as SpellRecipe if item is SpellRecipe else null


func bound_skill_id(bar_index: int) -> String:
	if bar_index == SpellCatalog.CRAFT_SLOTS:
		return talent_spend.slot_d
	if bar_index == SpellCatalog.CRAFT_SLOTS + 1:
		return talent_spend.slot_f
	return ""


func swap_skill_binds() -> void:
	ensure_loadout()
	while skill_loadout.size() < SpellCatalog.SKILL_SLOTS:
		skill_loadout.append(SpellRecipe.new())
	var tmp_id := talent_spend.slot_d
	talent_spend.slot_d = talent_spend.slot_f
	talent_spend.slot_f = tmp_id
	var tmp_recipe = skill_loadout[0]
	skill_loadout[0] = skill_loadout[1]
	skill_loadout[1] = tmp_recipe
	talent_spend.sanitize_binds()
	_ensure_skill_loadout()
	_apply_loadout_to_unit()
	persist_loadout()
	talents_changed.emit()
	loadout_changed.emit()


func apply_loadout(next: Array, profile_name: String = "", skill_next: Array = []) -> void:
	if next.size() != SpellCatalog.CRAFT_SLOTS:
		return
	var copy: Array = []
	for item in next:
		if not (item is SpellRecipe):
			return
		copy.append((item as SpellRecipe).duplicate_recipe())
	spell_loadout = copy
	skill_loadout = _copy_skill_recipes(skill_next)
	active_profile = profile_name
	ensure_loadout()
	_apply_loadout_to_unit()
	persist_loadout()
	loadout_changed.emit()


func profile_names() -> PackedStringArray:
	var names: Array = spell_profiles.keys()
	names.sort()
	var out := PackedStringArray()
	for name in names:
		out.append(String(name))
	return out


func is_profile_dirty() -> bool:
	if active_profile.is_empty() or not spell_profiles.has(active_profile):
		return true
	if not _loadout_matches_data(spell_profiles[active_profile], spell_loadout):
		return true
	return not _loadout_matches_data(skill_profiles.get(active_profile, []), skill_loadout)


func save_profile(profile_name: String) -> bool:
	var name := _sanitize_profile_name(profile_name)
	if name.is_empty():
		return false
	ensure_loadout()
	spell_profiles[name] = _recipes_to_data(spell_loadout)
	skill_profiles[name] = _recipes_to_data(skill_loadout)
	active_profile = name
	persist_loadout()
	loadout_changed.emit()
	return true


func apply_profile(profile_name: String) -> bool:
	var name := String(profile_name)
	if name.is_empty() or not spell_profiles.has(name):
		return false
	var recipes := _recipes_from_data(spell_profiles[name])
	var skills := _skill_recipes_from_data(skill_profiles.get(name, []))
	apply_loadout(recipes, name, skills)
	return true


func delete_profile(profile_name: String) -> void:
	var name := String(profile_name)
	if name.is_empty() or not spell_profiles.has(name):
		return
	spell_profiles.erase(name)
	skill_profiles.erase(name)
	if active_profile == name:
		active_profile = ""
	persist_loadout()
	loadout_changed.emit()


func persist_loadout() -> void:
	ensure_loadout()
	var payload := {
		"version": LOADOUT_VERSION,
		"current": _recipes_to_data(spell_loadout),
		"skills": _recipes_to_data(skill_loadout),
		"active_profile": active_profile,
		"profiles": spell_profiles.duplicate(true),
		"profile_skills": skill_profiles.duplicate(true),
		"class": talent_spend.to_dict(),
		"player_role": RaidComp.normalize_role(player_role),
	}
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameSession: could not save spell loadout (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _load_persisted_loadout() -> void:
	if not FileAccess.file_exists(LOADOUT_PATH):
		return
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.READ)
	if file == null:
		push_warning("GameSession: could not read spell loadout (%s)" % error_string(FileAccess.get_open_error()))
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_warning("GameSession: ignored invalid spell loadout JSON")
		return
	var data: Dictionary = parsed
	var current := _recipes_from_data(data.get("current", []))
	if current.size() == SpellCatalog.CRAFT_SLOTS:
		spell_loadout = current
	skill_loadout = _skill_recipes_from_data(data.get("skills", []))
	active_profile = String(data.get("active_profile", ""))
	spell_profiles.clear()
	skill_profiles.clear()
	var raw_profiles = data.get("profiles", {})
	var raw_skill_profiles = data.get("profile_skills", {})
	if raw_profiles is Dictionary:
		for key in raw_profiles.keys():
			var name := _sanitize_profile_name(String(key))
			if name.is_empty():
				continue
			var recipes := _recipes_from_data(raw_profiles[key])
			if recipes.size() == SpellCatalog.CRAFT_SLOTS:
				spell_profiles[name] = _recipes_to_data(recipes)
			if raw_skill_profiles is Dictionary:
				skill_profiles[name] = _recipes_to_data(_skill_recipes_from_data(raw_skill_profiles.get(key, [])))
	if not active_profile.is_empty() and not spell_profiles.has(active_profile):
		active_profile = ""
	player_role = RaidComp.normalize_role(String(data.get("player_role", player_role)))
	var class_data = data.get("class", {})
	talent_spend = TalentSpend.from_dict(class_data if class_data is Dictionary else {})
	if not talent_spend.changed.is_connected(_on_talents_changed):
		talent_spend.changed.connect(_on_talents_changed)


func _recipes_to_data(recipes: Array) -> Array:
	var out: Array = []
	for item in recipes:
		if item is SpellRecipe:
			out.append((item as SpellRecipe).to_dict())
	return out


func _recipes_from_data(raw) -> Array:
	var rows: Array = raw if raw is Array else []
	var fallback := SpellCatalog.default_loadout()
	var out: Array = []
	for i in SpellCatalog.CRAFT_SLOTS:
		var item = rows[i] if i < rows.size() else null
		if item is Dictionary:
			out.append(SpellRecipe.from_dict(item))
		else:
			out.append((fallback[i] as SpellRecipe).duplicate_recipe())
	return out


func _loadout_matches_data(raw, live_recipes: Array) -> bool:
	var saved: Array
	if live_recipes == spell_loadout:
		saved = _recipes_from_data(raw)
	else:
		saved = _skill_recipes_from_data(raw)
	if saved.size() != live_recipes.size():
		return false
	for i in live_recipes.size():
		var live: SpellRecipe = live_recipes[i] if live_recipes[i] is SpellRecipe else null
		var other: SpellRecipe = saved[i] if saved[i] is SpellRecipe else null
		if live == null or not live.same_as(other):
			return false
	return true


func _ensure_skill_loadout() -> void:
	if skill_loadout.size() != SpellCatalog.SKILL_SLOTS:
		skill_loadout = _empty_skill_loadout()
	for i in SpellCatalog.SKILL_SLOTS:
		var item = skill_loadout[i] if i < skill_loadout.size() else null
		if not (item is SpellRecipe):
			item = SpellRecipe.new()
			skill_loadout[i] = item
		_store_skill_recipe(i, item)


func _empty_skill_loadout() -> Array:
	var out: Array = []
	for _i in SpellCatalog.SKILL_SLOTS:
		out.append(SpellRecipe.new())
	return out


func _copy_skill_recipes(source: Array) -> Array:
	var out := _empty_skill_loadout()
	for i in SpellCatalog.SKILL_SLOTS:
		var item = source[i] if i < source.size() else null
		if not (item is SpellRecipe):
			continue
		var next := SpellRecipe.new()
		next.infusion_ids = PackedStringArray()
		next.augment_ids = (item as SpellRecipe).augment_ids.duplicate()
		next.base_id = (item as SpellRecipe).base_id
		out[i] = next
	return out


func _skill_recipes_from_data(raw) -> Array:
	var rows: Array = raw if raw is Array else []
	var out := _empty_skill_loadout()
	for i in SpellCatalog.SKILL_SLOTS:
		var item = rows[i] if i < rows.size() else null
		if not (item is Dictionary):
			continue
		var next := SpellRecipe.new()
		next.infusion_ids = PackedStringArray()
		var augs := PackedStringArray()
		for id in item.get("augments", []):
			var aug_id := SpellCatalog.migrate_augment_id(String(id))
			if not aug_id.is_empty() and SpellCatalog.get_augment(aug_id) != null and not augs.has(aug_id):
				augs.append(aug_id)
		next.augment_ids = augs
		next.base_id = String(item.get("base", item.get("base_id", "")))
		out[i] = next
	return out


func _store_skill_recipe(index: int, recipe: SpellRecipe) -> void:
	if index < 0 or index >= SpellCatalog.SKILL_SLOTS or recipe == null:
		return
	while skill_loadout.size() < SpellCatalog.SKILL_SLOTS:
		skill_loadout.append(SpellRecipe.new())
	var next := SpellRecipe.new()
	next.infusion_ids = PackedStringArray()
	next.base_id = talent_spend.slot_d if index == 0 else talent_spend.slot_f
	if next.base_id.is_empty():
		next.augment_ids = PackedStringArray()
	else:
		next.augment_ids = recipe.augment_ids.duplicate()
		next.normalize()
	skill_loadout[index] = next


func _sanitize_profile_name(raw: String) -> String:
	var name := raw.strip_edges()
	name = name.replace("/", " ").replace("\\", " ").replace(":", " ")
	while name.find("  ") >= 0:
		name = name.replace("  ", " ")
	if name.length() > 24:
		name = name.substr(0, 24).strip_edges()
	return name


func _apply_loadout_to_unit() -> void:
	if active_unit == null or not is_instance_valid(active_unit):
		return
	active_unit.apply_compiled_abilities(ChampionLoadout.compile(spell_loadout, talent_spend, skill_loadout))
	var hooks := TalentHooks.from_spend(talent_spend)
	active_unit.bind_talent_hooks(hooks)
	ClassCatalog.apply_auto_to(active_unit, talent_spend)
	var next_hp := 500.0 * (1.0 + hooks.max_health_pct)
	var was_full := active_unit.health >= active_unit.max_health - 0.5
	active_unit.max_health = next_hp
	active_unit.health = next_hp if was_full else minf(active_unit.health, next_hp)


func _on_talents_changed() -> void:
	talent_spend.sanitize_binds()
	_ensure_skill_loadout()
	_apply_loadout_to_unit()
	persist_loadout()
	talents_changed.emit()
	loadout_changed.emit()


func _ensure_input_map() -> void:
	_add_key("ability_q", KEY_Q)
	_add_key("ability_w", KEY_W)
	_add_key("ability_e", KEY_E)
	_add_key("ability_r", KEY_R)
	_add_key("ability_d", KEY_D)
	_add_key("ability_f", KEY_F)
	_add_key("attack_move", KEY_A)
	_add_key("stop_command", KEY_S)
	_set_key("camera_lock", KEY_Y)
	_add_key("dodge", KEY_SPACE)
	_add_key("camera_left", KEY_LEFT)
	_add_key("camera_right", KEY_RIGHT)
	_add_key("camera_up", KEY_UP)
	_add_key("camera_down", KEY_DOWN)
	_add_key("restart", KEY_ENTER)
	_add_key("clear_target", KEY_ESCAPE)


func _add_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _set_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey:
			InputMap.action_erase_event(action, existing)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = true
	InputMap.action_add_event(action, ev)


func _add_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Godot matches mouse actions against pressed=true. A default (unpressed)
	# binding only fires on release, so RMB move / LMB confirm never ran.
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton:
			InputMap.action_erase_event(action, existing)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	InputMap.action_add_event(action, ev)


func _action_has_event(action: String, ev: InputEvent) -> bool:
	for existing in InputMap.action_get_events(action):
		if existing.as_text() == ev.as_text():
			return true
	return false


func select_target(u: Unit) -> void:
	if u == null or not is_instance_valid(u) or u.is_dead:
		selected_target = null
		return
	selected_target = u


func clear_selected_target() -> void:
	selected_target = null


func set_player_role(role: String) -> void:
	var next := RaidComp.normalize_role(role)
	if player_role == next:
		return
	player_role = next
	persist_loadout()


func player_is_tank() -> bool:
	return RaidComp.normalize_role(player_role) == RaidComp.ROLE_TANK


func player_is_healer() -> bool:
	return RaidComp.normalize_role(player_role) == RaidComp.ROLE_HEALER


func request_match(training: bool = true) -> void:
	training_mode = training
	if fight_started:
		session_started.emit()
		return
	match_requested.emit()


func begin_fight() -> void:
	var champ := ArenaState.champion
	if champ == null:
		return
	fight_started = true
	active_unit = champ
	selected_target = null
	champ.set_ai_enabled(false)
	champ.refresh_hover_outline()
	session_started.emit()
	unit_assigned.emit(champ)


func restart() -> void:
	fight_started = false
	active_unit = null
	selected_target = null
	_DamageNumber.clear_all()
	get_tree().reload_current_scene()
