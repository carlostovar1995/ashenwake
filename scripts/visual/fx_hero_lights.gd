class_name FxHeroLights
extends Node

## Clustered VFX lights. Bursts borrow a small OmniLight pool instead of
## spawning one light per effect. World sun / fill / character shadows stay.
## Instantiated from AbilityFx.warmup, not by loading this script from itself.

const SLOT_COUNT := 10
const DEFAULT_LIFE := 0.35

var _lights: Array[OmniLight3D] = []
var _until: PackedFloat64Array = PackedFloat64Array()
var _score: PackedFloat32Array = PackedFloat32Array()
var _bind_id: Array = []
var _bind_host: Array[Node3D] = []

static var _inst: Node


static func ensure(parent: Node = null) -> Node:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var host := parent
	if host == null and ArenaState.arena:
		host = ArenaState.arena.get_node_or_null("FxRoot")
		if host == null:
			host = ArenaState.arena
	if host == null:
		var loop := Engine.get_main_loop()
		host = loop.root if loop else null
	if host == null:
		return null
	var existing := host.get_node_or_null("FxHeroLights")
	if existing:
		_inst = existing
		return _inst
	return null


static func pulse(pos: Vector3, color: Color, energy: float = 3.6, reach: float = 6.0, life: float = DEFAULT_LIFE) -> void:
	var n := ensure()
	if n == null:
		return
	n.call("_pulse", pos, color, energy, reach, life)


static func bind(host: Node3D, color: Color, energy: float = 2.4, reach: float = 6.0) -> void:
	var n := ensure()
	if n == null or host == null or not is_instance_valid(host):
		return
	n.call("_bind", host, color, energy, reach)


static func unbind(host: Node3D) -> void:
	if _inst == null or not is_instance_valid(_inst) or host == null:
		return
	_inst.call("_unbind", host)


func _build() -> void:
	if not _lights.is_empty():
		return
	_until.resize(SLOT_COUNT)
	_score.resize(SLOT_COUNT)
	_bind_id.resize(SLOT_COUNT)
	_bind_host.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		var light := OmniLight3D.new()
		light.shadow_enabled = false
		light.light_energy = 0.0
		light.omni_range = 4.0
		light.visible = false
		add_child(light)
		_lights.append(light)
		_until[i] = 0.0
		_score[i] = 0.0
		_bind_id[i] = 0
		_bind_host[i] = null


func _ready() -> void:
	_build()
	_inst = self


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for i in SLOT_COUNT:
		var host := _bind_host[i]
		if host != null:
			if not is_instance_valid(host) or not host.is_inside_tree():
				_clear_slot(i)
				continue
			_lights[i].global_position = host.global_position + Vector3(0.0, 0.55, 0.0)
			continue
		if _until[i] > 0.0 and now >= _until[i]:
			_clear_slot(i)


func _pulse(pos: Vector3, color: Color, energy: float, reach: float, life: float) -> void:
	var weight := _weight(pos, energy, reach)
	var slot := _claim(weight, 0)
	if slot < 0:
		return
	_bind_id[slot] = 0
	_bind_host[slot] = null
	_until[slot] = Time.get_ticks_msec() * 0.001 + maxf(life, 0.08)
	_score[slot] = weight
	var light := _lights[slot]
	light.visible = true
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.global_position = pos + Vector3(0.0, 0.55, 0.0)


func _bind(host: Node3D, color: Color, energy: float, reach: float) -> void:
	_unbind(host)
	var pos := host.global_position
	var weight := _weight(pos, energy, reach) + 2.0
	var slot := _claim(weight, host.get_instance_id())
	if slot < 0:
		return
	_bind_id[slot] = host.get_instance_id()
	_bind_host[slot] = host
	_until[slot] = 0.0
	_score[slot] = weight
	var light := _lights[slot]
	light.visible = true
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = false
	light.global_position = pos + Vector3(0.0, 0.55, 0.0)
	if not host.tree_exiting.is_connected(_on_host_exit):
		host.tree_exiting.connect(_on_host_exit.bind(host), CONNECT_ONE_SHOT)


func _on_host_exit(host: Node3D) -> void:
	_unbind(host)


func _unbind(host: Node3D) -> void:
	if host == null:
		return
	var id := host.get_instance_id()
	for i in SLOT_COUNT:
		if _bind_id[i] == id:
			_clear_slot(i)


func _claim(weight: float, keep_id: int) -> int:
	var now := Time.get_ticks_msec() * 0.001
	var free_i := -1
	var worst_i := -1
	var worst_score := INF
	for i in SLOT_COUNT:
		if keep_id != 0 and _bind_id[i] == keep_id:
			return i
		var occupied: bool = int(_bind_id[i]) != 0 or (_until[i] > now)
		if not occupied:
			free_i = i
			break
		if _score[i] < worst_score:
			worst_score = _score[i]
			worst_i = i
	if free_i >= 0:
		return free_i
	if worst_i >= 0 and weight >= worst_score:
		_clear_slot(worst_i)
		return worst_i
	return -1


func _weight(pos: Vector3, color_energy: float, reach: float) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dist := 12.0
	if cam:
		dist = cam.global_position.distance_to(pos)
	return color_energy * (0.35 + reach * 0.08) / (1.0 + dist * 0.08)


func _clear_slot(i: int) -> void:
	_until[i] = 0.0
	_score[i] = 0.0
	_bind_id[i] = 0
	_bind_host[i] = null
	if i < 0 or i >= _lights.size():
		return
	var light := _lights[i]
	light.light_energy = 0.0
	light.visible = false
