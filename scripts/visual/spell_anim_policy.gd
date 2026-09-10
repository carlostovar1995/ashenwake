class_name SpellAnimPolicy
extends Object

## Maps a live ability to body-anim playback. Clips are not pasted 1:1;
## speed and overlap come from the current cast window (augments can change it).
## COMBINED: one full clip scaled so `fire_frac` of its length lands at fire.
## SPLIT: Load then Cast, with Cast overlapped so fire is mid-throw.
## HOLD: instant channel. Play Load to the extended pose, freeze, then start Cast
## so a quarter of that clip has played when the channel completes.
## WINDUP_HOLD: windup then channel. Load during windup, overlap Cast so the arm
## is fully out when the channel starts, freeze that pose until complete/cancel.
## Tune per delivery here; CharacterVisual only binds clips and plays.

enum Mode { NONE, COMBINED, SPLIT, HOLD, WINDUP_HOLD }

const MIN_WINDOW := 0.08
## 1.0 = the whole clip fits in the windup (fire on last frame). Lower to leave follow-through after fire.
const COMBINED_FIRE_FRAC := 1.0
## Fire is meant to land this far through a split Cast clip.
const SPLIT_RELEASE_OVERLAP_FRAC := 0.5
## Channel end lands this far through the HOLD Cast clip.
const HOLD_RELEASE_OVERLAP_FRAC := 0.25
## Channel start lands this far through Direct Cast (1.0 = last frame, arm out).
const WINDUP_HOLD_POSE_FRAC := 1.0


static func mode_for(ab: AbilityDef) -> int:
	if ab == null or ab.is_toggle or ab.delivery == AbilityDef.Delivery.AURA:
		return Mode.NONE
	match ab.delivery:
		AbilityDef.Delivery.BOLT:
			return Mode.COMBINED
		AbilityDef.Delivery.MISSILES:
			return Mode.HOLD
		AbilityDef.Delivery.RAY:
			return Mode.WINDUP_HOLD
		_:
			return Mode.SPLIT


static func fire_frac(ab: AbilityDef) -> float:
	if mode_for(ab) == Mode.COMBINED:
		return COMBINED_FIRE_FRAC
	return 1.0


static func overlap_frac(ab: AbilityDef) -> float:
	match mode_for(ab):
		Mode.SPLIT:
			return SPLIT_RELEASE_OVERLAP_FRAC
		Mode.HOLD:
			return HOLD_RELEASE_OVERLAP_FRAC
		Mode.WINDUP_HOLD:
			return WINDUP_HOLD_POSE_FRAC
		_:
			return 0.0


static func queues_release_on_channel(ab: AbilityDef) -> bool:
	return mode_for(ab) == Mode.HOLD


static func gameplay_window(cast_time: float, scale: float = 1.0) -> float:
	return maxf(cast_time * scale, MIN_WINDOW)


static func fitted_speed(clip_length: float, gameplay_window: float, at_frac: float = 1.0) -> float:
	if clip_length <= 0.0:
		return 1.0
	var span := clip_length * clampf(at_frac, 0.05, 1.0)
	return span / maxf(gameplay_window, MIN_WINDOW)
