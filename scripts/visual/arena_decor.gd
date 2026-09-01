class_name ArenaDecor
extends Node3D

const P := CharacterCatalog.PROPS


func decorate(_parent: Node3D) -> void:
	var ring := [
		["Barrel.gltf", Vector3(-8, 0, 12), 1.0],
		["Barrel_Apples.gltf", Vector3(-7.2, 0, 13.1), 1.0],
		["Crate_Wooden.gltf", Vector3(8.5, 0, 11.5), 1.0],
		["Crate_Metal.gltf", Vector3(9.4, 0, 10.4), 1.0],
		["Banner_1.gltf", Vector3(-14, 0, 6), 1.2],
		["Banner_2.gltf", Vector3(15, 0, -3), 1.2],
		["Chest_Wood.gltf", Vector3(-12, 0, -8), 1.0],
		["WeaponStand.gltf", Vector3(11, 0, -8), 1.0],
		["Dummy.gltf", Vector3(-6, 0, -14), 1.0],
		["Torch_Metal.gltf", Vector3(-16, 0, 0), 1.15],
		["Torch_Metal.gltf", Vector3(16, 0, 0), 1.15],
		["Anvil.gltf", Vector3(13, 0, 5), 1.0],
		["Workbench.gltf", Vector3(-13, 0, 3), 1.0],
		["Cauldron.gltf", Vector3(6, 0, -15), 1.0],
		["Stall_Empty.gltf", Vector3(-18, 0, 8), 1.0],
		["Shield_Wooden.gltf", Vector3(10.2, 0, -7.2), 1.0],
		["Sword_Bronze.gltf", Vector3(10.6, 0, -7.6), 1.0],
		["Potion_1.gltf", Vector3(8.8, 0, 11.0), 1.0],
		["Lantern_Wall.gltf", Vector3(-10.5, 0, 6.5), 1.0],
		["Bag.gltf", Vector3(-7.6, 0, 12.4), 1.0],
	]
	for item in ring:
		_place(String(item[0]), item[1], float(item[2]))


func _place(file: String, pos: Vector3, sc: float) -> void:
	var path := P + file
	if not ResourceLoader.exists(path):
		return
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var n := packed.instantiate() as Node3D
	if n == null:
		return
	add_child(n)
	n.global_position = pos
	n.scale = Vector3.ONE * sc
	n.rotation.y = randf() * TAU
