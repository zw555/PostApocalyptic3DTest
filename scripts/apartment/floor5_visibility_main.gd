extends "res://scripts/apartment/floor5_main.gd"

func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/floor5_visibility_policy.gd").new()

func update_cutaway() -> void:
	# Intentionally no Mesh writes here. The policy is the sole final writer at
	# priority 90, after camera movement and before the priority-100 contour.
	pass

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(structure_visibility):
		apartment_status.text = apartment_status.text.replace("动态墙/顶面","实际遮挡墙")
		apartment_status.text += "\n区域：%s | 本层顶面隐藏"%structure_visibility.region_label()

func build_hud() -> void:
	super.build_hud()
	for label in get_node("ApartmentHUD").get_children():
		if label is Label and label.text.contains("F7 完整墙体对比"):
			label.text = label.text.replace("F7 完整墙体对比","F7 墙体对比（本层顶面仍隐藏）")
