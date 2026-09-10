class_name ArenaLayout
extends Node3D

## Authorable boss-room geometry. Open a file under `scenes/arena/layouts/` in Godot
## to place floor, cover, lights, and spawn markers. Fight logic stays on Arena.
## Layouts are standalone scenes. Instance collision props from
## `assets/models/props/collision/`; do not share a parent layout scene.
##
## Required:
## - NavigationRegion3D (any descendant)
## - StaticBody3D named `Floor` (line-of-sight treats that name as walkable floor)
##
## Cover: StaticBody3D children of the nav region whose names start with `Obstacle`
## Spawn markers (optional Marker3D, recursive by name):
## PlayerSpawn, BossSpawn, ChasePad, RaidTank, RaidHeal, RaidHex, RaidVex
## TrainingPlayer, TrainingDummy, TrainingPack, TrainingAlly, TrainingShooter
## (training layout only)
## PillarSpawn* — Dawnwarden pillar anchors; omitted markers fall back to the ring.

const DEFAULT_PLAYER := Vector3(0.0, 0.1, 16.5)
const DEFAULT_BOSS := Vector3(0.0, 0.1, 0.0)
const DEFAULT_TRAINING_PLAYER := Vector3(0.0, 0.1, 8.0)
const DEFAULT_TRAINING_DUMMY := Vector3(0.0, 0.1, 0.0)
const DEFAULT_TRAINING_PACK := Vector3(8.8, 0.1, 1.2)
const DEFAULT_TRAINING_ALLY := Vector3(-5.4, 0.1, 6.2)
const DEFAULT_TRAINING_SHOOTER := Vector3(6.8, 0.1, 13.5)
const DEFAULT_TRAINING_SHOOTER_DIR := Vector3(-1.0, 0.0, 0.0)
const DEFAULT_CHASE_PAD := Vector3(-22.0, 0.08, 1.5)

@export var arena_radius: float = 28.0
@export var use_stock_decor: bool = true

var nav_region: NavigationRegion3D


func bind_to_arena() -> void:
	nav_region = _find_typed("NavigationRegion3D") as NavigationRegion3D
	if nav_region == null:
		push_error("ArenaLayout: %s needs a NavigationRegion3D" % _layout_id())
	if floor_body() == null:
		push_error("ArenaLayout: %s needs a StaticBody3D named Floor" % _layout_id())


func floor_body() -> StaticBody3D:
	var node := _find_by_name("Floor")
	return node as StaticBody3D


func sun_light() -> DirectionalLight3D:
	return _find_typed("DirectionalLight3D") as DirectionalLight3D


func fill_light() -> OmniLight3D:
	var named := _find_by_name("FillLight")
	if named is OmniLight3D:
		return named as OmniLight3D
	return _find_typed("OmniLight3D") as OmniLight3D


func world_environment() -> WorldEnvironment:
	return _find_typed("WorldEnvironment") as WorldEnvironment


func player_spawn(training: bool) -> Vector3:
	if training:
		return marker_position("TrainingPlayer", DEFAULT_TRAINING_PLAYER)
	return marker_position("PlayerSpawn", DEFAULT_PLAYER)


func boss_spawn() -> Vector3:
	return marker_position("BossSpawn", DEFAULT_BOSS)


func training_dummy_spawn() -> Vector3:
	return marker_position("TrainingDummy", DEFAULT_TRAINING_DUMMY)


func training_pack_spawn() -> Vector3:
	return marker_position("TrainingPack", DEFAULT_TRAINING_PACK)


func training_ally_spawn() -> Vector3:
	return marker_position("TrainingAlly", DEFAULT_TRAINING_ALLY)


func training_shooter_spawn() -> Vector3:
	return marker_position("TrainingShooter", DEFAULT_TRAINING_SHOOTER)


func training_shooter_dir() -> Vector3:
	var marker := _find_by_name("TrainingShooter") as Node3D
	if marker == null:
		return DEFAULT_TRAINING_SHOOTER_DIR
	var forward := -_world_basis(marker).z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return DEFAULT_TRAINING_SHOOTER_DIR
	return forward.normalized()


func chase_pad_position() -> Vector3:
	return marker_position("ChasePad", DEFAULT_CHASE_PAD)


func raid_member_spawn(member_id: String, player_role: String) -> Vector3:
	match member_id:
		RaidComp.MEMBER_BULWARK:
			return marker_position("RaidTank", RaidComp.POS_TANK)
		RaidComp.MEMBER_MEND:
			return marker_position("RaidHeal", RaidComp.POS_HEAL)
		RaidComp.MEMBER_HEX:
			return marker_position("RaidHex", RaidComp.POS_HEX)
		RaidComp.MEMBER_VEX:
			return marker_position("RaidVex", RaidComp.POS_VEX)
		RaidComp.MEMBER_ROOK:
			if RaidComp.normalize_role(player_role) == RaidComp.ROLE_TANK:
				return marker_position("RaidTank", RaidComp.POS_TANK)
			return marker_position("RaidHeal", RaidComp.POS_HEAL)
		_:
			return marker_position("RaidHex", RaidComp.POS_HEX)


func pillar_anchors() -> Array[Vector3]:
	var markers: Array[Node3D] = []
	_collect_name_prefix(self, "PillarSpawn", markers)
	markers.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.name < b.name)
	var out: Array[Vector3] = []
	for marker in markers:
		var pos := _world_position(marker)
		pos.y = 0.0
		out.append(pos)
	return out


func marker_position(marker_name: String, fallback: Vector3) -> Vector3:
	var node := _find_by_name(marker_name) as Node3D
	if node == null:
		return fallback
	return _world_position(node)


func has_marker(marker_name: String) -> bool:
	return _find_by_name(marker_name) is Node3D


func _layout_id() -> String:
	var path := scene_file_path
	if path.is_empty():
		return name
	return path


func _world_position(node: Node3D) -> Vector3:
	if node.is_inside_tree():
		return node.global_position
	return node.position


func _world_basis(node: Node3D) -> Basis:
	if node.is_inside_tree():
		return node.global_transform.basis
	return node.transform.basis


func _find_by_name(node_name: String) -> Node:
	return _find_named(self, node_name)


func _find_typed(type_name: String) -> Node:
	return _find_class(self, type_name)


func _find_named(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var hit := _find_named(child, node_name)
		if hit:
			return hit
	return null


func _find_class(root: Node, type_name: String) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var hit := _find_class(child, type_name)
		if hit:
			return hit
	return null


func _collect_name_prefix(root: Node, prefix: String, out: Array[Node3D]) -> void:
	if root is Marker3D and String(root.name).begins_with(prefix):
		out.append(root as Marker3D)
	for child in root.get_children():
		_collect_name_prefix(child, prefix, out)
