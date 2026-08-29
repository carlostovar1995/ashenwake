extends Node

signal session_started
signal unit_assigned(unit)

var fight_started: bool = false
var active_unit: Unit = null
var selected_class_id: String = "elemental"
var selected_boss_id: String = "colossus"
var selected_destination_id: String = "training"
var training_mode: bool = true
var ignore_cooldowns: bool = true
var infinite_mana: bool = true
var selected_target: Unit = null
var smart_cast: bool = false
var unit_hover_width: float = 0.050
var spell_hover_width: float = 0.10

signal match_requested
signal highlight_settings_changed


func ignores_cooldowns() -> bool:
	return training_mode and ignore_cooldowns


func has_infinite_mana() -> bool:
	return training_mode and infinite_mana


func _ready() -> void:
	_ensure_input_map()


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
	get_tree().reload_current_scene()
