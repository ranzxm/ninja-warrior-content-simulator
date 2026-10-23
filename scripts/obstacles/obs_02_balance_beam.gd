class_name ObstacleBalanceBeam
extends ObstacleBase

## OBS-02: Narrow elevated balance beam with dynamically resized BoxMesh, BoxShape3D, and triggers.

const ALLOWED_KEYS: Array[String] = [
	"beam_length",
	"beam_width",
	"beam_height",
]

@export_range(1.5, 25.0, 0.5) var beam_length: float = 7.0
@export_range(0.25, 2.5, 0.05) var beam_width: float = 0.6
@export_range(0.15, 3.0, 0.05) var beam_height: float = 0.4

@onready var _beam_body: StaticBody3D = get_node_or_null("BeamBody") as StaticBody3D
@onready var _beam_mesh_inst: MeshInstance3D = get_node_or_null("BeamBody/MeshInstance3D") as MeshInstance3D
@onready var _beam_col_shape: CollisionShape3D = get_node_or_null("BeamBody/CollisionShape3D") as CollisionShape3D


func _init() -> void:
	obstacle_id = "obs_02_balance_beam"
	obstacle_type = "balance_beam"
	display_name = "Balance Beam"


func get_beam_mesh_size() -> Vector3:
	if _beam_mesh_inst == null:
		_beam_mesh_inst = get_node_or_null("BeamBody/MeshInstance3D") as MeshInstance3D
	if _beam_mesh_inst != null and _beam_mesh_inst.mesh is BoxMesh:
		return (_beam_mesh_inst.mesh as BoxMesh).size
	return Vector3.ZERO


func get_beam_collision_size() -> Vector3:
	if _beam_col_shape == null:
		_beam_col_shape = get_node_or_null("BeamBody/CollisionShape3D") as CollisionShape3D
	if _beam_col_shape != null and _beam_col_shape.shape is BoxShape3D:
		return (_beam_col_shape.shape as BoxShape3D).size
	return Vector3.ZERO


func _rebuild_obstacle() -> void:
	_cache_common_nodes()
	if _beam_body == null:
		_beam_body = get_node_or_null("BeamBody") as StaticBody3D
	if _beam_mesh_inst == null:
		_beam_mesh_inst = get_node_or_null("BeamBody/MeshInstance3D") as MeshInstance3D
	if _beam_col_shape == null:
		_beam_col_shape = get_node_or_null("BeamBody/CollisionShape3D") as CollisionShape3D

	var dims: Vector3 = Vector3(beam_width, beam_height, beam_length)
	if _beam_body != null:
		_beam_body.position = Vector3(0.0, -beam_height * 0.5, -beam_length * 0.5)
	if _beam_mesh_inst != null and _beam_mesh_inst.mesh is BoxMesh:
		var box_mesh: BoxMesh = (_beam_mesh_inst.mesh as BoxMesh).duplicate() as BoxMesh
		box_mesh.size = dims
		_beam_mesh_inst.mesh = box_mesh
	if _beam_col_shape != null and _beam_col_shape.shape is BoxShape3D:
		var box_shape: BoxShape3D = (_beam_col_shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box_shape.size = dims
		_beam_col_shape.shape = box_shape

	if entry_anchor != null:
		entry_anchor.position = Vector3.ZERO
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -beam_length)
	if _entry_trigger != null:
		_entry_trigger.position = Vector3(0.0, 1.2, -0.6)
	if _exit_trigger != null:
		_exit_trigger.position = Vector3(0.0, 1.2, -beam_length - 0.4)
	if _hazard_zone != null:
		_hazard_zone.position = Vector3(0.0, -2.2, -beam_length * 0.5)
		var hz_col: CollisionShape3D = _hazard_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if hz_col != null and hz_col.shape is BoxShape3D:
			var hz_box: BoxShape3D = (hz_col.shape as BoxShape3D).duplicate() as BoxShape3D
			hz_box.size = Vector3(maxf(10.0, beam_width + 6.0), 1.5, beam_length + 2.0)
			hz_col.shape = hz_box


func _validate_parameters() -> bool:
	return _is_valid_config(beam_length, beam_width, beam_height)


static func _is_valid_config(length: float, width: float, height: float) -> bool:
	if not is_finite(length) or not is_finite(width) or not is_finite(height):
		return false
	if length < 1.5 or length > 25.0:
		return false
	if width < 0.25 or width > 2.5:
		return false
	if height < 0.15 or height > 3.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"beam_length": beam_length,
		"beam_width": beam_width,
		"beam_height": beam_height,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	if not _has_only_known_keys(params, ALLOWED_KEYS):
		return false

	var parsed: Dictionary = {}
	if not _read_strict_float(params, "beam_length", beam_length, parsed):
		return false
	if not _read_strict_float(params, "beam_width", beam_width, parsed):
		return false
	if not _read_strict_float(params, "beam_height", beam_height, parsed):
		return false

	var next_len: float = float(parsed["beam_length"])
	var next_wid: float = float(parsed["beam_width"])
	var next_hgt: float = float(parsed["beam_height"])

	if not _is_valid_config(next_len, next_wid, next_hgt):
		return false

	beam_length = next_len
	beam_width = next_wid
	beam_height = next_hgt
	return true
