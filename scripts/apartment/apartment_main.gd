extends "res://scripts/main.gd"
const L = preload("res://scripts/apartment/apartment_layout.gd")
var occluders: Node
var occlusion: Node
var show_full_walls := false
var apartment_status: Label

func _ready() -> void:
	super._ready()
	camera.wall_debug.set_process_unhandled_key_input(false)
	camera.set_mode(2)
	camera.reset_follow()
	update_cutaway()
	occluders = load("res://scripts/apartment/apartment_occluders.gd").new()
	occluders.name = "ApartmentOccluders"
	add_child(occluders)
	occlusion = load("res://scripts/occlusion/player_occlusion.gd").new()
	occlusion.name = "PlayerOcclusion"
	camera.add_child(occlusion)
	occlusion.initialize(camera,player,occluders)
	occluders.register_apartment(occlusion,$Apartment)

func update_cutaway() -> void:
	for part in $Apartment/Architecture.get_children():
		if not part.has_meta("cut_normal"): continue
		var normal: Vector3 = part.get_meta("cut_normal")
		var relative: Vector3 = part.global_position-player.global_position
		var eye: Vector3 = camera.global_position-player.global_position
		var cut := not show_full_walls and normal.dot(relative) > 0.01 and normal.dot(eye) > 0.1
		var upper: MeshInstance3D = part.get_node("Upper")
		upper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if cut else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Like the south wall, the back of its mirror would hide the basin from an
	# outside cutaway view. Keep the panel in full-wall comparison mode.
	for mesh in $Apartment/Furniture/Basin.get_children():
		if mesh.has_meta("foreground_panel"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if not show_full_walls and camera.global_position.z > mesh.global_position.z else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func _process(_delta: float) -> void:
	update_cutaway()
	if apartment_status:
		apartment_status.text = "出租公寓 · 安全屋场景原型\n9.20 × 4.20 m  |  F%d 正交  |  %.1f×\n玩家 %.2f, %.2f  |  %d FPS\n前景墙：%s  |  遮挡轮廓：%s"%[camera.mode,camera.get_zoom_multiplier(),player.position.x,player.position.z,Engine.get_frames_per_second(),"完整" if show_full_walls else "剖切（碰撞保留）","启用" if not is_instance_valid(occluders) or occluders.enabled else "关闭"]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				player.position = L.SPAWN
				player.velocity = Vector3.ZERO
				camera.reset_follow()
				return
			KEY_F7:
				show_full_walls = not show_full_walls
				update_cutaway()
				get_viewport().set_input_as_handled()
				return
			KEY_F8:
				occlusion.debug_label.visible = not occlusion.debug_label.visible
				return
			KEY_F9:
				occluders.enabled = not occluders.enabled
				occlusion.set_enabled(occluders.enabled)
				return
	super._unhandled_key_input(event)

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ApartmentHUD"
	add_child(layer)
	apartment_status = Label.new()
	apartment_status.position = Vector2(22,20)
	apartment_status.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	apartment_status.add_theme_font_size_override("font_size",17)
	apartment_status.add_theme_color_override("font_shadow_color",Color.BLACK)
	apartment_status.add_theme_constant_override("shadow_offset_x",1)
	apartment_status.add_theme_constant_override("shadow_offset_y",1)
	apartment_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(apartment_status)
	var footer := Label.new()
	footer.text = "移动 WASD / 滚轮缩放 / Home 默认缩放 / R 回入口\nF1 85° / F2 65° / F5 45° / F6 45°斜向 / F7 墙体对比 / F8 遮挡调试 / F9 轮廓\n本阶段仅建筑与移动验证，无战斗或家具交互"
	footer.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
	footer.add_theme_font_size_override("font_size",15)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 22
	footer.offset_top = -82
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(footer)
