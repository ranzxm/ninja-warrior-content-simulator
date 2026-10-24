class_name ObstacleSteppingPads
extends ObstacleBase

## OBS-01: Stepping Pads / Jump Gap obstacle with configurable pad count, size, gap, height variation, and lateral offset.

const ALLOWED_KEYS: Array[String] = [
	"pad_count",
	"pad_dimensions",
	"gap_distance",
	"height_variation",
	"lateral_offset",
]

@export_range(1, 12, 1) var pad_count: int = 4
@export var pad_dimensions: Vector3 = Vector3(1.8, 0.4, 1.8)
@export_range(0.2, 4.0, 0.1) var gap_distance: float = 0.8
@export_range(-1.2, 1.2, 0.05) var height_variation: float = 0.12
@export_range(0.0, 2.0, 0.05) var lateral_offset: float = 0.45

@onready var _pads_container: Node3D = get_node_or_null("PadsContainer") as Node3D

var _pad_material: StandardMaterial3D = null


func _init() -> void:
	super._init()
	obstacle_type = "stepping_pads"
	display_name = "Stepping Pads"


func get_pad_bodies() -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	if _pads_container == null:
		_pads_container = get_node_or_null("PadsContainer") as Node3D
	if _pads_container == null:
		return bodies
	for child: Node in _pads_container.get_children():
		if child is StaticBody3D:
			bodies.append(child as StaticBody3D)
	return bodies


func _rebuild_obstacle() -> void:
	_cache_common_nodes()
	_localize_geometry_resources()
	if _pads_container == null:
		_pads_container = get_node_or_null("PadsContainer") as Node3D
	if _pads_container == null:
		return

	var bodies: Array[StaticBody3D] = get_pad_bodies()
	while bodies.size() > pad_count:
		_retire_geometry_node(bodies.pop_back() as StaticBody3D)

	if _pad_material == null:
		_pad_material = StandardMaterial3D.new()
		_pad_material.albedo_color = Color(0.22, 0.64, 0.86, 1.0)
		_pad_material.roughness = 0.75

	var step_z: float = pad_dimensions.z + gap_distance
	for i: int in range(pad_count):
		var pad_body: StaticBody3D
		if i < bodies.size():
			pad_body = bodies[i]
		else:
			pad_body = StaticBody3D.new()
			pad_body.name = "Pad_%02d" % (i + 1)
			pad_body.collision_layer = 5 # WORLD (1) | OBSTACLE (4)
			pad_body.collision_mask = 0
			var mesh_inst: MeshInstance3D = MeshInstance3D.new()
			mesh_inst.name = "MeshInstance3D"
			var box_mesh: BoxMesh = BoxMesh.new()
			box_mesh.material = _pad_material
			mesh_inst.mesh = box_mesh
			pad_body.add_child(mesh_inst)
			var col_shape: CollisionShape3D = CollisionShape3D.new()
			col_shape.name = "CollisionShape3D"
			col_shape.shape = BoxShape3D.new()
			pad_body.add_child(col_shape)
			_pads_container.add_child(pad_body)

		var side_sign: float = -1.0 if (i % 2 == 0) else 1.0
		var x_pos: float = side_sign * lateral_offset if pad_count > 1 else 0.0
		var y_pos: float = (-pad_dimensions.y * 0.5) + ((i % 2) * height_variation)
		var z_pos: float = -(gap_distance + pad_dimensions.z * 0.5 + float(i) * step_z)
		pad_body.position = Vector3(x_pos, y_pos, z_pos)

		(pad_body.get_node("MeshInstance3D").mesh as BoxMesh).size = pad_dimensions
		(pad_body.get_node("CollisionShape3D").shape as BoxShape3D).size = pad_dimensions

	var total_span: float = float(pad_count) * step_z + gap_distance
	if entry_anchor != null:
		entry_anchor.position = Vector3.ZERO
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -total_span)
	if _entry_trigger != null:
		_entry_trigger.position = Vector3(0.0, 1.2, -0.8)
	if _exit_trigger != null:
		_exit_trigger.position = Vector3(0.0, 1.2, -total_span - 0.4)
	if _hazard_zone != null:
		_hazard_zone.position = Vector3(0.0, -2.2, -total_span * 0.5)
		var hz_col: CollisionShape3D = _hazard_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if hz_col != null and hz_col.shape is BoxShape3D:
			var hz_box: BoxShape3D = hz_col.shape as BoxShape3D
			hz_box.size = Vector3(maxf(10.0, pad_dimensions.x + lateral_offset * 2.0 + 4.0), 1.5, total_span + 2.0)


func _validate_parameters() -> bool:
	return _is_valid_config(pad_count, pad_dimensions, gap_distance, height_variation, lateral_offset)


static func _is_valid_config(
	count: int,
	dims: Vector3,
	gap: float,
	h_var: float,
	lat_offset: float
) -> bool:
	if not is_finite(gap) or not is_finite(h_var) or not is_finite(lat_offset):
		return false
	if not is_finite(dims.x) or not is_finite(dims.y) or not is_finite(dims.z):
		return false
	if count < 1 or count > 12:
		return false
	if dims.x < 0.4 or dims.y < 0.1 or dims.z < 0.4:
		return false
	if dims.x > 8.0 or dims.y > 4.0 or dims.z > 8.0:
		return false
	if gap < 0.2 or gap > 4.0:
		return false
	if absf(h_var) > 1.2:
		return false
	if lat_offset < 0.0 or lat_offset > 2.0:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"pad_count": pad_count,
		"pad_dimensions": [pad_dimensions.x, pad_dimensions.y, pad_dimensions.z],
		"gap_distance": gap_distance,
		"height_variation": height_variation,
		"lateral_offset": lateral_offset,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	if not _has_only_known_keys(params, ALLOWED_KEYS):
		return false

	var parsed: Dictionary = {}
	if not _read_strict_int(params, "pad_count", pad_count, parsed):
		return false
	if not _read_strict_vec3(params, "pad_dimensions", pad_dimensions, parsed):
		return false
	if not _read_strict_float(params, "gap_distance", gap_distance, parsed):
		return false
	if not _read_strict_float(params, "height_variation", height_variation, parsed):
		return false
	if not _read_strict_float(params, "lateral_offset", lateral_offset, parsed):
		return false

	var next_count: int = int(parsed["pad_count"])
	var next_dims: Vector3 = parsed["pad_dimensions"] as Vector3
	var next_gap: float = float(parsed["gap_distance"])
	var next_hvar: float = float(parsed["height_variation"])
	var next_lat: float = float(parsed["lateral_offset"])

	if not _is_valid_config(next_count, next_dims, next_gap, next_hvar, next_lat):
		return false

	pad_count = next_count
	pad_dimensions = next_dims
	gap_distance = next_gap
	height_variation = next_hvar
	lateral_offset = next_lat
	return true
