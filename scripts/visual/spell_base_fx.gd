class_name SpellBaseFx
extends Object


static func colors(ab: AbilityDef) -> Dictionary:
	return palette(ab)


static func palette(ab: AbilityDef) -> Dictionary:
	var core := Color(0.75, 0.84, 1.0)
	var rim := Color(0.95, 0.97, 1.0)
	if ab == null:
		return {"core": core, "rim": rim, "primary": core, "secondary": rim}
	var first := _infusion_swatch(ab, 0)
	var second := _infusion_swatch(ab, 1)
	if first.a > 0.02:
		core = first
	elif ab.vfx_primary.a > 0.02:
		core = ab.vfx_primary
	elif ab.color.a > 0.02:
		core = ab.color
	if second.a > 0.02:
		rim = second
	elif ab.vfx_secondary.a > 0.02:
		rim = ab.vfx_secondary
	else:
		rim = core.lightened(0.28)
	var third := _infusion_swatch(ab, 2)
	if third.a > 0.02:
		rim = rim.lerp(third, 0.35)
	return {"core": core, "rim": rim, "primary": core, "secondary": rim}


static func _infusion_swatch(ab: AbilityDef, index: int) -> Color:
	if ab == null or index < 0 or index >= ab.infusion_ids.size():
		return Color(0, 0, 0, 0)
	var inf := SpellCatalog.get_infusion(ab.infusion_ids[index])
	if inf == null:
		return Color(0, 0, 0, 0)
	if inf.color.a > 0.02:
		return inf.color
	if inf.vfx_primary.a > 0.02:
		return inf.vfx_primary
	return Color(0, 0, 0, 0)


static func burst(point: Vector3, radius: float, ab: AbilityDef) -> void:
	var pal := palette(ab)
	var rad := maxf(radius, 0.8)
	_ring(point, rad, pal.core, pal.rim, 0.28)
	_flash(point + Vector3(0.0, 0.35, 0.0), pal.core, pal.rim, rad * 0.28, 0.32)
	FxHeroLights.pulse(point + Vector3(0.0, 0.7, 0.0), pal.core.lerp(pal.rim, 0.35), 3.4, rad * 1.8, 0.35)


static func nova(point: Vector3, radius: float, ab: AbilityDef) -> void:
	var pal := palette(ab)
	_ring(point, maxf(radius, 1.2), pal.core, pal.rim, 0.4)
	_flash(point + Vector3(0.0, 0.45, 0.0), pal.core, pal.rim, 0.42, 0.24)


static func wave(host: Node3D, radius: float, color: Color, life: float = 0.55, rim: Color = Color(0, 0, 0, 0), inner: float = 0.0) -> void:
	if host == null or not is_instance_valid(host):
		return
	var fx := MeshInstance3D.new()
	fx.mesh = GroundIndicator.circle_mesh()
	var mat := GroundIndicator.zone_mat(color, 0.25, 0.0, 0.42)
	GroundIndicator.set_rim(mat, rim if rim.a > 0.02 else color)
	mat.set_shader_parameter("outline_width", 0.038)
	mat.set_shader_parameter("emission_strength", 0.4)
	fx.material_override = mat
	GroundIndicator.prepare(fx)
	host.add_child(fx)
	fx.position = Vector3(0.0, 0.02, 0.0)
	var start := maxf(inner, 0.25)
	fx.scale = Vector3(start, 1.0, start)
	var tw := fx.create_tween()
	tw.tween_method(func(s: float) -> void:
		if not is_instance_valid(fx):
			return
		fx.scale = Vector3(s, 1.0, s)
		if is_instance_valid(mat):
			mat.set_shader_parameter("quad_size", Vector2(s, s))
	, start, maxf(radius, 0.4), life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(a: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("outline_alpha", a * 0.42)
			mat.set_shader_parameter("fill_alpha", 0.0 if inner > 0.05 else a * 0.018)
	, 1.0, 0.0, life)
	tw.tween_callback(fx.queue_free)


static func shield_bubble(target: Node3D, ab: AbilityDef, life: float = 0.55) -> void:
	if target == null or not is_instance_valid(target):
		return
	var pal := colors(ab)
	var height := float(target.get("height")) if "height" in target else 1.8
	var radius := maxf(float(target.get("radius")) if "radius" in target else 0.45, 0.4) + 0.28
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.15
	fx.mesh = sphere
	var mat := _emis(pal.primary, 0.28, 1.6)
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	target.add_child(fx)
	fx.position = Vector3(0.0, height * 0.45, 0.0)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3(1.18, 1.22, 1.18), life)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(fx.queue_free)


static func cast_pop(point: Vector3, ab: AbilityDef) -> void:
	var pal := colors(ab)
	_flash(point, pal.primary, pal.secondary, 0.38, 0.22)


static func attach_core(host: Node3D, tint: Color, size: float = 0.14) -> void:
	if host == null:
		return
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	core.mesh = sm
	var mat := _emis(tint, 0.95, 3.4)
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(core)


static func _flash(point: Vector3, primary: Color, secondary: Color, size: float, life: float) -> void:
	var parent := _parent()
	if parent == null:
		return
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	fx.mesh = sphere
	var mat := _emis(primary.lerp(secondary, 0.35), 0.7, 2.8)
	fx.material_override = mat
	fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fx)
	fx.global_position = point
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 1.85, life)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(fx.queue_free)


static func _ring(point: Vector3, radius: float, color: Color, rim: Color, life: float) -> void:
	var parent := _parent()
	if parent == null:
		return
	var fx := MeshInstance3D.new()
	fx.mesh = GroundIndicator.circle_mesh()
	var mat := GroundIndicator.shader_mat(color, true)
	GroundIndicator.set_rim(mat, rim)
	fx.material_override = mat
	GroundIndicator.prepare(fx)
	parent.add_child(fx)
	fx.global_position = Vector3(point.x, 0.08, point.z)
	fx.scale = Vector3(0.35, 1.0, 0.35)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3(radius, 1.0, radius), life)
	tw.parallel().tween_method(func(a: float) -> void:
		if is_instance_valid(mat):
			mat.set_shader_parameter("fill_alpha", a * 0.22)
			mat.set_shader_parameter("outline_alpha", a)
	, 1.0, 0.0, life)
	tw.tween_callback(fx.queue_free)


static func _emis(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy * 1.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	return mat


static func _parent() -> Node:
	if ArenaState.arena:
		return ArenaState.arena
	var loop := Engine.get_main_loop()
	return loop.root if loop else null
