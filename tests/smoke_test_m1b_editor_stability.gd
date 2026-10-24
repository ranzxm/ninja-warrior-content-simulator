extends SceneTree

## Connected Control signals + viewport input, not a substitute for human playtests.
var _failures: Array[String] = []
var _checks: int = 0
var _edits: int = 0
var app: MainApp
var editor: ArenaEditor
var arena: StageDemoArena

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("EDITOR_STABILITY: " + message)

func settle() -> void:
	await process_frame
	await physics_frame
	await process_frame

func _run() -> void:
	app = (load("res://scenes/app/main.tscn") as PackedScene).instantiate() as MainApp
	root.add_child(app)
	await settle()
	app.enter_edit_mode(true)
	editor = app.get_editor()
	arena = app.get_arena() as StageDemoArena
	await settle()
	await _inspector_lifecycle()
	await _geometry_stress()
	await _interactions()
	await _layout_and_placement()
	print("EDITOR_STABILITY_METRICS edits=%d nodes=%d objects=%d resources=%d static_memory=%d" % [_edits, get_node_count(), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), OS.get_static_memory_usage()])
	app.queue_free()
	await settle()
	print("SMOKE_TEST_M1B_EDITOR_STABILITY: %s (%d checks; %d parameter operations)" % ["PASS" if _failures.is_empty() else "FAIL", _checks, _edits])
	quit(0 if _failures.is_empty() else 1)

func _spin(key: String, axis: int = -1) -> SpinBox:
	var node_name: String = key + ("_%d" % axis if axis >= 0 else "")
	return editor._parameter_inspector.find_child(node_name, true, false) as SpinBox

func _enter(spin: SpinBox, value: float) -> void:
	var line: LineEdit = spin.get_line_edit()
	line.grab_focus()
	line.text = str(value)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await settle()
	key.pressed = false
	Input.parse_input_event(key)

func _inspector_lifecycle() -> void:
	var pads: ObstacleBase = arena.get_obstacles()[0]
	editor.select_obstacle(pads)
	await settle()
	var spin: SpinBox = _spin("pad_dimensions", 0)
	check(spin != null, "Actual pad width SpinBox exists")
	if spin == null:
		return
	var sender_id: int = spin.get_instance_id()
	var steps: int = editor._undo_stack.size()
	spin.get_line_edit().grab_focus()
	spin.value = 2.5
	check(is_instance_valid(spin), "value_changed preserves emitter")
	check(is_equal_approx(float(pads.get_parameters()["pad_dimensions"][0]), 1.8), "Pending spinner does not rebuild synchronously")
	spin.value = 2.6
	spin.value = 2.7
	await create_timer(0.4).timeout
	await settle()
	check(is_instance_valid(spin) and spin.get_instance_id() == sender_id, "Rapid values keep same Control")
	check(spin.get_line_edit().has_focus(), "Spinner focus preserved")
	check(editor.get_selected_obstacle() == pads, "Selection preserved")
	check(is_equal_approx(float(pads.get_parameters()["pad_dimensions"][0]), 2.7), "Debounce keeps final value")
	check(editor._undo_stack.size() == steps + 1, "Rapid spinner changes create one undo")
	await _enter(spin, 3.1)
	check(is_equal_approx(float(pads.get_parameters()["pad_dimensions"][0]), 3.1), "Keyboard Enter commits actual LineEdit")
	check(is_instance_valid(spin) and spin.get_line_edit().has_focus(), "Enter preserves sender/focus")
	var caret: int = spin.get_line_edit().caret_column
	editor._refresh_inspector_ui()
	check(spin.get_line_edit().caret_column == caret, "UI synchronization preserves caret")
	var old_value: float = spin.value
	var arrow: InputEventMouseButton = InputEventMouseButton.new()
	arrow.position = Vector2(spin.get_global_rect().end.x - 7, spin.global_position.y + 7)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = arrow.position
	root.push_input(motion, true)
	await process_frame
	arrow.button_index = MOUSE_BUTTON_LEFT
	arrow.pressed = true
	root.push_input(arrow, true)
	await process_frame
	arrow.pressed = false
	root.push_input(arrow, true)
	await create_timer(0.4).timeout
	await settle()
	check(spin.value > old_value, "Real spinner arrow input changes value")
	check(is_equal_approx(float(pads.get_parameters()["pad_dimensions"][0]), spin.value), "Spinner release commits final geometry")
	_edits += 4
	# Pending selection switch must commit to old object, never the new one.
	spin.value = 2.2
	editor.select_obstacle(arena.get_obstacles()[1])
	await settle()
	check(is_equal_approx(float(pads.get_parameters()["pad_dimensions"][0]), 2.2), "Selection switch flushes old target")
	editor.select_obstacle(pads)
	await settle()
	check(is_equal_approx(_spin("pad_dimensions", 0).value, 2.2), "Reopened inspector synchronized")
	var before: Dictionary = pads.get_parameters().duplicate(true)
	check(not editor.update_selected_parameter("pad_dimensions", [0, 0, 0]), "Invalid dimensions rejected")
	check(before == pads.get_parameters(), "Invalid edit preserves geometry configuration")

func _geometry_stress() -> void:
	var keys: Array[String] = ["pad_dimensions", "beam_length", "platform_size", "arm_length", "pendulum_length", "wall_height"]
	for index: int in range(6):
		var obstacle: ObstacleBase = arena.get_obstacles()[index]
		editor.select_obstacle(obstacle)
		await settle()
		var key: String = keys[index]
		var vector: bool = index in [0, 2]
		var controls: Array[SpinBox] = []
		for axis: int in range(3 if vector else 1):
			controls.append(_spin(key, axis if vector else -1))
		var baseline_nodes: int = get_node_count()
		var baseline_objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		var baseline_resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		var baseline_memory: int = OS.get_static_memory_usage()
		for operation: int in range(36):
			var spin: SpinBox = controls[operation % controls.size()]
			var value: float = spin.min_value if operation % 2 == 0 else spin.max_value
			spin.value = value
			spin.get_line_edit().text_submitted.emit(str(value))
			await settle()
			_edits += 1
			check(is_instance_valid(spin), "Control survives stress %s/%d" % [obstacle.obstacle_type, operation])
			check(obstacle.validate_configuration(), "Anchors and parameters valid")
			check(editor.get_selected_obstacle() == obstacle, "Stress selection stable")
			_verify_geometry(obstacle)
			var pick: StaticBody3D = obstacle.get_node("_EditorPickBody") as StaticBody3D
			check(pick.collision_layer == 16, "Editor pick collider remains selectable")
			if operation % 6 == 0:
				editor.set_selected_obstacle_enabled(false)
				await settle()
				check(obstacle.visible and pick.collision_layer == 16, "Disabled obstacle remains editor-selectable")
				editor.set_selected_obstacle_enabled(true)
		await settle()
		check(get_node_count() == baseline_nodes, "Stable node count after fixed-schema resize")
		check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= baseline_resources + 8, "Resources do not grow per edit")
		print("STRESS_RESOURCES type=%s nodes=%d/%d objects=%d/%d resources=%d/%d memory=%d/%d" % [obstacle.obstacle_type, baseline_nodes, get_node_count(), baseline_objects, Performance.get_monitor(Performance.OBJECT_COUNT), baseline_resources, Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), baseline_memory, OS.get_static_memory_usage()])
	# Generated collections: alternate additions/removals, settle deferred retirement.
	editor.select_obstacle(arena.get_obstacles()[0])
	await settle()
	for operation: int in range(24):
		var count_spin: SpinBox = _spin("pad_count")
		count_spin.value = 1 if operation % 2 == 0 else 12
		count_spin.get_line_edit().text_submitted.emit(str(count_spin.value))
		await settle()
		_edits += 1
		check((arena.get_obstacles()[0] as ObstacleSteppingPads).get_pad_bodies().size() == int(count_spin.value), "Generated pad collection stays synchronized")

func _verify_geometry(obstacle: ObstacleBase) -> void:
	if obstacle is ObstacleSwingingPendulum:
		var pendulum: ObstacleSwingingPendulum = obstacle as ObstacleSwingingPendulum
		check(is_equal_approx(pendulum.get_rod_height(), pendulum.pendulum_length), "Rod matches length")
		check(is_equal_approx(pendulum.get_bob_local_y(), -pendulum.pendulum_length), "Bob collider follows rod")
	for node: Node in obstacle.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		if not mesh.mesh is BoxMesh:
			continue
		var collider: CollisionShape3D = mesh.get_parent().get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collider == null:
			collider = mesh.get_parent().get_node_or_null("ArmCollision") as CollisionShape3D
		if collider != null and collider.shape is BoxShape3D:
			check((mesh.mesh as BoxMesh).size.is_equal_approx((collider.shape as BoxShape3D).size), "Box mesh/collider agree")

func _interactions() -> void:
	for index: int in range(6):
		editor.select_obstacle(arena.get_obstacles()[index])
		var original: Dictionary = editor.get_selected_obstacle().get_parameters()
		var copy: ObstacleBase = editor.duplicate_selected_obstacle()
		check(copy.get_parameters() == original, "Duplicate resized configuration")
	for index: int in range(14):
		check(editor.duplicate_selected_obstacle() != null, "Duplicate 20 instances")
	for index: int in range(5):
		editor.select_obstacle(arena.get_obstacles().back())
		check(editor.delete_selected_obstacle(), "Delete duplicate")
	for index: int in range(8):
		check(editor.undo(), "Undo action")
		await settle()
		check(editor.redo(), "Redo action")
		await settle()
		editor.select_obstacle(arena.get_obstacles()[0])
	# One completed drag records one snapshot, not one per motion.
	editor.select_obstacle(arena.get_obstacles()[1])
	editor._undo_stack.clear()
	editor.set_tool(ArenaEditor.Tool.MOVE)
	editor.begin_drag(Vector2(600, 350))
	for index: int in range(20):
		editor.preview_drag(Vector2(610 + index * 4, 350))
	editor.end_drag()
	check(editor._undo_stack.size() == 1, "One move gesture equals one undo")
	editor.set_tool(ArenaEditor.Tool.ROTATE)
	editor.begin_drag(Vector2(600, 350))
	editor.preview_drag(Vector2(680, 350))
	editor.end_drag()
	check(editor._undo_stack.size() == 2, "One rotation gesture equals one undo")
	check(editor.undo() and editor.redo(), "Transform undo/redo geometry valid")
	check(bool(editor.save_current_arena_as("stability_course", "Stability Course", "user://arenas_test_stability")["ok"]), "Save resized course")
	var expected: Dictionary = ArenaSerializer.serialize_arena(arena)
	check(bool(editor.load_arena_by_id("stability_course", "user://arenas_test_stability", true)["ok"]), "Load resized course")
	check(JSON.stringify(expected) == JSON.stringify(ArenaSerializer.serialize_arena(arena)), "Round-trip exact configuration")
	editor.select_obstacle(arena.get_obstacles()[1])
	var original_position: Vector3 = editor.get_selected_obstacle().position
	editor.move_selected_obstacle(original_position + Vector3(0.5, 0, 0))
	check(editor.is_dirty, "Edit after save is dirty")
	check(editor.undo() and not editor.is_dirty, "Undo to save point is clean")
	check(editor.redo() and editor.is_dirty, "Redo past save point is dirty")
	editor.select_obstacle(arena.get_obstacles()[0])
	_spin("pad_dimensions", 1).value = 0.5
	_spin("pad_dimensions", 1).get_line_edit().text_submitted.emit("0.5")
	await settle()
	check(is_equal_approx(float(arena.get_obstacles()[0].get_parameters()["pad_dimensions"][1]), 0.5), "GUI edit after load")
	check(app.enter_play_mode(), "Test Play after all resizing")
	await settle()
	check(app.enter_edit_mode(true), "Return to Edit")
	await settle()
	for obstacle: ObstacleBase in arena.get_obstacles():
		_verify_geometry(obstacle)
	for suffix: String in [".json", ".json.bak", ".json.tmp"]:
		var path: String = "user://arenas_test_stability/stability_course" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://arenas_test_stability"))

func _layout_and_placement() -> void:
	editor.select_obstacle(arena.get_obstacles()[0])
	await settle()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await settle()
		var right: Control = editor.get_node("RightDock") as Control
		check(right.get_global_rect().end.x <= editor.size.x + 1, "Inspector within screen at %s" % resolution)
		for spin_node: Node in editor._parameter_inspector.find_children("*", "SpinBox", true, false):
			var field: SpinBox = spin_node as SpinBox
			check(field.get_global_rect().position.x >= right.position.x and field.get_global_rect().end.x <= right.get_global_rect().end.x, "No horizontal numeric overflow")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://editor_stability_%dx%d.png" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 720)
	await settle()
	var count: int = arena.get_obstacle_count()
	var palette_button: Button = editor._palette_container.get_child(0).get_child(1) as Button
	palette_button.pressed.emit()
	await settle()
	check(arena.get_obstacle_count() == count and editor.active_tool == ArenaEditor.Tool.PLACE, "Palette enters PLACE without creating object")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.gui_release_focus()
	Input.parse_input_event(escape)
	await settle()
	check(arena.get_obstacle_count() == count and editor.active_tool == ArenaEditor.Tool.SELECT, "Escape cancels without creation")
	palette_button.pressed.emit()
	await settle()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(600, 350)
	click.pressed = true
	Input.parse_input_event(click)
	await settle()
	click.pressed = false
	Input.parse_input_event(click)
	await settle()
	check(arena.get_obstacle_count() == count + 1, "Viewport placement creates exactly one obstacle")
	check(editor.active_tool == ArenaEditor.Tool.SELECT and editor._pending_placement_type.is_empty(), "Placement exits by default")
	check(editor._selection_highlight.mesh is ImmediateMesh, "Selection uses non-colliding lines")
