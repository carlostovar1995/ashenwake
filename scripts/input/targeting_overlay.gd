class_name TargetingOverlay
extends Node3D

const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")

var _range: MeshInstance3D
var _shot: MeshInstance3D
var _aoe: MeshInstance3D
var _lock: MeshInstance3D
var _cone: MeshInstance3D
var _cone_line: MeshInstance3D
var _cone_angle: float = -1.0
var _cone_radius: float = -1.0
var _cone_lengths: PackedFloat32Array = PackedFloat32Array()
var _wall_marks: Array[MeshInstance3D] = []


func _ready() -> void:
	_range = _make_circle(Color(0.3, 0.7, 1.0))
	_shot = _make_rect(Color(0.4, 0.85, 1.0))
	_aoe = _make_circle(Color(1.0, 0.55, 0.2))
	_lock = _make_circle(Color(1.0, 0.35, 0.08))
	_cone = MeshInstance3D.new()
	_cone.material_override = GroundIndicator.fill_mat(Color(0.45, 0.8, 1.0))
	GroundIndicator.prepare(_cone)
	add_child(_cone)
	_cone_line = MeshInstance3D.new()
	_cone_line.material_override = GroundIndicator.line_mat(Color(0.45, 0.8, 1.0))
	GroundIndicator.prepare(_cone_line)
	add_child(_cone_line)
	hide_fx()
	hide_lock()
	if not GameSession.highlight_settings_changed.is_connected(_apply_outline_width):
		GameSession.highlight_settings_changed.connect(_apply_outline_width)
	_apply_outline_width()


func _make_circle(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GroundIndicator.circle_mesh()
	mi.material_override = GroundIndicator.shader_mat(color, true)
	GroundIndicator.prepare(mi)
	add_child(mi)
	return mi


func _make_rect(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = GroundIndicator.rect_mesh()
	mi.material_override = GroundIndicator.shader_mat(color, false)
	GroundIndicator.prepare(mi)
	add_child(mi)
	return mi


func hide_fx() -> void:
	if _range:
		_range.visible = false
	if _shot:
		_shot.visible = false
	if _aoe:
		_aoe.visible = false
	if _cone:
		_cone.visible = false
	if _cone_line:
		_cone_line.visible = false
	_hide_wall_marks()


func show_range(u: Unit, radius: float) -> void:
	hide_fx()
	_range.visible = true
	_range.global_position = Vector3(u.global_position.x, 0.09, u.global_position.z)
	GroundIndicator.set_circle_radius(_range, radius)


func show_skillshot(u: Unit, aim: Vector3, ab: AbilityDef) -> void:
	show_range(u, ab.range)
	var dir := aim - u.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = u.facing_dir()
	dir = dir.normalized()
	if ab.is_cone():
		_show_cone(u, dir, ab)
		return
	var max_len := minf(ab.skillshot_length, ab.range) if ab.skillshot_length > 0.05 else ab.range
	max_len = u.wall_travel_distance(dir, max_len, false)
	var length := max_len
	if ab.splash_radius > 0.05:
		var to_cursor := Vector2(aim.x - u.global_position.x, aim.z - u.global_position.z).length()
		length = clampf(to_cursor, 0.4, max_len)
	_shot.visible = true
	var mid := u.global_position + dir * (length * 0.5)
	_shot.global_position = Vector3(mid.x, 0.1, mid.z)
	_shot.scale = Vector3(ab.skillshot_width, 1.0, length)
	_shot.look_at(Vector3(mid.x, 0.1, mid.z) + dir, Vector3.UP)
	GroundIndicator.tint_palette(_shot.material_override, SpellBaseFx.palette(ab))
	var sm := _shot.material_override as ShaderMaterial
	if sm:
		sm.set_shader_parameter("quad_size", Vector2(ab.skillshot_width, length))
	if ab.splash_radius > 0.05:
		var end := u.global_position + dir * length
		_aoe.visible = true
		_aoe.global_position = Vector3(end.x, 0.09, end.z)
		GroundIndicator.set_circle_radius(_aoe, ab.splash_radius)
		GroundIndicator.set_inner_hole(_aoe.material_override, 0.0, ab.splash_radius)
		_tint_aoe(ab)


func _show_cone(u: Unit, dir: Vector3, ab: AbilityDef) -> void:
	var radius := ab.range if ab.range > 0.05 else ab.skillshot_length
	_build_clipped_cone(ab.cone_angle, u.cone_wall_lengths(dir, ab.cone_angle, radius, 20))
	_cone.visible = true
	_cone_line.visible = true
	var pos := Vector3(u.global_position.x, 0.09, u.global_position.z)
	_cone.global_position = pos
	_cone_line.global_position = pos
	var look := pos + dir
	if look.distance_squared_to(pos) > 0.0001:
		_cone.look_at(look, Vector3.UP)
		_cone_line.look_at(look, Vector3.UP)
	GroundIndicator.tint_standard(_cone.material_override, ab.color, GroundIndicator.FILL_ALPHA)
	GroundIndicator.tint_standard(_cone_line.material_override, ab.color, GroundIndicator.OUTLINE_ALPHA)


func _build_clipped_cone(angle: float, lengths: PackedFloat32Array) -> void:
	_cone.mesh = GroundIndicator.cone_fill_mesh(angle, lengths)
	_cone_line.mesh = GroundIndicator.cone_outline_mesh(angle, lengths)
	_cone_angle = angle
	_cone_lengths = lengths
	_cone_radius = -1.0


func show_ground(u: Unit, aim: Vector3, ab: AbilityDef) -> void:
	if ab.delivery == AbilityDef.Delivery.WALL:
		_show_wall(u, aim, ab)
		return
	show_range(u, ab.range)
	_aoe.visible = true
	var pos := u.clamped_ground_point(aim, ab.range)
	_aoe.global_position = Vector3(pos.x, 0.09, pos.z)
	GroundIndicator.set_circle_radius(_aoe, ab.aoe_radius)
	GroundIndicator.set_inner_hole(_aoe.material_override, 0.0, ab.aoe_radius)
	_tint_aoe(ab)


func _show_wall(u: Unit, aim: Vector3, ab: AbilityDef) -> void:
	show_range(u, ab.range)
	var pos := u.clamped_ground_point(aim, ab.range)
	var dir := SpellWallLayout.aim_dir(u.global_position, pos, u.facing_dir())
	if SpellWallLayout.style_id(ab) == "ice":
		_show_ice_wall(pos, dir, ab)
		return
	if SpellWallLayout.style_id(ab) == "lightning":
		_show_lightning_wall(pos, ab)
		return
	if SpellWallLayout.style_id(ab) == "nature":
		_show_nature_wall(pos, ab)
		return
	if SpellWallLayout.style_id(ab) == "divine":
		_show_divine_wall(pos, ab)
		return
	if SpellWallLayout.style_id(ab) == "protection":
		_show_protection_wall(u, pos, ab)
		return
	if SpellWallLayout.style_id(ab) == "illusion":
		_show_illusion_wall(pos, dir, ab)
		return
	var length := SpellWallLayout.length_of(ab)
	var thick := SpellWallLayout.thickness_of(ab)
	_shot.visible = true
	_shot.global_position = Vector3(pos.x, 0.1, pos.z)
	_shot.scale = Vector3(length, 1.0, thick)
	var look := _shot.global_position + dir
	if look.distance_squared_to(_shot.global_position) > 0.0001:
		_shot.look_at(look, Vector3.UP)
	GroundIndicator.tint_palette(_shot.material_override, SpellBaseFx.palette(ab))
	var sm := _shot.material_override as ShaderMaterial
	if sm:
		sm.set_shader_parameter("quad_size", Vector2(length, thick))


func _show_illusion_wall(pos: Vector3, _dir: Vector3, ab: AbilityDef) -> void:
	var radius := SpellWallLayout.illusion_radius(ab)
	_ensure_wall_marks(1)
	var pal := SpellBaseFx.palette(ab)
	var mark := _wall_marks[0]
	mark.visible = true
	mark.global_position = Vector3(pos.x, 0.1, pos.z)
	GroundIndicator.set_circle_radius(mark, radius)
	GroundIndicator.tint_palette(mark.material_override, pal)


func _show_protection_wall(u: Unit, pos: Vector3, ab: AbilityDef) -> void:
	var center := Vector3(u.global_position.x, 0.09, u.global_position.z)
	var dir := SpellWallLayout.aim_dir(u.global_position, pos, u.facing_dir())
	var offsets := SpellWallLayout.protection_offsets(ab)
	_ensure_wall_marks(offsets.size())
	var pal := SpellBaseFx.palette(ab)
	var basis := SpellWallLayout.wall_basis(dir)
	var half := 0.28
	for i in offsets.size():
		var world := center + basis * offsets[i]
		var mark := _wall_marks[i]
		mark.visible = true
		mark.global_position = Vector3(world.x, 0.1, world.z)
		GroundIndicator.set_circle_radius(mark, half)
		GroundIndicator.tint_palette(mark.material_override, pal)


func _show_divine_wall(pos: Vector3, ab: AbilityDef) -> void:
	var rad := SpellWallLayout.divine_radius(ab)
	_aoe.visible = true
	_aoe.global_position = Vector3(pos.x, 0.09, pos.z)
	GroundIndicator.set_circle_radius(_aoe, rad)
	GroundIndicator.set_inner_hole(_aoe.material_override, 0.0, rad)
	_tint_aoe(ab)


func _show_nature_wall(pos: Vector3, ab: AbilityDef) -> void:
	var ring := SpellWallLayout.nature_radius(ab)
	var thick := SpellWallLayout.thickness_of(ab)
	var outer := ring + thick * 0.5
	_aoe.visible = true
	_aoe.global_position = Vector3(pos.x, 0.09, pos.z)
	GroundIndicator.set_circle_radius(_aoe, outer)
	GroundIndicator.set_inner_hole(_aoe.material_override, maxf(ring - thick * 0.5, 0.2), outer)
	_tint_aoe(ab)


func _show_lightning_wall(pos: Vector3, ab: AbilityDef) -> void:
	var pillar_r := SpellWallLayout.lightning_radius(ab)
	var reach := CombatBalance.flat("wall.lightning.range")
	if reach < 1.0:
		reach = 8.0
	_ensure_wall_marks(2)
	var pal := SpellBaseFx.palette(ab)
	var zone := _wall_marks[0]
	zone.visible = true
	zone.global_position = Vector3(pos.x, 0.09, pos.z)
	GroundIndicator.set_circle_radius(zone, reach)
	GroundIndicator.tint_palette(zone.material_override, pal)
	var pip := _wall_marks[1]
	pip.visible = true
	pip.global_position = Vector3(pos.x, 0.11, pos.z)
	GroundIndicator.set_circle_radius(pip, pillar_r)
	GroundIndicator.tint_palette(pip.material_override, pal)


func _show_ice_wall(pos: Vector3, dir: Vector3, ab: AbilityDef) -> void:
	var length := SpellWallLayout.length_of(ab)
	var thick := SpellWallLayout.thickness_of(ab)
	var zone_r := SpellWallLayout.ice_zone_radius(ab)
	_ensure_wall_marks(1)
	var pal := SpellBaseFx.palette(ab)
	var zone := _wall_marks[0]
	zone.visible = true
	zone.global_position = Vector3(pos.x, 0.09, pos.z)
	GroundIndicator.set_circle_radius(zone, zone_r)
	GroundIndicator.tint_palette(zone.material_override, pal)
	_shot.visible = true
	_shot.global_position = Vector3(pos.x, 0.11, pos.z)
	_shot.scale = Vector3(length, 1.0, thick)
	var look := _shot.global_position + dir
	if look.distance_squared_to(_shot.global_position) > 0.0001:
		_shot.look_at(look, Vector3.UP)
	GroundIndicator.tint_palette(_shot.material_override, pal)
	var sm := _shot.material_override as ShaderMaterial
	if sm:
		sm.set_shader_parameter("quad_size", Vector2(length, thick))


func _ensure_wall_marks(count: int) -> void:
	while _wall_marks.size() < count:
		_wall_marks.append(_make_circle(Color(0.45, 0.82, 1.0)))


func _hide_wall_marks() -> void:
	for mi in _wall_marks:
		if mi:
			mi.visible = false
			mi.scale = Vector3.ONE
			mi.rotation = Vector3.ZERO


func show_locked_aoe(_u: Unit, pos: Vector3, radius: float, color: Color, ab: AbilityDef = null) -> void:
	if _lock == null:
		return
	_lock.visible = true
	_lock.global_position = Vector3(pos.x, 0.08, pos.z)
	GroundIndicator.set_circle_radius(_lock, maxf(radius, 0.2))
	if ab != null:
		GroundIndicator.tint_palette(_lock.material_override, SpellBaseFx.palette(ab))
	else:
		GroundIndicator.tint_shader(_lock.material_override, color)


func hide_lock() -> void:
	if _lock:
		_lock.visible = false


func _tint_aoe(ab: AbilityDef) -> void:
	GroundIndicator.tint_palette(_aoe.material_override, SpellBaseFx.palette(ab))


func _apply_outline_width() -> void:
	var w := GroundIndicator.outline_width()
	var marks: Array[MeshInstance3D] = [_range, _shot, _aoe, _lock]
	marks.append_array(_wall_marks)
	for mi in marks:
		if mi == null:
			continue
		var sh := mi.material_override as ShaderMaterial
		if sh:
			sh.set_shader_parameter("outline_width", w)
	if _cone_line and _cone_line.visible and _cone_lengths.size() > 0:
		_cone_line.mesh = GroundIndicator.cone_outline_mesh(_cone_angle, _cone_lengths)
