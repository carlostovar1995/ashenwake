class_name EnemyNameplate
extends Node3D

const StatusIcons := preload("res://scripts/ui/status_icons.gd")

const PLATE_W := 768
const HEADER_H := 146
const HP_H := 40
const GAP := 6
const PLATE_H := HEADER_H + GAP + HP_H
const ICON := 146
const MAX_ICONS := 3
const WORLD_W := 4.39

var _vp: SubViewport
var _root: Control
var _sprite: Sprite3D
var _name: Label
var _hp: ProgressBar
var _hp_fill: StyleBoxFlat
var _hp_shield: ColorRect
var _icons: Array[Panel] = []
var _clock_tex: Texture2D


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PLATE_W, PLATE_H)
	_vp.transparent_bg = true
	_vp.disable_3d = true
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_build_ui()
	_sprite = Sprite3D.new()
	_sprite.texture = _vp.get_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.no_depth_test = true
	_sprite.transparent = true
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_sprite.flip_v = false
	_sprite.pixel_size = WORLD_W / float(PLATE_W)
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.render_priority = 127
	_sprite.sorting_offset = 24.0
	_sprite.position.y = 0.28
	add_child(_sprite)


func world_size() -> Vector2:
	return Vector2(float(PLATE_W) * _sprite.pixel_size, float(PLATE_H) * _sprite.pixel_size)


func world_offset() -> Vector3:
	return _sprite.position if _sprite else Vector3.ZERO


func refresh(u: Unit) -> void:
	if _name == null or _hp == null:
		return
	visible = u != null and is_instance_valid(u) and not u.is_dead
	if not visible:
		return
	_name.text = u.unit_name
	var hp := 0.0 if u.is_dead else u.health
	var sh := 0.0 if u.is_dead else u.shield_amount()
	var span := maxf(u.max_health, hp + sh)
	_hp.max_value = span
	_hp.value = hp
	_hp_fill.bg_color = Color(0.62, 0.10, 0.10)
	if _hp_shield:
		if sh <= 0.05 or u.is_dead:
			_hp_shield.visible = false
		else:
			_hp_shield.visible = true
			_hp_shield.anchor_left = clampf(hp / span, 0.0, 1.0)
			_hp_shield.anchor_right = clampf((hp + sh) / span, 0.0, 1.0)
	var debuffs := u.collect_nameplate_debuffs()
	debuffs.reverse()
	while _icons.size() < mini(debuffs.size(), MAX_ICONS):
		_make_icon()
	var shown := mini(debuffs.size(), MAX_ICONS)
	for i in _icons.size():
		var icon := _icons[i]
		if i >= shown:
			icon.visible = false
			continue
		icon.visible = true
		_paint_icon(icon, debuffs[i])
		var from_right := shown - i
		var x := float(PLATE_W) - float(from_right * ICON) - float(shown - i - 1) * 8.0
		icon.position = Vector2(x, 0.0)
		icon.size = Vector2(ICON, ICON)
	var icon_span := 0.0
	if shown > 0:
		icon_span = float(ICON * shown + 8 * (shown - 1) + 10)
	_name.size = Vector2(float(PLATE_W) - icon_span, float(HEADER_H))


func _build_ui() -> void:
	var root := Control.new()
	root.size = Vector2(PLATE_W, PLATE_H)
	root.custom_minimum_size = Vector2(PLATE_W, PLATE_H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.clip_contents = false
	_vp.add_child(root)
	_root = root
	_name = Label.new()
	_name.position = Vector2.ZERO
	_name.size = Vector2(PLATE_W, HEADER_H)
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 72)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_name.add_theme_constant_override("outline_size", 16)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_name)
	var hp_wrap := Panel.new()
	hp_wrap.position = Vector2(0, HEADER_H + GAP)
	hp_wrap.size = Vector2(PLATE_W, HP_H)
	hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_wrap.add_theme_stylebox_override("panel", _box(Color.BLACK, Color.BLACK, 0))
	root.add_child(hp_wrap)
	_hp = ProgressBar.new()
	_hp.position = Vector2(4, 4)
	_hp.size = Vector2(PLATE_W - 8, HP_H - 8)
	_hp.show_percentage = false
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	_hp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	_hp.add_theme_font_size_override("font_size", 1)
	_hp_fill = StyleBoxFlat.new()
	_hp_fill.bg_color = Color(0.62, 0.10, 0.10)
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.08, 0.02, 0.02)
	_hp.add_theme_stylebox_override("fill", _hp_fill)
	_hp.add_theme_stylebox_override("background", trough)
	hp_wrap.add_child(_hp)
	_hp_shield = ColorRect.new()
	_hp_shield.name = "ShieldFill"
	_hp_shield.color = Color(0.86, 0.90, 0.96, 0.95)
	_hp_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_shield.anchor_left = 0.0
	_hp_shield.anchor_top = 0.0
	_hp_shield.anchor_right = 0.0
	_hp_shield.anchor_bottom = 1.0
	_hp_shield.visible = false
	_hp.add_child(_hp_shield)
	for i in MAX_ICONS:
		_make_icon()


func _make_icon() -> void:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(ICON, ICON)
	p.size = Vector2(ICON, ICON)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	p.z_index = 2
	p.add_theme_stylebox_override("panel", _box(Color(0.75, 0.8, 1.0), Color.BLACK, 4))
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2(6, 6)
	art.size = Vector2(ICON - 12, ICON - 12)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(art)
	var clock := TextureProgressBar.new()
	clock.name = "Clock"
	clock.position = Vector2.ZERO
	clock.size = Vector2(ICON, ICON)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	clock.min_value = 0.0
	clock.max_value = 1.0
	clock.step = 0.001
	clock.nine_patch_stretch = true
	clock.texture_progress = _clock_texture()
	clock.tint_progress = Color(0.02, 0.03, 0.05, 0.62)
	clock.visible = false
	p.add_child(clock)
	var stacks := Label.new()
	stacks.name = "Stacks"
	stacks.position = Vector2.ZERO
	stacks.size = Vector2(ICON, ICON)
	stacks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stacks.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stacks.add_theme_font_size_override("font_size", 84)
	stacks.add_theme_color_override("font_color", Color.WHITE)
	stacks.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	stacks.add_theme_constant_override("outline_size", 16)
	stacks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(stacks)
	_root.add_child(p)
	_icons.append(p)


func _paint_icon(icon: Panel, data: Dictionary) -> void:
	var color: Color = data.get("color", Color(0.7, 0.7, 0.75))
	var pastel := color.lightened(0.45)
	pastel.a = 1.0
	icon.add_theme_stylebox_override("panel", _box(pastel, Color.BLACK, 4))
	var art := icon.get_node("Art") as TextureRect
	if art:
		art.texture = StatusIcons.texture_for(String(data.get("icon", data.get("id", ""))))
	var remaining := float(data.get("time_left", 0.0))
	var duration := float(data.get("duration", 0.0))
	var clock := icon.get_node_or_null("Clock") as TextureProgressBar
	if clock:
		if remaining > 0.04 and duration > 0.04:
			var remain := clampf(remaining / duration, 0.0, 1.0)
			var elapsed := 1.0 - remain
			clock.visible = elapsed > 0.02
			clock.value = elapsed
		else:
			clock.visible = false
	var stacks := icon.get_node_or_null("Stacks") as Label
	if stacks:
		var n := int(data.get("stacks", 0))
		stacks.text = str(n) if n > 0 else ""


func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(0)
	return s


func _clock_texture() -> Texture2D:
	if _clock_tex:
		return _clock_tex
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_clock_tex = ImageTexture.create_from_image(img)
	return _clock_tex
