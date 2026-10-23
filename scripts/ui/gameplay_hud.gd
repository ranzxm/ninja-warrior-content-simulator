class_name GameplayHud
extends Control

## Competition & gameplay HUD displaying stage, run state, timer, obstacle progress, and result overlay.

signal retry_requested()

@onready var _title_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/TitleLabel") as Label
@onready var _stage_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/StageLabel") as Label
@onready var _mode_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/ModeLabel") as Label
@onready var _state_label: Label = get_node_or_null("MarginContainer/VBoxContainer/TopBar/StateLabel") as Label

@onready var _run_state_label: Label = get_node_or_null("MarginContainer/VBoxContainer/CompetitionBar/RunStateLabel") as Label
@onready var _timer_label: Label = get_node_or_null("MarginContainer/VBoxContainer/CompetitionBar/TimerLabel") as Label
@onready var _limit_label: Label = get_node_or_null("MarginContainer/VBoxContainer/CompetitionBar/LimitLabel") as Label
@onready var _obstacle_label: Label = get_node_or_null("MarginContainer/VBoxContainer/CompetitionBar/ObstacleLabel") as Label

@onready var _result_overlay: Control = get_node_or_null("ResultOverlay") as Control
@onready var _result_Banner_label: Label = get_node_or_null("ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BannerLabel") as Label
@onready var _result_detail_label: Label = get_node_or_null("ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DetailLabel") as Label
@onready var _result_sub_label: Label = get_node_or_null("ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubLabel") as Label
@onready var _retry_button: Button = get_node_or_null("ResultOverlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RetryButton") as Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _retry_button != null and not _retry_button.pressed.is_connected(_on_retry_button_pressed):
		_retry_button.pressed.connect(_on_retry_button_pressed)
	set_mode_text("PLAY")
	set_player_state_text("IDLE")
	set_run_state_text("READY")
	set_timer_values(0.0, 120.0)
	set_obstacle_progress("Ready at Start", 0, 6)
	hide_result()


func set_stage_name(stage_title: String) -> void:
	if _stage_label != null:
		_stage_label.text = stage_title


func set_mode_text(mode_name: String) -> void:
	if _mode_label != null:
		_mode_label.text = "MODE: %s" % mode_name.to_upper()


func set_player_state_text(state_name: String) -> void:
	if _state_label != null:
		_state_label.text = "STATE: %s" % state_name.to_upper()


func set_run_state_text(run_state_name: String) -> void:
	if _run_state_label != null:
		_run_state_label.text = "RUN: %s" % run_state_name.to_upper()


func set_timer_values(elapsed_sec: float, remaining_sec: float) -> void:
	if _timer_label != null:
		_timer_label.text = "TIME: %s" % RunSession.format_time_ms(elapsed_sec)
	if _limit_label != null:
		_limit_label.text = "REMAINING: %s" % RunSession.format_time_ms(remaining_sec)


func set_obstacle_progress(obstacle_name: String, index: int, total: int) -> void:
	if _obstacle_label != null:
		var label_name: String = obstacle_name if not obstacle_name.is_empty() else "Course"
		_obstacle_label.text = "OBSTACLE: %s (%d/%d)" % [label_name, index, total]


func show_result(
	final_state: RunSession.RunState,
	elapsed_sec: float,
	reason: String,
	last_obstacle_id: String
) -> void:
	if _result_overlay == null:
		return

	var banner: String = "STAGE CLEAR"
	var detail: String = "Completion Time: %s" % RunSession.format_time_ms(elapsed_sec)
	var sub: String = "All obstacles cleared!"

	match final_state:
		RunSession.RunState.FINISHED:
			banner = "STAGE CLEAR"
			detail = "Completion Time: %s" % RunSession.format_time_ms(elapsed_sec)
			sub = "Status: FINISHED"
		RunSession.RunState.FAILED:
			banner = "FAILED"
			detail = "Reason: %s" % (reason if not reason.is_empty() else "Course Hazard")
			var obs_info: String = last_obstacle_id if not last_obstacle_id.is_empty() else "start"
			sub = "Elapsed: %s | Last Obstacle: %s" % [RunSession.format_time_ms(elapsed_sec), obs_info]
		RunSession.RunState.TIMEOUT:
			banner = "TIME UP"
			detail = "Time Limit Reached: %s" % RunSession.format_time_ms(elapsed_sec)
			var obs_timeout: String = last_obstacle_id if not last_obstacle_id.is_empty() else "start"
			sub = "Last Obstacle: %s" % obs_timeout

	if _result_Banner_label != null:
		_result_Banner_label.text = banner
	if _result_detail_label != null:
		_result_detail_label.text = detail
	if _result_sub_label != null:
		_result_sub_label.text = sub

	_result_overlay.visible = true
	if _retry_button != null:
		_retry_button.grab_focus()


func hide_result() -> void:
	if _result_overlay != null:
		_result_overlay.visible = false


func is_result_visible() -> bool:
	return _result_overlay != null and _result_overlay.visible


func get_result_banner_text() -> String:
	return _result_Banner_label.text if _result_Banner_label != null else ""


func toggle_clean_feed() -> void:
	visible = not visible


func get_mode_text() -> String:
	return _mode_label.text if _mode_label != null else ""


func get_state_text() -> String:
	return _state_label.text if _state_label != null else ""


func get_run_state_text() -> String:
	return _run_state_label.text if _run_state_label != null else ""


func get_timer_text() -> String:
	return _timer_label.text if _timer_label != null else ""


func _on_retry_button_pressed() -> void:
	retry_requested.emit()
