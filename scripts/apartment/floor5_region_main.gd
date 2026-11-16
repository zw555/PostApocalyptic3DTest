extends "res://scripts/apartment/floor5_visibility_main.gd"

func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/floor5_region_presentation.gd").new()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(structure_visibility):
		apartment_status.text = apartment_status.text.replace("本层顶面隐藏","当前区域优先 · 邻户仅保留临楼道边界")
