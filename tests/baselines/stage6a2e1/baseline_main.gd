extends "res://scripts/apartment/floor5_connected_main.gd"
func create_structure_visibility() -> Node:
	return load("res://tests/baselines/stage6a2e1/floor5_smooth_peek_before.gd").new()
