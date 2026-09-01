extends Node

const BUS_SFX := "SFX"
const POOL_SIZE := 28
const MIX_MAX := 2.0
const TIMING_MAX := 1.5
const _MIX_PATH := "user://sfx_mix.cfg"
const _Catalog := preload("res://scripts/audio/sfx_catalog.gd")

var _pool: Array[AudioStreamPlayer] = []
var _busy: Dictionary = {} ## player -> event_id
var _event_counts: Dictionary = {}
var _streams: Dictionary = {} ## path -> AudioStream
var _loops: Dictionary = {} ## token -> {player, event}
var _next_token: int = 1
var _mix: Dictionary = {} ## event_id -> linear gain (1.0 = catalog volume)
var _timing: Dictionary = {} ## event_id -> seconds (positive delay, negative skip)
var _preview_players: Array[AudioStreamPlayer] = []
var _preview_gen: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_mix()
	_preload_streams()
	var holder := Node.new()
	holder.name = "SfxPool"
	add_child(holder)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool%d" % i
		p.bus = BUS_SFX
		p.finished.connect(_on_oneshot_finished.bind(p))
		holder.add_child(p)
		_pool.append(p)


func play_at(event_id: String, _pos: Vector3, extra: Dictionary = {}) -> void:
	var def := _Catalog.get_event(event_id)
	if def.is_empty():
		return
	var max_poly := int(def.get("max_poly", 6))
	if int(_event_counts.get(event_id, 0)) >= max_poly:
		return
	var layers: Array = def.get("layers", [])
	if layers.is_empty():
		layers = [def]
	for layer in layers:
		if not (layer is Dictionary):
			continue
		_play_layer(event_id, def, layer, extra)


func play_on(event_id: String, host: Node, extra: Dictionary = {}) -> int:
	if host == null or not is_instance_valid(host):
		return 0
	var def := _Catalog.get_event(event_id)
	if def.is_empty():
		return 0
	var layer: Dictionary = def
	var layers: Array = def.get("layers", [])
	if not layers.is_empty() and layers[0] is Dictionary:
		layer = layers[0]
	var stream := _stream_for(String(layer.get("path", def.get("path", ""))))
	if stream == null:
		return 0
	var player := _make_owned_player("SfxCast", stream, def, layer, extra, event_id)
	var cue := _playback_cue(stream, extra, event_id)
	host.add_child(player)
	var token := _track_owned(player, event_id, host)
	_start_player(player, cue, false)
	return token


func attach_loop(event_id: String, host: Node, extra: Dictionary = {}) -> int:
	if host == null or not is_instance_valid(host):
		return 0
	var def := _Catalog.get_event(event_id)
	if def.is_empty():
		return 0
	var layer: Dictionary = def
	var layers: Array = def.get("layers", [])
	if not layers.is_empty() and layers[0] is Dictionary:
		layer = layers[0]
	var stream := _stream_for(String(layer.get("path", def.get("path", ""))))
	if stream == null:
		return 0
	var looped := stream.duplicate()
	_enable_loop(looped)
	var player := _make_owned_player("SfxLoop", looped, def, layer, extra, event_id)
	host.add_child(player)
	var token := _track_owned(player, event_id, host)
	_start_player(player, _playback_cue(looped, extra, event_id), false)
	return token


func stop_loop(token: int, fade_sec: float = 0.0) -> void:
	if token <= 0 or not _loops.has(token):
		return
	var rec: Dictionary = _loops[token]
	_loops.erase(token)
	var player: AudioStreamPlayer = rec.get("player")
	if player == null or not is_instance_valid(player):
		return
	_disable_loop(player.stream)
	if fade_sec > 0.04 and is_inside_tree():
		var tw := create_tween()
		tw.tween_property(player, "volume_db", -48.0, fade_sec)
		tw.tween_callback(func() -> void:
			if player != null and is_instance_valid(player):
				player.stop()
				player.queue_free()
		)
	else:
		player.stop()
		player.queue_free()


func mix_gain(event_id: String) -> float:
	return clampf(float(_mix.get(event_id, 1.0)), 0.0, MIX_MAX)


func set_mix_gain(event_id: String, gain: float, persist: bool = true) -> void:
	if event_id.is_empty():
		return
	var next := clampf(gain, 0.0, MIX_MAX)
	if absf(next - 1.0) < 0.005:
		_mix.erase(event_id)
	else:
		_mix[event_id] = next
	_apply_mix_to_playing(event_id)
	if persist:
		_save_mix()


func timing_offset(event_id: String) -> float:
	return clampf(float(_timing.get(event_id, 0.0)), -TIMING_MAX, TIMING_MAX)


func set_timing_offset(event_id: String, seconds: float, persist: bool = true) -> void:
	if event_id.is_empty():
		return
	var next := clampf(seconds, -TIMING_MAX, TIMING_MAX)
	if absf(next) < 0.001:
		_timing.erase(event_id)
	else:
		_timing[event_id] = next
	if persist:
		_save_mix()


func persist_mix() -> void:
	_save_mix()


func stop_preview() -> void:
	_preview_gen += 1
	_clear_preview()


func reset_mix_group(event_ids: PackedStringArray) -> void:
	for event_id in event_ids:
		_mix.erase(event_id)
		_timing.erase(event_id)
		_apply_mix_to_playing(event_id)
	_save_mix()


func preview(event_id: String) -> void:
	_preview_gen += 1
	_clear_preview()
	var def := _Catalog.get_event(event_id)
	if def.is_empty():
		return
	var layers: Array = def.get("layers", [])
	if layers.is_empty():
		layers = [def]
	var gen := _preview_gen
	for layer in layers:
		if not (layer is Dictionary):
			continue
		var stream := _stream_for(String(layer.get("path", def.get("path", ""))))
		if stream == null:
			continue
		var player := AudioStreamPlayer.new()
		player.name = "SfxPreview"
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.stream = stream
		var base_db := float(layer.get("volume_db", def.get("volume_db", 0.0)))
		player.set_meta("sfx_event", event_id)
		player.set_meta("sfx_base_db", base_db)
		player.volume_db = _mixed_db(event_id, base_db)
		player.pitch_scale = 1.0
		add_child(player)
		_preview_players.append(player)
		player.finished.connect(_on_preview_finished.bind(player), CONNECT_ONE_SHOT)
		_start_player(player, _playback_cue(stream, {}, event_id), true, gen)


func _make_owned_player(
	p_name: String,
	stream: AudioStream,
	def: Dictionary,
	layer: Dictionary,
	extra: Dictionary,
	event_id: String
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = p_name
	player.bus = BUS_SFX
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = stream
	var base_db := float(layer.get("volume_db", def.get("volume_db", 0.0))) + float(extra.get("volume_db", 0.0))
	player.set_meta("sfx_event", event_id)
	player.set_meta("sfx_base_db", base_db)
	player.volume_db = _mixed_db(event_id, base_db)
	player.pitch_scale = float(extra.get("pitch", 1.0))
	if player.pitch_scale <= 0.001:
		player.pitch_scale = 1.0
	return player


func _track_owned(player: AudioStreamPlayer, event_id: String, host: Node) -> int:
	var token := _next_token
	_next_token += 1
	_loops[token] = {"player": player, "event": event_id, "host": host}
	player.finished.connect(_on_owned_finished.bind(token), CONNECT_ONE_SHOT)
	if not host.tree_exiting.is_connected(_on_loop_host_exit):
		host.tree_exiting.connect(_on_loop_host_exit.bind(token), CONNECT_ONE_SHOT)
	return token


func _play_layer(event_id: String, def: Dictionary, layer: Dictionary, extra: Dictionary) -> void:
	var stream := _stream_for(String(layer.get("path", "")))
	if stream == null:
		return
	var player := _acquire()
	if player == null:
		return
	player.stream = stream
	var vol := float(layer.get("volume_db", def.get("volume_db", 0.0)))
	vol += float(extra.get("volume_db", 0.0))
	player.set_meta("sfx_event", event_id)
	player.set_meta("sfx_base_db", vol)
	player.volume_db = _mixed_db(event_id, vol)
	var pitch := float(extra.get("pitch", 0.0))
	if pitch <= 0.001:
		var pmin := float(layer.get("pitch_min", def.get("pitch_min", 1.0)))
		var pmax := float(layer.get("pitch_max", def.get("pitch_max", 1.0)))
		pitch = randf_range(minf(pmin, pmax), maxf(pmin, pmax))
	player.pitch_scale = pitch
	_busy[player] = event_id
	_event_counts[event_id] = int(_event_counts.get(event_id, 0)) + 1
	_start_player(player, _playback_cue(stream, extra, event_id), false)


func _acquire() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing and not _busy.has(p):
			return p
	return null


func _on_oneshot_finished(player: AudioStreamPlayer) -> void:
	if not _busy.has(player):
		return
	var event_id: String = _busy[player]
	_busy.erase(player)
	_event_counts[event_id] = maxi(int(_event_counts.get(event_id, 1)) - 1, 0)


func _on_owned_finished(token: int) -> void:
	if not _loops.has(token):
		return
	var rec: Dictionary = _loops[token]
	_loops.erase(token)
	var player: AudioStreamPlayer = rec.get("player")
	if player != null and is_instance_valid(player):
		player.queue_free()


func _on_loop_host_exit(token: int) -> void:
	stop_loop(token, 0.0)


func _preload_streams() -> void:
	for path in _Catalog.all_paths():
		var stream := _load_stream(path)
		if stream == null:
			push_warning("SFX missing: %s" % path)
			continue
		_streams[path] = stream


func _stream_for(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if _streams.has(path):
		return _streams[path]
	var stream := _load_stream(path)
	if stream != null:
		_streams[path] = stream
	return stream


func _load_stream(path: String) -> AudioStream:
	# Prefer a direct file load so ffmpeg-written / overwritten oggs play even
	# when Godot has not imported them (or is still serving a stale .import).
	if path.ends_with(".ogg") and FileAccess.file_exists(path):
		var ogg := AudioStreamOggVorbis.load_from_file(path)
		if ogg != null:
			return ogg
	if ResourceLoader.exists(path):
		var stream := load(path)
		if stream is AudioStream:
			return stream
	return null


func _playback_cue(stream: AudioStream, extra: Dictionary, event_id: String) -> Dictionary:
	var start_at := float(extra.get("start_at", 0.0))
	var from_end := float(extra.get("from_end", 0.0))
	var length := stream.get_length() if stream != null else 0.0
	if from_end > 0.001:
		start_at = maxf(0.0, length - from_end)
	var def := _Catalog.get_event(event_id)
	var offset := float(def.get("timing_sec", 0.0)) + timing_offset(event_id)
	var delay := 0.0
	if offset > 0.001:
		delay = offset
	elif offset < -0.001:
		start_at = minf(maxf(0.0, length - 0.02), start_at - offset)
	return {"start_at": start_at, "delay": delay}


func _start_player(player: AudioStreamPlayer, cue: Dictionary, ignore_pause: bool, gen: int = -1) -> void:
	if player == null or not is_instance_valid(player):
		return
	var start_at := float(cue.get("start_at", 0.0))
	var delay := float(cue.get("delay", 0.0))
	if delay <= 0.001:
		player.play(start_at)
		return
	var tree := get_tree()
	if tree == null:
		player.play(start_at)
		return
	tree.create_timer(delay, ignore_pause, false, ignore_pause).timeout.connect(func() -> void:
		if gen >= 0 and gen != _preview_gen:
			return
		if player != null and is_instance_valid(player) and not player.playing:
			player.play(start_at)
	)


func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = wav.data.size()


func _disable_loop(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED


func _mixed_db(event_id: String, base_db: float) -> float:
	var gain := mix_gain(event_id)
	if gain <= 0.001:
		return -80.0
	return base_db + linear_to_db(gain)


func _apply_mix_to_playing(event_id: String) -> void:
	for player in _busy:
		if player is AudioStreamPlayer:
			_refresh_player_mix(player as AudioStreamPlayer, event_id)
	for token in _loops:
		var rec: Dictionary = _loops[token]
		var player: AudioStreamPlayer = rec.get("player")
		if player != null and is_instance_valid(player):
			_refresh_player_mix(player, event_id)
	for player in _preview_players:
		if is_instance_valid(player):
			_refresh_player_mix(player, event_id)


func _refresh_player_mix(player: AudioStreamPlayer, event_id: String) -> void:
	if not player.has_meta("sfx_event"):
		return
	if String(player.get_meta("sfx_event")) != event_id:
		return
	var base_db := float(player.get_meta("sfx_base_db", player.volume_db))
	player.volume_db = _mixed_db(event_id, base_db)


func _clear_preview() -> void:
	for player in _preview_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_preview_players.clear()


func _on_preview_finished(player: AudioStreamPlayer) -> void:
	_preview_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()


func _load_mix() -> void:
	_mix.clear()
	_timing.clear()
	var cfg := ConfigFile.new()
	if cfg.load(_MIX_PATH) != OK:
		return
	if cfg.has_section("mix"):
		for key in cfg.get_section_keys("mix"):
			if not _Catalog.EVENTS.has(key):
				continue
			_mix[key] = clampf(float(cfg.get_value("mix", key, 1.0)), 0.0, MIX_MAX)
	if cfg.has_section("timing"):
		for key in cfg.get_section_keys("timing"):
			if not _Catalog.EVENTS.has(key):
				continue
			_timing[key] = clampf(float(cfg.get_value("timing", key, 0.0)), -TIMING_MAX, TIMING_MAX)


func _save_mix() -> void:
	var cfg := ConfigFile.new()
	for event_id in _mix:
		if not _Catalog.EVENTS.has(event_id):
			continue
		cfg.set_value("mix", event_id, float(_mix[event_id]))
	for event_id in _timing:
		if not _Catalog.EVENTS.has(event_id):
			continue
		cfg.set_value("timing", event_id, float(_timing[event_id]))
	cfg.save(_MIX_PATH)
