extends "res://scripts/apartment/floor5_visibility_main.gd"

func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/floor5_connected_visibility.gd").new()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(structure_visibility):
		apartment_status.text += "\n门洞局部视野 / 活动区域前景墙"
