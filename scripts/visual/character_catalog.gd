class_name CharacterCatalog
extends Object

const OUTFITS := "res://assets/quaternius/outfits/Modular Character Outfits - Fantasy[Standard]/Exports/glTF (Godot-Unreal)/Outfits/"
const BASE := "res://assets/quaternius/characters/Universal Base Characters[Standard]/Base Characters/Godot - UE/"
const UAL1 := "res://assets/anims/UAL1_Standard.glb"
const UAL2 := "res://assets/anims/UAL2_Standard.glb"
const PROPS := "res://assets/quaternius/props/Exports/glTF/"

const MALE_RANGER := OUTFITS + "Male_Ranger.gltf"
const FEMALE_RANGER := OUTFITS + "Female_Ranger.gltf"
const MALE_PEASANT := OUTFITS + "Male_Peasant.gltf"
const FEMALE_PEASANT := OUTFITS + "Female_Peasant.gltf"
const BOSS_BODY := BASE + "Superhero_Male_FullBody.gltf"
const FIRE_ELEMENTAL := "res://assets/bosses/fire_elemental.glb"
const MAGMA_GOLEM := "res://assets/bosses/magma_golem.glb"
# Light Entity v.1 by RunemarkStudio — CC BY 4.0
const LIGHT_ENTITY := "res://assets/bosses/light_entity.glb"
const TRAINING_DUMMY := PROPS + "Dummy.gltf"

static var _anim_libs: Array = []
static var _libs_ready: bool = false


static func attach(unit: Unit, model_path: String, model_scale: float = 1.0, yaw: float = PI, y_offset: float = 0.0, pitch: float = 0.0) -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		push_warning("Missing character model: %s" % model_path)
		return
	var vis := CharacterVisual.new()
	vis.name = "CharacterVisual"
	unit.add_child(vis)
	vis.setup(unit, model_path, model_scale, yaw, y_offset, pitch)


static func animation_libraries() -> Array:
	if _libs_ready:
		return _anim_libs
	_libs_ready = true
	for path in [UAL1, UAL2]:
		if not ResourceLoader.exists(path):
			continue
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var dummy := packed.instantiate()
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.root.add_child(dummy)
		var src := _find_player(dummy)
		if src:
			for lib_name in src.get_animation_library_list():
				var lib := src.get_animation_library(lib_name)
				if lib:
					_anim_libs.append(lib.duplicate(true))
		dummy.free()
	return _anim_libs


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_player(c)
		if found:
			return found
	return null
