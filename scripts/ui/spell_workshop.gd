class_name SpellWorkshop
extends VBoxContainer

const _GOLD := Color(1.0, 0.84, 0.38)
const _HOTKEYS := ["Q", "W", "E", "R", "D", "F"]

var _slot_buttons: Array[SpellHotkeySlot] = []
var _edit_index: int = 0
var _stats: Label
var _lore: RichTextLabel
var _lore_costs: RichTextLabel
var _lore_infusions: RichTextLabel
var _lore_augments: RichTextLabel
var _lore_icon: TextureRect
var _lore_title: Label
var _base_buttons: Dictionary = {}
var _infusion_buttons: Dictionary = {}
var _augment_buttons: Dictionary = {}
var _infusion_heading: Label
var _augment_heading: Label
var _picker_heading: Label
var _base_pane: Control
var _infusion_pane: Control
var _augment_pane: Control
var _picker_kind: String = "base"
var _focus_socket: int = 0
var _base_socket: SpellSocket
var _infusion_sockets: Array[SpellSocket] = []
var _augment_sockets: Array[SpellSocket] = []
var _craft_hint: Label
var _tip: PanelContainer
var _tip_label: RichTextLabel
var _tip_from: Control
var _kit_dropdown: OptionButton
var _kit_save: Button
var _kit_new: Button
var _kit_delete: Button
var _kit_hint: Label
var _kit_lock: bool = false
var _kit_name_popup: PopupPanel
var _kit_name_edit: LineEdit


func _ready() -> void:
	GameSession.ensure_loadout()
	if not GameSession.balance_changed.is_connected(_refresh):
		GameSession.balance_changed.connect(_refresh)
	if not GameSession.loadout_changed.is_connected(_on_loadout_changed):
		GameSession.loadout_changed.connect(_on_loadout_changed)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build()
	_select_slot(0)
	_refresh_kit_ui()


func _on_socket_drop(kind: String, id: String, index: int, data: Dictionary) -> void:
	if id.is_empty():
		return
	var recipe := _recipe()
	var from := String(data.get("from", ""))
	var from_index := int(data.get("from_index", -1))
	if kind == "base":
		_set_base(id)
		return
	if kind == "infusion":
		if from == "socket" and from_index != index:
			recipe.set_infusion(from_index, "")
		recipe.set_infusion(index, id)
	elif kind == "augment":
		if not SpellCatalog.augment_fits(recipe.base_id, id):
			return
		if id == SpellRecipe.OVERFLOW_ID:
			if not recipe.has_overflow():
				recipe.toggle_augment(id)
		else:
			if recipe.has_overflow():
				return
			if from == "socket" and from_index != index:
				recipe.set_augment(from_index, "")
			recipe.set_augment(index, id)
	GameSession.set_slot_recipe(_edit_index, recipe)
	_refresh()


func _on_socket_clear(kind: String, index: int) -> void:
	var recipe := _recipe()
	if kind == "base":
		return
	if kind == "infusion":
		recipe.set_infusion(index, "")
	elif kind == "augment":
		recipe.set_augment(index, "")
	GameSession.set_slot_recipe(_edit_index, recipe)
	_refresh()


func _on_hotkey_drop(index: int, data: Dictionary) -> void:
	_edit_index = clampi(index, 0, 5)
	var kind := String(data.get("kind", ""))
	var id := String(data.get("id", ""))
	if id.is_empty():
		_refresh()
		return
	if kind == "base":
		_set_base(id)
	elif kind == "infusion":
		var recipe := _recipe()
		if not recipe.has_infusion(id):
			recipe.toggle_infusion(id)
			GameSession.set_slot_recipe(_edit_index, recipe)
		_refresh()
	elif kind == "augment":
		_toggle_augment(id)


func _build() -> void:
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	add_child(body)
	body.add_child(_build_kit_column())
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	body.add_child(main)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.add_theme_constant_override("separation", 6)
	main.add_child(slots)
	for i in 6:
		var b := _slot_button(i)
		slots.add_child(b)
		_slot_buttons.append(b)
		_paint_slot(b, i)
	_stats = Label.new()
	_stats.visible = false
	main.add_child(_stats)
	main.add_child(_build_craft_bench())
	main.add_child(_build_picker())
	main.add_child(_build_lore_pane())
	_build_piece_tip()
	_build_kit_name_popup()


func _build_lore_pane() -> Panel:
	var pane := Panel.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.custom_minimum_size = Vector2(0, 64)
	pane.clip_contents = true
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.015, 0.02, 0.035, 0.82)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.36, 0.40, 0.48, 0.55)
	bg.set_corner_radius_all(4)
	pane.add_theme_stylebox_override("panel", bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_right = -10
	scroll.offset_top = 8
	scroll.offset_bottom = -8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.clip_contents = true
	pane.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	scroll.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	_lore_icon = TextureRect.new()
	_lore_icon.custom_minimum_size = Vector2(48, 48)
	_lore_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lore_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_lore_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lore_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_lore_icon)
	_lore_title = Label.new()
	_lore_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lore_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label(_lore_title, 20)
	head.add_child(_lore_title)
	_lore = _lore_text()
	col.add_child(_lore)
	var cols := HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	col.add_child(cols)
	_lore_costs = _lore_column(cols, "Stats")
	_lore_infusions = _lore_column(cols, "Infusions")
	_lore_augments = _lore_column(cols, "Augments")
	var fit_wrap := func() -> void:
		var wrap_w := scroll.size.x - 8.0
		if wrap_w > 80.0:
			col.custom_minimum_size.x = wrap_w
			_lore.custom_minimum_size.x = wrap_w
	scroll.resized.connect(fit_wrap)
	pane.resized.connect(fit_wrap)
	return pane


func _lore_text() -> RichTextLabel:
	var lab := RichTextLabel.new()
	lab.bbcode_enabled = true
	lab.fit_content = true
	lab.scroll_active = false
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.add_theme_font_size_override("normal_font_size", 14)
	lab.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96))
	return lab


func _lore_column(row: HBoxContainer, heading: String) -> RichTextLabel:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = 1.0
	box.add_theme_constant_override("separation", 4)
	var lab := Label.new()
	lab.text = heading
	_gold_label(lab, 13)
	box.add_child(lab)
	var body := _lore_text()
	box.add_child(body)
	row.add_child(box)
	return body


func _section(title: String, body: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	var lab := Label.new()
	lab.text = title
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(lab, 11)
	box.add_child(lab)
	box.add_child(body)
	return box


func _build_craft_bench() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_craft_hint = Label.new()
	_craft_hint.text = "Click an empty socket to choose pieces. Right-click a filled socket to remove it."
	_craft_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_craft_hint.modulate = Color(0.70, 0.72, 0.78)
	_craft_hint.add_theme_font_size_override("font_size", 11)
	box.add_child(_craft_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_base_socket = _make_socket("base", 0, "+")
	row.add_child(_socket_group("BASE", [_base_socket]))
	_infusion_sockets.clear()
	for i in 3:
		_infusion_sockets.append(_make_socket("infusion", i, "+"))
	row.add_child(_socket_group("INFUSIONS", _infusion_sockets))
	_augment_sockets.clear()
	for i in 3:
		_augment_sockets.append(_make_socket("augment", i, "+"))
	row.add_child(_socket_group("AUGMENTS", _augment_sockets))
	return box


func _socket_group(title: String, sockets: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var lab := Label.new()
	lab.text = title
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(lab, 11)
	box.add_child(lab)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	for sock in sockets:
		row.add_child(sock)
	return box


func _make_socket(kind: String, index: int, hint: String) -> SpellSocket:
	var sock := SpellSocket.new()
	sock.socket_kind = kind
	sock.socket_index = index
	sock.hint = hint
	sock.piece_dropped.connect(func(k: String, pid: String, idx: int, data: Dictionary) -> void:
		_on_socket_drop(k, pid, idx, data)
	)
	sock.piece_cleared.connect(func(k: String, idx: int) -> void:
		_on_socket_clear(k, idx)
	)
	sock.pressed.connect(func(k: String, idx: int) -> void:
		_on_socket_pressed(k, idx)
	)
	_hook_socket_tip(sock)
	return sock


func _slot_button(index: int) -> SpellHotkeySlot:
	var b := SpellHotkeySlot.new()
	b.slot_index = index
	b.pressed.connect(func() -> void:
		_select_slot(index)
	)
	b.piece_dropped.connect(func(i: int, data: Dictionary) -> void:
		_on_hotkey_drop(i, data)
	)
	return b


func _build_picker() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 6)
	_picker_heading = Label.new()
	_picker_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(_picker_heading, 13)
	box.add_child(_picker_heading)
	_base_pane = _build_base_row()
	_infusion_pane = _build_infusion_row()
	_augment_pane = _build_augment_row()
	box.add_child(_base_pane)
	box.add_child(_infusion_pane)
	box.add_child(_augment_pane)
	_infusion_pane.visible = false
	_augment_pane.visible = false
	_infusion_heading = _picker_heading
	_augment_heading = _picker_heading
	return box


func _chip_flow(min_h: float = 110.0) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.custom_minimum_size.y = min_h
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	# FlowContainer.ALIGNMENT_CENTER — leftover / extra icons stay centered.
	flow.set("alignment", 1)
	return flow


func _picker_subhead(title: String) -> Label:
	var lab := Label.new()
	lab.text = title
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(lab, 11)
	return lab


func _add_infusion_chip(parent: Control, inf: SpellInfusion) -> void:
	var id := inf.id
	var b := SpellPieceChip.new()
	b.pressed.connect(func() -> void:
		_toggle_infusion(id)
	)
	parent.add_child(b)
	b.setup("infusion", id, inf.display_name, StatusIcons.texture_for(inf.icon_tag), inf.color.lightened(0.15))
	_hook_piece_tip(b, "infusion", id)
	_infusion_buttons[id] = b


func _build_base_row() -> HFlowContainer:
	var flow := _chip_flow(210.0)
	for base in SpellCatalog.all_bases():
		var id := base.id
		var b := SpellPieceChip.new()
		b.pressed.connect(func() -> void:
			_set_base(id)
		)
		flow.add_child(b)
		b.setup("base", id, base.display_name, StatusIcons.texture_for_ability(base.icon_id, ""))
		_hook_piece_tip(b, "base", id)
		_base_buttons[id] = b
	return flow


func _build_infusion_row() -> Control:
	var wrap := CenterContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 48)
	row.add_child(_infusion_category("OFFENSIVE", SpellCatalog.all_offensive_infusions()))
	row.add_child(_infusion_category("UTILITY", SpellCatalog.all_utility_infusions()))
	row.add_child(_infusion_category("DEFENSIVE", SpellCatalog.all_defensive_infusions()))
	wrap.add_child(row)
	return wrap


func _infusion_category(title: String, infusions: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.add_child(_picker_subhead(title))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	for inf in infusions:
		_add_infusion_chip(chips, inf)
	col.add_child(chips)
	return col


func _build_augment_row() -> HFlowContainer:
	var flow := _chip_flow(210.0)
	for aug in SpellCatalog.all_augments():
		var id := aug.id
		var b := SpellPieceChip.new()
		b.pressed.connect(func() -> void:
			_toggle_augment(id)
		)
		flow.add_child(b)
		b.setup("augment", id, aug.display_name, StatusIcons.texture_for(aug.id))
		_hook_piece_tip(b, "augment", id)
		_augment_buttons[id] = b
	return flow


func _select_slot(index: int) -> void:
	_edit_index = clampi(index, 0, 5)
	_show_picker("base", 0)


func _on_socket_pressed(kind: String, index: int) -> void:
	_show_picker(kind, index)


func _show_picker(kind: String, socket_index: int = -1) -> void:
	_picker_kind = kind
	if socket_index >= 0:
		_focus_socket = socket_index
	if _base_pane:
		_base_pane.visible = kind == "base"
	if _infusion_pane:
		_infusion_pane.visible = kind == "infusion"
	if _augment_pane:
		_augment_pane.visible = kind == "augment"
	_refresh()


func _next_empty_infusion(recipe: SpellRecipe) -> int:
	var cap := recipe.infusion_cap()
	for i in cap:
		if i >= recipe.infusion_ids.size() or String(recipe.infusion_ids[i]).is_empty():
			return i
	return -1


func _next_empty_augment(recipe: SpellRecipe) -> int:
	if recipe.has_overflow():
		return -1
	for i in SpellRecipe.MAX_AUGMENTS:
		if i >= recipe.augment_ids.size() or String(recipe.augment_ids[i]).is_empty():
			return i
	return -1


func _recipe() -> SpellRecipe:
	GameSession.ensure_loadout()
	var item = GameSession.spell_loadout[_edit_index]
	if item is SpellRecipe:
		return item
	var fresh: SpellRecipe = SpellCatalog.default_loadout()[_edit_index]
	GameSession.set_slot_recipe(_edit_index, fresh)
	return fresh


func _set_base(base_id: String) -> void:
	if not SpellCatalog.is_base_available(base_id):
		return
	var recipe := _recipe()
	recipe.base_id = base_id
	recipe.normalize()
	GameSession.set_slot_recipe(_edit_index, recipe)
	_show_picker("infusion", _next_empty_infusion(recipe))


func _toggle_infusion(infusion_id: String) -> void:
	var recipe := _recipe()
	if recipe.has_infusion(infusion_id):
		recipe.toggle_infusion(infusion_id)
		GameSession.set_slot_recipe(_edit_index, recipe)
		var back := _next_empty_infusion(recipe)
		_show_picker("infusion", back if back >= 0 else 0)
		return
	if _picker_kind == "infusion" and _focus_socket >= 0:
		recipe.set_infusion(_focus_socket, infusion_id)
	else:
		recipe.toggle_infusion(infusion_id)
	GameSession.set_slot_recipe(_edit_index, recipe)
	var next := _next_empty_infusion(recipe)
	if next >= 0:
		_show_picker("infusion", next)
	else:
		_show_picker("augment", _next_empty_augment(recipe))


func _toggle_augment(augment_id: String) -> void:
	var recipe := _recipe()
	if not recipe.has_augment(augment_id) and not SpellCatalog.augment_fits(recipe.base_id, augment_id):
		return
	if recipe.has_overflow() and augment_id != SpellRecipe.OVERFLOW_ID:
		return
	if augment_id == SpellRecipe.OVERFLOW_ID or _picker_kind != "augment" or _focus_socket < 0:
		recipe.toggle_augment(augment_id)
	else:
		recipe.set_augment(_focus_socket, augment_id)
	GameSession.set_slot_recipe(_edit_index, recipe)
	if recipe.has_overflow():
		_show_picker("infusion", _next_empty_infusion(recipe))
		return
	var next := _next_empty_augment(recipe)
	if next >= 0:
		_show_picker("augment", next)
	else:
		_refresh()


func _fill_lore(ab: AbilityDef, recipe: SpellRecipe) -> void:
	var parts := SpellCard.sections(ab, recipe, true)
	if _lore:
		var top: PackedStringArray = PackedStringArray()
		var flavor := String(parts.get("flavor", ""))
		if not flavor.is_empty():
			top.append(flavor)
		var lock := String(parts.get("lock", ""))
		if not lock.is_empty():
			top.append(lock)
		_set_bbcode(_lore, "\n".join(top))
	if _lore_costs:
		_set_bbcode(_lore_costs, "\n".join(parts.get("costs", PackedStringArray())))
	if _lore_infusions:
		var inf_lines: PackedStringArray = PackedStringArray()
		var note := String(parts.get("infusion_note", ""))
		if not note.is_empty():
			inf_lines.append(note)
		for line in parts.get("infusions", PackedStringArray()):
			inf_lines.append(String(line))
		_set_bbcode(_lore_infusions, "\n".join(inf_lines) if not inf_lines.is_empty() else "—")
	if _lore_augments:
		var aug_lines: PackedStringArray = PackedStringArray()
		for line in parts.get("augments", PackedStringArray()):
			aug_lines.append(String(line))
		_set_bbcode(_lore_augments, "\n".join(aug_lines) if not aug_lines.is_empty() else "—")


func _set_bbcode(lab: RichTextLabel, text: String) -> void:
	if lab.text != text:
		lab.text = text


func _on_loadout_changed() -> void:
	if not is_inside_tree() or _slot_buttons.is_empty():
		return
	_refresh()
	_refresh_kit_ui()


func _build_kit_column() -> Panel:
	var pane := Panel.new()
	pane.custom_minimum_size.x = 204
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.015, 0.02, 0.035, 0.82)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.36, 0.40, 0.48, 0.55)
	bg.set_corner_radius_all(4)
	pane.add_theme_stylebox_override("panel", bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_right = -10
	col.offset_top = 10
	col.offset_bottom = -10
	col.add_theme_constant_override("separation", 8)
	pane.add_child(col)
	var title := Label.new()
	title.text = "KITS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(title, 13)
	col.add_child(title)
	_kit_dropdown = OptionButton.new()
	_kit_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_dropdown.fit_to_longest_item = false
	_kit_dropdown.custom_minimum_size = Vector2(0, 34)
	_kit_dropdown.tooltip_text = "Swap this spellbook for a saved kit."
	_style_kit_dropdown(_kit_dropdown)
	_kit_dropdown.item_selected.connect(_on_kit_selected)
	col.add_child(_kit_dropdown)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	col.add_child(actions)
	_kit_save = _kit_btn("Save", _on_kit_save)
	_kit_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_save.tooltip_text = "Overwrite the selected kit, or name a new one."
	actions.add_child(_kit_save)
	_kit_new = _kit_btn("New", _open_kit_name_popup)
	_kit_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_new.tooltip_text = "Save the current Q–F loadout as a new kit."
	actions.add_child(_kit_new)
	_kit_delete = _kit_btn("Delete", _on_kit_delete)
	_kit_delete.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kit_delete.tooltip_text = "Remove the selected kit. Your current spellbook stays."
	col.add_child(_kit_delete)
	_kit_hint = Label.new()
	_kit_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_kit_hint.add_theme_font_size_override("font_size", 11)
	_kit_hint.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78))
	_kit_hint.text = "Your spellbook is saved when you leave. Pick a kit to swap all six slots."
	col.add_child(_kit_hint)
	return pane


func _kit_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 30
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.11, 0.05, 0.94)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.78, 0.62, 0.28, 0.95)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.2, 0.08, 0.96)
	hover.border_color = Color(1.0, 0.86, 0.42)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.08, 0.04, 0.96)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.07, 0.06, 0.8)
	disabled.border_color = Color(0.4, 0.34, 0.22, 0.7)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", _GOLD)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.78, 0.32))
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.48, 0.32, 0.8))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	return b


func _style_kit_dropdown(b: OptionButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.07, 0.06, 0.96)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.78, 0.62, 0.28, 0.95)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.12, 0.07, 0.96)
	hover.border_color = Color(1.0, 0.86, 0.42)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", _GOLD)
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.7))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_font_size_override("font_size", 13)
	var popup := b.get_popup()
	if popup:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.05, 0.05, 0.07, 0.98)
		panel.set_border_width_all(1)
		panel.border_color = Color(0.84, 0.70, 0.34, 0.95)
		panel.set_corner_radius_all(3)
		popup.add_theme_stylebox_override("panel", panel)


func _refresh_kit_ui() -> void:
	if _kit_dropdown == null:
		return
	_kit_lock = true
	_kit_dropdown.clear()
	var names := GameSession.profile_names()
	var select_idx := 0
	var item_i := 0
	if GameSession.active_profile.is_empty():
		_kit_dropdown.add_item("Unsaved spellbook")
		_kit_dropdown.set_item_disabled(0, true)
		_kit_dropdown.set_item_metadata(0, "")
		item_i = 1
	for name in names:
		var label := String(name)
		if name == GameSession.active_profile and GameSession.is_profile_dirty():
			label = "%s *" % name
		_kit_dropdown.add_item(label)
		_kit_dropdown.set_item_metadata(item_i, name)
		if name == GameSession.active_profile:
			select_idx = item_i
		item_i += 1
	_kit_dropdown.disabled = names.is_empty()
	_kit_dropdown.select(select_idx)
	_kit_delete.disabled = GameSession.active_profile.is_empty()
	if names.is_empty():
		_kit_hint.text = "Craft Q–F, then Save to keep this spellbook as a kit you can swap back to."
	elif GameSession.active_profile.is_empty():
		_kit_hint.text = "Pick a kit to swap all six slots, or Save to name this spellbook."
	elif GameSession.is_profile_dirty():
		_kit_hint.text = "This spellbook has unsaved changes. Save to update %s." % GameSession.active_profile
	else:
		_kit_hint.text = "Loaded %s. Pick another kit to swap the whole bar." % GameSession.active_profile
	_kit_lock = false


func _on_kit_selected(index: int) -> void:
	if _kit_lock or _kit_dropdown == null:
		return
	if index < 0 or index >= _kit_dropdown.item_count:
		return
	if _kit_dropdown.is_item_disabled(index):
		return
	var name := String(_kit_dropdown.get_item_metadata(index))
	if name.is_empty() or name == GameSession.active_profile:
		return
	GameSession.apply_profile(name)


func _on_kit_save() -> void:
	if not GameSession.active_profile.is_empty():
		GameSession.save_profile(GameSession.active_profile)
		return
	_open_kit_name_popup()


func _on_kit_delete() -> void:
	if GameSession.active_profile.is_empty():
		return
	GameSession.delete_profile(GameSession.active_profile)


func _build_kit_name_popup() -> void:
	_kit_name_popup = PopupPanel.new()
	_kit_name_popup.exclusive = true
	_kit_name_popup.unresizable = true
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.03, 0.035, 0.05, 0.98)
	panel.border_color = Color(1.0, 0.80, 0.30, 0.95)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	_kit_name_popup.add_theme_stylebox_override("panel", panel)
	add_child(_kit_name_popup)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(260, 0)
	_kit_name_popup.add_child(box)
	var title := Label.new()
	title.text = "NAME THIS KIT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label(title, 13)
	box.add_child(title)
	_kit_name_edit = LineEdit.new()
	_kit_name_edit.placeholder_text = "Frost barrage"
	_kit_name_edit.max_length = 24
	_kit_name_edit.custom_minimum_size.y = 32
	_kit_name_edit.text_submitted.connect(func(_t: String) -> void:
		_confirm_kit_name()
	)
	box.add_child(_kit_name_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	row.add_child(_kit_btn("Cancel", func() -> void:
		_kit_name_popup.hide()
	))
	row.add_child(_kit_btn("Save", _confirm_kit_name))


func _open_kit_name_popup() -> void:
	if _kit_name_popup == null or _kit_name_edit == null:
		return
	_kit_name_edit.text = GameSession.active_profile
	_kit_name_popup.popup_centered()
	_kit_name_edit.grab_focus()
	_kit_name_edit.select_all()


func _confirm_kit_name() -> void:
	if _kit_name_edit == null:
		return
	if GameSession.save_profile(_kit_name_edit.text):
		if _kit_name_popup:
			_kit_name_popup.hide()


func _refresh() -> void:
	var recipe := _recipe()
	var ab := SpellCompiler.compile(recipe, _HOTKEYS[_edit_index])
	for i in _slot_buttons.size():
		_paint_slot(_slot_buttons[i], i)
		_slot_buttons[i].set_selected(i == _edit_index)
	if _lore_title:
		_lore_title.text = ab.display_name
	if _lore_icon:
		_lore_icon.texture = StatusIcons.texture_for_ability(ab.icon_id, ab.icon_infusion_tag)
	_fill_lore(ab, recipe)
	if _picker_kind == "base":
		for id in _base_buttons.keys():
			_base_buttons[id].set_selected(id == recipe.base_id)
	if _picker_heading:
		match _picker_kind:
			"infusion":
				_picker_heading.text = "INFUSIONS  (up to %d)" % recipe.infusion_cap()
			"augment":
				_picker_heading.text = "AUGMENTS  (Overflow only)" if recipe.has_overflow() else "AUGMENTS  (up to 3)"
			_:
				_picker_heading.text = "BASES"
	if _picker_kind == "infusion":
		for id in _infusion_buttons.keys():
			_infusion_buttons[id].set_selected(recipe.has_infusion(id))
	if _picker_kind == "augment":
		_paint_augment_buttons(recipe)
	_paint_sockets(recipe)


func _paint_augment_buttons(recipe: SpellRecipe) -> void:
	var overflow := recipe.has_overflow()
	for id in _augment_buttons.keys():
		var chip: SpellPieceChip = _augment_buttons[id]
		chip.set_selected(recipe.has_augment(id))
		var skip := SpellCatalog.augment_skip_reason(recipe.base_id, id)
		if not skip.is_empty():
			chip.modulate = Color(0.55, 0.55, 0.6, 0.7)
		elif overflow and id != SpellRecipe.OVERFLOW_ID:
			chip.modulate = Color(0.55, 0.55, 0.6, 0.7)
		else:
			chip.modulate = Color.WHITE


func _paint_sockets(recipe: SpellRecipe) -> void:
	var base := SpellCatalog.get_base(recipe.base_id)
	if _base_socket:
		_base_socket.set_piece(base.id, StatusIcons.texture_for_ability(base.icon_id, ""), base.display_name)
		_base_socket.set_active(_picker_kind == "base")
	var overflow := recipe.has_overflow()
	var cap := recipe.infusion_cap()
	for i in _infusion_sockets.size():
		var sock: SpellSocket = _infusion_sockets[i]
		sock.visible = i < cap
		sock.set_locked(false)
		if not sock.visible:
			continue
		var inf_id := recipe.infusion_ids[i] if i < recipe.infusion_ids.size() else ""
		var inf := SpellCatalog.get_infusion(inf_id) if not inf_id.is_empty() else null
		if inf:
			sock.set_piece(inf.id, StatusIcons.texture_for(inf.icon_tag), inf.display_name, inf.color)
		else:
			sock.set_piece("", null, "+")
		sock.set_active(_picker_kind == "infusion" and i == _focus_socket)
	for i in _augment_sockets.size():
		var sock: SpellSocket = _augment_sockets[i]
		sock.visible = not overflow or i == 0
		sock.set_locked(false)
		if not sock.visible:
			continue
		if overflow:
			var overflow_aug := SpellCatalog.get_augment(SpellRecipe.OVERFLOW_ID)
			sock.set_piece(overflow_aug.id, StatusIcons.texture_for(overflow_aug.id), overflow_aug.display_name)
			sock.set_active(_picker_kind == "augment" and i == 0)
			continue
		var aug_id := recipe.augment_ids[i] if i < recipe.augment_ids.size() else ""
		var aug := SpellCatalog.get_augment(aug_id) if not aug_id.is_empty() else null
		if aug:
			sock.set_piece(aug.id, StatusIcons.texture_for(aug.id), aug.display_name)
		else:
			sock.set_piece("", null, "+")
		sock.set_active(_picker_kind == "augment" and i == _focus_socket)


func _paint_slot(b: SpellHotkeySlot, index: int) -> void:
	GameSession.ensure_loadout()
	var recipe: SpellRecipe = GameSession.spell_loadout[index] if index < GameSession.spell_loadout.size() and GameSession.spell_loadout[index] is SpellRecipe else SpellCatalog.default_loadout()[index]
	var ab := SpellCompiler.compile(recipe, _HOTKEYS[index])
	b.set_art(StatusIcons.texture_for_ability(ab.icon_id, ab.icon_infusion_tag), _HOTKEYS[index])


func _cast_label(ab: AbilityDef) -> String:
	if ab.is_toggle:
		return "Toggle"
	if ab.is_channel:
		if ab.cast_time > 0.05:
			return "Cast %0.1fs, then channel %0.1fs" % [ab.cast_time, ab.channel_time]
		return "Channel %0.1fs" % ab.channel_time
	if ab.cast_time > 0.05:
		return "Cast %0.1fs" % ab.cast_time
	return "Instant"


func _cd_label(ab: AbilityDef) -> String:
	if ab.cooldown <= 0.05:
		return "No CD"
	return "CD %0.1fs" % ab.cooldown




func _gold_label(lab: Label, size: int) -> void:
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", _GOLD)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	lab.add_theme_constant_override("outline_size", 4)


func _hook_piece_tip(ctrl: Control, kind: String, id: String) -> void:
	ctrl.mouse_entered.connect(func() -> void:
		_show_piece_tip(kind, id, ctrl)
	)
	ctrl.mouse_exited.connect(_hide_piece_tip)


func _hook_socket_tip(sock: SpellSocket) -> void:
	sock.mouse_entered.connect(func() -> void:
		if sock.piece_id.is_empty():
			return
		_show_piece_tip(sock.socket_kind, sock.piece_id, sock)
	)
	sock.mouse_exited.connect(_hide_piece_tip)


func _build_piece_tip() -> void:
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.top_level = true
	_tip.z_index = 80
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_stylebox_override("panel", _piece_tip_style())
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size.x = 320
	_tip_label.add_theme_font_size_override("normal_font_size", 13)
	_tip_label.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96))
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	add_child(_tip)
	set_process(false)


func _piece_tip_style() -> StyleBox:
	var path := "res://assets/ui/hud/wow_tooltip_frame.png"
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			var s := StyleBoxTexture.new()
			s.texture = tex
			s.texture_margin_left = 14.0
			s.texture_margin_top = 14.0
			s.texture_margin_right = 14.0
			s.texture_margin_bottom = 14.0
			s.content_margin_left = 16.0
			s.content_margin_top = 16.0
			s.content_margin_right = 16.0
			s.content_margin_bottom = 16.0
			return s
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = Color(0.05, 0.04, 0.03, 0.96)
	fallback.border_color = Color(0.78, 0.62, 0.28, 0.9)
	fallback.set_border_width_all(2)
	fallback.set_corner_radius_all(6)
	fallback.content_margin_left = 16.0
	fallback.content_margin_top = 16.0
	fallback.content_margin_right = 16.0
	fallback.content_margin_bottom = 16.0
	return fallback


func _show_piece_tip(kind: String, id: String, from: Control) -> void:
	if _tip == null or id.is_empty():
		return
	var text := SpellCard.piece_tooltip(kind, id, true)
	if kind == "augment":
		var skip := SpellCatalog.augment_skip_reason(_recipe().base_id, id)
		if skip.is_empty() and _recipe().has_overflow() and id != SpellRecipe.OVERFLOW_ID:
			skip = "Overflow cannot be combined with other augments."
		if not skip.is_empty():
			text = "[color=#ff857a]%s[/color]\n\n%s" % [skip, text]
	if text.is_empty():
		_hide_piece_tip()
		return
	_tip_label.text = text
	_tip_from = from
	_tip.visible = true
	set_process(true)
	_place_piece_tip()


func _hide_piece_tip() -> void:
	_tip_from = null
	set_process(false)
	if _tip:
		_tip.visible = false


func _process(_delta: float) -> void:
	if _tip == null or not _tip.visible:
		set_process(false)
		return
	_place_piece_tip()


func _place_piece_tip() -> void:
	if _tip == null or not _tip.visible:
		return
	_tip.reset_size()
	var pos: Vector2
	if _tip_from != null and is_instance_valid(_tip_from):
		var r := _tip_from.get_global_rect()
		pos = Vector2(r.position.x + r.size.x + 10.0, r.position.y)
	else:
		pos = get_viewport().get_mouse_position() + Vector2(18.0, 18.0)
	var vp := get_viewport().get_visible_rect().size
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - _tip.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - _tip.size.y - 8.0))
	_tip.global_position = pos
