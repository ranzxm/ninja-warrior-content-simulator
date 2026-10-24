class_name ArenaRepository
extends RefCounted

## Manages atomic JSON persistence, backups, path sanitization, and listing in user://arenas/.

const DEFAULT_ARENA_DIR: String = "user://arenas"
const MAX_FILE_SIZE_BYTES: int = 524288 # 512 KB


static func is_safe_arena_id(arena_id: String) -> bool:
	return ArenaValidator.is_safe_identifier(arena_id, 64)


static func sanitize_arena_id(raw_text: String) -> String:
	var lowered: String = raw_text.strip_edges().to_lower()
	var result: String = ""
	for i: int in range(lowered.length()):
		var code: int = lowered.unicode_at(i)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if is_lower or is_digit or code == 95 or code == 45:
			result += char(code)
		elif code == 32:
			result += "_"
	if result.length() > 64:
		result = result.substr(0, 64)
	return result


static func get_arena_file_path(arena_id: String, base_dir: String = DEFAULT_ARENA_DIR) -> String:
	if not is_safe_arena_id(arena_id):
		return ""
	return "%s/%s.json" % [base_dir.trim_suffix("/"), arena_id]


static func ensure_arena_dir(base_dir: String = DEFAULT_ARENA_DIR) -> bool:
	var global_dir: String = ProjectSettings.globalize_path(base_dir)
	if DirAccess.dir_exists_absolute(global_dir):
		return true
	return DirAccess.make_dir_recursive_absolute(global_dir) == OK


static func list_saved_arenas(base_dir: String = DEFAULT_ARENA_DIR) -> Array[String]:
	var arenas: Array[String] = []
	if not ensure_arena_dir(base_dir):
		return arenas
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return arenas

	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while not fname.is_empty():
		if not dir.current_is_dir() and fname.ends_with(".json") and not fname.ends_with(".tmp") and not fname.ends_with(".bak"):
			var id_part: String = fname.substr(0, fname.length() - 5)
			if is_safe_arena_id(id_part):
				arenas.append(id_part)
		fname = dir.get_next()
	dir.list_dir_end()
	arenas.sort()
	return arenas


static func save_arena_data(data: Dictionary, base_dir: String = DEFAULT_ARENA_DIR) -> Dictionary:
	var report: Dictionary = ArenaValidator.validate_data(data, false)
	if not bool(report["valid"]):
		return {
			"ok": false,
			"path": "",
			"errors": report["errors"],
			"warnings": report["warnings"],
		}

	var arena_id: String = String(data.get("arena_id", ""))
	if not is_safe_arena_id(arena_id):
		return {
			"ok": false,
			"path": "",
			"errors": ["Unsafe arena_id rejected: " + arena_id],
			"warnings": [],
		}

	var json_str: String = ArenaSerializer.to_json_string(data)
	if json_str.is_empty():
		return {
			"ok": false,
			"path": "",
			"errors": ["Failed to serialize arena data to JSON."],
			"warnings": [],
		}

	var bytes: PackedByteArray = json_str.to_utf8_buffer()
	if bytes.size() > MAX_FILE_SIZE_BYTES:
		return {
			"ok": false,
			"path": "",
			"errors": ["Serialized arena exceeds maximum allowed file size."],
			"warnings": [],
		}

	if not ensure_arena_dir(base_dir):
		return {
			"ok": false,
			"path": "",
			"errors": ["Could not create arena directory: " + base_dir],
			"warnings": [],
		}

	var target_path: String = get_arena_file_path(arena_id, base_dir)
	var tmp_path: String = target_path + ".tmp"
	var bak_path: String = target_path + ".bak"

	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		return {
			"ok": false,
			"path": "",
			"errors": ["Could not open temporary file for writing: " + tmp_path],
			"warnings": [],
		}
	tmp_file.store_string(json_str)
	tmp_file.flush()
	tmp_file = null

	# Verify temporary file integrity before replacing existing file
	var check_read: String = FileAccess.get_file_as_string(tmp_path)
	var verify_parsed: Dictionary = ArenaSerializer.from_json_string(check_read, false)
	if not bool(verify_parsed["ok"]):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return {
			"ok": false,
			"path": "",
			"errors": ["Temporary save file verification failed."],
			"warnings": [],
		}

	# Rotate existing valid file to .bak before replacing
	if FileAccess.file_exists(target_path):
		var existing_text: String = FileAccess.get_file_as_string(target_path)
		var bak_file: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
		if bak_file != null:
			bak_file.store_string(existing_text)
			bak_file.flush()
			bak_file = null

	var final_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if final_file == null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
		return {
			"ok": false,
			"path": "",
			"errors": ["Could not write final arena file: " + target_path],
			"warnings": [],
		}
	final_file.store_string(json_str)
	final_file.flush()
	final_file = null

	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	return {
		"ok": true,
		"path": target_path,
		"errors": [],
		"warnings": report["warnings"],
	}


static func save_arena_as(
	data: Dictionary,
	new_arena_id: String,
	new_name: String = "",
	base_dir: String = DEFAULT_ARENA_DIR
) -> Dictionary:
	if not is_safe_arena_id(new_arena_id):
		return {
			"ok": false,
			"path": "",
			"errors": ["Invalid or unsafe Save As arena_id: '%s'." % new_arena_id],
			"warnings": [],
		}
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"path": "",
			"errors": ["Arena data must be a Dictionary."],
			"warnings": [],
		}
	var cloned: Dictionary = data.duplicate(true)
	cloned["arena_id"] = new_arena_id
	if not new_name.strip_edges().is_empty():
		cloned["name"] = new_name.strip_edges()
	return save_arena_data(cloned, base_dir)


static func load_arena_data(
	arena_id: String,
	base_dir: String = DEFAULT_ARENA_DIR,
	require_play_ready: bool = false
) -> Dictionary:
	if not is_safe_arena_id(arena_id):
		return {
			"ok": false,
			"data": {},
			"errors": ["Unsafe or invalid arena_id rejected: '%s'." % arena_id],
			"warnings": [],
		}

	var target_path: String = get_arena_file_path(arena_id, base_dir)
	if not FileAccess.file_exists(target_path):
		return {
			"ok": false,
			"data": {},
			"errors": ["Arena file does not exist: " + target_path],
			"warnings": [],
		}

	var f: FileAccess = FileAccess.open(target_path, FileAccess.READ)
	if f == null:
		return {
			"ok": false,
			"data": {},
			"errors": ["Unable to open arena file: " + target_path],
			"warnings": [],
		}
	var byte_len: int = f.get_length()
	if byte_len > MAX_FILE_SIZE_BYTES:
		f = null
		return {
			"ok": false,
			"data": {},
			"errors": ["Arena file exceeds maximum size (%d > %d bytes)." % [byte_len, MAX_FILE_SIZE_BYTES]],
			"warnings": [],
		}
	var content: String = f.get_as_text()
	f = null

	return ArenaSerializer.from_json_string(content, require_play_ready)
