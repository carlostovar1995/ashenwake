class_name SpellWall
extends StaticBody3D

enum Allegiance {
	ALLIED, ## Friendly allied wall: only the owner's enemies may target or damage it.
	ENEMY, ## Enemy wall: only the owner's friends may target or damage it.
	CONTESTED, ## Enemy to both teams.
}

const HEIGHT := 2.35
const LAYER_WORLD := 1
const LAYER_BARRIER := 16
const _BAR_W := 1.48
const _BAR_H := 0.11
const _SpellBaseFx := preload("res://scripts/visual/spell_base_fx.gd")
const GroundIndicator := preload("res://scripts/visual/ground_indicator.gd")
const _DamageNumber := preload("res://scripts/visual/damage_number.gd")
const _UnitController := preload("res://scripts/units/unit_controller.gd")
const _UnitMovement := preload("res://scripts/units/movement.gd")
const _AutoAttack := preload("res://scripts/combat/auto_attack.gd")
const _HoverOutline := preload("res://scripts/visual/hover_outline.gdshader")
const _HoverFrameShader := preload("res://scripts/visual/hover_frame.gdshader")

var source: Unit
var ability: AbilityDef
var extras: PackedInt32Array = PackedInt32Array()
var overheat_cast_id: int = -1
var combat_text_cast_id: int = -1
var infusion_double: int = 0
var blast_radius: float = 3.6
var blast_damage: float = 160.0
var max_health: float = 160.0
var health: float = 160.0
var duration: float = 8.0
var living: bool = true
var allegiance: int = Allegiance.ALLIED

var _elapsed: float = 0.0
var _grow_t: float = 0.0
var _grow_time: float = 0.14
var _growing: bool = true
var _mat: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []
var _shapes: Array[CollisionShape3D] = []
var _full_sizes: Array[Vector3] = []
var _seg_offsets: Array[Vector3] = []
var _bar: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _bar_root: Node3D
var _bar_fill_quad: QuadMesh
var _zones: Array[GroundAoeZone] = []
var _ice_tick_acc: float = 0.0
var _ice_ticked: bool = false
var _fire_on: Dictionary = {}
var _illusion_role: String = ""
var _illusion_outlet: SpellWall
var _illusion_queue: Array[Dictionary] = []
var _illusion_moves_left: int = 0
var _portal_frame: MeshInstance3D
var _portal_rim_mat: StandardMaterial3D
var _seg_health: Array[float] = []
var _seg_mats: Array[StandardMaterial3D] = []
var _nature_tick_acc: float = 0.0
var _nature_ticked: bool = false
var _lightning_acc: float = 99.0
var _dome: MeshInstance3D
var _disc: MeshInstance3D
var _protect_dir: Vector3 = Vector3(0, 0, -1)
var _protect_target_dir: Vector3 = Vector3(0, 0, -1)
var _target_proxy: Unit = null
var _targeted: bool = false
var _hover_color: Color = Color(1.0, 0.82, 0.28, 0.92)
var _hover_mat: ShaderMaterial = null
var _bar_frame: MeshInstance3D = null

static var _illusion_inlets: Dictionary = {}


static func spawn(caster: Unit, point: Vector3, ab: AbilityDef, extras: PackedInt32Array, ice_id: int, double_mask: int, text_cast_id: int = -1) -> SpellWall:
	var wall := SpellWall.new()
	wall.source = caster
	wall.ability = ab
	wall.extras = extras
	wall.overheat_cast_id = ice_id
	wall.combat_text_cast_id = text_cast_id
	wall.infusion_double = double_mask
	wall.blast_radius = maxf(ab.aoe_radius * 3.1, 3.2)
	wall.blast_damage = caster._scaled(ab.damage)
	if SpellWallLayout.style_id(ab) == "shadow":
		wall.max_health = CombatBalance.flat("wall.shadow.hp")
	elif SpellWallLayout.style_id(ab) == "nature":
		wall.max_health = CombatBalance.flat("wall.nature.hp")
	elif SpellWallLayout.style_id(ab) == "lightning":
		wall.max_health = CombatBalance.flat("wall.lightning.hp")
	else:
		wall.max_health = CombatBalance.flat("wall.hp")
	wall.health = wall.max_health
	wall.duration = maxf(ab.zone_duration, 4.0)
	if SpellWallLayout.style_id(ab) == "illusion":
		wall.duration = CombatBalance.flat("wall.illusion.time")
	elif SpellWallLayout.style_id(ab) == "nature":
		wall.duration = CombatBalance.flat("wall.nature.time")
	elif SpellWallLayout.style_id(ab) == "divine":
		wall.duration = CombatBalance.flat("wall.divine.time")
	elif SpellWallLayout.style_id(ab) == "protection":
		wall.duration = CombatBalance.flat("wall.protection.time") + 0.35
	var physical := SpellWallLayout.is_physical(ab)
	var style := SpellWallLayout.style_id(ab)
	wall.allegiance = SpellWallLayout.allegiance(ab)
	if style == "protection":
		wall.name = "SpellProtectionWall"
	elif style == "wind":
		wall.name = "SpellWindWall"
	elif style == "nature":
		wall.name = "SpellNatureWall"
	elif physical:
		wall.name = "ObstacleSpellWall"
	elif style == "illusion":
		wall.name = "SpellIllusionWall"
	elif style == "divine":
		wall.name = "SpellDivineWall"
	else:
		wall.name = "SpellFireWall"
	if style == "nature":
		wall.collision_layer = LAYER_BARRIER
	else:
		wall.collision_layer = 1 if physical else 0
	wall.collision_mask = 0
	var height := SpellWallLayout.height_of(ab)
	var fallback := caster.facing_dir() if caster != null and is_instance_valid(caster) else Vector3(0, 0, -1)
	var from := caster.global_position if caster != null and is_instance_valid(caster) else point
	var dir := SpellWallLayout.aim_dir(from, point, fallback)
	if style == "protection" and caster != null and is_instance_valid(caster):
		caster.add_child(wall)
		wall.top_level = true
		wall._protect_dir = dir
		wall._protect_target_dir = dir
		wall._growing = false
	else:
		var parent: Node = ArenaState.arena.nav_region if ArenaState.arena else Engine.get_main_loop().root
		parent.add_child(wall)
		if style == "divine":
			wall.global_position = Vector3(point.x, 0.08, point.z)
		else:
			wall.global_position = Vector3(point.x, height * 0.5, point.z)
			var look := wall.global_position + dir
			wall.look_at(Vector3(look.x, wall.global_position.y, look.z), Vector3.UP)
	wall._grow_time = CombatBalance.flat("wall.grow")
	wall._build()
	wall._attach_target_proxy()
	wall.add_to_group("spell_walls")
	if style == "ice":
		wall._spawn_ice_zones()
	if style == "protection":
		wall._apply_grow(1.0)
		wall.add_to_group("spell_protection_walls")
		if caster != null and is_instance_valid(caster):
			wall.add_collision_exception_with(caster)
		wall._follow_protection()
	if style == "fire":
		wall.add_to_group("spell_fire_walls")
	elif style == "wind":
		wall.add_to_group("spell_wind_walls")
	elif style == "illusion":
		wall.add_to_group("spell_illusion_walls")
		wall._register_illusion()
	elif style == "nature":
		wall.add_to_group("spell_nature_walls")
	return wall


func take_hit(amount: float, at: Vector3 = Vector3.ZERO, from: Unit = null, hit_kind: String = "hit", number_color: Color = Color(0, 0, 0, 0), crit: bool = false, text_cast_id: int = -1, combat_text_split: Dictionary = {}) -> void:
	if not living or amount <= 0.0 or not can_be_damaged_by(from):
		return
	health = maxf(0.0, health - amount)
	_refresh()
	_sync_proxy()
	var kind := hit_kind if not hit_kind.is_empty() else "hit"
	var shown_split := combat_text_split
	if shown_split.is_empty():
		shown_split = _DamageNumber.split_for_amount(kind, amount, number_color)
	else:
		shown_split = _DamageNumber.scaled_split(shown_split, amount)
	var at_node: Node3D = _target_proxy if _target_proxy != null and is_instance_valid(_target_proxy) else self
	_DamageNumber.show_hit(at_node, amount, kind, number_color, crit, text_cast_id, "", shown_split)
	if health <= 0.0:
		detonate(true)


func detonate(broken: bool = false) -> void:
	if not living:
		return
	living = false
	collision_layer = 0
	_release_proxy()
	for shape in _shapes:
		if is_instance_valid(shape):
			shape.disabled = true
	_clear_ice_zones()
	_release_illusion()
	if _is_ice():
		if broken:
			_shatter_ice()
		queue_free()
		return
	if _is_lightning():
		queue_free()
		return
	if _is_shadow():
		if broken:
			_rupture_shadow()
		queue_free()
		return
	if _is_nature():
		if broken:
			_nature_heal_blast()
		queue_free()
		return
	if _is_illusion() or _is_divine() or _is_protection() or _is_wind() or _is_fire():
		queue_free()
		return
	var pos := Vector3(global_position.x, 0.12, global_position.z)
	if _is_physical() and source != null and is_instance_valid(source) and ability != null:
		source._ground_burst(pos, ability, blast_damage, blast_radius, extras, overheat_cast_id, infusion_double, 2.0, combat_text_cast_id)
	queue_free()


func _exit_tree() -> void:
	_release_proxy()
	if source != null and is_instance_valid(source) and source._spell_wall == self:
		source._spell_wall = null


func _physics_process(delta: float) -> void:
	if not living:
		return
	_orient_bar()
	_elapsed += delta
	if _is_protection():
		_tick_protection_turn(delta)
		_follow_protection()
		return
	if _elapsed >= duration:
		detonate(false)
		return
	if _growing:
		_grow_t = minf(1.0, _grow_t + delta / maxf(_grow_time, 0.04))
		_apply_grow(1.0 - pow(1.0 - _grow_t, 3.0))
		if _is_physical() and not _is_nature():
			_push_overlaps()
		if _is_nature():
			_tick_nature_walk()
		if _is_divine() and _grow_t > 0.35:
			_refresh_divine_dr()
		if _grow_t >= 1.0:
			_growing = false
		return
	if not _is_physical():
		if _is_fire():
			_flicker_fire()
			_tick_fire_line(delta)
		elif _is_wind():
			_flicker_wind()
		elif _is_illusion():
			_flicker_portal()
		elif _is_divine():
			_flicker_divine()
			_refresh_divine_dr()
		return
	if _is_ice():
		_tick_ice_zones(delta)
	if _is_lightning():
		_tick_lightning_totem(delta)
		return
	if _is_nature():
		_tick_nature_grove(delta)
		_tick_nature_walk()
		return


func _build() -> void:
	_mat = StandardMaterial3D.new()
	if _is_ice():
		_mat.albedo_color = Color(0.62, 0.88, 1.0, 0.88)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.12
		_mat.metallic = 0.18
		_mat.emission_enabled = true
		_mat.emission = Color(0.38, 0.72, 1.0)
		_mat.emission_energy_multiplier = 0.85
	elif _is_shadow():
		_mat.albedo_color = Color(0.22, 0.08, 0.32, 0.92)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.42
		_mat.emission_enabled = true
		_mat.emission = Color(0.58, 0.22, 0.82)
		_mat.emission_energy_multiplier = 0.7
	elif _is_wind():
		_mat.albedo_color = Color(0.72, 0.95, 0.86, 0.72)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.18
		_mat.emission_enabled = true
		_mat.emission = Color(0.55, 0.92, 0.78)
		_mat.emission_energy_multiplier = 1.15
	elif _is_lightning():
		_mat.albedo_color = Color(0.72, 0.62, 1.0, 0.88)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.12
		_mat.emission_enabled = true
		_mat.emission = Color(0.78, 0.62, 1.0)
		_mat.emission_energy_multiplier = 2.2
	elif _is_illusion():
		_mat.albedo_color = Color(0.92, 0.42, 0.78, 0.38)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.08
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.55, 0.88)
		_mat.emission_energy_multiplier = 2.4
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_build_portal_cylinder()
		_apply_grow(0.0)
		return
	elif _is_nature():
		_mat.albedo_color = Color(0.32, 0.78, 0.38, 0.92)
		_mat.roughness = 0.38
		_mat.emission_enabled = true
		_mat.emission = Color(0.42, 0.95, 0.48)
		_mat.emission_energy_multiplier = 0.7
	elif _is_protection():
		_mat.albedo_color = Color(0.78, 0.88, 1.0, 0.86)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.16
		_mat.metallic = 0.22
		_mat.emission_enabled = true
		_mat.emission = Color(0.55, 0.74, 1.0)
		_mat.emission_energy_multiplier = 0.95
	elif _is_divine():
		_build_divine()
		return
	elif _is_physical():
		var tint := ability.color if ability else Color(0.72, 0.8, 0.92)
		_mat.albedo_color = tint.lightened(0.12)
		_mat.roughness = 0.55
		_mat.emission_enabled = true
		_mat.emission = tint
		_mat.emission_energy_multiplier = 0.55
	else:
		_mat.albedo_color = Color(1.0, 0.38, 0.08, 0.82)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.roughness = 0.22
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.42, 0.06)
		_mat.emission_energy_multiplier = 3.4
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var length := SpellWallLayout.length_of(ability)
	var thick := SpellWallLayout.thickness_of(ability)
	var segs := SpellWallLayout.segments(ability)
	for i in segs.size():
		_add_segment(segs[i], i, length, thick)
	_apply_grow(1.0 if _is_protection() else 0.0)
	if _is_physical() and not _is_protection():
		_build_bar()
		_refresh()


func _add_segment(seg: Dictionary, index: int, default_length: float, default_thick: float) -> void:
	var kind := String(seg.get("kind", "box"))
	var offset: Vector3 = seg.get("offset", Vector3.ZERO)
	var yaw := float(seg.get("yaw", 0.0))
	var height := SpellWallLayout.height_of(ability)
	var mesh := MeshInstance3D.new()
	mesh.name = "WallSeg%d" % index
	mesh.material_override = _mat
	mesh.position = offset
	mesh.rotation.y = yaw
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D" if index == 0 else "CollisionShape3D_%d" % index
	shape.position = offset
	shape.rotation.y = yaw
	if not _is_physical():
		shape.disabled = true
	var full := Vector3.ZERO
	if kind == "capsule":
		var cap_r := float(seg.get("radius", -1.0))
		var cap_len := float(seg.get("length", -1.0))
		if cap_r <= 0.0:
			cap_r = SpellWallLayout.ice_radius(ability)
		if cap_len <= 0.0:
			cap_len = default_length
		full = Vector3(cap_len, height, cap_r)
		var cap_mesh := CapsuleMesh.new()
		cap_mesh.radius = 0.06
		cap_mesh.height = 0.28
		mesh.mesh = cap_mesh
		mesh.rotation = Vector3(0.0, yaw, PI * 0.5)
		var cap_shape := CapsuleShape3D.new()
		cap_shape.radius = 0.06
		cap_shape.height = 0.28
		shape.shape = cap_shape
		shape.rotation = Vector3(0.0, yaw, PI * 0.5)
	elif kind == "cylinder":
		var radius := float(seg.get("radius", -1.0))
		if radius <= 0.0:
			radius = SpellWallLayout.ice_radius(ability)
		full = Vector3(radius, height, radius)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.06
		cyl.height = 0.28
		mesh.mesh = cyl
		var col := CylinderShape3D.new()
		col.radius = 0.06
		col.height = 0.28
		shape.shape = col
	else:
		var length := float(seg.get("length", -1.0))
		var thick := float(seg.get("thickness", -1.0))
		if length <= 0.0:
			length = default_length
		if thick <= 0.0:
			thick = default_thick
		full = Vector3(length, height, thick)
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.28, 0.16)
		mesh.mesh = box
		var col := BoxShape3D.new()
		col.size = box.size
		shape.shape = col
	add_child(mesh)
	add_child(shape)
	_meshes.append(mesh)
	_shapes.append(shape)
	_full_sizes.append(full)
	_seg_offsets.append(offset)
	if _is_nature() and _mat != null:
		var sm := _mat.duplicate() as StandardMaterial3D
		mesh.material_override = sm
		_seg_mats.append(sm)


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "WallHpBar"
	_bar_root.top_level = true
	add_child(_bar_root)
	_bar = _make_bar_quad("HpBg", Vector2(_BAR_W + 0.10, _BAR_H + 0.05), Color(0.07, 0.06, 0.05), 0.0)
	_bar_root.add_child(_bar)
	_bar_fill_quad = QuadMesh.new()
	_bar_fill_quad.size = Vector2(_BAR_W, _BAR_H)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.name = "HpFill"
	_bar_fill.mesh = _bar_fill_quad
	_bar_fill.position.z = 0.004
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.emission_enabled = true
	_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_bar_mat.no_depth_test = true
	_bar_mat.disable_receive_shadows = true
	_bar_mat.render_priority = 10
	_bar_fill.material_override = _bar_mat
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(_bar_fill)
	_make_bar_hover_frame()
	_orient_bar()


func _make_bar_quad(quad_name: String, size: Vector2, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = quad_name
	var mesh := QuadMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position.z = z
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	mat.render_priority = 8
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _make_bar_hover_frame() -> void:
	if _bar_root == null:
		return
	_bar_frame = MeshInstance3D.new()
	_bar_frame.name = "HoverFrame"
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_bar_frame.mesh = quad
	_bar_frame.position.z = 0.008
	var mat := ShaderMaterial.new()
	mat.shader = _HoverFrameShader
	mat.set_shader_parameter("outline_color", _hover_color)
	mat.set_shader_parameter("border", 0.024)
	mat.set_shader_parameter("billboard", false)
	mat.render_priority = 12
	_bar_frame.material_override = mat
	_bar_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_frame.visible = false
	_bar_root.add_child(_bar_frame)


func hp_bar_world() -> Vector3:
	if _bar_root == null or not is_instance_valid(_bar_root):
		return Vector3.ZERO
	return _bar_world_pos()


func _bar_world_pos() -> Vector3:
	var h := SpellWallLayout.height_of(ability)
	if _is_nature():
		var top := _top_nature_mesh()
		var at := top.global_position if top != null else global_position
		at.y = at.y + h * 0.5 + 0.22
		return at
	var acc := Vector3.ZERO
	var n := 0
	for mesh in _meshes:
		if mesh == null or not is_instance_valid(mesh) or not mesh.visible:
			continue
		acc += mesh.global_position
		n += 1
	var at := global_position if n <= 0 else acc / float(n)
	at.y = global_position.y + h * 0.5 + 0.42
	return at


func _top_nature_mesh() -> MeshInstance3D:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var best: MeshInstance3D = null
	var best_score := INF
	for mesh in _meshes:
		if mesh == null or not is_instance_valid(mesh) or not mesh.visible:
			continue
		var score := -mesh.global_position.z
		if cam != null:
			score = cam.unproject_position(mesh.global_position).y
		if score < best_score:
			best_score = score
			best = mesh
	return best


func _orient_bar() -> void:
	if _bar_root == null or not is_instance_valid(_bar_root):
		return
	var pos := _bar_world_pos()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		_bar_root.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	var z := cam.global_position - pos
	if z.length_squared() < 0.0001:
		_bar_root.global_transform = Transform3D(Basis.IDENTITY, pos)
		return
	z = z.normalized()
	var x := cam.global_transform.basis.y.cross(z)
	if x.length_squared() < 0.0001:
		x = cam.global_transform.basis.x
	x = x.normalized()
	var y := z.cross(x).normalized()
	_bar_root.global_transform = Transform3D(Basis(x, y, z), pos)


func _apply_grow(u: float) -> void:
	var t := clampf(u, 0.0, 1.0)
	for i in _full_sizes.size():
		var full := _full_sizes[i]
		var tall := _is_physical() or _is_wind() or _is_illusion()
		var size := Vector3(
			lerpf(0.16, full.x, t),
			lerpf(0.08 if not tall else 0.28, full.y, t),
			lerpf(0.12 if not tall else 0.18, full.z, t)
		)
		var lift := 0.0 if not tall else (size.y - full.y) * 0.5
		var offset := _seg_offsets[i] if i < _seg_offsets.size() else Vector3.ZERO
		var at := Vector3(offset.x, offset.y + lift, offset.z)
		if i < _meshes.size() and is_instance_valid(_meshes[i]):
			if _meshes[i].mesh is SphereMesh:
				_meshes[i].scale = size
				_meshes[i].position = at
			elif _meshes[i].mesh is BoxMesh:
				(_meshes[i].mesh as BoxMesh).size = size
				_meshes[i].position = at
			elif _meshes[i].mesh is CapsuleMesh:
				var cap := _meshes[i].mesh as CapsuleMesh
				cap.radius = size.z
				cap.height = maxf(size.x, size.z * 2.0 + 0.001)
				var cap_stretch := size.y / maxf(size.z * 2.0, 0.01)
				_meshes[i].scale = Vector3(cap_stretch, 1.0, 1.0)
				_meshes[i].position = at
			elif _meshes[i].mesh is CylinderMesh:
				var cyl := _meshes[i].mesh as CylinderMesh
				cyl.top_radius = size.x
				cyl.bottom_radius = size.x
				cyl.height = size.y
				_meshes[i].position = at
		if i < _shapes.size() and is_instance_valid(_shapes[i]):
			if _shapes[i].shape is SphereShape3D:
				_shapes[i].scale = size
				_shapes[i].position = at
			elif _shapes[i].shape is BoxShape3D:
				var col_size := size
				var col_at := at
				if _is_nature():
					var col_h := lerpf(0.28, HEIGHT, t)
					col_size = Vector3(size.x, col_h, size.z)
					col_at = Vector3(offset.x, (col_h - full.y) * 0.5, offset.z)
				(_shapes[i].shape as BoxShape3D).size = col_size
				_shapes[i].position = col_at
			elif _shapes[i].shape is CapsuleShape3D:
				var cap_col := _shapes[i].shape as CapsuleShape3D
				cap_col.radius = size.z
				cap_col.height = maxf(size.x, size.z * 2.0 + 0.001)
				var cap_stretch := size.y / maxf(size.z * 2.0, 0.01)
				_shapes[i].scale = Vector3(cap_stretch, 1.0, 1.0)
				_shapes[i].position = at
			elif _shapes[i].shape is CylinderShape3D:
				var col := _shapes[i].shape as CylinderShape3D
				col.radius = size.x
				col.height = size.y
				_shapes[i].position = at
	if _is_divine():
		var rad := SpellWallLayout.divine_radius(ability)
		var s := lerpf(0.12, rad, t)
		if _disc != null and is_instance_valid(_disc):
			_disc.scale = Vector3(s, 1.0, s)
			var sh := _disc.material_override as ShaderMaterial
			if sh:
				sh.set_shader_parameter("quad_size", Vector2(s, s))
		if _dome != null and is_instance_valid(_dome):
			var peak := SpellWallLayout.divine_height(ability)
			_dome.scale = Vector3(s, lerpf(0.08, peak, t), s)


func _push_overlaps() -> void:
	var arena := ArenaState.arena as Arena
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_structure:
			continue
		var dest := _nudge_out(u)
		if dest == u.global_position:
			continue
		if arena:
			dest = arena.clamp_movement_point(dest, maxf(u.radius, 0.35))
		dest.y = u.global_position.y
		u.global_position = dest
		u.velocity = Vector3.ZERO


func _nudge_out(u: Unit) -> Vector3:
	if _is_ice():
		return _nudge_out_ice(u)
	var pos := u.global_position
	var pad := u.radius + 0.1
	for shape in _shapes:
		if not is_instance_valid(shape) or shape.disabled:
			continue
		var local := shape.to_local(pos)
		if shape.shape is CylinderShape3D:
			var cyl := shape.shape as CylinderShape3D
			var xz := Vector2(local.x, local.z)
			var need := cyl.radius + pad
			if xz.length() >= need:
				continue
			if xz.length_squared() < 0.000001:
				xz = Vector2(need, 0.0)
			else:
				xz = xz.normalized() * need
			local.x = xz.x
			local.z = xz.y
			pos = shape.to_global(local)
			pos.y = u.global_position.y
			continue
		if not (shape.shape is BoxShape3D):
			continue
		var box := shape.shape as BoxShape3D
		var half := box.size * 0.5
		var hx := half.x + pad
		var hz := half.z + pad
		if absf(local.x) >= hx or absf(local.z) >= hz:
			continue
		var push_x := hx - absf(local.x)
		var push_z := hz - absf(local.z)
		if push_x < push_z:
			local.x = hx * (1.0 if local.x >= 0.0 else -1.0)
		else:
			local.z = hz * (1.0 if local.z >= 0.0 else -1.0)
		pos = shape.to_global(local)
		pos.y = u.global_position.y
	return pos


func _nudge_out_ice(u: Unit) -> Vector3:
	var pos := u.global_position
	var pad := u.radius + 0.1
	var local := to_local(pos)
	var r := SpellWallLayout.ice_radius(ability) + pad
	var half := SpellWallLayout.ice_medial_half(ability)
	var x := clampf(local.x, -half, half)
	var d := Vector2(local.x - x, local.z)
	if d.length() >= r:
		return pos
	if d.length_squared() < 0.000001:
		d = Vector2(0.0, 1.0)
	else:
		d = d.normalized()
	local.x = x + d.x * r
	local.z = d.y * r
	pos = to_global(local)
	pos.y = u.global_position.y
	return pos


func _is_physical() -> bool:
	return SpellWallLayout.is_physical(ability)


func owner_team() -> int:
	if source != null and is_instance_valid(source):
		return source.team
	return Unit.TEAM_RAID


func can_be_targeted_by(from: Unit) -> bool:
	if not living or not _is_physical() or _is_protection():
		return false
	return _allows_unit(from)


func can_be_damaged_by(from: Unit) -> bool:
	return can_be_targeted_by(from)


func takes_hits_from(from: Unit) -> bool:
	return can_be_damaged_by(from)


func is_player_targetable() -> bool:
	return can_be_targeted_by(ArenaState.champion)


func blocks_shot(shot_source: Unit) -> bool:
	if not living or collision_layer == 0:
		return false
	return not lets_through(shot_source)


func is_cover_solid() -> bool:
	return living and collision_layer != 0


func cover_half() -> float:
	if _is_ice():
		return maxf(SpellWallLayout.ice_radius(ability), 0.45)
	if _is_lightning():
		return maxf(SpellWallLayout.lightning_radius(ability), 0.35)
	if _is_nature():
		return maxf(SpellWallLayout.nature_radius(ability) * 0.12, 0.4)
	return maxf(SpellWallLayout.thickness_of(ability) * 0.5, 0.45)


func occludes_segment(from: Vector3, to: Vector3, pad: float = 0.2) -> bool:
	if not is_cover_solid():
		return false
	if covers_segment(from, to, pad):
		return true
	var steps := 8
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		if range_to(p) <= pad:
			return true
	return false


static func cover_occludes(from: Vector3, to: Vector3, extra_exclude: Array[RID] = [], pad: float = 0.2) -> bool:
	for wall in living_walls():
		if extra_exclude.has(wall.get_rid()):
			continue
		if wall.occludes_segment(from, to, pad):
			return true
	return false


func _allows_unit(from: Unit) -> bool:
	if from == null or not is_instance_valid(from):
		return allegiance == Allegiance.CONTESTED
	match allegiance:
		Allegiance.ALLIED:
			return from.team != owner_team()
		Allegiance.ENEMY:
			return from.team == owner_team()
		Allegiance.CONTESTED:
			return true
	return false


func _proxy_team() -> int:
	var mine := owner_team()
	match allegiance:
		Allegiance.ALLIED:
			return mine
		Allegiance.ENEMY:
			return Unit.TEAM_BOSS if mine == Unit.TEAM_RAID else Unit.TEAM_RAID
		Allegiance.CONTESTED:
			return Unit.TEAM_CONTESTED
	return Unit.TEAM_CONTESTED


static func living_walls() -> Array[SpellWall]:
	var out: Array[SpellWall] = []
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return out
	for node in (tree as SceneTree).get_nodes_in_group("spell_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if wall.living:
			out.append(wall)
	return out


static func apply_radius_hit(
	from: Unit,
	origin: Vector3,
	radius: float,
	amount: float,
	hit_kind: String = "hit",
	number_color: Color = Color(0, 0, 0, 0),
	text_cast_id: int = -1,
	need_los: bool = false
) -> void:
	if amount <= 0.0 or radius <= 0.0:
		return
	var arena := ArenaState.arena as Arena
	var exclude: Array[RID] = []
	if from != null and is_instance_valid(from):
		exclude.append(from.get_rid())
	for wall in living_walls():
		if not wall.can_be_damaged_by(from):
			continue
		if wall.range_to(origin) > radius:
			continue
		if need_los and arena != null:
			var skip := exclude.duplicate()
			skip.append(wall.get_rid())
			if not arena.spell_has_los(origin, wall.aim_point(origin), skip):
				continue
		wall.take_hit(amount, wall.aim_point(origin), from, hit_kind, number_color, false, text_cast_id)


static func apply_cone_hit(
	from: Unit,
	origin: Vector3,
	dir: Vector3,
	length: float,
	half_angle: float,
	amount: float,
	hit_kind: String = "hit",
	number_color: Color = Color(0, 0, 0, 0),
	text_cast_id: int = -1
) -> void:
	if amount <= 0.0 or length <= 0.0:
		return
	var forward := Vector3(dir.x, 0.0, dir.z)
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()
	var arena := ArenaState.arena as Arena
	var exclude: Array[RID] = []
	if from != null and is_instance_valid(from):
		exclude.append(from.get_rid())
	for wall in living_walls():
		if not wall.can_be_damaged_by(from):
			continue
		if wall.range_to(origin) > length:
			continue
		var aim := wall.aim_point(origin) - origin
		aim.y = 0.0
		if aim.length() > 0.04 and absf(forward.signed_angle_to(aim.normalized(), Vector3.UP)) > half_angle + 0.12:
			continue
		if arena != null:
			var skip := exclude.duplicate()
			skip.append(wall.get_rid())
			if not arena.spell_has_los(origin, wall.aim_point(origin), skip):
				continue
		wall.take_hit(amount, wall.aim_point(origin), from, hit_kind, number_color, false, text_cast_id)


func target_proxy() -> Unit:
	if _target_proxy != null and is_instance_valid(_target_proxy) and not _target_proxy.is_dead:
		return _target_proxy
	return null


func set_targeted(on: bool, color: Color = Color(1.0, 0.82, 0.28, 0.92)) -> void:
	if not on:
		color = Color(1.0, 0.82, 0.28, 0.92)
	if _targeted == on and _hover_color.is_equal_approx(color):
		return
	_targeted = on
	_hover_color = color
	_apply_hover_outline()
	_refresh()


func range_to(from: Vector3) -> float:
	if _is_ice():
		var ice_local := to_local(from)
		return SpellWallLayout.ice_distance_xz(Vector2(ice_local.x, ice_local.z), ability)
	var best := INF
	for i in _shapes.size():
		var shape := _shapes[i]
		if not is_instance_valid(shape) or shape.disabled:
			continue
		var local := shape.to_local(from)
		local.y = 0.0
		var d := 0.0
		if shape.shape is CylinderShape3D:
			var cyl := shape.shape as CylinderShape3D
			d = maxf(0.0, Vector2(local.x, local.z).length() - cyl.radius)
		elif shape.shape is BoxShape3D:
			var box := shape.shape as BoxShape3D
			var half := box.size * 0.5
			var dx := maxf(0.0, absf(local.x) - half.x)
			var dz := maxf(0.0, absf(local.z) - half.z)
			d = Vector2(dx, dz).length()
		else:
			d = Vector2(local.x, local.z).length()
		if d < best:
			best = d
	if best < INF:
		return best
	var to := global_position - from
	to.y = 0.0
	return to.length()


func aim_point(from: Vector3) -> Vector3:
	var best := global_position
	var best_d := INF
	var found := false
	for shape in _shapes:
		if shape == null or not is_instance_valid(shape) or shape.disabled:
			continue
		var at := shape.global_position
		var dx := at.x - from.x
		var dz := at.z - from.z
		var d := dx * dx + dz * dz
		if d < best_d:
			best_d = d
			best = at
			found = true
	if not found:
		best = global_position + Vector3(0.0, 1.0, 0.0)
	return best


func click_world_points() -> PackedVector3Array:
	if _is_ice():
		var out_ice := PackedVector3Array()
		var hx := SpellWallLayout.ice_length(ability) * 0.5
		var hy := SpellWallLayout.height_of(ability) * 0.5
		var hz := SpellWallLayout.ice_radius(ability)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out_ice.append(to_global(Vector3(hx * sx, hy * sy, hz * sz)))
		return out_ice
	var out := PackedVector3Array()
	for i in _shapes.size():
		var shape := _shapes[i]
		if not is_instance_valid(shape) or shape.disabled:
			continue
		var xf := shape.global_transform
		if shape.shape is CylinderShape3D:
			var cyl := shape.shape as CylinderShape3D
			var r := cyl.radius
			var hy := cyl.height * 0.5
			out.append(xf * Vector3(-r, -hy, 0.0))
			out.append(xf * Vector3(r, -hy, 0.0))
			out.append(xf * Vector3(0.0, -hy, -r))
			out.append(xf * Vector3(0.0, -hy, r))
			out.append(xf * Vector3(-r, hy, 0.0))
			out.append(xf * Vector3(r, hy, 0.0))
			out.append(xf * Vector3(0.0, hy, -r))
			out.append(xf * Vector3(0.0, hy, r))
			continue
		if not (shape.shape is BoxShape3D):
			out.append(shape.global_position)
			continue
		var box := shape.shape as BoxShape3D
		var half := box.size * 0.5
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(xf * Vector3(half.x * sx, half.y * sy, half.z * sz))
	if out.is_empty():
		var h := SpellWallLayout.height_of(ability) * 0.5
		out.append(global_position + Vector3(0.0, -h, 0.0))
		out.append(global_position + Vector3(0.0, h, 0.0))
	return out


func _attach_target_proxy() -> void:
	if not living or not _is_physical() or _is_protection():
		return
	var u := Unit.new()
	u.is_structure = true
	u.host_wall = self
	u.unit_name = _proxy_name()
	u.team = _proxy_team()
	u.max_health = max_health
	u.max_mana = 0.0
	u.radius = _proxy_radius()
	u.height = SpellWallLayout.height_of(ability)
	u.move_speed = 0.0
	u.ai_enabled = false
	u.visual_path = ""
	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	u.add_child(nav)
	var ctrl := _UnitController.new()
	ctrl.name = "Controller"
	u.add_child(ctrl)
	var mov := _UnitMovement.new()
	mov.name = "Movement"
	u.add_child(mov)
	var aa := _AutoAttack.new()
	aa.name = "AutoAttack"
	u.add_child(aa)
	add_child(u)
	u.position = Vector3(0.0, -u.height * 0.5, 0.0)
	_target_proxy = u
	add_to_group("spell_hittable_walls")


func _proxy_radius() -> float:
	if _is_ice():
		return maxf(SpellWallLayout.ice_radius(), 0.55)
	return maxf(SpellWallLayout.thickness_of(ability) * 0.5, 0.45)


func _proxy_name() -> String:
	if ability != null and not ability.display_name.is_empty():
		var base := ability.display_name
		if not base.to_lower().contains("wall"):
			return "%s Wall" % base
		return base
	var style := SpellWallLayout.style_id(ability)
	if style.is_empty():
		return "Wall"
	return "%s Wall" % style.capitalize()


func _sync_proxy() -> void:
	if _target_proxy == null or not is_instance_valid(_target_proxy):
		return
	_target_proxy.max_health = max_health
	_target_proxy.health = health


func _release_proxy() -> void:
	remove_from_group("spell_hittable_walls")
	var proxy := _target_proxy
	_target_proxy = null
	if proxy == null or not is_instance_valid(proxy):
		return
	proxy.host_wall = null
	if not proxy.is_dead:
		proxy.is_dead = true
		proxy.health = 0.0
		proxy.died.emit(proxy)
	ArenaState.unregister_unit(proxy)
	proxy.queue_free()


func _is_ice() -> bool:
	return SpellWallLayout.style_id(ability) == "ice"


func _is_shadow() -> bool:
	return SpellWallLayout.style_id(ability) == "shadow"


func _is_wind() -> bool:
	return SpellWallLayout.style_id(ability) == "wind"


func _is_fire() -> bool:
	return SpellWallLayout.style_id(ability) == "fire"


func _is_illusion() -> bool:
	return SpellWallLayout.style_id(ability) == "illusion"


func _is_nature() -> bool:
	return SpellWallLayout.style_id(ability) == "nature"


func _is_divine() -> bool:
	return SpellWallLayout.style_id(ability) == "divine"


func _is_lightning() -> bool:
	return SpellWallLayout.style_id(ability) == "lightning"


func _is_protection() -> bool:
	return SpellWallLayout.style_id(ability) == "protection"


func aim_protection(dir: Vector3) -> void:
	if not _is_protection() or not living:
		return
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_protect_target_dir = dir.normalized()
	_follow_protection()


func _tick_protection_turn(delta: float) -> void:
	var to := Vector3(_protect_target_dir.x, 0.0, _protect_target_dir.z)
	if to.length_squared() < 0.0001:
		return
	to = to.normalized()
	var from := Vector3(_protect_dir.x, 0.0, _protect_dir.z)
	if from.length_squared() < 0.0001:
		_protect_dir = to
		return
	from = from.normalized()
	var from_yaw := atan2(from.x, from.z)
	var to_yaw := atan2(to.x, to.z)
	var turn := CombatBalance.flat("wall.protection.turn")
	var speed := PI / maxf(turn, 0.01)
	var yaw := rotate_toward(from_yaw, to_yaw, speed * delta)
	_protect_dir = Vector3(sin(yaw), 0.0, cos(yaw))


func _follow_protection() -> void:
	if source == null or not is_instance_valid(source) or source.is_dead:
		detonate(false)
		return
	var dir := _protect_dir
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = source.facing_dir()
	dir = dir.normalized()
	_protect_dir = dir
	var height := SpellWallLayout.height_of(ability)
	var origin := Vector3(source.global_position.x, height * 0.5, source.global_position.z)
	global_transform = Transform3D(SpellWallLayout.wall_basis(dir), origin)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
	_ignore_unit_collision()


func _ignore_unit_collision() -> void:
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u):
			continue
		add_collision_exception_with(u)


func _build_divine() -> void:
	var rad := SpellWallLayout.divine_radius(ability)
	var pal := _SpellBaseFx.palette(ability) if ability != null else {"core": Color(0.95, 0.84, 0.38), "rim": Color(1.0, 0.92, 0.55)}
	_disc = MeshInstance3D.new()
	_disc.name = "DivineDisc"
	_disc.mesh = GroundIndicator.circle_mesh()
	_disc.extra_cull_margin = 16.0
	var disc_mat := GroundIndicator.zone_mat(pal.core, rad, 0.04, 0.72)
	GroundIndicator.set_rim(disc_mat, pal.rim)
	disc_mat.render_priority = 4
	_disc.material_override = disc_mat
	GroundIndicator.prepare(_disc)
	add_child(_disc)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.is_hemisphere = true
	sphere.radial_segments = 28
	sphere.rings = 14
	_dome = MeshInstance3D.new()
	_dome.name = "DivineDome"
	_dome.mesh = sphere
	_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dome_mat := StandardMaterial3D.new()
	dome_mat.albedo_color = Color(0.98, 0.88, 0.42, 0.07)
	dome_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dome_mat.roughness = 0.08
	dome_mat.metallic = 0.08
	dome_mat.emission_enabled = true
	dome_mat.emission = Color(1.0, 0.86, 0.38)
	dome_mat.emission_energy_multiplier = 0.38
	dome_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome_mat.disable_receive_shadows = true
	_dome.material_override = dome_mat
	_mat = dome_mat
	add_child(_dome)
	FxHeroLights.bind(self, Color(1.0, 0.88, 0.48), 0.9, rad * 1.2)
	_apply_grow(0.0)


func _flicker_divine() -> void:
	if _mat == null:
		return
	_mat.emission_energy_multiplier = 0.32 + 0.14 * absf(sin(_elapsed * 4.2))


func _refresh_divine_dr() -> void:
	if source == null or not is_instance_valid(source):
		return
	var amount := CombatBalance.pct("wall.divine.dr")
	if amount <= 0.0:
		return
	var pos := global_position
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != source.team:
			continue
		if not SpellWallLayout.contains_point(pos, Vector3(0, 0, -1), ability, u.global_position, u.radius):
			continue
		u.apply_damage_reduction(amount, 0.15)


static func shot_block_mask() -> int:
	return LAYER_WORLD | LAYER_BARRIER


func lets_through(shot_source: Unit) -> bool:
	if not living:
		return false
	if not SpellWallLayout.allied_shots_pass(ability):
		return false
	return _is_ally_of(shot_source)


func _is_ally_of(u: Unit) -> bool:
	if source == null or not is_instance_valid(source) or u == null or not is_instance_valid(u):
		return false
	return u.team == source.team


static func append_pass_excludes(exclude: Array[RID], shot_source: Unit) -> void:
	if shot_source == null:
		return
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return
	for node in (tree as SceneTree).get_nodes_in_group("spell_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if not wall.lets_through(shot_source):
			continue
		exclude.append(wall.get_rid())


func can_reflect(shot_source: Unit) -> bool:
	if not living or not _is_wind():
		return false
	if source == null or not is_instance_valid(source):
		return false
	if shot_source == null or not is_instance_valid(shot_source):
		return true
	return shot_source.team != source.team


func face_normal(incoming: Vector3) -> Vector3:
	var n := global_transform.basis.z
	n.y = 0.0
	if n.length_squared() < 0.0001:
		n = Vector3(0, 0, 1)
	else:
		n = n.normalized()
	var incoming_flat := Vector3(incoming.x, 0.0, incoming.z)
	if incoming_flat.dot(n) > 0.0:
		n = -n
	return n


func _take_seg_hit(amount: float, at: Vector3) -> void:
	var idx := _nearest_living_seg(at)
	if idx < 0:
		return
	_seg_health[idx] = maxf(0.0, _seg_health[idx] - amount)
	_refresh_seg(idx)
	if _seg_health[idx] > 0.0:
		return
	_break_seg(idx)
	if _living_seg_count() <= 0:
		detonate(false)


func _nearest_living_seg(at: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in _shapes.size():
		if i >= _seg_health.size() or _seg_health[i] <= 0.0:
			continue
		var shape := _shapes[i]
		if not is_instance_valid(shape):
			continue
		var d := shape.global_position.distance_squared_to(at)
		if d < best_d:
			best_d = d
			best = i
	return best


func _living_seg_count() -> int:
	var n := 0
	for hp in _seg_health:
		if hp > 0.0:
			n += 1
	return n


func _break_seg(idx: int) -> void:
	if idx < 0 or idx >= _shapes.size():
		return
	if idx < _meshes.size() and is_instance_valid(_meshes[idx]):
		_meshes[idx].visible = false
	if is_instance_valid(_shapes[idx]):
		_shapes[idx].disabled = true
	_nature_heal_blast()


func _refresh_seg(idx: int) -> void:
	if idx < 0 or idx >= _seg_mats.size() or _seg_mats[idx] == null:
		return
	var r := clampf(_seg_health[idx] / maxf(max_health, 1.0), 0.0, 1.0)
	_seg_mats[idx].emission_energy_multiplier = 0.28 + 0.7 * r


func _tick_nature_grove(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var interval := 1.0
	_nature_tick_acc += delta
	if not _nature_ticked:
		_nature_ticked = true
		_pulse_nature_heal(false)
		_nature_tick_acc = 0.0
		return
	if _nature_tick_acc < interval:
		return
	_nature_tick_acc -= interval
	_pulse_nature_heal(false)


func _tick_nature_walk() -> void:
	if source == null or not is_instance_valid(source):
		return
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead or u.is_structure:
			continue
		if u.team == source.team:
			continue
		if _unit_on_hedge(u):
			u.refresh_nature_hedge_slow()


func _unit_on_hedge(u: Unit) -> bool:
	var pos := u.global_position
	var pad := u.radius
	for shape in _shapes:
		if not is_instance_valid(shape) or shape.disabled:
			continue
		if not (shape.shape is BoxShape3D):
			continue
		var local := shape.to_local(pos)
		var box := shape.shape as BoxShape3D
		var half := box.size * 0.5
		if absf(local.x) <= half.x + pad and absf(local.z) <= half.z + pad:
			return true
	return false


func _nature_heal_blast() -> void:
	_pulse_nature_heal(true)
	_SpellBaseFx.burst(Vector3(global_position.x, 0.12, global_position.z), SpellWallLayout.nature_radius(ability), ability)


func _pulse_nature_heal(broken: bool) -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	var raw := CombatBalance.flat("wall.nature.blast") if broken else CombatBalance.flat("wall.nature.tick")
	var amt := source._scaled(raw)
	if amt <= 0.0:
		return
	var rad := SpellWallLayout.nature_radius(ability)
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team != source.team:
			continue
		var to := u.global_position - global_position
		to.y = 0.0
		if to.length() > rad + u.radius:
			continue
		u.apply_support_hit(source, amt, 0.0, 0.0, true, AbilityDef.combat_id_of(ability, "wall"), 0.0, extras, ability.element if ability else AbilityDef.Element.NONE, combat_text_cast_id, false)


func _flicker_fire() -> void:
	if _mat == null:
		return
	_mat.emission_energy_multiplier = 2.6 + 1.4 * absf(sin(_elapsed * 14.0))


func _flicker_wind() -> void:
	if _mat == null:
		return
	_mat.emission_energy_multiplier = 0.85 + 0.55 * absf(sin(_elapsed * 7.0))


func _flicker_portal() -> void:
	if _mat == null:
		return
	var pulse := 0.55 + 0.45 * absf(sin(_elapsed * 8.0))
	if _illusion_role == "outlet":
		_mat.emission_energy_multiplier = 2.2 + 1.8 * pulse
		if _portal_rim_mat != null:
			_portal_rim_mat.emission_energy_multiplier = 2.6 + 1.4 * pulse
	else:
		_mat.emission_energy_multiplier = 1.4 + 1.1 * pulse
		if _portal_rim_mat != null:
			_portal_rim_mat.emission_energy_multiplier = 1.8 + 0.9 * pulse


func _build_portal_cylinder() -> void:
	var radius := SpellWallLayout.illusion_radius(ability)
	var height := SpellWallLayout.illusion_height(ability)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.28
	var mesh := MeshInstance3D.new()
	mesh.name = "PortalCylinder"
	mesh.mesh = cyl
	mesh.material_override = _mat
	add_child(mesh)
	_meshes.append(mesh)
	_full_sizes.append(Vector3(radius, height, radius))
	_seg_offsets.append(Vector3.ZERO)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var col := CylinderShape3D.new()
	col.radius = 0.06
	col.height = 0.28
	shape.shape = col
	shape.disabled = true
	add_child(shape)
	_shapes.append(shape)


func _register_illusion() -> void:
	if source == null or not is_instance_valid(source):
		_illusion_role = "inlet"
		return
	var id := source.get_instance_id()
	var inlet := _living_illusion_inlet(id)
	if inlet != null and inlet != self:
		if _illusion_outlet_live(inlet) and inlet._illusion_moves_left > 0:
			_bind_as_outlet(inlet)
			var old := inlet._illusion_outlet
			inlet._illusion_outlet = self
			if old != null and is_instance_valid(old) and old.living and old != self:
				old.detonate(false)
			inlet._illusion_moves_left -= 1
			inlet._offer_outlet_recast()
			return
		if not _illusion_outlet_live(inlet):
			_bind_as_outlet(inlet)
			inlet._illusion_outlet = self
			inlet._illusion_moves_left = maxi(int(round(CombatBalance.flat("wall.illusion.moves"))), 0)
			inlet._flush_illusion()
			inlet._offer_outlet_recast()
			return
	detonate_owned_by(source, self)
	_illusion_role = "inlet"
	_illusion_moves_left = 0
	_illusion_inlets[id] = self
	_tint_portal()


func _bind_as_outlet(inlet: SpellWall) -> void:
	_illusion_role = "outlet"
	inlet._tint_portal()
	_tint_portal()


func _offer_outlet_recast() -> void:
	if _illusion_moves_left <= 0:
		return
	if source == null or not is_instance_valid(source):
		return
	source._arm_illusion_portal_recast(maxf(duration - _elapsed, 0.05))


func _living_illusion_inlet(caster_id: int) -> SpellWall:
	var raw = _illusion_inlets.get(caster_id)
	if raw == null or not is_instance_valid(raw) or not (raw is SpellWall):
		return null
	var inlet := raw as SpellWall
	if not inlet.living:
		return null
	return inlet


static func _illusion_outlet_live(inlet: SpellWall) -> bool:
	if inlet == null:
		return false
	var outlet := inlet._illusion_outlet
	return outlet != null and is_instance_valid(outlet) and outlet.living


static func outlet_moves_left(caster: Unit) -> int:
	if caster == null or not is_instance_valid(caster):
		return 0
	var raw = _illusion_inlets.get(caster.get_instance_id())
	if raw == null or not is_instance_valid(raw) or not (raw is SpellWall):
		return 0
	var inlet := raw as SpellWall
	if not inlet.living:
		return 0
	if not _illusion_outlet_live(inlet):
		return 0
	return inlet._illusion_moves_left


func _release_illusion() -> void:
	if source != null and is_instance_valid(source):
		var id := source.get_instance_id()
		if _illusion_inlets.get(id) == self:
			_illusion_inlets.erase(id)
			source._clear_recast()
	_illusion_queue.clear()
	_illusion_outlet = null
	_illusion_moves_left = 0


func _tint_portal() -> void:
	if _mat == null:
		return
	if _illusion_role == "outlet":
		_mat.albedo_color = Color(1.0, 0.72, 0.92, 0.42)
		_mat.emission = Color(1.0, 0.78, 0.95)
		if _portal_rim_mat != null:
			_portal_rim_mat.albedo_color = Color(0.95, 0.55, 0.82, 0.92)
			_portal_rim_mat.emission = Color(1.0, 0.72, 0.9)
	else:
		_mat.albedo_color = Color(0.62, 0.18, 0.55, 0.5)
		_mat.emission = Color(0.72, 0.22, 0.68)
		if _portal_rim_mat != null:
			_portal_rim_mat.albedo_color = Color(0.42, 0.08, 0.38, 0.9)
			_portal_rim_mat.emission = Color(0.85, 0.35, 0.75)


func _flush_illusion() -> void:
	var delay := 0.0
	for snap in _illusion_queue:
		_emit_illusion(snap, delay)
		delay += 0.05
	_illusion_queue.clear()


func absorb_projectile(shot: Projectile) -> void:
	if not living or shot == null or _illusion_role == "outlet":
		return
	var snap := shot.snapshot()
	snap["inlet_forward"] = emit_dir()
	snap["height"] = shot.global_position.y
	if _illusion_outlet != null and is_instance_valid(_illusion_outlet) and _illusion_outlet.living:
		_emit_illusion(snap, 0.0)
	else:
		_illusion_queue.append(snap)
	shot.swallow()


func _emit_illusion(snap: Dictionary, delay: float) -> void:
	if delay <= 0.02:
		_spawn_illusion_shot(snap)
		return
	if not is_inside_tree():
		_spawn_illusion_shot(snap)
		return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(_spawn_illusion_shot.bind(snap))


func _spawn_illusion_shot(snap: Dictionary) -> void:
	var gate := _illusion_outlet if _illusion_outlet != null and is_instance_valid(_illusion_outlet) and _illusion_outlet.living else self
	if gate == null or not is_instance_valid(gate) or not gate.living:
		return
	var original := snap.get("source") as Unit
	var owner := source
	var caster := original
	var converted := false
	if owner != null and is_instance_valid(owner):
		if original == null or not is_instance_valid(original) or original.team != owner.team:
			caster = owner
			converted = original != null and is_instance_valid(original) and original.team != owner.team
		else:
			caster = original
	if caster == null or not is_instance_valid(caster):
		return
	var cfg := snap.duplicate(true)
	var out_dir := _portal_exit_dir(snap, gate)
	cfg["direction"] = out_dir
	cfg["portal_exit"] = true
	if converted:
		cfg["heal_allies"] = false
		cfg["heal"] = 0.0
		cfg["shield"] = 0.0
		cfg["shield_duration"] = 0.0
		cfg["applies_rejuvenation"] = false
		cfg["blessing_power"] = 0.0
		cfg["ally_cast"] = false
		cfg["hit_cooldown_reduction"] = 0.0
		var home = cfg.get("homing")
		if home is Unit and is_instance_valid(home) and home.team == owner.team:
			cfg["homing"] = null
			cfg["arc_width"] = 0.0
	var origin := gate.emit_point_along(out_dir, float(snap.get("height", -1.0)))
	var shot := Projectile._make(caster, origin, cfg, true)
	if shot:
		shot._portal_hops = int(snap.get("portal_hops", 0)) + 1
		if converted:
			shot.source = owner


func _portal_exit_dir(snap: Dictionary, gate: SpellWall) -> Vector3:
	var incoming := Vector3(snap.get("direction", Vector3.FORWARD))
	incoming.y = 0.0
	if incoming.length_squared() < 0.0001:
		return gate.emit_dir()
	incoming = incoming.normalized()
	var inlet_fwd := Vector3(snap.get("inlet_forward", incoming))
	inlet_fwd.y = 0.0
	if inlet_fwd.length_squared() < 0.0001:
		return incoming
	inlet_fwd = inlet_fwd.normalized()
	var yaw := inlet_fwd.signed_angle_to(incoming, Vector3.UP)
	return gate.emit_dir().rotated(Vector3.UP, yaw)


func emit_dir() -> Vector3:
	var dir := -global_transform.basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = Vector3(0, 0, -1)
	else:
		dir = dir.normalized()
	if _illusion_role == "outlet":
		dir = -dir
	return dir


func emit_point() -> Vector3:
	return emit_point_along(emit_dir())


func emit_point_along(dir: Vector3, height: float = -1.0) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = emit_dir()
	else:
		flat = flat.normalized()
	var pad := SpellWallLayout.illusion_radius(ability) + 0.38
	var at := global_position + flat * pad
	if height > 0.05:
		var half := SpellWallLayout.illusion_height(ability) * 0.5 - 0.2
		at.y = clampf(height, global_position.y - half, global_position.y + half)
	else:
		at.y = maxf(global_position.y, 0.45)
	return at


static func protection_hit(from: Vector3, to: Vector3, pad: float = 0.12) -> SpellWall:
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return null
	for node in (tree as SceneTree).get_nodes_in_group("spell_protection_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if not wall.living:
			continue
		if wall.covers_segment(from, to, pad):
			return wall
	return null


static func illusion_inlet_hit(from: Vector3, to: Vector3, pad: float = 0.12) -> SpellWall:
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return null
	for node in (tree as SceneTree).get_nodes_in_group("spell_illusion_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if not wall.living:
			continue
		if wall._illusion_role == "outlet":
			continue
		if wall.covers_segment(from, to, pad):
			return wall
	return null


static func detonate_owned_by(caster: Unit, keep: SpellWall = null) -> void:
	if caster == null:
		return
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return
	var nodes: Array = (tree as SceneTree).get_nodes_in_group("spell_illusion_walls")
	for node in nodes:
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if wall == keep or not wall.living:
			continue
		if wall.source != caster:
			continue
		wall.detonate(false)


func _tick_fire_line(delta: float) -> void:
	if source == null or not is_instance_valid(source):
		return
	var bonus := CombatBalance.flat("wall.fire.bonus")
	if bonus <= 0.0:
		return
	var seen: Dictionary = {}
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == source.team:
			continue
		if not _enemy_on_fire(u, delta):
			continue
		var id := u.get_instance_id()
		seen[id] = true
		if not _fire_on.has(id):
			_apply_fire_flat(u, bonus)
			_fire_on[id] = 1.0
			continue
		var wait := float(_fire_on[id]) - delta
		if wait <= 0.0:
			_apply_fire_flat(u, bonus)
			wait = 1.0
		_fire_on[id] = wait
	for id in _fire_on.keys():
		if not seen.has(id):
			_fire_on.erase(id)


func _enemy_on_fire(u: Unit, delta: float) -> bool:
	if _touches_unit(u, true):
		return true
	var prev := u.global_position - u.velocity * maxf(delta, 0.0)
	return covers_segment(prev, u.global_position, u.radius + 0.08)


func _apply_fire_flat(u: Unit, amount: float) -> void:
	if source == null or not is_instance_valid(source) or u == null or not is_instance_valid(u):
		return
	var extras_el := extras
	var ab_id := AbilityDef.combat_id_of(ability, "wall")
	u.receive_ability_hit(
		source,
		AbilityDef.Element.FIRE,
		amount,
		0.0,
		extras_el,
		false,
		true,
		true,
		-1,
		0,
		ab_id,
		combat_text_cast_id,
		true
	)


func covers_segment(from: Vector3, to: Vector3, pad: float = 0.0) -> bool:
	if not living:
		return false
	if _is_fire():
		return _covers_fire_line(from, to, pad)
	if _is_illusion():
		return _covers_portal(from, to, pad)
	for shape in _shapes:
		if not is_instance_valid(shape):
			continue
		var a := shape.to_local(from)
		var b := shape.to_local(to)
		if shape.shape is CylinderShape3D:
			var cyl := shape.shape as CylinderShape3D
			if _segment_hits_circle(Vector2(a.x, a.z), Vector2(b.x, b.z), cyl.radius + pad):
				return true
			continue
		if shape.shape is CapsuleShape3D:
			var cap := shape.shape as CapsuleShape3D
			var r := cap.radius * maxf(shape.scale.z, 0.01) + pad
			var half_x := maxf(cap.height * 0.5 * maxf(shape.scale.x, 0.01), r)
			if _segment_hits_capsule_xz(Vector2(a.x, a.z), Vector2(b.x, b.z), half_x, r):
				return true
			continue
		if not (shape.shape is BoxShape3D):
			continue
		var box := shape.shape as BoxShape3D
		var half := box.size * 0.5
		if _segment_hits_rect(
			Vector2(a.x, a.z),
			Vector2(b.x, b.z),
			Vector2(half.x + pad, half.z + pad)
		):
			return true
	return false


static func wind_hit(from: Vector3, to: Vector3, pad: float = 0.12) -> SpellWall:
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return null
	for node in (tree as SceneTree).get_nodes_in_group("spell_wind_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if not wall.living:
			continue
		if wall.covers_segment(from, to, pad):
			return wall
	return null


static func fire_shot_bonus(from: Vector3, to: Vector3, pad: float = 0.12, shot_source = null) -> float:
	if not is_instance_valid(shot_source):
		shot_source = null
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return 0.0
	var bonus := 0.0
	for node in (tree as SceneTree).get_nodes_in_group("spell_fire_walls"):
		if node == null or not is_instance_valid(node) or not (node is SpellWall):
			continue
		var wall := node as SpellWall
		if not wall.living:
			continue
		if shot_source != null and wall.source != null and is_instance_valid(wall.source) and wall.source.team != shot_source.team:
			continue
		if wall.covers_segment(from, to, pad):
			bonus = maxf(bonus, CombatBalance.flat("wall.fire.bonus"))
	return bonus


func _covers_fire_line(from: Vector3, to: Vector3, pad: float) -> bool:
	var half := _fire_line_half(pad)
	var a := to_local(from)
	var b := to_local(to)
	return _segment_hits_rect(Vector2(a.x, a.z), Vector2(b.x, b.z), half)


func _covers_portal(from: Vector3, to: Vector3, pad: float) -> bool:
	var radius := SpellWallLayout.illusion_radius(ability)
	if not _shapes.is_empty() and is_instance_valid(_shapes[0]) and _shapes[0].shape is CylinderShape3D:
		radius = (_shapes[0].shape as CylinderShape3D).radius
	var a := to_local(from)
	var b := to_local(to)
	return _segment_hits_circle(Vector2(a.x, a.z), Vector2(b.x, b.z), radius + pad)


func _fire_line_half(pad: float) -> Vector2:
	var length := SpellWallLayout.length_of(ability)
	var thick := SpellWallLayout.thickness_of(ability)
	return Vector2(length * 0.5 + pad, maxf(thick * 0.5, 0.45) + pad)


static func _segment_hits_rect(a: Vector2, b: Vector2, half: Vector2) -> bool:
	var delta := b - a
	var enter := 0.0
	var exit := 1.0
	for axis in 2:
		var origin := a[axis]
		var direction := delta[axis]
		var extent := half[axis]
		if absf(direction) < 0.00001:
			if absf(origin) <= extent:
				continue
			return false
		var t1 := (-extent - origin) / direction
		var t2 := (extent - origin) / direction
		if t1 > t2:
			var swap := t1
			t1 = t2
			t2 = swap
		enter = maxf(enter, t1)
		exit = minf(exit, t2)
		if enter > exit:
			return false
	return exit >= 0.0 and enter <= 1.0


static func _segment_hits_circle(a: Vector2, b: Vector2, radius: float) -> bool:
	var delta := b - a
	var len2 := delta.length_squared()
	var t := 0.0
	if len2 > 0.00001:
		t = clampf(-a.dot(delta) / len2, 0.0, 1.0)
	return (a + delta * t).length() <= radius


static func _segment_hits_capsule_xz(a: Vector2, b: Vector2, half_x: float, radius: float) -> bool:
	var inner := maxf(half_x - radius, 0.0)
	if _segment_hits_rect(a, b, Vector2(inner, radius)):
		return true
	if _segment_hits_circle(a - Vector2(-inner, 0.0), b - Vector2(-inner, 0.0), radius):
		return true
	return _segment_hits_circle(a - Vector2(inner, 0.0), b - Vector2(inner, 0.0), radius)


func _touches_unit(u: Unit, include_disabled: bool = false) -> bool:
	if _is_fire():
		var half := _fire_line_half(u.radius + 0.12)
		var local := to_local(u.global_position)
		return absf(local.x) <= half.x and absf(local.z) <= half.y
	if _is_ice():
		var ice_local := to_local(u.global_position)
		return SpellWallLayout.ice_distance_xz(Vector2(ice_local.x, ice_local.z), ability) <= u.radius + 0.12
	for shape in _shapes:
		if not is_instance_valid(shape):
			continue
		if shape.disabled and not include_disabled:
			continue
		var local := shape.to_local(u.global_position)
		if shape.shape is CylinderShape3D:
			var cyl := shape.shape as CylinderShape3D
			var xz := Vector2(local.x, local.z)
			if xz.length() <= cyl.radius + u.radius + 0.12:
				return true
			continue
		if not (shape.shape is BoxShape3D):
			continue
		var box := shape.shape as BoxShape3D
		var half := box.size * 0.5
		if absf(local.x) <= half.x + u.radius + 0.12 and absf(local.z) <= half.z + u.radius + 0.12:
			return true
	return false


func _spawn_ice_zones() -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	var zone_r := SpellWallLayout.ice_zone_radius(ability)
	for off in SpellWallLayout.ice_offsets(ability):
		var world := to_global(off)
		var zone := GroundAoeZone.spawn(source, Vector3(world.x, 0.10, world.z), ability, extras, zone_r)
		zone.tick_damage = 0.0
		zone.duration = duration + 0.35
		zone.tick_interval = maxf(SpellCatalog.ground_aoe().tick_interval, 0.05)
		zone._max_ticks = maxi(int(round(zone.duration / zone.tick_interval)), 1)
		zone.reparent(self)
		_zones.append(zone)


func _clear_ice_zones() -> void:
	for zone in _zones:
		if is_instance_valid(zone):
			zone.queue_free()
	_zones.clear()


func _tick_lightning_totem(delta: float) -> void:
	if _mat != null:
		_mat.emission_energy_multiplier = move_toward(_mat.emission_energy_multiplier, 2.2, delta * 10.0)
	if source == null or not is_instance_valid(source) or source.is_dead or ability == null:
		return
	_lightning_acc += delta
	var wait := CombatBalance.flat("wall.lightning.tick")
	if wait < 0.15:
		wait = 1.0
	if _lightning_acc < wait:
		return
	_lightning_acc = 0.0
	var reach := CombatBalance.flat("wall.lightning.range")
	if reach < 1.0:
		reach = 8.0
	var target := _nearest_lightning_foe(reach)
	if target == null:
		return
	var hops := int(round(CombatBalance.flat("wall.lightning.hops")))
	if hops <= 0:
		hops = 3
	var bounce := CombatBalance.flat("wall.lightning.bounce")
	if bounce < 1.0:
		bounce = 7.0
	var origin := global_position + Vector3(0.0, SpellWallLayout.height_of(ability) * 0.55, 0.0)
	var dmg := CombatBalance.wall_hit_damage(health)
	source.chain_lightning_at(origin, target, ability, extras, overheat_cast_id, infusion_double, hops, bounce, combat_text_cast_id, true, dmg, self)
	if _mat != null:
		_mat.emission_energy_multiplier = 4.2


func _nearest_lightning_foe(reach: float) -> Unit:
	var best: Unit = null
	var best_d := reach
	var from := global_position
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_structure:
			continue
		if source != null and is_instance_valid(source) and u.team == source.team:
			continue
		var to := u.global_position - from
		to.y = 0.0
		var d := to.length()
		if d > best_d:
			continue
		if not _lightning_has_los(u.global_position):
			continue
		best = u
		best_d = d
	return best


func _lightning_has_los(to: Vector3) -> bool:
	var arena := ArenaState.arena as Arena
	if arena == null:
		return true
	var exclude: Array[RID] = [get_rid()]
	if source != null and is_instance_valid(source):
		exclude.append(source.get_rid())
		SpellWall.append_pass_excludes(exclude, source)
	return arena.spell_wall_hit(global_position, to, exclude, 1.05, true).is_empty()


func _tick_ice_zones(delta: float) -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	var interval := maxf(SpellCatalog.ground_aoe().tick_interval, 0.05)
	_ice_tick_acc += delta
	if not _ice_ticked:
		_ice_ticked = true
		_pulse_ice_zones()
		_ice_tick_acc = 0.0
		return
	if _ice_tick_acc < interval:
		return
	_ice_tick_acc -= interval
	_pulse_ice_zones()


func _pulse_ice_zones() -> void:
	if source == null or not is_instance_valid(source):
		return
	var dmg := source._scaled(CombatBalance.scaled_hit("ground_aoe.tick"))
	if dmg <= 0.0:
		return
	var zone_r := SpellWallLayout.ice_zone_radius(ability)
	var extras_el := extras
	var el := ability.element if ability else AbilityDef.Element.ICE
	var ab_id := AbilityDef.combat_id_of(ability, "wall")
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == source.team:
			continue
		if u.is_structure:
			continue
		if not _in_ice_zone(u, zone_r):
			continue
		u.receive_ability_hit(source, el, dmg, 0.0, extras_el, true, true, true, -1, 0, ab_id, combat_text_cast_id)


func _in_ice_zone(u: Unit, zone_r: float) -> bool:
	for off in SpellWallLayout.ice_offsets(ability):
		var world := to_global(off)
		var to := u.global_position - world
		to.y = 0.0
		if to.length() <= zone_r + u.radius:
			return true
	return false


func _shatter_ice() -> void:
	if source == null or not is_instance_valid(source) or ability == null:
		return
	var dmg := max_health * CombatBalance.flat("wall.ice.break")
	var zone_r := SpellWallLayout.ice_zone_radius(ability)
	var extras_el := extras
	var el := ability.element
	for off in SpellWallLayout.ice_offsets(ability):
		var pos := to_global(off)
		pos.y = 0.12
		_SpellBaseFx.burst(pos, zone_r, ability)
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.team == source.team:
			continue
		if u.is_structure:
			continue
		if not _in_ice_zone(u, zone_r):
			continue
		u.receive_ability_hit(source, el, dmg, 0.0, extras_el, false, true, true, -1, 0, AbilityDef.combat_id_of(ability, "wall"), combat_text_cast_id)


func _rupture_shadow() -> void:
	if source == null or not is_instance_valid(source):
		return
	var stacks := maxi(int(round(CombatBalance.flat("wall.shadow.stacks"))), 1)
	var rad := maxf(CombatBalance.flat("wall.shadow.range"), ArenaState.arena_radius)
	var pos := Vector3(global_position.x, 0.12, global_position.z)
	if ability != null:
		_SpellBaseFx.burst(pos, rad, ability)
	for other in ArenaState.units:
		var u := other as Unit
		if u == null or not is_instance_valid(u) or u.is_dead:
			continue
		if u.is_champion:
			continue
		if u.team == source.team:
			continue
		var to := u.global_position - pos
		to.y = 0.0
		if to.length() > rad + u.radius:
			continue
		u.apply_afflict_stacks(source, stacks)


func _refresh() -> void:
	var r := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	if _bar_fill:
		_bar_fill.scale = Vector3.ONE
		if _bar_fill_quad != null:
			var w := _BAR_W * maxf(r, 0.001)
			_bar_fill_quad.size = Vector2(w, _BAR_H)
			_bar_fill.position = Vector3((w - _BAR_W) * 0.5, 0.0, 0.004)
		if _bar_mat:
			_bar_mat.albedo_color = Color(0.9, 0.28, 0.18).lerp(Color(0.4, 0.86, 0.48), r)
			_bar_mat.emission = _bar_mat.albedo_color
			_bar_mat.emission_energy_multiplier = 1.1
	var emit := 0.28 + 0.55 * r + (0.5 if _targeted else 0.0)
	if _mat and ability:
		_mat.emission_energy_multiplier = emit
	for sm in _seg_mats:
		if sm != null:
			sm.emission_energy_multiplier = 0.28 + 0.7 * r
	_sync_bar_hover_frame()


func _apply_hover_outline() -> void:
	if _hover_mat == null:
		_hover_mat = ShaderMaterial.new()
		_hover_mat.shader = _HoverOutline
	_hover_mat.set_shader_parameter("outline_color", _hover_color)
	_hover_mat.set_shader_parameter("width", maxf(GameSession.unit_hover_width, 0.028) * 2.2)
	for mesh in _meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		if _targeted:
			mesh.material_overlay = _hover_mat
		elif mesh.material_overlay == _hover_mat:
			mesh.material_overlay = null


func _sync_bar_hover_frame() -> void:
	if _bar_frame == null or not is_instance_valid(_bar_frame):
		return
	_bar_frame.visible = _targeted
	if not _targeted:
		return
	var size := Vector2(_BAR_W + 0.16, _BAR_H + 0.12)
	_bar_frame.scale = Vector3(size.x, size.y, 1.0)
	var mat := _bar_frame.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("outline_color", _hover_color)
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("border", 0.028)
