class_name CameraRig
extends Node3D

@export var height: float = 19.0
@export var back: float = 16.0
@export var pitch_deg: float = -52.0
@export var pan_speed: float = 24.0
@export var edge_pan_speed: float = 234.0
@export var edge_pan_px: float = 16.0
@export var lerp_speed: float = 11.0
@export var drag_sensitivity: float = 0.027
@export var limit_margin: float = 4.0

var follow_locked: bool = true
var _cam: Camera3D
var _look: Vector3 = Vector3(0, 0, 12)
var _dragging: bool = false
var _drag_last: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Follow-cam is updated every render frame; don't let the engine interpolate it.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = 42.0
	_cam.near = 0.2
	_cam.far = 200.0
	_cam.current = true
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_cam)
	_cam.position = Vector3(0.0, height, back)
	_cam.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)
	var listener := AudioListener3D.new()
	listener.name = "AudioListener3D"
	listener.current = true
	_cam.add_child(listener)
	global_position = _look


func get_camera() -> Camera3D:
	return _cam


func _process(delta: float) -> void:
	if follow_locked:
		var u: Node3D = GameSession.active_unit
		if u and is_instance_valid(u):
			# Hard lock to the rendered pose. Extra lerp vs physics ticks is what made
			# the run cycle look blurry/jittery while unlocked (static cam) looked fine.
			_look = _follow_origin(u)
			global_position = _look
		return
	var target_look := _look + _pan_vector() * pan_speed * delta
	target_look += _edge_pan() * edge_pan_speed * delta
	target_look = _clamp_look(target_look)
	_look = _clamp_look(_look.lerp(target_look, 1.0 - exp(-lerp_speed * delta)))
	global_position = _look


func _follow_origin(u: Node3D) -> Vector3:
	var origin := u.get_global_transform_interpolated().origin
	origin.y = 0.0
	return origin


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_lock"):
		follow_locked = not follow_locked
		if follow_locked:
			var u: Node3D = GameSession.active_unit
			if u:
				_look = _follow_origin(u)
				global_position = _look
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = event.pressed
		_drag_last = event.position
		if _dragging:
			follow_locked = false
	if event is InputEventMouseMotion and _dragging:
		follow_locked = false
		var delta_px: Vector2 = event.position - _drag_last
		_drag_last = event.position
		_look = _clamp_look(_look + Vector3(-delta_px.x, 0.0, -delta_px.y) * drag_sensitivity)
		global_position = _look


func _clamp_look(p: Vector3) -> Vector3:
	var max_r := 28.0 + limit_margin
	if ArenaState:
		max_r = ArenaState.arena_radius + limit_margin
	var flat := Vector2(p.x, p.z)
	if flat.length() > max_r:
		flat = flat.normalized() * max_r
	return Vector3(flat.x, 0.0, flat.y)


func _pan_vector() -> Vector3:
	var v := Vector3.ZERO
	if Input.is_action_pressed("camera_left"):
		v.x -= 1.0
	if Input.is_action_pressed("camera_right"):
		v.x += 1.0
	if Input.is_action_pressed("camera_up"):
		v.z -= 1.0
	if Input.is_action_pressed("camera_down"):
		v.z += 1.0
	if v.length_squared() > 1.0:
		v = v.normalized()
	if v.length_squared() > 0.0:
		follow_locked = false
	return v


func _edge_pan() -> Vector3:
	if not get_window().has_focus():
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var size := get_viewport().get_visible_rect().size
	var v := Vector3.ZERO
	if mouse.x <= edge_pan_px:
		v.x -= 1.0
	elif mouse.x >= size.x - edge_pan_px:
		v.x += 1.0
	if mouse.y <= edge_pan_px:
		v.z -= 1.0
	elif mouse.y >= size.y - edge_pan_px:
		v.z += 1.0
	if v.length_squared() > 0.0:
		follow_locked = false
	return v
