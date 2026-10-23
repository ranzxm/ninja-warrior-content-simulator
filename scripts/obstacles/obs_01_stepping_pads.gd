class_name ObstacleSteppingPads
extends ObstacleBase

## OBS-01: Stepping Pads / Jump Gap obstacle with configurable pad count, size, gap, and height variation.

@export_range(1, 12, 1) var pad_count: int = 4
@export var pad_dimensions: Vector3 = Vector3(1.8, 0.4, 1.8)
@export_range(0.2, 4.0, 0.1) var gap_distance: float = 0.8
@export_range(-1.2, 1.2, 0.05) var height_variation: float = 0.12
@export_range(0.0, 2.0, 0.05) var lateral_offset: float = 0.45

@onready var _pads_container: Node3D = get_node_or_null("PadsContainer") as Node3D

var _pad_material: StandardMaterial3D = null


func _init() -> void:
	obstacle_id = "obs_01_stepping_pads"
	obstacle_type = "stepping_pads"
	display_name = "Stepping Pads"


func _rebuild_obstacle() -> void:
	if _pads_container == null:
		_pads_container = get_node_or_null("PadsContainer") as Node3D
	if _pads_container == null:
		return

	for child: Node in _pads_container.get_children():
		_pads_container.remove_child(child)
		child.queue_free()

	if _pad_material == null:
		_pad_material = StandardMaterial3D.new()
		_pad_material.albedo_color = Color(0.22, 0.64, 0.86, 1.0)
		_pad_material.roughness = 0.75

	var step_z: float = pad_dimensions.z + gap_distance
	for i: int in range(pad_count):
		var pad_body: StaticBody3D = StaticBody3D.new()
		pad_body.name = "Pad_%02d" % (i + 1)
		pad_body.collision_layer = 5 # WORLD (1) | OBSTACLE (4)
		pad_body.collision_mask = 0

		var side_sign: float = -1.0 if (i % 2 == 0) else 1.0
		var x_pos: float = side_sign * lateral_offset if pad_count > 1 else 0.0
		var y_pos: float = (-pad_dimensions.y * 0.5) + ((i % 2) * height_variation)
		var z_pos: float = -(gap_distance + pad_dimensions.z * 0.5 + float(i) * step_z)
		pad_body.position = Vector3(x_pos, y_pos, z_pos)

		var mesh_inst: MeshInstance3D = MeshInstance3D.new()
		var box_mesh: BoxMesh = BoxMesh.new()
		box_mesh.size = pad_dimensions
		box_mesh.material = _pad_material
		mesh_inst.mesh = box_mesh
		pad_body.add_child(mesh_inst)

		var col_shape: CollisionShape3D = CollisionShape3D.new()
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = pad_dimensions
		col_shape.shape = box_shape
		pad_body.add_child(col_shape)

		_pads_container.add_child(pad_body)

	var total_span: float = float(pad_count) * step_z + gap_distance
	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, 0.0, -total_span)


func _validate_parameters() -> bool:
	if not is_finite(gap_distance) or not is_finite(height_variation) or not is_finite(lateral_offset):
		return false
	if pad_count < 1 or pad_count > 12:
		return false
	if pad_dimensions.x < 0.4 or pad_dimensions.y < 0.1 or pad_dimensions.z < 0.4:
		return false
	if pad_dimensions.x > 8.0 or pad_dimensions.y > 4.0 or pad_dimensions.z > 8.0:
		return false
	if gap_distance < 0.2 or gap_distance > 4.0:
		return false
	if absf(height_variation) > 1.2:
		return false
	if lateral_offset < 0.0 or lateral_offset > 2.0:
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
	var next_count: int = int(params.get("pad_count", pad_count))
	var next_gap: float = float(params.get("gap_distance", gap_distance))
	var next_height_var: float = float(params.get("height_variation", height_variation))
	var next_lateral: float = float(params.get("lateral_offset", lateral_offset))
	var next_dims: Vector3 = pad_dimensions
	if params.has("pad_dimensions"):
		var raw_dims: Variant = params["pad_dimensions"]
		if raw_dims is Vector3:
			next_dims = raw_dims
		elif raw_dims is Array and (raw_dims as Array).size() == 3:
			var arr: Array = raw_dims as Array
			next_dims = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		else:
			return false

	var prev_count: int = pad_count
	var prev_dims: Vector3 = pad_dimensions
	var prev_gap: float = gap_distance
	var prev_hvar: float = height_variation
	var prev_lat: float = lateral_offset

	pad_count = next_count
	pad_dimensions = next_dims
	gap_distance = next_gap
	height_variation = next_height_var
	lateral_offset = next_lateral

	if not _validate_parameters():
		pad_count = prev_count
		pad_dimensions = prev_dims
		gap_distance = prev_gap
		height_variation = prev_hvar
		lateral_offset = prev_lat
		return false
	return true
