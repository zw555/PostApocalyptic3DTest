extends "res://scripts/apartment/floor5_smooth_peek_main.gd"
const StairBuilder = preload("res://scripts/apartment/stairwell_builder.gd")
const StairLayout = preload("res://scripts/apartment/stairwell_layout.gd")

func _enter_tree() -> void:
	StairBuilder.build(get_node("Apartment"))
	var entry: Node3D = get_node("Apartment/Corridor/Doors/Doorstairs")
	var saved := {}
	for key in ["door_id","room_id","display_name","portal_point","portal_tangent","floor_root_path","closed_yaw","open_yaw","angular_speed"]: saved[key] = entry.get(key)
	entry.set_script(load("res://scripts/apartment/floor5_safe_door.gd"))
	for key in saved: entry.set(key,saved[key])
	entry.locked = false

func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/stairwell_visibility.gd").new()

func choose_door() -> Node3D:
	var local_y: float = get_node("Apartment").to_local(player.global_position).y
	var d: Dictionary = get_node("Apartment/Stairwell").get_meta("dimensions")
	if local_y < d.five_y-0.50: return null # No E interaction with a door one storey overhead.
	return super.choose_door()

func build_hud() -> void:
	super.build_hud()
	for label in get_node("ApartmentHUD").get_children():
		if label is Label: label.text = label.text.replace("502—504 与楼梯间暂不可进入","502—504 与四楼住户区暂不可进入；楼梯可往返")

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(structure_visibility): return
	var d: Dictionary = get_node("Apartment/Stairwell").get_meta("dimensions")
	apartment_status.text = apartment_status.text.replace("住宅楼 · 五楼  |  501—504","住宅楼 · 五楼 ↔ 四楼楼梯原型")
	apartment_status.text += "\n脚底 Y %.2fm | %s"%[player.global_position.y,structure_visibility.region_label()]
	if structure_visibility.current_region_id == "stairs_landing_f04":
		interaction_label.text = "四楼住宅暂未开放 · 可沿楼梯返回五楼"
