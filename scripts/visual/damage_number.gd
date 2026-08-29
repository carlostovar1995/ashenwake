extends Label

## Floating combat text. One manager ticks every floater so lifetime
## cannot stall, rise is capped, and lanes are reused instead of stacking
## ever higher.

const LIFE := 0.72
const MAX_RISE := 32.0
const LANES := 4
const LANE_X: Array[float] = [-28.0, -10.0, 10.0, 28.0]
const WRAP_X := 16.0
const MAX_LIVE := 12

var _target: Node3D
var _amount: float = 0.0
var _kind: String = "hit"
var _tint: Color = Color.WHITE
var _age: float = 0.0
var _life: float = LIFE
var _lane: int = 0
var _wrap: int = 0
var _pop: float = 1.0
var _banner: bool = false

static var _live: Array = []
static var _runner: Node


static func show_hit(target: Node3D, amount: float, kind: String = "hit", tint: Color = Color(0, 0, 0, 0)) -> void:
	if target == null or not is_instance_valid(target) or amount <= 0.0:
		return
	var tree := target.get_tree()
	if tree == null:
		return
	var want_kind := kind if not kind.is_empty() else "hit"
	var want_tint := tint if tint.a > 0.02 else _tint_for(want_kind)
	_ensure_runner(tree)
	if _is_fast_dot(want_kind):
		var existing = _find_merge(target, want_kind)
		if existing:
			existing._add(amount, want_tint)
			return
	_prune_overflow(target)
	var n = new()
	var slot := _free_slot(target)
	n._boot(target, amount, want_kind, want_tint, slot.x, slot.y)
	_layer(tree).add_child(n)
	_live.append(n)
	n._place()


static func present_merged(target: Node3D, amount: float, tint: Color = Color(0, 0, 0, 0)) -> void:
	show_hit(target, amount, "hit", tint)


static func show_banner(target: Node3D, text: String, tint: Color = Color(0.62, 0.92, 1.0)) -> void:
	if target == null or not is_instance_valid(target) or text.is_empty():
		return
	var tree := target.get_tree()
	if tree == null:
		return
	_ensure_runner(tree)
	var n = new()
	n._boot_banner(target, text, tint)
	_layer(tree).add_child(n)
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


static func _is_fast_dot(kind: String) -> bool:
	return kind == "ice_tick" or kind == "storm_tick" or kind == "heal"


static func _find_merge(target: Node3D, kind: String):
	for n in _live:
		if n == null or not is_instance_valid(n):
			continue
		if n._banner or n._kind != kind or n._target != target:
			continue
		if n._age < n._life * 0.85:
			return n
	return null


static func _free_slot(target: Node3D) -> Vector2i:
	var counts: Array[int] = [0, 0, 0, 0]
	for n in _live:
		if n == null or not is_instance_valid(n) or n._banner:
			continue
		if n._target != target or n._lane < 0 or n._lane >= LANES:
			continue
		counts[n._lane] += 1
	var best := 0
	for i in LANES:
		if counts[i] < counts[best]:
			best = i
	return Vector2i(best, counts[best])


static func _prune_overflow(target: Node3D) -> void:
	var mine: Array = []
	for n in _live:
		if n != null and is_instance_valid(n) and not n._banner and n._target == target:
			mine.append(n)
	while mine.size() >= MAX_LIVE:
		var oldest = mine[0]
		for n in mine:
			if n._age > oldest._age:
				oldest = n
		_retire(oldest)
		mine.erase(oldest)


static func _retire(n) -> void:
	if n == null:
		return
	_live.erase(n)
	if is_instance_valid(n):
		n.queue_free()


static func tick_all(delta: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		var n = _live[i]
		if n == null or not is_instance_valid(n) or not n._advance(delta):
			if n != null and is_instance_valid(n):
				n.queue_free()
			_live.remove_at(i)
		i -= 1


static func _tint_for(kind: String) -> Color:
	match kind:
		"burn", "fire", "fire_tick":
			return Color(1.0, 0.52, 0.18)
		"combust":
			return Color(1.0, 0.32, 0.08)
		"ice", "ice_tick":
			return Color(0.62, 0.88, 1.0)
		"storm", "storm_tick":
			return Color(0.8, 0.66, 1.0)
		"banner":
			return Color(0.62, 0.92, 1.0)
		"heal":
			return Color(0.42, 0.95, 0.52)
		_:
			return Color(1.0, 1.0, 1.0)


func _boot(target: Node3D, amount: float, kind: String, tint: Color, lane: int, wrap: int) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	_target = target
	_amount = amount
	_kind = kind
	_tint = tint
	_lane = lane
	_wrap = wrap
	_age = 0.0
	_life = LIFE
	_pop = 1.14
	_banner = false
	_style(str(maxi(1, int(round(amount)))), 26)


func _boot_banner(target: Node3D, banner: String, tint: Color) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	_target = target
	_kind = "banner"
	_tint = tint if tint.a > 0.02 else _tint_for("banner")
	_lane = 1
	_wrap = 0
	_age = 0.0
	_life = 0.85
	_pop = 1.08
	_banner = true
	_style(banner, 20)


func _add(amount: float, tint: Color) -> void:
	_amount += amount
	_pop = 1.18
	modulate.a = 1.0
	if tint.a > 0.02:
		_tint = tint
		add_theme_color_override("font_color", _tint)
	text = str(maxi(1, int(round(_amount))))
	# Keep it readable, but never rewind age — that is what sent numbers
	# climbing forever while Chilled Ground kept merging.
	_life = minf(maxf(_life, _age + 0.28), 0.95)


func _style(caption: String, font_size: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text = caption
	size = Vector2(96.0, 32.0)
	pivot_offset = size * 0.5
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", _tint)
	add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.94))
	add_theme_constant_override("outline_size", 10)


func _advance(delta: float) -> bool:
	_age += delta
	_pop = lerpf(_pop, 1.0, clampf(delta * 12.0, 0.0, 1.0))
	if _age >= _life:
		return false
	var fade_from := _life * 0.58
	if _age > fade_from:
		modulate.a = 1.0 - clampf((_age - fade_from) / (_life - fade_from), 0.0, 1.0)
	else:
		modulate.a = 1.0
	_place()
	return true


func _place() -> void:
	if _target == null or not is_instance_valid(_target):
		_age = _life
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head_y := float(_target.get("height")) if "height" in _target else 1.8
	var world := _target.get_global_transform_interpolated().origin + Vector3(0.0, head_y + 0.22, 0.0)
	if cam.is_position_behind(world):
		visible = false
		return
	visible = true
	var t := clampf(_age / maxf(_life, 0.001), 0.0, 1.0)
	var rise := (1.0 - (1.0 - t) * (1.0 - t)) * MAX_RISE
	var side := 1.0
	if _lane < LANE_X.size() and LANE_X[_lane] < 0.0:
		side = -1.0
	var x := 0.0
	if not _banner and _lane >= 0 and _lane < LANE_X.size():
		x = LANE_X[_lane] + float(_wrap) * WRAP_X * side
	var y := -22.0 - rise
	if _banner:
		y = -40.0 - rise * 0.7
	scale = Vector2(_pop, _pop)
	position = cam.unproject_position(world) + Vector2(-size.x * 0.5 + x, y)
