class_name ArenaPillar
extends StaticBody3D

signal destroyed(pillar: ArenaPillar)

const RADIUS := 1.4
const HEIGHT := 2.4
const MAX_HP := 1200.0
const _BAR_W := 1.62
const _BAR_H := 0.10
const PILLAR_TEX := preload("res://assets/textures/arena/pillar_stone.png")

var max_health: float = MAX_HP
var health: float = MAX_HP
var living: bool = true

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _shape: CollisionShape3D
var _bar_root: Node3D
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _bar_fill: MeshInstance3D
var _bar_fill_quad: QuadMesh


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("pillars")
	_build()
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	if living:
		_orient_bar()


func setup(index: int, pos: Vector3) -> void:
	name = "ObstaclePillar%d" % index
	position = Vector3(pos.x, HEIGHT * 0.5, pos.z)
	health = max_health


func half_xz() -> float:
	return RADIUS


func is_full() -> bool:
	return living and health >= max_health - 0.5


func health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)


func take_damage(amount: float) -> void:
	if not living or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_refresh_visual()
	if health <= 0.0:
		_die()


func _die() -> void:
	if not living:
		return
	living = false
	collision_layer = 0
	if _shape:
		_shape.disabled = true
	if _bar_root:
		_bar_root.visible = false
	if _mat:
		_mat.albedo_color = Color(0.18, 0.16, 0.14, 0.35)
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.emission_energy_multiplier = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.0, 0.12, 1.0), 0.35)
	destroyed.emit(self)


func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = PILLAR_TEX
	_mat.albedo_color = Color(0.95, 0.86, 0.68)
	_mat.roughness = 0.78
	_mat.uv1_triplanar = true
	_mat.uv1_world_triplanar = true
	_mat.uv1_scale = Vector3(0.42, 0.42, 0.42)
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat.emission_enabled = true
	_mat.emission = Color(0.95, 0.78, 0.32)
	_mat.emission_energy_multiplier = 0.18
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = HEIGHT
	cyl.radial_segments = 28
	cyl.rings = 1
	_mesh = MeshInstance3D.new()
	_mesh.mesh = cyl
	_mesh.material_override = _mat
	add_child(_mesh)
	var col := CylinderShape3D.new()
	col.radius = RADIUS
	col.height = HEIGHT
	_shape = CollisionShape3D.new()
	_shape.name = "CollisionShape3D"
	_shape.shape = col
	add_child(_shape)
	_build_hp_bar()


func _build_hp_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "PillarHpBar"
	_bar_root.top_level = true
	add_child(_bar_root)
	_bar = _make_bar_quad("HpBg", Vector2(_BAR_W + 0.10, _BAR_H + 0.05), Color(0.08, 0.07, 0.06), 0.0)
	_bar_root.add_child(_bar)
	_bar_fill_quad = QuadMesh.new()
	_bar_fill_quad.size = Vector2(_BAR_W, _BAR_H)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.name = "HpFill"
	_bar_fill.mesh = _bar_fill_quad
	_bar_fill.position.z = 0.004
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.albedo_color = Color(0.35, 0.85, 0.4)
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.emission_enabled = true
	_bar_mat.emission = Color(0.3, 0.8, 0.35)
	_bar_mat.emission_energy_multiplier = 1.2
	_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	_bar_mat.no_depth_test = true
	_bar_mat.disable_receive_shadows = true
	_bar_mat.render_priority = 10
	_bar_fill.material_override = _bar_mat
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(_bar_fill)
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


func _bar_world_pos() -> Vector3:
	return global_position + Vector3(0.0, HEIGHT * 0.5 + 0.45, 0.0)


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


func _refresh_visual() -> void:
	if not living:
		return
	var r := health_ratio()
	if _mat:
		_mat.albedo_color = Color(0.72, 0.62, 0.38).lerp(Color(0.42, 0.22, 0.12), 1.0 - r)
		_mat.emission_energy_multiplier = 0.15 + 0.55 * r
	if _bar_fill and _bar_fill_quad != null:
		var w := _BAR_W * maxf(r, 0.001)
		_bar_fill_quad.size = Vector2(w, _BAR_H)
		_bar_fill.position = Vector3((w - _BAR_W) * 0.5, 0.0, 0.004)
	if _bar_mat:
		_bar_mat.albedo_color = Color(0.9, 0.28, 0.18).lerp(Color(0.35, 0.85, 0.4), r)
		_bar_mat.emission = _bar_mat.albedo_color
