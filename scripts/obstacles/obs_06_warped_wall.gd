class_name ObstacleWarpedWall
extends ObstacleBase

## OBS-06: Curved segmented Warped Wall traversable via sprint + jump onto the upper summit deck.

@export_range(2.0, 5.5, 0.2) var wall_height: float = 3.2
@export_range(2.0, 6.0, 0.2) var wall_width: float = 3.6
@export_range(0.6, 1.8, 0.1) var curve_profile: float = 1.0

const SEGMENT_COUNT: int = 5
const RUNUP_LENGTH: float = 3.6
const TOP_DECK_LENGTH: float = 3.5
const SLAB_THICKNESS: float = 0.4

@onready var _geometry_root: Node3D = get_node_or_null("GeometryRoot") as Node3D

var _ramp_material: StandardMaterial3D = null
var _top_material: StandardMaterial3D = null


func _init() -> void:
	obstacle_id = "obs_06_warped_wall"
	obstacle_type = "warped_wall"
	display_name = "Warped Wall"


func _rebuild_obstacle() -> void:
	if _geometry_root == null:
		_geometry_root = get_node_or_null("GeometryRoot") as Node3D
	if _geometry_root == null:
		return

	for child: Node in _geometry_root.get_children():
		_geometry_root.remove_child(child)
		child.queue_free()

	if _ramp_material == null:
		_ramp_material = StandardMaterial3D.new()
		_ramp_material.albedo_color = Color(0.26, 0.44, 0.78, 1.0)
		_ramp_material.roughness = 0.7
	if _top_material == null:
		_top_material = StandardMaterial3D.new()
		_top_material.albedo_color = Color(0.86, 0.68, 0.18, 1.0)
		_top_material.roughness = 0.65

	# 1. Flat run-up deck
	_create_slab(
		"RunupDeck",
		Vector3(wall_width, SLAB_THICKNESS, RUNUP_LENGTH),
		Vector3(0.0, -SLAB_THICKNESS * 0.5, -RUNUP_LENGTH * 0.5),
		0.0,
		_ramp_material
	)

	# 2. Segmented curved ramp
	var curve_span_z: float = 3.5 * curve_profile
	var curve_start_z: float = -RUNUP_LENGTH
	for i: int in range(SEGMENT_COUNT):
		var t0: float = float(i) / float(SEGMENT_COUNT)
		var t1: float = float(i + 1) / float(SEGMENT_COUNT)
		var z0: float = curve_start_z - (t0 * curve_span_z)
		var z1: float = curve_start_z - (t1 * curve_span_z)
		var y0: float = wall_height * pow(t0, 1.32)
		var y1: float = wall_height * pow(t1, 1.32)

		var dy: float = y1 - y0
		var dz: float = z1 - z0
		var seg_len: float = sqrt(dy * dy + dz * dz) + 0.08
		var pitch_rad: float = atan2(dy, -dz)
		var normal: Vector3 = Vector3(0.0, cos(pitch_rad), sin(pitch_rad))
		var top_mid: Vector3 = Vector3(0.0, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
		var center_pos: Vector3 = top_mid - normal * (SLAB_THICKNESS * 0.5)

		_create_slab(
			"RampSegment_%02d" % (i + 1),
			Vector3(wall_width, SLAB_THICKNESS, seg_len),
			center_pos,
			pitch_rad,
			_ramp_material
		)

	# 3. Summit platform at the top of the Warped Wall
	var top_start_z: float = curve_start_z - curve_span_z
	var top_center_z: float = top_start_z - (TOP_DECK_LENGTH * 0.5)
	_create_slab(
		"TopDeck",
		Vector3(wall_width, SLAB_THICKNESS, TOP_DECK_LENGTH),
		Vector3(0.0, wall_height - SLAB_THICKNESS * 0.5, top_center_z),
		0.0,
		_top_material
	)

	if exit_anchor != null:
		exit_anchor.position = Vector3(0.0, wall_height, top_start_z - TOP_DECK_LENGTH)


func _create_slab(
	slab_name: String,
	dims: Vector3,
	pos: Vector3,
	pitch_rad: float,
	mat: StandardMaterial3D
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = slab_name
	body.collision_layer = 5
	body.collision_mask = 0
	body.position = pos
	body.rotation = Vector3(pitch_rad, 0.0, 0.0)

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = dims
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	body.add_child(mesh_inst)

	var col: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = dims
	col.shape = box_shape
	body.add_child(col)

	_geometry_root.add_child(body)


func _validate_parameters() -> bool:
	if not is_finite(wall_height) or not is_finite(wall_width) or not is_finite(curve_profile):
		return false
	if wall_height < 1.8 or wall_height > 6.0:
		return false
	if wall_width < 1.5 or wall_width > 8.0:
		return false
	if curve_profile < 0.5 or curve_profile > 2.2:
		return false
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {
		"wall_height": wall_height,
		"wall_width": wall_width,
		"curve_profile": curve_profile,
	}


func _apply_obstacle_parameters(params: Dictionary) -> bool:
	var next_hgt: float = float(params.get("wall_height", wall_height))
	var next_wid: float = float(params.get("wall_width", wall_width))
	var next_crv: float = float(params.get("curve_profile", curve_profile))

	var prev_hgt: float = wall_height
	var prev_wid: float = wall_width
	var prev_crv: float = curve_profile

	wall_height = next_hgt
	wall_width = next_wid
	curve_profile = next_crv

	if not _validate_parameters():
		wall_height = prev_hgt
		wall_width = prev_wid
		curve_profile = prev_crv
		return false
	return true
