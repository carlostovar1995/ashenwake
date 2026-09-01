class_name SpellVfx
extends Object

const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")


static func attach_projectile(host: Node3D, cfg: Dictionary) -> bool:
	if host == null:
		return false
	var used := false
	var vfx_path := String(cfg.get("vfx_scene", ""))
	if AbilityFx.exists(vfx_path):
		if AbilityFx.attach(vfx_path, host, _base_cfg(cfg)):
			used = true
			if vfx_path == AbilityFx.FIRE_PROJECTILE or _layers_include(cfg, "fire"):
				_add_fire_trail(host, float(cfg.get("vfx_scale", 0.95)))
	for layer in _layers(cfg):
		var path := String(layer.get("path", ""))
		var kind := String(layer.get("kind", ""))
		if not path.is_empty() and path != vfx_path and AbilityFx.exists(path):
			if AbilityFx.attach(path, host, _layer_cfg(layer)):
				used = true
		if kind == "frost" or kind == "ice":
			_add_frost_trail(host, float(layer.get("scale", 0.7)))
			used = true
		elif kind == "storm" or kind == "lightning":
			_add_storm_sparks(host, float(layer.get("scale", 0.5)))
			used = true
		elif kind == "holy" or kind == "divine":
			_add_holy_glow(host, float(layer.get("scale", 0.5)))
			used = true
		elif kind == "shadow":
			_add_shadow_wisps(host, float(layer.get("scale", 0.6)))
			used = true
		elif kind == "nature":
			_add_nature_wisps(host, float(layer.get("scale", 0.55)))
			used = true
		elif kind == "protection":
			_add_ward_wisps(host, float(layer.get("scale", 0.55)))
			used = true
	var tint: Color = cfg.get("color", Color(0, 0, 0, 0))
	if tint.a <= 0.02:
		tint = cfg.get("vfx_primary", Color(0, 0, 0, 0))
	if tint.a > 0.02:
		SpellBaseFx.attach_core(host, tint, clampf(float(cfg.get("vfx_scale", 0.6)) * 0.16, 0.08, 0.2))
		used = true
	if not used:
		return false
	return true


static func play_impact(pos: Vector3, cfg: Dictionary) -> void:
	var layers := _layers(cfg)
	if layers.is_empty():
		return
	for layer in layers:
		var path := String(layer.get("path", ""))
		if path.is_empty() or not AbilityFx.exists(path):
			continue
		var impact := _layer_cfg(layer)
		impact["lifetime"] = 1.1
		impact["scale"] = float(layer.get("scale", 0.7)) * 0.65
		AbilityFx.play_at(path, pos, impact)


static func attach_to_node(host: Node3D, ab: AbilityDef, extra_scale: float = 1.0) -> void:
	if host == null or ab == null:
		return
	for layer in ab.vfx_layers:
		if not (layer is Dictionary):
			continue
		var path := String(layer.get("path", ""))
		if path.is_empty() or path == ab.vfx_scene or not AbilityFx.exists(path):
			continue
		var cfg := _layer_cfg(layer)
		cfg["scale"] = float(cfg.get("scale", 1.0)) * extra_scale
		AbilityFx.attach(path, host, cfg)


static func _base_cfg(cfg: Dictionary) -> Dictionary:
	var vcfg := {
		"scale": float(cfg.get("vfx_scale", 0.55)),
		"yaw_offset": float(cfg.get("vfx_yaw", 0.0)),
	}
	if cfg.has("vfx_primary") and (cfg["vfx_primary"] as Color).a > 0.0:
		vcfg["primary_color"] = cfg["vfx_primary"]
	if cfg.has("vfx_secondary") and (cfg["vfx_secondary"] as Color).a > 0.0:
		vcfg["secondary_color"] = cfg["vfx_secondary"]
	if cfg.has("vfx_tertiary") and (cfg["vfx_tertiary"] as Color).a > 0.0:
		vcfg["tertiary_color"] = cfg["vfx_tertiary"]
	return vcfg


static func _layer_cfg(layer: Dictionary) -> Dictionary:
	var cfg := {
		"scale": float(layer.get("scale", 0.7)),
		"yaw_offset": float(layer.get("yaw_offset", 0.0)),
	}
	if layer.has("primary_color"):
		cfg["primary_color"] = layer["primary_color"]
	if layer.has("secondary_color"):
		cfg["secondary_color"] = layer["secondary_color"]
	if layer.has("tertiary_color"):
		cfg["tertiary_color"] = layer["tertiary_color"]
	return cfg


static func _layers(cfg: Dictionary) -> Array:
	var raw = cfg.get("vfx_layers", [])
	if raw is Array:
		return raw
	return []


static func _layers_include(cfg: Dictionary, kind: String) -> bool:
	for layer in _layers(cfg):
		if layer is Dictionary and String(layer.get("kind", "")) == kind:
			return true
	return false


static func _add_fire_trail(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.2)
	host.add_child(_wisp_particles(
		28, 0.28, Vector3(0.0, 0.0, 0.45 * s), Vector2(0.16, 0.55) * s,
		Color(1.0, 0.48, 0.12, 0.88), Color(1.0, 0.5, 0.12, 0.9),
		Vector3(0.08, 0.08, 0.18) * s, Vector3(0.0, 0.15, 1.0), 18.0, 1.2 * s, 3.4 * s
	))


static func _add_frost_trail(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		22, 0.34, Vector3(0.0, 0.05, 0.2 * s), Vector2(0.14, 0.42) * s,
		Color(0.72, 0.94, 1.0, 0.82), Color(0.55, 0.86, 1.0, 0.85),
		Vector3(0.1, 0.1, 0.16) * s, Vector3(0.0, 0.25, 0.8), 24.0, 0.8 * s, 2.2 * s
	))


static func _add_storm_sparks(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		18, 0.18, Vector3.ZERO, Vector2(0.1, 0.32) * s,
		Color(0.85, 0.92, 1.0, 0.9), Color(1.0, 0.95, 0.55, 0.85),
		Vector3(0.12, 0.12, 0.12) * s, Vector3(0.0, 0.6, 0.2), 50.0, 2.0 * s, 5.0 * s
	))


static func _add_shadow_wisps(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		20, 0.36, Vector3(0.0, 0.02, 0.12 * s), Vector2(0.16, 0.4) * s,
		Color(0.55, 0.22, 0.78, 0.82), Color(0.28, 0.08, 0.42, 0.8),
		Vector3(0.1, 0.1, 0.16) * s, Vector3(0.0, 0.35, 0.6), 16.0, 0.6 * s, 1.8 * s
	))


static func _add_nature_wisps(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		18, 0.4, Vector3(0.0, 0.04, 0.08 * s), Vector2(0.16, 0.32) * s,
		Color(0.55, 1.0, 0.48, 0.8), Color(0.28, 0.72, 0.32, 0.75),
		Vector3(0.1, 0.12, 0.12) * s, Vector3(0.0, 0.7, 0.15), 14.0, 0.45 * s, 1.4 * s
	))


static func _add_ward_wisps(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		14, 0.42, Vector3(0.0, 0.05, 0.0), Vector2(0.18, 0.2) * s,
		Color(0.82, 0.9, 1.0, 0.78), Color(0.55, 0.7, 0.98, 0.7),
		Vector3(0.1, 0.1, 0.1) * s, Vector3(0.0, 0.85, 0.0), 10.0, 0.35 * s, 1.1 * s
	))


static func _add_holy_glow(host: Node3D, vfx_scale: float) -> void:
	var s := maxf(vfx_scale, 0.25)
	host.add_child(_wisp_particles(
		16, 0.4, Vector3(0.0, 0.04, 0.0), Vector2(0.18, 0.18) * s,
		Color(1.0, 0.94, 0.55, 0.8), Color(1.0, 0.88, 0.4, 0.75),
		Vector3(0.08, 0.08, 0.08) * s, Vector3(0.0, 0.8, 0.0), 12.0, 0.4 * s, 1.2 * s
	))


static func _wisp_particles(
	amount: int,
	lifetime: float,
	pos: Vector3,
	mesh_size: Vector2,
	shader_color: Color,
	process_color: Color,
	emit_scale: Vector3,
	dir: Vector3,
	spread: float,
	vmin: float,
	vmax: float
) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = pos
	var mesh := QuadMesh.new()
	mesh.size = mesh_size
	p.draw_pass_1 = mesh
	var smat := ShaderMaterial.new()
	smat.shader = _WISP_SHADER
	smat.set_shader_parameter("color", shader_color)
	p.material_override = smat
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_shape_scale = emit_scale
	pp.direction = dir
	pp.spread = spread
	pp.initial_velocity_min = vmin
	pp.initial_velocity_max = vmax
	pp.gravity = Vector3(0.0, 0.35, 0.0)
	pp.damping_min = 0.8
	pp.damping_max = 2.0
	pp.scale_min = 0.65
	pp.scale_max = 1.25
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	pp.scale_curve = tex
	pp.color = process_color
	p.process_material = pp
	return p
