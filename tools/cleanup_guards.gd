extends Object

static var _hot_path_scan_allow: Array[String] = [
	"res://scripts/input/player_input.gd",
]
static var _forbidden_legacy_dirs: Array[String] = [
	"res://assets/BinbunVFX",
	"res://assets/BinbunVFX_Vol2",
	"res://assets/_incoming",
	"res://assets/quaternius",
	"res://assets/bosses",
	"res://assets/models/bosses",
	"res://assets/meshes",
	"res://assets/models/props/Exports",
	"res://assets/models/props/Textures",
	"res://assets/models/outfits/Modular Character Outfits - Fantasy[Standard]",
	"res://assets/models/characters/Universal Base Characters[Standard]",
	"res://assets/anims/ual1",
	"res://assets/anims/ual2",
	"res://_incoming/spell_icons",
	"res://_incoming/kevdev",
]
static var _forbidden_legacy_files: Array[String] = [
	"res://assets/textures/arena/floor_stone.png",
	"res://assets/textures/arena/pillar_stone.png",
	"res://assets/textures/arena/wall_medieval.png",
	"res://assets/textures/spotlight_01.png",
	"res://scripts/main.gd",
]
static var _uid_roots: Array[String] = [
	"res://scripts",
	"res://tools",
	"res://scenes",
]


static func run() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	_check_forbidden_legacy_dirs(errors)
	_check_forbidden_legacy_files(errors)
	_check_orphan_uids(errors)
	_check_hot_path_scans(errors)
	return errors


static func _check_forbidden_legacy_dirs(errors: PackedStringArray) -> void:
	for path in _forbidden_legacy_dirs:
		var dir := DirAccess.open(path)
		if dir != null:
			errors.append("Forbidden legacy asset directory still exists: %s" % path)


static func _check_forbidden_legacy_files(errors: PackedStringArray) -> void:
	for path in _forbidden_legacy_files:
		if FileAccess.file_exists(path):
			errors.append("Forbidden legacy file still exists: %s" % path)


static func _check_orphan_uids(errors: PackedStringArray) -> void:
	var files: PackedStringArray = PackedStringArray()
	for root in _uid_roots:
		_collect_files(root, files)
	for path in files:
		if not path.ends_with(".uid"):
			continue
		var resource_path := path.substr(0, path.length() - 4)
		if not FileAccess.file_exists(resource_path):
			errors.append("Orphan UID with no resource: %s" % path)


static func _check_hot_path_scans(errors: PackedStringArray) -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect_files("res://scripts", files)
	for path in files:
		if not path.ends_with(".gd"):
			continue
		if _hot_path_scan_allow.has(path):
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		if _has_linear_units_scan(text):
			errors.append("Linear ArenaState.units scan in %s; use ArenaState.units_near or a typed team list" % path)


static func _has_linear_units_scan(text: String) -> bool:
	var needle := "ArenaState.units"
	var idx := 0
	var found := text.find(needle, idx)
	while found >= 0:
		var after := found + needle.length()
		if after >= text.length() or text.substr(after, 1) != "_":
			return true
		idx = after
		found = text.find(needle, idx)
	return false


static func _collect_files(path: String, files: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := path.path_join(name)
			if dir.current_is_dir():
				_collect_files(child, files)
			else:
				files.append(child)
		name = dir.get_next()
	dir.list_dir_end()
