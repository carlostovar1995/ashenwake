class_name SpellHotkeySlot
extends Panel

var slot_index: int = 0
signal pressed
signal piece_dropped(index: int, data: Dictionary)

var _art: TextureRect
var _label: Label
var _selected: int = -1
static var _style_idle: StyleBoxFlat
static var _style_sel: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(88, 88)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art = TextureRect.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.offset_left = 3
	_art.offset_top = 3
	_art.offset_right = -3
	_art.offset_bottom = -3
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.offset_left = 6
	_label.offset_top = 4
	_label.offset_right = 28
	_label.offset_bottom = 22
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_paint_border(false)


func set_art(tex: Texture2D, caption: String) -> void:
	if _art:
		_art.texture = tex
	if _label:
		_label.text = caption


func set_selected(on: bool) -> void:
	_paint_border(on)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		modulate = Color.WHITE
		return false
	var kind := String(data.get("kind", ""))
	var ok := kind == "base" or kind == "infusion" or kind == "augment"
	modulate = Color(1.12, 1.06, 0.82) if ok else Color.WHITE
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	modulate = Color.WHITE
	if data is Dictionary:
		piece_dropped.emit(slot_index, data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE


func _paint_border(selected: bool) -> void:
	if _style_idle == null:
		_style_idle = _make_style(false)
		_style_sel = _make_style(true)
	var flag := 1 if selected else 0
	if _selected == flag:
		return
	_selected = flag
	add_theme_stylebox_override("panel", _style_sel if selected else _style_idle)
	if _label:
		_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38) if selected else Color(0.86, 0.9, 0.96))


func _make_style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.98)
	style.border_color = Color(1.0, 0.80, 0.30, 1.0) if on else Color(0.36, 0.40, 0.48, 0.92)
	style.set_border_width_all(2 if on else 1)
	style.set_corner_radius_all(6)
	return style
