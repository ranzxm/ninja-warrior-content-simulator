class_name ObstacleMovingPlatform
extends ObstacleBase

## OBS-03: AnimatableBody3D moving platform updated on fixed physics ticks.

@export_range(1.0, 20.0, 0.25) var movement_distance: float = 4.6
@export_range(0.25, 12.0, 0.25) var movement_speed: float = 2.4
@export_enum("PING_PONG", "LOOP", "ONE_WAY") var travel_mode: String = "PING_PONG"
@export_range(-1, 1, 2) var initial_direction: int = 1
@export var platform_size: Vector3 = Vector3(2.8, 0.4, 2.8)

var _progress: float = 0.0
var _direction: int = 1

@onready var _platform_body: AnimatableBody3D = get_node_or_null("PlatformBody") as AnimatableBody3D
@onready var _mesh_inst: MeshInstance3D = get_node_or_null("PlatformBody/MeshInstance3D") as MeshInstance3D
@onready var _col_shape: CollisionShape3D = get_node_or_null("PlatformBody/CollisionShape3D") as CollisionShape3D


func _init() -> void:
	obstacle_id = "obs_03_moving_platform"
	obstacle_type = "moving_platform"
	display_name = "Moving Platform"


func _physics_process(delta: float) -> void:
	if not is_enabled or _platform_body == null or movement_distance <= 0.001:
		return

	var step: float = (movement_speed * delta) / movement_distance
	_progress += step * float(_direction)

	match travel_mode:
		"PING_PONG":
			if _progress >= 1.0:
				_progress = 1.0
				_direction = -1
			elif _progress <= 0.0:
				_progress = 0.0
				_direction = 1
		"LOOP":
			if _progress > 1.0:
				_progress = fposmod(_progress, 1.0)
			elif _progress < 0.0:
				_progress = 1.0 - fposmod(-_progress, 1.0)
		"ONE_WAY":
			_progress = clampf(_progress, 0.0, 1.0)

	_apply_platform_transform()


func get_progress() -> float:
	return _progress


func get_platform_body() -> AnimatableBody3D:
	return _platform_body


func _rebuild_obstacle() -> void:
	if _platform_body == null:
		_platform_body = get_node_or_null("PlatformBody") as AnimatableBody3D
	if _mesh_inst == null:
		_mesh_inst = get_node_or_null("PlatformBody/MeshInstance3D") as MeshInstance3D
	if _col_shape == null:
		_col_shape = get_node_or_null("PlatformBody/CollisionShape3D") as CollisionShape3D

	if _mesh_inst != null and _mesh_inst.mesh is BoxMesh:
		var box_mesh: BoxMesh = (_mesh_inst.mesh as BoxMesh).duplicate() as BoxMesh
		box_mesh.size = platform_size
		_mesh_inst.mesh = box_mesh
	if _col_shape != null and _col_shape.shape is BoxShape3D:
		var box_shape: BoxShape3D = (_col_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box_shape.size = platform_size
		_col_shape.shape = box_shape

	if exit_anchor != null:
		var total_span: float = platform_size.z + movement_distance + 0.6
		exit_anchor.position = Vector3(0.0, 0.0, -total_span)


func _on_reset_obstacle() -> void:
	if _platform_body == null:
		_platform_body = get_node_or_null("PlatformBody") as AnimatableBody3D
	_direction = 1 if initial_direction >= 0 else -1
	_progress = 0.0 if _direction > 0 else 1.0
	_apply_platform_transform()


func _apply_platform_transform() -> void:
	if _platform_body == null:
		return
	var start_z: float = -(0.3 + platform_size.z * 0.5)
	var end_z: float = start_z - movement_distance
	var current_z: float = lerpf(start_z, end_z, _progress)
	_platform_body.position = Vector3(0.0, -platform_size.y * 0.5, current_z)


func _validate_parameters() -> bool:
	if not is_finite(movement_distance) or not is_finite(movement_speed):
		return false
	if movement_distance < 0.5 or movement_distance > 25.0:
		return false
	if movement_speed < 0.1 or movement_speed > 15.0:
		return false
	if not (travel_mode in ["PING_PONG", "LOOP", "ONE_WAY"]):
		return false
	if not (initial_direction in [-1, 1]):
		return false
	if platform_size.x < 0.8 or platform_size.y < 0.15 or platform_size.z < 0.8:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"movement_distance": movement_distance,
		"movement_speed": movement_speed,
		"travel_mode": travel_mode,
		"initial_direction": initial_direction,
		"platform_size": [platform_size.x, platform_size.y, platform_size.z],
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	var next_dist: float = float(params.get("movement_distance", movement_distance))
	var next_speed: float = float(params.get("movement_speed", movement_speed))
	var next_mode: String = String(params.get("travel_mode", travel_mode))
	var next_dir: int = int(params.get("initial_direction", initial_direction))

	var prev_dist: float = movement_distance
	var prev_speed: float = movement_speed
	var prev_mode: String = travel_mode
	var prev_dir: int = initial_direction

	movement_distance = next_dist
	movement_speed = next_speed
	travel_mode = next_mode
	initial_direction = next_dir

	if not _validate_parameters():
		movement_distance = prev_dist
		movement_speed = prev_speed
		travel_mode = prev_mode
		initial_direction = prev_dir
		return false
	return true
