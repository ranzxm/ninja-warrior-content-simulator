extends SceneTree

func _initialize() -> void:
	var dir: DirAccess = DirAccess.create_temp("arena_preservation", true)
	assert(dir != null)
	var base: String = dir.get_current_dir()
	var data: Dictionary = {
		"schema_version": 1, "arena_id": "preservation", "name": "Original",
		"theme_id": "default", "time_limit_sec": 60,
		"spawn": {"position": [0, 0, 0], "rotation_y_deg": 0},
		"finish": {"position": [0, 0, -10], "rotation_y_deg": 0, "size": [2, 2, 2]},
		"obstacles": [], "route": [],
	}
	var target: String = base.path_join("preservation.json")
	assert(ArenaRepository.save_arena_data(data, base)["ok"])
	var original: PackedByteArray = FileAccess.get_file_as_bytes(target)
	assert(original == ArenaSerializer.to_json_string(data).to_utf8_buffer())
	data["name"] = "Replacement"
	assert(ArenaRepository.save_arena_data(data, base)["ok"])
	assert(FileAccess.get_file_as_bytes(target + ".bak") == original)
	var replacement: PackedByteArray = ArenaSerializer.to_json_string(data).to_utf8_buffer()
	assert(FileAccess.get_file_as_bytes(target) == replacement)
	assert(not FileAccess.file_exists(target + ".tmp"))
	assert(DirAccess.remove_absolute(target + ".bak") == OK)
	assert(DirAccess.make_dir_absolute(target + ".bak") == OK)
	data["name"] = "Must not overwrite"
	var result: Dictionary = ArenaRepository.save_arena_data(data, base)
	assert(not result["ok"] and not result["errors"].is_empty())
	assert(FileAccess.get_file_as_bytes(target) == replacement)
	assert(DirAccess.remove_absolute(target + ".bak") == OK)
	assert(FileAccess.set_read_only_attribute(target, true) == OK)
	result = ArenaRepository.save_arena_data(data, base)
	assert(not result["ok"] and not result["errors"].is_empty())
	assert(FileAccess.get_file_as_bytes(target) == replacement)
	assert(FileAccess.get_file_as_bytes(target + ".bak") == replacement)
	assert(FileAccess.set_read_only_attribute(target, false) == OK)
	assert(DirAccess.remove_absolute(target + ".tmp") == OK)
	assert(DirAccess.make_dir_absolute(target + ".tmp") == OK)
	result = ArenaRepository.save_arena_data(data, base)
	assert(not result["ok"] and not result["errors"].is_empty())
	assert(FileAccess.get_file_as_bytes(target) == replacement)
	assert(DirAccess.remove_absolute(target + ".tmp") == OK)
	assert(DirAccess.remove_absolute(target + ".bak") == OK)
	assert(DirAccess.remove_absolute(target) == OK)
	dir = null
	assert(DirAccess.remove_absolute(base) == OK)
	print("ARENA_REPOSITORY_PRESERVATION: PASS (exact bytes, backup failure, rename failure, temporary open failure)")
	quit()
