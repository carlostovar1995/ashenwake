class_name ArenaPillar
extends StaticBody3D

signal destroyed(pillar: ArenaPillar)

const RADIUS := 1.4
const HEIGHT := 2.4
const MAX_HP := 1200.0
const PILLAR_TEX := preload("res://assets/textures/arena/pillar_stone.png")

var max_health: float = MAX_HP
var health: float = MAX_HP
var living: bool = true

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _shape: CollisionShape3D
var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _bar_fill: MeshInstance3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("pillars")
	_build()
	_refresh_visual()


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
	if _bar:
		_bar.visible = false
	if _bar_fill:
		_bar_fill.visible = false
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
	var bg := BoxMesh.new()
	bg.size = Vector3(1.7, 0.1, 0.08)
	_bar = MeshInstance3D.new()
	_bar.mesh = bg
	_bar.position = Vector3(0.0, HEIGHT * 0.5 + 0.45, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.07, 0.06)
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.disable_receive_shadows = true
	_bar.material_override = bg_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar)
	var fill := BoxMesh.new()
	fill.size = Vector3(1.62, 0.07, 0.09)
	_bar_fill = MeshInstance3D.new()
	_bar_fill.mesh = fill
	_bar_fill.position = _bar.position
	_bar_mat = StandardMaterial3D.new()
	_bar_mat.albedo_color = Color(0.35, 0.85, 0.4)
	_bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_mat.emission_enabled = true
	_bar_mat.emission = Color(0.3, 0.8, 0.35)
	_bar_mat.emission_energy_multiplier = 1.2
	_bar_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_mat.disable_receive_shadows = true
	_bar_fill.material_override = _bar_mat
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar_fill)


func _refresh_visual() -> void:
	if not living:
		return
	var r := health_ratio()
	if _mat:
		_mat.albedo_color = Color(0.72, 0.62, 0.38).lerp(Color(0.42, 0.22, 0.12), 1.0 - r)
		_mat.emission_energy_multiplier = 0.15 + 0.55 * r
	if _bar_fill:
		_bar_fill.scale.x = maxf(r, 0.02)
		_bar_fill.position.x = (r - 1.0) * 0.81
		_bar_mat.albedo_color = Color(0.9, 0.28, 0.18).lerp(Color(0.35, 0.85, 0.4), r)
		_bar_mat.emission = _bar_mat.albedo_color
