class_name TalentSpend
extends RefCounted

signal changed

const STARTING_POINTS := 50
const SPEC_SLOTS := 2

var class_id: String = "kindling"
var spec_ids: PackedStringArray = PackedStringArray(["kindling", ""])
var ranks: Dictionary = {}
var slot_d: String = ""
var slot_f: String = ""


func points_spent() -> int:
	var total := 0
	for key in ranks.keys():
		total += maxi(int(ranks[key]), 0)
	return total


func points_left() -> int:
	return maxi(STARTING_POINTS - points_spent(), 0)


func rank_of(talent_id: String) -> int:
	return maxi(int(ranks.get(talent_id, 0)), 0)


func spec_id_at(index: int) -> String:
	if index < 0 or index >= spec_ids.size():
		return ""
	return spec_ids[index]


func set_spec_slot(index: int, spec_id: String) -> void:
	if index < 0 or index >= SPEC_SLOTS:
		return
	while spec_ids.size() < SPEC_SLOTS:
		spec_ids.append("")
	var want := spec_id.strip_edges()
	if want == spec_ids[index]:
		return
	if not want.is_empty():
		for i in SPEC_SLOTS:
			if i != index and spec_ids[i] == want:
				_clear_spec_ranks(spec_ids[i])
				spec_ids[i] = ""
		if ClassCatalog.def_for(want) == null:
			return
	_clear_spec_ranks(spec_ids[index])
	spec_ids[index] = want
	_sync_class_id()
	_clamp_to_catalog()
	sanitize_binds()
	_emit()


func slotted_specs() -> Array[ClassDef]:
	var out: Array[ClassDef] = []
	for i in SPEC_SLOTS:
		var id := spec_id_at(i)
		if id.is_empty():
			continue
		var spec := ClassCatalog.def_for(id)
		if spec != null:
			out.append(spec)
	return out


func can_invest(talent_id: String) -> bool:
	if points_left() < 1:
		return false
	var def := _talent(talent_id)
	if def == null:
		return false
	if rank_of(talent_id) >= def.max_rank:
		return false
	if not _spec_owns(talent_id):
		return false
	if def.melee_auto and _other_melee_invested(talent_id):
		return false
	if def.type == TalentDef.TYPE_AUTO and _other_auto_in_row_invested(talent_id):
		return false
	return _row_unlocked(talent_id)


func invest(talent_id: String) -> bool:
	if not can_invest(talent_id):
		return false
	ranks[talent_id] = rank_of(talent_id) + 1
	sanitize_binds()
	_emit()
	return true


func can_refund(talent_id: String) -> bool:
	if rank_of(talent_id) <= 0:
		return false
	var previous := rank_of(talent_id)
	if previous <= 1:
		ranks.erase(talent_id)
	else:
		ranks[talent_id] = previous - 1
	var ok := _invested_rows_unlocked()
	if previous <= 1:
		ranks[talent_id] = previous
	else:
		ranks[talent_id] = previous
	return ok


func refund(talent_id: String) -> bool:
	if not can_refund(talent_id):
		return false
	var next_rank := rank_of(talent_id) - 1
	if next_rank <= 0:
		ranks.erase(talent_id)
	else:
		ranks[talent_id] = next_rank
	sanitize_binds()
	_emit()
	return true


func reset_tree(tree_id: String) -> void:
	for spec in slotted_specs():
		var tree := spec.tree_named(tree_id) if spec != null else null
		if tree == null:
			continue
		for talent in tree.talents:
			ranks.erase(talent.id)
	sanitize_binds()
	_emit()


func reset_all() -> void:
	ranks.clear()
	slot_d = ""
	slot_f = ""
	_emit()


func set_class_id(next_id: String) -> void:
	set_spec_slot(0, next_id if not next_id.is_empty() else ClassCatalog.default_class_id())


func is_unlocked(talent_id: String) -> bool:
	return rank_of(talent_id) > 0


func unlocked_skill_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for spec in slotted_specs():
		for talent in spec.all_skills():
			if rank_of(talent.id) > 0 and not talent.skill_id.is_empty() and not out.has(talent.skill_id):
				out.append(talent.skill_id)
	return out


func set_slot_d(skill_id: String) -> bool:
	return _set_slot(true, skill_id)


func set_slot_f(skill_id: String) -> bool:
	return _set_slot(false, skill_id)


func sanitize_binds() -> void:
	var pool := unlocked_skill_ids()
	if not slot_d.is_empty() and not pool.has(slot_d):
		slot_d = ""
	if not slot_f.is_empty() and not pool.has(slot_f):
		slot_f = ""
	if not slot_d.is_empty() and slot_d == slot_f:
		slot_f = ""
	for skill_id in pool:
		if skill_id == slot_d or skill_id == slot_f:
			continue
		if slot_d.is_empty():
			slot_d = skill_id
		elif slot_f.is_empty():
			slot_f = skill_id
		else:
			break


func swap_binds() -> void:
	var tmp := slot_d
	slot_d = slot_f
	slot_f = tmp
	sanitize_binds()
	_emit()


func to_dict() -> Dictionary:
	var rank_data := {}
	for key in ranks.keys():
		rank_data[String(key)] = int(ranks[key])
	var specs: Array = []
	for i in SPEC_SLOTS:
		specs.append(spec_id_at(i))
	return {
		"class_id": class_id,
		"spec_ids": specs,
		"ranks": rank_data,
		"slot_d": slot_d,
		"slot_f": slot_f,
	}


static func from_dict(data: Dictionary) -> TalentSpend:
	var spend := TalentSpend.new()
	if data.is_empty():
		return spend
	var specs = data.get("spec_ids", null)
	var old_class := String(data.get("class_id", ""))
	if specs is Array and not specs.is_empty():
		spend.spec_ids = PackedStringArray()
		for i in SPEC_SLOTS:
			spend.spec_ids.append("")
		for i in mini(SPEC_SLOTS, specs.size()):
			spend.spec_ids[i] = String(specs[i])
	elif old_class == "fire_mage" or old_class == "bulwark" or old_class == "storm_druid":
		spend.spec_ids = PackedStringArray(["kindling", ""])
		spend.ranks.clear()
		spend._sync_class_id()
		return spend
	elif not old_class.is_empty():
		spend.spec_ids = PackedStringArray([old_class, ""])
	var raw = data.get("ranks", {})
	if raw is Dictionary:
		for key in raw.keys():
			var talent_id := String(key)
			var amount := int(raw[key])
			if talent_id.is_empty() or amount <= 0:
				continue
			spend.ranks[talent_id] = amount
	spend.slot_d = String(data.get("slot_d", ""))
	spend.slot_f = String(data.get("slot_f", ""))
	spend._sync_class_id()
	spend._clamp_to_catalog()
	spend.sanitize_binds()
	return spend


func _clear_spec_ranks(spec_id: String) -> void:
	var spec := ClassCatalog.def_for(spec_id) if not spec_id.is_empty() else null
	if spec == null:
		return
	for tree in spec.trees:
		for talent in tree.talents:
			ranks.erase(talent.id)


func _sync_class_id() -> void:
	for i in SPEC_SLOTS:
		if not spec_id_at(i).is_empty():
			class_id = spec_ids[i]
			return
	class_id = ClassCatalog.default_class_id()


func _clamp_to_catalog() -> void:
	if spec_ids.size() > SPEC_SLOTS:
		for i in range(SPEC_SLOTS, spec_ids.size()):
			_clear_spec_ranks(spec_ids[i])
		spec_ids.resize(SPEC_SLOTS)
	while spec_ids.size() < SPEC_SLOTS:
		spec_ids.append("")
	for i in SPEC_SLOTS:
		if spec_ids[i].is_empty():
			continue
		if ClassCatalog.def_for(spec_ids[i]) == null:
			spec_ids[i] = ""
	_sync_class_id()
	var keep := {}
	for key in ranks.keys():
		var talent_id := String(key)
		var def := _talent(talent_id)
		if def == null or not _spec_owns(talent_id):
			continue
		keep[talent_id] = clampi(int(ranks[key]), 0, def.max_rank)
	ranks = keep
	_sanitize_sequence()
	if points_spent() > STARTING_POINTS:
		reset_all()


func _sanitize_sequence() -> void:
	var dirty := true
	while dirty:
		dirty = false
		for spec in slotted_specs():
			for tree in spec.trees:
				if tree == null or not tree.choice_tree:
					continue
				for row in range(tree.row_count() - 1, -1, -1):
					if _tree_row_unlocked(tree, row):
						continue
					for talent in tree.talents_in_row(row):
						if rank_of(talent.id) > 0:
							ranks.erase(talent.id)
							dirty = true


func _set_slot(is_d: bool, skill_id: String) -> bool:
	var want := String(skill_id)
	if not want.is_empty() and not unlocked_skill_ids().has(want):
		return false
	if is_d:
		if want == slot_f and not want.is_empty():
			slot_f = ""
		slot_d = want
	else:
		if want == slot_d and not want.is_empty():
			slot_d = ""
		slot_f = want
	_emit()
	return true


func _row_unlocked(talent_id: String) -> bool:
	var tree := _tree_for(talent_id)
	if tree == null:
		return false
	var def := tree.talent_at(tree.index_of(talent_id))
	if def == null:
		return false
	return _tree_row_unlocked(tree, def.row)


func _tree_row_unlocked(tree: TalentTreeDef, row: int) -> bool:
	if tree == null or row <= 0:
		return true
	return _points_before_row(tree, row) >= tree.unlock_cost(row)


func _points_before_row(tree: TalentTreeDef, row: int) -> int:
	var total := 0
	for talent in tree.talents:
		if talent != null and talent.row < row:
			total += rank_of(talent.id)
	return total


func points_in_tree(tree: TalentTreeDef) -> int:
	if tree == null:
		return 0
	var total := 0
	for talent in tree.talents:
		total += rank_of(talent.id)
	return total


func _invested_rows_unlocked() -> bool:
	for spec in slotted_specs():
		for tree in spec.trees:
			if tree == null:
				continue
			for talent in tree.talents:
				if rank_of(talent.id) > 0 and not _tree_row_unlocked(tree, talent.row):
					return false
	return true


func _other_auto_in_row_invested(talent_id: String) -> bool:
	var tree := _tree_for(talent_id)
	if tree == null:
		return false
	var def := tree.talent_at(tree.index_of(talent_id))
	if def == null:
		return false
	for talent in tree.auto_options_in_row(def.row):
		if talent.id != talent_id and rank_of(talent.id) > 0:
			return true
	return false


func _other_melee_invested(except_id: String) -> bool:
	for spec in slotted_specs():
		for tree in spec.trees:
			for talent in tree.talents:
				if talent.melee_auto and talent.id != except_id and rank_of(talent.id) > 0:
					return true
	return false


func _spec_owns(talent_id: String) -> bool:
	for spec in slotted_specs():
		if spec.talent(talent_id) != null:
			return true
	return false


func _talent(talent_id: String) -> TalentDef:
	var owned := ClassCatalog.find_talent(talent_id)
	if owned != null and _spec_owns(talent_id):
		return owned
	return owned if _spec_owns(talent_id) else null


func _tree_for(talent_id: String) -> TalentTreeDef:
	for spec in slotted_specs():
		var tree := spec.tree_for_talent(talent_id)
		if tree != null:
			return tree
	return null


func _emit() -> void:
	changed.emit()
