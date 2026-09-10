class_name AutoAnimPolicy
extends Object

## Auto body-anim timing. Same idea as SpellAnimPolicy: do not paste the clip 1:1.
## Windup scales ThrowBall / melee swing so FIRE_FRAC of the clip lands when the
## shot fires. Cooldown starts after fire (cycle - windup). A move or cast order
## during windup cancels the auto; leaving range does not. Move after fire only
## cuts leftover follow-through.

const MIN_WINDOW := 0.08
const MAX_CYCLE_FRAC := 0.4
## Hit / projectile at this fraction of the swing. Remainder is move-cancellable.
const FIRE_FRAC := 0.85


static func attack_cycle(cooldown: float) -> float:
	return maxf(0.12, cooldown)


static func windup_window(windup: float, cooldown: float) -> float:
	var cycle := attack_cycle(cooldown)
	return clampf(windup, MIN_WINDOW, cycle * MAX_CYCLE_FRAC)


static func fire_cooldown(cooldown: float, played_windup: float) -> float:
	var cycle := attack_cycle(cooldown)
	return maxf(0.04, cycle - played_windup)


static func fitted_speed(clip_length: float, windup: float) -> float:
	return SpellAnimPolicy.fitted_speed(clip_length, windup, FIRE_FRAC)
