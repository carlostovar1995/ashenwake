class_name ArenaCatalog
extends Object

## Destination id -> layout scene. Add a row here, author a standalone layout
## under `scenes/arena/layouts/`, and the play menu picks it up. Do not instance
## another destination layout. Collision cover lives in
## `assets/models/props/collision/`.

const ID_TRAINING := "training"
const ID_COLOSSUS := "colossus"
const ID_DAWNWARDEN := "dawnwarden"

const _ENTRIES: Array[Dictionary] = [
	{
		"id": ID_TRAINING,
		"name": "TRAINING ARENA",
		"image": "boss_game_training_arena.png",
		"layout": "res://scenes/arena/layouts/training.tscn",
		"training": true,
		"boss_id": "",
	},
	{
		"id": ID_COLOSSUS,
		"name": "COLOSSUS",
		"image": "boss_game_colossus.png",
		"layout": "res://scenes/arena/layouts/colossus.tscn",
		"training": false,
		"boss_id": ID_COLOSSUS,
	},
	{
		"id": ID_DAWNWARDEN,
		"name": "DAWNWARDEN",
		"image": "boss_game_dawnwarden.png",
		"layout": "res://scenes/arena/layouts/dawnwarden.tscn",
		"training": false,
		"boss_id": ID_DAWNWARDEN,
	},
]


static func destinations() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in _ENTRIES:
		out.append(entry.duplicate())
	return out


static func entry(destination_id: String) -> Dictionary:
	var id := destination_id.strip_edges()
	for row in _ENTRIES:
		if String(row.get("id", "")) == id:
			return row.duplicate()
	push_error("ArenaCatalog: unknown destination '%s'" % destination_id)
	return _ENTRIES[0].duplicate()


static func is_training(destination_id: String) -> bool:
	return bool(entry(destination_id).get("training", true))


static func boss_id(destination_id: String) -> String:
	return String(entry(destination_id).get("boss_id", ""))


static func layout_path(destination_id: String) -> String:
	return String(entry(destination_id).get("layout", ""))


static func destination_for_boss(boss_id: String) -> String:
	var id := boss_id.strip_edges()
	if id.is_empty():
		return ""
	for row in _ENTRIES:
		if String(row.get("boss_id", "")) == id:
			return String(row.get("id", ""))
	return ""


static func load_layout(destination_id: String) -> PackedScene:
	var path := layout_path(destination_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("ArenaCatalog: layout missing for '%s' (%s)" % [destination_id, path])
		path = String(_ENTRIES[0].get("layout", ""))
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("ArenaCatalog: could not load layout %s" % path)
	return packed
