class_name Projectile
extends Area3D

var source: Unit
var damage: float = 0.0
var speed: float = 18.0
var max_distance: float = 14.0
var radius: float = 0.2
var direction: Vector3 = Vector3.FORWARD
var homing: Unit = null
var skillshot: bool = true
var traveled: float = 0.0
var authoritative: bool = true
var element: int = 0
var mark_damage_bonus: float = 0.0
var splash_radius: float = 0.0
var splash_ratio: float = 0.0
var splash_vfx: String = ""
var splash_vfx_scale: float = 0.5
var extra_elements: PackedInt32Array = PackedInt32Array()
var grant_charged: bool = false
var overheat_cast_id: int = -1
var combat_text_cast_id: int = -1
var infusion_double: int = 0
var ability_id: String = ""
var shield: float = 0.0
var shield_duration: float = 0.0
var heal_allies: bool = false
var heal: float = 0.0
var applies_rejuvenation: bool = false
var blessing_power: float = 0.0
var ally_cast: bool = false
var hit_cooldown_reduction: float = 0.0
var pierce: bool = false
var ghost_enemies: bool = false
var vfx_layers: Array = []
var arc_side: float = 0.0
var arc_width: float = 0.0
var arc_lift: float = 0.0
var arc_min: float = 0.0
var _arc_origin: Vector3 = Vector3.ZERO
var _arc_u: float = 0.0
var _resolved: bool = false
var _travel_sfx: int = 0
var _hit_ids: Dictionary = {}
var _landed: bool = false
var _fire_wall_amped: bool = false
var fire_wall_bonus: float = 0.0
var _wind_ignore: SpellWall = null
var _wind_bounce_u: float = -1.0
var _wind_out: Vector3 = Vector3.ZERO
var _portal_hops: int = 0
var _spawn_cfg: Dictionary = {}

const TEAM_RAID := 0
const SPLASH_PUSH := 0.9
const _FireboltFx := preload("res://scripts/visual/firebolt_fx.gd")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")


static func spawn(p_source: Unit, origin: Vector3, cfg: Dictionary) -> void:
	if p_source == null:
		return
	_make(p_source, origin, cfg, true)


static func _make(p_source: Unit, origin: Vector3, cfg: Dictionary, auth: bool) -> Projectile:
	var p := Projectile.new()
	p.source = p_source
	p.damage = float(cfg.get("damage", 0.0))
	p.speed = float(cfg.get("speed", 18.0))
	p.max_distance = float(cfg.get("max_distance", 16.0))
	p.radius = float(cfg.get("radius", 0.2))
	p.skillshot = bool(cfg.get("skillshot", true))
	p.element = int(cfg.get("element", 0))
	var extras = cfg.get("extra_elements", PackedInt32Array())
	if extras is PackedInt32Array:
		p.extra_elements = extras
	elif extras is Array:
		var packed := PackedInt32Array()
		for v in extras:
			packed.append(int(v))
		p.extra_elements = packed
	p.mark_damage_bonus = float(cfg.get("mark_damage_bonus", 0.0))
	p.splash_radius = float(cfg.get("splash_radius", 0.0))
	p.splash_ratio = float(cfg.get("splash_ratio", 0.0))
	p.splash_vfx = String(cfg.get("splash_vfx", ""))
	p.splash_vfx_scale = float(cfg.get("splash_vfx_scale", 0.5))
	p.grant_charged = bool(cfg.get("grant_charged", false))
	p.overheat_cast_id = int(cfg.get("overheat_cast_id", -1))
	p.combat_text_cast_id = int(cfg.get("combat_text_cast_id", -1))
	p.infusion_double = int(cfg.get("infusion_double", 0))
	p.ability_id = String(cfg.get("ability_id", ""))
	p.shield = float(cfg.get("shield", 0.0))
	p.shield_duration = float(cfg.get("shield_duration", 0.0))
	p.heal_allies = bool(cfg.get("heal_allies", false))
	p.heal = float(cfg.get("heal", 0.0))
	p.applies_rejuvenation = bool(cfg.get("applies_rejuvenation", false))
	p.blessing_power = float(cfg.get("blessing_power", 0.0))
	p.ally_cast = bool(cfg.get("ally_cast", false))
	p.hit_cooldown_reduction = float(cfg.get("hit_cooldown_reduction", 0.0))
	p.pierce = bool(cfg.get("pierce", false))
	p.ghost_enemies = bool(cfg.get("ghost_enemies", false))
	p.fire_wall_bonus = float(cfg.get("fire_wall_bonus", 0.0))
	p._fire_wall_amped = bool(cfg.get("fire_wall_amped", false)) or p.fire_wall_bonus > 0.05
	var layers = cfg.get("vfx_layers", [])
	if layers is Array:
		p.vfx_layers = layers
	p.authoritative = auth
	p.homing = cfg.get("homing", null)
	p.arc_side = float(cfg.get("arc_side", 0.0))
	p.arc_width = float(cfg.get("arc_width", 0.0))
	p.arc_lift = float(cfg.get("arc_lift", 0.0))
	p.arc_min = float(cfg.get("arc_min", 0.0))
	p._arc_origin = origin
	p._spawn_cfg = cfg.duplicate(true)
	if cfg.has("direction"):
		p.direction = Vector3(cfg["direction"]).normalized()
	elif p.homing:
		p.direction = (p._arc_aim() - origin).slide(Vector3.UP).normalized()
	else:
		p.direction = p_source.facing_dir()
	if not bool(cfg.get("portal_exit", false)) and p._uses_arc() and p.homing and is_instance_valid(p.homing):
		var launch := p._arc_point(p._arc_aim(), 0.16) - origin
		if launch.length_squared() > 0.0001:
			p.direction = launch.normalized()
	p.collision_layer = 4
	p.collision_mask = SpellWall.shot_block_mask()
	if p.skillshot:
		p.collision_mask |= 2
	p.monitoring = auth
	var shape := SphereShape3D.new()
	shape.radius = p.radius
	var col := CollisionShape3D.new()
	col.shape = shape
	p.add_child(col)
	var used_vfx := false
	var wave_ab := p_source._ability_def(p.ability_id) if p_source != null else null
	if AbilityDef.matches_base(p.ability_id, "wave") or (wave_ab != null and wave_ab.delivery == AbilityDef.Delivery.WAVE):
		var pal := SpellBaseFx.palette(wave_ab) if wave_ab != null else {"core": Color(0.62, 0.82, 1.0), "rim": Color(0.32, 0.55, 0.95)}
		WaveFx.attach(p, p.radius * 2.0, pal.core, pal.rim)
		used_vfx = true
	else:
		used_vfx = SpellVfx.attach_projectile(p, cfg)
	if not used_vfx:
		var mesh := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = p.radius
		sm.height = p.radius * 2.0
		mesh.mesh = sm
		var mat := StandardMaterial3D.new()
		var colr: Color = cfg.get("color", Color(1, 0.85, 0.3))
		mat.albedo_color = colr
		mat.emission_enabled = true
		mat.emission = colr
		mat.emission_energy_multiplier = 2.4
		mesh.material_override = mat
		p.add_child(mesh)
	var parent: Node = ArenaState.arena if ArenaState.arena else p_source.get_tree().current_scene
	parent.add_child(p)
	p.global_position = origin
	if p.direction.length_squared() > 0.0001:
		var look_at_pos := origin + p.direction
		if absf(p.direction.dot(Vector3.UP)) < 0.98:
			p.look_at(look_at_pos, Vector3.UP)
	p.body_entered.connect(p._on_body_entered)
	if AbilityDef.matches_base(p.ability_id, "firebolt") or AbilityDef.matches_base(p.ability_id, "energy_bolt") or AbilityDef.matches_base(p.ability_id, "bolt"):
		p._travel_sfx = AudioManager.play_on("firebolt.travel", p)
	elif AbilityDef.matches_base(p.ability_id, "wave"):
		p._travel_sfx = AudioManager.play_on("thunder_wave.cast", p)
	elif AbilityDef.matches_base(p.ability_id, "auto"):
		AudioManager.play_at("auto.fire", origin)
	return p


func _add_fire_trail(vfx_scale: float = 0.95) -> void:
	var s := maxf(vfx_scale, 0.2)
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.28
	p.emitting = true
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0.0, 0.0, 0.45 * s)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.16, 0.55) * s
	p.draw_pass_1 = mesh
	var smat := ShaderMaterial.new()
	smat.shader = _WISP_SHADER
	smat.set_shader_parameter("color", Color(1.0, 0.48, 0.12, 0.88))
	p.material_override = smat
	var pp := ParticleProcessMaterial.new()
	pp.particle_flag_align_y = true
	pp.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pp.emission_shape_scale = Vector3(0.08, 0.08, 0.18) * s
	pp.direction = Vector3(0.0, 0.15, 1.0)
	pp.spread = 18.0
	pp.initial_velocity_min = 1.2 * s
	pp.initial_velocity_max = 3.4 * s
	pp.gravity = Vector3(0.0, 0.4, 0.0)
	pp.damping_min = 1.0
	pp.damping_max = 2.4
	pp.scale_min = 0.7
	pp.scale_max = 1.35
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.85))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	pp.scale_curve = tex
	pp.color = Color(1.0, 0.5, 0.12, 0.9)
	p.process_material = pp
	add_child(p)


func _src() -> Unit:
	if not is_instance_valid(source):
		source = null
		return null
	return source


func _physics_process(delta: float) -> void:
	if _resolved:
		return
	_src()
	if _wind_bounce_u >= 0.0:
		_tick_wind_bounce(delta)
	var step := _next_step(delta)
	if step.length_squared() < 0.0000001:
		return
	if _wind_bounce_u < 0.0:
		var shield := SpellWall.protection_hit(global_position, global_position + step, maxf(radius, 0.12))
		if shield:
			_hit_spell_wall(shield)
			_explode(null)
			return
		_amp_from_fire_wall(global_position, global_position + step)
		if _try_wind_reflect(global_position, global_position + step):
			_tick_wind_bounce(delta)
			step = _next_step(delta)
			if step.length_squared() < 0.0000001:
				return
		elif _blocked_by_wall(step):
			return
		elif _try_illusion_portal(global_position, global_position + step):
			return
	global_position += step
	if direction.length_squared() > 0.0001 and absf(direction.dot(Vector3.UP)) < 0.98:
		look_at(global_position + direction, Vector3.UP)
	traveled += step.length()
	if traveled >= max_distance:
		_hit_wall_ahead()
		_explode(null)
		return
	if homing and is_instance_valid(homing):
		if _reached_homing():
			_hit_unit(homing)


func _try_illusion_portal(from: Vector3, to: Vector3) -> bool:
	if _resolved or _portal_hops >= 2:
		return false
	var gate := SpellWall.illusion_inlet_hit(from, to, maxf(radius, 0.12))
	if gate == null:
		return false
	gate.absorb_projectile(self)
	return true


func _try_wind_reflect(from: Vector3, to: Vector3) -> bool:
	if _resolved or _wind_bounce_u >= 0.0:
		return false
	var wall := SpellWall.wind_hit(from, to, maxf(radius, 0.12))
	if wall == null or wall == _wind_ignore:
		return false
	if not wall.can_reflect(_src()):
		return false
	return _try_reflect_wall(wall)


func snapshot() -> Dictionary:
	var snap := _spawn_cfg.duplicate(true)
	snap["source"] = _src()
	snap["damage"] = damage
	snap["speed"] = speed
	snap["max_distance"] = maxf(max_distance - traveled, 0.2)
	snap["radius"] = radius
	snap["skillshot"] = skillshot
	snap["element"] = element
	snap["extra_elements"] = extra_elements.duplicate()
	snap["mark_damage_bonus"] = mark_damage_bonus
	snap["splash_radius"] = splash_radius
	snap["splash_ratio"] = splash_ratio
	snap["splash_vfx"] = splash_vfx
	snap["splash_vfx_scale"] = splash_vfx_scale
	snap["grant_charged"] = grant_charged
	snap["overheat_cast_id"] = overheat_cast_id
	snap["combat_text_cast_id"] = combat_text_cast_id
	snap["infusion_double"] = infusion_double
	snap["ability_id"] = ability_id
	snap["shield"] = shield
	snap["shield_duration"] = shield_duration
	snap["heal_allies"] = heal_allies
	snap["heal"] = heal
	snap["applies_rejuvenation"] = applies_rejuvenation
	snap["blessing_power"] = blessing_power
	snap["ally_cast"] = ally_cast
	snap["hit_cooldown_reduction"] = hit_cooldown_reduction
	snap["pierce"] = pierce
	snap["ghost_enemies"] = ghost_enemies
	snap["fire_wall_bonus"] = fire_wall_bonus
	snap["fire_wall_amped"] = _fire_wall_amped
	snap["vfx_layers"] = vfx_layers.duplicate()
	snap["homing"] = homing
	snap["direction"] = direction
	snap["arc_side"] = arc_side
	snap["arc_width"] = arc_width
	snap["arc_lift"] = arc_lift
	snap["arc_min"] = arc_min
	snap["portal_hops"] = _portal_hops
	return snap


func swallow() -> void:
	if _resolved:
		return
	_resolved = true
	AudioManager.stop_loop(_travel_sfx, 0.0)
	_travel_sfx = 0
	queue_free()


func _amp_from_fire_wall(from: Vector3, to: Vector3) -> void:
	if _fire_wall_amped or damage <= 0.05:
		return
	var bonus := SpellWall.fire_shot_bonus(from, to, maxf(radius, 0.25), _src())
	if bonus <= 0.0:
		return
	_fire_wall_amped = true
	fire_wall_bonus = maxf(fire_wall_bonus, bonus)


func _uses_arc() -> bool:
	return arc_width > 0.001 and homing != null


func _arc_aim() -> Vector3:
	if homing != null and is_instance_valid(homing):
		if homing.is_structure and homing.host_wall != null and is_instance_valid(homing.host_wall):
			var from := _arc_origin if not is_inside_tree() else global_position
			return homing.host_wall.aim_point(from)
		return homing.global_position + Vector3(0.0, 1.0, 0.0)
	return global_position + direction


func _reached_homing(pad: float = 0.0) -> bool:
	if homing == null or not is_instance_valid(homing):
		return false
	if homing.is_structure:
		return homing.hit_distance_to(global_position) <= radius + pad
	return global_position.distance_to(_arc_aim()) <= radius + homing.radius + pad


func _next_step(delta: float) -> Vector3:
	if _wind_bounce_u >= 0.0:
		return direction * speed * _wind_bounce_scale() * delta
	if _uses_arc() and is_instance_valid(homing) and not homing.is_dead:
		var dest := _arc_aim()
		var remain := dest - global_position
		if _reached_homing(0.35) or _arc_u >= 0.9:
			if remain.length_squared() > 0.0001:
				direction = remain.normalized()
			return direction * speed * delta
		var path_len := maxf(_arc_length(dest), 0.35)
		_arc_u = minf(1.0, _arc_u + speed * delta / path_len)
		var nxt := _arc_point(dest, _arc_u)
		var move := nxt - global_position
		if move.length_squared() > 0.0001:
			direction = move.normalized()
			var cap := speed * delta * 1.6
			if move.length() > cap:
				return direction * cap
			return move
	elif homing and is_instance_valid(homing) and not homing.is_dead:
		var to := _arc_aim() - global_position
		if to.length_squared() > 0.0001:
			direction = to.normalized()
	return direction * speed * delta


func _arc_length(dest: Vector3) -> float:
	var chord := dest.distance_to(_arc_origin)
	return chord + absf(arc_side) * maxf(chord * arc_width, arc_min) * 1.7 + absf(arc_lift)


func _arc_point(dest: Vector3, t: float) -> Vector3:
	var chord := dest - _arc_origin
	var dist := chord.length()
	var fwd := Vector3.FORWARD
	if dist > 0.001:
		fwd = chord / dist
	else:
		dist = 0.2
	var side := fwd.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	else:
		side = side.normalized()
	var width := arc_side * maxf(dist * arc_width, arc_min)
	var p1 := _arc_origin + fwd * dist * 0.12 + side * width + Vector3.UP * arc_lift
	var p2 := _arc_origin + fwd * dist * 0.58 + side * width * 0.52 + Vector3.UP * (arc_lift * 0.22)
	return _cubic_bezier(_arc_origin, p1, p2, dest, clampf(t, 0.0, 1.0))


func _cubic_bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * (u * u * u) + b * (3.0 * u * u * t) + c * (3.0 * u * t * t) + d * (t * t * t)


func _on_body_entered(body: Node) -> void:
	if not authoritative or _resolved:
		return
	var src := _src()
	if body == src:
		return
	if body is Unit:
		if _locks_target() and body != homing:
			return
		_hit_unit(body)
		return
	if body is SpellWall:
		if body == _wind_ignore:
			return
		if not body.blocks_shot(src):
			return
		if _try_reflect_wall(body):
			return
		_hit_spell_wall(body)
		_explode(null)
		return
	if body is CollisionObject3D and _is_wall_body(body):
		_explode(null)


func _is_wall_body(body: Node) -> bool:
	if not (body is StaticBody3D):
		return false
	return String(body.name) != "Floor"


func _hit_spell_wall(wall: Variant) -> void:
	if wall == null or not is_instance_valid(wall) or not (wall is SpellWall):
		return
	var barrier := wall as SpellWall
	var src := _src()
	if not barrier.can_be_damaged_by(src):
		return
	var proxy := barrier.target_proxy()
	if proxy != null:
		proxy.receive_ability_hit(src, element, damage, mark_damage_bonus, extra_elements, false, true, true, overheat_cast_id, infusion_double, ability_id, combat_text_cast_id)
		return
	var display_element := element
	if display_element == AbilityDef.Element.NONE and not extra_elements.is_empty():
		display_element = extra_elements[0]
	var kind := _DamageNumber.kind_for_element(display_element)
	var tint := _DamageNumber.tint_for_element(display_element)
	var split := {}
	if element != AbilityDef.Element.NONE or not extra_elements.is_empty():
		var ab := src._ability_def_for_hit(ability_id, element, extra_elements) if src != null else null
		split = _DamageNumber.split_for_hit(ab, extra_elements, null, ability_id, false, element, false, damage, damage)
	else:
		split = _DamageNumber.split_for_amount(kind, damage, tint)
	barrier.take_hit(damage, global_position, src, kind, tint, false, combat_text_cast_id, split)


func _try_reflect_wall(wall: SpellWall) -> bool:
	if wall == null or not is_instance_valid(wall) or wall == _wind_ignore:
		return false
	if _wind_bounce_u >= 0.0:
		return false
	if not wall.can_reflect(_src()):
		return false
	var n := wall.face_normal(direction)
	var bounced := direction.bounce(n)
	bounced.y = 0.0
	if bounced.length_squared() < 0.0001:
		bounced = -Vector3(direction.x, 0.0, direction.z)
	if bounced.length_squared() < 0.0001:
		bounced = n
	_wind_out = bounced.normalized()
	_wind_bounce_u = 0.0
	var original := _src()
	if wall.source != null and is_instance_valid(wall.source):
		source = wall.source
	if original != null and is_instance_valid(original) and original != source and original.team != source.team:
		homing = original
	else:
		homing = null
	arc_width = 0.0
	_arc_u = 0.0
	_hit_ids.clear()
	traveled = 0.0
	_wind_ignore = wall
	return true


func _tick_wind_bounce(delta: float) -> void:
	var dur := CombatBalance.flat("wall.wind.bounce")
	if dur < 0.04:
		dur = 0.12
	var before := _wind_bounce_u
	_wind_bounce_u += delta / dur
	if before < 0.5 and _wind_bounce_u >= 0.5:
		direction = _wind_out
	if _wind_bounce_u >= 1.0:
		_wind_bounce_u = -1.0
		direction = _wind_out


func _wind_bounce_scale() -> float:
	if _wind_bounce_u < 0.0:
		return 1.0
	var u := clampf(_wind_bounce_u, 0.0, 1.0)
	var t := (1.0 - u * 2.0) if u < 0.5 else (u * 2.0 - 1.0)
	return t * t


func _hit_wall_ahead() -> void:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return
	var exclude: Array[RID] = []
	var src := _src()
	if src:
		exclude.append(src.get_rid())
		SpellWall.append_pass_excludes(exclude, src)
	if _wind_ignore != null and is_instance_valid(_wind_ignore):
		exclude.append(_wind_ignore.get_rid())
	var ahead := direction * maxf(radius + 0.35, 0.5)
	var hit := arena.spell_wall_hit(global_position, global_position + ahead, exclude, global_position.y)
	if hit.get("collider") is SpellWall:
		_hit_spell_wall(hit.get("collider"))


func _blocked_by_wall(step: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	var hit := {}
	var src := _src()
	if arena:
		var exclude: Array[RID] = []
		if src:
			exclude.append(src.get_rid())
			SpellWall.append_pass_excludes(exclude, src)
		if _wind_ignore != null and is_instance_valid(_wind_ignore):
			exclude.append(_wind_ignore.get_rid())
		hit = arena.spell_wall_hit(global_position, global_position + step, exclude, global_position.y)
	else:
		var space := get_world_3d().direct_space_state
		if space == null:
			return false
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
		q.collision_mask = SpellWall.shot_block_mask()
		var skip: Array[RID] = []
		if src:
			skip.append(src.get_rid())
			SpellWall.append_pass_excludes(skip, src)
		if _wind_ignore != null and is_instance_valid(_wind_ignore):
			skip.append(_wind_ignore.get_rid())
		q.exclude = skip
		q.collide_with_areas = false
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var col = hit.get("collider")
	if col is SpellWall:
		if not col.blocks_shot(src):
			return false
		if _try_reflect_wall(col):
			return true
		_hit_spell_wall(col)
	var p: Vector3 = hit.position
	var n: Vector3 = hit.get("normal", -direction)
	n.y = 0.0
	if n.length_squared() > 0.0001:
		p += n.normalized() * 0.08
	global_position = p
	_explode(null)
	return true


func _fired_ability() -> AbilityDef:
	var src := _src()
	if src == null:
		return null
	return src._ability_def_for_hit(ability_id, element, extra_elements)


func _locks_target() -> bool:
	return homing != null and is_instance_valid(homing) and not skillshot


func _passes_through_enemy(u: Unit) -> bool:
	var src := _src()
	if u == null or src == null or u.team == src.team:
		return false
	if _locks_target() and u == homing:
		return false
	if ghost_enemies:
		return true
	return SpellPower.ghosts_enemies(_fired_ability())


func _hit_unit(u: Unit) -> void:
	if not authoritative or _resolved or u == null or not is_instance_valid(u) or u.is_dead:
		return
	var uid := u.get_instance_id()
	if _hit_ids.has(uid):
		return
	_hit_ids[uid] = true
	if _passes_through_enemy(u):
		return
	var src := _src()
	if src and u.team == src.team:
		var ab := _fired_ability()
		var altered := ab != null and ab.altered
		var support := heal_allies or applies_rejuvenation or shield > 0.05 or ally_cast
		if not support and not altered:
			return
		if homing != null and u != homing:
			return
		if support:
			var heal_amt := heal if heal > 0.05 else (damage if heal_allies else 0.0)
			u.apply_support_hit(src, heal_amt, shield, shield_duration, applies_rejuvenation, ability_id, blessing_power, extra_elements, element, combat_text_cast_id, false)
		if ally_cast and ab:
			src._apply_ally_spell(u, ab, false)
			if src != u:
				src.apply_altered_from(ab)
		elif altered:
			u.apply_altered_from(ab)
		if skillshot and not ally_cast and not support:
			return
		_on_land()
		if pierce:
			return
		_explode(u)
		return
	_deal_hit(u, damage, true)
	if src and is_instance_valid(u) and not u.is_dead:
		UnitWind.apply_on_skillshot(u, _fired_ability(), self)
	_on_land()
	if pierce:
		return
	_explode(u)


func _on_land() -> void:
	var src := _src()
	if _landed or hit_cooldown_reduction <= 0.0 or src == null:
		return
	_landed = true
	src.reduce_all_cooldowns(hit_cooldown_reduction)


func _explode(primary: Unit) -> void:
	if _resolved:
		return
	_resolved = true
	AudioManager.stop_loop(_travel_sfx, 0.0)
	_travel_sfx = 0
	var origin := _splash_origin()
	if AbilityDef.matches_base(ability_id, "firebolt") or AbilityDef.matches_base(ability_id, "energy_bolt") or AbilityDef.matches_base(ability_id, "bolt") or AbilityDef.matches_base(ability_id, "wave"):
		AudioManager.play_at("firebolt.explode", origin)
	elif AbilityDef.matches_base(ability_id, "auto"):
		AudioManager.play_at("auto.hit", global_position)
	_play_splash_fx(origin)
	if not vfx_layers.is_empty() and not AbilityDef.matches_base(ability_id, "wave") and splash_radius <= 0.0:
		SpellVfx.play_impact(origin, {"vfx_layers": vfx_layers})
	if authoritative and splash_radius > 0.0:
		var splash_dmg := damage * splash_ratio
		if splash_dmg > 0.0:
			for other in ArenaState.units:
				var u := other as Unit
				if u == null or u == primary or not is_instance_valid(u) or u.is_dead:
					continue
				if u.is_structure:
					continue
				var src := _src()
				if src and u.team == src.team:
					var splash_ab := _fired_ability()
					if splash_ab != null and splash_ab.altered and u.global_position.distance_to(origin) <= splash_radius + u.radius:
						u.apply_altered_from(splash_ab)
					continue
				if u.global_position.distance_to(origin) <= splash_radius + u.radius:
					if _splash_blocked(u, origin):
						continue
					_deal_hit(u, splash_dmg)
			SpellWall.apply_radius_hit(_src(), origin, splash_radius, splash_dmg, "hit", Color(0, 0, 0, 0), combat_text_cast_id, true)
	queue_free()


func _splash_origin() -> Vector3:
	var pos := Vector3(global_position.x, 0.18, global_position.z)
	var along := Vector3(direction.x, 0.0, direction.z)
	if along.length_squared() < 0.0001:
		return pos
	along = along.normalized()
	var dest := pos + along * SPLASH_PUSH
	var arena := ArenaState.arena as Arena
	if arena:
		var exclude: Array[RID] = []
		var src := _src()
		if src:
			exclude.append(src.get_rid())
		var hit := arena.spell_wall_hit(pos, dest, exclude, global_position.y)
		if not hit.is_empty():
			var p: Vector3 = hit.position
			dest = Vector3(p.x, 0.18, p.z) - along * 0.08
	return dest


func _play_splash_fx(pos: Vector3) -> void:
	if splash_vfx == AbilityFx.FIRE_AREA:
		_FireboltFx.burst(pos, splash_radius)
		return
	if splash_vfx == "" and splash_radius <= 0.0:
		return
	if splash_vfx != "" and AbilityFx.exists(splash_vfx):
		AbilityFx.play_at(splash_vfx, pos, {
			"scale": splash_vfx_scale if splash_vfx_scale > 0.05 else 0.85,
			"lifetime": 1.35,
			"area_radius": maxf(splash_radius, 1.2),
		})
		return
	if splash_radius > 0.0:
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, pos, {
			"scale": 1.24,
			"lifetime": 1.15,
			"area_radius": maxf(splash_radius, 1.2),
		})
		return
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = maxf(splash_radius, 0.8)
	sphere.height = sphere.radius * 2.0
	fx.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.45, 0.12, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 2.2
	fx.material_override = mat
	var parent: Node = ArenaState.arena if ArenaState.arena else get_tree().current_scene
	parent.add_child(fx)
	fx.global_position = pos + Vector3(0, 0.4, 0)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector3.ONE * 1.6, 0.2)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(fx.queue_free)


func _deal_hit(u: Unit, amount: float, apply_fire_wall: bool = false) -> void:
	if u == null or not is_instance_valid(u) or u.is_dead or amount <= 0.0:
		return
	var src := _src()
	if element != AbilityDef.Element.NONE or mark_damage_bonus > 0.0 or extra_elements.size() > 0:
		u.receive_ability_hit(src, element, amount, mark_damage_bonus, extra_elements, false, true, true, overheat_cast_id, infusion_double, ability_id, combat_text_cast_id)
	else:
		u.apply_world_hit(amount, src, "physical", ability_id if not ability_id.is_empty() else "auto", combat_text_cast_id)
	if apply_fire_wall and fire_wall_bonus > 0.05 and is_instance_valid(u) and not u.is_dead:
		u.receive_ability_hit(
			src,
			AbilityDef.Element.FIRE,
			fire_wall_bonus,
			0.0,
			PackedInt32Array(),
			false,
			true,
			true,
			-1,
			0,
			"fire_wall",
			combat_text_cast_id
		)
	if grant_charged and is_instance_valid(u) and not u.is_dead:
		u._apply_mark(AbilityDef.Element.STORM, src)


func _splash_blocked(u: Unit, from: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return false
	var exclude: Array[RID] = []
	var src := _src()
	if src:
		exclude.append(src.get_rid())
	exclude.append(u.get_rid())
	return not arena.spell_has_los(from, u.global_position, exclude, from.y)
