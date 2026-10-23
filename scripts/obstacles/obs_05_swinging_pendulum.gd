class_name ObstacleSwingingPendulum
extends ObstacleBase

## OBS-05: Periodic swinging pendulum hazard above a crossing walkway.

@export_range(5.0, 85.0, 1.0) var swing_amplitude_deg: float = 45.0
@export_range(0.5, 12.0, 0.1) var swing_period: float = 2.4
@export_range(1.5, 10.0, 0.2) var pendulum_length: float = 3.2
@export_range(0.0, 360.0, 5.0) var initial_phase_deg: float = 0.0
@export_range(2.0, 20.0, 0.5) var knockback_speed: float = 9.0

var _elapsed_time: float = 0.0
var _current_angle_rad: float = 0.0

@onready var _pendulum_pivot: AnimatableBody3D = get_node_or_null("PendulumPivot") as AnimatableBody3D
@onready var _rod_mesh: MeshInstance3D = get_node_or_null("PendulumPivot/RodMesh") as MeshInstance3D
@onready var _bob_mesh: MeshInstance3D = get_node_or_null("PendulumPivot/BobMesh") as MeshInstance3D
@onready var _bob_col: CollisionShape3D = get_node_or_null("PendulumPivot/BobCollision") as CollisionShape3D
@onready var _bob_hit_area: Area3D = get_node_or_null("PendulumPivot/BobHitArea") as Area3D


func _init() -> void:
	obstacle_id = "obs_05_swinging_pendulum"
	obstacle_type = "swinging_pendulum"
	display_name = "Swinging Pendulum"


func _physics_process(delta: float) -> void:
	if not is_enabled or _pendulum_pivot == null or swing_period <= 0.01:
		return

	_elapsed_time += delta
	_update_pendulum_angle()

	if _bob_hit_area != null:
		var omega: float = TAU / swing_period
		var phase: float = (_elapsed_time * omega) + deg_to_rad(initial_phase_deg)
		var swing_dir: float = signf(cos(phase))
		if is_zero_approx(swing_dir):
			swing_dir = 1.0
		for body: Node3D in _bob_hit_area.get_overlapping_bodies():
			if body is PlayerController:
				var player: PlayerController = body as PlayerController
				if player.global_position.distance_to(_bob_hit_area.global_position) <= 1.25:
					player.velocity.x = swing_dir * knockback_speed
					player.velocity.y = maxf(player.velocity.y, 2.0)


func get_current_angle_rad() -> float:
	return _current_angle_rad


func get_elapsed_time() -> float:
	return _elapsed_time


func _rebuild_obstacle() -> void:
	if _pendulum_pivot == null:
		_pendulum_pivot = get_node_or_null("PendulumPivot") as AnimatableBody3D
	if _rod_mesh == null:
		_rod_mesh = get_node_or_null("PendulumPivot/RodMesh") as MeshInstance3D
	if _bob_mesh == null:
		_bob_mesh = get_node_or_null("PendulumPivot/BobMesh") as MeshInstance3D
	if _bob_col == null:
		_bob_col = get_node_or_null("PendulumPivot/BobCollision") as CollisionShape3D
	if _bob_hit_area == null:
		_bob_hit_area = get_node_or_null("PendulumPivot/BobHitArea") as Area3D

	if _pendulum_pivot != null:
		_pendulum_pivot.position = Vector3(0.0, pendulum_length + 0.9, -3.5)
	if _rod_mesh != null:
		_rod_mesh.position = Vector3(0.0, -pendulum_length * 0.5, 0.0)
		if _rod_mesh.mesh is CylinderMesh:
			var cm: CylinderMesh = (_rod_mesh.mesh as CylinderMesh).duplicate() as CylinderMesh
			cm.height = pendulum_length
			_rod_mesh.mesh = cm
	if _bob_mesh != null:
		_bob_mesh.position = Vector3(0.0, -pendulum_length, 0.0)
	if _bob_col != null:
		_bob_col.position = Vector3(0.0, -pendulum_length, 0.0)
	if _bob_hit_area != null:
		_bob_hit_area.position = Vector3(0.0, -pendulum_length, 0.0)


func _on_reset_obstacle() -> void:
	if _pendulum_pivot == null:
		_pendulum_pivot = get_node_or_null("PendulumPivot") as AnimatableBody3D
	_elapsed_time = 0.0
	_update_pendulum_angle()


func _update_pendulum_angle() -> void:
	if _pendulum_pivot == null:
		return
	var omega: float = TAU / maxf(0.1, swing_period)
	var phase: float = (_elapsed_time * omega) + deg_to_rad(initial_phase_deg)
	_current_angle_rad = deg_to_rad(swing_amplitude_deg) * sin(phase)
	_pendulum_pivot.rotation = Vector3(0.0, 0.0, _current_angle_rad)


func _validate_parameters() -> bool:
	if not is_finite(swing_amplitude_deg) or not is_finite(swing_period) or not is_finite(pendulum_length):
		return false
	if swing_amplitude_deg <= 0.0 or swing_amplitude_deg > 89.0:
		return false
	if swing_period < 0.4 or swing_period > 15.0:
		return false
	if pendulum_length < 1.0 or pendulum_length > 12.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"swing_amplitude_deg": swing_amplitude_deg,
		"swing_period": swing_period,
		"pendulum_length": pendulum_length,
		"initial_phase_deg": initial_phase_deg,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	var next_amp: float = float(params.get("swing_amplitude_deg", swing_amplitude_deg))
	var next_per: float = float(params.get("swing_period", swing_period))
	var next_len: float = float(params.get("pendulum_length", pendulum_length))
	var next_pha: float = float(params.get("initial_phase_deg", initial_phase_deg))

	var prev_amp: float = swing_amplitude_deg
	var prev_per: float = swing_period
	var prev_len: float = pendulum_length
	var prev_pha: float = initial_phase_deg

	swing_amplitude_deg = next_amp
	swing_period = next_per
	pendulum_length = next_len
	initial_phase_deg = next_pha

	if not _validate_parameters():
		swing_amplitude_deg = prev_amp
		swing_period = prev_per
		pendulum_length = prev_len
		initial_phase_deg = prev_pha
		return false
	return true
