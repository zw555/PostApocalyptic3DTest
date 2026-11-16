extends "res://scripts/apartment/apartment_main.gd"
const P = preload("res://scripts/apartment/floor5_layout.gd")
const Door = preload("res://scripts/apartment/floor5_door.gd")
var structure_visibility: Node
var doors: Array[Node3D] = []
var target_door: Node3D
var interaction_label: Label
var message_label: Label
var message_remaining := 0.0
var structural_targets: Array[Node3D] = []
var dependencies: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()
	for node in $Apartment.find_children("*","Node3D",true,false):
		if node.get_meta("visibility_target",false): structural_targets.append(node)
		if node is MeshInstance3D and node.has_meta("cut_owner"): dependencies.append(node)
		if is_floor_door(node):
			doors.append(node)
			node.feedback.connect(show_message)
			var path := str($Apartment.get_path_to(node.get_node("LeafCollision")))
			for rid in occlusion.proxies:
				if occlusion.proxies[rid].label == path: node.proxy_rids.append(rid)
		if node is MeshInstance3D and node.get_meta("query_mesh",false):
			var shape := BoxShape3D.new()
			shape.size = node.mesh.size
			occlusion.owned_shapes.append(shape)
			occlusion.register_proxy(shape,node.global_transform,node,str($Apartment.get_path_to(node)))
	structure_visibility = create_structure_visibility()
	structure_visibility.name = "FloorStructureVisibility"
	add_child(structure_visibility)
	structure_visibility.initialize(self)
	update_cutaway()

func create_structure_visibility() -> Node:
	# Default A.2 behavior is retained for the original validation scene.
	return load("res://scripts/apartment/floor5_visibility.gd").new()

func is_floor_door(node: Node) -> bool:
	var script: Script = node.get_script()
	while script != null:
		if script == Door: return true
		script = script.get_base_script()
	return false

func mesh_for(node: Node3D) -> MeshInstance3D:
	return node.get_node("Upper") if node.has_node("Upper") else node

func update_cutaway() -> void:
	# No half-space or room-enter blanket cut. All structural targets start ON.
	for node in structural_targets:
		var hidden: bool = not show_full_walls and is_instance_valid(structure_visibility) and structure_visibility.is_hidden(node)
		mesh_for(node).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if hidden else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for mesh in dependencies:
		var path: NodePath = mesh.get_meta("cut_owner")
		var owner_node := mesh.get_node(path) if str(path) == ".." else $Apartment/Architecture.get_node(path)
		var source := mesh_for(owner_node)
		if mesh.get_meta("shadowless_fixture",false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visible = source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		else: mesh.cast_shadow = source.cast_shadow
	# Preserve C's decorative basin mirror comparison. This is furniture, not a
	# structural wall, and avoids adding duplicate override data to its PackedScene.
	for mesh in $Apartment/Furniture/Basin.get_children():
		if mesh.get_meta("foreground_panel",false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if not show_full_walls and camera.global_position.z > mesh.global_position.z else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func can_interact() -> bool:
	return player.controls_enabled and (player.combat_component == null or player.combat_component.can_interact())

func choose_door() -> Node3D:
	if not can_interact(): return null
	var best: Node3D
	var best_score := INF
	var facing: Vector3 = -player.visual.global_basis.z
	facing.y = 0
	facing = facing.normalized()
	for door in doors:
		var distance: float = door.distance_to_portal(player.global_position)
		if distance > 1.3: continue
		var center: Vector3 = door.portal_position()
		var query := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*1.1,center,1,[player.get_rid(),door.body.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var direction := center-player.global_position
		direction.y = 0
		var score := distance-0.32*facing.dot(direction.normalized())
		if score < best_score:
			best_score = score
			best = door
	return best

func interact_selected() -> bool:
	target_door = choose_door() # Revalidate range/line of sight at the input event.
	if target_door == null: return false
	show_message(target_door.interact())
	return true

func show_message(value: String) -> void:
	message_label.text = value
	message_remaining = 2.0

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			interact_selected()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_R:
			player.position = P.SPAWN
			player.velocity = Vector3.ZERO
			camera.reset_follow()
			return
	super._unhandled_key_input(event)

func _process(delta: float) -> void:
	update_cutaway()
	target_door = choose_door()
	if interaction_label:
		interaction_label.text = "" if target_door == null else "E  %s · %s"%[target_door.action_label(),target_door.display_name]
	message_remaining = maxf(0,message_remaining-delta)
	if message_label: message_label.visible = message_remaining > 0
	if apartment_status:
		apartment_status.text = "住宅楼 · 五楼  |  501—504\nF%d 正交  |  缩放 %.1f×  |  %d FPS\n玩家 X %.2f  Z %.2f  |  %s"%[camera.mode,camera.get_zoom_multiplier(),Engine.get_frames_per_second(),player.position.x,player.position.z,"501 室内" if player.position.x > -4.6 else "公共楼道"]
		if is_instance_valid(occlusion) and occlusion.debug_label.visible and is_instance_valid(structure_visibility):
			apartment_status.text += "\n动态墙/顶面 %d 段 | 检测 %d μs"%[structure_visibility.hidden_names().size(),structure_visibility.detection_usec]

func build_hud() -> void:
	super.build_hud()
	var canvas := get_node("ApartmentHUD")
	for label in canvas.get_children():
		if label is Label and label != apartment_status:
			label.text = "WASD 移动 / E 开关501或查看房门 / 滚轮缩放 / Home 默认 / R 回501\nF1 85° / F2 65° / F5 45° / F6 斜向 / F7 完整墙体对比 / F8 调试 / F9 轮廓\n502—504 与楼梯间暂不可进入"
	interaction_label = Label.new()
	message_label = Label.new()
	for label in [interaction_label,message_label]:
		label.add_theme_font_override("font",load("res://assets/fonts/WangjiaUI.tres"))
		label.add_theme_font_size_override("font_size",19)
		label.add_theme_color_override("font_shadow_color",Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x",1)
		label.add_theme_constant_override("shadow_offset_y",1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -140 if label == interaction_label else -176
		label.offset_bottom = label.offset_top+30
		canvas.add_child(label)
