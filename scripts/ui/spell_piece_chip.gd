class_name SpellPieceChip
extends Panel

signal pressed

var piece_kind: String = ""
var piece_id: String = ""
var piece_color: Color = Color(0.86, 0.9, 0.96)

var _art: TextureRect
var _label: Label
var _selected: int = -1
static var _style_idle: StyleBoxFlat
static var _style_sel: StyleBoxFlat


func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -15
	_label.offset_bottom = -1
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_selected(false)


func setup(kind: String, id: String, caption: String, tex: Texture2D, tint: Color = Color.WHITE) -> void:
	piece_kind = kind
	piece_id = id
	piece_color = tint
	if _art == null:
		await ready
	if _art:
		_art.texture = tex
		_art.modulate = tint if tex else Color.WHITE
	if _label:
		_label.text = caption
		_label.add_theme_color_override("font_color", tint)
	tooltip_text = ""


func set_selected(on: bool) -> void:
	if _style_idle == null:
		_style_idle = _make_style(false)
		_style_sel = _make_style(true)
	var flag := 1 if on else 0
	if _selected == flag:
		return
	_selected = flag
	add_theme_stylebox_override("panel", _style_sel if on else _style_idle)


func _make_style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.055, 0.98)
	style.border_color = Color(1.0, 0.80, 0.30, 1.0) if on else Color(0.36, 0.40, 0.48, 0.92)
	style.set_border_width_all(2 if on else 1)
	style.set_corner_radius_all(6)
	return style


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if piece_kind.is_empty() or piece_id.is_empty():
		return null
	set_drag_preview(_preview())
	return {"kind": piece_kind, "id": piece_id, "from": "palette"}


func _preview() -> Control:
	var wrap := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.border_color = Color(1.0, 0.80, 0.30, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	wrap.add_theme_stylebox_override("panel", style)
	wrap.custom_minimum_size = Vector2(64, 64)
	if _art and _art.texture:
		var pic := TextureRect.new()
		pic.texture = _art.texture
		pic.set_anchors_preset(Control.PRESET_FULL_RECT)
		pic.offset_left = 4
		pic.offset_top = 4
		pic.offset_right = -4
		pic.offset_bottom = -4
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wrap.add_child(pic)
	return wrap
