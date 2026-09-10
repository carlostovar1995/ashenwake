class_name HudRefreshScheduler
extends RefCounted

var _interval: float
var _elapsed: float
var _force_refresh: bool = true
var _signatures: Dictionary = {}


func _init(interval: float = 0.10) -> void:
	_interval = maxf(interval, 0.001)
	_elapsed = _interval


func advance(delta: float) -> bool:
	_elapsed += maxf(delta, 0.0)
	if not _force_refresh and _elapsed < _interval:
		return false
	_force_refresh = false
	_elapsed = fmod(_elapsed, _interval)
	return true


func force_refresh() -> void:
	_force_refresh = true


func mark_refreshed() -> void:
	_force_refresh = false
	_elapsed = 0.0


func signature_changed(key: StringName, value: Variant) -> bool:
	if _signatures.has(key) and _signatures[key] == value:
		return false
	_signatures[key] = value
	return true


func clear_signature(key: StringName) -> void:
	_signatures.erase(key)
