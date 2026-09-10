class_name BulwarkKit
extends Object

## Canned NPC raid-tank loadout: Ironclad to Iron Rampage plus a Holdfast dip to 50.
## Iron Fist is the only melee auto. D = Iron Rampage.
## QWER: Lightning+Fire Target (Goad), Protection+Divine Aura, Fire Nova (Peal), Wind+Fire Ground.


static func spend() -> TalentSpend:
	var spend := TalentSpend.new()
	spend.set_spec_slot(0, "aegis")
	spend.set_spec_slot(1, "bastion")
	for talent_id in _talent_ids():
		var def := ClassCatalog.find_talent(talent_id)
		if def == null:
			push_error("BulwarkKit: missing talent %s" % talent_id)
			continue
		var want_rank := def.max_rank
		while spend.rank_of(talent_id) < want_rank:
			if not spend.invest(talent_id):
				push_error("BulwarkKit: could not invest %s" % talent_id)
				break
	spend.sanitize_binds()
	spend.set_slot_d("iron_rampage")
	return spend


static func recipes() -> Array:
	return [
		SpellRecipe.make("target", PackedStringArray(["lightning", "fire"])),
		SpellRecipe.make("aura", PackedStringArray(["protection", "divine"])),
		SpellRecipe.make("nova", PackedStringArray(["fire"])),
		SpellRecipe.make("ground_aoe", PackedStringArray(["wind", "fire"])),
	]


static func apply_to(unit: Unit) -> void:
	if unit == null:
		return
	var kit := spend()
	unit.apply_compiled_abilities(ChampionLoadout.compile(recipes(), kit))
	var hooks := TalentHooks.from_spend(kit)
	if hooks.max_health_pct > 0.0:
		unit.max_health *= 1.0 + hooks.max_health_pct
	unit.health = unit.max_health
	unit.mana = unit.max_mana
	unit.bind_talent_hooks(hooks)
	ClassCatalog.apply_auto_to(unit, kit)


static func _talent_ids() -> PackedStringArray:
	return PackedStringArray([
		"aegis_plate_slab",
		"aegis_mid_stamina",
		"aegis_grudge_spite",
		"aegis_plate_shared_plate",
		"aegis_mid_guard",
		"aegis_grudge_goad",
		"aegis_plate_anointed",
		"aegis_mid_resolve",
		"aegis_grudge_marked_prey",
		"aegis_auto_iron_fist",
		"aegis_mid_heavy_hands",
		"aegis_ult_iron_rampage",
		"bastion_rampart_footing",
		"bastion_mid_foundation",
		"bastion_oath_vow",
		"bastion_rampart_undertow",
		"bastion_mid_oathbound",
		"bastion_oath_halo",
		"bastion_rampart_masonry",
		"bastion_oath_cover",
	])
