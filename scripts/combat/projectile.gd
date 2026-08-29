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
var infusion_double: int = 0
var ability_id: String = ""
var shield: float = 0.0
var shield_duration: float = 0.0
var heal_allies: bool = false
var hit_cooldown_reduction: float = 0.0
var _resolved: bool = false
var _travel_sfx: int = 0

const TEAM_RAID := 0
const SPLASH_PUSH := 0.9
const _FireboltFx := preload("res://scripts/visual/firebolt_fx.gd")
const _WISP_SHADER := preload("res://scripts/visual/ice_wisp.gdshader")


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
	p.infusion_double = int(cfg.get("infusion_double", 0))
	p.ability_id = String(cfg.get("ability_id", ""))
	p.shield = float(cfg.get("shield", 0.0))
	p.shield_duration = float(cfg.get("shield_duration", 0.0))
	p.heal_allies = bool(cfg.get("heal_allies", false))
	p.hit_cooldown_reduction = float(cfg.get("hit_cooldown_reduction", 0.0))
	p.authoritative = auth
	p.homing = cfg.get("homing", null)
	if cfg.has("direction"):
		p.direction = Vector3(cfg["direction"]).normalized()
	elif p.homing:
		p.direction = (p.homing.global_position - origin).slide(Vector3.UP).normalized()
	else:
		p.direction = p_source.facing_dir()
	p.collision_layer = 4
	p.collision_mask = 3
	p.monitoring = auth
	var shape := SphereShape3D.new()
	shape.radius = p.radius
	var col := CollisionShape3D.new()
	col.shape = shape
	p.add_child(col)
	var vfx_path := String(cfg.get("vfx_scene", ""))
	var used_vfx := false
	if AbilityFx.exists(vfx_path):
		var vcfg := {
			"scale": float(cfg.get("vfx_scale", 0.55)),
			"yaw_offset": float(cfg.get("vfx_yaw", 0.0)),
		}
		if cfg.has("vfx_primary") and (cfg["vfx_primary"] as Color).a > 0.0:
			vcfg["primary_color"] = cfg["vfx_primary"]
		if cfg.has("vfx_secondary") and (cfg["vfx_secondary"] as Color).a > 0.0:
			vcfg["secondary_color"] = cfg["vfx_secondary"]
		if cfg.has("vfx_tertiary") and (cfg["vfx_tertiary"] as Color).a > 0.0:
			vcfg["tertiary_color"] = cfg["vfx_tertiary"]
		if AbilityFx.attach(vfx_path, p, vcfg):
			used_vfx = true
			if vfx_path == AbilityFx.FIRE_PROJECTILE:
				p._add_fire_trail(float(cfg.get("vfx_scale", 0.95)))
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
	if p.ability_id == "firebolt":
		p._travel_sfx = AudioManager.play_on("firebolt.travel", p)
	elif p.ability_id == "auto":
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


func _physics_process(delta: float) -> void:
	if homing and is_instance_valid(homing) and not homing.is_dead:
		var to := homing.global_position + Vector3(0, 1.0, 0) - global_position
		if to.length_squared() > 0.0001:
			direction = to.normalized()
	var step := direction * speed * delta
	if _blocked_by_wall(step):
		return
	global_position += step
	if direction.length_squared() > 0.0001 and absf(direction.dot(Vector3.UP)) < 0.98:
		look_at(global_position + direction, Vector3.UP)
	traveled += step.length()
	if traveled >= max_distance:
		_explode(null)
		return
	if homing and is_instance_valid(homing):
		if global_position.distance_to(homing.global_position + Vector3(0, 1.0, 0)) <= radius + homing.radius:
			_hit_unit(homing)


func _on_body_entered(body: Node) -> void:
	if not authoritative or _resolved:
		return
	if body == source:
		return
	if body is Unit:
		_hit_unit(body)
		return
	if body is CollisionObject3D and _is_wall_body(body):
		_explode(null)


func _is_wall_body(body: Node) -> bool:
	if not (body is StaticBody3D):
		return false
	return String(body.name) != "Floor"


func _blocked_by_wall(step: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	var hit := {}
	if arena:
		var exclude: Array[RID] = []
		if source:
			exclude.append(source.get_rid())
		hit = arena.spell_wall_hit(global_position, global_position + step, exclude, global_position.y)
	else:
		var space := get_world_3d().direct_space_state
		if space == null:
			return false
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step)
		q.collision_mask = 1
		if source:
			q.exclude = [source.get_rid()]
		q.collide_with_areas = false
		hit = space.intersect_ray(q)
	if hit.is_empty():
		return false
	var p: Vector3 = hit.position
	var n: Vector3 = hit.get("normal", -direction)
	n.y = 0.0
	if n.length_squared() > 0.0001:
		p += n.normalized() * 0.08
	global_position = p
	_explode(null)
	return true


func _hit_unit(u: Unit) -> void:
	if not authoritative or _resolved or u == null or u.is_dead:
		return
	if source and u.team == source.team:
		if heal_allies and damage > 0.05:
			u.apply_heal(damage, source, ability_id)
			_on_land()
			_explode(u)
			return
		if shield <= 0.05:
			return
		if homing != null and u != homing:
			return
		var dur := shield_duration if shield_duration > 0.05 else Unit.WARD_TIME
		u.apply_shield(shield, dur, source)
		_explode(u)
		return
	_deal_hit(u, damage)
	_on_land()
	_explode(u)


func _on_land() -> void:
	if hit_cooldown_reduction <= 0.0 or source == null or not is_instance_valid(source):
		return
	source.reduce_all_cooldowns(hit_cooldown_reduction)


func _explode(primary: Unit) -> void:
	if _resolved:
		return
	_resolved = true
	AudioManager.stop_loop(_travel_sfx, 0.0)
	_travel_sfx = 0
	var origin := _splash_origin()
	if ability_id == "firebolt":
		AudioManager.play_at("firebolt.explode", origin)
	elif ability_id == "auto":
		AudioManager.play_at("auto.hit", global_position)
	_play_splash_fx(origin)
	if authoritative and splash_radius > 0.0:
		var splash_dmg := damage * splash_ratio
		if splash_dmg > 0.0:
			for other in ArenaState.units:
				var u := other as Unit
				if u == null or u == primary or not is_instance_valid(u) or u.is_dead:
					continue
				if source and u.team == source.team:
					continue
				if u.global_position.distance_to(origin) <= splash_radius + u.radius:
					if _splash_blocked(u, origin):
						continue
					_deal_hit(u, splash_dmg)
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
		if source:
			exclude.append(source.get_rid())
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
	var played := false
	if splash_vfx != "" and AbilityFx.exists(splash_vfx):
		AbilityFx.play_at(splash_vfx, pos, {
			"scale": splash_vfx_scale if splash_vfx_scale > 0.05 else 0.85,
			"lifetime": 1.35,
			"area_radius": maxf(splash_radius, 1.2),
		})
		played = true
	if splash_radius > 0.0 and splash_vfx != AbilityFx.GROUND_EXPLOSION:
		AbilityFx.play_at(AbilityFx.GROUND_EXPLOSION, pos, {
			"scale": 1.24,
			"lifetime": 1.15,
			"area_radius": maxf(splash_radius, 1.2),
		})
		played = true
	if played:
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


func _deal_hit(u: Unit, amount: float) -> void:
	if u == null or u.is_dead or amount <= 0.0:
		return
	if element != AbilityDef.Element.NONE or mark_damage_bonus > 0.0 or extra_elements.size() > 0:
		u.receive_ability_hit(source, element, amount, mark_damage_bonus, extra_elements, false, true, true, overheat_cast_id, infusion_double, ability_id)
	else:
		u.take_damage(amount, source, Color(1.0, 1.0, 1.0), "auto", ability_id if not ability_id.is_empty() else "auto")
	if grant_charged and is_instance_valid(u) and not u.is_dead:
		u._apply_mark(AbilityDef.Element.STORM, source)


func _splash_blocked(u: Unit, from: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null or u == null:
		return false
	var exclude: Array[RID] = []
	if source:
		exclude.append(source.get_rid())
	exclude.append(u.get_rid())
	return not arena.spell_has_los(from, u.global_position, exclude, from.y)
