class_name SpellSocket
extends Panel

signal piece_dropped(kind: String, id: String, index: int, data: Dictionary)
signal piece_cleared(kind: String, index: int)
signal pressed(kind: String, index: int)

var socket_kind: String = ""
var socket_index: int = 0
var piece_id: String = ""
var hint: String = ""
var locked: bool = false
var active: bool = false

var _icon: TextureRect
var _label: Label
var _hover: bool = false
var _paint_key: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(76, 76)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_icon = TextureRect.new()
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 4
	_icon.offset_top = 4
	_icon.offset_right = -4
	_icon.offset_bottom = -4
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -16
	_label.offset_bottom = -2
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_paint()


func set_locked(value: bool) -> void:
	locked = value
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	_paint()


func set_active(value: bool) -> void:
	active = value
	_paint()


func set_piece(id: String, tex: Texture2D, caption: String, tint: Color = Color.WHITE) -> void:
	piece_id = id
	if _icon:
		_icon.texture = tex
		_icon.modulate = tint if tex else Color.WHITE
		_icon.visible = tex != null and not id.is_empty()
	if _label:
		_label.text = caption if not id.is_empty() else hint
	tooltip_text = ""
	_paint()


func is_empty() -> bool:
	return piece_id.is_empty()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if locked or not (data is Dictionary):
		_hover = false
		_paint()
		return false
	var ok := String(data.get("kind", "")) == socket_kind and not String(data.get("id", "")).is_empty()
	_hover = ok
	_paint()
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_hover = false
	if data is Dictionary:
		piece_dropped.emit(socket_kind, String(data.get("id", "")), socket_index, data)
	_paint()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if locked or piece_id.is_empty():
		return null
	var preview := ColorRect.new()
	preview.color = Color(1.0, 0.84, 0.38, 0.18)
	preview.custom_minimum_size = Vector2(64, 64)
	if _icon and _icon.texture:
		var pic := TextureRect.new()
		pic.texture = _icon.texture
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(pic)
	set_drag_preview(preview)
	return {"kind": socket_kind, "id": piece_id, "from": "socket", "from_index": socket_index}


func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_RIGHT and not piece_id.is_empty():
		piece_cleared.emit(socket_kind, socket_index)
		accept_event()
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		if click.double_click and not piece_id.is_empty():
			piece_cleared.emit(socket_kind, socket_index)
		else:
			pressed.emit(socket_kind, socket_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hover = false
		_paint()


func _paint() -> void:
	var empty := piece_id.is_empty()
	var key := "%s|%s|%s|%s" % [locked, _hover, active, empty]
	if key == _paint_key:
		return
	_paint_key = key
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.92)
	if locked:
		style.border_color = Color(0.28, 0.30, 0.36, 0.7)
		style.bg_color = Color(0.02, 0.02, 0.03, 0.7)
	elif _hover or active:
		style.border_color = Color(1.0, 0.86, 0.40, 1.0)
		style.bg_color = Color(0.16, 0.12, 0.04, 0.95)
	elif empty:
		style.border_color = Color(0.55, 0.48, 0.28, 0.85)
	else:
		style.border_color = Color(1.0, 0.80, 0.30, 0.95)
	style.set_border_width_all(3 if active or _hover else 2)
	style.set_corner_radius_all(8)
	if empty and not locked:
		style.border_color = Color(style.border_color, 0.7)
	add_theme_stylebox_override("panel", style)
	if _label:
		_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38) if not empty else Color(0.62, 0.58, 0.46))
		if empty and _label.text.is_empty():
			_label.text = hint
