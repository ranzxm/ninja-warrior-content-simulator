class_name PrototypeArena
extends Node3D

## Greybox prototype arena for M0 movement, jump gap, and fall recovery tests.
## ponytail: static greybox geometry for M0; modular ObstacleBase prefabs arrive in M1a.

signal player_fell(body: Node3D)

@export var spawn_point_path: NodePath = NodePath("SpawnPoint")
@export var fail_zone_path: NodePath = NodePath("FailZone")
@export var fail_plane_y: float = -3.0

@onready var _spawn_point: Marker3D = get_node_or_null(spawn_point_path) as Marker3D
@onready var _fail_zone: Area3D = get_node_or_null(fail_zone_path) as Area3D


func _ready() -> void:
	if _fail_zone != null and not _fail_zone.body_entered.is_connected(_on_fail_zone_body_entered):
		_fail_zone.body_entered.connect(_on_fail_zone_body_entered)


func get_spawn_transform() -> Transform3D:
	if _spawn_point != null:
		return _spawn_point.global_transform
	return Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 10.0))


func is_below_fail_plane(world_position: Vector3) -> bool:
	return world_position.y < fail_plane_y


func _on_fail_zone_body_entered(body: Node3D) -> void:
	if body is PlayerController:
		player_fell.emit(body)
