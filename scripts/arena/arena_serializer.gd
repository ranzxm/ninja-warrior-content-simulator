class_name ArenaSerializer
extends RefCounted

## Converts StageDemoArena state to/from validated schema_version=1 JSON dictionaries.
## Performs atomic staging on load so failed loads never corrupt the currently active arena.

const SCHEMA_VERSION: int = 1
const MAX_JSON_BYTES: int = 524288 # 512 KB


static func serialize_arena(arena: StageDemoArena) -> Dictionary:
	if arena == null:
		return {}

	var spawn_pos: Vector3 = arena.get_spawn_position()
	var finish_pos: Vector3 = arena.get_finish_position()
	var finish_size: Vector3 = arena.get_finish_size()

	var serialized_obstacles: Array = []
	for obs: ObstacleBase in arena.get_obstacles():
		if not is_instance_valid(obs):
			continue
		var pos: Vector3 = obs.position
		serialized_obstacles.append({
			"id": obs.get_obstacle_instance_id(),
			"type": obs.get_obstacle_type(),
			"enabled": obs.is_enabled,
			"position": [pos.x, pos.y, pos.z],
			"rotation_y_deg": rad_to_deg(obs.rotation.y),
			"params": obs.get_parameters().duplicate(true),
		})

	var route_copy: Array = []
	for rid: String in arena.get_route_order():
		route_copy.append(rid)

	return {
		"schema_version": SCHEMA_VERSION,
		"arena_id": arena.stage_id,
		"name": arena.stage_name,
		"theme_id": arena.theme_id,
		"time_limit_sec": arena.time_limit_sec,
		"spawn": {
			"position": [spawn_pos.x, spawn_pos.y, spawn_pos.z],
			"rotation_y_deg": arena.get_spawn_rotation_y_deg(),
		},
		"finish": {
			"position": [finish_pos.x, finish_pos.y, finish_pos.z],
			"rotation_y_deg": arena.get_finish_rotation_y_deg(),
			"size": [finish_size.x, finish_size.y, finish_size.z],
		},
		"obstacles": serialized_obstacles,
		"route": route_copy,
	}


static func to_json_string(data: Dictionary) -> String:
	var report: Dictionary = ArenaValidator.validate_data(data, false)
	if not bool(report["valid"]):
		return ""
	return JSON.stringify(data, "  ")


static func from_json_string(json_text: String, require_play_ready: bool = false) -> Dictionary:
	var errors: Array[String] = []
	if json_text.is_empty():
		errors.append("JSON text is empty.")
		return {"ok": false, "data": {}, "errors": errors, "warnings": []}

	if json_text.to_utf8_buffer().size() > MAX_JSON_BYTES:
		errors.append("JSON payload exceeds maximum size (%d bytes)." % MAX_JSON_BYTES)
		return {"ok": false, "data": {}, "errors": errors, "warnings": []}

	var parser: JSON = JSON.new()
	var err: Error = parser.parse(json_text)
	if err != OK:
		errors.append("Malformed JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return {"ok": false, "data": {}, "errors": errors, "warnings": []}

	var raw_data: Variant = parser.data
	var report: Dictionary = ArenaValidator.validate_data(raw_data, require_play_ready)
	if not bool(report["valid"]):
		return {
			"ok": false,
			"data": {},
			"errors": report["errors"],
			"warnings": report["warnings"],
		}

	return {
		"ok": true,
		"data": raw_data as Dictionary,
		"errors": [],
		"warnings": report["warnings"],
	}


static func apply_data_to_arena(
	arena: StageDemoArena,
	data: Dictionary,
	require_play_ready: bool = false
) -> Dictionary:
	if arena == null:
		return {"ok": false, "errors": ["Target StageDemoArena is null."], "warnings": []}

	var report: Dictionary = ArenaValidator.validate_data(data, require_play_ready)
	if not bool(report["valid"]):
		return {
			"ok": false,
			"errors": report["errors"],
			"warnings": report["warnings"],
		}

	# Build candidate obstacles in memory first so any failure leaves active arena untouched
	var candidate_obstacles: Array[ObstacleBase] = []
	var obs_entries: Array = data["obstacles"] as Array
	for item: Variant in obs_entries:
		var obs_dict: Dictionary = item as Dictionary
		var inst_id: String = String(obs_dict["id"])
		var obs_type: String = String(obs_dict["type"])
		var candidate: ObstacleBase = ObstacleFactory.create_obstacle(obs_type, inst_id)
		if candidate == null:
			_free_candidates(candidate_obstacles)
			return {"ok": false, "errors": ["Failed to instantiate obstacle type: " + obs_type], "warnings": []}

		var pos_out: Dictionary = {}
		ObstacleBase._read_strict_vec3(obs_dict, "position", Vector3.ZERO, pos_out)
		var rot_out: Dictionary = {}
		ObstacleBase._read_strict_float(obs_dict, "rotation_y_deg", 0.0, rot_out)

		candidate.position = pos_out["position"] as Vector3
		candidate.rotation = Vector3(0.0, deg_to_rad(float(rot_out["rotation_y_deg"])), 0.0)
		candidate.is_enabled = bool(obs_dict["enabled"])

		var params_dict: Dictionary = obs_dict["params"] as Dictionary
		if not candidate.apply_parameters(params_dict):
			candidate.free()
			_free_candidates(candidate_obstacles)
			return {"ok": false, "errors": ["Failed to apply parameters for obstacle: " + inst_id], "warnings": []}

		candidate_obstacles.append(candidate)

	# Commit atomically to arena
	var spawn_dict: Dictionary = data["spawn"] as Dictionary
	var sp_out: Dictionary = {}
	ObstacleBase._read_strict_vec3(spawn_dict, "position", Vector3.ZERO, sp_out)
	ObstacleBase._read_strict_float(spawn_dict, "rotation_y_deg", 0.0, sp_out)

	var finish_dict: Dictionary = data["finish"] as Dictionary
	var fn_out: Dictionary = {}
	ObstacleBase._read_strict_vec3(finish_dict, "position", Vector3.ZERO, fn_out)
	ObstacleBase._read_strict_float(finish_dict, "rotation_y_deg", 0.0, fn_out)
	ObstacleBase._read_strict_vec3(finish_dict, "size", Vector3(4.6, 2.8, 3.6), fn_out)

	arena.clear_all_obstacles()
	arena.stage_id = String(data["arena_id"])
	arena.stage_name = String(data["name"])
	arena.theme_id = String(data["theme_id"])
	arena.time_limit_sec = float(data["time_limit_sec"])
	arena.set_spawn_transform_data(sp_out["position"] as Vector3, float(sp_out["rotation_y_deg"]))
	arena.set_finish_transform_data(
		fn_out["position"] as Vector3,
		float(fn_out["rotation_y_deg"]),
		fn_out["size"] as Vector3
	)

	for cand: ObstacleBase in candidate_obstacles:
		arena.add_obstacle_instance(cand, false)

	var route_typed: Array[String] = []
	for r_item: Variant in (data["route"] as Array):
		route_typed.append(String(r_item))
	arena.set_route_order(route_typed)

	var keep_demo_decks: bool = (arena.stage_id == "stage_01_demo" and candidate_obstacles.size() == 6)
	arena.set_connector_decks_enabled(keep_demo_decks)

	return {
		"ok": true,
		"errors": [],
		"warnings": report["warnings"],
	}


static func _free_candidates(list: Array[ObstacleBase]) -> void:
	for c: ObstacleBase in list:
		if is_instance_valid(c):
			c.free()
	list.clear()
