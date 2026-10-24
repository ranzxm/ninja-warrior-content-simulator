class_name ObstacleSwingingPendulum
extends ObstacleBase

## OBS-05: Periodic swinging pendulum hazard above a crossing walkway.

const ALLOWED_KEYS: Array[String] = [
	"swing_amplitude_deg",
	"swing_period",
	"pendulum_length",
	"initial_phase_deg",
	"knockback_speed",
]

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
	super._init()
	obstacle_type = "swinging_pendulum"
	display_name = "Swinging Pendulum"


func _physics_process(delta: float) -> void:
	if not is_simulation_running() or _pendulum_pivot == null or swing_period <= 0.01:
		return

	_elapsed_time += delta
	_update_pendulum_angle()

	if _bob_hit_area != null and _bob_hit_area.monitoring:
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


func get_rod_height() -> float:
	if _rod_mesh == null:
		_rod_mesh = get_node_or_null("PendulumPivot/RodMesh") as MeshInstance3D
	if _rod_mesh != null and _rod_mesh.mesh is CylinderMesh:
		return (_rod_mesh.mesh as CylinderMesh).height
	return 0.0


func get_bob_local_y() -> float:
	if _bob_col == null:
		_bob_col = get_node_or_null("PendulumPivot/BobCollision") as CollisionShape3D
	return _bob_col.position.y if _bob_col != null else 0.0


func _rebuild_obstacle() -> void:
	_cache_common_nodes()
	_localize_geometry_resources()
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
			var cm: CylinderMesh = _rod_mesh.mesh as CylinderMesh
			cm.height = pendulum_length
	if _bob_mesh != null:
		_bob_mesh.position = Vector3(0.0, -pendulum_length, 0.0)
	if _bob_col != null:
		_bob_col.position = Vector3(0.0, -pendulum_length, 0.0)
	if _bob_hit_area != null:
		_bob_hit_area.position = Vector3(0.0, -pendulum_length, 0.0)

	if entry_anchor != null:
		entry_anchor.position = Vector3.ZERO
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -7.0)
	if _entry_trigger != null:
		_entry_trigger.position = Vector3(0.0, 1.2, -0.6)
	if _exit_trigger != null:
		_exit_trigger.position = Vector3(0.0, 1.2, -7.4)


func _on_reset_obstacle() -> void:
	if _pendulum_pivot == null:
		_pendulum_pivot = get_node_or_null("PendulumPivot") as AnimatableBody3D
	_elapsed_time = 0.0
	_update_pendulum_angle()
	if _pendulum_pivot != null and _pendulum_pivot.is_inside_tree():
		PhysicsServer3D.body_set_state(
			_pendulum_pivot.get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM,
			_pendulum_pivot.global_transform
		)


func _update_pendulum_angle() -> void:
	if _pendulum_pivot == null:
		return
	var omega: float = TAU / maxf(0.1, swing_period)
	var phase: float = (_elapsed_time * omega) + deg_to_rad(initial_phase_deg)
	_current_angle_rad = deg_to_rad(swing_amplitude_deg) * sin(phase)
	_pendulum_pivot.rotation = Vector3(0.0, 0.0, _current_angle_rad)


func _validate_parameters() -> bool:
	return _is_valid_config(swing_amplitude_deg, swing_period, pendulum_length, initial_phase_deg, knockback_speed)


static func _is_valid_config(
	amp_deg: float,
	period: float,
	length: float,
	phase_deg: float,
	knockback: float
) -> bool:
	if not is_finite(amp_deg) or not is_finite(period) or not is_finite(length):
		return false
	if not is_finite(phase_deg) or not is_finite(knockback):
		return false
	if amp_deg <= 0.0 or amp_deg > 89.0:
		return false
	if period < 0.4 or period > 15.0:
		return false
	if length < 1.0 or length > 12.0:
		return false
	if phase_deg < -360.0 or phase_deg > 360.0:
		return false
	if knockback < 0.5 or knockback > 30.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"swing_amplitude_deg": swing_amplitude_deg,
		"swing_period": swing_period,
		"pendulum_length": pendulum_length,
		"initial_phase_deg": initial_phase_deg,
		"knockback_speed": knockback_speed,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	if not _has_only_known_keys(params, ALLOWED_KEYS):
		return false

	var parsed: Dictionary = {}
	if not _read_strict_float(params, "swing_amplitude_deg", swing_amplitude_deg, parsed):
		return false
	if not _read_strict_float(params, "swing_period", swing_period, parsed):
		return false
	if not _read_strict_float(params, "pendulum_length", pendulum_length, parsed):
		return false
	if not _read_strict_float(params, "initial_phase_deg", initial_phase_deg, parsed):
		return false
	if not _read_strict_float(params, "knockback_speed", knockback_speed, parsed):
		return false

	var next_amp: float = float(parsed["swing_amplitude_deg"])
	var next_per: float = float(parsed["swing_period"])
	var next_len: float = float(parsed["pendulum_length"])
	var next_pha: float = float(parsed["initial_phase_deg"])
	var next_kb: float = float(parsed["knockback_speed"])

	if not _is_valid_config(next_amp, next_per, next_len, next_pha, next_kb):
		return false

	swing_amplitude_deg = next_amp
	swing_period = next_per
	pendulum_length = next_len
	initial_phase_deg = next_pha
	knockback_speed = next_kb
	return true
