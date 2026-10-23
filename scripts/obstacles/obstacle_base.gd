class_name ObstacleBase
extends Node3D

## Shared contract for modular course obstacles (M1a) and future editor/AI systems (M1b/M2a).
## ponytail: flat inheritance (ObstacleBase -> concrete obstacle); no deep hierarchy.

signal obstacle_entered(obstacle: ObstacleBase, player: PlayerController)
signal obstacle_completed(obstacle: ObstacleBase, player: PlayerController)
signal obstacle_hazard_hit(obstacle: ObstacleBase, player: PlayerController, reason: String)

@export var obstacle_id: String = "obs_000"
@export var obstacle_type: String = "base"
@export var display_name: String = "Obstacle"
@export var is_enabled: bool = true:
	set(value):
		is_enabled = value
		_apply_enabled_state()
@export var entry_anchor_path: NodePath = NodePath("EntryAnchor")
@export var exit_anchor_path: NodePath = NodePath("ExitAnchor")
@export var entry_trigger_path: NodePath = NodePath("EntryTrigger")
@export var hazard_zone_path: NodePath = NodePath("HazardZone")

var entry_anchor: Marker3D = null
var exit_anchor: Marker3D = null

var _entry_trigger: Area3D = null
var _hazard_zone: Area3D = null


func _ready() -> void:
	_cache_common_nodes()
	_connect_triggers()
	_apply_enabled_state()
	_rebuild_obstacle()
	reset_obstacle()


func reset_obstacle() -> void:
	_cache_common_nodes()
	_on_reset_obstacle()


func get_entry_position() -> Vector3:
	_cache_common_nodes()
	if entry_anchor != null:
		return entry_anchor.global_position
	return global_position


func get_exit_position() -> Vector3:
	_cache_common_nodes()
	if exit_anchor != null:
		return exit_anchor.global_position
	return global_position


func validate_configuration() -> bool:
	_cache_common_nodes()
	if obstacle_id.strip_edges().is_empty():
		return false
	if get_obstacle_type().strip_edges().is_empty():
		return false
	if display_name.strip_edges().is_empty():
		return false
	if entry_anchor == null or exit_anchor == null:
		return false
	return _validate_parameters()


func get_obstacle_type() -> String:
	return obstacle_type


func get_parameters() -> Dictionary:
	return _get_obstacle_parameters()


func apply_parameters(params: Dictionary) -> bool:
	if not _apply_obstacle_parameters(params):
		return false
	if not validate_configuration():
		return false
	_rebuild_obstacle()
	reset_obstacle()
	return true


func _cache_common_nodes() -> void:
	if entry_anchor == null:
		entry_anchor = get_node_or_null(entry_anchor_path) as Marker3D
	if exit_anchor == null:
		exit_anchor = get_node_or_null(exit_anchor_path) as Marker3D
	if _entry_trigger == null:
		_entry_trigger = get_node_or_null(entry_trigger_path) as Area3D
	if _hazard_zone == null:
		_hazard_zone = get_node_or_null(hazard_zone_path) as Area3D


func _connect_triggers() -> void:
	if _entry_trigger != null and not _entry_trigger.body_entered.is_connected(_on_entry_trigger_body_entered):
		_entry_trigger.body_entered.connect(_on_entry_trigger_body_entered)
	if _hazard_zone != null and not _hazard_zone.body_entered.is_connected(_on_hazard_zone_body_entered):
		_hazard_zone.body_entered.connect(_on_hazard_zone_body_entered)


func _apply_enabled_state() -> void:
	visible = is_enabled
	process_mode = Node.PROCESS_MODE_INHERIT if is_enabled else Node.PROCESS_MODE_DISABLED


func _on_entry_trigger_body_entered(body: Node3D) -> void:
	if is_enabled and body is PlayerController:
		obstacle_entered.emit(self, body as PlayerController)


func _on_hazard_zone_body_entered(body: Node3D) -> void:
	if is_enabled and body is PlayerController:
		obstacle_hazard_hit.emit(self, body as PlayerController, "Fell at %s" % display_name)


func _rebuild_obstacle() -> void:
	pass


func _on_reset_obstacle() -> void:
	pass


func _validate_parameters() -> bool:
	return true


func _get_obstacle_parameters() -> Dictionary:
	return {}


func _apply_obstacle_parameters(_params: Dictionary) -> bool:
	return true
