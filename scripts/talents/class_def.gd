class_name ClassDef
extends RefCounted

var id: String = ""
var display_name: String = ""
var role: String = ""
var starting_points: int = 25
var trees: Array[TalentTreeDef] = []
var auto: ClassAutoAttack = null


func tree_named(tree_id: String) -> TalentTreeDef:
	for tree in trees:
		if tree.id == tree_id:
			return tree
	return null


func talent(talent_id: String) -> TalentDef:
	for tree in trees:
		var idx := tree.index_of(talent_id)
		if idx >= 0:
			return tree.talents[idx]
	return null


func tree_for_talent(talent_id: String) -> TalentTreeDef:
	for tree in trees:
		if tree.index_of(talent_id) >= 0:
			return tree
	return null


func all_skills() -> Array[TalentDef]:
	var out: Array[TalentDef] = []
	for tree in trees:
		for talent in tree.talents:
			if talent.is_skill():
				out.append(talent)
	return out
