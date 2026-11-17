extends "res://scripts/apartment/stairwell_stable_main.gd"
func create_structure_visibility() -> Node:
	var config := preload("res://scripts/visibility/region_presentation_config.gd").new()
	config.name = "VisibilityConfiguration"
	add_child(config)
	config.build(self)
	var coordinator := preload("res://scripts/visibility/region_presentation_coordinator.gd").new()
	coordinator.config = config
	return coordinator

func _process(delta: float) -> void:
	super._process(delta)
	apartment_status.text = apartment_status.text.replace("A.3 稳定结构 / 单跳区域内容权限","A.4 当前区域完整 / 邻区深色背景")
