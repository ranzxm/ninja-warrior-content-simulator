class_name ObstacleBalanceBeam
extends ObstacleBase

## OBS-02: Narrow elevated balance beam with dynamically resized BoxMesh and BoxShape3D.

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


func _rebuild_obstacle() -> void:
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

	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -beam_length)


func _validate_parameters() -> bool:
	if not is_finite(beam_length) or not is_finite(beam_width) or not is_finite(beam_height):
		return false
	if beam_length < 1.5 or beam_length > 25.0:
		return false
	if beam_width < 0.25 or beam_width > 2.5:
		return false
	if beam_height < 0.15 or beam_height > 3.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"beam_length": beam_length,
		"beam_width": beam_width,
		"beam_height": beam_height,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	var next_len: float = float(params.get("beam_length", beam_length))
	var next_wid: float = float(params.get("beam_width", beam_width))
	var next_hgt: float = float(params.get("beam_height", beam_height))

	var prev_len: float = beam_length
	var prev_wid: float = beam_width
	var prev_hgt: float = beam_height

	beam_length = next_len
	beam_width = next_wid
	beam_height = next_hgt

	if not _validate_parameters():
		beam_length = prev_len
		beam_width = prev_wid
		beam_height = prev_hgt
		return false
	return true
