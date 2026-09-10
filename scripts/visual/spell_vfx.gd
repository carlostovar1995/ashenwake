class_name SpellVfx
extends Object

## Bind travel VFX to a projectile or falling rock. Call `AbilityFx.finish(host)`
## before freeing the host so persist particles can fade on FxRoot.
const GROUP_CORE := "fx_core"
const GROUP_AURA := "fx_aura"


static func attach_projectile(host: Node3D, cfg: Dictionary) -> bool:
	if host == null:
		return false
	var used := false
	var body := _body_path(cfg)
	var aura := String(cfg.get("vfx_body_aura", ""))
	var mixing := AbilityFx.exists(aura) and aura != body
	if AbilityFx.exists(body):
		var core_fx := AbilityFx.attach(body, host, _base_cfg(cfg))
		if core_fx:
			used = true
			if mixing:
				_keep_body_role(core_fx, GROUP_CORE)
	if mixing:
		var aura_cfg := _base_cfg(cfg)
		aura_cfg["bind_light"] = false
		aura_cfg.erase("primary_color")
		aura_cfg.erase("secondary_color")
		aura_cfg.erase("tertiary_color")
		var aura_fx := AbilityFx.attach(aura, host, aura_cfg)
		if aura_fx:
			used = true
			_keep_body_role(aura_fx, GROUP_AURA)
	if attach_persist_cfg(host, cfg):
		used = true
	return used


static func attach_persist(host: Node3D, ab: AbilityDef, extra_scale: float = 1.0) -> bool:
	if host == null or ab == null:
		return false
	return _attach_layers(host, ab.vfx_persist, extra_scale)


static func attach_persist_cfg(host: Node3D, cfg: Dictionary) -> bool:
	return _attach_layers(host, _persist(cfg), 1.0)


static func attach_to_node(host: Node3D, ab: AbilityDef, extra_scale: float = 1.0) -> void:
	attach_persist(host, ab, extra_scale)


static func play_impact(pos: Vector3, cfg: Dictionary) -> bool:
	return _play_layers(pos, _impact(cfg), cfg)


static func play_ability_impact(ab: AbilityDef, pos: Vector3) -> bool:
	if ab == null:
		return false
	return _play_layers(pos, ab.vfx_impact, ab.vfx_cfg())


static func play_point(ab: AbilityDef, pos: Vector3, look: Vector3 = Vector3.ZERO) -> bool:
	if ab == null:
		return false
	if play_ability_impact(ab, pos):
		return true
	if ab.vfx_scene.is_empty():
		return false
	var cfg := ab.vfx_cfg()
	if look.length_squared() > 0.0001:
		cfg["look"] = look
	return AbilityFx.play_at(ab.vfx_scene, pos, cfg) != null


static func _keep_body_role(fx: Node, keep_group: String) -> void:
	if fx == null:
		return
	if fx is OmniLight3D:
		if keep_group == GROUP_AURA:
			(fx as Node3D).visible = false
	elif fx is GeometryInstance3D:
		var mesh := fx as Node3D
		if keep_group == GROUP_CORE:
			if fx.is_in_group(GROUP_AURA) and not fx.is_in_group(GROUP_CORE):
				mesh.visible = false
		elif not fx.is_in_group(GROUP_AURA):
			mesh.visible = false
	for child in fx.get_children():
		_keep_body_role(child, keep_group)


static func _body_path(cfg: Dictionary) -> String:
	var body := String(cfg.get("vfx_body", ""))
	if not body.is_empty():
		return body
	return String(cfg.get("vfx_scene", ""))


static func _attach_layers(host: Node3D, layers: Array, extra_scale: float) -> bool:
	if host == null or layers.is_empty():
		return false
	var used := false
	for layer in layers:
		if not (layer is Dictionary):
			continue
		var path := String(layer.get("path", ""))
		if path.is_empty() or not AbilityFx.exists(path):
			continue
		var cfg := _layer_cfg(layer)
		cfg["scale"] = float(cfg.get("scale", 1.0)) * extra_scale
		cfg["bind_light"] = false
		if AbilityFx.attach(path, host, cfg):
			used = true
	return used


static func _play_layers(pos: Vector3, layers: Array, tint_cfg: Dictionary) -> bool:
	if layers.is_empty():
		return false
	var played := false
	for layer in layers:
		if not (layer is Dictionary):
			continue
		var path := String(layer.get("path", ""))
		if path.is_empty() or not AbilityFx.exists(path):
			continue
		var impact := _layer_cfg(layer)
		if tint_cfg.has("primary_color") and not impact.has("primary_color"):
			impact["primary_color"] = tint_cfg["primary_color"]
		impact["lifetime"] = 1.1
		impact["scale"] = float(layer.get("scale", 0.7)) * 0.65
		if AbilityFx.play_at(path, pos, impact):
			played = true
	return played


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


static func _persist(cfg: Dictionary) -> Array:
	var raw = cfg.get("vfx_persist", cfg.get("vfx_layers", []))
	if raw is Array:
		return raw
	return []


static func _impact(cfg: Dictionary) -> Array:
	var raw = cfg.get("vfx_impact", [])
	if raw is Array:
		return raw
	return []
