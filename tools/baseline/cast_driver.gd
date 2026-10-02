extends RefCounted
## Scripted caster for the baseline scenes. Walks a unit's six slots in order and
## casts whichever is ready, so every ability in the loadout gets exercised
## without AI randomness. Aim comes from the caller each tick.

const AURA_HOLD := 4.0

var unit: Unit
var casts: Dictionary = {}

var _next: int = 0
var _aura_age: Dictionary = {}


func _init(p_unit: Unit) -> void:
	unit = p_unit


func tick(delta: float, hostile: Unit, point: Vector3, friendly: Unit) -> void:
	if unit == null or not is_instance_valid(unit) or unit.is_dead:
		return
	var ctrl := unit.controller
	if ctrl == null:
		return
	unit.mana = unit.max_mana
	_release_old_auras(delta, ctrl, hostile, friendly)
	if ctrl.is_busy():
		return
	var count := unit.abilities.size()
	for step in count:
		var slot := (_next + step) % count
		var ab: AbilityDef = unit.abilities[slot]
		if not ab.implemented or ab.id.is_empty() or unit.has_aura(slot):
			continue
		# Slots on cooldown or out of mana are skipped, but a slot that is only
		# waiting on the global cooldown is waited for. Skipping ahead there lets
		# instant gcd-exempt skills restart the GCD forever and starve the rest.
		if not unit.can_prepare_cast(slot):
			continue
		if unit.is_on_global_cooldown(slot):
			return
		var support := ab.is_ally_support() or ab.friendly_only
		var target: Unit = friendly if support else hostile
		var aim := point
		if target != null and is_instance_valid(target):
			aim = target.global_position
		ctrl.ai_cast(slot, aim, target)
		var key := "%d:%s" % [slot, ab.id]
		casts[key] = int(casts.get(key, 0)) + 1
		_next = (slot + 1) % count
		return


func _release_old_auras(delta: float, ctrl: UnitController, hostile: Unit, friendly: Unit) -> void:
	for slot in unit.abilities.size():
		if not unit.has_aura(slot):
			_aura_age.erase(slot)
			continue
		var age := float(_aura_age.get(slot, 0.0)) + delta
		_aura_age[slot] = age
		if age >= AURA_HOLD and not ctrl.is_busy():
			var ab: AbilityDef = unit.abilities[slot]
			var target: Unit = friendly if ab.is_ally_support() else hostile
			ctrl.ai_cast(slot, unit.global_position, target)
			_aura_age.erase(slot)
