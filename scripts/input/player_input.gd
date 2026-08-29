class_name PlayerInput
extends Node

enum TargetMode { NONE, SKILLSHOT, UNIT, GROUND, ATTACK_MOVE }

var targeting: TargetMode = TargetMode.NONE
var targeting_index: int = -1

var _overlay: TargetingOverlay
var _click_fx: ClickMarker
var _hud_blocking: bool = false
var _rmb_held: bool = false
var _hold_accum: float = 0.0
var _hold_fx_accum: float = 0.0
var _hold_mouse: Vector2 = Vector2.ZERO
var _hover_units: Array[Unit] = []
var _target_cursor: Texture2D
var _lmb_down: bool = false
var _rmb_down: bool = false

const _ENEMY_HOVER := Color(1.0, 0.45, 0.08, 0.92)
const _TARGET_HOVER := Color(1.0, 0.92, 0.18, 0.95)
const _ATTACK_CLICK_ACQUIRE := 4.2


var _aim_unit: Unit = null
var _aim_ground: Vector3 = Vector3.ZERO
var _aim_from_frame: bool = false
var _aim_unit_at_ms: int = 0
var _aim_ready: bool = false

const _AIM_GRACE_MS := 800


func _ready() -> void:
	add_to_group("player_input")
	_overlay = TargetingOverlay.new()
	add_child(_overlay)
	_click_fx = ClickMarker.new()
	add_child(_click_fx)
	_target_cursor = _make_target_cursor()


func _unit() -> Unit:
	return GameSession.active_unit as Unit


func _process(delta: float) -> void:
	if not GameSession.fight_started:
		_clear_hover()
		_show_target_cursor(false)
		_reset_mouse_edges()
		_clear_aim_cache()
		return
	var u := _unit()
	if u == null or u.is_dead:
		_overlay.hide_fx()
		_overlay.hide_lock()
		_rmb_held = false
		_clear_hover()
		_show_target_cursor(false)
		_reset_mouse_edges()
		_clear_aim_cache()
		return
	_refresh_aim_cache()
	# Button events often never reach _input (HUD Controls mark them handled).
	# Hardware button state still updates, so poll edges here.
	_poll_mouse(u)
	_tick_rmb_hold(delta, u)
	var channeling := u.controller != null and u.controller.is_channeling()
	if channeling:
		var ch_ab := u.controller.casting_ability()
		if ch_ab:
			_overlay.show_locked_aoe(
				u,
				u.controller.cast_point,
				ch_ab.scaled_radius(u.controller.channel_charge()),
				ch_ab.color
			)
		else:
			_overlay.hide_lock()
	else:
		_overlay.hide_lock()
	if targeting == TargetMode.NONE:
		if not channeling:
			_overlay.hide_fx()
		_refresh_hover(u, u.controller.casting_ability() if channeling else null, channeling)
		_show_target_cursor(false)
		return
	var ground := ground_at_mouse()
	var ab: AbilityDef = null
	if targeting_index >= 0 and targeting_index < u.abilities.size():
		ab = u.abilities[targeting_index]
	match targeting:
		TargetMode.SKILLSHOT:
			if ab:
				_overlay.show_skillshot(u, ground, ab)
		TargetMode.GROUND:
			if ab:
				_overlay.show_ground(u, ground, ab)
		TargetMode.UNIT:
			if ab:
				_overlay.show_range(u, ab.range)
		TargetMode.ATTACK_MOVE:
			_overlay.show_range(u, u.attack_range)
	_refresh_hover(u, ab)
	_show_target_cursor(true)


func _input(event: InputEvent) -> void:
	if not GameSession.fight_started:
		return
	if ArenaState.outcome != "":
		return
	var u := _unit()
	if u == null or u.is_dead:
		return
	if event.is_action_pressed("dodge"):
		var ground := ground_at_mouse()
		var dir := ground - u.global_position
		dir.y = 0.0
		u.controller.issue_dodge(dir)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("stop_command"):
		_cancel_targeting()
		if not u.controller.is_channeling():
			u.controller.issue_stop_local()
		else:
			u.controller.clear_cast_queue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("clear_target"):
		var hud := get_tree().get_first_node_in_group("combat_hud")
		if hud and hud.has_method("handle_escape"):
			hud.call("handle_escape")
		else:
			GameSession.clear_selected_target()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack_move"):
		targeting = TargetMode.ATTACK_MOVE
		targeting_index = -1
		_show_target_cursor(true)
		get_viewport().set_input_as_handled()
		return
	if _ability_press(event, "ability_q", 0, u):
		return
	if _ability_press(event, "ability_w", 1, u):
		return
	if _ability_press(event, "ability_e", 2, u):
		return
	if _ability_press(event, "ability_r", 3, u):
		return
	if _ability_press(event, "ability_d", 4, u):
		return
	if _ability_press(event, "ability_f", 5, u):
		return


func try_activate_ability(index: int, from_bar: bool = false) -> bool:
	if not GameSession.fight_started or ArenaState.outcome != "":
		return false
	var u := _unit()
	if u == null or u.is_dead:
		return false
	return _activate_ability(u, index, from_bar)


func _reset_mouse_edges() -> void:
	_lmb_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_rmb_down = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if not _rmb_down:
		_rmb_held = false


func _poll_mouse(u: Unit) -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var over_ui := _mouse_over_blocking_hud()
	if lmb and not _lmb_down:
		if _on_party_frame_click(u):
			pass
		elif not over_ui:
			_on_left_click(u)
	if rmb and not _rmb_down and not over_ui:
		_rmb_held = true
		_hold_accum = 0.0
		_hold_fx_accum = 0.0
		_hold_mouse = get_viewport().get_mouse_position()
		_on_right_click(u)
	if not rmb:
		_rmb_held = false
	_lmb_down = lmb
	_rmb_down = rmb


func _mouse_over_blocking_hud() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	if hovered is BaseButton or hovered is Range:
		return true
	var node: Node = hovered
	while node:
		if node.is_in_group("hud_block_world"):
			return true
		node = node.get_parent()
	return false


func _tick_rmb_hold(delta: float, u: Unit) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rmb_held = false
		return
	if not _rmb_held or targeting != TargetMode.NONE or ArenaState.outcome != "":
		return
	_hold_accum += delta
	if _hold_accum < 0.15 and get_viewport().get_mouse_position().distance_to(_hold_mouse) < 10.0:
		return
	# Hold-drag is always a move-to-cursor. Attacking on hover was canceling kites.
	var pos := ground_at_mouse()
	u.controller.issue_move_hold(pos)
	_hold_fx_accum += delta
	if _hold_fx_accum >= 0.16:
		_hold_fx_accum = 0.0
		_click_fx.ping(pos, Color(0.3, 0.95, 0.45))


func _ability_press(event: InputEvent, action: String, index: int, u: Unit) -> bool:
	if event is InputEventMouseButton:
		return false
	if not event.is_action_pressed(action, false):
		return false
	get_viewport().set_input_as_handled()
	_activate_ability(u, index, false)
	return true


func _activate_ability(u: Unit, index: int, from_bar: bool) -> bool:
	if u.controller == null or index < 0 or index >= u.abilities.size():
		return false
	if u.controller.is_channeling() and u.controller.cast_index == index:
		u.controller.confirm_channel()
		_cancel_targeting()
		return true
	if not u.can_prepare_cast(index):
		return true
	var ab: AbilityDef = u.abilities[index]
	if ab.target_mode == AbilityDef.TargetMode.INSTANT:
		u.controller.issue_cast_local(index, u.global_position, null)
		_cancel_targeting()
		return true
	if _alt_held() and ab.can_self_cast():
		u.controller.issue_cast_local(index, u.global_position, u)
		_cancel_targeting()
		return true
	if GameSession.smart_cast and not _shift_held():
		if _smart_fire(u, index, ab, from_bar):
			return true
	_begin_targeting(index, ab)
	return true


func _begin_targeting(index: int, ab: AbilityDef) -> void:
	targeting_index = index
	match ab.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
			targeting = TargetMode.SKILLSHOT
		AbilityDef.TargetMode.UNIT:
			targeting = TargetMode.UNIT
		AbilityDef.TargetMode.GROUND:
			targeting = TargetMode.GROUND
		_:
			targeting = TargetMode.NONE
	_show_target_cursor(true)


func _smart_fire(u: Unit, index: int, ab: AbilityDef, from_bar: bool) -> bool:
	_refresh_aim_cache()
	var target := _smart_aim_unit(from_bar)
	var ground := _smart_aim_ground(from_bar, target)
	match ab.target_mode:
		AbilityDef.TargetMode.SKILLSHOT:
			if from_bar and not _aim_ready:
				return false
			u.controller.issue_cast_local(index, ground, null)
			_click_fx.ping(ground, ab.color)
			_cancel_targeting()
			return true
		AbilityDef.TargetMode.GROUND:
			if from_bar and not _aim_ready:
				return false
			ground = u.clamped_ground_point(ground, ab.range)
			u.controller.issue_cast_local(index, ground, null)
			_click_fx.ping(ground, ab.color)
			_cancel_targeting()
			return true
		AbilityDef.TargetMode.UNIT:
			if ab.is_ally_support():
				if target != null and target.team != u.team:
					return false
				if target == null:
					target = u
			else:
				if target == null or target.team == u.team:
					var locked := GameSession.selected_target
					if locked and is_instance_valid(locked) and not locked.is_dead and locked.team != u.team:
						target = locked
					else:
						return false
			GameSession.select_target(target)
			u.controller.issue_cast_local(index, target.global_position, target)
			_click_fx.ping(target.global_position, ab.color)
			_cancel_targeting()
			return true
		_:
			return false


func _smart_aim_unit(from_bar: bool) -> Unit:
	var party := _party_unit_at_mouse()
	if party:
		return party
	if from_bar:
		return _cached_aim_unit()
	if _mouse_over_ability_bar():
		return _cached_aim_unit()
	return unit_at_mouse()


func _smart_aim_ground(from_bar: bool, target: Unit) -> Vector3:
	var party := _party_unit_at_mouse()
	if party:
		return party.global_position
	if target and (from_bar or _aim_from_frame):
		return target.global_position
	if from_bar or _mouse_over_ability_bar():
		if _aim_ready:
			return _aim_ground
		if target:
			return target.global_position
		return Vector3.ZERO
	return ground_at_mouse()


func _cached_aim_unit() -> Unit:
	if _aim_unit == null or not is_instance_valid(_aim_unit) or _aim_unit.is_dead:
		return null
	if Time.get_ticks_msec() - _aim_unit_at_ms > _AIM_GRACE_MS:
		return null
	return _aim_unit


func _refresh_aim_cache() -> void:
	var party := _party_unit_at_mouse()
	if party:
		_aim_unit = party
		_aim_ground = party.global_position
		_aim_from_frame = true
		_aim_unit_at_ms = Time.get_ticks_msec()
		_aim_ready = true
		return
	if _mouse_over_ability_bar():
		return
	if _mouse_over_blocking_hud():
		return
	_aim_from_frame = false
	_aim_ground = ground_at_mouse()
	_aim_ready = true
	var hovered := unit_at_mouse()
	if hovered:
		_aim_unit = hovered
		_aim_unit_at_ms = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _aim_unit_at_ms > _AIM_GRACE_MS:
		_aim_unit = null


func _clear_aim_cache() -> void:
	_aim_unit = null
	_aim_ground = Vector3.ZERO
	_aim_from_frame = false
	_aim_unit_at_ms = 0
	_aim_ready = false


func _mouse_over_ability_bar() -> bool:
	var hud := _combat_hud()
	if hud and hud.has_method("is_mouse_over_ability_bar"):
		return bool(hud.call("is_mouse_over_ability_bar"))
	return false


func _alt_held() -> bool:
	return Input.is_physical_key_pressed(KEY_ALT) or Input.is_key_pressed(KEY_ALT)


func _shift_held() -> bool:
	return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SHIFT)


func _on_party_frame_click(u: Unit) -> bool:
	var frame_unit := _party_unit_at_mouse()
	if frame_unit == null:
		return false
	if targeting == TargetMode.UNIT:
		GameSession.select_target(frame_unit)
		_confirm_ability(u, frame_unit)
		get_viewport().set_input_as_handled()
		return true
	if targeting == TargetMode.ATTACK_MOVE:
		if not frame_unit.is_dead and (frame_unit.team != u.team or u.can_attack_ally()):
			GameSession.select_target(frame_unit)
			u.controller.issue_attack_local(frame_unit)
			_click_fx.ping(frame_unit.global_position, Color(0.35, 0.95, 0.45))
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return true
	if targeting != TargetMode.NONE:
		get_viewport().set_input_as_handled()
		return true
	GameSession.select_target(frame_unit)
	get_viewport().set_input_as_handled()
	return true


func _on_left_click(u: Unit) -> void:
	if targeting == TargetMode.ATTACK_MOVE:
		var pos := ground_at_mouse()
		var other := unit_at_mouse()
		if other == null or other.is_dead:
			other = _attackable_near_point(u, pos)
		if other and not other.is_dead and (other.team != u.team or u.can_attack_ally()):
			GameSession.select_target(other)
			u.controller.issue_attack_local(other)
			var ping := Color(0.35, 0.95, 0.45) if other.team == u.team else Color(1.0, 0.25, 0.2)
			_click_fx.ping(other.global_position, ping)
		else:
			u.controller.issue_attack_move_local(pos)
			_click_fx.ping(pos, Color(1.0, 0.3, 0.3))
		_cancel_targeting()
		get_viewport().set_input_as_handled()
		return
	if targeting != TargetMode.NONE:
		if targeting == TargetMode.UNIT:
			var aimed := unit_at_mouse()
			if aimed:
				GameSession.select_target(aimed)
		_confirm_ability(u)
		get_viewport().set_input_as_handled()
		return
	if _is_mid_cast(u):
		get_viewport().set_input_as_handled()
		return
	var picked := unit_at_mouse()
	if picked:
		GameSession.select_target(picked)
		get_viewport().set_input_as_handled()


func _is_mid_cast(u: Unit) -> bool:
	return u.controller != null and (u.controller.is_casting() or u.controller.is_channeling())


func _on_right_click(u: Unit) -> void:
	var hud := _combat_hud()
	if hud and hud.has_method("try_dismiss_hovered_player_buff") and hud.call("try_dismiss_hovered_player_buff", u):
		_rmb_held = false
		get_viewport().set_input_as_handled()
		return
	if hud and hud.has_method("try_frame_context_menu") and hud.call("try_frame_context_menu"):
		_rmb_held = false
		get_viewport().set_input_as_handled()
		return
	if targeting != TargetMode.NONE:
		_cancel_targeting()
	var pos := ground_at_mouse()
	u.controller.issue_move_local(pos)
	_click_fx.ping(pos, Color(0.3, 0.95, 0.45))
	get_viewport().set_input_as_handled()


func _confirm_ability(u: Unit, forced_target: Unit = null) -> void:
	if targeting_index < 0:
		_cancel_targeting()
		return
	var ab: AbilityDef = u.abilities[targeting_index]
	var target := forced_target
	var ground := ground_at_mouse()
	if target:
		ground = target.global_position
	else:
		target = unit_at_mouse()
	match targeting:
		TargetMode.SKILLSHOT:
			u.controller.issue_cast_local(targeting_index, ground, null)
		TargetMode.GROUND:
			ground = u.clamped_ground_point(ground, ab.range)
			u.controller.issue_cast_local(targeting_index, ground, null)
		TargetMode.UNIT:
			if ab.is_ally_support():
				if target != null and target.team != u.team:
					_cancel_targeting()
					return
				if target == null:
					target = u
			elif target == null or target.team == u.team:
				_cancel_targeting()
				return
			u.controller.issue_cast_local(targeting_index, target.global_position, target)
		_:
			pass
	_click_fx.ping(ground if target == null else target.global_position, ab.color)
	_cancel_targeting()


func _cancel_targeting() -> void:
	targeting = TargetMode.NONE
	targeting_index = -1
	_overlay.hide_fx()
	_clear_hover()
	_show_target_cursor(false)


func _show_target_cursor(on: bool) -> void:
	if on and _target_cursor:
		Input.set_custom_mouse_cursor(_target_cursor, Input.CURSOR_ARROW, Vector2(16, 16))
	else:
		Input.set_custom_mouse_cursor(null)


func _make_target_cursor() -> Texture2D:
	var s := 32
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1.0, 0.92, 0.45, 0.95)
	var r_outer := 12.0
	var r_inner := 9.5
	var cx := 15.5
	var cy := 15.5
	for y in s:
		for x in s:
			var dx := float(x) - cx
			var dy := float(y) - cy
			var d := sqrt(dx * dx + dy * dy)
			if d <= r_outer and d >= r_inner:
				img.set_pixel(x, y, c)
			elif absf(dx) <= 1.0 and absf(dy) >= 4.0 and absf(dy) <= 14.0:
				img.set_pixel(x, y, c)
			elif absf(dy) <= 1.0 and absf(dx) >= 4.0 and absf(dx) <= 14.0:
				img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _refresh_hover(caster: Unit, ab: AbilityDef = null, locked_aoe: bool = false) -> void:
	var wanted: Dictionary = {}
	if ab and (locked_aoe or targeting == TargetMode.GROUND or targeting == TargetMode.SKILLSHOT):
		var spell_c := ab.color.lightened(0.18)
		spell_c.a = 0.92
		for u in _preview_aoe_units(caster, ab, locked_aoe):
			wanted[u] = spell_c
	var hovered := _party_unit_at_mouse()
	if hovered == null:
		hovered = unit_at_mouse()
	if hovered and not hovered.is_dead:
		if ab and targeting != TargetMode.ATTACK_MOVE and not locked_aoe:
			var spell_target := _ability_hover_target(caster, ab)
			if spell_target:
				wanted[spell_target] = _hover_color(ab, spell_target, caster)
			elif hovered.team != caster.team and not wanted.has(hovered):
				wanted[hovered] = _ENEMY_HOVER
		elif hovered.team == caster.team and caster.can_attack_ally() and targeting == TargetMode.ATTACK_MOVE:
			wanted[hovered] = Color(0.35, 0.95, 0.45, 0.92)
		elif hovered.team != caster.team and not wanted.has(hovered):
			wanted[hovered] = _ENEMY_HOVER
	var locked := GameSession.selected_target
	if locked and is_instance_valid(locked) and not locked.is_dead:
		wanted[locked] = _TARGET_HOVER
	_apply_hovers(wanted)


func _preview_aoe_units(caster: Unit, ab: AbilityDef, locked_aoe: bool) -> Array[Unit]:
	var out: Array[Unit] = []
	if locked_aoe:
		if caster.controller == null:
			return out
		return _units_in_circle(caster, caster.controller.cast_point, ab.scaled_radius(caster.controller.channel_charge()))
	if targeting == TargetMode.GROUND:
		var pos := caster.clamped_ground_point(ground_at_mouse(), ab.range)
		return _units_in_circle(caster, pos, ab.aoe_radius)
	if targeting != TargetMode.SKILLSHOT:
		return out
	var aim := ground_at_mouse()
	var dir := aim - caster.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = caster.facing_dir()
	dir = dir.normalized()
	if ab.is_cone():
		return _units_in_cone(caster, dir, ab)
	var max_len := minf(ab.skillshot_length, ab.range) if ab.skillshot_length > 0.05 else ab.range
	max_len = caster.wall_travel_distance(dir, max_len)
	var length := max_len
	if ab.splash_radius > 0.05:
		var to_cursor := Vector2(aim.x - caster.global_position.x, aim.z - caster.global_position.z).length()
		length = clampf(to_cursor, 0.4, max_len)
	var start: Vector3 = caster.global_position
	var end: Vector3 = caster.global_position + dir * length
	var half_w := ab.skillshot_width * 0.5
	for raw in ArenaState.units:
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u == caster:
			continue
		if u.team == caster.team:
			continue
		var along := _dist_to_xz_segment(u.global_position, start, end)
		var in_shot := along <= half_w + u.radius
		var in_splash := ab.splash_radius > 0.05 and u.global_position.distance_to(end) <= ab.splash_radius + u.radius
		if in_shot or in_splash:
			out.append(u)
	return out


func _units_in_circle(caster: Unit, point: Vector3, radius: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for raw in ArenaState.units:
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u == caster:
			continue
		if u.team == caster.team:
			continue
		if u.global_position.distance_to(point) > radius + u.radius:
			continue
		if not caster._burst_has_los(point, u.global_position):
			continue
		out.append(u)
	return out


func _units_in_cone(caster: Unit, dir: Vector3, ab: AbilityDef) -> Array[Unit]:
	var out: Array[Unit] = []
	var length := ab.range if ab.range > 0.05 else ab.skillshot_length
	var half := ab.cone_angle * 0.5
	for raw in ArenaState.units:
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u == caster:
			continue
		if u.team == caster.team:
			continue
		var to := u.global_position - caster.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > length + u.radius:
			continue
		if dist > 0.04:
			var ang := absf(dir.signed_angle_to(to.normalized(), Vector3.UP))
			var extra := atan2(u.radius, maxf(dist, 0.01))
			if ang > half + extra:
				continue
		if not caster.has_wall_los(u.global_position):
			continue
		out.append(u)
	return out


func _dist_to_xz_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len_sq := ab.length_squared()
	var t := 0.0 if len_sq < 0.0001 else clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
	return Vector2(p.x, p.z).distance_to(Vector2(a.x, a.z) + ab * t)


func _apply_hovers(wanted: Dictionary) -> void:
	for old in _hover_units:
		if old and is_instance_valid(old) and not wanted.has(old):
			old.set_ability_hover(false)
	_hover_units.clear()
	for u in wanted.keys():
		var unit := u as Unit
		if unit == null or not is_instance_valid(unit) or unit.is_dead:
			continue
		unit.set_ability_hover(true, wanted[u])
		_hover_units.append(unit)


func _party_unit_at_mouse() -> Unit:
	var hud := _combat_hud()
	if hud == null or not hud.has_method("party_unit_under_mouse"):
		return null
	return hud.call("party_unit_under_mouse") as Unit


func _ability_hover_target(caster: Unit, ab: AbilityDef) -> Unit:
	var other := _party_unit_at_mouse()
	if other == null:
		other = unit_at_mouse()
	if other == null or other.is_dead:
		return null
	if other.team == caster.team:
		if ab == null or (ab.heal <= 0.0 and ab.shield <= 0.0):
			return null
		return other
	if ab != null and ab.is_ally_support():
		return null
	return other


func _hover_color(ab: AbilityDef, target: Unit, caster: Unit) -> Color:
	var c := ab.color
	if target.team == caster.team:
		c = Color(0.35, 0.95, 0.45)
	c.a = 0.92
	return c.lightened(0.18)


func _clear_hover() -> void:
	for old in _hover_units:
		if old and is_instance_valid(old):
			old.set_ability_hover(false)
	_hover_units.clear()


func _combat_hud() -> Node:
	return get_tree().get_first_node_in_group("combat_hud")


func ground_at_mouse() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse)
	var n := cam.project_ray_normal(mouse)
	if absf(n.y) < 0.001:
		return Vector3(from.x, 0.0, from.z)
	var t := -from.y / n.y
	var p := from + n * t
	p.y = 0.0
	return p


func _attackable_near_point(caster: Unit, point: Vector3) -> Unit:
	var best: Unit = null
	var best_d := _ATTACK_CLICK_ACQUIRE
	for raw in ArenaState.units:
		var other := raw as Unit
		if other == null or other == caster or not is_instance_valid(other) or other.is_dead:
			continue
		if other.team == caster.team and not caster.can_attack_ally():
			continue
		var d := point.distance_to(other.global_position) - other.radius
		if d < best_d:
			best_d = d
			best = other
	return best


func unit_at_mouse() -> Unit:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var self_unit := _unit()
	var best: Unit = null
	var best_score := INF
	for raw in ArenaState.units:
		var u := raw as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u == self_unit:
			continue
		var score := _unit_click_score(cam, mouse, u)
		if score < best_score:
			best_score = score
			best = u
	return best


func _unit_click_score(cam: Camera3D, mouse: Vector2, u: Unit) -> float:
	var feet: Vector3 = u.global_position
	var head: Vector3 = u.global_position + Vector3(0.0, u.height, 0.0)
	var plate: Vector3 = u.hp_anchor_world()
	if cam.is_position_behind(feet) and cam.is_position_behind(head) and cam.is_position_behind(plate):
		return INF
	var a := cam.unproject_position(feet)
	var b := cam.unproject_position(head)
	var plate_top := cam.unproject_position(plate + Vector3(0.0, 0.9, 0.0))
	var dist := minf(_dist_to_segment(mouse, a, b), _dist_to_segment(mouse, b, plate_top))
	if u.uses_feet_resource_bars():
		var feet_bar := cam.unproject_position(u.feet_anchor_world())
		dist = minf(dist, mouse.distance_to(feet_bar))
	var body_h := maxf(24.0, a.distance_to(b))
	var click_r := clampf(body_h * 0.42, 22.0, 52.0)
	var plate_rect := _nameplate_screen_rect(cam, u)
	var on_plate := plate_rect.has_point(mouse)
	if not on_plate and dist > click_r:
		return INF
	if on_plate:
		return minf(dist, mouse.distance_to(plate_rect.get_center()) * 0.35)
	return dist


func _nameplate_screen_rect(cam: Camera3D, u: Unit) -> Rect2:
	var started := false
	var r := Rect2()
	for p in u.nameplate_click_points():
		if cam.is_position_behind(p):
			continue
		var s := cam.unproject_position(p)
		if not started:
			r = Rect2(s, Vector2.ZERO)
			started = true
		else:
			r = r.expand(s)
	if not started:
		return Rect2()
	return r.grow(8.0)


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
