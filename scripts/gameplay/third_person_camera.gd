class_name ThirdPersonCamera
extends Node3D

## Reusable third-person orbital camera rig decoupled from PlayerController.
## ponytail: single orbital mode for M0; add preset shots (side/wide/finish) in M2b.

@export var follow_target_path: NodePath
@export var target_offset: Vector3 = Vector3(0.0, 1.4, 0.0)
@export_range(1.0, 40.0, 0.5) var follow_speed: float = 15.0
@export_range(1.0, 40.0, 0.5) var rotation_smoothness: float = 20.0
@export_range(0.0005, 0.02, 0.0001) var mouse_sensitivity: float = 0.0025
@export_range(-85.0, 0.0, 1.0) var min_pitch_deg: float = -65.0
@export_range(0.0, 85.0, 1.0) var max_pitch_deg: float = 35.0
@export_range(1.5, 15.0, 0.1) var spring_length: float = 4.5
@export_flags_3d_physics var collision_mask: int = 5 # WORLD (1) | OBSTACLE (4)

var _follow_target: Node3D = null
var _target_yaw: float = 0.0
var _target_pitch: float = deg_to_rad(-15.0)
var _current_yaw: float = 0.0
var _current_pitch: float = deg_to_rad(-15.0)

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var _camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	set_as_top_level(true)
	if not follow_target_path.is_empty():
		var resolved: Node = get_node_or_null(follow_target_path)
		if resolved is Node3D:
			set_follow_target(resolved as Node3D)
	elif get_parent() is Node3D:
		set_follow_target(get_parent() as Node3D)

	if _spring_arm != null:
		_spring_arm.spring_length = spring_length
		_spring_arm.collision_mask = collision_mask

	_apply_pivots()


func _unhandled_input(event: InputEvent) -> void:
	if not is_mouse_captured():
		return
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		apply_look_delta(motion.relative)


func _physics_process(delta: float) -> void:
	var clamped_delta: float = minf(delta, 0.1)
	if is_instance_valid(_follow_target):
		var desired_position: Vector3 = _follow_target.global_position + target_offset
		var pos_weight: float = 1.0 - exp(-follow_speed * clamped_delta)
		global_position = global_position.lerp(desired_position, pos_weight)

	var rot_weight: float = 1.0 - exp(-rotation_smoothness * clamped_delta)
	_current_yaw = lerp_angle(_current_yaw, _target_yaw, rot_weight)
	_current_pitch = lerpf(_current_pitch, _target_pitch, rot_weight)
	_apply_pivots()


func apply_look_delta(relative_motion: Vector2) -> void:
	var sens: float = clampf(mouse_sensitivity, 0.0005, 0.02)
	_target_yaw = wrapf(_target_yaw - relative_motion.x * sens, -PI, PI)
	var min_rad: float = deg_to_rad(minf(min_pitch_deg, max_pitch_deg))
	var max_rad: float = deg_to_rad(maxf(min_pitch_deg, max_pitch_deg))
	_target_pitch = clampf(_target_pitch - relative_motion.y * sens, min_rad, max_rad)


func set_follow_target(target: Node3D) -> void:
	_follow_target = target
	if is_instance_valid(_follow_target):
		global_position = _follow_target.global_position + target_offset


func get_follow_target() -> Node3D:
	return _follow_target


func get_yaw() -> float:
	return _current_yaw


func get_pitch() -> float:
	return _current_pitch


func get_camera() -> Camera3D:
	return _camera


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.02)


func reset_behind_target(target_transform: Transform3D) -> void:
	var forward: Vector3 = -target_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
		_target_yaw = atan2(-forward.x, -forward.z)
	else:
		_target_yaw = 0.0
	_target_pitch = deg_to_rad(-15.0)
	_current_yaw = _target_yaw
	_current_pitch = _target_pitch
	global_position = target_transform.origin + target_offset
	_apply_pivots()


func capture_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func release_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func is_mouse_captured() -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED


func _apply_pivots() -> void:
	if _yaw_pivot != null:
		_yaw_pivot.rotation.y = _current_yaw
	if _pitch_pivot != null:
		_pitch_pivot.rotation.x = _current_pitch
