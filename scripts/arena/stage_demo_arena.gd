class_name StageDemoArena
extends Node3D

## Editable & playable competition arena managing StartGate, SpawnPoint, FinishZone,
## FailZone, obstacle instances, explicit route ordering, and pause-aware simulation.

signal start_gate_crossed(player: PlayerController)
signal finish_zone_reached(player: PlayerController)
signal player_fell(player: PlayerController, reason: String, obstacle_id: String)
signal obstacle_entered(obstacle: ObstacleBase, index: int, total: int)
signal obstacle_completed(obstacle: ObstacleBase, index: int, total: int)

@export var stage_id: String = "stage_01_demo"
@export var stage_name: String = "STAGE 01 — NINJA COURSE DEMO"
@export var theme_id: String = "default"
@export_range(10.0, 600.0, 5.0) var time_limit_sec: float = 120.0
@export var fail_plane_y: float = -2.0
@export var spawn_point_path: NodePath = NodePath("SpawnPoint")
@export var start_platform_path: NodePath = NodePath("StartPlatform")
@export var start_gate_path: NodePath = NodePath("StartGate")
@export var finish_platform_path: NodePath = NodePath("FinishPlatform")
@export var finish_zone_path: NodePath = NodePath("FinishZone")
@export var fail_zone_path: NodePath = NodePath("FailZone")
@export var obstacles_root_path: NodePath = NodePath("Obstacles")
@export var connector_decks_path: NodePath = NodePath("ConnectorDecks")

var _obstacles: Array[ObstacleBase] = []
var _route_order: Array[String] = []
var _last_obstacle_id: String = ""
var _last_obstacle_name: String = ""
var _editor_mode_active: bool = false

var _spawn_editor_marker: MeshInstance3D = null
var _finish_editor_marker: MeshInstance3D = null

@onready var _spawn_point: Marker3D = get_node_or_null(spawn_point_path) as Marker3D
@onready var _start_platform: StaticBody3D = get_node_or_null(start_platform_path) as StaticBody3D
@onready var _start_gate: Area3D = get_node_or_null(start_gate_path) as Area3D
@onready var _finish_platform: StaticBody3D = get_node_or_null(finish_platform_path) as StaticBody3D
@onready var _finish_zone: Area3D = get_node_or_null(finish_zone_path) as Area3D
@onready var _fail_zone: Area3D = get_node_or_null(fail_zone_path) as Area3D
@onready var _obstacles_root: Node3D = get_node_or_null(obstacles_root_path) as Node3D
@onready var _connector_decks: Node3D = get_node_or_null(connector_decks_path) as Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_cache_arena_nodes()
	_collect_obstacles()
	_ensure_editor_markers()
	if _start_gate != null and not _start_gate.body_entered.is_connected(_on_start_gate_body_entered):
		_start_gate.body_entered.connect(_on_start_gate_body_entered)
	if _finish_zone != null and not _finish_zone.body_entered.is_connected(_on_finish_zone_body_entered):
		_finish_zone.body_entered.connect(_on_finish_zone_body_entered)
	if _fail_zone != null and not _fail_zone.body_entered.is_connected(_on_fail_zone_body_entered):
		_fail_zone.body_entered.connect(_on_fail_zone_body_entered)


func _cache_arena_nodes() -> void:
	if _spawn_point == null:
		_spawn_point = get_node_or_null(spawn_point_path) as Marker3D
	if _start_platform == null:
		_start_platform = get_node_or_null(start_platform_path) as StaticBody3D
	if _start_gate == null:
		_start_gate = get_node_or_null(start_gate_path) as Area3D
	if _finish_platform == null:
		_finish_platform = get_node_or_null(finish_platform_path) as StaticBody3D
	if _finish_zone == null:
		_finish_zone = get_node_or_null(finish_zone_path) as Area3D
	if _fail_zone == null:
		_fail_zone = get_node_or_null(fail_zone_path) as Area3D
	if _obstacles_root == null:
		_obstacles_root = get_node_or_null(obstacles_root_path) as Node3D
	if _connector_decks == null:
		_connector_decks = get_node_or_null(connector_decks_path) as Node3D


func _ensure_editor_markers() -> void:
	_cache_arena_nodes()
	if _spawn_point != null and _spawn_editor_marker == null:
		_spawn_editor_marker = MeshInstance3D.new()
		_spawn_editor_marker.name = "_SpawnEditorMarker"
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.0
		cyl.bottom_radius = 0.45
		cyl.height = 1.2
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.95, 0.35, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cyl.material = mat
		_spawn_editor_marker.mesh = cyl
		_spawn_editor_marker.position = Vector3(0.0, 0.8, 0.0)
		_spawn_editor_marker.visible = _editor_mode_active
		_spawn_point.add_child(_spawn_editor_marker)

	if _finish_zone != null and _finish_editor_marker == null:
		_finish_editor_marker = MeshInstance3D.new()
		_finish_editor_marker.name = "_FinishEditorMarker"
		var box: BoxMesh = BoxMesh.new()
		box.size = get_finish_size()
		var fmat: StandardMaterial3D = StandardMaterial3D.new()
		fmat.albedo_color = Color(0.98, 0.78, 0.12, 0.35)
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = fmat
		_finish_editor_marker.mesh = box
		_finish_editor_marker.visible = _editor_mode_active
		_finish_zone.add_child(_finish_editor_marker)


func set_editor_mode(active: bool) -> void:
	_editor_mode_active = active
	_ensure_editor_markers()
	if _spawn_editor_marker != null:
		_spawn_editor_marker.visible = active
	if _finish_editor_marker != null:
		_finish_editor_marker.visible = active
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.set_editor_mode(active)


func set_connector_decks_enabled(enabled_flag: bool) -> void:
	_cache_arena_nodes()
	if _connector_decks == null:
		return
	_connector_decks.visible = enabled_flag
	for child: Node in _connector_decks.get_children():
		if child is CollisionObject3D:
			var co: CollisionObject3D = child as CollisionObject3D
			var target_layer: int = 1 if enabled_flag else 0
			co.collision_layer = target_layer
			co.set_deferred("collision_layer", target_layer)
			for sub: Node in co.get_children():
				if sub is CollisionShape3D:
					(sub as CollisionShape3D).disabled = not enabled_flag
					(sub as CollisionShape3D).set_deferred("disabled", not enabled_flag)


func get_spawn_transform() -> Transform3D:
	_cache_arena_nodes()
	if _spawn_point != null:
		return _spawn_point.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.4))


func get_spawn_position() -> Vector3:
	_cache_arena_nodes()
	return _spawn_point.position if _spawn_point != null else Vector3(0.0, 0.0, 2.4)


func get_spawn_rotation_y_deg() -> float:
	_cache_arena_nodes()
	return rad_to_deg(_spawn_point.rotation.y) if _spawn_point != null else 0.0


func set_spawn_transform_data(pos: Vector3, rot_y_deg: float) -> bool:
	if not is_finite(pos.x) or not is_finite(pos.y) or not is_finite(pos.z) or not is_finite(rot_y_deg):
		return false
	if pos.abs().x > 250.0 or pos.y < -10.0 or pos.y > 100.0 or pos.abs().z > 250.0:
		return false
	if absf(rot_y_deg) > 360.0:
		return false
	_cache_arena_nodes()
	if _spawn_point == null:
		return false
	var rot_rad: float = deg_to_rad(rot_y_deg)
	var rot_basis: Basis = Basis(Vector3.UP, rot_rad)
	_spawn_point.position = pos
	_spawn_point.rotation = Vector3(0.0, rot_rad, 0.0)
	if _start_platform != null:
		_start_platform.position = pos + rot_basis * Vector3(0.0, -0.2, -0.4)
		_start_platform.rotation = Vector3(0.0, rot_rad, 0.0)
	if _start_gate != null:
		_start_gate.position = pos + rot_basis * Vector3(0.0, 1.3, -2.2)
		_start_gate.rotation = Vector3(0.0, rot_rad, 0.0)
	return true


func get_finish_position() -> Vector3:
	_cache_arena_nodes()
	return _finish_zone.position if _finish_zone != null else Vector3(0.0, 4.5, -68.3)


func get_finish_rotation_y_deg() -> float:
	_cache_arena_nodes()
	return rad_to_deg(_finish_zone.rotation.y) if _finish_zone != null else 0.0


func get_finish_size() -> Vector3:
	_cache_arena_nodes()
	if _finish_zone != null:
		var col: CollisionShape3D = _finish_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col != null and col.shape is BoxShape3D:
			return (col.shape as BoxShape3D).size
	return Vector3(4.6, 2.8, 3.6)


func set_finish_transform_data(pos: Vector3, rot_y_deg: float, size: Vector3) -> bool:
	if not is_finite(pos.x) or not is_finite(pos.y) or not is_finite(pos.z) or not is_finite(rot_y_deg):
		return false
	if not is_finite(size.x) or not is_finite(size.y) or not is_finite(size.z):
		return false
	if pos.abs().x > 250.0 or pos.y < -10.0 or pos.y > 100.0 or pos.abs().z > 250.0:
		return false
	if absf(rot_y_deg) > 360.0:
		return false
	if size.x < 1.0 or size.y < 1.0 or size.z < 1.0 or size.x > 20.0 or size.y > 20.0 or size.z > 20.0:
		return false
	_cache_arena_nodes()
	if _finish_zone == null:
		return false
	var rot_rad: float = deg_to_rad(rot_y_deg)
	_finish_zone.position = pos
	_finish_zone.rotation = Vector3(0.0, rot_rad, 0.0)
	var col: CollisionShape3D = _finish_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col != null and col.shape is BoxShape3D:
		var box: BoxShape3D = (col.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = size
		col.shape = box
	if _finish_editor_marker != null and _finish_editor_marker.mesh is BoxMesh:
		(_finish_editor_marker.mesh as BoxMesh).size = size
	if _finish_platform != null:
		_finish_platform.position = pos + Vector3(0.0, -1.5, 0.0)
		_finish_platform.rotation = Vector3(0.0, rot_rad, 0.0)
	return true


func has_valid_spawn_and_finish() -> bool:
	_cache_arena_nodes()
	if _spawn_point == null or _finish_zone == null:
		return false
	var col: CollisionShape3D = _finish_zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return col != null and col.shape is BoxShape3D


func is_below_fail_plane(world_position: Vector3) -> bool:
	return world_position.y < fail_plane_y


func get_obstacles() -> Array[ObstacleBase]:
	if _obstacles.is_empty():
		_collect_obstacles()
	return _obstacles


func get_obstacle_count() -> int:
	return get_obstacles().size()


func get_obstacle_by_id(inst_id: String) -> ObstacleBase:
	var clean: String = inst_id.strip_edges()
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs) and obs.get_obstacle_instance_id() == clean:
			return obs
	return null


func get_route_order() -> Array[String]:
	if _route_order.is_empty() and not _obstacles.is_empty():
		_rebuild_default_route_order()
	return _route_order.duplicate()


func set_route_order(new_route: Array[String]) -> bool:
	var seen: Dictionary = {}
	var validated: Array[String] = []
	for item_id: String in new_route:
		var clean: String = item_id.strip_edges()
		if clean.is_empty() or seen.has(clean):
			return false
		if get_obstacle_by_id(clean) == null:
			return false
		seen[clean] = true
		validated.append(clean)
	_route_order = validated
	return true


func move_route_item(inst_id: String, delta_index: int) -> bool:
	var idx: int = _route_order.find(inst_id)
	if idx < 0:
		return false
	var target_idx: int = clampi(idx + delta_index, 0, _route_order.size() - 1)
	if target_idx == idx:
		return false
	var item: String = _route_order[idx]
	_route_order.remove_at(idx)
	_route_order.insert(target_idx, item)
	return true


func get_required_obstacle_ids() -> Array[String]:
	return get_route_order()


func get_obstacle_enabled_map() -> Dictionary:
	var enabled_map: Dictionary = {}
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			enabled_map[obs.get_obstacle_instance_id()] = obs.is_enabled
	return enabled_map


func add_obstacle_instance(obs: ObstacleBase, append_to_route: bool = true) -> bool:
	_cache_arena_nodes()
	if obs == null or _obstacles_root == null:
		return false
	var inst_id: String = obs.get_obstacle_instance_id()
	if inst_id.is_empty() or get_obstacle_by_id(inst_id) != null:
		return false
	if obs.get_parent() != _obstacles_root:
		_obstacles_root.add_child(obs)
	obs.set_editor_mode(_editor_mode_active)
	_obstacles.append(obs)
	_connect_single_obstacle_signals(obs)
	if append_to_route and not _route_order.has(inst_id):
		_route_order.append(inst_id)
	return true


func remove_obstacle_by_id(inst_id: String) -> bool:
	var obs: ObstacleBase = get_obstacle_by_id(inst_id)
	if obs == null:
		return false
	_disconnect_single_obstacle_signals(obs)
	_obstacles.erase(obs)
	_route_order.erase(inst_id)
	if obs.get_parent() != null:
		obs.get_parent().remove_child(obs)
	obs.free()
	return true


func clear_all_obstacles() -> void:
	_cache_arena_nodes()
	for obs: ObstacleBase in _obstacles.duplicate():
		if is_instance_valid(obs):
			_disconnect_single_obstacle_signals(obs)
			if obs.get_parent() != null:
				obs.get_parent().remove_child(obs)
			obs.free()
	_obstacles.clear()
	_route_order.clear()
	_last_obstacle_id = ""
	_last_obstacle_name = ""


func get_last_obstacle_id() -> String:
	return _last_obstacle_id


func get_last_obstacle_name() -> String:
	return _last_obstacle_name


func start_obstacles_simulation() -> void:
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.set_simulation_paused(false)
			obs.start_simulation()


func stop_obstacles_simulation() -> void:
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.stop_simulation()


func set_obstacles_paused(paused: bool) -> void:
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.set_simulation_paused(paused)


func reset_all_obstacles() -> void:
	_last_obstacle_id = ""
	_last_obstacle_name = ""
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.reset_obstacle()


func _collect_obstacles() -> void:
	_obstacles.clear()
	_cache_arena_nodes()
	if _obstacles_root == null:
		return

	var seen_ids: Dictionary = {}
	for child: Node in _obstacles_root.get_children():
		if child is ObstacleBase:
			var obs: ObstacleBase = child as ObstacleBase
			if obs.get_obstacle_instance_id().is_empty() or seen_ids.has(obs.get_obstacle_instance_id()):
				obs.set_obstacle_instance_id(ObstacleBase.allocate_unique_instance_id())
			seen_ids[obs.get_obstacle_instance_id()] = true
			_obstacles.append(obs)
			_connect_single_obstacle_signals(obs)

	if _route_order.is_empty():
		_rebuild_default_route_order()


func _rebuild_default_route_order() -> void:
	_route_order.clear()
	for obs: ObstacleBase in _obstacles:
		if is_instance_valid(obs):
			var id_str: String = obs.get_obstacle_instance_id()
			if not id_str.is_empty() and not _route_order.has(id_str):
				_route_order.append(id_str)


func _connect_single_obstacle_signals(obs: ObstacleBase) -> void:
	if not obs.obstacle_entered.is_connected(_on_obstacle_entered):
		obs.obstacle_entered.connect(_on_obstacle_entered)
	if not obs.obstacle_completed.is_connected(_on_obstacle_completed):
		obs.obstacle_completed.connect(_on_obstacle_completed)
	if not obs.obstacle_hazard_hit.is_connected(_on_obstacle_hazard_hit):
		obs.obstacle_hazard_hit.connect(_on_obstacle_hazard_hit)


func _disconnect_single_obstacle_signals(obs: ObstacleBase) -> void:
	if obs.obstacle_entered.is_connected(_on_obstacle_entered):
		obs.obstacle_entered.disconnect(_on_obstacle_entered)
	if obs.obstacle_completed.is_connected(_on_obstacle_completed):
		obs.obstacle_completed.disconnect(_on_obstacle_completed)
	if obs.obstacle_hazard_hit.is_connected(_on_obstacle_hazard_hit):
		obs.obstacle_hazard_hit.disconnect(_on_obstacle_hazard_hit)


func _on_start_gate_body_entered(body: Node3D) -> void:
	if _editor_mode_active:
		return
	if body is PlayerController:
		start_gate_crossed.emit(body as PlayerController)


func _on_finish_zone_body_entered(body: Node3D) -> void:
	if _editor_mode_active:
		return
	if body is PlayerController:
		finish_zone_reached.emit(body as PlayerController)


func _on_fail_zone_body_entered(body: Node3D) -> void:
	if _editor_mode_active:
		return
	if body is PlayerController:
		var reason: String = "Fell into Course Hazard"
		if not _last_obstacle_name.is_empty():
			reason = "Fell at %s" % _last_obstacle_name
		player_fell.emit(body as PlayerController, reason, _last_obstacle_id)


func _on_obstacle_entered(obstacle: ObstacleBase, _player: PlayerController) -> void:
	if _editor_mode_active or not obstacle.is_enabled:
		return
	_last_obstacle_id = obstacle.get_obstacle_instance_id()
	_last_obstacle_name = obstacle.display_name
	var route_idx: int = _route_order.find(_last_obstacle_id) + 1
	obstacle_entered.emit(obstacle, maxi(1, route_idx), _route_order.size())


func _on_obstacle_completed(obstacle: ObstacleBase, _player: PlayerController) -> void:
	if _editor_mode_active or not obstacle.is_enabled:
		return
	_last_obstacle_id = obstacle.get_obstacle_instance_id()
	_last_obstacle_name = obstacle.display_name
	var route_idx: int = _route_order.find(_last_obstacle_id) + 1
	obstacle_completed.emit(obstacle, maxi(1, route_idx), _route_order.size())


func _on_obstacle_hazard_hit(obstacle: ObstacleBase, player: PlayerController, reason: String) -> void:
	if _editor_mode_active or not obstacle.is_enabled:
		return
	_last_obstacle_id = obstacle.get_obstacle_instance_id()
	_last_obstacle_name = obstacle.display_name
	player_fell.emit(player, reason, obstacle.get_obstacle_instance_id())
