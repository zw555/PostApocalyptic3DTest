extends Node3D
var local_lights_enabled := true
var shadows_enabled := true
@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
var status: Label

func _ready() -> void:
	configure_input()
	build_hud()
	apply_lighting()

func configure_input() -> void:
	var actions := {"move_left": KEY_A, "move_right": KEY_D, "move_forward": KEY_W, "move_back": KEY_S}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = actions[action]
			InputMap.action_add_event(action, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: camera.set_mode(1)
		KEY_F2: camera.set_mode(2)
		KEY_F3: set_local_lights(not local_lights_enabled)
		KEY_F4: set_shadows(not shadows_enabled)
		KEY_R:
			player.position = Vector3(0, 0.02, 2.3)
			player.velocity = Vector3.ZERO
			camera.reset_follow()

func set_local_lights(value: bool) -> void:
	local_lights_enabled = value
	apply_lighting()

func set_shadows(value: bool) -> void:
	shadows_enabled = value
	apply_lighting()

func apply_lighting() -> void:
	for light in get_tree().get_nodes_in_group("local_lights"):
		light.visible = local_lights_enabled
	for light in get_tree().get_nodes_in_group("shadow_lights"):
		light.shadow_enabled = shadows_enabled

func build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugHUD"
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(26, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.068, 0.074, 0.91)
	style.border_color = Color("8d9e8a")
	style.border_width_left = 3
	style.content_margin_left = 18
	style.content_margin_right = 20
	style.content_margin_top = 13
	style.content_margin_bottom = 13
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 16)
	status.add_theme_color_override("font_color", Color("d9ded0"))
	panel.add_child(status)
	var footer := Label.new()
	footer.text = "WASD  MOVE  /  WHEEL  ZOOM  /  HOME  DEFAULT ZOOM  /  F1  85°  F2  65°  /  F3  LIGHTS  F4  SHADOWS  /  R  RESET"
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", Color("bac6ba"))
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38
	footer.offset_left = 28
	footer.offset_right = -20
	canvas.add_child(footer)
	var title := Label.new()
	title.text = "AFTER HOURS\nCONVENIENCE / 01"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("b7c1b4"))
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	title.offset_left = -285
	title.offset_top = 26
	title.offset_right = -28
	canvas.add_child(title)

func _process(_delta: float) -> void:
	if status:
		status.text = "3D ART STUDY   /   GODOT 4.5.2\nF%d  ORTHO %d°   •   %d FPS\nLOCAL LIGHTS  %s    /    SHADOWS  %s\nZOOM %.1f×" % [camera.mode, int(camera.elevation), Engine.get_frames_per_second(), "ON" if local_lights_enabled else "OFF", "ON" if shadows_enabled else "OFF", camera.get_zoom_multiplier()]
