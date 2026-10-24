class_name ObstacleBase
extends Node3D

## Shared contract for modular course obstacles (M1a/M1b) with unique instance_id,
## pause-aware dynamic simulation lifecycle, full collision enable/disable,
## explicit traversal states (NOT_STARTED -> ENTERED -> COMPLETED), and atomic parameters.

signal obstacle_entered(obstacle: ObstacleBase, player: PlayerController)
signal obstacle_completed(obstacle: ObstacleBase, player: PlayerController)
signal obstacle_hazard_hit(obstacle: ObstacleBase, player: PlayerController, reason: String)

enum TraversalState {
	NOT_STARTED,
	ENTERED,
	COMPLETED,
}

const META_ORIG_LAYER: StringName = &"_orig_collision_layer"
const META_ORIG_MASK: StringName = &"_orig_collision_mask"
const META_ORIG_MONITORING: StringName = &"_orig_monitoring"
const META_ORIG_MONITORABLE: StringName = &"_orig_monitorable"
const EDITOR_PICK_LAYER: int = 16 # Layer 5: EDITOR_PICK

static var _next_instance_counter: int = 0

var _instance_id: String = ""

@export var instance_id: String = "":
	set(value):
		_set_identity_internal(value)
	get:
		return _instance_id

## Compatibility alias synchronized with instance_id.
@export var obstacle_id: String = "":
	set(value):
		_set_identity_internal(value)
	get:
		return _instance_id

@export var obstacle_type: String = "base"
@export var display_name: String = "Obstacle"
@export var is_enabled: bool = true:
	set(value):
		is_enabled = value
		_apply_enabled_state()
@export var entry_anchor_path: NodePath = NodePath("EntryAnchor")
@export var exit_anchor_path: NodePath = NodePath("ExitAnchor")
@export var entry_trigger_path: NodePath = NodePath("EntryTrigger")
@export var exit_trigger_path: NodePath = NodePath("ExitTrigger")
@export var hazard_zone_path: NodePath = NodePath("HazardZone")

var entry_anchor: Marker3D = null
var exit_anchor: Marker3D = null
var traversal_state: TraversalState = TraversalState.NOT_STARTED
var simulation_active: bool = false
var simulation_paused: bool = false
var editor_mode_active: bool = false

var _entry_trigger: Area3D = null
var _exit_trigger: Area3D = null
var _hazard_zone: Area3D = null
var _editor_pick_body: StaticBody3D = null


static func allocate_unique_instance_id() -> String:
	_next_instance_counter += 1
	return "ob_%06d" % _next_instance_counter


static func register_known_instance_id(id_str: String) -> void:
	var clean: String = id_str.strip_edges()
	if clean.begins_with("ob_"):
		var num_part: String = clean.substr(3)
		if num_part.is_valid_int():
			var parsed_num: int = num_part.to_int()
			if parsed_num > _next_instance_counter:
				_next_instance_counter = parsed_num


func _init() -> void:
	_set_identity_internal(allocate_unique_instance_id())


func _ready() -> void:
	if _instance_id.is_empty():
		_set_identity_internal(allocate_unique_instance_id())
	else:
		register_known_instance_id(_instance_id)
	_cache_common_nodes()
	_connect_triggers()
	_rebuild_obstacle()
	reset_obstacle()
	_apply_enabled_state()


func get_obstacle_instance_id() -> String:
	return _instance_id


func set_obstacle_instance_id(new_id: String) -> void:
	_set_identity_internal(new_id)


func _set_identity_internal(new_id: String) -> void:
	var clean: String = new_id.strip_edges()
	if clean.is_empty():
		return
	_instance_id = clean
	register_known_instance_id(clean)


func start_simulation() -> void:
	if not is_enabled or editor_mode_active:
		simulation_active = false
		return
	simulation_active = true


func stop_simulation() -> void:
	simulation_active = false


func set_simulation_paused(paused: bool) -> void:
	simulation_paused = paused


func is_simulation_running() -> bool:
	if not is_enabled or not simulation_active or simulation_paused or editor_mode_active:
		return false
	if is_inside_tree() and get_tree().paused:
		return false
	return true


func set_editor_mode(active: bool) -> void:
	editor_mode_active = active
	if active:
		simulation_active = false
	_ensure_editor_pick_body()
	_apply_enabled_state()


func reset_obstacle() -> void:
	_cache_common_nodes()
	simulation_active = false
	simulation_paused = false
	traversal_state = TraversalState.NOT_STARTED
	_on_reset_obstacle()
	_apply_enabled_state()


func mark_entered() -> void:
	if traversal_state == TraversalState.NOT_STARTED:
		traversal_state = TraversalState.ENTERED


func mark_completed() -> void:
	if traversal_state == TraversalState.ENTERED:
		traversal_state = TraversalState.COMPLETED


func get_traversal_state() -> TraversalState:
	return traversal_state


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


func get_local_bounds_aabb() -> AABB:
	_cache_common_nodes()
	var entry_local: Vector3 = entry_anchor.position if entry_anchor != null else Vector3.ZERO
	var exit_local: Vector3 = exit_anchor.position if exit_anchor != null else Vector3(0.0, 0.0, -6.0)
	var min_pt: Vector3 = Vector3(
		minf(entry_local.x, exit_local.x) - 2.0,
		minf(entry_local.y, exit_local.y) - 0.5,
		minf(entry_local.z, exit_local.z) - 0.5
	)
	var max_pt: Vector3 = Vector3(
		maxf(entry_local.x, exit_local.x) + 2.0,
		maxf(entry_local.y, exit_local.y) + 2.5,
		maxf(entry_local.z, exit_local.z) + 0.5
	)
	return AABB(min_pt, max_pt - min_pt)


func validate_configuration() -> bool:
	_cache_common_nodes()
	if _instance_id.strip_edges().is_empty():
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
	if params == null or typeof(params) != TYPE_DICTIONARY:
		return false
	if not _apply_obstacle_parameters(params):
		return false
	if not validate_configuration():
		return false
	_rebuild_obstacle()
	_ensure_editor_pick_body()
	reset_obstacle()
	_apply_enabled_state()
	return true


func _cache_common_nodes() -> void:
	if entry_anchor == null:
		entry_anchor = get_node_or_null(entry_anchor_path) as Marker3D
	if exit_anchor == null:
		exit_anchor = get_node_or_null(exit_anchor_path) as Marker3D
	if _entry_trigger == null:
		_entry_trigger = get_node_or_null(entry_trigger_path) as Area3D
	if _exit_trigger == null:
		_exit_trigger = get_node_or_null(exit_trigger_path) as Area3D
	if _hazard_zone == null:
		_hazard_zone = get_node_or_null(hazard_zone_path) as Area3D


func _ensure_editor_pick_body() -> void:
	if not editor_mode_active:
		if _editor_pick_body != null and is_instance_valid(_editor_pick_body):
			if _editor_pick_body.get_parent() != null:
				_editor_pick_body.get_parent().remove_child(_editor_pick_body)
			_editor_pick_body.free()
		_editor_pick_body = null
		return

	if _editor_pick_body == null or not is_instance_valid(_editor_pick_body):
		_editor_pick_body = get_node_or_null("_EditorPickBody") as StaticBody3D
	if _editor_pick_body == null:
		_editor_pick_body = StaticBody3D.new()
		_editor_pick_body.name = "_EditorPickBody"
		_editor_pick_body.collision_layer = EDITOR_PICK_LAYER
		_editor_pick_body.collision_mask = 0
		var col: CollisionShape3D = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = BoxShape3D.new()
		_editor_pick_body.add_child(col)
		add_child(_editor_pick_body)

	var bounds: AABB = get_local_bounds_aabb()
	var pick_col: CollisionShape3D = _editor_pick_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if pick_col != null and pick_col.shape is BoxShape3D:
		var box: BoxShape3D = pick_col.shape as BoxShape3D
		box.size = Vector3(
			maxf(1.0, bounds.size.x),
			maxf(1.0, bounds.size.y),
			maxf(1.0, bounds.size.z)
		)
		pick_col.position = bounds.position + bounds.size * 0.5


func _connect_triggers() -> void:
	if _entry_trigger != null and not _entry_trigger.body_entered.is_connected(_on_entry_trigger_body_entered):
		_entry_trigger.body_entered.connect(_on_entry_trigger_body_entered)
	if _exit_trigger != null and not _exit_trigger.body_entered.is_connected(_on_exit_trigger_body_entered):
		_exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)
	if _hazard_zone != null and not _hazard_zone.body_entered.is_connected(_on_hazard_zone_body_entered):
		_hazard_zone.body_entered.connect(_on_hazard_zone_body_entered)


func _apply_enabled_state() -> void:
	visible = is_enabled or editor_mode_active
	if not is_enabled:
		simulation_active = false
	process_mode = Node.PROCESS_MODE_PAUSABLE if is_enabled else Node.PROCESS_MODE_DISABLED
	_sync_collision_tree(self, is_enabled)


func _sync_collision_tree(node: Node, enabled_flag: bool) -> void:
	if node == _editor_pick_body:
		var pick_layer: int = EDITOR_PICK_LAYER if editor_mode_active else 0
		_editor_pick_body.collision_layer = pick_layer
		_editor_pick_body.collision_mask = 0
		_editor_pick_body.set_deferred("collision_layer", pick_layer)
		var pick_shape: CollisionShape3D = _editor_pick_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if pick_shape != null:
			pick_shape.disabled = not editor_mode_active
			pick_shape.set_deferred("disabled", not editor_mode_active)
		return

	if node is CollisionObject3D:
		var col_obj: CollisionObject3D = node as CollisionObject3D
		if not col_obj.has_meta(META_ORIG_LAYER):
			col_obj.set_meta(META_ORIG_LAYER, col_obj.collision_layer)
		if not col_obj.has_meta(META_ORIG_MASK):
			col_obj.set_meta(META_ORIG_MASK, col_obj.collision_mask)

		var active_gameplay_col: bool = enabled_flag and (not editor_mode_active or not (col_obj is Area3D))
		var target_layer: int = int(col_obj.get_meta(META_ORIG_LAYER)) if active_gameplay_col else 0
		var target_mask: int = int(col_obj.get_meta(META_ORIG_MASK)) if active_gameplay_col else 0
		col_obj.collision_layer = target_layer
		col_obj.collision_mask = target_mask
		col_obj.set_deferred("collision_layer", target_layer)
		col_obj.set_deferred("collision_mask", target_mask)

		if col_obj is Area3D:
			var area: Area3D = col_obj as Area3D
			if not area.has_meta(META_ORIG_MONITORING):
				area.set_meta(META_ORIG_MONITORING, area.monitoring)
			if not area.has_meta(META_ORIG_MONITORABLE):
				area.set_meta(META_ORIG_MONITORABLE, area.monitorable)
			var allow_area: bool = enabled_flag and not editor_mode_active
			var target_mon: bool = bool(area.get_meta(META_ORIG_MONITORING)) if allow_area else false
			var target_monable: bool = bool(area.get_meta(META_ORIG_MONITORABLE)) if allow_area else false
			area.set_deferred("monitoring", target_mon)
			area.set_deferred("monitorable", target_monable)

	elif node is CollisionShape3D:
		var col_shape: CollisionShape3D = node as CollisionShape3D
		var parent_is_area: bool = node.get_parent() is Area3D
		var should_disable: bool = (not enabled_flag) or (editor_mode_active and parent_is_area)
		col_shape.disabled = should_disable
		col_shape.set_deferred("disabled", should_disable)

	for child: Node in node.get_children():
		_sync_collision_tree(child, enabled_flag)


func _on_entry_trigger_body_entered(body: Node3D) -> void:
	if not is_enabled or editor_mode_active:
		return
	if body is PlayerController:
		obstacle_entered.emit(self, body as PlayerController)


func _on_exit_trigger_body_entered(body: Node3D) -> void:
	if not is_enabled or editor_mode_active:
		return
	if body is PlayerController:
		obstacle_completed.emit(self, body as PlayerController)


func _on_hazard_zone_body_entered(body: Node3D) -> void:
	if not is_enabled or editor_mode_active:
		return
	if body is PlayerController:
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


static func _has_only_known_keys(params: Dictionary, allowed_keys: Array[String]) -> bool:
	for k: Variant in params.keys():
		if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
			return false
		if not allowed_keys.has(String(k)):
			return false
	return true


static func _read_strict_float(params: Dictionary, key: String, default_val: float, out: Dictionary) -> bool:
	if not params.has(key):
		out[key] = default_val
		return true
	var raw: Variant = params[key]
	var t: int = typeof(raw)
	if t != TYPE_FLOAT and t != TYPE_INT:
		return false
	var val: float = float(raw)
	if not is_finite(val):
		return false
	out[key] = val
	return true


static func _read_strict_int(params: Dictionary, key: String, default_val: int, out: Dictionary) -> bool:
	if not params.has(key):
		out[key] = default_val
		return true
	var raw: Variant = params[key]
	var t: int = typeof(raw)
	if t == TYPE_INT:
		out[key] = int(raw)
		return true
	if t == TYPE_FLOAT:
		var f: float = float(raw)
		if not is_finite(f) or not is_equal_approx(f, roundf(f)):
			return false
		out[key] = int(roundf(f))
		return true
	return false


static func _read_strict_string(params: Dictionary, key: String, default_val: String, out: Dictionary) -> bool:
	if not params.has(key):
		out[key] = default_val
		return true
	var raw: Variant = params[key]
	if typeof(raw) != TYPE_STRING and typeof(raw) != TYPE_STRING_NAME:
		return false
	out[key] = String(raw)
	return true


static func _read_strict_vec3(params: Dictionary, key: String, default_val: Vector3, out: Dictionary) -> bool:
	if not params.has(key):
		out[key] = default_val
		return true
	var raw: Variant = params[key]
	if raw is Vector3:
		var v: Vector3 = raw as Vector3
		if not is_finite(v.x) or not is_finite(v.y) or not is_finite(v.z):
			return false
		out[key] = v
		return true
	if raw is Array:
		var arr: Array = raw as Array
		if arr.size() != 3:
			return false
		var components: Array[float] = []
		for item: Variant in arr:
			var it_type: int = typeof(item)
			if it_type != TYPE_FLOAT and it_type != TYPE_INT:
				return false
			var fv: float = float(item)
			if not is_finite(fv):
				return false
			components.append(fv)
		out[key] = Vector3(components[0], components[1], components[2])
		return true
	return false
