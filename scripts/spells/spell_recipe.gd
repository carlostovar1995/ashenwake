class_name SpellRecipe
extends RefCounted

const DEFAULT_INFUSIONS := 2
const MAX_INFUSIONS := 3
const MAX_AUGMENTS := 3
const OVERFLOW_ID := "overflow"

var base_id: String = "bolt"
var infusion_ids: PackedStringArray = PackedStringArray()
var augment_ids: PackedStringArray = PackedStringArray()


static func make(p_base: String, p_infusions: PackedStringArray = PackedStringArray(), p_augments: PackedStringArray = PackedStringArray()) -> SpellRecipe:
	var r := SpellRecipe.new()
	r.base_id = p_base
	r.augment_ids = _capped(p_augments, MAX_AUGMENTS)
	r.normalize()
	r.infusion_ids = _capped(p_infusions, r.infusion_cap())
	return r


func duplicate_recipe() -> SpellRecipe:
	return make(base_id, infusion_ids, augment_ids)


func to_dict() -> Dictionary:
	return {
		"base": base_id,
		"infusions": Array(infusion_ids),
		"augments": Array(augment_ids),
	}


static func from_dict(data: Dictionary) -> SpellRecipe:
	var inf := PackedStringArray()
	for id in data.get("infusions", []):
		inf.append(String(id))
	var augs := PackedStringArray()
	for id in data.get("augments", []):
		augs.append(String(id))
	var base := String(data.get("base", data.get("base_id", "bolt")))
	return make(base, inf, augs)


func same_as(other: SpellRecipe) -> bool:
	if other == null:
		return false
	return base_id == other.base_id and infusion_ids == other.infusion_ids and augment_ids == other.augment_ids


func set_infusion(slot: int, infusion_id: String) -> void:
	var current := infusion_ids[slot] if slot >= 0 and slot < infusion_ids.size() else ""
	if not infusion_id.is_empty() and current == infusion_id:
		infusion_id = ""
	infusion_ids = _write_slot(infusion_ids, slot, infusion_id, infusion_cap())


func set_augment(slot: int, augment_id: String) -> void:
	augment_ids = _write_slot(augment_ids, slot, augment_id, MAX_AUGMENTS)
	normalize()


func toggle_infusion(infusion_id: String) -> void:
	infusion_ids = _toggle(infusion_ids, infusion_id, infusion_cap())


func toggle_augment(augment_id: String) -> void:
	if augment_id.is_empty():
		return
	if augment_id == OVERFLOW_ID:
		if has_overflow():
			augment_ids = PackedStringArray()
		else:
			augment_ids = PackedStringArray([OVERFLOW_ID])
		normalize()
		return
	if has_overflow():
		augment_ids = PackedStringArray([augment_id])
		normalize()
		return
	augment_ids = _toggle(augment_ids, augment_id, MAX_AUGMENTS)
	normalize()


func has_infusion(infusion_id: String) -> bool:
	return infusion_ids.has(infusion_id)


func has_augment(augment_id: String) -> bool:
	return augment_ids.has(augment_id)


func has_overflow() -> bool:
	return has_augment(OVERFLOW_ID)


func infusion_cap() -> int:
	var base := SpellCatalog.get_base(base_id)
	var cap := DEFAULT_INFUSIONS
	if base != null and base.max_infusions > 0:
		cap = base.max_infusions
	if has_overflow() and cap >= DEFAULT_INFUSIONS:
		return MAX_INFUSIONS
	return cap


func normalize() -> void:
	augment_ids = _normalized_augments(augment_ids)
	augment_ids = _fits_base(base_id, augment_ids)
	infusion_ids = _capped(infusion_ids, infusion_cap())


static func _fits_base(base_id: String, ids: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for id in ids:
		if SpellCatalog.augment_fits(base_id, id):
			out.append(id)
	return out


static func _normalized_augments(ids: PackedStringArray) -> PackedStringArray:
	var out := _capped(ids, MAX_AUGMENTS)
	if out.has(OVERFLOW_ID):
		return PackedStringArray([OVERFLOW_ID])
	return out


static func _capped(ids: PackedStringArray, cap: int) -> PackedStringArray:
	var out := PackedStringArray()
	var seen: Dictionary = {}
	for raw in ids:
		var id := String(raw).strip_edges()
		if id.is_empty() or seen.has(id) or out.size() >= cap:
			continue
		seen[id] = true
		out.append(id)
	return out


static func _write_slot(ids: PackedStringArray, slot: int, value: String, cap: int) -> PackedStringArray:
	var next: Array[String] = []
	for id in ids:
		next.append(id)
	while next.size() < cap:
		next.append("")
	if slot < 0 or slot >= cap:
		return _capped(PackedStringArray(next), cap)
	next[slot] = value
	return _capped(PackedStringArray(next), cap)


static func _toggle(ids: PackedStringArray, value: String, cap: int) -> PackedStringArray:
	if value.is_empty():
		return ids
	var next := PackedStringArray()
	var removed := false
	for id in ids:
		if id == value and not removed:
			removed = true
			continue
		next.append(id)
	if not removed and next.size() < cap:
		next.append(value)
	return _capped(next, cap)
