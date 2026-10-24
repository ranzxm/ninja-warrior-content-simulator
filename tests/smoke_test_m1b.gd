extends SceneTree

## Comprehensive automated test suite for Milestone M1b:
## In-Game Arena Editor, Modular Course Builder, Pause Lifecycle, Unique Instance IDs & JSON Persistence.
## Covers Groups A–F (60 required test cases).
## Run with: godot --headless --path . -s res://tests/smoke_test_m1b.gd

const TEST_ARENA_DIR: String = "user://arenas_test_m1b"

var _failures: Array[String] = []
var _passed_checks: int = 0
var _main_node: MainApp = null
var _frame: int = 0

# Group A pause physics tracking
var _paused_plat_progress: float = 0.0
var _paused_plat_pos: Vector3 = Vector3.ZERO
var _paused_sweep_angle: float = 0.0
var _paused_pend_angle: float = 0.0
var _paused_pend_time: float = 0.0
var _paused_elapsed_sec: float = 0.0
var _state_change_count: int = 0


func _initialize() -> void:
	var main_packed: PackedScene = load("res://scenes/app/main.tscn") as PackedScene
	_assert_true(main_packed != null, "Init. main.tscn must load")
	if main_packed == null:
		_finish()
		return
	_main_node = main_packed.instantiate() as MainApp
	root.add_child(_main_node)


func _physics_process(_delta: float) -> bool:
	if _main_node == null:
		_finish()
		return true

	_frame += 1

	# Frame 2: Verify Stage 01 & start RUNNING for real multi-frame pause test (Group A)
	if _frame == 2:
		_test_group_a_identities_and_stage01()
		_start_group_a_running_phase()
		return false

	# Frames 3..17: Let dynamic obstacles run in RUNNING mode for 15 real physics frames
	if _frame > 2 and _frame <= 17:
		return false

	# Frame 18: Pause the game and record exact dynamic obstacle phases/transforms
	if _frame == 18:
		_pause_and_snapshot_group_a()
		return false

	# Frames 19..33: Advance 15 real SceneTree physics frames while paused
	if _frame > 18 and _frame <= 33:
		return false

	# Frame 34: Verify zero movement during pause, then resume
	if _frame == 34:
		_verify_paused_and_resume_group_a()
		return false

	# Frames 35..44: Advance 10 real physics frames after resume
	if _frame > 34 and _frame <= 44:
		return false

	# Frame 45: Verify smooth resumption, then run Groups B, C, D, E, F
	if _frame == 45:
		_verify_resumed_group_a()
		_test_group_b_arena_creation()
		_test_group_c_editing_operations()
		return false

	# Frame 46: Allow physics space to register newly placed/edited editor pick bodies for raycast test, then run D, E, F
	if _frame == 46:
		_test_group_c_raycast_selection()
		_test_group_d_persistence()
		_test_group_e_invalid_data()
		_test_group_f_gameplay_integration()
		_cleanup_test_files()
		root.remove_child(_main_node)
		_main_node.free()
		_main_node = null
		_finish()
		return true

	return false


# --- Group A: Prerequisite Regression (Pause Lifecycle & Unique Instance IDs) ---

func _test_group_a_identities_and_stage01() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	_assert_true(stage != null, "A7a. Stage01Demo exists on startup")
	var stage_obs: Array[ObstacleBase] = stage.get_obstacles()
	_assert_true(stage_obs.size() == 6, "A7b. Stage01Demo has 6 obstacles")

	var seen_stage_ids: Dictionary = {}
	for obs: ObstacleBase in stage_obs:
		var iid: String = obs.get_obstacle_instance_id()
		_assert_true(not iid.is_empty(), "A4a. Stage obstacle has non-empty instance_id")
		_assert_true(not seen_stage_ids.has(iid), "A4b. Stage obstacle instance_id is unique: " + iid)
		seen_stage_ids[iid] = true

	# A4 & A5: Two same-type obstacles receive distinct unique instance IDs
	var mp1: ObstacleBase = ObstacleFactory.create_obstacle("moving_platform")
	var mp2: ObstacleBase = ObstacleFactory.create_obstacle("moving_platform")
	_assert_true(mp1 != null and mp2 != null, "A5a. ObstacleFactory instantiates same-type obstacles")
	if mp1 != null and mp2 != null:
		_assert_true(
			mp1.get_obstacle_instance_id() != mp2.get_obstacle_instance_id(),
			"A5b. Two MovingPlatform instances have distinct instance_ids (%s vs %s)" % [
				mp1.get_obstacle_instance_id(),
				mp2.get_obstacle_instance_id(),
			]
		)
		_assert_true(mp1.get_obstacle_type() == "moving_platform" and mp2.get_obstacle_type() == "moving_platform", "A5c. Both share obstacle_type 'moving_platform'")
		mp1.free()
		mp2.free()


func _start_group_a_running_phase() -> void:
	_main_node.restart_session()
	var session: RunSession = _main_node.get_run_session()
	if not session.state_changed.is_connected(_on_session_state_changed_count):
		session.state_changed.connect(_on_session_state_changed_count)
	_state_change_count = 0
	_main_node._on_start_gate_crossed(_main_node.get_player())
	_assert_true(session.state == RunSession.RunState.RUNNING, "A1a. Session enters RUNNING")


func _pause_and_snapshot_group_a() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var obs: Array[ObstacleBase] = stage.get_obstacles()
	var mplat: ObstacleMovingPlatform = obs[2] as ObstacleMovingPlatform
	var sweeper: ObstacleRotatingSweeper = obs[3] as ObstacleRotatingSweeper
	var pendulum: ObstacleSwingingPendulum = obs[4] as ObstacleSwingingPendulum

	_assert_true(mplat.get_progress() > 0.02, "A1b. MovingPlatform advanced during RUNNING frames")
	_assert_true(absf(sweeper.get_current_angle_rad()) > 0.02, "A1c. RotatingSweeper rotated during RUNNING frames")
	_assert_true(pendulum.get_elapsed_time() > 0.05, "A1d. SwingingPendulum swung during RUNNING frames")

	_main_node.set_paused(true)
	_paused_plat_progress = mplat.get_progress()
	_paused_plat_pos = mplat.get_platform_body().global_position
	_paused_sweep_angle = sweeper.get_current_angle_rad()
	_paused_pend_angle = pendulum.get_current_angle_rad()
	_paused_pend_time = pendulum.get_elapsed_time()
	_paused_elapsed_sec = _main_node.get_run_session().elapsed_sec


func _verify_paused_and_resume_group_a() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var obs: Array[ObstacleBase] = stage.get_obstacles()
	var mplat: ObstacleMovingPlatform = obs[2] as ObstacleMovingPlatform
	var sweeper: ObstacleRotatingSweeper = obs[3] as ObstacleRotatingSweeper
	var pendulum: ObstacleSwingingPendulum = obs[4] as ObstacleSwingingPendulum

	# A1: Dynamic obstacles and timer must remain 100% frozen across 15 paused SceneTree frames
	_assert_true(is_equal_approx(mplat.get_progress(), _paused_plat_progress), "A1e. MovingPlatform phase frozen while paused")
	_assert_true(mplat.get_platform_body().global_position.distance_to(_paused_plat_pos) < 0.0001, "A1f. MovingPlatform transform frozen while paused")
	_assert_true(is_equal_approx(sweeper.get_current_angle_rad(), _paused_sweep_angle), "A1g. RotatingSweeper angle frozen while paused")
	_assert_true(is_equal_approx(pendulum.get_current_angle_rad(), _paused_pend_angle), "A1h. SwingingPendulum angle frozen while paused")
	_assert_true(is_equal_approx(pendulum.get_elapsed_time(), _paused_pend_time), "A1i. SwingingPendulum elapsed time frozen while paused")
	_assert_true(is_equal_approx(_main_node.get_run_session().elapsed_sec, _paused_elapsed_sec), "A1j. RunSession timer frozen while paused")

	# A3: Repeated pause/resume cycles preserve exact phase without duplicate state transitions
	var prev_transitions: int = _state_change_count
	_main_node.set_paused(false)
	_main_node.set_paused(true)
	_main_node.set_paused(false)
	_assert_true(_state_change_count == prev_transitions, "A3a. Pause/resume cycles do not emit duplicate RunSession state transitions")
	_assert_true(is_equal_approx(mplat.get_progress(), _paused_plat_progress), "A2a. Immediate resume starts from exact stored phase without jump")


func _verify_resumed_group_a() -> void:
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var obs: Array[ObstacleBase] = stage.get_obstacles()
	var mplat: ObstacleMovingPlatform = obs[2] as ObstacleMovingPlatform
	var sweeper: ObstacleRotatingSweeper = obs[3] as ObstacleRotatingSweeper
	var pendulum: ObstacleSwingingPendulum = obs[4] as ObstacleSwingingPendulum

	_assert_true(mplat.get_progress() > _paused_plat_progress + 0.02, "A2b. MovingPlatform continues advancing after resume")
	_assert_true(absf(sweeper.get_current_angle_rad() - _paused_sweep_angle) > 0.02, "A2c. RotatingSweeper continues rotating after resume")
	_assert_true(pendulum.get_elapsed_time() > _paused_pend_time + 0.05, "A2d. SwingingPendulum continues swinging after resume")

	# Verify terminal state remains frozen across pause/unpause
	_main_node.get_run_session().fail_run("Pause terminal check")
	var term_plat: float = mplat.get_progress()
	_main_node.set_paused(true)
	_main_node.set_paused(false)
	mplat._physics_process(0.5)
	_assert_true(is_equal_approx(mplat.get_progress(), term_plat), "A3b. Terminal states remain frozen after pause/resume")
	_main_node.restart_session()


# --- Group B: Arena Creation (9–16) ---

func _test_group_b_arena_creation() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	_assert_true(editor != null, "B9a. ArenaEditor instance exists on MainApp")
	editor.arena_storage_dir = TEST_ARENA_DIR

	# Enter EDIT mode
	var entered_edit: bool = _main_node.enter_edit_mode(true)
	_assert_true(entered_edit and _main_node.get_app_mode() == MainApp.AppMode.EDIT, "B9b. MainApp enters EDIT mode")
	_assert_true(editor.is_editor_active() and editor.visible, "B9c. ArenaEditor UI is active and visible")
	_assert_true(_main_node.get_editor_camera().is_active(), "B9d. EditorCamera is active in EDIT mode")

	# B9. Create a new arena
	var created: bool = editor.create_new_arena("test_course_b", "Test Course B", true)
	_assert_true(created, "B9e. create_new_arena() succeeds")
	_assert_true(stage.get_obstacle_count() == 0, "B9f. New arena starts with 0 obstacles")
	_assert_true(not editor.is_dirty, "B9g. New arena starts clean (is_dirty == false)")

	# B10, B11, B12, B14: Place all 6 obstacle types with grid snapping
	editor.snap_enabled = true
	editor.grid_size = 0.5
	var types: Array[String] = ObstacleFactory.get_supported_types()
	var placed_ids: Dictionary = {}
	for i: int in range(types.size()):
		var t_name: String = types[i]
		var raw_pos: Vector3 = Vector3(0.23, 0.0, -4.12 - float(i) * 10.0)
		var placed: ObstacleBase = editor.place_obstacle_at(t_name, raw_pos, 0.0, true)
		_assert_true(placed != null, "B10. Placed obstacle of type: " + t_name)
		if placed != null:
			_assert_true(placed.validate_configuration(), "B11. Placed obstacle has valid collider/geometry: " + t_name)
			var pid: String = placed.get_obstacle_instance_id()
			_assert_true(not pid.is_empty() and not placed_ids.has(pid), "B12. Placed obstacle has unique instance_id: " + pid)
			placed_ids[pid] = true
			_assert_true(is_equal_approx(placed.position.x, 0.0) and is_equal_approx(placed.position.z, -4.0 - float(i) * 10.0), "B14. Grid snapping snapped placement coordinates to 0.5m")

	_assert_true(stage.get_obstacle_count() == 6, "B10b. All 6 obstacle types exist in arena")
	_assert_true(editor.is_dirty, "B10c. Placing obstacles marks arena dirty")

	# B13, B15, B16: Transform and parameter edits on selected obstacle
	var first_obs: ObstacleBase = stage.get_obstacles()[0]
	editor.select_obstacle(first_obs)
	_assert_true(editor.move_selected_obstacle(Vector3(2.5, 0.5, -6.0), false), "B13a. move_selected_obstacle succeeds")
	_assert_true(first_obs.position.distance_to(Vector3(2.5, 0.5, -6.0)) < 0.001, "B13b. Object position persists in memory")
	_assert_true(editor.rotate_selected_obstacle(45.0, false), "B15a. rotate_selected_obstacle succeeds")
	_assert_true(is_equal_approx(rad_to_deg(first_obs.rotation.y), 45.0), "B15b. Object Y rotation persists in memory")

	_assert_true(editor.update_selected_parameter("pad_count", 6), "B16a. Parameter inspector update_selected_parameter succeeds")
	_assert_true(int(first_obs.get_parameters()["pad_count"]) == 6, "B16b. Updated pad_count persists on obstacle")
	_assert_true((first_obs as ObstacleSteppingPads).get_pad_bodies().size() == 6, "B16c. Updated parameter rebuilds geometry")


# --- Group C: Editing Operations (17–24) ---

func _test_group_c_editing_operations() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena

	# C17a. Child body resolution to owning ObstacleBase
	var pads_obs: ObstacleSteppingPads = stage.get_obstacles()[0] as ObstacleSteppingPads
	var child_pad_body: StaticBody3D = pads_obs.get_pad_bodies()[0]
	var resolved_owner: ObstacleBase = ArenaEditor.resolve_owning_obstacle(child_pad_body)
	_assert_true(resolved_owner == pads_obs, "C17a. Child StaticBody3D resolves to owning ObstacleBase")

	# A6 & C18. Duplicate creates independent instance with copied parameters & new ID
	var mplat_obs: ObstacleMovingPlatform = stage.get_obstacles()[2] as ObstacleMovingPlatform
	editor.select_obstacle(mplat_obs)
	_assert_true(editor.update_selected_parameter("movement_speed", 4.5), "C18a. Configure source MovingPlatform speed=4.5")
	var dup_obs: ObstacleBase = editor.duplicate_selected_obstacle(Vector3(3.0, 0.0, -2.0))
	_assert_true(dup_obs != null, "C18b. duplicate_selected_obstacle returns new instance")
	if dup_obs != null:
		_assert_true(dup_obs != mplat_obs, "C18c. Duplicate is a distinct node")
		_assert_true(dup_obs.get_obstacle_instance_id() != mplat_obs.get_obstacle_instance_id(), "A6a. Duplicate receives new unique instance_id")
		_assert_true(is_equal_approx(float(dup_obs.get_parameters()["movement_speed"]), 4.5), "A6b. Duplicate preserves source parameters")
		# Mutate duplicate parameter and verify source is unaffected
		editor.select_obstacle(dup_obs)
		editor.update_selected_parameter("movement_speed", 6.0)
		_assert_true(is_equal_approx(float(mplat_obs.get_parameters()["movement_speed"]), 4.5), "C18d. Modifying duplicate does not mutate original")

	# C19 & C20. Delete removes selected obstacle and updates route references
	var dup_id: String = dup_obs.get_obstacle_instance_id()
	_assert_true(stage.get_route_order().has(dup_id), "C20a. Duplicate is in route before deletion")
	var deleted_ok: bool = editor.delete_selected_obstacle()
	_assert_true(deleted_ok, "C19a. delete_selected_obstacle succeeds")
	_assert_true(stage.get_obstacle_by_id(dup_id) == null, "C19b. Deleted obstacle is removed from arena")
	_assert_true(not stage.get_route_order().has(dup_id), "C20b. Deleted obstacle ID is removed from route_order")
	_assert_true(editor.get_selected_obstacle() == null, "C19c. Selection is cleared after deleting selected obstacle")

	# C21 & C22. Spawn and Finish transforms can be edited
	_assert_true(editor.set_spawn_transform(Vector3(1.5, 0.5, 4.0), 15.0), "C21a. set_spawn_transform succeeds")
	_assert_true(stage.get_spawn_position().distance_to(Vector3(1.5, 0.5, 4.0)) < 0.001, "C21b. Spawn position updated")
	_assert_true(is_equal_approx(stage.get_spawn_rotation_y_deg(), 15.0), "C21c. Spawn rotation updated")

	_assert_true(editor.set_finish_transform(Vector3(-1.0, 2.5, -65.0), -30.0, Vector3(5.0, 3.0, 4.0)), "C22a. set_finish_transform succeeds")
	_assert_true(stage.get_finish_position().distance_to(Vector3(-1.0, 2.5, -65.0)) < 0.001, "C22b. Finish position updated")
	_assert_true(is_equal_approx(stage.get_finish_rotation_y_deg(), -30.0), "C22c. Finish rotation updated")
	_assert_true(stage.get_finish_size().distance_to(Vector3(5.0, 3.0, 4.0)) < 0.001, "C22d. Finish size updated")

	# C23. Route order can be modified
	var route_before: Array[String] = stage.get_route_order()
	var second_id: String = route_before[1]
	_assert_true(editor.move_route_obstacle(second_id, -1), "C23a. move_route_obstacle moves second item up to index 0")
	_assert_true(stage.get_route_order()[0] == second_id, "C23b. Route order updated with moved item at index 0")

	# C24. Invalid parameter changes are rejected atomically
	var beam_obs: ObstacleBalanceBeam = stage.get_obstacles()[1] as ObstacleBalanceBeam
	editor.select_obstacle(beam_obs)
	var prev_beam_len: float = beam_obs.beam_length
	_assert_true(not editor.update_selected_parameter("beam_length", -10.0), "C24a. Negative beam_length rejected by editor")
	_assert_true(is_equal_approx(beam_obs.beam_length, prev_beam_len), "C24b. Previous beam_length preserved after rejection")

	# Aim editor camera from above at beam_obs so frame 46 raycast test has an unoccluded line of sight
	var ed_cam: EditorCamera = _main_node.get_editor_camera()
	ed_cam.yaw_deg = 0.0
	ed_cam.pitch_deg = -75.0
	ed_cam.focus_on(beam_obs.global_position + Vector3(0.0, 0.0, -3.5), 8.0)


func _test_group_c_raycast_selection() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var beam_obs: ObstacleBalanceBeam = stage.get_obstacles()[1] as ObstacleBalanceBeam
	var cam: Camera3D = _main_node.get_editor_camera().get_camera()
	var screen_pt: Vector2 = cam.unproject_position(beam_obs.global_position + Vector3(0.0, 0.0, -3.5))
	editor.select_obstacle(null)
	var picked: ObstacleBase = editor.select_at_screen_position(screen_pt)
	_assert_true(picked == beam_obs, "C17b. 3D viewport raycast selects the target ObstacleBase")


# --- Group D: Persistence (25–37) ---

func _test_group_d_persistence() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena

	# Configure one obstacle as disabled to verify D31 (Load restores enabled states)
	var obs_list: Array[ObstacleBase] = stage.get_obstacles()
	obs_list[5].is_enabled = false

	var snapshot_data: Dictionary = ArenaSerializer.serialize_arena(stage)
	var json_str: String = ArenaSerializer.to_json_string(snapshot_data)
	_assert_true(not json_str.is_empty(), "D25. ArenaSerializer produces non-empty valid JSON")
	_assert_true(int(snapshot_data.get("schema_version", 0)) == 1, "D26. Arena schema_version is 1")

	# D27 & D36: Save twice and verify file + backup integrity
	var save1: Dictionary = editor.save_current_arena(TEST_ARENA_DIR)
	_assert_true(bool(save1["ok"]), "D27a. First save_current_arena succeeds")
	_assert_true(not editor.is_dirty, "D27b. Saving clears dirty flag")
	_assert_true(FileAccess.file_exists(String(save1["path"])), "D27c. Saved JSON file exists on disk")

	var save2: Dictionary = editor.save_current_arena(TEST_ARENA_DIR)
	_assert_true(bool(save2["ok"]), "D36a. Second save_current_arena succeeds")
	_assert_true(FileAccess.file_exists(String(save2["path"]) + ".bak"), "D36b. Second save creates/rotates .bak backup file")

	# D37: Save As creates an independent arena file
	var save_as_res: Dictionary = editor.save_current_arena_as("test_course_copy", "Copied Course", TEST_ARENA_DIR)
	_assert_true(bool(save_as_res["ok"]), "D37a. save_current_arena_as succeeds")
	var saved_list: Array[String] = ArenaRepository.list_saved_arenas(TEST_ARENA_DIR)
	_assert_true(saved_list.has("test_course_b") and saved_list.has("test_course_copy"), "D37b. Both original and Save As files exist independently")

	# Clear arena completely, then load "test_course_b" and verify D28..D35
	editor.create_new_arena("empty_temp", "Empty Temp", true)
	_assert_true(stage.get_obstacle_count() == 0, "D28a. Arena cleared before load test")

	var load_res: Dictionary = editor.load_arena_by_id("test_course_b", TEST_ARENA_DIR, true)
	_assert_true(bool(load_res["ok"]), "D28b. load_arena_by_id('test_course_b') succeeds")
	_assert_true(stage.get_obstacle_count() == 6, "D28c. Load restores all 6 obstacles")

	var restored_data: Dictionary = ArenaSerializer.serialize_arena(stage)
	_assert_true(
		_json_roundtrip_matches(snapshot_data, restored_data),
		"D29-D34. Loaded arena matches saved transforms, parameters, enabled states, instance IDs, route order, and spawn/finish"
	)
	_assert_true(not stage.get_obstacles()[5].is_enabled, "D31. Load restores disabled state (is_enabled == false) on 6th obstacle")
	stage.get_obstacles()[5].is_enabled = true

	# D35: Verify loading does not create duplicate signal connections
	var test_obs: ObstacleBase = stage.get_obstacles()[0]
	var enter_signal_count: Array[int] = [0]
	var conn_cb: Callable = func(_o: ObstacleBase, _idx: int, _tot: int) -> void: enter_signal_count[0] += 1
	stage.obstacle_entered.connect(conn_cb)
	stage.set_editor_mode(false)
	test_obs.obstacle_entered.emit(test_obs, _main_node.get_player())
	stage.obstacle_entered.disconnect(conn_cb)
	stage.set_editor_mode(true)
	_assert_true(enter_signal_count[0] == 1, "D35. Loaded obstacle emits stage signal exactly once (no duplicate connections)")


# --- Group E: Invalid Data & Fault Tolerance (38–49) ---

func _test_group_e_invalid_data() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var valid_base: Dictionary = ArenaSerializer.serialize_arena(stage)

	# E38. Malformed JSON rejected without crashing
	var bad_json_res: Dictionary = ArenaSerializer.from_json_string("{bad_json: [1, 2,")
	_assert_true(not bool(bad_json_res["ok"]), "E38. Malformed JSON rejected safely")

	# E39. Unknown obstacle type rejected
	var bad_type: Dictionary = valid_base.duplicate(true)
	(bad_type["obstacles"] as Array)[0]["type"] = "laser_cannon_9000"
	_assert_true(not bool(ArenaValidator.validate_data(bad_type)["valid"]), "E39. Unknown obstacle type rejected")

	# E40. Duplicate instance IDs rejected
	var bad_dup_id: Dictionary = valid_base.duplicate(true)
	(bad_dup_id["obstacles"] as Array)[1]["id"] = (bad_dup_id["obstacles"] as Array)[0]["id"]
	_assert_true(not bool(ArenaValidator.validate_data(bad_dup_id)["valid"]), "E40. Duplicate obstacle instance IDs rejected")

	# E41. Unsupported schema version rejected
	var bad_schema: Dictionary = valid_base.duplicate(true)
	bad_schema["schema_version"] = 99
	_assert_true(not bool(ArenaValidator.validate_data(bad_schema)["valid"]), "E41. Unsupported schema_version rejected")

	# E42. NaN/INF values rejected
	var bad_nan: Dictionary = valid_base.duplicate(true)
	bad_nan["time_limit_sec"] = NAN
	_assert_true(not bool(ArenaValidator.validate_data(bad_nan)["valid"]), "E42. NaN value rejected")

	# E43. Invalid transforms rejected
	var bad_xform: Dictionary = valid_base.duplicate(true)
	(bad_xform["obstacles"] as Array)[0]["position"] = [99999.0, 0.0, 0.0]
	_assert_true(not bool(ArenaValidator.validate_data(bad_xform)["valid"]), "E43. Out-of-bounds transform rejected")

	# E44. Missing spawn/finish data rejected
	var bad_no_spawn: Dictionary = valid_base.duplicate(true)
	bad_no_spawn.erase("spawn")
	_assert_true(not bool(ArenaValidator.validate_data(bad_no_spawn)["valid"]), "E44. Missing spawn data rejected")

	# E45. Invalid route references (unknown ID and duplicate route entry) rejected
	var bad_route_missing: Dictionary = valid_base.duplicate(true)
	bad_route_missing["route"] = ["ob_nonexistent_999"]
	_assert_true(not bool(ArenaValidator.validate_data(bad_route_missing)["valid"]), "E45a. Route referencing missing obstacle ID rejected")

	var bad_route_dup: Dictionary = valid_base.duplicate(true)
	var first_id: String = String((bad_route_dup["obstacles"] as Array)[0]["id"])
	bad_route_dup["route"] = [first_id, first_id]
	_assert_true(not bool(ArenaValidator.validate_data(bad_route_dup)["valid"]), "E45b. Duplicate route reference rejected")

	# E46. Oversized payload rejected
	var huge_str: String = "x".repeat(ArenaSerializer.MAX_JSON_BYTES + 1024)
	_assert_true(not bool(ArenaSerializer.from_json_string(huge_str)["ok"]), "E46. Oversized JSON payload rejected")

	# E47. Failed load preserves the currently active arena intact
	var before_failed_load: Dictionary = ArenaSerializer.serialize_arena(stage)
	var corrupt_path: String = "%s/corrupt_arena.json" % TEST_ARENA_DIR
	var cf: FileAccess = FileAccess.open(corrupt_path, FileAccess.WRITE)
	if cf != null:
		cf.store_string("{not valid json!!!")
		cf.flush()
		cf = null
	var failed_load_res: Dictionary = editor.load_arena_by_id("corrupt_arena", TEST_ARENA_DIR, true)
	_assert_true(not bool(failed_load_res["ok"]), "E47a. Loading corrupt file returns ok=false")
	_assert_true(
		_json_roundtrip_matches(before_failed_load, ArenaSerializer.serialize_arena(stage)),
		"E47b. Active arena remains 100% intact after failed load"
	)

	# E48. Failed save preserves previous valid file on disk
	var valid_save_res: Dictionary = ArenaRepository.save_arena_data(valid_base, TEST_ARENA_DIR)
	_assert_true(bool(valid_save_res["ok"]), "E48a. Baseline valid file saved")
	var invalid_overwrite: Dictionary = valid_base.duplicate(true)
	invalid_overwrite["time_limit_sec"] = -50.0
	var failed_save_res: Dictionary = ArenaRepository.save_arena_data(invalid_overwrite, TEST_ARENA_DIR)
	_assert_true(not bool(failed_save_res["ok"]), "E48b. Invalid save rejected")
	var reload_after_failed_save: Dictionary = ArenaRepository.load_arena_data(String(valid_base["arena_id"]), TEST_ARENA_DIR)
	_assert_true(bool(reload_after_failed_save["ok"]), "E48c. Previous valid file on disk preserved after failed save")

	# E49. Path traversal rejected
	_assert_true(not ArenaRepository.is_safe_arena_id("../evil"), "E49a. Path traversal '../evil' rejected")
	_assert_true(not ArenaRepository.is_safe_arena_id("..\\evil"), "E49b. Path traversal '..\\evil' rejected")
	_assert_true(not ArenaRepository.is_safe_arena_id("sub/arena"), "E49c. Subdirectory path rejected")
	_assert_true(not bool(ArenaRepository.load_arena_data("../evil", TEST_ARENA_DIR)["ok"]), "E49d. load_arena_data rejects path traversal")
	_assert_true(not bool(ArenaRepository.save_arena_as(valid_base, "../evil", "Evil", TEST_ARENA_DIR)["ok"]), "E49e. save_arena_as rejects path traversal")


# --- Group F: Gameplay Integration with Custom Arena & Same-Type Obstacles (50–60) ---

func _test_group_f_gameplay_integration() -> void:
	var editor: ArenaEditor = _main_node.get_editor()
	var stage: StageDemoArena = _main_node.get_arena() as StageDemoArena
	var session: RunSession = _main_node.get_run_session()
	var player: PlayerController = _main_node.get_player()

	# Build a custom arena with 3 obstacles:
	# moving_platform (inst A) -> balance_beam (inst B) -> moving_platform (inst C)
	editor.create_new_arena("custom_play_test", "Custom Play Test", true)
	var custom_spawn: Vector3 = Vector3(2.0, 0.5, 6.0)
	var custom_finish: Vector3 = Vector3(2.0, 1.5, -32.0)
	editor.set_spawn_transform(custom_spawn, 0.0)
	editor.set_finish_transform(custom_finish, 0.0, Vector3(4.6, 2.8, 3.6))

	var inst_a: ObstacleBase = editor.place_obstacle_at("moving_platform", Vector3(2.0, 0.0, -2.0), 0.0, false)
	var inst_b: ObstacleBase = editor.place_obstacle_at("balance_beam", Vector3(2.0, 0.0, -12.0), 0.0, false)
	var inst_c: ObstacleBase = editor.place_obstacle_at("moving_platform", Vector3(2.0, 0.0, -22.0), 0.0, false)

	var id_a: String = inst_a.get_obstacle_instance_id()
	var id_b: String = inst_b.get_obstacle_instance_id()
	var id_c: String = inst_c.get_obstacle_instance_id()
	_assert_true(id_a != id_c, "F54a. Two MovingPlatform instances in custom arena have distinct IDs")

	# F50. Switch from EDIT to PLAY mode (Test Play)
	var play_ok: bool = _main_node.enter_play_mode()
	_assert_true(play_ok and _main_node.get_app_mode() == MainApp.AppMode.PLAY, "F50. Custom arena enters PLAY mode")
	_assert_true(editor.is_dirty, "F60a. Unsaved dirty flag is preserved when entering Test Play")

	# F51. Player spawns at custom SpawnPoint
	_assert_true(player.global_position.distance_to(custom_spawn) < 0.05, "F51. Player spawns at custom SpawnPoint")

	# F52. RunSession receives custom route [id_a, id_b, id_c]
	_assert_true(session.required_obstacle_ids == [id_a, id_b, id_c], "F52. RunSession receives custom 3-obstacle route")

	# F53. StartGate begins the run
	_main_node._on_start_gate_crossed(player)
	_assert_true(session.state == RunSession.RunState.RUNNING, "F53. StartGate begins RUNNING in custom arena")

	# F54, F55, F56: Same-type obstacle instances track separately; early finish is rejected
	_main_node._on_stage_obstacle_entered(inst_a, 1, 3)
	_main_node._on_stage_obstacle_completed(inst_a, 1, 3)
	_assert_true(session.get_completed_count() == 1, "F54b. Completing MovingPlatform A increments count to 1/3")
	_assert_true(
		inst_c.get_traversal_state() == ObstacleBase.TraversalState.NOT_STARTED,
		"F54c. MovingPlatform C remains NOT_STARTED when MovingPlatform A completes"
	)

	# Attempt out-of-order completion of MovingPlatform C before BalanceBeam B
	_main_node._on_stage_obstacle_entered(inst_c, 3, 3)
	_main_node._on_stage_obstacle_completed(inst_c, 3, 3)
	_assert_true(session.get_completed_count() == 1, "F55a. Out-of-order MovingPlatform C completion rejected")

	# F56. Early FinishZone rejected
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.RUNNING, "F56. Early FinishZone rejected in custom arena")

	# Complete BalanceBeam B (2/3) then MovingPlatform C (3/3)
	_main_node._on_stage_obstacle_entered(inst_b, 2, 3)
	_main_node._on_stage_obstacle_completed(inst_b, 2, 3)
	_assert_true(session.get_completed_count() == 2, "F55b. Completing BalanceBeam B increments count to 2/3")

	_main_node._on_stage_obstacle_entered(inst_c, 3, 3)
	_main_node._on_stage_obstacle_completed(inst_c, 3, 3)
	_assert_true(session.get_completed_count() == 3, "F54d. Completing MovingPlatform C increments count to 3/3")

	# F57. Valid complete route permits FINISHED
	_main_node._on_finish_zone_reached(player)
	_assert_true(session.state == RunSession.RunState.FINISHED, "F57. Custom arena transitions to FINISHED after all 3 obstacles cleared")

	# F58 & F59. Retry resets custom arena obstacles and failure ends the run
	(inst_a as ObstacleMovingPlatform)._physics_process(0.5)
	_main_node.restart_session()
	_assert_true(session.state == RunSession.RunState.READY, "F59a. Retry restores READY in custom arena")
	_assert_true(is_zero_approx((inst_a as ObstacleMovingPlatform).get_progress()), "F59b. Retry resets custom MovingPlatform phase")
	_assert_true(session.get_completed_count() == 0, "F59c. Retry clears custom completion count")

	_main_node._on_start_gate_crossed(player)
	_main_node._on_stage_player_fell(player, "Custom Hazard", id_a)
	_assert_true(session.state == RunSession.RunState.FAILED, "F58a. Hazard failure ends custom run in FAILED")
	_assert_true(session.last_obstacle_id == id_a, "F58b. Failure records specific instance_id")

	# F60. Returning to EDIT mode preserves layout, route, and settings
	var back_to_edit: bool = _main_node.enter_edit_mode(true)
	_assert_true(back_to_edit and _main_node.get_app_mode() == MainApp.AppMode.EDIT, "F60b. Returned to EDIT mode")
	_assert_true(stage.get_obstacle_count() == 3, "F60c. Custom arena obstacle count preserved on return to EDIT")
	_assert_true(stage.get_route_order() == [id_a, id_b, id_c], "F60d. Custom route order preserved on return to EDIT")
	_assert_true(stage.get_spawn_position().distance_to(custom_spawn) < 0.001, "F60e. Custom SpawnPoint preserved on return to EDIT")
	_assert_true(editor.is_dirty, "F60f. Unsaved dirty flag preserved after returning from Test Play")


func _on_session_state_changed_count(_new_state: RunSession.RunState, _state_name: String) -> void:
	_state_change_count += 1


func _json_roundtrip_matches(a: Dictionary, b: Dictionary) -> bool:
	var ja: String = JSON.stringify(a)
	var jb: String = JSON.stringify(b)
	if ja == jb:
		return true
	var pa: Variant = JSON.parse_string(ja)
	var pb: Variant = JSON.parse_string(jb)
	return _variant_approx_equal(pa, pb)


func _variant_approx_equal(va: Variant, vb: Variant) -> bool:
	if (typeof(va) == TYPE_FLOAT or typeof(va) == TYPE_INT) and (typeof(vb) == TYPE_FLOAT or typeof(vb) == TYPE_INT):
		return absf(float(va) - float(vb)) <= 0.001
	if va is Array and vb is Array:
		var arr_a: Array = va as Array
		var arr_b: Array = vb as Array
		if arr_a.size() != arr_b.size():
			return false
		for i: int in range(arr_a.size()):
			if not _variant_approx_equal(arr_a[i], arr_b[i]):
				return false
		return true
	if va is Dictionary and vb is Dictionary:
		var da: Dictionary = va as Dictionary
		var db: Dictionary = vb as Dictionary
		if da.size() != db.size():
			return false
		for k: Variant in da.keys():
			if not db.has(k) or not _variant_approx_equal(da[k], db[k]):
				return false
		return true
	return va == vb


func _cleanup_test_files() -> void:
	var global_dir: String = ProjectSettings.globalize_path(TEST_ARENA_DIR)
	if not DirAccess.dir_exists_absolute(global_dir):
		return
	var dir: DirAccess = DirAccess.open(TEST_ARENA_DIR)
	if dir != null:
		dir.list_dir_begin()
		var fn: String = dir.get_next()
		while not fn.is_empty():
			if not dir.current_is_dir():
				DirAccess.remove_absolute(global_dir.path_join(fn))
			fn = dir.get_next()
		dir.list_dir_end()
	DirAccess.remove_absolute(global_dir)


func _assert_true(condition: bool, message: String) -> void:
	if condition:
		_passed_checks += 1
	else:
		_failures.append(message)
		push_error("SMOKE_TEST_M1B_FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE_TEST_M1B: PASS (%d checks passed)" % _passed_checks)
		quit(0)
	else:
		print("SMOKE_TEST_M1B: FAIL (%d failures, %d passed)" % [_failures.size(), _passed_checks])
		quit(1)
