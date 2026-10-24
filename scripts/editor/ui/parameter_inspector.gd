class_name ParameterInspector
extends VBoxContainer

## Stable controls. Signals only stage data; commits run after input/physics callbacks.
signal commit_requested(parameters: Dictionary)

var _schema: String = ""
var _controls: Dictionary = {}
var _values: Dictionary = {}
var _pending: bool = false
var _syncing: bool = false
var _typed: Dictionary = {}
var _timer: Timer

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.3
	_timer.timeout.connect(_commit_when_released)
	add_child(_timer)

func show_parameters(obstacle: ObstacleBase) -> void:
	var schema: String = obstacle.get_obstacle_type() if obstacle != null else ""
	if schema != _schema:
		_schema = schema
		_controls.clear()
		_typed.clear()
		for child: Node in get_children():
			if child != _timer:
				remove_child(child)
				child.queue_free()
		if obstacle != null:
			_build(ObstacleFactory.get_parameter_descriptors(schema))
	if obstacle != null:
		synchronize(obstacle.get_parameters())

func synchronize(parameters: Dictionary) -> void:
	_syncing = true
	_values = parameters.duplicate(true)
	_pending = false
	if _timer != null:
		_timer.stop()
	for key: String in _controls:
		var controls: Array = _controls[key]
		var value: Variant = parameters[key]
		for axis: int in range(controls.size()):
			var control: Control = controls[axis] as Control
			if control is SpinBox:
				var number: float = float(value[axis]) if value is Array else float(value)
				# Avoid rewriting focused text/caret when the accepted value already matches.
				if not is_equal_approx((control as SpinBox).value, number):
					(control as SpinBox).set_value_no_signal(number)
			elif control is OptionButton:
				var option: OptionButton = control as OptionButton
				for index: int in range(option.item_count):
					if str(option.get_item_metadata(index)) == str(value):
						option.select(index)
	_syncing = false

func flush() -> void:
	# SpinBox owns parsing/Enter/focus-exit; apply pending typed text before transitions.
	for controls: Array in _controls.values():
		for control: Control in controls:
			if control is SpinBox and _typed.has(control.get_instance_id()):
				(control as SpinBox).apply()
	_typed.clear()
	if _pending:
		_pending = false
		_timer.stop()
		commit_requested.emit(_values.duplicate(true))

func _commit_when_released() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_timer.start()
	else:
		flush()

func _stage(value: float, key: String, axis: int, integer: bool) -> void:
	if _syncing:
		return
	if axis >= 0:
		(_values[key] as Array)[axis] = value
	elif integer:
		_values[key] = int(roundf(value))
	else:
		_values[key] = value
	_pending = true
	_timer.start()

func _option(index: int, key: String, control: OptionButton) -> void:
	_values[key] = control.get_item_metadata(index)
	_pending = true
	call_deferred("flush")

func _build(descriptors: Array) -> void:
	for descriptor: Dictionary in descriptors:
		var key: String = descriptor["key"]
		var kind: String = descriptor["type"]
		var label: Label = Label.new()
		label.text = descriptor["label"]
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		add_child(label)
		var controls: Array[Control] = []
		if kind in ["enum", "dir_int"]:
			var option: OptionButton = OptionButton.new()
			for value: Variant in descriptor["options"]:
				option.add_item(str(value))
				option.set_item_metadata(option.item_count - 1, value)
			option.item_selected.connect(_option.bind(key, option))
			add_child(option)
			controls.append(option)
		else:
			for axis: int in range(3 if kind == "vec3" else 1):
				var row: HBoxContainer = HBoxContainer.new()
				if kind == "vec3":
					var axis_label: Label = Label.new()
					axis_label.text = ["Width (X)", "Height (Y)", "Length (Z)"][axis]
					axis_label.custom_minimum_size.x = 100
					row.add_child(axis_label)
				var spin: SpinBox = SpinBox.new()
				spin.name = key + ("_%d" % axis if kind == "vec3" else "")
				spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spin.custom_minimum_size = Vector2(110, 32)
				var minimum: Variant = descriptor.get("axis_min", descriptor.get("min", 0.0))
				var maximum: Variant = descriptor.get("axis_max", descriptor.get("max", 100.0))
				spin.min_value = float(minimum[axis]) if minimum is Array else float(minimum)
				spin.max_value = float(maximum[axis]) if maximum is Array else float(maximum)
				spin.step = float(descriptor.get("step", 0.1))
				spin.tooltip_text = "%s: %s to %s. Enter or leave field to apply." % [descriptor["label"], spin.min_value, spin.max_value]
				spin.value_changed.connect(_stage.bind(key, axis if kind == "vec3" else -1, kind == "int"))
				spin.get_line_edit().text_changed.connect(func(_text: String) -> void: _typed[spin.get_instance_id()] = true)
				spin.get_line_edit().text_submitted.connect(func(_text: String) -> void: call_deferred("flush"))
				spin.get_line_edit().focus_exited.connect(func() -> void: call_deferred("flush"))
				row.add_child(spin)
				add_child(row)
				controls.append(spin)
		_controls[key] = controls
	var hint: Label = Label.new()
	hint.text = "Enter / leave field to apply. Spinners apply after release."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
