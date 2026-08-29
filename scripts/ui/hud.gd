extends CanvasLayer

const _StatusIcons := preload("res://scripts/ui/status_icons.gd")
const _CircleClip := preload("res://scripts/ui/circle_clip.gdshader")
const _HUD_DIR := "res://assets/ui/hud/"
const _GOLD := Color(1.0, 0.84, 0.38)
const _HP_GREEN := Color(0.20, 0.56, 0.22)
const _MP_BLUE := Color(0.22, 0.40, 0.78)
const _BOSS_RED := Color(0.52, 0.16, 0.15)
const _SHIELD_GRAY := Color(0.86, 0.90, 0.96, 0.95)
const _SLOT_HOVER := Color(1.42, 1.26, 0.72)
const _SPARK_PX := 32.0

var _lobby: Control
var _ip: LineEdit
var _port: LineEdit
var _status: Label
var _boss_bar: ProgressBar
var _boss_shield: ColorRect
var _boss_label: Label
var _boss_cast_wrap: Control
var _boss_cast_bar: ProgressBar
var _boss_cast_name: Label
var _boss_cast_fill: StyleBox
var _boss_frame: VBoxContainer
var _raid_frame: VBoxContainer
var _action_tray: Control
var _hp: ProgressBar
var _hp_shield: ColorRect
var _mp: ProgressBar
var _hp_label: Label
var _mp_label: Label
var _player_frame: Panel
var _player_portrait: TextureRect
var _player_name: Label
var _free_cast_row: HBoxContainer
var _free_cast_hud: Array[Panel] = []
var _hp_pulse_t: float = 0.0
var _tray_top: float = -116.0
var _bar_fill_cache: Dictionary = {}
var _target_portrait: TextureRect
var _cast_spark: TextureRect
var _boss_cast_spark: TextureRect
var _ability_panels: Array[Panel] = []
var _ability_cds: Array[Label] = []
var _ability_names: Array[Label] = []
var _ability_clocks: Array[TextureProgressBar] = []
var _passive_panel: Panel
var _passive_name: Label
var _hover_passive: bool = false
var _cd_clock_tex: Texture2D
var _class_buttons: Dictionary = {}
var _boss_buttons: Dictionary = {}
var _ally_rows: Array[Control] = []
var _ally_bars: Array[ProgressBar] = []
var _ally_shields: Array[ColorRect] = []
var _ally_names: Array[Label] = []
var _outcome: Label
var _combat: Control
var _cast_wrap: Control
var _cast_bar: ProgressBar
var _cast_name: Label
var _cast_fill_style: StyleBox
var _tip: PanelContainer
var _tip_label: Label
var _hover_ability: int = -1
var _hover_boss_status: int = -1
var _hover_player_buff: int = -1
var _tip_follow_mouse: bool = false
var _boss_status_row: HBoxContainer
var _boss_status_icons: Array[Panel] = []
var _boss_debuffs: Array[Dictionary] = []
var _player_buff_row: HBoxContainer
var _player_buff_icons: Array[Panel] = []
var _player_buffs: Array[Dictionary] = []
var _hover_target_status: int = -1
var _target_frame: Panel
var _target_name: Label
var _target_hp: ProgressBar
var _target_shield: ColorRect
var _target_hp_label: Label
var _target_status_row: HBoxContainer
var _target_status_icons: Array[Panel] = []
var _target_debuffs: Array[Dictionary] = []
var _training_tools: Control
var _no_cd_toggle: CheckBox
var _inf_mana_toggle: CheckBox
var _meter: Panel
var _meter_title: Label
var _meter_time: Label
var _meter_total: Label
var _meter_col_total: Label
var _meter_col_rate: Label
var _meter_rows: Array[Dictionary] = []
var _meter_handle: Control
var _meter_locked: bool = false
var _player_handle: Control
var _player_locked: bool = false
var _target_handle: Control
var _target_locked: bool = false
var _drag_panel: Control
var _drag_from: Vector2 = Vector2.ZERO
var _drag_moved: bool = false
var _drag_click: Callable
var _frame_menu: PopupMenu
var _frame_menu_which: String = ""
var _edit_mode: bool = false
var _edit_toolbar: Control
var _edit_handles: Array[Control] = []
var _edit_frames: Array[Dictionary] = []
var _default_layout: Dictionary = {}
var _pause_menu: Control
var _settings_menu: Control
var _settings_from_pause: bool = false
var _settings_edit_button: Button
var _settings_menu_button: Button
var _master_volume: float = 0.80
var _fullscreen: bool = false
var _hero_audio_menu: Control
var _hero_audio_card: Panel
var _hero_audio_dim: ColorRect
var _hero_audio_drag: Control
var _hero_audio_title: Label
var _hero_audio_subtitle: Label
var _hero_list_page: Control
var _hero_detail_page: Control
var _hero_clip_list: VBoxContainer
var _hero_open_group: Dictionary = {}
var _hero_audio_live: bool = false
var _hover_meter_unit: Unit
var _meter_break: Panel
var _meter_break_title: Label
var _meter_break_rows: Array[Dictionary] = []
var _hud_tex_cache: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("combat_hud")
	_load_settings()
	_build()
	GameSession.session_started.connect(_on_session_started)
	GameSession.unit_assigned.connect(_on_unit_assigned)
	ArenaState.fight_won.connect(_on_fight_won)
	ArenaState.fight_lost.connect(_on_fight_lost)
	if GameSession.fight_started:
		_on_session_started()
	else:
		_show_lobby(true)


func _on_fight_won() -> void:
	_show_outcome("VICTORY", Color(0.95, 0.82, 0.25))


func _on_fight_lost() -> void:
	_show_outcome("DEFEAT", Color(0.9, 0.2, 0.22))


func _exit_tree() -> void:
	if GameSession.session_started.is_connected(_on_session_started):
		GameSession.session_started.disconnect(_on_session_started)
	if GameSession.unit_assigned.is_connected(_on_unit_assigned):
		GameSession.unit_assigned.disconnect(_on_unit_assigned)
	if ArenaState.fight_won.is_connected(_on_fight_won):
		ArenaState.fight_won.disconnect(_on_fight_won)
	if ArenaState.fight_lost.is_connected(_on_fight_lost):
		ArenaState.fight_lost.disconnect(_on_fight_lost)


func _process(delta: float) -> void:
	if _combat.visible:
		_refresh_combat()
		_tick_hud_life(delta)
		if _tip and _tip.visible:
			if _hover_ability >= 0:
				_place_ability_tip()
			elif _hover_passive:
				_place_passive_tip()
			elif _hover_player_buff >= 0:
				_place_player_buff_tip()
			elif _hover_boss_status >= 0:
				_place_boss_status_tip()
			elif _hover_target_status >= 0:
				_place_target_status_tip()
			elif _tip_follow_mouse:
				_place_status_tip()
		_refresh_meter_breakdown()
		if _edit_mode:
			_sync_edit_handles()
	if Input.is_action_just_pressed("restart") and ArenaState.outcome != "":
		GameSession.restart()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("clear_target", false):
		if handle_escape():
			get_viewport().set_input_as_handled()
			return
	if _drag_panel == null:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var d: Vector2 = motion.global_position - _drag_from
		if not _drag_moved and d.length() < 4.0:
			return
		_drag_moved = true
		_drag_from = motion.global_position
		_nudge_frame(_drag_panel, d)
		_clamp_frame(_drag_panel)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var btn := event as InputEventMouseButton
		if btn.button_index == MOUSE_BUTTON_LEFT and not btn.pressed:
			_finish_frame_drag()
			get_viewport().set_input_as_handled()


func handle_escape() -> bool:
	if _hero_audio_menu and _hero_audio_menu.visible:
		if _hero_audio_live and GameSession.fight_started:
			_dismiss_hero_audio_live()
		elif _hero_detail_page and _hero_detail_page.visible:
			_show_hero_audio_list()
		else:
			_close_hero_audio()
		return true
	if _settings_menu and _settings_menu.visible:
		_close_settings()
		return true
	if _edit_mode:
		_leave_edit_mode(true)
		return true
	if _pause_menu and _pause_menu.visible:
		_resume_game()
		return true
	if GameSession.fight_started and ArenaState.outcome == "":
		_open_pause_menu()
		return true
	return false


func _on_session_started() -> void:
	get_tree().paused = false
	if _pause_menu:
		_pause_menu.visible = false
	if _settings_menu:
		_settings_menu.visible = false
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	if _edit_mode:
		_leave_edit_mode(false)
	_sync_hero_audio_window()
	_show_lobby(false)
	_combat.visible = true
	_refresh_training_tools()


func _on_unit_assigned(_u: Node) -> void:
	_refresh_combat()


func _show_lobby(show: bool) -> void:
	_lobby.visible = show
	# A hidden full-screen Control with STOP still eats world clicks in Godot 4.
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP if show else Control.MOUSE_FILTER_IGNORE
	_lobby.process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED
	if _lobby.get_child_count() > 0:
		var dim := _lobby.get_child(0)
		if dim is Control:
			(dim as Control).mouse_filter = _lobby.mouse_filter
	_combat.visible = not show and GameSession.fight_started
	_hover_ability = -1
	_hover_passive = false
	_hover_boss_status = -1
	_hover_player_buff = -1
	_hover_target_status = -1
	_tip_follow_mouse = false
	if _tip:
		_tip.visible = false
	if _frame_menu:
		_frame_menu.hide()
	if _meter_break:
		_meter_break.visible = false
		_hover_meter_unit = null
	_refresh_training_tools()


func _show_outcome(text: String, color: Color) -> void:
	GameSession.clear_selected_target()
	_outcome.visible = true
	_outcome.text = "%s\nEnter to return to menu" % text
	_outcome.modulate = color


func _refresh_combat() -> void:
	var boss := ArenaState.boss
	if boss:
		_apply_hp_with_shield(_boss_bar, _boss_shield, boss)
		if GameSession.training_mode:
			_boss_label.text = "%s   %d / %d   (training)" % [boss.unit_name, int(boss.health), int(boss.max_health)]
		else:
			var phase := "Phase 2" if boss.health <= boss.max_health * 0.5 else "Phase 1"
			_boss_label.text = "%s  —  %s   %d / %d" % [boss.unit_name, phase, int(boss.health), int(boss.max_health)]
	_refresh_boss_cast_bar()
	var u := GameSession.active_unit as Unit
	if u:
		_apply_hp_with_shield(_hp, _hp_shield, u)
		_mp.max_value = maxf(u.max_mana, 1.0)
		_mp.value = u.mana
		_hp_label.text = "%d/%d" % [int(u.health), int(u.max_health)]
		_mp_label.text = "%d/%d" % [int(u.mana), int(u.max_mana)]
		if _player_name:
			_player_name.text = u.unit_name
		_pulse_player_frame(u)
		_refresh_free_cast_hud(u)
		for i in _ability_panels.size():
			if i >= u.abilities.size():
				_ability_panels[i].visible = false
				if i < _ability_clocks.size():
					_ability_clocks[i].visible = false
				continue
			_ability_panels[i].visible = true
			var ab: AbilityDef = u.abilities[i]
			var ability_cd: float = u.cooldown_left[i] if i < u.cooldown_left.size() else 0.0
			var gcd: float = u.gcd_display_left(i)
			var display_cd := maxf(ability_cd, gcd)
			var display_duration := u.cooldown_duration(i) if ability_cd >= gcd else u.gcd_clock_duration()
			_ability_cds[i].text = ab.hotkey if ability_cd <= 0.0 else "%0.1f" % ability_cd
			if i < _ability_names.size():
				_ability_names[i].text = ab.display_name
				_ability_names[i].modulate = ab.color.lightened(0.25)
			var icon_id := ab.icon_id if not ab.icon_id.is_empty() else ab.id
			var infusion_tag := "" if ab.grant_all_infusions else u.infusion_icon_tag()
			_paint_ability_art(_ability_panels[i], icon_id, infusion_tag)
			if ability_cd > 0.0:
				_ability_panels[i].modulate = Color(1, 1, 1, 1)
			else:
				_ability_panels[i].modulate = Color(1, 1, 1, 1) if u.can_prepare_cast(i) else Color(0.5, 0.5, 0.55)
			_glow_slot(_ability_panels[i], _hover_ability == i)
			_refresh_ability_clock(i, display_cd, display_duration)
		_refresh_passive_slot()
	for i in _ally_bars.size():
		if i >= ArenaState.allies.size():
			_ally_bars[i].get_parent().visible = false
			continue
		var ally: Unit = ArenaState.allies[i]
		_ally_bars[i].get_parent().visible = true
		_ally_names[i].text = ally.unit_name + ("  [YOU]" if ally == GameSession.active_unit else "") + ("  [TANK]" if ally.immortal else "")
		_apply_hp_with_shield(_ally_bars[i], _ally_shields[i] if i < _ally_shields.size() else null, ally)
		_ally_names[i].modulate = Color(1, 0.85, 0.4) if ally == GameSession.active_unit else Color.WHITE
		var row := _ally_rows[i] if i < _ally_rows.size() else _ally_bars[i].get_parent() as Control
		if row:
			var hovered := _party_row_hovered(row)
			row.modulate = Color(1.18, 1.14, 0.92) if hovered else Color.WHITE
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered else Control.CURSOR_ARROW
	_refresh_cast_bar()
	_refresh_boss_debuffs()
	_refresh_player_buffs()
	_refresh_target_frame()
	_refresh_combat_meter()


func _build() -> void:
	_build_lobby()
	_build_combat()
	_outcome = Label.new()
	_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outcome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_outcome.anchor_right = 1.0
	_outcome.anchor_bottom = 1.0
	_outcome.offset_top = -40
	_outcome.add_theme_font_size_override("font_size", 52)
	_outcome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outcome.visible = false
	add_child(_outcome)
	_build_pause_menu()
	_build_settings_menu()
	_build_hero_audio_menu()
	_build_edit_toolbar()
	_build_reload_button()
	_build_training_tools()


func _panel(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 2
	s.corner_radius_top_right = 2
	s.corner_radius_bottom_left = 2
	s.corner_radius_bottom_right = 2
	s.content_margin_left = 0
	s.content_margin_top = 0
	s.content_margin_right = 0
	s.content_margin_bottom = 0
	return s


func _hud_tex(file: String) -> Texture2D:
	if _hud_tex_cache.has(file):
		return _hud_tex_cache[file]
	var path := _HUD_DIR + file
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img := Image.load_from_file(abs_path)
			if img and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	_hud_tex_cache[file] = tex
	return tex


func _hud_size(file: String, width: float, fallback_h: float) -> Vector2:
	var tex := _hud_tex(file)
	if tex == null or tex.get_width() < 1:
		return Vector2(width, fallback_h)
	return Vector2(width, width * float(tex.get_height()) / float(tex.get_width()))


func _bar_fill(color: Color) -> StyleBox:
	var key := color.to_html(false)
	if _bar_fill_cache.has(key):
		return _bar_fill_cache[key]
	var h := 32
	var img := Image.create(8, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t := float(y) / float(h - 1)
		var c: Color
		if y == 0:
			c = color.lightened(0.55)
		elif y <= 3:
			c = color.lightened(0.28 - float(y) * 0.04)
		elif y >= h - 2:
			c = color.darkened(0.48)
		else:
			c = color.lerp(color.darkened(0.38), clampf((t - 0.12) / 0.78, 0.0, 1.0))
		c.a = 0.98
		for x in 8:
			var px := c
			if x == 0:
				px = c.darkened(0.18)
			elif x == 1:
				px = c.darkened(0.06)
			elif x >= 6:
				px = c.lightened(0.05)
			img.set_pixel(x, y, px)
	var tex := ImageTexture.create_from_image(img)
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_bar_fill_cache[key] = s
	return s


func _paint_bar(bar: ProgressBar, color: Color) -> void:
	if bar:
		bar.add_theme_stylebox_override("fill", _bar_fill(color))


func _tooltip_style() -> StyleBox:
	# Rim ~7px, corners ~14px after scale. Content sits just inside the well.
	return _tex_style("wow_tooltip_frame.png", 14.0, 16.0)


func _tex_style(file: String, texture_margin: float, content_margin: float) -> StyleBox:
	var tex := _hud_tex(file)
	if tex == null:
		var fallback := _panel(Color(0.05, 0.04, 0.03, 0.94))
		fallback.border_width_left = 2
		fallback.border_width_top = 2
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
		fallback.border_color = Color(0.78, 0.62, 0.28, 0.9)
		fallback.content_margin_left = content_margin
		fallback.content_margin_top = content_margin
		fallback.content_margin_right = content_margin
		fallback.content_margin_bottom = content_margin
		return fallback
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = texture_margin
	s.texture_margin_top = texture_margin
	s.texture_margin_right = texture_margin
	s.texture_margin_bottom = texture_margin
	s.content_margin_left = content_margin
	s.content_margin_top = content_margin
	s.content_margin_right = content_margin
	s.content_margin_bottom = content_margin
	return s


func _chrome(file: String, stretch: TextureRect.StretchMode = TextureRect.STRETCH_SCALE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _hud_tex(file)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = stretch
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _atlas_rect(tex: Texture2D) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _sliced_chrome(file: String, left_px: int, right_px: int, height: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := _hud_tex(file)
	if tex == null:
		return root
	var tw := tex.get_width()
	var th := maxi(tex.get_height(), 1)
	left_px = clampi(left_px, 1, tw - 2)
	right_px = clampi(right_px, 1, tw - left_px - 1)
	var left_w := height * float(left_px) / float(th)
	var right_w := height * float(right_px) / float(th)
	var left_at := AtlasTexture.new()
	left_at.atlas = tex
	left_at.region = Rect2(0, 0, left_px, th)
	var mid_at := AtlasTexture.new()
	mid_at.atlas = tex
	mid_at.region = Rect2(left_px, 0, tw - left_px - right_px, th)
	var right_at := AtlasTexture.new()
	right_at.atlas = tex
	right_at.region = Rect2(tw - right_px, 0, right_px, th)
	var mid := _atlas_rect(mid_at)
	mid.anchor_left = 0.0
	mid.anchor_right = 1.0
	mid.anchor_top = 0.0
	mid.anchor_bottom = 1.0
	mid.offset_left = left_w
	mid.offset_right = -right_w
	var left := _atlas_rect(left_at)
	left.anchor_left = 0.0
	left.anchor_right = 0.0
	left.anchor_top = 0.0
	left.anchor_bottom = 1.0
	left.offset_right = left_w
	var right := _atlas_rect(right_at)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.offset_left = -right_w
	root.add_child(mid)
	root.add_child(left)
	root.add_child(right)
	return root


func _gold_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 5)


func _white_label(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", 5)


func _style_menu_button(b: Button) -> void:
	var normal := _panel(Color(0.16, 0.11, 0.05, 0.94))
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.78, 0.62, 0.28, 0.95)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.2, 0.08, 0.96)
	hover.border_color = Color(1.0, 0.86, 0.42)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.08, 0.04, 0.96)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", _GOLD)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)


func _bar_bg() -> StyleBoxFlat:
	return _panel(Color(0.07, 0.06, 0.05, 0.92))


func _unit_frame_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.06, 0.94)
	s.set_border_width_all(1)
	s.border_color = Color(0.84, 0.70, 0.34, 0.95)
	s.set_corner_radius_all(2)
	return s


func _menu_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.07, 0.96)
	s.set_border_width_all(1)
	s.border_color = Color(0.84, 0.70, 0.34, 0.95)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _dialog_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.045, 0.042, 0.05, 0.96)
	s.set_border_width_all(2)
	s.border_color = Color(0.84, 0.70, 0.34, 0.95)
	s.set_corner_radius_all(3)
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 2)
	return s


func _meter_style() -> StyleBoxFlat:
	var s := _unit_frame_style()
	s.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	return s


func _meter_row_label(align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _meter_col_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.72, 0.72, 0.74, 0.92))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _anchor_meter_rate_col(l: Control) -> void:
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_top = 0.0
	l.anchor_bottom = 1.0
	l.offset_top = 0
	l.offset_bottom = 0
	l.offset_left = -42
	l.offset_right = -4


func _anchor_meter_total_col(l: Control) -> void:
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_top = 0.0
	l.anchor_bottom = 1.0
	l.offset_top = 0
	l.offset_bottom = 0
	l.offset_left = -90
	l.offset_right = -44


func _flat_fill(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(1)
	return s


func _flat_trough() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.04, 0.05, 0.96)
	s.set_corner_radius_all(1)
	return s


func _make_flat_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", _flat_fill(fill))
	bar.add_theme_stylebox_override("background", _flat_trough())
	return bar


func _make_shield_overlay(bar: ProgressBar) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "ShieldFill"
	overlay.color = _SHIELD_GRAY
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.anchor_left = 0.0
	overlay.anchor_top = 0.0
	overlay.anchor_right = 0.0
	overlay.anchor_bottom = 1.0
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.z_index = 1
	overlay.visible = false
	bar.add_child(overlay)
	return overlay


func _apply_hp_with_shield(bar: ProgressBar, overlay: ColorRect, u: Unit) -> void:
	if bar == null or u == null:
		return
	var hp := 0.0 if u.is_dead else u.health
	var sh := 0.0 if u.is_dead else u.shield_amount()
	var span := maxf(u.max_health, hp + sh)
	bar.max_value = span
	bar.value = hp
	if overlay == null:
		return
	if sh <= 0.05 or u.is_dead:
		overlay.visible = false
		return
	overlay.visible = true
	overlay.anchor_left = clampf(hp / span, 0.0, 1.0)
	overlay.anchor_right = clampf((hp + sh) / span, 0.0, 1.0)


func _paint_flat_bar(bar: ProgressBar, color: Color) -> void:
	if bar:
		bar.add_theme_stylebox_override("fill", _flat_fill(color))


func _window_style() -> StyleBox:
	return _dialog_style()


func _make_fill_bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("fill", _bar_fill(fill))
	bar.add_theme_stylebox_override("background", _bar_bg())
	return bar


func _make_bar_label(align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 8
	label.offset_right = -8
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_constant_override("line_spacing", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_resource_bar(height: float, fill: Color) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size.y = height
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trough := _hud_tex("wow_bar_trough.png")
	if trough:
		wrap.add_child(_chrome("wow_bar_trough.png"))
	var bar := _make_fill_bar(fill)
	bar.name = "Bar"
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	if trough:
		bar.offset_left = 18
		bar.offset_right = -18
		bar.offset_top = 5
		bar.offset_bottom = -5
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	wrap.add_child(bar)
	var label := _make_bar_label()
	label.name = "Value"
	wrap.add_child(label)
	return wrap


func _cd_clock_texture() -> Texture2D:
	if _cd_clock_tex:
		return _cd_clock_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_cd_clock_tex = ImageTexture.create_from_image(img)
	return _cd_clock_tex


func _make_ability_clock() -> TextureProgressBar:
	var clock := TextureProgressBar.new()
	clock.set_anchors_preset(Control.PRESET_FULL_RECT)
	clock.offset_left = 7
	clock.offset_top = 7
	clock.offset_right = -7
	clock.offset_bottom = -7
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.z_index = 6
	clock.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	clock.min_value = 0.0
	clock.max_value = 1.0
	clock.step = 0.001
	clock.value = 0.0
	clock.radial_initial_angle = 0.0
	clock.texture_progress = _cd_clock_texture()
	clock.tint_progress = Color(0.015, 0.02, 0.035, 0.82)
	clock.visible = false
	return clock


func _make_bar_slot(key: String, name: String, color: Color, with_clock: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(72, 72)
	p.clip_contents = false
	var slot_tex := _hud_tex("wow_slot_frame.png")
	var inset := 7 if slot_tex else 5
	if slot_tex:
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		var slot_style := _panel(Color(0.09, 0.08, 0.06, 0.95))
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.78, 0.62, 0.28, 0.95)
		p.add_theme_stylebox_override("panel", slot_style)
	var art := TextureRect.new()
	art.name = "Art"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = inset
	art.offset_top = inset
	art.offset_right = -inset
	art.offset_bottom = -inset
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(art)
	if slot_tex:
		var frame := _chrome("wow_slot_frame.png")
		frame.name = "Frame"
		p.add_child(frame)
	if with_clock:
		var clock := _make_ability_clock()
		clock.name = "Clock"
		p.add_child(clock)
	if not key.is_empty():
		var l := Label.new()
		l.name = "Key"
		l.text = key
		l.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		l.offset_top = -22
		l.offset_bottom = -3
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", _GOLD)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		l.add_theme_constant_override("outline_size", 7)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
	var n := Label.new()
	n.name = "Name"
	n.text = name
	n.visible = false
	n.modulate = color.lightened(0.25)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(n)
	return p


func _refresh_ability_clock(index: int, remaining: float, duration: float) -> void:
	if index < 0 or index >= _ability_clocks.size():
		return
	var clock := _ability_clocks[index]
	if remaining <= 0.04 or duration <= 0.04:
		clock.visible = false
		return
	var ratio := clampf(remaining / duration, 0.0, 1.0)
	clock.visible = true
	clock.value = ratio
	clock.radial_initial_angle = fmod((1.0 - ratio) * 360.0, 360.0)


func _build_lobby() -> void:
	_lobby = Control.new()
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_lobby)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.025, 0.02, 0.92)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_lobby.add_child(dim)

	var card := Panel.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -560
	card.offset_right = 560
	card.offset_top = -400
	card.offset_bottom = 400
	card.add_theme_stylebox_override("panel", _dialog_style())
	_lobby.add_child(card)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = 20
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	var title := Label.new()
	title.text = "BOSS FIGHTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(title, 42)
	box.add_child(title)

	var pick := Label.new()
	pick.text = "CHARACTER"
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(pick, 15)
	box.add_child(pick)
	box.add_child(_build_class_row())

	var boss_pick := Label.new()
	boss_pick.text = "DESTINATION"
	boss_pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(boss_pick, 15)
	box.add_child(boss_pick)
	box.add_child(_build_boss_row())

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var play := _btn("PLAY", _play_selected_destination)
	play.custom_minimum_size = Vector2(300, 46)
	actions.add_child(play)
	var settings := _btn("Settings", func() -> void:
		_open_settings(false)
	)
	settings.custom_minimum_size = Vector2(150, 46)
	actions.add_child(settings)


func _build_class_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for kit in ClassCatalog.all():
		var art_file: String = String({
			"elemental": "boss_game_ember.png",
			"healer": "boss_game_ember.png",
			"arcane": "boss_game_spark.png",
			"dark": "boss_game_hex.png",
		}.get(kit.id, "boss_game_ember.png"))
		var b := _selection_card(
			art_file,
			kit.champion_name.to_upper(),
			kit.display_name.to_upper() if kit.available else "COMING SOON",
			Vector2(205, 250)
		)
		b.disabled = not kit.available
		if b.disabled:
			b.modulate = Color(0.52, 0.54, 0.60, 0.82)
		var class_id: String = kit.id
		b.pressed.connect(func() -> void:
			_select_class(class_id)
		)
		row.add_child(b)
		_class_buttons[kit.id] = b
	_select_class(GameSession.selected_class_id)
	return row


func _build_boss_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var destinations := [
		{"id": "training", "name": "TRAINING ARENA", "image": "boss_game_training_arena.png"},
		{"id": "colossus", "name": "COLOSSUS", "image": "boss_game_colossus.png"},
		{"id": "dawnwarden", "name": "DAWNWARDEN", "image": "boss_game_dawnwarden.png"},
	]
	for info in destinations:
		var b := _selection_card(String(info["image"]), String(info["name"]), "", Vector2(300, 172))
		var destination_id: String = info["id"]
		b.pressed.connect(func() -> void:
			_select_destination(destination_id)
		)
		row.add_child(b)
		_boss_buttons[destination_id] = b
	_select_destination(GameSession.selected_destination_id)
	return row


func _selection_card(image_file: String, title_text: String, subtitle_text: String, card_size: Vector2) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = card_size
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _selection_card_style(false))
	b.add_theme_stylebox_override("hover", _selection_card_style(true))
	b.add_theme_stylebox_override("pressed", _selection_card_style(true))
	b.add_theme_stylebox_override("focus", _selection_card_style(true))
	b.add_theme_stylebox_override("disabled", _selection_card_style(false))
	var art := TextureRect.new()
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = 4
	art.offset_right = -4
	art.offset_top = 4
	art.offset_bottom = -4
	art.texture = _hud_tex(image_file)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -58 if not subtitle_text.is_empty() else -44
	shade.color = Color(0.015, 0.02, 0.035, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade)
	var title := Label.new()
	title.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title.offset_top = -56 if not subtitle_text.is_empty() else -42
	title.offset_bottom = -26 if not subtitle_text.is_empty() else -4
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.91, 0.62))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
	title.add_theme_constant_override("outline_size", 5)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(title)
	if not subtitle_text.is_empty():
		var subtitle := Label.new()
		subtitle.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		subtitle.offset_top = -29
		subtitle.offset_bottom = -5
		subtitle.text = subtitle_text
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.add_theme_font_size_override("font_size", 11)
		subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
		subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.98))
		subtitle.add_theme_constant_override("outline_size", 4)
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(subtitle)
	return b


func _selection_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.98)
	style.border_color = Color(1.0, 0.80, 0.30, 1.0) if selected else Color(0.36, 0.40, 0.48, 0.92)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(4)
	return style


func _set_selection_card_selected(b: Button, selected: bool) -> void:
	if b == null:
		return
	var normal := _selection_card_style(selected)
	var hover := _selection_card_style(true)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)


func _select_destination(destination_id: String) -> void:
	GameSession.selected_destination_id = destination_id
	if destination_id != "training":
		GameSession.selected_boss_id = destination_id
	for id in _boss_buttons.keys():
		var b: Button = _boss_buttons[id]
		_set_selection_card_selected(b, id == destination_id)


func _select_class(class_id: String) -> void:
	var kit: ChampionClass = ClassCatalog.get_by_id(class_id)
	if not kit.available:
		return
	GameSession.selected_class_id = class_id
	for id in _class_buttons.keys():
		var b: Button = _class_buttons[id]
		_set_selection_card_selected(b, id == class_id)


func _play_selected_destination() -> void:
	if GameSession.fight_started:
		_on_session_started()
		return
	GameSession.request_match(GameSession.selected_destination_id == "training")


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 42
	_style_menu_button(b)
	b.pressed.connect(cb)
	return b


func _build_combat() -> void:
	_combat = Control.new()
	_combat.set_anchors_preset(Control.PRESET_FULL_RECT)
	_combat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat.visible = false
	add_child(_combat)

	_boss_frame = VBoxContainer.new()
	_boss_frame.anchor_left = 0.16
	_boss_frame.anchor_right = 0.84
	_boss_frame.offset_top = 8
	_boss_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_frame.add_theme_constant_override("separation", 3)
	_combat.add_child(_boss_frame)

	var boss_wrap := Control.new()
	const BOSS_H := 54.0
	boss_wrap.custom_minimum_size.y = BOSS_H
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_frame.add_child(boss_wrap)
	_boss_bar = _make_fill_bar(_BOSS_RED)
	_boss_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	var boss_tex := _hud_tex("wow_boss_frame.png")
	if boss_tex:
		var th := float(maxi(boss_tex.get_height(), 1))
		var scale := BOSS_H / th
		_boss_bar.offset_left = 115.0 * scale
		_boss_bar.offset_right = -116.0 * scale
		_boss_bar.offset_top = 61.0 * scale
		_boss_bar.offset_bottom = -62.0 * scale
	else:
		_boss_bar.offset_left = 8
		_boss_bar.offset_right = -8
		_boss_bar.offset_top = 10
		_boss_bar.offset_bottom = -10
	_boss_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	boss_wrap.add_child(_boss_bar)
	_boss_shield = _make_shield_overlay(_boss_bar)
	if boss_tex:
		boss_wrap.add_child(_sliced_chrome("wow_boss_frame.png", 160, 154, BOSS_H))
	_boss_label = Label.new()
	_boss_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_white_label(_boss_label, 16)
	_boss_label.z_index = 4
	_boss_label.z_as_relative = false
	_boss_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_wrap.add_child(_boss_label)
	_build_boss_cast_bar(_boss_frame)
	_boss_status_row = HBoxContainer.new()
	_boss_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_status_row.add_theme_constant_override("separation", 4)
	_boss_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_frame.add_child(_boss_status_row)

	_raid_frame = VBoxContainer.new()
	_raid_frame.offset_left = 16
	_raid_frame.offset_top = 100
	_raid_frame.custom_minimum_size.x = 220
	_raid_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raid_frame.add_theme_constant_override("separation", 5)
	_combat.add_child(_raid_frame)
	for i in 4:
		var row := Control.new()
		row.custom_minimum_size = _hud_size("wow_raid_frame.png", 216.0, 84.0)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var bar := _make_fill_bar(_HP_GREEN)
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.anchor_left = 0.06
		bar.anchor_right = 0.94
		bar.anchor_top = 0.145
		bar.anchor_bottom = 0.847
		bar.offset_left = 0
		bar.offset_right = 0
		bar.offset_top = 0
		bar.offset_bottom = 0
		bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		row.add_child(bar)
		if _hud_tex("wow_raid_frame.png"):
			row.add_child(_chrome("wow_raid_frame.png"))
		var name := Label.new()
		name.text = "Ally"
		name.set_anchors_preset(Control.PRESET_FULL_RECT)
		name.offset_left = 14
		name.offset_right = -10
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_white_label(name, 13)
		name.z_index = 4
		name.z_as_relative = false
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name)
		_raid_frame.add_child(row)
		_ally_rows.append(row)
		_ally_names.append(name)
		_ally_bars.append(bar)
		_ally_shields.append(_make_shield_overlay(bar))

	_build_player_frame()
	_player_buff_row = HBoxContainer.new()
	_player_buff_row.anchor_left = 0.0
	_player_buff_row.anchor_right = 0.0
	_player_buff_row.anchor_top = 1.0
	_player_buff_row.anchor_bottom = 1.0
	_player_buff_row.offset_left = _player_frame.offset_left + 8.0
	_player_buff_row.offset_right = _player_frame.offset_right
	_player_buff_row.offset_bottom = _player_frame.offset_top - 4.0
	_player_buff_row.offset_top = _player_buff_row.offset_bottom - 40.0
	_player_buff_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_player_buff_row.add_theme_constant_override("separation", 4)
	_player_buff_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat.add_child(_player_buff_row)

	_build_action_bar()
	_build_target_frame()
	_build_cast_bar()
	_ignore_mouse(_combat)
	_enable_party_frame_clicks()
	_enable_ability_hover()
	_enable_passive_hover()
	_enable_boss_status_hover()
	_build_ability_tip()
	_build_combat_meter()
	_setup_movable_frames()


func _build_player_frame() -> void:
	const W := 248.0
	const PAD := 4.0
	const BAR := 20.0
	const GAP := 2.0
	const H := PAD + BAR + GAP + BAR + PAD
	_player_frame = Panel.new()
	_player_frame.anchor_left = 0.0
	_player_frame.anchor_right = 0.0
	_player_frame.anchor_top = 1.0
	_player_frame.anchor_bottom = 1.0
	_player_frame.offset_left = 16
	_player_frame.offset_right = 16 + W
	_player_frame.offset_bottom = -118
	_player_frame.offset_top = -118 - H
	_player_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_frame.add_theme_stylebox_override("panel", _unit_frame_style())
	_combat.add_child(_player_frame)
	_player_portrait = null

	_hp = _make_flat_bar(_HP_GREEN)
	_hp.anchor_left = 0.0
	_hp.anchor_right = 1.0
	_hp.anchor_top = 0.0
	_hp.anchor_bottom = 0.0
	_hp.offset_left = PAD
	_hp.offset_right = -PAD
	_hp.offset_top = PAD
	_hp.offset_bottom = PAD + BAR
	_player_frame.add_child(_hp)
	_hp_shield = _make_shield_overlay(_hp)

	_mp = _make_flat_bar(_MP_BLUE)
	_mp.anchor_left = 0.0
	_mp.anchor_right = 1.0
	_mp.anchor_top = 0.0
	_mp.anchor_bottom = 0.0
	_mp.offset_left = PAD
	_mp.offset_right = -PAD
	_mp.offset_top = PAD + BAR + GAP
	_mp.offset_bottom = PAD + BAR + GAP + BAR
	_player_frame.add_child(_mp)

	_player_name = _make_bar_label(HORIZONTAL_ALIGNMENT_LEFT)
	_player_name.offset_left = 8
	_player_name.offset_right = -72
	_white_label(_player_name, 12)
	_player_name.add_theme_constant_override("outline_size", 3)
	_player_name.z_index = 2
	_hp.add_child(_player_name)
	_hp_label = _make_bar_label()
	_hp_label.add_theme_constant_override("outline_size", 3)
	_hp_label.z_index = 2
	_hp.add_child(_hp_label)
	_mp_label = _make_bar_label()
	_mp_label.add_theme_constant_override("outline_size", 3)
	_mp.add_child(_mp_label)

	_free_cast_row = HBoxContainer.new()
	_free_cast_row.name = "FreeCastPips"
	_free_cast_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_free_cast_row.add_theme_constant_override("separation", 4)
	_free_cast_row.anchor_left = 0.0
	_free_cast_row.anchor_right = 1.0
	_free_cast_row.anchor_top = 0.0
	_free_cast_row.anchor_bottom = 0.0
	_free_cast_row.offset_left = PAD + 2.0
	_free_cast_row.offset_right = -PAD - 2.0
	_free_cast_row.offset_top = PAD + BAR + 1.0
	_free_cast_row.offset_bottom = PAD + BAR + 9.0
	_free_cast_row.visible = false
	_player_frame.add_child(_free_cast_row)
	for i in 2:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(7, 7)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := _panel(Color(0.18, 0.14, 0.06))
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		pip.add_theme_stylebox_override("panel", s)
		_free_cast_row.add_child(pip)
		_free_cast_hud.append(pip)


func _refresh_free_cast_hud(u: Unit) -> void:
	if _free_cast_row == null:
		return
	var max_charges := u.free_cast_charge_max() if u.has_method("free_cast_charge_max") else 0
	var charges := u.free_cast_charges() if u.has_method("free_cast_charges") else 0
	_free_cast_row.visible = max_charges > 0
	for i in _free_cast_hud.size():
		var pip := _free_cast_hud[i]
		if i >= max_charges:
			pip.visible = false
			continue
		pip.visible = true
		var lit := i < charges
		var s := _panel(Color(1.0, 0.88, 0.35) if lit else Color(0.22, 0.18, 0.08))
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		pip.add_theme_stylebox_override("panel", s)
		pip.modulate = Color.WHITE if lit else Color(0.65, 0.6, 0.5, 0.7)


func _build_action_bar() -> void:
	_action_tray = Control.new()
	const SLOT := 72.0
	const GAP := 8.0
	const PAD_X := 40.0
	const PAD_Y := 12.0
	var tray_w := 7.0 * SLOT + 6.0 * GAP + PAD_X * 2.0
	var tray_h := SLOT + PAD_Y * 2.0
	_action_tray.anchor_left = 0.5
	_action_tray.anchor_right = 0.5
	_action_tray.anchor_top = 1.0
	_action_tray.anchor_bottom = 1.0
	_action_tray.offset_left = -tray_w * 0.5
	_action_tray.offset_right = tray_w * 0.5
	_action_tray.offset_bottom = -8
	_action_tray.offset_top = -8 - tray_h
	_tray_top = _action_tray.offset_top
	_action_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat.add_child(_action_tray)
	if _hud_tex("wow_actionbar_tray.png"):
		_action_tray.add_child(_chrome("wow_actionbar_tray.png"))
	var abilities := HBoxContainer.new()
	abilities.set_anchors_preset(Control.PRESET_FULL_RECT)
	abilities.offset_left = PAD_X
	abilities.offset_right = -PAD_X
	abilities.offset_top = PAD_Y
	abilities.offset_bottom = -PAD_Y
	abilities.alignment = BoxContainer.ALIGNMENT_CENTER
	abilities.add_theme_constant_override("separation", 8)
	abilities.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_tray.add_child(abilities)
	_passive_panel = _make_bar_slot("", "Attenuate", Color(0.95, 0.78, 0.32), false)
	abilities.add_child(_passive_panel)
	_passive_name = _passive_panel.get_node("Name") as Label
	var keys := ["Q", "W", "E", "R", "D", "F"]
	var names := ["Firebolt", "Freeze", "Thunder Wave", "Meteor", "Chilled Ground", "Overcharge"]
	var colors := [
		Color(1.0, 0.45, 0.12), Color(0.45, 0.8, 1.0), Color(0.75, 0.85, 1.0),
		Color(1.0, 0.35, 0.08), Color(0.4, 0.78, 1.0), Color(0.95, 0.85, 0.4),
	]
	for i in 6:
		var p := _make_bar_slot(keys[i], names[i], colors[i], true)
		abilities.add_child(p)
		_ability_panels.append(p)
		_ability_cds.append(p.get_node("Key") as Label)
		_ability_names.append(p.get_node("Name") as Label)
		_ability_clocks.append(p.get_node("Clock") as TextureProgressBar)


func _build_combat_meter() -> void:
	_meter = Panel.new()
	_meter.anchor_left = 1.0
	_meter.anchor_right = 1.0
	_meter.anchor_top = 0.0
	_meter.anchor_bottom = 0.0
	_meter.offset_left = -254
	_meter.offset_top = 58
	_meter.offset_right = -14
	_meter.offset_bottom = 140
	_meter.mouse_filter = Control.MOUSE_FILTER_STOP
	_meter.add_theme_stylebox_override("panel", _meter_style())
	_combat.add_child(_meter)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_right = -4
	box.offset_top = 4
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.add_child(box)

	var header := HBoxContainer.new()
	header.name = "Handle"
	header.custom_minimum_size.y = 18
	header.add_theme_constant_override("separation", 6)
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(header)
	_meter_handle = header

	_meter_title = Label.new()
	_meter_title.text = "Damage Done"
	_meter_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meter_title.add_theme_font_size_override("font_size", 12)
	_meter_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_meter_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_meter_title.add_theme_constant_override("outline_size", 3)
	_meter_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_meter_title)

	_meter_time = Label.new()
	_meter_time.text = "0:00"
	_meter_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meter_time.add_theme_font_size_override("font_size", 12)
	_meter_time.add_theme_color_override("font_color", Color(0.82, 0.82, 0.84))
	_meter_time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_meter_time)

	var reset_btn := Button.new()
	reset_btn.text = "↺"
	reset_btn.tooltip_text = "Reset meter"
	reset_btn.flat = true
	reset_btn.focus_mode = Control.FOCUS_NONE
	reset_btn.custom_minimum_size = Vector2(16, 16)
	reset_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	reset_btn.add_theme_font_size_override("font_size", 13)
	reset_btn.add_theme_color_override("font_color", Color(0.78, 0.78, 0.8))
	reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
	reset_btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32))
	reset_btn.pressed.connect(func() -> void:
		CombatMeter.reset_meter()
		_refresh_combat_meter()
	)
	header.add_child(reset_btn)

	var sub := Control.new()
	sub.custom_minimum_size.y = 14
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)

	_meter_total = Label.new()
	_meter_total.text = "0   0 DPS"
	_meter_total.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meter_total.offset_right = -94
	_meter_total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meter_total.add_theme_font_size_override("font_size", 11)
	_meter_total.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
	_meter_total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_child(_meter_total)

	_meter_col_total = _meter_col_header("Total")
	_anchor_meter_total_col(_meter_col_total)
	sub.add_child(_meter_col_total)
	_meter_col_rate = _meter_col_header("DPS")
	_anchor_meter_rate_col(_meter_col_rate)
	sub.add_child(_meter_col_rate)

	for i in 5:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 18)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.visible = false
		var bar := ProgressBar.new()
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.value = 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _flat_trough())
		row.add_child(bar)
		var name_lbl := _meter_row_label(HORIZONTAL_ALIGNMENT_LEFT)
		name_lbl.offset_left = 6
		name_lbl.offset_right = -94
		row.add_child(name_lbl)
		var amount := _meter_row_label(HORIZONTAL_ALIGNMENT_RIGHT)
		amount.add_theme_font_size_override("font_size", 11)
		_anchor_meter_total_col(amount)
		row.add_child(amount)
		var rate := _meter_row_label(HORIZONTAL_ALIGNMENT_RIGHT)
		rate.add_theme_font_size_override("font_size", 11)
		_anchor_meter_rate_col(rate)
		row.add_child(rate)
		box.add_child(row)
		var fill := _flat_fill(Color(0.92, 0.48, 0.14, 0.92))
		bar.add_theme_stylebox_override("fill", fill)
		var idx := i
		row.mouse_entered.connect(func() -> void:
			_hover_meter_unit = _meter_rows[idx].get("unit") as Unit
			_refresh_meter_breakdown()
		)
		row.mouse_exited.connect(func() -> void:
			var still := _meter_rows[idx].get("unit") as Unit
			if _hover_meter_unit == still:
				_hover_meter_unit = null
				_refresh_meter_breakdown()
		)
		_meter_rows.append({"row": row, "bar": bar, "name": name_lbl, "amount": amount, "rate": rate, "fill": fill, "unit": null})
	var foot := Control.new()
	foot.custom_minimum_size.y = 6
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	_build_meter_breakdown()


func _refresh_combat_meter() -> void:
	if _meter == null:
		return
	var healing := CombatMeter.mode == CombatMeter.Mode.HEALING
	_meter_title.text = CombatMeter.mode_title()
	_meter_time.text = CombatMeter.format_time(CombatMeter.elapsed())
	var rate_label := "HPS" if healing else "DPS"
	if _meter_col_rate:
		_meter_col_rate.text = rate_label
	_meter_total.text = "%s   %s %s" % [
		CombatMeter.format_amount(CombatMeter.total_amount()),
		rate_label,
		CombatMeter.format_amount(CombatMeter.overall_rate()),
	]
	var rows := CombatMeter.ranked_rows()
	for i in _meter_rows.size():
		var widgets: Dictionary = _meter_rows[i]
		var row: Control = widgets["row"]
		if i >= rows.size():
			row.visible = false
			continue
		var data: Dictionary = rows[i]
		row.visible = true
		var color: Color = data["color"]
		if data["is_you"]:
			color = color.lightened(0.12)
		var fill: StyleBoxFlat = widgets["fill"]
		fill.bg_color = Color(color.r, color.g, color.b, 0.92)
		(widgets["bar"] as ProgressBar).value = float(data["bar"])
		var nm := String(data["name"])
		if data["is_you"]:
			nm += " *"
		(widgets["name"] as Label).text = nm
		(widgets["name"] as Label).modulate = Color(1.0, 0.92, 0.55) if data["is_you"] else Color.WHITE
		(widgets["amount"] as Label).text = CombatMeter.format_amount(float(data["amount"]))
		(widgets["rate"] as Label).text = CombatMeter.format_amount(float(data["rate"]))
		widgets["unit"] = data.get("unit")
		if _hover_meter_unit != null and data.get("unit") == _hover_meter_unit:
			_hover_meter_unit = data.get("unit") as Unit
	var shown := mini(rows.size(), _meter_rows.size())
	var h := 58.0 + float(shown) * 19.0
	_meter.offset_bottom = _meter.offset_top + h


func _build_meter_breakdown() -> void:
	_meter_break = Panel.new()
	_meter_break.visible = false
	_meter_break.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_break.z_index = 20
	_meter_break.add_theme_stylebox_override("panel", _meter_style())
	_combat.add_child(_meter_break)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 4
	box.offset_right = -4
	box.offset_top = 4
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter_break.add_child(box)
	_meter_break_title = Label.new()
	_meter_break_title.add_theme_font_size_override("font_size", 12)
	_meter_break_title.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_meter_break_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_meter_break_title.add_theme_constant_override("outline_size", 3)
	_meter_break_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_meter_break_title)
	for i in 8:
		var row := Control.new()
		row.custom_minimum_size = Vector2(0, 18)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.visible = false
		var bar := ProgressBar.new()
		bar.set_anchors_preset(Control.PRESET_FULL_RECT)
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _flat_trough())
		var fill := _flat_fill(Color(0.92, 0.48, 0.14, 0.9))
		bar.add_theme_stylebox_override("fill", fill)
		row.add_child(bar)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		icon.offset_left = 2
		icon.offset_right = 18
		icon.offset_top = 1
		icon.offset_bottom = -1
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var name_lbl := _meter_row_label(HORIZONTAL_ALIGNMENT_LEFT)
		name_lbl.offset_left = 22
		name_lbl.offset_right = -72
		name_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(name_lbl)
		var stats := _meter_row_label(HORIZONTAL_ALIGNMENT_RIGHT)
		stats.offset_left = 80
		stats.offset_right = -4
		stats.add_theme_font_size_override("font_size", 11)
		row.add_child(stats)
		box.add_child(row)
		_meter_break_rows.append({"row": row, "bar": bar, "fill": fill, "icon": icon, "name": name_lbl, "stats": stats})


func _refresh_meter_breakdown() -> void:
	if _meter_break == null:
		return
	var u := _hover_meter_unit
	if u == null or not is_instance_valid(u) or _meter == null or not _meter.visible:
		_meter_break.visible = false
		return
	var spells := CombatMeter.spell_breakdown(u)
	if spells.is_empty():
		_meter_break.visible = false
		return
	var mode_name := "Healing" if CombatMeter.mode == CombatMeter.Mode.HEALING else "Damage"
	_meter_break_title.text = "%s  —  %s" % [u.unit_name, mode_name]
	for i in _meter_break_rows.size():
		var widgets: Dictionary = _meter_break_rows[i]
		var row: Control = widgets["row"]
		if i >= spells.size():
			row.visible = false
			continue
		var data: Dictionary = spells[i]
		row.visible = true
		var color: Color = data["color"]
		(widgets["fill"] as StyleBoxFlat).bg_color = Color(color.r, color.g, color.b, 0.9)
		(widgets["bar"] as ProgressBar).value = float(data["share"])
		(widgets["icon"] as TextureRect).texture = _StatusIcons.texture_for(String(data["icon"]))
		(widgets["name"] as Label).text = String(data["name"])
		(widgets["stats"] as Label).text = "%s  %d%%" % [
			CombatMeter.format_amount(float(data["amount"])),
			int(round(float(data["share"]) * 100.0)),
		]
	var shown := mini(spells.size(), _meter_break_rows.size())
	var w := 220.0
	var h := 28.0 + float(shown) * 19.0
	_meter_break.size = Vector2(w, h)
	var origin := _meter.global_position + Vector2(_meter.size.x + 10.0, 22.0)
	var vp := get_viewport().get_visible_rect().size
	if origin.x + w > vp.x - 8.0:
		origin.x = _meter.global_position.x - w - 10.0
	if origin.y + h > vp.y - 8.0:
		origin.y = maxf(8.0, vp.y - h - 8.0)
	_meter_break.global_position = origin
	_meter_break.visible = true


func _setup_movable_frames() -> void:
	_build_frame_menu()
	if _meter and _meter_handle:
		_wire_frame_drag(_meter, _meter_handle, func() -> bool: return _meter_locked, func() -> void:
			CombatMeter.toggle_mode()
			_refresh_combat_meter()
		)
		_apply_frame_lock(_meter_handle, _meter_locked)
	if _player_frame:
		_player_handle = _make_frame_handle(_player_frame)
		_player_frame.mouse_filter = Control.MOUSE_FILTER_STOP
		_wire_frame_drag(_player_frame, _player_handle, func() -> bool: return _player_locked, Callable())
		_apply_frame_lock(_player_handle, _player_locked)
	if _target_frame:
		_target_handle = _make_frame_handle(_target_frame)
		_target_frame.mouse_filter = Control.MOUSE_FILTER_STOP
		_wire_frame_drag(_target_frame, _target_handle, func() -> bool: return _target_locked, Callable())
		_apply_frame_lock(_target_handle, _target_locked)
	_register_edit_frame("Boss Frame", "boss", _boss_frame)
	_register_edit_frame("Raid Frames", "raid", _raid_frame)
	_register_edit_frame("Player Frame", "player", _player_frame)
	_register_edit_frame("Target Frame", "target5", _target_frame)
	_register_edit_frame("Action Bar", "action", _action_tray)
	_register_edit_frame("Cast Bar", "cast", _cast_wrap)
	_register_edit_frame("Damage Meter", "meter_r", _meter)
	_capture_default_layout()
	_load_hud_layout()


func _make_frame_handle(frame: Control) -> Panel:
	var handle := Panel.new()
	handle.name = "Handle"
	handle.set_anchors_preset(Control.PRESET_FULL_RECT)
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.add_child(handle)
	frame.move_child(handle, 0)
	return handle


func _register_edit_frame(title: String, section: String, frame: Control) -> void:
	if frame == null:
		return
	var handle := Panel.new()
	handle.name = "EditHandle_%s" % section
	handle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.z_index = 80
	handle.visible = false
	handle.add_theme_stylebox_override("panel", _edit_handle_style())
	var label := Label.new()
	label.text = title
	label.position = Vector2(8, 5)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.84, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	handle.add_child(label)
	_combat.add_child(handle)
	_edit_handles.append(handle)
	_edit_frames.append({"frame": frame, "handle": handle, "section": section})
	_wire_edit_drag(frame, handle)


func _edit_handle_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.34, 0.56, 0.18)
	style.border_color = Color(0.28, 0.78, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	return style


func _wire_edit_drag(frame: Control, handle: Control) -> void:
	handle.gui_input.connect(func(ev: InputEvent) -> void:
		if not _edit_mode or not ev is InputEventMouseButton:
			return
		var btn := ev as InputEventMouseButton
		if btn.button_index != MOUSE_BUTTON_LEFT:
			return
		if btn.pressed:
			_drag_panel = frame
			_drag_from = btn.global_position
			_drag_moved = false
			_drag_click = Callable()
			handle.accept_event()
		elif _drag_panel == frame:
			_finish_frame_drag()
			handle.accept_event()
	)


func _sync_edit_handles() -> void:
	for info in _edit_frames:
		var frame := info.get("frame") as Control
		var handle := info.get("handle") as Control
		if frame == null or handle == null:
			continue
		handle.global_position = frame.global_position
		handle.size = frame.size


func _capture_default_layout() -> void:
	_default_layout.clear()
	for info in _edit_frames:
		var frame := info.get("frame") as Control
		var section := String(info.get("section", ""))
		if frame:
			_default_layout[section] = Vector4(frame.offset_left, frame.offset_top, frame.offset_right, frame.offset_bottom)


func _build_frame_menu() -> void:
	if _frame_menu:
		return
	_frame_menu = PopupMenu.new()
	_frame_menu.popup_window = false
	_frame_menu.hide_on_item_selection = true
	_frame_menu.add_theme_stylebox_override("panel", _menu_style())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.18, 0.10, 0.96)
	hover.set_corner_radius_all(1)
	_frame_menu.add_theme_stylebox_override("hover", hover)
	_frame_menu.add_theme_color_override("font_color", Color(0.94, 0.94, 0.95))
	_frame_menu.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72))
	_frame_menu.add_theme_color_override("font_separator_color", Color(0.84, 0.70, 0.34, 0.55))
	_frame_menu.add_theme_font_size_override("font_size", 13)
	_frame_menu.add_theme_constant_override("v_separation", 2)
	_frame_menu.add_theme_constant_override("item_start_padding", 6)
	_frame_menu.add_theme_constant_override("item_end_padding", 6)
	_frame_menu.id_pressed.connect(_on_frame_menu_id)
	add_child(_frame_menu)


func try_frame_context_menu() -> bool:
	if _combat == null or not _combat.visible or _frame_menu == null:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null or hovered == _frame_menu:
		return false
	if _under_control(hovered, _meter):
		_popup_frame_menu("meter")
		return true
	if _player_frame and _under_control(hovered, _player_frame):
		_popup_frame_menu("player")
		return true
	if _target_frame and _target_frame.visible and _under_control(hovered, _target_frame):
		_popup_frame_menu("target")
		return true
	return false


func _enable_party_frame_clicks() -> void:
	for row in _ally_rows:
		if row == null:
			continue
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		if not row.is_in_group("hud_block_world"):
			row.add_to_group("hud_block_world")


func party_unit_under_mouse() -> Unit:
	if _edit_mode or _combat == null or not _combat.visible:
		return null
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return null
	for i in _ally_rows.size():
		if i >= ArenaState.allies.size():
			continue
		var row := _ally_rows[i]
		if row == null or not row.visible:
			continue
		if not _under_control(hovered, row):
			continue
		var ally: Unit = ArenaState.allies[i]
		if ally == null or not is_instance_valid(ally) or ally.is_dead:
			return null
		return ally
	return null


func is_mouse_over_ability_bar() -> bool:
	if _hover_ability >= 0:
		return true
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	for p in _ability_panels:
		if p and p.visible and _under_control(hovered, p):
			return true
	return false


func _party_row_hovered(row: Control) -> bool:
	if row == null or not row.visible:
		return false
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and _under_control(hovered, row)


func _under_control(n: Node, ancestor: Node) -> bool:
	if ancestor == null or n == null:
		return false
	var cur := n
	while cur:
		if cur == ancestor:
			return true
		cur = cur.get_parent()
	return false


func _popup_frame_menu(which: String) -> void:
	_frame_menu_which = which
	var locked := _frame_locked(which)
	_frame_menu.clear()
	_frame_menu.add_item("Lock" if not locked else "Unlock")
	var pos := Vector2i(get_viewport().get_mouse_position()) + Vector2i(4, 4)
	_frame_menu.reset_size()
	_frame_menu.position = pos
	_frame_menu.popup()


func _frame_locked(which: String) -> bool:
	match which:
		"meter":
			return _meter_locked
		"player":
			return _player_locked
		"target":
			return _target_locked
		_:
			return false


func _on_frame_menu_id(_id: int) -> void:
	match _frame_menu_which:
		"meter":
			_meter_locked = not _meter_locked
			_apply_frame_lock(_meter_handle, _meter_locked)
		"player":
			_player_locked = not _player_locked
			_apply_frame_lock(_player_handle, _player_locked)
		"target":
			_target_locked = not _target_locked
			_apply_frame_lock(_target_handle, _target_locked)
	_save_hud_layout()


func _apply_frame_lock(handle: Control, locked: bool) -> void:
	if handle:
		handle.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_MOVE


func _wire_frame_drag(panel: Control, handle: Control, is_locked: Callable, on_click: Callable) -> void:
	handle.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton:
			var btn := ev as InputEventMouseButton
			if btn.button_index != MOUSE_BUTTON_LEFT:
				return
			if btn.pressed:
				if is_locked.call():
					if on_click.is_valid():
						on_click.call()
					handle.accept_event()
					return
				_drag_panel = panel
				_drag_from = btn.global_position
				_drag_moved = false
				_drag_click = on_click
				handle.accept_event()
			elif _drag_panel == panel:
				_finish_frame_drag()
				handle.accept_event()
	)


func _finish_frame_drag() -> void:
	if _drag_panel == null:
		return
	if not _drag_moved and _drag_click.is_valid():
		_drag_click.call()
	var panel := _drag_panel
	_drag_panel = null
	_drag_moved = false
	_drag_click = Callable()
	if panel != _hero_audio_card:
		_save_hud_layout()


func _nudge_frame(panel: Control, delta: Vector2) -> void:
	panel.offset_left += delta.x
	panel.offset_right += delta.x
	panel.offset_top += delta.y
	panel.offset_bottom += delta.y
	if panel == _player_frame:
		_sync_player_buff_row()
	elif panel == _target_frame:
		_sync_target_status_row()


func _sync_player_buff_row() -> void:
	if _player_buff_row == null or _player_frame == null:
		return
	_player_buff_row.offset_left = _player_frame.offset_left + 8.0
	_player_buff_row.offset_right = _player_frame.offset_right
	_player_buff_row.offset_bottom = _player_frame.offset_top - 4.0
	_player_buff_row.offset_top = _player_buff_row.offset_bottom - 40.0


func _sync_target_status_row() -> void:
	if _target_status_row == null or _target_frame == null:
		return
	_target_status_row.offset_left = _target_frame.offset_left
	_target_status_row.offset_right = _target_frame.offset_right - 8.0
	_target_status_row.offset_bottom = _target_frame.offset_top - 4.0
	_target_status_row.offset_top = _target_status_row.offset_bottom - 40.0


func _clamp_frame(panel: Control) -> void:
	var r := panel.get_global_rect()
	var vp := get_viewport().get_visible_rect().size
	var pad_r := 24.0
	var pad_t := 24.0
	var dx := 0.0
	var dy := 0.0
	if r.position.x < 0.0:
		dx = -r.position.x
	if r.position.y < pad_t:
		dy = pad_t - r.position.y
	if r.end.x > vp.x - pad_r:
		dx = (vp.x - pad_r) - r.end.x
	if r.end.y > vp.y:
		dy = vp.y - r.end.y
	if dx != 0.0 or dy != 0.0:
		_nudge_frame(panel, Vector2(dx, dy))


func _save_hud_layout() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://hud_layout.cfg")
	for info in _edit_frames:
		_save_frame_layout(cfg, String(info.get("section", "")), info.get("frame") as Control)
	if _meter:
		cfg.set_value("meter_r", "locked", _meter_locked)
	if _player_frame:
		cfg.set_value("player", "locked", _player_locked)
	if _target_frame:
		cfg.set_value("target5", "locked", _target_locked)
	cfg.save("user://hud_layout.cfg")


func _save_frame_layout(cfg: ConfigFile, section: String, frame: Control) -> void:
	if frame == null or section.is_empty():
		return
	cfg.set_value(section, "left", frame.offset_left)
	cfg.set_value(section, "right", frame.offset_right)
	cfg.set_value(section, "top", frame.offset_top)
	cfg.set_value(section, "bottom", frame.offset_bottom)


func _load_hud_layout() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://hud_layout.cfg") != OK:
		return
	for info in _edit_frames:
		_load_frame_layout(cfg, String(info.get("section", "")), info.get("frame") as Control)
	if _meter and cfg.has_section("meter_r"):
		_meter_locked = bool(cfg.get_value("meter_r", "locked", false))
		_apply_frame_lock(_meter_handle, _meter_locked)
	if _player_frame and cfg.has_section("player"):
		_player_locked = bool(cfg.get_value("player", "locked", false))
		_apply_frame_lock(_player_handle, _player_locked)
		_sync_player_buff_row()
	if _target_frame:
		var section := "target5" if cfg.has_section("target5") else ("target4" if cfg.has_section("target4") else "")
		if section != "":
			if section == "target4":
				_load_frame_layout(cfg, section, _target_frame)
			_target_locked = bool(cfg.get_value(section, "locked", false))
			const TARGET_H := 4.0 + 20.0 + 4.0
			if absf((_target_frame.offset_bottom - _target_frame.offset_top) - TARGET_H) > 1.0:
				_target_frame.offset_bottom = _target_frame.offset_top + TARGET_H
			_apply_frame_lock(_target_handle, _target_locked)
			_sync_target_status_row()
	_sync_edit_handles()


func _load_frame_layout(cfg: ConfigFile, section: String, frame: Control) -> void:
	if frame == null or section.is_empty() or not cfg.has_section(section):
		return
	frame.offset_left = float(cfg.get_value(section, "left", frame.offset_left))
	frame.offset_right = float(cfg.get_value(section, "right", frame.offset_right))
	frame.offset_top = float(cfg.get_value(section, "top", frame.offset_top))
	frame.offset_bottom = float(cfg.get_value(section, "bottom", frame.offset_bottom))


func _reset_hud_layout() -> void:
	for info in _edit_frames:
		var frame := info.get("frame") as Control
		var section := String(info.get("section", ""))
		if frame == null or not _default_layout.has(section):
			continue
		var rect: Vector4 = _default_layout[section]
		frame.offset_left = rect.x
		frame.offset_top = rect.y
		frame.offset_right = rect.z
		frame.offset_bottom = rect.w
	_sync_player_buff_row()
	_sync_target_status_row()
	_sync_edit_handles()
	_save_hud_layout()


func _build_target_frame() -> void:
	const W := 248.0
	const PAD := 4.0
	const BAR := 20.0
	const H := PAD + BAR + PAD
	_target_frame = Panel.new()
	_target_frame.anchor_left = 0.0
	_target_frame.anchor_right = 0.0
	_target_frame.anchor_top = 1.0
	_target_frame.anchor_bottom = 1.0
	_target_frame.offset_left = 276
	_target_frame.offset_right = 276 + W
	_target_frame.offset_top = -168
	_target_frame.offset_bottom = -168 + H
	_target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_frame.visible = false
	_target_frame.add_theme_stylebox_override("panel", _unit_frame_style())
	_combat.add_child(_target_frame)
	_target_portrait = null

	_target_hp = _make_flat_bar(_BOSS_RED)
	_target_hp.anchor_left = 0.0
	_target_hp.anchor_right = 1.0
	_target_hp.anchor_top = 0.0
	_target_hp.anchor_bottom = 0.0
	_target_hp.offset_left = PAD
	_target_hp.offset_right = -PAD
	_target_hp.offset_top = PAD
	_target_hp.offset_bottom = PAD + BAR
	_target_frame.add_child(_target_hp)
	_target_shield = _make_shield_overlay(_target_hp)

	_target_name = _make_bar_label(HORIZONTAL_ALIGNMENT_LEFT)
	_target_name.offset_left = 8
	_target_name.offset_right = -80
	_white_label(_target_name, 12)
	_target_name.add_theme_constant_override("outline_size", 3)
	_target_name.z_index = 2
	_target_hp.add_child(_target_name)
	_target_hp_label = _make_bar_label()
	_target_hp_label.add_theme_constant_override("outline_size", 3)
	_target_hp_label.z_index = 2
	_target_hp.add_child(_target_hp_label)

	_target_status_row = HBoxContainer.new()
	_target_status_row.anchor_left = 0.0
	_target_status_row.anchor_right = 0.0
	_target_status_row.anchor_top = 1.0
	_target_status_row.anchor_bottom = 1.0
	_target_status_row.alignment = BoxContainer.ALIGNMENT_END
	_target_status_row.add_theme_constant_override("separation", 4)
	_target_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_status_row.visible = false
	_combat.add_child(_target_status_row)
	_sync_target_status_row()


func _refresh_target_frame() -> void:
	if _target_frame == null:
		return
	var t := GameSession.selected_target
	if t == null or not is_instance_valid(t) or t.is_dead:
		if t != null and (not is_instance_valid(t) or t.is_dead):
			GameSession.clear_selected_target()
		_target_frame.visible = _edit_mode
		if _edit_mode:
			_target_name.text = "Target Frame"
			_target_name.modulate = Color(1.0, 0.82, 0.62)
			_target_hp.value = 72.0
			_target_hp.max_value = 100.0
			_target_hp_label.text = "72/100"
		if _target_status_row:
			_target_status_row.visible = false
		_target_debuffs.clear()
		_hover_target_status = -1
		return
	_target_frame.visible = true
	_target_name.text = t.unit_name
	var you := GameSession.active_unit as Unit
	var enemy := you == null or t.team != you.team
	_target_name.modulate = Color(1.0, 0.72, 0.72) if enemy else Color(0.75, 1.0, 0.78)
	_paint_flat_bar(_target_hp, _BOSS_RED if enemy else _HP_GREEN)
	_apply_hp_with_shield(_target_hp, _target_shield, t)
	_target_hp_label.text = "%d/%d" % [int(t.health), int(t.max_health)]
	_refresh_target_debuffs(t)


func _refresh_target_debuffs(t: Unit) -> void:
	if _target_status_row == null:
		return
	_target_debuffs = t.collect_debuffs()
	_target_status_row.visible = _target_frame.visible and not _target_debuffs.is_empty()
	while _target_status_icons.size() < _target_debuffs.size():
		_make_target_status_icon()
	for i in _target_status_icons.size():
		var icon := _target_status_icons[i]
		if i >= _target_debuffs.size():
			icon.visible = false
			continue
		icon.visible = true
		_paint_status_icon(icon, _target_debuffs[i])
	if _hover_target_status >= _target_debuffs.size():
		_hover_target_status = -1
		_hide_tip_if_idle()
	elif _hover_target_status >= 0 and _hover_ability < 0 and not _hover_passive:
		_show_target_status_tip()


func _show_target_status_tip() -> void:
	if _tip == null or _hover_target_status < 0 or _hover_target_status >= _target_debuffs.size():
		return
	if _hover_ability >= 0 or _hover_passive:
		return
	var data := _target_debuffs[_hover_target_status]
	_show_status_data_tip(data, false)
	_place_target_status_tip()


func _place_target_status_tip() -> void:
	_place_status_icon_tip(_target_status_icons, _hover_target_status, false)


func _build_boss_cast_bar(parent: Control) -> void:
	_boss_cast_wrap = Control.new()
	_boss_cast_wrap.custom_minimum_size = Vector2(0, 22)
	_boss_cast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_cast_wrap.visible = false
	parent.add_child(_boss_cast_wrap)
	_boss_cast_fill = _bar_fill(Color(1.0, 0.78, 0.28))
	_boss_cast_bar = ProgressBar.new()
	_boss_cast_bar.anchor_left = 0.037
	_boss_cast_bar.anchor_right = 0.963
	_boss_cast_bar.anchor_top = 0.227
	_boss_cast_bar.anchor_bottom = 0.765
	_boss_cast_bar.max_value = 1.0
	_boss_cast_bar.show_percentage = false
	_boss_cast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_cast_bar.add_theme_stylebox_override("fill", _boss_cast_fill)
	_boss_cast_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_boss_cast_wrap.add_child(_boss_cast_bar)
	if _hud_tex("wow_bar_trough.png"):
		_boss_cast_wrap.add_child(_chrome("wow_bar_trough.png"))
	_boss_cast_name = Label.new()
	_boss_cast_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boss_cast_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_cast_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_white_label(_boss_cast_name, 13)
	_boss_cast_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_cast_wrap.add_child(_boss_cast_name)
	_boss_cast_spark = _make_spark()
	_combat.add_child(_boss_cast_spark)


func _boss_brain(boss: Unit) -> BossAI:
	if boss == null:
		return null
	for child in boss.get_children():
		if child is BossAI:
			return child
	return null


func _refresh_boss_cast_bar() -> void:
	if _boss_cast_wrap == null:
		return
	var brain := _boss_brain(ArenaState.boss)
	if brain == null or not brain.is_showing_ability():
		_boss_cast_wrap.visible = _edit_mode
		if _edit_mode:
			_boss_cast_bar.value = 0.62
			_boss_cast_name.text = "Boss Cast Bar"
		if _boss_cast_spark:
			_boss_cast_spark.visible = false
		return
	_boss_cast_wrap.visible = true
	_boss_cast_bar.value = brain.ability_progress()
	if brain.ability_interruptible:
		_boss_cast_name.text = "%s   ◆ Interrupt" % brain.ability_name
		_paint_bar(_boss_cast_bar, Color(0.38, 0.78, 1.0))
	else:
		_boss_cast_name.text = "%s   🔒" % brain.ability_name
		_paint_bar(_boss_cast_bar, Color(0.95, 0.62, 0.16))


func _build_cast_bar() -> void:
	_cast_wrap = Control.new()
	_cast_wrap.anchor_left = 0.5
	_cast_wrap.anchor_right = 0.5
	_cast_wrap.anchor_top = 1.0
	_cast_wrap.anchor_bottom = 1.0
	_cast_wrap.offset_left = -155
	_cast_wrap.offset_right = 155
	_cast_wrap.offset_bottom = _tray_top - 8.0
	_cast_wrap.offset_top = _cast_wrap.offset_bottom - 32.0
	_cast_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_wrap.visible = false
	_combat.add_child(_cast_wrap)
	_cast_fill_style = _bar_fill(Color(0.95, 0.82, 0.28))
	_cast_bar = ProgressBar.new()
	_cast_bar.anchor_left = 0.037
	_cast_bar.anchor_right = 0.963
	_cast_bar.anchor_top = 0.227
	_cast_bar.anchor_bottom = 0.765
	_cast_bar.max_value = 1.0
	_cast_bar.show_percentage = false
	_cast_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_bar.add_theme_stylebox_override("fill", _cast_fill_style)
	_cast_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_cast_wrap.add_child(_cast_bar)
	if _hud_tex("wow_bar_trough.png"):
		_cast_wrap.add_child(_chrome("wow_bar_trough.png"))

	_cast_name = Label.new()
	_cast_name.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cast_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cast_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_white_label(_cast_name, 13)
	_cast_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cast_wrap.add_child(_cast_name)
	_cast_spark = _make_spark()
	_combat.add_child(_cast_spark)


func _refresh_cast_bar() -> void:
	if _cast_wrap == null:
		return
	var u := GameSession.active_unit as Unit
	if u == null or u.controller == null or not u.controller.is_casting():
		_cast_wrap.visible = _edit_mode
		if _edit_mode:
			_cast_bar.value = 0.62
			_cast_name.text = "Player Cast Bar"
		if _cast_spark:
			_cast_spark.visible = false
		return
	var ab := u.controller.casting_ability()
	_cast_wrap.visible = true
	_cast_bar.value = u.controller.cast_progress()
	_cast_name.text = ab.display_name if ab else ""
	if ab:
		_paint_bar(_cast_bar, ab.color.lightened(0.12))


func _enable_ability_hover() -> void:
	for i in _ability_panels.size():
		var p: Panel = _ability_panels[i]
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		if not p.is_in_group("hud_block_world"):
			p.add_to_group("hud_block_world")
		var idx := i
		p.mouse_entered.connect(func() -> void:
			_hover_boss_status = -1
			_hover_player_buff = -1
			_hover_target_status = -1
			_hover_passive = false
			_hover_ability = idx
			_tip_follow_mouse = false
			_glow_slot(p, true)
			_show_ability_tip()
		)
		p.mouse_exited.connect(func() -> void:
			if _hover_ability == idx:
				_hover_ability = -1
				_glow_slot(p, false)
				_hide_tip_if_idle()
		)
		p.gui_input.connect(func(ev: InputEvent) -> void:
			if not ev is InputEventMouseButton:
				return
			var btn := ev as InputEventMouseButton
			if btn.button_index != MOUSE_BUTTON_LEFT or not btn.pressed:
				return
			var pin := get_tree().get_first_node_in_group("player_input")
			if pin and pin.has_method("try_activate_ability"):
				pin.call("try_activate_ability", idx, true)
			p.accept_event()
		)


func _enable_passive_hover() -> void:
	if _passive_panel == null:
		return
	_passive_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_passive_panel.mouse_entered.connect(func() -> void:
		_hover_boss_status = -1
		_hover_player_buff = -1
		_hover_target_status = -1
		_hover_ability = -1
		_hover_passive = true
		_tip_follow_mouse = false
		_glow_slot(_passive_panel, true)
		_show_passive_tip()
	)
	_passive_panel.mouse_exited.connect(func() -> void:
		if _hover_passive:
			_hover_passive = false
			_glow_slot(_passive_panel, false)
			_hide_tip_if_idle()
	)


func _refresh_passive_slot() -> void:
	if _passive_panel == null:
		return
	var kit: ChampionClass = ClassCatalog.get_by_id(GameSession.selected_class_id)
	var has_passive := kit != null and not kit.passive_name.is_empty()
	_passive_panel.visible = has_passive
	if not has_passive:
		_hover_passive = false
		return
	if _passive_name:
		_passive_name.text = kit.passive_name
	var icon_id := kit.passive_icon if kit and not kit.passive_icon.is_empty() else "attenuate"
	_paint_ability_art(_passive_panel, icon_id)


func _paint_ability_art(panel: Panel, icon_id: String, infusion_tag: String = "") -> void:
	if panel == null:
		return
	var art := panel.get_node_or_null("Art") as TextureRect
	if art == null:
		return
	art.texture = _StatusIcons.texture_for_ability(icon_id, infusion_tag)
	art.visible = true


func _show_passive_tip() -> void:
	if _tip == null or not _hover_passive:
		return
	var kit: ChampionClass = ClassCatalog.get_by_id(GameSession.selected_class_id)
	var text := kit.passive_tooltip() if kit else ""
	if text.is_empty():
		_tip.visible = false
		return
	_tip_label.text = text
	_tip.visible = true
	_tip_follow_mouse = false
	_place_passive_tip()


func _build_ability_tip() -> void:
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 30
	_tip.add_theme_stylebox_override("panel", _tooltip_style())
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size.x = 320
	_tip_label.add_theme_font_size_override("font_size", 13)
	_tip_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	add_child(_tip)


func _show_ability_tip() -> void:
	if _tip == null or _hover_ability < 0:
		return
	var u := GameSession.active_unit as Unit
	if u == null or _hover_ability >= u.abilities.size():
		_tip.visible = false
		return
	var ab: AbilityDef = u.abilities[_hover_ability]
	_tip_label.text = ab.tooltip()
	_tip.visible = true
	_tip_follow_mouse = false
	_place_ability_tip()


func show_status_tip(title: String, body: String, footer: String = "Right-click to remove.") -> void:
	if _tip == null or _hover_ability >= 0 or _hover_passive or _hover_boss_status >= 0 or _hover_player_buff >= 0 or _hover_target_status >= 0:
		return
	if footer.is_empty():
		_tip_label.text = "%s\n\n%s" % [title, body]
	else:
		_tip_label.text = "%s\n\n%s\n\n%s" % [title, body, footer]
	_tip.visible = true
	_tip_follow_mouse = true
	_place_status_tip()


func hide_status_tip() -> void:
	if not _tip_follow_mouse:
		return
	_tip_follow_mouse = false
	_hide_tip_if_idle()


func _hide_tip_if_idle() -> void:
	if _hover_ability < 0 and not _hover_passive and _hover_boss_status < 0 and _hover_player_buff < 0 and _hover_target_status < 0 and _tip and not _tip_follow_mouse:
		_tip.visible = false


func _status_icon_style(color: Color) -> StyleBoxFlat:
	var s := _panel(color.darkened(0.55))
	s.corner_radius_top_left = 18
	s.corner_radius_top_right = 18
	s.corner_radius_bottom_left = 18
	s.corner_radius_bottom_right = 18
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = color
	return s


func _make_status_icon(row: HBoxContainer, kind: String, idx: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(36, 36)
	p.clip_contents = false
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.visible = false
	var buff_tex := _hud_tex("wow_buff_frame.png")
	if buff_tex:
		p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		p.add_theme_stylebox_override("panel", _status_icon_style(Color(0.1, 0.11, 0.14)))
	var art := TextureRect.new()
	art.name = "Art"
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	if buff_tex:
		art.offset_left = 5
		art.offset_top = 5
		art.offset_right = -5
		art.offset_bottom = -5
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(art)
	if buff_tex:
		var frame := _chrome("wow_buff_frame.png")
		frame.name = "Frame"
		p.add_child(frame)
	var clock := TextureProgressBar.new()
	clock.name = "Clock"
	clock.set_anchors_preset(Control.PRESET_FULL_RECT)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	clock.min_value = 0.0
	clock.max_value = 1.0
	clock.step = 0.001
	clock.value = 0.0
	clock.radial_initial_angle = 0.0
	clock.radial_center_offset = Vector2.ZERO
	clock.radial_fill_degrees = 360.0
	clock.nine_patch_stretch = true
	clock.texture_under = null
	clock.texture_over = null
	clock.texture_progress = _cd_clock_texture()
	clock.tint_progress = Color(0.03, 0.04, 0.07, 0.58)
	clock.visible = false
	p.add_child(clock)
	var stacks := Label.new()
	stacks.name = "Stacks"
	stacks.anchor_left = 0.0
	stacks.anchor_top = 1.0
	stacks.anchor_right = 0.0
	stacks.anchor_bottom = 1.0
	stacks.offset_left = 1
	stacks.offset_top = -15
	stacks.offset_right = 34
	stacks.offset_bottom = 1
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stacks.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	stacks.add_theme_font_size_override("font_size", 11)
	stacks.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	stacks.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	stacks.add_theme_constant_override("outline_size", 4)
	stacks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stacks.visible = false
	p.add_child(stacks)
	row.add_child(p)
	p.mouse_entered.connect(func() -> void:
		if not p.visible:
			return
		_hover_ability = -1
		_hover_passive = false
		_tip_follow_mouse = false
		_hover_player_buff = -1
		_hover_boss_status = -1
		_hover_target_status = -1
		if kind == "player":
			_hover_player_buff = idx
			_show_player_buff_tip()
		elif kind == "target":
			_hover_target_status = idx
			_show_target_status_tip()
		else:
			_hover_boss_status = idx
			_show_boss_status_tip()
	)
	p.mouse_exited.connect(func() -> void:
		if kind == "player":
			if _hover_player_buff == idx:
				_hover_player_buff = -1
				_hide_tip_if_idle()
		elif kind == "target":
			if _hover_target_status == idx:
				_hover_target_status = -1
				_hide_tip_if_idle()
		elif _hover_boss_status == idx:
			_hover_boss_status = -1
			_hide_tip_if_idle()
	)
	return p


func _make_boss_status_icon() -> Panel:
	var p := _make_status_icon(_boss_status_row, "boss", _boss_status_icons.size())
	_boss_status_icons.append(p)
	return p


func _make_player_buff_icon() -> Panel:
	var p := _make_status_icon(_player_buff_row, "player", _player_buff_icons.size())
	_player_buff_icons.append(p)
	return p


func _make_target_status_icon() -> Panel:
	var p := _make_status_icon(_target_status_row, "target", _target_status_icons.size())
	_target_status_icons.append(p)
	return p


func _enable_boss_status_hover() -> void:
	for p in _boss_status_icons:
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	for p in _player_buff_icons:
		p.mouse_filter = Control.MOUSE_FILTER_STOP
	for p in _target_status_icons:
		p.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_status_clock(clock: TextureProgressBar, remaining: float, duration: float) -> void:
	if clock == null:
		return
	if remaining <= 0.04 or duration <= 0.04:
		clock.visible = false
		return
	var remain := clampf(remaining / duration, 0.0, 1.0)
	var elapsed := 1.0 - remain
	if elapsed <= 0.02:
		clock.visible = false
		return
	clock.visible = true
	clock.value = elapsed
	clock.radial_initial_angle = 0.0
	clock.radial_center_offset = Vector2.ZERO


func _paint_status_icon(icon: Panel, data: Dictionary) -> void:
	var color: Color = data.get("color", Color(0.5, 0.5, 0.55))
	var frame := icon.get_node_or_null("Frame") as CanvasItem
	if frame:
		frame.modulate = Color(minf(color.r + 0.35, 1.0), minf(color.g + 0.28, 1.0), minf(color.b + 0.12, 1.0))
	else:
		icon.add_theme_stylebox_override("panel", _status_icon_style(color))
	var art := icon.get_node("Art") as TextureRect
	if art:
		var icon_id := String(data.get("icon", data.get("id", "")))
		art.texture = _StatusIcons.texture_for(icon_id)
		art.visible = true
		art.modulate = Color.WHITE
	var remaining := float(data.get("time_left", 0.0))
	var duration := float(data.get("duration", 0.0))
	_refresh_status_clock(icon.get_node_or_null("Clock") as TextureProgressBar, remaining, duration)
	var stacks := icon.get_node_or_null("Stacks") as Label
	if stacks:
		var badge := String(data.get("badge", ""))
		if badge.is_empty():
			var count := int(data.get("stacks", 0))
			if count > 0:
				badge = "%d" % count
		if not badge.is_empty():
			stacks.visible = true
			stacks.text = badge
		else:
			stacks.visible = false
			stacks.text = ""


func _refresh_boss_debuffs() -> void:
	if _boss_status_row == null:
		return
	var boss := ArenaState.boss as Unit
	if boss == null or not is_instance_valid(boss) or boss.is_dead:
		_boss_debuffs.clear()
	else:
		_boss_debuffs = boss.collect_debuffs()
	while _boss_status_icons.size() < _boss_debuffs.size():
		_make_boss_status_icon()
	for i in _boss_status_icons.size():
		var icon := _boss_status_icons[i]
		if i >= _boss_debuffs.size():
			icon.visible = false
			continue
		icon.visible = true
		_paint_status_icon(icon, _boss_debuffs[i])
	if _hover_boss_status >= _boss_debuffs.size():
		_hover_boss_status = -1
		_hide_tip_if_idle()
	elif _hover_boss_status >= 0 and _hover_ability < 0 and not _hover_passive:
		_show_boss_status_tip()


func _refresh_player_buffs() -> void:
	if _player_buff_row == null:
		return
	var u := GameSession.active_unit as Unit
	if u == null or not is_instance_valid(u) or u.is_dead:
		_player_buffs.clear()
	else:
		_player_buffs = u.collect_buffs()
	_player_buff_row.visible = not _player_buffs.is_empty()
	while _player_buff_icons.size() < _player_buffs.size():
		_make_player_buff_icon()
	for i in _player_buff_icons.size():
		var icon := _player_buff_icons[i]
		if i >= _player_buffs.size():
			icon.visible = false
			continue
		icon.visible = true
		_paint_status_icon(icon, _player_buffs[i])
	if _hover_player_buff >= _player_buffs.size():
		_hover_player_buff = -1
		_hide_tip_if_idle()
	elif _hover_player_buff >= 0 and _hover_ability < 0 and not _hover_passive:
		_show_player_buff_tip()


func try_dismiss_hovered_player_buff(u: Unit) -> bool:
	if _hover_player_buff < 0 or _hover_player_buff >= _player_buffs.size():
		return false
	if u == null:
		return true
	var id := String(_player_buffs[_hover_player_buff].get("id", ""))
	u.dismiss_buff(id)
	return true


func _show_boss_status_tip() -> void:
	if _tip == null or _hover_boss_status < 0 or _hover_boss_status >= _boss_debuffs.size():
		return
	if _hover_ability >= 0 or _hover_passive:
		return
	var data := _boss_debuffs[_hover_boss_status]
	_show_status_data_tip(data, false)
	_place_boss_status_tip()


func _show_player_buff_tip() -> void:
	if _tip == null or _hover_player_buff < 0 or _hover_player_buff >= _player_buffs.size():
		return
	if _hover_ability >= 0 or _hover_passive:
		return
	var data := _player_buffs[_hover_player_buff]
	_show_status_data_tip(data, true)
	_place_player_buff_tip()


func _show_status_data_tip(data: Dictionary, dismissable: bool) -> void:
	var title := String(data.get("name", "Status"))
	var body := String(data.get("description", ""))
	var left := float(data.get("time_left", 0.0))
	var stacks := int(data.get("stacks", 0))
	if stacks > 1:
		title = "%s  x%d" % [title, stacks]
	if left > 0.05:
		title = "%s  ·  %0.1fs" % [title, left]
	if dismissable:
		_tip_label.text = "%s\n\n%s\n\nRight-click to remove." % [title, body]
	else:
		_tip_label.text = "%s\n\n%s" % [title, body]
	_tip.visible = true
	_tip_follow_mouse = false


func _place_status_icon_tip(icons: Array[Panel], index: int, below: bool) -> void:
	if _tip == null or not _tip.visible or index < 0 or index >= icons.size():
		return
	var p: Panel = icons[index]
	if not p.visible:
		return
	_tip.reset_size()
	var r := p.get_global_rect()
	var pos: Vector2
	if below:
		pos = Vector2(r.position.x + r.size.x * 0.5 - _tip.size.x * 0.5, r.position.y + r.size.y + 8.0)
	else:
		pos = Vector2(r.position.x + r.size.x * 0.5 - _tip.size.x * 0.5, r.position.y - _tip.size.y - 8.0)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - _tip.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - _tip.size.y - 8.0))
	_tip.global_position = pos


func _place_boss_status_tip() -> void:
	_place_status_icon_tip(_boss_status_icons, _hover_boss_status, true)


func _place_player_buff_tip() -> void:
	_place_status_icon_tip(_player_buff_icons, _hover_player_buff, false)


func _place_status_tip() -> void:
	if _tip == null or not _tip.visible:
		return
	_tip.reset_size()
	var mouse := get_viewport().get_mouse_position()
	var vp := get_viewport().get_visible_rect().size
	var pos := mouse + Vector2(18.0, 20.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - _tip.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - _tip.size.y - 8.0))
	_tip.global_position = pos


func _place_ability_tip() -> void:
	if _tip == null or not _tip.visible or _hover_ability < 0:
		return
	if _hover_ability >= _ability_panels.size():
		return
	_place_bar_tip(_ability_panels[_hover_ability])


func _place_passive_tip() -> void:
	if _tip == null or not _tip.visible or not _hover_passive or _passive_panel == null:
		return
	_place_bar_tip(_passive_panel)


func _place_bar_tip(p: Panel) -> void:
	_tip.reset_size()
	var r := p.get_global_rect()
	var pos := Vector2(r.position.x + r.size.x * 0.5 - _tip.size.x * 0.5, r.position.y - _tip.size.y - 12.0)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - _tip.size.x - 8.0))
	pos.y = maxf(8.0, pos.y)
	_tip.global_position = pos


func _build_training_tools() -> void:
	_training_tools = Control.new()
	_training_tools.set_anchors_preset(Control.PRESET_FULL_RECT)
	_training_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_training_tools.visible = false
	add_child(_training_tools)
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -280
	box.offset_right = -16
	box.offset_top = -88
	box.offset_bottom = -16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	_training_tools.add_child(box)
	_no_cd_toggle = _make_training_toggle("No cooldowns", "Training only. Removes ability cooldowns; the global cooldown remains.", GameSession.ignore_cooldowns, _on_no_cd_toggled)
	_inf_mana_toggle = _make_training_toggle("Infinite mana", "Training only. Spells cost no mana.", GameSession.infinite_mana, _on_inf_mana_toggled)
	box.add_child(_no_cd_toggle)
	box.add_child(_inf_mana_toggle)


func _make_training_toggle(label: String, tip: String, pressed: bool, on_toggle: Callable) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = label
	cb.tooltip_text = tip
	cb.button_pressed = pressed
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_filter = Control.MOUSE_FILTER_STOP
	cb.add_theme_font_size_override("font_size", 14)
	cb.add_theme_color_override("font_color", _GOLD)
	cb.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
	cb.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32))
	cb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	cb.add_theme_constant_override("outline_size", 4)
	cb.toggled.connect(on_toggle)
	return cb


func _refresh_training_tools() -> void:
	if _training_tools == null:
		return
	var show := GameSession.fight_started and _lobby != null and not _lobby.visible
	_training_tools.visible = show
	if not show:
		return
	var training := GameSession.training_mode
	if _no_cd_toggle:
		_no_cd_toggle.visible = training
		_no_cd_toggle.set_pressed_no_signal(GameSession.ignore_cooldowns)
	if _inf_mana_toggle:
		_inf_mana_toggle.visible = training
		_inf_mana_toggle.set_pressed_no_signal(GameSession.infinite_mana)


func _on_no_cd_toggled(pressed: bool) -> void:
	GameSession.ignore_cooldowns = pressed
	var u := GameSession.active_unit as Unit
	if u and pressed:
		for i in u.cooldown_left.size():
			u.cooldown_left[i] = 0.0


func _on_inf_mana_toggled(pressed: bool) -> void:
	GameSession.infinite_mana = pressed
	var u := GameSession.active_unit as Unit
	if u and pressed:
		u.mana = u.max_mana


func _make_modal(title_text: String, card_size: Vector2) -> Dictionary:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	root.z_index = 100
	add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.025, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var card := Panel.new()
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -card_size.x * 0.5
	card.offset_right = card_size.x * 0.5
	card.offset_top = -card_size.y * 0.5
	card.offset_bottom = card_size.y * 0.5
	card.add_theme_stylebox_override("panel", _dialog_style())
	root.add_child(card)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 22
	box.offset_right = -22
	box.offset_top = 18
	box.offset_bottom = -18
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(title, 30)
	box.add_child(title)
	return {"root": root, "box": box, "card": card, "dim": dim}


func _build_pause_menu() -> void:
	var ui := _make_modal("GAME MENU", Vector2(430, 490))
	_pause_menu = ui["root"] as Control
	var box := ui["box"] as VBoxContainer
	box.add_child(_btn("Resume", _resume_game))
	box.add_child(_btn("Edit Mode", _enter_edit_mode))
	box.add_child(_btn("Settings", func() -> void:
		_open_settings(true)
	))
	box.add_child(_btn("Return to Main Menu", _return_to_main_menu))
	box.add_child(_btn("Quit Game", func() -> void:
		get_tree().paused = false
		get_tree().quit()
	))
	var help := Label.new()
	help.text = "Esc closes this menu"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.modulate = Color(0.72, 0.75, 0.82)
	box.add_child(help)


func _build_settings_menu() -> void:
	var ui := _make_modal("SETTINGS", Vector2(540, 760))
	_settings_menu = ui["root"] as Control
	_settings_menu.z_index = 110
	var box := ui["box"] as VBoxContainer

	var audio_title := Label.new()
	audio_title.text = "Audio"
	_gold_label(audio_title, 17)
	box.add_child(audio_title)
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 10)
	box.add_child(volume_row)
	var volume_name := Label.new()
	volume_name.text = "Master Volume"
	volume_name.custom_minimum_size.x = 145
	_white_label(volume_name, 14)
	volume_row.add_child(volume_name)
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = _master_volume * 100.0
	volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume.focus_mode = Control.FOCUS_NONE
	volume_row.add_child(volume)
	var volume_value := Label.new()
	volume_value.text = "%d%%" % int(round(volume.value))
	volume_value.custom_minimum_size.x = 48
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_white_label(volume_value, 13)
	volume_row.add_child(volume_value)
	volume.value_changed.connect(func(v: float) -> void:
		_master_volume = v / 100.0
		volume_value.text = "%d%%" % int(round(v))
		_apply_settings()
		_save_settings()
	)

	box.add_child(_btn("Hero Audio Mix", _open_hero_audio))

	var display_title := Label.new()
	display_title.text = "Display"
	_gold_label(display_title, 17)
	box.add_child(display_title)
	var fullscreen := CheckBox.new()
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = _fullscreen
	fullscreen.focus_mode = Control.FOCUS_NONE
	fullscreen.add_theme_font_size_override("font_size", 14)
	fullscreen.add_theme_color_override("font_color", Color(0.94, 0.94, 0.96))
	fullscreen.add_theme_color_override("font_hover_color", _GOLD)
	fullscreen.toggled.connect(func(pressed: bool) -> void:
		_fullscreen = pressed
		_apply_settings()
		_save_settings()
	)
	box.add_child(fullscreen)

	var combat_title := Label.new()
	combat_title.text = "Combat"
	_gold_label(combat_title, 17)
	box.add_child(combat_title)
	var smart := CheckBox.new()
	smart.text = "Smart Cast"
	smart.button_pressed = GameSession.smart_cast
	smart.focus_mode = Control.FOCUS_NONE
	smart.tooltip_text = "Abilities fire immediately at your cursor or hovered ally, including party frames. Hold Shift for the targeting reticle."
	smart.add_theme_font_size_override("font_size", 14)
	smart.add_theme_color_override("font_color", Color(0.94, 0.94, 0.96))
	smart.add_theme_color_override("font_hover_color", _GOLD)
	smart.toggled.connect(func(pressed: bool) -> void:
		GameSession.smart_cast = pressed
		_save_settings()
	)
	box.add_child(smart)
	var smart_note := Label.new()
	smart_note.text = "Press or click a spell while hovering a target to fire it. Hold Shift to aim first."
	smart_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	smart_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	smart_note.modulate = Color(0.72, 0.75, 0.82)
	box.add_child(smart_note)

	var interface_title := Label.new()
	interface_title.text = "Interface"
	_gold_label(interface_title, 17)
	box.add_child(interface_title)
	_settings_edit_button = _btn("Enter Edit Mode", _enter_edit_mode)
	box.add_child(_settings_edit_button)
	box.add_child(_btn("Reset Interface Positions", _reset_hud_layout))
	var note := Label.new()
	note.text = "Frame positions save automatically."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(0.72, 0.75, 0.82)
	box.add_child(note)

	_settings_menu_button = _btn("Return to Main Menu", _return_to_main_menu)
	box.add_child(_settings_menu_button)
	box.add_child(_btn("Back", _close_settings))


func _build_hero_audio_menu() -> void:
	var ui := _make_modal("HERO AUDIO MIX", Vector2(760, 740))
	_hero_audio_menu = ui["root"] as Control
	_hero_audio_menu.z_index = 120
	_hero_audio_card = ui["card"] as Panel
	_hero_audio_dim = ui["dim"] as ColorRect
	if _hero_audio_card:
		_hero_audio_card.add_to_group("hud_block_world")
	_hero_audio_drag = Control.new()
	_hero_audio_drag.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hero_audio_drag.offset_bottom = 86
	_hero_audio_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_audio_drag.mouse_default_cursor_shape = Control.CURSOR_MOVE
	if _hero_audio_card:
		_hero_audio_card.add_child(_hero_audio_drag)
		_wire_frame_drag(_hero_audio_card, _hero_audio_drag, func() -> bool:
			return not _hero_audio_live
		, Callable())
	var box := ui["box"] as VBoxContainer
	_hero_audio_title = box.get_child(0) as Label
	_hero_audio_subtitle = Label.new()
	_hero_audio_subtitle.text = "Pick a hero, then mix volume and timing."
	_hero_audio_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_audio_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_audio_subtitle.modulate = Color(0.72, 0.75, 0.82)
	box.add_child(_hero_audio_subtitle)

	_hero_list_page = VBoxContainer.new()
	_hero_list_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_list_page.add_theme_constant_override("separation", 8)
	box.add_child(_hero_list_page)
	for group in SfxCatalog.mixer_groups():
		if not (group is Dictionary):
			continue
		var title := String(group.get("title", "Hero"))
		var subtitle := String(group.get("subtitle", ""))
		var label := title if subtitle.is_empty() else "%s  —  %s" % [title, subtitle]
		var captured: Dictionary = (group as Dictionary).duplicate(true)
		_hero_list_page.add_child(_btn(label, _open_hero_audio_group.bind(captured)))
	_hero_list_page.add_child(_btn("Back", _close_hero_audio))

	_hero_detail_page = VBoxContainer.new()
	_hero_detail_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hero_detail_page.add_theme_constant_override("separation", 8)
	_hero_detail_page.visible = false
	box.add_child(_hero_detail_page)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_hero_detail_page.add_child(scroll)
	_hero_clip_list = VBoxContainer.new()
	_hero_clip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_clip_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_hero_clip_list)
	var detail_actions := HBoxContainer.new()
	detail_actions.add_theme_constant_override("separation", 10)
	_hero_detail_page.add_child(detail_actions)
	var reset := _btn("Reset This Hero", _reset_open_hero_mix)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_actions.add_child(reset)
	var back := _btn("All Heroes", _show_hero_audio_list)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_actions.add_child(back)


func _open_hero_audio() -> void:
	if _hero_audio_menu == null:
		return
	if _settings_menu:
		_settings_menu.visible = false
	_show_hero_audio_list()
	_hero_audio_menu.visible = true
	_sync_hero_audio_window()


func _close_hero_audio() -> void:
	AudioManager.persist_mix()
	AudioManager.stop_preview()
	_finish_frame_drag()
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	_sync_hero_audio_window()
	if _settings_menu:
		_settings_menu.visible = true
	if _settings_from_pause and GameSession.fight_started:
		get_tree().paused = true


func _dismiss_hero_audio_live() -> void:
	AudioManager.persist_mix()
	AudioManager.stop_preview()
	_finish_frame_drag()
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	_sync_hero_audio_window()
	get_tree().paused = false


func _show_hero_audio_list() -> void:
	AudioManager.persist_mix()
	AudioManager.stop_preview()
	_hero_open_group = {}
	if _hero_audio_title:
		_hero_audio_title.text = "HERO AUDIO MIX"
	if _hero_audio_subtitle:
		_hero_audio_subtitle.text = "Pick a hero, then mix volume and timing."
	if _hero_list_page:
		_hero_list_page.visible = true
	if _hero_detail_page:
		_hero_detail_page.visible = false
	_sync_hero_audio_window()


func _open_hero_audio_group(group: Dictionary) -> void:
	_hero_open_group = group
	if _hero_audio_title:
		_hero_audio_title.text = String(group.get("title", "Hero")).to_upper()
	if _hero_audio_subtitle:
		var subtitle := String(group.get("subtitle", ""))
		var mix_text := "%s  ·  − ms advances, + ms delays" % (subtitle if not subtitle.is_empty() else "Clip mix")
		if GameSession.fight_started:
			mix_text += "  ·  Drag the title to move. Combat stays live."
		else:
			mix_text += "  ·  Drag the title to move."
		_hero_audio_subtitle.text = mix_text
	if _hero_list_page:
		_hero_list_page.visible = false
	if _hero_detail_page:
		_hero_detail_page.visible = true
	_rebuild_hero_clip_sliders()
	_sync_hero_audio_window()


func _sync_hero_audio_window() -> void:
	var detail := _hero_detail_page != null and _hero_detail_page.visible
	var open := _hero_audio_menu != null and _hero_audio_menu.visible
	_hero_audio_live = open and detail
	if _hero_audio_drag:
		_hero_audio_drag.mouse_filter = Control.MOUSE_FILTER_STOP if _hero_audio_live else Control.MOUSE_FILTER_IGNORE
		_hero_audio_drag.mouse_default_cursor_shape = Control.CURSOR_MOVE if _hero_audio_live else Control.CURSOR_ARROW
	if _hero_audio_menu == null:
		return
	if not open:
		_hero_audio_menu.mouse_filter = Control.MOUSE_FILTER_STOP
		if _hero_audio_dim:
			_hero_audio_dim.visible = true
			_hero_audio_dim.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	var play_through := _hero_audio_live and GameSession.fight_started
	_hero_audio_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE if play_through else Control.MOUSE_FILTER_STOP
	if _hero_audio_dim:
		_hero_audio_dim.visible = not play_through
		_hero_audio_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if play_through else Control.MOUSE_FILTER_STOP
	if play_through:
		if _pause_menu:
			_pause_menu.visible = false
		if _settings_menu:
			_settings_menu.visible = false
		_dock_hero_audio_aside()
		get_tree().paused = false
	elif GameSession.fight_started:
		get_tree().paused = true


func _dock_hero_audio_aside() -> void:
	if _hero_audio_card == null:
		return
	# Centered pose keeps left+right = 0. Leave it alone after the player has dragged it.
	if absf(_hero_audio_card.offset_left + _hero_audio_card.offset_right) > 8.0:
		return
	var vp := get_viewport().get_visible_rect().size
	var width := maxf(_hero_audio_card.size.x, 760.0)
	var center_x := vp.x * 0.5
	var right_edge := vp.x - 28.0
	var left_edge := right_edge - width
	_hero_audio_card.offset_left = left_edge - center_x
	_hero_audio_card.offset_right = right_edge - center_x
	_clamp_frame(_hero_audio_card)


func _rebuild_hero_clip_sliders() -> void:
	for child in _hero_clip_list.get_children():
		child.queue_free()
	var clips: Array = _hero_open_group.get("clips", [])
	if clips.is_empty():
		var empty := Label.new()
		empty.text = "No unique clips yet — they will show up here as you add them."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.modulate = Color(0.72, 0.75, 0.82)
		_hero_clip_list.add_child(empty)
		return
	var rows: Array = []
	for clip in clips:
		if clip is Dictionary:
			rows.append(clip)
	for i in rows.size():
		if i > 0:
			_hero_clip_list.add_child(_mix_clip_separator())
		_hero_clip_list.add_child(_make_mix_slider_row(rows[i]))


func _mix_clip_separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = Color(0.84, 0.70, 0.34, 0.32)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _make_mix_slider_row(clip: Dictionary) -> Control:
	var event_id := String(clip.get("id", ""))
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 8)
	block.add_child(vol_row)
	var name := Label.new()
	name.text = String(clip.get("label", event_id))
	name.custom_minimum_size.x = 210
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_white_label(name, 13)
	vol_row.add_child(name)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 200
	slider.step = 1
	slider.value = AudioManager.mix_gain(event_id) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	vol_row.add_child(slider)
	var value := Label.new()
	value.text = "%d%%" % int(round(slider.value))
	value.custom_minimum_size.x = 72
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_white_label(value, 13)
	vol_row.add_child(value)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % int(round(v))
		AudioManager.set_mix_gain(event_id, v / 100.0, false)
	)
	slider.drag_ended.connect(func(_changed: bool) -> void:
		AudioManager.set_mix_gain(event_id, slider.value / 100.0, true)
	)
	var play := Button.new()
	play.text = "Play"
	play.custom_minimum_size = Vector2(64, 32)
	play.focus_mode = Control.FOCUS_NONE
	_style_menu_button(play)
	play.pressed.connect(func() -> void:
		AudioManager.preview(event_id)
	)
	vol_row.add_child(play)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	block.add_child(time_row)
	var time_name := Label.new()
	time_name.text = "Timing"
	time_name.custom_minimum_size.x = 210
	time_name.modulate = Color(0.78, 0.8, 0.86)
	_white_label(time_name, 12)
	time_row.add_child(time_name)
	var time_slider := HSlider.new()
	time_slider.min_value = -AudioManager.TIMING_MAX * 1000.0
	time_slider.max_value = AudioManager.TIMING_MAX * 1000.0
	time_slider.step = 5
	time_slider.value = AudioManager.timing_offset(event_id) * 1000.0
	time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_slider.focus_mode = Control.FOCUS_NONE
	time_row.add_child(time_slider)
	var time_value := Label.new()
	time_value.text = _format_mix_timing(time_slider.value)
	time_value.custom_minimum_size.x = 72
	time_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_white_label(time_value, 12)
	time_value.modulate = Color(0.78, 0.8, 0.86)
	time_row.add_child(time_value)
	time_slider.value_changed.connect(func(v: float) -> void:
		time_value.text = _format_mix_timing(v)
		AudioManager.set_timing_offset(event_id, v / 1000.0, false)
	)
	time_slider.drag_ended.connect(func(_changed: bool) -> void:
		AudioManager.set_timing_offset(event_id, time_slider.value / 1000.0, true)
		AudioManager.preview(event_id)
	)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(64, 1)
	time_row.add_child(spacer)
	return block


func _format_mix_timing(ms: float) -> String:
	var rounded := int(round(ms))
	if rounded == 0:
		return "0 ms"
	return "%+d ms" % rounded


func _reset_open_hero_mix() -> void:
	var ids := PackedStringArray()
	var clips: Array = _hero_open_group.get("clips", [])
	for clip in clips:
		if clip is Dictionary:
			ids.append(String(clip.get("id", "")))
	AudioManager.reset_mix_group(ids)
	_rebuild_hero_clip_sliders()


func _build_edit_toolbar() -> void:
	_edit_toolbar = Panel.new()
	_edit_toolbar.anchor_left = 0.5
	_edit_toolbar.anchor_right = 0.5
	_edit_toolbar.offset_left = -300
	_edit_toolbar.offset_right = 300
	_edit_toolbar.offset_top = 16
	_edit_toolbar.offset_bottom = 70
	_edit_toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_edit_toolbar.z_index = 120
	_edit_toolbar.add_theme_stylebox_override("panel", _menu_style())
	_edit_toolbar.visible = false
	add_child(_edit_toolbar)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 6
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 10)
	_edit_toolbar.add_child(row)
	var title := Label.new()
	title.text = "EDIT MODE  ·  Drag any highlighted frame"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label(title, 16)
	row.add_child(title)
	var reset := _btn("Reset", _reset_hud_layout)
	reset.custom_minimum_size = Vector2(90, 38)
	row.add_child(reset)
	var done := _btn("Done", func() -> void:
		_leave_edit_mode(false)
	)
	done.custom_minimum_size = Vector2(90, 38)
	row.add_child(done)


func _open_pause_menu() -> void:
	if _pause_menu == null or not GameSession.fight_started:
		return
	GameSession.clear_selected_target()
	_pause_menu.visible = true
	if _tip:
		_tip.visible = false
	get_tree().paused = true


func _resume_game() -> void:
	if _pause_menu:
		_pause_menu.visible = false
	if _settings_menu:
		_settings_menu.visible = false
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	_sync_hero_audio_window()
	get_tree().paused = false


func _open_settings(from_pause: bool) -> void:
	if _settings_menu == null:
		return
	_settings_from_pause = from_pause
	if _pause_menu:
		_pause_menu.visible = false
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	_settings_menu.visible = true
	if _settings_edit_button:
		_settings_edit_button.disabled = not GameSession.fight_started
	if _settings_menu_button:
		_settings_menu_button.text = "Return to Main Menu" if GameSession.fight_started else "Back to Main Menu"


func _close_settings() -> void:
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	if _settings_menu:
		_settings_menu.visible = false
	if _settings_from_pause and GameSession.fight_started:
		_pause_menu.visible = true
	else:
		get_tree().paused = false


func _enter_edit_mode() -> void:
	if not GameSession.fight_started:
		return
	if _hero_audio_menu:
		_hero_audio_menu.visible = false
	_sync_hero_audio_window()
	if _pause_menu:
		_pause_menu.visible = false
	if _settings_menu:
		_settings_menu.visible = false
	_edit_mode = true
	_edit_toolbar.visible = true
	get_tree().paused = true
	_refresh_combat()
	for handle in _edit_handles:
		handle.visible = true
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_edit_handles()


func _leave_edit_mode(show_pause: bool) -> void:
	if not _edit_mode:
		return
	_finish_frame_drag()
	_edit_mode = false
	_save_hud_layout()
	if _edit_toolbar:
		_edit_toolbar.visible = false
	for handle in _edit_handles:
		handle.visible = false
		handle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_combat()
	if show_pause and GameSession.fight_started:
		_pause_menu.visible = true
		get_tree().paused = true
	else:
		get_tree().paused = false


func _return_to_main_menu() -> void:
	if not GameSession.fight_started:
		_close_settings()
		return
	if _edit_mode:
		_edit_mode = false
	get_tree().paused = false
	GameSession.restart()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		_master_volume = clampf(float(cfg.get_value("audio", "master_volume", _master_volume)), 0.0, 1.0)
		_fullscreen = bool(cfg.get_value("display", "fullscreen", _fullscreen))
		GameSession.smart_cast = bool(cfg.get_value("combat", "smart_cast", GameSession.smart_cast))
	_apply_settings()


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("audio", "master_volume", _master_volume)
	cfg.set_value("display", "fullscreen", _fullscreen)
	cfg.set_value("combat", "smart_cast", GameSession.smart_cast)
	cfg.save("user://settings.cfg")


func _apply_settings() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, _master_volume <= 0.001)
		AudioServer.set_bus_volume_db(master, linear_to_db(maxf(_master_volume, 0.001)))
	if DisplayServer.get_name().to_lower() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)


func _build_reload_button() -> void:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var btn := Button.new()
	btn.text = "Reload"
	btn.tooltip_text = "Quit and relaunch so the newest scripts load"
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -132
	btn.offset_right = -16
	btn.offset_top = 12
	btn.offset_bottom = 46
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_menu_button(btn)
	btn.pressed.connect(_reload_latest)
	overlay.add_child(btn)


func _reload_latest() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	if not "--path" in args:
		var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
		args = PackedStringArray(["--path", project_dir])
	OS.set_restart_on_exit(true, args)
	get_tree().quit()


func _ignore_mouse(n: Control) -> void:
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		if c is Control:
			_ignore_mouse(c)


func _apply_circle_clip(t: TextureRect) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _CircleClip
	t.material = mat


func _unit_portrait_tex(u: Unit) -> Texture2D:
	if u == null:
		return null
	if u == GameSession.active_unit:
		var kit: ChampionClass = ClassCatalog.get_by_id(GameSession.selected_class_id)
		var icon_id := "attenuate"
		if kit and not kit.passive_icon.is_empty():
			icon_id = kit.passive_icon
		return _StatusIcons.texture_for(icon_id)
	if not u.abilities.is_empty():
		var ab: AbilityDef = u.abilities[0]
		var icon_id := ab.icon_id if not ab.icon_id.is_empty() else ab.id
		if not icon_id.is_empty():
			return _StatusIcons.texture_for(icon_id)
	return _StatusIcons.texture_for("ward")


func _glow_slot(panel: Panel, on: bool) -> void:
	if panel == null:
		return
	var frame := panel.get_node_or_null("Frame") as CanvasItem
	if frame:
		frame.modulate = _SLOT_HOVER if on else Color.WHITE


func _make_spark() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture = _hud_tex("wow_spark.png")
	t.custom_minimum_size = Vector2(_SPARK_PX, _SPARK_PX)
	t.size = Vector2(_SPARK_PX, _SPARK_PX)
	t.set_anchors_preset(Control.PRESET_TOP_LEFT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.z_index = 12
	t.pivot_offset = Vector2(_SPARK_PX, _SPARK_PX) * 0.5
	t.visible = false
	return t


func _place_spark(spark: TextureRect, bar: ProgressBar) -> void:
	if spark == null or bar == null:
		return
	if not bar.is_visible_in_tree():
		spark.visible = false
		return
	var ratio := 0.0
	if bar.max_value > 0.001:
		ratio = clampf(float(bar.value) / float(bar.max_value), 0.0, 1.0)
	if ratio <= 0.03 or ratio >= 0.985:
		spark.visible = false
		return
	spark.visible = true
	spark.size = Vector2(_SPARK_PX, _SPARK_PX)
	spark.pivot_offset = Vector2(_SPARK_PX, _SPARK_PX) * 0.5
	var pulse := 1.05 + 0.12 * sin(Time.get_ticks_msec() * 0.014)
	spark.scale = Vector2(pulse, pulse)
	var gr := bar.get_global_rect()
	spark.global_position = Vector2(
		gr.position.x + gr.size.x * ratio - _SPARK_PX * 0.5,
		gr.position.y + gr.size.y * 0.5 - _SPARK_PX * 0.5
	)


func _pulse_player_frame(u: Unit) -> void:
	if _player_frame == null or u == null:
		return
	var ratio := 1.0
	if u.max_health > 0.001:
		ratio = u.health / u.max_health
	if ratio >= 0.25:
		_hp_pulse_t = 0.0
		_player_frame.modulate = Color.WHITE
		return
	_hp_pulse_t += get_process_delta_time()
	var wave := 0.58 + 0.42 * (0.5 + 0.5 * sin(_hp_pulse_t * 7.0))
	_player_frame.modulate = Color(1.0, wave, wave)


func _tick_hud_life(_delta: float) -> void:
	_place_spark(_cast_spark, _cast_bar)
	_place_spark(_boss_cast_spark, _boss_cast_bar)
	if _passive_panel:
		_glow_slot(_passive_panel, _hover_passive)
