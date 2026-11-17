extends "res://scripts/apartment/stairwell_main.gd"
func create_structure_visibility() -> Node:
	var config := preload("res://scripts/visibility/floor5_visibility_config.gd").new()
	config.name = "VisibilityConfiguration"
	add_child(config)
	config.build(self)
	var coordinator := preload("res://scripts/visibility/visibility_coordinator.gd").new()
	coordinator.config = config
	return coordinator
