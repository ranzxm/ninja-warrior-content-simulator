class_name PlayerController
extends CharacterBody3D

## 3D Character controller for manual play (M0) and future AI intent (M2a).
## ponytail: direct state enum instead of node-based state machine; upgrade only if M4 custom rigs diverge.

signal state_changed(new_state: LocomotionState, state_name: String)
signal jumped()
signal landed(impact_speed: float)

enum LocomotionState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	LANDING,
}

const STATE_NAMES: Dictionary = {
	LocomotionState.IDLE: "IDLE",
	LocomotionState.WALKING: "WALKING",
	LocomotionState.RUNNING: "RUNNING",
	LocomotionState.JUMPING: "JUMPING",
	LocomotionState.FALLING: "FALLING",
	LocomotionState.LANDING: "LANDING",
}

@export_range(1.0, 15.0, 0.1) var walk_speed: float = 5.0
@export_range(2.0, 25.0, 0.1) var sprint_speed: float = 8.5
@export_range(5.0, 60.0, 0.5) var ground_acceleration: float = 28.0
@export_range(5.0, 60.0, 0.5) var ground_deceleration: float = 34.0
@export_range(1.0, 40.0, 0.5) var air_acceleration: float = 12.0
@export_range(2.0, 20.0, 0.1) var jump_velocity: float = 7.2
@export_range(0.5, 4.0, 0.1) var gravity_multiplier: float = 1.6
@export_range(5.0, 60.0, 1.0) var max_fall_speed: float = 35.0
@export_range(2.0, 30.0, 0.5) var rotation_speed: float = 12.0
@export_range(0.05, 0.5, 0.01) var landing_duration: float = 0.12
@export var camera_rig_path: NodePath = NodePath("CameraRig")

var current_state: LocomotionState = LocomotionState.IDLE
var controls_enabled: bool = true

var _base_gravity: float = 9.8
var _was_on_floor: bool = false
var _landing_timer: float = 0.0
var _last_vertical_velocity: float = 0.0
var _use_override_input: bool = false
var _override_move_input: Vector2 = Vector2.ZERO
var _override_sprint: bool = false
var _override_jump: bool = false

@onready var _visual_root: Node3D = get_node_or_null("VisualRoot") as Node3D
@onready var _camera_rig: ThirdPersonCamera = get_node_or_null(camera_rig_path) as ThirdPersonCamera


func _ready() -> void:
	_base_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_max_angle = deg_to_rad(50.0)
	_was_on_floor = is_on_floor()
	if _camera_rig != null:
		_camera_rig.set_follow_target(self)


func _physics_process(delta: float) -> void:
	var safe_delta: float = clampf(delta, 0.0001, 0.1)
	var on_floor: bool = is_on_floor()

	if on_floor and not _was_on_floor:
		_landing_timer = landing_duration
		landed.emit(absf(_last_vertical_velocity))
		_set_state(LocomotionState.LANDING)

	if _landing_timer > 0.0:
		_landing_timer = maxf(0.0, _landing_timer - safe_delta)

	var move_input: Vector2 = _read_move_input()
	var wants_sprint: bool = _read_sprint_input()
	var wants_jump: bool = _read_jump_input()

	var move_direction: Vector3 = compute_camera_relative_direction(move_input)
	var target_speed: float = sprint_speed if wants_sprint else walk_speed
	var desired_horizontal: Vector3 = move_direction * target_speed

	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var accel: float = air_acceleration
	if on_floor:
		accel = ground_acceleration if move_direction.length_squared() > 0.001 else ground_deceleration

	current_horizontal = current_horizontal.move_toward(desired_horizontal, accel * safe_delta)
	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.z

	if on_floor:
		if wants_jump:
			velocity.y = jump_velocity
			_landing_timer = 0.0
			on_floor = false
			jumped.emit()
		elif velocity.y < 0.0:
			velocity.y = -0.1
	else:
		var gravity_step: float = _base_gravity * gravity_multiplier * safe_delta
		velocity.y = maxf(velocity.y - gravity_step, -max_fall_speed)

	_last_vertical_velocity = velocity.y
	_was_on_floor = on_floor

	_rotate_visual_toward(move_direction, safe_delta)
	move_and_slide()
	_evaluate_locomotion_state(move_direction, wants_sprint)


func compute_camera_relative_direction(input_vec: Vector2) -> Vector3:
	if input_vec.length_squared() <= 0.0001:
		return Vector3.ZERO
	var clamped_input: Vector2 = input_vec.limit_length(1.0)
	var reference_yaw: float = _get_reference_yaw()
	var basis_yaw: Basis = Basis(Vector3.UP, reference_yaw)
	var direction: Vector3 = (basis_yaw.x * clamped_input.x) + (basis_yaw.z * clamped_input.y)
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		return direction.normalized()
	return Vector3.ZERO


func reset_to_transform(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	_last_vertical_velocity = 0.0
	_landing_timer = 0.0
	_was_on_floor = true
	clear_override_input()

	if _visual_root != null:
		var forward: Vector3 = -spawn_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.0001:
			_visual_root.global_rotation = Vector3(0.0, atan2(-forward.x, -forward.z), 0.0)
		else:
			_visual_root.rotation = Vector3.ZERO

	if _camera_rig != null:
		_camera_rig.reset_behind_target(spawn_transform)

	_set_state(LocomotionState.IDLE)


func set_camera_rig(rig: ThirdPersonCamera) -> void:
	_camera_rig = rig
	if _camera_rig != null:
		_camera_rig.set_follow_target(self)


func get_camera_rig() -> ThirdPersonCamera:
	return _camera_rig


func get_state_name() -> String:
	return String(STATE_NAMES.get(current_state, "IDLE"))


func set_override_input(move_vec: Vector2, sprinting: bool, jump_pressed: bool) -> void:
	_use_override_input = true
	_override_move_input = move_vec
	_override_sprint = sprinting
	_override_jump = jump_pressed


func clear_override_input() -> void:
	_use_override_input = false
	_override_move_input = Vector2.ZERO
	_override_sprint = false
	_override_jump = false


func _read_move_input() -> Vector2:
	if not controls_enabled:
		return Vector2.ZERO
	if _use_override_input:
		return _override_move_input
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")


func _read_sprint_input() -> bool:
	if not controls_enabled:
		return false
	if _use_override_input:
		return _override_sprint
	return Input.is_action_pressed("sprint")


func _read_jump_input() -> bool:
	if not controls_enabled:
		return false
	if _use_override_input:
		var jump_now: bool = _override_jump
		_override_jump = false
		return jump_now
	return Input.is_action_just_pressed("jump")


func _get_reference_yaw() -> float:
	if _camera_rig != null:
		return _camera_rig.get_yaw()
	return global_rotation.y


func _rotate_visual_toward(move_direction: Vector3, delta: float) -> void:
	if _visual_root == null or move_direction.length_squared() <= 0.0001:
		return
	var target_yaw: float = atan2(-move_direction.x, -move_direction.z)
	var weight: float = 1.0 - exp(-rotation_speed * delta)
	_visual_root.global_rotation.y = lerp_angle(_visual_root.global_rotation.y, target_yaw, weight)


func _evaluate_locomotion_state(move_direction: Vector3, sprinting: bool) -> void:
	if not is_on_floor():
		if velocity.y > 0.1:
			_set_state(LocomotionState.JUMPING)
		else:
			_set_state(LocomotionState.FALLING)
		return

	if _landing_timer > 0.0:
		_set_state(LocomotionState.LANDING)
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if move_direction.length_squared() <= 0.01 and horizontal_speed < 0.25:
		_set_state(LocomotionState.IDLE)
	elif sprinting and horizontal_speed > (walk_speed + 0.25):
		_set_state(LocomotionState.RUNNING)
	else:
		_set_state(LocomotionState.WALKING)


func _set_state(next_state: LocomotionState) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	state_changed.emit(current_state, get_state_name())
