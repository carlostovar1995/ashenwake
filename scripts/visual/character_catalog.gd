class_name CharacterCatalog
extends Object

const OUTFITS := "res://assets/models/outfits/fantasy/"
const BASE := "res://assets/models/characters/humanoid_boss/"
const UAL1 := "res://assets/anims/UAL1_Standard.glb"
const UAL2 := "res://assets/anims/UAL2_Standard.glb"
const KEVDEV_DUMMY_F := "res://assets/models/characters/kevdev/HumanCharacterDummy_F.fbx"
const KEVDEV_ANIMS: PackedStringArray = [
	"res://assets/anims/kevdev/HumanF@Idle01.fbx",
	"res://assets/anims/kevdev/HumanF@Walk01_Forward.fbx",
	"res://assets/anims/kevdev/HumanF@Run01_Forward.fbx",
	"res://assets/anims/kevdev/HumanF@Jump01.fbx",
	"res://assets/anims/kevdev/HumanF@Death01.fbx",
	"res://assets/anims/kevdev/HumanF@Attack1H01_R.fbx",
	"res://assets/anims/kevdev/HumanF@CastingIdle01.fbx",
	"res://assets/anims/kevdev/HumanF@CastingEnter01.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackOmni01_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_L.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect1H01_R_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect2H01_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackDirect2H01_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackCall1H01_L_Load.fbx",
	"res://assets/anims/kevdev/HumanF@MagicAttackCall1H01_L_Cast.fbx",
	"res://assets/anims/kevdev/HumanF@ThrowBall01_R.fbx",
]
const PROPS := "res://assets/models/props/fantasy/"

const MALE_RANGER := OUTFITS + "Male_Ranger.gltf"
const FEMALE_RANGER := OUTFITS + "Female_Ranger.gltf"
const MALE_PEASANT := OUTFITS + "Male_Peasant.gltf"
const FEMALE_PEASANT := OUTFITS + "Female_Peasant.gltf"
const BOSS_BODY := BASE + "Superhero_Male_FullBody.gltf"
const TRAINING_DUMMY := PROPS + "Dummy.gltf"

static var _anim_libs: Array = []
static var _libs_ready: bool = false
static var _kevdev_libs: Array = []
static var _kevdev_ready: bool = false


static func uses_kevdev_anims(model_path: String) -> bool:
	return model_path.find("/kevdev/") >= 0 or model_path.find("HumanCharacterDummy") >= 0


static func attach(unit: Unit, model_path: String, model_scale: float = 1.0, yaw: float = PI, y_offset: float = 0.0, pitch: float = 0.0) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if model_path.is_empty():
		return
	var existing := unit.get_node_or_null("CharacterVisual")
	if existing is CharacterVisual:
		return
	if existing != null:
		existing.free()
	var packed := load(model_path) as PackedScene
	if packed == null:
		push_warning("Missing character model: %s" % model_path)
		return
	var vis := CharacterVisual.new()
	vis.name = "CharacterVisual"
	unit.add_child(vis)
	vis.setup(unit, model_path, model_scale, yaw, y_offset, pitch)
	if vis.get_child_count() == 0:
		_mount_model(vis, unit, packed, model_scale, yaw, y_offset, pitch)


static func _mount_model(vis: Node, unit: Unit, packed: PackedScene, model_scale: float, yaw: float, y_offset: float, pitch: float) -> void:
	var model := packed.instantiate() as Node3D
	if model == null:
		return
	vis.add_child(model)
	model.scale = Vector3.ONE * model_scale
	if absf(pitch) > 0.001:
		model.rotate_x(pitch)
	if absf(yaw) > 0.001:
		model.rotate_y(yaw)
	if absf(y_offset) > 0.001:
		model.position.y = y_offset
	var mesh := unit.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		mesh.visible = false
	var face := unit.get_node_or_null("FacingMarker") as MeshInstance3D
	if face:
		face.visible = false


static func animation_libraries() -> Array:
	if _libs_ready:
		return _anim_libs
	_libs_ready = true
	_anim_libs = _collect_libs_from_paths([UAL1, UAL2], false)
	return _anim_libs


static func kevdev_animation_libraries() -> Array:
	if _kevdev_ready:
		return _kevdev_libs
	_kevdev_ready = true
	_kevdev_libs = _collect_libs_from_paths(Array(KEVDEV_ANIMS), true)
	return _kevdev_libs


static func _collect_libs_from_paths(paths: Array, rename_to_stem: bool) -> Array:
	var libs: Array = []
	for path in paths:
		var res_path := String(path)
		if not ResourceLoader.exists(res_path):
			push_warning("Missing animation source: %s" % res_path)
			continue
		var packed := load(res_path) as PackedScene
		if packed == null:
			continue
		var dummy := packed.instantiate()
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			tree.root.add_child(dummy)
		var src := _find_player(dummy)
		if src:
			var stem := res_path.get_file().get_basename()
			for lib_name in src.get_animation_library_list():
				var lib := src.get_animation_library(lib_name)
				if lib == null:
					continue
				var copy := lib.duplicate(true) as AnimationLibrary
				if rename_to_stem:
					_rename_library_clips(copy, stem)
				libs.append(copy)
		dummy.free()
	return libs


static func _rename_library_clips(lib: AnimationLibrary, stem: String) -> void:
	var names: PackedStringArray = lib.get_animation_list()
	if names.is_empty() or stem.is_empty():
		return
	if names.size() == 1:
		if names[0] != stem and not lib.has_animation(stem):
			lib.rename_animation(names[0], stem)
		return
	for anim_name in names:
		var dest := "%s_%s" % [stem, anim_name]
		if anim_name != dest and not lib.has_animation(dest):
			lib.rename_animation(anim_name, dest)


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_player(c)
		if found:
			return found
	return null
