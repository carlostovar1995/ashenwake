class_name SolarWashFx
extends CanvasLayer

## Full-screen white blowout for Solar Corona / Solar Collapse.
## One ColorRect, two timelines; the screen uses the brighter of the two
## so back-to-back casts do not reset each other's flash.
## Above HUD (10) and damage numbers (25).

const LAYER := 80
const SLOTS := 2
const DEFAULT_FADE_SEC := 0.3

static var _inst: SolarWashFx
static var _host: Node

var _rect: ColorRect
var _active: PackedByteArray = PackedByteArray()
var _elapsed: PackedFloat32Array = PackedFloat32Array()
var _peak: PackedFloat32Array = PackedFloat32Array()
var _fade: PackedFloat32Array = PackedFloat32Array()


static func warmup(parent: Node) -> void:
	if parent == null:
		return
	_host = parent
	if not parent.tree_exiting.is_connected(_release):
		parent.tree_exiting.connect(_release)
	if _inst != null and is_instance_valid(_inst):
		return
	var fx := SolarWashFx.new()
	fx.layer = LAYER
	fx.name = "SolarWash"
	parent.add_child(fx)
	_inst = fx


static func _release() -> void:
	_inst = null
	_host = null


static func play(peak_sec: float, fade_sec: float = DEFAULT_FADE_SEC) -> void:
	var parent: Node = _host
	if parent == null or not is_instance_valid(parent):
		parent = ArenaState.arena
		if parent:
			var fx_root := parent.get_node_or_null("FxRoot")
			if fx_root:
				parent = fx_root
	if parent == null:
		var loop := Engine.get_main_loop()
		parent = loop.root if loop else null
	if parent == null:
		return
	if _inst == null or not is_instance_valid(_inst):
		warmup(parent)
	if _inst == null or not is_instance_valid(_inst):
		return
	_inst._play(peak_sec, fade_sec)


func _ready() -> void:
	_active.resize(SLOTS)
	_elapsed.resize(SLOTS)
	_peak.resize(SLOTS)
	_fade.resize(SLOTS)
	_ensure_rect()
	_set_alpha(0.0)
	set_process(false)


func _play(peak_sec: float, fade_sec: float) -> void:
	_ensure_rect()
	var slot := _claim()
	_active[slot] = 1
	_elapsed[slot] = 0.0
	_peak[slot] = maxf(peak_sec, 0.05)
	_fade[slot] = maxf(fade_sec, 0.05)
	set_process(true)


func _claim() -> int:
	for i in SLOTS:
		if _active[i] == 0:
			return i
	var oldest := 0
	var oldest_elapsed := _elapsed[0]
	for i in range(1, SLOTS):
		if _elapsed[i] > oldest_elapsed:
			oldest = i
			oldest_elapsed = _elapsed[i]
	return oldest


func _process(delta: float) -> void:
	var a := 0.0
	var any := false
	for i in SLOTS:
		if _active[i] == 0:
			continue
		_elapsed[i] += delta
		var peak := _peak[i]
		var fade := _fade[i]
		var u := 0.0
		if _elapsed[i] <= peak:
			u = clampf(_elapsed[i] / peak, 0.0, 1.0)
		else:
			u = 1.0 - clampf((_elapsed[i] - peak) / fade, 0.0, 1.0)
			if _elapsed[i] >= peak + fade:
				_active[i] = 0
				continue
		a = maxf(a, u)
		any = true
	_set_alpha(a)
	if not any:
		set_process(false)


func _ensure_rect() -> void:
	if _rect != null and is_instance_valid(_rect):
		return
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_rect.visible = false
	add_child(_rect)


func _set_alpha(alpha: float) -> void:
	_ensure_rect()
	if _rect == null or not is_instance_valid(_rect):
		return
	var a := clampf(alpha, 0.0, 1.0)
	if a <= 0.001:
		_rect.visible = false
		_rect.color = Color(1.0, 1.0, 1.0, 0.0)
		return
	_rect.visible = true
	_rect.color = Color(1.0, 0.96, 0.88, a * 0.55)
