class_name TalentDef
extends RefCounted

const TYPE_PASSIVE := "passive"
const TYPE_INTERACTION := "interaction"
const TYPE_AUTO := "auto"
const TYPE_ULTIMATE := "ultimate"
const SIDE_LEFT := "left"
const SIDE_RIGHT := "right"
const SIDE_MID := "mid"
const SIDE_SHARED := "shared"

var id: String = ""
var display_name: String = ""
var max_rank: int = 1
var type: String = TYPE_PASSIVE
var per_point: PackedStringArray = PackedStringArray()
var hook: String = "none"
var skill_id: String = ""
var row: int = 0
var side: String = SIDE_LEFT
var melee_auto: bool = false


static func make(
	p_id: String,
	p_name: String,
	p_max: int,
	p_type: String,
	p_lines: PackedStringArray,
	p_hook: String = "none",
	p_skill_id: String = ""
) -> TalentDef:
	var t := TalentDef.new()
	t.id = p_id
	t.display_name = p_name
	t.max_rank = clampi(p_max, 1, 3)
	t.type = p_type
	t.per_point = p_lines
	t.hook = p_hook
	t.skill_id = p_skill_id
	return t


func is_skill() -> bool:
	return type == TYPE_ULTIMATE or not skill_id.is_empty()


func is_auto() -> bool:
	return type == TYPE_AUTO


func is_choice() -> bool:
	return side == SIDE_LEFT or side == SIDE_RIGHT


func line_for_rank(rank: int) -> String:
	if rank <= 0 or rank > per_point.size():
		return ""
	return per_point[rank - 1]
