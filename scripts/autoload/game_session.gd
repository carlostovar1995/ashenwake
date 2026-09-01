extends Node

signal session_started
signal unit_assigned(unit)
signal loadout_changed

const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const LOADOUT_PATH := "user://spell_loadout.json"

var fight_started: bool = false
var active_unit: Unit = null
var spell_loadout: Array = []
var spell_profiles: Dictionary = {}
var active_profile: String = ""
var selected_boss_id: String = "colossus"
var selected_destination_id: String = "training"
var training_mode: bool = true
var ignore_cooldowns: bool = true
var infinite_mana: bool = true
var selected_target: Unit = null
var smart_cast: bool = false
var show_damage_numbers: bool = true
var unit_hover_width: float = 0.050
var spell_hover_width: float = 0.10

signal match_requested
signal highlight_settings_changed
signal balance_changed


func notify_balance_changed() -> void:
	SpellCatalog.invalidate()
	_apply_loadout_to_unit()
	balance_changed.emit()


func ignores_cooldowns() -> bool:
	return training_mode and ignore_cooldowns


func has_infinite_mana() -> bool:
	return training_mode and infinite_mana


func _ready() -> void:
	_ensure_input_map()
	var had_save := FileAccess.file_exists(LOADOUT_PATH)
	_load_persisted_loadout()
	ensure_loadout()
	if had_save:
		persist_loadout()


func ensure_loadout() -> void:
	if spell_loadout.size() != 6:
		spell_loadout = SpellCatalog.default_loadout()
		return
	for i in 6:
		var item = spell_loadout[i]
		if not (item is SpellRecipe):
			spell_loadout = SpellCatalog.default_loadout()
			return
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


func set_slot_recipe(index: int, recipe: SpellRecipe) -> void:
	ensure_loadout()
	if index < 0 or index >= 6 or recipe == null:
		return
	spell_loadout[index] = recipe
	_apply_loadout_to_unit()
	persist_loadout()
	loadout_changed.emit()


func apply_loadout(next: Array, profile_name: String = "") -> void:
	if next.size() != 6:
		return
	var copy: Array = []
	for item in next:
		if not (item is SpellRecipe):
			return
		copy.append((item as SpellRecipe).duplicate_recipe())
	spell_loadout = copy
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
	return not _loadout_matches_data(spell_profiles[active_profile])


func save_profile(profile_name: String) -> bool:
	var name := _sanitize_profile_name(profile_name)
	if name.is_empty():
		return false
	ensure_loadout()
	spell_profiles[name] = _loadout_to_data()
	active_profile = name
	persist_loadout()
	loadout_changed.emit()
	return true


func apply_profile(profile_name: String) -> bool:
	var name := String(profile_name)
	if name.is_empty() or not spell_profiles.has(name):
		return false
	var recipes := _recipes_from_data(spell_profiles[name])
	apply_loadout(recipes, name)
	return true


func delete_profile(profile_name: String) -> void:
	var name := String(profile_name)
	if name.is_empty() or not spell_profiles.has(name):
		return
	spell_profiles.erase(name)
	if active_profile == name:
		active_profile = ""
	persist_loadout()
	loadout_changed.emit()


func persist_loadout() -> void:
	ensure_loadout()
	var payload := {
		"current": _loadout_to_data(),
		"active_profile": active_profile,
		"profiles": spell_profiles.duplicate(true),
	}
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload, "\t"))


func _load_persisted_loadout() -> void:
	if not FileAccess.file_exists(LOADOUT_PATH):
		return
	var file := FileAccess.open(LOADOUT_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	var current := _recipes_from_data(data.get("current", []))
	if current.size() == 6:
		spell_loadout = current
	active_profile = String(data.get("active_profile", ""))
	spell_profiles.clear()
	var raw_profiles = data.get("profiles", {})
	if raw_profiles is Dictionary:
		for key in raw_profiles.keys():
			var name := _sanitize_profile_name(String(key))
			if name.is_empty():
				continue
			var recipes := _recipes_from_data(raw_profiles[key])
			if recipes.size() == 6:
				spell_profiles[name] = _recipes_to_data(recipes)
	if not active_profile.is_empty() and not spell_profiles.has(active_profile):
		active_profile = ""


func _loadout_to_data() -> Array:
	return _recipes_to_data(spell_loadout)


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
	for i in 6:
		var item = rows[i] if i < rows.size() else null
		if item is Dictionary:
			out.append(SpellRecipe.from_dict(item))
		else:
			out.append((fallback[i] as SpellRecipe).duplicate_recipe())
	return out


func _loadout_matches_data(raw) -> bool:
	var saved := _recipes_from_data(raw)
	if saved.size() != spell_loadout.size():
		return false
	for i in spell_loadout.size():
		var live: SpellRecipe = spell_loadout[i] if spell_loadout[i] is SpellRecipe else null
		var other: SpellRecipe = saved[i] if saved[i] is SpellRecipe else null
		if live == null or not live.same_as(other):
			return false
	return true


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
	active_unit.apply_compiled_abilities(SpellCompiler.compile_loadout(spell_loadout))


func _ensure_input_map() -> void:
	_add_mouse("move_command", MOUSE_BUTTON_RIGHT)
	_add_mouse("confirm_cast", MOUSE_BUTTON_LEFT)
	_add_mouse("camera_drag", MOUSE_BUTTON_MIDDLE)
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
