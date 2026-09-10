class_name ChampionLoadout
extends Object


static func compile(recipes: Array, spend: TalentSpend, skill_overlays: Array = []) -> Array[AbilityDef]:
	var crafted: Array = recipes
	if crafted.size() < SpellCatalog.CRAFT_SLOTS:
		crafted = SpellCatalog.default_loadout()
	var out: Array[AbilityDef] = []
	for i in SpellCatalog.CRAFT_SLOTS:
		var recipe: SpellRecipe = crafted[i] if i < crafted.size() and crafted[i] is SpellRecipe else SpellCatalog.default_loadout()[i]
		var ab := SpellCompiler.compile(recipe, SpellCatalog.CRAFTED_HOTKEYS[i])
		ab.loadout_slot = i
		out.append(ab)
	var bound_d := spend.slot_d if spend != null else ""
	var bound_f := spend.slot_f if spend != null else ""
	var skill_d := SpellCompiler.compile_skill(bound_d, _overlay_at(skill_overlays, 0), "D")
	skill_d.loadout_slot = 4
	out.append(skill_d)
	var skill_f := SpellCompiler.compile_skill(bound_f, _overlay_at(skill_overlays, 1), "F")
	skill_f.loadout_slot = 5
	out.append(skill_f)
	if spend != null:
		TalentHooks.apply_compile(out, spend)
	return out


static func _overlay_at(overlays: Array, index: int) -> SpellRecipe:
	if index < 0 or index >= overlays.size():
		return null
	var item = overlays[index]
	return item as SpellRecipe if item is SpellRecipe else null
