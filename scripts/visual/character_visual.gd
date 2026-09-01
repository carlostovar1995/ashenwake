class_name CharacterVisual
extends Node3D

var _unit: Unit
var _player: AnimationPlayer
var _idle: StringName = &""
var _walk: StringName = &""
var _run: StringName = &""
var _attack: StringName = &""
var _cast: StringName = &""
var _death: StringName = &""
var _busy: bool = false
var _corpse: bool = false
var _death_started: bool = false
var _running: bool = false
var _still_time: float = 0.0
var _was_winding: bool = false
var _aa_recover: float = 0.0
var _dodge: StringName = &""
var _dodge_left: float = 0.0
var _skel: Skeleton3D
var _hand_bone: int = -1
var _hover_meshes: Array[MeshInstance3D] = []
var _hover_mat: ShaderMaterial
var _infusion_mat: ShaderMaterial
var _freeze_mat: ShaderMaterial
var _hover_on: bool = false
var _infusion_on: bool = false
var _frozen: bool = false
var _on_screen: bool = true

static var _recolor_cache: Dictionary = {}

const _HOVER_SHADER := preload("res://scripts/visual/hover_outline.gdshader")
const _INFUSION_SHADER := preload("res://scripts/visual/infusion_tint.gdshader")
const _FREEZE_SHADER := preload("res://scripts/visual/freeze_tint.gdshader")


func setup(unit: Unit, model_path: String, model_scale: float, yaw: float = PI, y_offset: float = 0.0, pitch: float = 0.0) -> void:
	_unit = unit
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_warning("Could not load %s" % model_path)
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	add_child(model)
	model.scale = Vector3.ONE * model_scale
	if absf(pitch) > 0.001:
		model.rotate_x(pitch)
	# Quaternius meshes face +Z; units face Godot -Z, so without this they moonwalk.
	if absf(yaw) > 0.001:
		model.rotate_y(yaw)
	if absf(y_offset) > 0.001:
		model.position.y = y_offset
	_sharpen_meshes(model)
	_cache_hover_meshes(model)
	_hide_placeholders(unit)
	_cache_skeleton(model)
	# Static props (training dummy) have no skeleton. Don't graft locomotion clips.
	if _skel == null:
		return
	_player = _find_anim_player(model)
	var native := _player != null and _player.get_animation_list().size() > 0
	if _player == null:
		_player = AnimationPlayer.new()
		_player.name = "AnimationPlayer"
		model.add_child(_player)
	# Don't graft humanoid UAL clips onto a foreign skeleton that already has animations.
	if not native:
		_import_libraries()
	_bind_clips(native)
	_player.playback_default_blend_time = 0.08
	if not _player.animation_finished.is_connected(_on_animation_finished):
		_player.animation_finished.connect(_on_animation_finished)
	_play_loco(false)
	_setup_screen_lod()


func _sharpen_meshes(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).lod_bias = 1.0
	for c in n.get_children():
		_sharpen_meshes(c)


func _hide_placeholders(unit: Unit) -> void:
	var mesh := unit.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var face := unit.get_node_or_null("FacingMarker") as MeshInstance3D
	if face:
		face.visible = false


func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null


func _import_libraries() -> void:
	if _player == null:
		return
	var i := 0
	for lib in CharacterCatalog.animation_libraries():
		var dest_name := StringName("ual_%s" % i)
		i += 1
		if not _player.has_animation_library(dest_name):
			_player.add_animation_library(dest_name, lib.duplicate(true))


func _bind_clips(native: bool = false) -> void:
	if _player == null:
		return
	var names: PackedStringArray = _player.get_animation_list()
	_idle = _pick(names, ["Idle", "Hover"])
	_walk = _pick(names, ["Walk", "Hover"])
	_run = _pick(names, ["Jog_Fwd", "Sprint", "Run", "Walk", "Hover"])
	if _unit and _unit.is_melee:
		_attack = _pick(names, ["Attack", "Sword_Attack", "Sword_Regular_A", "Punch_Cross"])
	else:
		_attack = _pick(names, ["Attack", "Spell_Simple_Shoot", "Pistol_Shoot", "OverhandThrow", "Punch_Cross"])
	_cast = _pick(names, ["ChargeUp", "Cast", "Spell_Simple_Shoot", "OverhandThrow", "Pistol_Shoot", "Attack"])
	_death = _pick(names, ["Death01", "Death"])
	_dodge = _pick(names, ["Roll", "Sword_Dash", "Shield_Dash", "Slide_Start"])
	if not native:
		if _unit and _unit.is_melee:
			_attack = _alias(_attack, "Sword_Attack")
		else:
			_attack = _alias(_attack, "Spell_Simple_Shoot")
		_idle = _alias(_idle, "Idle")
		_walk = _alias(_walk, "Walk")
		_run = _alias(_run, "Jog_Fwd")
		_cast = _alias(_cast, "Spell_Simple_Shoot")
		_death = _alias(_death, "Death01")
		if _dodge != &"":
			_dodge = _alias(_dodge, "Roll")
	_set_loop(_idle, true)
	_set_loop(_walk, true)
	_set_loop(_run, true)
	_set_loop(_attack, false)
	_set_loop(_cast, false)
	_set_loop(_death, false)
	_set_loop(_dodge, false)
	if not native:
		_prepare_loco_clip(_idle)
		_prepare_loco_clip(_walk)
		_prepare_loco_clip(_run)
		_prepare_loco_clip(_dodge)
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE


func _leaf(anim_name: String) -> String:
	var i := anim_name.rfind("/")
	return anim_name.substr(i + 1) if i >= 0 else anim_name


func _pick(names: PackedStringArray, hints: Array) -> StringName:
	for hint in hints:
		var h := String(hint).to_lower()
		for n in names:
			if _leaf(n).to_lower() == h:
				return StringName(n)
	for hint in hints:
		var h := String(hint).to_lower()
		for n in names:
			if _leaf(n).to_lower().find(h) >= 0:
				return StringName(n)
	return &""


func _alias(src: StringName, dest: String) -> StringName:
	if src == &"" or _player == null or not _player.has_animation(src):
		return src
	var lib: AnimationLibrary
	if _player.has_animation_library(&""):
		lib = _player.get_animation_library(&"")
	else:
		lib = AnimationLibrary.new()
		_player.add_animation_library(&"", lib)
	if not lib.has_animation(dest):
		lib.add_animation(dest, _player.get_animation(src).duplicate(true))
	return StringName(dest)


func _set_loop(clip: StringName, loop: bool) -> void:
	if clip == &"" or _player == null or not _player.has_animation(clip):
		return
	var anim := _player.get_animation(clip)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


func _setup_screen_lod() -> void:
	if _unit == null or _unit.is_boss or _unit.is_champion:
		return
	var n := VisibleOnScreenNotifier3D.new()
	n.aabb = AABB(Vector3(-1.4, -0.2, -1.4), Vector3(2.8, 3.4, 2.8))
	add_child(n)
	n.screen_entered.connect(_on_screen_entered)
	n.screen_exited.connect(_on_screen_exited)


func _on_screen_entered() -> void:
	_on_screen = true
	set_process(true)
	if _player:
		_player.active = true
		_player.speed_scale = 1.0


func _on_screen_exited() -> void:
	if _unit != null and (_unit.is_boss or _unit.is_champion or _unit.is_dead):
		return
	_on_screen = false
	if _player:
		_player.active = false
	set_process(false)


func _process(delta: float) -> void:
	if not _on_screen:
		return
	if _unit == null or _player == null:
		return
	if _unit.is_dead:
		_ensure_death()
		return
	if _dodge_left > 0.0:
		_dodge_left = maxf(0.0, _dodge_left - delta)
		return
	if _frozen or _unit.is_stunned():
		if _player:
			_player.speed_scale = 0.0
			_player.pause()
		return
	var winding := _unit.auto_attack != null and _unit.auto_attack.winding
	if winding:
		if not _was_winding:
			_start_attack_anim()
		_was_winding = true
		_running = false
		return
	if _was_winding:
		_was_winding = false
		_aa_recover = 0.22
	if _aa_recover > 0.0:
		_aa_recover = maxf(0.0, _aa_recover - delta)
		var planar := Vector3(_unit.velocity.x, 0.0, _unit.velocity.z).length()
		if planar > 0.9:
			_aa_recover = 0.0
		else:
			_running = false
			return
	if _unit.controller and _unit.controller.is_casting():
		_running = false
		_reset_speed()
		_play(_cast if _cast != &"" else _attack, false)
		return
	if _boss_is_casting():
		_running = false
		_reset_speed()
		_play(_cast if _cast != &"" else _attack, false)
		return
	_reset_speed()
	_update_loco(delta)


func _prepare_loco_clip(clip: StringName) -> void:
	if clip == &"" or _player == null or not _player.has_animation(clip):
		return
	var anim := _player.get_animation(clip)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in anim.get_track_count():
		anim.track_set_interpolation_type(i, Animation.INTERPOLATION_LINEAR)
		if anim.has_method("track_set_interpolation_loop_wrap"):
			anim.track_set_interpolation_loop_wrap(i, false)
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var path := String(anim.track_get_path(i))
		var bone := path.get_slice(":", 1) if path.find(":") >= 0 else path
		if bone != "root" and bone != "Root":
			continue
		for k in anim.track_get_key_count(i):
			var v: Vector3 = anim.track_get_key_value(i, k)
			anim.track_set_key_value(i, k, Vector3(0.0, v.y, 0.0))


func _update_loco(delta: float) -> void:
	var planar := Vector3(_unit.velocity.x, 0.0, _unit.velocity.z).length()
	var commanded := 0.0
	if _unit.movement:
		commanded = _unit.movement.current_speed
	var moving := commanded > 0.7 or planar > 0.7
	if moving:
		_still_time = 0.0
		if not _running:
			_play_loco(true)
	else:
		_still_time += delta
		if _still_time >= 0.1 and _running:
			_play_loco(false)


func _boss_is_casting() -> bool:
	if _unit == null or not _unit.is_boss:
		return false
	for child in _unit.get_children():
		if child.has_method("is_showing_ability") and child.is_showing_ability():
			return true
	return false


func play_dodge(duration: float) -> void:
	_dodge_left = maxf(duration, 0.08)
	_running = false
	_aa_recover = 0.0
	if _dodge == &"" or _player == null or not _player.has_animation(_dodge):
		return
	_set_loop(_dodge, false)
	var anim := _player.get_animation(_dodge)
	var length := anim.length if anim else duration
	_player.speed_scale = maxf(length / maxf(duration, 0.08), 1.0)
	_player.play(_dodge, 0.04)
	_player.seek(0.0, true)


func _play_loco(should_run: bool) -> void:
	var clip := _idle
	if should_run:
		if _run != &"":
			clip = _run
		elif _walk != &"":
			clip = _walk
	if clip == &"" or not _player.has_animation(clip):
		return
	if _is_playing_clip(clip):
		_running = should_run
		return
	_set_loop(clip, true)
	_reset_speed()
	_player.play(clip, 0.08)
	_running = should_run


func _is_playing_clip(clip: StringName) -> bool:
	if _player == null or clip == &"":
		return false
	var cur := _leaf(String(_player.current_animation))
	var assigned := _leaf(String(_player.assigned_animation))
	var want := _leaf(String(clip))
	if cur == want:
		return true
	return _player.is_playing() and assigned == want


func _ensure_death() -> void:
	if _corpse or _death == &"" or not _player.has_animation(_death):
		return
	if _death_started:
		if not _player.is_playing():
			_freeze_corpse()
		return
	_death_started = true
	_set_loop(_death, false)
	_player.play(_death, 0.08)


func _on_animation_finished(anim_name: StringName) -> void:
	if _unit == null or not _unit.is_dead:
		return
	if _leaf(String(anim_name)).to_lower().find("death") < 0 and anim_name != _death:
		return
	_freeze_corpse()


func _freeze_corpse() -> void:
	_corpse = true
	_busy = false
	if _player == null or _death == &"" or not _player.has_animation(_death):
		return
	var anim := _player.get_animation(_death)
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_NONE
	_player.play(_death)
	_player.seek(anim.length, true)
	_player.pause()


func _play(clip: StringName, _loop: bool) -> void:
	if clip == &"" or _player == null:
		return
	if not _player.has_animation(clip):
		return
	var cur := StringName(_player.current_animation)
	if cur == clip and _player.is_playing():
		return
	_reset_speed()
	_player.play(clip, 0.06)


func _reset_speed() -> void:
	if _player:
		_player.speed_scale = 1.0


func _start_attack_anim() -> void:
	if _attack == &"" or _player == null or not _player.has_animation(_attack):
		return
	_aa_recover = 0.0
	_player.speed_scale = 1.85
	_player.play(_attack, 0.02)
	_player.seek(0.0, true)


func set_hover_outline(enabled: bool, color: Color = Color(1.0, 0.82, 0.28, 0.92), width: float = 0.01) -> void:
	_hover_on = enabled
	if enabled:
		_ensure_hover_mat()
		_hover_mat.set_shader_parameter("outline_color", color)
		_hover_mat.set_shader_parameter("width", width)
	_sync_overlays()


func set_infusion_tint(color: Color, strength: float = 0.55) -> void:
	_infusion_on = strength > 0.02 and color.a > 0.02
	if _infusion_on:
		_ensure_infusion_mat()
		_infusion_mat.set_shader_parameter("tint_color", color)
		_infusion_mat.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	_sync_overlays()


func set_freeze_tint(enabled: bool, color: Color = Color(0.62, 0.9, 1.0, 1.0)) -> void:
	var was_frozen := _frozen
	_frozen = enabled
	if enabled:
		_ensure_freeze_mat()
		_freeze_mat.set_shader_parameter("tint_color", color)
		_freeze_mat.set_shader_parameter("strength", 0.92)
		if _player:
			_player.speed_scale = 0.0
			_player.pause()
	elif was_frozen and _player:
		_player.speed_scale = 1.0
		if not _player.is_playing() and String(_player.current_animation) != "":
			_player.play()
	_sync_overlays()


func _sync_overlays() -> void:
	var overlay: Material = null
	if _frozen and _freeze_mat:
		_freeze_mat.next_pass = _hover_mat if _hover_on else null
		if _infusion_mat:
			_infusion_mat.next_pass = null
		overlay = _freeze_mat
	elif _infusion_on and _infusion_mat:
		_infusion_mat.next_pass = _hover_mat if _hover_on else null
		if _freeze_mat:
			_freeze_mat.next_pass = null
		overlay = _infusion_mat
	elif _hover_on:
		if _infusion_mat:
			_infusion_mat.next_pass = null
		if _freeze_mat:
			_freeze_mat.next_pass = null
		overlay = _hover_mat
	else:
		if _infusion_mat:
			_infusion_mat.next_pass = null
		if _freeze_mat:
			_freeze_mat.next_pass = null
	for mi in _hover_meshes:
		if not is_instance_valid(mi):
			continue
		if overlay:
			mi.material_overlay = overlay
		elif mi.material_overlay == _hover_mat or mi.material_overlay == _infusion_mat or mi.material_overlay == _freeze_mat:
			mi.material_overlay = null


func _ensure_hover_mat() -> void:
	if _hover_mat:
		return
	_hover_mat = ShaderMaterial.new()
	_hover_mat.shader = _HOVER_SHADER


func _ensure_infusion_mat() -> void:
	if _infusion_mat:
		return
	_infusion_mat = ShaderMaterial.new()
	_infusion_mat.shader = _INFUSION_SHADER


func _ensure_freeze_mat() -> void:
	if _freeze_mat:
		return
	_freeze_mat = ShaderMaterial.new()
	_freeze_mat.shader = _FREEZE_SHADER


func _cache_hover_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh:
			_hover_meshes.append(mi)
	for c in n.get_children():
		_cache_hover_meshes(c)


func muzzle_point() -> Vector3:
	if _skel and _hand_bone >= 0:
		var local := _skel.get_bone_global_pose(_hand_bone)
		var world := _skel.global_transform * local
		return world.origin
	if _unit:
		return _unit.global_position + Vector3(0.0, _unit.height * 0.72, 0.0) + _unit.facing_dir() * 0.12
	return global_position


func _cache_skeleton(n: Node) -> void:
	_skel = _find_skel(n)
	if _skel == null:
		return
	var hints := ["hand_r", "Hand_R", "RightHand", "mixamorig:RightHand", "hand.R"]
	for hint in hints:
		var idx := _skel.find_bone(hint)
		if idx >= 0:
			_hand_bone = idx
			return
	for i in _skel.get_bone_count():
		var nm := _skel.get_bone_name(i).to_lower()
		if nm.find("hand") >= 0 and (nm.ends_with("r") or nm.find("right") >= 0):
			_hand_bone = i
			return


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var found := _find_skel(c)
		if found:
			return found
	return null


func set_stealthed(on: bool) -> void:
	_fade_model(self, 0.80 if on else 0.0)


func recolor(color: Color, emit: float = 1.8) -> void:
	for mi in _hover_meshes:
		if not is_instance_valid(mi) or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var key := "%d|%.3f|%.3f|%.3f|%.2f" % [mat.get_instance_id(), color.r, color.g, color.b, emit]
				var bm: BaseMaterial3D
				if _recolor_cache.has(key):
					bm = _recolor_cache[key]
				else:
					bm = (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					bm.albedo_color = color
					bm.emission_enabled = true
					bm.emission = color
					bm.emission_energy_multiplier = emit
					_recolor_cache[key] = bm
				mi.set_surface_override_material(i, bm)
			elif mat is ShaderMaterial:
				var key := "s%d|%.3f|%.3f|%.3f" % [mat.get_instance_id(), color.r, color.g, color.b]
				var sm: ShaderMaterial
				if _recolor_cache.has(key):
					sm = _recolor_cache[key]
				else:
					sm = (mat as ShaderMaterial).duplicate() as ShaderMaterial
					if sm.get_shader_parameter("albedo") != null:
						sm.set_shader_parameter("albedo", color)
					if sm.get_shader_parameter("albedo_color") != null:
						sm.set_shader_parameter("albedo_color", color)
					if sm.get_shader_parameter("emission") != null:
						sm.set_shader_parameter("emission", color)
					_recolor_cache[key] = sm
				mi.set_surface_override_material(i, sm)


func _fade_model(n: Node, fade: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = fade
	for c in n.get_children():
		_fade_model(c, fade)
