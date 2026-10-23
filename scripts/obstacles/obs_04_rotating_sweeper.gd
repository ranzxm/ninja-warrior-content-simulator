class_name ObstacleRotatingSweeper
extends ObstacleBase

## OBS-04: Rotating horizontal sweeper arm on a walkable platform deck.

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
	if not is_enabled or _sweeper_pivot == null:
		return

	var dir_sign: float = 1.0 if rotation_direction >= 0 else -1.0
	_current_angle_rad = wrapf(_current_angle_rad + rotation_speed * dir_sign * delta, -PI, PI)
	_sweeper_pivot.rotation = Vector3(0.0, _current_angle_rad, 0.0)

	if _push_area != null:
		for body: Node3D in _push_area.get_overlapping_bodies():
			if body is PlayerController:
				_apply_sweeper_push(body as PlayerController, dir_sign)


func get_current_angle_rad() -> float:
	return _current_angle_rad


func _apply_sweeper_push(player: PlayerController, dir_sign: float) -> void:
	if _sweeper_pivot == null:
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


func _on_reset_obstacle() -> void:
	if _sweeper_pivot == null:
		_sweeper_pivot = get_node_or_null("SweeperPivot") as AnimatableBody3D
	_current_angle_rad = deg_to_rad(initial_angle_deg)
	if _sweeper_pivot != null:
		_sweeper_pivot.rotation = Vector3(0.0, _current_angle_rad, 0.0)


func _validate_parameters() -> bool:
	if not is_finite(rotation_speed) or not is_finite(arm_length) or not is_finite(arm_height):
		return false
	if rotation_speed <= 0.0 or rotation_speed > 10.0:
		return false
	if not (rotation_direction in [-1, 1]):
		return false
	if arm_length < 1.0 or arm_length > 12.0:
		return false
	if arm_height < 0.15 or arm_height > 3.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"rotation_speed": rotation_speed,
		"rotation_direction": rotation_direction,
		"arm_length": arm_length,
		"arm_height": arm_height,
		"initial_angle_deg": initial_angle_deg,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	var next_speed: float = float(params.get("rotation_speed", rotation_speed))
	var next_dir: int = int(params.get("rotation_direction", rotation_direction))
	var next_len: float = float(params.get("arm_length", arm_length))
	var next_hgt: float = float(params.get("arm_height", arm_height))
	var next_ang: float = float(params.get("initial_angle_deg", initial_angle_deg))

	var prev_speed: float = rotation_speed
	var prev_dir: int = rotation_direction
	var prev_len: float = arm_length
	var prev_hgt: float = arm_height
	var prev_ang: float = initial_angle_deg

	rotation_speed = next_speed
	rotation_direction = next_dir
	arm_length = next_len
	arm_height = next_hgt
	initial_angle_deg = next_ang

	if not _validate_parameters():
		rotation_speed = prev_speed
		rotation_direction = prev_dir
		arm_length = prev_len
		arm_height = prev_hgt
		initial_angle_deg = prev_ang
		return false
	return true
