class_name ObstacleMovingPlatform
extends ObstacleBase

## OBS-03: AnimatableBody3D moving platform updated on fixed physics ticks when simulation is active.

const ALLOWED_KEYS: Array[String] = [
	"movement_distance",
	"movement_speed",
	"travel_mode",
	"initial_direction",
	"platform_size",
]

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
	super._init()
	obstacle_type = "moving_platform"
	display_name = "Moving Platform"


func _physics_process(delta: float) -> void:
	if not is_simulation_running() or _platform_body == null or movement_distance <= 0.001:
		return

	var step: float = (movement_speed * delta) / movement_distance
	_progress += step * float(_direction)
	var wrapped: bool = false

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
				wrapped = true
			elif _progress < 0.0:
				_progress = 1.0 - fposmod(-_progress, 1.0)
				wrapped = true
		"ONE_WAY":
			_progress = clampf(_progress, 0.0, 1.0)

	_apply_platform_transform(wrapped)


func get_progress() -> float:
	return _progress


func get_direction() -> int:
	return _direction


func get_platform_body() -> AnimatableBody3D:
	return _platform_body


func get_platform_mesh_size() -> Vector3:
	if _mesh_inst == null:
		_mesh_inst = get_node_or_null("PlatformBody/MeshInstance3D") as MeshInstance3D
	if _mesh_inst != null and _mesh_inst.mesh is BoxMesh:
		return (_mesh_inst.mesh as BoxMesh).size
	return Vector3.ZERO


func get_platform_collision_size() -> Vector3:
	if _col_shape == null:
		_col_shape = get_node_or_null("PlatformBody/CollisionShape3D") as CollisionShape3D
	if _col_shape != null and _col_shape.shape is BoxShape3D:
		return (_col_shape.shape as BoxShape3D).size
	return Vector3.ZERO


func _rebuild_obstacle() -> void:
	_cache_common_nodes()
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

	var total_span: float = platform_size.z + movement_distance + 0.6
	if entry_anchor != null:
		entry_anchor.position = Vector3.ZERO
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -total_span)
	if _entry_trigger != null:
		_entry_trigger.position = Vector3(0.0, 1.2, -0.6)
	if _exit_trigger != null:
		_exit_trigger.position = Vector3(0.0, 1.2, -total_span - 0.4)
	if _hazard_zone != null:
		_hazard_zone.position = Vector3(0.0, -2.2, -total_span * 0.5)
		var hz_col: CollisionShape3D = _hazard_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if hz_col != null and hz_col.shape is BoxShape3D:
			var hz_box: BoxShape3D = (hz_col.shape as BoxShape3D).duplicate() as BoxShape3D
			hz_box.size = Vector3(maxf(10.0, platform_size.x + 6.0), 1.5, total_span + 2.0)
			hz_col.shape = hz_box


func _on_reset_obstacle() -> void:
	if _platform_body == null:
		_platform_body = get_node_or_null("PlatformBody") as AnimatableBody3D
	_direction = 1 if initial_direction >= 0 else -1
	_progress = 0.0 if _direction > 0 else 1.0
	_apply_platform_transform(true)


func _apply_platform_transform(discontinuous_teleport: bool = false) -> void:
	if _platform_body == null:
		return
	var start_z: float = -(0.3 + platform_size.z * 0.5)
	var end_z: float = start_z - movement_distance
	var current_z: float = lerpf(start_z, end_z, _progress)
	_platform_body.position = Vector3(0.0, -platform_size.y * 0.5, current_z)
	if discontinuous_teleport and _platform_body.is_inside_tree():
		# Sync physics server state directly on reset/loop-wrap so no artificial velocity impulse is generated
		PhysicsServer3D.body_set_state(
			_platform_body.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			_platform_body.global_transform
		)


func _validate_parameters() -> bool:
	return _is_valid_config(movement_distance, movement_speed, travel_mode, initial_direction, platform_size)


static func _is_valid_config(
	dist: float,
	speed: float,
	mode: String,
	init_dir: int,
	plat_dims: Vector3
) -> bool:
	if not is_finite(dist) or not is_finite(speed):
		return false
	if not is_finite(plat_dims.x) or not is_finite(plat_dims.y) or not is_finite(plat_dims.z):
		return false
	if dist < 0.5 or dist > 25.0:
		return false
	if speed < 0.1 or speed > 15.0:
		return false
	if not (mode in ["PING_PONG", "LOOP", "ONE_WAY"]):
		return false
	if not (init_dir in [-1, 1]):
		return false
	if plat_dims.x < 0.8 or plat_dims.y < 0.15 or plat_dims.z < 0.8:
		return false
	if plat_dims.x > 10.0 or plat_dims.y > 4.0 or plat_dims.z > 10.0:
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
	if not _has_only_known_keys(params, ALLOWED_KEYS):
		return false

	var parsed: Dictionary = {}
	if not _read_strict_float(params, "movement_distance", movement_distance, parsed):
		return false
	if not _read_strict_float(params, "movement_speed", movement_speed, parsed):
		return false
	if not _read_strict_string(params, "travel_mode", travel_mode, parsed):
		return false
	if not _read_strict_int(params, "initial_direction", initial_direction, parsed):
		return false
	if not _read_strict_vec3(params, "platform_size", platform_size, parsed):
		return false

	var next_dist: float = float(parsed["movement_distance"])
	var next_speed: float = float(parsed["movement_speed"])
	var next_mode: String = String(parsed["travel_mode"])
	var next_dir: int = int(parsed["initial_direction"])
	var next_size: Vector3 = parsed["platform_size"] as Vector3

	if not _is_valid_config(next_dist, next_speed, next_mode, next_dir, next_size):
		return false

	movement_distance = next_dist
	movement_speed = next_speed
	travel_mode = next_mode
	initial_direction = next_dir
	platform_size = next_size
	return true
