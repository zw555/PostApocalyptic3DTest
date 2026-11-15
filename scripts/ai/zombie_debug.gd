extends Node
var zombie: CharacterBody3D
var label: Label
var lines: MeshInstance3D
var enabled := false
var elapsed := 0.0

func initialize(actor: CharacterBody3D) -> void:
	zombie = actor
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(20,320)
	label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",Color("E4B7A3"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	label.hide()
	lines = MeshInstance3D.new()
	lines.mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("C88872")
	lines.material_override = material
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(lines)
	lines.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		enabled = not enabled
		label.visible = enabled
		lines.visible = enabled
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(zombie):
		return
	elapsed += delta
	if elapsed < 0.1:
		return
	elapsed = 0
	label.text = "F10 AI 调试 | %s\n目标 %s\n最后发现 %s\n视距 %.1fm / FOV %.0f° | LOS %s\n路径有效 %s | 重算 %d\nAI %d μs / 导航 %d μs"%[zombie.state,str(zombie.target),str(zombie.last_seen),zombie.settings.vision_distance,zombie.settings.field_of_view_degrees,zombie.last_los,zombie.path_valid,zombie.repath_count,zombie.update_usec,zombie.navigation_usec]
	var mesh: ImmediateMesh = lines.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var origin := zombie.global_position+Vector3.UP*0.08
	var previous := origin
	var path: PackedVector3Array = zombie.agent.get_current_navigation_path() if zombie.state in ["CHASE","INVESTIGATE","RETURN"] else PackedVector3Array()
	for point in path:
		mesh.surface_add_vertex(previous)
		mesh.surface_add_vertex(point+Vector3.UP*0.08)
		previous = point+Vector3.UP*0.08
	var radius: float = zombie.settings.vision_distance
	var yaw: float = zombie.visual.rotation.y
	var half_fov: float = zombie.settings.field_of_view_degrees*0.5
	previous = origin
	for i in 25:
		var angle := yaw+deg_to_rad(-half_fov+i*half_fov/12.0)
		var point := origin+Vector3(-sin(angle),0,-cos(angle))*radius
		mesh.surface_add_vertex(previous)
		mesh.surface_add_vertex(point)
		previous = point
	mesh.surface_add_vertex(previous)
	mesh.surface_add_vertex(origin)
	mesh.surface_end()
