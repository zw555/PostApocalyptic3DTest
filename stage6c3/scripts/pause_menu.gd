extends CanvasLayer

signal resume_requested

var overlay: Control
var resume_button: Button

func setup() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	layer = 105
	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/WangjiaUI.tres")
	theme.default_font_size = 20
	overlay.theme = theme
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.045, 0.86)
	overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172329")
	style.border_color = Color("768b86")
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 300
	rows.add_theme_constant_override("separation", 16)
	panel.add_child(rows)
	var title := Label.new()
	title.text = "游戏已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	resume_button = Button.new()
	resume_button.text = "继续游戏  [Esc]"
	resume_button.custom_minimum_size.y = 46
	resume_button.pressed.connect(func(): resume_requested.emit())
	rows.add_child(resume_button)
	overlay.hide()

func is_open() -> bool:
	return overlay != null and overlay.visible

func set_open(value: bool) -> void:
	overlay.visible = value

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		resume_requested.emit()
