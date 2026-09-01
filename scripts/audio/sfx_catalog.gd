class_name SfxCatalog
extends Object

## Event id -> playback definition. Gameplay never hardcodes file paths.
## Only clips the user supplied are registered. Missing events are silent.

const _SFX := "res://assets/audio/sfx/"

const EVENTS := {
	"fire.cast": {
		"max_poly": 2,
		"max_distance": 42.0,
		"path": _SFX + "fire_cast.ogg",
		"volume_db": -4.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"firebolt.travel": {
		"path": _SFX + "fire_travel.ogg",
		"volume_db": -18.0,
		"max_distance": 42.0,
		"unit_size": 6.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"timing_sec": -0.15,
	},
	"firebolt.explode": {
		"max_poly": 5,
		"max_distance": 48.0,
		"path": _SFX + "firebolt_impact.ogg",
		"volume_db": -17.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"freeze.blast": {
		"max_poly": 3,
		"max_distance": 40.0,
		"path": _SFX + "freeze_blast.ogg",
		"volume_db": -12.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"freeze.lock": {
		"max_poly": 4,
		"max_distance": 36.0,
		"path": _SFX + "freeze_lock.ogg",
		"volume_db": -6.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"thunder_wave.cast": {
		"max_poly": 2,
		"max_distance": 42.0,
		"path": _SFX + "thunder_cast.ogg",
		"volume_db": -24.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"thunder_wave.hop": {
		"max_poly": 8,
		"max_distance": 38.0,
		"path": _SFX + "thunder_hop.ogg",
		"volume_db": -14.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"meteor.impact": {
		"max_poly": 2,
		"max_distance": 64.0,
		"path": _SFX + "meteor_impact.ogg",
		"volume_db": -9.9,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"timing_sec": 0.17,
	},
	"chilled_ground.place": {
		"max_poly": 2,
		"max_distance": 40.0,
		"path": _SFX + "chilled_place.ogg",
		"volume_db": -10.2,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"reaction.shatter": {
		"max_poly": 6,
		"max_distance": 34.0,
		"path": _SFX + "shatter.ogg",
		"volume_db": -12.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"overcharge.activate": {
		"max_poly": 1,
		"max_distance": 40.0,
		"path": _SFX + "overcharge_activate.ogg",
		"volume_db": -8.4,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
	"overcharge.loop": {
		"max_distance": 40.0,
		"path": _SFX + "overcharge_loop.ogg",
		"volume_db": -17.1,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
		"timing_sec": 0.75,
	},
	"overcharge.end": {
		"max_poly": 1,
		"max_distance": 40.0,
		"path": _SFX + "overcharge_end.ogg",
		"volume_db": -10.0,
		"pitch_min": 1.0,
		"pitch_max": 1.0,
	},
}


## Mixer pages in Settings. Add a clip when you drop in a new file.
const MIXER_GROUPS := [
	{
		"id": "caster",
		"title": "Caster",
		"subtitle": "Spells",
		"clips": [
			{"id": "fire.cast", "label": "Fire bolt / Meteor windup"},
			{"id": "firebolt.travel", "label": "Bolt in flight"},
			{"id": "firebolt.explode", "label": "Bolt impact"},
			{"id": "freeze.blast", "label": "Frost cone"},
			{"id": "freeze.lock", "label": "Freeze lock"},
			{"id": "thunder_wave.cast", "label": "Chain spark cast"},
			{"id": "thunder_wave.hop", "label": "Chain spark hit"},
			{"id": "meteor.impact", "label": "Meteor fall + explosion"},
			{"id": "chilled_ground.place", "label": "Ground zone place"},
			{"id": "overcharge.activate", "label": "Overcharge activate"},
			{"id": "overcharge.loop", "label": "Overcharge rumble"},
			{"id": "overcharge.end", "label": "Overcharge end"},
			{"id": "reaction.shatter", "label": "Shatter"},
		],
	},
	{
		"id": "colossus",
		"title": "Colossus",
		"subtitle": "Boss",
		"clips": [],
	},
	{
		"id": "dawnwarden",
		"title": "Dawnwarden",
		"subtitle": "Boss",
		"clips": [],
	},
]


static func get_event(event_id: String) -> Dictionary:
	if EVENTS.has(event_id):
		return EVENTS[event_id]
	return {}


static func mixer_groups() -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for group in MIXER_GROUPS:
		out.append(group)
		var clips: Array = group.get("clips", [])
		for clip in clips:
			if clip is Dictionary:
				seen[String(clip.get("id", ""))] = true
	var leftover: Array = []
	for event_id in EVENTS:
		if not seen.has(event_id):
			leftover.append({"id": event_id, "label": event_id})
	if not leftover.is_empty():
		out.append({
			"id": "ungrouped",
			"title": "Ungrouped",
			"subtitle": "New clips",
			"clips": leftover,
		})
	return out


static func all_paths() -> PackedStringArray:
	var seen: Dictionary = {}
	var out := PackedStringArray()
	for event_id in EVENTS:
		_collect_paths(EVENTS[event_id], seen, out)
	return out


static func _collect_paths(def: Dictionary, seen: Dictionary, out: PackedStringArray) -> void:
	var path := String(def.get("path", ""))
	if path != "" and not seen.has(path):
		seen[path] = true
		out.append(path)
	var layers: Variant = def.get("layers", [])
	if layers is Array:
		for layer in layers:
			if layer is Dictionary:
				_collect_paths(layer, seen, out)
