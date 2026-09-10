class_name TalentValidator
extends Object


static func validate(class_def: ClassDef) -> PackedStringArray:
	var errors := PackedStringArray()
	if class_def == null:
		errors.append("ClassDef is null")
		return errors
	if class_def.id.is_empty():
		errors.append("Class id is empty")
	if class_def.trees.size() != 1:
		errors.append("%s expected 1 spec tree, got %d" % [class_def.id, class_def.trees.size()])
		return errors
	var tree: TalentTreeDef = class_def.trees[0]
	if tree == null or not tree.choice_tree:
		errors.append("%s tree must be a tier spec" % class_def.id)
		return errors
	var seen: Dictionary = {}
	_validate_tier_tree(class_def.id, tree, seen, errors)
	return errors


static func _validate_tier_tree(class_id: String, tree: TalentTreeDef, seen: Dictionary, errors: PackedStringArray) -> void:
	if tree.talents.is_empty():
		errors.append("%s/%s has no talents" % [class_id, tree.id])
		return
	var rows := tree.row_count()
	if rows < 2:
		errors.append("%s has too few rows" % tree.id)
		return
	var auto_rows := 0
	var max3_plus := 0
	var left_inter := 0
	var right_inter := 0
	var left_pct := 0
	var right_pct := 0
	for row in rows:
		var pair := tree.talents_in_row(row)
		if pair.is_empty():
			errors.append("%s missing row %d" % [tree.id, row])
			continue
		var last := row == rows - 1
		if last:
			if pair.size() != 1 or pair[0].type != TalentDef.TYPE_ULTIMATE:
				errors.append("%s last row must be a shared ultimate" % tree.id)
			elif pair[0].max_rank != 1:
				errors.append("%s ultimate must cost 1" % pair[0].id)
			elif pair[0].skill_id.is_empty():
				errors.append("%s ultimate missing skill_id" % pair[0].id)
			var ult_need := (rows - 1) * TalentTreeDef.TIER_STEP
			if tree.unlock_cost(row) != ult_need:
				errors.append("%s ultimate must unlock at %d points in this spec" % [tree.id, ult_need])
			_mark_seen(pair[0], seen, errors)
			continue
		if pair.size() < 2:
			errors.append("%s row %d must have at least two talents" % [tree.id, row])
			continue
		var autos := 0
		var earlier_here := 0
		for talent in pair:
			_mark_seen(talent, seen, errors)
			if talent.per_point.size() != talent.max_rank:
				errors.append("%s expected %d per-point lines, got %d" % [talent.id, talent.max_rank, talent.per_point.size()])
			earlier_here += talent.max_rank
			if talent.max_rank >= 3:
				max3_plus += 1
			if talent.type == TalentDef.TYPE_AUTO:
				autos += 1
				if talent.max_rank != 1:
					errors.append("%s auto must be max 1" % talent.id)
			elif talent.type == TalentDef.TYPE_INTERACTION:
				if talent.side == TalentDef.SIDE_LEFT:
					left_inter += 1
				elif talent.side == TalentDef.SIDE_RIGHT:
					right_inter += 1
			elif talent.type == TalentDef.TYPE_PASSIVE:
				if talent.side == TalentDef.SIDE_LEFT:
					left_pct += 1
				elif talent.side == TalentDef.SIDE_RIGHT:
					right_pct += 1
		if autos > 0:
			if autos != 2:
				errors.append("%s row %d auto row must have exactly two auto options" % [tree.id, row])
			auto_rows += 1
		var need := tree.unlock_cost(row + 1) if row + 1 < rows else 0
		if need > 0:
			var available := 0
			for prior in range(0, row + 1):
				for talent in tree.talents_in_row(prior):
					if talent.type == TalentDef.TYPE_AUTO:
						available += 1
					else:
						available += talent.max_rank
			if available < need:
				errors.append("%s rows 0-%d offer %d ranks, need %d to unlock the next tier" % [tree.id, row, available, need])
	if auto_rows != 1:
		errors.append("%s needs exactly one auto row, has %d" % [tree.id, auto_rows])
	if max3_plus < 2:
		errors.append("%s needs at least two max-3+ talents" % tree.id)
	if left_inter < 3:
		errors.append("%s left column has %d interactions, need 3" % [tree.id, left_inter])
	if right_inter < 3:
		errors.append("%s right column has %d interactions, need 3" % [tree.id, right_inter])
	if left_pct < 1:
		errors.append("%s left column has %d percent passives, need at least 1" % [tree.id, left_pct])
	if right_pct < 1:
		errors.append("%s right column has %d percent passives, need at least 1" % [tree.id, right_pct])


static func _mark_seen(talent: TalentDef, seen: Dictionary, errors: PackedStringArray) -> void:
	if talent == null or talent.id.is_empty():
		errors.append("empty talent")
		return
	if seen.has(talent.id):
		errors.append("Duplicate talent id %s" % talent.id)
	seen[talent.id] = true
	if talent.max_rank < 1 or talent.max_rank > 3:
		errors.append("%s max_rank %d is illegal" % [talent.id, talent.max_rank])
