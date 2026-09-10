class_name SpellVfxSlots
extends Object

## Mix-and-match VFX: one body per spell base, persist + impact per (infusion, base).
## First infusion may supply `{base}_body.tscn` to replace the base silhouette.
## Dual craft: first infusion keeps `fx_core`, second infusion supplies `fx_aura` when both
## have `{base}_body.tscn`. Both persist scenes still attach.
## Plug in a finished scene by dropping it on the convention path, or set an override below.
## Empty persist/impact means that slot is skipped.

const BASE_IDS: PackedStringArray = [
	"bolt", "missiles", "ground_aoe", "aoe_explosion", "aura", "ray",
	"meteor", "nova", "wall", "wave", "target",
]
const INFUSION_IDS: PackedStringArray = [
	"fire", "ice", "lightning", "shadow", "nature", "divine", "protection", "wind", "illusion",
]

## Travel-body placeholders until `assets/vfx/bases/{base}/body.tscn` exists.
const PLACEHOLDER_BODY := {
	"bolt": AbilityFx.MAGIC_BOLT,
	"missiles": AbilityFx.MAGIC_JAVELIN,
	"meteor": AbilityFx.FIRE_PROJECTILE,
	"wave": "",
}

## Optional explicit paths. Non-empty values win over convention files.
## Keys: base id for BODY, "{infusion}|{base}" for PERSIST / IMPACT.
const BODY := {}
const PERSIST := {}
const IMPACT := {}


static func apply(ab: AbilityDef, base: SpellBase, infusions: Array[SpellInfusion]) -> void:
	if ab == null or base == null:
		return
	ab.vfx_body = body_scene(base, infusions)
	ab.vfx_body_aura = aura_body_scene(base, infusions)
	ab.vfx_persist = overlay_layers(ab, base.id, infusions, "persist")
	ab.vfx_impact = overlay_layers(ab, base.id, infusions, "impact")
	ab.vfx_layers = []


static func body_scene(base: SpellBase, infusions: Array[SpellInfusion] = []) -> String:
	if base == null:
		return ""
	var overridden := String(BODY.get(base.id, ""))
	if not overridden.is_empty():
		return _require(overridden, "body " + base.id)
	if not infusions.is_empty() and infusions[0] != null:
		var inf_body := overlay_path(infusions[0].id, base.id, "body")
		if ResourceLoader.exists(inf_body):
			return inf_body
	var custom := body_path(base.id)
	if ResourceLoader.exists(custom):
		return custom
	return String(PLACEHOLDER_BODY.get(base.id, ""))


static func aura_body_scene(base: SpellBase, infusions: Array[SpellInfusion] = []) -> String:
	if base == null or infusions.size() < 2 or infusions[0] == null or infusions[1] == null:
		return ""
	var first := overlay_path(infusions[0].id, base.id, "body")
	var second := overlay_path(infusions[1].id, base.id, "body")
	if first == second:
		return ""
	if not ResourceLoader.exists(first) or not ResourceLoader.exists(second):
		return ""
	return second


static func overlay_layers(ab: AbilityDef, base_id: String, infusions: Array[SpellInfusion], slot: String) -> Array:
	var layers: Array = []
	for i in infusions.size():
		var inf: SpellInfusion = infusions[i]
		if inf == null:
			continue
		var path := overlay_scene(inf.id, base_id, slot)
		if path.is_empty():
			continue
		var scale := 1.0 if i == 0 else 0.65
		layers.append({
			"path": path,
			"scale": scale,
			"kind": inf.id,
			"primary_color": inf.vfx_primary,
			"secondary_color": inf.vfx_secondary,
			"tertiary_color": inf.vfx_tertiary,
			"yaw_offset": ab.vfx_yaw,
		})
	return layers


static func overlay_scene(infusion_id: String, base_id: String, slot: String) -> String:
	var key := "%s|%s" % [infusion_id, base_id]
	var table: Dictionary = PERSIST if slot == "persist" else IMPACT
	var overridden := String(table.get(key, ""))
	if not overridden.is_empty():
		return _require(overridden, "%s %s" % [slot, key])
	var custom := overlay_path(infusion_id, base_id, slot)
	if ResourceLoader.exists(custom):
		return custom
	return ""


static func body_path(base_id: String) -> String:
	return "res://assets/vfx/bases/%s/body.tscn" % base_id


static func overlay_path(infusion_id: String, base_id: String, slot: String) -> String:
	return "res://assets/vfx/infusions/%s/%s_%s.tscn" % [infusion_id, base_id, slot]


static func pool_paths() -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for base_id in BASE_IDS:
		_add_pool(out, seen, body_path(base_id))
		var placeholder := String(PLACEHOLDER_BODY.get(base_id, ""))
		_add_pool(out, seen, placeholder)
		var body_over := String(BODY.get(base_id, ""))
		_add_pool(out, seen, body_over)
		for inf_id in INFUSION_IDS:
			_add_pool(out, seen, overlay_path(inf_id, base_id, "body"))
			_add_pool(out, seen, overlay_path(inf_id, base_id, "persist"))
			_add_pool(out, seen, overlay_path(inf_id, base_id, "impact"))
			var key := "%s|%s" % [inf_id, base_id]
			_add_pool(out, seen, String(PERSIST.get(key, "")))
			_add_pool(out, seen, String(IMPACT.get(key, "")))
	return out


static func _add_pool(out: PackedStringArray, seen: Dictionary, path: String) -> void:
	if path.is_empty() or seen.has(path) or not ResourceLoader.exists(path):
		return
	seen[path] = true
	out.append(path)


static func _require(path: String, label: String) -> String:
	if ResourceLoader.exists(path):
		return path
	push_error("SpellVfxSlots missing %s: %s" % [label, path])
	return ""
