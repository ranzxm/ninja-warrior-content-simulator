class_name EditorLayout
extends RefCounted

## Native editor chrome. Editing state and callbacks stay in ArenaEditor.
static func build(editor: Control) -> void:
	if editor.has_node("TopToolbar"):
		return
	var ui_theme: Theme = Theme.new()
	ui_theme.default_font_size = 14
	editor.theme = ui_theme
	_build_toolbar(editor)
	_build_left_dock(editor)
	_build_inspector(editor)
	_build_bottom_bar(editor)
	_build_file_dialog(editor)
	var discard: ConfirmationDialog = ConfirmationDialog.new()
	discard.title = "Unsaved Arena Changes"
	discard.confirmed.connect(Callable(editor, "_on_confirm_discard_confirmed"), Object.CONNECT_DEFERRED)
	editor.add_child(discard)
	editor.set("_confirm_discard_dialog", discard)


## Run after layout: EditorLayout.check(editor). No arena or input required.
static func check(editor: Control) -> void:
	for field: String in ["_palette_container", "_route_list", "_params_container", "_pos_x_spin", "_pos_y_spin", "_pos_z_spin", "_rot_y_spin", "_spawn_x_spin", "_spawn_rot_spin", "_finish_x_spin", "_finish_rot_spin", "_finish_sx_spin", "_finish_sy_spin", "_finish_sz_spin", "_file_dialog_panel", "_status_label", "_dirty_label"]:
		assert(editor.get(field) is Control, "Missing editor field: " + field)
	for section: String in ["obstacle_section", "spawn_section", "finish_section"]:
		assert(editor.get_meta(section) is VBoxContainer, "Missing inspector section: " + section)
	var right: Control = editor.get_node("RightDock") as Control
	assert(is_equal_approx(right.size.x, 300.0), "Inspector exceeds its 300px dock")
	assert(is_equal_approx((editor.get_node("LeftDock") as Control).size.x, 240.0), "Palette exceeds its 240px dock")
	assert(is_equal_approx((editor.get_node("BottomBar") as Control).size.y, 72.0), "Bottom toolbar exceeds 72px")
	assert((right.get_child(0) as ScrollContainer).horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	var files: Control = editor.get("_file_dialog_panel") as Control
	assert(files.get_rect().get_center().is_equal_approx(editor.size * 0.5), "File dialog is not centered")


static func _build_toolbar(editor: Control) -> void:
	var panel: PanelContainer = _panel(editor, "TopToolbar", Control.PRESET_TOP_WIDE)
	panel.offset_bottom = 52.0
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	_label(row, "ARENA EDITOR")
	var arena_name: LineEdit = _text_row(row, "", "Arena name", 80)
	arena_name.custom_minimum_size.x = 100.0
	arena_name.text_submitted.connect(Callable(editor, "_on_apply_metadata_pressed").unbind(1), Object.CONNECT_DEFERRED)
	arena_name.focus_exited.connect(Callable(editor, "_on_apply_metadata_pressed"), Object.CONNECT_DEFERRED)
	editor.set("_toolbar_arena_name_edit", arena_name)
	_button(row, "New", Callable(editor, "create_new_arena"))
	_button(row, "Open", Callable(editor, "_on_open_file_dialog_pressed"), "Open / Save As")
	_button(row, "Save", Callable(editor, "save_current_arena"), "Save (Ctrl+S)")
	_button(row, "Test Play", Callable(editor, "emit_signal").bind("test_play_requested"), "Test Play (F2)")
	var settings: Window = _window(editor, "ArenaSettings", "Arena Settings", Vector2i(380, 280))
	editor.set_meta("settings_window", settings)
	var content: VBoxContainer = _window_content(settings)
	var arena_id: LineEdit = _text_row(content, "Arena ID", "custom_arena_001", 64)
	editor.set("_toolbar_arena_id_edit", arena_id)
	var time_limit: SpinBox = _numeric_row(content, "Time limit", 10.0, 600.0, 5.0)
	time_limit.value = 120.0
	time_limit.suffix = "s"
	editor.set("_toolbar_time_limit_spin", time_limit)
	var theme_edit: LineEdit = _text_row(content, "Theme", "default", 64)
	theme_edit.text = "default"
	editor.set_meta("theme_edit", theme_edit)
	_button(content, "Set Meta", Callable(editor, "_on_apply_metadata_pressed"))
	_button(content, "Close", Callable(settings, "hide"))
	_button(row, "Settings", Callable(settings, "popup_centered"))


static func _build_left_dock(editor: Control) -> void:
	var panel: PanelContainer = _panel(editor, "LeftDock", Control.PRESET_LEFT_WIDE)
	panel.offset_top = 56.0
	panel.offset_bottom = -76.0
	panel.offset_right = 240.0
	var content: VBoxContainer = _scroll_content(panel)
	_label(content, "OBSTACLE PALETTE")
	var palette_scroll: ScrollContainer = ScrollContainer.new()
	palette_scroll.custom_minimum_size.y = 216.0
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(palette_scroll)
	var palette: VBoxContainer = VBoxContainer.new()
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_theme_constant_override("separation", 4)
	palette_scroll.add_child(palette)
	editor.set("_palette_container", palette)
	_label(content, "COURSE ROUTE")
	var route: ItemList = _item_list(content, 128.0)
	route.item_selected.connect(Callable(editor, "_on_route_item_selected"), Object.CONNECT_DEFERRED)
	editor.set("_route_list", route)
	var order_row: HBoxContainer = HBoxContainer.new()
	content.add_child(order_row)
	_button(order_row, "Up", Callable(editor, "_on_route_move_up_pressed"))
	_button(order_row, "Down", Callable(editor, "_on_route_move_down_pressed"))
	var markers: HBoxContainer = HBoxContainer.new()
	content.add_child(markers)
	_button(markers, "Spawn", Callable(editor, "select_marker").bind("spawn"))
	_button(markers, "Finish", Callable(editor, "select_marker").bind("finish"))
	var report: VBoxContainer = _collapsible_section(content, "Validation report", false)
	editor.set_meta("validation_section", report)
	var validation: RichTextLabel = RichTextLabel.new()
	validation.custom_minimum_size.y = 112.0
	validation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	validation.bbcode_enabled = false
	validation.text = "Validate to inspect this course."
	validation.selection_enabled = true
	report.add_child(validation)
	editor.set("_validation_label", validation)
	_button(content, "Validate", func() -> void:
		report.show()
		var toggle: Button = report.get_meta("toggle") as Button
		toggle.set_pressed_no_signal(true)
		Callable(editor, "validate_current_arena").call(true)
	)


static func _build_inspector(editor: Control) -> void:
	var panel: PanelContainer = _panel(editor, "RightDock", Control.PRESET_RIGHT_WIDE)
	panel.offset_top = 56.0
	panel.offset_bottom = -76.0
	panel.offset_left = -300.0
	var content: VBoxContainer = _scroll_content(panel)
	var title: Label = _label(content, "INSPECTOR — No Obstacle Selected")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.set("_inspector_title_label", title)
	var obstacle: VBoxContainer = VBoxContainer.new()
	obstacle.add_theme_constant_override("separation", 6)
	content.add_child(obstacle)
	editor.set_meta("obstacle_section", obstacle)
	var enabled: CheckBox = CheckBox.new()
	enabled.text = "Obstacle enabled"
	enabled.custom_minimum_size.y = 30.0
	enabled.button_pressed = true
	enabled.toggled.connect(Callable(editor, "_on_enabled_toggled"))
	obstacle.add_child(enabled)
	editor.set("_enabled_checkbox", enabled)
	var transform: VBoxContainer = _collapsible_section(obstacle, "Transform")
	_transform_rows(editor, transform, "_pos", "_rot_y_spin", true)
	var reset_row: HBoxContainer = HBoxContainer.new()
	transform.add_child(reset_row)
	_button(reset_row, "Reset position", Callable(editor, "reset_selected_position"))
	_button(reset_row, "Reset rotation", Callable(editor, "reset_selected_rotation"))
	var parameters: VBoxContainer = _collapsible_section(obstacle, "Parameters")
	var params: VBoxContainer = VBoxContainer.new()
	params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parameters.add_child(params)
	editor.set("_params_container", params)
	_button(parameters, "Reset parameters", Callable(editor, "reset_selected_parameters"))
	var actions: HBoxContainer = HBoxContainer.new()
	obstacle.add_child(actions)
	_button(actions, "Duplicate", Callable(editor, "duplicate_selected_obstacle"), "Duplicate (Ctrl+D)")
	_button(actions, "Delete", Callable(editor, "delete_selected_obstacle"), "Delete (Del)")
	_build_marker(editor, content, "spawn")
	_build_marker(editor, content, "finish")


static func _build_marker(editor: Control, parent: Control, kind: String) -> void:
	var section: VBoxContainer = VBoxContainer.new()
	section.name = kind.capitalize() + "Section"
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)
	section.hide()
	editor.set_meta(kind + "_section", section)
	_label(section, kind.to_upper() + " TRANSFORM")
	_transform_rows(editor, section, "_" + kind, "_" + kind + "_rot_spin", false)
	if kind == "finish":
		for axis: String in ["x", "y", "z"]:
			var spin: SpinBox = _numeric_row(section, "Size " + axis.to_upper(), 1.0, 20.0, 0.2)
			spin.value = 1.0
			editor.set("_finish_s" + axis + "_spin", spin)
	_button(section, "Apply " + kind.capitalize(), Callable(editor, "_on_apply_spawn_finish_pressed"))


static func _transform_rows(editor: Control, parent: Control, prefix: String, rotation_field: String, live: bool) -> void:
	for axis: String in ["x", "y", "z"]:
		var spin: SpinBox = _numeric_row(parent, "Position " + axis.to_upper(), -10.0 if axis == "y" else -250.0, 100.0 if axis == "y" else 250.0, 0.25)
		editor.set(prefix + "_" + axis + "_spin", spin)
	var rotation: SpinBox = _numeric_row(parent, "Rotation Y", -360.0, 360.0, 5.0)
	rotation.suffix = "°"
	editor.set(rotation_field, rotation)
	if live:
		_button(parent, "Apply Transform", Callable(editor, "_on_transform_spin_changed").bind(0.0))


static func _build_bottom_bar(editor: Control) -> void:
	var panel: PanelContainer = _panel(editor, "BottomBar", Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -72.0
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	panel.add_child(content)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	var tool_group: ButtonGroup = ButtonGroup.new()
	var tools: Array[Button] = []
	for index: int in range(3):
		var tool: Button = _button(row, ["SELECT", "MOVE", "ROTATE"][index], Callable(editor, "set_tool").bind(index))
		tool.toggle_mode = true
		tool.button_group = tool_group
		tool.button_pressed = index == 0
		tools.append(tool)
	editor.set_meta("tool_buttons", tools)
	var snap: CheckBox = CheckBox.new()
	snap.text = "Snap"
	snap.button_pressed = bool(editor.get("snap_enabled"))
	snap.toggled.connect(func(on: bool) -> void:
		editor.set("snap_enabled", on)
		Callable(editor, "_refresh_status_bar").call()
	)
	row.add_child(snap)
	editor.set("_snap_checkbox", snap)
	var grid: SpinBox = SpinBox.new()
	grid.min_value = 0.1
	grid.max_value = 5.0
	grid.step = 0.1
	grid.value = float(editor.get("grid_size"))
	grid.suffix = "m"
	grid.tooltip_text = "Grid spacing (meters)"
	grid.custom_minimum_size = Vector2(90, 30)
	grid.value_changed.connect(func(value: float) -> void:
		editor.set("grid_size", value)
		Callable(editor, "_refresh_status_bar").call()
	)
	row.add_child(grid)
	editor.set("_grid_spin", grid)
	_button(row, "Undo", Callable(editor, "undo"), "Undo (Ctrl+Z)")
	_button(row, "Redo", Callable(editor, "redo"), "Redo (Ctrl+Y)")
	_button(row, "Camera Reset", Callable(editor, "reset_camera_view"))
	_button(row, "Frame All", Callable(editor, "frame_arena"))
	_button(row, "Spawn", Callable(editor, "focus_spawn"))
	var help: Window = _window(editor, "EditorHelp", "Editor Help", Vector2i(440, 310))
	editor.set_meta("help_window", help)
	var help_content: VBoxContainer = _window_content(help)
	var instructions: Label = _label(help_content, "Select a palette obstacle, then click the arena to place it.\nEsc: cancel placement / leave text input\nShift + drag: move selection · Q / E: rotate\nF: focus selection · Delete: remove\nCtrl+D: duplicate · Ctrl+S: save\nCtrl+Z / Ctrl+Y: undo / redo\nF2: test play\nSpawn / Finish: edit marker, then Apply.")
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_button(help_content, "Close", Callable(help, "hide"))
	_button(row, "Help", Callable(help, "popup_centered"))
	var status_row: HBoxContainer = HBoxContainer.new()
	content.add_child(status_row)
	var dirty: Label = _label(status_row, "MODE: EDIT")
	_ellipsis(dirty)
	editor.set("_dirty_label", dirty)
	var status: Label = _label(status_row, "Ready.")
	_ellipsis(status)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	editor.set("_status_label", status)


static func _build_file_dialog(editor: Control) -> void:
	var panel: PanelContainer = _panel(editor, "FileDialogPanel", Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = -200.0
	panel.offset_bottom = 200.0
	panel.z_index = 10
	panel.hide()
	editor.set("_file_dialog_panel", panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	_label(content, "OPEN / SAVE AS ARENA")
	var files: ItemList = _item_list(content, 144.0)
	files.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.set("_file_list", files)
	_button(content, "Load selected arena", Callable(editor, "_on_load_selected_file_pressed"))
	editor.set("_save_as_id_edit", _text_row(content, "Arena ID", "custom_stage_01", 64))
	editor.set("_save_as_name_edit", _text_row(content, "Name", "Arena display name", 80))
	var actions: HBoxContainer = HBoxContainer.new()
	content.add_child(actions)
	_button(actions, "Save As", Callable(editor, "_on_save_as_confirm_pressed"))
	_button(actions, "Close", Callable(panel, "hide"))


static func _panel(parent: Control, node_name: String, preset: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_preset(preset)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.09, 0.12, 0.97)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


static func _scroll_content(parent: Control) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)
	return content


static func _button(parent: Control, text: String, action: Callable, hint: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size.y = 30.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action, Object.CONNECT_DEFERRED)
	parent.add_child(button)
	return button


static func _label(parent: Control, text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	parent.add_child(label)
	return label


static func _ellipsis(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


static func _numeric_row(parent: Control, caption: String, minimum: float, maximum: float, increment: float) -> SpinBox:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	var label: Label = _label(row, caption)
	label.custom_minimum_size.x = 88.0
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = increment
	spin.custom_minimum_size = Vector2(112, 32)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.tooltip_text = caption
	row.add_child(spin)
	return spin


static func _text_row(parent: Control, caption: String, placeholder: String, length_limit: int) -> LineEdit:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	if not caption.is_empty():
		var label: Label = _label(row, caption)
		label.custom_minimum_size.x = 88.0
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.tooltip_text = caption if not caption.is_empty() else placeholder
	edit.max_length = length_limit
	edit.custom_minimum_size.y = 32.0
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(edit)
	return edit


static func _collapsible_section(parent: Control, caption: String, expanded: bool = true) -> VBoxContainer:
	var toggle: Button = Button.new()
	toggle.text = caption
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	toggle.button_pressed = expanded
	toggle.custom_minimum_size.y = 30.0
	parent.add_child(toggle)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.visible = expanded
	parent.add_child(content)
	content.set_meta("toggle", toggle)
	toggle.toggled.connect(Callable(content, "set_visible"))
	return content


static func _item_list(parent: Control, height: float) -> ItemList:
	var list: ItemList = ItemList.new()
	list.custom_minimum_size.y = height
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.max_columns = 1
	list.auto_height = false
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(list)
	return list


static func _window(editor: Control, node_name: String, title: String, window_size: Vector2i) -> Window:
	var window: Window = Window.new()
	window.name = node_name
	window.title = title
	window.size = window_size
	window.min_size = window_size
	window.transient = true
	window.exclusive = true
	window.visible = false
	window.close_requested.connect(Callable(window, "hide"))
	editor.add_child(window)
	return window


static func _window_content(window: Window) -> VBoxContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	window.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	return content
