class_name EnemyRank
extends Object

## Combat rank for Chill/Freeze and Shatter pacing.
## Training dummies and small adds are NORMAL. Bosses are ELITE. RARE is unused until new enemies exist.
enum Rank { NORMAL, RARE, ELITE }

const STACK_MAX := 50
const SLOW_PER_STACK := 0.01
const ICE_PER_STACK_NORMAL := 6.0
const ICE_PER_STACK_RARE := 20.0
const ICE_PER_STACK_ELITE := 40.0
const FREEZE_IMMUNE_NORMAL := 2.5
const FREEZE_IMMUNE_RARE := 6.0
const FREEZE_IMMUNE_ELITE := 12.0


static func from_unit(unit: Unit) -> int:
	if unit == null:
		return Rank.NORMAL
	if unit.enemy_rank == Rank.RARE or unit.enemy_rank == Rank.ELITE:
		return unit.enemy_rank
	if unit.is_boss:
		return Rank.ELITE
	return Rank.NORMAL


static func ice_per_stack(rank: int) -> float:
	match rank:
		Rank.RARE:
			return CombatBalance.flat("chill.ice.rare")
		Rank.ELITE:
			return CombatBalance.flat("chill.ice.elite")
		_:
			return CombatBalance.flat("chill.ice.normal")


static func freeze_immune_time(rank: int) -> float:
	match rank:
		Rank.RARE:
			return CombatBalance.flat("freeze.immune.rare")
		Rank.ELITE:
			return CombatBalance.flat("freeze.immune.elite")
		_:
			return CombatBalance.flat("freeze.immune.normal")


static func shatter_shell(rank: int) -> float:
	match rank:
		Rank.RARE:
			return maxf(CombatBalance.flat("shatter.shell.rare"), 1.0)
		Rank.ELITE:
			return maxf(CombatBalance.flat("shatter.shell.elite"), 1.0)
		_:
			return maxf(CombatBalance.flat("shatter.shell.normal"), 1.0)


static func stack_max() -> int:
	return maxi(int(round(CombatBalance.flat("chill.stacks.max"))), 1)


static func slow_per_stack() -> float:
	return clampf(CombatBalance.pct("chill.slow.per_stack"), 0.0, 1.0)
