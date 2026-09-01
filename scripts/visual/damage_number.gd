extends Label

## Floating combat text. One manager ticks every floater so lifetime
## cannot stall, rise is capped, and lanes are reused instead of stacking
## ever higher.

const LIFE := 2.0
const CRIT_LIFE := 2.0
const FADE_TIME := 0.35
const DIRECT_BURST_WINDOW := 0.14
const HIT_COMPONENT_WINDOW := 0.025
const ORDER_MEMORY_MSEC := 2400
const RECENTER_HOLD_MSEC := 420
const LAYOUT_MOVE_SPEED := 15.0
const ENTRY_OUTSET := 48.0
const EVICT_TIME := 0.22
const EVICT_PUSH := 42.0
const NORMAL_POP := 1.25
const CRIT_POP := 1.50
const MERGE_POP := 1.25
const LANES := 6
const QUEUE_PAD := 8.0
const FOOT_ANCHOR := 0.28
const MAX_COLOR_BANDS := 4
const _SplitShader := preload("res://scripts/visual/damage_split.gdshader")
const MAX_LIVE_PER_QUEUE := 6
const MAX_POOLED := 512
const ORDER_PRUNE_INTERVAL_MSEC := 500
const SPLIT_BUCKETS := 16.0
const MAX_STYLE_UPDATES_PER_TICK := 128
const QUEUE_DIRECT := "direct"
const QUEUE_DOT := "dot"
const QUEUE_HEAL := "heal"
const QUEUE_HOT := "hot"

var _target: Node3D
var _amount: float = 0.0
var _kind: String = "hit"
var _tint: Color = Color.WHITE
var _age: float = 0.0
var _life: float = LIFE
var _lane: int = 0
var _pop: float = 1.0
var _banner: bool = false
var _crit: bool = false
var _cast_instance_id: int = -1
var _periodic_key: String = ""
var _band_colors: Array = []
var _band_amts: Array = []
var _band_elements: Array = []
var _split_sig: String = ""
var _heal: bool = false
var _secondary_queue: bool = false
var _order_id: int = 0
var _layout_offset := Vector2.ZERO
var _layout_target := Vector2.ZERO
var _layout_ready: bool = false
var _anchor_y: float = 0.0
var _anchor_target_y: float = 0.0
var _anchor_ready: bool = false
var _last_world_anchor := Vector3.ZERO
var _has_world_anchor: bool = false
var _evicted: bool = false
var _evict_age: float = 0.0
var _evict_from := Vector2.ZERO
var _evict_to := Vector2.ZERO
var _evict_start_alpha: float = 1.0
var _style_dirty: bool = false
var _styled_font_size: int = -1

static var _live: Array = []
static var _pool: Array = []
static var _runner: Node
static var _cast_seq: int = 0
static var _order_seq: int = 0
static var _order_memory: Dictionary = {}
static var _recenter_holds: Dictionary = {}
static var _periodic_index: Dictionary = {}
static var _cast_index: Dictionary = {}
static var _direct_index: Dictionary = {}
static var _queue_index: Dictionary = {}
static var _dirty_reflows: Dictionary = {}
static var _split_material_cache: Dictionary = {}
static var _last_order_prune_msec: int = 0
static var _frame_camera: Camera3D
static var _frame_origins: Dictionary = {}
static var _style_queue: Array = []
static var _style_queued: Dictionary = {}


static func begin_cast() -> int:
	_cast_seq += 1
	return _cast_seq


static func warmup(tree: SceneTree, count: int = MAX_POOLED) -> void:
	if tree == null:
		return
	_ensure_runner(tree)
	var layer := _layer(tree)
	var keep: Array = []
	for item in _pool:
		if item == null or not is_instance_valid(item) or item.is_queued_for_deletion():
			continue
		if item.get_parent() != layer:
			if item.get_parent():
				item.get_parent().remove_child(item)
			layer.add_child(item)
		keep.append(item)
	_pool = keep
	var wanted := clampi(count, 0, MAX_POOLED)
	while _pool.size() < wanted:
		var n = new()
		n._reset_for_pool()
		layer.add_child(n)
		_pool.append(n)


static func show_hit(target: Node3D, amount: float, kind: String = "hit", tint: Color = Color(0, 0, 0, 0), crit: bool = false, cast_instance_id: int = -1, periodic_key: String = "", split: Dictionary = {}, heal: bool = false) -> void:
	if not GameSession.show_damage_numbers:
		return
	if target == null or not is_instance_valid(target) or amount <= 0.0:
		return
	var tree := target.get_tree()
	if tree == null:
		return
	var want_kind := kind if not kind.is_empty() else "hit"
	var want_tint := _effective_tint(want_kind, tint)
	_ensure_runner(tree)
	if not periodic_key.is_empty():
		var periodic = _find_periodic(target, periodic_key)
		if periodic:
			periodic._replace_tick(amount, want_tint, crit, split)
			return
	elif cast_instance_id >= 0:
		var cast_number = _find_cast(target, cast_instance_id, heal, want_kind)
		if cast_number:
			cast_number._add(amount, want_tint, crit, split)
			return
	elif not crit and not _is_periodic(want_kind):
		var existing = _find_direct_burst(target, want_kind, split, heal)
		if existing:
			existing._add(amount, want_tint, false, split)
			return
	var secondary_queue := _is_secondary_queue(want_kind, periodic_key)
	var queue := _queue_name(heal, secondary_queue)
	var replaced = _prune_overflow(target, queue)
	var n = _acquire_number()
	var slot: int = 0
	var identity := _memory_identity(cast_instance_id, periodic_key)
	var order_id: int = 0
	if replaced != null:
		slot = int(replaced._lane)
		order_id = int(replaced._order_id)
		_touch_order_memory(target, queue, identity, order_id)
	else:
		slot = _free_slot(target, queue)
		order_id = _order_for(target, queue, identity)
	n._boot(target, amount, want_kind, want_tint, slot, crit, cast_instance_id, periodic_key, split, heal, secondary_queue, order_id)
	var layer := _layer(tree)
	if n.get_parent() != layer:
		if n.get_parent():
			n.get_parent().remove_child(n)
		layer.add_child(n)
	else:
		layer.move_child(n, layer.get_child_count() - 1)
	_live.append(n)
	_index_number(n)
	if replaced != null:
		_recenter_holds.erase(_recenter_key(target, queue))
		n._set_layout_target(replaced._layout_target)
	_mark_reflow(target, n)


static func present_merged(target: Node3D, amount: float, tint: Color = Color(0, 0, 0, 0)) -> void:
	show_hit(target, amount, "hit", tint)


static func show_banner(target: Node3D, text: String, tint: Color = Color(0.62, 0.92, 1.0)) -> void:
	if target == null or not is_instance_valid(target) or text.is_empty():
		return
	var tree := target.get_tree()
	if tree == null:
		return
	_ensure_runner(tree)
	var n = _acquire_number()
	n._boot_banner(target, text, tint)
	var layer := _layer(tree)
	if n.get_parent() != layer:
		if n.get_parent():
			n.get_parent().remove_child(n)
		layer.add_child(n)
	else:
		layer.move_child(n, layer.get_child_count() - 1)
	_live.append(n)
	n._place()


static func _layer(tree: SceneTree) -> CanvasLayer:
	var layer := tree.root.get_node_or_null("DamageNumbers") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "DamageNumbers"
		layer.layer = 25
		tree.root.add_child(layer)
	return layer


static func _ensure_runner(tree: SceneTree) -> void:
	if _runner != null and is_instance_valid(_runner):
		return
	var layer := _layer(tree)
	_runner = load("res://scripts/visual/damage_number_runner.gd").new()
	_runner.tick = func(delta: float) -> void:
		tick_all(delta)
	layer.add_child(_runner)


static func _acquire_number():
	while not _pool.is_empty():
		var n = _pool.pop_back()
		if n != null and is_instance_valid(n):
			return n
	return new()


static func _periodic_lookup_key(target: Node3D, periodic_key: String) -> String:
	return "%d|%s" % [target.get_instance_id(), periodic_key]


static func _cast_lookup_key(target: Node3D, cast_instance_id: int, heal: bool, kind: String) -> String:
	return "%d|%d|%d|%s" % [target.get_instance_id(), cast_instance_id, int(heal), kind]


static func _direct_lookup_key(target: Node3D, kind: String, heal: bool) -> String:
	return "%d|%d|%s" % [target.get_instance_id(), int(heal), kind]


static func _queue_lookup_key(target: Node3D, queue: String) -> String:
	return "%d|%s" % [target.get_instance_id(), queue]


static func _indexed(index: Dictionary, key: String):
	var n = index.get(key)
	if n == null or not is_instance_valid(n) or n._evicted:
		index.erase(key)
		return null
	return n


static func _index_number(n) -> void:
	if n == null or not is_instance_valid(n) or n._banner:
		return
	var target := _alive_target(n)
	if target == null:
		return
	if not n._periodic_key.is_empty():
		_periodic_index[_periodic_lookup_key(target, n._periodic_key)] = n
	elif n._cast_instance_id >= 0:
		_cast_index[_cast_lookup_key(target, n._cast_instance_id, n._heal, n._kind)] = n
	elif not n._crit and not _is_periodic(n._kind):
		_direct_index[_direct_lookup_key(target, n._kind, n._heal)] = n
	var queue_key := _queue_lookup_key(target, n._queue_key())
	var bucket: Array = _queue_index.get(queue_key, [])
	bucket.append(n)
	_queue_index[queue_key] = bucket


static func _erase_if_same(index: Dictionary, key: String, n) -> void:
	if index.get(key) == n:
		index.erase(key)


static func _unindex_number(n) -> void:
	if n == null or not is_instance_valid(n) or n._banner:
		return
	var target := _alive_target(n)
	if target == null:
		return
	if not n._periodic_key.is_empty():
		_erase_if_same(_periodic_index, _periodic_lookup_key(target, n._periodic_key), n)
	elif n._cast_instance_id >= 0:
		_erase_if_same(_cast_index, _cast_lookup_key(target, n._cast_instance_id, n._heal, n._kind), n)
	elif not n._crit and not _is_periodic(n._kind):
		_erase_if_same(_direct_index, _direct_lookup_key(target, n._kind, n._heal), n)
	var queue_key := _queue_lookup_key(target, n._queue_key())
	var bucket: Array = _queue_index.get(queue_key, [])
	bucket.erase(n)
	if bucket.is_empty():
		_queue_index.erase(queue_key)
	else:
		_queue_index[queue_key] = bucket


static func _mark_reflow(target: Node3D, newcomer = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var key := target.get_instance_id()
	var entry: Dictionary = _dirty_reflows.get(key, {})
	entry["target"] = target
	if newcomer != null and is_instance_valid(newcomer):
		entry["newcomer"] = newcomer
	_dirty_reflows[key] = entry


static func _flush_reflows() -> void:
	if _dirty_reflows.is_empty():
		return
	var entries := _dirty_reflows.values()
	_dirty_reflows.clear()
	for entry_any in entries:
		var entry: Dictionary = entry_any
		var target = entry.get("target")
		if target == null or not is_instance_valid(target):
			continue
		var newcomer = entry.get("newcomer")
		if newcomer != null and not is_instance_valid(newcomer):
			newcomer = null
		_reflow_all(target, newcomer)


static func _queue_style(n) -> void:
	if n == null or not is_instance_valid(n):
		return
	var key: int = int(n.get_instance_id())
	if _style_queued.has(key):
		return
	_style_queued[key] = true
	_style_queue.append(n)


static func _flush_style_budget() -> void:
	var remaining := MAX_STYLE_UPDATES_PER_TICK
	while remaining > 0 and not _style_queue.is_empty():
		var n = _style_queue.pop_back()
		if n == null or not is_instance_valid(n):
			remaining -= 1
			continue
		_style_queued.erase(n.get_instance_id())
		n._flush_style()
		remaining -= 1
	if _style_queue.is_empty():
		_style_queued.clear()


static func _is_periodic(kind: String) -> bool:
	return (
		kind.ends_with("_tick")
		or kind == "tick"
		or kind == "burn"
		or kind == "afflicted"
		or kind == "combust"
		or kind == "rejuvenation"
	)


static func _is_status_dot(kind: String) -> bool:
	return kind == "burn" or kind == "afflicted" or kind == "combust"


static func _is_status_hot(kind: String) -> bool:
	return kind == "rejuvenation"


static func _is_secondary_queue(kind: String, periodic_key: String) -> bool:
	# Foot lane: status HoTs, shields, and status DoTs. Spell-tick heals
	# (aura, zone, ray) keep a periodic key for merge/replace but stay
	# in the primary chest lane, matching spell-tick damage.
	if kind == "shield" or _is_status_hot(kind):
		return true
	return not periodic_key.is_empty() and _is_status_dot(kind)


static func _queue_name(heal: bool, secondary: bool) -> String:
	if heal:
		return QUEUE_HOT if secondary else QUEUE_HEAL
	return QUEUE_DOT if secondary else QUEUE_DIRECT


static func _memory_identity(cast_instance_id: int, periodic_key: String) -> String:
	if not periodic_key.is_empty():
		return "periodic:%s" % periodic_key
	if cast_instance_id >= 0:
		return "cast:%d" % cast_instance_id
	return ""


static func _memory_key(target: Node3D, queue: String, identity: String) -> String:
	return "%d|%s|%s" % [target.get_instance_id(), queue, identity]


static func _prune_order_memory(now: int) -> void:
	if now - _last_order_prune_msec < ORDER_PRUNE_INTERVAL_MSEC:
		return
	_last_order_prune_msec = now
	for key in _order_memory.keys():
		var entry: Dictionary = _order_memory.get(key, {})
		if now - int(entry.get("seen", 0)) > ORDER_MEMORY_MSEC:
			_order_memory.erase(key)


static func _order_for(target: Node3D, queue: String, identity: String) -> int:
	var now := Time.get_ticks_msec()
	_prune_order_memory(now)
	if not identity.is_empty():
		var key := _memory_key(target, queue, identity)
		if _order_memory.has(key):
			var entry: Dictionary = _order_memory[key]
			entry["seen"] = now
			_order_memory[key] = entry
			return int(entry.get("order", 0))
	_order_seq += 1
	if not identity.is_empty():
		_order_memory[_memory_key(target, queue, identity)] = {"order": _order_seq, "seen": now}
	return _order_seq


static func _touch_order_memory(target: Node3D, queue: String, identity: String, order_id: int) -> void:
	if target == null or not is_instance_valid(target) or identity.is_empty():
		return
	var now := Time.get_ticks_msec()
	_prune_order_memory(now)
	_order_memory[_memory_key(target, queue, identity)] = {"order": order_id, "seen": now}


static func _forget_order_memory(n) -> void:
	if n == null or not is_instance_valid(n) or n._target == null or not is_instance_valid(n._target):
		return
	var identity := _memory_identity(n._cast_instance_id, n._periodic_key)
	if identity.is_empty():
		return
	_order_memory.erase(_memory_key(n._target, n._queue_key(), identity))


static func _find_direct_burst(target: Node3D, kind: String, split: Dictionary = {}, heal: bool = false):
	var n = _indexed(_direct_index, _direct_lookup_key(target, kind, heal))
	if n != null and not n._banner and not n._crit and n._target == target and n._compatible_split(split) and n._age <= DIRECT_BURST_WINDOW:
		return n
	return null


static func _find_cast(target: Node3D, cast_instance_id: int, heal: bool = false, kind: String = ""):
	var key := _cast_lookup_key(target, cast_instance_id, heal, kind)
	var n = _indexed(_cast_index, key)
	if n == null or n._banner or n._target != target or not n._periodic_key.is_empty():
		return null
	return n


static func _find_periodic(target: Node3D, periodic_key: String):
	var n = _indexed(_periodic_index, _periodic_lookup_key(target, periodic_key))
	if n == null or n._banner or n._target != target:
		return null
	return n


static func _free_slot(target: Node3D, queue: String) -> int:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for n in _queue_members(target, queue):
		if n._lane < 0 or n._lane >= LANES:
			continue
		counts[n._lane] += 1
	var best := 0
	for i in LANES:
		if counts[i] < counts[best]:
			best = i
	return best


static func _prune_overflow(target: Node3D, queue: String):
	var mine := _queue_members(target, queue)
	if mine.size() < MAX_LIVE_PER_QUEUE:
		return null
	var oldest = mine[0]
	for n in mine:
		if n._age > oldest._age:
			oldest = n
	_forget_order_memory(oldest)
	oldest._begin_eviction()
	return oldest


static func _queue_members(target: Node3D, queue: String) -> Array:
	var members: Array = []
	var key := _queue_lookup_key(target, queue)
	var bucket: Array = _queue_index.get(key, [])
	var keep: Array = []
	for n in bucket:
		if n == null or not is_instance_valid(n):
			continue
		keep.append(n)
		if not n._banner and not n._evicted and n._target == target and n._queue_key() == queue:
			members.append(n)
	if keep.is_empty():
		_queue_index.erase(key)
	elif keep.size() != bucket.size():
		_queue_index[key] = keep
	members.sort_custom(func(a, b) -> bool:
		if a._order_id == b._order_id:
			return a._lane < b._lane
		return a._order_id < b._order_id
	)
	return members


static func _recenter_key(target: Node3D, queue: String) -> String:
	return "%d|%s" % [target.get_instance_id(), queue]


static func _queue_affected_by_newcomer(queue: String, newcomer) -> bool:
	if newcomer == null or not is_instance_valid(newcomer):
		return false
	var incoming := String(newcomer._queue_key())
	return (
		incoming == queue
		or (incoming == QUEUE_DIRECT and queue == QUEUE_DOT)
		or (incoming == QUEUE_HEAL and queue == QUEUE_HOT)
	)


static func _hold_recenter(target: Node3D, queue: String) -> void:
	if target == null or not is_instance_valid(target) or _queue_members(target, queue).is_empty():
		return
	_recenter_holds[_recenter_key(target, queue)] = {
		"target": target,
		"queue": queue,
		"until": Time.get_ticks_msec() + RECENTER_HOLD_MSEC,
	}


static func _flush_recenter_holds() -> void:
	var now := Time.get_ticks_msec()
	for key in _recenter_holds.keys():
		var entry: Dictionary = _recenter_holds.get(key, {})
		var target = entry.get("target")
		if target == null or not is_instance_valid(target):
			_recenter_holds.erase(key)
			continue
		if now < int(entry.get("until", 0)):
			continue
		var queue := String(entry.get("queue", QUEUE_DIRECT))
		_recenter_holds.erase(key)
		_mark_reflow(target)


static func _reflow_queue(target: Node3D, queue: String, newcomer = null) -> void:
	if target == null or not is_instance_valid(target):
		return
	var hold_key := _recenter_key(target, queue)
	if _queue_affected_by_newcomer(queue, newcomer):
		_recenter_holds.erase(hold_key)
	elif _recenter_holds.has(hold_key):
		if Time.get_ticks_msec() < int((_recenter_holds[hold_key] as Dictionary).get("until", 0)):
			return
		_recenter_holds.erase(hold_key)
	var members := _queue_members(target, queue)
	if members.is_empty():
		return
	var centers := _pack_centers(members)
	for i in members.size():
		var n = members[i]
		var desired: Vector2 = centers[mini(i, centers.size() - 1)]
		n._set_layout_target(desired, n == newcomer and members.size() > 1)


static func _reflow_all(target: Node3D, newcomer = null) -> void:
	_reflow_queue(target, QUEUE_DIRECT, newcomer)
	_reflow_queue(target, QUEUE_DOT, newcomer)
	_reflow_queue(target, QUEUE_HEAL, newcomer)
	_reflow_queue(target, QUEUE_HOT, newcomer)


static func _alive_target(n) -> Node3D:
	if n == null or not is_instance_valid(n):
		return null
	var t = n._target
	if t == null or not is_instance_valid(t):
		return null
	return t


static func _retire(n, remove_from_live: bool = true) -> void:
	if n == null:
		return
	var target := _alive_target(n)
	var queue := QUEUE_DIRECT
	var was_banner := false
	var was_evicted := false
	if is_instance_valid(n):
		queue = n._queue_key()
		was_banner = n._banner
		was_evicted = n._evicted
		_unindex_number(n)
		n._reset_for_pool()
		if _pool.size() < MAX_POOLED:
			_pool.append(n)
		else:
			n.queue_free()
	if remove_from_live:
		_live.erase(n)
	if target != null and not was_banner and not was_evicted:
		_hold_recenter(target, queue)
		if queue == QUEUE_DIRECT:
			_hold_recenter(target, QUEUE_DOT)
		elif queue == QUEUE_HEAL:
			_hold_recenter(target, QUEUE_HOT)


static func clear_all() -> void:
	_live.clear()
	_pool.clear()
	_runner = null
	_order_memory.clear()
	_order_seq = 0
	_recenter_holds.clear()
	_periodic_index.clear()
	_cast_index.clear()
	_direct_index.clear()
	_queue_index.clear()
	_dirty_reflows.clear()
	_split_material_cache.clear()
	_last_order_prune_msec = 0
	_frame_camera = null
	_frame_origins.clear()
	_style_queue.clear()
	_style_queued.clear()
	var tree := Engine.get_main_loop()
	if not (tree is SceneTree):
		return
	var layer := (tree as SceneTree).root.get_node_or_null("DamageNumbers")
	if layer != null and is_instance_valid(layer):
		layer.queue_free()


static func clear_for(target: Node3D) -> void:
	if target == null:
		return
	for n in _live.duplicate():
		if n == null or not is_instance_valid(n):
			_live.erase(n)
			continue
		if n._target == target:
			_discard(n)
	var prefix := "%d|" % target.get_instance_id()
	for key in _recenter_holds.keys():
		if String(key).begins_with(prefix):
			_recenter_holds.erase(key)
	for key in _order_memory.keys():
		if String(key).begins_with(prefix):
			_order_memory.erase(key)


static func _discard(n) -> void:
	if n == null:
		return
	if is_instance_valid(n):
		_unindex_number(n)
		n._reset_for_pool()
		if _pool.size() < MAX_POOLED:
			_pool.append(n)
		else:
			n.queue_free()
	_live.erase(n)


static func tick_all(delta: float) -> void:
	_flush_recenter_holds()
	_frame_origins.clear()
	_frame_camera = _runner.get_viewport().get_camera_3d() if _runner != null and is_instance_valid(_runner) else null
	_flush_style_budget()
	_flush_reflows()
	var i := _live.size() - 1
	while i >= 0:
		var n = _live[i]
		if n == null or not is_instance_valid(n):
			_live.remove_at(i)
		elif not n._advance(delta):
			_retire(n, false)
			_live.remove_at(i)
		i -= 1
	_frame_camera = null
	_frame_origins.clear()


static func tint_for(kind: String) -> Color:
	return _tint_for(kind)


static func tint_for_element(element: int, tick: bool = false) -> Color:
	return _tint_for(kind_for_element(element, tick))


static func kind_for_element(element: int, tick: bool = false) -> String:
	if tick:
		match element:
			AbilityDef.Element.FIRE:
				return "fire_tick"
			AbilityDef.Element.ICE:
				return "ice_tick"
			AbilityDef.Element.STORM:
				return "lightning_tick"
			AbilityDef.Element.SHADOW:
				return "shadow_tick"
			AbilityDef.Element.NATURE:
				return "nature_tick"
			AbilityDef.Element.HOLY:
				return "divine_tick"
			AbilityDef.Element.PROTECTION:
				return "protection_tick"
			AbilityDef.Element.WIND:
				return "wind_tick"
			AbilityDef.Element.ILLUSION:
				return "illusion_tick"
			_:
				return "tick"
	match element:
		AbilityDef.Element.FIRE:
			return "fire"
		AbilityDef.Element.ICE:
			return "ice"
		AbilityDef.Element.STORM:
			return "lightning"
		AbilityDef.Element.SHADOW:
			return "shadow"
		AbilityDef.Element.NATURE:
			return "nature"
		AbilityDef.Element.HOLY:
			return "divine"
		AbilityDef.Element.PROTECTION:
			return "protection"
		AbilityDef.Element.WIND:
			return "wind"
		AbilityDef.Element.ILLUSION:
			return "illusion"
		_:
			return "physical"


static func split_for_hit(ab: AbilityDef, extras: PackedInt32Array, victim: Object, ability_id: String, crit: bool, primary: int, tick: bool, base: float, actual_total: float = -1.0) -> Dictionary:
	return _split_from_packet(ab, extras, victim, ability_id, crit, primary, tick, base, false, actual_total)


static func split_for_heal(ab: AbilityDef, extras: PackedInt32Array, ability_id: String, crit: bool, primary: int, base: float, actual_total: float = -1.0) -> Dictionary:
	return _split_from_packet(ab, extras, null, ability_id, crit, primary, false, base, true, actual_total)


static func split_for_amount(kind: String, amount: float, tint: Color = Color(0, 0, 0, 0)) -> Dictionary:
	if amount <= 0.0:
		return {}
	var color := _effective_tint(kind, tint)
	return {
		"elements": [AbilityDef.Element.NONE],
		"colors": [color],
		"amts": [amount],
		"sig": _split_signature([color]),
	}


static func scaled_split(split: Dictionary, actual_total: float) -> Dictionary:
	if split.is_empty() or actual_total <= 0.0:
		return {}
	var amts: Array = split.get("amts", [])
	var split_total := 0.0
	for amount in amts:
		split_total += float(amount)
	if split_total <= 0.001:
		return {}
	var out := split.duplicate(true)
	var scaled: Array = []
	var factor := actual_total / split_total
	for amount in amts:
		scaled.append(float(amount) * factor)
	out["amts"] = scaled
	return out


static func _split_from_packet(ab: AbilityDef, extras: PackedInt32Array, victim: Object, ability_id: String, crit: bool, primary: int, tick: bool, base: float, healing: bool, actual_total: float = -1.0) -> Dictionary:
	if base <= 0.0 and (ab == null or ab.split_flat.is_empty()):
		return {}
	var channel := "heal" if healing else "damage"
	var parts := SpellPower.packet_parts(base, ab, extras, victim, healing, ability_id, crit, primary, channel)
	if parts.is_empty():
		return {}
	var display_elements := (
		SpellPower.healing_elements_for(ab, extras, primary)
		if healing
		else SpellPower.damage_elements_for(ab, extras, primary)
	)
	var restrict_elements := ab != null and not ab.infusion_ids.is_empty()
	var visible_parts: Array = []
	for part in parts:
		var element := int(part.get("element", primary))
		if restrict_elements and not display_elements.has(element):
			continue
		visible_parts.append(part)
	if visible_parts.is_empty():
		return {}
	var calculated_total := 0.0
	for part in visible_parts:
		calculated_total += float(part.get("amount", 0.0))
	var amount_scale := 1.0
	if actual_total >= 0.0 and calculated_total > 0.001:
		amount_scale = actual_total / calculated_total
	var elements: Array = []
	var colors: Array = []
	var amts: Array = []
	for part in visible_parts:
		var el := int(part.get("element", primary))
		var amt := float(part.get("amount", 0.0)) * amount_scale
		if amt <= 0.01:
			continue
		elements.append(el)
		colors.append(tint_for_element(el, tick))
		amts.append(amt)
		if colors.size() >= MAX_COLOR_BANDS:
			break
	if colors.is_empty():
		return {}
	return {"elements": elements, "colors": colors, "amts": amts, "sig": _split_signature(colors)}


static func _effective_tint(kind: String, tint: Color) -> Color:
	if tint.a <= 0.02 or tint.is_equal_approx(Color.WHITE):
		return _tint_for(kind)
	return tint


static func _tint_for(kind: String) -> Color:
	# Add new combat-text colors here. Tick variants can share the parent type.
	match kind:
		"fire", "fire_tick", "burn":
			return Color(1.0, 0.48, 0.16)
		"combust":
			return Color(1.0, 0.28, 0.05)
		"ice", "ice_tick", "frost":
			return Color(0.55, 0.86, 1.0)
		"storm", "storm_tick", "lightning", "lightning_tick", "shocked":
			return Color(0.62, 0.74, 1.0)
		"holy", "holy_tick", "divine", "divine_tick":
			return Color(1.0, 0.86, 0.38)
		"shadow", "shadow_tick", "afflicted":
			return Color(0.56, 0.27, 0.72)
		"nature", "nature_tick", "rejuvenation":
			return Color(0.42, 0.88, 0.42)
		"protection", "protection_tick":
			return Color(0.78, 0.86, 1.0)
		"wind", "wind_tick":
			return Color(0.72, 0.92, 0.82)
		"illusion", "illusion_tick":
			return Color(0.92, 0.55, 0.82)
		"heal":
			return Color(0.42, 0.95, 0.52)
		"shield":
			return Color(0.72, 0.72, 0.74)
		"physical", "auto", "hit", "tick":
			return Color(0.96, 0.93, 0.86)
		"banner":
			return Color(0.62, 0.92, 1.0)
		_:
			return Color(0.96, 0.93, 0.86)


func _boot(target: Node3D, amount: float, kind: String, tint: Color, lane: int, crit: bool = false, cast_instance_id: int = -1, periodic_key: String = "", split: Dictionary = {}, heal: bool = false, secondary_queue: bool = false, order_id: int = 0) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = true
	_target = target
	_amount = amount
	_kind = kind
	_tint = tint
	_lane = lane
	_age = 0.0
	_banner = false
	_crit = crit
	_cast_instance_id = cast_instance_id
	_periodic_key = periodic_key
	_heal = heal
	_secondary_queue = secondary_queue
	_order_id = order_id
	_life = CRIT_LIFE if crit else LIFE
	_pop = CRIT_POP if crit else NORMAL_POP
	_evicted = false
	_evict_age = 0.0
	_layout_ready = false
	_anchor_ready = false
	_has_world_anchor = false
	_style_dirty = false
	_absorb_split(split)
	_style_dirty = true
	_queue_style(self)


func _boot_banner(target: Node3D, banner: String, tint: Color) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = true
	_target = target
	_kind = "banner"
	_tint = tint if tint.a > 0.02 else _tint_for("banner")
	_lane = 1
	_age = 0.0
	_life = 0.85
	_pop = 1.08
	_banner = true
	_evicted = false
	_evict_age = 0.0
	_layout_ready = false
	_anchor_ready = false
	_has_world_anchor = false
	_style_dirty = false
	_band_colors.clear()
	_band_amts.clear()
	_band_elements.clear()
	_split_sig = ""
	_style(banner, 20)


func _add(amount: float, tint: Color, crit: bool = false, split: Dictionary = {}) -> void:
	var same_hit_component := _age <= HIT_COMPONENT_WINDOW
	_amount += amount
	_crit = (_crit or crit) if same_hit_component else crit
	_age = 0.0
	_life = CRIT_LIFE if _crit else LIFE
	_pop = CRIT_POP if crit else MERGE_POP
	modulate.a = 1.0
	if tint.a > 0.02:
		_tint = tint
	_merge_split(split, false)
	_style_dirty = true
	_queue_style(self)
	_touch_memory()
	_mark_reflow(_target)


func _replace_tick(amount: float, tint: Color, crit: bool = false, split: Dictionary = {}) -> void:
	var same_hit_component := _age <= HIT_COMPONENT_WINDOW
	if same_hit_component:
		_amount += amount
		_merge_split(split, false)
	else:
		_amount = amount
		_absorb_split(split)
	_crit = (_crit or crit) if same_hit_component else crit
	_age = 0.0
	_life = CRIT_LIFE if _crit else LIFE
	_pop = CRIT_POP if crit else MERGE_POP
	modulate.a = 1.0
	if tint.a > 0.02:
		_tint = tint
	_style_dirty = true
	_queue_style(self)
	_touch_memory()
	_mark_reflow(_target)


func _flush_style() -> void:
	if not _style_dirty:
		return
	_style_dirty = false
	_style(_caption(), 34 if _crit else 26)
	_mark_reflow(_target)


func _reset_for_pool() -> void:
	_target = null
	_amount = 0.0
	_kind = "hit"
	_tint = Color.WHITE
	_age = 0.0
	_life = LIFE
	_lane = 0
	_pop = 1.0
	_banner = false
	_crit = false
	_cast_instance_id = -1
	_periodic_key = ""
	_heal = false
	_secondary_queue = false
	_order_id = 0
	_layout_offset = Vector2.ZERO
	_layout_target = Vector2.ZERO
	_layout_ready = false
	_anchor_y = 0.0
	_anchor_target_y = 0.0
	_anchor_ready = false
	_last_world_anchor = Vector3.ZERO
	_has_world_anchor = false
	_evicted = false
	_evict_age = 0.0
	_evict_from = Vector2.ZERO
	_evict_to = Vector2.ZERO
	_evict_start_alpha = 1.0
	_style_dirty = false
	_styled_font_size = -1
	_band_colors.clear()
	_band_amts.clear()
	_band_elements.clear()
	_split_sig = ""
	text = ""
	material = null
	modulate = Color.WHITE
	scale = Vector2.ONE
	position = Vector2.ZERO
	visible = false


func _caption() -> String:
	var caption := str(maxi(1, int(round(_amount))))
	if _crit:
		caption += "!"
	return caption


func _is_dot() -> bool:
	return _secondary_queue


func _queue_key() -> String:
	return _queue_name(_heal, _is_dot())


func _touch_memory() -> void:
	_touch_order_memory(_target, _queue_key(), _memory_identity(_cast_instance_id, _periodic_key), _order_id)


func _has_split() -> bool:
	return _visible_band_count() >= 2


func _compatible_split(split: Dictionary) -> bool:
	if split.is_empty() or _split_sig.is_empty():
		return true
	var incoming := String(split.get("sig", _split_signature(split.get("colors", []))))
	if incoming.is_empty():
		return true
	return incoming == _split_sig


static func _split_signature(colors: Array) -> String:
	var bits: PackedStringArray = []
	for item in colors:
		var col := Color(item)
		bits.append("%.2f:%.2f:%.2f" % [col.r, col.g, col.b])
	return "|".join(bits)


func _visible_band_count() -> int:
	var total := _band_total()
	if total <= 0.01:
		return 0
	var n := 0
	for amt in _band_amts:
		if float(amt) / total > 0.005:
			n += 1
	return n


func _band_total() -> float:
	var total := 0.0
	for amt in _band_amts:
		total += float(amt)
	return total


func _absorb_split(split: Dictionary) -> void:
	_band_colors.clear()
	_band_amts.clear()
	_band_elements.clear()
	_split_sig = ""
	if split.is_empty():
		return
	var elements: Array = split.get("elements", [])
	var colors: Array = split.get("colors", [])
	var amts: Array = split.get("amts", [])
	for i in mini(MAX_COLOR_BANDS, mini(colors.size(), amts.size())):
		_band_elements.append(int(elements[i]) if i < elements.size() else AbilityDef.Element.NONE)
		_band_colors.append(colors[i])
		_band_amts.append(float(amts[i]))
	_split_sig = String(split.get("sig", _split_signature(_band_colors)))


func _merge_split(split: Dictionary, replace: bool) -> void:
	if split.is_empty():
		return
	if replace or _band_amts.is_empty():
		_absorb_split(split)
		return
	var elements: Array = split.get("elements", [])
	var colors: Array = split.get("colors", [])
	var amts: Array = split.get("amts", [])
	for i in mini(MAX_COLOR_BANDS, amts.size()):
		var add := float(amts[i])
		if add <= 0.01:
			continue
		var element := int(elements[i]) if i < elements.size() else AbilityDef.Element.NONE
		var color := Color(colors[i]) if i < colors.size() else _tint
		var matched := -1
		for j in _band_amts.size():
			var same_element := element != AbilityDef.Element.NONE and j < _band_elements.size() and int(_band_elements[j]) == element
			var same_color := j < _band_colors.size() and Color(_band_colors[j]).is_equal_approx(color)
			if same_element or same_color:
				matched = j
				break
		if matched >= 0:
			_band_amts[matched] = float(_band_amts[matched]) + add
			_band_colors[matched] = color
		elif _band_amts.size() < MAX_COLOR_BANDS:
			_band_elements.append(element)
			_band_amts.append(add)
			_band_colors.append(color)
	_split_sig = _split_signature(_band_colors)


static func _split_material(colors: Array, splits: PackedFloat32Array, used: int, control_height: float) -> ShaderMaterial:
	var quantized := PackedFloat32Array()
	for split in splits:
		quantized.append(float(round(split * SPLIT_BUCKETS)) / SPLIT_BUCKETS)
	var bits := PackedStringArray(["%d" % used, "%d" % int(round(control_height))])
	for item in colors:
		var color := Color(item)
		bits.append("%d:%d:%d" % [
			int(round(color.r * 255.0)),
			int(round(color.g * 255.0)),
			int(round(color.b * 255.0)),
		])
	for split in quantized:
		bits.append("%d" % int(round(split * SPLIT_BUCKETS)))
	var key := "|".join(bits)
	var cached := _split_material_cache.get(key) as ShaderMaterial
	if cached != null:
		return cached
	var mat := ShaderMaterial.new()
	mat.shader = _SplitShader
	mat.set_shader_parameter("color_0", colors[0])
	mat.set_shader_parameter("color_1", colors[1])
	mat.set_shader_parameter("color_2", colors[2])
	mat.set_shader_parameter("color_3", colors[3])
	mat.set_shader_parameter("split_0", quantized[0])
	mat.set_shader_parameter("split_1", quantized[1] if used >= 3 else 1.0)
	mat.set_shader_parameter("split_2", quantized[2] if used >= 4 else 1.0)
	mat.set_shader_parameter("band_count", float(used))
	mat.set_shader_parameter("control_size", Vector2(1.0, maxf(control_height, 1.0)))
	_split_material_cache[key] = mat
	return mat


func _apply_split_material() -> void:
	if not _has_split():
		material = null
		var solid_tint := _tint
		var total := _band_total()
		if total > 0.01:
			for i in _band_amts.size():
				if float(_band_amts[i]) / total <= 0.005:
					continue
				solid_tint = Color(_band_colors[i]) if i < _band_colors.size() else _tint
				break
		add_theme_color_override("font_color", solid_tint)
		return
	var total := _band_total()
	var colors: Array[Color] = [_tint, _tint, _tint, _tint]
	var splits := PackedFloat32Array([1.0, 1.0, 1.0])
	var used := 0
	var cum := 0.0
	for i in _band_amts.size():
		var share := float(_band_amts[i]) / total
		if share <= 0.005:
			continue
		colors[used] = _band_colors[i] if i < _band_colors.size() else _tint
		cum += share
		if used < MAX_COLOR_BANDS - 1:
			splits[used] = clampf(cum, 0.0, 1.0)
		used += 1
		if used >= MAX_COLOR_BANDS:
			break
	material = _split_material(colors, splits, used, size.y)
	add_theme_color_override("font_color", Color.WHITE)


func _style(caption: String, font_size: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var layout_changed := text != caption or _styled_font_size != font_size
	if text != caption:
		text = caption
	if _styled_font_size != font_size:
		_styled_font_size = font_size
		add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.94))
	add_theme_constant_override("outline_size", 5)
	if layout_changed:
		_fit_text()
	else:
		_apply_split_material()


func _fit_text() -> void:
	var mins := get_minimum_size()
	size = Vector2(maxf(mins.x, 8.0), maxf(mins.y, 8.0))
	pivot_offset = size * 0.5
	_apply_split_material()


func _advance(delta: float) -> bool:
	if _target_is_gone():
		return false
	if _evicted:
		_evict_age += delta
		var evict_t := clampf(_evict_age / EVICT_TIME, 0.0, 1.0)
		var eased_t := 1.0 - (1.0 - evict_t) * (1.0 - evict_t)
		_layout_offset = _evict_from.lerp(_evict_to, eased_t)
		_pop = lerpf(_pop, 1.0, clampf(delta * 12.0, 0.0, 1.0))
		modulate.a = _evict_start_alpha * (1.0 - evict_t)
		_place()
		return evict_t < 1.0
	_age += delta
	_pop = lerpf(_pop, 1.0, clampf(delta * 12.0, 0.0, 1.0))
	var layout_weight := 1.0 - exp(-LAYOUT_MOVE_SPEED * delta)
	if _layout_ready:
		_layout_offset = _layout_offset.lerp(_layout_target, layout_weight)
	if _anchor_ready:
		_anchor_y = lerpf(_anchor_y, _anchor_target_y, layout_weight)
	if _age >= _life:
		return false
	var fade_time := FADE_TIME
	var fade_from := maxf(0.0, _life - fade_time)
	if _age > fade_from:
		modulate.a = 1.0 - clampf((_age - fade_from) / (_life - fade_from), 0.0, 1.0)
	else:
		modulate.a = 1.0
	_place()
	return true


static func _frame_origin(target: Node3D) -> Vector3:
	var key := target.get_instance_id()
	if _frame_origins.has(key):
		return _frame_origins[key] as Vector3
	var origin := target.get_global_transform_interpolated().origin
	_frame_origins[key] = origin
	return origin


func _place() -> void:
	if _target_is_gone() and not _has_world_anchor:
		_age = _life
		return
	var target_valid := not _target_is_gone()
	var cam := _frame_camera if _frame_camera != null and is_instance_valid(_frame_camera) else get_viewport().get_camera_3d()
	if cam == null:
		return
	var world := _last_world_anchor
	if target_valid:
		var anchor_y := _desired_anchor_y() if not _anchor_ready else _anchor_y
		world = _frame_origin(_target) + Vector3(0.0, anchor_y, 0.0)
		_last_world_anchor = world
		_has_world_anchor = true
	if cam.is_position_behind(world):
		visible = false
		return
	visible = true
	var offset := _layout_offset if _layout_ready else Vector2.ZERO
	if _banner:
		offset = Vector2(0.0, -40.0)
	scale = Vector2(_pop, _pop)
	position = cam.unproject_position(world) + offset - size * 0.5


func _begin_eviction() -> void:
	_evicted = true
	_evict_age = 0.0
	_evict_from = _layout_offset if _layout_ready else Vector2.ZERO
	_evict_to = _evict_from + Vector2(0.0, -EVICT_PUSH)
	_evict_start_alpha = modulate.a


func _set_layout_target(offset: Vector2, arriving: bool = false) -> void:
	_layout_target = offset
	if not _layout_ready:
		_layout_offset = offset
		if arriving and not offset.is_zero_approx():
			_layout_offset += offset.normalized() * ENTRY_OUTSET
		_layout_ready = true
	_anchor_target_y = _desired_anchor_y()
	if not _anchor_ready:
		_anchor_y = _anchor_target_y
		_anchor_ready = true
	_place()


func _desired_anchor_y() -> float:
	var head_y := float(_target.get("height")) if _target != null and "height" in _target else 1.8
	if _banner:
		return head_y + 0.22
	if _is_dot():
		return FOOT_ANCHOR
	return head_y * 0.5


func _target_is_gone() -> bool:
	if _target == null or not is_instance_valid(_target):
		return true
	return bool(_target.get("is_dead"))


static func _pack_row(sizes: Array) -> Array:
	var total := 0.0
	for i in sizes.size():
		var piece: Vector2 = sizes[i]
		total += piece.x
		if i > 0:
			total += QUEUE_PAD
	var x := -total * 0.5
	var out: Array = []
	for piece_any in sizes:
		var piece: Vector2 = piece_any
		out.append(Vector2(x + piece.x * 0.5, 0.0))
		x += piece.x + QUEUE_PAD
	return out


static func _pack_centers(members: Array) -> Array:
	if members.size() <= 1:
		return [Vector2.ZERO]
	var sizes: Array = []
	for member in members:
		sizes.append(member.size)
	return _pack_row(sizes)
