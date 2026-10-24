class_name ArenaValidator
extends RefCounted

## Validates serialized arena dictionaries and live StageDemoArena instances.
## Separates blocking errors from heuristic geometric/performance warnings.

const SUPPORTED_SCHEMA_VERSION: int = 1
const MAX_OBSTACLES: int = 100
const WARN_OBSTACLE_COUNT: int = 30
const WORLD_XZ_LIMIT: float = 250.0
const WORLD_Y_MIN: float = -10.0
const WORLD_Y_MAX: float = 100.0
const MIN_TIME_LIMIT_SEC: float = 10.0
const MAX_TIME_LIMIT_SEC: float = 600.0

const ROOT_KEYS: Array[String] = [
	"schema_version",
	"arena_id",
	"name",
	"theme_id",
	"time_limit_sec",
	"spawn",
	"finish",
	"obstacles",
	"route",
]

const SPAWN_KEYS: Array[String] = ["position", "rotation_y_deg"]
const FINISH_KEYS: Array[String] = ["position", "rotation_y_deg", "size"]
const OBSTACLE_KEYS: Array[String] = ["id", "type", "enabled", "position", "rotation_y_deg", "params"]


static func is_safe_identifier(id_str: String, max_len: int = 64) -> bool:
	var s: String = id_str.strip_edges()
	if s.is_empty() or s.length() > max_len or s != id_str:
		return false
	if s.contains("..") or s.contains("/") or s.contains("\\") or s.contains(":"):
		return false
	for i: int in range(s.length()):
		var code: int = s.unicode_at(i)
		var is_alpha_upper: bool = code >= 65 and code <= 90
		var is_alpha_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		var is_underscore_or_dash: bool = code == 95 or code == 45
		if not (is_alpha_upper or is_alpha_lower or is_digit or is_underscore_or_dash):
			return false
	return true


static func validate_data(raw_data: Variant, require_play_ready: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	if typeof(raw_data) != TYPE_DICTIONARY:
		errors.append("Arena data root must be a Dictionary.")
		return _make_report(errors, warnings)

	var data: Dictionary = raw_data as Dictionary
	if not ObstacleBase._has_only_known_keys(data, ROOT_KEYS):
		errors.append("Arena data contains unknown top-level keys.")

	for req_key: String in ROOT_KEYS:
		if not data.has(req_key):
			errors.append("Missing required top-level field: '%s'." % req_key)

	if not errors.is_empty():
		return _make_report(errors, warnings)

	# 1. Schema version
	var parsed_ver: Dictionary = {}
	if not ObstacleBase._read_strict_int(data, "schema_version", -1, parsed_ver):
		errors.append("Field 'schema_version' must be an integer.")
	elif int(parsed_ver["schema_version"]) != SUPPORTED_SCHEMA_VERSION:
		errors.append("Unsupported schema_version: %d (expected %d)." % [int(parsed_ver["schema_version"]), SUPPORTED_SCHEMA_VERSION])

	# 2. Arena ID, Name, Theme, Time limit
	if typeof(data["arena_id"]) != TYPE_STRING or not is_safe_identifier(String(data["arena_id"]), 64):
		errors.append("Field 'arena_id' must be a safe identifier (1..64 alphanumeric/underscore/hyphen chars).")

	if typeof(data["name"]) != TYPE_STRING:
		errors.append("Field 'name' must be a String.")
	else:
		var name_clean: String = String(data["name"]).strip_edges()
		if name_clean.is_empty() or name_clean.length() > 80:
			errors.append("Field 'name' must be 1..80 characters.")

	if typeof(data["theme_id"]) != TYPE_STRING:
		errors.append("Field 'theme_id' must be a String.")
	else:
		var theme_clean: String = String(data["theme_id"]).strip_edges()
		if theme_clean.is_empty() or theme_clean.length() > 32:
			errors.append("Field 'theme_id' must be 1..32 characters.")

	var parsed_time: Dictionary = {}
	if not ObstacleBase._read_strict_float(data, "time_limit_sec", 0.0, parsed_time):
		errors.append("Field 'time_limit_sec' must be a finite number.")
	else:
		var t_limit: float = float(parsed_time["time_limit_sec"])
		if t_limit < MIN_TIME_LIMIT_SEC or t_limit > MAX_TIME_LIMIT_SEC:
			errors.append("Field 'time_limit_sec' must be between %.1f and %.1f." % [MIN_TIME_LIMIT_SEC, MAX_TIME_LIMIT_SEC])

	# 3. Spawn
	var spawn_pos: Vector3 = Vector3.ZERO
	if typeof(data["spawn"]) != TYPE_DICTIONARY:
		errors.append("Field 'spawn' must be a Dictionary.")
	else:
		var spawn_dict: Dictionary = data["spawn"] as Dictionary
		if not ObstacleBase._has_only_known_keys(spawn_dict, SPAWN_KEYS):
			errors.append("Field 'spawn' contains unknown keys.")
		var sp_out: Dictionary = {}
		if not spawn_dict.has("position") or not ObstacleBase._read_strict_vec3(spawn_dict, "position", Vector3.ZERO, sp_out):
			errors.append("Field 'spawn.position' must be a finite 3-element vector.")
		else:
			spawn_pos = sp_out["position"] as Vector3
			if not _is_within_world_bounds(spawn_pos):
				errors.append("Field 'spawn.position' is outside allowed world bounds.")
		if not spawn_dict.has("rotation_y_deg") or not ObstacleBase._read_strict_float(spawn_dict, "rotation_y_deg", 0.0, sp_out):
			errors.append("Field 'spawn.rotation_y_deg' must be a finite number.")
		elif absf(float(sp_out["rotation_y_deg"])) > 360.0:
			errors.append("Field 'spawn.rotation_y_deg' must be within [-360, 360].")

	# 4. Finish
	var finish_pos: Vector3 = Vector3.ZERO
	if typeof(data["finish"]) != TYPE_DICTIONARY:
		errors.append("Field 'finish' must be a Dictionary.")
	else:
		var finish_dict: Dictionary = data["finish"] as Dictionary
		if not ObstacleBase._has_only_known_keys(finish_dict, FINISH_KEYS):
			errors.append("Field 'finish' contains unknown keys.")
		var fn_out: Dictionary = {}
		if not finish_dict.has("position") or not ObstacleBase._read_strict_vec3(finish_dict, "position", Vector3.ZERO, fn_out):
			errors.append("Field 'finish.position' must be a finite 3-element vector.")
		else:
			finish_pos = fn_out["position"] as Vector3
			if not _is_within_world_bounds(finish_pos):
				errors.append("Field 'finish.position' is outside allowed world bounds.")
		if not finish_dict.has("rotation_y_deg") or not ObstacleBase._read_strict_float(finish_dict, "rotation_y_deg", 0.0, fn_out):
			errors.append("Field 'finish.rotation_y_deg' must be a finite number.")
		elif absf(float(fn_out["rotation_y_deg"])) > 360.0:
			errors.append("Field 'finish.rotation_y_deg' must be within [-360, 360].")
		if not finish_dict.has("size") or not ObstacleBase._read_strict_vec3(finish_dict, "size", Vector3.ZERO, fn_out):
			errors.append("Field 'finish.size' must be a finite 3-element vector.")
		else:
			var f_size: Vector3 = fn_out["size"] as Vector3
			if f_size.x < 1.0 or f_size.y < 1.0 or f_size.z < 1.0 or f_size.x > 20.0 or f_size.y > 20.0 or f_size.z > 20.0:
				errors.append("Field 'finish.size' dimensions must be within [1.0, 20.0].")

	# 5. Obstacles
	var obstacle_map: Dictionary = {}
	var obstacle_positions: Dictionary = {}
	var obstacle_enabled_map: Dictionary = {}

	if typeof(data["obstacles"]) != TYPE_ARRAY:
		errors.append("Field 'obstacles' must be an Array.")
	else:
		var obs_array: Array = data["obstacles"] as Array
		if obs_array.size() > MAX_OBSTACLES:
			errors.append("Obstacle count (%d) exceeds maximum limit (%d)." % [obs_array.size(), MAX_OBSTACLES])
		elif obs_array.size() > WARN_OBSTACLE_COUNT:
			warnings.append("Obstacle count (%d) exceeds %d; may impact FPS on low-end PCs." % [obs_array.size(), WARN_OBSTACLE_COUNT])

		for idx: int in range(mini(obs_array.size(), MAX_OBSTACLES)):
			var raw_obs: Variant = obs_array[idx]
			if typeof(raw_obs) != TYPE_DICTIONARY:
				errors.append("Obstacle at index %d must be a Dictionary." % idx)
				continue
			var obs_dict: Dictionary = raw_obs as Dictionary
			if not ObstacleBase._has_only_known_keys(obs_dict, OBSTACLE_KEYS):
				errors.append("Obstacle at index %d contains unknown keys." % idx)
				continue
			for req_obs_key: String in OBSTACLE_KEYS:
				if not obs_dict.has(req_obs_key):
					errors.append("Obstacle at index %d is missing key '%s'." % [idx, req_obs_key])

			if not obs_dict.has("id") or typeof(obs_dict["id"]) != TYPE_STRING:
				errors.append("Obstacle at index %d has invalid 'id'." % idx)
				continue
			var inst_id: String = String(obs_dict["id"])
			if not is_safe_identifier(inst_id, 64):
				errors.append("Obstacle ID '%s' is not a safe identifier." % inst_id)
				continue
			if obstacle_map.has(inst_id):
				errors.append("Duplicate obstacle instance ID '%s'." % inst_id)
				continue

			var obs_type: String = String(obs_dict.get("type", ""))
			if typeof(obs_dict.get("type")) != TYPE_STRING or not ObstacleFactory.is_valid_type(obs_type):
				errors.append("Obstacle '%s' has unsupported type '%s'." % [inst_id, obs_type])
				continue

			if typeof(obs_dict.get("enabled")) != TYPE_BOOL:
				errors.append("Obstacle '%s' field 'enabled' must be a boolean." % inst_id)
				continue

			var tr_out: Dictionary = {}
			if not ObstacleBase._read_strict_vec3(obs_dict, "position", Vector3.ZERO, tr_out):
				errors.append("Obstacle '%s' has invalid 'position'." % inst_id)
				continue
			var obs_pos: Vector3 = tr_out["position"] as Vector3
			if not _is_within_world_bounds(obs_pos):
				errors.append("Obstacle '%s' position is outside allowed world bounds." % inst_id)
				continue

			if not ObstacleBase._read_strict_float(obs_dict, "rotation_y_deg", 0.0, tr_out):
				errors.append("Obstacle '%s' has invalid 'rotation_y_deg'." % inst_id)
				continue
			if absf(float(tr_out["rotation_y_deg"])) > 360.0:
				errors.append("Obstacle '%s' rotation_y_deg must be within [-360, 360]." % inst_id)
				continue

			if typeof(obs_dict.get("params")) != TYPE_DICTIONARY:
				errors.append("Obstacle '%s' field 'params' must be a Dictionary." % inst_id)
				continue
			var params_dict: Dictionary = obs_dict["params"] as Dictionary
			if not _validate_obstacle_parameters_for_type(obs_type, params_dict):
				errors.append("Obstacle '%s' (%s) has invalid parameters." % [inst_id, obs_type])
				continue

			obstacle_map[inst_id] = obs_dict
			obstacle_positions[inst_id] = obs_pos
			obstacle_enabled_map[inst_id] = bool(obs_dict["enabled"])

	# 6. Route validation
	var route_ids: Array[String] = []
	if typeof(data["route"]) != TYPE_ARRAY:
		errors.append("Field 'route' must be an Array.")
	else:
		var raw_route: Array = data["route"] as Array
		var seen_route: Dictionary = {}
		for r_item: Variant in raw_route:
			if typeof(r_item) != TYPE_STRING:
				errors.append("Route entries must be String obstacle IDs.")
				continue
			var rid: String = String(r_item)
			if seen_route.has(rid):
				errors.append("Duplicate route reference '%s'." % rid)
				continue
			if not obstacle_map.has(rid):
				errors.append("Route references missing or invalid obstacle ID '%s'." % rid)
				continue
			seen_route[rid] = true
			route_ids.append(rid)

		if (not obstacle_map.is_empty() or require_play_ready) and route_ids.is_empty():
			errors.append("Arena route cannot be empty when obstacles exist or when entering Test Play.")

		var enabled_in_route: int = 0
		for rid: String in route_ids:
			if bool(obstacle_enabled_map.get(rid, false)):
				enabled_in_route += 1
			else:
				if require_play_ready:
					errors.append("Required route obstacle '%s' is disabled; enable it or remove from route to Test Play." % rid)
				else:
					warnings.append("Route obstacle '%s' is disabled." % rid)

		if require_play_ready and enabled_in_route == 0:
			errors.append("Arena requires at least one enabled obstacle in route for Test Play.")

	# 7. Heuristic geometric warnings
	var obs_ids_list: Array = obstacle_positions.keys()
	for i: int in range(obs_ids_list.size()):
		for j: int in range(i + 1, obs_ids_list.size()):
			var id_a: String = String(obs_ids_list[i])
			var id_b: String = String(obs_ids_list[j])
			var pos_a: Vector3 = obstacle_positions[id_a] as Vector3
			var pos_b: Vector3 = obstacle_positions[id_b] as Vector3
			var d: float = pos_a.distance_to(pos_b)
			if d < 1.2:
				warnings.append("Obstacles '%s' and '%s' have overlapping or very close origins (%.2fm)." % [id_a, id_b, d])

	if not route_ids.is_empty() and errors.is_empty():
		var first_pos: Vector3 = obstacle_positions[route_ids[0]] as Vector3
		if spawn_pos.distance_to(first_pos) > 16.0:
			warnings.append("SpawnPoint is far (%.1fm) from first route obstacle '%s'." % [spawn_pos.distance_to(first_pos), route_ids[0]])
		var last_pos: Vector3 = obstacle_positions[route_ids[route_ids.size() - 1]] as Vector3
		if last_pos.distance_to(finish_pos) > 20.0:
			warnings.append("FinishZone is far (%.1fm) from final route obstacle '%s'." % [last_pos.distance_to(finish_pos), route_ids[route_ids.size() - 1]])
		for k: int in range(route_ids.size() - 1):
			var p0: Vector3 = obstacle_positions[route_ids[k]] as Vector3
			var p1: Vector3 = obstacle_positions[route_ids[k + 1]] as Vector3
			if p1.y - p0.y > 3.8:
				warnings.append("Large vertical climb (%.1fm) between '%s' and '%s'." % [p1.y - p0.y, route_ids[k], route_ids[k + 1]])

	return _make_report(errors, warnings)


static func validate_arena(arena: StageDemoArena, require_play_ready: bool = true) -> Dictionary:
	if arena == null:
		return _make_report(["Arena instance is null."], [])
	if not arena.has_valid_spawn_and_finish():
		return _make_report(["Arena is missing valid SpawnPoint or FinishZone."], [])
	var serialized: Dictionary = ArenaSerializer.serialize_arena(arena)
	var report: Dictionary = validate_data(serialized, require_play_ready)

	# Additional anchor gap checks using live obstacle entry/exit anchors
	if bool(report["valid"]):
		var warnings: Array[String] = report["warnings"] as Array[String]
		var route: Array[String] = arena.get_route_order()
		for i: int in range(route.size() - 1):
			var obs_curr: ObstacleBase = arena.get_obstacle_by_id(route[i])
			var obs_next: ObstacleBase = arena.get_obstacle_by_id(route[i + 1])
			if obs_curr != null and obs_next != null:
				var gap: float = obs_curr.get_exit_position().distance_to(obs_next.get_entry_position())
				if gap > 9.0:
					warnings.append(
						"Large gap (%.1fm) between exit of '%s' and entry of '%s'." % [
							gap,
							obs_curr.get_obstacle_instance_id(),
							obs_next.get_obstacle_instance_id(),
						]
					)
	return report


static func _validate_obstacle_parameters_for_type(obs_type: String, params: Dictionary) -> bool:
	var temp_obs: ObstacleBase = ObstacleFactory.create_obstacle(obs_type, "ob_validator_tmp")
	if temp_obs == null:
		return false
	var ok: bool = temp_obs._apply_obstacle_parameters(params) and temp_obs._validate_parameters()
	temp_obs.free()
	return ok


static func _is_within_world_bounds(pos: Vector3) -> bool:
	if not is_finite(pos.x) or not is_finite(pos.y) or not is_finite(pos.z):
		return false
	if absf(pos.x) > WORLD_XZ_LIMIT or absf(pos.z) > WORLD_XZ_LIMIT:
		return false
	if pos.y < WORLD_Y_MIN or pos.y > WORLD_Y_MAX:
		return false
	return true


static func _make_report(errors: Array[String], warnings: Array[String]) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
	}
