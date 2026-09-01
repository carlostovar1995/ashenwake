class_name SpellPower
extends Object

## Per-infusion slice, used for damage, healing, and shield:
## (base * (1 + infusion modifier) / n) * (1 + n * infusion.base) + flat
## n is the total infusion count. The last term is the shared infusion bonus
## (1 → 120%, 2 → 140%, 3 → 160%). Damage then applies (1 - resist).
## A crit roll adds crit_damage - 1 to the modifier (default 200% → +100% base).


static func skips_infusion_damage(ab: AbilityDef) -> bool:
	return ab != null and ab.delivery == AbilityDef.Delivery.WALL


static func infusion_count(ab: AbilityDef) -> int:
	if ab == null or ab.infusion_ids.is_empty():
		return 0
	return ab.infusion_ids.size()


static func infusion_base_mult(ab: AbilityDef) -> float:
	var n := infusion_count(ab)
	if n <= 0 or skips_infusion_damage(ab):
		return 1.0
	return 1.0 + CombatBalance.pct("infusion.base") * float(n)


static func share_for(count: int) -> float:
	if count <= 1:
		return 1.0
	if count == 2:
		return 0.5
	if count == 3:
		return 1.0 / 3.0
	return 1.0 / float(count)


static func deals_enemy_damage(ab: AbilityDef) -> bool:
	if ab == null or ab.infusion_ids.is_empty():
		return true
	for id in ab.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf != null and inf.offensive:
			return true
	return false


static func ghosts_enemies(ab: AbilityDef) -> bool:
	return ab != null and not deals_enemy_damage(ab)


static func elements_for(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := PackedInt32Array()
	if ab != null:
		for el in ab.split_elements:
			_add_element(els, el)
		_add_element(els, ab.element)
	for el in extras:
		_add_element(els, el)
	_add_element(els, primary)
	if els.is_empty() and ab != null:
		_add_element(els, ab.element)
	return els


static func damage_elements_for(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := elements_for(ab, extras, primary)
	if ab == null or ab.infusion_ids.is_empty():
		return els
	var out := PackedInt32Array()
	for el in els:
		if _element_deals_damage(ab, el):
			_add_element(out, el)
	return out


static func healing_elements_for(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := elements_for(ab, extras, primary)
	if ab == null or ab.infusion_ids.is_empty():
		return els
	var out := PackedInt32Array()
	for el in els:
		if _element_provides_healing(ab, el):
			_add_element(out, el)
	return out


static func shield_elements_for(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := elements_for(ab, extras, primary)
	if ab == null or ab.infusion_ids.is_empty():
		return els
	var out := PackedInt32Array()
	for el in els:
		if _element_provides_shield(ab, el):
			_add_element(out, el)
	return out


static func _element_deals_damage(ab: AbilityDef, el: int) -> bool:
	if ab == null or ab.infusion_ids.is_empty():
		return true
	var matched := false
	for id in ab.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf == null or inf.element != el:
			continue
		matched = true
		if inf.offensive:
			return true
	return not matched


static func _element_provides_healing(ab: AbilityDef, el: int) -> bool:
	if ab == null or ab.infusion_ids.is_empty():
		return true
	var matched := false
	for id in ab.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf == null or inf.element != el:
			continue
		matched = true
		if inf.heal_allies or not is_equal_approx(inf.heal_mult, 1.0):
			return true
	return not matched


static func _element_provides_shield(ab: AbilityDef, el: int) -> bool:
	if ab == null or ab.infusion_ids.is_empty():
		return true
	for id in ab.infusion_ids:
		var inf := SpellCatalog.get_infusion(id)
		if inf == null or inf.element != el:
			continue
		if inf.shield_from_base > 0.02:
			return true
		if ab.shield > 0.05 and not is_equal_approx(increase_for(ab, el, true, "shield"), 0.0):
			return true
	return false


static func _add_element(els: PackedInt32Array, el: int) -> void:
	if el == AbilityDef.Element.NONE:
		return
	for existing in els:
		if existing == el:
			return
	els.append(el)


static func increase_for(ab: AbilityDef, element: int, healing: bool, channel: String = "") -> float:
	if ab == null:
		return 0.0
	var mode := channel
	if mode.is_empty():
		mode = "heal" if healing else "damage"
	if mode == "damage" and skips_infusion_damage(ab):
		return 0.0
	for i in ab.split_elements.size():
		if ab.split_elements[i] != element:
			continue
		match mode:
			"heal":
				return ab.split_heal_inc[i] if i < ab.split_heal_inc.size() else 0.0
			"shield":
				return ab.split_shield_inc[i] if i < ab.split_shield_inc.size() else 0.0
			_:
				return ab.split_damage_inc[i] if i < ab.split_damage_inc.size() else 0.0
	return 0.0


static func flat_for(ab: AbilityDef, element: int) -> float:
	if ab == null:
		return 0.0
	for i in ab.split_elements.size():
		if ab.split_elements[i] != element:
			continue
		return ab.split_flat[i] if i < ab.split_flat.size() else 0.0
	return 0.0


static func crit_base_increase(ab: AbilityDef, crit: bool) -> float:
	if not crit:
		return 0.0
	var mult := 2.0
	if ab != null:
		mult = maxf(ab.crit_damage, 1.0)
	return maxf(0.0, mult - 1.0)


static func _resist_cut(victim: Object, element: int, ability_id: String) -> float:
	if victim == null or not victim.has_method("element_resist"):
		return 0.0
	return maxf(0.0, float(victim.call("element_resist", element, ability_id)))


static func packet(base: float, ab: AbilityDef, extras: PackedInt32Array, victim: Object, healing: bool, ability_id: String = "", crit: bool = false, primary: int = AbilityDef.Element.NONE, channel: String = "") -> float:
	var total := 0.0
	for part in packet_parts(base, ab, extras, victim, healing, ability_id, crit, primary, channel):
		total += float(part.get("amount", 0.0))
	return total


static func _channel_elements(ab: AbilityDef, extras: PackedInt32Array, primary: int, mode: String) -> PackedInt32Array:
	match mode:
		"heal":
			return healing_elements_for(ab, extras, primary)
		"shield":
			return shield_elements_for(ab, extras, primary)
		_:
			return damage_elements_for(ab, extras, primary)


static func _slice_amount(base: float, ab: AbilityDef, el: int, healing: bool, mode: String, crit_inc: float) -> float:
	var n := maxi(infusion_count(ab), 1)
	var stack := infusion_base_mult(ab)
	return (base * (1.0 + increase_for(ab, el, healing, mode) + crit_inc) / float(n)) * stack + flat_for(ab, el)


static func packet_parts(base: float, ab: AbilityDef, extras: PackedInt32Array, victim: Object, healing: bool, ability_id: String = "", crit: bool = false, primary: int = AbilityDef.Element.NONE, channel: String = "") -> Array:
	var parts: Array = []
	if base <= 0.0 and (ab == null or ab.split_flat.is_empty()):
		return parts
	var mode := channel
	if mode.is_empty():
		mode = "heal" if healing else "damage"
	var crit_inc := crit_base_increase(ab, crit)
	if mode == "damage" and not deals_enemy_damage(ab):
		return parts
	var els := _channel_elements(ab, extras, primary, mode)
	if els.is_empty():
		var raw := base * (1.0 + crit_inc)
		if mode == "damage":
			raw *= maxf(0.0, 1.0 - _resist_cut(victim, AbilityDef.Element.NONE, ability_id))
		if raw > 0.0:
			parts.append({"element": primary, "amount": raw})
		return parts
	for el in els:
		var slice := _slice_amount(base, ab, el, healing, mode, crit_inc)
		if mode == "damage":
			slice *= maxf(0.0, 1.0 - _resist_cut(victim, el, ability_id))
		if slice > 0.0:
			parts.append({"element": el, "amount": slice})
	return parts


static func slot_elements(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := PackedInt32Array()
	if ab != null and not ab.split_elements.is_empty():
		for el in ab.split_elements:
			_add_element(els, el)
		return els
	if ab != null:
		for id in ab.infusion_ids:
			var inf := SpellCatalog.get_infusion(id)
			if inf != null:
				_add_element(els, inf.element)
	_add_element(els, primary)
	if ab != null:
		_add_element(els, ab.element)
	for el in extras:
		_add_element(els, el)
	return els


static func hit_slot_elements(ab: AbilityDef, extras: PackedInt32Array = PackedInt32Array(), primary: int = AbilityDef.Element.NONE) -> PackedInt32Array:
	var els := PackedInt32Array()
	_add_element(els, primary)
	for el in extras:
		_add_element(els, el)
	if els.size() >= 2:
		return els
	return slot_elements(ab, extras, primary)


static func matches_hit(ab: AbilityDef, extras: PackedInt32Array, primary: int) -> bool:
	if ab == null:
		return false
	var fired := PackedInt32Array()
	_add_element(fired, primary)
	for el in extras:
		_add_element(fired, el)
	if fired.is_empty():
		return false
	var slots := slot_elements(ab, extras, primary)
	if slots.size() != fired.size():
		return false
	for i in slots.size():
		if slots[i] != fired[i]:
			return false
	return true


static func preview_shield(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	return packet(ab.shield, ab, PackedInt32Array(), null, true, ab.id, false, AbilityDef.Element.NONE, "shield")


static func preview_slices(ab: AbilityDef) -> Array:
	var rows: Array = []
	if ab == null:
		return rows
	if ab.damage > 0.05:
		rows.append_array(_slices(ab.damage, ab, false, "damage"))
	elif ab.tick_damage > 0.05:
		rows.append_array(_slices(ab.tick_damage, ab, false, "damage per tick"))
	if ab.heal > 0.05:
		rows.append_array(_slices(ab.heal, ab, true, "healing"))
	if ab.shield > 0.05:
		var shield_verb := "shield per tick" if ab.ticks_shield() else "shield"
		rows.append_array(_slices(ab.shield, ab, true, shield_verb, "shield"))
	return rows


static func _slices(base: float, ab: AbilityDef, healing: bool, verb: String, channel: String = "") -> Array:
	var rows: Array = []
	var mode := channel
	if mode.is_empty():
		mode = "heal" if healing else "damage"
	if mode == "damage" and not deals_enemy_damage(ab):
		return rows
	var els := _channel_elements(ab, PackedInt32Array(), AbilityDef.Element.NONE, mode)
	if els.is_empty():
		if base > 0.05:
			rows.append({"element": AbilityDef.Element.NONE, "amount": base, "verb": verb})
		return rows
	for el in els:
		var slice := _slice_amount(base, ab, el, healing, mode, 0.0)
		if slice <= 0.05:
			continue
		rows.append({"element": el, "amount": slice, "verb": verb})
	return rows


static func preview_damage(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	var base := ab.damage if ab.damage > 0.05 else ab.tick_damage
	return packet(base, ab, PackedInt32Array(), null, false, ab.id)


static func preview_heal(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	return packet(ab.heal, ab, PackedInt32Array(), null, true, ab.id)


static func preview_tick(ab: AbilityDef) -> float:
	if ab == null:
		return 0.0
	return packet(ab.tick_damage, ab, PackedInt32Array(), null, false, ab.id)
