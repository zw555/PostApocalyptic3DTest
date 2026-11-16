extends "res://scripts/apartment/floor5_connected_main.gd"

func create_structure_visibility() -> Node:
	return load("res://scripts/apartment/floor5_player_peek.gd").new()

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(structure_visibility): apartment_status.text += "\n玩家视线门洞通视 · 相机遮挡独立"
