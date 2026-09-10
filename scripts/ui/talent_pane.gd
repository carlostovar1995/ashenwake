class_name TalentPane
extends VBoxContainer

const _GOLD := Color(1.0, 0.84, 0.38)

var _points: Label
var _slot_picks: Array[OptionButton] = []
var _trees_host: HBoxContainer
var _tip: PanelContainer
var _tip_label: RichTextLabel
var _tip_from: Control
var _tip_talent: TalentDef
var _shown_specs: PackedStringArray = PackedStringArray()


func _ready() -> void:
	ClassCatalog.ensure()
	if not GameSession.talents_changed.is_connected(_refresh):
		GameSession.talents_changed.connect(_refresh)
	if not GameSession.loadout_changed.is_connected(_refresh):
		GameSession.loadout_changed.connect(_refresh)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	add_theme_constant_override("separation", 6)
	_build()
	_refresh()


func _build() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	_points = Label.new()
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold(_points, 15)
	head.add_child(_points)
	for i in TalentSpend.SPEC_SLOTS:
		var pick := OptionButton.new()
		pick.custom_minimum_size.x = 200
		pick.add_item("Empty")
		pick.set_item_metadata(0, "")
		for spec in ClassCatalog.all_classes():
			pick.add_item("%s (%s)" % [spec.display_name, spec.role])
			pick.set_item_metadata(pick.item_count - 1, spec.id)
		var slot := i
		pick.item_selected.connect(func(index: int) -> void:
			_on_spec_selected(slot, index)
		)
		head.add_child(pick)
		_slot_picks.append(pick)
	var reset := Button.new()
	reset.text = "Reset all"
	reset.pressed.connect(func() -> void:
		GameSession.talent_spend.reset_all()
	)
	head.add_child(reset)
	_trees_host = HBoxContainer.new()
	_trees_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trees_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_trees_host.add_theme_constant_override("separation", 12)
	add_child(_trees_host)
	_rebuild_trees()
	add_child(_build_footer())
	_build_tip()


func _on_spec_selected(slot: int, index: int) -> void:
	var pick := _slot_picks[slot]
	var spec_id := String(pick.get_item_metadata(index))
	GameSession.talent_spend.set_spec_slot(slot, spec_id)
	_rebuild_trees()
	_refresh()


func _rebuild_trees() -> void:
	if _trees_host == null:
		return
	_hide_inspect()
	for child in _trees_host.get_children():
		child.free()
	_shown_specs = PackedStringArray()
	var spend := GameSession.talent_spend
	for i in TalentSpend.SPEC_SLOTS:
		var spec_id := spend.spec_id_at(i)
		_shown_specs.append(spec_id)
		if spec_id.is_empty():
			_trees_host.add_child(_empty_slot(i))
			continue
		var spec := ClassCatalog.def_for(spec_id)
		if spec == null or spec.trees.is_empty():
			_trees_host.add_child(_empty_slot(i))
			continue
		_trees_host.add_child(_build_tree(spec, spec.trees[0]))


func _empty_slot(index: int) -> Panel:
	var pane := _tree_panel()
	var lab := Label.new()
	lab.text = "Slot %d empty" % (index + 1)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.set_anchors_preset(Control.PRESET_FULL_RECT)
	lab.add_theme_font_size_override("font_size", 15)
	lab.add_theme_color_override("font_color", Color(0.55, 0.52, 0.46))
	pane.add_child(lab)
	return pane


func _tree_panel() -> Panel:
	var pane := Panel.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.clip_contents = true
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.04, 0.035, 0.03, 0.92)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.55, 0.42, 0.18, 0.8)
	bg.set_corner_radius_all(4)
	pane.add_theme_stylebox_override("panel", bg)
	return pane


func _build_tree(spec: ClassDef, tree: TalentTreeDef) -> Panel:
	var pane := _tree_panel()
	var shell := VBoxContainer.new()
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 10
	shell.offset_right = -10
	shell.offset_top = 8
	shell.offset_bottom = -8
	shell.add_theme_constant_override("separation", 6)
	pane.add_child(shell)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = spec.display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold(title, 16)
	title_row.add_child(title)
	var spent := Label.new()
	spent.name = "SpecSpent_%s" % spec.id
	spent.add_theme_font_size_override("font_size", 12)
	spent.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	title_row.add_child(spent)
	var reset := Button.new()
	reset.text = "Reset"
	reset.custom_minimum_size = Vector2(64, 24)
	reset.pressed.connect(func() -> void:
		GameSession.talent_spend.reset_tree(tree.id)
	)
	title_row.add_child(reset)
	shell.add_child(title_row)
	var theme := Label.new()
	theme.text = "%s  ·  %s / %s" % [tree.theme, tree.left_name, tree.right_name]
	theme.clip_text = true
	theme.add_theme_font_size_override("font_size", 12)
	theme.add_theme_color_override("font_color", Color(0.78, 0.74, 0.66))
	shell.add_child(theme)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)
	for row in tree.row_count():
		rows.add_child(_build_row(tree, row))
	return pane


func _build_row(tree: TalentTreeDef, row: int) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	var pair := tree.ordered_row(row)
	if pair.size() == 1 and pair[0].type == TalentDef.TYPE_ULTIMATE:
		line.add_child(_talent_button(pair[0]))
		return line
	for talent in pair:
		line.add_child(_talent_button(talent))
	return line


func _talent_button(talent: TalentDef) -> Button:
	var b := Button.new()
	b.name = talent.id
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 32)
	b.clip_text = true
	b.text = ""
	b.add_theme_stylebox_override("normal", _node_style(false))
	b.add_theme_stylebox_override("hover", _node_style(true))
	b.add_theme_stylebox_override("pressed", _node_style(true))
	b.add_theme_stylebox_override("disabled", _node_style(false))
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_top", 2)
	pad.add_theme_constant_override("margin_bottom", 2)
	b.add_child(pad)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	pad.add_child(row)
	var name_l := Label.new()
	name_l.name = "TalentName"
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.add_theme_font_size_override("font_size", 13)
	name_l.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	row.add_child(name_l)
	var rank_l := Label.new()
	rank_l.name = "TalentRank"
	rank_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_l.add_theme_font_size_override("font_size", 13)
	rank_l.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	row.add_child(rank_l)
	b.pressed.connect(func() -> void:
		GameSession.talent_spend.invest(talent.id)
	)
	b.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			GameSession.talent_spend.refund(talent.id)
			accept_event()
	)
	b.mouse_entered.connect(func() -> void:
		_show_inspect(talent, b)
	)
	b.mouse_exited.connect(func() -> void:
		if _tip_from == b:
			_hide_inspect()
	)
	return b


func _node_style(hover: bool) -> StyleBoxFlat:
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(3)
	bg.set_border_width_all(1)
	bg.bg_color = Color(0.09, 0.06, 0.03, 0.95)
	bg.border_color = Color(0.62, 0.48, 0.22, 0.9 if hover else 0.55)
	return bg


func _build_footer() -> PanelContainer:
	var wrap := PanelContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.03, 0.025, 0.96)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.55, 0.42, 0.18, 0.7)
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	wrap.add_theme_stylebox_override("panel", bg)
	var hint := Label.new()
	hint.text = "Left-click invest · right-click refund. Unlocked ultimates go to D / F on the Spellbook."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.72, 0.68, 0.58))
	wrap.add_child(hint)
	return wrap


func _refresh() -> void:
	var spend := GameSession.talent_spend
	var specs := PackedStringArray()
	for i in TalentSpend.SPEC_SLOTS:
		specs.append(spend.spec_id_at(i))
	if specs != _shown_specs:
		_rebuild_trees()
	_points.text = "Specs  ·  %d / %d points left" % [spend.points_left(), TalentSpend.STARTING_POINTS]
	for i in _slot_picks.size():
		var pick := _slot_picks[i]
		var current := spend.spec_id_at(i)
		pick.set_block_signals(true)
		var found := 0
		for j in pick.item_count:
			if String(pick.get_item_metadata(j)) == current:
				found = j
				break
		pick.select(found)
		pick.set_block_signals(false)
	for spec in spend.slotted_specs():
		for tree in spec.trees:
			var spent_l := find_child("SpecSpent_%s" % spec.id, true, false) as Label
			if spent_l != null:
				spent_l.text = "%d pts" % spend.points_in_tree(tree)
			for talent in tree.talents:
				var b := find_child(talent.id, true, false) as Button
				if b == null:
					continue
				var rank := spend.rank_of(talent.id)
				var locked := not spend.can_invest(talent.id) and rank <= 0
				b.disabled = locked and rank <= 0
				b.modulate = Color(1, 1, 1) if rank > 0 else Color(0.72, 0.7, 0.66)
				var name_l := b.find_child("TalentName", true, false) as Label
				var rank_l := b.find_child("TalentRank", true, false) as Label
				if name_l != null:
					name_l.text = talent.display_name
				if rank_l != null:
					rank_l.text = "%d/%d" % [rank, talent.max_rank]
	if _tip != null and _tip.visible and _tip_talent != null and _tip_from != null and is_instance_valid(_tip_from):
		_show_inspect(_tip_talent, _tip_from)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		_hide_inspect()


func _exit_tree() -> void:
	_hide_inspect()
	if _tip != null and is_instance_valid(_tip):
		_tip.queue_free()
	_tip = null
	_tip_label = null


func _build_tip() -> void:
	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.top_level = true
	_tip.z_index = 80
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_theme_stylebox_override("panel", _tip_style())
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size.x = 280
	_tip_label.add_theme_font_size_override("normal_font_size", 13)
	_tip_label.add_theme_color_override("default_color", Color(0.90, 0.92, 0.96))
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	var host := get_parent()
	if host:
		host.add_child(_tip)
	else:
		add_child(_tip)
	set_process(false)


func _tip_style() -> StyleBox:
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


func _show_inspect(talent: TalentDef, from: Control) -> void:
	if _tip == null or _tip_label == null:
		return
	var spend := GameSession.talent_spend
	var rank := spend.rank_of(talent.id)
	var lines := "[b]%s[/b]  (%s)  %d/%d\n" % [talent.display_name, talent.type, rank, talent.max_rank]
	for i in talent.per_point.size():
		var mark := ">" if i + 1 == rank else " "
		lines += "%s %s\n" % [mark, talent.per_point[i]]
	if talent.is_skill():
		lines += "\nGoes to D or F on the Spellbook."
	_tip_label.text = lines.strip_edges()
	_tip_from = from
	_tip_talent = talent
	_tip.visible = true
	set_process(true)
	_place_inspect()


func _hide_inspect() -> void:
	_tip_from = null
	_tip_talent = null
	set_process(false)
	if _tip:
		_tip.visible = false


func _process(_delta: float) -> void:
	if _tip == null or not _tip.visible:
		set_process(false)
		return
	_place_inspect()


func _place_inspect() -> void:
	if _tip == null or not _tip.visible:
		return
	_tip.reset_size()
	var vp := get_viewport().get_visible_rect().size
	var pos: Vector2
	if _tip_from != null and is_instance_valid(_tip_from):
		var r := _tip_from.get_global_rect()
		var gap := 8.0
		pos = Vector2(r.position.x + r.size.x + gap, r.position.y)
		if pos.x + _tip.size.x > vp.x - 8.0:
			pos.x = r.position.x - _tip.size.x - gap
	else:
		pos = get_viewport().get_mouse_position() + Vector2(16.0, 16.0)
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - _tip.size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - _tip.size.y - 8.0))
	_tip.global_position = pos


func _gold(l: Label, size: int) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", _GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 4)
