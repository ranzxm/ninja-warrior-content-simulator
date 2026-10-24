class_name EditorCamera
extends Node3D

## Dedicated 3D orbital/pan/zoom camera controller for EDIT mode, separate from ThirdPersonCamera.

@export var focus_point: Vector3 = Vector3(0.0, 1.0, -12.0)
@export_range(-180.0, 180.0, 1.0) var yaw_deg: float = -25.0
@export_range(-85.0, -5.0, 1.0) var pitch_deg: float = -32.0
@export_range(3.0, 120.0, 0.5) var distance: float = 18.0
@export_range(0.05, 2.0, 0.05) var orbit_sensitivity: float = 0.35
@export_range(0.005, 0.2, 0.005) var pan_sensitivity: float = 0.025
@export_range(0.5, 10.0, 0.5) var zoom_step_distance: float = 2.0
@export_range(2.0, 40.0, 1.0) var smooth_speed: float = 18.0
@export var min_distance: float = 3.0
@export var max_distance: float = 120.0
@export var min_pitch_deg: float = -85.0
@export var max_pitch_deg: float = -5.0

var _active: bool = false
var _orbit_dragging: bool = false
var _pan_dragging: bool = false
var _current_focus: Vector3 = Vector3(0.0, 1.0, -12.0)
var _current_yaw_rad: float = deg_to_rad(-25.0)
var _current_pitch_rad: float = deg_to_rad(-32.0)
var _current_distance: float = 18.0

var _camera: Camera3D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_camera_node()
	snap_to_target()


func _ensure_camera_node() -> void:
	if _camera == null:
		_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.name = "Camera3D"
		_camera.fov = 65.0
		_camera.near = 0.1
		_camera.far = 350.0
		add_child(_camera)


func set_active(active: bool) -> void:
	_active = active
	_orbit_dragging = false
	_pan_dragging = false
	_ensure_camera_node()
	if _camera != null:
		_camera.current = active
	if active and DisplayServer.get_name() != "headless":
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func is_active() -> bool:
	return _active


func get_camera() -> Camera3D:
	_ensure_camera_node()
	return _camera


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.shift_pressed:
				_pan_dragging = mb.pressed
				_orbit_dragging = false
			else:
				_orbit_dragging = mb.pressed
				_pan_dragging = false
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_dragging = mb.pressed
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if _orbit_dragging:
			orbit(mm.relative)
		elif _pan_dragging:
			pan(mm.relative)


func _process(delta: float) -> void:
	if not _active:
		return
	var clamped_delta: float = clampf(delta, 0.001, 0.1)
	var weight: float = 1.0 - exp(-smooth_speed * clamped_delta)
	_current_focus = _current_focus.lerp(focus_point, weight)
	_current_yaw_rad = lerp_angle(_current_yaw_rad, deg_to_rad(yaw_deg), weight)
	_current_pitch_rad = lerpf(_current_pitch_rad, deg_to_rad(pitch_deg), weight)
	_current_distance = lerpf(_current_distance, distance, weight)
	_apply_camera_transform()


func orbit(relative_px: Vector2) -> void:
	yaw_deg = wrapf(yaw_deg - relative_px.x * orbit_sensitivity, -180.0, 180.0)
	pitch_deg = clampf(pitch_deg - relative_px.y * orbit_sensitivity, min_pitch_deg, max_pitch_deg)


func pan(relative_px: Vector2) -> void:
	var scale_factor: float = pan_sensitivity * maxf(1.0, distance * 0.08)
	var yaw_basis: Basis = Basis(Vector3.UP, _current_yaw_rad)
	var right_vec: Vector3 = yaw_basis.x
	var up_vec: Vector3 = Vector3.UP
	focus_point += (-right_vec * relative_px.x + up_vec * relative_px.y) * scale_factor
	focus_point.x = clampf(focus_point.x, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	focus_point.z = clampf(focus_point.z, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	focus_point.y = clampf(focus_point.y, ArenaValidator.WORLD_Y_MIN, ArenaValidator.WORLD_Y_MAX)


func zoom(step_direction: float) -> void:
	distance = clampf(distance + step_direction * zoom_step_distance, min_distance, max_distance)


func focus_on(target_pos: Vector3, target_dist: float = -1.0) -> void:
	if is_finite(target_pos.x) and is_finite(target_pos.y) and is_finite(target_pos.z):
		focus_point = target_pos
	if target_dist > 0.0 and is_finite(target_dist):
		distance = clampf(target_dist, min_distance, max_distance)
	snap_to_target()


func snap_to_target() -> void:
	_ensure_camera_node()
	pitch_deg = clampf(pitch_deg, min_pitch_deg, max_pitch_deg)
	distance = clampf(distance, min_distance, max_distance)
	_current_focus = focus_point
	_current_yaw_rad = deg_to_rad(yaw_deg)
	_current_pitch_rad = deg_to_rad(pitch_deg)
	_current_distance = distance
	_apply_camera_transform()


func _apply_camera_transform() -> void:
	if _camera == null:
		return
	var rot_basis: Basis = Basis.from_euler(Vector3(_current_pitch_rad, _current_yaw_rad, 0.0))
	var cam_pos: Vector3 = _current_focus + (rot_basis.z * _current_distance)
	_camera.global_transform = Transform3D(rot_basis, cam_pos)
