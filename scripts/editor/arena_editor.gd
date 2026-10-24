class_name ArenaEditor
extends Control

## In-game 3D Arena Editor controller and UI coordinator for M1b.
## Handles obstacle palette, ghost placement, raycast selection, transform editing,
## dynamic parameter inspector, route ordering, spawn/finish editing, validation, and JSON persistence.

signal test_play_requested()
signal exit_editor_requested()
signal status_message_changed(message: String, is_error: bool)

const MAX_UNDO_STEPS: int = 25

var snap_enabled: bool = true
var grid_size: float = 0.5
var snap_rotation_deg: float = 15.0
var placement_height: float = 0.0
var is_dirty: bool = false
var arena_storage_dir: String = ArenaRepository.DEFAULT_ARENA_DIR

var _arena: StageDemoArena = null
var _editor_camera: EditorCamera = null
var _active: bool = false
var _selected_obstacle: ObstacleBase = null
var _pending_placement_type: String = ""
var _placement_ghost: MeshInstance3D = null
var _selection_highlight: MeshInstance3D = null
var _dragging_selected: bool = false
var _suppress_inspector_callbacks: bool = false
var _pending_discard_action: String = ""
var _pending_load_id: String = ""

var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []

# UI Node references (built in _ready or resolved from scene)
var _toolbar_arena_name_edit: LineEdit = null
var _toolbar_arena_id_edit: LineEdit = null
var _toolbar_time_limit_spin: SpinBox = null
var _snap_checkbox: CheckBox = null
var _grid_spin: SpinBox = null
var _palette_container: VBoxContainer = null
var _inspector_title_label: Label = null
var _pos_x_spin: SpinBox = null
var _pos_y_spin: SpinBox = null
var _pos_z_spin: SpinBox = null
var _rot_y_spin: SpinBox = null
var _enabled_checkbox: CheckBox = null
var _params_container: VBoxContainer = null
var _route_list: ItemList = null
var _spawn_x_spin: SpinBox = null
var _spawn_y_spin: SpinBox = null
var _spawn_z_spin: SpinBox = null
var _spawn_rot_spin: SpinBox = null
var _finish_x_spin: SpinBox = null
var _finish_y_spin: SpinBox = null
var _finish_z_spin: SpinBox = null
var _finish_rot_spin: SpinBox = null
var _finish_sx_spin: SpinBox = null
var _finish_sy_spin: SpinBox = null
var _finish_sz_spin: SpinBox = null
var _status_label: Label = null
var _dirty_label: Label = null
var _validation_label: RichTextLabel = null
var _file_dialog_panel: PanelContainer = null
var _file_list: ItemList = null
var _save_as_id_edit: LineEdit = null
var _save_as_name_edit: LineEdit = null
var _confirm_discard_dialog: ConfirmationDialog = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_editor_ui_if_needed()
	_refresh_palette_ui()
	_refresh_all_ui()


func setup(arena: StageDemoArena, editor_camera: EditorCamera) -> void:
	_arena = arena
	_editor_camera = editor_camera
	_ensure_3d_helpers()
	_refresh_all_ui()


func set_editor_active(active: bool) -> void:
	_active = active
	visible = active
	if not active:
		cancel_placement()
		_dragging_selected = false
		if _selection_highlight != null:
			_selection_highlight.visible = false
		if _file_dialog_panel != null:
			_file_dialog_panel.visible = false
	else:
		_ensure_3d_helpers()
		_update_selection_highlight()
		_refresh_all_ui()


func is_editor_active() -> bool:
	return _active


func get_selected_obstacle() -> ObstacleBase:
	if is_instance_valid(_selected_obstacle):
		return _selected_obstacle
	_selected_obstacle = null
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _arena == null:
		return

	if _is_text_entry_focused():
		if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_ESCAPE:
				if not _pending_placement_type.is_empty():
					cancel_placement()
					get_viewport().set_input_as_handled()
					return
				elif _file_dialog_panel != null and _file_dialog_panel.visible:
					_file_dialog_panel.visible = false
					get_viewport().set_input_as_handled()
					return
			elif ke.keycode == KEY_DELETE:
				if get_selected_obstacle() != null:
					delete_selected_obstacle()
					get_viewport().set_input_as_handled()
					return
			elif ke.keycode == KEY_F:
				focus_camera_on_selection()
				get_viewport().set_input_as_handled()
				return
			elif ke.ctrl_pressed and ke.keycode == KEY_D:
				if get_selected_obstacle() != null:
					duplicate_selected_obstacle()
					get_viewport().set_input_as_handled()
					return
			elif ke.ctrl_pressed and ke.keycode == KEY_S:
				save_current_arena(arena_storage_dir)
				get_viewport().set_input_as_handled()
				return
			elif ke.ctrl_pressed and ke.keycode == KEY_Z:
				undo()
				get_viewport().set_input_as_handled()
				return
			elif ke.ctrl_pressed and ke.keycode == KEY_Y:
				redo()
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_Q and get_selected_obstacle() != null:
				rotate_selected_obstacle(rad_to_deg(get_selected_obstacle().rotation.y) - snap_rotation_deg, false)
				get_viewport().set_input_as_handled()
				return
			elif ke.keycode == KEY_E and get_selected_obstacle() != null:
				rotate_selected_obstacle(rad_to_deg(get_selected_obstacle().rotation.y) + snap_rotation_deg, false)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if not _pending_placement_type.is_empty():
			_update_ghost_from_screen(mm.position)
		elif _dragging_selected and get_selected_obstacle() != null:
			var drag_pos: Vector3 = _project_screen_to_plane(mm.position, get_selected_obstacle().position.y)
			if is_finite(drag_pos.x):
				move_selected_obstacle(drag_pos, true)

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _is_point_over_ui_panel(mb.position):
					return
				if not _pending_placement_type.is_empty():
					var target_pos: Vector3 = _project_screen_to_plane(mb.position, placement_height)
					if is_finite(target_pos.x):
						place_obstacle_at(_pending_placement_type, target_pos, 0.0, true)
					get_viewport().set_input_as_handled()
				else:
					var picked: ObstacleBase = select_at_screen_position(mb.position)
					_dragging_selected = (picked != null and mb.shift_pressed)
			else:
				_dragging_selected = false


# --- Core Editing Operations ---

func create_new_arena(
	new_id: String = "custom_arena_001",
	new_name: String = "Custom Ninja Course",
	force_discard: bool = false
) -> bool:
	if _arena == null:
		return false
	if is_dirty and not force_discard:
		_pending_discard_action = "new"
		if _confirm_discard_dialog != null:
			_confirm_discard_dialog.dialog_text = "Discard unsaved arena changes and create a new arena?"
			_confirm_discard_dialog.popup_centered()
		_set_status("Unsaved changes present. Confirm discard before creating a new arena.", true)
		return false

	var clean_id: String = ArenaRepository.sanitize_arena_id(new_id)
	if not ArenaRepository.is_safe_arena_id(clean_id):
		clean_id = "custom_arena_001"

	_undo_stack.clear()
	_redo_stack.clear()
	cancel_placement()
	select_obstacle(null)

	_arena.clear_all_obstacles()
	_arena.stage_id = clean_id
	_arena.stage_name = new_name.strip_edges() if not new_name.strip_edges().is_empty() else "Custom Ninja Course"
	_arena.theme_id = "default"
	_arena.time_limit_sec = 120.0
	_arena.set_connector_decks_enabled(false)
	_arena.set_spawn_transform_data(Vector3(0.0, 0.0, 2.4), 0.0)
	_arena.set_finish_transform_data(Vector3(0.0, 1.5, -24.0), 0.0, Vector3(4.6, 2.8, 3.6))
	_arena.set_editor_mode(_active)

	is_dirty = false
	_refresh_all_ui()
	_set_status("Created new arena '%s'." % _arena.stage_id, false)
	return true


func begin_placement(obstacle_type: String) -> bool:
	if not ObstacleFactory.is_valid_type(obstacle_type):
		_set_status("Unsupported obstacle type: %s" % obstacle_type, true)
		return false
	_pending_placement_type = obstacle_type
	_ensure_3d_helpers()
	if _placement_ghost != null:
		_placement_ghost.visible = true
		var col: Color = ObstacleFactory.get_indicator_color(obstacle_type)
		col.a = 0.45
		if _placement_ghost.material_override is StandardMaterial3D:
			(_placement_ghost.material_override as StandardMaterial3D).albedo_color = col
	_set_status("Placement mode: %s (Left-click 3D view to place, Esc to cancel)" % ObstacleFactory.get_display_name(obstacle_type), false)
	return true


func cancel_placement() -> void:
	_pending_placement_type = ""
	if _placement_ghost != null:
		_placement_ghost.visible = false
	_set_status("Placement cancelled.", false)


func place_obstacle_at(
	type_name: String,
	world_pos: Vector3,
	rot_y_deg: float = 0.0,
	use_snap: bool = true
) -> ObstacleBase:
	if _arena == null:
		return null
	if not ObstacleFactory.is_valid_type(type_name):
		_set_status("Invalid obstacle type: %s" % type_name, true)
		return null
	if _arena.get_obstacle_count() >= ArenaValidator.MAX_OBSTACLES:
		_set_status("Maximum obstacle limit (%d) reached." % ArenaValidator.MAX_OBSTACLES, true)
		return null
	if not is_finite(world_pos.x) or not is_finite(world_pos.y) or not is_finite(world_pos.z) or not is_finite(rot_y_deg):
		_set_status("Invalid non-finite placement transform.", true)
		return null

	var final_pos: Vector3 = snap_vector3(world_pos) if (use_snap and snap_enabled) else world_pos
	if not ArenaValidator._is_within_world_bounds(final_pos):
		_set_status("Placement position outside world bounds.", true)
		return null

	_push_undo_snapshot()
	var instance: ObstacleBase = ObstacleFactory.create_obstacle(type_name)
	if instance == null:
		return null

	instance.position = final_pos
	instance.rotation = Vector3(0.0, deg_to_rad(clampf(rot_y_deg, -360.0, 360.0)), 0.0)
	if not _arena.add_obstacle_instance(instance, true):
		instance.free()
		return null

	instance.reset_obstacle()
	instance.set_editor_mode(_active)
	is_dirty = true
	select_obstacle(instance)
	_refresh_all_ui()
	_set_status("Placed %s [%s]." % [instance.display_name, instance.get_obstacle_instance_id()], false)
	return instance


func select_at_screen_position(screen_pos: Vector2) -> ObstacleBase:
	if _arena == null or _editor_camera == null:
		return null
	var cam: Camera3D = _editor_camera.get_camera()
	if cam == null or _arena.get_world_3d() == null:
		return null

	var ray_origin: Vector3 = cam.project_ray_origin(screen_pos)
	var ray_normal: Vector3 = cam.project_ray_normal(screen_pos)
	var ray_end: Vector3 = ray_origin + ray_normal * 250.0

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		1 | 4 | ObstacleBase.EDITOR_PICK_LAYER
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var hit: Dictionary = _arena.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("collider"):
		select_obstacle(null)
		return null

	var collider_node: Node = hit["collider"] as Node
	var resolved: ObstacleBase = resolve_owning_obstacle(collider_node)
	select_obstacle(resolved)
	return resolved


static func resolve_owning_obstacle(node: Node) -> ObstacleBase:
	var cur: Node = node
	while cur != null:
		if cur is ObstacleBase:
			return cur as ObstacleBase
		cur = cur.get_parent()
	return null


func select_obstacle(obs: ObstacleBase) -> void:
	if obs != null and not is_instance_valid(obs):
		obs = null
	_selected_obstacle = obs
	_update_selection_highlight()
	_refresh_inspector_ui()
	_refresh_route_selection_ui()
	if _selected_obstacle != null:
		_set_status(
			"Selected: %s [%s]" % [_selected_obstacle.display_name, _selected_obstacle.get_obstacle_instance_id()],
			false
		)
	else:
		_set_status("Selection cleared.", false)


func focus_camera_on_selection() -> void:
	if _editor_camera == null:
		return
	var sel: ObstacleBase = get_selected_obstacle()
	if sel != null:
		_editor_camera.focus_on(sel.global_position, 14.0)
	elif _arena != null:
		_editor_camera.focus_on(_arena.get_spawn_position(), 18.0)


func snap_vector3(pos: Vector3) -> Vector3:
	if not snap_enabled or grid_size <= 0.001:
		return pos
	return Vector3(
		snappedf(pos.x, grid_size),
		snappedf(pos.y, grid_size),
		snappedf(pos.z, grid_size)
	)


func move_selected_obstacle(new_pos: Vector3, apply_snap: bool = false) -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		return false
	if not is_finite(new_pos.x) or not is_finite(new_pos.y) or not is_finite(new_pos.z):
		_set_status("Rejected non-finite position.", true)
		return false

	var target_pos: Vector3 = snap_vector3(new_pos) if (apply_snap and snap_enabled) else new_pos
	if not ArenaValidator._is_within_world_bounds(target_pos):
		_set_status("Position outside allowed world bounds.", true)
		return false

	_push_undo_snapshot()
	sel.position = target_pos
	sel.reset_obstacle()
	sel.set_editor_mode(_active)
	is_dirty = true
	_update_selection_highlight()
	_refresh_transform_spinboxes()
	_refresh_status_bar()
	return true


func rotate_selected_obstacle(new_rot_y_deg: float, apply_snap: bool = false) -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		return false
	if not is_finite(new_rot_y_deg) or absf(new_rot_y_deg) > 360.0:
		_set_status("Rotation Y must be a finite angle in [-360, 360].", true)
		return false

	var target_deg: float = snappedf(new_rot_y_deg, snap_rotation_deg) if (apply_snap and snap_enabled) else new_rot_y_deg
	target_deg = clampf(target_deg, -360.0, 360.0)

	_push_undo_snapshot()
	sel.rotation = Vector3(0.0, deg_to_rad(target_deg), 0.0)
	sel.reset_obstacle()
	sel.set_editor_mode(_active)
	is_dirty = true
	_update_selection_highlight()
	_refresh_transform_spinboxes()
	_refresh_status_bar()
	return true


func reset_selected_position() -> bool:
	return move_selected_obstacle(Vector3.ZERO, false)


func reset_selected_rotation() -> bool:
	return rotate_selected_obstacle(0.0, false)


func update_selected_parameter(param_key: String, param_value: Variant) -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		return false
	var current_params: Dictionary = sel.get_parameters().duplicate(true)
	if not current_params.has(param_key):
		_set_status("Unknown parameter '%s' for %s." % [param_key, sel.get_obstacle_type()], true)
		return false
	current_params[param_key] = param_value
	return update_selected_parameters(current_params)


func update_selected_parameters(new_params: Dictionary) -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null or new_params == null or typeof(new_params) != TYPE_DICTIONARY:
		return false

	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not sel.apply_parameters(new_params):
		_set_status("Invalid parameter value rejected for '%s'." % sel.get_obstacle_instance_id(), true)
		_refresh_inspector_ui()
		return false

	_record_snapshot(snapshot)
	sel.set_editor_mode(_active)
	is_dirty = true
	_update_selection_highlight()
	_refresh_inspector_ui()
	_refresh_status_bar()
	_set_status("Updated parameters for %s [%s]." % [sel.display_name, sel.get_obstacle_instance_id()], false)
	return true


func set_selected_obstacle_enabled(enabled_flag: bool) -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		return false
	_push_undo_snapshot()
	sel.is_enabled = enabled_flag
	sel.set_editor_mode(_active)
	is_dirty = true
	_refresh_route_ui()
	_refresh_status_bar()
	return true


func duplicate_selected_obstacle(offset: Vector3 = Vector3(1.5, 0.0, -2.0)) -> ObstacleBase:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null or _arena == null:
		return null
	if _arena.get_obstacle_count() >= ArenaValidator.MAX_OBSTACLES:
		_set_status("Cannot duplicate: maximum obstacle count (%d) reached." % ArenaValidator.MAX_OBSTACLES, true)
		return null

	_push_undo_snapshot()
	var dup: ObstacleBase = ObstacleFactory.create_obstacle(sel.get_obstacle_type())
	if dup == null:
		return null

	var target_pos: Vector3 = sel.position + offset
	target_pos.x = clampf(target_pos.x, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	target_pos.z = clampf(target_pos.z, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	target_pos.y = clampf(target_pos.y, ArenaValidator.WORLD_Y_MIN, ArenaValidator.WORLD_Y_MAX)

	dup.position = snap_vector3(target_pos) if snap_enabled else target_pos
	dup.rotation = sel.rotation
	dup.is_enabled = sel.is_enabled
	dup.apply_parameters(sel.get_parameters().duplicate(true))

	if not _arena.add_obstacle_instance(dup, true):
		dup.free()
		return null

	dup.reset_obstacle()
	dup.set_editor_mode(_active)
	is_dirty = true
	select_obstacle(dup)
	_refresh_all_ui()
	_set_status("Duplicated %s -> [%s]." % [sel.get_obstacle_instance_id(), dup.get_obstacle_instance_id()], false)
	return dup


func delete_selected_obstacle() -> bool:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null or _arena == null:
		return false

	_push_undo_snapshot()
	var deleted_id: String = sel.get_obstacle_instance_id()
	_selected_obstacle = null
	var removed: bool = _arena.remove_obstacle_by_id(deleted_id)
	if not removed:
		return false

	is_dirty = true
	_update_selection_highlight()
	_refresh_all_ui()
	_set_status("Deleted obstacle [%s]." % deleted_id, false)
	return true


func set_spawn_transform(pos: Vector3, rot_y_deg: float) -> bool:
	if _arena == null:
		return false
	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not _arena.set_spawn_transform_data(pos, rot_y_deg):
		_set_status("Invalid SpawnPoint transform rejected.", true)
		_refresh_spawn_finish_ui()
		return false
	_record_snapshot(snapshot)
	is_dirty = true
	_refresh_spawn_finish_ui()
	_refresh_status_bar()
	_set_status("Updated SpawnPoint transform.", false)
	return true


func set_finish_transform(pos: Vector3, rot_y_deg: float, size: Vector3) -> bool:
	if _arena == null:
		return false
	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not _arena.set_finish_transform_data(pos, rot_y_deg, size):
		_set_status("Invalid FinishZone transform/size rejected.", true)
		_refresh_spawn_finish_ui()
		return false
	_record_snapshot(snapshot)
	is_dirty = true
	_refresh_spawn_finish_ui()
	_refresh_status_bar()
	_set_status("Updated FinishZone transform.", false)
	return true


func move_route_obstacle(inst_id: String, delta_index: int) -> bool:
	if _arena == null:
		return false
	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not _arena.move_route_item(inst_id, delta_index):
		return false
	_record_snapshot(snapshot)
	is_dirty = true
	_refresh_route_ui()
	_refresh_status_bar()
	return true


func set_custom_route_order(new_route: Array[String]) -> bool:
	if _arena == null:
		return false
	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not _arena.set_route_order(new_route):
		_set_status("Invalid route order rejected.", true)
		return false
	_record_snapshot(snapshot)
	is_dirty = true
	_refresh_route_ui()
	_refresh_status_bar()
	return true


func set_arena_metadata(new_id: String, new_name: String, new_time_limit_sec: float) -> bool:
	if _arena == null:
		return false
	if not ArenaValidator.is_safe_identifier(new_id, 64):
		_set_status("Invalid arena ID format.", true)
		return false
	var clean_name: String = new_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 80:
		_set_status("Arena name must be 1..80 characters.", true)
		return false
	if not is_finite(new_time_limit_sec) or new_time_limit_sec < ArenaValidator.MIN_TIME_LIMIT_SEC or new_time_limit_sec > ArenaValidator.MAX_TIME_LIMIT_SEC:
		_set_status("Time limit must be between 10 and 600 seconds.", true)
		return false

	_push_undo_snapshot()
	_arena.stage_id = new_id
	_arena.stage_name = clean_name
	_arena.time_limit_sec = new_time_limit_sec
	is_dirty = true
	_refresh_all_ui()
	return true


# --- Validation & Persistence ---

func validate_current_arena(require_play_ready: bool = true) -> Dictionary:
	if _arena == null:
		return {"valid": false, "errors": ["Arena is null."], "warnings": []}
	var report: Dictionary = ArenaValidator.validate_arena(_arena, require_play_ready)
	_display_validation_report(report)
	if bool(report["valid"]):
		var warn_cnt: int = (report["warnings"] as Array).size()
		_set_status("Arena validation passed (%d warning(s))." % warn_cnt, false)
	else:
		var err_list: Array = report["errors"] as Array
		_set_status("Validation failed: %s" % String(err_list[0]), true)
	return report


func save_current_arena(base_dir: String = "") -> Dictionary:
	if _arena == null:
		return {"ok": false, "errors": ["Arena is null."], "warnings": []}
	var target_dir: String = base_dir if not base_dir.is_empty() else arena_storage_dir
	var data: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var res: Dictionary = ArenaRepository.save_arena_data(data, target_dir)
	if bool(res["ok"]):
		is_dirty = false
		_refresh_status_bar()
		_set_status("Saved arena '%s' to %s" % [_arena.stage_id, String(res["path"])], false)
	else:
		var errs: Array = res["errors"] as Array
		_set_status("Save failed: %s" % (String(errs[0]) if not errs.is_empty() else "Unknown error"), true)
	return res


func save_current_arena_as(
	new_arena_id: String,
	new_name: String = "",
	base_dir: String = ""
) -> Dictionary:
	if _arena == null:
		return {"ok": false, "errors": ["Arena is null."], "warnings": []}
	var target_dir: String = base_dir if not base_dir.is_empty() else arena_storage_dir
	var data: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var res: Dictionary = ArenaRepository.save_arena_as(data, new_arena_id, new_name, target_dir)
	if bool(res["ok"]):
		_arena.stage_id = new_arena_id
		if not new_name.strip_edges().is_empty():
			_arena.stage_name = new_name.strip_edges()
		is_dirty = false
		_refresh_all_ui()
		_set_status("Saved arena as '%s'." % new_arena_id, false)
	else:
		var errs: Array = res["errors"] as Array
		_set_status("Save As failed: %s" % (String(errs[0]) if not errs.is_empty() else "Invalid ID"), true)
	return res


func load_arena_by_id(
	arena_id: String,
	base_dir: String = "",
	force_discard: bool = false
) -> Dictionary:
	if _arena == null:
		return {"ok": false, "errors": ["Arena is null."], "warnings": []}
	var target_dir: String = base_dir if not base_dir.is_empty() else arena_storage_dir

	if is_dirty and not force_discard:
		_pending_discard_action = "load"
		_pending_load_id = arena_id
		if _confirm_discard_dialog != null:
			_confirm_discard_dialog.dialog_text = "Discard unsaved changes and load '%s'?" % arena_id
			_confirm_discard_dialog.popup_centered()
		return {"ok": false, "errors": ["Unsaved changes confirmation required."], "warnings": []}

	var loaded: Dictionary = ArenaRepository.load_arena_data(arena_id, target_dir, false)
	if not bool(loaded["ok"]):
		var errs: Array = loaded["errors"] as Array
		_set_status("Load failed: %s" % (String(errs[0]) if not errs.is_empty() else "Invalid arena file"), true)
		return loaded

	var data: Dictionary = loaded["data"] as Dictionary
	return load_arena_from_dictionary(data)


func load_arena_from_dictionary(data: Dictionary) -> Dictionary:
	if _arena == null:
		return {"ok": false, "errors": ["Arena is null."], "warnings": []}

	var apply_res: Dictionary = ArenaSerializer.apply_data_to_arena(_arena, data, false)
	if not bool(apply_res["ok"]):
		var errs: Array = apply_res["errors"] as Array
		_set_status("Load rejected: %s" % (String(errs[0]) if not errs.is_empty() else "Invalid arena data"), true)
		return apply_res

	_undo_stack.clear()
	_redo_stack.clear()
	cancel_placement()
	select_obstacle(null)
	_arena.set_editor_mode(_active)
	is_dirty = false
	_refresh_all_ui()
	_set_status("Loaded arena '%s'." % _arena.stage_id, false)
	return apply_res


func undo() -> bool:
	if _undo_stack.is_empty() or _arena == null:
		return false
	var current_snap: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var prev_snap: Dictionary = _undo_stack.pop_back() as Dictionary
	var selected_id: String = _selected_obstacle.get_obstacle_instance_id() if get_selected_obstacle() != null else ""
	if bool(ArenaSerializer.apply_data_to_arena(_arena, prev_snap, false)["ok"]):
		_redo_stack.append(current_snap)
		_arena.set_editor_mode(_active)
		select_obstacle(_arena.get_obstacle_by_id(selected_id))
		is_dirty = true
		_refresh_all_ui()
		_set_status("Undo applied.", false)
		return true
	return false


func redo() -> bool:
	if _redo_stack.is_empty() or _arena == null:
		return false
	var current_snap: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var next_snap: Dictionary = _redo_stack.pop_back() as Dictionary
	var selected_id: String = _selected_obstacle.get_obstacle_instance_id() if get_selected_obstacle() != null else ""
	if bool(ArenaSerializer.apply_data_to_arena(_arena, next_snap, false)["ok"]):
		_undo_stack.append(current_snap)
		_arena.set_editor_mode(_active)
		select_obstacle(_arena.get_obstacle_by_id(selected_id))
		is_dirty = true
		_refresh_all_ui()
		_set_status("Redo applied.", false)
		return true
	return false


# --- Internal Helpers & UI Construction ---

func _push_undo_snapshot() -> void:
	if _arena == null:
		return
	_record_snapshot(ArenaSerializer.serialize_arena(_arena))


func _record_snapshot(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	_undo_stack.append(snap)
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.remove_at(0)
	_redo_stack.clear()


func _ensure_3d_helpers() -> void:
	if _arena == null:
		return
	if _placement_ghost == null:
		_placement_ghost = MeshInstance3D.new()
		_placement_ghost.name = "_EditorPlacementGhost"
		var gbox: BoxMesh = BoxMesh.new()
		gbox.size = Vector3(2.4, 0.5, 4.0)
		_placement_ghost.mesh = gbox
		var gmat: StandardMaterial3D = StandardMaterial3D.new()
		gmat.albedo_color = Color(0.2, 0.85, 0.95, 0.4)
		gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_placement_ghost.material_override = gmat
		_placement_ghost.visible = false
		_arena.add_child(_placement_ghost)

	if _selection_highlight == null:
		_selection_highlight = MeshInstance3D.new()
		_selection_highlight.name = "_EditorSelectionHighlight"
		var sbox: BoxMesh = BoxMesh.new()
		sbox.size = Vector3(3.0, 2.0, 4.0)
		_selection_highlight.mesh = sbox
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.92, 0.15, 0.28)
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_selection_highlight.material_override = smat
		_selection_highlight.visible = false
		_arena.add_child(_selection_highlight)


func _update_selection_highlight() -> void:
	_ensure_3d_helpers()
	if _selection_highlight == null:
		return
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null or not _active:
		_selection_highlight.visible = false
		return

	var bounds: AABB = sel.get_local_bounds_aabb()
	if _selection_highlight.mesh is BoxMesh:
		(_selection_highlight.mesh as BoxMesh).size = bounds.size + Vector3(0.25, 0.25, 0.25)
	var local_center: Vector3 = bounds.position + bounds.size * 0.5
	_selection_highlight.global_transform = sel.global_transform * Transform3D(Basis.IDENTITY, local_center)
	_selection_highlight.visible = true


func _project_screen_to_plane(screen_pos: Vector2, plane_y: float) -> Vector3:
	if _editor_camera == null:
		return Vector3(NAN, NAN, NAN)
	var cam: Camera3D = _editor_camera.get_camera()
	if cam == null:
		return Vector3(NAN, NAN, NAN)
	var origin: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3(NAN, NAN, NAN)
	var t: float = (plane_y - origin.y) / dir.y
	if t <= 0.0 or t > 300.0:
		return Vector3(NAN, NAN, NAN)
	var hit_pt: Vector3 = origin + dir * t
	hit_pt.x = clampf(hit_pt.x, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	hit_pt.z = clampf(hit_pt.z, -ArenaValidator.WORLD_XZ_LIMIT, ArenaValidator.WORLD_XZ_LIMIT)
	return hit_pt


func _update_ghost_from_screen(screen_pos: Vector2) -> void:
	if _placement_ghost == null or _pending_placement_type.is_empty():
		return
	var pt: Vector3 = _project_screen_to_plane(screen_pos, placement_height)
	if is_finite(pt.x):
		_placement_ghost.global_position = (snap_vector3(pt) if snap_enabled else pt) + Vector3(0.0, 0.25, -2.0)


func _is_text_entry_focused() -> bool:
	if not is_inside_tree():
		return false
	var owner_ctrl: Control = get_viewport().gui_get_focus_owner()
	return owner_ctrl is LineEdit or owner_ctrl is TextEdit


func _is_point_over_ui_panel(screen_pos: Vector2) -> bool:
	for panel_name: String in ["TopToolbar", "LeftDock", "RightDock", "BottomBar", "FileDialogPanel"]:
		var node: Control = get_node_or_null(panel_name) as Control
		if node != null and node.visible and node.get_global_rect().has_point(screen_pos):
			return true
	return false


func _set_status(msg: String, is_err: bool) -> void:
	if _status_label != null:
		_status_label.text = msg
		_status_label.modulate = Color(1.0, 0.45, 0.45, 1.0) if is_err else Color(0.85, 0.95, 0.88, 1.0)
	status_message_changed.emit(msg, is_err)


func _display_validation_report(report: Dictionary) -> void:
	if _validation_label == null:
		return
	var errs: Array = report.get("errors", []) as Array
	var warns: Array = report.get("warnings", []) as Array
	var lines: PackedStringArray = PackedStringArray()
	if errs.is_empty() and warns.is_empty():
		lines.append("VALID: No errors or warnings.")
	for e: Variant in errs:
		lines.append("[ERROR] " + String(e))
	for w: Variant in warns:
		lines.append("[WARN] " + String(w))
	_validation_label.text = "\n".join(lines)


func _refresh_all_ui() -> void:
	_refresh_toolbar_ui()
	_refresh_inspector_ui()
	_refresh_route_ui()
	_refresh_spawn_finish_ui()
	_refresh_status_bar()


func _refresh_toolbar_ui() -> void:
	if _arena == null:
		return
	_suppress_inspector_callbacks = true
	if _toolbar_arena_id_edit != null:
		_toolbar_arena_id_edit.text = _arena.stage_id
	if _toolbar_arena_name_edit != null:
		_toolbar_arena_name_edit.text = _arena.stage_name
	if _toolbar_time_limit_spin != null:
		_toolbar_time_limit_spin.value = _arena.time_limit_sec
	if _snap_checkbox != null:
		_snap_checkbox.button_pressed = snap_enabled
	if _grid_spin != null:
		_grid_spin.value = grid_size
	_suppress_inspector_callbacks = false


func _refresh_palette_ui() -> void:
	if _palette_container == null:
		return
	for child: Node in _palette_container.get_children():
		_palette_container.remove_child(child)
		child.free()

	for obs_type: String in ObstacleFactory.get_supported_types():
		var row: HBoxContainer = HBoxContainer.new()
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 24)
		swatch.color = ObstacleFactory.get_indicator_color(obs_type)
		row.add_child(swatch)

		var btn: Button = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = "+ " + ObstacleFactory.get_display_name(obs_type)
		btn.pressed.connect(_on_palette_button_pressed.bind(obs_type))
		row.add_child(btn)
		_palette_container.add_child(row)


func _refresh_transform_spinboxes() -> void:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		return
	_suppress_inspector_callbacks = true
	if _pos_x_spin != null:
		_pos_x_spin.value = sel.position.x
	if _pos_y_spin != null:
		_pos_y_spin.value = sel.position.y
	if _pos_z_spin != null:
		_pos_z_spin.value = sel.position.z
	if _rot_y_spin != null:
		_rot_y_spin.value = rad_to_deg(sel.rotation.y)
	if _enabled_checkbox != null:
		_enabled_checkbox.button_pressed = sel.is_enabled
	_suppress_inspector_callbacks = false


func _refresh_inspector_ui() -> void:
	if _params_container == null:
		return
	for child: Node in _params_container.get_children():
		_params_container.remove_child(child)
		child.free()

	var sel: ObstacleBase = get_selected_obstacle()
	var has_sel: bool = (sel != null)
	if _pos_x_spin != null:
		_pos_x_spin.editable = has_sel
		_pos_y_spin.editable = has_sel
		_pos_z_spin.editable = has_sel
		_rot_y_spin.editable = has_sel
	if _enabled_checkbox != null:
		_enabled_checkbox.disabled = not has_sel

	if not has_sel:
		if _inspector_title_label != null:
			_inspector_title_label.text = "INSPECTOR — No Obstacle Selected"
		return

	if _inspector_title_label != null:
		_inspector_title_label.text = "%s [%s]" % [sel.display_name, sel.get_obstacle_instance_id()]

	_refresh_transform_spinboxes()

	var current_params: Dictionary = sel.get_parameters()
	var descriptors: Array = ObstacleFactory.get_parameter_descriptors(sel.get_obstacle_type())
	for desc_var: Variant in descriptors:
		var desc: Dictionary = desc_var as Dictionary
		var key: String = String(desc["key"])
		var label_text: String = String(desc["label"])
		var ptype: String = String(desc["type"])
		var cur_val: Variant = current_params.get(key, desc.get("default"))

		var row: HBoxContainer = HBoxContainer.new()
		var lbl: Label = Label.new()
		lbl.text = label_text
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		if ptype == "float" or ptype == "int":
			var sp: SpinBox = SpinBox.new()
			sp.min_value = float(desc.get("min", 0.0))
			sp.max_value = float(desc.get("max", 100.0))
			sp.step = float(desc.get("step", 0.1 if ptype == "float" else 1.0))
			sp.value = float(cur_val)
			sp.value_changed.connect(_on_param_scalar_changed.bind(key, ptype == "int"))
			row.add_child(sp)
			_params_container.add_child(row)
		elif ptype == "enum" or ptype == "dir_int":
			var opt: OptionButton = OptionButton.new()
			var options: Array = desc.get("options", []) as Array
			for idx: int in range(options.size()):
				var ov: Variant = options[idx]
				opt.add_item(str(ov))
				if str(ov) == str(cur_val):
					opt.selected = idx
			opt.item_selected.connect(_on_param_option_selected.bind(key, options, ptype == "dir_int"))
			row.add_child(opt)
			_params_container.add_child(row)
		elif ptype == "vec3":
			_params_container.add_child(row)
			var vec_row: HBoxContainer = HBoxContainer.new()
			var arr: Array = cur_val as Array if cur_val is Array else [1.0, 1.0, 1.0]
			for axis: int in range(3):
				var vsp: SpinBox = SpinBox.new()
				vsp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				vsp.min_value = float(desc.get("min", 0.1))
				vsp.max_value = float(desc.get("max", 20.0))
				vsp.step = float(desc.get("step", 0.1))
				vsp.value = float(arr[axis])
				vsp.value_changed.connect(_on_param_vec3_axis_changed.bind(key, axis))
				vec_row.add_child(vsp)
			_params_container.add_child(vec_row)


func _refresh_route_ui() -> void:
	if _route_list == null or _arena == null:
		return
	_route_list.clear()
	var route: Array[String] = _arena.get_route_order()
	for i: int in range(route.size()):
		var rid: String = route[i]
		var obs: ObstacleBase = _arena.get_obstacle_by_id(rid)
		var type_label: String = obs.display_name if obs != null else "Missing"
		var state_tag: String = "" if (obs != null and obs.is_enabled) else " [OFF]"
		_route_list.add_item("%d. %s (%s)%s" % [i + 1, rid, type_label, state_tag])
		_route_list.set_item_metadata(i, rid)
	_refresh_route_selection_ui()


func _refresh_route_selection_ui() -> void:
	if _route_list == null:
		return
	var sel: ObstacleBase = get_selected_obstacle()
	if sel == null:
		_route_list.deselect_all()
		return
	var sel_id: String = sel.get_obstacle_instance_id()
	for i: int in range(_route_list.item_count):
		if String(_route_list.get_item_metadata(i)) == sel_id:
			_route_list.select(i)
			return


func _refresh_spawn_finish_ui() -> void:
	if _arena == null:
		return
	_suppress_inspector_callbacks = true
	var sp: Vector3 = _arena.get_spawn_position()
	if _spawn_x_spin != null:
		_spawn_x_spin.value = sp.x
		_spawn_y_spin.value = sp.y
		_spawn_z_spin.value = sp.z
		_spawn_rot_spin.value = _arena.get_spawn_rotation_y_deg()
	var fp: Vector3 = _arena.get_finish_position()
	var fs: Vector3 = _arena.get_finish_size()
	if _finish_x_spin != null:
		_finish_x_spin.value = fp.x
		_finish_y_spin.value = fp.y
		_finish_z_spin.value = fp.z
		_finish_rot_spin.value = _arena.get_finish_rotation_y_deg()
		_finish_sx_spin.value = fs.x
		_finish_sy_spin.value = fs.y
		_finish_sz_spin.value = fs.z
	_suppress_inspector_callbacks = false


func _refresh_status_bar() -> void:
	if _dirty_label != null and _arena != null:
		var dirty_tag: String = " *UNSAVED*" if is_dirty else " [SAVED]"
		_dirty_label.text = "MODE: EDIT | Arena: %s%s | Obstacles: %d/%d | Snap: %s (%.2fm)" % [
			_arena.stage_id,
			dirty_tag,
			_arena.get_obstacle_count(),
			ArenaValidator.MAX_OBSTACLES,
			"ON" if snap_enabled else "OFF",
			grid_size,
		]


# --- UI Signal Callbacks ---

func _on_palette_button_pressed(obs_type: String) -> void:
	var center_pos: Vector3 = Vector3(0.0, placement_height, -8.0)
	if _editor_camera != null:
		center_pos = Vector3(_editor_camera.focus_point.x, placement_height, _editor_camera.focus_point.z)
	place_obstacle_at(obs_type, center_pos, 0.0, true)
	begin_placement(obs_type)


func _on_transform_spin_changed(_val: float) -> void:
	if _suppress_inspector_callbacks or get_selected_obstacle() == null:
		return
	var target_pos: Vector3 = Vector3(_pos_x_spin.value, _pos_y_spin.value, _pos_z_spin.value)
	move_selected_obstacle(target_pos, false)
	rotate_selected_obstacle(_rot_y_spin.value, false)


func _on_enabled_toggled(toggled_on: bool) -> void:
	if _suppress_inspector_callbacks:
		return
	set_selected_obstacle_enabled(toggled_on)


func _on_param_scalar_changed(new_val: float, as_int: bool, key: String) -> void:
	if _suppress_inspector_callbacks:
		return
	if as_int:
		update_selected_parameter(key, int(roundf(new_val)))
	else:
		update_selected_parameter(key, new_val)


func _on_param_option_selected(idx: int, key: String, options: Array, as_int: bool) -> void:
	if _suppress_inspector_callbacks or idx < 0 or idx >= options.size():
		return
	var val: Variant = int(options[idx]) if as_int else str(options[idx])
	update_selected_parameter(key, val)


func _on_param_vec3_axis_changed(new_val: float, key: String, axis: int) -> void:
	if _suppress_inspector_callbacks or get_selected_obstacle() == null:
		return
	var cur_params: Dictionary = get_selected_obstacle().get_parameters()
	var arr: Array = (cur_params.get(key, [1.0, 1.0, 1.0]) as Array).duplicate()
	if axis >= 0 and axis < 3:
		arr[axis] = new_val
		update_selected_parameter(key, arr)


func _on_route_item_selected(index: int) -> void:
	if _route_list == null or _arena == null:
		return
	var rid: String = String(_route_list.get_item_metadata(index))
	var obs: ObstacleBase = _arena.get_obstacle_by_id(rid)
	if obs != null:
		select_obstacle(obs)


func _on_route_move_up_pressed() -> void:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel != null:
		move_route_obstacle(sel.get_obstacle_instance_id(), -1)


func _on_route_move_down_pressed() -> void:
	var sel: ObstacleBase = get_selected_obstacle()
	if sel != null:
		move_route_obstacle(sel.get_obstacle_instance_id(), 1)


func _on_apply_spawn_finish_pressed() -> void:
	if _suppress_inspector_callbacks or _arena == null:
		return
	set_spawn_transform(
		Vector3(_spawn_x_spin.value, _spawn_y_spin.value, _spawn_z_spin.value),
		_spawn_rot_spin.value
	)
	set_finish_transform(
		Vector3(_finish_x_spin.value, _finish_y_spin.value, _finish_z_spin.value),
		_finish_rot_spin.value,
		Vector3(_finish_sx_spin.value, _finish_sy_spin.value, _finish_sz_spin.value)
	)


func _on_apply_metadata_pressed() -> void:
	if _toolbar_arena_id_edit == null or _toolbar_arena_name_edit == null or _toolbar_time_limit_spin == null:
		return
	set_arena_metadata(
		_toolbar_arena_id_edit.text.strip_edges(),
		_toolbar_arena_name_edit.text.strip_edges(),
		_toolbar_time_limit_spin.value
	)


func _on_open_file_dialog_pressed() -> void:
	if _file_dialog_panel == null or _file_list == null:
		return
	_file_list.clear()
	for aid: String in ArenaRepository.list_saved_arenas(arena_storage_dir):
		_file_list.add_item(aid)
	if _arena != null:
		_save_as_id_edit.text = _arena.stage_id
		_save_as_name_edit.text = _arena.stage_name
	_file_dialog_panel.visible = true


func _on_load_selected_file_pressed() -> void:
	if _file_list == null:
		return
	var selected_items: PackedInt32Array = _file_list.get_selected_items()
	if selected_items.is_empty():
		_set_status("Select an arena ID from the list to load.", true)
		return
	var target_id: String = _file_list.get_item_text(selected_items[0])
	if bool(load_arena_by_id(target_id, arena_storage_dir, false)["ok"]):
		_file_dialog_panel.visible = false


func _on_save_as_confirm_pressed() -> void:
	if _save_as_id_edit == null or _save_as_name_edit == null:
		return
	var res: Dictionary = save_current_arena_as(
		_save_as_id_edit.text.strip_edges(),
		_save_as_name_edit.text.strip_edges(),
		arena_storage_dir
	)
	if bool(res["ok"]) and _file_dialog_panel != null:
		_file_dialog_panel.visible = false


func _on_confirm_discard_confirmed() -> void:
	if _pending_discard_action == "new":
		create_new_arena("custom_arena_001", "Custom Ninja Course", true)
	elif _pending_discard_action == "load" and not _pending_load_id.is_empty():
		if bool(load_arena_by_id(_pending_load_id, arena_storage_dir, true)["ok"]) and _file_dialog_panel != null:
			_file_dialog_panel.visible = false
	_pending_discard_action = ""
	_pending_load_id = ""


func _build_editor_ui_if_needed() -> void:
	if get_node_or_null("TopToolbar") != null:
		return

	# Top Toolbar
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.name = "TopToolbar"
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_bottom = 44.0
	add_child(top_panel)

	var top_hbox: HBoxContainer = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	top_panel.add_child(top_hbox)

	var title_lbl: Label = Label.new()
	title_lbl.text = " ARENA EDITOR "
	top_hbox.add_child(title_lbl)

	var new_btn: Button = Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(create_new_arena.bind("custom_arena_001", "Custom Ninja Course", false))
	top_hbox.add_child(new_btn)

	var open_btn: Button = Button.new()
	open_btn.text = "Open / Save As"
	open_btn.pressed.connect(_on_open_file_dialog_pressed)
	top_hbox.add_child(open_btn)

	var save_btn: Button = Button.new()
	save_btn.text = "Save (Ctrl+S)"
	save_btn.pressed.connect(save_current_arena.bind(""))
	top_hbox.add_child(save_btn)

	var val_btn: Button = Button.new()
	val_btn.text = "Validate"
	val_btn.pressed.connect(validate_current_arena.bind(true))
	top_hbox.add_child(val_btn)

	_toolbar_arena_id_edit = LineEdit.new()
	_toolbar_arena_id_edit.placeholder_text = "arena_id"
	_toolbar_arena_id_edit.custom_minimum_size = Vector2(120, 0)
	top_hbox.add_child(_toolbar_arena_id_edit)

	_toolbar_arena_name_edit = LineEdit.new()
	_toolbar_arena_name_edit.placeholder_text = "Arena Name"
	_toolbar_arena_name_edit.custom_minimum_size = Vector2(150, 0)
	top_hbox.add_child(_toolbar_arena_name_edit)

	_toolbar_time_limit_spin = SpinBox.new()
	_toolbar_time_limit_spin.min_value = 10.0
	_toolbar_time_limit_spin.max_value = 600.0
	_toolbar_time_limit_spin.step = 5.0
	_toolbar_time_limit_spin.value = 120.0
	_toolbar_time_limit_spin.suffix = "s"
	top_hbox.add_child(_toolbar_time_limit_spin)

	var meta_btn: Button = Button.new()
	meta_btn.text = "Set Meta"
	meta_btn.pressed.connect(_on_apply_metadata_pressed)
	top_hbox.add_child(meta_btn)

	_snap_checkbox = CheckBox.new()
	_snap_checkbox.text = "Snap"
	_snap_checkbox.button_pressed = true
	_snap_checkbox.toggled.connect(func(on: bool) -> void:
		snap_enabled = on
		_refresh_status_bar()
	)
	top_hbox.add_child(_snap_checkbox)

	_grid_spin = SpinBox.new()
	_grid_spin.min_value = 0.1
	_grid_spin.max_value = 5.0
	_grid_spin.step = 0.1
	_grid_spin.value = 0.5
	_grid_spin.suffix = "m"
	_grid_spin.value_changed.connect(func(v: float) -> void:
		grid_size = v
		_refresh_status_bar()
	)
	top_hbox.add_child(_grid_spin)

	var test_play_btn: Button = Button.new()
	test_play_btn.text = "Test Play (F2)"
	test_play_btn.pressed.connect(func() -> void: test_play_requested.emit())
	top_hbox.add_child(test_play_btn)

	# Left Dock (Palette + Route + Validation)
	var left_dock: PanelContainer = PanelContainer.new()
	left_dock.name = "LeftDock"
	left_dock.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_dock.offset_top = 48.0
	left_dock.offset_bottom = -36.0
	left_dock.offset_right = 250.0
	add_child(left_dock)

	var left_scroll: ScrollContainer = ScrollContainer.new()
	left_dock.add_child(left_scroll)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 6)
	left_scroll.add_child(left_vbox)

	var pal_lbl: Label = Label.new()
	pal_lbl.text = "OBSTACLE PALETTE"
	left_vbox.add_child(pal_lbl)

	_palette_container = VBoxContainer.new()
	left_vbox.add_child(_palette_container)

	var act_row: HBoxContainer = HBoxContainer.new()
	var dup_btn: Button = Button.new()
	dup_btn.text = "Duplicate (Ctrl+D)"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(func() -> void: duplicate_selected_obstacle())
	act_row.add_child(dup_btn)

	var del_btn: Button = Button.new()
	del_btn.text = "Delete (Del)"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(func() -> void: delete_selected_obstacle())
	act_row.add_child(del_btn)
	left_vbox.add_child(act_row)

	var route_lbl: Label = Label.new()
	route_lbl.text = "ORDERED ROUTE"
	left_vbox.add_child(route_lbl)

	_route_list = ItemList.new()
	_route_list.custom_minimum_size = Vector2(0, 130)
	_route_list.item_selected.connect(_on_route_item_selected)
	left_vbox.add_child(_route_list)

	var route_btns: HBoxContainer = HBoxContainer.new()
	var up_btn: Button = Button.new()
	up_btn.text = "Move Up"
	up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_btn.pressed.connect(_on_route_move_up_pressed)
	route_btns.add_child(up_btn)

	var down_btn: Button = Button.new()
	down_btn.text = "Move Down"
	down_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	down_btn.pressed.connect(_on_route_move_down_pressed)
	route_btns.add_child(down_btn)
	left_vbox.add_child(route_btns)

	var val_title: Label = Label.new()
	val_title.text = "VALIDATION REPORT"
	left_vbox.add_child(val_title)

	_validation_label = RichTextLabel.new()
	_validation_label.custom_minimum_size = Vector2(0, 110)
	_validation_label.text = "Click Validate to inspect course."
	left_vbox.add_child(_validation_label)

	# Right Dock (Inspector + Spawn/Finish)
	var right_dock: PanelContainer = PanelContainer.new()
	right_dock.name = "RightDock"
	right_dock.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_dock.offset_top = 48.0
	right_dock.offset_bottom = -36.0
	right_dock.offset_left = -290.0
	add_child(right_dock)

	var right_scroll: ScrollContainer = ScrollContainer.new()
	right_dock.add_child(right_scroll)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right_vbox)

	_inspector_title_label = Label.new()
	_inspector_title_label.text = "INSPECTOR"
	right_vbox.add_child(_inspector_title_label)

	_enabled_checkbox = CheckBox.new()
	_enabled_checkbox.text = "Obstacle Enabled"
	_enabled_checkbox.button_pressed = true
	_enabled_checkbox.toggled.connect(_on_enabled_toggled)
	right_vbox.add_child(_enabled_checkbox)

	var pos_lbl: Label = Label.new()
	pos_lbl.text = "Position (X, Y, Z) & Rot Y:"
	right_vbox.add_child(pos_lbl)

	var pos_row: HBoxContainer = HBoxContainer.new()
	_pos_x_spin = _make_coord_spin(-250.0, 250.0, 0.25)
	_pos_y_spin = _make_coord_spin(-10.0, 100.0, 0.25)
	_pos_z_spin = _make_coord_spin(-250.0, 250.0, 0.25)
	pos_row.add_child(_pos_x_spin)
	pos_row.add_child(_pos_y_spin)
	pos_row.add_child(_pos_z_spin)
	right_vbox.add_child(pos_row)

	var rot_row: HBoxContainer = HBoxContainer.new()
	_rot_y_spin = _make_coord_spin(-360.0, 360.0, 5.0)
	rot_row.add_child(_rot_y_spin)
	var rst_pos_btn: Button = Button.new()
	rst_pos_btn.text = "Rst Pos"
	rst_pos_btn.pressed.connect(reset_selected_position)
	rot_row.add_child(rst_pos_btn)
	var rst_rot_btn: Button = Button.new()
	rst_rot_btn.text = "Rst Rot"
	rst_rot_btn.pressed.connect(reset_selected_rotation)
	rot_row.add_child(rst_rot_btn)
	right_vbox.add_child(rot_row)

	var p_hdr: Label = Label.new()
	p_hdr.text = "OBSTACLE PARAMETERS"
	right_vbox.add_child(p_hdr)

	_params_container = VBoxContainer.new()
	right_vbox.add_child(_params_container)

	var sf_hdr: Label = Label.new()
	sf_hdr.text = "SPAWN & FINISH EDITOR"
	right_vbox.add_child(sf_hdr)

	var sp_row: HBoxContainer = HBoxContainer.new()
	_spawn_x_spin = _make_coord_spin(-250.0, 250.0, 0.5, false)
	_spawn_y_spin = _make_coord_spin(-10.0, 100.0, 0.5, false)
	_spawn_z_spin = _make_coord_spin(-250.0, 250.0, 0.5, false)
	_spawn_rot_spin = _make_coord_spin(-360.0, 360.0, 15.0, false)
	sp_row.add_child(_spawn_x_spin)
	sp_row.add_child(_spawn_y_spin)
	sp_row.add_child(_spawn_z_spin)
	sp_row.add_child(_spawn_rot_spin)
	right_vbox.add_child(sp_row)

	var fn_row: HBoxContainer = HBoxContainer.new()
	_finish_x_spin = _make_coord_spin(-250.0, 250.0, 0.5, false)
	_finish_y_spin = _make_coord_spin(-10.0, 100.0, 0.5, false)
	_finish_z_spin = _make_coord_spin(-250.0, 250.0, 0.5, false)
	_finish_rot_spin = _make_coord_spin(-360.0, 360.0, 15.0, false)
	fn_row.add_child(_finish_x_spin)
	fn_row.add_child(_finish_y_spin)
	fn_row.add_child(_finish_z_spin)
	fn_row.add_child(_finish_rot_spin)
	right_vbox.add_child(fn_row)

	var fs_row: HBoxContainer = HBoxContainer.new()
	_finish_sx_spin = _make_coord_spin(1.0, 20.0, 0.2, false)
	_finish_sy_spin = _make_coord_spin(1.0, 20.0, 0.2, false)
	_finish_sz_spin = _make_coord_spin(1.0, 20.0, 0.2, false)
	fs_row.add_child(_finish_sx_spin)
	fs_row.add_child(_finish_sy_spin)
	fs_row.add_child(_finish_sz_spin)
	right_vbox.add_child(fs_row)

	var apply_sf_btn: Button = Button.new()
	apply_sf_btn.text = "Apply Spawn & Finish"
	apply_sf_btn.pressed.connect(_on_apply_spawn_finish_pressed)
	right_vbox.add_child(apply_sf_btn)

	# Bottom Status Bar
	var bottom_panel: PanelContainer = PanelContainer.new()
	bottom_panel.name = "BottomBar"
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -32.0
	add_child(bottom_panel)

	var bottom_hbox: HBoxContainer = HBoxContainer.new()
	bottom_panel.add_child(bottom_hbox)

	_dirty_label = Label.new()
	_dirty_label.text = "MODE: EDIT"
	bottom_hbox.add_child(_dirty_label)

	var sep: Control = Control.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(sep)

	_status_label = Label.new()
	_status_label.text = "Ready."
	bottom_hbox.add_child(_status_label)

	# File Open / Save As Modal Panel
	_file_dialog_panel = PanelContainer.new()
	_file_dialog_panel.name = "FileDialogPanel"
	_file_dialog_panel.visible = false
	_file_dialog_panel.custom_minimum_size = Vector2(420, 320)
	_file_dialog_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_file_dialog_panel)

	var fd_vbox: VBoxContainer = VBoxContainer.new()
	fd_vbox.add_theme_constant_override("separation", 8)
	_file_dialog_panel.add_child(fd_vbox)

	var fd_title: Label = Label.new()
	fd_title.text = "OPEN / SAVE AS ARENA (user://arenas/)"
	fd_vbox.add_child(fd_title)

	_file_list = ItemList.new()
	_file_list.custom_minimum_size = Vector2(0, 140)
	fd_vbox.add_child(_file_list)

	var load_btn: Button = Button.new()
	load_btn.text = "Load Selected Arena"
	load_btn.pressed.connect(_on_load_selected_file_pressed)
	fd_vbox.add_child(load_btn)

	_save_as_id_edit = LineEdit.new()
	_save_as_id_edit.placeholder_text = "New arena_id (e.g. custom_stage_01)"
	fd_vbox.add_child(_save_as_id_edit)

	_save_as_name_edit = LineEdit.new()
	_save_as_name_edit.placeholder_text = "New Arena Display Name"
	fd_vbox.add_child(_save_as_name_edit)

	var fd_btns: HBoxContainer = HBoxContainer.new()
	var sa_btn: Button = Button.new()
	sa_btn.text = "Save As"
	sa_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sa_btn.pressed.connect(_on_save_as_confirm_pressed)
	fd_btns.add_child(sa_btn)

	var close_fd_btn: Button = Button.new()
	close_fd_btn.text = "Close"
	close_fd_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_fd_btn.pressed.connect(func() -> void: _file_dialog_panel.visible = false)
	fd_btns.add_child(close_fd_btn)
	fd_vbox.add_child(fd_btns)

	_confirm_discard_dialog = ConfirmationDialog.new()
	_confirm_discard_dialog.title = "Unsaved Arena Changes"
	_confirm_discard_dialog.confirmed.connect(_on_confirm_discard_confirmed)
	add_child(_confirm_discard_dialog)


func _make_coord_spin(min_v: float, max_v: float, step_v: float, bind_selected: bool = true) -> SpinBox:
	var sp: SpinBox = SpinBox.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.min_value = min_v
	sp.max_value = max_v
	sp.step = step_v
	if bind_selected:
		sp.value_changed.connect(_on_transform_spin_changed)
	return sp
