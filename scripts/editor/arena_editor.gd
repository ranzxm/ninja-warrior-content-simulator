class_name ArenaEditor
extends Control

## In-game 3D Arena Editor controller and UI coordinator for M1b.
## Handles obstacle palette, ghost placement, raycast selection, transform editing,
## dynamic parameter inspector, route ordering, spawn/finish editing, validation, and JSON persistence.

signal test_play_requested()
signal exit_editor_requested()
signal status_message_changed(message: String, is_error: bool)

const MAX_UNDO_STEPS: int = 25
enum Tool { SELECT, MOVE, ROTATE, PLACE }
var active_tool: Tool = Tool.SELECT
var _drag_snapshot: Dictionary = {}
var _drag_start: Vector2
var _drag_position: Vector3
var _drag_rotation: float
var _saved_state: String = ""
var _marker_selection: String = ""
var _parameter_inspector: ParameterInspector
var _ghost_bounds: AABB

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
	_parameter_inspector = ParameterInspector.new()
	_params_container.add_child(_parameter_inspector)
	_parameter_inspector.commit_requested.connect(_commit_parameters)
	_refresh_palette_ui()
	_refresh_all_ui()


func setup(arena: StageDemoArena, editor_camera: EditorCamera) -> void:
	_arena = arena
	_editor_camera = editor_camera
	_saved_state = JSON.stringify(ArenaSerializer.serialize_arena(arena))
	_ensure_3d_helpers()
	_refresh_all_ui()


func set_editor_active(active: bool) -> void:
	if _parameter_inspector != null:
		_parameter_inspector.flush()
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
				if _dragging_selected:
					_selected_obstacle.position = _drag_position
					_selected_obstacle.rotation.y = _drag_rotation
					_dragging_selected = false
					_drag_snapshot = {}
					_update_selection_highlight()
					_refresh_transform_spinboxes()
					get_viewport().set_input_as_handled()
					return
				elif not _pending_placement_type.is_empty():
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
			preview_drag(mm.position)

	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _is_point_over_ui_panel(mb.position):
					return
				if not _pending_placement_type.is_empty():
					var target_pos: Vector3 = _project_screen_to_plane(mb.position, placement_height)
					if is_finite(target_pos.x):
						if place_obstacle_at(_pending_placement_type, target_pos, 0.0, true) != null:
							cancel_placement()
					get_viewport().set_input_as_handled()
				else:
					var picked: ObstacleBase = select_at_screen_position(mb.position)
					if picked != null and (active_tool in [Tool.MOVE, Tool.ROTATE] or mb.shift_pressed):
						begin_drag(mb.position)
			else:
				end_drag()


# --- Core Editing Operations ---

func _commit_parameters(parameters: Dictionary) -> void:
	# Called by deferred Enter/focus exit or idle Timer, never by value_changed.
	update_selected_parameters(parameters)

func reset_selected_parameters() -> void:
	var selected: ObstacleBase = get_selected_obstacle()
	if selected != null:
		update_selected_parameters(ObstacleFactory.get_default_parameters(selected.obstacle_type))

func select_marker(marker: String) -> void:
	select_obstacle(null)
	_marker_selection = marker
	_refresh_inspector_ui()
	_refresh_spawn_finish_ui()
	_inspector_title_label.text = "SpawnPoint" if marker == "spawn" else "FinishZone"
	_set_status("Edit %s in the inspector." % _inspector_title_label.text, false)

func set_tool(tool: int) -> void:
	end_drag()
	cancel_placement()
	active_tool = tool as Tool
	_refresh_status_bar()

func begin_drag(screen_position: Vector2) -> void:
	if get_selected_obstacle() == null:
		return
	_drag_snapshot = ArenaSerializer.serialize_arena(_arena)
	_drag_start = screen_position
	_drag_position = _selected_obstacle.position
	_drag_rotation = _selected_obstacle.rotation.y
	_dragging_selected = true

func preview_drag(screen_position: Vector2) -> void:
	if not _dragging_selected or get_selected_obstacle() == null:
		return
	if active_tool == Tool.ROTATE:
		var degrees: float = rad_to_deg(_drag_rotation) + (screen_position.x - _drag_start.x) * 0.5
		_selected_obstacle.rotation.y = deg_to_rad(snappedf(degrees, 15.0) if snap_enabled else degrees)
	else:
		var start: Vector3 = _project_screen_to_plane(_drag_start, _drag_position.y)
		var target: Vector3 = _project_screen_to_plane(screen_position, _drag_position.y)
		var next: Vector3 = snap_vector3(_drag_position + target - start)
		if ArenaValidator._is_within_world_bounds(next):
			_selected_obstacle.position = next
	_update_selection_highlight()
	_refresh_transform_spinboxes()

func end_drag() -> void:
	if not _dragging_selected:
		return
	_dragging_selected = false
	if get_selected_obstacle() != null:
		_selected_obstacle.rotation.y = deg_to_rad(wrapf(rad_to_deg(_selected_obstacle.rotation.y), -180.0, 180.0))
		if _drag_snapshot != ArenaSerializer.serialize_arena(_arena):
			_record_snapshot(_drag_snapshot)
			is_dirty = true
	_drag_snapshot = {}
	_refresh_status_bar()

func _input(event: InputEvent) -> void:
	# Release over a dock still ends a drag; GUI must not swallow the transaction.
	if _active and _dragging_selected and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			end_drag()

func _shortcut_input(event: InputEvent) -> void:
	if _active and event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_S:
		save_current_arena.call_deferred()
		get_viewport().set_input_as_handled()

func reset_camera_view() -> void:
	_editor_camera.yaw_deg = -25.0
	_editor_camera.pitch_deg = -32.0
	_editor_camera.focus_on(Vector3(0, 1, -12), 18.0)

func focus_spawn() -> void:
	_editor_camera.focus_on(_arena.get_spawn_position(), 18.0)

func frame_arena() -> void:
	var bounds: AABB = AABB(_arena.get_spawn_position(), Vector3.ONE)
	for obstacle: ObstacleBase in _arena.get_obstacles():
		bounds = bounds.merge(obstacle.transform * obstacle.get_local_bounds_aabb())
	_editor_camera.focus_on(bounds.get_center(), maxf(12, bounds.size.length() * 1.2))

func create_new_arena(
	new_id: String = "custom_arena_001",
	new_name: String = "Custom Ninja Course",
	force_discard: bool = false
) -> bool:
	if _arena == null:
		return false
	_parameter_inspector.flush()
	end_drag()
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
	_saved_state = JSON.stringify(ArenaSerializer.serialize_arena(_arena))
	_refresh_all_ui()
	_set_status("Created new arena '%s'." % _arena.stage_id, false)
	return true


func begin_placement(obstacle_type: String) -> bool:
	if not ObstacleFactory.is_valid_type(obstacle_type):
		_set_status("Unsupported obstacle type: %s" % obstacle_type, true)
		return false
	_pending_placement_type = obstacle_type
	active_tool = Tool.PLACE
	_ensure_3d_helpers()
	var sample: ObstacleBase = ObstacleFactory.create_obstacle(obstacle_type)
	sample._rebuild_obstacle()
	_ghost_bounds = sample.get_local_bounds_aabb()
	sample.free()
	(_placement_ghost.mesh as BoxMesh).size = _ghost_bounds.size
	if _placement_ghost != null:
		_placement_ghost.visible = true
		var col: Color = ObstacleFactory.get_indicator_color(obstacle_type)
		col.a = 0.45
		if _placement_ghost.material_override is StandardMaterial3D:
			(_placement_ghost.material_override as StandardMaterial3D).albedo_color = col
	_set_status("Placement mode: %s (Left-click 3D view to place, Esc to cancel)" % ObstacleFactory.get_display_name(obstacle_type), false)
	_refresh_status_bar()
	return true


func cancel_placement() -> void:
	_pending_placement_type = ""
	if active_tool == Tool.PLACE:
		active_tool = Tool.SELECT
	if _placement_ghost != null:
		_placement_ghost.visible = false
	_refresh_status_bar()


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
	if _parameter_inspector != null:
		_parameter_inspector.flush()
	end_drag()
	_marker_selection = ""
	var old_selection: ObstacleBase = get_selected_obstacle()
	if old_selection != null and old_selection.geometry_changed.is_connected(_on_geometry_changed):
		old_selection.geometry_changed.disconnect(_on_geometry_changed)
	if obs != null and not is_instance_valid(obs):
		obs = null
	_selected_obstacle = obs
	if obs != null and not obs.geometry_changed.is_connected(_on_geometry_changed):
		obs.geometry_changed.connect(_on_geometry_changed)
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

func _on_geometry_changed(obstacle: ObstacleBase) -> void:
	if obstacle == get_selected_obstacle():
		_update_selection_highlight()


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

	if sel.position.is_equal_approx(target_pos):
		return true
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
	if is_equal_approx(rad_to_deg(sel.rotation.y), target_deg):
		return true

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
	var previous: Dictionary = sel.get_parameters()
	if not sel.apply_parameters(new_params):
		push_warning("PARAMETER_EDIT id=%s type=%s attempted=%s validation=false rebuild_started=false rebuild_completed=false" % [sel.instance_id, sel.obstacle_type, str(new_params)])
		_set_status("Invalid parameter value rejected for '%s'." % sel.get_obstacle_instance_id(), true)
		_refresh_inspector_ui()
		return false
	if previous == sel.get_parameters():
		return true

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
	_parameter_inspector.flush()
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
	_parameter_inspector.flush()
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


func set_finish_transform(pos: Vector3, rot_y_deg: float, dimensions: Vector3) -> bool:
	if _arena == null:
		return false
	var snapshot: Dictionary = ArenaSerializer.serialize_arena(_arena)
	if not _arena.set_finish_transform_data(pos, rot_y_deg, dimensions):
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


func set_arena_metadata(new_id: String, new_name: String, new_time_limit_sec: float, new_theme: String = "") -> bool:
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

	var theme_value: String = _arena.theme_id if new_theme.is_empty() else new_theme
	if theme_value.length() > 32:
		_set_status("Theme must contain 1..32 characters.", true)
		return false
	if _arena.stage_id == new_id and _arena.stage_name == clean_name and is_equal_approx(_arena.time_limit_sec, new_time_limit_sec) and _arena.theme_id == theme_value:
		return true
	_push_undo_snapshot()
	_arena.stage_id = new_id
	_arena.stage_name = clean_name
	_arena.time_limit_sec = new_time_limit_sec
	_arena.theme_id = theme_value
	is_dirty = true
	_refresh_all_ui()
	return true


# --- Validation & Persistence ---

func validate_current_arena(require_play_ready: bool = true) -> Dictionary:
	_parameter_inspector.flush()
	end_drag()
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
	_parameter_inspector.flush()
	end_drag()
	if _arena == null:
		return {"ok": false, "errors": ["Arena is null."], "warnings": []}
	var target_dir: String = base_dir if not base_dir.is_empty() else arena_storage_dir
	var data: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var res: Dictionary = ArenaRepository.save_arena_data(data, target_dir)
	if bool(res["ok"]):
		_saved_state = JSON.stringify(ArenaSerializer.serialize_arena(_arena))
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
	_parameter_inspector.flush()
	end_drag()
	var target_dir: String = base_dir if not base_dir.is_empty() else arena_storage_dir
	var data: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var res: Dictionary = ArenaRepository.save_arena_as(data, new_arena_id, new_name, target_dir)
	if bool(res["ok"]):
		_arena.stage_id = new_arena_id
		if not new_name.strip_edges().is_empty():
			_arena.stage_name = new_name.strip_edges()
		is_dirty = false
		_saved_state = JSON.stringify(ArenaSerializer.serialize_arena(_arena))
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
	_parameter_inspector.flush()
	end_drag()
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
	_saved_state = JSON.stringify(ArenaSerializer.serialize_arena(_arena))
	_refresh_all_ui()
	_set_status("Loaded arena '%s'." % _arena.stage_id, false)
	return apply_res


func undo() -> bool:
	_parameter_inspector.flush()
	end_drag()
	if _undo_stack.is_empty() or _arena == null:
		return false
	var current_snap: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var prev_snap: Dictionary = _undo_stack.pop_back() as Dictionary
	var selected_id: String = _selected_obstacle.get_obstacle_instance_id() if get_selected_obstacle() != null else ""
	if bool(ArenaSerializer.apply_data_to_arena(_arena, prev_snap, false)["ok"]):
		_redo_stack.append(current_snap)
		_arena.set_editor_mode(_active)
		select_obstacle(_arena.get_obstacle_by_id(selected_id))
		is_dirty = JSON.stringify(ArenaSerializer.serialize_arena(_arena)) != _saved_state
		_refresh_all_ui()
		_set_status("Undo applied.", false)
		return true
	return false


func redo() -> bool:
	_parameter_inspector.flush()
	end_drag()
	if _redo_stack.is_empty() or _arena == null:
		return false
	var current_snap: Dictionary = ArenaSerializer.serialize_arena(_arena)
	var next_snap: Dictionary = _redo_stack.pop_back() as Dictionary
	var selected_id: String = _selected_obstacle.get_obstacle_instance_id() if get_selected_obstacle() != null else ""
	if bool(ArenaSerializer.apply_data_to_arena(_arena, next_snap, false)["ok"]):
		_undo_stack.append(current_snap)
		_arena.set_editor_mode(_active)
		select_obstacle(_arena.get_obstacle_by_id(selected_id))
		is_dirty = JSON.stringify(ArenaSerializer.serialize_arena(_arena)) != _saved_state
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
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		smat.albedo_color = Color(1.0, 0.92, 0.15)
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
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var box: AABB = AABB(-bounds.size * 0.5, bounds.size)
	for index: int in range(8):
		for bit: int in [1, 2, 4]:
			if index & bit == 0:
				lines.surface_add_vertex(box.get_endpoint(index))
				lines.surface_add_vertex(box.get_endpoint(index | bit))
	lines.surface_end()
	_selection_highlight.mesh = lines
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
	return hit_pt


func _update_ghost_from_screen(screen_pos: Vector2) -> void:
	if _placement_ghost == null or _pending_placement_type.is_empty():
		return
	var pt: Vector3 = _project_screen_to_plane(screen_pos, placement_height)
	var valid: bool = ArenaValidator._is_within_world_bounds(pt) and _arena.get_obstacle_count() < ArenaValidator.MAX_OBSTACLES
	(_placement_ghost.material_override as StandardMaterial3D).albedo_color = Color(0.2, 0.9, 0.6, 0.25) if valid else Color(1.0, 0.1, 0.1, 0.4)
	_placement_ghost.visible = is_finite(pt.x)
	if is_finite(pt.x):
		_placement_ghost.global_position = (snap_vector3(pt) if snap_enabled else pt) + _ghost_bounds.get_center()


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
		_status_label.tooltip_text = msg
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
	if has_meta("theme_edit"):
		(get_meta("theme_edit") as LineEdit).text = _arena.theme_id
	_suppress_inspector_callbacks = false


func _refresh_palette_ui() -> void:
	if _palette_container == null:
		return
	for child: Node in _palette_container.get_children():
		_palette_container.remove_child(child)
		child.queue_free()

	for obs_type: String in ObstacleFactory.get_supported_types():
		var row: HBoxContainer = HBoxContainer.new()
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 24)
		swatch.color = ObstacleFactory.get_indicator_color(obs_type)
		row.add_child(swatch)

		var btn: Button = Button.new()
		btn.custom_minimum_size.y = 32
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
	if _parameter_inspector == null:
		return
	var sel: ObstacleBase = get_selected_obstacle()
	var has_sel: bool = (sel != null)
	_parameter_inspector.show_parameters(sel)
	for section: String in ["obstacle_section", "spawn_section", "finish_section"]:
		if has_meta(section):
			(get_meta(section) as Control).visible = (has_sel if section == "obstacle_section" else _marker_selection == section.trim_suffix("_section"))
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
	if has_meta("tool_buttons"):
		var buttons: Array = get_meta("tool_buttons") as Array
		for index: int in range(buttons.size()):
			(buttons[index] as Button).set_pressed_no_signal(index == active_tool)
	if _dirty_label != null and _arena != null:
		var selected: ObstacleBase = get_selected_obstacle()
		_dirty_label.text = "EDIT | %s | %s | Snap %s %.2fm | %s" % [Tool.keys()[active_tool], selected.instance_id if selected != null else _marker_selection, "ON" if snap_enabled else "OFF", grid_size, "Unsaved" if is_dirty else "Saved"]


# --- UI Signal Callbacks ---

func _on_palette_button_pressed(obs_type: String) -> void:
	begin_placement(obs_type)


func _on_transform_spin_changed(_val: float) -> void:
	if _suppress_inspector_callbacks or get_selected_obstacle() == null:
		return
	# Transform fields commit together after Enter/focus exit (wired by layout).
	var target_pos: Vector3 = Vector3(_pos_x_spin.value, _pos_y_spin.value, _pos_z_spin.value)
	var target_rotation: float = _rot_y_spin.value
	if not ArenaValidator._is_within_world_bounds(target_pos) or not is_finite(target_rotation) or absf(target_rotation) > 360:
		_set_status("Invalid transform. Previous values preserved.", true)
		_refresh_transform_spinboxes()
		return
	var before: Dictionary = ArenaSerializer.serialize_arena(_arena)
	_selected_obstacle.position = target_pos
	_selected_obstacle.rotation.y = deg_to_rad(target_rotation)
	if before != ArenaSerializer.serialize_arena(_arena):
		_record_snapshot(before)
		is_dirty = true
	_update_selection_highlight()
	_refresh_status_bar()


func _on_enabled_toggled(toggled_on: bool) -> void:
	if _suppress_inspector_callbacks:
		return
	set_selected_obstacle_enabled(toggled_on)


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
	if _marker_selection == "spawn":
		set_spawn_transform(Vector3(_spawn_x_spin.value, _spawn_y_spin.value, _spawn_z_spin.value), _spawn_rot_spin.value)
	elif _marker_selection == "finish":
		set_finish_transform(Vector3(_finish_x_spin.value, _finish_y_spin.value, _finish_z_spin.value), _finish_rot_spin.value, Vector3(_finish_sx_spin.value, _finish_sy_spin.value, _finish_sz_spin.value))


func _on_apply_metadata_pressed() -> void:
	if _toolbar_arena_id_edit == null or _toolbar_arena_name_edit == null or _toolbar_time_limit_spin == null:
		return
	var theme_value: String = (get_meta("theme_edit") as LineEdit).text.strip_edges() if has_meta("theme_edit") else "default"
	if theme_value.is_empty() or theme_value.length() > 32:
		_set_status("Theme must contain 1..32 characters.", true)
		return
	set_arena_metadata(
		_toolbar_arena_id_edit.text.strip_edges(),
		_toolbar_arena_name_edit.text.strip_edges(),
		_toolbar_time_limit_spin.value,
		theme_value
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
	EditorLayout.build(self)
