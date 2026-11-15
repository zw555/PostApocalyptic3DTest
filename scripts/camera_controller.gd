extends Camera3D
@export var target_path: NodePath
@export var follow_speed := 7.0
@export var view_size := 13.8
@export var target_offset := Vector3(0, 0.85, 0)
@export_range(0.1, 1.0, 0.05) var closest_size_ratio := 0.6
@export_range(1.0, 4.0, 0.05) var farthest_size_ratio := 1.8
@export_range(1.01, 2.0, 0.01) var zoom_step_factor := 1.1
@export_range(1.0, 30.0, 0.5) var zoom_smooth_speed := 12.0
var default_size := 0.0
var target_size := 0.0
var mode := 2
var elevation := 65.0
var focus := Vector3.ZERO
var initialized := false
var follow_enabled := true
var presets: Dictionary = {}
var heading := 0.0
var follow_offset := Vector3(0,0,22)
var active_base_size := 13.8
var wall_debug: Node
var reference_size := 13.8

func vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func preset_base(value: int) -> float:
	# Match Camera3D.size's native single-precision storage, including Home targets.
	return Vector2(view_size*float(presets[str(value)].orthographic_size)/reference_size,0).x

func _ready() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/camera_presets.json"))
	presets = config.presets
	reference_size = config.reference_size
	mode = int(config.default_mode)
	elevation = presets[str(mode)].pitch
	heading = presets[str(mode)].yaw
	target_offset = vector(presets[str(mode)].target_offset)
	follow_offset = vector(presets[str(mode)].follow_offset)
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	active_base_size = preset_base(mode)
	size = active_base_size
	default_size = size
	target_size = default_size
	current = true
	reset_follow()
	wall_debug = Node.new()
	wall_debug.set_script(load("res://scripts/camera_visibility_debug.gd"))
	wall_debug.name = "WallVisibilityDebug"
	add_child(wall_debug)
	call_deferred("describe_controls")
	call_deferred("attach_occlusion")

func attach_occlusion() -> void:
	# Only the current playable CAD scene opts in. Historical scenes stay intact.
	if not get_parent().has_node("LootDisplay"):
		return
	var component := Node.new()
	component.set_script(load("res://scripts/occlusion/player_occlusion.gd"))
	component.name = "PlayerOcclusion"
	add_child(component)
	component.initialize(self,get_node(target_path))

func describe_controls() -> void:
	var hud := get_parent().get_node_or_null("DebugHUD")
	if hud:
		for label in hud.get_children():
			if label is Label and label.text.begins_with("WASD"):
				label.text = "WASD MOVE / WHEEL ZOOM / HOME RESET / E SEARCH / R SPAWN / F8 OCC DEBUG / F9 OCC ON-OFF\nF1 85° / F2 65° / F5 45° / F6 45° YAW35° / F3 LIGHTS / F4 SHADOWS / F7 WALLS(DEBUG)"
				label.offset_top = -55
				label.add_theme_font_size_override("font_size",14)

func _unhandled_input(event: InputEvent) -> void:
	# GUI gets first refusal: scrolling a menu must not also zoom the world.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
		if not is_finite(event.factor):
			return
		var steps := clampf(event.factor if event.factor > 0.0 else 1.0, 0.0, 16.0)
		var factor := pow(zoom_step_factor, steps)
		var requested := target_size / factor if event.button_index == MOUSE_BUTTON_WHEEL_UP else target_size * factor
		target_size = clampf(requested, active_base_size * closest_size_ratio, active_base_size * farthest_size_ratio)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME:
			target_size = active_base_size
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_F5,KEY_F6]:
			set_mode(5 if event.keycode == KEY_F5 else 6)
			get_viewport().set_input_as_handled()

func get_zoom_multiplier() -> float:
	# Smaller orthographic size makes the subject larger on screen.
	return active_base_size / size

func set_mode(value: int) -> void:
	if not presets.has(str(value)):
		return
	var old_base := active_base_size
	mode = value
	var data: Dictionary = presets[str(mode)]
	elevation = data.pitch
	heading = data.yaw
	target_offset = vector(data.target_offset)
	follow_offset = vector(data.follow_offset)
	active_base_size = preset_base(mode)
	if not is_equal_approx(old_base,active_base_size):
		size = clampf(size/old_base*active_base_size,active_base_size*closest_size_ratio,active_base_size*farthest_size_ratio)
		target_size = clampf(target_size/old_base*active_base_size,active_base_size*closest_size_ratio,active_base_size*farthest_size_ratio)
	apply_pose()

func reset_follow() -> void:
	var target := get_node_or_null(target_path) as Node3D
	if target:
		focus = target.global_position + target_offset
	initialized = true
	apply_pose()

func apply_pose() -> void:
	var angle := deg_to_rad(elevation)
	var orbit := Basis(Vector3.UP,deg_to_rad(heading))*Basis(Vector3.RIGHT,-angle)
	global_position = focus + orbit*follow_offset
	look_at(focus, Vector3.UP)

func _process(delta: float) -> void:
	size = lerpf(size, target_size, 1.0 - exp(-zoom_smooth_speed * delta))
	if not follow_enabled:
		return
	var target := get_node_or_null(target_path) as Node3D
	if target:
		var desired := target.global_position + target_offset
		focus = focus.lerp(desired, 1.0 - exp(-follow_speed * delta)) if initialized else desired
		initialized = true
		apply_pose()
