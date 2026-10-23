class_name StageDemoArena
extends Node3D

## Complete M1a competition course containing StartGate, 6 modular obstacles, FailZone, and FinishZone.

signal start_gate_crossed(player: PlayerController)
signal finish_zone_reached(player: PlayerController)
signal player_fell(player: PlayerController, reason: String, obstacle_id: String)
signal obstacle_entered(obstacle: ObstacleBase, index: int, total: int)

@export var stage_id: String = "stage_01_demo"
@export var stage_name: String = "STAGE 01 — NINJA COURSE DEMO"
@export_range(10.0, 600.0, 5.0) var time_limit_sec: float = 120.0
@export var fail_plane_y: float = -2.0
@export var spawn_point_path: NodePath = NodePath("SpawnPoint")
@export var start_gate_path: NodePath = NodePath("StartGate")
@export var finish_zone_path: NodePath = NodePath("FinishZone")
@export var fail_zone_path: NodePath = NodePath("FailZone")
@export var obstacles_root_path: NodePath = NodePath("Obstacles")

var _obstacles: Array[ObstacleBase] = []
var _last_obstacle_id: String = ""
var _last_obstacle_name: String = ""

@onready var _spawn_point: Marker3D = get_node_or_null(spawn_point_path) as Marker3D
@onready var _start_gate: Area3D = get_node_or_null(start_gate_path) as Area3D
@onready var _finish_zone: Area3D = get_node_or_null(finish_zone_path) as Area3D
@onready var _fail_zone: Area3D = get_node_or_null(fail_zone_path) as Area3D
@onready var _obstacles_root: Node3D = get_node_or_null(obstacles_root_path) as Node3D


func _ready() -> void:
	_collect_obstacles()
	if _start_gate != null and not _start_gate.body_entered.is_connected(_on_start_gate_body_entered):
		_start_gate.body_entered.connect(_on_start_gate_body_entered)
	if _finish_zone != null and not _finish_zone.body_entered.is_connected(_on_finish_zone_body_entered):
		_finish_zone.body_entered.connect(_on_finish_zone_body_entered)
	if _fail_zone != null and not _fail_zone.body_entered.is_connected(_on_fail_zone_body_entered):
		_fail_zone.body_entered.connect(_on_fail_zone_body_entered)


func get_spawn_transform() -> Transform3D:
	if _spawn_point != null:
		return _spawn_point.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 2.4))


func is_below_fail_plane(world_position: Vector3) -> bool:
	return world_position.y < fail_plane_y


func get_obstacles() -> Array[ObstacleBase]:
	if _obstacles.is_empty():
		_collect_obstacles()
	return _obstacles


func get_obstacle_count() -> int:
	return get_obstacles().size()


func get_last_obstacle_id() -> String:
	return _last_obstacle_id


func get_last_obstacle_name() -> String:
	return _last_obstacle_name


func reset_all_obstacles() -> void:
	_last_obstacle_id = ""
	_last_obstacle_name = ""
	for obs: ObstacleBase in get_obstacles():
		if is_instance_valid(obs):
			obs.reset_obstacle()


func _collect_obstacles() -> void:
	_obstacles.clear()
	if _obstacles_root == null:
		_obstacles_root = get_node_or_null(obstacles_root_path) as Node3D
	if _obstacles_root == null:
		return

	var idx: int = 0
	for child: Node in _obstacles_root.get_children():
		if child is ObstacleBase:
			idx += 1
			var obs: ObstacleBase = child as ObstacleBase
			_obstacles.append(obs)
			var captured_index: int = idx
			if not obs.obstacle_entered.is_connected(_on_obstacle_entered):
				obs.obstacle_entered.connect(_on_obstacle_entered.bind(captured_index))
			if not obs.obstacle_hazard_hit.is_connected(_on_obstacle_hazard_hit):
				obs.obstacle_hazard_hit.connect(_on_obstacle_hazard_hit)


func _on_start_gate_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		start_gate_crossed.emit(body as PlayerController)


func _on_finish_zone_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		finish_zone_reached.emit(body as PlayerController)


func _on_fail_zone_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		var reason: String = "Fell into Course Hazard"
		if not _last_obstacle_name.is_empty():
			reason = "Fell at %s" % _last_obstacle_name
		player_fell.emit(body as PlayerController, reason, _last_obstacle_id)


func _on_obstacle_entered(obstacle: ObstacleBase, _player: PlayerController, index: int) -> void:
	_last_obstacle_id = obstacle.obstacle_id
	_last_obstacle_name = obstacle.display_name
	obstacle_entered.emit(obstacle, index, _obstacles.size())


func _on_obstacle_hazard_hit(obstacle: ObstacleBase, player: PlayerController, reason: String) -> void:
	_last_obstacle_id = obstacle.obstacle_id
	_last_obstacle_name = obstacle.display_name
	player_fell.emit(player, reason, obstacle.obstacle_id)
