class_name ObstacleRotatingSweeper
extends ObstacleBase

## OBS-04: Rotating horizontal sweeper arm on a walkable platform deck.

const ALLOWED_KEYS: Array[String] = [
	"rotation_speed",
	"rotation_direction",
	"arm_length",
	"arm_height",
	"initial_angle_deg",
	"push_strength",
]

@export_range(0.2, 8.0, 0.1) var rotation_speed: float = 1.6
@export_range(-1, 1, 2) var rotation_direction: int = 1
@export_range(1.2, 10.0, 0.2) var arm_length: float = 4.0
@export_range(0.25, 2.0, 0.05) var arm_height: float = 0.52
@export_range(0.0, 360.0, 5.0) var initial_angle_deg: float = 0.0
@export_range(2.0, 18.0, 0.5) var push_strength: float = 8.5

var _current_angle_rad: float = 0.0

@onready var _sweeper_pivot: AnimatableBody3D = get_node_or_null("SweeperPivot") as AnimatableBody3D
@onready var _arm_mesh_inst: MeshInstance3D = get_node_or_null("SweeperPivot/ArmMesh") as MeshInstance3D
@onready var _arm_col_shape: CollisionShape3D = get_node_or_null("SweeperPivot/ArmCollision") as CollisionShape3D
@onready var _push_area: Area3D = get_node_or_null("SweeperPivot/ArmPushArea") as Area3D
@onready var _push_col_shape: CollisionShape3D = get_node_or_null("SweeperPivot/ArmPushArea/CollisionShape3D") as CollisionShape3D


func _init() -> void:
	obstacle_id = "obs_04_rotating_sweeper"
	obstacle_type = "rotating_sweeper"
	display_name = "Rotating Sweeper"


func _physics_process(delta: float) -> void:
	if not is_simulation_running() or _sweeper_pivot == null:
		return

	var dir_sign: float = 1.0 if rotation_direction >= 0 else -1.0
	_current_angle_rad = wrapf(_current_angle_rad + rotation_speed * dir_sign * delta, -PI, PI)
	_sweeper_pivot.rotation = Vector3(0.0, _current_angle_rad, 0.0)

	if _push_area != null and _push_area.monitoring:
		for body: Node3D in _push_area.get_overlapping_bodies():
			if body is PlayerController:
				_apply_sweeper_push(body as PlayerController, dir_sign)


func get_current_angle_rad() -> float:
	return _current_angle_rad


func get_arm_mesh_size() -> Vector3:
	if _arm_mesh_inst == null:
		_arm_mesh_inst = get_node_or_null("SweeperPivot/ArmMesh") as MeshInstance3D
	if _arm_mesh_inst != null and _arm_mesh_inst.mesh is BoxMesh:
		return (_arm_mesh_inst.mesh as BoxMesh).size
	return Vector3.ZERO


func get_arm_collision_size() -> Vector3:
	if _arm_col_shape == null:
		_arm_col_shape = get_node_or_null("SweeperPivot/ArmCollision") as CollisionShape3D
	if _arm_col_shape != null and _arm_col_shape.shape is BoxShape3D:
		return (_arm_col_shape.shape as BoxShape3D).size
	return Vector3.ZERO


func _apply_sweeper_push(player: PlayerController, dir_sign: float) -> void:
	if not is_enabled or _sweeper_pivot == null:
		return
	if absf(player.global_position.y - _sweeper_pivot.global_position.y) > 2.0:
		return
	var offset: Vector3 = player.global_position - _sweeper_pivot.global_position
	offset.y = 0.0
	if offset.length() > (arm_length * 0.55 + 0.6):
		return
	var tangent: Vector3 = Vector3(-offset.z, 0.0, offset.x) * dir_sign
	if tangent.length_squared() < 0.001:
		tangent = _sweeper_pivot.global_transform.basis.z * dir_sign
	else:
		tangent = tangent.normalized()
	player.velocity.x = tangent.x * push_strength
	player.velocity.z = tangent.z * push_strength


func _rebuild_obstacle() -> void:
	_cache_common_nodes()
	if _sweeper_pivot == null:
		_sweeper_pivot = get_node_or_null("SweeperPivot") as AnimatableBody3D
	if _arm_mesh_inst == null:
		_arm_mesh_inst = get_node_or_null("SweeperPivot/ArmMesh") as MeshInstance3D
	if _arm_col_shape == null:
		_arm_col_shape = get_node_or_null("SweeperPivot/ArmCollision") as CollisionShape3D
	if _push_area == null:
		_push_area = get_node_or_null("SweeperPivot/ArmPushArea") as Area3D
	if _push_col_shape == null:
		_push_col_shape = get_node_or_null("SweeperPivot/ArmPushArea/CollisionShape3D") as CollisionShape3D

	var arm_dims: Vector3 = Vector3(arm_length, 0.28, 0.28)
	if _arm_mesh_inst != null:
		_arm_mesh_inst.position = Vector3(0.0, arm_height, 0.0)
		if _arm_mesh_inst.mesh is BoxMesh:
			var bm: BoxMesh = (_arm_mesh_inst.mesh as BoxMesh).duplicate() as BoxMesh
			bm.size = arm_dims
			_arm_mesh_inst.mesh = bm
	if _arm_col_shape != null:
		_arm_col_shape.position = Vector3(0.0, arm_height, 0.0)
		if _arm_col_shape.shape is BoxShape3D:
			var bs: BoxShape3D = (_arm_col_shape.shape as BoxShape3D).duplicate() as BoxShape3D
			bs.size = arm_dims
			_arm_col_shape.shape = bs
	if _push_area != null:
		_push_area.position = Vector3(0.0, arm_height, 0.0)
	if _push_col_shape != null and _push_col_shape.shape is BoxShape3D:
		var ps: BoxShape3D = (_push_col_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		ps.size = Vector3(arm_length, 0.34, 0.42)
		_push_col_shape.shape = ps

	if entry_anchor != null:
		entry_anchor.position = Vector3.ZERO
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -7.0)
	if _entry_trigger != null:
		_entry_trigger.position = Vector3(0.0, 1.2, -0.6)
	if _exit_trigger != null:
		_exit_trigger.position = Vector3(0.0, 1.2, -7.4)


func _on_reset_obstacle() -> void:
	if _sweeper_pivot == null:
		_sweeper_pivot = get_node_or_null("SweeperPivot") as AnimatableBody3D
	_current_angle_rad = deg_to_rad(initial_angle_deg)
	if _sweeper_pivot != null:
		_sweeper_pivot.rotation = Vector3(0.0, _current_angle_rad, 0.0)
		if _sweeper_pivot.is_inside_tree():
			PhysicsServer3D.body_set_state(
				_sweeper_pivot.get_rid(),
				PhysicsServer3D.BODY_STATE_TRANSFORM,
				_sweeper_pivot.global_transform
			)


func _validate_parameters() -> bool:
	return _is_valid_config(rotation_speed, rotation_direction, arm_length, arm_height, initial_angle_deg, push_strength)


static func _is_valid_config(
	rot_speed: float,
	rot_dir: int,
	length: float,
	height: float,
	init_angle: float,
	push: float
) -> bool:
	if not is_finite(rot_speed) or not is_finite(length) or not is_finite(height):
		return false
	if not is_finite(init_angle) or not is_finite(push):
		return false
	if rot_speed <= 0.0 or rot_speed > 10.0:
		return false
	if not (rot_dir in [-1, 1]):
		return false
	if length < 1.0 or length > 12.0:
		return false
	if height < 0.15 or height > 3.0:
		return false
	if init_angle < -360.0 or init_angle > 360.0:
		return false
	if push < 0.5 or push > 25.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"rotation_speed": rotation_speed,
		"rotation_direction": rotation_direction,
		"arm_length": arm_length,
		"arm_height": arm_height,
		"initial_angle_deg": initial_angle_deg,
		"push_strength": push_strength,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	if not _has_only_known_keys(params, ALLOWED_KEYS):
		return false

	var parsed: Dictionary = {}
	if not _read_strict_float(params, "rotation_speed", rotation_speed, parsed):
		return false
	if not _read_strict_int(params, "rotation_direction", rotation_direction, parsed):
		return false
	if not _read_strict_float(params, "arm_length", arm_length, parsed):
		return false
	if not _read_strict_float(params, "arm_height", arm_height, parsed):
		return false
	if not _read_strict_float(params, "initial_angle_deg", initial_angle_deg, parsed):
		return false
	if not _read_strict_float(params, "push_strength", push_strength, parsed):
		return false

	var next_speed: float = float(parsed["rotation_speed"])
	var next_dir: int = int(parsed["rotation_direction"])
	var next_len: float = float(parsed["arm_length"])
	var next_hgt: float = float(parsed["arm_height"])
	var next_ang: float = float(parsed["initial_angle_deg"])
	var next_push: float = float(parsed["push_strength"])

	if not _is_valid_config(next_speed, next_dir, next_len, next_hgt, next_ang, next_push):
		return false

	rotation_speed = next_speed
	rotation_direction = next_dir
	arm_length = next_len
	arm_height = next_hgt
	initial_angle_deg = next_ang
	push_strength = next_push
	return true
