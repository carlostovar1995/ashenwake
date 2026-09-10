class_name TalentTreeDef
extends RefCounted

## Each later row costs this many more points in the spec than the one above it.
## 7-row trees unlock at 0 / 3 / 6 / 9 / 12 / 15 / 18.
const TIER_STEP := 3

var id: String = ""
var display_name: String = ""
var theme: String = ""
var talents: Array[TalentDef] = []
var choice_tree: bool = false
var left_name: String = ""
var right_name: String = ""


static func make(p_id: String, p_name: String, p_theme: String, p_talents: Array[TalentDef]) -> TalentTreeDef:
	var tree := TalentTreeDef.new()
	tree.id = p_id
	tree.display_name = p_name
	tree.theme = p_theme
	tree.talents = p_talents
	return tree


static func make_choice(
	p_id: String,
	p_name: String,
	p_theme: String,
	p_left_name: String,
	p_right_name: String,
	p_rows: Array,
	p_ult: TalentDef
) -> TalentTreeDef:
	var tree := TalentTreeDef.new()
	tree.id = p_id
	tree.display_name = p_name
	tree.theme = p_theme
	tree.choice_tree = true
	tree.left_name = p_left_name
	tree.right_name = p_right_name
	var flat: Array[TalentDef] = []
	for i in p_rows.size():
		var pair = p_rows[i]
		if not (pair is Array) or pair.is_empty():
			continue
		var n: int = pair.size()
		for j in n:
			var talent: TalentDef = pair[j]
			if talent == null:
				continue
			talent.row = i
			if n == 1:
				talent.side = TalentDef.SIDE_LEFT
			elif j == 0:
				talent.side = TalentDef.SIDE_LEFT
			elif j == n - 1:
				talent.side = TalentDef.SIDE_RIGHT
			else:
				talent.side = TalentDef.SIDE_MID
			flat.append(talent)
	if p_ult != null:
		p_ult.row = p_rows.size()
		p_ult.side = TalentDef.SIDE_SHARED
		p_ult.type = TalentDef.TYPE_ULTIMATE
		flat.append(p_ult)
	tree.talents = flat
	return tree


func talent_at(index: int) -> TalentDef:
	if index < 0 or index >= talents.size():
		return null
	return talents[index]


func index_of(talent_id: String) -> int:
	for i in talents.size():
		if talents[i].id == talent_id:
			return i
	return -1


func row_count() -> int:
	var highest := -1
	for talent in talents:
		if talent != null:
			highest = maxi(highest, talent.row)
	return highest + 1


func talents_in_row(row: int) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	for talent in talents:
		if talent != null and talent.row == row:
			out.append(talent)
	return out


func ordered_row(row: int) -> Array[TalentDef]:
	var lefts: Array[TalentDef] = []
	var mids: Array[TalentDef] = []
	var rights: Array[TalentDef] = []
	var shared: Array[TalentDef] = []
	for talent in talents_in_row(row):
		match talent.side:
			TalentDef.SIDE_LEFT:
				lefts.append(talent)
			TalentDef.SIDE_RIGHT:
				rights.append(talent)
			TalentDef.SIDE_SHARED:
				shared.append(talent)
			_:
				mids.append(talent)
	var out: Array[TalentDef] = []
	out.append_array(lefts)
	out.append_array(mids)
	out.append_array(rights)
	out.append_array(shared)
	return out


func unlock_cost(row: int) -> int:
	if row <= 0:
		return 0
	return row * TIER_STEP


func sibling(talent_id: String) -> TalentDef:
	var def := talent_at(index_of(talent_id))
	if def == null or def.type != TalentDef.TYPE_AUTO:
		return null
	for talent in talents_in_row(def.row):
		if talent.type == TalentDef.TYPE_AUTO and talent.id != def.id:
			return talent
	return null


func auto_options_in_row(row: int) -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	for talent in talents_in_row(row):
		if talent != null and talent.type == TalentDef.TYPE_AUTO:
			out.append(talent)
	return out


func ultimate() -> TalentDef:
	if talents.is_empty():
		return null
	var last: TalentDef = talents[talents.size() - 1]
	if last != null and last.type == TalentDef.TYPE_ULTIMATE:
		return last
	return null
